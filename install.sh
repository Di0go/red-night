#!/usr/bin/env bash
# Install red-night for the current user (no root needed).
#
#   ./install.sh
#
# - ~/.local/bin/red-night          -> symlink to this checkout
# - ~/.local/share/applications/red-night.desktop  (menu entry with actions)
# - a Red Night switch in the system tray's Brightness and Color popup, with its
#   guard (red-night-tray install; see README)
# - removes the global shortcuts an older install registered
#
# Undo everything with ./uninstall.sh.
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin/red-night"
DESKTOP_ID="red-night.desktop"
DESKTOP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

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

echo
echo "Done. Click the brightness icon in the tray; 'red-night status' shows the state; ./uninstall.sh undoes it all."
