' POINTING - Az/El step table for the next pass (PicoCalc / MMBasic)
' Hand-track a rotator or aim a beam. Text table to the console.
' Orbit model: secular-J2 mean elements + Kepler (shared core).
OPTION EXPLICIT
OPTION DEFAULT FLOAT
CONST PI = 3.1415926535898
CONST TWOPI = 6.2831853071796
CONST DEG = PI / 180.0
CONST RAD = 180.0 / PI
CONST MU = 398600.4418
CONST ERAD = 6378.137
CONST J2C = 1.08262668E-3

DIM OBLAT, OBLON
DIM WI, WE, WO, WG, WM, WN, WJ, WA, WRD, WPD
DIM GX, GY, GZ, EX, EY, EZ, LEL, LAZ, LRNG
DIM CMO, CD, CH, CMI, CS
DIM INTEGER CY
DIM PAOS, PLOS, PTCA, PMEL
' SKYTRACK - graphical polar sky chart of a pass (PicoCalc / MMBasic).
' Plots the pass arc on an Az/El polar plot: horizon ring, 30/60 rings,
' N/E/S/W, and AOS/TCA/LOS marks. Uses the PicoCalc LCD.
DIM SW, SH, cx, cy, rr
DIM t, el, az, pr2, px, py, lx, ly, ang
DIM INTEGER kk, firstp
DIM CBG, CFG, CGRID, CARC, CMARK
PRINT "SKYTRACK - polar sky chart"
DIM g$, inc, ecc, ra, ap, ma, mm
DIM ey, emo, ed, eh, emi, es
DIM ny, nmo, nd, nh, nmi
INPUT "Grid [FM18LV] "; g$
IF g$ = "" THEN g$ = "FM18LV"
CALL Maiden(g$)
INPUT "INC  "; inc
INPUT "ECC  "; ecc
INPUT "RAAN "; ra
INPUT "ARGP "; ap
INPUT "MA   "; ma
INPUT "MM   "; mm
PRINT "Epoch UTC:"
INPUT "  Yr "; ey
INPUT "  Mo "; emo
INPUT "  Dy "; ed
INPUT "  Hr "; eh
INPUT "  Mi "; emi
INPUT "  Sc "; es
PRINT "Now UTC:"
INPUT "  Yr "; ny
INPUT "  Mo "; nmo
INPUT "  Dy "; nd
INPUT "  Hr "; nh
INPUT "  Mi "; nmi
CALL LoadSat(inc, ecc, ra, ap, ma, mm, FNjd(ey, emo, ed, eh, emi, es))
CALL FindPass(FNjd(ny, nmo, nd, nh, nmi, 0))
IF PAOS = 0 THEN PRINT "No pass in 14d." : END
SW = MM.HRES : SH = MM.VRES
CBG = RGB(0,0,0) : CFG = RGB(255,255,255) : CGRID = RGB(60,60,60)
CARC = RGB(0,200,255) : CMARK = RGB(255,80,80)
cx = SW / 2 : cy = SH / 2 + 8
rr = SH / 2 - 16
CLS CBG
CIRCLE cx, cy, rr, 1, , CGRID
CIRCLE cx, cy, rr * 2 / 3, 1, , CGRID
CIRCLE cx, cy, rr / 3, 1, , CGRID
LINE cx - rr, cy, cx + rr, cy, 1, CGRID
LINE cx, cy - rr, cx, cy + rr, 1, CGRID
TEXT cx, cy - rr - 12, "N", "CT", 7, 1, CFG
TEXT cx, cy + rr + 2, "S", "CT", 7, 1, CFG
TEXT cx + rr + 2, cy, "E", "LM", 7, 1, CFG
TEXT cx - rr - 8, cy, "W", "LM", 7, 1, CFG
' plot the pass arc
firstp = 0
FOR kk = 0 TO 60
  t = PAOS + (PLOS - PAOS) * kk / 60.0
  CALL Look(t, OBLAT, OBLON)
  IF LEL >= 0 THEN
    pr2 = (90.0 - LEL * RAD) / 90.0 * rr
    px = cx + pr2 * SIN(LAZ)
    py = cy - pr2 * COS(LAZ)
    IF firstp = 1 THEN LINE lx, ly, px, py, 2, CARC
    lx = px : ly = py
    firstp = 1
  ENDIF
NEXT kk
' AOS/TCA/LOS marks
CALL Mark(PAOS, cx, cy, rr, CMARK)
CALL Mark(PTCA, cx, cy, rr, CFG)
CALL Mark(PLOS, cx, cy, rr, CARC)
CALL Cal(PAOS)
TEXT 2, 2, "Pass " + STR$(CH,2,0,"0") + ":" + STR$(CMI,2,0,"0") + " MaxEl " + STR$(PMEL*RAD,0,0), "LT", 7, 1, CFG
DO : LOOP UNTIL INKEY$ <> ""
END

SUB Mark(t, cx, cy, rr, col)
  LOCAL el2, pr3, px2, py2
  CALL Look(t, OBLAT, OBLON)
  el2 = LEL : IF el2 < 0 THEN el2 = 0
  pr3 = (90.0 - el2 * RAD) / 90.0 * rr
  px2 = cx + pr3 * SIN(LAZ)
  py2 = cy - pr3 * COS(LAZ)
  CIRCLE px2, py2, 3, 1, , col, col
END SUB


SUB FindPass(now)
  LOCAL stp, j, ed, a0, a1, m, t0, t1, ml, mr
  LOCAL INTEGER k
  stp = 30.0 / 86400.0
  PAOS = 0
  CALL Look(now, OBLAT, OBLON)
  IF LEL >= 0 THEN
    PAOS = now
  ELSE
    j = now : ed = now + 14.0
    DO WHILE j < ed
      CALL Look(j, OBLAT, OBLON)
      IF LEL >= 0 THEN
        a0 = j - stp : a1 = j
        FOR k = 1 TO 25
          m = (a0 + a1) / 2 : CALL Look(m, OBLAT, OBLON)
          IF LEL >= 0 THEN a1 = m ELSE a0 = m
        NEXT k
        PAOS = a1
        EXIT DO
      ENDIF
      j = j + stp
    LOOP
  ENDIF
  IF PAOS = 0 THEN EXIT SUB
  j = PAOS + stp
  DO
    CALL Look(j, OBLAT, OBLON)
    j = j + stp
    IF LEL < 0 OR j > PAOS + 0.02 THEN EXIT DO
  LOOP
  PLOS = j
  t0 = PAOS : t1 = PLOS
  FOR k = 1 TO 40
    ml = t0 + (t1 - t0) / 3 : mr = t1 - (t1 - t0) / 3
    CALL Look(ml, OBLAT, OBLON) : a0 = LEL
    CALL Look(mr, OBLAT, OBLON) : a1 = LEL
    IF a0 < a1 THEN t0 = ml ELSE t1 = mr
  NEXT k
  PTCA = (t0 + t1) / 2
  CALL Look(PTCA, OBLAT, OBLON)
  PMEL = LEL
END SUB

FUNCTION FMT2$(x)
  IF x < 10 THEN FMT2$ = "0" + STR$(x) ELSE FMT2$ = STR$(x)
END FUNCTION

' ---- orbit core ----
SUB LoadSat(inc, ecc, ra, ap, ma, mm, ep)
  WI = inc * DEG : WE = ecc : WO = ra * DEG : WG = ap * DEG
  WM = ma * DEG : WN = mm * TWOPI / 86400.0 : WJ = ep
  WA = (MU / (WN * WN)) ^ (1.0 / 3.0)
  LOCAL p, f, ci, si
  p = WA * (1 - WE * WE)
  f = 1.5 * J2C * (ERAD / p) ^ 2 * WN
  ci = COS(WI) : si = SIN(WI)
  WRD = -f * ci : WPD = f * (2 - 2.5 * si * si)
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
  CALL Eci(j)
  g = Gmst(j) : cg = COS(g) : sg = SIN(g)
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
  OBLAT = la * DEG : OBLON = lo * DEG
END SUB
