# BBC BASIC (BBCSDL / Matrix Brandy / Acorn)

- Executed and verified under Matrix Brandy; matches the reference exactly.
- PI, RAD and DEG are reserved (RAD()/DEG() are built-in functions), so the
  code uses kP, kP2, kD, kR for those constants.
- Uses DEF FN / DEF PROC, WHILE/ENDWHILE, and ASN for arcsine.

## Companion tools (run-tested under Matrix Brandy)

All ten of these were executed under `tbrandy` and match the MicroPython
reference for AO-7 from FM18LV on 2026-06-22:

- `PASSCAL.BBC`  - multi-day pass calendar filtered by min max-elevation
- `SATFREQ.BBC`  - frequency/mode/tone reference card (DATA table; 2026-06 snapshot)
- `UPDOWN.BBC`   - live Doppler "dial now" readout, steps on a keypress (GET)
- `NODE2ME.BBC`  - equator-crossing (node) time/longitude table
- `SKEDQSO.BBC`  - mutual-pass scheduler for two grids
- `ROTOR.BBC`    - pass Az/El as table / CSV / replay macro, optional flip-mode
- `PHASE.BBC`    - sunlight/eclipse state, next change, sunlight-only active flag
- `WINDOW.BBC`   - horizon-mask-aware effective AOS/LOS
- `SKYTRACK.BBC` - ASCII polar sky chart of the pass (A=AOS T=TCA L=LOS)
- `DXGRID.BBC`   - Maidenhead fields currently inside the footprint

### BBC BASIC gotchas found while porting (apply to all BBC ports)
1. **Reserved-token variable prefixes break the tokenizer.** A variable named
   `ASCN` fails because BBC greedily matches the `ASC` function token and chokes
   on the trailing `N`. Avoid names starting with `ASC`, `SIN`, `COS`, `TAN`,
   `LOG`, `LEN`, `PI`, `DEG`, `RAD`, `INT`, etc. (`ASCN` -> `WANTASC`).
2. **Integer overflow on `JD*86400`.** Julian Date times 86400 is ~2.1e11, past
   the 2^31 integer range; `INT(T*86400/60)*60` overflows. Derive seconds from
   the calendar fraction (`CS` out of `PROCcal`) instead.
3. **Negative literals as `FN(...)` arguments confuse the parser** ("too many
   parameters"). Pass via variables, or inline the computation in a PROC.
4. SDL `brandy` sends PRINT to its graphics window; use the console build
   `tbrandy` for stdout. Strip the `ESC [1G` cursor codes when capturing.

## Graphical world-map tracker: SATTRACKG.BBC

A full-screen equirectangular tracker (MODE 1). Draws the graticule, equator,
observer cross, sub-satellite point (boxed cross), and footprint boundary
circle, with a VDU 5 text panel showing UTC / Lat / Lon / Az / El / Range.
Steps the clock on each keypress (GET).

- Uses ONLY MOVE/DRAW (no RECTANGLE, no CIRCLE FILL) so it runs on real Acorn
  BBC BASIC and BBCSDL. The console Brandy build (tbrandy) has NO graphics, so
  this program can't be run-tested there - the sub-point/footprint math is the
  same verified core, and a faithful mockup is in screenshots/bbc-sattrack.png.
- Footprint boundary uses a great-circle destination-point walk (PROCfppt) and
  a dateline-wrap guard (PROCdrawwrap / LASTX) to avoid a line streaking across
  the map when the circle crosses +/-180 longitude.

### World map added
SATTRACKG.BBC now draws a coarse vector coastline (6 continent outlines, 185
points) from DATA statements at line 9000+, via PROCcoast (READ/RESTORE).
Same lon/lat->pixel projection as the graticule, with the dateline-wrap guard.
The READ/DATA path was verified under tbrandy (6 strokes, 185 points, all
projecting inside the map rectangle); only the actual MOVE/DRAW needs real
graphics hardware.
