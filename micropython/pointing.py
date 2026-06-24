# Pointing - Az/El step table for the next (or current) pass, plus a
# one-line "next pass" summary. MicroPython / CPython, no dependencies.
# Same secular-J2 core as the rest of the repo.
#
# Use it to hand-track a rotator or aim an arrow/Yagi: it prints the
# satellite's azimuth and elevation at a fixed time step across the pass.

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
        sth = sl * col * rx + sl * sol * ry - cl * rz
        eth = -sol * rx + col * ry
        zz = cl * col * rx + cl * sol * ry + sl * rz
        rng = math.sqrt(rx * rx + ry * ry + rz * rz)
        v = zz / rng
        if v > 1:
            v = 1
        if v < -1:
            v = -1
        el = math.asin(v)
        az = math.atan2(eth, -sth)
        if az < 0:
            az += TWOPI
        return el, az, rng


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


def find_pass(sat, now, la, lo, horizon=0.0):
    """Return (aos, tca, los, maxel) of the next/current pass, or None."""
    stp = 30.0 / 86400.0
    j = now
    end = now + 14.0
    el, _, _ = sat.look(j, la, lo)
    if el >= horizon:
        aos = j
    else:
        aos = None
        while j < end:
            el, _, _ = sat.look(j, la, lo)
            if el >= horizon:
                a0 = j - stp
                a1 = j
                for _ in range(25):
                    m = (a0 + a1) / 2
                    e2, _, _ = sat.look(m, la, lo)
                    if e2 >= horizon:
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
        el, _, _ = sat.look(j, la, lo)
        j += stp
        if el < horizon or j > aos + 0.02:
            break
    los = j
    t0 = aos
    t1 = los
    for _ in range(40):
        ml = t0 + (t1 - t0) / 3
        mr = t1 - (t1 - t0) / 3
        e1, _, _ = sat.look(ml, la, lo)
        e2, _, _ = sat.look(mr, la, lo)
        if e1 < e2:
            t0 = ml
        else:
            t1 = mr
    tca = (t0 + t1) / 2
    mel, _, _ = sat.look(tca, la, lo)
    return aos, tca, los, mel


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
    print("Pointing - Az/El step table for the next pass")
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
    step = ask("Step seconds", 30)
    sat = Sat(inc, ecc, raan, argp, ma, mm, jd(ey, emo, ed, eh, emi, es))
    now = jd(ny, nmo, nd, nh, nmi, 0)
    pr = find_pass(sat, now, la, lo)
    if pr is None:
        print("No pass within 14 days.")
        return
    aos, tca, los, mel = pr
    mo, d, h, mi = cal(aos)
    _, _, h2, m2 = cal(los)
    dur = round((los - aos) * 1440.0)
    print("")
    print("NEXT PASS  %02d/%02d  AOS %02d:%02dZ  LOS %02d:%02dZ" % (d, mo, h, mi, h2, m2))
    print("MaxEl %.0f deg   Duration %d min" % (mel * RAD, dur))
    print("UTC      Az    El   Range")
    t = aos
    while t <= los + 1e-9:
        el, az, rng = sat.look(t, la, lo)
        if el < 0:
            el = 0.0
        _, _, hh, mm2 = cal(t)
        ss = int(round((t * 86400.0) % 60))
        print("%02d:%02d:%02d %3.0f  %4.0f  %5.0f" %
              (hh, mm2, ss, az * RAD, el * RAD, rng))
        t += step / 86400.0


if __name__ == "__main__":
    main()
