#!/usr/bin/env bash
# Remove the global shortcuts (Meta+Ctrl+Alt+R/Up/Down) that installs before the tray
# switch registered. Safe to run when there are none.
set -uo pipefail
DESKTOP_ID="red-night.desktop"
python3 - "$DESKTOP_ID" <<'PY'
import sys
from gi.repository import Gio, GLib

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
removed = 0
for action in ("_launch", "brighter", "dimmer"):
    try:
        reply = bus.call_sync("org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel", "unregister",
                              GLib.Variant("(ss)", (sys.argv[1], action)), GLib.VariantType("(b)"),
                              Gio.DBusCallFlags.NONE, 3000, None)
        removed += reply.unpack()[0]
    except GLib.Error as e:
        print(f"! could not unregister {action}: {e.message}")
print(f"· shortcuts: {removed} removed" if removed else "· shortcuts: none registered")
PY
for key in _launch brighter dimmer _k_friendly_name; do
    kwriteconfig6 --file kglobalshortcutsrc --group services --group "$DESKTOP_ID" --key "$key" --delete
done
