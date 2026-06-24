# orbdata.py - orbital data from GP/OMM elements, Casio fx-9750GIII
# Python mode. Closed-form summary (no propagation): apogee/perigee,
# period, semi-major axis, velocities, J2 drift, footprint, track shift.
# MicroPython 1.9.4 safe dialect (plain decimals, one stmt per line).
import math

PI = math.pi
TWOPI = 2.0 * PI
DEG = PI / 180.0
RAD = 180.0 / PI
MU = 398600.4418
RE = 6378.137
J2 = 0.00108262668


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
    print("OrbData (fx-9750GIII)")
    inc = ask("INC deg", 101.9899)
    ecc = ask("ECC", 0.0012609)
    mm = ask("MM rev/day", 12.53698149)
    n = mm * TWOPI / 86400.0
    a = (MU / (n * n)) ** (1.0 / 3.0)
    i = inc * DEG
    rp = a * (1.0 - ecc)
    ra = a * (1.0 + ecc)
    p = a * (1.0 - ecc * ecc)
    f = 1.5 * J2 * (RE / p) ** 2 * n
    raandot = -f * math.cos(i) * RAD * 86400.0
    argpdot = f * (2.0 - 2.5 * math.sin(i) ** 2) * RAD * 86400.0
    vp = math.sqrt(MU * (2.0 / rp - 1.0 / a))
    va = math.sqrt(MU * (2.0 / ra - 1.0 / a))
    vc = math.sqrt(MU / a)
    per = 1440.0 / mm
    rmean = (ra + rp) / 2.0
    rho = math.acos(RE / rmean)
    shift = 360.0 / mm
    print("a    %.1f km" % a)
    print("per  %.2f min" % per)
    print("apo  %.1f km" % (ra - RE))
    print("per  %.1f km" % (rp - RE))
    print("Vp   %.3f km/s" % vp)
    print("Va   %.3f km/s" % va)
    print("Vc   %.3f km/s" % vc)
    print("dRAAN %+.4f d/dy" % raandot)
    print("dARGP %+.4f d/dy" % argpdot)
    print("foot %.1f deg" % (rho * RAD))
    print("footkm %.0f" % (rho * RE))
    print("lon/orb %.2f W" % shift)


main()
