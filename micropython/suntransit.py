# SunTransit - Sun & Moon angular separation from a satellite's line of
# sight, and "transit" alerts when the satellite passes near the Sun or
# Moon disc as seen from your QTH. MicroPython / CPython.
#
# Uses: same secular-J2 satellite core, low-precision Sun almanac, and a
# truncated lunar series. Scans the next/current pass and reports the
# minimum Sun-sat and Moon-sat angular separation, flagging close
# approaches (solar transit can add noise; lunar proximity is a neat
# spotting aid). Planning-grade.

import math
PI = math.pi
TWOPI = 2.0 * PI
DEG = PI / 180.0
RAD = 180.0 / PI
MU = 398600.4418
RE = 6378.137
J2 = 1.08262668e-3
AU = 149597870.7


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
    def __init__(s, inc, ecc, raan, argp, ma, mm, ep):
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

    def topo(s, j, la, lo):
        """Return (el, az, unit-vector to sat in ENU) for observer."""
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
        return enu_unit(xe, ye, ze, la, lo)


def enu_unit(xe, ye, ze, la, lo):
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
    s_ = sl * col * rx + sl * sol * ry - cl * rz   # south
    e = -sol * rx + col * ry                       # east
    up = cl * col * rx + cl * sol * ry + sl * rz    # up
    rng = math.sqrt(rx * rx + ry * ry + rz * rz)
    el = math.asin(up / rng)
    az = math.atan2(e, -s_)
    if az < 0:
        az += TWOPI
    # unit vector in ENU
    ux = e / rng
    uy = -s_ / rng    # north
    uz = up / rng
    return el, az, (ux, uy, uz)


def sun_eci(j):
    n = j - 2451545.0
    L = (280.460 + 0.9856474 * n) % 360
    g = ((357.528 + 0.9856003 * n) % 360) * DEG
    lam = (L + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g)) * DEG
    eps = (23.439 - 0.0000004 * n) * DEG
    R = (1.00014 - 0.01671 * math.cos(g) - 0.00014 * math.cos(2 * g)) * AU
    return R * math.cos(lam), R * math.cos(eps) * math.sin(lam), R * math.sin(eps) * math.sin(lam)


def moon_eci(j):
    T = (j - 2451545.0) / 36525.0
    Lp = (218.316 + 481267.881 * T) % 360
    M = (357.529 + 35999.050 * T) % 360
    Mp = (134.963 + 477198.867 * T) % 360
    D = (297.850 + 445267.115 * T) % 360
    F = (93.272 + 483202.018 * T) % 360
    Lp *= DEG
    M *= DEG
    Mp *= DEG
    D *= DEG
    F *= DEG
    lon = Lp + (6.289 * math.sin(Mp) + 1.274 * math.sin(2 * D - Mp)
                + 0.658 * math.sin(2 * D) + 0.214 * math.sin(2 * Mp)
                - 0.186 * math.sin(M) - 0.114 * math.sin(2 * F)) * DEG
    lat = (5.128 * math.sin(F) + 0.281 * math.sin(Mp + F)
           + 0.278 * math.sin(Mp - F) + 0.173 * math.sin(2 * D - F)) * DEG
    dist = 385000.0 - 20905 * math.cos(Mp) - 3699 * math.cos(2 * D - Mp) - 2956 * math.cos(2 * D)
    eps = 23.439 * DEG
    xe = dist * math.cos(lat) * math.cos(lon)
    ye = dist * (math.cos(eps) * math.cos(lat) * math.sin(lon) - math.sin(eps) * math.sin(lat))
    ze = dist * (math.sin(eps) * math.cos(lat) * math.sin(lon) + math.cos(eps) * math.sin(lat))
    return xe, ye, ze


def body_unit(eci_fn, j, la, lo):
    xs, ys, zs = eci_fn(j)
    g = gmst(j)
    cg = math.cos(g)
    sg = math.sin(g)
    xe = cg * xs + sg * ys
    ye = -sg * xs + cg * ys
    ze = zs
    el, az, u = enu_unit(xe, ye, ze, la, lo)
    return el, az, u


def sep(u, v):
    d = u[0] * v[0] + u[1] * v[1] + u[2] * v[2]
    if d > 1:
        d = 1.0
    if d < -1:
        d = -1.0
    return math.acos(d) * RAD


def find_pass(sat, now, la, lo):
    stp = 30.0 / 86400.0
    j = now
    end = now + 14.0
    el, _, _ = sat.topo(j, la, lo)
    if el >= 0:
        aos = j
    else:
        aos = None
        while j < end:
            el, _, _ = sat.topo(j, la, lo)
            if el >= 0:
                a0 = j - stp
                a1 = j
                for _ in range(25):
                    m = (a0 + a1) / 2
                    e2, _, _ = sat.topo(m, la, lo)
                    if e2 >= 0:
                        a1 = m
                    else:
                        a0 = m
                aos = a1
                break
            j += stp
        if aos is None:
            return None
    j = aos + stp
    while True:
        el, _, _ = sat.topo(j, la, lo)
        j += stp
        if el < 0 or j > aos + 0.02:
            break
    return aos, j


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


def main():
    print("SunTransit - Sun/Moon proximity during a pass")
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
    sat = Sat(inc, ecc, raan, argp, ma, mm, jd(ey, emo, ed, eh, emi, es))
    now = jd(ny, nmo, nd, nh, nmi, 0)
    pr = find_pass(sat, now, la, lo)
    if pr is None:
        print("No pass within 14 days.")
        return
    aos, los = pr
    best_sun = 999.0
    best_moon = 999.0
    tsun = aos
    tmoon = aos
    t = aos
    while t <= los:
        el, az, su = sat.topo(t, la, lo)
        sel, saz, suu = body_unit(sun_eci, t, la, lo)
        mel, maz, muu = body_unit(moon_eci, t, la, lo)
        dssun = sep(su, suu)
        dsmoon = sep(su, muu)
        if dssun < best_sun:
            best_sun = dssun
            tsun = t
        if dsmoon < best_moon:
            best_moon = dsmoon
            tmoon = t
        t += 5.0 / 86400.0
    mo, d, h, mi = cal(tsun)
    print("")
    print("Min Sun-sat separation : %.1f deg at %02d:%02dZ" % (best_sun, h, mi))
    mo, d, h, mi = cal(tmoon)
    print("Min Moon-sat separation: %.1f deg at %02d:%02dZ" % (best_moon, h, mi))
    if best_sun < 5.0:
        print("  ! Near SOLAR transit - expect extra noise.")
    if best_moon < 5.0:
        print("  ! Near the Moon - nice spotting opportunity.")


if __name__ == "__main__":
    main()
