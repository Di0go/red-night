#!/usr/bin/env python3
"""Summarise the GAMMA_LUT the kernel is scanning out on each active CRTC.

Reads `modetest -M <driver> -p` (no root needed) and prints, per CRTC, the
first, middle and last LUT entries plus the max of each channel, as 0-1 floats.
This is the ramp the display hardware applies to every plane (primary, cursor,
overlays), so it is the ground truth for "is the screen red only".
"""
import re
import subprocess
import sys

driver = sys.argv[1] if len(sys.argv) > 1 else "amdgpu"
text = subprocess.run(["modetest", "-M", driver, "-p"], capture_output=True, text=True).stdout
crtcs = text.split("\nPlanes:")[0].split("\nCRTCs:")[1]

for block in re.split(r"\n(?=\d+\t\d+\t\()", crtcs):
    head = re.match(r"\s*(\d+)\t(\d+)\t", block)
    if not head or head.group(2) == "0":
        continue  # inactive CRTC
    lut = re.search(r"GAMMA_LUT:\n.*?value:\n((?:\t\t\t[0-9a-f]+\n)+)", block, re.S)
    if not lut:
        print(f"crtc {head.group(1)}: no GAMMA_LUT set")
        continue
    raw = bytes.fromhex("".join(lut.group(1).split()))
    entries = [
        tuple(int.from_bytes(raw[i + 2 * c:i + 2 * c + 2], "little") / 65535 for c in range(3))
        for i in range(0, len(raw), 8)
    ]
    fmt = lambda e: "(" + ", ".join(f"{v:.3f}" for v in e) + ")"
    peak = tuple(max(e[c] for e in entries) for c in range(3))
    print(f"crtc {head.group(1)}: {len(entries)} entries  first {fmt(entries[0])}  "
          f"mid {fmt(entries[len(entries) // 2])}  last {fmt(entries[-1])}  max {fmt(peak)}")
