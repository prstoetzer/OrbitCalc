' OrbitCalc - MMBasic (PicoCalc), no external dependencies
' Next-10-passes and 10-day reference-orbit (EQX) tables from
' AMSAT GP/OMM mean orbital elements (daily-bulletin.json fields).
' Method: secular J2 mean-element propagation + Kepler solve.

OPTION DEFAULT FLOAT
CONST PI = 3.14159265358979
CONST TWOPI = 6.28318530717959
CONST DEG = PI/180.0
CONST RAD = 180.0/PI
CONST MU = 398600.4418
CONST RE = 6378.137
CONST J2 = 1.08262668e-3

' --- satellite element globals (set by SETSAT) ---
DIM S_I, S_E, S_RAAN0, S_ARGP0, S_M0, S_N0, S_EPOCH, S_A
DIM S_RAANDOT, S_ARGPDOT

' --- working outputs from subs ---
DIM G_X, G_Y, G_Z          ' eci
DIM E_X, E_Y, E_Z          ' ecef
DIM O_LAT, O_LON           ' subpoint
DIM L_EL, L_AZ, L_RNG      ' look angles

SUB SETSAT inc, ecc, raan, argp, ma, mmrev, epjd
  S_I = inc*DEG
  S_E = ecc
  S_RAAN0 = raan*DEG
  S_ARGP0 = argp*DEG
  S_M0 = ma*DEG
  S_N0 = mmrev*TWOPI/86400.0
  S_EPOCH = epjd
  S_A = (MU/(S_N0*S_N0))^(1.0/3.0)
  LOCAL p, f, ci, si
  p = S_A*(1-S_E*S_E)
  f = 1.5*J2*(RE/p)^2*S_N0
  ci = COS(S_I) : si = SIN(S_I)
  S_RAANDOT = -f*ci
  S_ARGPDOT = f*(2.0-2.5*si*si)
END SUB

FUNCTION JDATE(y, mo, d, h, mi, s)
  LOCAL yy, mm, a, b
  yy = y : mm = mo
  IF mm <= 2 THEN yy = yy-1 : mm = mm+12
  a = INT(yy/100)
  b = 2 - a + INT(a/4)
  JDATE = INT(365.25*(yy+4716)) + INT(30.6001*(mm+1)) + d + b - 1524.5
  JDATE = JDATE + (h + mi/60.0 + s/3600.0)/24.0
END FUNCTION

FUNCTION GMST(jd)
  LOCAL t, g
  t = (jd-2451545.0)/36525.0
  g = 280.46061837 + 360.98564736629*(jd-2451545.0) + 0.000387933*t*t - t*t*t/38710000.0
  g = g - 360.0*INT(g/360.0)
  IF g < 0 THEN g = g + 360.0
  GMST = g*DEG
END FUNCTION

FUNCTION KEPLER(m, e)
  LOCAL ee, de, k
  ee = m
  FOR k = 1 TO 50
    de = (ee - e*SIN(ee) - m)/(1 - e*COS(ee))
    ee = ee - de
    IF ABS(de) < 1e-12 THEN EXIT FOR
  NEXT k
  KEPLER = ee
END FUNCTION

SUB ECIPOS jd
  LOCAL dt, m, raan, argp, ee, xo, yo, u, r
  LOCAL co, so, cu, su, ci, si
  dt = (jd - S_EPOCH)*86400.0
  m = S_M0 + S_N0*dt
  raan = S_RAAN0 + S_RAANDOT*dt
  argp = S_ARGP0 + S_ARGPDOT*dt
  m = m - TWOPI*INT(m/TWOPI)
  ee = KEPLER(m, S_E)
  xo = S_A*(COS(ee) - S_E)
  yo = S_A*SQR(1 - S_E*S_E)*SIN(ee)
  u = ATAN2(yo, xo) + argp
  r = SQR(xo*xo + yo*yo)
  co = COS(raan) : so = SIN(raan)
  cu = COS(u) : su = SIN(u)
  ci = COS(S_I) : si = SIN(S_I)
  G_X = r*(co*cu - so*su*ci)
  G_Y = r*(so*cu + co*su*ci)
  G_Z = r*(su*si)
END SUB

SUB ECEFPOS jd
  LOCAL g, cg, sg
  ECIPOS jd
  g = GMST(jd)
  cg = COS(g) : sg = SIN(g)
  E_X = cg*G_X + sg*G_Y
  E_Y = -sg*G_X + cg*G_Y
  E_Z = G_Z
END SUB

SUB SUBPOINT jd
  ECEFPOS jd
  O_LON = ATAN2(E_Y, E_X)
  O_LAT = ATAN2(E_Z, SQR(E_X*E_X + E_Y*E_Y))
END SUB

SUB LOOKANG jd, obslat, obslon
  LOCAL r, clat, slat, clon, slon, ox, oy, oz
  LOCAL rx, ry, rz, ss, ee, zz, rng
  ECEFPOS jd
  r = RE
  clat = COS(obslat) : slat = SIN(obslat)
  clon = COS(obslon) : slon = SIN(obslon)
  ox = r*clat*clon : oy = r*clat*slon : oz = r*slat
  rx = E_X-ox : ry = E_Y-oy : rz = E_Z-oz
  ss = slat*clon*rx + slat*slon*ry - clat*rz
  ee = -slon*rx + clon*ry
  zz = clat*clon*rx + clat*slon*ry + slat*rz
  rng = SQR(rx*rx + ry*ry + rz*rz)
  L_EL = ASIN(zz/rng)
  L_AZ = ATAN2(ee, -ss)
  IF L_AZ < 0 THEN L_AZ = L_AZ + TWOPI
  L_RNG = rng
END SUB

SUB MAIDEN g$, lat, lon
  LOCAL u$
  u$ = UCASE$(g$)
  lon = (ASC(MID$(u$,1,1))-65)*20 - 180
  lat = (ASC(MID$(u$,2,1))-65)*10 - 90
  lon = lon + (ASC(MID$(u$,3,1))-48)*2
  lat = lat + (ASC(MID$(u$,4,1))-48)*1
  IF LEN(u$) >= 6 THEN
    lon = lon + (ASC(MID$(u$,5,1))-65)*(2.0/24.0) + 1.0/24.0
    lat = lat + (ASC(MID$(u$,6,1))-65)*(1.0/24.0) + 0.5/24.0
  ELSE
    lon = lon + 1.0 : lat = lat + 0.5
  ENDIF
  lat = lat*DEG : lon = lon*DEG
END SUB

' JD -> calendar; results in CY,CMO,CD,CH,CMI,CS
DIM CY, CMO, CD, CH, CMI, CS
SUB CALDATE jd
  LOCAL z, f, alpha, a, b, c, dd, e, day, secs
  jd = jd + 0.5
  z = INT(jd) : f = jd - z
  IF z < 2299161 THEN
    a = z
  ELSE
    alpha = INT((z-1867216.25)/36524.25)
    a = z + 1 + alpha - INT(alpha/4)
  ENDIF
  b = a + 1524 : c = INT((b-122.1)/365.25)
  dd = INT(365.25*c) : e = INT((b-dd)/30.6001)
  day = b - dd - INT(30.6001*e) + f
  IF e < 14 THEN CMO = e-1 ELSE CMO = e-13
  IF CMO > 2 THEN CY = c-4716 ELSE CY = c-4715
  CD = INT(day)
  secs = (day - CD)*86400.0
  CH = INT(secs/3600) : secs = secs - CH*3600
  CMI = INT(secs/60) : CS = secs - CMI*60
END SUB

FUNCTION HMS$(h, mi, s)
  HMS$ = STR$(h,2,0,"0") + ":" + STR$(mi,2,0,"0") + ":" + STR$(INT(s+0.5),2,0,"0")
END FUNCTION

FUNCTION LONFMT$(lond)
  IF lond >= 0 THEN
    LONFMT$ = STR$(lond,7,2) + " E"
  ELSE
    LONFMT$ = STR$(-lond,7,2) + " W"
  ENDIF
END FUNCTION

' ---------- Passes ----------
SUB DOPASSES obslat, obslon, startjd
  LOCAL step, jd, endd, inpass, npass
  LOCAL aos, los, tca, maxel, azaos, aztca, azlos
  LOCAL a0, a1, mm, k, t0, t1, ml, mr, ell, elr, azr
  step = 30.0/86400.0
  jd = startjd : endd = startjd + 12.0
  inpass = 0 : npass = 0
  PRINT "DATE       AOS      LOS      MaxEl AzAOS AzTCA AzLOS"
  DO WHILE jd < endd AND npass < 10
    LOOKANG jd, obslat, obslon
    IF L_EL >= 0 AND inpass = 0 THEN
      a0 = jd-step : a1 = jd
      FOR k = 1 TO 25
        mm = 0.5*(a0+a1) : LOOKANG mm, obslat, obslon
        IF L_EL >= 0 THEN a1 = mm ELSE a0 = mm
      NEXT k
      aos = a1 : LOOKANG aos, obslat, obslon : azaos = L_AZ
      inpass = 1 : maxel = -PI
    ENDIF
    IF inpass = 1 THEN
      LOOKANG jd, obslat, obslon
      IF L_EL > maxel THEN maxel = L_EL : tca = jd
      IF L_EL < 0 THEN
        a0 = jd-step : a1 = jd
        FOR k = 1 TO 25
          mm = 0.5*(a0+a1) : LOOKANG mm, obslat, obslon
          IF L_EL >= 0 THEN a0 = mm ELSE a1 = mm
        NEXT k
        los = a0 : LOOKANG los, obslat, obslon : azlos = L_AZ
        t0 = tca-step : t1 = tca+step
        FOR k = 1 TO 40
          ml = t0+(t1-t0)/3 : mr = t1-(t1-t0)/3
          LOOKANG ml, obslat, obslon : ell = L_EL
          LOOKANG mr, obslat, obslon : elr = L_EL
          IF ell < elr THEN t0 = ml ELSE t1 = mr
        NEXT k
        tca = 0.5*(t0+t1) : LOOKANG tca, obslat, obslon
        maxel = L_EL : aztca = L_AZ
        CALDATE aos
        PRINT STR$(CY,4,0,"0");"-";STR$(CMO,2,0,"0");"-";STR$(CD,2,0,"0");" ";
        PRINT HMS$(CH,CMI,CS);" ";
        CALDATE los
        PRINT HMS$(CH,CMI,CS);" ";
        PRINT STR$(maxel*RAD,5,1);" ";STR$(azaos*RAD,5,1);" ";
        PRINT STR$(aztca*RAD,5,1);" ";STR$(azlos*RAD,5,1)
        inpass = 0 : npass = npass + 1
      ENDIF
    ENDIF
    jd = jd + step
  LOOP
END SUB

' ---------- Reference orbits (EQX) ----------
' returns crossing jd in RJD, lon(rad) in RLON; RFOUND=1 if found
DIM RJD, RLON, RFOUND
SUB FINDEQX daystart, asc
  LOCAL step, jd, endd, prevlat, lat, lon, a0, a1, mm, k, la, lo, crossing
  step = 60.0/86400.0
  jd = daystart : endd = daystart + 1.0
  prevlat = 999 : RFOUND = 0
  DO WHILE jd < endd
    SUBPOINT jd : lat = O_LAT
    IF prevlat <> 999 THEN
      IF asc = 1 THEN
        crossing = (prevlat < 0 AND lat >= 0)
      ELSE
        crossing = (prevlat > 0 AND lat <= 0)
      ENDIF
      IF crossing THEN
        a0 = jd-step : a1 = jd
        FOR k = 1 TO 40
          mm = 0.5*(a0+a1) : SUBPOINT mm : la = O_LAT
          IF (la >= 0) = (asc = 1) THEN a1 = mm ELSE a0 = mm
        NEXT k
        mm = 0.5*(a0+a1) : SUBPOINT mm
        RJD = mm : RLON = O_LON : RFOUND = 1
        EXIT SUB
      ENDIF
    ENDIF
    prevlat = lat
    jd = jd + step
  LOOP
END SUB

SUB DOREFORBITS startjd, southern
  LOCAL asc, day0, k, ds
  IF southern = 1 THEN asc = 0 ELSE asc = 1
  CALDATE startjd
  day0 = JDATE(CY, CMO, CD, 0, 0, 0)
  IF southern = 1 THEN
    PRINT "Ref orbits - first DESCENDING node EQX per UTC day"
  ELSE
    PRINT "Ref orbits - first ASCENDING node EQX per UTC day"
  ENDIF
  PRINT "DATE       UTC-TIME  EQX-LON"
  FOR k = 0 TO 9
    ds = day0 + k
    FINDEQX ds, asc
    IF RFOUND = 1 THEN
      CALDATE RJD
      PRINT STR$(CY,4,0,"0");"-";STR$(CMO,2,0,"0");"-";STR$(CD,2,0,"0");" ";
      PRINT HMS$(CH,CMI,CS);" ";LONFMT$(RLON*RAD)
    ENDIF
  NEXT k
END SUB

' ---------- Main ----------
DIM inc, ecc, raan, argp, ma, mm, ep$
DIM ey, emo, ed, eh, emi, es, epjd
DIM ny, nmo, nd, nh, nmi, ns, nowjd
DIM ch$, gflag$, grid$, lat, lon, southern

CLS
PRINT "=== OrbitCalc ==="
PRINT "Enter orbital elements:"
INPUT "  INCLINATION (deg): ", inc
INPUT "  ECCENTRICITY: ", ecc
INPUT "  RA_OF_ASC_NODE (deg): ", raan
INPUT "  ARG_OF_PERICENTER (deg): ", argp
INPUT "  MEAN_ANOMALY (deg): ", ma
INPUT "  MEAN_MOTION (rev/day): ", mm
PRINT "  EPOCH (UTC):"
INPUT "    Year: ", ey
INPUT "    Month: ", emo
INPUT "    Day: ", ed
INPUT "    Hour: ", eh
INPUT "    Min: ", emi
INPUT "    Sec: ", es
epjd = JDATE(ey, emo, ed, eh, emi, es)
SETSAT inc, ecc, raan, argp, ma, mm, epjd

PRINT "Current UTC date/time:"
INPUT "  Year: ", ny
INPUT "  Month: ", nmo
INPUT "  Day: ", nd
INPUT "  Hour: ", nh
INPUT "  Min: ", nmi
INPUT "  Sec: ", ns
nowjd = JDATE(ny, nmo, nd, nh, nmi, ns)

PRINT "1) Next 10 passes"
PRINT "2) 10-day reference orbit (EQX) table"
INPUT "Choose 1 or 2: ", ch$

INPUT "Use Maidenhead grid? (y/n): ", gflag$
IF UCASE$(gflag$) = "Y" THEN
  INPUT "  Grid: ", grid$
  MAIDEN grid$, lat, lon
ELSE
  INPUT "  Latitude (deg,+N): ", lat
  INPUT "  Longitude (deg,+E): ", lon
  lat = lat*DEG : lon = lon*DEG
ENDIF

IF ch$ = "1" THEN
  DOPASSES lat, lon, nowjd
ELSE
  IF lat < 0 THEN southern = 1 ELSE southern = 0
  DOREFORBITS nowjd, southern
ENDIF
END
