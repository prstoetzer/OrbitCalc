# decay.py - element freshness & decay flag, Casio fx-9750GIII Python.
# Warns when elements are stale; flags low-perigee fast decay.
# MicroPython 1.9.4 safe dialect.
import math

PI = math.pi
TWOPI = 2.0 * PI
MU = 398600.4418
RE = 6378.137


def jd(y, mo, d, h, mi, s):
    if mo <= 2:
        y = y - 1
        mo = mo + 12
    a = int(y / 100)
    b = 2 - a + int(a / 4)
    return (int(365.25 * (y + 4716)) + int(30.6001 * (mo + 1)) + d + b
            - 1524.5 + (h + mi / 60.0 + s / 3600.0) / 24.0)


def ask(p, d):
    try:
        s = input(p + " [" + str(d) + "]: ").strip()
    except EOFError:
        return d
    if s == "":
        return d
    try:
        return float(s)
    except ValueError:
        return d


def main():
    print("Decay (fx-9750GIII)")
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
    n = mm * TWOPI / 86400.0
    a = (MU / (n * n)) ** (1.0 / 3.0)
    altp = a * (1.0 - ecc) - RE
    alta = a * (1.0 + ecc) - RE
    print("Age %.2f days" % age)
    if age < 0:
        print("! Now before epoch")
    elif age > 14:
        print("! Very stale (>14d)")
    elif age > 5:
        print("! Getting stale (>5d)")
    else:
        print("Fresh enough")
    print("Mean alt %.0f km" % (a - RE))
    print("Peri %.0f Apo %.0f km" % (altp, alta))
    if altp < 200:
        print("! Low peri-rapid decay")
    elif altp < 350:
        print("! Low peri-refresh daily")


main()
