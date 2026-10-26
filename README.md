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
| menu entry "Red Night" (right-click for On/Off/Brighter/Dimmer) | `~/.local/share/applications/red-night.desktop` |
| **Red Night switch in the tray**: a pill in the Brightness and Color popup, under Night Light | `~/.local/share/plasma/plasmoids/rednight.brightness/` |
| the guard for that switch | `~/.config/systemd/user/plasma-plasmashell.service.d/red-night-tray.conf`, `red-night-tray.path`, `red-night-tray.service` |

There is no keyboard shortcut any more; `install.sh` removes the ones older versions set.

## The tray switch

Click the brightness icon in the system tray. Under Night Light there is a **Red Night** row
with a switch like Night Light's: it turns the filter on and off at the last level, shows
On/Off and the level, and follows changes made elsewhere (the schedule, the command).

How it is done, and why this way:

- Plasma 6 compiles the stock applet's QML into
  `/usr/lib/qt6/plugins/plasma/applets/org.kde.plasma.brightness.so` (package `powerdevil`) and
  prefers that copy, so a same-id package in `~/.local/share/plasma/plasmoids/` is ignored
  (it only "wins" when its metadata has no `Id`, and then the applet's id becomes `metadata`,
  which breaks translations, settings and the tray).
- So `red-night-tray install` builds a copy under its own id, **`rednight.brightness`**, from
  the QML inside the *installed* `.so` (read with PySide6), adds `tray/RedNightItem.qml`
  before the Theme row, keeps the stock translations, compiles it to check it, and swaps it
  into the tray in place of `org.kde.plasma.brightness` (live, through plasmashell's
  scripting interface; no restart).
- The copy uses powerdevil's private QML plugin, so it must match the installed powerdevil.
  **The guard** (`red-night-tray check`) runs before every plasmashell start (systemd drop-in)
  and a few seconds after the applet's files change (systemd path unit, i.e. after a
  `pacman -Syu`). If powerdevil changed, it rebuilds the copy from the new files and checks
  that it compiles; if that fails for any reason, it puts the stock applet back in the tray,
  removes the copy, writes the reason to `~/.local/state/red-night/tray-error` and sends a
  notification. Either way you keep the brightness slider.

```sh
red-night-tray status    # copy built from which powerdevil, what the tray shows, guard
red-night-tray remove    # back to the stock Brightness and Color, copy and guard removed
red-night-tray install   # again
```

If the popup ever shows an error instead of the sliders (for example plasmashell was
restarted by hand right after an update, so the guard had not run yet), run
`red-night-tray check` or `red-night-tray remove`.

## Use

```sh
red-night toggle
red-night on [LEVEL]          # LEVEL 1-100, red brightness; default is the last used (60 at first)
red-night off
red-night level up|down|N     # steps: 2 5 10 20 30 … 100
red-night status
red-night state               # one line for scripts: on|off LEVEL
red-night schedule 22:00 07:00   # systemd user timer; catches up after sleep/boot
red-night schedule off
```

## Uninstall: undo everything

```sh
./uninstall.sh
```

This restores every output's colour profile, puts the stock Brightness and Color back in
the tray, removes the schedule timer and the guard, and deletes the menu entry, the
command, the generated profiles and the settings. The checkout itself is left in place.

## Tests

```sh
tests/profile-test.py   # generates profiles, reads them back with lcms: red = x·level, green = blue = 0
tests/screen-test.sh    # REAL SCREEN, ~3 s red: runs on/brighter/dimmer/off and reads the hardware LUT, always reverts
tests/tray-test.py      # the tray guard, offline in temp dirs: build, swap, rebuild after an update, fall back to stock
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
