# Verification reference

Test case used across all ports:

- Satellite: AO-7 (OSCAR 7)
  INC 101.9899, ECC 0.0012609, RAAN 184.6033, ARGP 124.3014,
  MA 247.3322, MM 12.53698149 rev/day, EPOCH 2026-06-20T07:46:20.6 UTC
- Observer: grid FM18LV  (~38.9N, 77.0W)
- Now: 2026-06-22 00:00 UTC

Expected PASSES (next 10):

    21/06 23:59-00:17 El32 Az199/262/333
    22/06 10:07-10:25 El16 Az35/91/147
    22/06 11:58-12:20 El88 Az17/109/199
    22/06 13:52-14:10 El21 Az6/307/249
    22/06 15:47-15:54 El1  Az350/332/314
    22/06 19:21-19:29 El3  Az55/31/7
    22/06 21:05-21:24 El25 Az117/55/353
    22/06 22:56-23:18 El76 Az166/253/342
    23/06 00:52-01:09 El13 Az220/270/322
    23/06 09:11-09:17 El1  Az64/81/98

Expected EQX (ascending node, 10 days, observer north):

    22/06 01:50 111.6W
    23/06 00:49 96.3W
    24/06 01:43 109.7W
    25/06 00:42 94.4W
    26/06 01:36 107.8W
    27/06 00:35 92.5W
    28/06 01:28 105.9W
    29/06 00:27 90.6W
    30/06 01:21 104.1W
    01/07 00:20 88.8W

OSCARLOCATOR (EQX 111.6W asc, 2026-06-22 01:50, period 114.86 min,
advance 28.74 deg W) first rows:

    00 01:50 111.6W
    01 03:44 140.3W
    02 05:39 169.1W
    03 07:34 162.2E
    ...

`ref.py` is the Python reference implementation. Run it to regenerate.
