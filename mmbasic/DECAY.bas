' DECAY - element freshness & decay flag (PicoCalc / MMBasic).
OPTION EXPLICIT
OPTION DEFAULT FLOAT
CONST PI = 3.1415926535898
CONST TWOPI = 6.2831853071796
CONST MU = 398600.4418
CONST ERAD = 6378.137
DIM mm, ecc, ep, now, age, n, a, altp, alta
DIM ey, emo, ed, eh, emi, ny, nmo, nd, nh, nmi
PRINT "DECAY - freshness & decay"
INPUT "MM rev/day "; mm
INPUT "ECC "; ecc
PRINT "Epoch UTC:"
INPUT "  Yr "; ey
INPUT "  Mo "; emo
INPUT "  Dy "; ed
INPUT "  Hr "; eh
INPUT "  Mi "; emi
PRINT "Now UTC:"
INPUT "  Yr "; ny
INPUT "  Mo "; nmo
INPUT "  Dy "; nd
INPUT "  Hr "; nh
INPUT "  Mi "; nmi
ep = FNjd(ey, emo, ed, eh, emi, 0)
now = FNjd(ny, nmo, nd, nh, nmi, 0)
age = now - ep
n = mm * TWOPI / 86400.0
a = (MU / (n * n)) ^ (1.0 / 3.0)
altp = a * (1.0 - ecc) - ERAD
alta = a * (1.0 + ecc) - ERAD
PRINT "Age "; STR$(age,0,2); " days"
IF age < 0 THEN PRINT "! Now before epoch"
IF age > 14 THEN PRINT "! Very stale >14d"
IF age > 5 AND age <= 14 THEN PRINT "! Stale >5d"
IF age >= 0 AND age <= 5 THEN PRINT "Fresh enough"
PRINT "Mean alt "; STR$(a - ERAD,0,0); " km"
PRINT "Peri "; STR$(altp,0,0); " Apo "; STR$(alta,0,0); " km"
IF altp < 200 THEN PRINT "! Rapid decay-refresh daily"
IF altp >= 200 AND altp < 350 THEN PRINT "! Low peri-refresh 1-2d"
END

FUNCTION FNjd(y, mo, d, h, mi, s)
  LOCAL yy, mmo, aa, bb
  yy = y : mmo = mo
  IF mmo <= 2 THEN yy = yy - 1 : mmo = mmo + 12
  aa = INT(yy / 100) : bb = 2 - aa + INT(aa / 4)
  FNjd = INT(365.25 * (yy + 4716)) + INT(30.6001 * (mmo + 1)) + d + bb - 1524.5
  FNjd = FNjd + (h + mi / 60.0 + s / 3600.0) / 24.0
END FUNCTION
