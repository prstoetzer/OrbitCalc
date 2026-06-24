# MultiSat - next pass of EACH of several satellites, merged and sorted
# by time (a "what's up next" board). MicroPython / CPython. Same
# secular-J2 core. Enter up to 8 satellites; it prints the next AOS for
# each within the search window, sorted soonest-first.

import math
PI = math.pi
TWOPI = 2.0 * PI
DEG = PI / 180.0
RAD = 180.0 / PI
MU = 398600.4418
RE = 6378.137
J2 = 1.08262668e-3


def jd(y, mo, d, h, mi, s):
    if mo <= 2:
        y -= 1
        mo += 12
    a = y // 100
    b = 2 - a + a // 4
    return (int(365.25 * (y + 4716)) + int(30.6001 * (mo + 1)) + d + b
            - 1524.5 + (h + mi / 60.0 + s / 3600.0) / 24.0)


def gmst(j):
    t = (j - 2451545.0) / 36525.0
    g = (280.46061837 + 360.98564736629 * (j - 2451545.0)
         + 0.000387933 * t * t - t * t * t / 38710000.0)
    g = math.fmod(g, 360.0)
    if g < 0:
        g += 360.0
    return g * DEG


def kepler(m, e):
    x = m
    for _ in range(50):
        dx = (x - e * math.sin(x) - m) / (1 - e * math.cos(x))
        x -= dx
        if abs(dx) < 1e-12:
            break
    return x


class Sat:
    def __init__(s, name, inc, ecc, raan, argp, ma, mm, ep):
        s.name = name
        s.i = inc * DEG
        s.e = ecc
        s.raan0 = raan * DEG
        s.argp0 = argp * DEG
        s.M0 = ma * DEG
        s.n0 = mm * TWOPI / 86400.0
        s.epoch = ep
        s.a = (MU / (s.n0 * s.n0)) ** (1.0 / 3.0)
        p = s.a * (1 - s.e * s.e)
        f = 1.5 * J2 * (RE / p) ** 2 * s.n0
        s.raandot = -f * math.cos(s.i)
        s.argpdot = f * (2 - 2.5 * math.sin(s.i) ** 2)

    def look(s, j, la, lo):
        dt = (j - s.epoch) * 86400.0
        m = s.M0 + s.n0 * dt
        raan = s.raan0 + s.raandot * dt
        argp = s.argp0 + s.argpdot * dt
        ee = kepler(math.fmod(m, TWOPI), s.e)
        xo = s.a * (math.cos(ee) - s.e)
        yo = s.a * math.sqrt(1 - s.e * s.e) * math.sin(ee)
        u = math.atan2(yo, xo) + argp
        r = math.sqrt(xo * xo + yo * yo)
        co = math.cos(raan)
        so = math.sin(raan)
        cu = math.cos(u)
        su = math.sin(u)
        ci = math.cos(s.i)
        si = math.sin(s.i)
        x = r * (co * cu - so * su * ci)
        y = r * (so * cu + co * su * ci)
        z = r * (su * si)
        g = gmst(j)
        cg = math.cos(g)
        sg = math.sin(g)
        xe = cg * x + sg * y
        ye = -sg * x + cg * y
        ze = z
        cl = math.cos(la)
        sl = math.sin(la)
        col = math.cos(lo)
        sol = math.sin(lo)
        ox = RE * cl * col
        oy = RE * cl * sol
        oz = RE * sl
        rx = xe - ox
        ry = ye - oy
        rz = ze - oz
        zz = cl * col * rx + cl * sol * ry + sl * rz
        rng = math.sqrt(rx * rx + ry * ry + rz * rz)
        return math.asin(zz / rng)


def next_aos(sat, now, la, lo, days=2.0):
    stp = 30.0 / 86400.0
    j = now
    end = now + days
    el = sat.look(j, la, lo)
    if el >= 0:
        return now, True   # already up
    while j < end:
        el = sat.look(j, la, lo)
        if el >= 0:
            a0 = j - stp
            a1 = j
            for _ in range(20):
                m = (a0 + a1) / 2
                if sat.look(m, la, lo) >= 0:
                    a1 = m
                else:
                    a0 = m
            return a1, False
        j += stp
    return None, False


def maxel(sat, aos, la, lo):
    stp = 30.0 / 86400.0
    j = aos
    me = 0.0
    while j < aos + 0.02:
        e = sat.look(j, la, lo)
        if e < 0 and j > aos + stp:
            break
        if e > me:
            me = e
        j += stp
    return me


def cal(j):
    j += 0.5
    z = int(j)
    f = j - z
    if z < 2299161:
        a = z
    else:
        al = int((z - 1867216.25) / 36524.25)
        a = z + 1 + al - int(al / 4)
    b = a + 1524
    c = int((b - 122.1) / 365.25)
    dd = int(365.25 * c)
    e = int((b - dd) / 30.6001)
    day = b - dd - int(30.6001 * e) + f
    mo = e - 1 if e < 14 else e - 13
    d = int(day)
    sec = (day - d) * 86400.0
    h = int(sec / 3600)
    sec -= h * 3600
    mi = int(sec / 60)
    return mo, d, h, mi


def maiden(g):
    g = g.strip().upper()
    lo = (ord(g[0]) - 65) * 20 - 180
    la = (ord(g[1]) - 65) * 10 - 90
    lo += (ord(g[2]) - 48) * 2
    la += (ord(g[3]) - 48)
    if len(g) >= 6:
        lo += (ord(g[4]) - 65) / 12.0 + 1.0 / 24.0
        la += (ord(g[5]) - 65) / 24.0 + 1.0 / 48.0
    else:
        lo += 1.0
        la += 0.5
    return la * DEG, lo * DEG


def ask(p, d):
    try:
        s = input("%s [%s]: " % (p, d)).strip()
    except EOFError:
        return d
    if s == "":
        return d
    try:
        return float(s) if ("." in s or "e" in s.lower() or "-" in s) else int(s)
    except ValueError:
        return d


# A small built-in starter catalogue (epoch 2026-06-20 07:46:20.6, same as AO-7
# reference for AO-7; others are representative and should be refreshed).
CATALOG = [
    ("AO-7", 101.9899, 0.0012609, 184.6033, 124.3014, 247.3322, 12.53698149),
    ("ISS", 51.6400, 0.0003000, 90.0000, 60.0000, 300.0000, 15.5000000),
    ("SO-50", 64.5500, 0.0070000, 200.0000, 150.0000, 210.0000, 14.7500000),
]


def main():
    print("MultiSat - next pass of each satellite")
    g = input("Grid [FM18LV]: ").strip() or "FM18LV"
    la, lo = maiden(g)
    print("Epoch UTC (shared) :")
    ey = ask("Ep Yr", 2026)
    emo = ask("Ep Mo", 6)
    ed = ask("Ep Dy", 20)
    eh = ask("Ep Hr", 7)
    emi = ask("Ep Mi", 46)
    es = ask("Ep Sec", 20.6)
    print("Now UTC:")
    ny = ask("Now Yr", 2026)
    nmo = ask("Now Mo", 6)
    nd = ask("Now Dy", 22)
    nh = ask("Now Hr", 0)
    nmi = ask("Now Mi", 0)
    ep = jd(ey, emo, ed, eh, emi, es)
    now = jd(ny, nmo, nd, nh, nmi, 0)
    use = input("Use built-in catalog? y/n [y]: ").strip().lower()
    sats = []
    if use != "n":
        for c in CATALOG:
            sats.append(Sat(c[0], c[1], c[2], c[3], c[4], c[5], c[6], ep))
    else:
        ns = int(ask("How many sats", 2))
        for k in range(ns):
            nm = input("Name #%d: " % (k + 1)).strip() or ("SAT%d" % (k + 1))
            inc = ask(" INC", 51.6)
            ecc = ask(" ECC", 0.001)
            raan = ask(" RAAN", 90)
            argp = ask(" ARGP", 60)
            ma = ask(" MA", 300)
            mm = ask(" MM", 15.5)
            sats.append(Sat(nm, inc, ecc, raan, argp, ma, mm, ep))
    rows = []
    for st in sats:
        aos, up = next_aos(st, now, la, lo)
        if aos is None:
            continue
        me = maxel(st, aos, la, lo)
        rows.append((aos, st.name, me, up))
    rows.sort(key=lambda r: r[0])
    print("")
    print("NEXT PASSES (soonest first)")
    print("Sat       AOS(UTC)  MaxEl")
    for (aos, nm, me, up) in rows:
        mo, d, h, mi = cal(aos)
        tag = " (UP NOW)" if up else ""
        print("%-9s %02d/%02d %02d:%02d  %3.0f%s" % (nm, d, mo, h, mi, me * RAD, tag))


if __name__ == "__main__":
    main()
