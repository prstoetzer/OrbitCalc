# OrbitCalc & OSCARLOCATOR for Casio fx-9750GIII

Two delivery formats here:

- **MicroPython** (`.py`) — for the calculator's Python mode (PYTHON icon).
- **Casio BASIC** (`.txt`) — for PRGM mode. Type these in (or transfer via
  the USB drive / FA-124-style tools, renaming to program names without the
  `.txt`). The `'` lines are comments you can skip when keying in.

All longitudes are shown as a positive magnitude with an **E** or **W**
suffix. Elements are the AMSAT daily-bulletin fields (INCLINATION,
ECCENTRICITY, RA_OF_ASC_NODE, ARG_OF_PERICENTER, MEAN_ANOMALY, MEAN_MOTION,
EPOCH). The model is secular-J2 mean-element propagation — fine for amateur
planning; refresh elements every few days.

## MicroPython files
- `ocpass.py`  — next 10 passes (date, AOS, LOS, max El, Az AOS/TCA/LOS)
- `oceqx.py`   — 10-day reference-orbit EQX table (first asc-node crossing
                 per UTC day; descending node if your latitude is south)
- `oscloc.py`  — OSCARLOCATOR: one day's equatorial crossings from one EQX
- These are split because the fx-9750GIII Python editor and RAM are tight;
  keeping passes and EQX in separate files keeps each well within limits.
- Output columns are narrowed for the 21-char screen.

## Casio BASIC files
Main programs:
- `OCPASS` — next 10 passes (2 screen lines per pass)
- `OCEQX`  — 10-day EQX reference-orbit table
- `OSCLOC` — OSCARLOCATOR table

Shared sub-programs (REQUIRED — store all of them):
- `OJD`    — Gregorian date/time -> Julian Date
- `OCAL`   — Julian Date -> calendar
- `OATAN2` — two-argument arctangent
- `OSUBPT` — satellite ECI/ECEF position + sub-point
- `OLOOK`  — observer look angles (calls OSUBPT)

### Casio BASIC notation in the listings
- `->` is the assign/store arrow key.
- The fx-9750GIII has only single-letter variables (A–Z, r, θ), so the
  programs keep their persistent values in **list memory**:
  - `List 1` holds orbit constants (set up by the main program).
  - `List 2` (OCEQX) / `List 3` (OCPASS) hold the loop state.
  Don't clear these lists while a program is paused.
- `Locate c,r,X` prints at column c (1–21), row r (1–7).
- Run on the calculator in **Radian** mode (the programs set `Rad`).

### Entry order (BASIC)
OCPASS / OCEQX prompt for: INC, ECC, RAAN, ARGP, MA, MM, then EPOCH
(YR/MON/DAY/HR/MIN/SEC), then NOW (UTC), then your latitude (and longitude
for OCPASS). OSCLOC prompts for EQX longitude (sign: +E / −W), node
(1=ascending, 2=descending), month, day, EQX hour/min, period (min), and
advance per orbit (degrees west).
