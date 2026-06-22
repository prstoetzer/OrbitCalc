# SATTRACK — Graphical Satellite Pass Predictor for PicoCalc

MMBasic (PicoMite) application for the ClockworkPi PicoCalc (320x320 LCD).

## Install
1. Copy `SATTRACK.bas` to the SD card (drive `B:`).
2. (Optional) copy `sats.dat.sample` to `B:/sats.dat` for a starter set:
   AO-7, AO-27, FO-29, ISS, SO-50. (These elements are from June 2026 — replace
   with fresh AMSAT bulletin elements before relying on them.)
3. At the MMBasic prompt:  `RUN "B:/SATTRACK.bas"`

## Menu
1. **Set location / date / time** — Maidenhead grid or lat/lon, plus UTC clock.
   Saved to `B:/loc.dat`.
2. **Edit satellites** — add/edit/delete up to 20 sats; each is the 7 AMSAT
   bulletin fields + epoch. Saved to `B:/sats.dat`.
3. **Next 10 passes** — list for one satellite: date, AOS-LOS, max El, Az A/T/L.
4. **Polar plot** — sky-track of the next (or current) pass for one satellite,
   with AOS marker and live position dot.
5. **Next 3 passes (all sats)** — merged and sorted by AOS time, paged.
6. **World map + footprints** — equirectangular map with your location, each
   satellite's sub-point, and its coverage circle. SPACE single-steps +5 min;
   ENTER auto-advances (press any key to stop).

## Controls
Arrow Up/Down + Enter to choose, or number keys 1-6. ESC backs out or quits.
Backspace edits text fields.

## Performance notes
This is an interpreter on a microcontroller. Pass searches step at 30-second
intervals with bisection refinement, so a 10-pass search may take a few seconds.
The world map redraws all footprints each frame; auto-advance uses a ~300 ms
pause per frame so it stays responsive — fine for visualizing motion, not a
real-time display. Lowering the number of stored sats speeds up the map.

## Files written
- `B:/sats.dat` — saved satellite elements (CSV per sat).
- `B:/loc.dat`  — observer grid, lat/lon, and UTC date/time.

## Accuracy
Same secular-J2 mean-element model as the console OrbitCalc, verified against a
common reference. Good for pointing and planning; refresh elements every few
days. Footprint radius is computed from each satellite's mean altitude
(spherical Earth).
