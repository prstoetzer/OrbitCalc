# OSCARLOCATOR helper - MicroPython, no external dependencies
# Given the EQX of one orbit, the node type, the date, the orbital
# period, and the longitude advance per orbit, produce the time and
# longitude of every equatorial crossing during that UTC day.
#
# Convention: each successive orbit the satellite crosses the equator
# one period later in time and "advance" degrees further WEST in
# longitude (positive advance = westward, the usual Oscarlocator sense).

def hms_to_min(h, m):
    return h * 60.0 + m

def wrap_lon(lon):
    while lon > 180.0: lon -= 360.0
    while lon <= -180.0: lon += 360.0
    return lon

def fmt_lon(lon):
    lon = wrap_lon(lon)
    if lon >= 0:
        return "%7.2f E" % lon
    return "%7.2f W" % (-lon)

def parse_lon(s):
    # accept "111.56 W", "-111.56", "111.56W", "111.56 E"
    s = s.strip().upper()
    sign = 1.0
    if s.endswith("W"):
        sign = -1.0; s = s[:-1]
    elif s.endswith("E"):
        s = s[:-1]
    return sign * float(s.strip())

def main():
    print("=== OSCARLOCATOR ===")
    lon0 = parse_lon(input("EQX longitude (e.g. 111.56 W or -111.56): "))
    nt = input("Node: (A)scending or (D)escending? ").strip().upper()
    y = int(input("Date Year: "))
    mo = int(input("Date Month: "))
    d = int(input("Date Day: "))
    h = int(input("EQX time hour (UTC): "))
    mi = int(input("EQX time min (UTC): "))
    period = float(input("Orbital period (min): "))
    adv = float(input("Longitude advance per orbit (deg West): "))

    node = "ASC" if nt == "A" else "DESC"
    t0 = hms_to_min(h, mi)

    # find integer k so that the first crossing time t0 - k*period is in [0,period)
    k = int(t0 // period)
    first_t = t0 - k * period
    first_lon = wrap_lon(lon0 + k * adv)   # earlier orbit was k advances East of lon0

    print()
    print("UTC day %04d-%02d-%02d   node=%s" % (y, mo, d, node))
    print("ORBIT  UTC-TIME   EQX-LON")
    t = first_t
    lon = first_lon
    n = 0
    while t < 1440.0:
        hh = int(t // 60); mm = t - hh * 60
        print("%4d   %02d:%02d:%02d   %s" % (
            n, hh, int(mm), int(round((mm - int(mm)) * 60)), fmt_lon(lon)))
        t += period
        lon = wrap_lon(lon - adv)   # forward in time -> advance westward
        n += 1

if __name__ == "__main__":
    main()
