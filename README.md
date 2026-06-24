# OrbitCalc + SATTRACK — amateur-satellite tools for retro & embedded platforms

A dependency-free suite of amateur-satellite tracking and planning tools, written
to run on vintage and embedded computers as well as modern ones. Everything is
built on one shared orbit model — a secular-J2 mean-element propagator with a
Kepler solver, fed the same GP/OMM mean elements published in the AMSAT daily
bulletin — and every program is verified against a single golden reference so the
results agree across platforms.

The collection spans seven language/platform targets: **MicroPython**,
**Casio fx-9750GIII** (both its Python and its native BASIC), **MMBasic** on the
ClockworkPi **PicoCalc**, **BBC BASIC**, **GW-BASIC / BASICA**, and **OPL** on the
Psion **Series 5** and **Series 3c**. Two of them carry graphical applications;
the rest share a common console toolset.

For a complete, program-by-program reference — every input, output, and on-screen
control on every platform — see [`PROGRAMS.md`](PROGRAMS.md). This file is the
guided tour.

---

## What's here

At the centre are two console programs and two graphical applications, surrounded
by a set of nineteen single-purpose companion tools. All of them use the same
propagator and the same element format, so a satellite entered once behaves
identically whether you run it on a Psion organiser from the 1990s or a Raspberry
Pi Pico.

### OrbitCalc — passes & orbital data (console)

The core console program. Enter a satellite's six mean elements and epoch, set
your Maidenhead grid and a UTC clock, and it predicts upcoming passes (AOS, peak,
LOS, duration, maximum elevation, and azimuths) and prints closed-form orbital
data. It is the reference implementation of the shared model and exists on every
platform (`orbitcalc.py`, `ORBCALC.BBC`, `ORBCALC.BAS`, `ORBCALC.opl`, and the
Casio equivalents).

### OSCARLOCATOR — equator-crossing tables (console)

Produces the numbers a classic paper **OSCARLOCATOR** plotting board needs: the
first equator crossing of each UTC day — the time and the longitude — for the
loaded satellite. Northern-hemisphere stations use the ascending node and
southern stations the descending node, so the listed crossing always matches the
pass you actually track. Present on every platform as `oscarlocator.py` /
`OSCARLOC.*`.

### SATTRACK — graphical tracker (PicoCalc, MMBasic)

The flagship graphical application, for the PicoCalc's 320x320 colour screen. It
keeps a small on-device catalogue of satellites and your station, and presents a
thirteen-item menu of views and tools. In addition to the orbit math shared with the
rest of the suite, SATTRACK adds hardware- and display-oriented features the
console tools don't have:

1. **Set location / date / time** — Maidenhead grid or lat/lon, with the clock
   set either from the PicoCalc's real-time clock or by hand.
2. **Edit satellites** — add, edit, or delete up to **200** satellites, each with
   the six mean elements, an epoch, and optional downlink/uplink frequencies. The
   list scrolls for large catalogues.
3. **Load elements (TLE or JSON)** — import from the SD card, auto-detecting
   NORAD TLE/3LE text or OMM/JSON. It reads both the **AMSAT daily-bulletin.json**
   (preferring the friendly `AMSAT_NAME`) and the **Celestrak GP json-pretty**
   feed, skipping null placeholder records and handling ISO-8601 epochs. The whole
   AMSAT amateur bulletin loads in one import.
4. **Next 10 passes** of one satellite, as a list.
5. **Polar plot** of the next or current pass as a sky-track.
6. **Live track + Doppler** — an Az/El compass dial, Doppler-corrected RX/TX dial
   frequencies, range and range-rate, a sunlit/eclipse flag, and the next AOS.
7. **Next 3 passes of all satellites**, merged and sorted by time, with an
   adaptive search horizon so large catalogues stay responsive.
8. **World map** — equirectangular world map with each satellite's sub-point and
   footprint in a distinct colour, plus a shaded day/night terminator.
9. **Pass ground-track preview** — the upcoming pass drawn as a ground-track arc
   with footprints at AOS, TCA, and LOS.
10. **OSCARLOCATOR** — an interactive azimuthal-equidistant OSCARLOCATOR (see
    below).
11. **Pass watch + AOS alarm** — counts down to the soonest AOS across the whole
    catalogue, with a screen flash and speaker beep in the final minute.
12. **Pass detail** — the next pass's elevation-versus-time curve, coloured by
    sunlit/eclipse, with a Sun glyph and an AOS/TCA/LOS/max-elevation readout.
13. **Sun position** — a live sky dial of the Sun's azimuth and elevation from your
    station, plus the subsolar point, for solar-noise and daylight-pass planning.

Items 11-13 are inspired by features in CardSat, adapted to the PicoCalc and using
no external devices. They are reached with the **A**, **B**, **C** keys (or by
scrolling the menu).

### OSCARLOCATOR view & OSCARMAP — azimuthal plotting (PicoCalc, MMBasic)

The OSCARLOCATOR concept — a polar or QTH-centred azimuthal-equidistant map with
the satellite's ground-track arc, a range circle over your station, and the
footprint — appears in two places on the PicoCalc:

- **Inside SATTRACK** as menu item 0, working from SATTRACK's stored catalogue.
- **As `OSCARMAP.bas`**, a standalone program with its own element entry and a
  vector coastline, for when you want the plotting board on its own.

In both, the **polar projection is the default** and auto-selects the north or
south hemisphere from your latitude; an optional **QTH-centred** projection puts
your station at the centre with true bearings outward. The arc is one orbit's
ground track drawn from its equator crossing; stepping the clock animates the
satellite along it. This view is modelled on the interactive
[OSCARLOCATOR simulator](https://oscarlocator.n8hm.radio) and, through it, on
OrbitDeck by Paul Stoetzer, N8HM.

### CardSat-style feature programs (Casio & PicoCalc)

Several features here are inspired by [CardSat](https://github.com/prstoetzer/CardSat),
a Cardputer satellite tracker. Excluding everything that drives external hardware
(its CAT radio and antenna-rotator control), the device-independent ideas that
make sense on these platforms are implemented two ways:

- **As standalone display programs** for the Casio fx-9750GIII and the PicoCalc:
  **DOPPLER** (live uplink/downlink shift), **PASSPLOT** (pass elevation plot),
  **SUNECL** (sunlight/eclipse timeline), and **MUTUAL** (mutual-visibility window
  finder). Full write-up in [`FEATURES-CARDSAT.md`](FEATURES-CARDSAT.md).
- **Built into SATTRACK** on the PicoCalc as menu items 11-13: a **pass watch with
  AOS alarm** (countdown across all favourites with a beep and screen flash), a
  **pass-detail elevation plot coloured by sunlit/eclipse**, and a **Sun
  position** dial — mirroring CardSat's AOS alarm, pass-detail plot, and Sun
  az/el display, with no external devices.

### Companion tools (all platforms)

Nineteen focused command-line utilities, each solving one real operating problem
and each verified against the golden reference. They divide loosely into data,
pass-planning, pointing/radio, and visibility helpers:

| Tool | Purpose |
|------|---------|
| **orbdata** | Closed-form orbital data from one element set: semi-major axis, period, apogee/perigee, vis-viva velocities, J2 node & perigee drift, footprint, ground-track shift. |
| **gridutil** | Maidenhead grid to/from lat/lon, plus great-circle bearing and distance. |
| **elcheck** | Element-set sanity checker; flags transcription errors before a pass. |
| **decay** | Element-age freshness warning and low-perigee fast-decay flag. |
| **passcal** | Multi-day pass calendar filtered by a minimum maximum-elevation. |
| **pointing** | Az/El/range step table across a pass for rotators or beam aiming. |
| **rotor** | Az/El pass sequence with optional flip-mode for over-the-top rotators. |
| **freqplan** | Per-step downlink/uplink Doppler dial frequencies across a pass. |
| **updown** | Live "dial now" Doppler RX/TX readout, stepped through a pass. |
| **satfreq** | Uplink/downlink/mode/CTCSS reference card for the common birds. |
| **node2me** | Ascending/descending node times and equator-crossing longitudes. |
| **skedqso** | Mutual-visibility windows between two grids above a minimum elevation. |
| **window** | Effective AOS/LOS against a per-azimuth horizon-obstruction mask. |
| **phase** | Whether a sunlight-only bird is likely active now; next illumination change. |
| **sunlight** | Per-pass satellite sunlit/eclipsed timeline plus observer darkness. |
| **suntransit** | Minimum Sun-satellite (and Moon) separation during a pass. |
| **dxgrid** | Maidenhead fields currently inside the satellite's footprint. |
| **skytrack** | Polar sky chart of the pass arc (ASCII on consoles, graphical on PicoCalc). |
| **multisat** | Next AOS and maximum elevation of each satellite in a small catalogue. |

---

## Platforms & files

Every platform has the two core console programs (`ORBCALC` / `OSCARLOC`). The
companion-tool coverage and the graphical extras vary by what each platform can
practically support. Counts below are program files, excluding docs and data.

| Platform | Folder | Console coverage | Graphical / extras |
|---|---|---|---|
| MicroPython (desktop / MCU) | `micropython/` | both cores + all 19 tools (reference implementations) | — |
| Casio fx-9750GIII | `casio-fx9750giii/` | Python: both cores + 16 tools; native BASIC: cores + a fitted subset | DOPPLER, PASSPLOT, SUNECL, MUTUAL, OSCARLOCATOR map (`CASIO-NOTES.md`) |
| MMBasic / PicoCalc | `mmbasic/` | both cores + all 19 tools | **SATTRACK** (13-view app), **OSCARMAP**, DOPPLER, PASSPLOT, SUNECL, MUTUAL |
| BBC BASIC | `bbcbasic/` | both cores + all 19 tools — **run-tested under Matrix Brandy** | **SATTRACKG** graphical world map |
| GW-BASIC / BASICA | `gwbasic/` | both cores + all 19 tools — **run-verified under PC-BASIC** | **SATTRACK** graphical world map |
| OPL — Psion Series 5 | `opl-series5/` | both cores + all 19 tools | — |
| OPL — Psion Series 3c | `opl-series3c/` | both cores + all 19 tools (SIBO dialect: no `ASIN`) | — |

Each folder carries its own notes (`*-NOTES.md`) and, where relevant, per-program
READMEs. See [`PROGRAMS.md`](PROGRAMS.md) for the exhaustive per-platform file
names and the input/output of every program.

---

## Screenshots

Example outputs from the PicoCalc graphical programs are in `screenshots/`. These
are **renders** produced from each program's exact draw logic plus the verified
orbit math, not photographs of a device — see `screenshots/README.md` for the
caveat.

---

## Quick start

Pick the satellite's elements from the AMSAT daily bulletin (or any TLE source),
your Maidenhead grid, and a UTC time. At every input prompt on the BASIC and OPL
ports you can press **Enter** to accept the AO-7 default shown in parentheses.

### MicroPython
```
$ python orbitcalc.py        # or any tool, e.g. python passcal.py
```
Runs unchanged on desktop CPython and on MicroPython boards.

### BBC BASIC
Load and `RUN` under Matrix Brandy, BBCSDL, or a real Acorn:
```
*RUN ORBCALC
```

### GW-BASIC / BASICA / PC-BASIC
```
pcbasic --interface=none --mount=C:/work ORBCALC.BAS
```
Note the GW-BASIC convention: under `DEFDBL`, `FOR` counters must use the `%`
integer suffix, and programs avoid the core's short scratch variable names — see
`gwbasic/GW-NOTES.md`.

### OPL (Psion)
Translate the module on the device (Series 5: `ORBCALC.opl`; Series 3c uses the
SIBO dialect with an `ATAN`-based elevation in place of `ASIN`), then run it.

### SATTRACK on the PicoCalc
1. Copy `mmbasic/SATTRACK.bas` to the SD card (drive `B:`).
2. Optionally copy `sats.dat.sample` to `B:/sats.dat`, and drop a `tle.txt` or an
   OMM/JSON file on the card for menu 3 to import.
3. At the MMBasic prompt: `RUN "B:/SATTRACK.bas"`.

Full SATTRACK guide, including the on-device shakedown checklist for the RTC and
the terminator/OSCARLOCATOR redraw, is in `mmbasic/SATTRACK-README.md`.

---

## Input conventions (all platforms)

- **Elements** are the AMSAT daily-bulletin / GP mean elements: inclination,
  eccentricity, RAAN, argument of perigee, mean anomaly, mean motion (rev/day),
  and a UTC epoch.
- **Location** is a Maidenhead grid (e.g. `FM18LV`) or a lat/lon pair. The Casio
  native-BASIC grid tool takes field/square/subsquare as numbers, because that
  dialect has no character-code function.
- **Time** is UTC throughout.
- On the BASIC/OPL ports, pressing **Enter** at a prompt accepts the shown AO-7
  default, which makes it quick to retrace the verification example.

---

## Accuracy & verification

The model is a planning-grade **secular-J2 mean-element propagator** — it carries
the dominant J2 nodal and perigee drift but is not SGP4. It is excellent for
pointing, scheduling, and OSCARLOCATOR-style plotting, and you should refresh
elements every few days. The Sun position is a low-precision almanac (good to a
fraction of a degree, ample for terminators and transit checks); the Moon, where
used, is a truncated series of about a degree.

Every port is checked against one golden reference, AO-7 from grid FM18LV at
2026-06-22 00:00 UTC, covering pass times and elevations, sub-point, footprint,
Doppler, node crossings, and Sun geometry. The reference values and the script
that generates them live in [`_verify/`](_verify/).

What has been run on an interpreter versus verified by transcription:

- **BBC BASIC** is run-tested under Matrix Brandy.
- **GW-BASIC** is run-verified under PC-BASIC.
- **MicroPython** is the executable reference implementation.
- **Casio, MMBasic, and both OPL dialects** are verified by faithful
  transcription against the reference and by structural/dialect audits, because
  no interpreter for them was available in the build environment. The first run
  on real hardware is always a shakedown — see each folder's notes.

The PicoCalc graphical programs add their own verification: SATTRACK's Sun
position and Sun azimuth/elevation, Doppler, terminator, OSCARLOCATOR
projections, equator-crossing arc, and JSON/TLE import were each checked against
the reference (for example, the AO-7 ascending node reproduces 01:50 UTC at
111.6 deg W, and the Sun reaches its highest elevation due south at local solar
noon). The 200-satellite store uses length-limited name strings to stay within
PicoMite RAM.

---

## License & credits

By Paul Stoetzer, **N8HM**, for AMSAT. The OSCARLOCATOR views are modelled on the
interactive simulator at <https://oscarlocator.n8hm.radio> and on OrbitDeck; the
CardSat-style feature programs are inspired by CardSat. Element data is the public
GP/OMM data redistributed by AMSAT and Celestrak.
