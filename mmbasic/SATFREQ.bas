' SATFREQ - frequency & mode reference card (PicoCalc / MMBasic).
' Snapshot 2026-06; verify against current AMSAT list before a pass.
OPTION EXPLICIT
OPTION DEFAULT FLOAT
DIM INTEGER NS = 12
DIM nm$(NS), md$(NS), tn$(NS), nt$(NS)
DIM up(NS), dn(NS)
DIM INTEGER inv(NS)
DIM INTEGER i
DIM q$, hit
FOR i = 1 TO NS
  READ nm$(i), up(i), dn(i), md$(i), inv(i), tn$(i), nt$(i)
NEXT i
PRINT "SATFREQ - freq/mode card"
PRINT "snapshot 2026-06; verify!"
PRINT "name/part, L=list, Q=quit"
DO
  INPUT "> "; q$
  q$ = UCASE$(q$)
  IF q$ = "Q" THEN EXIT DO
  IF q$ = "L" THEN
    FOR i = 1 TO NS
      PRINT "  "; nm$(i)
    NEXT i
  ELSEIF q$ <> "" THEN
    hit = 0
    FOR i = 1 TO NS
      IF INSTR(nm$(i), q$) > 0 THEN
        CALL Show(i)
        hit = 1
      ENDIF
    NEXT i
    IF hit = 0 THEN PRINT "No match. L=list"
  ENDIF
LOOP
END

SUB Show(i)
  PRINT nm$(i)
  PRINT "  Up   "; STR$(up(i),0,3); " MHz"
  PRINT "  Down "; STR$(dn(i),0,3); " MHz"
  IF inv(i) = 1 THEN
    PRINT "  Mode "; md$(i); " (inv)"
  ELSE
    PRINT "  Mode "; md$(i); " (non-inv)"
  ENDIF
  IF tn$(i) <> "" THEN PRINT "  Tone "; tn$(i); " Hz"
  IF nt$(i) <> "" THEN PRINT "  Note "; nt$(i)
END SUB

' name, up, down, mode, inverting, tone, note
DATA "AO-7-A", 145.850, 29.400, "SSB/CW", 0, "", "Mode A sunlit only"
DATA "AO-7-B", 432.125, 145.975, "SSB/CW", 1, "", "Mode B inv sunlit"
DATA "AO-27", 145.850, 436.795, "FM", 0, "", "FM schedule-gated"
DATA "AO-91", 435.250, 145.960, "FM", 0, "67.0", "Fox-1 67Hz"
DATA "SO-50", 145.850, 436.795, "FM", 0, "67.0", "67Hz;74.4 arms timer"
DATA "ISS-FM", 145.990, 437.800, "FM", 0, "67.0", "Crossband FM"
DATA "ISS-AP", 145.825, 145.825, "APRS", 0, "", "APRS digipeater"
DATA "FO-29", 145.900, 435.800, "SSB/CW", 1, "", "Linear inv gated"
DATA "RS-44", 145.965, 435.640, "SSB/CW", 1, "", "Linear inv wide"
DATA "PO-101", 437.500, 145.900, "FM", 0, "141.3", "Diwata-2 gated"
DATA "TEVEL", 145.970, 436.400, "FM", 0, "67.0", "TEVEL per-sat"
DATA "QO-100", 2400.250, 10489.750, "SSB/CW", 1, "", "GEO NB Es'hail-2"
