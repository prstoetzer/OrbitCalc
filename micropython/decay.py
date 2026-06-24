# Decay - element-freshness warner & rough decay/altitude flag.
# MicroPython / CPython. The single biggest source of bad predictions
# with a mean-element model is a stale element set. This tool computes
# the age of your elements relative to "now" and warns past a threshold,
# and from mean motion classifies the altitude regime and flags likely
# fast-decaying objects. Optionally, given a SECOND epoch's mean motion,
# it estimates dn/dt and a crude remaining lifetime. Same core constants.

import math
MU = 398600.4418
RE = 6378.137
TWOPI = 2.0 * math.pi


def jd(y, mo, d, h, mi, s):
    if mo <= 2:
        y -= 1
        mo += 12
    a = y // 100
    b = 2 - a + a // 4
    return (int(365.25 * (y + 4716)) + int(30.6001 * (mo + 1)) + d + b
            - 1524.5 + (h + mi / 60.0 + s / 3600.0) / 24.0)


def alt_from_mm(mm):
    n = mm * TWOPI / 86400.0
    a = (MU / (n * n)) ** (1.0 / 3.0)
    return a - RE, a


def ask(p, d):
    try:
        s = input("%s [%s]: " % (p, d)).strip()
    except EOFError:
        return d
    if s == "":
        return d
    try:
        return float(s) if ("." in s or "-" in s or "e" in s.lower()) else int(s)
    except ValueError:
        return d


def main():
    print("Decay - element freshness & decay flag")
    mm = ask("MM rev/day", 12.53698149)
    ecc = ask("ECC", 0.0012609)
    ey = ask("Ep Yr", 2026)
    emo = ask("Ep Mo", 6)
    ed = ask("Ep Dy", 20)
    eh = ask("Ep Hr", 7)
    emi = ask("Ep Mi", 46)
    ny = ask("Now Yr", 2026)
    nmo = ask("Now Mo", 6)
    nd = ask("Now Dy", 22)
    nh = ask("Now Hr", 0)
    nmi = ask("Now Mi", 0)
    ep = jd(ey, emo, ed, eh, emi, 0)
    now = jd(ny, nmo, nd, nh, nmi, 0)
    age = now - ep
    alt, a = alt_from_mm(mm)
    print("")
    print("Element age : %.2f days" % age)
    if age < 0:
        print("  ! 'Now' is BEFORE epoch - check dates.")
    elif age > 14:
        print("  ! Very stale (>14 d). Predictions likely off by minutes+.")
    elif age > 5:
        print("  ! Getting stale (>5 d). Refresh soon for best timing.")
    else:
        print("  Fresh enough for planning-grade timing.")
    print("Mean alt    : %.0f km (a=%.0f km)" % (alt, a))
    perigee = a * (1 - ecc) - RE
    print("Perigee alt : %.0f km" % perigee)
    if perigee < 200:
        print("  ! Perigee very low - rapid decay likely; refresh daily.")
    elif perigee < 350:
        print("  ! Low perigee - drag significant; refresh every day or two.")
    # optional second epoch to estimate dn/dt
    two = ask("Have a 2nd-epoch MM? 1/0", 0)
    if two == 1:
        mm2 = ask(" 2nd MM rev/day", mm)
        d2y = ask(" 2nd Ep Yr", ny)
        d2mo = ask(" 2nd Ep Mo", nmo)
        d2d = ask(" 2nd Ep Dy", nd)
        ep2 = jd(d2y, d2mo, d2d, 0, 0, 0)
        dt = ep2 - ep
        if abs(dt) > 0.01 and mm2 > mm:
            dndt = (mm2 - mm) / dt
            print(" dn/dt    : %.5f rev/day/day (rising = decaying)" % dndt)
            # extremely rough: revs to reach a decaying ~16 rev/day threshold
            if dndt > 0:
                days_left = (16.5 - mm2) / dndt
                if days_left > 0 and days_left < 3650:
                    print(" Crude est : ~%.0f days to rapid-decay regime" % days_left)
                else:
                    print(" Crude est : long-lived at this rate")
        else:
            print(" (no decay trend detected between epochs)")


if __name__ == "__main__":
    main()
