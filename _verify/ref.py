# OrbitCalc - MicroPython, no external dependencies
# Computes next-10-passes and 10-day reference-orbit (EQX) tables
# from AMSAT GP/OMM mean orbital elements.
#
# Input elements correspond to fields in the AMSAT daily-bulletin.json:
#   INCLINATION (deg), ECCENTRICITY, RA_OF_ASC_NODE (deg),
#   ARG_OF_PERICENTER (deg), MEAN_ANOMALY (deg), MEAN_MOTION (rev/day),
#   EPOCH (UTC).
#
# Method: secular J2 propagation of mean elements + Kepler solve.
# Accuracy is "Oscarlocator class" - good for amateur planning, not
# a substitute for full SGP4.

import math

PI = math.pi
TWOPI = 2.0 * PI
DEG = PI / 180.0
RAD = 180.0 / PI
MU = 398600.4418          # km^3/s^2
RE = 6378.137             # km
J2 = 1.08262668e-3
WE = 7.2921150e-5         # earth rotation rad/s (sidereal)

def jd_from_ymdhms(y, mo, d, h, mi, s):
    if mo <= 2:
        y -= 1; mo += 12
    A = y // 100
    B = 2 - A + A // 4
    jd = int(365.25 * (y + 4716)) + int(30.6001 * (mo + 1)) + d + B - 1524.5
    jd += (h + mi / 60.0 + s / 3600.0) / 24.0
    return jd

def gmst_rad(jd):
    T = (jd - 2451545.0) / 36525.0
    g = 280.46061837 + 360.98564736629 * (jd - 2451545.0) \
        + 0.000387933 * T * T - T * T * T / 38710000.0
    g = math.fmod(g, 360.0)
    if g < 0: g += 360.0
    return g * DEG

def parse_epoch(s):
    # "2026-06-20T07:46:20.595936"
    datep, timep = s.split("T")
    y, mo, d = [int(x) for x in datep.split("-")]
    hh, mm, ss = timep.split(":")
    return jd_from_ymdhms(y, mo, d, int(hh), int(mm), float(ss))

def kepler(M, e):
    E = M
    for _ in range(50):
        dE = (E - e * math.sin(E) - M) / (1 - e * math.cos(E))
        E -= dE
        if abs(dE) < 1e-12: break
    return E

class Sat:
    def __init__(self, inc, ecc, raan, argp, ma, mm_revday, epoch_jd):
        self.i = inc * DEG
        self.e = ecc
        self.raan0 = raan * DEG
        self.argp0 = argp * DEG
        self.M0 = ma * DEG
        self.n0 = mm_revday * TWOPI / 86400.0   # rad/s
        self.epoch = epoch_jd
        self.a = (MU / (self.n0 * self.n0)) ** (1.0 / 3.0)
        p = self.a * (1 - self.e * self.e)
        f = 1.5 * J2 * (RE / p) ** 2 * self.n0
        ci = math.cos(self.i)
        si = math.sin(self.i)
        self.raandot = -f * ci
        self.argpdot = f * (2.0 - 2.5 * si * si)
        self.mdot = self.n0  # mean motion (secular Mdot ~ n0)

    def eci(self, jd):
        dt = (jd - self.epoch) * 86400.0
        M = self.M0 + self.mdot * dt
        raan = self.raan0 + self.raandot * dt
        argp = self.argp0 + self.argpdot * dt
        E = kepler(math.fmod(M, TWOPI), self.e)
        xo = self.a * (math.cos(E) - self.e)
        yo = self.a * math.sqrt(1 - self.e * self.e) * math.sin(E)
        u = math.atan2(yo, xo) + argp
        r = math.sqrt(xo * xo + yo * yo)
        co = math.cos(raan); so = math.sin(raan)
        cu = math.cos(u); su = math.sin(u)
        ci = math.cos(self.i); si = math.sin(self.i)
        x = r * (co * cu - so * su * ci)
        y = r * (so * cu + co * su * ci)
        z = r * (su * si)
        return x, y, z

def ecef(x, y, z, jd):
    g = gmst_rad(jd)
    cg = math.cos(g); sg = math.sin(g)
    xe = cg * x + sg * y
    ye = -sg * x + cg * y
    return xe, ye, z

def geodetic_subpoint(xe, ye, ze):
    lon = math.atan2(ye, xe)
    lat = math.atan2(ze, math.sqrt(xe * xe + ye * ye))
    return lat, lon

def look_angles(xe, ye, ze, obslat, obslon, obsalt=0.0):
    # observer ECEF (spherical earth)
    r = RE + obsalt
    clat = math.cos(obslat); slat = math.sin(obslat)
    clon = math.cos(obslon); slon = math.sin(obslon)
    ox = r * clat * clon; oy = r * clat * slon; oz = r * slat
    rx = xe - ox; ry = ye - oy; rz = ze - oz
    # to topocentric SEZ
    s = slat * clon * rx + slat * slon * ry - clat * rz
    e = -slon * rx + clon * ry
    zz = clat * clon * rx + clat * slon * ry + slat * rz
    rng = math.sqrt(rx * rx + ry * ry + rz * rz)
    el = math.asin(zz / rng)
    az = math.atan2(e, -s)
    if az < 0: az += TWOPI
    return el, az, rng

def maiden_to_latlon(g):
    g = g.strip().upper()
    lon = (ord(g[0]) - 65) * 20 - 180
    lat = (ord(g[1]) - 65) * 10 - 90
    lon += (ord(g[2]) - 48) * 2
    lat += (ord(g[3]) - 48) * 1
    if len(g) >= 6:
        lon += (ord(g[4]) - 65) * (2.0 / 24.0)
        lat += (ord(g[5]) - 65) * (1.0 / 24.0)
        lon += 1.0 / 24.0
        lat += 0.5 / 24.0
    else:
        lon += 1.0; lat += 0.5
    return lat * DEG, lon * DEG

def jd_to_ymdhms(jd):
    jd += 0.5
    Z = int(jd); F = jd - Z
    if Z < 2299161: A = Z
    else:
        alpha = int((Z - 1867216.25) / 36524.25)
        A = Z + 1 + alpha - alpha // 4
    B = A + 1524; C = int((B - 122.1) / 365.25)
    D = int(365.25 * C); E = int((B - D) / 30.6001)
    day = B - D - int(30.6001 * E) + F
    mo = E - 1 if E < 14 else E - 13
    y = C - 4716 if mo > 2 else C - 4715
    d = int(day); frac = day - d
    secs = frac * 86400.0
    h = int(secs // 3600); secs -= h * 3600
    mi = int(secs // 60); s = secs - mi * 60
    return y, mo, d, h, mi, s

def fmt_hms(h, mi, s):
    return "%02d:%02d:%02d" % (h, mi, int(round(s)))

def fmt_lon(lon_deg):
    # positive magnitude with E/W suffix
    if lon_deg >= 0:
        return "%7.2f E" % lon_deg
    return "%7.2f W" % (-lon_deg)

# ---------- Pass prediction ----------
def predict_passes(sat, obslat, obslon, start_jd, count=10, horizon=0.0):
    passes = []
    step = 30.0 / 86400.0    # 30 s
    fine = 1.0 / 86400.0
    jd = start_jd
    end = start_jd + 12.0    # search up to 12 days
    inpass = False
    aos = los = tca = None
    maxel = -PI
    azaos = aztca = azlos = 0.0
    prevel = None
    while jd < end and len(passes) < count:
        x, y, z = sat.eci(jd)
        xe, ye, ze = ecef(x, y, z, jd)
        el, az, rng = look_angles(xe, ye, ze, obslat, obslon)
        if el >= horizon and not inpass:
            # refine AOS backward
            a0, a1 = jd - step, jd
            for _ in range(25):
                m = 0.5 * (a0 + a1)
                xx, yy, zz = sat.eci(m); xe2, ye2, ze2 = ecef(xx, yy, zz, m)
                e2, az2, _ = look_angles(xe2, ye2, ze2, obslat, obslon)
                if e2 >= horizon: a1 = m
                else: a0 = m
            aos = a1
            xx, yy, zz = sat.eci(aos); xe2, ye2, ze2 = ecef(xx, yy, zz, aos)
            _, azaos, _ = look_angles(xe2, ye2, ze2, obslat, obslon)
            inpass = True; maxel = -PI
        if inpass:
            if el > maxel:
                maxel = el; tca = jd; aztca = az
            if el < horizon:
                a0, a1 = jd - step, jd
                for _ in range(25):
                    m = 0.5 * (a0 + a1)
                    xx, yy, zz = sat.eci(m); xe2, ye2, ze2 = ecef(xx, yy, zz, m)
                    e2, az2, _ = look_angles(xe2, ye2, ze2, obslat, obslon)
                    if e2 >= horizon: a0 = m
                    else: a1 = m
                los = a0
                xx, yy, zz = sat.eci(los); xe2, ye2, ze2 = ecef(xx, yy, zz, los)
                _, azlos, _ = look_angles(xe2, ye2, ze2, obslat, obslon)
                # refine TCA
                t0, t1 = tca - step, tca + step
                for _ in range(40):
                    ml = t0 + (t1 - t0) / 3; mr = t1 - (t1 - t0) / 3
                    xx, yy, zz = sat.eci(ml); xe2, ye2, ze2 = ecef(xx, yy, zz, ml)
                    el_l, _, _ = look_angles(xe2, ye2, ze2, obslat, obslon)
                    xx, yy, zz = sat.eci(mr); xe2, ye2, ze2 = ecef(xx, yy, zz, mr)
                    el_r, azr, _ = look_angles(xe2, ye2, ze2, obslat, obslon)
                    if el_l < el_r: t0 = ml
                    else: t1 = mr
                tca = 0.5 * (t0 + t1)
                xx, yy, zz = sat.eci(tca); xe2, ye2, ze2 = ecef(xx, yy, zz, tca)
                maxel, aztca, _ = look_angles(xe2, ye2, ze2, obslat, obslon)
                passes.append((aos, los, tca, maxel, azaos, aztca, azlos))
                inpass = False
        jd += step
    return passes

# ---------- Reference orbit (EQX) ----------
def find_eqx(sat, day_start_jd, ascending=True):
    # find first equator crossing of given node type within the UTC day
    step = 60.0 / 86400.0
    jd = day_start_jd
    end = day_start_jd + 1.0
    prevlat = None
    while jd < end:
        x, y, z = sat.eci(jd)
        xe, ye, ze = ecef(x, y, z, jd)
        lat, lon = geodetic_subpoint(xe, ye, ze)
        if prevlat is not None:
            crossing = prevlat < 0 <= lat if ascending else prevlat > 0 >= lat
            if crossing:
                a0, a1 = jd - step, jd
                for _ in range(40):
                    m = 0.5 * (a0 + a1)
                    xx, yy, zz = sat.eci(m); xe2, ye2, ze2 = ecef(xx, yy, zz, m)
                    la, lo = geodetic_subpoint(xe2, ye2, ze2)
                    if (la >= 0) == ascending: a1 = m
                    else: a0 = m
                m = 0.5 * (a0 + a1)
                xx, yy, zz = sat.eci(m); xe2, ye2, ze2 = ecef(xx, yy, zz, m)
                la, lo = geodetic_subpoint(xe2, ye2, ze2)
                return m, lo
        prevlat = lat
        jd += step
    return None, None

def reference_orbits(sat, start_jd, southern, days=10):
    rows = []
    asc = not southern
    # align to UTC midnight of start day
    y, mo, d, h, mi, s = jd_to_ymdhms(start_jd)
    day0 = jd_from_ymdhms(y, mo, d, 0, 0, 0)
    for k in range(days):
        ds = day0 + k
        jd, lon = find_eqx(sat, ds, asc)
        if jd is not None:
            rows.append((jd, lon))
    return rows

# ---------- I/O ----------
def ask_elements():
    print("Enter orbital elements (from AMSAT bulletin):")
    inc = float(input("  INCLINATION (deg): "))
    ecc = float(input("  ECCENTRICITY: "))
    raan = float(input("  RA_OF_ASC_NODE (deg): "))
    argp = float(input("  ARG_OF_PERICENTER (deg): "))
    ma = float(input("  MEAN_ANOMALY (deg): "))
    mm = float(input("  MEAN_MOTION (rev/day): "))
    ep = input("  EPOCH (YYYY-MM-DDTHH:MM:SS): ").strip()
    return Sat(inc, ecc, raan, argp, ma, mm, parse_epoch(ep))

def ask_location():
    m = input("Location - Maidenhead grid? (y/n): ").strip().lower()
    if m == "y":
        g = input("  Grid: ").strip()
        return maiden_to_latlon(g)
    lat = float(input("  Latitude (deg, + N): "))
    lon = float(input("  Longitude (deg, + E): "))
    return lat * DEG, lon * DEG

def ask_now():
    print("Current UTC date/time:")
    y = int(input("  Year: ")); mo = int(input("  Month: ")); d = int(input("  Day: "))
    h = int(input("  Hour: ")); mi = int(input("  Min: ")); s = float(input("  Sec: "))
    return jd_from_ymdhms(y, mo, d, h, mi, s)

def main():
    print("=== OrbitCalc ===")
    sat = ask_elements()
    now = ask_now()
    print("1) Next 10 passes")
    print("2) 10-day reference orbit (EQX) table")
    ch = input("Choose 1 or 2: ").strip()
    if ch == "1":
        obslat, obslon = ask_location()
        passes = predict_passes(sat, obslat, obslon, now, 10)
        print()
        print("DATE       AOS      LOS      MaxEl  AzAOS AzTCA AzLOS")
        for (aos, los, tca, mel, aa, at, al) in passes:
            y, mo, d, h, mi, s = jd_to_ymdhms(aos)
            _, _, _, h2, mi2, s2 = jd_to_ymdhms(los)
            print("%04d-%02d-%02d %s %s %5.1f  %5.1f %5.1f %5.1f" % (
                y, mo, d, fmt_hms(h, mi, s), fmt_hms(h2, mi2, s2),
                mel * RAD, aa * RAD, at * RAD, al * RAD))
    else:
        obslat, obslon = ask_location()
        southern = obslat < 0
        rows = reference_orbits(sat, now, southern, 10)
        node = "DESCENDING" if southern else "ASCENDING"
        print("\nReference orbits - first %s node EQX each UTC day" % node)
        print("DATE       UTC-TIME   EQX-LON")
        for (jd, lon) in rows:
            y, mo, d, h, mi, s = jd_to_ymdhms(jd)
            print("%04d-%02d-%02d %s  %s" % (
                y, mo, d, fmt_hms(h, mi, s), fmt_lon(lon * RAD)))

if __name__ == "__main__":
    main()
