# OSCLMAP / oscarloc_map — Live polar OSCARLOCATOR for the Casio fx-9750GIII

A live, single-hemisphere polar OSCARLOCATOR for the Casio fx-9750GIII (and the
near-identical fx-9860GIII), in **two forms**:

- **`oscarloc_map.py`** — Python mode (casioplot), 128×64 monochrome
- **`OSCLMAP.txt` + helpers** — CASIO BASIC, 127×63 graphics screen

Both draw the same thing: a single-hemisphere azimuthal-equidistant map with the
pole of your hemisphere at the centre and the **equator at the rim**. They show
the satellite's ground-track arc (computed from orbital elements and anchored at
its equator crossing), the live sub-satellite point stepping in time, and a
range circle over your QTH. **No footprint** — deliberately, to keep the tiny
screen readable.

## What's on screen
- Outer circle = the **equator** (the boundary of the board)
- Two inner circles = the **30° and 60° latitude** graticule for your hemisphere
- Cross through the centre = **meridian spokes** (0/90/180/270° longitude)
- Solid arc = the **ground track** of the current orbit, clipped at the equator
- Dotted ring = the **range circle** over your QTH (3000 km)
- Small **+** = your station; filled 3×3 block = the **live satellite**
- Right column = read-out (UTC time, sub-point lat/lon; the Python build also
  shows Az/El)

When the satellite crosses into the other hemisphere it simply leaves the disc,
exactly as it would on a real OSCARLOCATOR overlay.

## CASIO BASIC version — files & install
Type these programs into the calculator (or transfer with FA-124 / fx-Link).
You need the main program plus these sub-programs in the same calculator:

| Program  | Role |
|----------|------|
| `OSCLMAP`| main: input, live loop, drawing |
| `PROJ`   | single-hemisphere projection (lat/lon → pixel + visible flag) |
| `EQXFIN` | finds the equator crossing to anchor the ground track |
| `OSUBPT` | sub-satellite point from elements (shared with the other tools) |
| `OATAN2` | four-quadrant arctangent (shared) |
| `OJD`    | Julian Date from calendar (shared) |
| `OCAL`   | calendar from Julian Date (shared) |

Orbital constants live in **List 1**, working/loop state in **List 4** (the file
headers document every slot). Run in **Radian** mode. The program sets
`ViewWindow 0,127,0,0,62,0` so plot coordinates equal screen pixels; screen-Y is
flipped (`62-y`) so the pole is at the top.

### Controls (live screen)
The program reads `Getkey`:
- **→ (27)** step forward · **← (38)** step back
- **F1 (79)** bigger step · **F2 (69)** smaller step
- **F3-area (39)** flip hemisphere · **EXIT (47)** quit

Key codes can vary slightly by OS version; adjust the `If Z=…` lines if a key
doesn't respond as labelled.

## Python version — install
Copy `oscarloc_map.py` to the calculator's Python storage and run it from the
Python app. Enter your grid/elements at the prompts (press EXE to accept the
AO-7 defaults). Keys use `getkey()` when available, with an `input()` fallback so
it still runs on a PC emulator.

## Accuracy & limits
- Orbit model: secular-J2 mean elements + Kepler — the same verified core as the
  rest of this repo. Reference geometry for planning, not precise pointing;
  refresh elements every few days.
- **Speed:** this is an interpreter on a calculator. Each frame re-finds the
  equator crossing and redraws everything, so expect a few **seconds per step**,
  especially in CASIO BASIC. It's a planning visualiser, not a smooth animation.
- The CASIO BASIC build was verified by transcribing its exact control/variable
  flow (including the List-memory contracts and the `OSUBPT`/`PROJ`/`EQXFIN`
  subprograms) against the project's reference and rendering it; it has **not**
  been run on physical hardware. The first on-device run is a shakedown — watch
  the `Getkey` codes and the `ViewWindow`/`Text` coordinates.

## Modelled on
The OSCARLOCATOR simulator / OrbitDeck by Paul Stoetzer, N8HM
(https://oscarlocator.n8hm.radio).
