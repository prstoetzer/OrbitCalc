# doppler.py - Standalone Doppler display for the Casio fx-9750GIII
# Python mode (casioplot). Shows live uplink/downlink Doppler shift
# for one satellite from orbital elements. Planning tool - does NOT
# control a radio. Secular-J2 model + 1-second finite-difference
# range-rate.
from casioplot import set_pixel, draw_string, show_screen, clear_screen
import math

PI = math.pi
TWOPI = 2 * PI
DEG = PI / 180.0
RAD = 180.0 / PI
MU = 398600.4418
ERAD = 6378.137
J2 = 0.00108262668
CK = 299792.458  # speed of light km/s
BLACK = (0, 0, 0)

OBLAT = 38.9 * DEG
OBLON = -77.0 * DEG
EL = [101.9899, 0.0012609, 184.6033, 124.3014, 247.3322, 12.53698149]
EP = [2026, 6, 20, 7, 46, 20.6]
NW = [2026, 6, 22, 0, 0]
FDN = 145.95
FUP = 435.1
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
    f = 1.5 * J2 * (ERAD / p) ** 2 * WN
    WRD = -f * math.cos(WI)
    WPD = f * (2 - 2.5 * math.sin(WI) ** 2)


def look(j):
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
    cl = math.cos(OBLAT)
    sl = math.sin(OBLAT)
    col = math.cos(OBLON)
    sol = math.sin(OBLON)
    ox = ERAD * cl * col
    oy = ERAD * cl * sol
    oz = ERAD * sl
    rx = xe - ox
    ry = ye - oy
    rz = ze - oz
    s = sl * col * rx + sl * sol * ry - cl * rz
    e = -sol * rx + col * ry
    zz = cl * col * rx + cl * sol * ry + sl * rz
    rng = math.sqrt(rx * rx + ry * ry + rz * rz)
    v = max(-1, min(1, zz / rng))
    el = math.asin(v)
    az = math.atan2(e, -s)
    if az < 0:
        az += TWOPI
    return el, az, rng


def range_rate(j):
    dt = 1.0 / 86400.0
    _, _, r0 = look(j - dt)
    _, _, r1 = look(j + dt)
    return (r1 - r0) / 2.0


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


def line(x0, y0, x1, y1):
    dx = abs(x1 - x0)
    dy = -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    while True:
        if x0 >= 0 and x0 < 128 and y0 >= 0 and y0 < 64:
            set_pixel(x0, y0, BLACK)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def draw(now, toff):
    j = now + toff / 1440.0
    clear_screen()
    el, az, rng = look(j)
    rr = range_rate(j)
    ds = -FDN * 1000000.0 * rr / CK
    us = -FUP * 1000000.0 * rr / CK
    mo, d, h, mi = cal(j)
    draw_string(0, 0, "DOPPLER T+" + str(int(toff)), BLACK, "medium")
    draw_string(0, 10, "%02d:%02dZ El%d" % (h, mi, int(el * RAD)), BLACK, "medium")
    if el >= 0:
        draw_string(64, 10, "R%d" % int(rng), BLACK, "medium")
    draw_string(0, 22, "rr %+.2f km/s" % rr, BLACK, "medium")
    draw_string(0, 34, "DN %+5d Hz" % int(ds), BLACK, "medium")
    draw_string(0, 44, "UP %+5d Hz" % int(us), BLACK, "medium")
    # tiny doppler curve across the bottom
    y0 = 60
    mx = FDN * 1000000.0 * 6.0 / CK
    last = None
    for i in range(0, 128, 4):
        t = j + (i - 64) * 30.0 / 86400.0
        sh = -FDN * 1000000.0 * range_rate(t) / CK
        py = y0 - int(sh / mx * 3)
        if py < 56:
            py = 56
        if py > 63:
            py = 63
        if last:
            line(last[0], last[1], i, py)
        last = (i, py)
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
    global OBLAT, OBLON, FDN, FUP
    print("DOPPLER (fx-9750GIII)")
    print("Enter setup, then the graph")
    print("stays up. Press EXIT to quit,")
    print("re-run to step time.")
    g = input("Grid [FM18LV]: ").strip().upper()
    if len(g) >= 4:
        lo = (ord(g[0]) - 65) * 20 - 180
        la = (ord(g[1]) - 65) * 10 - 90
        lo += (ord(g[2]) - 48) * 2
        la += (ord(g[3]) - 48)
        if len(g) >= 6:
            lo += (ord(g[4]) - 65) / 12.0 + 1 / 24.0
            la += (ord(g[5]) - 65) / 24.0 + 1 / 48.0
        else:
            lo += 1.0
            la += 0.5
        OBLAT = la * DEG
        OBLON = lo * DEG
    _names = ["INC", "ECC", "RAAN", "ARGP", "MA", "MM"]
    for i in range(6):
        EL[i] = ask(_names[i], EL[i])
    print("Epoch UTC (from elements):")
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
    FDN = ask("Downlink MHz", FDN)
    FUP = ask("Uplink MHz", FUP)
    toff = ask("Time offset min", 0)
    loadsat()
    now = jd(NW[0], NW[1], NW[2], NW[3], NW[4], 0)
    draw(now, toff)
    # Graphics persist until the user presses EXIT (stock MicroPython
    # has iostream-only input; calling input() here would switch back
    # to the text console and hide the plot, so we simply stop).


main()
