# pointing.py - Az/El step table for the next pass, Casio fx-9750GIII
# Python mode. Hand-track a rotator or aim a beam. Self-contained
# secular-J2 propagator. MicroPython 1.9.4 safe dialect.
import math

PI = math.pi
TWOPI = 2.0 * PI
DEG = PI / 180.0
RAD = 180.0 / PI
MU = 398600.4418
RE = 6378.137
J2 = 0.00108262668

EL = [101.9899, 0.0012609, 184.6033, 124.3014, 247.3322, 12.53698149]
EP = [2026, 6, 20, 7, 46, 20.6]
NW = [2026, 6, 22, 0, 0]
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
        g = g + 360.0
    return g * DEG


def kepler(m, e):
    x = m
    for _ in range(40):
        dx = (x - e * math.sin(x) - m) / (1 - e * math.cos(x))
        x = x - dx
        if abs(dx) < 0.00000000001:
            break
    return x


def loadsat():
    global WI, WE, WO, WG, WM, WN, WJ, WA, WRD, WPD
    WI = EL[0] * DEG
    WE = EL[1]
    WO = EL[2] * DEG
    WG = EL[3] * DEG
    WM = EL[4] * DEG
    WN = EL[5] * TWOPI / 86400.0
    WJ = jd(EP[0], EP[1], EP[2], EP[3], EP[4], EP[5])
    WA = (MU / (WN * WN)) ** (1.0 / 3.0)
    p = WA * (1 - WE * WE)
    f = 1.5 * J2 * (RE / p) ** 2 * WN
    WRD = -f * math.cos(WI)
    WPD = f * (2 - 2.5 * math.sin(WI) ** 2)


def look(j, la, lo):
    dt = (j - WJ) * 86400.0
    m = WM + WN * dt
    ra = WO + WRD * dt
    ap = WG + WPD * dt
    m = m - TWOPI * int(m / TWOPI)
    ee = kepler(m, WE)
    xo = WA * (math.cos(ee) - WE)
    yo = WA * math.sqrt(1 - WE * WE) * math.sin(ee)
    u = math.atan2(yo, xo) + ap
    r = math.sqrt(xo * xo + yo * yo)
    co = math.cos(ra)
    so = math.sin(ra)
    cu = math.cos(u)
    su = math.sin(u)
    ci = math.cos(WI)
    si = math.sin(WI)
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
        v = 1.0
    if v < -1:
        v = -1.0
    el = math.asin(v)
    az = math.atan2(eth, -sth)
    if az < 0:
        az = az + TWOPI
    return el, az, rng


def cal(j):
    j = j + 0.5
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
    sec = sec - h * 3600
    mi = int(sec / 60)
    return mo, d, h, mi


def find_pass(now, la, lo):
    stp = 30.0 / 86400.0
    j = now
    end = now + 14.0
    el, az, rng = look(j, la, lo)
    if el >= 0:
        aos = j
    else:
        aos = None
        while j < end:
            el, az, rng = look(j, la, lo)
            if el >= 0:
                a0 = j - stp
                a1 = j
                for _ in range(25):
                    m = (a0 + a1) / 2
                    e2, z2, r2 = look(m, la, lo)
                    if e2 >= 0:
                        a1 = m
                    else:
                        a0 = m
                aos = a1
                break
            j = j + stp
        if aos is None:
            return None
    j = aos + stp
    while True:
        el, az, rng = look(j, la, lo)
        j = j + stp
        if el < 0 or j > aos + 0.02:
            break
    los = j
    t0 = aos
    t1 = los
    for _ in range(40):
        ml = t0 + (t1 - t0) / 3
        mr = t1 - (t1 - t0) / 3
        e1, z1, r1 = look(ml, la, lo)
        e3, z3, r3 = look(mr, la, lo)
        if e1 < e3:
            t0 = ml
        else:
            t1 = mr
    tca = (t0 + t1) / 2
    mel, maz, mr = look(tca, la, lo)
    return aos, tca, los, mel


def maiden(g):
    g = g.strip().upper()
    lo = (ord(g[0]) - 65) * 20 - 180
    la = (ord(g[1]) - 65) * 10 - 90
    lo = lo + (ord(g[2]) - 48) * 2
    la = la + (ord(g[3]) - 48)
    if len(g) >= 6:
        lo = lo + (ord(g[4]) - 65) / 12.0 + 1.0 / 24.0
        la = la + (ord(g[5]) - 65) / 24.0 + 1.0 / 48.0
    else:
        lo = lo + 1.0
        la = la + 0.5
    return la * DEG, lo * DEG


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
    print("PassCal (fx-9750GIII)")
    g = input("Grid [FM18LV]: ").strip() or "FM18LV"
    la, lo = maiden(g)
    nm = ["INC", "ECC", "RAAN", "ARGP", "MA", "MM"]
    for i in range(6):
        EL[i] = ask(nm[i], EL[i])
    print("Epoch UTC:")
    EP[0] = ask("Ep Yr", EP[0])
    EP[1] = ask("Ep Mo", EP[1])
    EP[2] = ask("Ep Dy", EP[2])
    EP[3] = ask("Ep Hr", EP[3])
    EP[4] = ask("Ep Mi", EP[4])
    EP[5] = ask("Ep Sec", EP[5])
    print("Now UTC:")
    NW[0] = ask("Now Yr", NW[0])
    NW[1] = ask("Now Mo", NW[1])
    NW[2] = ask("Now Dy", NW[2])
    NW[3] = ask("Now Hr", NW[3])
    NW[4] = ask("Now Mi", NW[4])
    days = ask("Days ahead", 3)
    minel = ask("Min max-El", 20)
    loadsat()
    now = jd(NW[0], NW[1], NW[2], NW[3], NW[4], 0)
    end = now + days
    print("Passes >=" + str(minel) + " over " + str(days) + "d")
    print("Date  AOS   LOS   El Az")
    t = now
    cnt = 0
    guard = 0
    while t < end:
        guard = guard + 1
        if guard > 400:
            break
        pr = find_pass(t, la, lo)
        if pr is None:
            break
        aos = pr[0]
        tca = pr[1]
        los = pr[2]
        mel = pr[3]
        if aos >= end:
            break
        if mel * RAD >= minel:
            mo, d, h, mi = cal(aos)
            z, z2, h2, m2 = cal(los)
            el, az, rng = look(tca, la, lo)
            cnt = cnt + 1
            print("%02d/%02d %02d:%02d %02d:%02d %2.0f %3.0f" % (d, mo, h, mi, h2, m2, mel * RAD, az * RAD))
        t = los + 60.0 / 86400.0
    if cnt == 0:
        print("(none)")


main()
