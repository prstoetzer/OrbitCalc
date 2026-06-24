# GridUtil - Maidenhead grid <-> lat/lon, plus bearing & distance
# MicroPython / CPython, no dependencies. A standalone ham utility.

import math
PI = math.pi
DEG = PI / 180.0
RAD = 180.0 / PI
RE = 6371.0    # mean Earth radius, km (great-circle distance)


def grid_to_ll(g):
    g = g.strip().upper()
    lon = (ord(g[0]) - 65) * 20 - 180
    lat = (ord(g[1]) - 65) * 10 - 90
    lon += (ord(g[2]) - 48) * 2
    lat += (ord(g[3]) - 48)
    if len(g) >= 6:
        lon += (ord(g[4]) - 65) / 12.0 + 1.0 / 24.0
        lat += (ord(g[5]) - 65) / 24.0 + 1.0 / 48.0
    else:
        lon += 1.0
        lat += 0.5
    return lat, lon


def ll_to_grid(lat, lon):
    lon += 180.0
    lat += 90.0
    A = chr(65 + int(lon // 20))
    B = chr(65 + int(lat // 10))
    c = int((lon % 20) // 2)
    d = int(lat % 10)
    e = chr(97 + int(((lon % 2) * 60) // 5))
    f = chr(97 + int(((lat % 1) * 60) // 2.5))
    return "%c%c%d%d%c%c" % (A, B, c, d, e, f)


def bearing_distance(lat1, lon1, lat2, lon2):
    la1 = lat1 * DEG
    lo1 = lon1 * DEG
    la2 = lat2 * DEG
    lo2 = lon2 * DEG
    dlon = lo2 - lo1
    y = math.sin(dlon) * math.cos(la2)
    x = math.cos(la1) * math.sin(la2) - math.sin(la1) * math.cos(la2) * math.cos(dlon)
    brg = (math.atan2(y, x) * RAD) % 360.0
    cd = math.sin(la1) * math.sin(la2) + math.cos(la1) * math.cos(la2) * math.cos(dlon)
    if cd > 1:
        cd = 1
    if cd < -1:
        cd = -1
    dist = math.acos(cd) * RE
    return brg, dist


def ask(prompt, default=""):
    try:
        s = input("%s [%s]: " % (prompt, default)).strip()
    except EOFError:
        return default
    return s if s else default


def main():
    print("GridUtil")
    print("1 = grid -> lat/lon")
    print("2 = lat/lon -> grid")
    print("3 = bearing & distance between two grids")
    mode = ask("Choose 1/2/3", "1")
    if mode == "1":
        g = ask("Grid", "FM18LV")
        la, lo = grid_to_ll(g)
        print("%s = %.4f N, %.4f E" % (g.upper(), la, lo))
    elif mode == "2":
        la = float(ask("Latitude (+N)", "38.9"))
        lo = float(ask("Longitude (+E)", "-77.0"))
        print("Grid = %s" % ll_to_grid(la, lo))
    else:
        g1 = ask("From grid", "FM18LV")
        g2 = ask("To grid", "CM87XX")
        la1, lo1 = grid_to_ll(g1)
        la2, lo2 = grid_to_ll(g2)
        brg, dist = bearing_distance(la1, lo1, la2, lo2)
        print("%s -> %s" % (g1.upper(), g2.upper()))
        print("Bearing : %.0f deg" % brg)
        print("Distance: %.0f km  (%.0f mi)" % (dist, dist * 0.621371))


if __name__ == "__main__":
    main()
