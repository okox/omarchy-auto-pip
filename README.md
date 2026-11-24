# Auto Picture-in-Picture for Omarchy

Watching a video and need to jump to another desktop? With this, the video
follows you. Leave a desktop where a browser is playing a video and it pops out
into the browser's own picture-in-picture window, pinned in a corner of every
desktop. Go back to that desktop and the PiP closes; the video carries on in
its tab as if nothing happened.

For [Omarchy](https://omarchy.org) and other [Hyprland](https://hyprland.org)
setups, with Chromium-based browsers (Chromium, Brave, Chrome, Vivaldi, Edge).
Tested with Chromium; the others share its machinery but are untested so far.

![The bar icon, on and off](assets/bar.png)

## How it behaves

- **Only when something is playing.** A paused video stays where it is.
- **It remembers where you put it.** Drag or resize the PiP once and it opens
  there from then on.
- **It never moves you.** Opening the PiP needs a keypress in the browser, so
  for a moment the keyboard goes to the browser and straight back to the
  window you were using. If you type at that exact instant, a key could land
  in the browser.
- **On/off switch:** the bar icon (dimmed and crossed out when off), or
  `auto-pip toggle` on a key. Switching off also closes an open PiP.
- A PiP you open yourself is left alone.

## Requirements

- Hyprland **0.56 or newer** (Lua dispatchers).
- `jq`, `socat`, `busctl` (systemd) and `flock`. All come with Omarchy.
- A Chromium-based browser.
- Omarchy for the bar icon. Without it, everything else works; see
  [Without Omarchy](#without-omarchy).

## Install

```bash
omarchy plugin add https://github.com/okox/omarchy-auto-pip.git
~/.config/omarchy/plugins/okox.auto-pip/setup.sh
```

Or clone it anywhere and run `./setup.sh`. Re-run it any time to update.

Setup:

1. Puts the project in `~/.config/omarchy/plugins/okox.auto-pip` and an
   `auto-pip` command in `~/.local/bin`.
2. Adds the browser extension to `~/.config/chromium-flags.conf` (and
   `brave-flags.conf` if you use Brave).
3. Starts the watcher as a systemd user service, `auto-pip.service`, which
   runs with your desktop session.
4. Puts the icon on the right of the bar.

Then **restart your browser once** so it loads the extension.

**Google Chrome, Vivaldi, Edge:** Chrome ignores the extension flag, so load
it by hand: open `chrome://extensions`, switch on *Developer mode*, click
*Load unpacked* and pick `~/.config/omarchy/plugins/okox.auto-pip/extension`.

### A key to switch it

Add to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + P", "Auto picture-in-picture on/off", "auto-pip toggle")
```

## Settings

`~/.config/auto-pip/config`, plain shell variables
([all of them](examples/config)). After a change:
`systemctl --user restart auto-pip`.

```bash
TITLE='YouTube|Twitch'   # only pop out from these sites (window title); default: any
SIZE='480 270'           # first PiP size; afterwards it remembers yours
NOTIFY=0                 # no notification when switching on/off
```

To switch something else along with it (another player's PiP script, say),
put an executable `~/.config/auto-pip/on-switch`; it gets `on` or `off`
([example](examples/on-switch)).

## Commands

```
auto-pip on | off | toggle   switch it (switching off closes an open PiP)
auto-pip status              prints on or off
auto-pip close               close the PiP it opened, now
auto-pip watch               the watcher itself (run by auto-pip.service)
```

## How it works

Browsers only let a page open picture-in-picture in response to something
you do, such as a click or a keypress. So the project has two halves:

- **A tiny browser extension** with two keyboard shortcuts, Alt+Shift+8 (open
  PiP for the biggest playing video in the tab) and Alt+Shift+9 (close it).
  It has no background activity, reads nothing and sends nothing anywhere;
  it only acts when one of its shortcuts is pressed.
- **A watcher** (`bin/auto-pip`) that listens to Hyprland's desktop changes.
  When you leave a desktop, it checks whether the browser window you left is
  playing (through the browser's media player on D-Bus, MPRIS) and, if so,
  sends that window the shortcut with Hyprland's `send_shortcut`. It then
  pins the PiP in its spot; when you come back it sends the closing one.

If a shortcut clashes with something, change it at
`chrome://extensions/shortcuts` and set `MODS`, `OPEN_KEY` and `CLOSE_KEY`
in the config to match.

## Without Omarchy

Everything except the bar icon works on any Hyprland 0.56+. Run `./setup.sh`
from a clone (it skips the bar), and give PiP windows a floating, pinned rule,
which Omarchy has built in:

```lua
hl.window_rule({ match = { title = "^Picture.?in.?[Pp]icture$" }, float = true, pin = true })
```

For Waybar, a custom module can show `auto-pip status` and run
`auto-pip toggle` on click.

## Troubleshooting

- **Nothing happens:** check the browser has loaded the extension
  (`chrome://extensions`) and that its shortcuts are set
  (`chrome://extensions/shortcuts`). Then `journalctl --user -u auto-pip`.
- **Pops out from the wrong window:** set `TITLE` so only video sites count.
- **Flatpak or Snap browsers** aren't supported yet.

## Uninstall

```bash
~/.config/omarchy/plugins/okox.auto-pip/uninstall.sh          # keeps your settings
~/.config/omarchy/plugins/okox.auto-pip/uninstall.sh --purge  # removes them too
```

## License

[MIT](LICENSE)
