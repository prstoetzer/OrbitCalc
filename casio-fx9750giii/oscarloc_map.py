# OSCARLOC - Polar OSCARLOCATOR for the Casio fx-9750GIII
# Python mode (casioplot). Monochrome 128x64 screen.
#
# Single-hemisphere azimuthal-equidistant map: pole of your
# hemisphere at the centre, the EQUATOR at the rim. Shows the
# satellite's ground-track arc (computed from elements), the
# sub-satellite point at the chosen time, a range circle over
# your QTH, and a text read-out.
#
# Orbit model: secular-J2 mean-element propagation + Kepler.
# Reference geometry for planning, not precise pointing.
#
# Usage: answer the setup prompts (press EXE to accept the
# default in brackets), including a "Time offset min" value.
# The map is then drawn and stays on screen until you press
# EXIT. To step the satellite along its track, re-run with a
# different time offset; to view the other hemisphere, enter a
# grid in that hemisphere. (The stock calculator's MicroPython
# has only iostream input, so a live key-stepped loop isn't
# possible without dropping back to the text console, which
# would hide the graphics.)

from casioplot import set_pixel, draw_string, show_screen, clear_screen
import math


# ---- screen ----
W = 128
H = 64
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)

# disc geometry: leave a few rows at the bottom for text
CX = 40
CY = 30
RR = 28

PI = math.pi
TWOPI = 2 * PI
DEG = PI / 180.0
RAD = 180.0 / PI
MU = 398600.4418
ERAD = 6378.137
J2 = 0.00108262668

# ---- defaults (AO-7) ----
NHEMI = 1                 # 1 = north-centred, 0 = south
OBLAT = 38.9 * DEG
OBLON = -77.0 * DEG
SATNM = "AO-07"
EL = [101.9899, 0.0012609, 184.6033, 124.3014, 247.3322, 12.53698149]
EPY, EPMO, EPD, EPH, EPMI, EPS = 2026, 6, 20, 7, 46, 20.6
NWY, NWMO, NWD, NWH, NWMI = 2026, 6, 22, 0, 0

# ---- orbit globals (set by loadsat) ----
WI = WE = WO = WG = WM = WN = WJ = WA = WRD = WPD = 0.0
SPERIOD = 0.0


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


def atan2(y, x):
    return math.atan2(y, x)


def loadsat():
    global WI, WE, WO, WG, WM, WN, WJ, WA, WRD, WPD, SPERIOD
    WI = EL[0] * DEG
    WE = EL[1]
    WO = EL[2] * DEG
    WG = EL[3] * DEG
    WM = EL[4] * DEG
    WN = EL[5] * TWOPI / 86400.0
    WJ = jd(EPY, EPMO, EPD, EPH, EPMI, EPS)
    WA = (MU / (WN * WN)) ** (1.0 / 3.0)
    p = WA * (1 - WE * WE)
    f = 1.5 * J2 * (ERAD / p) ** 2 * WN
    ci = math.cos(WI)
    si = math.sin(WI)
    WRD = -f * ci
    WPD = f * (2 - 2.5 * si * si)
    SPERIOD = 1440.0 / EL[5]


def subpt(j):
    dt = (j - WJ) * 86400.0
    m = WM + WN * dt
    ra = WO + WRD * dt
    ap = WG + WPD * dt
    m = m - TWOPI * int(m / TWOPI)
    ee = kepler(m, WE)
    xo = WA * (math.cos(ee) - WE)
    yo = WA * math.sqrt(1 - WE * WE) * math.sin(ee)
    u = atan2(yo, xo) + ap
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
    blat = atan2(z, math.sqrt(xe * xe + ye * ye))
    blon = atan2(ye, xe)
    return blat, blon


def look(j):
    dt = (j - WJ) * 86400.0
    m = WM + WN * dt
    ra = WO + WRD * dt
    ap = WG + WPD * dt
    m = m - TWOPI * int(m / TWOPI)
    ee = kepler(m, WE)
    xo = WA * (math.cos(ee) - WE)
    yo = WA * math.sqrt(1 - WE * WE) * math.sin(ee)
    u = atan2(yo, xo) + ap
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
    v = zz / rng
    if v > 1:
        v = 1
    if v < -1:
        v = -1
    el = math.asin(v)
    az = atan2(e, -s)
    if az < 0:
        az += TWOPI
    return el, az, rng


# ---- projection: lat,lon(rad) -> (px,py,ok). rim = equator ----
def project(latr, lonr):
    if NHEMI == 1:
        rho = (PI / 2 - latr)
        theta = lonr
    else:
        rho = (PI / 2 + latr)
        theta = -lonr
    r = rho / (PI / 2)
    # East is counterclockwise when looking down on the north pole, so the
    # x term is subtracted (a +sin here mirrors the map east-west).
    px = int(CX - r * RR * math.sin(theta) + 0.5)
    py = int(CY - r * RR * math.cos(theta) + 0.5)
    ok = 1 if rho <= PI / 2 else 0
    return px, py, ok


def plot(x, y):
    if x >= 0 and x < W and y >= 0 and y < H:
        set_pixel(x, y, BLACK)


def line(x0, y0, x1, y1):
    # Bresenham (canonical, terminating form)
    dx = abs(x1 - x0)
    dy = -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    while True:
        plot(x0, y0)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def dline(x0, y0, x1, y1):
    # dotted line (range circle reads differently in mono)
    dx = abs(x1 - x0)
    dy = -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    n = 0
    while True:
        if n % 2 == 0:
            plot(x0, y0)
        n += 1
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def circle_px(cx, cy, rad):
    # midpoint circle (rim)
    x = rad
    y = 0
    err = 0
    while x >= y:
        for (px, py) in ((cx + x, cy + y), (cx + y, cy + x),
                         (cx - y, cy + x), (cx - x, cy + y),
                         (cx - x, cy - y), (cx - y, cy - x),
                         (cx + y, cy - x), (cx + x, cy - y)):
            plot(px, py)
        y += 1
        if err <= 0:
            err += 2 * y + 1
        if err > 0:
            x -= 1
            err -= 2 * x + 1


def poly_clip(pts_ok, dotted=0):
    last = None
    for (x, y, ok) in pts_ok:
        if last is not None and last[2] == 1 and ok == 1:
            if dotted:
                dline(last[0], last[1], x, y)
            else:
                line(last[0], last[1], x, y)
        last = (x, y, ok)


def find_eqx(tref):
    asc = 1 if NHEMI == 1 else 0
    stp = 60.0 / 86400.0
    prevlat = None
    j = tref - (SPERIOD + 5) / 1440.0
    while j < tref:
        la, lo = subpt(j)
        if prevlat is not None:
            cross = (asc == 1 and prevlat < 0 and la >= 0) or \
                    (asc == 0 and prevlat > 0 and la <= 0)
            if cross:
                a0 = j - stp
                a1 = j
                for _ in range(28):
                    m = (a0 + a1) / 2
                    la2, _ = subpt(m)
                    if (la2 >= 0) == (asc == 1):
                        a1 = m
                    else:
                        a0 = m
                return (a0 + a1) / 2
        prevlat = la
        j += stp
    return tref


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
    secs = (day - d) * 86400.0
    h = int(secs / 3600)
    secs -= h * 3600
    mi = int(secs / 60)
    return mo, d, h, mi


def z2(n):
    return ("0" + str(n)) if n < 10 else str(n)


def draw_frame(now, toff):
    j = now + toff / 1440.0
    clear_screen()
    # equator rim
    circle_px(CX, CY, RR)
    # graticule: 30 and 60 lat circles, sampled + clipped
    for k in (1, 2):
        latc = k * 30 if NHEMI == 1 else -k * 30
        pts = [project(latc * DEG, a * DEG) for a in range(0, 361, 15)]
        poly_clip(pts)
    # a couple of meridian spokes (0 and 90 deg) pole->equator
    near = 80 if NHEMI == 1 else -80
    for lon0 in (0, 90, 180, 270):
        x0, y0, _ = project(near * DEG, lon0 * DEG)
        x1, y1, _ = project(0, lon0 * DEG)
        line(x0, y0, x1, y1)
    # range circle over QTH (dotted)
    rho = 3000.0 / ERAD
    rpts = []
    for a in range(0, 361, 12):
        az = a * DEG
        dlat = math.asin(math.sin(OBLAT) * math.cos(rho) +
                         math.cos(OBLAT) * math.sin(rho) * math.cos(az))
        dlon = OBLON + atan2(math.sin(az) * math.sin(rho) * math.cos(OBLAT),
                             math.cos(rho) - math.sin(OBLAT) * math.sin(dlat))
        rpts.append(project(dlat, dlon))
    poly_clip(rpts, dotted=1)
    # ground-track arc from equator crossing
    eqxj = find_eqx(j)
    n = 80
    tp = []
    for i in range(n + 1):
        jj = eqxj + (i * (SPERIOD / n)) / 1440.0
        la, lo = subpt(jj)
        tp.append(project(la, lo))
    poly_clip(tp)
    # QTH marker (small cross)
    qx, qy, qok = project(OBLAT, OBLON)
    if qok:
        plot(qx - 1, qy)
        plot(qx + 1, qy)
        plot(qx, qy - 1)
        plot(qx, qy + 1)
        plot(qx, qy)
    # satellite dot (3x3 block) if in this hemisphere
    la, lo = subpt(j)
    sx, sy, sok = project(la, lo)
    if sok:
        for ax in (-1, 0, 1):
            for ay in (-1, 0, 1):
                plot(sx + ax, sy + ay)
    # text read-out (right column + bottom rows)
    mo, d, h, mi = cal(j)
    draw_string(72, 2, z2(h) + ":" + z2(mi) + "Z", BLACK, "medium")
    el, az, rng = look(j)
    sub = "%d%s %d%s" % (abs(int(la * RAD)), "N" if la >= 0 else "S",
                         abs(int(lo * RAD)), "E" if lo >= 0 else "W")
    draw_string(72, 14, sub, BLACK, "medium")
    if el >= 0:
        draw_string(72, 26, "Az%d" % int(az * RAD), BLACK, "medium")
        draw_string(72, 38, "El%d" % int(el * RAD), BLACK, "medium")
    else:
        draw_string(72, 26, "below", BLACK, "medium")
        draw_string(72, 38, "horiz", BLACK, "medium")
    draw_string(0, 56, SATNM + " T+" + str(int(toff)) + "m", BLACK, "medium")
    show_screen()


def ask(prompt, default):
    try:
        s = input(prompt + " [" + str(default) + "]: ").strip()
    except EOFError:
        return default
    if s == "":
        return default
    try:
        return float(s) if ("." in s or "e" in s.lower()) else int(s)
    except ValueError:
        return default


def main():
    global NHEMI, OBLAT, OBLON, SATNM
    global EL, EPY, EPMO, EPD, EPH, EPMI, EPS, NWY, NWMO, NWD, NWH, NWMI
    print("OSCARLOC (fx-9750GIII)")
    print("Enter to accept defaults.")
    g = input("Grid (e.g. FM18LV): ").strip().upper()
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
    NHEMI = 1 if OBLAT >= 0 else 0
    nm = input("Sat name: ").strip()
    if nm:
        SATNM = nm.upper()
    EL[0] = ask("INC", EL[0])
    EL[1] = ask("ECC", EL[1])
    EL[2] = ask("RAAN", EL[2])
    EL[3] = ask("ARGP", EL[3])
    EL[4] = ask("MA", EL[4])
    EL[5] = ask("MM", EL[5])
    EPY = ask("Epoch Yr", EPY)
    EPMO = ask("Epoch Mo", EPMO)
    EPD = ask("Epoch Dy", EPD)
    EPH = ask("Epoch Hr", EPH)
    EPMI = ask("Epoch Mi", EPMI)
    EPS = ask("Epoch Se", EPS)
    NWY = ask("Now Yr", NWY)
    NWMO = ask("Now Mo", NWMO)
    NWD = ask("Now Dy", NWD)
    NWH = ask("Now Hr", NWH)
    NWMI = ask("Now Mi", NWMI)
    toff = ask("Time offset min", 0)
    loadsat()
    now = jd(NWY, NWMO, NWD, NWH, NWMI, 0)
    draw_frame(now, toff)
    # Graphics persist until EXIT (stock MicroPython is iostream-only;
    # re-run with a different time offset to step the satellite along
    # its track, or change the grid to flip hemisphere).


main()
