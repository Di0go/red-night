#!/usr/bin/env python3
"""Generate profiles with `red-night` into a temp dir and read them back with lcms.

Checks, for several levels: the vcgt tag exists, red(x) = x * level/100 and
green(x) = blue(x) = 0 across the ramp, and the sRGB colorants are unchanged
(so nothing but the VCGT alters colour). No screen is touched.
"""
import ctypes
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
lcms = ctypes.CDLL("liblcms2.so.2")
vp = ctypes.c_void_p
lcms.cmsOpenProfileFromFile.restype = vp
lcms.cmsOpenProfileFromFile.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
lcms.cmsReadTag.restype = vp
lcms.cmsReadTag.argtypes = [vp, ctypes.c_uint32]
lcms.cmsEvalToneCurveFloat.restype = ctypes.c_float
lcms.cmsEvalToneCurveFloat.argtypes = [vp, ctypes.c_float]


class XYZ(ctypes.Structure):
    _fields_ = [("X", ctypes.c_double), ("Y", ctypes.c_double), ("Z", ctypes.c_double)]


failures = 0
with tempfile.TemporaryDirectory() as tmp:
    env = dict(os.environ, XDG_DATA_HOME=tmp)
    for level in (1, 2, 37, 60, 100):
        loader = ("from importlib.machinery import SourceFileLoader;"
                  f"print(SourceFileLoader('rn', '{ROOT}/red-night').load_module().profile_for({level}))")
        path = subprocess.run([sys.executable, "-c", loader], env=env, capture_output=True,
                              text=True, check=True).stdout.strip()
        h = lcms.cmsOpenProfileFromFile(path.encode(), b"r")
        vcgt = lcms.cmsReadTag(h, 0x76636774)
        if not vcgt:
            print(f"FAIL level {level}: no vcgt tag")
            failures += 1
            continue
        curves = ctypes.cast(vcgt, ctypes.POINTER(vp * 3)).contents
        worst = 0.0
        for i in range(101):
            x = i / 100
            r, g, b = (lcms.cmsEvalToneCurveFloat(c, x) for c in curves)
            worst = max(worst, abs(r - x * level / 100), abs(g), abs(b))
        red = XYZ.from_address(lcms.cmsReadTag(h, 0x7258595A))  # 'rXYZ'
        ok = worst < 1e-3 and abs(red.X - 0.4361) < 1e-3
        failures += not ok
        print(f"{'ok  ' if ok else 'FAIL'} level {level:3d}: max |error| {worst:.5f}, "
              f"red(1.0) {lcms.cmsEvalToneCurveFloat(curves[0], 1.0):.4f}, rXYZ.X {red.X:.4f}")
sys.exit(1 if failures else 0)
