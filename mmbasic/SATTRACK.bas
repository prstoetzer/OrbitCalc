' ============================================================
'  SATTRACK - Graphical Satellite Pass Predictor for PicoCalc
'  MMBasic (PicoMite) for the ClockworkPi PicoCalc (320x320 LCD)
'
'  Features:
'    1) Set location, date and time (UTC)
'    2) Enter / edit / save up to 20 satellites' elements
'    3) Next 10 passes of one satellite (list)
'    4) Next/current pass polar plot of one satellite
'    5) Next 3 passes of ALL satellites, sorted by time
'    6) World map: your location + footprints of all sats
'
'  Orbit model: secular-J2 mean-element propagation + Kepler.
'  Elements are the AMSAT daily-bulletin / GP fields.
'
'  Files (SD card, drive B:):
'    B:/sats.dat   - saved satellite elements
'    B:/loc.dat    - saved observer location
' ============================================================

OPTION EXPLICIT
OPTION DEFAULT FLOAT

' ---- math constants ----
CONST PI = 3.1415926535898
CONST TWOPI = 6.2831853071796
CONST DEG = PI / 180.0
CONST RAD = 180.0 / PI
CONST MU = 398600.4418
CONST ERAD = 6378.137
CONST J2C = 1.08262668E-3
' Maximum satellites held in RAM. PicoMite strings default to 255 bytes, so the
' name array is explicitly LENGTH-limited (below) to keep the store compact:
' ~200 sats x (9 floats + 1 int + a 20-byte name) ~ 20 KB.
CONST MAXSAT = 200
CONST NAMELEN = 20

' ---- display geometry (read at runtime) ----
DIM SH
DIM INTEGER SW
SW = MM.HRES
SH = MM.VRES
' PicoCalc physical panel is 320x320; clamp working height
IF SH > 320 THEN SH = 320

' ---- colours ----
DIM CFG, CACC, CGRID, CSAT, CWARN, CFOOT, CLAND
DIM INTEGER CBG
CBG = RGB(0, 0, 0)
CFG = RGB(255, 255, 255)
CACC = RGB(0, 200, 255)
CGRID = RGB(60, 60, 60)
CSAT = RGB(255, 80, 80)
CWARN = RGB(255, 220, 0)
CFOOT = RGB(0, 220, 120)
CLAND = RGB(40, 90, 160)

' ---- observer state ----
DIM OBLAT, OBLON          ' radians
DIM OBGRID$
DIM NMO, ND, NH, NMI   ' current UTC date/time
DIM INTEGER NY
DIM NOWJD

' ---- satellite store ----
DIM NSAT INTEGER
DIM SATNAME$(MAXSAT) LENGTH NAMELEN
DIM SINC(MAXSAT), SECC(MAXSAT), SRAAN(MAXSAT)
DIM SARGP(MAXSAT), SMA(MAXSAT), SMM(MAXSAT), SEPJD(MAXSAT)
' downlink/uplink (MHz) and inverting flag for Doppler readout (0 = unknown)
DIM SDN(MAXSAT), SUP(MAXSAT)
DIM INTEGER SINV(MAXSAT)

' ---- working orbit (the "loaded" satellite) ----
DIM WI, WE, WO, WG, WM, WN, WJ, WA, WRD, WPD

' ---- propagation outputs ----
DIM GX, GY, GZ, EX, EY, EZ, BLAT, BLON, LEL, LAZ, LRNG
' ---- sun position ----
DIM SUNX, SUNY, SUNZ, SUNLAT, SUNLON
' ---- calendar outputs ----
DIM CMO, CD, CH, CMI
DIM INTEGER CY
DIM CS
' ---- find-pass outputs ----
DIM FP_AOS, FP_LOS, FP_TCA, FP_MEL
DIM INTEGER FP_OK

' ---- OSCARLOCATOR view state ----
' Projection: OVMODE 0 = polar azimuthal-equidistant (default, auto N/S),
'             OVMODE 1 = QTH-centred azimuthal-equidistant (optional).
DIM OVCX, OVCY, OVRR          ' map centre + radius (pixels)
DIM OVPY, OVPOK               ' Project outputs
DIM INTEGER OVPX
DIM INTEGER OVMODE, OVNHEMI   ' projection mode; polar hemisphere (1=N, 0=S)
DIM OVQLAT, OVQLON            ' centre lat/lon for QTH mode (radians)
DIM OVPER                     ' loaded sat orbital period (minutes)
CONST OVNTRK = 96
DIM OVTLAT(OVNTRK), OVTLON(OVNTRK)
DIM INTEGER OVNPTS

DIM DUMMY$
NSAT = 0
OBLAT = 38.9 * DEG
OBLON = -77.0 * DEG
OBGRID$ = "FM18LV"
NY = 2026 : NMO = 6 : ND = 22 : NH = 0 : NMI = 0

CALL LoadLoc
CALL LoadSats
CALL MainMenu
END

' ============================================================
'  MENU SYSTEM
' ============================================================
CONST NMENU = 13

SUB MainMenu
  LOCAL sel
  LOCAL INTEGER k
  sel = 1
  DO
    CALL DrawMenu(sel)
    k = ASC(UCASE$(WaitKey$()))
    IF k = 128 THEN sel = sel - 1     ' up arrow
    IF k = 129 THEN sel = sel + 1     ' down arrow
    IF sel < 1 THEN sel = NMENU
    IF sel > NMENU THEN sel = 1
    IF k = 13 THEN CALL RunItem(sel)  ' enter
    IF k >= 49 AND k <= 57 THEN CALL RunItem(k - 48)  ' 1..9
    IF k = 48 THEN CALL RunItem(10)   ' 0 = item 10
    IF k = ASC("A") THEN CALL RunItem(11)
    IF k = ASC("B") THEN CALL RunItem(12)
    IF k = ASC("C") THEN CALL RunItem(13)
  LOOP UNTIL k = 27                    ' ESC quits
  CLS
  PRINT "Bye."
END SUB

SUB DrawMenu(sel AS INTEGER)
  LOCAL y
  LOCAL INTEGER i, top, vis, last
  CLS CBG
  CALL Header("SATTRACK  -  PicoCalc")
  CALL StatusLine
  LOCAL m$(NMENU)
  m$(1) = "1 Set location / date / time"
  m$(2) = "2 Edit satellites (" + STR$(NSAT) + ")"
  m$(3) = "3 Load elements (TLE or JSON)"
  m$(4) = "4 Next 10 passes (one sat)"
  m$(5) = "5 Polar plot (one sat)"
  m$(6) = "6 Live track + Doppler (one sat)"
  m$(7) = "7 Next 3 passes (all sats)"
  m$(8) = "8 World map (sats+terminator)"
  m$(9) = "9 Pass ground-track preview"
  m$(10) = "0 OSCARLOCATOR (polar/QTH)"
  m$(11) = "A Pass watch + AOS alarm"
  m$(12) = "B Pass detail (el plot)"
  m$(13) = "C Sun position + glyph"
  vis = (SH - 64) \ 18
  IF vis > NMENU THEN vis = NMENU
  top = 1
  IF sel > top + vis - 1 THEN top = sel - vis + 1
  IF sel < top THEN top = sel
  last = top + vis - 1
  IF last > NMENU THEN last = NMENU
  y = 50
  FOR i = top TO last
    IF i = sel THEN
      BOX 6, y - 2, SW - 12, 15, 1, CACC, RGB(0, 40, 60)
      TEXT 12, y, m$(i), "L", 1, 1, CFG
    ELSE
      TEXT 12, y, m$(i), "L", 1, 1, CFG
    ENDIF
    y = y + 18
  NEXT i
  IF top > 1 THEN TEXT SW - 6, 46, CHR$(24), "RT", 7, 1, CWARN
  IF last < NMENU THEN TEXT SW - 6, SH - 28, CHR$(25), "RB", 7, 1, CWARN
  TEXT 6, SH - 14, "1-9,0,A-C or Up/Dn+Enter. ESC", "L", 7, 1, CGRID
END SUB

SUB Header(t$)
  BOX 0, 0, SW, 18, 1, CACC, RGB(0, 30, 45)
  TEXT 4, 3, t$, "L", 1, 1, CACC
END SUB

SUB StatusLine
  LOCAL s$
  s$ = "Grid " + OBGRID$ + "  " + Z2$(NH) + ":" + Z2$(NMI) + "Z " + Z2$(ND) + "/" + Z2$(NMO)
  TEXT 4, 22, s$, "L", 7, 1, CWARN
  TEXT 4, 36, "Sats loaded: " + STR$(NSAT), "L", 7, 1, CFOOT
END SUB

SUB RunItem(n AS INTEGER)
  SELECT CASE n
    CASE 1 : CALL SetLocation
    CASE 2 : CALL EditSats
    CASE 3 : CALL LoadFromSD
    CASE 4 : CALL Next10
    CASE 5 : CALL PolarPlot
    CASE 6 : CALL LiveTrack
    CASE 7 : CALL AllNext3
    CASE 8 : CALL WorldMap
    CASE 9 : CALL TrackPreview
    CASE 10 : CALL OscarView
    CASE 11 : CALL PassWatch
    CASE 12 : CALL PassDetail
    CASE 13 : CALL SunView
  END SELECT
END SUB

' ============================================================
'  1) LOCATION / DATE / TIME
' ============================================================
SUB SetLocation
  LOCAL g$, a$, la, lo, u$
  CLS CBG
  CALL Header("Set Location / Time")
  TEXT 4, 26, "Maidenhead grid (blank=lat/lon):", "L", 7, 1, CFG
  g$ = AskStr$("Grid", 6, 44)
  IF LEN(g$) >= 4 THEN
    CALL Maiden(g$)
    OBGRID$ = UCASE$(g$)
  ELSE
    la = AskNum("Lat +N", 6, 64)
    lo = AskNum("Lon +E", 6, 84)
    OBLAT = la * DEG
    OBLON = lo * DEG
    OBGRID$ = GridFromLL$(OBLAT, OBLON)
  ENDIF
  TEXT 4, 104, "Time: R=read PicoCalc RTC, M=manual", "L", 7, 1, CACC
  u$ = UCASE$(WaitKey$())
  IF u$ = "R" THEN
    IF GetRTC() = 1 THEN
      CALL Flash("RTC -> " + Z2$(NH) + ":" + Z2$(NMI) + "Z")
    ELSE
      CALL Flash("RTC not set")
    ENDIF
  ELSE
    TEXT 4, 122, "UTC date/time:", "L", 7, 1, CACC
    NY = AskNum("Year", 6, 138)
    NMO = AskNum("Month", 6, 154)
    ND = AskNum("Day", 6, 170)
    NH = AskNum("Hour", 6, 186)
    NMI = AskNum("Min", 6, 202)
  ENDIF
  NOWJD = FNjd(NY, NMO, ND, NH, NMI, 0)
  CALL SaveLoc
  CALL Flash("Saved.")
END SUB

' Read the PicoMite RTC into the NOW fields. Returns 1 if it looks valid.
' The PicoCalc RTC is assumed to hold UTC. RTC GETTIME loads MM.DAY$ etc.,
' but we read the numeric DATE$/TIME$ which PicoMite keeps in sync with the RTC.
FUNCTION GetRTC()
  LOCAL d$, t$
  LOCAL INTEGER yy
  ON ERROR SKIP
  RTC GETTIME
  d$ = DATE$        ' "DD-MM-YYYY"
  t$ = TIME$        ' "HH:MM:SS"
  yy = VAL(MID$(d$, 7, 4))
  IF yy < 2020 OR yy > 2099 THEN GetRTC = 0 : EXIT FUNCTION
  ND  = VAL(MID$(d$, 1, 2))
  NMO = VAL(MID$(d$, 4, 2))
  NY  = yy
  NH  = VAL(MID$(t$, 1, 2))
  NMI = VAL(MID$(t$, 4, 2))
  NOWJD = FNjd(NY, NMO, ND, NH, NMI, VAL(MID$(t$, 7, 2)))
  GetRTC = 1
END FUNCTION

' ============================================================
'  2) EDIT / ENTER SATELLITES
' ============================================================
SUB EditSats
  LOCAL sel
  LOCAL INTEGER k, i, top, vis, last
  LOCAL y
  sel = 1
  top = 1
  vis = (SH - 84) \ 14
  IF vis < 1 THEN vis = 1
  DO
    IF sel < top THEN top = sel
    IF sel > top + vis - 1 THEN top = sel - vis + 1
    last = top + vis - 1
    IF last > NSAT THEN last = NSAT
    CLS CBG
    CALL Header("Satellites  (" + STR$(NSAT) + "/" + STR$(MAXSAT) + ")")
    y = 24
    IF NSAT = 0 THEN TEXT 6, y, "(none yet)", "L", 7, 1, CGRID
    FOR i = top TO last
      IF i = sel THEN
        BOX 4, y - 1, SW - 8, 13, 1, CACC, RGB(0, 35, 50)
      ENDIF
      TEXT 8, y, Str3i$(i) + " " + SATNAME$(i), "L", 7, 1, CFG
      y = y + 14
    NEXT i
    IF top > 1 THEN TEXT SW - 6, 24, CHR$(24), "RT", 7, 1, CWARN
    IF last < NSAT THEN TEXT SW - 6, SH - 56, CHR$(25), "RB", 7, 1, CWARN
    TEXT 4, SH - 52, "A=Add  E=Edit  D=Del", "L", 7, 1, CWARN
    TEXT 4, SH - 40, "Up/Dn Lt/Rt page  ESC=back", "L", 7, 1, CWARN
    k = ASC(UCASE$(WaitKey$()))
    IF k = 128 THEN sel = sel - 1
    IF k = 129 THEN sel = sel + 1
    IF k = 130 THEN sel = sel - vis
    IF k = 131 THEN sel = sel + vis
    IF sel < 1 THEN sel = 1
    IF sel > NSAT THEN sel = NSAT
    IF NSAT = 0 THEN sel = 1
    IF k = ASC("A") THEN CALL AddSat
    IF k = ASC("E") AND NSAT > 0 THEN CALL EditOneSat(sel)
    IF k = ASC("D") AND NSAT > 0 THEN CALL DelSat(sel) : IF sel > NSAT THEN sel = NSAT
  LOOP UNTIL k = 27
END SUB

SUB AddSat
  IF NSAT >= MAXSAT THEN CALL Flash("Full (20 max)") : EXIT SUB
  NSAT = NSAT + 1
  SATNAME$(NSAT) = ""
  CALL EditOneSat(NSAT)
  IF SATNAME$(NSAT) = "" THEN NSAT = NSAT - 1   ' cancelled
END SUB

SUB EditOneSat(ix AS INTEGER)
  LOCAL nm$, ey, emo, ed, eh, emi, es
  CLS CBG
  CALL Header("Edit sat #" + STR$(ix))
  nm$ = AskStr$("Name", 6, 24)
  IF LEN(nm$) = 0 THEN nm$ = SATNAME$(ix)
  IF LEN(nm$) = 0 THEN CALL Flash("Cancelled") : EXIT SUB
  SATNAME$(ix) = LEFT$(UCASE$(nm$), NAMELEN)
  SINC(ix)  = AskNum("INC", 6, 40)
  SECC(ix)  = AskNum("ECC", 6, 56)
  SRAAN(ix) = AskNum("RAAN", 6, 72)
  SARGP(ix) = AskNum("ARGP", 6, 88)
  SMA(ix)   = AskNum("MA", 6, 104)
  SMM(ix)   = AskNum("MM rev/d", 6, 120)
  TEXT 4, 140, "Epoch UTC:", "L", 7, 1, CACC
  ey  = AskNum("Yr", 6, 156)
  emo = AskNum("Mon", 6, 172)
  ed  = AskNum("Day", 6, 188)
  eh  = AskNum("Hr", 6, 204)
  emi = AskNum("Min", 6, 220)
  es  = AskNum("Sec", 6, 236)
  SEPJD(ix) = FNjd(ey, emo, ed, eh, emi, es)
  TEXT 4, 252, "Radio (MHz, 0=skip):", "L", 7, 1, CACC
  SDN(ix) = AskNum("Downlink", 6, 268)
  SUP(ix) = AskNum("Uplink", 6, 284)
  SINV(ix) = AskNum("Invert 1/0", 6, 300)
  CALL SaveSats
  CALL Flash("Saved " + SATNAME$(ix))
END SUB

SUB DelSat(ix AS INTEGER)
  LOCAL INTEGER i
  FOR i = ix TO NSAT - 1
    SATNAME$(i) = SATNAME$(i + 1)
    SINC(i) = SINC(i + 1) : SECC(i) = SECC(i + 1)
    SRAAN(i) = SRAAN(i + 1) : SARGP(i) = SARGP(i + 1)
    SMA(i) = SMA(i + 1) : SMM(i) = SMM(i + 1) : SEPJD(i) = SEPJD(i + 1)
    SDN(i) = SDN(i + 1) : SUP(i) = SUP(i + 1) : SINV(i) = SINV(i + 1)
  NEXT i
  NSAT = NSAT - 1
  CALL SaveSats
END SUB

' ============================================================
'  3) LOAD ELEMENTS FROM SD CARD (TLE format)
' ============================================================
' Reads a standard NORAD 2-line element file (optionally with a name line,
' "3LE" format) from the SD card and appends each satellite to the store.
' Default path B:/tle.txt - editable. Each TLE set is:
'   AO-7                       <- optional name (<= 24 chars, no leading "1 "/"2 ")
'   1 07530U 74089B   26171...
'   2 07530 101.9899 184.6033 0012609 124.3014 247.3322 12.53698149...
SUB LoadFromSD
  LOCAL path$, l$, c$
  LOCAL INTEGER f, added
  CLS CBG
  CALL Header("Load elements from SD")
  TEXT 4, 24, "Reads TLE (.txt) or OMM/JSON", "L", 7, 1, CFG
  TEXT 4, 38, "(AMSAT or Celestrak GP) from SD.", "L", 7, 1, CGRID
  path$ = AskStr$("File [B:/tle.txt]", 6, 58)
  IF path$ = "" THEN path$ = "B:/tle.txt"
  IF MM.INFO(EXISTS FILE path$) = 0 THEN CALL Flash("Not found") : EXIT SUB
  ' --- sniff the first non-blank character to choose the parser ---
  f = 2
  OPEN path$ FOR INPUT AS #f
  c$ = ""
  DO WHILE NOT EOF(#f) AND c$ = ""
    LINE INPUT #f, l$
    l$ = Trim$(l$)
    IF LEN(l$) > 0 THEN c$ = LEFT$(l$, 1)
  LOOP
  CLOSE #f
  IF c$ = "[" OR c$ = "{" THEN
    added = LoadJSON(path$)
  ELSE
    added = LoadTLE(path$)
  ENDIF
  CALL SaveSats
  CALL Flash(STR$(added) + " loaded, " + STR$(NSAT) + " total")
END SUB

' Parse a NORAD TLE / 3LE text file. Returns the count added.
FUNCTION LoadTLE(path$)
  LOCAL nm$, l1$, l2$, l$
  LOCAL INTEGER f, added, havename
  f = 2
  added = 0
  nm$ = "" : havename = 0
  OPEN path$ FOR INPUT AS #f
  DO WHILE NOT EOF(#f)
    LINE INPUT #f, l$
    l$ = Trim$(l$)
    IF LEN(l$) = 0 THEN
      ' blank line - ignore
    ELSEIF LEFT$(l$, 2) = "1 " THEN
      l1$ = l$
      IF NOT EOF(#f) THEN LINE INPUT #f, l2$ : l2$ = Trim$(l2$)
      IF LEFT$(l2$, 2) = "2 " THEN
        IF havename = 0 THEN nm$ = "SAT" + STR$(NSAT + 1)
        CALL AddTLE(nm$, l1$, l2$)
        added = added + 1
      ENDIF
      nm$ = "" : havename = 0
    ELSE
      nm$ = UCASE$(LEFT$(l$, NAMELEN))
      havename = 1
    ENDIF
    IF NSAT >= MAXSAT THEN EXIT DO
  LOOP
  CLOSE #f
  LoadTLE = added
END FUNCTION

' Parse an OMM/JSON file (AMSAT daily-bulletin.json or Celestrak GP json-pretty).
' Both are JSON arrays of objects with one key per line in the pretty form, e.g.
'   "OBJECT_NAME": "OSCAR 7",
'   "EPOCH": "2026-06-22T12:14:23.563680",
'   "MEAN_MOTION": 12.53698175,
' We scan line by line, collect the fields we need per object, and commit the
' satellite when the object closes ("}"). Entries with a null/blank epoch or
' mean motion are skipped (some bulletin rows are all-null placeholders).
FUNCTION LoadJSON(path$)
  LOCAL l$, key$, val$
  LOCAL nm$, amsat$, epoch$
  LOCAL inc, ecc, raan, argp, ma, mm
  LOCAL INTEGER f, added, have
  f = 2
  added = 0
  OPEN path$ FOR INPUT AS #f
  CALL ResetOMM(nm$, amsat$, epoch$, inc, ecc, raan, argp, ma, mm, have)
  DO WHILE NOT EOF(#f)
    LINE INPUT #f, l$
    l$ = Trim$(l$)
    IF INSTR(l$, "}") > 0 THEN
      ' object closed - commit if usable
      IF have = 1 AND mm > 0 AND LEN(epoch$) >= 10 THEN
        IF LEN(amsat$) > 0 THEN nm$ = amsat$
        IF LEN(nm$) = 0 THEN nm$ = "SAT" + STR$(NSAT + 1)
        CALL AddOMM(nm$, inc, ecc, raan, argp, ma, mm, epoch$)
        added = added + 1
      ENDIF
      CALL ResetOMM(nm$, amsat$, epoch$, inc, ecc, raan, argp, ma, mm, have)
      IF NSAT >= MAXSAT THEN EXIT DO
    ELSEIF INSTR(l$, ":") > 0 AND LEFT$(l$, 1) = CHR$(34) THEN
      key$ = JKey$(l$)
      val$ = JVal$(l$)
      IF key$ = "AMSAT_NAME" THEN amsat$ = UCASE$(JStr$(val$))
      IF key$ = "OBJECT_NAME" THEN nm$ = UCASE$(JStr$(val$))
      IF key$ = "EPOCH" THEN epoch$ = JStr$(val$)
      IF key$ = "INCLINATION" THEN inc = VAL(val$) : have = 1
      IF key$ = "ECCENTRICITY" THEN ecc = VAL(val$)
      IF key$ = "RA_OF_ASC_NODE" THEN raan = VAL(val$)
      IF key$ = "ARG_OF_PERICENTER" THEN argp = VAL(val$)
      IF key$ = "MEAN_ANOMALY" THEN ma = VAL(val$)
      IF key$ = "MEAN_MOTION" THEN mm = VAL(val$)
    ENDIF
  LOOP
  CLOSE #f
  LoadJSON = added
END FUNCTION

' Clear the per-object accumulators.
SUB ResetOMM(nm$, amsat$, epoch$, inc, ecc, raan, argp, ma, mm, have AS INTEGER)
  nm$ = "" : amsat$ = "" : epoch$ = ""
  inc = 0 : ecc = 0 : raan = 0 : argp = 0 : ma = 0 : mm = 0
  have = 0
END SUB

' Commit one OMM record. ECCENTRICITY is already a real decimal (not implied).
SUB AddOMM(nm$, inc, ecc, raan, argp, ma, mm, epoch$)
  IF NSAT >= MAXSAT THEN EXIT SUB
  NSAT = NSAT + 1
  SATNAME$(NSAT) = LEFT$(nm$, NAMELEN)
  SINC(NSAT) = inc : SECC(NSAT) = ecc : SRAAN(NSAT) = raan
  SARGP(NSAT) = argp : SMA(NSAT) = ma : SMM(NSAT) = mm
  SEPJD(NSAT) = JDfromISO(epoch$)
  SDN(NSAT) = 0 : SUP(NSAT) = 0 : SINV(NSAT) = 0
END SUB

' --- tiny JSON line helpers (one key:value per line) ---
' Extract the key name (text between the first pair of double-quotes).
FUNCTION JKey$(l$)
  LOCAL INTEGER a, b
  a = INSTR(l$, CHR$(34))
  b = INSTR(a + 1, l$, CHR$(34))
  IF a > 0 AND b > a THEN JKey$ = MID$(l$, a + 1, b - a - 1) ELSE JKey$ = ""
END FUNCTION

' Everything after the first colon, trimmed, with any trailing comma removed.
FUNCTION JVal$(l$)
  LOCAL r$
  LOCAL INTEGER c
  c = INSTR(l$, ":")
  IF c = 0 THEN JVal$ = "" : EXIT FUNCTION
  r$ = Trim$(MID$(l$, c + 1))
  DO WHILE LEN(r$) > 0 AND RIGHT$(r$, 1) = ","
    r$ = Trim$(LEFT$(r$, LEN(r$) - 1))
  LOOP
  JVal$ = r$
END FUNCTION

' Strip surrounding double-quotes from a JSON string value.
FUNCTION JStr$(v$)
  LOCAL r$
  r$ = v$
  IF LEN(r$) >= 2 AND LEFT$(r$, 1) = CHR$(34) AND RIGHT$(r$, 1) = CHR$(34) THEN
    r$ = MID$(r$, 2, LEN(r$) - 2)
  ENDIF
  JStr$ = r$
END FUNCTION

' Julian Date from an ISO-8601 epoch "YYYY-MM-DDxHH:MM:SS(.ffffff)" where x is
' 'T' or a space. Returns 0 if the string is null/blank/too short.
FUNCTION JDfromISO(s$)
  LOCAL yy, mo, dd, hh, mi, ss
  IF LEN(s$) < 19 THEN JDfromISO = 0 : EXIT FUNCTION
  yy = VAL(MID$(s$, 1, 4))
  mo = VAL(MID$(s$, 6, 2))
  dd = VAL(MID$(s$, 9, 2))
  hh = VAL(MID$(s$, 12, 2))
  mi = VAL(MID$(s$, 15, 2))
  ss = VAL(MID$(s$, 18))          ' seconds + fraction to end of string
  JDfromISO = FNjd(yy, mo, dd, hh, mi, ss)
END FUNCTION

' Parse one TLE pair into a new satellite slot.
SUB AddTLE(nm$, l1$, l2$)
  LOCAL inc, raan, ecc, argp, ma, mm, ey, doy, epjd
  LOCAL es$
  IF NSAT >= MAXSAT THEN EXIT SUB
  ' --- epoch from line 1: cols 19-20 = 2-digit year, 21-32 = day-of-year.frac ---
  ey = VAL(MID$(l1$, 19, 2))
  IF ey < 57 THEN ey = ey + 2000 ELSE ey = ey + 1900
  doy = VAL(MID$(l1$, 21, 12))
  epjd = JDfromYearDoy(ey, doy)
  ' --- orbit from line 2 (fixed columns per the NORAD spec) ---
  inc  = VAL(MID$(l2$, 9, 8))
  raan = VAL(MID$(l2$, 18, 8))
  es$  = "0." + Trim$(MID$(l2$, 27, 7))   ' decimal point is implied
  ecc  = VAL(es$)
  argp = VAL(MID$(l2$, 35, 8))
  ma   = VAL(MID$(l2$, 44, 8))
  mm   = VAL(MID$(l2$, 53, 11))
  NSAT = NSAT + 1
  SATNAME$(NSAT) = nm$
  SINC(NSAT) = inc : SECC(NSAT) = ecc : SRAAN(NSAT) = raan
  SARGP(NSAT) = argp : SMA(NSAT) = ma : SMM(NSAT) = mm
  SEPJD(NSAT) = epjd
  SDN(NSAT) = 0 : SUP(NSAT) = 0 : SINV(NSAT) = 0
END SUB

' Julian Date from a 4-digit year and a day-of-year (1.0 = Jan 1 00:00).
FUNCTION JDfromYearDoy(yr, doy)
  LOCAL jan1
  jan1 = FNjd(yr, 1, 1, 0, 0, 0)
  JDfromYearDoy = jan1 + (doy - 1.0)
END FUNCTION

FUNCTION Trim$(s$)
  LOCAL r$
  r$ = s$
  DO WHILE LEN(r$) > 0 AND (LEFT$(r$, 1) = " " OR LEFT$(r$, 1) = CHR$(9) OR LEFT$(r$, 1) = CHR$(13))
    r$ = MID$(r$, 2)
  LOOP
  DO WHILE LEN(r$) > 0 AND (RIGHT$(r$, 1) = " " OR RIGHT$(r$, 1) = CHR$(9) OR RIGHT$(r$, 1) = CHR$(13))
    r$ = LEFT$(r$, LEN(r$) - 1)
  LOOP
  Trim$ = r$
END FUNCTION

' ============================================================
'  3) NEXT 10 PASSES OF ONE SATELLITE
' ============================================================
SUB Next10
  LOCAL INTEGER ix
  ix = PickSat("Next 10 passes")
  IF ix = 0 THEN EXIT SUB
  CALL LoadSat(ix)
  CLS CBG
  CALL Header("Passes: " + SATNAME$(ix))
  TEXT 2, 20, "DATE  AOS   LOS   El AzA/T/L", "L", 7, 1, CACC
  LOCAL stp, j, endd, npass, k
  LOCAL INTEGER inpass
  LOCAL maxel, azaos, aztca, azlos, aos, los, tca
  LOCAL a0, a1, m, t0, t1, ml, mr, ell, elr
  LOCAL INTEGER yrow
  LOCAL r$
  stp = 30.0 / 86400.0
  j = NOWJD : endd = NOWJD + 12.0
  inpass = 0 : npass = 0 : maxel = -9 : yrow = 32
  DO WHILE j < endd AND npass < 10
    CALL Look(j, OBLAT, OBLON)
    IF LEL >= 0 AND inpass = 0 THEN
      a0 = j - stp : a1 = j
      FOR k = 1 TO 25
        m = (a0 + a1) / 2 : CALL Look(m, OBLAT, OBLON)
        IF LEL >= 0 THEN a1 = m ELSE a0 = m
      NEXT k
      aos = a1 : CALL Look(aos, OBLAT, OBLON) : azaos = LAZ
      inpass = 1 : maxel = -9
    ENDIF
    IF inpass = 1 THEN
      CALL Look(j, OBLAT, OBLON)
      IF LEL > maxel THEN maxel = LEL : tca = j
      IF LEL < 0 THEN
        a0 = j - stp : a1 = j
        FOR k = 1 TO 25
          m = (a0 + a1) / 2 : CALL Look(m, OBLAT, OBLON)
          IF LEL >= 0 THEN a0 = m ELSE a1 = m
        NEXT k
        los = a0 : CALL Look(los, OBLAT, OBLON) : azlos = LAZ
        t0 = tca - stp : t1 = tca + stp
        FOR k = 1 TO 40
          ml = t0 + (t1 - t0) / 3 : mr = t1 - (t1 - t0) / 3
          CALL Look(ml, OBLAT, OBLON) : ell = LEL
          CALL Look(mr, OBLAT, OBLON) : elr = LEL
          IF ell < elr THEN t0 = ml ELSE t1 = mr
        NEXT k
        tca = (t0 + t1) / 2 : CALL Look(tca, OBLAT, OBLON)
        maxel = LEL : aztca = LAZ
        CALL Cal(aos)
        r$ = Z2$(CD) + "/" + Z2$(CMO) + " " + Z2$(CH) + ":" + Z2$(CMI)
        CALL Cal(los)
        r$ = r$ + "-" + Z2$(CH) + ":" + Z2$(CMI) + " "
        r$ = r$ + STR$(INT(maxel * RAD + 0.5)) + " "
        r$ = r$ + STR$(INT(azaos * RAD + 0.5)) + "/" + STR$(INT(aztca * RAD + 0.5)) + "/" + STR$(INT(azlos * RAD + 0.5))
        TEXT 2, yrow, r$, "L", 7, 1, CFG
        yrow = yrow + 12
        inpass = 0 : npass = npass + 1
      ENDIF
    ENDIF
    j = j + stp
  LOOP
  TEXT 2, SH - 12, "Press any key", "L", 7, 1, CGRID
  DUMMY$ = WaitKey$()
END SUB

' ============================================================
'  4) POLAR PLOT OF NEXT/CURRENT PASS
' ============================================================
SUB PolarPlot
  LOCAL INTEGER ix
  ix = PickSat("Polar plot")
  IF ix = 0 THEN EXIT SUB
  CALL LoadSat(ix)
  ' find next pass (AOS,LOS); if currently in a pass start now
  LOCAL stp, j, endd, aos, los, k
  LOCAL INTEGER found
  LOCAL a0, a1, m
  stp = 30.0 / 86400.0
  j = NOWJD : endd = NOWJD + 14.0 : found = 0
  ' if already up, AOS = now
  CALL Look(j, OBLAT, OBLON)
  IF LEL >= 0 THEN
    aos = j : found = 1
  ELSE
    DO WHILE j < endd AND found = 0
      CALL Look(j, OBLAT, OBLON)
      IF LEL >= 0 THEN
        a0 = j - stp : a1 = j
        FOR k = 1 TO 25
          m = (a0 + a1) / 2 : CALL Look(m, OBLAT, OBLON)
          IF LEL >= 0 THEN a1 = m ELSE a0 = m
        NEXT k
        aos = a1 : found = 1
      ENDIF
      j = j + stp
    LOOP
  ENDIF
  IF found = 0 THEN CALL Flash("No pass in 14d") : EXIT SUB
  ' find LOS after aos
  j = aos + stp
  DO
    CALL Look(j, OBLAT, OBLON)
    j = j + stp
  LOOP UNTIL LEL < 0 OR j > aos + 0.02
  los = j
  ' draw polar frame
  CALL DrawPolarFrame(SATNAME$(ix))
  ' plot the arc, sampling between aos and los
  LOCAL t, pr
  LOCAL INTEGER first, px, py, lx, ly
  LOCAL cx, cy, rr
  cx = SW / 2 : cy = 28 + (SH - 40) / 2 : rr = (SH - 40) / 2 - 4
  first = 1
  FOR t = aos TO los STEP (los - aos) / 60.0
    CALL Look(t, OBLAT, OBLON)
    IF LEL >= 0 THEN
      ' radius scales with co-elevation: zenith at center, horizon at edge
      pr = rr * (1 - LEL / (PI / 2))
      px = cx + pr * SIN(LAZ)
      py = cy - pr * COS(LAZ)
      IF first = 0 THEN LINE lx, ly, px, py, 2, CSAT
      lx = px : ly = py
      first = 0
    ENDIF
  NEXT t
  ' mark AOS and current position
  CALL Look(aos, OBLAT, OBLON)
  CALL PolarDot(cx, cy, rr, LEL, LAZ, CFOOT)
  CALL Look(NOWJD, OBLAT, OBLON)
  IF LEL >= 0 THEN CALL PolarDot(cx, cy, rr, LEL, LAZ, CWARN)
  ' labels
  CALL Cal(aos)
  TEXT 2, SH - 24, "AOS " + Z2$(CH) + ":" + Z2$(CMI) + "Z", "L", 7, 1, CFOOT
  CALL Look(aos, OBLAT, OBLON)
  TEXT 90, SH - 24, "AzA " + STR$(INT(LAZ * RAD)), "L", 7, 1, CFG
  TEXT 2, SH - 12, "Press any key", "L", 7, 1, CGRID
  DUMMY$ = WaitKey$()
END SUB

SUB DrawPolarFrame(nm$)
  CLS CBG
  CALL Header("Polar: " + nm$)
  LOCAL cx, cy, rr
  LOCAL INTEGER i
  cx = SW / 2 : cy = 28 + (SH - 40) / 2 : rr = (SH - 40) / 2 - 4
  ' elevation rings: horizon, 30, 60
  CIRCLE cx, cy, rr, 1, , CGRID
  CIRCLE cx, cy, rr * 2 / 3, 1, , CGRID
  CIRCLE cx, cy, rr / 3, 1, , CGRID
  ' cross hairs
  LINE cx - rr, cy, cx + rr, cy, 1, CGRID
  LINE cx, cy - rr, cx, cy + rr, 1, CGRID
  TEXT cx, cy - rr - 10, "N", "CT", 7, 1, CACC
  TEXT cx + rr + 2, cy, "E", "LM", 7, 1, CACC
  TEXT cx, cy + rr + 2, "S", "CT", 7, 1, CACC
  TEXT cx - rr - 2, cy, "W", "RM", 7, 1, CACC
END SUB

SUB PolarDot(cx, cy, rr, el, az, col AS INTEGER)
  LOCAL pr
  LOCAL INTEGER px, py
  pr = rr * (1 - el / (PI / 2))
  px = cx + pr * SIN(az)
  py = cy - pr * COS(az)
  CIRCLE px, py, 3, 1, , col, col
END SUB

' ============================================================
'  5) NEXT 3 PASSES OF ALL SATS, SORTED BY TIME
' ============================================================
SUB AllNext3
  IF NSAT = 0 THEN CALL Flash("No sats") : EXIT SUB
  LOCAL maxrows
  LOCAL INTEGER cnt
  maxrows = NSAT * 3
  LOCAL pAOS(maxrows), pMEL(maxrows)
  LOCAL INTEGER pIX(maxrows)
  LOCAL np, stp, j, endd, maxel, aos, a0, a1, m
  LOCAL INTEGER s, k, inpass
  LOCAL jj, ta, tm
  LOCAL INTEGER i, ti
  LOCAL pg, perpage, startr
  LOCAL INTEGER row, kk
  LOCAL r$
  cnt = 0
  ' With a large catalogue, scanning every satellite over a long horizon on an
  ' interpreter is slow, so shorten the search window as the catalogue grows and
  ' show progress. Each satellite still reports its next up-to-3 passes.
  LOCAL horizon
  horizon = 7.0
  IF NSAT > 30 THEN horizon = 3.0
  IF NSAT > 80 THEN horizon = 2.0
  IF NSAT > 150 THEN horizon = 1.5
  CLS CBG
  CALL Header("All sats - next passes")
  TEXT 4, 40, "Searching " + STR$(NSAT) + " sats over", "L", 7, 1, CFG
  TEXT 4, 54, Str1$(horizon) + " days...", "L", 7, 1, CFG
  FOR s = 1 TO NSAT
    IF (s AND 7) = 0 THEN TEXT 4, 74, "sat " + STR$(s) + "/" + STR$(NSAT), "L", 7, 1, CWARN
    CALL LoadSat(s)
    stp = 30.0 / 86400.0
    j = NOWJD : endd = NOWJD + horizon
    inpass = 0 : np = 0 : maxel = -9
    DO WHILE j < endd AND np < 3
      CALL Look(j, OBLAT, OBLON)
      IF LEL >= 0 AND inpass = 0 THEN
        a0 = j - stp : a1 = j
        FOR k = 1 TO 22
          m = (a0 + a1) / 2 : CALL Look(m, OBLAT, OBLON)
          IF LEL >= 0 THEN a1 = m ELSE a0 = m
        NEXT k
        aos = a1 : inpass = 1 : maxel = -9
      ENDIF
      IF inpass = 1 THEN
        CALL Look(j, OBLAT, OBLON)
        IF LEL > maxel THEN maxel = LEL
        IF LEL < 0 THEN
          cnt = cnt + 1
          pAOS(cnt) = aos : pMEL(cnt) = maxel : pIX(cnt) = s
          inpass = 0 : np = np + 1
        ENDIF
      ENDIF
      j = j + stp
    LOOP
  NEXT s
  ' sort by AOS (simple insertion sort)
  FOR i = 2 TO cnt
    ta = pAOS(i) : tm = pMEL(i) : ti = pIX(i) : jj = i - 1
    DO WHILE jj >= 1 AND pAOS(jj) > ta
      pAOS(jj + 1) = pAOS(jj) : pMEL(jj + 1) = pMEL(jj) : pIX(jj + 1) = pIX(jj)
      jj = jj - 1
    LOOP
    pAOS(jj + 1) = ta : pMEL(jj + 1) = tm : pIX(jj + 1) = ti
  NEXT i
  ' display (paged)
  perpage = INT((SH - 46) / 12)
  pg = 0
  DO
    CLS CBG
    CALL Header("All sats - next passes")
    TEXT 2, 20, "DATE  AOS  MaxEl  SAT", "L", 7, 1, CACC
    startr = pg * perpage
    row = 32
    FOR i = startr + 1 TO startr + perpage
      IF i <= cnt THEN
        CALL Cal(pAOS(i))
        r$ = Z2$(CD) + "/" + Z2$(CMO) + " " + Z2$(CH) + ":" + Z2$(CMI)
        r$ = r$ + "  " + Pad$(STR$(INT(pMEL(i) * RAD + 0.5)), 3) + "  " + SATNAME$(pIX(i))
        TEXT 2, row, r$, "L", 7, 1, CFG
        row = row + 12
      ENDIF
    NEXT i
    TEXT 2, SH - 12, "SPACE=more  ESC=back", "L", 7, 1, CGRID
    kk = ASC(WaitKey$())
    IF kk = 32 THEN pg = pg + 1
    IF (pg * perpage) >= cnt THEN pg = 0
  LOOP UNTIL kk = 27
END SUB

' ============================================================
'  6) WORLD MAP + FOOTPRINTS
' ============================================================
SUB WorldMap
  IF NSAT = 0 THEN CALL Flash("No sats") : EXIT SUB
  LOCAL mapy, mapw, maph
  LOCAL INTEGER mapx, shownight
  LOCAL toff, jj
  LOCAL INTEGER kk, s, col
  mapx = 0 : mapy = 20 : mapw = SW : maph = SH - 40
  shownight = 1
  toff = 0.0
  DO
    CALL DrawMapBase(mapx, mapy, mapw, maph)
    jj = NOWJD + toff / 1440.0
    IF shownight = 1 THEN CALL Terminator(mapx, mapy, mapw, maph, jj)
    ' observer marker
    CALL PlotMapPt(mapx, mapy, mapw, maph, OBLAT, OBLON, CWARN, 1)
    ' each satellite: subpoint + footprint, distinct colour
    FOR s = 1 TO NSAT
      col = SatColor(s)
      CALL LoadSat(s)
      CALL SubPt(jj)
      CALL PlotMapPt(mapx, mapy, mapw, maph, BLAT, BLON, col, 0)
      CALL FootprintC(mapx, mapy, mapw, maph, jj, s, col)
    NEXT s
    TEXT 2, 22, "T+" + STR$(INT(toff)) + "m", "L", 7, 1, CACC
    TEXT 2, SH - 12, "SPC=step A=auto N=night ESC", "L", 7, 1, CGRID
    kk = ASC(UCASE$(WaitKey$()))
    IF kk = 32 THEN toff = toff + 5
    IF kk = ASC("A") THEN CALL AutoMap(mapx, mapy, mapw, maph)
    IF kk = ASC("N") THEN shownight = 1 - shownight
  LOOP UNTIL kk = 27
END SUB

' Distinct colour per satellite index (cycles through a small palette).
FUNCTION SatColor(s AS INTEGER)
  SELECT CASE (s - 1) MOD 6
    CASE 0 : SatColor = RGB(255, 80, 80)
    CASE 1 : SatColor = RGB(0, 220, 120)
    CASE 2 : SatColor = RGB(255, 220, 0)
    CASE 3 : SatColor = RGB(120, 160, 255)
    CASE 4 : SatColor = RGB(255, 130, 0)
    CASE 5 : SatColor = RGB(220, 120, 255)
  END SELECT
END FUNCTION

SUB AutoMap(mapx AS INTEGER, mapy AS INTEGER, mapw AS INTEGER, maph AS INTEGER)
  LOCAL toff, kk$, jj
  LOCAL INTEGER s, col
  toff = 0
  DO
    CALL DrawMapBase(mapx, mapy, mapw, maph)
    jj = NOWJD + toff / 1440.0
    CALL Terminator(mapx, mapy, mapw, maph, jj)
    CALL PlotMapPt(mapx, mapy, mapw, maph, OBLAT, OBLON, CWARN, 1)
    FOR s = 1 TO NSAT
      col = SatColor(s)
      CALL LoadSat(s)
      CALL SubPt(jj)
      CALL PlotMapPt(mapx, mapy, mapw, maph, BLAT, BLON, col, 0)
      CALL FootprintC(mapx, mapy, mapw, maph, jj, s, col)
    NEXT s
    TEXT 2, 22, "AUTO T+" + STR$(INT(toff)) + "m  (key=stop)", "L", 7, 1, CACC
    toff = toff + 2
    PAUSE 300
    kk$ = INKEY$
  LOOP UNTIL kk$ <> ""
END SUB

SUB DrawMapBase(mapx AS INTEGER, mapy AS INTEGER, mapw AS INTEGER, maph AS INTEGER)
  CLS CBG
  CALL Header("World Map + Footprints")
  ' ocean panel
  BOX mapx, mapy, mapw, maph, 1, CGRID, RGB(0, 0, 30)
  ' equator and prime meridian
  LOCAL ex
  LOCAL INTEGER ey
  ey = mapy + maph / 2
  LINE mapx, ey, mapx + mapw, ey, 1, CGRID
  ex = mapx + mapw / 2
  LINE ex, mapy, ex, mapy + maph, 1, CGRID
  ' coarse coastline boxes (very simplified continents)
  CALL Continents(mapx, mapy, mapw, maph)
END SUB

SUB Continents(mx AS INTEGER, my AS INTEGER, mw AS INTEGER, mh AS INTEGER)
  ' Draw a handful of filled rectangles approximating land masses,
  ' positioned by lon(-180..180)->x, lat(90..-90)->y.
  ' Data: lon1,lat1,lon2,lat2 (deg) as rough bounding boxes.
  LOCAL nb
  LOCAL INTEGER i
  LOCAL lonA(12), latA(12), lonB(12), latB(12)
  LOCAL y1, x2, y2
  LOCAL INTEGER x1
  ' N America
  lonA(1)=-168:latA(1)=72:lonB(1)=-52:latB(1)=15
  ' S America
  lonA(2)=-82:latA(2)=12:lonB(2)=-34:latB(2)=-55
  ' Africa
  lonA(3)=-18:latA(3)=37:lonB(3)=52:latB(3)=-35
  ' Europe
  lonA(4)=-10:latA(4)=71:lonB(4)=40:latB(4)=37
  ' Asia
  lonA(5)=40:latA(5)=75:lonB(5)=180:latB(5)=8
  ' Australia
  lonA(6)=112:latA(6)=-10:lonB(6)=154:latB(6)=-39
  ' Greenland
  lonA(7)=-55:latA(7)=83:lonB(7)=-12:latB(7)=60
  nb = 7
  FOR i = 1 TO nb
    x1 = mx + (lonA(i) + 180) / 360 * mw
    x2 = mx + (lonB(i) + 180) / 360 * mw
    y1 = my + (90 - latA(i)) / 180 * mh
    y2 = my + (90 - latB(i)) / 180 * mh
    BOX x1, y1, x2 - x1, y2 - y1, 1, CLAND, CLAND
  NEXT i
END SUB

' Shade the night hemisphere. For each map column (longitude) we compute the
' terminator latitude from the subsolar point, then shade whichever side is dark
' (decided by sampling sun elevation at the column's far-north edge). Coarse
' (every few px) to stay fast on the Pico.
SUB Terminator(mx AS INTEGER, my AS INTEGER, mw AS INTEGER, mh AS INTEGER, j)
  LOCAL lon, latt, hh, sinel
  LOCAL INTEGER px, py, ytop, ybot, yy, stpx, northdark, allcol
  CALL SunPos(j)
  stpx = 4
  FOR px = mx TO mx + mw - 1 STEP stpx
    lon = ((px - mx) / mw * 360.0 - 180.0) * DEG
    hh = lon - SUNLON
    allcol = -1            ' -1 = use terminator; 0 = all day; 1 = all night
    IF ABS(SUNLAT) < 0.0001 THEN
      ' sun on equator: a whole meridian is night when it faces away (cos hh < 0)
      IF COS(hh) < 0 THEN allcol = 1 ELSE allcol = 0
      latt = 0
    ELSE
      latt = ATN(-COS(hh) / TAN(SUNLAT)) * RAD
    ENDIF
    ' decide which side is dark: test sun elevation at the far north (+89 deg)
    sinel = SIN(89 * DEG) * SIN(SUNLAT) + COS(89 * DEG) * COS(SUNLAT) * COS(hh)
    IF sinel < 0 THEN northdark = 1 ELSE northdark = 0
    IF allcol = 1 THEN
      ytop = my : ybot = my + mh
    ELSEIF allcol = 0 THEN
      ytop = 0 : ybot = -1     ' nothing to shade
    ELSE
      py = my + (90 - latt) / 180 * mh
      IF northdark = 1 THEN
        ytop = my : ybot = py
      ELSE
        ytop = py : ybot = my + mh
      ENDIF
    ENDIF
    IF ytop < my THEN ytop = my
    IF ybot > my + mh THEN ybot = my + mh
    FOR yy = ytop TO ybot STEP 3
      PIXEL px, yy, RGB(20, 20, 50)
    NEXT yy
  NEXT px
  ' mark the subsolar point
  px = mx + (SUNLON * RAD + 180) / 360 * mw
  py = my + (90 - SUNLAT * RAD) / 180 * mh
  CIRCLE px, py, 3, 1, , CWARN, CWARN
  CIRCLE px, py, 6, 1, , CWARN
END SUB

SUB PlotMapPt(mx AS INTEGER, my AS INTEGER, mw AS INTEGER, mh AS INTEGER, la, lo, col AS INTEGER, big AS INTEGER)
  LOCAL py
  LOCAL INTEGER px
  px = mx + (lo * RAD + 180) / 360 * mw
  py = my + (90 - la * RAD) / 180 * mh
  IF big = 1 THEN
    LINE px - 4, py, px + 4, py, 1, col
    LINE px, py - 4, px, py + 4, 1, col
  ELSE
    CIRCLE px, py, 2, 1, , col, col
  ENDIF
END SUB

SUB Footprint(mx AS INTEGER, my AS INTEGER, mw AS INTEGER, mh AS INTEGER, j, ix AS INTEGER)
  CALL FootprintC(mx, my, mw, mh, j, ix, CFOOT)
END SUB

SUB FootprintC(mx AS INTEGER, my AS INTEGER, mw AS INTEGER, mh AS INTEGER, j, ix AS INTEGER, col AS INTEGER)
  ' footprint radius (great-circle) from altitude: cos(rho)=Re/(Re+h)
  LOCAL h, rho
  LOCAL INTEGER i
  LOCAL clat, clon
  CALL SubPt(j)
  clat = BLAT : clon = BLON
  h = WA - ERAD
  rho = ACOSS(ERAD / (ERAD + h))      ' Earth central angle to horizon
  LOCAL az, dlat, dlon
  LOCAL INTEGER px, py, first, lx, ly
  first = 1
  FOR i = 0 TO 36
    az = i * 10 * DEG
    dlat = ASINN(SIN(clat) * COS(rho) + COS(clat) * SIN(rho) * COS(az))
    dlon = clon + ATAN2S(SIN(az) * SIN(rho) * COS(clat), COS(rho) - SIN(clat) * SIN(dlat))
    px = mx + (WrapDeg(dlon * RAD) + 180) / 360 * mw
    py = my + (90 - dlat * RAD) / 180 * mh
    IF first = 0 THEN
      IF ABS(px - lx) < mw / 2 THEN LINE lx, ly, px, py, 1, col
    ENDIF
    lx = px : ly = py : first = 0
  NEXT i
END SUB

' ============================================================
'  SHARED: find next pass of the loaded satellite from time t0
'  Sets FP_AOS, FP_LOS, FP_TCA, FP_MEL; FP_OK=1 if found.
' ============================================================
SUB FindPass(t0)
  LOCAL stp, j, endd, a0, a1, m, t0b, t1b, ml, mr, ell, elr
  LOCAL INTEGER k
  stp = 30.0 / 86400.0
  FP_OK = 0
  j = t0 : endd = t0 + 14.0
  CALL Look(j, OBLAT, OBLON)
  IF LEL >= 0 THEN
    FP_AOS = j : FP_OK = 1
  ELSE
    DO WHILE j < endd AND FP_OK = 0
      CALL Look(j, OBLAT, OBLON)
      IF LEL >= 0 THEN
        a0 = j - stp : a1 = j
        FOR k = 1 TO 25
          m = (a0 + a1) / 2 : CALL Look(m, OBLAT, OBLON)
          IF LEL >= 0 THEN a1 = m ELSE a0 = m
        NEXT k
        FP_AOS = a1 : FP_OK = 1
      ENDIF
      j = j + stp
    LOOP
  ENDIF
  IF FP_OK = 0 THEN EXIT SUB
  ' LOS
  j = FP_AOS + stp
  DO
    CALL Look(j, OBLAT, OBLON)
    j = j + stp
  LOOP UNTIL LEL < 0 OR j > FP_AOS + 0.04
  FP_LOS = j
  ' TCA by golden-ish section
  t0b = FP_AOS : t1b = FP_LOS
  FOR k = 1 TO 40
    ml = t0b + (t1b - t0b) / 3 : mr = t1b - (t1b - t0b) / 3
    CALL Look(ml, OBLAT, OBLON) : ell = LEL
    CALL Look(mr, OBLAT, OBLON) : elr = LEL
    IF ell < elr THEN t0b = ml ELSE t1b = mr
  NEXT k
  FP_TCA = (t0b + t1b) / 2
  CALL Look(FP_TCA, OBLAT, OBLON)
  FP_MEL = LEL
END SUB

' ============================================================
'  6) LIVE TRACK + DOPPLER (one sat) - real-time az/el dial
' ============================================================
SUB LiveTrack
  LOCAL INTEGER ix
  ix = PickSat("Live track")
  IF ix = 0 THEN EXIT SUB
  CALL LoadSat(ix)
  LOCAL cx, cy, rr
  LOCAL kk$
  LOCAL j, rr2, dop, lit, pr, yb, r0, r1
  LOCAL INTEGER px, py
  cx = SW / 2 : cy = 150 : rr = 78
  DO
    ' refresh "now" from RTC each tick if available, else step a little
    IF GetRTC() = 0 THEN NOWJD = NOWJD + 2.0 / 86400.0
    j = NOWJD
    CLS CBG
    CALL Header("Live: " + SATNAME$(ix))
    ' --- compass dial ---
    CIRCLE cx, cy, rr, 1, , CGRID
    CIRCLE cx, cy, rr * 2 / 3, 1, , CGRID
    CIRCLE cx, cy, rr / 3, 1, , CGRID
    LINE cx - rr, cy, cx + rr, cy, 1, CGRID
    LINE cx, cy - rr, cx, cy + rr, 1, CGRID
    TEXT cx, cy - rr - 10, "N", "CT", 7, 1, CACC
    TEXT cx + rr + 2, cy, "E", "LM", 7, 1, CACC
    TEXT cx, cy + rr + 2, "S", "CT", 7, 1, CACC
    TEXT cx - rr - 2, cy, "W", "RM", 7, 1, CACC
    CALL Look(j, OBLAT, OBLON)
    IF LEL >= 0 THEN
      CALL PolarDot(cx, cy, rr, LEL, LAZ, CSAT)
      ' line from centre to sat to show bearing
      pr = rr * (1 - LEL / (PI / 2))
      px = cx + pr * SIN(LAZ) : py = cy - pr * COS(LAZ)
      LINE cx, cy, px, py, 1, CSAT
      TEXT cx, cy + rr + 16, "Az " + STR$(INT(LAZ * RAD + 0.5)) + "  El " + STR$(INT(LEL * RAD + 0.5)), "CT", 1, 1, CFG
    ELSE
      TEXT cx, cy + rr + 16, "Below horizon", "CT", 1, 1, CWARN
      CALL FindPass(j)
      IF FP_OK = 1 THEN
        CALL Cal(FP_AOS)
        TEXT cx, cy + rr + 30, "Next AOS " + Z2$(CH) + ":" + Z2$(CMI) + "Z", "CT", 7, 1, CFOOT
      ENDIF
    ENDIF
    ' --- Doppler readout ---
    yb = SH - 70
    IF SDN(ix) > 0 OR SUP(ix) > 0 THEN
      ' range rate via 1-second finite difference
      CALL Look(j - 1.0 / 86400.0, OBLAT, OBLON) : r0 = LRNG
      CALL Look(j + 1.0 / 86400.0, OBLAT, OBLON) : r1 = LRNG
      rr2 = (r1 - r0) / 2.0           ' km/s, +ve = receding
      IF SDN(ix) > 0 THEN
        dop = SDN(ix) - SDN(ix) * rr2 / 299792.458
        TEXT 4, yb, "RX " + Str3$(dop) + " MHz", "L", 1, 1, CFOOT
      ENDIF
      IF SUP(ix) > 0 THEN
        IF SINV(ix) = 1 THEN
          dop = SUP(ix) + SUP(ix) * rr2 / 299792.458
        ELSE
          dop = SUP(ix) - SUP(ix) * rr2 / 299792.458
        ENDIF
        TEXT 4, yb + 16, "TX " + Str3$(dop) + " MHz", "L", 1, 1, CWARN
      ENDIF
      TEXT 4, yb + 32, "Rng " + STR$(INT(LRNG)) + " km  Rdot " + Str1$(rr2), "L", 7, 1, CFG
    ELSE
      TEXT 4, yb, "(no freqs set for Doppler)", "L", 7, 1, CGRID
    ENDIF
    ' --- sunlit flag ---
    lit = Sunlit(j)
    IF lit = 1 THEN
      TEXT SW - 4, 22, "SUN", "RT", 7, 1, CWARN
    ELSE
      TEXT SW - 4, 22, "ECL", "RT", 7, 1, CGRID
    ENDIF
    CALL Cal(j)
    TEXT 4, 22, Z2$(CH) + ":" + Z2$(CMI) + ":" + Z2$(INT(CS)) + "Z", "L", 7, 1, CACC
    TEXT 4, SH - 12, "any key updates  ESC=back", "L", 7, 1, CGRID
    PAUSE 500
    kk$ = INKEY$
  LOOP UNTIL kk$ = CHR$(27)
END SUB

' ============================================================
'  9) PASS GROUND-TRACK PREVIEW (one sat over its next pass)
' ============================================================
SUB TrackPreview
  LOCAL INTEGER ix
  ix = PickSat("Track preview")
  IF ix = 0 THEN EXIT SUB
  CALL LoadSat(ix)
  CALL FindPass(NOWJD)
  IF FP_OK = 0 THEN CALL Flash("No pass in 14d") : EXIT SUB
  LOCAL mapy, mapw, maph
  LOCAL INTEGER mapx
  mapx = 0 : mapy = 20 : mapw = SW : maph = SH - 40
  CALL DrawMapBase(mapx, mapy, mapw, maph)
  CALL Terminator(mapx, mapy, mapw, maph, FP_TCA)
  CALL PlotMapPt(mapx, mapy, mapw, maph, OBLAT, OBLON, CWARN, 1)
  ' ground track polyline AOS..LOS (extend a little past for context)
  LOCAL t, t0, t1, stpt
  LOCAL INTEGER first, px, py, lx, ly
  t0 = FP_AOS - 0.01 : t1 = FP_LOS + 0.01
  stpt = (t1 - t0) / 80.0
  first = 1
  FOR t = t0 TO t1 STEP stpt
    CALL SubPt(t)
    px = mapx + (WrapDeg(BLON * RAD) + 180) / 360 * mapw
    py = mapy + (90 - BLAT * RAD) / 180 * maph
    IF first = 0 THEN
      IF ABS(px - lx) < mapw / 2 THEN LINE lx, ly, px, py, 2, CSAT
    ENDIF
    lx = px : ly = py : first = 0
  NEXT t
  ' footprints at AOS / TCA / LOS
  CALL FootprintC(mapx, mapy, mapw, maph, FP_AOS, ix, CFOOT)
  CALL FootprintC(mapx, mapy, mapw, maph, FP_TCA, ix, CACC)
  CALL FootprintC(mapx, mapy, mapw, maph, FP_LOS, ix, CGRID)
  ' subpoint dots at the three key times
  CALL SubPt(FP_AOS) : CALL PlotMapPt(mapx, mapy, mapw, maph, BLAT, BLON, CFOOT, 0)
  CALL SubPt(FP_TCA) : CALL PlotMapPt(mapx, mapy, mapw, maph, BLAT, BLON, CACC, 0)
  CALL SubPt(FP_LOS) : CALL PlotMapPt(mapx, mapy, mapw, maph, BLAT, BLON, CSAT, 0)
  ' label
  LOCAL r$
  CALL Cal(FP_AOS)
  r$ = "AOS " + Z2$(CH) + ":" + Z2$(CMI)
  CALL Cal(FP_LOS)
  r$ = r$ + " LOS " + Z2$(CH) + ":" + Z2$(CMI) + " El" + STR$(INT(FP_MEL * RAD + 0.5))
  TEXT 2, 22, r$, "L", 7, 1, CACC
  TEXT 2, SH - 12, "grn=AOS cyn=TCA gry=LOS  any key", "L", 7, 1, CGRID
  DUMMY$ = WaitKey$()
END SUB

' format helpers for frequencies (MMBasic STR$ with decimals)
FUNCTION Str3$(x)
  Str3$ = STR$(x, 0, 4)
END FUNCTION
FUNCTION Str1$(x)
  Str1$ = STR$(x, 0, 3)
END FUNCTION

' ============================================================
'  10) OSCARLOCATOR VIEW
'  An azimuthal-equidistant OSCARLOCATOR for one satellite:
'    - polar projection (default, auto N/S by your hemisphere), or
'      QTH-centred azimuthal (optional, press 'M' to toggle)
'    - the satellite ground-track arc for one orbit, drawn from its
'      equator crossing (ascending node in N, descending in S)
'    - a range circle over your QTH (amber)
'    - the satellite footprint at the sub-point (green)
'    - sub-point, Az/El, range, and EQX longitude readout
'  SPACE +1 min, B -1 min, F auto, S stop, R re-pin track to now,
'  M toggle projection, ESC back.
' ============================================================
SUB OscarView
  LOCAL INTEGER ix, auto, stepmin
  LOCAL toff, trackbase
  LOCAL k$
  ix = PickSat("OSCARLOCATOR")
  IF ix = 0 THEN EXIT SUB
  CALL LoadSat(ix)
  OVPER = 1440.0 / SMM(ix)              ' minutes per orbit
  ' default projection: polar, hemisphere auto from QTH latitude
  OVMODE = 0
  IF OBLAT < 0 THEN OVNHEMI = 0 ELSE OVNHEMI = 1
  CALL OVSetup
  auto = 0 : stepmin = 1 : toff = 0 : trackbase = 0
  CALL OVComputeTrack(NOWJD)
  DO
    IF ABS(toff - trackbase) > OVPER THEN
      CALL OVComputeTrack(NOWJD + toff / 1440.0)
      trackbase = toff
    ENDIF
    CALL OVFrame(ix, toff)
    IF auto = 1 THEN
      PAUSE 250
      k$ = INKEY$
      IF k$ = "" THEN toff = toff + stepmin
    ELSE
      k$ = WaitKey$()
    ENDIF
    IF k$ = " " THEN toff = toff + stepmin
    IF UCASE$(k$) = "F" THEN auto = 1
    IF UCASE$(k$) = "S" THEN auto = 0
    IF UCASE$(k$) = "B" THEN toff = toff - stepmin
    IF UCASE$(k$) = "R" THEN NOWJD = NOWJD + toff / 1440.0 : toff = 0 : trackbase = 0 : CALL OVComputeTrack(NOWJD)
    IF UCASE$(k$) = "M" THEN CALL OVToggleMode(toff)
  LOOP UNTIL k$ = CHR$(27)
END SUB

' Set the map centre/radius and (for QTH mode) the centre lat/lon.
SUB OVSetup
  OVCX = SW / 2
  OVCY = 18 + (SH - 18) / 2
  OVRR = (SH - 18) / 2 - 2
  OVQLAT = OBLAT : OVQLON = OBLON
END SUB

SUB OVToggleMode(toff)
  OVMODE = 1 - OVMODE
  ' re-pin centre for QTH mode in case the location changed
  OVQLAT = OBLAT : OVQLON = OBLON
  CALL OVComputeTrack(NOWJD + toff / 1440.0)
END SUB

' ------------------------------------------------------------
'  PROJECTION: lat,lon (radians) -> OVPX,OVPY, with OVPOK flag.
'  OVMODE 0: polar azimuthal-equidistant, centred on N or S pole.
'  OVMODE 1: azimuthal-equidistant centred on the QTH.
' ------------------------------------------------------------
SUB OVProject(latr, lonr)
  LOCAL rho, theta, rr2, cc, sc, cl2, dlon, bx, by
  IF OVMODE = 0 THEN
    IF OVNHEMI = 1 THEN
      rho = (PI / 2 - latr) : theta = lonr
    ELSE
      rho = (PI / 2 + latr) : theta = -lonr
    ENDIF
    rr2 = rho / (PI / 2)
    OVPX = OVCX - rr2 * OVRR * SIN(theta)
    OVPY = OVCY - rr2 * OVRR * COS(theta)
    IF rho > PI / 2 THEN OVPOK = 0 ELSE OVPOK = 1
  ELSE
    ' QTH-centred: great-circle distance c from centre, bearing brg.
    dlon = lonr - OVQLON
    cc = SIN(OVQLAT) * SIN(latr) + COS(OVQLAT) * COS(latr) * COS(dlon)
    IF cc > 1 THEN cc = 1
    IF cc < -1 THEN cc = -1
    rho = ACOSS(cc)                       ' 0..PI angular distance
    rr2 = rho / PI                         ' full globe fits the disc
    by = SIN(dlon) * COS(latr)
    bx = COS(OVQLAT) * SIN(latr) - SIN(OVQLAT) * COS(latr) * COS(dlon)
    theta = ATAN2S(by, bx)                 ' bearing from centre, 0=N CW
    OVPX = OVCX + rr2 * OVRR * SIN(theta)
    OVPY = OVCY - rr2 * OVRR * COS(theta)
    IF rho > PI THEN OVPOK = 0 ELSE OVPOK = 1
  ENDIF
END SUB

' Build the one-orbit ground-track arc from the equator crossing.
SUB OVComputeTrack(tref)
  LOCAL j, dtmin, eqxj
  LOCAL INTEGER i
  eqxj = OVFindEqx(tref)
  dtmin = OVPER / OVNTRK
  FOR i = 0 TO OVNTRK
    j = eqxj + (i * dtmin) / 1440.0
    CALL SubPt(j)
    OVTLAT(i) = BLAT
    OVTLON(i) = BLON
  NEXT i
  OVNPTS = OVNTRK
END SUB

' Equator crossing at/just before tref: ascending node (N hemisphere or
' QTH mode in N) or descending node (S). Returns its JD.
FUNCTION OVFindEqx(tref)
  LOCAL j, stp, prevlat, a0, a1, m, jback
  LOCAL INTEGER asc, found, k, cross
  IF OVQLAT < 0 THEN asc = 0 ELSE asc = 1
  IF OVMODE = 0 THEN
    IF OVNHEMI = 1 THEN asc = 1 ELSE asc = 0
  ENDIF
  stp = 60.0 / 86400.0
  prevlat = 999
  found = 0
  jback = tref - (OVPER + 5) / 1440.0
  j = jback
  DO WHILE j < tref AND found = 0
    CALL SubPt(j)
    IF prevlat <> 999 THEN
      cross = 0
      IF asc = 1 AND prevlat < 0 AND BLAT >= 0 THEN cross = 1
      IF asc = 0 AND prevlat > 0 AND BLAT <= 0 THEN cross = 1
      IF cross = 1 THEN
        a0 = j - stp : a1 = j
        FOR k = 1 TO 30
          m = (a0 + a1) / 2 : CALL SubPt(m)
          IF (BLAT >= 0) = (asc = 1) THEN a1 = m ELSE a0 = m
        NEXT k
        OVFindEqx = (a0 + a1) / 2
        found = 1
      ENDIF
    ENDIF
    prevlat = BLAT
    j = j + stp
  LOOP
  IF found = 0 THEN OVFindEqx = tref
END FUNCTION

SUB OVMark(latr, lonr, col AS INTEGER, big AS INTEGER)
  CALL OVProject(latr, lonr)
  IF OVPOK = 0 THEN EXIT SUB
  IF big = 1 THEN
    LINE OVPX - 4, OVPY, OVPX + 4, OVPY, 1, col
    LINE OVPX, OVPY - 4, OVPX, OVPY + 4, 1, col
    CIRCLE OVPX, OVPY, 3, 1, , col
  ELSE
    CIRCLE OVPX, OVPY, 3, 1, , col, col
  ENDIF
END SUB

SUB OVDrawTrack
  LOCAL INTEGER x0, y0, x1, y1, ok0, ok1, first, i
  first = 1
  FOR i = 0 TO OVNPTS
    CALL OVProject(OVTLAT(i), OVTLON(i))
    x1 = OVPX : y1 = OVPY : ok1 = OVPOK
    IF first = 0 THEN
      IF ok0 = 1 AND ok1 = 1 THEN LINE x0, y0, x1, y1, 1, CSAT
    ENDIF
    x0 = x1 : y0 = y1 : ok0 = ok1 : first = 0
  NEXT i
END SUB

' Circle of constant angular radius rho (radians) about a centre point.
SUB OVCircle(clat, clon, rho, col AS INTEGER)
  LOCAL az, dlat, dlon
  LOCAL INTEGER x0, y0, x1, y1, ok0, ok1, first, i
  first = 1
  FOR i = 0 TO 36
    az = i * 10 * DEG
    dlat = ASINN(SIN(clat) * COS(rho) + COS(clat) * SIN(rho) * COS(az))
    dlon = clon + ATAN2S(SIN(az) * SIN(rho) * COS(clat), COS(rho) - SIN(clat) * SIN(dlat))
    CALL OVProject(dlat, dlon)
    x1 = OVPX : y1 = OVPY : ok1 = OVPOK
    IF first = 0 THEN
      IF ok0 = 1 AND ok1 = 1 THEN LINE x0, y0, x1, y1, 1, col
    ENDIF
    x0 = x1 : y0 = y1 : ok0 = ok1 : first = 0
  NEXT i
END SUB

' Draw the graticule (rim = equator for polar, or horizon ring for QTH;
' plus a couple of inner range/elevation rings) and the frame chrome.
SUB OVGrid
  LOCAL INTEGER i
  CIRCLE OVCX, OVCY, OVRR, 1, , CGRID
  CIRCLE OVCX, OVCY, OVRR * 2 / 3, 1, , CGRID
  CIRCLE OVCX, OVCY, OVRR / 3, 1, , CGRID
  LINE OVCX - OVRR, OVCY, OVCX + OVRR, OVCY, 1, CGRID
  LINE OVCX, OVCY - OVRR, OVCX, OVCY + OVRR, 1, CGRID
  IF OVMODE = 0 THEN
    IF OVNHEMI = 1 THEN
      TEXT OVCX, OVCY - OVRR - 9, "0", "CT", 7, 1, CGRID
      TEXT OVCX + OVRR + 2, OVCY, "90E", "LM", 7, 1, CGRID
      TEXT OVCX - OVRR - 2, OVCY, "90W", "RM", 7, 1, CGRID
    ELSE
      TEXT OVCX, OVCY - OVRR - 9, "180", "CT", 7, 1, CGRID
    ENDIF
  ELSE
    TEXT OVCX, OVCY - OVRR - 9, "N", "CT", 7, 1, CACC
    TEXT OVCX + OVRR + 2, OVCY, "E", "LM", 7, 1, CACC
    TEXT OVCX, OVCY + OVRR + 1, "S", "CT", 7, 1, CACC
    TEXT OVCX - OVRR - 2, OVCY, "W", "RM", 7, 1, CACC
  ENDIF
END SUB

SUB OVFrame(ix AS INTEGER, toff)
  LOCAL j, h, rho
  CLS CBG
  CALL Header("OSCARLOCATOR  " + SATNAME$(ix))
  j = NOWJD + toff / 1440.0
  CALL OVGrid
  ' ground-track arc (one orbit from its equator crossing)
  CALL OVDrawTrack
  ' range circle over the QTH (3000 km ground radius, amber)
  rho = 3000.0 / ERAD
  CALL OVCircle(OVQLAT, OVQLON, rho, CWARN)
  ' QTH marker
  CALL OVMark(OBLAT, OBLON, CWARN, 1)
  ' satellite now: sub-point, footprint (green), look angles
  CALL SubPt(j)
  h = WA - ERAD
  rho = ACOSS(ERAD / (ERAD + h))
  CALL OVCircle(BLAT, BLON, rho, CFOOT)
  CALL OVMark(BLAT, BLON, CSAT, 0)
  CALL OVReadout(ix, j, toff)
END SUB

SUB OVReadout(ix AS INTEGER, j, toff)
  LOCAL eqxj, eqxlon, el, az, rng
  LOCAL s$
  ' EQX longitude of the arc currently shown
  eqxj = OVFindEqx(j)
  CALL SubPt(eqxj)
  eqxlon = BLON * RAD
  ' look angles now
  CALL Look(j, OBLAT, OBLON)
  el = LEL * RAD : az = LAZ * RAD : rng = LRNG
  CALL SubPt(j)
  CALL Cal(j)
  TEXT 2, 20, Z2$(CH) + ":" + Z2$(CMI) + "Z +" + STR$(INT(toff)) + "m", "L", 7, 1, CACC
  IF OVMODE = 0 THEN
    IF OVNHEMI = 1 THEN s$ = "Polar N" ELSE s$ = "Polar S"
  ELSE
    s$ = "QTH"
  ENDIF
  TEXT SW - 2, 20, s$, "RT", 7, 1, CGRID
  s$ = "Sub " + Str1$(BLAT * RAD) + "," + Str1$(BLON * RAD)
  TEXT 2, SH - 34, s$, "L", 7, 1, CFG
  IF el >= 0 THEN
    s$ = "Az " + STR$(INT(az + 0.5)) + " El " + STR$(INT(el + 0.5)) + " " + STR$(INT(rng)) + "km"
    TEXT 2, SH - 22, s$, "L", 7, 1, CFOOT
  ELSE
    TEXT 2, SH - 22, "Below horizon  " + STR$(INT(rng)) + "km", "L", 7, 1, CGRID
  ENDIF
  s$ = "EQX " + Str1$(eqxlon) + "  SPC/B F/S R M ESC"
  TEXT 2, SH - 10, s$, "L", 7, 1, CGRID
END SUB

' ============================================================
'  11) PASS WATCH + AOS ALARM
'  Finds the soonest AOS across all satellites and counts down to it,
'  refreshing from the RTC. Beeps and flashes the screen as AOS nears.
'  (No external devices - uses the PicoCalc's own speaker via PLAY TONE.)
' ============================================================
SUB PassWatch
  LOCAL INTEGER s, bestix, beeped, ss
  LOCAL bestaos, bestmel, secs
  LOCAL k$, nm$
  IF NSAT = 0 THEN CALL Flash("No sats") : EXIT SUB
  beeped = 0
  DO
    IF GetRTC() = 0 THEN NOWJD = NOWJD + 1.0 / 86400.0
    ' soonest AOS across the catalogue (capped horizon for speed)
    bestix = 0 : bestaos = NOWJD + 999
    FOR s = 1 TO NSAT
      CALL LoadSat(s)
      CALL FindPass(NOWJD)
      IF FP_OK = 1 THEN
        IF FP_AOS < bestaos THEN bestaos = FP_AOS : bestmel = FP_MEL : bestix = s
      ENDIF
    NEXT s
    CLS CBG
    CALL Header("Pass watch")
    IF bestix = 0 THEN
      TEXT SW / 2, SH / 2, "No passes found", "CM", 1, 1, CWARN
    ELSE
      nm$ = SATNAME$(bestix)
      secs = (bestaos - NOWJD) * 86400.0
      IF secs < 0 THEN secs = 0
      TEXT SW / 2, 40, "Next AOS", "CT", 7, 1, CACC
      TEXT SW / 2, 56, nm$, "CT", 1, 1, CFG
      CALL Cal(bestaos)
      ss = INT(secs) MOD 60
      TEXT SW / 2, 96, Z2$(CH) + ":" + Z2$(CMI) + ":" + Z2$(ss) + " UTC", "CT", 1, 1, CFOOT
      CALL DrawCountdown(secs)
      TEXT SW / 2, SH - 70, "in " + FmtHMS$(secs), "CT", 1, 1, CWARN
      TEXT SW / 2, SH - 50, "Max el " + STR$(INT(bestmel * RAD + 0.5)) + " deg", "CT", 7, 1, CFG
      ' alarm: beep/flash inside the last 60 s, once per pass
      IF secs <= 60 AND secs > 0 THEN
        BOX 0, 0, SW, SH, 1, CSAT
        PLAY TONE 880, 880, 120
        IF beeped = 0 THEN beeped = 1
      ELSE
        IF secs > 60 THEN beeped = 0
      ENDIF
    ENDIF
    TEXT 4, SH - 12, "Watching... ESC=back", "L", 7, 1, CGRID
    PAUSE 500
    k$ = INKEY$
  LOOP UNTIL k$ = CHR$(27)
END SUB

' A shrinking arc / ring countdown (full ring at >=10 min, empties toward 0).
SUB DrawCountdown(secs)
  LOCAL frac
  LOCAL INTEGER cx, cy, rr
  cx = SW / 2 : cy = SH / 2 : rr = 36
  CIRCLE cx, cy, rr, 1, , CGRID
  frac = secs / 600.0
  IF frac > 1 THEN frac = 1
  IF frac < 0 THEN frac = 0
  ' inner disc scaled by remaining fraction
  IF frac > 0 THEN CIRCLE cx, cy, INT(rr * frac), 1, , CWARN, CWARN
END SUB

FUNCTION FmtHMS$(secs)
  LOCAL INTEGER h, m, s, t
  t = INT(secs)
  h = t \ 3600 : m = (t MOD 3600) \ 60 : s = t MOD 60
  IF h > 0 THEN
    FmtHMS$ = STR$(h) + "h" + Z2$(m) + "m"
  ELSE
    FmtHMS$ = STR$(m) + "m" + Z2$(s) + "s"
  ENDIF
END FUNCTION

' ============================================================
'  12) PASS DETAIL - elevation-vs-time plot for the next pass,
'  coloured by sunlit (green) vs eclipse (grey), with a Sun glyph
'  and AOS/TCA/LOS / max-el readout.
' ============================================================
SUB PassDetail
  LOCAL INTEGER ix, i, n, px, py, px0, py0, lit, col, first
  LOCAL j, dur, frac, el, x0, y0, pw, ph, gx, gy
  ix = PickSat("Pass detail")
  IF ix = 0 THEN EXIT SUB
  CALL LoadSat(ix)
  CALL FindPass(NOWJD)
  IF FP_OK = 0 THEN CALL Flash("No pass") : EXIT SUB
  CLS CBG
  CALL Header("Pass detail: " + SATNAME$(ix))
  ' plot frame
  x0 = 28 : y0 = SH - 56 : pw = SW - 40 : ph = SH - 120
  LINE x0, y0, x0 + pw, y0, 1, CGRID          ' time axis
  LINE x0, y0, x0, y0 - ph, 1, CGRID          ' elevation axis
  TEXT 2, y0 - ph, "90", "LT", 7, 1, CGRID
  TEXT 2, y0 - ph / 2, "45", "LM", 7, 1, CGRID
  TEXT 2, y0, "0", "LB", 7, 1, CGRID
  dur = FP_LOS - FP_AOS
  IF dur <= 0 THEN dur = 0.01
  n = 60
  first = 1
  FOR i = 0 TO n
    frac = i / n
    j = FP_AOS + frac * dur
    CALL Look(j, OBLAT, OBLON)
    el = LEL
    IF el < 0 THEN el = 0
    px = x0 + frac * pw
    py = y0 - (el / (PI / 2)) * ph
    lit = Sunlit(j)
    IF lit = 1 THEN col = CFOOT ELSE col = CGRID
    IF first = 0 THEN LINE px0, py0, px, py, 2, col
    px0 = px : py0 = py : first = 0
  NEXT i
  ' Sun glyph at TCA elevation marker corner
  CALL SunAzEl(FP_TCA, OBLAT, OBLON)
  gx = SW - 22 : gy = 30
  IF SUNEL >= 0 THEN
    CIRCLE gx, gy, 6, 1, , CWARN, CWARN
    TEXT gx, gy + 10, "Sun " + STR$(INT(SUNEL * RAD + 0.5)), "CT", 7, 1, CWARN
  ELSE
    CIRCLE gx, gy, 6, 1, , CGRID
    TEXT gx, gy + 10, "Sun dn", "CT", 7, 1, CGRID
  ENDIF
  ' readout
  CALL Cal(FP_AOS) : TEXT 4, SH - 42, "AOS " + Z2$(CH) + ":" + Z2$(CMI), "L", 7, 1, CFOOT
  CALL Cal(FP_TCA) : TEXT 4, SH - 30, "TCA " + Z2$(CH) + ":" + Z2$(CMI) + "  MaxEl " + STR$(INT(FP_MEL * RAD + 0.5)), "L", 7, 1, CFG
  CALL Cal(FP_LOS) : TEXT 4, SH - 18, "LOS " + Z2$(CH) + ":" + Z2$(CMI) + "  green=sunlit", "L", 7, 1, CGRID
  CALL WaitKey$()
END SUB

' ============================================================
'  13) SUN VIEW - Sun azimuth/elevation now and a sky glyph, plus
'  the subsolar point. Useful for solar-noise avoidance and for
'  knowing whether a sunlight-only bird's passes are in daylight.
' ============================================================
SUB SunView
  LOCAL k$
  LOCAL INTEGER cx, cy, rr, px, py
  LOCAL pr
  cx = SW / 2 : cy = 150 : rr = 90
  DO
    IF GetRTC() = 0 THEN NOWJD = NOWJD + 2.0 / 86400.0
    CALL SunAzEl(NOWJD, OBLAT, OBLON)
    CLS CBG
    CALL Header("Sun position")
    ' sky dome dial (same convention as the live track)
    CIRCLE cx, cy, rr, 1, , CGRID
    CIRCLE cx, cy, rr * 2 / 3, 1, , CGRID
    CIRCLE cx, cy, rr / 3, 1, , CGRID
    LINE cx - rr, cy, cx + rr, cy, 1, CGRID
    LINE cx, cy - rr, cx, cy + rr, 1, CGRID
    TEXT cx, cy - rr - 10, "N", "CT", 7, 1, CACC
    TEXT cx + rr + 2, cy, "E", "LM", 7, 1, CACC
    TEXT cx, cy + rr + 2, "S", "CT", 7, 1, CACC
    TEXT cx - rr - 2, cy, "W", "RM", 7, 1, CACC
    IF SUNEL >= 0 THEN
      pr = rr * (1 - SUNEL / (PI / 2))
      px = cx + pr * SIN(SUNAZ) : py = cy - pr * COS(SUNAZ)
      CIRCLE px, py, 6, 1, , CWARN, CWARN
      TEXT cx, cy + rr + 18, "Az " + STR$(INT(SUNAZ * RAD + 0.5)) + "  El " + STR$(INT(SUNEL * RAD + 0.5)), "CT", 1, 1, CFG
    ELSE
      TEXT cx, cy + rr + 18, "Sun below horizon", "CT", 1, 1, CGRID
      TEXT cx, cy + rr + 32, "Az " + STR$(INT(SUNAZ * RAD + 0.5)) + "  El " + STR$(INT(SUNEL * RAD + 0.5)), "CT", 7, 1, CGRID
    ENDIF
    CALL SunPos(NOWJD)
    TEXT 4, SH - 30, "Subsolar " + Str1$(SUNLAT * RAD) + "," + Str1$(SUNLON * RAD), "L", 7, 1, CFOOT
    TEXT 4, SH - 14, "Live... ESC=back", "L", 7, 1, CGRID
    PAUSE 400
    k$ = INKEY$
  LOOP UNTIL k$ = CHR$(27)
END SUB

' ============================================================
'  ORBIT MODEL
' ============================================================
SUB LoadSat(ix AS INTEGER)
  WI = SINC(ix) * DEG
  WE = SECC(ix)
  WO = SRAAN(ix) * DEG
  WG = SARGP(ix) * DEG
  WM = SMA(ix) * DEG
  WN = SMM(ix) * TWOPI / 86400.0
  WJ = SEPJD(ix)
  WA = (MU / (WN * WN)) ^ (1.0 / 3.0)
  LOCAL p, f, ci, si
  p = WA * (1 - WE * WE)
  f = 1.5 * J2C * (ERAD / p) ^ 2 * WN
  ci = COS(WI) : si = SIN(WI)
  WRD = -f * ci
  WPD = f * (2 - 2.5 * si * si)
END SUB

SUB Eci(j)
  LOCAL dt, m, ra, ap, ee, xo, yo, u, r
  LOCAL co, so, cu, su, ci, si
  dt = (j - WJ) * 86400.0
  m = WM + WN * dt
  ra = WO + WRD * dt
  ap = WG + WPD * dt
  m = m - TWOPI * INT(m / TWOPI)
  ee = Kepler(m, WE)
  xo = WA * (COS(ee) - WE)
  yo = WA * SQR(1 - WE * WE) * SIN(ee)
  u = ATAN2S(yo, xo) + ap
  r = SQR(xo * xo + yo * yo)
  co = COS(ra) : so = SIN(ra)
  cu = COS(u) : su = SIN(u)
  ci = COS(WI) : si = SIN(WI)
  GX = r * (co * cu - so * su * ci)
  GY = r * (so * cu + co * su * ci)
  GZ = r * (su * si)
END SUB

SUB Ecef(j)
  LOCAL g, cg, sg
  CALL Eci(j)
  g = Gmst(j)
  cg = COS(g) : sg = SIN(g)
  EX = cg * GX + sg * GY
  EY = -sg * GX + cg * GY
  EZ = GZ
END SUB

SUB SubPt(j)
  CALL Ecef(j)
  BLON = ATAN2S(EY, EX)
  BLAT = ATAN2S(EZ, SQR(EX * EX + EY * EY))
END SUB

' Low-precision Sun position (ECI, km). Sets SUNX,SUNY,SUNZ and the
' subsolar lat/lon (SUNLAT,SUNLON in radians) for the terminator.
SUB SunPos(j)
  LOCAL n, ll, gg, lam, eps, r, g2
  LOCAL gmstv
  n = j - 2451545.0
  ll = 280.460 + 0.9856474 * n : ll = ll - 360.0 * INT(ll / 360.0)
  gg = 357.528 + 0.9856003 * n : gg = gg - 360.0 * INT(gg / 360.0)
  g2 = gg * DEG
  lam = (ll + 1.915 * SIN(g2) + 0.020 * SIN(2.0 * g2)) * DEG
  eps = (23.439 - 0.0000004 * n) * DEG
  r = (1.00014 - 0.01671 * COS(g2) - 0.00014 * COS(2.0 * g2)) * 149597870.7
  SUNX = r * COS(lam)
  SUNY = r * COS(eps) * SIN(lam)
  SUNZ = r * SIN(eps) * SIN(lam)
  ' subsolar point: declination + hour angle vs GMST
  SUNLAT = ASINN(SUNZ / r)
  gmstv = Gmst(j)
  SUNLON = ATAN2S(SUNY, SUNX) - gmstv
  DO WHILE SUNLON > PI : SUNLON = SUNLON - TWOPI : LOOP
  DO WHILE SUNLON <= -PI : SUNLON = SUNLON + TWOPI : LOOP
END SUB

' Sun azimuth/elevation from the observer (la,lo radians) at time j.
' Outputs into SUNAZ, SUNEL (radians). Uses the subsolar point as a bearing
' target on the celestial sphere (Sun distance >> Earth radius, so topocentric
' parallax is negligible for a glyph/readout).
DIM SUNAZ, SUNEL
SUB SunAzEl(j, la, lo)
  LOCAL hh, sinel, cosel, sinaz, cosaz, ela
  CALL SunPos(j)
  hh = lo - SUNLON                       ' observer west of subsolar = +hour angle here
  sinel = SIN(la) * SIN(SUNLAT) + COS(la) * COS(SUNLAT) * COS(hh)
  IF sinel > 1 THEN sinel = 1
  IF sinel < -1 THEN sinel = -1
  ela = ASINN(sinel)
  SUNEL = ela
  cosel = COS(ela)
  IF ABS(cosel) < 0.0001 THEN
    SUNAZ = 0
  ELSE
    sinaz = -COS(SUNLAT) * SIN(hh) / cosel
    cosaz = (SIN(SUNLAT) - SIN(la) * sinel) / (COS(la) * cosel)
    SUNAZ = ATAN2S(sinaz, cosaz)
    IF SUNAZ < 0 THEN SUNAZ = SUNAZ + TWOPI
  ENDIF
END SUB

' Is the loaded satellite in sunlight at time j? (cylindrical shadow)
' Requires Eci(j) outputs in GX,GY,GZ. Returns 1 lit, 0 eclipse.
FUNCTION Sunlit(j)
  LOCAL ux, uy, uz, un, along, px, py, pz, perp
  CALL Eci(j)
  CALL SunPos(j)
  un = SQR(SUNX * SUNX + SUNY * SUNY + SUNZ * SUNZ)
  ux = SUNX / un : uy = SUNY / un : uz = SUNZ / un
  along = GX * ux + GY * uy + GZ * uz
  IF along > 0 THEN Sunlit = 1 : EXIT FUNCTION
  px = GX - along * ux : py = GY - along * uy : pz = GZ - along * uz
  perp = SQR(px * px + py * py + pz * pz)
  IF perp > ERAD THEN Sunlit = 1 ELSE Sunlit = 0
END FUNCTION

SUB Look(j, la, lo)
  LOCAL cl, sl, col, sol, ox, oy, oz
  LOCAL rx, ry, rz, s, e, zz, rng
  CALL Ecef(j)
  cl = COS(la) : sl = SIN(la)
  col = COS(lo) : sol = SIN(lo)
  ox = ERAD * cl * col
  oy = ERAD * cl * sol
  oz = ERAD * sl
  rx = EX - ox : ry = EY - oy : rz = EZ - oz
  s = sl * col * rx + sl * sol * ry - cl * rz
  e = -sol * rx + col * ry
  zz = cl * col * rx + cl * sol * ry + sl * rz
  rng = SQR(rx * rx + ry * ry + rz * rz)
  LEL = ASINN(zz / rng)
  LAZ = ATAN2S(e, -s)
  IF LAZ < 0 THEN LAZ = LAZ + TWOPI
  LRNG = rng
END SUB

FUNCTION FNjd(y, mo, d, h, mi, s)
  LOCAL yy, mm, a, b
  yy = y : mm = mo
  IF mm <= 2 THEN yy = yy - 1 : mm = mm + 12
  a = INT(yy / 100)
  b = 2 - a + INT(a / 4)
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
    dx = (x - e * SIN(x) - m) / (1 - e * COS(x))
    x = x - dx
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

FUNCTION ACOSS(x)
  ACOSS = PI / 2 - ASINN(x)
END FUNCTION

SUB Cal(j)
  LOCAL z, f, al, a, b, c, dd, e, day, secs
  j = j + 0.5
  z = INT(j) : f = j - z
  IF z < 2299161 THEN
    a = z
  ELSE
    al = INT((z - 1867216.25) / 36524.25)
    a = z + 1 + al - INT(al / 4)
  ENDIF
  b = a + 1524
  c = INT((b - 122.1) / 365.25)
  dd = INT(365.25 * c)
  e = INT((b - dd) / 30.6001)
  day = b - dd - INT(30.6001 * e) + f
  IF e < 14 THEN CMO = e - 1 ELSE CMO = e - 13
  IF CMO > 2 THEN CY = c - 4716 ELSE CY = c - 4715
  CD = INT(day)
  secs = (day - CD) * 86400.0
  CH = INT(secs / 3600) : secs = secs - CH * 3600
  CMI = INT(secs / 60)
  CS = secs - CMI * 60
END SUB

' ============================================================
'  MAIDENHEAD
' ============================================================
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
  OBLAT = la * DEG
  OBLON = lo * DEG
END SUB

FUNCTION GridFromLL$(la, lo)
  LOCAL alo, ala
  LOCAL INTEGER a, b, c, d
  alo = lo * RAD + 180
  ala = la * RAD + 90
  a = INT(alo / 20)
  b = INT(ala / 10)
  c = INT((alo - a * 20) / 2)
  d = INT(ala - b * 10)
  GridFromLL$ = CHR$(65 + a) + CHR$(65 + b) + STR$(c) + STR$(d)
END FUNCTION

' ============================================================
'  FILE I/O
' ============================================================
SUB SaveSats
  LOCAL f
  LOCAL INTEGER i
  f = 1
  ON ERROR SKIP
  OPEN "B:/sats.dat" FOR OUTPUT AS #f
  PRINT #f, NSAT
  FOR i = 1 TO NSAT
    PRINT #f, SATNAME$(i)
    PRINT #f, STR$(SINC(i)) + "," + STR$(SECC(i)) + "," + STR$(SRAAN(i)) + "," + STR$(SARGP(i)) + "," + STR$(SMA(i)) + "," + STR$(SMM(i)) + "," + STR$(SEPJD(i)) + "," + STR$(SDN(i)) + "," + STR$(SUP(i)) + "," + STR$(SINV(i))
  NEXT i
  CLOSE #f
END SUB

SUB LoadSats
  LOCAL f
  LOCAL INTEGER i
  LOCAL l$
  IF MM.INFO(EXISTS FILE "B:/sats.dat") = 0 THEN EXIT SUB
  f = 1
  OPEN "B:/sats.dat" FOR INPUT AS #f
  LINE INPUT #f, l$ : NSAT = VAL(l$)
  IF NSAT > MAXSAT THEN NSAT = MAXSAT
  FOR i = 1 TO NSAT
    LINE INPUT #f, SATNAME$(i)
    LINE INPUT #f, l$
    SINC(i)  = VAL(FIELD$(l$, 1, ","))
    SECC(i)  = VAL(FIELD$(l$, 2, ","))
    SRAAN(i) = VAL(FIELD$(l$, 3, ","))
    SARGP(i) = VAL(FIELD$(l$, 4, ","))
    SMA(i)   = VAL(FIELD$(l$, 5, ","))
    SMM(i)   = VAL(FIELD$(l$, 6, ","))
    SEPJD(i) = VAL(FIELD$(l$, 7, ","))
    SDN(i)   = VAL(FIELD$(l$, 8, ","))
    SUP(i)   = VAL(FIELD$(l$, 9, ","))
    SINV(i)  = VAL(FIELD$(l$, 10, ","))
  NEXT i
  CLOSE #f
END SUB

SUB SaveLoc
  LOCAL INTEGER f
  f = 1
  ON ERROR SKIP
  OPEN "B:/loc.dat" FOR OUTPUT AS #f
  PRINT #f, OBGRID$
  PRINT #f, STR$(OBLAT) + "," + STR$(OBLON)
  PRINT #f, STR$(NY) + "," + STR$(NMO) + "," + STR$(ND) + "," + STR$(NH) + "," + STR$(NMI)
  CLOSE #f
END SUB

SUB LoadLoc
  LOCAL INTEGER f
  LOCAL l$
  IF MM.INFO(EXISTS FILE "B:/loc.dat") = 0 THEN EXIT SUB
  f = 1
  OPEN "B:/loc.dat" FOR INPUT AS #f
  LINE INPUT #f, OBGRID$
  LINE INPUT #f, l$
  OBLAT = VAL(FIELD$(l$, 1, ","))
  OBLON = VAL(FIELD$(l$, 2, ","))
  LINE INPUT #f, l$
  NY  = VAL(FIELD$(l$, 1, ","))
  NMO = VAL(FIELD$(l$, 2, ","))
  ND  = VAL(FIELD$(l$, 3, ","))
  NH  = VAL(FIELD$(l$, 4, ","))
  NMI = VAL(FIELD$(l$, 5, ","))
  CLOSE #f
  NOWJD = FNjd(NY, NMO, ND, NH, NMI, 0)
END SUB

' ============================================================
'  UI HELPERS
' ============================================================
FUNCTION PickSat(title$)
  LOCAL k, y
  LOCAL INTEGER sel, i, top, vis, last
  IF NSAT = 0 THEN CALL Flash("No sats") : PickSat = 0 : EXIT FUNCTION
  sel = 1
  top = 1
  vis = (SH - 52) \ 14          ' rows that fit between header and footer
  IF vis < 1 THEN vis = 1
  DO
    ' keep the selected row inside the visible window
    IF sel < top THEN top = sel
    IF sel > top + vis - 1 THEN top = sel - vis + 1
    last = top + vis - 1
    IF last > NSAT THEN last = NSAT
    CLS CBG
    CALL Header(title$)
    TEXT 4, 22, "Select satellite (" + STR$(NSAT) + "):", "L", 7, 1, CACC
    y = 38
    FOR i = top TO last
      IF i = sel THEN BOX 4, y - 1, SW - 8, 13, 1, CACC, RGB(0, 35, 50)
      TEXT 8, y, Str3i$(i) + " " + SATNAME$(i), "L", 7, 1, CFG
      y = y + 14
    NEXT i
    IF top > 1 THEN TEXT SW - 6, 30, CHR$(24), "RT", 7, 1, CWARN
    IF last < NSAT THEN TEXT SW - 6, SH - 22, CHR$(25), "RB", 7, 1, CWARN
    TEXT 4, SH - 12, "Up/Dn Enter  ESC=cancel", "L", 7, 1, CGRID
    k = ASC(WaitKey$())
    IF k = 128 THEN sel = sel - 1
    IF k = 129 THEN sel = sel + 1
    IF k = 130 THEN sel = sel - vis      ' left = page up
    IF k = 131 THEN sel = sel + vis      ' right = page down
    IF sel < 1 THEN sel = NSAT
    IF sel > NSAT THEN sel = 1
    IF k = 13 THEN PickSat = sel : EXIT FUNCTION
  LOOP UNTIL k = 27
  PickSat = 0
END FUNCTION

' Right-justified 3-digit index for satellite lists (1..200).
FUNCTION Str3i$(n AS INTEGER)
  LOCAL s$
  s$ = STR$(n)
  DO WHILE LEN(s$) < 3
    s$ = " " + s$
  LOOP
  Str3i$ = s$
END FUNCTION

FUNCTION AskNum(label$, x AS INTEGER, y AS INTEGER)
  LOCAL s$
  s$ = AskStr$(label$, x, y)
  AskNum = VAL(s$)
END FUNCTION

FUNCTION AskStr$(label$, x AS INTEGER, y AS INTEGER)
  LOCAL s$, c$
  LOCAL INTEGER done
  s$ = ""
  done = 0
  DO
    BOX x, y, SW - x - 4, 12, 1, CBG, CBG
    TEXT x, y, label$ + ": " + s$ + "_", "L", 7, 1, CFG
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
  BOX x, y, SW - x - 4, 12, 1, CBG, CBG
  TEXT x, y, label$ + ": " + s$, "L", 7, 1, CFOOT
  AskStr$ = s$
END FUNCTION

FUNCTION WaitKey$()
  LOCAL k$
  DO
    k$ = INKEY$
  LOOP UNTIL k$ <> ""
  WaitKey$ = k$
END FUNCTION

SUB Flash(msg$)
  LOCAL INTEGER w
  w = LEN(msg$) * 8 + 16
  BOX (SW - w) / 2, SH / 2 - 10, w, 20, 1, CWARN, RGB(40, 30, 0)
  TEXT SW / 2, SH / 2, msg$, "CM", 1, 1, CWARN
  PAUSE 700
END SUB

FUNCTION Z2$(n AS INTEGER)
  IF n < 10 THEN Z2$ = "0" + STR$(n) ELSE Z2$ = STR$(n)
END FUNCTION

FUNCTION Pad$(s$, n AS INTEGER)
  LOCAL r$
  r$ = s$
  DO WHILE LEN(r$) < n
    r$ = " " + r$
  LOOP
  Pad$ = r$
END FUNCTION

FUNCTION WrapDeg(d)
  LOCAL v
  v = d
  DO WHILE v > 180 : v = v - 360 : LOOP
  DO WHILE v <= -180 : v = v + 360 : LOOP
  WrapDeg = v
END FUNCTION
