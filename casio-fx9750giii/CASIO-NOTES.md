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
- `oscarloc_map.py` — live graphical polar OSCARLOCATOR (casioplot, 128×64):
                 equator rim, 30°/60° lat circles, ground-track arc, live sat
                 dot, range circle, text read-out. See `OSCLMAP-README.md`.
- `doppler.py` — standalone Doppler display (shift, range-rate, tiny curve)
- `passplot.py`— pass-detail elevation plot (AOS/TCA/LOS, max El, duration)
- `sunecl.py`  — Sun az/el + satellite sunlit/eclipse with a timeline
- `mutual.py`  — co-visibility window finder for two stations (text)
- These are split because the fx-9750GIII Python editor and RAM are tight;
  keeping passes and EQX in separate files keeps each well within limits.
- Output columns are narrowed for the 21-char screen.

### Casio Python compatibility notes
The stock Casio Python is **MicroPython 1.9.4** (an old, size-optimised build
with a cut-down parser). Its parser is stricter than desktop CPython, so the
programs here are written in a conservative dialect that avoids constructs the
calculator rejects — several of which raise a bare `invalid syntax` at load
time, before the program even runs:

- **No scientific-notation float literals.** `1e-11`, `1e6`, `1.08262668e-3`
  and the like can fail to parse on this build, so all constants are written as
  plain decimals (e.g. `0.00000000001`, `1000000.0`, `0.00108262668`).
- **No semicolon-compound statements.** Each statement is on its own line; the
  `a = 1; b = 2` form is avoided.
- **No chained comparisons.** `0 <= x < 128` is written as
  `x >= 0 and x < 128`.
- **No `enumerate`** — element entry uses an explicit `for i in range(6)` over a
  names list.
- **No argument unpacking** (`jd(*EP)`) — arguments are passed explicitly.
- **No f-strings** — output uses `%` formatting.

`getkey()` is imported when available (live programs) with a fallback to `None`
so they drop to `input()`; this keeps them runnable on the calculator's
iostream-only Python and on desktop CPython. All five Python programs
(`oscarloc_map.py`, `doppler.py`, `passplot.py`, `sunecl.py`, `mutual.py`) were
re-checked after these changes and produce the same results as before.

## Casio BASIC files
Main programs:
- `OCPASS` — next 10 passes (2 screen lines per pass)
- `OCEQX`  — 10-day EQX reference-orbit table
- `OSCLOC` — OSCARLOCATOR table
- `OSCLMAP`— live graphical polar OSCARLOCATOR (127×63). See `OSCLMAP-README.md`.
- `ODOPLR` — standalone Doppler display (text read-out)
- `OPASS`  — pass-detail elevation plot (graphical)
- `OSUN`   — Sun az/el + satellite sunlit/eclipse (text)
- `OMUTUAL`— co-visibility window finder for two stations (text)

Shared sub-programs (REQUIRED — store all your main programs' listed deps):
- `OJD`    — Gregorian date/time -> Julian Date
- `OCAL`   — Julian Date -> calendar
- `OATAN2` — two-argument arctangent
- `OSUBPT` — satellite ECI/ECEF position + sub-point
- `OLOOK`  — observer look angles + range (calls OSUBPT)
- `PROJ`   — single-hemisphere projection (OSCLMAP)
- `EQXFIN` — equator-crossing finder (OSCLMAP)
- `OSUNEC` — low-precision Sun position in ECI (OSUN)
- `OSUNANG`— Sun look angles for the observer (OSUN; calls OSUNEC)
- `OECL`   — sunlit/eclipse cylindrical-shadow test (OSUN; calls OSUBPT, OSUNEC)

The feature programs (`OSCLMAP`, `ODOPLR`, `OPASS`, `OSUN`, `OMUTUAL`) keep
orbit constants in **List 1** and working state in **List 4**. Because
`OSUBPT`/`OLOOK`/`OSUNEC` overwrite almost every single-letter variable, the
callers use only **I, J, N, S, T** for loop counters/scratch and stash all other
values in List 4 — see each file's header for the exact slot map.

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
