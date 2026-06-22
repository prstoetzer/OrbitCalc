' ============================================================
'  PASSPLOT - Pass-detail elevation plot for PicoCalc (MMBasic)
'  Cartesian elevation-vs-time curve for the next (or current)
'  pass of one satellite, with AOS/TCA/LOS markers, max-El and
'  azimuth read-outs. Complements the polar plot in SATTRACK.
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
DIM INTEGER CBG, CFG, CACC, CGRID, CCURVE, CWARN
CBG = RGB(0, 0, 0) : CFG = RGB(255, 255, 255) : CACC = RGB(0, 200, 255)
CGRID = RGB(60, 60, 70) : CCURVE = RGB(0, 220, 120) : CWARN = RGB(255, 220, 0)

DIM OBLAT, OBLON
DIM WI, WE, WO, WG, WM, WN, WJ, WA, WRD, WPD
DIM NOWJD
DIM GX, GY, GZ, EX, EY, EZ, BLAT, BLON, LEL, LAZ, LRNG
DIM INTEGER CY, CMO, CD, CH, CMI
DIM CS

CALL Setup
CALL PlotPass
CLS
PRINT "73"
END

SUB Setup
  LOCAL g$, inc, ecc, ra, ap, ma, mm, ey, emo, ed, eh, emi, es
  LOCAL ny, nmo, nd, nh, nmi
  CLS CBG
  CALL Hdr("PASSPLOT setup")
  g$ = Ask$("Grid", 2, 24, "FM18LV") : CALL Maiden(g$)
  inc = AskN("INC", 2, 40, 101.9899)
  ecc = AskN("ECC", 2, 52, 0.0012609)
  ra = AskN("RAAN", 2, 64, 184.6033)
  ap = AskN("ARGP", 2, 76, 124.3014)
  ma = AskN("MA", 2, 88, 247.3322)
  mm = AskN("MM", 2, 100, 12.53698149)
  TEXT 2, 116, "Epoch UTC:", "L", 7, 1, CACC
  ey = AskN("Yr", 2, 128, 2026) : emo = AskN("Mo", 2, 140, 6)
  ed = AskN("Dy", 2, 152, 20) : eh = AskN("Hr", 2, 164, 7)
  emi = AskN("Mi", 2, 176, 46) : es = AskN("Se", 2, 188, 20.6)
  CALL LoadSat(inc, ecc, ra, ap, ma, mm, FNjd(ey, emo, ed, eh, emi, es))
  TEXT 2, 204, "Now UTC:", "L", 7, 1, CACC
  ny = AskN("Yr", 2, 216, 2026) : nmo = AskN("Mo", 2, 228, 6)
  nd = AskN("Dy", 2, 240, 22) : nh = AskN("Hr", 2, 252, 0)
  nmi = AskN("Mi", 2, 264, 0)
  NOWJD = FNjd(ny, nmo, nd, nh, nmi, 0)
END SUB

SUB PlotPass
  LOCAL stp, j, endd, aos, los, tca, maxel
  LOCAL a0, a1, m, t0, t1, ml, mr, ell, elr
  LOCAL INTEGER found, k
  stp = 30.0 / 86400.0
  j = NOWJD : endd = NOWJD + 14.0 : found = 0
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
  ' LOS
  j = aos + stp
  DO
    CALL Look(j, OBLAT, OBLON) : j = j + stp
  LOOP UNTIL LEL < 0 OR j > aos + 0.02
  los = j
  ' TCA by golden-ish search
  t0 = aos : t1 = los
  FOR k = 1 TO 40
    ml = t0 + (t1 - t0) / 3 : mr = t1 - (t1 - t0) / 3
    CALL Look(ml, OBLAT, OBLON) : ell = LEL
    CALL Look(mr, OBLAT, OBLON) : elr = LEL
    IF ell < elr THEN t0 = ml ELSE t1 = mr
  NEXT k
  tca = (t0 + t1) / 2 : CALL Look(tca, OBLAT, OBLON) : maxel = LEL
  ' draw
  CLS CBG
  CALL Hdr("Pass elevation plot")
  LOCAL INTEGER gx0, gy0, gw, gh
  gx0 = 30 : gy0 = 40 : gw = SW - 40 : gh = SH - 110
  ' axes
  BOX gx0, gy0, gw, gh, 1, CGRID, CBG
  ' elevation gridlines 30/60/90
  LOCAL INTEGER e
  FOR e = 0 TO 90 STEP 30
    LOCAL INTEGER yy
    yy = gy0 + gh - INT(e / 90.0 * gh)
    LINE gx0, yy, gx0 + gw, yy, 1, CGRID
    TEXT 2, yy - 4, STR$(e), "L", 7, 1, CGRID
  NEXT e
  ' curve
  LOCAL INTEGER i, px, py, lx, ly, first
  LOCAL t, el
  first = 1
  FOR i = 0 TO 100
    t = aos + (los - aos) * i / 100.0
    CALL Look(t, OBLAT, OBLON) : el = LEL
    IF el < 0 THEN el = 0
    px = gx0 + INT(i / 100.0 * gw)
    py = gy0 + gh - INT(el / (PI / 2) * gh)
    IF first = 0 THEN LINE lx, ly, px, py, 2, CCURVE
    lx = px : ly = py : first = 0
  NEXT i
  ' TCA marker
  LOCAL INTEGER tx
  tx = gx0 + INT((tca - aos) / (los - aos) * gw)
  LINE tx, gy0, tx, gy0 + gh, 1, CWARN
  ' read-outs
  CALL Cal(aos)
  TEXT 4, SH - 60, "AOS " + Z2$(CH) + ":" + Z2$(CMI) + "Z", "L", 7, 1, CFG
  CALL Look(aos, OBLAT, OBLON)
  TEXT 110, SH - 60, "Az " + STR$(INT(LAZ * RAD + 0.5)), "L", 7, 1, CFG
  CALL Cal(tca)
  TEXT 4, SH - 48, "TCA " + Z2$(CH) + ":" + Z2$(CMI) + "Z  MaxEl " + STR$(INT(maxel * RAD + 0.5)), "L", 7, 1, CWARN
  CALL Cal(los)
  TEXT 4, SH - 36, "LOS " + Z2$(CH) + ":" + Z2$(CMI) + "Z", "L", 7, 1, CFG
  TEXT 110, SH - 36, "Dur " + STR$(INT((los - aos) * 1440 + 0.5)) + "m", "L", 7, 1, CFG
  TEXT 4, SH - 12, "Press any key", "L", 7, 1, CGRID
  LOCAL d$
  d$ = WaitKey$()
END SUB

' ---- orbit core (shared) ----
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

SUB Hdr(t$)
  BOX 0, 0, SW, 16, 1, CACC, RGB(0, 30, 45)
  TEXT 4, 2, t$, "L", 1, 1, CACC
END SUB

SUB Flash(m$)
  LOCAL INTEGER w
  w = LEN(m$) * 8 + 16
  BOX (SW - w) / 2, SH / 2 - 10, w, 20, 1, CWARN, RGB(40, 30, 0)
  TEXT SW / 2, SH / 2, m$, "CM", 1, 1, CWARN
  PAUSE 800
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
