# UpDown - live Doppler "dial now" single readout. MicroPython / CPython.
# Shows the downlink dial to set RIGHT NOW and the matching uplink dial,
# stepping forward each time you press Enter (or auto-steps if you give a
# step). A during-the-pass companion to freqplan.py's whole-pass table.
# Same secular-J2 core; inverting transponder handled.

import math
from pointing import (Sat, find_pass, maiden, cal, jd, RAD)

CK = 299792.458


def range_rate(sat, j, la, lo):
    dt = 1.0 / 86400.0
    _, _, r0 = sat.look(j - dt, la, lo)
    _, _, r1 = sat.look(j + dt, la, lo)
    return (r1 - r0) / 2.0


def dials(sat, j, la, lo, fdn, fup, inv):
    rr = range_rate(sat, j, la, lo)
    dn = fdn - fdn * rr / CK
    if inv:
        up = fup + fup * rr / CK
    else:
        up = fup - fup * rr / CK
    el, az, rng = sat.look(j, la, lo)
    return dn, up, el, az, rng, rr


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
    print("UpDown - live Doppler dial readout")
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
    fdn = ask("Downlink MHz", 145.95)
    fup = ask("Uplink MHz", 435.1)
    inv = ask("Invert? 1/0", 1)
    step = ask("Step sec (Enter=manual)", 15)
    sat = Sat(inc, ecc, raan, argp, ma, mm, jd(ey, emo, ed, eh, emi, es))
    t = jd(ny, nmo, nd, nh, nmi, 0)
    print("Enter to step, Ctrl-C to stop")
    while True:
        dn, up, el, az, rng, rr = dials(sat, t, la, lo, fdn, fup, inv)
        mo, d, h, mi = cal(t)
        tag = "" if el >= 0 else " (below horizon)"
        print("%02d:%02d  RX %.4f  TX %.4f  El%3.0f%s"
              % (h, mi, dn, up, el * RAD, tag))
        try:
            input("")
        except EOFError:
            return
        t += step / 86400.0


if __name__ == "__main__":
    main()
