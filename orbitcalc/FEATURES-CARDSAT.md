# CardSat-style feature programs

Four planning tools inspired by features in **CardSat**
(https://github.com/prstoetzer/CardSat), ported to the calculator/handheld
platforms in this repo. Each runs on the same verified **secular-J2 mean-element
propagator** used everywhere else here (AMSAT daily-bulletin GP/OMM elements),
so they are *planning-grade*, not precise-pointing tools.

CardSat is an ESP32 (Cardputer ADV) application with WiFi, SGP4, GPS, and CAT
radio/rotator control. The features below are the parts that map cleanly onto a
calculator with no radio, no network, and a lightweight propagator. The radio
**control** half of CardSat's Doppler feature is deliberately not ported — this
is the **display** half: it shows you the numbers; it doesn't tune a rig.

## The four features

1. **Doppler display (standalone)** — live uplink/downlink Doppler shift for one
   satellite during a pass, plus range-rate, total passband walk, and a small
   Doppler S-curve. Range-rate is a 1-second finite difference of slant range.
2. **Pass-detail elevation plot** — the elevation-vs-time curve for the next (or
   current) pass, with AOS/TCA/LOS markers, max elevation, AOS azimuth, and
   duration. Complements the polar plot in SATTRACK/OSCARMAP.
3. **Sun & eclipse** — Sun azimuth/elevation for your QTH, day/twilight/night,
   and whether the satellite is sunlit or in Earth's shadow, with a sunlit/
   eclipse timeline and the next transition time. Low-precision almanac Sun;
   cylindrical-shadow eclipse test.
4. **Mutual-window finder** — enter a remote station's grid (or lat/lon) and get
   the co-visibility windows when **both** stations can see the satellite at
   once, each with duration and the peak elevation at each end.

## Files by platform

| Feature | PicoCalc (MMBasic) | Casio BASIC | Casio Python |
|---------|--------------------|-------------|--------------|
| Doppler (standalone) | `mmbasic/DOPPLER.bas` | `casio-fx9750giii/ODOPLR.txt` | `casio-fx9750giii/doppler.py` |
| Pass elevation plot  | `mmbasic/PASSPLOT.bas`| `casio-fx9750giii/OPASS.txt`  | `casio-fx9750giii/passplot.py` |
| Sun & eclipse        | `mmbasic/SUNECL.bas`  | `casio-fx9750giii/OSUN.txt`   | `casio-fx9750giii/sunecl.py` |
| Mutual-window finder | `mmbasic/MUTUAL.bas`  | `casio-fx9750giii/OMUTUAL.txt`| `casio-fx9750giii/mutual.py` |

### Casio BASIC helper sub-programs (shared)
The Casio BASIC versions reuse the existing `OSUBPT`, `OATAN2`, `OJD`, `OCAL`,
and `OLOOK` sub-programs, and add three new ones:

- **`OSUNEC`** — low-precision Sun position in ECI (used by OSUN).
- **`OSUNANG`** — Sun look angles (az/el) for the observer (used by OSUN).
- **`OECL`** — cylindrical-shadow sunlit/eclipse test (used by OSUN).

All of these keep orbital constants in **List 1** and scratch/working state in
**List 4**, and obey the hard constraint that `OSUBPT`/`OLOOK` overwrite almost
every single-letter variable — so loop counters and scratch in the callers use
only **I, J, N, S, T**, with everything else stashed in List 4. Run in **Radian**
mode.

## How the numbers were checked

Every feature's math was first written and verified in Python against the
project's golden reference (AO-7 from FM18LV), then each platform port was
checked by transcribing its exact control/variable flow and comparing to that
reference. Representative AO-7 values (now = 2026-06-22 00:00 UTC), all matched
across all three platforms within rounding:

- Doppler at 00:05 (el 27.6°, range ~2460 km, approaching at -2.43 km/s):
  **+1180 Hz** on a 145.95 MHz downlink, **+3520 Hz** on a 435.1 MHz uplink.
  The shift curve crosses zero at TCA — the correct Doppler S-curve.
- Sun at 00:00 over FM18: **el 5.5°, az 295.8°** (just before local sunset).
  AO-7 **sunlit**.
- Pass 21/06 23:59 → 22/06 00:17, **max el ~32°**.
- Mutual window FM18 ↔ CM87: **00:01–00:17**, peak el **32° / 22°**, 16 min.

## Honest caveats

- **Planning grade.** Secular-J2 mean elements + Kepler, not full SGP4. Refresh
  elements every few days; don't use for precise antenna pointing.
- **Not run on hardware.** All ports here were verified by faithful transcription
  / emulation against the reference. Nothing has been executed on a physical
  PicoCalc or fx-9750GIII. Treat the first on-device run as a shakedown:
  - **Casio Python** is MicroPython 1.9.4 with a strict, cut-down parser and
    iostream-only input. The `.py` files here are written in a conservative
    dialect (plain-decimal constants instead of `1e-6`-style literals, one
    statement per line, no chained comparisons, no `enumerate`, no f-strings) so
    they load without a bare `invalid syntax` error. Because the stock OS has no
    `getkey()` and any `input()` call hides the graphics behind the text
    console, the graphical Python programs are **single-shot**: enter the setup
    (including a time offset), the frame is drawn, and it stays up until you
    press EXIT — re-run with a different offset to step in time. They use the
    `"medium"` casioplot font on the 128×64 screen. (The Casio BASIC versions
    *do* have a live `Getkey` loop, since Casio BASIC supports key input.)
  - **Casio BASIC** text screens use `Locate`; on a 21-column screen a few
    multi-digit fields in OMUTUAL sit close together — adjust columns to taste.
  - **Interpreted = slow.** Each redraw re-runs the orbit math; expect seconds
    per step, especially in CASIO BASIC.
- **Doppler is display-only.** No CAT/radio control (CardSat's ESP32 does that
  over a serial interface this software has no equivalent for).

## Modelled on
CardSat by Paul Stoetzer, **N8HM** — https://github.com/prstoetzer/CardSat
