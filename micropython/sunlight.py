# Sunlight - illumination & optical-visibility timeline for a pass.
# MicroPython / CPython. For the upcoming pass it reports when the
# satellite is sunlit vs. in Earth's shadow (cylindrical-shadow model),
# and whether the GROUND STATION is in darkness - the classic optical
# spotting condition (satellite lit, observer dark). Also handy for
# reasoning about a solar-powered bird's battery state. Same core.

import math
from pointing import (Sat, find_pass, maiden, cal, jd, gmst, RAD, DEG, TWOPI, RE, kepler)

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
            r * (so * cu + co * su * ci),
            r * (su * si))


def sunlit(sat, j):
    """True if satellite is in sunlight (cylindrical shadow test)."""
    sx, sy, sz = sat_eci(sat, j)
    ux, uy, uz = sun_eci(j)
    un = math.sqrt(ux * ux + uy * uy + uz * uz)
    ux, uy, uz = ux / un, uy / un, uz / un
    # component of sat vector along sun direction
    along = sx * ux + sy * uy + sz * uz
    if along > 0:
        return True   # sun-side hemisphere: always lit
    # perpendicular distance from Earth-Sun axis
    px = sx - along * ux
    py = sy - along * uy
    pz = sz - along * uz
    perp = math.sqrt(px * px + py * py + pz * pz)
    return perp > RE   # outside the shadow cylinder => lit


def observer_dark(j, la, lo):
    """True if the Sun is below the observer's horizon (civil-ish, el<0)."""
    ux, uy, uz = sun_eci(j)
    g = gmst(j)
    cg = math.cos(g)
    sg = math.sin(g)
    xe = cg * ux + sg * uy
    ye = -sg * ux + cg * uy
    ze = uz
    cl = math.cos(la)
    sl = math.sin(la)
    col = math.cos(lo)
    sol = math.sin(lo)
    # up component at observer
    up = cl * col * xe + cl * sol * ye + sl * ze
    return up < 0


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
    print("Sunlight - illumination & visibility")
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
    aos, tca, los, mel = pr
    print("")
    print("UTC    Sat   Obs   Visible?")
    t = aos
    vis_any = False
    prev_lit = None
    while t <= los + 1e-9:
        lit = sunlit(sat, t)
        dark = observer_dark(t, la, lo)
        vis = lit and dark
        if vis:
            vis_any = True
        mo, d, h, mi = cal(t)
        print("%02d:%02d  %s  %s  %s" % (
            h, mi, "sun " if lit else "shad",
            "dark" if dark else "day ",
            "YES" if vis else "-"))
        t += 60.0 / 86400.0
    print("")
    if vis_any:
        print("Optically visible at some point (sat sunlit, you in dark).")
    else:
        print("Not optically visible this pass.")


if __name__ == "__main__":
    main()
