#!/usr/bin/env bash
# Undo ./install.sh: screens back as they were, schedule, shortcuts, menu entry,
# command and generated profiles removed. Leaves this checkout alone.
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_ID="red-night.desktop"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"

"$HERE/red-night" off && echo "· screens restored"
"$HERE/red-night" schedule off >/dev/null && echo "· schedule removed"

python3 - "$DESKTOP_ID" <<'PY'
import sys
from gi.repository import Gio, GLib

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
for action in ("_launch", "brighter", "dimmer"):
    try:
        bus.call_sync("org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel", "unregister",
                      GLib.Variant("(ss)", (sys.argv[1], action)), GLib.VariantType("(b)"),
                      Gio.DBusCallFlags.NONE, 3000, None)
    except GLib.Error as e:
        print(f"! could not unregister {action}: {e.message}")
print("· shortcuts unregistered")
PY
kwriteconfig6 --file kglobalshortcutsrc --group services --group "$DESKTOP_ID" --key _launch --delete
kwriteconfig6 --file kglobalshortcutsrc --group services --group "$DESKTOP_ID" --key brighter --delete
kwriteconfig6 --file kglobalshortcutsrc --group services --group "$DESKTOP_ID" --key dimmer --delete
kwriteconfig6 --file kglobalshortcutsrc --group services --group "$DESKTOP_ID" --key _k_friendly_name --delete

rm -f "$DATA/applications/$DESKTOP_ID" "$HOME/.local/bin/red-night"
rm -rf "$DATA/red-night" "$CONF/red-night" "$STATE/red-night"
command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 >/dev/null 2>&1
echo "· menu entry, command, profiles and settings removed"
