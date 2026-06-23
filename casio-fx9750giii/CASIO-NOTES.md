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

### Entry order (Python feature programs)
Each of `doppler.py`, `passplot.py`, `sunecl.py`, and `mutual.py` prompts for
**everything the prediction needs** — so they work for any satellite at any
time, not just the AO-7 defaults. Order:

1. Grid(s): one for most; `mutual.py` asks for **your grid** and the **remote
   grid**.
2. The six elements: INC, ECC, RAAN, ARGP, MA, MM (rev/day).
3. **Epoch UTC** of those elements: Yr, Mo, Dy, Hr, Mi, Sec.
4. **Now (UTC)**: Yr, Mo, Dy, Hr, Mi.
5. Program-specific extras: `doppler.py` → downlink MHz, uplink MHz, time
   offset; `passplot.py` → skip-ahead minutes; `sunecl.py` → time offset;
   `mutual.py` → minimum elevation (deg).

Press EXE at any prompt to accept the bracketed default. The epoch and "now"
fields are essential: an element set is only valid relative to its epoch, and
passes/Doppler/eclipse are all computed for the "now" you enter (plus any
offset). Earlier versions hard-coded these to AO-7 / 2026-06-22, which made the
feature programs unable to predict for other satellites or dates — that is
fixed.
- These are split because the fx-9750GIII Python editor and RAM are tight;
  keeping passes and EQX in separate files keeps each well within limits.
- Output columns are narrowed for the 21-char screen.

### Casio Python compatibility notes
The stock Casio Python is **MicroPython 1.9.4** (an old, size-optimised build
with a cut-down parser and **iostream-only input — no live key presses**). The
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

### Graphics programs: how display works on the stock calculator
The graphical Python programs (`oscarloc_map.py`, `passplot.py`, `sunecl.py`,
`doppler.py`) use the **casioplot** module. Two facts about the stock OS shape
how they must be written:

1. **`casioplot` draws to an off-screen buffer; nothing appears until
   `show_screen()` is called.** Every program ends its drawing with a single
   `show_screen()`.
2. **Stock MicroPython has only iostream input — there is no `getkey()`.** Any
   call to `input()` switches the calculator to the **text console**, which sits
   in front of the graphics and hides them. There is also no way to hide the
   graphics screen once shown; the user exits the program manually.

Because of (2), these programs cannot run a live, key-stepped animation on the
stock calculator (an earlier version tried to, which is why the graphics didn't
appear — the `input()` fallback kept throwing the screen back to the console).
They are therefore **single-shot**: answer all the setup prompts first (text
console), including a **time-offset** value, then the program draws the frame,
calls `show_screen()`, and **the graphic stays on screen until you press EXIT**.
To step the satellite/Sun/Doppler in time, re-run with a different time offset.
`draw_string` uses the `"medium"` font size, which is the reliable monochrome
size on this model. The drawable area is **128×64** pixels.

`getkey()` (true key input) and a live loop are only available under third-party
firmware such as PythonExtra; the programs here target the stock OS so they work
out of the box. All Python programs were re-checked after these changes and
still produce the same numeric results.

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
