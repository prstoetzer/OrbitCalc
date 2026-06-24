# Tool ideas — amateur-satellite utilities to build next

> **STATUS (all built).** Every tool below has been implemented across the
> platforms. The companion tools (passcal, satfreq, updown, node2me, skedqso,
> rotor, sunlight/phase, decay, window, skytrack, dxgrid, and the rest) ship in
> MicroPython, BBC BASIC (run-tested), GW-BASIC (run-verified), MMBasic, and both
> Psion OPL dialects; Casio gets the subset that fits the platform. The two
> trackers (BBC `SATTRACKG`, GW-BASIC `SATTRACK`, PicoCalc `SATTRACK`) are also
> done. See `PROGRAMS.md` → "Companion tools" for the shipped list.
> This file is kept as the original design rationale.

A brainstorm of candidate tools for the OrbitCalc suite, all buildable on the
existing dependency-free secular-J2 core and portable to every platform
(MicroPython, MMBasic/PicoCalc, BBC BASIC, Casio, Psion OPL, GW-BASIC). Ranked
loosely by usefulness-to-effort. Each notes what it needs beyond the current
core and any platform caveats.

The design rules that keep these portable: integer/float math only, no
dependencies, prompt-driven I/O, the shared Kepler + secular-J2 propagator, and
honest "planning-grade" accuracy (refresh elements every few days; not SGP4).

---

## Tier 1 — high value, low effort (build these first)

### 1. PASSCAL — multi-day pass calendar with elevation filter
A week-at-a-glance table: every workable pass of one satellite (or the built-in
catalog) over the next N days, **filtered by a minimum max-elevation** the user
sets (e.g. only show passes above 20°, the rule-of-thumb threshold for completing
FM contacts). Columns: date, AOS, LOS, max-El, max-El azimuth, duration.
- Core: already have pass-finding (`pointing`/`multisat`). Just loop over days
  and apply an elevation gate.
- Why: operators plan their day around the few high passes; the current tools
  show one pass or one "next" per sat. This is the planning view people actually
  use.
- Caveat: on tiny screens, page the table (the Casio/OPL pattern we already use).

### 2. SATFREQ — satellite frequency & mode reference card
A lookup of uplink/downlink frequencies, mode (FM / SSB-CW linear / APRS / SSTV),
transponder inversion, CTCSS tone, and OSCAR designation for the common birds
(AO-7, AO-91, SO-50, ISS, FO-29, RS-44, TEVEL, QO-100…). Feeds straight into
`freqplan` (which currently asks the user to type frequencies).
- Core: none — it's a static data table plus a search prompt.
- Why: newcomers constantly look these up; pairing it with the Doppler planner
  removes the most error-prone manual input. SO-50's 67 Hz tone, the 74.4 Hz
  arming tone, FM vs inverting-linear — all easy to fat-finger.
- Caveat: data goes stale as birds come and go; ship it as an editable table and
  date-stamp it. On Casio BASIC, store as numeric arrays (no string tables).

### 3. UPDOWN — live Doppler "dial now" single-readout
Strip `freqplan` down to one screen: given the current UTC second, show the
**downlink dial to set right now** and the **uplink dial**, updating each time you
press a key (or on a timer where the platform allows). A "tune to this" companion
for use *during* the pass rather than a pre-pass table.
- Core: reuse `freqplan` range-rate; just single-step on keypress.
- Why: linear-transponder ops re-tune constantly; a one-line "set RX here" is
  less to read mid-pass than a table. Pairs with the "listen to your own
  downlink" power-setting advice.
- Caveat: stock Casio Python has no getkey(); use the single-shot + re-run
  pattern (same constraint we already documented for the graphical Casio tools).

### 4. NODE2ME — next ascending node & ground-track longitude list
For Oscarlocator/board users: print the next several ascending-node times and
their equatorial-crossing longitudes (the numbers you actually mark on a paper
Oscarlocator), derived from the live elements instead of a hand-kept table.
- Core: we already have EQX logic in OrbitCalc and the AO-7 `ao7_eqx.py`
  generator; generalize it into a standalone companion on every platform.
- Why: ties the modern element set back to the classic plotting board — squarely
  in this project's wheelhouse.

---

## Tier 2 — high value, moderate effort

### 5. SKEDQSO — mutual-pass scheduler for two stations
We have `mutual` (co-visibility windows for two QTHs). Turn it into a planner:
"find the next N times satellite X is simultaneously visible to BOTH grids above
E�, in the next M days," with the overlap window start/end and the max mutual
elevation. The tool two hams use to schedule a grid-to-grid contact.
- Core: extend `mutual` with a day loop + elevation gate on both ends.
- Why: scheduled satellite QSOs (especially for rare grids/DXpeditions) are a
  real use; this is the "when can we both hear it" answer.

### 6. ROTOR — rotator preset / pass macro generator
Emit a time-stamped Az/El sequence for a pass in a few selectable formats: plain
table, comma-separated, or a simple `;`-delimited "Az El @hh:mm:ss" macro that a
microcontroller (ESP32/Pico) could replay to a rotator. Add a configurable step
and an optional flip-mode (180° + complement El) note for az/el rotators that
would otherwise hit the stop at zenith.
- Core: reuse `pointing`; add output-format choice and the flip-mode geometry.
- Why: bridges the gap between "where do I point" and actually driving hardware,
  which is exactly N8HM's CI-V / Cardputer interfacing territory. The
  MicroPython/MMBasic versions could even emit directly over a serial port.
- Caveat: keep the on-calculator versions as printed tables; the serial-out
  variant only where a UART exists.

### 7. SUNLIGHT — illumination & beacon-visibility timeline for a pass
We compute eclipse (cylindrical shadow) already in the CardSat SUNECL tool.
Package a companion that, for the upcoming pass, prints when the satellite enters
/ exits sunlight, plus whether the **ground station is in darkness** (the classic
"satellite sunlit, observer in dark" optical-visibility condition) — useful for
spotting ISS/large sats and for solar-panel/eclipse-aware power expectations.
- Core: have the shadow test and Sun almanac; combine with observer day/night.
- Why: optical spotters and anyone reasoning about a bird's battery state want
  this; complements `suntransit`.

### 8. DECAY — orbital-lifetime & element-freshness warner
From mean motion and its change (if the user enters two epochs' MM, or a B*/decay
hint), flag fast-decaying objects and, more simply, **warn when the element set
is more than a few days old** relative to the entered "now" — the single biggest
source of bad predictions with a mean-element model.
- Core: mostly date math; the freshness warning is trivial and high-value.
- Why: our own accuracy caveat says "refresh every few days" — this enforces it.
  Could be folded into `elcheck` as an extra section instead of a separate tool.

---

## Tier 3 — nice to have / more specialized

### 9. SKYTRACK — ASCII/■-grid sky chart of a pass
A text or low-res polar sky chart (concentric El rings, N/E/S/W) plotting the
pass arc with time ticks — a print companion to the graphical PicoCalc polar
plot, for platforms without graphics (Casio text, OPL, GW-BASIC).
- Core: reuse pass sampling + the compass projection from the sky-plot.
- Caveat: character-cell resolution; keep it legible on 16–21 col screens.

### 10. WINDOW — horizon-mask-aware AOS/LOS
Let the user enter a simple azimuth→horizon-elevation mask (e.g. trees to the NE
at 15°, clear to the SW) and recompute the *effective* AOS/LOS and usable
elevation, so predictions match a real backyard.
- Core: pass-finder with a per-azimuth elevation threshold instead of 0°.
- Why: the gap between "10° pass" and "I can't hear it behind my house."

### 11. PHASE — transponder/beacon phase & Mode-A/B/J helper
For satellites with a "phase" or operating schedule (e.g. AO-7's alternating
modes on a sunlight cycle), show the predicted current mode/phase. Niche but
charming for the classic birds this project celebrates.

### 12. DXGRID — footprint grid-square enumerator
For the current sub-satellite point and footprint radius, list which Maidenhead
fields/squares fall inside the footprint — "who can I work right now." Heavier
(loops over grid centers) but a fun "what's reachable" view.

---

## Cross-cutting improvements (not new tools)

- **Shared catalog file**: one editable element/frequency catalog the tools read,
  instead of each embedding its own AO-7/ISS/SO-50 defaults. MMBasic already uses
  `sats.dat`; generalize the format and reuse it where a filesystem exists.
- **GW-BASIC companion back-fill**: GW-BASIC currently has only the two core
  programs; port the seven companion tools there to complete the matrix.
- **Casio BASIC SATFREQ via numeric tables**: prove the frequency-card pattern
  under the no-string-table constraint so the whole suite stays uniform.

---

## What to skip (and why)
- Real-time auto-tracking / continuous rig+rotor control loops: needs hardware
  I/O and timing the calculators/retro platforms can't portably guarantee.
- Anything requiring SGP4-grade accuracy (precise close approaches, conjunction
  screening): out of scope for a secular-J2 mean-element model; would be
  dishonest to present at that precision.
- TLE *fetching* over the network: most target platforms have no IP stack; keep
  element entry manual or via the existing `tle2gp.py`/companion converters on
  the host side.
