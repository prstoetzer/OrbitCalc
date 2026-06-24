' SUNTRAN - Sun/Moon angular separation from a satellite during a pass
' (PicoCalc / MMBasic). Reports minimum Sun-sat and Moon-sat separation,
' flags solar-transit noise and lunar spotting chances. Planning-grade:
' Sun is a low-precision almanac, Moon a truncated series (~1 deg).
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

DIM OBLAT, OBLON
DIM WI, WE, WO, WG, WM, WN, WJ, WA, WRD, WPD
DIM GX, GY, GZ, EX, EY, EZ, LEL, LAZ, LRNG
DIM CMO, CD, CH, CMI, CS
DIM INTEGER CY
DIM PAOS, PLOS
DIM UUX, UUY, UUZ      ' last ENU unit vector from EnuUnit
DIM BEX, BEY, BEZ      ' body ECI

CALL Setup
END

SUB Setup
  LOCAL g$, inc, ecc, ra, ap, ma, mm
  LOCAL ey, emo, ed, eh, emi, es, ny, nmo, nd, nh, nmi
  LOCAL j, t, sx, sy, sz, mx, my, mz
  LOCAL satx, saty, satz, dssun, dsmoon, bsun, bmoon, tsun, tmoon
  CLS
  PRINT "SUNTRAN - Sun/Moon proximity"
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
  INPUT " Yr "; ey
  INPUT " Mo "; emo
  INPUT " Dy "; ed
  INPUT " Hr "; eh
  INPUT " Mi "; emi
  INPUT " Sc "; es
  PRINT "Now UTC:"
  INPUT " Yr "; ny
  INPUT " Mo "; nmo
  INPUT " Dy "; nd
  INPUT " Hr "; nh
  INPUT " Mi "; nmi
  CALL LoadSat(inc, ecc, ra, ap, ma, mm, FNjd(ey, emo, ed, eh, emi, es))
  j = FNjd(ny, nmo, nd, nh, nmi, 0)
  CALL FindPass(j)
  IF PAOS = 0 THEN
    PRINT "No pass within 14 days."
    EXIT SUB
  ENDIF
  bsun = 999 : bmoon = 999 : tsun = PAOS : tmoon = PAOS
  t = PAOS
  DO WHILE t <= PLOS
    CALL Ecef(t)
    CALL EnuUnit(EX, EY, EZ)
    satx = UUX : saty = UUY : satz = UUZ
    CALL SunEci(t) : CALL BodyUnit(t)
    dssun = SepDeg(satx, saty, satz, UUX, UUY, UUZ)
    CALL MoonEci(t) : CALL BodyUnit(t)
    dsmoon = SepDeg(satx, saty, satz, UUX, UUY, UUZ)
    IF dssun < bsun THEN bsun = dssun : tsun = t
    IF dsmoon < bmoon THEN bmoon = dsmoon : tmoon = t
    t = t + 5.0 / 86400.0
  LOOP
  CALL Cal(tsun)
  PRINT
  PRINT "Min Sun-sat  : "; STR$(bsun, 0, 1); " deg at "; FMT2$(CH); ":"; FMT2$(CMI); "Z"
  CALL Cal(tmoon)
  PRINT "Min Moon-sat : "; STR$(bmoon, 0, 1); " deg at "; FMT2$(CH); ":"; FMT2$(CMI); "Z"
  IF bsun < 5 THEN PRINT "  ! Near SOLAR transit - expect noise."
  IF bmoon < 5 THEN PRINT "  ! Near the Moon - spotting chance."
END SUB

' --- body positions ---
SUB SunEci(j)
  LOCAL n, l, g, lam, eps, r
  n = j - 2451545.0
  l = 280.460 + 0.9856474 * n : l = l - 360 * INT(l / 360)
  g = (357.528 + 0.9856003 * n) : g = g - 360 * INT(g / 360) : g = g * DEG
  lam = (l + 1.915 * SIN(g) + 0.020 * SIN(2 * g)) * DEG
  eps = (23.439 - 0.0000004 * n) * DEG
  r = (1.00014 - 0.01671 * COS(g) - 0.00014 * COS(2 * g)) * AU
  BEX = r * COS(lam)
  BEY = r * COS(eps) * SIN(lam)
  BEZ = r * SIN(eps) * SIN(lam)
END SUB

SUB MoonEci(j)
  LOCAL t, lp, m, mp, d, f, lon, lat, dist, eps
  t = (j - 2451545.0) / 36525.0
  lp = 218.316 + 481267.881 * t : lp = lp - 360 * INT(lp / 360)
  m = 357.529 + 35999.050 * t : m = m - 360 * INT(m / 360)
  mp = 134.963 + 477198.867 * t : mp = mp - 360 * INT(mp / 360)
  d = 297.850 + 445267.115 * t : d = d - 360 * INT(d / 360)
  f = 93.272 + 483202.018 * t : f = f - 360 * INT(f / 360)
  lp = lp * DEG : m = m * DEG : mp = mp * DEG : d = d * DEG : f = f * DEG
  lon = lp + (6.289 * SIN(mp) + 1.274 * SIN(2 * d - mp) + 0.658 * SIN(2 * d) + 0.214 * SIN(2 * mp) - 0.186 * SIN(m) - 0.114 * SIN(2 * f)) * DEG
  lat = (5.128 * SIN(f) + 0.281 * SIN(mp + f) + 0.278 * SIN(mp - f) + 0.173 * SIN(2 * d - f)) * DEG
  dist = 385000.0 - 20905 * COS(mp) - 3699 * COS(2 * d - mp) - 2956 * COS(2 * d)
  eps = 23.439 * DEG
  BEX = dist * COS(lat) * COS(lon)
  BEY = dist * (COS(eps) * COS(lat) * SIN(lon) - SIN(eps) * SIN(lat))
  BEZ = dist * (SIN(eps) * COS(lat) * SIN(lon) + COS(eps) * SIN(lat))
END SUB

SUB BodyUnit(j)
  LOCAL g, cg, sg, xe, ye, ze
  g = Gmst(j) : cg = COS(g) : sg = SIN(g)
  xe = cg * BEX + sg * BEY
  ye = -sg * BEX + cg * BEY
  ze = BEZ
  CALL EnuUnit(xe, ye, ze)
END SUB

SUB EnuUnit(xe, ye, ze)
  LOCAL cl, sl, col, sol, ox, oy, oz, rx, ry, rz, s, e, up, rng
  cl = COS(OBLAT) : sl = SIN(OBLAT) : col = COS(OBLON) : sol = SIN(OBLON)
  ox = ERAD * cl * col : oy = ERAD * cl * sol : oz = ERAD * sl
  rx = xe - ox : ry = ye - oy : rz = ze - oz
  s = sl * col * rx + sl * sol * ry - cl * rz
  e = -sol * rx + col * ry
  up = cl * col * rx + cl * sol * ry + sl * rz
  rng = SQR(rx * rx + ry * ry + rz * rz)
  UUX = e / rng : UUY = -s / rng : UUZ = up / rng
END SUB

FUNCTION SepDeg(ax, ay, az, bx, by, bz)
  LOCAL d
  d = ax * bx + ay * by + az * bz
  IF d > 1 THEN d = 1
  IF d < -1 THEN d = -1
  SepDeg = ACOS2(d) * RAD
END FUNCTION

FUNCTION ACOS2(x)
  LOCAL v
  v = x
  IF v > 1 THEN v = 1
  IF v < -1 THEN v = -1
  ACOS2 = PI / 2 - ATN(v / SQR(1 - v * v + 1E-18))
END FUNCTION

SUB FindPass(now)
  LOCAL stp, j, ed, a0, a1, m
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