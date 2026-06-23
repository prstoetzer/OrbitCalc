# OPL on the Psion Series 3c (SIBO)

- Open in the Program editor, translate, and run. Modules: ORBCALC, OSCARLOC.
- These variants compute arcsine from ATAN (asin(x)=atan(x/sqrt(1-x*x))) to
  avoid depending on ASIN across SIBO ROM revisions.
- Otherwise identical math to the Series 5 version.
- Memory is tighter on the 3c; the programs are written to stay modest.
