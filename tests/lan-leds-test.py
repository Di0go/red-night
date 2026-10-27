#!/usr/bin/env python3
"""The network port LEDs, offline: a fake /sys/class/leds that behaves like the r8169 netdev
hardware offload (activating netdev reads the mode from the hardware, leaving it keeps the
mode; rx without tx is not a hardware mode, so that write keeps the bit and fails with
EOPNOTSUPP), in a temporary directory. Touches nothing real.

  1. dark: every wired *::lan LED on netdev with every mode 0; the wireless one untouched
  2. dark again (a level change): the saved state is the original, not the dark one
  3. restore: modes and trigger exactly as before, saved state removed
  4. a LED that was already on netdev stays on netdev
  5. reboot while on (hardware back to its default, trigger none): sync darkens them again,
     and restore still gives the state from before the first dark
  6. no write permission (the udev rule is not installed): skipped, nothing raised, trigger kept
"""
import errno
import os
import sys
import tempfile
from importlib.machinery import SourceFileLoader
from pathlib import Path

HERE = Path(__file__).resolve().parent
tmp = Path(tempfile.mkdtemp(prefix="red-night-leds-test."))
os.environ["XDG_STATE_HOME"] = str(tmp / "state")
os.environ["RED_NIGHT_LEDS"] = str(tmp / "leds")

rn = SourceFileLoader("red_night", str(HERE.parent / "red-night")).load_module()
rn.LED_WAIT = 0.05

MODES = rn.NETDEV_MODES
TRIGGERS = ["none", "kbd-numlock", "netdev"]
DEFAULT = {"a-0::lan": {"rx": 1, "tx": 1}, "a-2::lan": {"link_10": 1, "link_100": 1, "link_1000": 1},
           "b-0::lan": {"rx": 1, "tx": 1}, "w-0::lan": {"link": 1}}
hw = {}                # the hardware register of each LED: {mode: 0|1}
readonly = set()


def boot():
    """Hardware back to its default, every trigger none, no netdev files."""
    for name, modes in DEFAULT.items():
        d = tmp / "leds" / name
        (d / "device").mkdir(parents=True, exist_ok=True)
        for m in MODES:
            (d / m).unlink(missing_ok=True)
        hw[name] = {m: modes.get(m, 0) for m in MODES}
        set_trigger(d, "none")
    (tmp / "leds/w-0::lan/device/wireless").mkdir(exist_ok=True)


def set_trigger(d, trigger):
    (d / "trigger").write_text(" ".join(f"[{t}]" if t == trigger else t for t in TRIGGERS) + "\n")
    for m in MODES:
        if trigger == "netdev":
            (d / m).write_text(f"{hw[d.name][m]}\n")
        else:
            (d / m).unlink(missing_ok=True)


def fake_write(path, value):
    d = path.parent
    if d.name in readonly:
        raise PermissionError(13, "Permission denied", str(path))
    if path.name == "trigger":
        set_trigger(d, value)
    else:
        mode = dict(rn.led_modes(d), **{path.name: int(value)})  # the trigger keeps the bit either way
        path.write_text(f"{value}\n")
        if mode["rx"] != mode["tx"]:
            raise OSError(errno.EOPNOTSUPP, "Operation not supported")
        hw[d.name] = mode


rn.sysfs_write = fake_write
rn.writable = lambda path: path.exists() and path.parent.name not in readonly


def state(name):
    """The trigger and the hardware mode, checked against what the mode files say."""
    d = tmp / "leds" / name
    trigger = rn.led_trigger(d)
    if trigger == "netdev" and rn.led_modes(d) != hw[name]:
        return trigger, "files and hardware differ"
    return trigger, {m: v for m, v in hw[name].items() if v}


failed = 0


def check(what, got, want):
    global failed
    ok = got == want
    failed += not ok
    print(f"{'ok  ' if ok else 'FAIL'} {what}" + ("" if ok else f"\n     got  {got}\n     want {want}"))


boot()
before = {n: state(n) for n in DEFAULT}

# 1
rn.leds_dark()
for n in ("a-0::lan", "a-2::lan", "b-0::lan"):
    check(f"dark: {n} netdev, all modes 0", state(n), ("netdev", {}))
check("dark: wireless LED untouched", state("w-0::lan"), before["w-0::lan"])
saved = rn.LED_SAVED.read_text()

# 2
rn.leds_dark()
check("dark twice: saved state unchanged", rn.LED_SAVED.read_text(), saved)

# 3
rn.leds_restore()
check("restore: every LED as before", {n: state(n) for n in DEFAULT}, before)
check("restore: saved state removed", rn.LED_SAVED.exists(), False)

# 4
set_trigger(tmp / "leds/b-0::lan", "netdev")
rn.leds_dark()
rn.leds_restore()
check("already netdev: stays netdev with its modes", state("b-0::lan"), ("netdev", {"rx": 1, "tx": 1}))
set_trigger(tmp / "leds/b-0::lan", "none")

# 5
rn.leds_dark()
boot()
check("reboot: hardware lit again", state("a-2::lan"), before["a-2::lan"])
rn.is_on = lambda outs=None: True
rn.leds_sync()
check("reboot, Red Night on: sync darkens", state("a-2::lan"), ("netdev", {}))
rn.is_on = lambda outs=None: False
rn.leds_sync()
check("Red Night off: sync restores", {n: state(n) for n in DEFAULT}, before)

# 6
readonly.add("a-0::lan")
rn.leds_dark()
check("no permission: LED left as it was", state("a-0::lan"), before["a-0::lan"])
check("no permission: the others still dark", state("a-2::lan"), ("netdev", {}))
rn.leds_restore()
readonly.clear()
check("no permission: restore of the others", {n: state(n) for n in DEFAULT}, before)

print("all passed" if not failed else f"{failed} failed")
sys.exit(1 if failed else 0)
