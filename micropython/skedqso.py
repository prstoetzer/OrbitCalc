# SkedQSO - mutual-pass scheduler for two stations. MicroPython / CPython.
# Finds the next N times a satellite is simultaneously visible (above a
# minimum elevation) from BOTH grids - the windows two operators use to
# schedule a grid-to-grid contact. Same secular-J2 core.

import math
from pointing import (Sat, maiden, cal, jd, RAD)


def both_up(sat, j, la1, lo1, la2, lo2, hor):
    e1, _, _ = sat.look(j, la1, lo1)
    e2, _, _ = sat.look(j, la2, lo2)
    return e1 >= hor and e2 >= hor


def windows(sat, now, la1, lo1, la2, lo2, days, min_el, count):
    hor = min_el / RAD
    step = 30.0 / 86400.0
    out = []
    j = now
    end = now + days
    guard = 0
    inwin = both_up(sat, j, la1, lo1, la2, lo2, hor)
    wstart = j if inwin else None
    while j < end and len(out) < count and guard < 2000000:
        guard += 1
        j2 = j + step
        now_up = both_up(sat, j2, la1, lo1, la2, lo2, hor)
        if now_up and not inwin:
            wstart = j2
        if (not now_up) and inwin and wstart is not None:
            out.append((wstart, j2))
        inwin = now_up
        j = j2
    if inwin and wstart is not None and len(out) < count:
        out.append((wstart, j))
    return out


def max_mutual_el(sat, a, b, la1, lo1, la2, lo2):
    best = -90.0
    n = 12
    for k in range(n + 1):
        t = a + (b - a) * k / n
        e1, _, _ = sat.look(t, la1, lo1)
        e2, _, _ = sat.look(t, la2, lo2)
        m = min(e1, e2) * RAD
        if m > best:
            best = m
    return best


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
    print("SkedQSO - mutual-pass scheduler")
    g1 = input("Your grid [FM18LV]: ").strip() or "FM18LV"
    g2 = input("Their grid [CM87XX]: ").strip() or "CM87XX"
    la1, lo1 = maiden(g1)
    la2, lo2 = maiden(g2)
    inc = ask("INC", 101.9899)
    ecc = ask("ECC", 0.0012609)
    raan = ask("RAAN", 184.6033)
    argp = ask("ARGP", 124.3014)
    ma = ask("MA", 247.3322)
    mm = ask("MM", 12.53698149)
    ey = ask("Ep Yr", 2026)
    emo = ask("Ep Mo", 6)
    ed = ask("Ep Dy", 20)
    eh = ask("Ep Hr", 7)
    emi = ask("Ep Mi", 46)
    es = ask("Ep Sec", 20.6)
    ny = ask("Now Yr", 2026)
    nmo = ask("Now Mo", 6)
    nd = ask("Now Dy", 22)
    nh = ask("Now Hr", 0)
    nmi = ask("Now Mi", 0)
    days = ask("Days ahead", 2)
    minel = ask("Min elev both ends", 0)
    cnt = ask("How many windows", 5)
    sat = Sat(inc, ecc, raan, argp, ma, mm, jd(ey, emo, ed, eh, emi, es))
    now = jd(ny, nmo, nd, nh, nmi, 0)
    wins = windows(sat, now, la1, lo1, la2, lo2, days, minel, int(cnt))
    print("")
    print("Mutual windows %s <-> %s (>= %g deg both)" % (g1.upper(), g2.upper(), minel))
    print("Date  Start LOS   Dur MaxMin-El")
    if not wins:
        print("(none in window)")
    for (a, b) in wins:
        mo, d, h, mi = cal(a)
        z, z2, h2, m2 = cal(b)
        dur = int(round((b - a) * 1440.0))
        mme = max_mutual_el(sat, a, b, la1, lo1, la2, lo2)
        print("%02d/%02d %02d:%02d %02d:%02d %3dm %5.0f" %
              (d, mo, h, mi, h2, m2, dur, mme))


if __name__ == "__main__":
    main()
