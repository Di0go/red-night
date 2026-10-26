#!/usr/bin/env bash
# Install red-night for the current user (no root needed).
#
#   ./install.sh
#
# - ~/.local/bin/red-night          -> symlink to this checkout
# - ~/.local/share/applications/red-night.desktop  (menu entry with actions)
# - global shortcuts, registered live with kglobalaccel and persisted in
#   kglobalshortcutsrc:
#     Meta+Ctrl+Alt+R        toggle
#     Meta+Ctrl+Alt+Up       brighter
#     Meta+Ctrl+Alt+Down     dimmer
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

cat > "$DESKTOP_DIR/$DESKTOP_ID" <<EOF
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
X-KDE-GlobalAccel-CommandShortcut=true
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
EOF
echo "· menu      -> $DESKTOP_DIR/$DESKTOP_ID"
command -v update-desktop-database >/dev/null && update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 >/dev/null 2>&1 || true

# Shortcuts. On Plasma 6 Wayland org.kde.kglobalaccel lives inside kwin_wayland,
# so writing kglobalshortcutsrc alone only takes effect next login: register over
# D-Bus too. setForeignShortcut(asai) on purpose: setShortcutKeys' QKeySequence
# demarshaller reads four ints without checking atEnd(), and a short array aborts
# kwin_wayland (learned in ~/Gadgets/guake-display-switch).
python3 - "$DESKTOP_ID" <<'PY'
import subprocess
import sys
from gi.repository import Gio, GLib

desktop_id = sys.argv[1]
META, CTRL, ALT = 0x10000000, 0x04000000, 0x08000000
UP, DOWN = 0x01000013, 0x01000015
SHORTCUTS = [  # action, friendly name, Qt keycode, kglobalshortcutsrc spelling
    ("_launch", "Toggle Red Night", META | CTRL | ALT | ord("R"), "Meta+Ctrl+Alt+R"),
    ("brighter", "Red Night brighter", META | CTRL | ALT | UP, "Meta+Ctrl+Alt+Up"),
    ("dimmer", "Red Night dimmer", META | CTRL | ALT | DOWN, "Meta+Ctrl+Alt+Down"),
]
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)


def call(method, args, reply):
    return bus.call_sync("org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel",
                         method, args, GLib.VariantType(reply) if reply else None,
                         Gio.DBusCallFlags.NONE, 3000, None)


def owners(key):
    return call("getGlobalShortcutsByKey", GLib.Variant("(i)", (key,)), "(a(ssssssaiai))").unpack()[0]


group = ["--file", "kglobalshortcutsrc", "--group", "services", "--group", desktop_id]
subprocess.run(["kwriteconfig6", *group, "--key", "_k_friendly_name", "Red Night"], check=True)
failed = False
for action, friendly, key, spelled in SHORTCUTS:
    taken = [o for o in owners(key) if o[0] != action or o[2] != desktop_id]
    if taken:
        who = ", ".join(f"{o[2]}/{o[0]}" for o in taken)
        print(f"! {spelled} is already used by {who}: not binding {action}")
        failed = True
        continue
    action_id = [desktop_id, action, "Red Night", friendly]
    call("doRegister", GLib.Variant("(as)", (action_id,)), None)
    call("setForeignShortcut", GLib.Variant("(asai)", (action_id, [key])), None)
    subprocess.run(["kwriteconfig6", *group, "--key", action, f"{spelled},none,{friendly}"], check=True)
    # Check the grab, not the registry: a registered key is not necessarily grabbed.
    if any(o[0] == action and o[2] == desktop_id for o in owners(key)):
        print(f"· shortcut  -> {spelled}: {friendly}")
    else:
        print(f"! {spelled} registered but not grabbed")
        failed = True
sys.exit(1 if failed else 0)
PY

echo
echo "Done. Meta+Ctrl+Alt+R toggles; 'red-night status' shows the state; ./uninstall.sh undoes it all."
