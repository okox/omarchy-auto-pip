// Auto picture-in-picture: the browser half.
// The auto-pip watcher sends these shortcuts to the browser window you leave
// (open) and come back to (close). A keyboard shortcut counts as a user
// gesture, which requestPictureInPicture() needs.
//
// The playing video can be in any tab of that window, not only the one on
// screen, which is why the extension asks for access to all sites. It only
// ever runs on these two shortcuts, and reads nothing else.
//
// Chromium lets only the tab that was on screen when the key arrived use its
// gesture. So for a video in another tab it takes two presses: the first
// brings that tab to the front, the second (the watcher sends it) opens the
// PiP, and then the tab you had goes back on top. That window is on the
// desktop you just left, so you don't see any of it.

// Runs in the page.
function enter() {
  if (document.pictureInPictureElement) return 'already';
  const playing = [...document.querySelectorAll('video')].filter(
    (v) => !v.paused && !v.ended && v.readyState > 2 && !v.disablePictureInPicture
  );
  if (!playing.length) return 'none';
  // the biggest playing video, not a muted preview thumbnail
  playing.sort((a, b) => b.clientWidth * b.clientHeight - a.clientWidth * a.clientHeight);
  return playing[0].requestPictureInPicture().then(() => 'entered', (e) => 'error: ' + e.message);
}

// Runs in the page: is a video playing here?
function playing() {
  return [...document.querySelectorAll('video')].some((v) => !v.paused && !v.ended && v.readyState > 2);
}

// Runs in the page.
function exit() {
  if (!document.pictureInPictureElement) return 'none';
  // exitPictureInPicture keeps the video playing in its tab
  return document.exitPictureInPicture().then(() => 'exited', (e) => 'error: ' + e.message);
}

async function run(tabId, func) {
  try {
    const [r] = await chrome.scripting.executeScript({ target: { tabId }, world: 'MAIN', func });
    return r && r.result;
  } catch (e) {
    return 'skip: ' + e.message; // a page extensions can't touch (chrome://, the web store)
  }
}

// The tab on screen first, then tabs making sound, then the rest.
async function candidates(tab) {
  const tabs = await chrome.tabs.query({ windowId: tab.windowId });
  const rank = (t) => (t.id === tab.id ? 0 : t.audible ? 1 : 2);
  return tabs.filter((t) => !t.discarded).sort((a, b) => rank(a) - rank(b));
}

// The PiP request must start while the shortcut is being handled (Chromium
// only trusts it that long), so the tab in front is tried straight away and
// everything else waits until after.
async function openPip(tab, front) {
  const result = await front;
  const { back } = await chrome.storage.session.get('back');
  await chrome.storage.session.remove('back');
  if (result === 'entered' || result === 'already') await chrome.storage.session.set({ pipTab: tab.id });
  // second press: the tab you had goes back on top, the PiP stays open
  if (back && back.windowId === tab.windowId && Date.now() - back.at < 5000) {
    await chrome.tabs.update(back.tabId, { active: true }).catch(() => {});
    return `${result} (tab ${tab.id}, back to ${back.tabId})`;
  }
  if (result === 'entered' || result === 'already') return `${result} (tab ${tab.id})`;
  // first press: is the video in another tab? bring it forward for the next press
  for (const t of await candidates(tab)) {
    if (t.id === tab.id || (await run(t.id, playing)) !== true) continue;
    await chrome.storage.session.set({ back: { tabId: tab.id, windowId: tab.windowId, at: Date.now() } });
    await chrome.tabs.update(t.id, { active: true });
    return `brought tab ${t.id} forward: press again`;
  }
  return 'nothing playing';
}

async function closePip(tab) {
  const { pipTab } = await chrome.storage.session.get('pipTab');
  await chrome.storage.session.remove('pipTab');
  if (pipTab !== undefined && (await run(pipTab, exit)) === 'exited') return `exited (tab ${pipTab})`;
  for (const t of await candidates(tab)) if ((await run(t.id, exit)) === 'exited') return `exited (tab ${t.id})`;
  return 'none';
}

chrome.commands.onCommand.addListener((command, tab) => {
  if (!tab || tab.windowId === undefined) return;
  const job = command === 'pip-enter' ? openPip(tab, run(tab.id, enter)) : command === 'pip-exit' ? closePip(tab) : null;
  if (job) job.then((r) => console.log(command, r), (e) => console.log(command, 'failed', e.message));
});
