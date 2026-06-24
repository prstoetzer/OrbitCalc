# Companion tools (MicroPython / CPython)

These standalone tools extend the OrbitCalc suite. Each runs on MicroPython
or desktop CPython with no dependencies, using the same secular-J2 core (and
AO-7 golden reference) as the rest of the repo. They are the **reference
implementations** the other-platform ports are derived from.

| File | Tool | What it does |
|------|------|--------------|
| `orbdata.py`    | **Orbital data** | Apogee/perigee, period, semi-major axis, vis-viva velocities, J2 node & perigee drift, footprint radius, ground-track shift — closed-form from one element set. |
| `gridutil.py`   | **Grid utility** | Maidenhead grid ⇄ lat/lon, plus great-circle bearing and distance. |
| `pointing.py`   | **Pointing table** | Az/El/range step table across the next pass for rotator/beam aiming, with a one-line next-pass summary. |
| `freqplan.py`   | **Doppler plan** | Per-step downlink/uplink dial frequencies across a pass (inverting transponder handled). Needs `pointing.py` alongside. |
| `elcheck.py`    | **Element checker** | Range/consistency sanity check on a freshly-typed GP set; flags transcription errors before you waste a pass. |
| `suntransit.py` | **Sun/Moon transit** | Minimum Sun-sat and Moon-sat angular separation during a pass; flags solar-transit noise and lunar spotting chances. |
| `multisat.py`   | **Multi-sat board** | Next AOS + max elevation of each of several satellites, merged and sorted soonest-first. Has a small built-in starter catalog. |

## Verified values (AO-7 from FM18LV, 2026-06-22)
- orbdata: a=7827.2 km, period 114.86 min, apogee/perigee 1458.9/1439.2 km,
  node drift +1.011°/day, perigee drift −1.908°/day, footprint 35.4°.
- gridutil: FM18LV → 38.896 N, −77.042 E; DC→SF 283°, 3921 km.
- pointing: next pass AOS 00:00 LOS 00:18 MaxEl 32°, Az 201→285→335.
- freqplan: at 00:05, downlink shift +1181 Hz on 145.95 MHz.
- suntransit: Sun el 5.5°/az 295.8°, Moon el 45.9°/az 198.3° (Moon in Virgo,
  matching ephemeris for the date).
- multisat: AO-7 up at 00:00, max el 32°.

## Run
`python3 orbdata.py` (likewise for the others). On a board/calculator, copy the
file(s) over and run from the Python prompt. `freqplan.py` imports `pointing.py`,
so keep them together.

## Accuracy & status
Planning-grade secular-J2 (not SGP4); refresh elements every few days. The Sun is
a low-precision almanac and the Moon a truncated series (good to ~1°, ample for a
proximity finder). Verified against the project reference by computation; not run
on physical hardware.

---

## Companion tools (twelve more)

These extend the suite further (see `../TOOL-IDEAS.md` for the rationale behind
each). All share the same secular-J2 core and AO-7 reference.

| File | Tool | What it does |
|------|------|--------------|
| `passcal.py`  | **Pass calendar** | Every pass over N days filtered by a minimum max-elevation (only show the workable >20deg passes). |
| `satfreq.py`  | **Frequency card** | Uplink/downlink/mode/tone/inversion reference for the common birds; pairs with freqplan. Snapshot data - verify before a pass. |
| `updown.py`   | **Live dial** | Single "set RX/TX here now" Doppler readout, stepping on keypress - a during-the-pass companion. |
| `node2me.py`  | **Node table** | Next ascending-node times and equator-crossing longitudes for paper-OSCARLOCATOR users. |
| `skedqso.py`  | **Mutual scheduler** | Next windows a satellite is visible to BOTH of two grids above a min elevation - for grid-to-grid skeds. |
| `rotor.py`    | **Rotor macro** | Az/El pass sequence as a table, CSV, or replayable macro; optional flip-mode for over-the-top az/el rotators. |
| `sunlight.py` | **Illumination** | When the satellite is sunlit vs eclipsed during a pass, and whether you're in darkness (optical-visibility). |
| `decay.py`    | **Freshness/decay** | Warns when elements are stale; flags low-perigee fast-decay; optional two-epoch dn/dt estimate. |
| `skytrack.py` | **ASCII sky chart** | Text polar plot of the pass arc with AOS/TCA/LOS marks - the no-graphics companion to the PicoCalc polar plot. |
| `window.py`   | **Horizon mask** | Recomputes effective AOS/LOS against a per-azimuth obstruction mask (trees/buildings). |
| `phase.py`    | **Sunlight/mode** | Is a sunlight-only bird (e.g. AO-7) likely active now; next illumination change; orbit-phase %. |
| `dxgrid.py`   | **Footprint grids** | Lists the Maidenhead fields currently inside the satellite footprint - "who can I work right now." |

### A few verified values (AO-7 from FM18LV, 2026-06-22)
- passcal: first qualifying pass 00:00, MaxEl 32; flags a near-overhead 88deg pass at 11:58.
- updown: at 00:05, RX 145.9512 (approaching).
- node2me: ascending nodes step -28.73deg/orbit (matches orbdata's track shift).
- skedqso: FM18LV<->CM87XX mutual 00:01-00:17, both >=22deg.
- sunlight/phase: AO-7 sunlit at 00:00, next eclipse ~01:22Z.
- dxgrid: footprint radius 35.5deg (matches orbdata 35.4deg).

### Caveats
satfreq data is a hand-maintained snapshot (reviewed 2026-06) - satellites and
frequencies change; verify against the current AMSAT list. Everything else is
planning-grade secular-J2; refresh elements every few days. Only the BBC ports
of these tools are run-tested on an interpreter; the rest are verified by
transcription against this reference.
