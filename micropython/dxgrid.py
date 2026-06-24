# DXGrid - footprint grid-square enumerator. MicroPython / CPython.
# "Who can I work right now?" For the current sub-satellite point and
# footprint radius, list which Maidenhead fields/squares fall inside the
# footprint. Coarse by design (steps over grid-square centers). Same core.

import math
from pointing import (Sat, jd, cal, gmst, RAD, DEG, TWOPI, RE, kepler)


def subpoint_and_radius(sat, j):
    dt = (j - sat.epoch) * 86400.0
    m = sat.M0 + sat.n0 * dt
    raan = sat.raan0 + sat.raandot * dt
    argp = sat.argp0 + sat.argpdot * dt
    ee = kepler(math.fmod(m, TWOPI), sat.e)
    xo = sat.a * (math.cos(ee) - sat.e)
    yo = sat.a * math.sqrt(1 - sat.e * sat.e) * math.sin(ee)
    u = math.atan2(yo, xo) + argp
    r = math.sqrt(xo * xo + yo * yo)
    co = math.cos(raan)
    so = math.sin(raan)
    cu = math.cos(u)
    su = math.sin(u)
    ci = math.cos(sat.i)
    si = math.sin(sat.i)
    x = r * (co * cu - so * su * ci)
    y = r * (so * cu + co * su * ci)
    z = r * (su * si)
    g = gmst(j)
    cg = math.cos(g)
    sg = math.sin(g)
    xe = cg * x + sg * y
    ye = -sg * x + cg * y
    ze = z
    lat = math.atan2(ze, math.sqrt(xe * xe + ye * ye))
    lon = math.atan2(ye, xe)
    # footprint half-angle (Earth-central) for 0 deg elevation
    rho = math.acos(RE / r)
    return lat * RAD, lon * RAD, rho * RAD


def gc_deg(la1, lo1, la2, lo2):
    a = la1 * DEG
    b = la2 * DEG
    dl = (lo2 - lo1) * DEG
    c = math.sin(a) * math.sin(b) + math.cos(a) * math.cos(b) * math.cos(dl)
    if c > 1:
        c = 1.0
    if c < -1:
        c = -1.0
    return math.acos(c) * RAD


def to_grid(lat, lon):
    lon += 180.0
    lat += 90.0
    A = chr(65 + int(lon // 20))
    B = chr(65 + int(lat // 10))
    c = int((lon % 20) // 2)
    d = int(lat % 10)
    return "%c%c%d%d" % (A, B, c, d)


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
    print("DXGrid - footprint grid enumerator")
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
    sat = Sat(inc, ecc, raan, argp, ma, mm, jd(ey, emo, ed, eh, emi, es))
    now = jd(ny, nmo, nd, nh, nmi, 0)
    slat, slon, rho = subpoint_and_radius(sat, now)
    print("")
    print("Sub-point %.2f,%.2f  footprint %.1f deg radius" % (slat, slon, rho))
    print("Fields under the footprint (4-char grid centers):")
    seen = []
    # step over field/square centers: 2 deg lon, 1 deg lat is fine-grained;
    # use 4-char square centers (2x1 deg) but stride to keep the list short
    lat = -88.0
    while lat <= 88.0:
        lon = -178.0
        while lon <= 178.0:
            if gc_deg(slat, slon, lat, lon) <= rho:
                gsq = to_grid(lat, lon)
                f2 = gsq[:2]
                if f2 not in seen:
                    seen.append(f2)
            lon += 4.0
        lat += 4.0
    # print fields in rows
    line = ""
    for i, f in enumerate(seen):
        line += f + " "
        if (i + 1) % 10 == 0:
            print(line.rstrip())
            line = ""
    if line:
        print(line.rstrip())
    print("(%d fields at least partly in view)" % len(seen))


if __name__ == "__main__":
    main()
