# PassCal - multi-day pass calendar with a minimum-elevation filter.
# MicroPython / CPython. Lists every workable pass of one satellite over
# the next N days whose maximum elevation meets a threshold you set
# (e.g. only passes above 20 deg, the rule-of-thumb for completing FM
# contacts). Same secular-J2 core as the rest of the suite.

import math
from pointing import (Sat, find_pass, maiden, cal, jd, RAD)


def list_passes(sat, now, la, lo, days, min_el):
    """Yield (aos, tca, los, maxel) for passes with maxel >= min_el."""
    out = []
    end = now + days
    t = now
    guard = 0
    while t < end and guard < 400:
        guard += 1
        pr = find_pass(sat, t, la, lo)
        if pr is None:
            break
        aos, tca, los, mel = pr
        if aos >= end:
            break
        if mel * RAD >= min_el:
            out.append((aos, tca, los, mel))
        # advance to just after this LOS
        t = los + 60.0 / 86400.0
    return out


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
    print("PassCal - multi-day pass calendar")
    g = input("Grid [FM18LV]: ").strip() or "FM18LV"
    la, lo = maiden(g)
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
    days = ask("Days ahead", 3)
    minel = ask("Min max-El deg", 20)
    sat = Sat(inc, ecc, raan, argp, ma, mm, jd(ey, emo, ed, eh, emi, es))
    now = jd(ny, nmo, nd, nh, nmi, 0)
    rows = list_passes(sat, now, la, lo, days, minel)
    print("")
    print("Passes >= %g deg over %g days" % (minel, days))
    print("Date  AOS   LOS   MaxEl AzMax Dur")
    if not rows:
        print("(none)")
    for (aos, tca, los, mel) in rows:
        mo, d, h, mi = cal(aos)
        z2, z3, h2, m2 = cal(los)
        el, az, rng = sat.look(tca, la, lo)
        dur = int(round((los - aos) * 1440.0))
        print("%02d/%02d %02d:%02d %02d:%02d %4.0f %4.0f %3dm" %
              (d, mo, h, mi, h2, m2, mel * RAD, az * RAD, dur))


if __name__ == "__main__":
    main()
