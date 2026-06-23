' ============================================================
'  MUTUAL - Co-visibility window finder for PicoCalc (MMBasic)
'  Enter a remote station's grid; lists the next windows when
'  BOTH your QTH and the remote station can see the satellite
'  at once, with each window's AOS-LOS, duration, and the peak
'  elevation at each end. (CardSat's mutual-window feature.)
'
'  Orbit model: secular-J2 mean elements + Kepler.
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

DIM INTEGER SW, SH
SW = MM.HRES : SH = MM.VRES
IF SH > 320 THEN SH = 320
DIM INTEGER CBG, CFG, CACC, CGRID, CWARN, COK
CBG = RGB(0, 0, 0) : CFG = RGB(255, 255, 255) : CACC = RGB(0, 200, 255)
CGRID = RGB(60, 60, 70) : CWARN = RGB(255, 220, 0) : COK = RGB(0, 220, 120)

DIM LAT1, LON1, LAT2, LON2
DIM GRID1$, GRID2$
DIM WI, WE, WO, WG, WM, WN, WJ, WA, WRD, WPD
DIM NOWJD, MINEL
DIM GX, GY, GZ, EX, EY, EZ, LEL, LAZ, LRNG
DIM INTEGER CY, CMO, CD, CH, CMI
DIM CS

CALL Setup
CALL FindWindows
CLS
PRINT "73"
END

SUB Setup
  LOCAL g$, inc, ecc, ra, ap, ma, mm, ey, emo, ed, eh, emi, es
  LOCAL ny, nmo, nd, nh, nmi
  CLS CBG
  CALL Hdr("MUTUAL setup")
  GRID1$ = Ask$("Your grid", 2, 24, "FM18LV")
  CALL Maiden(GRID1$, 1)
  GRID2$ = Ask$("Remote grid", 2, 40, "CM87XX")
  CALL Maiden(GRID2$, 2)
  inc = AskN("INC", 2, 58, 101.9899)
  ecc = AskN("ECC", 2, 70, 0.0012609)
  ra = AskN("RAAN", 2, 82, 184.6033)
  ap = AskN("ARGP", 2, 94, 124.3014)
  ma = AskN("MA", 2, 106, 247.3322)
  mm = AskN("MM", 2, 118, 12.53698149)
  TEXT 2, 134, "Epoch UTC:", "L", 7, 1, CACC
  ey = AskN("Yr", 2, 146, 2026) : emo = AskN("Mo", 2, 158, 6)
  ed = AskN("Dy", 2, 170, 20) : eh = AskN("Hr", 2, 182, 7)
  emi = AskN("Mi", 2, 194, 46) : es = AskN("Se", 2, 206, 20.6)
  CALL LoadSat(inc, ecc, ra, ap, ma, mm, FNjd(ey, emo, ed, eh, emi, es))
  TEXT 2, 222, "Now UTC:", "L", 7, 1, CACC
  ny = AskN("Yr", 2, 234, 2026) : nmo = AskN("Mo", 2, 246, 6)
  nd = AskN("Dy", 2, 258, 22) : nh = AskN("Hr", 2, 270, 0)
  nmi = AskN("Mi", 2, 282, 0)
  NOWJD = FNjd(ny, nmo, nd, nh, nmi, 0)
  MINEL = AskN("Min elev deg", 2, 300, 0) * DEG
END SUB

SUB FindWindows
  CLS CBG
  CALL Hdr("Mutual windows")
  TEXT 2, 20, GRID1$ + " <-> " + GRID2$, "L", 7, 1, CACC
  TEXT 2, 32, "DATE  WINDOW      pkA pkB Dur", "L", 7, 1, CGRID
  LOCAL stp, j, endd, aos, e1, e2, az
  LOCAL pk1, pk2
  LOCAL INTEGER inwin, nwin, yrow
  stp = 30.0 / 86400.0
  j = NOWJD : endd = NOWJD + 4.0
  inwin = 0 : nwin = 0 : yrow = 44 : pk1 = -9 : pk2 = -9
  DO WHILE j < endd AND nwin < 12
    CALL Look(j, LAT1, LON1) : e1 = LEL
    CALL Look(j, LAT2, LON2) : e2 = LEL
    IF e1 >= MINEL AND e2 >= MINEL AND inwin = 0 THEN
      aos = j : inwin = 1 : pk1 = -9 : pk2 = -9
    ENDIF
    IF inwin = 1 THEN
      CALL Look(j, LAT1, LON1) : e1 = LEL
      CALL Look(j, LAT2, LON2) : e2 = LEL
      IF e1 > pk1 THEN pk1 = e1
      IF e2 > pk2 THEN pk2 = e2
      IF NOT (e1 >= MINEL AND e2 >= MINEL) THEN
        CALL Cal(aos)
        LOCAL r$
        r$ = Z2$(CD) + "/" + Z2$(CMO) + " " + Z2$(CH) + ":" + Z2$(CMI)
        CALL Cal(j)
        r$ = r$ + "-" + Z2$(CH) + ":" + Z2$(CMI)
        r$ = r$ + " " + Pad$(STR$(INT(pk1 * RAD + 0.5)), 3)
        r$ = r$ + " " + Pad$(STR$(INT(pk2 * RAD + 0.5)), 3)
        r$ = r$ + " " + STR$(INT((j - aos) * 1440 + 0.5)) + "m"
        TEXT 2, yrow, r$, "L", 7, 1, COK
        yrow = yrow + 12
        inwin = 0 : nwin = nwin + 1
      ENDIF
    ENDIF
    j = j + stp
  LOOP
  IF nwin = 0 THEN TEXT 2, 44, "No mutual windows in 4 days.", "L", 7, 1, CWARN
  TEXT 2, SH - 12, "Press any key", "L", 7, 1, CGRID
  LOCAL d$
  d$ = WaitKey$()
END SUB

' ---- orbit core ----
SUB LoadSat(inc, ecc, ra, ap, ma, mm, ep)
  WI = inc * DEG : WE = ecc : WO = ra * DEG : WG = ap * DEG
  WM = ma * DEG : WN = mm * TWOPI / 86400.0 : WJ = ep
  WA = (MU / (WN * WN)) ^ (1.0 / 3.0)
  LOCAL p, f, ci, si
  p = WA * (1 - WE * WE) : f = 1.5 * J2C * (ERAD / p) ^ 2 * WN
  ci = COS(WI) : si = SIN(WI) : WRD = -f * ci : WPD = f * (2 - 2.5 * si * si)
END SUB

SUB Eci(j)
  LOCAL dt, m, ra, ap, ee, xo, yo, u, r, co, so, cu, su, ci, si
  dt = (j - WJ) * 86400.0
  m = WM + WN * dt : ra = WO + WRD * dt : ap = WG + WPD * dt
  m = m - TWOPI * INT(m / TWOPI)
  ee = Kepler(m, WE)
  xo = WA * (COS(ee) - WE) : yo = WA * SQR(1 - WE * WE) * SIN(ee)
  u = ATAN2S(yo, xo) + ap : r = SQR(xo * xo + yo * yo)
  co = COS(ra) : so = SIN(ra) : cu = COS(u) : su = SIN(u) : ci = COS(WI) : si = SIN(WI)
  GX = r * (co * cu - so * su * ci)
  GY = r * (so * cu + co * su * ci)
  GZ = r * (su * si)
END SUB

SUB Ecef(j)
  LOCAL g, cg, sg
  CALL Eci(j) : g = Gmst(j) : cg = COS(g) : sg = SIN(g)
  EX = cg * GX + sg * GY : EY = -sg * GX + cg * GY : EZ = GZ
END SUB

SUB Look(j, la, lo)
  LOCAL cl, sl, col, sol, ox, oy, oz, rx, ry, rz, s, e, zz, rng
  CALL Ecef(j)
  cl = COS(la) : sl = SIN(la) : col = COS(lo) : sol = SIN(lo)
  ox = ERAD * cl * col : oy = ERAD * cl * sol : oz = ERAD * sl
  rx = EX - ox : ry = EY - oy : rz = EZ - oz
  s = sl * col * rx + sl * sol * ry - cl * rz
  e = -sol * rx + col * ry
  zz = cl * col * rx + cl * sol * ry + sl * rz
  rng = SQR(rx * rx + ry * ry + rz * rz)
  LEL = ASINN(zz / rng)
  LAZ = ATAN2S(e, -s) : IF LAZ < 0 THEN LAZ = LAZ + TWOPI
  LRNG = rng
END SUB

FUNCTION FNjd(y, mo, d, h, mi, s)
  LOCAL yy, mm, a, b
  yy = y : mm = mo
  IF mm <= 2 THEN yy = yy - 1 : mm = mm + 12
  a = INT(yy / 100) : b = 2 - a + INT(a / 4)
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
    dx = (x - e * SIN(x) - m) / (1 - e * COS(x)) : x = x - dx
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

SUB Cal(j)
  LOCAL z, f, al, a, b, c, dd, e, day, secs
  j = j + 0.5 : z = INT(j) : f = j - z
  IF z < 2299161 THEN
    a = z
  ELSE
    al = INT((z - 1867216.25) / 36524.25) : a = z + 1 + al - INT(al / 4)
  ENDIF
  b = a + 1524 : c = INT((b - 122.1) / 365.25) : dd = INT(365.25 * c)
  e = INT((b - dd) / 30.6001) : day = b - dd - INT(30.6001 * e) + f
  IF e < 14 THEN CMO = e - 1 ELSE CMO = e - 13
  IF CMO > 2 THEN CY = c - 4716 ELSE CY = c - 4715
  CD = INT(day) : secs = (day - CD) * 86400.0
  CH = INT(secs / 3600) : secs = secs - CH * 3600
  CMI = INT(secs / 60) : CS = secs - CMI * 60
END SUB

SUB Maiden(g$, which AS INTEGER)
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
  IF which = 1 THEN
    LAT1 = la * DEG : LON1 = lo * DEG
  ELSE
    LAT2 = la * DEG : LON2 = lo * DEG
  ENDIF
END SUB

SUB Hdr(t$)
  BOX 0, 0, SW, 16, 1, CACC, RGB(0, 30, 45)
  TEXT 4, 2, t$, "L", 1, 1, CACC
END SUB

FUNCTION WaitKey$()
  LOCAL k$
  DO
    k$ = INKEY$
  LOOP UNTIL k$ <> ""
  WaitKey$ = k$
END FUNCTION

FUNCTION Ask$(label$, x AS INTEGER, y AS INTEGER, dflt$)
  LOCAL s$, c$
  LOCAL INTEGER done
  s$ = "" : done = 0
  DO
    BOX x, y, SW - x - 2, 11, 1, CBG, CBG
    TEXT x, y, label$ + "(" + dflt$ + "):" + s$ + "_", "L", 7, 1, CFG
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
  IF LEN(s$) = 0 THEN s$ = dflt$
  BOX x, y, SW - x - 2, 11, 1, CBG, CBG
  TEXT x, y, label$ + ": " + s$, "L", 7, 1, RGB(0, 220, 120)
  Ask$ = s$
END FUNCTION

FUNCTION AskN(label$, x AS INTEGER, y AS INTEGER, dflt)
  AskN = VAL(Ask$(label$, x, y, STR$(dflt)))
END FUNCTION

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
