' ELCHECK - GP/OMM element-set sanity checker (PicoCalc / MMBasic)
' Flags likely transcription errors before you waste a pass.
OPTION EXPLICIT
OPTION DEFAULT FLOAT
CONST PI = 3.1415926535898
CONST TWOPI = 6.2831853071796
CONST MU = 398600.4418
CONST ERAD = 6378.137

DIM inc, ecc, raan, argp, ma, mm, n, a, altp, alta
DIM INTEGER nwarn

CLS
PRINT "ELCHECK - element sanity"
PRINT
INPUT "INC  "; inc
INPUT "ECC  "; ecc
INPUT "RAAN "; raan
INPUT "ARGP "; argp
INPUT "MA   "; ma
INPUT "MM   "; mm
PRINT
nwarn = 0
IF inc < 0 OR inc > 180 THEN PRINT "! INC out of 0..180" : nwarn = nwarn + 1
IF ecc < 0 OR ecc >= 1 THEN PRINT "! ECC out of 0..1 (need <1)" : nwarn = nwarn + 1
IF raan < 0 OR raan >= 360 THEN PRINT "! RAAN out of 0..360" : nwarn = nwarn + 1
IF argp < 0 OR argp >= 360 THEN PRINT "! ARGP out of 0..360" : nwarn = nwarn + 1
IF ma < 0 OR ma >= 360 THEN PRINT "! MA out of 0..360" : nwarn = nwarn + 1
IF mm <= 0 THEN
  PRINT "! MM must be > 0"
  nwarn = nwarn + 1
ELSE
  n = mm * TWOPI / 86400.0
  a = (MU / (n * n)) ^ (1.0 / 3.0)
  altp = a * (1 - ecc) - ERAD
  alta = a * (1 + ecc) - ERAD
  IF altp < 0 THEN PRINT "! Perigee below surface ("; STR$(altp, 0, 0); " km)" : nwarn = nwarn + 1
  IF mm > 17.5 THEN PRINT "! MM very high - decay or typo?" : nwarn = nwarn + 1
  IF mm < 0.5 THEN PRINT "! MM very low - beyond GEO or typo?" : nwarn = nwarn + 1
ENDIF
IF nwarn = 0 THEN PRINT "No range problems found."
PRINT
PRINT "Notes:"
IF mm > 0 THEN
  PRINT "  a = "; STR$(a, 0, 0); " km, period "; STR$(1440.0 / mm, 0, 2); " min"
  PRINT "  Perigee alt "; STR$(altp, 0, 0); " km, apogee "; STR$(alta, 0, 0); " km"
  IF mm > 0.95 AND mm < 1.05 AND ecc < 0.01 THEN PRINT "  Looks GEO/GSO"
  IF mm > 11 THEN PRINT "  Looks LEO"
  IF mm > 1.5 AND mm <= 11 THEN PRINT "  Looks MEO"
  IF ecc > 0.5 THEN PRINT "  Highly eccentric (Molniya/HEO-like)"
  IF inc > 90 THEN PRINT "  Retrograde / sun-synchronous-ish"
ENDIF
END
