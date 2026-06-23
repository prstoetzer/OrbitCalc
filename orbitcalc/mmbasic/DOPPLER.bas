' ============================================================
'  DOPPLER - Standalone Doppler-shift display for PicoCalc
'  MMBasic (PicoMite). Shows live uplink/downlink Doppler for
'  one satellite during a pass, from orbital elements.
'
'  This is the PLANNING half of CardSat's Doppler feature: it
'  computes and displays the shift; it does NOT control a radio.
'
'  Orbit model: secular-J2 mean elements + Kepler (same core as
'  the rest of the repo). Range-rate by 1-second finite diff.
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
CONST CKMS = 299792.458       ' speed of light, km/s

DIM SH
DIM INTEGER SW
SW = MM.HRES
SH = MM.VRES
IF SH > 320 THEN SH = 320

DIM CFG, CACC, CGRID, CUP, CDN, CWARN
DIM INTEGER CBG
CBG = RGB(0, 0, 0)
CFG = RGB(255, 255, 255)
CACC = RGB(0, 200, 255)
CGRID = RGB(60, 60, 70)
CUP = RGB(255, 120, 120)      ' uplink
CDN = RGB(120, 220, 255)      ' downlink
CWARN = RGB(255, 220, 0)

DIM OBLAT, OBLON
DIM WI, WE, WO, WG, WM, WN, WJ, WA, WRD, WPD
DIM NOWJD, FUP, FDN
DIM GX, GY, GZ, EX, EY, EZ, BLAT, BLON, LEL, LAZ, LRNG
DIM CMO, CD, CH, CMI
DIM INTEGER CY
DIM CS

CALL Setup
CALL LiveDoppler
CLS
PRINT "73"
END

SUB Setup
  LOCAL g$, inc, ecc, ra, ap, ma, mm
  LOCAL ey, emo, ed, eh, emi, es
  CLS CBG
  CALL Hdr("DOPPLER setup")
  TEXT 2, 20, "Grid (e.g. FM18LV):", "L", 7, 1, CFG
  g$ = Ask$("Grid", 2, 32, "FM18LV")
  CALL Maiden(g$)
  TEXT 2, 50, "Satellite elements:", "L", 7, 1, CACC
  inc = AskN("INC", 2, 62, 101.9899)
  ecc = AskN("ECC", 2, 74, 0.0012609)
  ra = AskN("RAAN", 2, 86, 184.6033)
  ap = AskN("ARGP", 2, 98, 124.3014)
  ma = AskN("MA", 2, 110, 247.3322)
  mm = AskN("MM", 2, 122, 12.53698149)
  TEXT 2, 138, "Epoch UTC:", "L", 7, 1, CACC
  ey = AskN("Yr", 2, 150, 2026)
  emo = AskN("Mo", 2, 162, 6)
  ed = AskN("Dy", 2, 174, 20)
  eh = AskN("Hr", 2, 186, 7)
  emi = AskN("Mi", 2, 198, 46)
  es = AskN("Se", 2, 210, 20.6)
  CALL LoadSat(inc, ecc, ra, ap, ma, mm, FNjd(ey, emo, ed, eh, emi, es))
  TEXT 2, 226, "Now (UTC):", "L", 7, 1, CACC
  LOCAL ny, nmo, nd, nh, nmi
  ny = AskN("Yr", 2, 238, 2026)
  nmo = AskN("Mo", 2, 250, 6)
  nd = AskN("Dy", 2, 262, 22)
  nh = AskN("Hr", 2, 274, 0)
  nmi = AskN("Mi", 2, 286, 0)
  NOWJD = FNjd(ny, nmo, nd, nh, nmi, 0)
  TEXT 2, 302, "Freqs MHz:", "L", 7, 1, CACC
  FDN = AskN("Downlink", 80, 302, 145.95)
  FUP = AskN("Uplink", 200, 302, 435.1)
END SUB

SUB LiveDoppler
  LOCAL k$
  LOCAL toff
  toff = 0
  DO
    CALL DrawDop(toff)
    k$ = WaitKey$()
    IF k$ = " " THEN toff = toff + 0.5
    IF UCASE$(k$) = "B" THEN toff = toff - 0.5
    IF UCASE$(k$) = "F" THEN toff = toff + 2
    IF UCASE$(k$) = "R" THEN NOWJD = NOWJD + toff / 1440.0 : toff = 0
  LOOP UNTIL k$ = CHR$(27)
END SUB

SUB DrawDop(toff)
  LOCAL j, rr, dshift, ushift
  LOCAL INTEGER yy
  j = NOWJD + toff / 1440.0
  CLS CBG
  CALL Hdr("DOPPLER")
  CALL Look(j, OBLAT, OBLON)
  CALL Cal(j)
  TEXT 4, 22, "UTC " + Z2$(CH) + ":" + Z2$(CMI) + ":" + Z2$(INT(CS)) + "  T+" + STR$(toff) + "m", "L", 7, 1, CWARN
  IF LEL >= 0 THEN
    TEXT 4, 40, "El " + STR$(INT(LEL * RAD + 0.5)) + " Az " + STR$(INT(LAZ * RAD + 0.5)) + " Rng " + STR$(INT(LRNG)) + "km", "L", 7, 1, CFG
  ELSE
    TEXT 4, 40, "Satellite below horizon", "L", 7, 1, CGRID
  ENDIF
  rr = RangeRate(j)
  TEXT 4, 58, "Range-rate " + STR$(INT(rr * 1000) / 1000.0) + " km/s", "L", 7, 1, CFG
  IF rr < 0 THEN
    TEXT 220, 58, "(approaching)", "L", 7, 1, CUP
  ELSE
    TEXT 220, 58, "(receding)", "L", 7, 1, CDN
  ENDIF
  ' downlink
  dshift = -FDN * 1000000.0 * rr / CKMS
  yy = 88
  CALL Bar("DOWN " + FmtMHz$(FDN), FDN * 1000000.0 + dshift, dshift, yy, CDN)
  ' uplink (note: to keep a constant freq AT the satellite, the uplink
  ' is corrected with opposite sense; show the raw shift the operator sees)
  ushift = -FUP * 1000000.0 * rr / CKMS
  yy = 150
  CALL Bar("UP   " + FmtMHz$(FUP), FUP * 1000000.0 + ushift, ushift, yy, CUP)
  ' net (sum of magnitudes) for full-duplex linear birds
  TEXT 4, 220, "Total passband walk: " + STR$(INT(ABS(dshift) + ABS(ushift))) + " Hz", "L", 7, 1, CWARN
  ' simple Doppler curve over the pass
  CALL DopCurve(j)
  TEXT 4, SH - 12, "SPC step F fast B back R repin ESC", "L", 7, 1, CGRID
END SUB

SUB Bar(lbl$, fobs, shift, y AS INTEGER, col AS INTEGER)
  TEXT 4, y, lbl$, "L", 1, 1, col
  TEXT 4, y + 16, "Shift " + Sgn$(shift) + STR$(INT(ABS(shift))) + " Hz", "L", 7, 1, CFG
  TEXT 4, y + 30, "Tune  " + FmtHz$(fobs) + " MHz", "L", 7, 1, col
  ' small bar showing shift magnitude (scaled, +-5kHz full)
  LOCAL w
  LOCAL INTEGER cx
  cx = SW / 2
  LINE cx, y + 46, cx, y + 54, 1, CGRID
  w = INT(shift / 5000.0 * (SW / 2 - 10))
  IF w > SW / 2 - 10 THEN w = SW / 2 - 10
  IF w < -(SW / 2 - 10) THEN w = -(SW / 2 - 10)
  BOX cx, y + 48, w, 4, 1, col, col
END SUB

SUB DopCurve(jc)
  ' Doppler-shift-vs-time curve for +-15 min around jc (downlink)
  LOCAL gy0, gh, gw, first, px, py, lx, ly
  LOCAL INTEGER x0
  LOCAL t, rr, sh, mx
  LOCAL i
  gy0 = SH - 70 : gh = 40 : gw = SW - 8 : x0 = 4
  mx = FDN * 1000000.0 * 6.0 / CKMS    ' approx full-scale for 6 km/s
  BOX x0, gy0, gw, gh, 1, CGRID, CBG
  LINE x0, gy0 + gh / 2, x0 + gw, gy0 + gh / 2, 1, CGRID
  first = 1
  FOR i = 0 TO 60
    t = jc + (i - 30) * 30.0 / 86400.0
    rr = RangeRate(t)
    sh = -FDN * 1000000.0 * rr / CKMS
    px = x0 + i * gw / 60
    py = gy0 + gh / 2 - INT(sh / mx * (gh / 2))
    IF py < gy0 THEN py = gy0
    IF py > gy0 + gh THEN py = gy0 + gh
    IF first = 0 THEN LINE lx, ly, px, py, 1, CDN
    lx = px : ly = py : first = 0
  NEXT i
  LINE x0 + gw / 2, gy0, x0 + gw / 2, gy0 + gh, 1, CWARN   ' "now"
END SUB

FUNCTION RangeRate(j)
  LOCAL dt, r0, r1
  dt = 1.0 / 86400.0
  CALL Look(j - dt, OBLAT, OBLON) : r0 = LRNG
  CALL Look(j + dt, OBLAT, OBLON) : r1 = LRNG
  RangeRate = (r1 - r0) / 2.0
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

' ---- UI helpers ----
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
  LOCAL s$
  s$ = Ask$(label$, x, y, STR$(dflt))
  AskN = VAL(s$)
END FUNCTION

FUNCTION Z2$(n AS INTEGER)
  IF n < 10 THEN Z2$ = "0" + STR$(n) ELSE Z2$ = STR$(n)
END FUNCTION

FUNCTION Sgn$(v)
  IF v >= 0 THEN Sgn$ = "+" ELSE Sgn$ = "-"
END FUNCTION

FUNCTION FmtMHz$(f)
  FmtMHz$ = STR$(f) + " MHz"
END FUNCTION

FUNCTION FmtHz$(fhz)
  ' format Hz to MHz with 4 decimals
  LOCAL mhz
  mhz = fhz / 1000000.0
  FmtHz$ = STR$(INT(mhz * 10000 + 0.5) / 10000.0)
END FUNCTION
