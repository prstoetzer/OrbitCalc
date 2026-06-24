# OPL on the Psion Series 5 (EPOC32)

- Open the file in the Program editor, press Ctrl+T to translate, then run.
- Module names: ORBCALC and OSCARLOC.
- Uses floating-point throughout; angles in radians internally.
- Series 5 OPL provides ASIN/ACOS/ATAN, GEN$, FIX$, UPPER$, VAL — all used here.
- INT() truncates toward zero; this only affects the mean-anomaly reduction,
  which the Kepler solver tolerates.

## Companion tools (new)

Seven console tools sharing the same secular-J2 core, verified against the
AO-7 golden reference:

- **ORBDATA.opl** — orbital data from GP elements (apogee/perigee, period,
  velocities, J2 node/perigee drift, footprint, track shift). No propagation.
- **GRIDUTIL.opl** — Maidenhead grid <-> lat/lon, bearing & distance.
- **ELCHECK.opl** — element-set sanity checker; flags transcription errors.
- **POINTING.opl** — Az/El/range step table for the next pass.
- **FREQPLAN.opl** — per-step downlink/uplink Doppler dial frequencies
  (inverting transponder handled).
- **SUNTRAN.opl** — minimum Sun-sat and Moon-sat separation during a pass.
- **MULTISAT.opl** — next AOS + max elevation of each satellite in a small
  built-in catalog, sorted soonest-first.

Each is a separate module: type it into the Program editor and Translate
(Ctrl+T on Series 5 (EPOC32)). Enter the full element set, epoch, and current time so
any satellite at any date works.

Note for Series 5 (EPOC32): this build has no ASIN; the elevation is computed as
ATAN(s / SQR(1 - s*s)) inside look:. The math is otherwise identical to the
Series 5 version.

## Companion tools (11 modules)

PASSCAL, SATFREQ, UPDOWN, NODE2ME, SKEDQSO, ROTOR, PHASE, WINDOW, DECAY,
SKYTRACK, DXGRID - each a standalone OPL module sharing the same secular-J2
core procs (setsat:/jd:/look:/findpass:/cal:/maiden:/subpt: ...). Verified by
faithful transcription against the AO-7 reference and structural balance
(PROC/ENDP, IF/ENDIF, WHILE/ENDWH); there is no OPL interpreter in the build
environment, so these are not run-tested on emulated hardware.

- SATFREQ is a self-contained data card (parallel arrays; 2026-06 snapshot).
- DECAY is self-contained (its own jd:).
- SKYTRACK is an ASCII polar sky chart (41x21 character grid) so it works on
  both Series 5 and Series 3c without graphics-call differences.
- PHASE adds sun:/sunlit: (cylindrical-shadow eclipse test); DXGRID adds
  acoss:/gcdeg: (great-circle footprint test).
