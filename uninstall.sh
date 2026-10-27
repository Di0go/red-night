#!/usr/bin/env bash
# Undo ./install.sh: screens and port LEDs back as they were, stock Brightness and Color back in
# the tray, schedule, LED rule, menu entry, command and generated profiles removed. Leaves this
# checkout alone.
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_ID="red-night.desktop"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"

"$HERE/red-night" off && echo "· screens restored"
"$HERE/red-night" schedule off >/dev/null && echo "· schedule removed"
"$HERE/red-night-tray" remove && echo "· tray: stock Brightness and Color is back"
"$HERE/tools/remove-shortcuts.sh"
systemctl --user disable red-night-leds.service >/dev/null 2>&1
rm -f "$CONF/systemd/user/red-night-leds.service"
systemctl --user daemon-reload
if [ -e /etc/udev/rules.d/90-red-night-lan-leds.rules ]; then
  pkexec "$HERE/tools/lan-leds" remove && echo "· port LED rule removed"
fi

rm -f "$DATA/applications/$DESKTOP_ID" "$HOME/.local/bin/red-night"
rm -rf "$DATA/red-night" "$CONF/red-night" "$STATE/red-night"
command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 >/dev/null 2>&1
echo "· menu entry, command, profiles and settings removed"
