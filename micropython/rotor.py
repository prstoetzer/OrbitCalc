# Rotor - rotator preset / pass-macro generator. MicroPython / CPython.
# Emits a time-stamped Az/El sequence for the next pass in a chosen
# format: a plain table, comma-separated values, or a ";"-delimited
# "Az El @hh:mm:ss" macro a microcontroller could replay to a rotator.
# Optional flip-mode note for az/el rotators that would hit the zenith
# stop. Same secular-J2 core as pointing.py.

import math
from pointing import (Sat, find_pass, maiden, cal, jd, RAD)


def flip(az, el):
    """Return the flipped (az, el) for an over-the-top az/el rotator."""
    fa = az + 180.0
    if fa >= 360.0:
        fa -= 360.0
    fe = 180.0 - el
    return fa, fe


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
    print("Rotor - pass macro / preset generator")
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
    step = ask("Step sec", 30)
    print("Format: 1 table  2 CSV  3 macro")
    fmt = ask("Choose", 1)
    fl = ask("Flip over top? 1/0", 0)
    sat = Sat(inc, ecc, raan, argp, ma, mm, jd(ey, emo, ed, eh, emi, es))
    now = jd(ny, nmo, nd, nh, nmi, 0)
    pr = find_pass(sat, now, la, lo)
    if pr is None:
        print("No pass within 14 days.")
        return
    aos, tca, los, mel = pr
    if fmt == 2:
        print("hh:mm:ss,az,el")
    elif fmt == 3:
        print("# replay: Az El @hh:mm:ss ; ...")
    else:
        print("UTC      Az   El")
    line = ""
    t = aos
    while t <= los + 1e-9:
        el, az, rng = sat.look(t, la, lo)
        if el < 0:
            el = 0.0
        ad = az * RAD
        ed_ = el * RAD
        if fl:
            ad, ed_ = flip(ad, ed_)
        mo, d, h, mi = cal(t)
        sec = int(round((t * 86400.0) % 60))
        if sec == 60:
            sec = 0
        ts = "%02d:%02d:%02d" % (h, mi, sec)
        if fmt == 2:
            print("%s,%.0f,%.0f" % (ts, ad, ed_))
        elif fmt == 3:
            line += "%.0f %.0f @%s ; " % (ad, ed_, ts)
        else:
            print("%s %4.0f %4.0f" % (ts, ad, ed_))
        t += step / 86400.0
    if fmt == 3:
        print(line.rstrip("; "))
    if fl:
        print("(flip-mode: az+180, el=180-el for over-the-top tracking)")


if __name__ == "__main__":
    main()
