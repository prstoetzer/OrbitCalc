# OPL on the Psion Series 5 (EPOC32)

- Open the file in the Program editor, press Ctrl+T to translate, then run.
- Module names: ORBCALC and OSCARLOC.
- Uses floating-point throughout; angles in radians internally.
- Series 5 OPL provides ASIN/ACOS/ATAN, GEN$, FIX$, UPPER$, VAL — all used here.
- INT() truncates toward zero; this only affects the mean-anomaly reduction,
  which the Kepler solver tolerates.
