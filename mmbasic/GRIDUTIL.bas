' GRIDUTIL - Maidenhead grid <-> lat/lon, bearing & distance (MMBasic)
OPTION EXPLICIT
OPTION DEFAULT FLOAT
CONST PI = 3.1415926535898
CONST DEG = PI / 180.0
CONST RAD = 180.0 / PI
CONST GRE = 6371.0

DIM mode$, g$
DIM la, lo, la1, lo1, la2, lo2, brg, dist
DIM GLAT, GLON, BRGOUT, DSTOUT

CLS
PRINT "GRIDUTIL"
PRINT "1 grid->lat/lon"
PRINT "2 lat/lon->grid"
PRINT "3 bearing & distance"
INPUT "Choose 1/2/3 "; mode$
IF mode$ = "1" THEN
  INPUT "Grid "; g$
  CALL GridToLL(g$)
  PRINT UCASE$(g$); " = "; STR$(GLAT, 0, 4); " N, "; STR$(GLON, 0, 4); " E"
ELSEIF mode$ = "2" THEN
  INPUT "Latitude +N "; la
  INPUT "Longitude +E "; lo
  PRINT "Grid = "; LLToGrid$(la, lo)
ELSE
  INPUT "From grid "; g$
  CALL GridToLL(g$)
  la1 = GLAT : lo1 = GLON
  INPUT "To grid "; g$
  CALL GridToLL(g$)
  la2 = GLAT : lo2 = GLON
  CALL BearDist(la1, lo1, la2, lo2)
  PRINT "Bearing : "; STR$(BRGOUT, 0, 0); " deg"
  PRINT "Distance: "; STR$(DSTOUT, 0, 0); " km ("; STR$(DSTOUT * 0.621371, 0, 0); " mi)"
ENDIF
END

SUB GridToLL(g$)
  LOCAL u$
  u$ = UCASE$(g$)
  GLON = (ASC(MID$(u$, 1, 1)) - 65) * 20 - 180
  GLAT = (ASC(MID$(u$, 2, 1)) - 65) * 10 - 90
  GLON = GLON + (ASC(MID$(u$, 3, 1)) - 48) * 2
  GLAT = GLAT + (ASC(MID$(u$, 4, 1)) - 48)
  IF LEN(u$) >= 6 THEN
    GLON = GLON + (ASC(MID$(u$, 5, 1)) - 65) / 12.0 + 1.0 / 24.0
    GLAT = GLAT + (ASC(MID$(u$, 6, 1)) - 65) / 24.0 + 1.0 / 48.0
  ELSE
    GLON = GLON + 1.0 : GLAT = GLAT + 0.5
  ENDIF
END SUB

FUNCTION LLToGrid$(lat, lon)
  LOCAL x, y
  LOCAL INTEGER fa, fb, sa, sb, ea, eb
  x = lon + 180.0
  y = lat + 90.0
  fa = INT(x / 20) : fb = INT(y / 10)
  sa = INT((x - fa * 20) / 2) : sb = INT(y - fb * 10)
  ea = INT(((x / 2) - INT(x / 2)) * 24) : eb = INT((y - INT(y)) * 24)
  LLToGrid$ = CHR$(65 + fa) + CHR$(65 + fb) + STR$(sa) + STR$(sb) + CHR$(97 + ea) + CHR$(97 + eb)
END FUNCTION

SUB BearDist(lat1, lon1, lat2, lon2)
  LOCAL a, b, c, d, dl, y, x, cd
  a = lat1 * DEG : b = lon1 * DEG : c = lat2 * DEG : d = lon2 * DEG
  dl = d - b
  y = SIN(dl) * COS(c)
  x = COS(a) * SIN(c) - SIN(a) * COS(c) * COS(dl)
  BRGOUT = ATAN2D(y, x)
  IF BRGOUT < 0 THEN BRGOUT = BRGOUT + 360
  cd = SIN(a) * SIN(c) + COS(a) * COS(c) * COS(dl)
  IF cd > 1 THEN cd = 1
  IF cd < -1 THEN cd = -1
  DSTOUT = ACOSR(cd) * GRE
END SUB

FUNCTION ATAN2D(y, x)
  LOCAL r
  IF x > 0 THEN
    r = ATN(y / x)
  ELSEIF x < 0 THEN
    IF y >= 0 THEN r = ATN(y / x) + PI ELSE r = ATN(y / x) - PI
  ELSE
    IF y > 0 THEN r = PI / 2 ELSE r = -PI / 2
  ENDIF
  ATAN2D = r * RAD
END FUNCTION

FUNCTION ACOSR(x)
  LOCAL v
  v = x
  IF v > 1 THEN v = 1
  IF v < -1 THEN v = -1
  ACOSR = PI / 2 - ATN(v / SQR(1 - v * v + 1E-18))
END FUNCTION
