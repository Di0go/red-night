#!/usr/bin/env bash
# End-to-end check on the real screen, a few seconds red at most, always reverted.
# Fires the installed global shortcuts through kglobalaccel (same path as the
# keys), then reads the CRTC GAMMA_LUT the hardware is using after each step.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
trap '"$HERE/../red-night" off >/dev/null 2>&1' EXIT
fire() {
    gdbus call --session --dest org.kde.kglobalaccel --object-path /component/red_night_desktop \
        --method org.kde.kglobalaccel.Component.invokeShortcut "$1" >/dev/null
    sleep 0.8  # the action runs asynchronously as a launched command
}
lut() { printf '%-26s' "$1"; python3 "$HERE/crtc-lut.py" | sed 's/^crtc [0-9]*: 4096 entries  //'; }
lut "before"
fire _launch;  lut "toggle (shortcut)"
fire brighter; lut "brighter (shortcut)"
fire dimmer;   lut "dimmer (shortcut)"
fire _launch;  lut "toggle again (shortcut)"
