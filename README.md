# OrbitCalc + SATTRACK — amateur-satellite tools for retro & embedded platforms

Pure, dependency-free satellite tracking for vintage computers, calculators,
and microcontrollers. Everything here is built around the **AMSAT
daily-bulletin / GP mean orbital elements** and a compact **secular-J2
mean-element propagator** with a Kepler solver — small enough to type into a
1980s calculator, accurate enough for real pass planning.

> Heads-up on accuracy: this is a mean-element model with secular J2 drift on
> RAAN and argument of perigee. It is *Oscarlocator-class* — excellent for
> "where do I point the antenna and when," not a substitute for full SGP4.
> Refresh elements every few days for best results.

---

## What's here

Two console programs, ported to many dialects, plus one graphical app:

### OrbitCalc (console)
Prompts for the seven bulletin fields (INCLINATION, ECCENTRICITY,
RA_OF_ASC_NODE, ARG_OF_PERICENTER, MEAN_ANOMALY, MEAN_MOTION, EPOCH), the
current UTC time, and your location (latitude/longitude **or** Maidenhead
grid). Then it produces either:

1. **Next 10 passes** — date, AOS time, LOS time, max elevation, and azimuth
   at AOS / TCA / LOS.
2. **10-day reference-orbit (EQX) table** — the first ascending-node equatorial
   crossing of each UTC day (date, UTC time, longitude). South of the equator
   it automatically switches to the first descending-node crossing.

Longitudes print as a positive magnitude with an **E**/**W** suffix.

### OSCARLOCATOR (console)
The classic plotting-board helper. Give it one EQX longitude, the node type
(ascending/descending), the date, the EQX time, the orbital period, and the
westward longitude advance per orbit. It prints the time and longitude of
**every equatorial crossing for that UTC day**, ready to mark on an
Oscarlocator board.

### SATTRACK (graphical, PicoCalc only)
A full graphical satellite tracker for the **ClockworkPi PicoCalc** in MMBasic
(PicoMite). Menu-driven, saves to the SD card:

1. Set location, date and time (UTC)
2. Enter / edit / save up to **20** satellites (stored on SD)
3. Next 10 passes of one satellite (list)
4. Next / current pass **polar plot** of one satellite
5. Next 3 passes of **all** satellites, sorted by time
6. **World map** with your location and the **footprints** of all satellites,
   with single-step and auto-advancing animation

---

## Platforms & files

| Platform | Folder | Files |
|---|---|---|
| MicroPython (desktop / MCU) | `micropython/` | `orbitcalc.py`, `oscarlocator.py` |
| Casio fx-9750GIII (Python + Casio BASIC) | `casio-fx9750giii/` | `oc*.py`, `OC*.txt`, `OSCLOC.txt`, sub-programs, `CASIO-NOTES.md` |
| MMBasic (PicoMite / PicoCalc) | `mmbasic/` | `orbitcalc.bas`, `oscarlocator.bas`, **`SATTRACK.bas`**, `sats.dat.sample` |
| OPL — Psion Series 5 (EPOC32) | `opl-series5/` | `ORBCALC.opl`, `OSCARLOC.opl` |
| OPL — Psion Series 3c (SIBO) | `opl-series3c/` | `ORBCALC.opl`, `OSCARLOC.opl` |
| GW-BASIC / BASICA / PC-BASIC | `gwbasic/` | `ORBCALC.BAS`, `OSCARLOC.BAS` |
| BBC BASIC (BBCSDL / Brandy / Acorn) | `bbcbasic/` | `ORBCALC.BBC`, `OSCARLOC.BBC` |

See each folder's notes, and the platform sections below.

---

## Quick start

### MicroPython
```
python3 orbitcalc.py
python3 oscarlocator.py
```
Runs unchanged on CPython for testing and on most MicroPython boards. (For the
memory-constrained Casio fx-9750GIII Python mode, use the trimmed, split
versions in `casio-fx9750giii/` instead.)

### BBC BASIC
With **BBCSDL** (Windows/macOS/Linux/RISC OS) or **Matrix Brandy**:
```
brandy ORBCALC.BBC
brandy OSCARLOC.BBC
```
Note: `PI`, `RAD` and `DEG` are reserved in BBC BASIC, so internal variables
use other names. No other changes needed.

### GW-BASIC
In GW-BASIC, BASICA, or **PC-BASIC**:
```
LOAD "ORBCALC.BAS"
RUN
```
Double precision is set with `DEFDBL`. Works in PC-BASIC with
`pcbasic ORBCALC.BAS`.

### OPL (Psion)
Open the file in the **Program** editor, translate (Series 5: Ctrl+T), and run.
Module names: `ORBCALC` and `OSCARLOC`. The Series 3c versions avoid `ASIN`
(computed from `ATAN`) for maximum SIBO-ROM compatibility.

### SATTRACK on PicoCalc
1. Copy `SATTRACK.bas` to the PicoCalc SD card (drive **B:**).
2. Optionally copy `sats.dat.sample` to `B:/sats.dat` for a starter satellite
   set (AO-7, AO-27, FO-29, ISS, SO-50).
3. At the MMBasic prompt: `RUN "B:/SATTRACK.bas"` (or `LOAD` then `RUN`).
4. Navigate with the arrow keys + Enter, or press 1–6. ESC backs out / quits.

Elements you enter are saved to `B:/sats.dat`; your location/time to
`B:/loc.dat`. Both reload automatically next launch.

---

## Input conventions (all platforms)

- **Longitude**: positive = East, negative = West. OSCARLOCATOR also accepts a
  trailing `E`/`W` (e.g. `111.6W`).
- **Azimuth**: degrees clockwise from true north.
- **Elevation**: degrees above the horizon (0 = horizon, 90 = zenith).
- **Maidenhead grid**: 4 or 6 characters (e.g. `FM18` or `FM18LV`).
- **Times** are UTC throughout.
- **Elements** are taken straight from the AMSAT daily bulletin
  (`daily-bulletin.json`) or any GP/OMM source.

---

## Accuracy & verification

Every console port was checked against a common Python reference
(`_verify/ref.py`) using AO-7 for 2026-06-22 from grid FM18LV. The BBC BASIC
ports were additionally **executed** under Matrix Brandy and match to the
displayed precision. The Casio BASIC, GW-BASIC, OPL, and MMBasic ports were
verified by faithful transcription of their exact control/variable flow against
the same reference (matching AOS/LOS to the minute, max elevation and azimuths
to the degree, and EQX longitudes to 0.1°). The SATTRACK orbital core is the
same verified model.

The propagation model and its limits are described above: secular J2 only, no
drag term applied to position, spherical-Earth look angles. Expect timing good
to a few seconds for low-eccentricity LEO sats within a few days of epoch.

---

## License

MIT — see `LICENSE`.

## Credits

Orbital elements courtesy of **AMSAT** (the Radio Amateur Satellite
Corporation). MMBasic / PicoMite by Geoff Graham and Peter Mather. The
Oscarlocator concept is a long-standing AMSAT tradition.
