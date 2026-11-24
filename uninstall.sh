#!/bin/bash
# Remove auto picture-in-picture. Keeps ~/.config/auto-pip unless --purge.
ID=okox.auto-pip
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
EXT="$HOME/.config/omarchy/plugins/$ID/extension"

auto-pip close 2>/dev/null
systemctl --user disable --now auto-pip.service 2>/dev/null
rm -f "$CONF/systemd/user/auto-pip.service"
systemctl --user daemon-reload

for f in "$CONF"/chromium-flags.conf "$CONF"/brave-flags.conf; do
  [[ -f $f ]] && grep -q -- "$EXT" "$f" || continue
  cp "$f" "$f.bak.$(date +%s)"
  sed -i -e "s#,$EXT\(,\|$\)#\1#" -e "s#=$EXT,#=#" -e "\#^--load-extension=$EXT\$#d" "$f"
done

command -v omarchy >/dev/null && omarchy plugin disable "$ID" >/dev/null 2>&1
rm -rf "$HOME/.local/bin/auto-pip" "${XDG_STATE_HOME:-$HOME/.local/state}/auto-pip" \
  "${XDG_RUNTIME_DIR:-/run/user/$UID}/auto-pip" "$HOME/.config/omarchy/plugins/$ID"
if [[ ${1:-} == --purge ]]; then
  rm -rf "$CONF/auto-pip"
  echo "Auto picture-in-picture removed, with its settings."
else
  echo "Auto picture-in-picture removed. Kept your settings in $CONF/auto-pip."
fi
echo "Restart your browser to unload the extension."
