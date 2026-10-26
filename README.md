# red-night

A truly red screen for night use on KDE Plasma 6 (Wayland): green and blue are switched
off and only the red channel is left, with adjustable brightness. It's like macOS's Color
Filters, Color Tint red at 100 %, with Reduce White Point. Plasma's Night Light stops at
about 1000 K, which is still orange.

## How it works

Plasma 6 colour management lets each output use an ICC profile, and KWin honours the
profile's **VCGT** (video card gamma table). `red-night` writes an ordinary sRGB profile
whose VCGT ramps are:

- red: identity × level/100
- green and blue: flat at 0

It then sets that profile on every enabled output with `kscreen-doctor`. On this machine
(amdgpu) KWin loads the ramp into the CRTC's hardware `GAMMA_LUT`. That means:

- **no per-frame cost**: no shader pass, and the compositor does no extra work;
- **everything is covered**: the cursor plane, fullscreen video and direct scanout all
  pass through the CRTC LUT;
- Plasma's Night Light setting is left alone.

When it is turned off, each output gets back the colour profile source and ICC path it
had before.

## Install

```sh
./install.sh
```

No root needed. This installs:

| What | Where |
|---|---|
| command | `~/.local/bin/red-night` (symlink to this checkout) |
| menu entry "Red Night" (right-click for On/Off/Brighter/Dimmer; can be dragged to a panel) | `~/.local/share/applications/red-night.desktop` |
| global shortcuts | kglobalaccel (registered live) and `kglobalshortcutsrc` |

| Shortcut | Action |
|---|---|
| Meta+Ctrl+Alt+R | toggle |
| Meta+Ctrl+Alt+Up | brighter |
| Meta+Ctrl+Alt+Down | dimmer |

You can rebind them in System Settings › Shortcuts › Red Night.

## Use

```sh
red-night toggle
red-night on [LEVEL]          # LEVEL 1-100, red brightness; default is the last used (60 at first)
red-night off
red-night level up|down|N     # steps: 2 5 10 20 30 … 100
red-night status
red-night schedule 22:00 07:00   # systemd user timer; catches up after sleep/boot
red-night schedule off
```

## Uninstall: undo everything

```sh
./uninstall.sh
```

This restores every output's colour profile, removes the schedule timer, unregisters the
shortcuts and deletes the menu entry, the command, the generated profiles and the
settings. The checkout itself is left in place.

## Tests

```sh
tests/profile-test.py   # generates profiles, reads them back with lcms: red = x·level, green = blue = 0
tests/screen-test.sh    # REAL SCREEN, ~3 s red: fires the shortcuts and reads the hardware LUT, always reverts
tests/crtc-lut.py       # print the GAMMA_LUT the kernel is scanning out right now (modetest, no root)
```

## Limits

- A monitor plugged in while red-night is on stays normal until you toggle (or run
  `red-night on`) again.
- If a monitor is unplugged while red-night is on, KWin remembers the red profile for it.
  Run `red-night off` after plugging it back in.
- The profile survives a reboot (KWin keeps the output settings). It stays on until you
  turn it off or the schedule does.
- HDR outputs use a separate HDR ICC slot that red-night does not touch.
- KWin's nested `--virtual` backend reports outputs as "ICC incapable", so the effect can
  only be tested on a real DRM output.
