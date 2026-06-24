# Node2Me - next ascending-node times and equator-crossing longitudes.
# MicroPython / CPython. Prints the numbers you mark on a paper
# OSCARLOCATOR board (ascending-node UTC time and its longitude), derived
# from the live element set instead of a hand-kept table. Same secular-J2
# core. South-going? Ask for descending nodes instead.

import math
from pointing import (Sat, jd, cal, gmst, RAD, DEG, TWOPI, RE)


def subpoint(sat, j):
    """Sub-satellite (lat, lon) in degrees from the ECI position."""
    # reuse the propagation inside Sat.look by recomputing ECEF here
    dt = (j - sat.epoch) * 86400.0
    m = sat.M0 + sat.n0 * dt
    raan = sat.raan0 + sat.raandot * dt
    argp = sat.argp0 + sat.argpdot * dt
    from pointing import kepler
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
    lat = math.atan2(ze, math.sqrt(xe * xe + ye * ye)) * RAD
    lon = math.atan2(ye, xe) * RAD
    return lat, lon


def find_nodes(sat, now, count, ascending=True):
    """Return list of (jd, lon_deg) for the next `count` equator crossings."""
    out = []
    step = 20.0 / 86400.0   # 20-second scan
    j = now
    guard = 0
    prev_lat, _ = subpoint(sat, j)
    while len(out) < count and guard < 600000:
        guard += 1
        j2 = j + step
        lat2, lon2 = subpoint(sat, j2)
        crossing = False
        if ascending and prev_lat < 0 <= lat2:
            crossing = True
        if (not ascending) and prev_lat > 0 >= lat2:
            crossing = True
        if crossing:
            a, b = j, j2
            for _ in range(30):
                m = (a + b) / 2
                lm, _ = subpoint(sat, m)
                if ascending:
                    if lm < 0:
                        a = m
                    else:
                        b = m
                else:
                    if lm > 0:
                        a = m
                    else:
                        b = m
            jc = (a + b) / 2
            _, lonc = subpoint(sat, jc)
            out.append((jc, lonc))
        prev_lat = lat2
        j = j2
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
    print("Node2Me - equator-crossing table")
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
    asc = ask("Ascending nodes? 1/0", 1)
    cnt = ask("How many", 8)
    sat = Sat(inc, ecc, raan, argp, ma, mm, jd(ey, emo, ed, eh, emi, es))
    now = jd(ny, nmo, nd, nh, nmi, 0)
    nodes = find_nodes(sat, now, int(cnt), asc == 1)
    kind = "Ascending" if asc == 1 else "Descending"
    print("")
    print("%s nodes (UTC time, longitude):" % kind)
    print("Date  UTC    Longitude")
    for (jc, lon) in nodes:
        mo, d, h, mi = cal(jc)
        ew = "E" if lon >= 0 else "W"
        print("%02d/%02d %02d:%02d  %6.2f %s" % (d, mo, h, mi, abs(lon), ew))


if __name__ == "__main__":
    main()
