# sunecl.py - Sun position + satellite eclipse for the Casio fx-9750GIII
# Python mode (casioplot). Sun az/el for your QTH, day/night, and
# whether the satellite is sunlit or in Earth's shadow, with a
# sunlit/eclipse timeline for the next ~100 minutes.
from casioplot import set_pixel, draw_string, show_screen, clear_screen
import math
try:
    from casioplot import getkey
except ImportError:
    getkey = None

PI = math.pi
TWOPI = 2 * PI
DEG = PI / 180.0
RAD = 180.0 / PI
MU = 398600.4418
ERAD = 6378.137
J2 = 1.08262668e-3
AU = 149597870.7
BLACK = (0, 0, 0)

OBLAT = 38.9 * DEG
OBLON = -77.0 * DEG
EL = [101.9899, 0.0012609, 184.6033, 124.3014, 247.3322, 12.53698149]
EP = (2026, 6, 20, 7, 46, 20.6)
NW = (2026, 6, 22, 0, 0)
WI = WE = WO = WG = WM = WN = WJ = WA = WRD = WPD = 0.0


def jd(y, mo, d, h, mi, s):
    if mo <= 2:
        y -= 1
        mo += 12
    a = int(y / 100)
    b = 2 - a + int(a / 4)
    return (int(365.25 * (y + 4716)) + int(30.6001 * (mo + 1)) + d + b
            - 1524.5 + (h + mi / 60.0 + s / 3600.0) / 24.0)


def gmst(j):
    t = (j - 2451545.0) / 36525.0
    g = 280.46061837 + 360.98564736629 * (j - 2451545.0) + 0.000387933 * t * t
    g = g % 360.0
    if g < 0:
        g += 360.0
    return g * DEG


def kepler(m, e):
    x = m
    for _ in range(40):
        dx = (x - e * math.sin(x) - m) / (1 - e * math.cos(x))
        x -= dx
        if abs(dx) < 1e-11:
            break
    return x


def loadsat():
    global WI, WE, WO, WG, WM, WN, WJ, WA, WRD, WPD
    WI = EL[0] * DEG; WE = EL[1]; WO = EL[2] * DEG; WG = EL[3] * DEG
    WM = EL[4] * DEG; WN = EL[5] * TWOPI / 86400.0; WJ = jd(*EP)
    WA = (MU / (WN * WN)) ** (1.0 / 3.0)
    p = WA * (1 - WE * WE)
    f = 1.5 * J2 * (ERAD / p) ** 2 * WN
    WRD = -f * math.cos(WI)
    WPD = f * (2 - 2.5 * math.sin(WI) ** 2)


def sat_eci(j):
    dt = (j - WJ) * 86400.0
    m = WM + WN * dt; ra = WO + WRD * dt; ap = WG + WPD * dt
    m = m - TWOPI * int(m / TWOPI)
    ee = kepler(m, WE)
    xo = WA * (math.cos(ee) - WE); yo = WA * math.sqrt(1 - WE * WE) * math.sin(ee)
    u = math.atan2(yo, xo) + ap; r = math.sqrt(xo * xo + yo * yo)
    co = math.cos(ra); so = math.sin(ra); cu = math.cos(u); su = math.sin(u)
    ci = math.cos(WI); si = math.sin(WI)
    return (r * (co * cu - so * su * ci), r * (so * cu + co * su * ci), r * (su * si))


def sun_eci(j):
    n = j - 2451545.0
    L = (280.460 + 0.9856474 * n) % 360
    g = ((357.528 + 0.9856003 * n) % 360) * DEG
    lam = (L + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g)) * DEG
    eps = (23.439 - 0.0000004 * n) * DEG
    R = 1.00014 - 0.01671 * math.cos(g) - 0.00014 * math.cos(2 * g)
    rk = R * AU
    return (rk * math.cos(lam), rk * math.cos(eps) * math.sin(lam),
            rk * math.sin(eps) * math.sin(lam))


def sun_look(j):
    xs, ys, zs = sun_eci(j)
    g = gmst(j); cg = math.cos(g); sg = math.sin(g)
    xe = cg * xs + sg * ys; ye = -sg * xs + cg * ys; ze = zs
    cl = math.cos(OBLAT); sl = math.sin(OBLAT); col = math.cos(OBLON); sol = math.sin(OBLON)
    ox = ERAD * cl * col; oy = ERAD * cl * sol; oz = ERAD * sl
    rx = xe - ox; ry = ye - oy; rz = ze - oz
    s = sl * col * rx + sl * sol * ry - cl * rz
    e = -sol * rx + col * ry
    zz = cl * col * rx + cl * sol * ry + sl * rz
    rng = math.sqrt(rx * rx + ry * ry + rz * rz)
    el = math.asin(zz / rng); az = math.atan2(e, -s)
    if az < 0:
        az += TWOPI
    return el, az


def is_lit(j):
    sx, sy, sz = sat_eci(j)
    ux, uy, uz = sun_eci(j)
    un = math.sqrt(ux * ux + uy * uy + uz * uz)
    ux /= un; uy /= un; uz /= un
    dotp = sx * ux + sy * uy + sz * uz
    if dotp > 0:
        return 1
    px = sx - dotp * ux; py = sy - dotp * uy; pz = sz - dotp * uz
    perp = math.sqrt(px * px + py * py + pz * pz)
    return 1 if perp > ERAD else 0


def cal(j):
    j += 0.5
    z = int(j); f = j - z
    if z < 2299161:
        a = z
    else:
        al = int((z - 1867216.25) / 36524.25)
        a = z + 1 + al - int(al / 4)
    b = a + 1524; c = int((b - 122.1) / 365.25); dd = int(365.25 * c)
    e = int((b - dd) / 30.6001); day = b - dd - int(30.6001 * e) + f
    mo = e - 1 if e < 14 else e - 13
    d = int(day); sec = (day - d) * 86400.0
    h = int(sec / 3600); sec -= h * 3600; mi = int(sec / 60)
    return mo, d, h, mi


def vline(x, y0, y1):
    for y in range(y0, y1 + 1):
        if 0 <= x < 128 and 0 <= y < 64:
            set_pixel(x, y, BLACK)


def draw(now, toff):
    j = now + toff / 1440.0
    clear_screen()
    sel, saz = sun_look(j)
    mo, d, h, mi = cal(j)
    draw_string(0, 0, "SUN/ECL %02d:%02dZ" % (h, mi), BLACK, "small")
    daystr = "day" if sel >= 0 else ("twi" if sel > -6 * DEG else "night")
    draw_string(0, 11, "Sun El%d Az%d %s" % (int(sel * RAD), int(saz * RAD), daystr), BLACK, "small")
    lit = is_lit(j)
    draw_string(0, 23, "Sat: " + ("SUNLIT" if lit else "ECLIPSE"), BLACK, "small")
    # timeline next 100 min
    draw_string(0, 35, "Next 100min:", BLACK, "small")
    y0 = 45; y1 = 53
    for i in range(0, 120):
        t = j + (i / 119.0) * (100.0 / 1440.0)
        if is_lit(t):
            # sunlit = full bar
            vline(4 + i, y0, y1)
        else:
            # eclipse = just baseline tick
            set_pixel(4 + i, y1, BLACK)
    # next transition
    cur = is_lit(j); tnext = None
    for i in range(1, 220):
        tt = j + i * 30.0 / 86400.0
        if is_lit(tt) != cur:
            tnext = tt
            break
    if tnext is not None:
        mo, d, h2, m2 = cal(tnext)
        if cur:
            draw_string(0, 56, "->eclipse %02d:%02d" % (h2, m2), BLACK, "small")
        else:
            draw_string(0, 56, "->sunlit %02d:%02d" % (h2, m2), BLACK, "small")
    show_screen()


def ask(p, dflt):
    try:
        s = input(p + " [" + str(dflt) + "]: ").strip()
    except EOFError:
        return dflt
    if s == "":
        return dflt
    try:
        return float(s) if ("." in s or "e" in s.lower()) else int(s)
    except ValueError:
        return dflt


def main():
    global OBLAT, OBLON
    print("SUN/ECLIPSE (fx-9750GIII)")
    g = input("Grid [FM18LV]: ").strip().upper()
    if len(g) >= 4:
        lo = (ord(g[0]) - 65) * 20 - 180
        la = (ord(g[1]) - 65) * 10 - 90
        lo += (ord(g[2]) - 48) * 2; la += (ord(g[3]) - 48)
        if len(g) >= 6:
            lo += (ord(g[4]) - 65) / 12.0 + 1 / 24.0
            la += (ord(g[5]) - 65) / 24.0 + 1 / 48.0
        else:
            lo += 1.0; la += 0.5
        OBLAT = la * DEG; OBLON = lo * DEG
    for i, nm in enumerate(["INC", "ECC", "RAAN", "ARGP", "MA", "MM"]):
        EL[i] = ask(nm, EL[i])
    loadsat()
    now = jd(NW[0], NW[1], NW[2], NW[3], NW[4], 0)
    toff = 0
    while True:
        draw(now, toff)
        if getkey is not None:
            k = getkey()
            if k in (27, 42):
                toff += 1
            elif k in (38, 41):
                toff -= 1
            elif k == 79:
                toff += 10
            elif k == 47:
                break
        else:
            s = input("[+]step [-]back [F]ast [Q]uit: ").strip().upper()
            if s == "Q":
                break
            elif s == "-":
                toff -= 1
            elif s == "F":
                toff += 10
            else:
                toff += 1


main()
