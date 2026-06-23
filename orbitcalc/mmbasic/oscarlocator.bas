' OSCARLOCATOR helper - MMBasic (PicoCalc), no external dependencies
' Given the EQX of one orbit, the node type, the date, the orbital
' period, and the longitude advance per orbit, produce the time and
' longitude of every equatorial crossing during that UTC day.
'
' Convention: each successive orbit crosses the equator one period
' later in time and "advance" degrees further WEST in longitude
' (positive advance = westward, the usual Oscarlocator sense).

OPTION DEFAULT FLOAT

FUNCTION WRAPLON(lon)
  LOCAL x
  x = lon
  DO WHILE x > 180.0 : x = x - 360.0 : LOOP
  DO WHILE x <= -180.0 : x = x + 360.0 : LOOP
  WRAPLON = x
END FUNCTION

FUNCTION LONFMT$(lon)
  LOCAL x
  x = WRAPLON(lon)
  IF x >= 0 THEN
    LONFMT$ = STR$(x,7,2) + " E"
  ELSE
    LONFMT$ = STR$(-x,7,2) + " W"
  ENDIF
END FUNCTION

' parse "111.56 W", "-111.56", "111.56E" -> signed deg (+E/-W)
FUNCTION PARSELON(s$)
  LOCAL u$, sign, c$
  u$ = UCASE$(s$)
  sign = 1.0
  c$ = RIGHT$(u$, 1)
  IF c$ = "W" THEN
    sign = -1.0 : u$ = LEFT$(u$, LEN(u$)-1)
  ELSEIF c$ = "E" THEN
    u$ = LEFT$(u$, LEN(u$)-1)
  ENDIF
  PARSELON = sign * VAL(u$)
END FUNCTION

DIM lon0, nt$, y, mo, d, h, mi, period, adv, lon0$
DIM node$, t0, k, ft, fl, t, lon, n, hh, mm, ss

CLS
PRINT "=== OSCARLOCATOR ==="
INPUT "EQX longitude (e.g. 111.56 W): ", lon0$
lon0 = PARSELON(lon0$)
INPUT "Node (A)scending/(D)escending: ", nt$
INPUT "Date Year: ", y
INPUT "Date Month: ", mo
INPUT "Date Day: ", d
INPUT "EQX time hour (UTC): ", h
INPUT "EQX time min (UTC): ", mi
INPUT "Orbital period (min): ", period
INPUT "Lon advance/orbit (deg W): ", adv

IF UCASE$(nt$) = "A" THEN node$ = "ASC" ELSE node$ = "DESC"
t0 = h*60.0 + mi

' first crossing time t0 - k*period inside [0,period)
k = INT(t0/period)
ft = t0 - k*period
fl = WRAPLON(lon0 + k*adv)   ' earlier orbit was k advances East of lon0

PRINT
PRINT "UTC day ";STR$(y,4,0,"0");"-";STR$(mo,2,0,"0");"-";STR$(d,2,0,"0");"  node=";node$
PRINT "ORBIT UTC-TIME  EQX-LON"
t = ft : lon = fl : n = 0
DO WHILE t < 1440.0
  hh = INT(t/60) : mm = t - hh*60
  ss = (mm - INT(mm))*60
  PRINT STR$(n,4);"  ";STR$(hh,2,0,"0");":";STR$(INT(mm),2,0,"0");":";STR$(INT(ss+0.5),2,0,"0");
  PRINT "  ";LONFMT$(lon)
  t = t + period
  lon = WRAPLON(lon - adv)   ' forward in time -> advance westward
  n = n + 1
LOOP
END
