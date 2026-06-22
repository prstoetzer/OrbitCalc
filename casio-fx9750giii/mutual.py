# mutual.py - Co-visibility window finder for the Casio fx-9750GIII
# Python mode. Lists the next windows when BOTH your QTH and a remote
# station can see the satellite at once, with duration and the peak
# elevation at each end. Text output (no graphics needed).
import math

PI = math.pi
TWOPI = 2 * PI
DEG = PI / 180.0
RAD = 180.0 / PI
MU = 398600.4418
ERAD = 6378.137
J2 = 1.08262668e-3

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


def ecef(j):
    dt = (j - WJ) * 86400.0
    m = WM + WN * dt; ra = WO + WRD * dt; ap = WG + WPD * dt
    m = m - TWOPI * int(m / TWOPI)
    ee = kepler(m, WE)
    xo = WA * (math.cos(ee) - WE); yo = WA * math.sqrt(1 - WE * WE) * math.sin(ee)
    u = math.atan2(yo, xo) + ap; r = math.sqrt(xo * xo + yo * yo)
    co = math.cos(ra); so = math.sin(ra); cu = math.cos(u); su = math.sin(u)
    ci = math.cos(WI); si = math.sin(WI)
    x = r * (co * cu - so * su * ci); y = r * (so * cu + co * su * ci); z = r * (su * si)
    g = gmst(j); cg = math.cos(g); sg = math.sin(g)
    return cg * x + sg * y, -sg * x + cg * y, z


def elev(j, la, lo):
    xe, ye, ze = ecef(j)
    cl = math.cos(la); sl = math.sin(la); col = math.cos(lo); sol = math.sin(lo)
    ox = ERAD * cl * col; oy = ERAD * cl * sol; oz = ERAD * sl
    rx = xe - ox; ry = ye - oy; rz = ze - oz
    zz = cl * col * rx + cl * sol * ry + sl * rz
    rng = math.sqrt(rx * rx + ry * ry + rz * rz)
    return math.asin(max(-1, min(1, zz / rng)))


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


def grid_ll(g):
    g = g.upper()
    lo = (ord(g[0]) - 65) * 20 - 180
    la = (ord(g[1]) - 65) * 10 - 90
    lo += (ord(g[2]) - 48) * 2
    la += (ord(g[3]) - 48)
    if len(g) >= 6:
        lo += (ord(g[4]) - 65) / 12.0 + 1 / 24.0
        la += (ord(g[5]) - 65) / 24.0 + 1 / 48.0
    else:
        lo += 1.0; la += 0.5
    return la * DEG, lo * DEG


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
    print("MUTUAL WINDOWS (fx-9750GIII)")
    g1 = input("Your grid [FM18LV]: ").strip() or "FM18LV"
    g2 = input("Remote grid [CM87XX]: ").strip() or "CM87XX"
    la1, lo1 = grid_ll(g1)
    la2, lo2 = grid_ll(g2)
    for i, nm in enumerate(["INC", "ECC", "RAAN", "ARGP", "MA", "MM"]):
        EL[i] = ask(nm, EL[i])
    minel = ask("Min elev deg", 0) * DEG
    loadsat()
    now = jd(NW[0], NW[1], NW[2], NW[3], NW[4], 0)
    stp = 30 / 86400.0
    j = now; end = now + 4
    inwin = 0; nwin = 0
    pk1 = pk2 = -9
    aos = 0
    print(g1.upper() + " <-> " + g2.upper())
    print("DATE  WINDOW       pkA pkB Dur")
    while j < end and nwin < 10:
        e1 = elev(j, la1, lo1)
        e2 = elev(j, la2, lo2)
        both = (e1 >= minel and e2 >= minel)
        if both and not inwin:
            aos = j; inwin = 1; pk1 = -9; pk2 = -9
        if inwin:
            if e1 > pk1:
                pk1 = e1
            if e2 > pk2:
                pk2 = e2
            if not both:
                mo, d, h, mi = cal(aos)
                _, _, h2, m2 = cal(j)
                print("%02d/%02d %02d:%02d-%02d:%02d %3d %3d %dm" % (
                    d, mo, h, mi, h2, m2, int(pk1 * RAD), int(pk2 * RAD),
                    round((j - aos) * 1440)))
                inwin = 0; nwin += 1
        j += stp
    if nwin == 0:
        print("No mutual windows in 4 days.")


main()
