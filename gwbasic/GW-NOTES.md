# GW-BASIC / BASICA / PC-BASIC

- DEFDBL A-H,J-Z forces double precision (important for orbital math).
- Subroutines are reached by GOSUB; shared state in global variables.
- Verified by transcription against the common Python reference. To run:
  GW-BASIC/BASICA: LOAD then RUN. PC-BASIC: pcbasic ORBCALC.BAS
- Output columns are kept narrow for an 80-column screen.

## Companion tools — not yet ported

The seven companion tools (orbdata, gridutil, elcheck, pointing, freqplan,
suntransit, multisat) that ship on the other platforms are **not yet available
in GW-BASIC**. They can be back-ported: the math is identical and GW-BASIC has
everything needed (double precision via DEFDBL, ATN for atan, and the same
secular-J2 core already used in ORBCALC.BAS). The main porting work is the
two-argument atan2 and asin/acos helpers (GW-BASIC has only ATN), plus
GW-BASIC's line-numbered, GOSUB-based structure. Until then, use ORBCALC.BAS
for pass prediction and OSCARLOC.BAS for the plotting board.

## Graphical world-map tracker: SATTRACK.BAS

An equirectangular tracker in SCREEN 2 (640x200 CGA mono). Draws the graticule,
equator, observer cross, sub-satellite point (boxed cross), and footprint
boundary circle, with top/bottom LOCATE status lines (UTC / Lat / Lon, and
Az / El / Range). Steps the clock on each keypress (INPUT$).

- Reuses the ORBCALC.BAS core subroutines (SETSAT 1000, JD 1100, GMST 1200,
  KEPLER 1300, ATAN2 1400, ECI 1500, ECEF 1700, SUBPOINT 1800, LOOK 1900,
  MAIDEN 2700, CAL 2900). Adds DEF FNAS/FNAC for asin/acos via ATN.
- Tokenizes cleanly under PC-BASIC (`pcbasic --convert=A SATTRACK.BAS`).
  Graphics need a display to capture; a faithful mockup is in
  screenshots/gw-sattrack.png. Sub-point/footprint math verified against the
  AO-7 reference (12.99,-86.70, footprint 35.5 deg; sub-point pixel ~170,88).
- The companion console tools (passcal, satfreq, etc.) are not yet ported to
  GW-BASIC; this graphical tracker and ORBCALC/OSCARMAP are the GW-BASIC set.

### World map added
SATTRACK.BAS now draws a coarse vector coastline (6 continent outlines, 185
points) from DATA at line 6000+, via the 5250 COASTLINE subroutine
(READ/RESTORE 6000). Same projection as the graticule; tokenizes cleanly under
PC-BASIC with the data included.

## GW-BASIC gotchas found while porting the console tools (verified under PC-BASIC)

1. **`DEFDBL A-H,J-Z` + a FOR loop counter in that range HANGS PC-BASIC.**
   `FOR KK=1 TO 50` froze the interpreter because `KK` became double-precision.
   The fix is an integer counter: `FOR KK%=1 TO 50 ... NEXT KK%`. This silently
   hung KEPLER (so every orbit calc froze) and also the graphical SATTRACK.BAS.
   All FOR counters in the suite now use the `%` suffix.
2. **Shared-core line-number ranges.** The CAL routine occupies 2900-3004, so a
   new subroutine must start at 3100+ (FindPass was moved off 3000). CAL also
   reuses the short name `DY` as a day-fraction temp, so the calling program must
   not use `DY` for its own data ("days ahead" was renamed `DZ`).
3. **Read CAL outputs immediately.** CAL clobbers many short scratch names; copy
   CD/CO/CH/CN into your own variables right after each `GOSUB 2900` before the
   next call.

### Verified test path (headless PC-BASIC)
`pcbasic --interface=none --mount=C:/tmp PROG.BAS` then write results with
`OPEN "O",1,"OUT.TXT" ... CLOSE 1 : SYSTEM` (file lands in the mounted /tmp), or
capture the screen with `--output=/tmp/scr.txt`. PASSCAL.BAS was run this way and
reproduced the AO-7 reference passes (00:00 El32, 11:58 El88, 13:52 El21).

## Console companion tools (12) - all run-verified under PC-BASIC

PASSCAL, SATFREQ, UPDOWN, NODE2ME, SKEDQSO, ROTOR, PHASE, WINDOW, DECAY,
SKYTRACK, DXGRID. Each was executed under PC-BASIC (headless, mounted output)
and reproduced the AO-7 reference:

- PASSCAL: 00:00 El32, 11:58 El88, 13:52 El21
- UPDOWN:  00:05 RX 145.9512 TX 435.0965
- NODE2ME: 01:50 -111.56, 03:45 -140.29
- SKEDQSO: FM18LV<->CM87XX 00:01-00:17 El22
- ROTOR:   TCA Az262 El32
- WINDOW:  geo 00:00-00:18, eff (20deg S wall) 00:02-00:17
- PHASE:   sunlit, next change ~01:22Z, phase 70%
- DECAY:   age 1.68d, mean alt 1449, peri 1439
- DXGRID:  sub 12.99,-86.71, foot 35.4, 29 fields
- SKYTRACK: ASCII polar chart, MaxEl 32, A/T/L marks placed correctly
- SATFREQ: SO-50 145.85/436.795 67.0Hz, AO-7-B inverting

### CRITICAL gotcha - main programs must avoid the core's scratch variable names
The shared core (1000-3004) writes ~90 short variables internally (DT, SS, E2,
AA, BB, RR, MM, MK, EE, XO, YO, VX...). Any GOSUB into the core clobbers them, so
a calling program must NOT keep its own data in those names across a core call.
The classic failures found: UPDOWN's finite-diff delta named DT (ECI uses DT for
seconds-since-epoch) gave nonsense ranges; SKEDQSO's step named SS (LOOK uses SS
for the topocentric south component) made the time jump past the window in one
step. Fix: these tools use a Q-prefixed safe-name convention (QS step,
Q1/Q2 elevations, QA/QB bisect, QM max-el, etc.) for all persistent main vars.
On real GW-BASIC/BASICA also remember names are significant to 2 chars, so keep
distinct variables distinct in their first two characters.
