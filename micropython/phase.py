# Phase - transponder/beacon phase & illumination-mode helper.
# MicroPython / CPython. Some classic birds operate only in sunlight
# (e.g. AO-7 runs on solar power with no usable battery, so its
# transponders are available only while the spacecraft is sunlit) or
# alternate modes on a schedule. This tool reports, for a given time,
# whether the satellite is sunlit (so a sunlight-only bird is likely
# active) and - if you give a simple mode schedule - which mode is
# predicted. Planning aid, not a substitute for the control team's word.

import math
from pointing import (Sat, jd, cal, gmst, RAD, DEG, TWOPI, RE, kepler)

AU = 149597870.7


def sun_eci(j):
    n = j - 2451545.0
    L = (280.460 + 0.9856474 * n) % 360
    g = ((357.528 + 0.9856003 * n) % 360) * DEG
    lam = (L + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g)) * DEG
    eps = (23.439 - 0.0000004 * n) * DEG
    R = (1.00014 - 0.01671 * math.cos(g) - 0.00014 * math.cos(2 * g)) * AU
    return R * math.cos(lam), R * math.cos(eps) * math.sin(lam), R * math.sin(eps) * math.sin(lam)


def sat_eci(sat, j):
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
    return (r * (co * cu - so * su * ci),
            r * (so * cu + co * su * ci), r * (su * si))


def sunlit(sat, j):
    sx, sy, sz = sat_eci(sat, j)
    ux, uy, uz = sun_eci(j)
    un = math.sqrt(ux * ux + uy * uy + uz * uz)
    ux, uy, uz = ux / un, uy / un, uz / un
    along = sx * ux + sy * uy + sz * uz
    if along > 0:
        return True
    px = sx - along * ux
    py = sy - along * uy
    pz = sz - along * uz
    return math.sqrt(px * px + py * py + pz * pz) > RE


def next_change(sat, j, want):
    """Find next time (within 3 h) sunlit-state differs from `want`."""
    step = 30.0 / 86400.0
    t = j
    end = j + 3.0 / 24.0
    while t < end:
        if sunlit(sat, t) != want:
            a, b = t - step, t
            for _ in range(25):
                m = (a + b) / 2
                if sunlit(sat, m) == want:
                    a = m
                else:
                    b = m
            return (a + b) / 2
        t += step
    return None


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
    print("Phase - sunlight/mode helper")
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
    sunonly = ask("Sunlight-only bird? 1/0", 1)
    sat = Sat(inc, ecc, raan, argp, ma, mm, jd(ey, emo, ed, eh, emi, es))
    now = jd(ny, nmo, nd, nh, nmi, 0)
    lit = sunlit(sat, now)
    print("")
    print("Now: satellite is %s" % ("SUNLIT" if lit else "in ECLIPSE"))
    nc = next_change(sat, now, lit)
    if nc is not None:
        mo, d, h, mi = cal(nc)
        print("Changes at ~%02d:%02dZ" % (h, mi))
    if sunonly:
        if lit:
            print("Sunlight-only payload: likely ACTIVE now.")
        else:
            print("Sunlight-only payload: likely OFF (in shadow).")
    # crude orbit-phase percentage from mean anomaly
    dt = (now - sat.epoch) * 86400.0
    m = (sat.M0 + sat.n0 * dt) % TWOPI
    print("Orbit phase : %.0f%% past perigee" % (m / TWOPI * 100.0))


if __name__ == "__main__":
    main()
