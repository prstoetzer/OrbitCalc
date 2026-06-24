' ORBDATA - orbital data from GP/OMM elements (PicoCalc / MMBasic)
' Closed-form summary: semi-major axis, period, apogee/perigee,
' velocities, J2 node/perigee drift, footprint, ground-track shift.
OPTION EXPLICIT
OPTION DEFAULT FLOAT
CONST PI = 3.1415926535898
CONST TWOPI = 6.2831853071796
CONST DEG = PI / 180.0
CONST RAD = 180.0 / PI
CONST MU = 398600.4418
CONST ERAD = 6378.137
CONST J2C = 1.08262668E-3

DIM inc, ecc, mm, n, a, i, rp, ra, p, f
DIM raandot, argpdot, vp, va, vc, per, foot, shift

CLS
PRINT "ORBDATA - orbital data"
PRINT
INPUT "INCLINATION deg "; inc
INPUT "ECCENTRICITY    "; ecc
INPUT "MEAN_MOTION r/d "; mm
n = mm * TWOPI / 86400.0
a = (MU / (n * n)) ^ (1.0 / 3.0)
i = inc * DEG
rp = a * (1 - ecc)
ra = a * (1 + ecc)
p = a * (1 - ecc * ecc)
f = 1.5 * J2C * (ERAD / p) ^ 2 * n
raandot = -f * COS(i) * RAD * 86400.0
argpdot = f * (2 - 2.5 * SIN(i) ^ 2) * RAD * 86400.0
vp = SQR(MU * (2 / rp - 1 / a))
va = SQR(MU * (2 / ra - 1 / a))
vc = SQR(MU / a)
per = 1440.0 / mm
foot = ACOSS(ERAD / ((ra + rp) / 2))
shift = 360.0 / mm
PRINT
PRINT "Semi-major a : "; STR$(a, 0, 1); " km"
PRINT "Period       : "; STR$(per, 0, 2); " min"
PRINT "Apogee  alt  : "; STR$(ra - ERAD, 0, 1); " km"
PRINT "Perigee alt  : "; STR$(rp - ERAD, 0, 1); " km"
PRINT "Vel perigee  : "; STR$(vp, 0, 4); " km/s"
PRINT "Vel apogee   : "; STR$(va, 0, 4); " km/s"
PRINT "Vel circular : "; STR$(vc, 0, 4); " km/s"
PRINT "Node drift   : "; STR$(raandot, 0, 4); " deg/day"
PRINT "Perigee drift: "; STR$(argpdot, 0, 4); " deg/day"
PRINT "Footprint    : "; STR$(foot * RAD, 0, 1); " deg ("; STR$(foot * ERAD, 0, 0); " km)"
PRINT "Lon/orbit    : "; STR$(shift, 0, 2); " deg W"
END

FUNCTION ACOSS(x)
  LOCAL v
  v = x
  IF v > 1 THEN v = 1
  IF v < -1 THEN v = -1
  ACOSS = PI / 2 - ATN(v / SQR(1 - v * v + 1E-18))
END FUNCTION
