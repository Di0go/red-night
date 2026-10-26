#!/usr/bin/env bash
# End-to-end check on the real screen, a few seconds red at most, always reverted.
# Runs the same commands the tray switch runs, then reads the CRTC GAMMA_LUT the
# hardware is using after each step.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RN="$HERE/../red-night"
trap '"$RN" off >/dev/null 2>&1' EXIT
lut() { printf '%-22s' "$1"; python3 "$HERE/crtc-lut.py" | sed 's/^crtc [0-9]*: 4096 entries  //'; }
lut "before"
"$RN" on >/dev/null;         lut "on ($("$RN" state))"
"$RN" level up >/dev/null;   lut "brighter"
"$RN" level down >/dev/null; lut "dimmer"
"$RN" off >/dev/null;        lut "off ($("$RN" state))"
