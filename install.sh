#!/usr/bin/env bash
# Install red-night for the current user.
#
#   ./install.sh             asks for the password once, for the port LED rule (pkexec)
#   ./install.sh --no-leds   no root at all; the network port LEDs are left alone
#
# - ~/.local/bin/red-night          -> symlink to this checkout
# - ~/.local/share/applications/red-night.desktop  (menu entry with actions)
# - a Red Night switch in the system tray's Brightness and Color popup, with its
#   guard (red-night-tray install; see README)
# - the wired network port LEDs off while the filter is on: a udev rule and ledtrig-netdev at
#   boot (tools/lan-leds, as root), and red-night-leds.service to apply it again at login
# - removes the global shortcuts an older install registered
#
# Undo everything with ./uninstall.sh.
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin/red-night"
DESKTOP_ID="red-night.desktop"
DESKTOP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
UNITS="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
LEDS=1
[ "${1:-}" = "--no-leds" ] && LEDS=0

mkdir -p "$(dirname "$BIN")" "$DESKTOP_DIR"
ln -sfn "$HERE/red-night" "$BIN"
echo "· command   -> $BIN"

cat > "$DESKTOP_DIR/$DESKTOP_ID" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Red Night
GenericName=Red-only screen filter
Comment=Toggle a red-only screen filter (green and blue off)
Exec=$BIN toggle
Icon=redshift-status-on
Terminal=false
StartupNotify=false
Categories=Utility;
Keywords=night;red;filter;color;tint;
Actions=on;off;brighter;dimmer;

[Desktop Action on]
Name=On
Exec=$BIN on

[Desktop Action off]
Name=Off
Exec=$BIN off

[Desktop Action brighter]
Name=Brighter
Exec=$BIN level up

[Desktop Action dimmer]
Name=Dimmer
Exec=$BIN level down
DESKTOP
echo "· menu      -> $DESKTOP_DIR/$DESKTOP_ID"
command -v update-desktop-database >/dev/null && update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 >/dev/null 2>&1 || true

"$HERE/tools/remove-shortcuts.sh"
"$HERE/red-night-tray" install
echo "· tray      -> Red Night switch in Brightness and Color"

if [ "$LEDS" = 1 ] && compgen -G "/sys/class/leds/*::lan" >/dev/null; then
  if pkexec "$HERE/tools/lan-leds" install "$(id -un)"; then
    mkdir -p "$UNITS"
    cat > "$UNITS/red-night-leds.service" <<UNIT
[Unit]
Description=red-night: network port LEDs off if the filter is on
After=plasma-kwin_wayland.service

[Service]
Type=oneshot
ExecStart=$BIN leds
Restart=on-failure
RestartSec=5

[Install]
WantedBy=plasma-workspace.target
UNIT
    systemctl --user daemon-reload
    systemctl --user enable red-night-leds.service >/dev/null 2>&1
    "$BIN" leds
    echo "· port LEDs -> off while the filter is on (udev rule, red-night-leds.service)"
  else
    echo "· port LEDs -> skipped (no root); run ./install.sh again to add them"
  fi
fi

echo
echo "Done. Click the brightness icon in the tray; 'red-night status' shows the state; ./uninstall.sh undoes it all."
