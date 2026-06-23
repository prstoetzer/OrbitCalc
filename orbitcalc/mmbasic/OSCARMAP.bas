' ============================================================
'  OSCARLOCATOR - Live polar satellite map for the PicoCalc
'  MMBasic (PicoMite) - ClockworkPi PicoCalc, 320x320 LCD
'
'  A polar azimuthal-equidistant world map (centred on the
'  pole of your hemisphere) showing:
'    - decent vector coastlines + lat/lon graticule
'    - the satellite's ground-track arc for the current orbit
'    - the live sub-satellite point (advancing in time)
'    - the satellite footprint (coverage circle)
'    - a range circle over your QTH
'    - live Az/El, sub-point and range read-outs
'
'  Orbit model: secular-J2 mean-element propagation + Kepler
'  (same core as OrbitCalc/SATTRACK). Reference geometry for
'  planning, not precise pointing. Refresh elements often.
'
'  Coastline: Natural Earth 110m, decimated, embedded as DATA.
' ============================================================

OPTION EXPLICIT
OPTION DEFAULT FLOAT

CONST PI = 3.1415926535898
CONST TWOPI = 6.2831853071796
CONST DEG = PI / 180.0
CONST RAD = 180.0 / PI
CONST MU = 398600.4418
CONST ERAD = 6378.137
CONST J2C = 1.08262668E-3

' ---- display ----
DIM SH, CX, CY, RR
DIM INTEGER SW
SW = MM.HRES
SH = MM.VRES
IF SH > 320 THEN SH = 320

' ---- colours ----
DIM CFG, CACC, CGRID, CLAND, CARC, CSAT, CFOOT, CRNG, CWARN
DIM INTEGER CBG
CBG   = RGB(0, 0, 0)
CFG   = RGB(255, 255, 255)
CACC  = RGB(0, 200, 255)
CGRID = RGB(50, 60, 70)
CLAND = RGB(70, 140, 90)
CARC  = RGB(255, 255, 255)
CSAT  = RGB(255, 70, 70)
CFOOT = RGB(0, 220, 120)
CRNG  = RGB(255, 190, 0)
CWARN = RGB(255, 220, 0)

' ---- observer ----
DIM OBLAT, OBLON                ' radians
DIM OBGRID$
DIM 0 = south-centred
DIM INTEGER NHEMI               ' 1 = north-centred
DIM NMO, ND, NH, NMI
DIM INTEGER NY
DIM NOWJD

' ---- loaded satellite elements ----
DIM SATNAME$
DIM WI, WE, WO, WG, WM, WN, WJ, WA, WRD, WPD
DIM SPERIOD                     ' orbital period (minutes)

' ---- propagation outputs ----
DIM GX, GY, GZ, EX, EY, EZ, BLAT, BLON, LEL, LAZ, LRNG

' ---- map centre + radius (azimuthal-equidistant unit -> pixels) ----
CX = SW / 2
CY = 18 + (SH - 18) / 2
RR = (SH - 18) / 2 - 2

' ---- coastline storage (filled from DATA) ----
DIM INTEGER NCSEG
DIM INTEGER CSCNT(120)          ' point count per segment (max segs)
DIM CSLON(900), CSLAT(900)      ' flattened lon/lat (deg)
DIM INTEGER CSSTART(120)        ' start index of each segment

' ---- ground-track cache (one orbit) ----
CONST NTRK = 120
DIM TRKLAT(NTRK), TRKLON(NTRK)
DIM INTEGER NTRKPTS

CALL Init
CALL DefaultState
CALL LoadCoast
CALL SetupScreen
CALL EnterElements
CALL ComputeTrack
CALL LiveLoop
CLS
PRINT "73!"
END

' ============================================================
SUB Init
  ' nothing heavy here yet
END SUB

SUB DefaultState
  OBGRID$ = "FM18LV"
  CALL Maiden(OBGRID$)
  NHEMI = 1
  IF OBLAT < 0 THEN NHEMI = 0
  NY = 2026 : NMO = 6 : ND = 22 : NH = 0 : NMI = 0
  NOWJD = FNjd(NY, NMO, ND, NH, NMI, 0)
  SATNAME$ = "AO-07"
END SUB

SUB SetupScreen
  CLS CBG
  BOX 0, 0, SW, 16, 1, CACC, RGB(0, 30, 45)
  TEXT 3, 2, "OSCARLOCATOR  N8HM", "L", 7, 1, CACC
END SUB

' ============================================================
'  AZIMUTHAL-EQUIDISTANT PROJECTION
'  lat,lon (radians) -> screen px,py. Returns visible flag in PJOK.
'  Centred on N pole (NHEMI=1) or S pole (NHEMI=0).
' ============================================================
DIM PJY, PJOK
DIM INTEGER PJX
SUB Project(latr, lonr)
  LOCAL rho, theta, r
  IF NHEMI = 1 THEN
    rho = (PI / 2 - latr)        ' 0 at N pole .. PI/2 at equator
    theta = lonr
  ELSE
    rho = (PI / 2 + latr)        ' 0 at S pole .. PI/2 at equator
    theta = -lonr
  ENDIF
  r = rho / (PI / 2)             ' 0 at pole, 1 at equator (rim)
  PJX = CX + r * RR * SIN(theta)
  PJY = CY - r * RR * COS(theta)
  ' single-hemisphere board: clip anything past the equator
  IF rho > PI / 2 THEN PJOK = 0 ELSE PJOK = 1
END SUB

' ============================================================
'  COASTLINE: load from DATA, draw
' ============================================================
SUB LoadCoast
  LOCAL n, i, idx
  LOCAL INTEGER s
  RESTORE CoastData
  READ NCSEG
  idx = 0
  FOR s = 1 TO NCSEG
    READ n
    CSCNT(s) = n
    CSSTART(s) = idx
    FOR i = 1 TO n
      READ CSLON(idx), CSLAT(idx)
      idx = idx + 1
    NEXT i
  NEXT s
END SUB

SUB DrawCoast
  LOCAL i, idx
  LOCAL INTEGER s
  LOCAL INTEGER x0, y0, x1, y1, ok0, ok1, first
  FOR s = 1 TO NCSEG
    idx = CSSTART(s)
    first = 1
    FOR i = 1 TO CSCNT(s)
      CALL Project(CSLAT(idx) * DEG, CSLON(idx) * DEG)
      x1 = PJX : y1 = PJY : ok1 = PJOK
      IF first = 0 THEN
        ' only draw when BOTH endpoints are in this hemisphere
        IF ok0 = 1 AND ok1 = 1 THEN LINE x0, y0, x1, y1, 1, CLAND
      ENDIF
      x0 = x1 : y0 = y1 : ok0 = ok1 : first = 0
      idx = idx + 1
    NEXT i
  NEXT s
END SUB

SUB DrawGraticule
  LOCAL INTEGER i
  LOCAL x0, y0, x1, y1, first, latc, nearlat
  LOCAL INTEGER j
  ' latitude circles at 30 and 60 deg of THIS hemisphere only
  FOR i = 1 TO 2
    latc = i * 30
    IF NHEMI = 0 THEN latc = -latc
    first = 1
    FOR j = 0 TO 360 STEP 8
      CALL Project(latc * DEG, j * DEG)
      x1 = PJX : y1 = PJY
      IF first = 0 THEN LINE x0, y0, x1, y1, 1, CGRID
      x0 = x1 : y0 = y1 : first = 0
    NEXT j
  NEXT i
  ' longitude spokes: from near the pole out to the equator rim
  IF NHEMI = 1 THEN nearlat = 80 ELSE nearlat = -80
  FOR i = 0 TO 330 STEP 30
    LOCAL px0, py0
    CALL Project(nearlat * DEG, i * DEG)
    px0 = PJX : py0 = PJY
    CALL Project(0, i * DEG)              ' equator end
    LINE px0, py0, PJX, PJY, 1, CGRID
  NEXT i
  ' equator = rim (this IS the boundary of the board)
  CIRCLE CX, CY, RR, 1, , CACC
END SUB

' ============================================================
'  ORBIT MODEL (secular-J2 mean elements)
' ============================================================
SUB LoadSatElems(inc, ecc, ra, ap, ma, mm, ep)
  WI = inc * DEG
  WE = ecc
  WO = ra * DEG
  WG = ap * DEG
  WM = ma * DEG
  WN = mm * TWOPI / 86400.0
  WJ = ep
  WA = (MU / (WN * WN)) ^ (1.0 / 3.0)
  LOCAL p, f, ci, si
  p = WA * (1 - WE * WE)
  f = 1.5 * J2C * (ERAD / p) ^ 2 * WN
  ci = COS(WI) : si = SIN(WI)
  WRD = -f * ci
  WPD = f * (2 - 2.5 * si * si)
  SPERIOD = 1440.0 / mm
END SUB

SUB Eci(j)
  LOCAL dt, m, ra, ap, ee, xo, yo, u, r
  LOCAL co, so, cu, su, ci, si
  dt = (j - WJ) * 86400.0
  m = WM + WN * dt
  ra = WO + WRD * dt
  ap = WG + WPD * dt
  m = m - TWOPI * INT(m / TWOPI)
  ee = Kepler(m, WE)
  xo = WA * (COS(ee) - WE)
  yo = WA * SQR(1 - WE * WE) * SIN(ee)
  u = ATAN2S(yo, xo) + ap
  r = SQR(xo * xo + yo * yo)
  co = COS(ra) : so = SIN(ra)
  cu = COS(u) : su = SIN(u)
  ci = COS(WI) : si = SIN(WI)
  GX = r * (co * cu - so * su * ci)
  GY = r * (so * cu + co * su * ci)
  GZ = r * (su * si)
END SUB

SUB Ecef(j)
  LOCAL g, cg, sg
  CALL Eci(j)
  g = Gmst(j)
  cg = COS(g) : sg = SIN(g)
  EX = cg * GX + sg * GY
  EY = -sg * GX + cg * GY
  EZ = GZ
END SUB

SUB SubPt(j)
  CALL Ecef(j)
  BLON = ATAN2S(EY, EX)
  BLAT = ATAN2S(EZ, SQR(EX * EX + EY * EY))
END SUB

SUB Look(j, la, lo)
  LOCAL cl, sl, col, sol, ox, oy, oz
  LOCAL rx, ry, rz, s, e, zz, rng
  CALL Ecef(j)
  cl = COS(la) : sl = SIN(la)
  col = COS(lo) : sol = SIN(lo)
  ox = ERAD * cl * col
  oy = ERAD * cl * sol
  oz = ERAD * sl
  rx = EX - ox : ry = EY - oy : rz = EZ - oz
  s = sl * col * rx + sl * sol * ry - cl * rz
  e = -sol * rx + col * ry
  zz = cl * col * rx + cl * sol * ry + sl * rz
  rng = SQR(rx * rx + ry * ry + rz * rz)
  LEL = ASINN(zz / rng)
  LAZ = ATAN2S(e, -s)
  IF LAZ < 0 THEN LAZ = LAZ + TWOPI
  LRNG = rng
END SUB

FUNCTION FNjd(y, mo, d, h, mi, s)
  LOCAL yy, mm, a, b
  yy = y : mm = mo
  IF mm <= 2 THEN yy = yy - 1 : mm = mm + 12
  a = INT(yy / 100)
  b = 2 - a + INT(a / 4)
  FNjd = INT(365.25 * (yy + 4716)) + INT(30.6001 * (mm + 1)) + d + b - 1524.5
  FNjd = FNjd + (h + mi / 60.0 + s / 3600.0) / 24.0
END FUNCTION

FUNCTION Gmst(j)
  LOCAL t, g
  t = (j - 2451545.0) / 36525.0
  g = 280.46061837 + 360.98564736629 * (j - 2451545.0) + 0.000387933 * t * t
  g = g - 360.0 * INT(g / 360.0)
  IF g < 0 THEN g = g + 360.0
  Gmst = g * DEG
END FUNCTION

FUNCTION Kepler(m, e)
  LOCAL x, dx
  LOCAL INTEGER k
  x = m
  FOR k = 1 TO 40
    dx = (x - e * SIN(x) - m) / (1 - e * COS(x))
    x = x - dx
    IF ABS(dx) < 1E-11 THEN EXIT FOR
  NEXT k
  Kepler = x
END FUNCTION

FUNCTION ATAN2S(y, x)
  IF x > 0 THEN ATAN2S = ATN(y / x) : EXIT FUNCTION
  IF x < 0 AND y >= 0 THEN ATAN2S = ATN(y / x) + PI : EXIT FUNCTION
  IF x < 0 AND y < 0 THEN ATAN2S = ATN(y / x) - PI : EXIT FUNCTION
  IF x = 0 AND y > 0 THEN ATAN2S = PI / 2 : EXIT FUNCTION
  IF x = 0 AND y < 0 THEN ATAN2S = -PI / 2 : EXIT FUNCTION
  ATAN2S = 0
END FUNCTION

FUNCTION ASINN(x)
  LOCAL v
  v = x
  IF v > 1 THEN v = 1
  IF v < -1 THEN v = -1
  ASINN = ATN(v / SQR(1 - v * v + 1E-18))
END FUNCTION

FUNCTION ACOSS(x)
  ACOSS = PI / 2 - ASINN(x)
END FUNCTION

' ============================================================
'  GROUND-TRACK ARC (one orbit, sampled, cached)
' ============================================================
SUB ComputeTrack
  CALL ComputeTrackAt(NOWJD)
END SUB

SUB ComputeTrackAt(tref)
  LOCAL j, dtmin, eqxj
  LOCAL INTEGER i
  eqxj = FindEqx(tref)
  dtmin = SPERIOD / NTRK          ' minutes per sample
  FOR i = 0 TO NTRK
    j = eqxj + (i * dtmin) / 1440.0
    CALL SubPt(j)
    TRKLAT(i) = BLAT
    TRKLON(i) = BLON
  NEXT i
  NTRKPTS = NTRK
END SUB

' Find node crossing (ascending if north hemi, descending if south)
' at or just before tref. Returns its JD.
FUNCTION FindEqx(tref)
  LOCAL j, stp, prevlat, a0, a1, m, jback
  LOCAL INTEGER asc, found, k, cross
  IF NHEMI = 1 THEN asc = 1 ELSE asc = 0
  stp = 60.0 / 86400.0
  prevlat = 999
  found = 0
  jback = tref - (SPERIOD + 5) / 1440.0
  j = jback
  DO WHILE j < tref AND found = 0
    CALL SubPt(j)
    IF prevlat <> 999 THEN
      cross = 0
      IF asc = 1 AND prevlat < 0 AND BLAT >= 0 THEN cross = 1
      IF asc = 0 AND prevlat > 0 AND BLAT <= 0 THEN cross = 1
      IF cross = 1 THEN
        a0 = j - stp : a1 = j
        FOR k = 1 TO 30
          m = (a0 + a1) / 2 : CALL SubPt(m)
          IF (BLAT >= 0) = (asc = 1) THEN a1 = m ELSE a0 = m
        NEXT k
        FindEqx = (a0 + a1) / 2
        found = 1
      ENDIF
    ENDIF
    prevlat = BLAT
    j = j + stp
  LOOP
  IF found = 0 THEN FindEqx = tref
END FUNCTION

SUB DrawTrack
  LOCAL INTEGER x0, y0, x1, y1, ok0, ok1, first
  LOCAL INTEGER i
  first = 1
  FOR i = 0 TO NTRKPTS
    CALL Project(TRKLAT(i), TRKLON(i))
    x1 = PJX : y1 = PJY : ok1 = PJOK
    IF first = 0 THEN
      IF ok0 = 1 AND ok1 = 1 THEN LINE x0, y0, x1, y1, 1, CARC
    ENDIF
    x0 = x1 : y0 = y1 : ok0 = ok1 : first = 0
  NEXT i
END SUB

' ============================================================
'  FOOTPRINT (coverage circle) around a sub-point
' ============================================================
SUB DrawFootprint(clat, clon, col AS INTEGER)
  LOCAL h, rho, az, dlat, dlon
  LOCAL INTEGER x0, y0, x1, y1, ok0, ok1, first
  LOCAL INTEGER i
  h = WA - ERAD
  rho = ACOSS(ERAD / (ERAD + h))      ' Earth central angle to horizon
  first = 1
  FOR i = 0 TO 36
    az = i * 10 * DEG
    dlat = ASINN(SIN(clat) * COS(rho) + COS(clat) * SIN(rho) * COS(az))
    dlon = clon + ATAN2S(SIN(az) * SIN(rho) * COS(clat), COS(rho) - SIN(clat) * SIN(dlat))
    CALL Project(dlat, dlon)
    x1 = PJX : y1 = PJY : ok1 = PJOK
    IF first = 0 THEN
      IF ok0 = 1 AND ok1 = 1 THEN LINE x0, y0, x1, y1, 1, col
    ENDIF
    x0 = x1 : y0 = y1 : ok0 = ok1 : first = 0
  NEXT i
END SUB

' ============================================================
'  RANGE CIRCLE over the QTH (fixed ground radius, km)
' ============================================================
SUB DrawRangeCircle(rkm, col AS INTEGER)
  LOCAL rho, az, dlat, dlon
  LOCAL INTEGER x0, y0, x1, y1, ok0, ok1, first
  LOCAL INTEGER i
  rho = rkm / ERAD                   ' central angle for a ground range
  first = 1
  FOR i = 0 TO 36
    az = i * 10 * DEG
    dlat = ASINN(SIN(OBLAT) * COS(rho) + COS(OBLAT) * SIN(rho) * COS(az))
    dlon = OBLON + ATAN2S(SIN(az) * SIN(rho) * COS(OBLAT), COS(rho) - SIN(OBLAT) * SIN(dlat))
    CALL Project(dlat, dlon)
    x1 = PJX : y1 = PJY : ok1 = PJOK
    IF first = 0 THEN
      IF ok0 = 1 AND ok1 = 1 THEN LINE x0, y0, x1, y1, 1, col
    ENDIF
    x0 = x1 : y0 = y1 : ok0 = ok1 : first = 0
  NEXT i
END SUB

SUB MarkPoint(latr, lonr, col AS INTEGER, big AS INTEGER)
  CALL Project(latr, lonr)
  IF PJOK = 0 THEN EXIT SUB        ' point is in the other hemisphere
  IF big = 1 THEN
    LINE PJX - 4, PJY, PJX + 4, PJY, 1, col
    LINE PJX, PJY - 4, PJX, PJY + 4, 1, col
    CIRCLE PJX, PJY, 3, 1, , col
  ELSE
    CIRCLE PJX, PJY, 3, 1, , col, col
  ENDIF
END SUB

' ============================================================
'  LIVE LOOP
'  Steps NOWJD forward; redraws map + sat. Keys:
'   SPACE = +1 min step, F = faster auto, S = slower, R = recompute
'   track (re-pin to current time), H = flip hemisphere, ESC = quit.
' ============================================================
SUB LiveLoop
  LOCAL k$
  LOCAL INTEGER auto, stepmin
  LOCAL toff, trackbase
  auto = 0
  stepmin = 1
  toff = 0
  trackbase = 0
  CALL ComputeTrackAt(NOWJD)
  DO
    IF ABS(toff - trackbase) > SPERIOD THEN
      CALL ComputeTrackAt(NOWJD + toff / 1440.0)
      trackbase = toff
    ENDIF
    CALL DrawFrame(toff)
    IF auto = 1 THEN
      PAUSE 250
      k$ = INKEY$
      IF k$ = "" THEN toff = toff + stepmin
    ELSE
      k$ = WaitKey$()
    ENDIF
    IF k$ = " " THEN toff = toff + stepmin
    IF UCASE$(k$) = "F" THEN auto = 1 : stepmin = stepmin + 1
    IF UCASE$(k$) = "S" THEN auto = 0
    IF UCASE$(k$) = "B" THEN toff = toff - stepmin
    IF UCASE$(k$) = "R" THEN NOWJD = NOWJD + toff / 1440.0 : toff = 0 : trackbase = 0 : CALL ComputeTrackAt(NOWJD)
    IF UCASE$(k$) = "H" THEN NHEMI = 1 - NHEMI : CALL ComputeTrackAt(NOWJD + toff / 1440.0) : trackbase = toff
  LOOP UNTIL k$ = CHR$(27)
END SUB

SUB DrawFrame(toff)
  LOCAL j
  j = NOWJD + toff / 1440.0
  CLS CBG
  BOX 0, 0, SW, 16, 1, CACC, RGB(0, 30, 45)
  TEXT 3, 2, "OSCARLOCATOR " + SATNAME$, "L", 7, 1, CACC
  ' base map
  CALL DrawGraticule
  CALL DrawCoast
  ' ground track (this orbit, from its equator crossing)
  CALL DrawTrack
  ' range circle over QTH
  CALL DrawRangeCircle(3000.0, CRNG)
  ' QTH marker
  CALL MarkPoint(OBLAT, OBLON, CWARN, 1)
  ' satellite now: sub-point, footprint, look angles
  CALL SubPt(j)
  CALL DrawFootprint(BLAT, BLON, CFOOT)
  CALL MarkPoint(BLAT, BLON, CSAT, 0)
  CALL Look(j, OBLAT, OBLON)
  CALL ReadOut(j, toff)
END SUB

SUB ReadOut(j, toff)
  LOCAL s$
  LOCAL INTEGER yb
  yb = SH - 30
  BOX 0, yb, SW, 30, 1, CBG, RGB(0, 10, 20)
  ' line 1: time + sub-point
  CALL Cal(j)
  s$ = Z2$(CH) + ":" + Z2$(CMI) + "Z  Sub " + Lat$(BLAT) + " " + Lon$(BLON)
  TEXT 2, yb + 1, s$, "L", 7, 1, CACC
  ' line 2: az/el/range or "below horizon"
  IF LEL >= 0 THEN
    s$ = "Az " + STR$(INT(LAZ * RAD + 0.5)) + " El " + STR$(INT(LEL * RAD + 0.5)) + " Rng " + STR$(INT(LRNG)) + "km"
    TEXT 2, yb + 11, s$, "L", 7, 1, CFOOT
  ELSE
    s$ = "Below horizon  (T+" + STR$(INT(toff)) + "m)"
    TEXT 2, yb + 11, s$, "L", 7, 1, RGB(160, 160, 160)
  ENDIF
  TEXT 2, yb + 21, "SPC=step F=fast S=stop H=hemi R=repin ESC", "L", 7, 1, CGRID
END SUB

' ============================================================
'  INPUT: elements (with AO-7 defaults) + QTH
' ============================================================
SUB EnterElements
  LOCAL g$, inc, ecc, ra, ap, ma, mm
  LOCAL ey, emo, ed, eh, emi, es
  CLS CBG
  BOX 0, 0, SW, 16, 1, CACC, RGB(0, 30, 45)
  TEXT 3, 2, "OSCARLOCATOR setup", "L", 7, 1, CACC
  TEXT 2, 20, "Enter grid (blank=keep " + OBGRID$ + ")", "L", 7, 1, CFG
  g$ = AskStr$("Grid", 2, 32)
  IF LEN(g$) >= 4 THEN OBGRID$ = UCASE$(g$) : CALL Maiden(OBGRID$)
  NHEMI = 1 : IF OBLAT < 0 THEN NHEMI = 0
  TEXT 2, 48, "UTC now:", "L", 7, 1, CACC
  NY  = AskNumD("Year", 2, 60, NY)
  NMO = AskNumD("Mon", 2, 72, NMO)
  ND  = AskNumD("Day", 2, 84, ND)
  NH  = AskNumD("Hr", 2, 96, NH)
  NMI = AskNumD("Min", 2, 108, NMI)
  NOWJD = FNjd(NY, NMO, ND, NH, NMI, 0)
  TEXT 2, 124, "Satellite name:", "L", 7, 1, CACC
  g$ = AskStr$("Name", 2, 136)
  IF LEN(g$) > 0 THEN SATNAME$ = UCASE$(g$)
  ' AO-7 defaults so you can just press Enter through
  TEXT 2, 152, "Elements (Enter=AO-7 default):", "L", 7, 1, CACC
  inc = AskNumD("INC", 2, 164, 101.9899)
  ecc = AskNumD("ECC", 2, 176, 0.0012609)
  ra  = AskNumD("RAAN", 2, 188, 184.6033)
  ap  = AskNumD("ARGP", 2, 200, 124.3014)
  ma  = AskNumD("MA", 2, 212, 247.3322)
  mm  = AskNumD("MM", 2, 224, 12.53698149)
  TEXT 2, 240, "Epoch UTC:", "L", 7, 1, CACC
  ey  = AskNumD("EYr", 2, 252, 2026)
  emo = AskNumD("EMo", 2, 264, 6)
  ed  = AskNumD("EDy", 2, 276, 20)
  eh  = AskNumD("EHr", 2, 288, 7)
  emi = AskNumD("EMi", 2, 300, 46)
  es  = AskNumD("ESe", 2, 312, 20.6)
  CALL LoadSatElems(inc, ecc, ra, ap, ma, mm, FNjd(ey, emo, ed, eh, emi, es))
END SUB

' ============================================================
'  CALENDAR + MAIDENHEAD + FORMAT HELPERS
' ============================================================
DIM CMO, CD, CH, CMI
DIM INTEGER CY
DIM CS
SUB Cal(j)
  LOCAL z, f, al, a, b, c, dd, e, day, secs
  j = j + 0.5
  z = INT(j) : f = j - z
  IF z < 2299161 THEN
    a = z
  ELSE
    al = INT((z - 1867216.25) / 36524.25)
    a = z + 1 + al - INT(al / 4)
  ENDIF
  b = a + 1524
  c = INT((b - 122.1) / 365.25)
  dd = INT(365.25 * c)
  e = INT((b - dd) / 30.6001)
  day = b - dd - INT(30.6001 * e) + f
  IF e < 14 THEN CMO = e - 1 ELSE CMO = e - 13
  IF CMO > 2 THEN CY = c - 4716 ELSE CY = c - 4715
  CD = INT(day)
  secs = (day - CD) * 86400.0
  CH = INT(secs / 3600) : secs = secs - CH * 3600
  CMI = INT(secs / 60)
  CS = secs - CMI * 60
END SUB

SUB Maiden(g$)
  LOCAL u$, lo, la
  u$ = UCASE$(g$)
  lo = (ASC(MID$(u$, 1, 1)) - 65) * 20 - 180
  la = (ASC(MID$(u$, 2, 1)) - 65) * 10 - 90
  lo = lo + (ASC(MID$(u$, 3, 1)) - 48) * 2
  la = la + (ASC(MID$(u$, 4, 1)) - 48)
  IF LEN(u$) >= 6 THEN
    lo = lo + (ASC(MID$(u$, 5, 1)) - 65) / 12.0 + 1.0 / 24.0
    la = la + (ASC(MID$(u$, 6, 1)) - 65) / 24.0 + 1.0 / 48.0
  ELSE
    lo = lo + 1.0 : la = la + 0.5
  ENDIF
  OBLAT = la * DEG
  OBLON = lo * DEG
END SUB

FUNCTION Z2$(n AS INTEGER)
  IF n < 10 THEN Z2$ = "0" + STR$(n) ELSE Z2$ = STR$(n)
END FUNCTION

FUNCTION Lat$(latr)
  LOCAL d
  d = latr * RAD
  IF d >= 0 THEN Lat$ = STR$(INT(d + 0.5)) + "N" ELSE Lat$ = STR$(INT(-d + 0.5)) + "S"
END FUNCTION

FUNCTION Lon$(lonr)
  LOCAL d
  d = lonr * RAD
  DO WHILE d > 180 : d = d - 360 : LOOP
  DO WHILE d <= -180 : d = d + 360 : LOOP
  IF d >= 0 THEN Lon$ = STR$(INT(d + 0.5)) + "E" ELSE Lon$ = STR$(INT(-d + 0.5)) + "W"
END FUNCTION

FUNCTION WaitKey$()
  LOCAL k$
  DO
    k$ = INKEY$
  LOOP UNTIL k$ <> ""
  WaitKey$ = k$
END FUNCTION

FUNCTION AskStr$(label$, x AS INTEGER, y AS INTEGER)
  LOCAL s$, c$
  LOCAL INTEGER done
  s$ = "" : done = 0
  DO
    BOX x, y, SW - x - 2, 11, 1, CBG, CBG
    TEXT x, y, label$ + ":" + s$ + "_", "L", 7, 1, CFG
    c$ = WaitKey$()
    IF c$ = CHR$(13) THEN
      done = 1
    ELSEIF c$ = CHR$(8) OR c$ = CHR$(127) THEN
      IF LEN(s$) > 0 THEN s$ = LEFT$(s$, LEN(s$) - 1)
    ELSEIF c$ = CHR$(27) THEN
      s$ = "" : done = 1
    ELSEIF ASC(c$) >= 32 AND ASC(c$) < 127 THEN
      s$ = s$ + c$
    ENDIF
  LOOP UNTIL done = 1
  BOX x, y, SW - x - 2, 11, 1, CBG, CBG
  TEXT x, y, label$ + ":" + s$, "L", 7, 1, CFOOT
  AskStr$ = s$
END FUNCTION

FUNCTION AskNumD(label$, x AS INTEGER, y AS INTEGER, dflt)
  LOCAL s$
  s$ = AskStr$(label$ + "(" + STR$(dflt) + ")", x, y)
  IF LEN(s$) = 0 THEN AskNumD = dflt ELSE AskNumD = VAL(s$)
END FUNCTION

' ============================================================
'  EMBEDDED COASTLINE DATA (Natural Earth 110m, decimated)
' ============================================================
' COAST DATA: 83 segments, 875 points
CoastData:
DATA 83
DATA 3
DATA -163.7,-78.6,-159.2,-79.5,-163.7,-78.6
DATA 5
DATA -6.2,53.9,-6.8,52.3,-10.0,51.8,-7.6,55.1,-6.2,53.9
DATA 16
DATA 141.0,-2.6,147.6,-6.1,147.2,-7.4,150.7,-10.6,144.7,-7.6,142.6,-9.3
DATA 137.6,-8.4,137.9,-5.4,133.0,-4.1,132.0,-2.8,133.7,-2.2,130.5,-0.9
DATA 134.0,-0.8,135.5,-3.4,137.4,-1.7,141.0,-2.6
DATA 10
DATA 114.2,4.5,116.7,6.9,119.2,5.4,117.3,3.2,119.0,0.9,116.1,-4.0
DATA 110.2,-2.9,109.1,-0.5,109.7,2.0,114.2,4.5
DATA 3
DATA -93.6,75.0,-96.8,74.9,-93.6,75.0
DATA 5
DATA -88.2,74.4,-97.1,76.8,-81.1,75.7,-80.5,74.7,-88.2,74.4
DATA 6
DATA -82.3,23.2,-74.2,20.3,-77.8,19.9,-81.8,22.6,-85.0,21.9,-82.3,23.2
DATA 6
DATA -55.6,51.3,-56.8,49.8,-53.5,49.2,-53.1,46.7,-59.3,47.6,-55.6,51.3
DATA 5
DATA -83.9,65.1,-80.1,63.7,-87.2,63.5,-85.9,65.7,-83.9,65.1
DATA 22
DATA -78.8,72.4,-68.8,70.5,-67.0,69.2,-68.8,68.7,-61.9,66.9,-63.9,65.0
DATA -68.0,66.3,-64.7,63.4,-68.8,63.7,-66.2,61.9,-74.8,64.7,-77.7,64.2
DATA -77.9,65.3,-74.0,65.5,-73.3,68.1,-79.0,70.2,-88.7,70.4,-90.2,72.2
DATA -85.8,73.8,-85.8,72.5,-82.3,73.8,-78.8,72.4
DATA 5
DATA -94.5,74.1,-90.5,73.9,-95.4,72.1,-96.0,73.4,-94.5,74.1
DATA 8
DATA -100.4,72.7,-101.5,73.4,-100.4,73.8,-97.4,73.8,-96.5,72.6,-98.4,71.3
DATA -102.5,72.5,-100.4,72.7
DATA 7
DATA -107.8,75.8,-105.9,76.0,-106.3,75.0,-112.2,74.4,-117.7,75.2,-115.4,76.5
DATA -107.8,75.8
DATA 3
DATA -122.9,76.1,-116.2,77.6,-122.9,76.1
DATA 7
DATA -121.5,74.4,-115.5,73.5,-123.1,70.9,-125.9,71.9,-123.9,73.7,-124.9,74.3
DATA -121.5,74.4
DATA 3
DATA -132.7,54.0,-131.2,52.2,-132.7,54.0
DATA 4
DATA -125.4,50.0,-124.0,48.4,-128.4,50.5,-125.4,50.0
DATA 3
DATA -171.7,63.8,-168.7,63.3,-171.7,63.8
DATA 3
DATA -105.5,79.3,-99.7,77.9,-105.5,79.3
DATA 7
DATA 49.5,-12.5,50.4,-15.7,47.1,-24.9,45.4,-25.6,43.3,-22.8,44.0,-17.4
DATA 49.5,-12.5
DATA 5
DATA -48.7,-78.0,-43.9,-78.5,-43.3,-80.0,-54.2,-80.6,-48.7,-78.0
DATA 3
DATA -66.3,-80.3,-59.6,-80.0,-66.3,-80.3
DATA 6
DATA -73.9,-71.3,-70.3,-68.9,-68.3,-71.4,-72.4,-72.5,-75.0,-72.1,-73.9,-71.3
DATA 3
DATA -102.3,-71.9,-96.2,-72.5,-102.3,-71.9
DATA 3
DATA -122.6,-73.7,-118.7,-73.5,-122.6,-73.7
DATA 3
DATA -127.3,-73.5,-124.0,-73.9,-127.3,-73.5
DATA 4
DATA 151.3,-5.8,148.3,-5.7,152.1,-4.1,151.3,-5.8
DATA 7
DATA 176.9,-40.1,174.7,-41.3,174.7,-37.4,172.6,-34.5,176.0,-37.6,178.5,-37.7
DATA 176.9,-40.1
DATA 6
DATA 169.7,-43.6,172.8,-40.5,174.2,-41.3,169.3,-46.6,166.5,-45.9,169.7,-43.6
DATA 5
DATA 147.7,-40.8,147.9,-43.2,146.0,-43.5,144.7,-40.7,147.7,-40.8
DATA 24
DATA 126.1,-32.2,118.0,-35.1,115.0,-34.2,113.7,-22.5,120.9,-19.7,125.7,-14.2
DATA 129.6,-15.0,132.4,-11.1,136.5,-11.9,135.5,-15.0,140.2,-17.7,142.5,-10.7
DATA 146.4,-19.0,150.7,-22.4,153.6,-28.1,150.0,-37.4,146.3,-39.0,140.6,-38.0
DATA 138.2,-34.4,136.8,-35.3,137.8,-32.9,136.0,-34.9,131.3,-31.5,126.1,-32.2
DATA 4
DATA 81.8,7.5,80.3,6.0,80.1,9.8,81.8,7.5
DATA 4
DATA 129.4,-2.8,130.8,-3.9,127.9,-3.4,129.4,-2.8
DATA 3
DATA 127.9,2.2,128.1,-0.9,127.9,2.2
DATA 12
DATA 122.9,0.9,125.1,1.6,124.4,0.4,120.0,-0.5,123.3,-0.6,121.5,-1.9
DATA 123.2,-5.3,121.0,-2.6,119.8,-5.7,118.8,-2.8,119.8,0.2,122.9,0.9
DATA 5
DATA 108.5,-6.4,115.7,-8.4,106.5,-7.4,106.1,-5.9,108.5,-6.4
DATA 6
DATA 104.4,-1.1,106.1,-3.1,104.7,-5.9,95.3,5.5,97.5,5.2,104.4,-1.1
DATA 6
DATA 126.4,8.4,125.4,5.6,123.6,7.8,121.9,7.2,125.4,9.8,126.4,8.4
DATA 4
DATA 109.5,18.2,108.6,19.4,110.8,20.1,109.5,18.2
DATA 4
DATA 121.8,24.4,120.7,22.0,120.1,23.6,121.8,24.4
DATA 11
DATA 141.9,39.2,140.3,35.1,135.8,33.5,135.1,34.6,131.0,33.9,132.0,33.1
DATA 130.2,31.4,129.4,33.3,139.4,38.2,140.3,41.2,141.9,39.2
DATA 6
DATA 144.6,44.0,145.5,43.3,143.2,42.0,140.0,41.6,142.0,45.6,144.6,44.0
DATA 4
DATA 8.7,40.9,9.8,40.5,8.8,38.9,8.7,40.9
DATA 11
DATA -4.2,58.6,-2.0,57.7,-3.1,56.0,1.7,52.7,1.4,51.3,-5.8,50.2
DATA -3.4,51.4,-5.3,52.0,-2.9,54.0,-6.1,56.8,-4.2,58.6
DATA 8
DATA -14.5,66.5,-13.6,65.1,-18.7,63.5,-22.8,64.0,-24.0,64.9,-22.2,65.4
DATA -24.3,65.6,-14.5,66.5
DATA 7
DATA 142.9,53.7,144.7,49.0,143.2,49.3,143.5,46.1,142.1,46.0,141.7,53.3
DATA 142.9,53.7
DATA 3
DATA 118.5,9.3,119.5,11.4,118.5,9.3
DATA 6
DATA 122.3,18.2,121.7,14.3,124.1,12.5,119.9,15.4,120.7,18.5,122.3,18.2
DATA 4
DATA 125.5,12.2,124.8,10.1,124.3,12.6,125.5,12.2
DATA 31
DATA -77.4,8.7,-71.8,12.4,-71.7,9.1,-69.9,12.2,-68.2,10.6,-61.9,10.7
DATA -57.1,6.0,-51.3,4.1,-50.4,-0.1,-44.6,-2.7,-40.0,-2.9,-35.6,-5.1
DATA -34.7,-7.3,-38.7,-13.1,-40.9,-21.9,-47.6,-24.9,-48.9,-28.7,-53.8,-34.4
DATA -58.4,-33.9,-56.7,-36.4,-57.7,-38.2,-62.3,-38.8,-62.1,-40.7,-65.1,-41.1
DATA -63.5,-42.6,-67.3,-45.6,-65.6,-47.2,-69.1,-50.7,-68.1,-52.3,-71.4,-53.9
DATA -74.9,-52.3
DATA 13
DATA -77.9,7.2,-77.1,3.8,-80.9,-1.1,-79.8,-2.7,-81.2,-6.1,-76.0,-14.6
DATA -70.2,-19.8,-74.3,-43.2,-72.7,-42.4,-75.6,-46.6,-74.1,-46.9,-75.6,-48.7
DATA -74.9,-52.3
DATA 6
DATA -74.7,-52.8,-71.1,-54.1,-68.6,-52.6,-65.1,-54.7,-69.2,-55.5,-74.7,-52.8
DATA 3
DATA 44.8,80.6,51.5,80.7,44.8,80.6
DATA 8
DATA 53.5,73.7,61.2,76.3,68.9,76.5,58.5,74.3,55.4,72.4,57.5,70.7
DATA 51.6,71.5,53.5,73.7
DATA 3
DATA 27.4,80.1,17.4,80.3,27.4,80.1
DATA 3
DATA 24.7,77.9,20.7,77.7,24.7,77.9
DATA 5
DATA 15.1,79.7,21.5,79.0,15.9,76.8,10.4,79.7,15.1,79.7
DATA 95
DATA -77.9,7.2,-79.1,9.0,-80.4,7.3,-83.5,8.4,-87.5,13.3,-103.5,18.3
DATA -113.9,31.6,-114.7,30.2,-109.4,23.4,-112.2,24.7,-117.3,33.0,-120.6,34.6
DATA -124.4,40.3,-124.7,48.2,-122.6,47.1,-122.8,49.0,-127.4,50.8,-134.1,58.1
DATA -147.1,60.9,-151.7,59.2,-150.6,61.3,-158.4,56.0,-164.8,54.4,-157.0,58.9
DATA -162.0,58.7,-166.1,61.5,-160.8,64.8,-168.1,65.7,-161.7,66.1,-166.8,68.4
DATA -156.6,71.4,-136.5,68.9,-128.1,70.5,-108.9,67.4,-106.2,68.8,-101.5,67.6
DATA -97.7,68.6,-96.1,67.3,-94.2,69.1,-96.5,70.1,-95.2,71.9,-87.4,67.2
DATA -85.5,69.9,-81.3,69.2,-81.4,67.1,-85.8,66.6,-94.2,60.9,-94.7,58.9
DATA -92.3,57.1,-82.3,55.1,-79.9,51.2,-78.6,52.6,-79.8,54.7,-76.5,56.5
DATA -78.5,58.8,-77.3,59.9,-78.1,62.3,-73.8,62.4,-69.6,61.1,-67.6,58.2
DATA -64.6,60.3,-61.8,56.3,-57.3,54.6,-55.7,52.1,-60.0,50.2,-66.4,50.2
DATA -71.1,46.8,-65.1,49.2,-64.5,46.2,-60.5,47.0,-59.8,45.9,-65.4,43.5
DATA -66.2,44.5,-64.4,45.3,-67.1,45.1,-70.6,43.1,-70.0,41.6,-75.5,39.5
DATA -75.9,37.2,-76.3,39.1,-75.7,35.6,-81.3,31.4,-80.4,25.2,-84.1,30.1
DATA -93.8,29.7,-97.1,27.8,-97.9,22.4,-95.9,18.8,-91.4,18.9,-90.3,21.0
DATA -87.1,21.5,-88.9,15.9,-83.4,15.3,-83.9,11.4,-82.5,9.6
DATA 2
DATA -82.5,9.6,-77.4,8.7
DATA 6
DATA -71.7,19.7,-68.3,18.6,-73.9,18.0,-72.3,18.7,-73.2,19.9,-71.7,19.7
DATA 4
DATA 14.8,38.1,15.1,36.6,12.4,37.6,14.8,38.1
DATA 2
DATA 37.5,44.7,40.0,43.4
DATA 109
DATA -16.3,19.1,-17.0,21.9,-14.4,26.3,-9.6,29.9,-9.3,32.6,-5.9,35.8
DATA 9.5,37.3,11.1,36.9,10.3,33.8,19.1,30.3,21.5,32.8,33.8,31.0
DATA 36.2,36.7,27.6,36.7,26.2,39.5,33.5,42.0,41.6,41.5,36.7,45.2
DATA 39.1,47.3,35.0,46.3,36.3,45.1,33.9,44.4,32.5,45.3,33.3,46.1
DATA 30.7,46.6,27.7,42.6,28.8,41.1,22.6,40.3,24.0,37.7,22.5,36.4
DATA 19.5,41.7,13.1,45.7,12.6,44.1,18.5,40.2,16.9,40.4,16.1,38.0
DATA 15.4,40.0,8.9,44.4,3.1,43.1,-2.1,36.7,-8.9,36.9,-9.4,43.0
DATA -1.4,44.0,-1.2,46.0,-4.6,48.7,-1.6,48.6,-1.9,49.8,8.1,53.5
DATA 8.5,57.1,10.6,57.7,9.6,55.5,10.9,54.0,19.7,54.4,21.6,57.4
DATA 24.1,57.0,23.3,59.2,29.1,60.0,21.3,60.7,21.5,63.2,25.4,65.1
DATA 23.9,66.0,17.8,62.7,17.1,61.3,18.8,60.1,15.9,56.1,12.9,55.4
DATA 10.4,59.5,5.7,58.6,5.0,62.0,19.2,69.8,28.2,71.2,40.3,67.9
DATA 41.1,66.8,40.0,66.3,33.2,66.6,37.0,63.8,37.2,65.1,43.9,66.1
DATA 43.5,68.6,46.3,68.2,46.3,66.7,53.7,68.9,59.9,68.3,60.6,69.8
DATA 68.5,68.1,66.7,71.0,69.9,73.0,72.8,72.2,71.8,71.4,73.7,68.4
DATA 71.3,66.3,72.4,66.2,75.1,67.8,73.1,71.4,74.7,72.8,76.4,71.2
DATA 81.5,71.7,80.5,73.6,104.4,77.7,114.1,75.8,109.4,74.2,127.0,73.6
DATA 131.3,70.8,139.9,71.5,139.1,72.4,140.5,72.8,159.0,70.9,160.9,69.4
DATA 180.0,69.0
DATA 95
DATA 180.0,65.0,177.4,64.6,179.2,62.3,170.3,59.9,163.5,59.9,162.0,58.2
DATA 163.2,57.6,162.1,54.9,156.8,51.0,155.9,56.8,164.5,62.6,160.1,60.5
DATA 156.7,61.4,154.2,59.8,155.0,59.1,142.2,59.0,135.1,54.7,139.9,54.2
DATA 141.4,52.2,138.2,46.3,127.5,39.8,129.1,35.1,126.5,34.4,125.3,39.6
DATA 121.1,38.9,121.6,40.9,118.0,39.2,118.9,37.4,122.4,37.5,119.2,34.9
DATA 121.9,31.7,121.7,28.2,115.9,22.8,110.4,20.3,108.5,21.7,105.9,19.8
DATA 109.3,13.4,109.2,11.7,105.2,8.6,100.1,13.4,99.2,9.2,103.0,5.5
DATA 104.2,1.3,101.4,2.8,98.3,7.8,97.2,16.9,94.2,16.0,91.4,22.8
DATA 87.0,21.5,80.3,15.9,79.9,10.4,77.5,8.0,72.6,21.4,70.5,20.9
DATA 66.4,25.4,57.4,25.7,56.5,27.1,51.5,27.9,50.1,30.1,48.0,30.0
DATA 51.8,24.0,56.4,26.4,56.8,24.2,59.8,22.3,55.3,17.2,43.5,12.6
DATA 42.6,16.8,34.9,29.5,33.9,27.6,32.4,29.9,37.5,18.6,42.7,11.7
DATA 44.6,10.4,51.1,12.0,51.0,10.6,47.7,4.2,39.2,-4.7,40.1,-16.1
DATA 34.8,-19.8,35.5,-24.1,32.6,-25.7,30.1,-31.1,25.8,-33.9,18.4,-34.1
DATA 15.2,-27.1,11.8,-18.1,13.7,-10.7,8.8,-1.1,9.4,3.7,5.9,4.3
DATA 4.3,6.3,-9.0,4.8,-16.6,12.2,-17.6,14.7,-16.3,19.1
DATA 2
DATA -177.6,68.2,-180.0,69.0
DATA 3
DATA 125.9,-8.4,123.5,-10.2,125.9,-8.4
DATA 59
DATA -180.0,-84.7,-143.1,-85.0,-153.6,-83.7,-152.9,-82.0,-156.8,-81.1,-146.4,-80.3
DATA -155.3,-79.1,-158.4,-76.9,-151.3,-77.4,-144.9,-75.2,-113.9,-73.7,-100.6,-75.3
DATA -103.7,-72.6,-76.2,-74.0,-68.9,-73.0,-67.1,-72.0,-68.5,-69.7,-67.3,-66.9
DATA -57.8,-63.3,-65.7,-68.0,-61.8,-70.7,-60.8,-73.7,-70.6,-76.6,-77.2,-76.7
DATA -73.7,-77.9,-78.0,-79.2,-58.2,-83.2,-28.5,-80.3,-35.6,-79.5,-35.3,-78.1
DATA -17.5,-75.1,-15.4,-73.1,-6.9,-70.9,27.1,-70.5,33.9,-68.5,38.6,-69.8
DATA 54.5,-65.8,61.4,-68.0,68.9,-67.9,69.7,-69.2,67.9,-71.9,69.9,-72.3
DATA 73.9,-69.9,88.0,-66.2,95.8,-67.4,102.8,-65.6,106.2,-66.9,113.6,-65.9
DATA 119.8,-67.3,135.1,-65.3,137.5,-67.0,145.5,-66.9,171.2,-71.7,163.6,-76.2
DATA 167.0,-78.8,161.8,-79.2,159.8,-80.9,169.4,-83.8,180.0,-84.7
DATA 5
DATA -180.0,69.0,-169.9,66.0,-173.0,64.3,-178.7,66.1,-180.0,65.0
DATA 3
DATA -180.0,71.5,-177.6,71.3,-180.0,70.8
DATA 3
DATA -61.2,-51.9,-57.8,-51.5,-61.2,-51.9
DATA 12
DATA 46.7,44.6,53.0,46.9,53.0,45.3,50.3,44.6,52.8,41.1,53.7,42.1
DATA 54.7,41.0,52.7,40.0,53.8,37.0,49.2,37.6,50.4,40.3,46.7,44.6
DATA 3
DATA -64.5,49.9,-61.8,49.1,-64.5,49.9
DATA 3
DATA -96.6,69.7,-99.8,69.4,-96.6,69.7
DATA 11
DATA -106.5,73.1,-101.0,70.0,-102.4,68.8,-113.3,68.5,-117.3,70.0,-112.4,70.4
DATA -119.4,71.6,-115.2,73.3,-108.2,71.7,-108.4,73.1,-106.5,73.1
DATA 3
DATA -79.8,72.8,-76.3,72.8,-79.8,72.8
DATA 3
DATA 139.9,73.4,143.6,73.2,139.9,73.4
DATA 5
DATA 138.8,76.1,145.1,75.6,139.0,74.6,137.0,75.3,138.8,76.1
DATA 4
DATA -98.6,76.6,-98.2,75.0,-102.5,75.6,-98.6,76.6
DATA 4
DATA 102.8,79.3,105.1,78.3,99.4,77.9,102.8,79.3
DATA 5
DATA 93.8,81.0,100.2,79.8,95.0,79.0,91.2,80.3,93.8,81.0
DATA 5
DATA -96.0,80.6,-92.4,81.3,-85.8,79.3,-92.9,78.3,-96.0,80.6
DATA 13
DATA -91.6,81.9,-61.9,82.6,-76.9,79.3,-75.4,78.5,-80.6,76.2,-89.5,76.5
DATA -88.3,77.9,-85.0,77.5,-88.0,78.4,-85.1,79.3,-86.9,80.3,-81.8,80.5
DATA -91.6,81.9
DATA 36
DATA -46.8,82.6,-27.1,83.5,-20.8,82.7,-31.4,82.0,-12.2,81.3,-20.0,80.2
DATA -17.7,80.1,-19.7,78.8,-18.5,77.0,-21.7,76.6,-19.4,74.3,-24.8,72.3
DATA -21.8,70.7,-25.5,71.4,-26.4,70.2,-22.3,70.1,-39.8,65.5,-44.8,60.0
DATA -51.6,63.6,-54.0,67.2,-50.9,69.9,-54.7,69.6,-54.4,70.8,-51.4,70.6
DATA -55.8,71.7,-54.7,72.6,-58.6,75.5,-68.5,76.1,-71.4,77.0,-66.8,77.4
DATA -73.3,78.0,-65.7,79.4,-68.0,80.1,-62.7,81.8,-44.5,81.7,-46.8,82.6