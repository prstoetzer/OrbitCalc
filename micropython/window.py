# Window - horizon-mask-aware AOS/LOS. MicroPython / CPython.
# Real backyards have trees and buildings. Enter a simple azimuth ->
# horizon-elevation mask (a few sectors) and this recomputes the
# EFFECTIVE AOS/LOS and the time the satellite is actually above your
# local obstructions - so predictions match what you can really hear.
# Same secular-J2 core.

import math
from pointing import (Sat, find_pass, maiden, cal, jd, RAD)


def mask_el(mask, az_deg):
    """Horizon elevation (deg) for a given azimuth from the sector mask."""
    best = 0.0
    for (a0, a1, e) in mask:
        if a0 <= a1:
            inside = a0 <= az_deg <= a1
        else:  # wraps through north
            inside = az_deg >= a0 or az_deg <= a1
        if inside and e > best:
            best = e
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
    print("Window - horizon-mask AOS/LOS")
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
    print("Horizon mask: enter sectors az0 az1 el (blank to end)")
    mask = []
    while True:
        try:
            line = input("sector: ").strip()
        except EOFError:
            break
        if line == "":
            break
        parts = line.replace(",", " ").split()
        if len(parts) >= 3:
            try:
                mask.append((float(parts[0]), float(parts[1]), float(parts[2])))
            except ValueError:
                print("  need: az0 az1 el")
    sat = Sat(inc, ecc, raan, argp, ma, mm, jd(ey, emo, ed, eh, emi, es))
    now = jd(ny, nmo, nd, nh, nmi, 0)
    pr = find_pass(sat, now, la, lo)
    if pr is None:
        print("No pass within 14 days.")
        return
    aos, tca, los, mel = pr
    # walk the pass at 5 s; find when el exceeds local mask
    step = 5.0 / 86400.0
    t = aos
    eff_aos = None
    eff_los = None
    maxvis = -90.0
    while t <= los + 1e-9:
        el, az, rng = sat.look(t, la, lo)
        if el < 0:
            t += step
            continue
        thr = mask_el(mask, az * RAD)
        if el * RAD >= thr:
            if eff_aos is None:
                eff_aos = t
            eff_los = t
            if el * RAD > maxvis:
                maxvis = el * RAD
        t += step
    mo, d, h, mi = cal(aos)
    z, z2, h2, m2 = cal(los)
    print("")
    print("Geometric: AOS %02d:%02d LOS %02d:%02d MaxEl %.0f"
          % (h, mi, h2, m2, mel * RAD))
    if eff_aos is None:
        print("Behind obstructions the whole pass - not workable.")
        return
    mo, d, h, mi = cal(eff_aos)
    z, z2, h2, m2 = cal(eff_los)
    print("Effective: AOS %02d:%02d LOS %02d:%02d MaxEl %.0f"
          % (h, mi, h2, m2, maxvis))
    lost = int(round(((eff_aos - aos) + (los - eff_los)) * 1440.0))
    print("Lost to horizon mask: ~%d min of the pass" % lost)


if __name__ == "__main__":
    main()
