' ============================================================
'  SUNECL - Sun position + satellite eclipse for PicoCalc
'  MMBasic. Shows Sun az/el for your QTH, day/night, and
'  whether the satellite is sunlit or in Earth's shadow now
'  (and a short timeline of upcoming sunlit/eclipse spans).
'
'  Sun: low-precision almanac formula. Eclipse: cylindrical
'  shadow test in ECI. Orbit: secular-J2 mean elements.
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
CONST AU = 149597870.7

DIM INTEGER SW, SH
SW = MM.HRES : SH = MM.VRES
IF SH > 320 THEN SH = 320
DIM INTEGER CBG, CFG, CACC, CGRID, CSUN, CSHAD, CWARN
CBG = RGB(0, 0, 0) : CFG = RGB(255, 255, 255) : CACC = RGB(0, 200, 255)
CGRID = RGB(60, 60, 70) : CSUN = RGB(255, 220, 0)
CSHAD = RGB(90, 90, 160) : CWARN = RGB(255, 150, 0)

DIM OBLAT, OBLON
DIM WI, WE, WO, WG, WM, WN, WJ, WA, WRD, WPD
DIM NOWJD
DIM GX, GY, GZ, EX, EY, EZ
DIM SUX, SUY, SUZ                 ' Sun ECI (km)
DIM SEL, SAZ                      ' Sun look angles
DIM INTEGER CY, CMO, CD, CH, CMI
DIM CS

CALL Setup
CALL Show
CLS
PRINT "73"
END

SUB Setup
  LOCAL g$, inc, ecc, ra, ap, ma, mm, ey, emo, ed, eh, emi, es
  LOCAL ny, nmo, nd, nh, nmi
  CLS CBG
  CALL Hdr("SUN / ECLIPSE setup")
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

SUB Show
  LOCAL k$, toff
  toff = 0
  DO
    CALL DrawSun(toff)
    k$ = WaitKey$()
    IF k$ = " " THEN toff = toff + 1
    IF UCASE$(k$) = "F" THEN toff = toff + 10
    IF UCASE$(k$) = "B" THEN toff = toff - 1
    IF UCASE$(k$) = "R" THEN NOWJD = NOWJD + toff / 1440.0 : toff = 0
  LOOP UNTIL k$ = CHR$(27)
END SUB

SUB DrawSun(toff)
  LOCAL j
  LOCAL INTEGER lit
  j = NOWJD + toff / 1440.0
  CLS CBG
  CALL Hdr("Sun / Eclipse")
  CALL Cal(j)
  TEXT 4, 22, "UTC " + Z2$(CH) + ":" + Z2$(CMI) + "  T+" + STR$(toff) + "m", "L", 7, 1, CWARN
  ' Sun for observer
  CALL SunLook(j)
  TEXT 4, 42, "Sun  El " + STR$(INT(SEL * RAD + 0.5)) + "  Az " + STR$(INT(SAZ * RAD + 0.5)), "L", 7, 1, CSUN
  IF SEL >= 0 THEN
    TEXT 220, 42, "(day)", "L", 7, 1, CSUN
  ELSEIF SEL > -6 * DEG THEN
    TEXT 220, 42, "(twilight)", "L", 7, 1, CWARN
  ELSE
    TEXT 220, 42, "(night)", "L", 7, 1, CSHAD
  ENDIF
  ' Satellite sunlit?
  lit = IsLit(j)
  IF lit = 1 THEN
    TEXT 4, 64, "Satellite: SUNLIT", "L", 1, 1, CSUN
    CIRCLE SW - 30, 64, 8, 1, , CSUN, CSUN
  ELSE
    TEXT 4, 64, "Satellite: IN ECLIPSE", "L", 1, 1, CSHAD
    CIRCLE SW - 30, 64, 8, 1, , CSHAD
  ENDIF
  ' timeline of next ~100 min: sunlit (bright) vs eclipse (dark) bar
  LOCAL INTEGER gx0, gy0, gw, gh, i, px
  gx0 = 8 : gy0 = 96 : gw = SW - 16 : gh = 18
  TEXT 8, 84, "Next 100 min (sunlit/eclipse):", "L", 7, 1, CACC
  FOR i = 0 TO gw - 1
    LOCAL t
    t = j + (i / (gw - 1.0)) * (100.0 / 1440.0)
    px = gx0 + i
    IF IsLit(t) = 1 THEN
      LINE px, gy0, px, gy0 + gh, 1, CSUN
    ELSE
      LINE px, gy0, px, gy0 + gh, 1, CSHAD
    ENDIF
  NEXT i
  BOX gx0, gy0, gw, gh, 1, CGRID, -1
  ' find next transition time
  LOCAL tnext
  LOCAL INTEGER cur, found
  cur = IsLit(j) : found = 0
  FOR i = 1 TO 200
    LOCAL tt
    tt = j + i * 30.0 / 86400.0
    IF IsLit(tt) <> cur THEN tnext = tt : found = 1 : EXIT FOR
  NEXT i
  IF found = 1 THEN
    CALL Cal(tnext)
    IF cur = 1 THEN
      TEXT 8, 124, "Enters eclipse ~" + Z2$(CH) + ":" + Z2$(CMI) + "Z", "L", 7, 1, CSHAD
    ELSE
      TEXT 8, 124, "Becomes sunlit ~" + Z2$(CH) + ":" + Z2$(CMI) + "Z", "L", 7, 1, CSUN
    ENDIF
  ENDIF
  ' little sky dial showing the Sun position over QTH
  CALL SunDial(j)
  TEXT 4, SH - 12, "SPC step F fast B back R repin ESC", "L", 7, 1, CGRID
END SUB

SUB SunDial(j)
  LOCAL INTEGER cx, cy, rr
  cx = SW / 2 : cy = SH - 80 : rr = 50
  CIRCLE cx, cy, rr, 1, , CGRID
  LINE cx - rr, cy, cx + rr, cy, 1, CGRID
  LINE cx, cy - rr, cx, cy + rr, 1, CGRID
  TEXT cx, cy - rr - 10, "N", "CT", 7, 1, CGRID
  CALL SunLook(j)
  IF SEL >= 0 THEN
    LOCAL pr
    LOCAL INTEGER px, py
    pr = rr * (1 - SEL / (PI / 2))
    px = cx + pr * SIN(SAZ) : py = cy - pr * COS(SAZ)
    CIRCLE px, py, 5, 1, , CSUN, CSUN
  ELSE
    TEXT cx, cy + rr + 4, "Sun below horizon", "CT", 7, 1, CSHAD
  ENDIF
END SUB

' ---- Sun position (low precision), ECI km ----
SUB SunEci(j)
  LOCAL n, l, g, lam, eps, r, rk
  n = j - 2451545.0
  l = 280.460 + 0.9856474 * n : l = l - 360 * INT(l / 360)
  g = (357.528 + 0.9856003 * n) : g = g - 360 * INT(g / 360) : g = g * DEG
  lam = (l + 1.915 * SIN(g) + 0.020 * SIN(2 * g)) * DEG
  eps = (23.439 - 0.0000004 * n) * DEG
  r = 1.00014 - 0.01671 * COS(g) - 0.00014 * COS(2 * g)
  rk = r * AU
  SUX = rk * COS(lam)
  SUY = rk * COS(eps) * SIN(lam)
  SUZ = rk * SIN(eps) * SIN(lam)
END SUB

SUB SunLook(j)
  LOCAL g, cg, sg, xe, ye, ze, cl, sl, col, sol, ox, oy, oz
  LOCAL rx, ry, rz, s, e, zz, rng
  CALL SunEci(j)
  g = Gmst(j) : cg = COS(g) : sg = SIN(g)
  xe = cg * SUX + sg * SUY : ye = -sg * SUX + cg * SUY : ze = SUZ
  cl = COS(OBLAT) : sl = SIN(OBLAT) : col = COS(OBLON) : sol = SIN(OBLON)
  ox = ERAD * cl * col : oy = ERAD * cl * sol : oz = ERAD * sl
  rx = xe - ox : ry = ye - oy : rz = ze - oz
  s = sl * col * rx + sl * sol * ry - cl * rz
  e = -sol * rx + col * ry
  zz = cl * col * rx + cl * sol * ry + sl * rz
  rng = SQR(rx * rx + ry * ry + rz * rz)
  SEL = ASINN(zz / rng)
  SAZ = ATAN2S(e, -s) : IF SAZ < 0 THEN SAZ = SAZ + TWOPI
END SUB

FUNCTION IsLit(j)
  ' cylindrical shadow test in ECI
  LOCAL sx, sy, sz, ux, uy, uz, un, dotp, pxx, pyy, pzz, perp
  CALL Eci(j) : sx = GX : sy = GY : sz = GZ
  CALL SunEci(j)
  un = SQR(SUX * SUX + SUY * SUY + SUZ * SUZ)
  ux = SUX / un : uy = SUY / un : uz = SUZ / un
  dotp = sx * ux + sy * uy + sz * uz
  IF dotp > 0 THEN
    IsLit = 1
    EXIT FUNCTION
  ENDIF
  pxx = sx - dotp * ux : pyy = sy - dotp * uy : pzz = sz - dotp * uz
  perp = SQR(pxx * pxx + pyy * pyy + pzz * pzz)
  IF perp > ERAD THEN IsLit = 1 ELSE IsLit = 0
END FUNCTION

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
