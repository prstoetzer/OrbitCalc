# OrbData - orbital data summary from GP/OMM mean elements
# MicroPython / CPython, no dependencies. Reports the quantities you can
# derive from a single element set: size/shape of the orbit, apogee and
# perigee, period, velocities, J2 precession rates, ground-track repeat,
# and footprint size.
#
# Method: closed-form from the mean elements (no propagation needed),
# using the same constants as the rest of this repo.

import math

PI = math.pi
TWOPI = 2.0 * PI
DEG = PI / 180.0
RAD = 180.0 / PI
MU = 398600.4418          # km^3/s^2  (Earth GM)
RE = 6378.137             # km        (Earth equatorial radius)
J2 = 1.08262668e-3


def orbital_data(inc, ecc, mm_revday):
    """Return a dict of derived orbital quantities."""
    n = mm_revday * TWOPI / 86400.0        # mean motion, rad/s
    a = (MU / (n * n)) ** (1.0 / 3.0)       # semi-major axis, km
    i = inc * DEG
    rp = a * (1.0 - ecc)                    # perigee radius, km
    ra = a * (1.0 + ecc)                    # apogee radius, km
    p = a * (1.0 - ecc * ecc)               # semi-latus rectum
    f = 1.5 * J2 * (RE / p) ** 2 * n        # J2 secular factor
    raandot = -f * math.cos(i) * RAD * 86400.0   # deg/day
    argpdot = f * (2.0 - 2.5 * math.sin(i) ** 2) * RAD * 86400.0
    # vis-viva speeds
    v_peri = math.sqrt(MU * (2.0 / rp - 1.0 / a))
    v_apo = math.sqrt(MU * (2.0 / ra - 1.0 / a))
    v_circ = math.sqrt(MU / a)
    period = 1440.0 / mm_revday            # minutes
    mean_alt = (ra + rp) / 2.0 - RE
    # footprint: central angle from sub-point to horizon at mean altitude
    rmean = (ra + rp) / 2.0
    rho = math.acos(RE / rmean)            # rad
    # nodal (draconic) considerations -> longitude shift per orbit
    lon_shift = 360.0 / mm_revday          # deg moved west per rev (approx)
    if mm_revday > 11.25:
        kind = "LEO"
    elif mm_revday > 2.0:
        kind = "MEO"
    elif abs(mm_revday - 1.0027) < 0.05:
        kind = "GEO/GSO"
    else:
        kind = "HEO/other"
    return {
        "a": a, "ecc": ecc, "inc": inc,
        "apogee_alt": ra - RE, "perigee_alt": rp - RE,
        "apogee_r": ra, "perigee_r": rp,
        "period_min": period, "mean_alt": mean_alt,
        "v_peri": v_peri, "v_apo": v_apo, "v_circ": v_circ,
        "raandot": raandot, "argpdot": argpdot,
        "footprint_deg": rho * RAD, "footprint_km": rho * RE,
        "lon_shift": lon_shift, "kind": kind,
    }


def fmt(d):
    lines = []
    lines.append("ORBITAL DATA")
    lines.append("Class        : %s" % d["kind"])
    lines.append("Inclination  : %.4f deg" % d["inc"])
    lines.append("Eccentricity : %.6f" % d["ecc"])
    lines.append("Semi-major a : %.1f km" % d["a"])
    lines.append("Period       : %.2f min  (%.4f h)" % (d["period_min"], d["period_min"] / 60.0))
    lines.append("Apogee  alt  : %.1f km  (r=%.1f)" % (d["apogee_alt"], d["apogee_r"]))
    lines.append("Perigee alt  : %.1f km  (r=%.1f)" % (d["perigee_alt"], d["perigee_r"]))
    lines.append("Mean alt     : %.1f km" % d["mean_alt"])
    lines.append("Vel perigee  : %.4f km/s" % d["v_peri"])
    lines.append("Vel apogee   : %.4f km/s" % d["v_apo"])
    lines.append("Vel circular : %.4f km/s" % d["v_circ"])
    lines.append("Node drift   : %+.4f deg/day" % d["raandot"])
    lines.append("Perigee drift: %+.4f deg/day" % d["argpdot"])
    lines.append("Footprint    : %.1f deg  (%.0f km radius)" % (d["footprint_deg"], d["footprint_km"]))
    lines.append("Lon/orbit    : %.2f deg west" % d["lon_shift"])
    return "\n".join(lines)


def ask_float(prompt, default):
    try:
        s = input("%s [%s]: " % (prompt, default)).strip()
    except EOFError:
        return default
    if s == "":
        return default
    try:
        return float(s)
    except ValueError:
        return default


def main():
    print("OrbData - orbital data from GP elements")
    inc = ask_float("INCLINATION deg", 101.9899)
    ecc = ask_float("ECCENTRICITY", 0.0012609)
    mm = ask_float("MEAN_MOTION rev/day", 12.53698149)
    print("")
    print(fmt(orbital_data(inc, ecc, mm)))


if __name__ == "__main__":
    main()
