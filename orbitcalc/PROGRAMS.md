# PROGRAMS — complete reference

Every program in this repository, what it does, what it asks for, what it shows,
and how to run it. All of them are built on one shared **secular-J2 mean-element
propagator** (see [Orbit model](#orbit-model-shared-by-everything) at the end),
take AMSAT daily-bulletin GP/OMM elements, and work entirely offline.

Programs fall into six functional groups:

1. [OrbitCalc — passes & EQX table](#1-orbitcalc--passes--eqx-table) (console, every platform)
2. [OSCARLOCATOR — crossing table](#2-oscarlocator--crossing-table) (console, every platform)
3. [SATTRACK — graphical tracker](#3-sattrack--graphical-tracker) (PicoCalc)
4. [OSCARMAP / OSCLMAP / oscarloc_map — live polar map](#4-live-polar-oscarlocator-map) (PicoCalc + Casio)
5. [CardSat-style feature programs](#5-cardsat-style-feature-programs) (all platforms)
6. [Shared Casio BASIC sub-programs](#6-shared-casio-basic-sub-programs)

A quick map of which platform has which program is in the
[Platform matrix](#platform-matrix) near the bottom.

---

## 1. OrbitCalc — passes & EQX table

**The core console tool.** Prompts for the satellite's elements, the current UTC
time, and your location, then offers two outputs.

**Files**

| Platform | File(s) | Notes |
|---|---|---|
| MicroPython | `micropython/orbitcalc.py` | passes + EQX in one program |
| Casio Python | `casio-fx9750giii/ocpass.py`, `oceqx.py` | split (RAM/editor limits) |
| Casio BASIC | `casio-fx9750giii/OCPASS.txt`, `OCEQX.txt` | split |
| MMBasic | `mmbasic/orbitcalc.bas` | passes + EQX |
| OPL (S5/S3c) | `opl-series5/ORBCALC.opl`, `opl-series3c/ORBCALC.opl` | |
| GW-BASIC | `gwbasic/ORBCALC.BAS` | |
| BBC BASIC | `bbcbasic/ORBCALC.BBC` | executed & verified under Brandy |

**Inputs (in order):** INCLINATION, ECCENTRICITY, RA_OF_ASC_NODE,
ARG_OF_PERICENTER, MEAN_ANOMALY, MEAN_MOTION (rev/day), EPOCH
(year/month/day/hour/min/sec UTC); then NOW (UTC); then your location as
latitude/longitude **or** a Maidenhead grid. Longitude is +E / −W.

**Output 1 — Next 10 passes:** one row per pass with date, AOS time, LOS time,
maximum elevation, and the azimuth at AOS / TCA / LOS. AOS/LOS are found by
30-second scanning + bisection; max elevation by a ternary search.

**Output 2 — 10-day reference-orbit (EQX) table:** the first ascending-node
equatorial crossing of each UTC day (date, UTC time, sub-satellite longitude).
If your latitude is south, it switches to the first descending-node crossing
automatically. This table is what you transcribe onto an OSCARLOCATOR board.

**Run:**
- MicroPython / CPython: `python3 orbitcalc.py`
- Casio: enter `OCPASS`/`OCEQX` (BASIC) or run `ocpass.py`/`oceqx.py` (Python)
- BBC BASIC: `brandy ORBCALC.BBC`
- GW-BASIC: `LOAD "ORBCALC.BAS"` then `RUN`
- OPL: open in the Program editor, translate, run

---

## 2. OSCARLOCATOR — crossing table

The classic plotting-board helper. Given **one** equator crossing, it prints
**every** equatorial crossing for that whole UTC day, ready to mark on an
OSCARLOCATOR overlay. No element set needed — just the EQX data.

**Files**

| Platform | File |
|---|---|
| MicroPython | `micropython/oscarlocator.py` |
| Casio Python | `casio-fx9750giii/oscloc.py` |
| Casio BASIC | `casio-fx9750giii/OSCLOC.txt` |
| MMBasic | `mmbasic/oscarlocator.bas` |
| OPL (S5/S3c) | `opl-series5/OSCARLOC.opl`, `opl-series3c/OSCARLOC.opl` |
| GW-BASIC | `gwbasic/OSCARLOC.BAS` |
| BBC BASIC | `bbcbasic/OSCARLOC.BBC` |

**Inputs:** EQX longitude (+E / −W; also accepts a trailing `E`/`W` like
`111.6W`), node type (1 = ascending, 2 = descending), date (month/day), EQX time
(hour/min UTC), orbital period (minutes), and the westward longitude advance per
orbit (degrees). Period and advance both come straight from the OrbitCalc EQX
output or any bulletin.

**Output:** a table of the time and longitude of each equator crossing through
the day, each one earlier-orbit-time plus the period, each longitude shifted west
by the per-orbit advance.

---

## 3. SATTRACK — graphical tracker

**PicoCalc only (MMBasic / PicoMite).** A full menu-driven tracker that persists
to the SD card. File: `mmbasic/SATTRACK.bas`. Full guide:
`mmbasic/SATTRACK-README.md`.

**Menu:**
1. **Set location, date & time (UTC)** — saved to `B:/loc.dat`.
2. **Edit / save satellites** — up to **20**, stored on `B:/sats.dat`.
3. **Next 10 passes** of one satellite (text list).
4. **Polar plot** of the next / current pass of one satellite (sky dial with the
   ground track across the sky, AOS/LOS markers, direction of travel).
5. **Next 3 passes of all satellites**, merged and sorted by time.
6. **World map** (equirectangular) with your location and the live **footprints**
   of all satellites, single-step or auto-advancing.

**Install:** copy `SATTRACK.bas` to SD (drive **B:**); optionally copy
`sats.dat.sample` to `B:/sats.dat` for a starter set (AO-7, AO-27, FO-29, ISS,
SO-50). At the MMBasic prompt: `RUN "B:/SATTRACK.bas"`. Navigate with arrow
keys + Enter or number keys 1–6; ESC backs out / quits. Your elements and
location reload automatically next launch.

---

## 4. Live polar OSCARLOCATOR map

A live, single-hemisphere azimuthal-equidistant map: the pole of your hemisphere
at the centre, the **equator at the rim**, the satellite's ground-track arc
(anchored at its equator crossing), and the live sub-satellite point stepping in
time. Three implementations:

### 4a. OSCARMAP (PicoCalc, MMBasic)
File: `mmbasic/OSCARMAP.bas`; guide: `mmbasic/OSCARMAP-README.md`. The richest
version: embedded Natural-Earth vector **coastlines**, lat/lon graticule, the
ground-track arc, the live sub-point, the satellite **footprint**, a range
circle, and live Az/El/range read-outs. Coastline data is in
`mmbasic/coastdata.inc`. Controls: SPACE step, F auto-advance (and increase
step), S stop auto, B back, R re-pin "now", H flip hemisphere, ESC quit.

### 4b. oscarloc_map.py (Casio fx-9750GIII, Python)
File: `casio-fx9750giii/oscarloc_map.py`. The 128×64 monochrome version:
equator rim, 30°/60° lat circles, meridian spokes, ground-track arc, live
sat block, range circle, and a text read-out (UTC, sub-point, Az/El). No
footprint (screen is too small to read it). Guide:
`casio-fx9750giii/OSCLMAP-README.md`.

### 4c. OSCLMAP (Casio fx-9750GIII, CASIO BASIC)
File: `casio-fx9750giii/OSCLMAP.txt` plus sub-programs `PROJ.txt`,
`EQXFIN.txt`, and the shared `OSUBPT`/`OATAN2`/`OJD`/`OCAL`. Same picture as
4b in native calculator graphics on the 127×63 screen. Uses **List 1** for
orbit constants and **List 4** for drawing/loop state. Run in Radian mode.

All three share the same projection, equator-rim clipping, and equator-anchored
track. See `OSCLMAP-README.md` for the two Casio builds together.

---

## 5. CardSat-style feature programs

Four planning tools inspired by [CardSat](https://github.com/prstoetzer/CardSat),
each implemented on all three programmable platforms. Overview and verification:
`FEATURES-CARDSAT.md`. These are **display/planning** tools — none control a
radio or rotator.

### 5a. Doppler display (standalone)
Live uplink/downlink Doppler shift for one satellite, plus range-rate, total
passband walk, and a small Doppler S-curve. Range-rate is a 1-second
finite-difference of slant range; shift = −f · (ṙ/c).

| Platform | File | Form |
|---|---|---|
| PicoCalc | `mmbasic/DOPPLER.bas` | graphical: bars + Doppler curve |
| Casio Python | `casio-fx9750giii/doppler.py` | compact read-out + tiny curve |
| Casio BASIC | `casio-fx9750giii/ODOPLR.txt` | text read-out |

**Inputs:** grid; the six elements; epoch; now; downlink MHz; uplink MHz.
**Shows:** El/Az/range, range-rate (km/s, with approaching/receding), the
downlink and uplink shift in Hz and the corrected tune frequency, total passband
walk, and a shift-vs-time curve that crosses zero at TCA.
**Controls (live):** step forward/back, faster/slower step, re-pin "now", quit.

### 5b. Pass-detail elevation plot
Elevation-vs-time curve for the next (or current) pass, with AOS/TCA/LOS markers,
max elevation, AOS azimuth, and duration. Complements the SATTRACK/OSCARMAP polar
view with a Cartesian one.

| Platform | File | Form |
|---|---|---|
| PicoCalc | `mmbasic/PASSPLOT.bas` | graphical curve + read-outs |
| Casio Python | `casio-fx9750giii/passplot.py` | graphical curve (128×64) |
| Casio BASIC | `casio-fx9750giii/OPASS.txt` | graphical curve (127×63) |

**Inputs:** grid; elements; epoch; now. **Shows:** the elevation arc with 30/60/90°
gridlines, a TCA marker, and AOS/TCA/LOS times, max elevation, and duration.

### 5c. Sun & eclipse
Sun azimuth/elevation for your QTH, day/twilight/night, and whether the satellite
is sunlit or in Earth's shadow, with a sunlit/eclipse timeline for the next ~100
minutes and the next transition time. Low-precision almanac Sun; cylindrical
shadow test.

| Platform | File | Form |
|---|---|---|
| PicoCalc | `mmbasic/SUNECL.bas` | graphical: timeline bar + sky dial |
| Casio Python | `casio-fx9750giii/sunecl.py` | read-out + timeline bar |
| Casio BASIC | `casio-fx9750giii/OSUN.txt` | text read-out |

Casio BASIC adds three sub-programs: `OSUNEC` (Sun position, ECI), `OSUNANG`
(Sun az/el for the observer), `OECL` (sunlit/eclipse test).
**Inputs:** grid; elements; epoch; now. **Shows:** Sun El/Az, day/twilight/night,
SUNLIT vs ECLIPSE, the timeline, and the next transition time.

### 5d. Mutual-window finder
Enter a remote station's grid (or lat/lon) and get the co-visibility windows when
**both** stations can see the satellite at once, each with duration and the peak
elevation at each end. Text output on every platform (a window table isn't
inherently graphical).

| Platform | File |
|---|---|
| PicoCalc | `mmbasic/MUTUAL.bas` |
| Casio Python | `casio-fx9750giii/mutual.py` |
| Casio BASIC | `casio-fx9750giii/OMUTUAL.txt` |

**Inputs:** your grid; remote grid; elements; epoch; now; minimum elevation.
**Shows:** a table of windows — date, AOS–LOS, peak elevation at each end,
duration — scanning the next 4 days.

---

## 6. Shared Casio BASIC sub-programs

The Casio BASIC programs are split into a main program plus reusable
sub-programs, because the fx-9750GIII has only single-letter variables (A–Z, r,
θ) and limited program size. **Store every sub-program a main program lists as
required.** Orbit constants live in **List 1**; per-program loop/scratch state in
**List 2/3/4** (each file's header documents its slots). Run in **Radian** mode.

| Sub-program | Contract | Used by |
|---|---|---|
| `OJD`     | Y,M,D,H,N,S → J (Julian Date) | all |
| `OCAL`    | J → Y,M,D,H,N (calendar) | all |
| `OATAN2`  | V,W → A = atan2(V,W) | all |
| `OSUBPT`  | T(JD) → P=lat, Q=lon, X,Y,Z=ECEF | all tracking |
| `OLOOK`   | T(JD) → P=el, Q=az, R=range (calls OSUBPT) | passes, Doppler, mutual |
| `PROJ`    | List4[31]=lat,[32]=lon → [33]=px,[34]=py,[35]=vis | OSCLMAP |
| `EQXFIN`  | T(ref JD) → List4[50]=eqx JD | OSCLMAP |
| `OSUNEC`  | T(JD) → List4[80..82]=Sun ECI (km) | OSUN |
| `OSUNANG` | T(JD) → List4[93]=Sun el,[94]=Sun az (calls OSUNEC) | OSUN |
| `OECL`    | T(JD) → List4[95]=1 sunlit / 0 eclipse (calls OSUBPT, OSUNEC) | OSUN |

**Critical constraint:** `OSUBPT`/`OLOOK`/`OSUNEC` overwrite almost every
single-letter variable. In any caller that loops around them, use **only I, J,
N, S, T** for loop counters and scratch, and keep everything else in List memory.
The list headers in each file spell out exactly which slots are inputs vs.
outputs.

---

## Platform matrix

| Program / feature | MicroPy | Casio Py | Casio BASIC | MMBasic | OPL | GW-BASIC | BBC |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| OrbitCalc (passes + EQX) | ● | ● | ● | ● | ● | ● | ● |
| OSCARLOCATOR (table) | ● | ● | ● | ● | ● | ● | ● |
| SATTRACK (tracker) | | | | ● | | | |
| Live polar map | | ● | ● | ● | | | |
| Doppler display | | ● | ● | ● | | | |
| Pass elevation plot | | ● | ● | ● | | | |
| Sun & eclipse | | ● | ● | ● | | | |
| Mutual-window finder | | ● | ● | ● | | | |

(MicroPython runs the console tools on desktop CPython and most MCU boards; the
Casio Python column is the trimmed/split fx-9750GIII build. The graphical and
feature programs target the platforms with a usable display: PicoCalc via MMBasic
and the fx-9750GIII via both its languages.)

---

## Orbit model (shared by everything)

A compact **secular-J2 mean-element propagator** with a Kepler solver:

- Elements are AMSAT bulletin GP/OMM mean elements (INC, ECC, RAAN, ARGP, MA, MM,
  EPOCH).
- Mean motion gives the semi-major axis `a = (μ/n²)^⅓`; Kepler's equation is
  solved by Newton iteration; true anomaly + argument of perigee give the
  in-plane position, rotated by inclination and RAAN to ECI.
- Secular J2 drift is applied to RAAN and argument of perigee:
  `RAAṄ = −f·cos i`, `ARGṖ = f·(2 − 2.5·sin²i)`, with
  `f = 1.5·J2·(Rₑ/p)²·n`.
- GMST rotates ECI → ECEF for sub-point and look angles; look angles use a
  spherical Earth.
- Doppler uses a 1-second finite-difference range-rate; the Sun uses a
  low-precision almanac series; eclipse is a cylindrical-shadow test.

**Accuracy:** this is *OSCARLOCATOR-class* — excellent for "where do I point the
antenna and when," good to a few seconds of timing and a degree or so of angle
for low-eccentricity LEO within a few days of epoch. It is **not** full SGP4 and
applies no drag to position. **Refresh elements every few days.**

**Verification:** all ports are checked against a common Python reference
(`_verify/ref.py`, AO-7 from FM18LV on 2026-06-22; see `_verify/REFERENCE.md`).
The BBC BASIC ports were additionally **executed** under Matrix Brandy. Every
other port — Casio (both languages), GW-BASIC, OPL, MMBasic — was verified by
faithfully transcribing its exact control/variable flow and comparing to the
reference. **Nothing here has been run on the physical PicoCalc or fx-9750GIII**;
the screenshots are renders from each program's real draw logic, not device
captures. Treat the first on-device run as a shakedown.
