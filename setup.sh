#!/bin/bash
# Auto picture-in-picture: install or update. Safe to re-run.
#
#   omarchy plugin add https://github.com/okox/omarchy-auto-pip.git
#   ~/.config/omarchy/plugins/okox.auto-pip/setup.sh
#
# or from a clone anywhere: ./setup.sh
set -euo pipefail
SRC=$(cd "$(dirname "$0")" && pwd)
ID=okox.auto-pip
PLUGIN="$HOME/.config/omarchy/plugins/$ID"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
UNITS="$CONF/systemd/user"
EXT="$PLUGIN/extension"

say() { printf '\033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*" >&2; }

for cmd in hyprctl jq socat busctl flock; do
  command -v "$cmd" >/dev/null || { warn "Needs '$cmd', which isn't installed."; exit 1; }
done
ver=$(hyprctl version -j 2>/dev/null | jq -r '.tag // .version // empty' | tr -d v)
if [[ -n $ver ]] && [[ $(printf '%s\n0.56\n' "${ver%%-*}" | sort -V | head -1) != 0.56 ]]; then
  warn "Hyprland $ver found; auto-pip needs 0.56 or newer (Lua dispatchers)."
  exit 1
fi

# 1. Into the plugin folder, unless this already is it.
if [[ $SRC != "$PLUGIN" ]]; then
  say "Installing into $PLUGIN"
  mkdir -p "$PLUGIN"
  rsync -a --delete --exclude .git "$SRC/" "$PLUGIN/"
fi

# 2. The command, run straight from the plugin folder so
#    `omarchy plugin update okox.auto-pip` updates it too.
mkdir -p "$HOME/.local/bin" "$CONF/auto-pip" "$UNITS"
ln -sfn "$PLUGIN/bin/auto-pip" "$HOME/.local/bin/auto-pip"
[[ -e $CONF/auto-pip/config ]] || cp "$PLUGIN/examples/config" "$CONF/auto-pip/config"

# 3. The browser extension, loaded at browser start by a flag.
#    Chromium and Brave read ~/.config/<browser>-flags.conf. Google Chrome
#    ignores --load-extension, so it's loaded by hand there (see below).
add_ext() { # $1 = flags file
  local f=$1
  if [[ -f $f ]] && grep -qE -- "^--load-extension=(.*,)?$EXT(,|$)" "$f"; then return; fi
  [[ -f $f ]] && cp "$f" "$f.bak.$(date +%s)"
  if [[ -f $f ]] && grep -q -- '^--load-extension=' "$f"; then
    sed -i "s|^--load-extension=.*|&,$EXT|" "$f"
  else
    echo "--load-extension=$EXT" >>"$f"
  fi
  say "Added the extension to $f"
}
loaded=()
for b in chromium brave; do
  if command -v "$b" >/dev/null || [[ -f $CONF/$b-flags.conf ]]; then
    add_ext "$CONF/$b-flags.conf"
    loaded+=("$b")
  fi
done

# Shortcuts only go to the first extension that asks for them. If a copy of
# this extension loaded from another folder (so with another ID) had them,
# Chromium keeps them there, and this one gets none. Say so.
shortcut_check() { # $1 = browser profile folder
  local prefs="$1/Default/Preferences" id
  [[ -f $prefs ]] || return 0
  id=$(jq -r --arg p "$EXT" '[.extensions.settings // {} | to_entries[] | select(.value.path == $p) | .key][0] // empty' "$prefs" 2>/dev/null)
  [[ -n $id ]] || return 0 # not loaded yet: it gets the shortcuts on first start
  jq -e --arg id "$id" '[.extensions.commands // {} | to_entries[] | select(.value.extension == $id)] | length > 0' \
    "$prefs" >/dev/null 2>&1 && return 0
  warn "The extension in ${1##*/} has no keyboard shortcuts (another copy took them)."
  warn "Open chrome://extensions/shortcuts there and set Auto Picture-in-Picture to Alt+Shift+8 / Alt+Shift+9."
}
shortcut_check "$CONF/chromium"
shortcut_check "$CONF/BraveSoftware/Brave-Browser"

# 4. The watcher, as a user service that runs with your Hyprland session.
cp "$PLUGIN/systemd/auto-pip.service" "$UNITS/"
systemctl --user daemon-reload
systemctl --user enable auto-pip.service >/dev/null 2>&1
systemctl --user restart auto-pip.service

# 5. The bar icon.
if command -v omarchy >/dev/null; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  sleep 1
  omarchy plugin enable "$ID" >/dev/null 2>&1 || true
  omarchy bar put "$ID" --section right --index 0 >/dev/null 2>&1 || true
fi

say "Auto picture-in-picture is installed."
echo
if ((${#loaded[@]})); then
  echo "Restart your browser (${loaded[*]}) once so it loads the extension."
fi
echo "Google Chrome, Vivaldi, Edge: open the extensions page, switch on Developer"
echo "mode, click 'Load unpacked' and pick $EXT"
echo
echo "A key to switch it on/off, for ~/.config/hypr/bindings.lua:"
echo "  o.bind(\"SUPER + ALT + P\", \"Auto picture-in-picture on/off\", \"auto-pip toggle\")"
