#!/usr/bin/env python3
"""The tray guard, offline: temporary XDG dirs, a copy of the real appletsrc, plasmashell treated
as not running (so the tray is edited in the file) and no notifications. Touches nothing real.

  1. build from the installed powerdevil: the copy compiles and records what it was built from
  2. swap the stock applet for the copy in the tray, and back: other tray items untouched
  3. check with nothing changed: no rebuild
  4. check after "an update" (recorded fingerprint differs): rebuilds, tray keeps the copy
  5. check after an update that cannot be rebuilt (the applet .so is something else):
     tray back to the stock applet, copy removed, error recorded
  6. install when the tray has neither applet: the copy is added
"""
import os
import shutil
import sys
import tempfile
from importlib.machinery import SourceFileLoader
from pathlib import Path

# On a private session bus: the code under test talks to plasmashell and the tray over D-Bus,
# and a stray signal on the real bus changes the real tray.
if os.environ.get("RED_NIGHT_TEST_BUS") != "private":
    os.environ["RED_NIGHT_TEST_BUS"] = "private"
    os.execvp("dbus-run-session", ["dbus-run-session", "--", sys.executable, *sys.argv])

HERE = Path(__file__).resolve().parent
tmp = Path(tempfile.mkdtemp(prefix="red-night-tray-test."))
for var in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_STATE_HOME"):
    os.environ[var] = str(tmp / var)
    (tmp / var).mkdir()
real = Path.home() / ".config/plasma-org.kde.plasma.desktop-appletsrc"
shutil.copy(real, tmp / "XDG_CONFIG_HOME" / real.name)

t = SourceFileLoader("red_night_tray", str(HERE.parent / "red-night-tray")).load_module()
t.plasmashell_running = lambda: False
signals = []
t.announce = signals.append
notes = []
t.notify_later = notes.append
t.swap_tray(t.FORK, t.STOCK)  # the copy of a real config may already have the switch installed
failures = 0


def expect(what, ok):
    global failures
    print(f"{'ok  ' if ok else 'FAIL'} {what}")
    failures += not ok


def tray_items(key="extraItems"):
    out = []
    for group in t.tray_groups():
        args = ["--file", str(t.APPLETSRC)] + [a for g in group for a in ("--group", g)]
        import subprocess
        out += subprocess.run(["kreadconfig6", *args, "--key", key], capture_output=True, text=True).stdout.strip().split(",")
    return out


try:
    fp = t.build()
    expect(f"1 built from powerdevil {fp['version']}, fingerprint recorded", t.built_from() == fp)
    expect("1 Red Night row is in PopupDialog.qml", "RedNightItem {" in (t.PKG / "contents/ui/PopupDialog.qml").read_text())

    before = tray_items()
    t.swap_tray(t.STOCK, t.FORK)
    after = tray_items()
    expect("2 tray: stock replaced by the copy, in the same place",
           after == [t.FORK if i == t.STOCK else i for i in before] and t.STOCK not in after)
    expect("2 knownItems keeps the stock id (so the tray does not add it back)",
           t.STOCK in tray_items("knownItems") and t.FORK in tray_items("knownItems"))
    t.swap_tray(t.FORK, t.STOCK)
    expect("2 and back: tray exactly as before", tray_items() == before)
    t.swap_tray(t.STOCK, t.FORK)

    stamp = (t.PKG / "contents/ui/main.qml").stat().st_mtime_ns
    t.check()
    expect("3 nothing changed: no rebuild", (t.PKG / "contents/ui/main.qml").stat().st_mtime_ns == stamp and not notes)

    (t.PKG / t.SOURCE_FILE).write_text('{"version": "older"}\n')
    t.check()
    expect("4 after an update: rebuilt, fingerprint current", t.built_from() == t.fingerprint())
    expect("4 tray still shows the copy", t.FORK in tray_items() and t.STOCK not in tray_items())
    expect("4 told the user", len(notes) == 1 and "Rebuilt" in notes[0])

    t.APPLET_SO = Path("/usr/lib/qt6/plugins/plasma/applets/org.kde.plasma.battery.so")
    t.check()
    expect("5 unbuildable update: tray back to stock", t.STOCK in tray_items() and t.FORK not in tray_items())
    expect("5 copy removed", not t.PKG.exists())
    expect("5 error recorded and user told", (t.STATE / "tray-error").exists() and len(notes) == 2 and "stock" in notes[1])
    expect("5 tray exactly as before the install", tray_items() == before)
    expect("5 tray told the copy is gone, after the swap back", signals[-1] == "packageUninstalled")

    t.swap_tray(t.STOCK, "nowhere.applet")  # neither id in the tray
    t.swap_tray(t.FORK, t.STOCK)
    t.swap_tray(t.STOCK, t.FORK, ensure=True)
    expect("6 install with neither id in the tray adds the copy", tray_items()[-1] == t.FORK)
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print("all passed" if not failures else f"{failures} failed")
sys.exit(1 if failures else 0)
