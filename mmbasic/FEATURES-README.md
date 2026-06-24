# DOPPLER / PASSPLOT / SUNECL / MUTUAL — PicoCalc feature programs

Four standalone MMBasic programs for the ClockworkPi **PicoCalc** (PicoMite),
inspired by features in [CardSat](https://github.com/prstoetzer/CardSat). They
all run on the same secular-J2 orbit core as the rest of this repo, are fully
offline, and are **planning/display tools** — none control a radio or rotator.
Full cross-platform write-up: `../FEATURES-CARDSAT.md`. Per-program reference:
`../PROGRAMS.md` §5.

These are 320×320 colour programs. Each is self-contained (its own copy of the
orbit core), so you can copy just the one you want to the SD card and
`RUN "B:/DOPPLER.bas"` (or whichever). At every input prompt, press **Enter** to
accept the AO-7 default shown in parentheses.

## DOPPLER.bas — standalone Doppler display
Live uplink/downlink Doppler shift for one satellite during a pass.

- **Asks for:** grid; the six elements (INC, ECC, RAAN, ARGP, MA, MM); epoch UTC;
  now UTC; downlink MHz; uplink MHz.
- **Shows:** UTC + time offset; El/Az/range; range-rate in km/s with an
  approaching/receding flag; for both the downlink and uplink — the shift in Hz
  and the corrected "tune" frequency; the total passband walk (|down|+|up|); and
  a Doppler-shift-vs-time curve for ±15 min that crosses zero at TCA.
- **Keys:** SPACE step +0.5 min · F step +2 min · B back · R re-pin "now" · ESC.
- **Maths:** range-rate is a 1-second finite difference of slant range; the
  shift is −f·(ṙ/c). Positive shift = approaching.

## PASSPLOT.bas — pass-detail elevation plot
The elevation-vs-time curve for the next (or current) pass.

- **Asks for:** grid; the six elements; epoch UTC; now UTC.
- **Shows:** the elevation arc with 30/60/90° gridlines, a TCA marker line, and
  read-outs for AOS time + azimuth, TCA time + max elevation, LOS time, and
  duration.
- **Finds the pass by:** 30-second scan to AOS, bisection to refine AOS, scan to
  LOS, ternary search for TCA. If no pass occurs within 14 days it says so.

## SUNECL.bas — Sun & eclipse
Sun position for your QTH and the satellite's illumination state.

- **Asks for:** grid; the six elements; epoch UTC; now UTC.
- **Shows:** Sun El/Az; day / twilight / night; whether the satellite is SUNLIT
  or IN ECLIPSE (with a glyph); a sunlit/eclipse timeline bar for the next ~100
  minutes; the next sunlit↔eclipse transition time; and a small sky dial plotting
  the Sun's position over your QTH.
- **Keys:** SPACE step +1 min · F step +10 min · B back · R re-pin "now" · ESC.
- **Maths:** low-precision almanac Sun position; a cylindrical-shadow test in ECI
  decides sunlit vs. eclipse (lit if the satellite is on the sunward side, or its
  distance from the Earth–Sun axis exceeds Earth's radius).

## MUTUAL.bas — mutual-window finder
Co-visibility windows for two ground stations.

- **Asks for:** your grid; a remote grid; the six elements; epoch UTC; now UTC;
  minimum elevation (degrees).
- **Shows:** a table of windows over the next 4 days — date, AOS–LOS, the peak
  elevation at each end (pkA / pkB), and the duration in minutes — for the times
  when **both** stations have the satellite above the minimum elevation at once.

## Companion tools (new)

These seven console tools share the same secular-J2 core and were verified
against the AO-7 golden reference:

- **ORBDATA.bas** — orbital data from GP elements (apogee/perigee, period,
  velocities, J2 node/perigee drift, footprint, ground-track shift). No
  propagation.
- **GRIDUTIL.bas** — Maidenhead grid <-> lat/lon, plus bearing & distance.
- **ELCHECK.bas** — element-set sanity checker; flags transcription errors.
- **POINTING.bas** — Az/El/range step table for the next pass (rotator/beam
  aiming) with an AOS/LOS/MaxEl summary.
- **FREQPLAN.bas** — per-step downlink/uplink Doppler dial frequencies for a
  pass (inverting transponder handled).
- **SUNTRAN.bas** — minimum Sun-sat and Moon-sat angular separation during a
  pass; flags solar-transit noise and lunar proximity.
- **MULTISAT.bas** — next AOS + max elevation of each satellite in a small
  built-in catalog, sorted soonest-first.

Each prompts for the full element set, epoch, and current time, so it works
for any satellite at any date.

## Accuracy & status
Secular-J2 mean elements (not SGP4); refresh elements every few days. The orbit
math, Doppler, Sun, and eclipse computations were verified against the project's
golden reference (AO-7 from FM18LV). **Not yet run on a physical PicoCalc** — the
screenshots are renders from the programs' real draw logic, so treat the first
on-device run as a shakedown.

## Companion tools (12)

All share the POINTING.bas secular-J2 core (LoadSat / Look / FindPass / Cal /
Maiden / FNjd ...) and are verified against the AO-7 reference.

| File | Tool |
|------|------|
| `PASSCAL.bas`  | Multi-day pass calendar, min max-elevation filter |
| `SATFREQ.bas`  | Frequency/mode/tone reference card (DATA table; 2026-06 snapshot) |
| `UPDOWN.bas`   | Live Doppler "dial now" RX/TX readout |
| `NODE2ME.bas`  | Equator-crossing (node) time/longitude table |
| `SKEDQSO.bas`  | Mutual-pass scheduler for two grids |
| `ROTOR.bas`    | Pass Az/El table, optional flip-mode |
| `PHASE.bas`    | Sunlight/eclipse state, next change, sunlight-only flag |
| `WINDOW.bas`   | Horizon-mask-aware effective AOS/LOS |
| `DECAY.bas`    | Element freshness warning + low-perigee decay flag |
| `SKYTRACK.bas` | **Graphical** polar sky chart of the pass (PicoCalc LCD) |
| `DXGRID.bas`   | Maidenhead fields inside the footprint |

Notes: all use OPTION EXPLICIT / OPTION DEFAULT FLOAT with the same DIM-at-top
discipline as the rest of the suite. SKYTRACK is graphical (MM.HRES/CIRCLE/LINE/TEXT);
the rest write a text table to the console. SATFREQ data is a hand-maintained
snapshot - verify against the current AMSAT list. Verified by faithful
transcription against the reference (no MMBasic interpreter in the build
environment); structural balance (SUB/FUNCTION/IF/FOR/DO) audited.
