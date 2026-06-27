# SATTRACK — Graphical Satellite Pass Predictor for PicoCalc

MMBasic (PicoMite) application for the ClockworkPi PicoCalc (320x320 LCD).

## Install
1. Copy `SATTRACK.bas` to the SD card (drive `B:`).
2. (Optional) copy `sats.dat.sample` to `B:/sats.dat` for a starter set
   (AO-7, AO-27, FO-29, ISS, SO-50 — June 2026 elements; replace with fresh
   AMSAT-bulletin elements before relying on them).
3. (Optional) drop a NORAD TLE file at `B:/tle.txt`, or an OMM/JSON file (AMSAT
   `daily-bulletin.json` or Celestrak `...FORMAT=json-pretty`) anywhere on the
   card, to bulk-import elements via menu 3. See `tle.txt.sample` /
   `omm.json.sample`.
4. At the MMBasic prompt:  `RUN "B:/SATTRACK.bas"`

## Menu (14 items)
1. **Set location / date / time** — Maidenhead grid or lat/lon. For the clock,
   press **R** to read the PicoCalc's real-time clock (assumed UTC) or **M** to
   type the UTC date/time. Saved to `B:/loc.dat`.
2. **Edit satellites** — add/edit/delete up to **200** sats; each is the 7 AMSAT
   bulletin fields + epoch, and optional downlink/uplink MHz + inverting flag
   (used by the Doppler readout). Saved to `B:/sats.dat`. The list scrolls: Up/Down
   move the cursor, Left/Right page through the catalogue.
3. **Load elements (TLE or JSON)** — import either a standard NORAD 2-line (or
   3-line, with a name line) element file, **or** an OMM/JSON file. The format is
   auto-detected from the first character (`[`/`{` = JSON, else TLE). Two JSON
   sources are supported directly:
   - **AMSAT daily bulletin** — `daily-bulletin.json` from
     `newark192.amsat.org/gpdata/current/`. The friendly `AMSAT_NAME`
     (e.g. "AO-07") is used as the satellite name.
   - **Celestrak GP** — `gp.php?GROUP=amateur&FORMAT=json-pretty` (or any GROUP).
     `OBJECT_NAME` is used as the name.

   Default path `B:/tle.txt`; type any path (e.g. `B:/omm.json`). Each usable
   record is appended to the store, up to the 200-satellite limit. Records with
   null/blank elements (placeholder rows in the AMSAT file) are skipped. Epochs
   in ISO-8601 form are parsed, accepting either a `T` or a space before the
   time. Eccentricity is taken as the real decimal value the OMM provides.
   The whole AMSAT amateur bulletin (~90 sats) loads in one go. See
   `omm.json.sample` and `tle.txt.sample`.
4. **Next 10 passes** — list for one satellite: date, AOS-LOS, max El, Az A/T/L.
5. **Polar plot** — sky-track of the next (or current) pass for one satellite.
6. **Live track + Doppler** — real-time single-satellite view: an Az/El compass
   dial with the satellite plotted and a bearing line; current Az/El; **RX/TX
   dial frequencies** corrected for Doppler (if the sat has freqs set), range and
   range-rate; a **SUN/ECL** flag (sunlit or eclipsed); and, when the bird is
   below the horizon, the next AOS time. Re-reads the RTC each tick if available,
   otherwise advances the clock; press a key to refresh, ESC to exit.
7. **Next 3 passes (all sats)** — merged and sorted by AOS time, paged.
8. **World map (sats + terminator)** — equirectangular map with your location,
   each satellite's sub-point and coverage circle in a **distinct colour**, and a
   shaded **day/night terminator** with the subsolar point marked. SPACE steps
   +5 min; **A** auto-advances (any key stops); **N** toggles the night shading.
9. **Pass ground-track preview** — draws the upcoming pass of one satellite as a
   ground-track polyline with footprints at AOS (green), TCA (cyan) and LOS
   (grey), over the map and terminator. A planning snapshot of the whole pass.
0. **OSCARLOCATOR (polar / QTH)** — an interactive azimuthal-equidistant
   OSCARLOCATOR for one satellite, in the spirit of the classic paper plotting
   board. Shows the satellite's ground-track arc for one orbit drawn from its
   equator crossing, a range circle over your QTH (amber), and the footprint at
   the sub-point (green), with a sub-point / Az-El-range / EQX-longitude readout.
   The **polar projection is the default** and auto-selects the north or south
   hemisphere from your latitude (ascending node for northern stations,
   descending for southern, so the listed crossing matches the pass you track).
   Press **M** to switch to the optional **QTH-centred azimuthal** projection,
   which puts your station at the centre with true bearings outward. Controls in
   this view: **SPACE** +1 min, **B** -1 min, **F** auto-run, **S** stop,
   **R** re-pin the arc to "now", **M** toggle projection, **ESC** back.

The next three are reached with the letter keys **A**, **B**, **C** (or by
scrolling the menu with the arrow keys). They are inspired by features in CardSat,
adapted to the PicoCalc and using no external devices:

A. **Pass watch + AOS alarm** — scans the whole catalogue for the soonest AOS and
   counts down to it with a shrinking ring, the satellite name, the AOS time, and
   the predicted maximum elevation. Inside the final minute it flashes the screen
   and beeps the PicoCalc's speaker. Refreshes from the RTC; **ESC** exits.
B. **Pass detail (elevation plot)** — for one satellite's next pass, plots the
   elevation-versus-time curve, **coloured green where the satellite is sunlit and
   grey where it is eclipsed**, with a Sun glyph showing the Sun's elevation at the
   time of closest approach and an AOS / TCA / LOS / max-elevation readout.
C. **Sun position + glyph** — a live sky dial showing the Sun's azimuth and
   elevation from your station (with the Sun plotted on the dome when it is up),
   plus the subsolar latitude/longitude. Useful for avoiding solar-noise transits
   and for telling whether a sunlight-only bird's passes fall in daylight.
D. **Download AMSAT GP (WiFi)** — fetches the AMSAT daily bulletin
   (`daily-bulletin.json`) directly over the network, saves it to `B:/amsat.json`,
   and loads it with the same parser used for SD-card imports. **This needs the
   WiFi build of MMBasic (WebMite) on a Pico W / Pico 2 W with WiFi already
   configured** (see below). On a non-WiFi PicoMite it detects the absence of
   networking and tells you to use the SD import (menu 3) instead — it will not
   crash. The bulletin is HTTPS, so the firmware must include the TLS client.

## Controls
Arrow Up/Down + Enter to choose, or the shortcut keys **1-9**, **0**
(OSCARLOCATOR), and **A**/**B**/**C**/**D** (pass watch / pass detail / Sun view /
download). The menu scrolls if it doesn't all fit. ESC backs out or quits;
Backspace edits text fields. In the scrolling satellite lists, Left/Right page
up/down.

## Downloading elements over WiFi (optional)
Menu item **D** downloads the AMSAT GP bulletin without a PC or SD card, but it
only works on the WiFi-capable firmware:

1. Use a **Raspberry Pi Pico W or Pico 2 W** (the wireless boards) running the
   **WebMite** firmware (the WiFi build of PicoMite). The plain PicoMite on a
   non-W Pico has no network commands, and the feature degrades gracefully there.
2. Configure WiFi once at the MMBasic console:
   `OPTION WIFI "your-ssid", "your-password"` then reboot. Confirm with
   `PRINT MM.INFO$(IP ADDRESS)` — you should see an address.
3. In SATTRACK, choose **D**. It connects to `newark192.amsat.org` over HTTPS,
   saves the bulletin to `B:/amsat.json`, and imports it (up to the 200-sat
   limit). The file is also left on the card so you have an offline copy.

Notes and caveats:
- The exact `WEB`/TLS command names have evolved across firmware versions. This
  uses `WEB OPEN TLS` / `WEB TCP REQUEST`, which match recent WebMite builds; if
  your firmware differs, the network portion of `SUB DownloadAMSAT` is the part to
  adjust (the parsing and storage around it are unchanged).
- If your build lacks a TLS client, point the host at an HTTP mirror and use
  `WEB OPEN TCP` on port 80 instead.
- The response buffer is sized for the ~60-90 KB amateur bulletin. On a RAM-tight
  board, fetch the smaller Celestrak amateur GP feed or use the SD import.

## Performance notes
This is an interpreter on a microcontroller. Pass searches step at 30-second
intervals with bisection refinement, so a multi-pass search may take a few
seconds. The heaviest views:
- **All-sats searches** ("Next 3 passes (all sats)" and "Pass watch") loop over
  the whole catalogue. With up to **200** satellites loaded, that is a lot of
  propagation, so the all-sats pass search automatically shortens its look-ahead
  window as the catalogue grows (7 days for small sets down to 1.5 days beyond 150
  sats) and shows a progress count. For the quickest results, keep only the birds
  you actually work, or run the single-satellite views.
- **World map terminator** shades the night hemisphere with `PIXEL` writes column
  by column (every 4 px, every 3rd row). On a busy map this is the slowest part;
  if it feels sluggish, increase the `stpx` step in `SUB Terminator` or replace
  the per-pixel inner loop with a short vertical `LINE`.
- **Live track** recomputes Look() several times per refresh (position + a
  1-second finite-difference for Doppler). The ~500 ms pause keeps it responsive.

## Capacity
The store holds up to **200 satellites** (`CONST MAXSAT = 200`). Names are kept to
20 characters (`CONST NAMELEN`) and stored in a length-limited string array so the
whole catalogue stays compact in RAM (roughly 20 KB for 200 sats: nine floats, one
integer, and a 20-byte name each). The full AMSAT amateur bulletin loads in one
import. If your PicoMite build is tight on memory, lower `MAXSAT`.

## Files written
- `B:/sats.dat` — saved satellite elements (CSV per sat; now includes the
  optional downlink, uplink and inverting fields).
- `B:/loc.dat`  — observer grid, lat/lon, and UTC date/time.

## On-device shakedown checklist
This program is verified by transcription of its orbit/Sun/Doppler math against
the repo's golden reference (subsolar point, sunlit flag, Doppler dial, and TLE
parse all match), and audited for MMBasic structure (all `LOCAL`s hoisted out of
loops; no reserved-word variable names). It has **not** been run on emulated
hardware. On first run, check:
1. **RTC format.** `GetRTC()` reads `DATE$` as `DD-MM-YYYY` and `TIME$` as
   `HH:MM:SS` (PicoMite convention) and treats the RTC as **UTC**. If your build
   formats the date differently, adjust the `MID$` offsets in `FUNCTION GetRTC`.
   If the RTC isn't set/fitted, the function returns 0 and the app falls back to
   the manual clock.
2. **Terminator speed.** If menu 8 redraws too slowly, coarsen `stpx`.
3. **TLE columns.** The parser uses fixed NORAD columns; if an exotic file has
   leading spaces, the `Trim$` helper handles them, but verify the first import.
4. **JSON import.** The OMM/JSON parser assumes the *pretty-printed* layout (one
   `"KEY": value` per line), which is what both the AMSAT bulletin and Celestrak
   `json-pretty` produce. A fully minified single-line JSON array would not parse
   line-by-line; re-save it pretty-printed if needed. The parser was verified
   against the live AMSAT and Celestrak field layouts (including null-record
   skipping and the space-vs-`T` epoch separator).
5. **AOS alarm audio.** "Pass watch" uses `PLAY TONE` for the alarm beep. If your
   PicoMite build routes audio to a pin your hardware doesn't wire to a speaker,
   the countdown and screen flash still work silently; adjust or remove the
   `PLAY TONE` line in `SUB PassWatch` to suit.
6. **Big catalogues.** With many satellites loaded, give the all-sats searches a
   moment — they show a progress count. The satellite picker and editor scroll, so
   every entry past the first screen is still reachable with the arrow keys.

## Accuracy
Same secular-J2 mean-element model as the console OrbitCalc, verified against a
common reference. Good for pointing and planning; refresh elements every few
days. Sun position is a low-precision almanac (subsolar point good to a fraction
of a degree — ample for a terminator). Footprint radius is from each satellite's
mean altitude (spherical Earth). Doppler uses a 1-second finite-difference
range-rate; it is a planning aid and does not control a radio.
