// Auto picture-in-picture: the browser half.
// The auto-pip watcher sends these shortcuts to the browser window you leave
// (open) and come back to (close). A keyboard shortcut counts as a user
// gesture, which requestPictureInPicture() needs.

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

function exit() {
  if (!document.pictureInPictureElement) return 'none';
  // exitPictureInPicture keeps the video playing in its tab
  return document.exitPictureInPicture().then(() => 'exited', (e) => 'error: ' + e.message);
}

chrome.commands.onCommand.addListener((command, tab) => {
  const func = command === 'pip-enter' ? enter : command === 'pip-exit' ? exit : null;
  if (!func || !tab || tab.id === undefined) return;
  chrome.scripting
    .executeScript({ target: { tabId: tab.id, allFrames: false }, world: 'MAIN', func })
    .then((r) => console.log(command, r && r[0] && r[0].result))
    .catch((e) => console.log(command, 'failed', e.message));
});
