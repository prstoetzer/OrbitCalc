# OSCARMAP — Live polar OSCARLOCATOR for the PicoCalc

A graphical, live OSCARLOCATOR for the ClockworkPi PicoCalc in MMBasic
(PicoMite). It draws the classic polar **azimuthal-equidistant** world map —
centred on the pole of your hemisphere — and overlays:

- decent vector **coastlines** (Natural Earth 110m, decimated to ~875 points,
  embedded as DATA) plus a lat/lon **graticule**
- the satellite's **ground-track arc** for the current orbit, anchored at its
  equator crossing (ascending node for northern stations, descending for
  southern) the way a real OSCARLOCATOR overlay is pinned
- the **live sub-satellite point**, advancing in time, riding the arc
- the satellite **footprint** (coverage circle)
- a **range circle** over your QTH (default 3000 km)
- live **Az / El / range**, sub-point and UTC read-outs

## Install & run
1. Copy `OSCARMAP.bas` to the PicoCalc SD card (drive `B:`).
   (The coastline data is embedded — there is no separate data file to copy;
   `coastdata.inc` in this folder is just the source listing of that DATA.)
2. At the MMBasic prompt: `RUN "B:/OSCARMAP.bas"`
3. On the setup screen, enter your grid and the UTC time, then the satellite
   name and elements. Press **Enter** on any element field to accept the
   built-in AO-7 default, so you can step straight through for a demo.

## Controls (live screen)
- **SPACE** — step forward by the current step (starts at 1 minute)
- **F** — auto-advance (and speed up); **S** — stop auto
- **B** — step backward
- **R** — re-pin "now" to the displayed time (resets T+offset)
- **H** — flip hemisphere (north/south polar centre)
- **ESC** — quit

## Notes
- **Projection:** single-hemisphere azimuthal-equidistant. The pole of your
  hemisphere is at the centre and the **equator is the rim** — the far
  hemisphere is not drawn. Track, footprint, range circle and the satellite dot
  are clipped at the equator, so the satellite leaves the board when it crosses
  into the other hemisphere, just like a real OSCARLOCATOR overlay. The disc is
  drawn as if looking down on the pole from space (north-centred, 0° longitude
  at the top), so **east longitudes are to the left and west to the right** —
  the coastlines read the same way as a real north-polar OSCARLOCATOR, not like
  a flat wall map.
- Orbit model: secular-J2 mean elements + Kepler — the same verified core as
  OrbitCalc/SATTRACK. Reference geometry for planning, not precise pointing;
  refresh elements every few days.
- The map redraws fully each frame (coastline + track + footprint + range), so
  on the interpreter a frame takes on the order of a second. Auto-advance uses a
  short pause and stays responsive; this is a planning visualiser, not a smooth
  real-time animation.
- Coastline data: Natural Earth 1:110m physical coastline (public domain),
  Douglas-Peucker–decimated and tiny islands culled to fit MMBasic memory.

## Modelled on
**OrbitDeck** and the OSCARLOCATOR simulator by Paul Stoetzer, N8HM
(https://oscarlocator.n8hm.radio).
