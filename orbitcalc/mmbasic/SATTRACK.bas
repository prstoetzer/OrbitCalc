' ============================================================
'  SATTRACK - Graphical Satellite Pass Predictor for PicoCalc
'  MMBasic (PicoMite) for the ClockworkPi PicoCalc (320x320 LCD)
'
'  Features:
'    1) Set location, date and time (UTC)
'    2) Enter / edit / save up to 20 satellites' elements
'    3) Next 10 passes of one satellite (list)
'    4) Next/current pass polar plot of one satellite
'    5) Next 3 passes of ALL satellites, sorted by time
'    6) World map: your location + footprints of all sats
'
'  Orbit model: secular-J2 mean-element propagation + Kepler.
'  Elements are the AMSAT daily-bulletin / GP fields.
'
'  Files (SD card, drive B:):
'    B:/sats.dat   - saved satellite elements
'    B:/loc.dat    - saved observer location
' ============================================================

OPTION EXPLICIT
OPTION DEFAULT FLOAT

' ---- math constants ----
CONST PI = 3.1415926535898
CONST TWOPI = 6.2831853071796
CONST DEG = PI / 180.0
CONST RAD = 180.0 / PI
CONST MU = 398600.4418
CONST ERAD = 6378.137
CONST J2C = 1.08262668E-3
CONST MAXSAT = 20

' ---- display geometry (read at runtime) ----
DIM SH
DIM INTEGER SW
SW = MM.HRES
SH = MM.VRES
' PicoCalc physical panel is 320x320; clamp working height
IF SH > 320 THEN SH = 320

' ---- colours ----
DIM CFG, CACC, CGRID, CSAT, CWARN, CFOOT, CLAND
DIM INTEGER CBG
CBG = RGB(0, 0, 0)
CFG = RGB(255, 255, 255)
CACC = RGB(0, 200, 255)
CGRID = RGB(60, 60, 60)
CSAT = RGB(255, 80, 80)
CWARN = RGB(255, 220, 0)
CFOOT = RGB(0, 220, 120)
CLAND = RGB(40, 90, 160)

' ---- observer state ----
DIM OBLAT, OBLON          ' radians
DIM OBGRID$
DIM NMO, ND, NH, NMI   ' current UTC date/time
DIM INTEGER NY
DIM NOWJD

' ---- satellite store ----
DIM NSAT INTEGER
DIM SATNAME$(MAXSAT)
DIM SINC(MAXSAT), SECC(MAXSAT), SRAAN(MAXSAT)
DIM SARGP(MAXSAT), SMA(MAXSAT), SMM(MAXSAT), SEPJD(MAXSAT)

' ---- working orbit (the "loaded" satellite) ----
DIM WI, WE, WO, WG, WM, WN, WJ, WA, WRD, WPD

' ---- propagation outputs ----
DIM GX, GY, GZ, EX, EY, EZ, BLAT, BLON, LEL, LAZ, LRNG
' ---- calendar outputs ----
DIM CMO, CD, CH, CMI
DIM INTEGER CY
DIM CS

DIM DUMMY$
NSAT = 0
OBLAT = 38.9 * DEG
OBLON = -77.0 * DEG
OBGRID$ = "FM18LV"
NY = 2026 : NMO = 6 : ND = 22 : NH = 0 : NMI = 0

CALL LoadLoc
CALL LoadSats
CALL MainMenu
END

' ============================================================
'  MENU SYSTEM
' ============================================================
SUB MainMenu
  LOCAL sel
  LOCAL INTEGER k
  sel = 1
  DO
    CALL DrawMenu(sel)
    k = ASC(UCASE$(WaitKey$()))
    IF k = 128 THEN sel = sel - 1     ' up arrow
    IF k = 129 THEN sel = sel + 1     ' down arrow
    IF sel < 1 THEN sel = 6
    IF sel > 6 THEN sel = 1
    IF k = 13 THEN CALL RunItem(sel)  ' enter
    IF k >= 49 AND k <= 54 THEN CALL RunItem(k - 48)  ' 1..6
  LOOP UNTIL k = 27                    ' ESC quits
  CLS
  PRINT "Bye."
END SUB

SUB DrawMenu(sel AS INTEGER)
  LOCAL y
  LOCAL INTEGER i
  CLS CBG
  CALL Header("SATTRACK  -  PicoCalc")
  CALL StatusLine
  LOCAL m$(6)
  m$(1) = "1 Set location / date / time"
  m$(2) = "2 Edit satellites (" + STR$(NSAT) + ")"
  m$(3) = "3 Next 10 passes (one sat)"
  m$(4) = "4 Polar plot (one sat)"
  m$(5) = "5 Next 3 passes (all sats)"
  m$(6) = "6 World map + footprints"
  y = 70
  FOR i = 1 TO 6
    IF i = sel THEN
      BOX 6, y - 2, SW - 12, 16, 1, CACC, RGB(0, 40, 60)
      TEXT 12, y, m$(i), "L", 1, 1, CFG
    ELSE
      TEXT 12, y, m$(i), "L", 1, 1, CFG
    ENDIF
    y = y + 22
  NEXT i
  TEXT 6, SH - 14, "Up/Dn + Enter, or 1-6. ESC quits", "L", 7, 1, CGRID
END SUB

SUB Header(t$)
  BOX 0, 0, SW, 18, 1, CACC, RGB(0, 30, 45)
  TEXT 4, 3, t$, "L", 1, 1, CACC
END SUB

SUB StatusLine
  LOCAL s$
  s$ = "Grid " + OBGRID$ + "  " + Z2$(NH) + ":" + Z2$(NMI) + "Z " + Z2$(ND) + "/" + Z2$(NMO)
  TEXT 4, 22, s$, "L", 7, 1, CWARN
  TEXT 4, 36, "Sats loaded: " + STR$(NSAT), "L", 7, 1, CFOOT
END SUB

SUB RunItem(n AS INTEGER)
  SELECT CASE n
    CASE 1 : CALL SetLocation
    CASE 2 : CALL EditSats
    CASE 3 : CALL Next10
    CASE 4 : CALL PolarPlot
    CASE 5 : CALL AllNext3
    CASE 6 : CALL WorldMap
  END SELECT
END SUB

' ============================================================
'  1) LOCATION / DATE / TIME
' ============================================================
SUB SetLocation
  LOCAL g$, a$, la, lo
  CLS CBG
  CALL Header("Set Location / Time")
  TEXT 4, 26, "Maidenhead grid (blank=lat/lon):", "L", 7, 1, CFG
  g$ = AskStr$("Grid", 6, 44)
  IF LEN(g$) >= 4 THEN
    CALL Maiden(g$)
    OBGRID$ = UCASE$(g$)
  ELSE
    la = AskNum("Lat +N", 6, 64)
    lo = AskNum("Lon +E", 6, 84)
    OBLAT = la * DEG
    OBLON = lo * DEG
    OBGRID$ = GridFromLL$(OBLAT, OBLON)
  ENDIF
  TEXT 4, 110, "UTC date/time:", "L", 7, 1, CACC
  NY = AskNum("Year", 6, 128)
  NMO = AskNum("Month", 6, 146)
  ND = AskNum("Day", 6, 164)
  NH = AskNum("Hour", 6, 182)
  NMI = AskNum("Min", 6, 200)
  NOWJD = FNjd(NY, NMO, ND, NH, NMI, 0)
  CALL SaveLoc
  CALL Flash("Saved.")
END SUB

' ============================================================
'  2) EDIT / ENTER SATELLITES
' ============================================================
SUB EditSats
  LOCAL sel
  LOCAL INTEGER k
  sel = 1
  DO
    CLS CBG
    CALL Header("Satellites  (" + STR$(NSAT) + "/" + STR$(MAXSAT) + ")")
    LOCAL y
    LOCAL INTEGER i
    y = 24
    IF NSAT = 0 THEN TEXT 6, y, "(none yet)", "L", 7, 1, CGRID
    FOR i = 1 TO NSAT
      IF i = sel THEN
        BOX 4, y - 1, SW - 8, 13, 1, CACC, RGB(0, 35, 50)
      ENDIF
      TEXT 8, y, Z2$(i) + " " + SATNAME$(i), "L", 7, 1, CFG
      y = y + 14
      IF y > SH - 60 THEN i = NSAT
    NEXT i
    TEXT 4, SH - 52, "A=Add  E=Edit  D=Del", "L", 7, 1, CWARN
    TEXT 4, SH - 40, "Up/Dn select  ESC=back", "L", 7, 1, CWARN
    k = ASC(UCASE$(WaitKey$()))
    IF k = 128 THEN sel = sel - 1
    IF k = 129 THEN sel = sel + 1
    IF sel < 1 THEN sel = 1
    IF sel > NSAT THEN sel = NSAT
    IF NSAT = 0 THEN sel = 1
    IF k = ASC("A") THEN CALL AddSat
    IF k = ASC("E") AND NSAT > 0 THEN CALL EditOneSat(sel)
    IF k = ASC("D") AND NSAT > 0 THEN CALL DelSat(sel) : IF sel > NSAT THEN sel = NSAT
  LOOP UNTIL k = 27
END SUB

SUB AddSat
  IF NSAT >= MAXSAT THEN CALL Flash("Full (20 max)") : EXIT SUB
  NSAT = NSAT + 1
  SATNAME$(NSAT) = ""
  CALL EditOneSat(NSAT)
  IF SATNAME$(NSAT) = "" THEN NSAT = NSAT - 1   ' cancelled
END SUB

SUB EditOneSat(ix AS INTEGER)
  LOCAL nm$, ey, emo, ed, eh, emi, es
  CLS CBG
  CALL Header("Edit sat #" + STR$(ix))
  nm$ = AskStr$("Name", 6, 24)
  IF LEN(nm$) = 0 THEN nm$ = SATNAME$(ix)
  IF LEN(nm$) = 0 THEN CALL Flash("Cancelled") : EXIT SUB
  SATNAME$(ix) = UCASE$(nm$)
  SINC(ix)  = AskNum("INC", 6, 40)
  SECC(ix)  = AskNum("ECC", 6, 56)
  SRAAN(ix) = AskNum("RAAN", 6, 72)
  SARGP(ix) = AskNum("ARGP", 6, 88)
  SMA(ix)   = AskNum("MA", 6, 104)
  SMM(ix)   = AskNum("MM rev/d", 6, 120)
  TEXT 4, 140, "Epoch UTC:", "L", 7, 1, CACC
  ey  = AskNum("Yr", 6, 156)
  emo = AskNum("Mon", 6, 172)
  ed  = AskNum("Day", 6, 188)
  eh  = AskNum("Hr", 6, 204)
  emi = AskNum("Min", 6, 220)
  es  = AskNum("Sec", 6, 236)
  SEPJD(ix) = FNjd(ey, emo, ed, eh, emi, es)
  CALL SaveSats
  CALL Flash("Saved " + SATNAME$(ix))
END SUB

SUB DelSat(ix AS INTEGER)
  LOCAL INTEGER i
  FOR i = ix TO NSAT - 1
    SATNAME$(i) = SATNAME$(i + 1)
    SINC(i) = SINC(i + 1) : SECC(i) = SECC(i + 1)
    SRAAN(i) = SRAAN(i + 1) : SARGP(i) = SARGP(i + 1)
    SMA(i) = SMA(i + 1) : SMM(i) = SMM(i + 1) : SEPJD(i) = SEPJD(i + 1)
  NEXT i
  NSAT = NSAT - 1
  CALL SaveSats
END SUB

' ============================================================
'  3) NEXT 10 PASSES OF ONE SATELLITE
' ============================================================
SUB Next10
  LOCAL INTEGER ix
  ix = PickSat("Next 10 passes")
  IF ix = 0 THEN EXIT SUB
  CALL LoadSat(ix)
  CLS CBG
  CALL Header("Passes: " + SATNAME$(ix))
  TEXT 2, 20, "DATE  AOS   LOS   El AzA/T/L", "L", 7, 1, CACC
  LOCAL stp, j, endd, npass, k
  LOCAL INTEGER inpass
  LOCAL maxel, azaos, aztca, azlos, aos, los, tca
  LOCAL a0, a1, m, t0, t1, ml, mr, ell, elr
  LOCAL INTEGER yrow
  stp = 30.0 / 86400.0
  j = NOWJD : endd = NOWJD + 12.0
  inpass = 0 : npass = 0 : maxel = -9 : yrow = 32
  DO WHILE j < endd AND npass < 10
    CALL Look(j, OBLAT, OBLON)
    IF LEL >= 0 AND inpass = 0 THEN
      a0 = j - stp : a1 = j
      FOR k = 1 TO 25
        m = (a0 + a1) / 2 : CALL Look(m, OBLAT, OBLON)
        IF LEL >= 0 THEN a1 = m ELSE a0 = m
      NEXT k
      aos = a1 : CALL Look(aos, OBLAT, OBLON) : azaos = LAZ
      inpass = 1 : maxel = -9
    ENDIF
    IF inpass = 1 THEN
      CALL Look(j, OBLAT, OBLON)
      IF LEL > maxel THEN maxel = LEL : tca = j
      IF LEL < 0 THEN
        a0 = j - stp : a1 = j
        FOR k = 1 TO 25
          m = (a0 + a1) / 2 : CALL Look(m, OBLAT, OBLON)
          IF LEL >= 0 THEN a0 = m ELSE a1 = m
        NEXT k
        los = a0 : CALL Look(los, OBLAT, OBLON) : azlos = LAZ
        t0 = tca - stp : t1 = tca + stp
        FOR k = 1 TO 40
          ml = t0 + (t1 - t0) / 3 : mr = t1 - (t1 - t0) / 3
          CALL Look(ml, OBLAT, OBLON) : ell = LEL
          CALL Look(mr, OBLAT, OBLON) : elr = LEL
          IF ell < elr THEN t0 = ml ELSE t1 = mr
        NEXT k
        tca = (t0 + t1) / 2 : CALL Look(tca, OBLAT, OBLON)
        maxel = LEL : aztca = LAZ
        CALL Cal(aos)
        LOCAL r$
        r$ = Z2$(CD) + "/" + Z2$(CMO) + " " + Z2$(CH) + ":" + Z2$(CMI)
        CALL Cal(los)
        r$ = r$ + "-" + Z2$(CH) + ":" + Z2$(CMI) + " "
        r$ = r$ + STR$(INT(maxel * RAD + 0.5)) + " "
        r$ = r$ + STR$(INT(azaos * RAD + 0.5)) + "/" + STR$(INT(aztca * RAD + 0.5)) + "/" + STR$(INT(azlos * RAD + 0.5))
        TEXT 2, yrow, r$, "L", 7, 1, CFG
        yrow = yrow + 12
        inpass = 0 : npass = npass + 1
      ENDIF
    ENDIF
    j = j + stp
  LOOP
  TEXT 2, SH - 12, "Press any key", "L", 7, 1, CGRID
  DUMMY$ = WaitKey$()
END SUB

' ============================================================
'  4) POLAR PLOT OF NEXT/CURRENT PASS
' ============================================================
SUB PolarPlot
  LOCAL INTEGER ix
  ix = PickSat("Polar plot")
  IF ix = 0 THEN EXIT SUB
  CALL LoadSat(ix)
  ' find next pass (AOS,LOS); if currently in a pass start now
  LOCAL stp, j, endd, aos, los, k
  LOCAL INTEGER found
  LOCAL a0, a1, m
  stp = 30.0 / 86400.0
  j = NOWJD : endd = NOWJD + 14.0 : found = 0
  ' if already up, AOS = now
  CALL Look(j, OBLAT, OBLON)
  IF LEL >= 0 THEN
    aos = j : found = 1
  ELSE
    DO WHILE j < endd AND found = 0
      CALL Look(j, OBLAT, OBLON)
      IF LEL >= 0 THEN
        a0 = j - stp : a1 = j
        FOR k = 1 TO 25
          m = (a0 + a1) / 2 : CALL Look(m, OBLAT, OBLON)
          IF LEL >= 0 THEN a1 = m ELSE a0 = m
        NEXT k
        aos = a1 : found = 1
      ENDIF
      j = j + stp
    LOOP
  ENDIF
  IF found = 0 THEN CALL Flash("No pass in 14d") : EXIT SUB
  ' find LOS after aos
  j = aos + stp
  DO
    CALL Look(j, OBLAT, OBLON)
    j = j + stp
  LOOP UNTIL LEL < 0 OR j > aos + 0.02
  los = j
  ' draw polar frame
  CALL DrawPolarFrame(SATNAME$(ix))
  ' plot the arc, sampling between aos and los
  LOCAL t
  LOCAL INTEGER first, px, py, lx, ly
  LOCAL cx, cy, rr
  cx = SW / 2 : cy = 28 + (SH - 40) / 2 : rr = (SH - 40) / 2 - 4
  first = 1
  FOR t = aos TO los STEP (los - aos) / 60.0
    CALL Look(t, OBLAT, OBLON)
    IF LEL >= 0 THEN
      ' radius scales with co-elevation: zenith at center, horizon at edge
      LOCAL pr
      pr = rr * (1 - LEL / (PI / 2))
      px = cx + pr * SIN(LAZ)
      py = cy - pr * COS(LAZ)
      IF first = 0 THEN LINE lx, ly, px, py, 2, CSAT
      lx = px : ly = py
      first = 0
    ENDIF
  NEXT t
  ' mark AOS and current position
  CALL Look(aos, OBLAT, OBLON)
  CALL PolarDot(cx, cy, rr, LEL, LAZ, CFOOT)
  CALL Look(NOWJD, OBLAT, OBLON)
  IF LEL >= 0 THEN CALL PolarDot(cx, cy, rr, LEL, LAZ, CWARN)
  ' labels
  CALL Cal(aos)
  TEXT 2, SH - 24, "AOS " + Z2$(CH) + ":" + Z2$(CMI) + "Z", "L", 7, 1, CFOOT
  CALL Look(aos, OBLAT, OBLON)
  TEXT 90, SH - 24, "AzA " + STR$(INT(LAZ * RAD)), "L", 7, 1, CFG
  TEXT 2, SH - 12, "Press any key", "L", 7, 1, CGRID
  DUMMY$ = WaitKey$()
END SUB

SUB DrawPolarFrame(nm$)
  CLS CBG
  CALL Header("Polar: " + nm$)
  LOCAL cx, cy, rr
  LOCAL INTEGER i
  cx = SW / 2 : cy = 28 + (SH - 40) / 2 : rr = (SH - 40) / 2 - 4
  ' elevation rings: horizon, 30, 60
  CIRCLE cx, cy, rr, 1, , CGRID
  CIRCLE cx, cy, rr * 2 / 3, 1, , CGRID
  CIRCLE cx, cy, rr / 3, 1, , CGRID
  ' cross hairs
  LINE cx - rr, cy, cx + rr, cy, 1, CGRID
  LINE cx, cy - rr, cx, cy + rr, 1, CGRID
  TEXT cx, cy - rr - 10, "N", "CT", 7, 1, CACC
  TEXT cx + rr + 2, cy, "E", "LM", 7, 1, CACC
  TEXT cx, cy + rr + 2, "S", "CT", 7, 1, CACC
  TEXT cx - rr - 2, cy, "W", "RM", 7, 1, CACC
END SUB

SUB PolarDot(cx, cy, rr, el, az, col AS INTEGER)
  LOCAL pr
  LOCAL INTEGER px, py
  pr = rr * (1 - el / (PI / 2))
  px = cx + pr * SIN(az)
  py = cy - pr * COS(az)
  CIRCLE px, py, 3, 1, , col, col
END SUB

' ============================================================
'  5) NEXT 3 PASSES OF ALL SATS, SORTED BY TIME
' ============================================================
SUB AllNext3
  IF NSAT = 0 THEN CALL Flash("No sats") : EXIT SUB
  LOCAL maxrows
  LOCAL INTEGER cnt
  maxrows = NSAT * 3
  LOCAL pAOS(maxrows), pMEL(maxrows)
  LOCAL INTEGER pIX(maxrows)
  cnt = 0
  LOCAL np
  LOCAL INTEGER s
  FOR s = 1 TO NSAT
    CALL LoadSat(s)
    LOCAL stp, j, endd, k
    LOCAL INTEGER inpass
    LOCAL maxel, aos, a0, a1, m
    stp = 30.0 / 86400.0
    j = NOWJD : endd = NOWJD + 7.0
    inpass = 0 : np = 0 : maxel = -9
    DO WHILE j < endd AND np < 3
      CALL Look(j, OBLAT, OBLON)
      IF LEL >= 0 AND inpass = 0 THEN
        a0 = j - stp : a1 = j
        FOR k = 1 TO 22
          m = (a0 + a1) / 2 : CALL Look(m, OBLAT, OBLON)
          IF LEL >= 0 THEN a1 = m ELSE a0 = m
        NEXT k
        aos = a1 : inpass = 1 : maxel = -9
      ENDIF
      IF inpass = 1 THEN
        CALL Look(j, OBLAT, OBLON)
        IF LEL > maxel THEN maxel = LEL
        IF LEL < 0 THEN
          cnt = cnt + 1
          pAOS(cnt) = aos : pMEL(cnt) = maxel : pIX(cnt) = s
          inpass = 0 : np = np + 1
        ENDIF
      ENDIF
      j = j + stp
    LOOP
  NEXT s
  ' sort by AOS (simple insertion sort)
  LOCAL jj
  LOCAL INTEGER i
  LOCAL ta, tm
  LOCAL INTEGER ti
  FOR i = 2 TO cnt
    ta = pAOS(i) : tm = pMEL(i) : ti = pIX(i) : jj = i - 1
    DO WHILE jj >= 1 AND pAOS(jj) > ta
      pAOS(jj + 1) = pAOS(jj) : pMEL(jj + 1) = pMEL(jj) : pIX(jj + 1) = pIX(jj)
      jj = jj - 1
    LOOP
    pAOS(jj + 1) = ta : pMEL(jj + 1) = tm : pIX(jj + 1) = ti
  NEXT i
  ' display (paged)
  LOCAL page, perpage, startr
  LOCAL INTEGER row
  perpage = INT((SH - 46) / 12)
  page = 0
  DO
    CLS CBG
    CALL Header("All sats - next passes")
    TEXT 2, 20, "DATE  AOS  MaxEl  SAT", "L", 7, 1, CACC
    startr = page * perpage
    row = 32
    FOR i = startr + 1 TO startr + perpage
      IF i <= cnt THEN
        CALL Cal(pAOS(i))
        LOCAL r$
        r$ = Z2$(CD) + "/" + Z2$(CMO) + " " + Z2$(CH) + ":" + Z2$(CMI)
        r$ = r$ + "  " + Pad$(STR$(INT(pMEL(i) * RAD + 0.5)), 3) + "  " + SATNAME$(pIX(i))
        TEXT 2, row, r$, "L", 7, 1, CFG
        row = row + 12
      ENDIF
    NEXT i
    TEXT 2, SH - 12, "SPACE=more  ESC=back", "L", 7, 1, CGRID
    LOCAL kk
    kk = ASC(WaitKey$())
    IF kk = 32 THEN page = page + 1
    IF (page * perpage) >= cnt THEN page = 0
  LOOP UNTIL kk = 27
END SUB

' ============================================================
'  6) WORLD MAP + FOOTPRINTS
' ============================================================
SUB WorldMap
  IF NSAT = 0 THEN CALL Flash("No sats") : EXIT SUB
  LOCAL mapy, mapw, maph
  LOCAL INTEGER mapx
  mapx = 0 : mapy = 20 : mapw = SW : maph = SH - 40
  LOCAL toff
  toff = 0.0
  LOCAL kk
  DO
    CALL DrawMapBase(mapx, mapy, mapw, maph)
    ' observer marker
    CALL PlotMapPt(mapx, mapy, mapw, maph, OBLAT, OBLON, CWARN, 1)
    ' each satellite: subpoint + footprint
    LOCAL INTEGER s
    LOCAL jj
    jj = NOWJD + toff / 1440.0
    FOR s = 1 TO NSAT
      CALL LoadSat(s)
      CALL SubPt(jj)
      CALL PlotMapPt(mapx, mapy, mapw, maph, BLAT, BLON, CSAT, 0)
      CALL Footprint(mapx, mapy, mapw, maph, jj, s)
    NEXT s
    TEXT 2, 22, "T+" + STR$(INT(toff)) + "m", "L", 7, 1, CACC
    TEXT 2, SH - 12, "SPACE=step ENTER=auto ESC=back", "L", 7, 1, CGRID
    kk = ASC(WaitKey$())
    IF kk = 32 THEN toff = toff + 5
    IF kk = 13 THEN CALL AutoMap(mapx, mapy, mapw, maph)
  LOOP UNTIL kk = 27
END SUB

SUB AutoMap(mapx AS INTEGER, mapy AS INTEGER, mapw AS INTEGER, maph AS INTEGER)
  LOCAL toff, kk$
  toff = 0
  DO
    CALL DrawMapBase(mapx, mapy, mapw, maph)
    CALL PlotMapPt(mapx, mapy, mapw, maph, OBLAT, OBLON, CWARN, 1)
    LOCAL INTEGER s
    LOCAL jj
    jj = NOWJD + toff / 1440.0
    FOR s = 1 TO NSAT
      CALL LoadSat(s)
      CALL SubPt(jj)
      CALL PlotMapPt(mapx, mapy, mapw, maph, BLAT, BLON, CSAT, 0)
      CALL Footprint(mapx, mapy, mapw, maph, jj, s)
    NEXT s
    TEXT 2, 22, "AUTO T+" + STR$(INT(toff)) + "m  (key=stop)", "L", 7, 1, CACC
    toff = toff + 2
    PAUSE 300
    kk$ = INKEY$
  LOOP UNTIL kk$ <> ""
END SUB

SUB DrawMapBase(mapx AS INTEGER, mapy AS INTEGER, mapw AS INTEGER, maph AS INTEGER)
  CLS CBG
  CALL Header("World Map + Footprints")
  ' ocean panel
  BOX mapx, mapy, mapw, maph, 1, CGRID, RGB(0, 0, 30)
  ' equator and prime meridian
  LOCAL ex
  LOCAL INTEGER ey
  ey = mapy + maph / 2
  LINE mapx, ey, mapx + mapw, ey, 1, CGRID
  ex = mapx + mapw / 2
  LINE ex, mapy, ex, mapy + maph, 1, CGRID
  ' coarse coastline boxes (very simplified continents)
  CALL Continents(mapx, mapy, mapw, maph)
END SUB

SUB Continents(mx AS INTEGER, my AS INTEGER, mw AS INTEGER, mh AS INTEGER)
  ' Draw a handful of filled rectangles approximating land masses,
  ' positioned by lon(-180..180)->x, lat(90..-90)->y.
  ' Data: lon1,lat1,lon2,lat2 (deg) as rough bounding boxes.
  LOCAL nb
  LOCAL INTEGER i
  LOCAL lonA(12), latA(12), lonB(12), latB(12)
  ' N America
  lonA(1)=-168:latA(1)=72:lonB(1)=-52:latB(1)=15
  ' S America
  lonA(2)=-82:latA(2)=12:lonB(2)=-34:latB(2)=-55
  ' Africa
  lonA(3)=-18:latA(3)=37:lonB(3)=52:latB(3)=-35
  ' Europe
  lonA(4)=-10:latA(4)=71:lonB(4)=40:latB(4)=37
  ' Asia
  lonA(5)=40:latA(5)=75:lonB(5)=180:latB(5)=8
  ' Australia
  lonA(6)=112:latA(6)=-10:lonB(6)=154:latB(6)=-39
  ' Greenland
  lonA(7)=-55:latA(7)=83:lonB(7)=-12:latB(7)=60
  nb = 7
  FOR i = 1 TO nb
    LOCAL y1, x2, y2
    LOCAL INTEGER x1
    x1 = mx + (lonA(i) + 180) / 360 * mw
    x2 = mx + (lonB(i) + 180) / 360 * mw
    y1 = my + (90 - latA(i)) / 180 * mh
    y2 = my + (90 - latB(i)) / 180 * mh
    BOX x1, y1, x2 - x1, y2 - y1, 1, CLAND, CLAND
  NEXT i
END SUB

SUB PlotMapPt(mx AS INTEGER, my AS INTEGER, mw AS INTEGER, mh AS INTEGER, la, lo, col AS INTEGER, big AS INTEGER)
  LOCAL py
  LOCAL INTEGER px
  px = mx + (lo * RAD + 180) / 360 * mw
  py = my + (90 - la * RAD) / 180 * mh
  IF big = 1 THEN
    LINE px - 4, py, px + 4, py, 1, col
    LINE px, py - 4, px, py + 4, 1, col
  ELSE
    CIRCLE px, py, 2, 1, , col, col
  ENDIF
END SUB

SUB Footprint(mx AS INTEGER, my AS INTEGER, mw AS INTEGER, mh AS INTEGER, j, ix AS INTEGER)
  ' footprint radius (great-circle) from altitude: cos(rho)=Re/(Re+h)
  ' h from semi-major axis of loaded sat (WA) minus Re (approx circular)
  LOCAL h, rho
  LOCAL INTEGER n, i
  LOCAL clat, clon
  CALL SubPt(j)
  clat = BLAT : clon = BLON
  h = WA - ERAD
  rho = ACOSS(ERAD / (ERAD + h))      ' Earth central angle to horizon
  ' draw ring of points at angular distance rho around subpoint
  LOCAL az, dlat, dlon
  LOCAL INTEGER px, py, first, lx, ly
  first = 1
  FOR i = 0 TO 36
    az = i * 10 * DEG
    ' destination point given start (clat,clon), bearing az, angular dist rho
    dlat = ASINN(SIN(clat) * COS(rho) + COS(clat) * SIN(rho) * COS(az))
    dlon = clon + ATAN2S(SIN(az) * SIN(rho) * COS(clat), COS(rho) - SIN(clat) * SIN(dlat))
    px = mx + (WrapDeg(dlon * RAD) + 180) / 360 * mw
    py = my + (90 - dlat * RAD) / 180 * mh
    IF first = 0 THEN
      ' avoid drawing the long wrap line across the map
      IF ABS(px - lx) < mw / 2 THEN LINE lx, ly, px, py, 1, CFOOT
    ENDIF
    lx = px : ly = py : first = 0
  NEXT i
END SUB

' ============================================================
'  ORBIT MODEL
' ============================================================
SUB LoadSat(ix AS INTEGER)
  WI = SINC(ix) * DEG
  WE = SECC(ix)
  WO = SRAAN(ix) * DEG
  WG = SARGP(ix) * DEG
  WM = SMA(ix) * DEG
  WN = SMM(ix) * TWOPI / 86400.0
  WJ = SEPJD(ix)
  WA = (MU / (WN * WN)) ^ (1.0 / 3.0)
  LOCAL p, f, ci, si
  p = WA * (1 - WE * WE)
  f = 1.5 * J2C * (ERAD / p) ^ 2 * WN
  ci = COS(WI) : si = SIN(WI)
  WRD = -f * ci
  WPD = f * (2 - 2.5 * si * si)
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
  FOR k = 1 TO 50
    dx = (x - e * SIN(x) - m) / (1 - e * COS(x))
    x = x - dx
    IF ABS(dx) < 1E-12 THEN EXIT FOR
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

' ============================================================
'  MAIDENHEAD
' ============================================================
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

FUNCTION GridFromLL$(la, lo)
  LOCAL alo, ala
  LOCAL INTEGER a, b, c, d
  alo = lo * RAD + 180
  ala = la * RAD + 90
  a = INT(alo / 20)
  b = INT(ala / 10)
  c = INT((alo - a * 20) / 2)
  d = INT(ala - b * 10)
  GridFromLL$ = CHR$(65 + a) + CHR$(65 + b) + STR$(c) + STR$(d)
END FUNCTION

' ============================================================
'  FILE I/O
' ============================================================
SUB SaveSats
  LOCAL f
  LOCAL INTEGER i
  f = 1
  ON ERROR SKIP
  OPEN "B:/sats.dat" FOR OUTPUT AS #f
  PRINT #f, NSAT
  FOR i = 1 TO NSAT
    PRINT #f, SATNAME$(i)
    PRINT #f, STR$(SINC(i)) + "," + STR$(SECC(i)) + "," + STR$(SRAAN(i)) + "," + STR$(SARGP(i)) + "," + STR$(SMA(i)) + "," + STR$(SMM(i)) + "," + STR$(SEPJD(i))
  NEXT i
  CLOSE #f
END SUB

SUB LoadSats
  LOCAL f
  LOCAL INTEGER i
  LOCAL l$
  IF MM.INFO(EXISTS FILE "B:/sats.dat") = 0 THEN EXIT SUB
  f = 1
  OPEN "B:/sats.dat" FOR INPUT AS #f
  LINE INPUT #f, l$ : NSAT = VAL(l$)
  IF NSAT > MAXSAT THEN NSAT = MAXSAT
  FOR i = 1 TO NSAT
    LINE INPUT #f, SATNAME$(i)
    LINE INPUT #f, l$
    SINC(i)  = VAL(FIELD$(l$, 1, ","))
    SECC(i)  = VAL(FIELD$(l$, 2, ","))
    SRAAN(i) = VAL(FIELD$(l$, 3, ","))
    SARGP(i) = VAL(FIELD$(l$, 4, ","))
    SMA(i)   = VAL(FIELD$(l$, 5, ","))
    SMM(i)   = VAL(FIELD$(l$, 6, ","))
    SEPJD(i) = VAL(FIELD$(l$, 7, ","))
  NEXT i
  CLOSE #f
END SUB

SUB SaveLoc
  LOCAL INTEGER f
  f = 1
  ON ERROR SKIP
  OPEN "B:/loc.dat" FOR OUTPUT AS #f
  PRINT #f, OBGRID$
  PRINT #f, STR$(OBLAT) + "," + STR$(OBLON)
  PRINT #f, STR$(NY) + "," + STR$(NMO) + "," + STR$(ND) + "," + STR$(NH) + "," + STR$(NMI)
  CLOSE #f
END SUB

SUB LoadLoc
  LOCAL INTEGER f
  LOCAL l$
  IF MM.INFO(EXISTS FILE "B:/loc.dat") = 0 THEN EXIT SUB
  f = 1
  OPEN "B:/loc.dat" FOR INPUT AS #f
  LINE INPUT #f, OBGRID$
  LINE INPUT #f, l$
  OBLAT = VAL(FIELD$(l$, 1, ","))
  OBLON = VAL(FIELD$(l$, 2, ","))
  LINE INPUT #f, l$
  NY  = VAL(FIELD$(l$, 1, ","))
  NMO = VAL(FIELD$(l$, 2, ","))
  ND  = VAL(FIELD$(l$, 3, ","))
  NH  = VAL(FIELD$(l$, 4, ","))
  NMI = VAL(FIELD$(l$, 5, ","))
  CLOSE #f
  NOWJD = FNjd(NY, NMO, ND, NH, NMI, 0)
END SUB

' ============================================================
'  UI HELPERS
' ============================================================
FUNCTION PickSat(title$)
  LOCAL k
  LOCAL INTEGER sel
  IF NSAT = 0 THEN CALL Flash("No sats") : PickSat = 0 : EXIT FUNCTION
  sel = 1
  DO
    CLS CBG
    CALL Header(title$)
    TEXT 4, 22, "Select satellite:", "L", 7, 1, CACC
    LOCAL y
    LOCAL INTEGER i
    y = 38
    FOR i = 1 TO NSAT
      IF i = sel THEN BOX 4, y - 1, SW - 8, 13, 1, CACC, RGB(0, 35, 50)
      TEXT 8, y, Z2$(i) + " " + SATNAME$(i), "L", 7, 1, CFG
      y = y + 14
    NEXT i
    TEXT 4, SH - 12, "Up/Dn Enter  ESC=cancel", "L", 7, 1, CGRID
    k = ASC(WaitKey$())
    IF k = 128 THEN sel = sel - 1
    IF k = 129 THEN sel = sel + 1
    IF sel < 1 THEN sel = NSAT
    IF sel > NSAT THEN sel = 1
    IF k = 13 THEN PickSat = sel : EXIT FUNCTION
  LOOP UNTIL k = 27
  PickSat = 0
END FUNCTION

FUNCTION AskNum(label$, x AS INTEGER, y AS INTEGER)
  LOCAL s$
  s$ = AskStr$(label$, x, y)
  AskNum = VAL(s$)
END FUNCTION

FUNCTION AskStr$(label$, x AS INTEGER, y AS INTEGER)
  LOCAL s$, c$
  LOCAL INTEGER done
  s$ = ""
  done = 0
  DO
    BOX x, y, SW - x - 4, 12, 1, CBG, CBG
    TEXT x, y, label$ + ": " + s$ + "_", "L", 7, 1, CFG
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
  BOX x, y, SW - x - 4, 12, 1, CBG, CBG
  TEXT x, y, label$ + ": " + s$, "L", 7, 1, CFOOT
  AskStr$ = s$
END FUNCTION

FUNCTION WaitKey$()
  LOCAL k$
  DO
    k$ = INKEY$
  LOOP UNTIL k$ <> ""
  WaitKey$ = k$
END FUNCTION

SUB Flash(msg$)
  LOCAL INTEGER w
  w = LEN(msg$) * 8 + 16
  BOX (SW - w) / 2, SH / 2 - 10, w, 20, 1, CWARN, RGB(40, 30, 0)
  TEXT SW / 2, SH / 2, msg$, "CM", 1, 1, CWARN
  PAUSE 700
END SUB

FUNCTION Z2$(n AS INTEGER)
  IF n < 10 THEN Z2$ = "0" + STR$(n) ELSE Z2$ = STR$(n)
END FUNCTION

FUNCTION Pad$(s$, n AS INTEGER)
  LOCAL r$
  r$ = s$
  DO WHILE LEN(r$) < n
    r$ = " " + r$
  LOOP
  Pad$ = r$
END FUNCTION

FUNCTION WrapDeg(d)
  LOCAL v
  v = d
  DO WHILE v > 180 : v = v - 360 : LOOP
  DO WHILE v <= -180 : v = v + 360 : LOOP
  WrapDeg = v
END FUNCTION
