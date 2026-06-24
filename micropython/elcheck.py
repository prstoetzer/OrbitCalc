# ElCheck - GP/OMM element-set sanity checker. MicroPython / CPython.
# Validates a freshly-typed element set and flags likely transcription
# errors BEFORE you waste a pass. Pure range/consistency checks - no
# propagation. Returns warnings; you decide.

import math
MU = 398600.4418
RE = 6378.137
TWOPI = 2.0 * math.pi


def check(inc, ecc, raan, argp, ma, mm):
    warn = []
    note = []
    # hard range checks
    if not (0.0 <= inc <= 180.0):
        warn.append("INC out of 0..180 deg")
    if not (0.0 <= ecc < 1.0):
        warn.append("ECC out of 0..1 (must be <1 for closed orbit)")
    if not (0.0 <= raan < 360.0):
        warn.append("RAAN out of 0..360 deg")
    if not (0.0 <= argp < 360.0):
        warn.append("ARGP out of 0..360 deg")
    if not (0.0 <= ma < 360.0):
        warn.append("MA out of 0..360 deg")
    if mm <= 0.0:
        warn.append("MM must be > 0 rev/day")
        return warn, note
    # mean motion sanity: derive altitude band
    n = mm * TWOPI / 86400.0
    a = (MU / (n * n)) ** (1.0 / 3.0)
    alt_p = a * (1 - ecc) - RE
    alt_a = a * (1 + ecc) - RE
    if alt_p < 0:
        warn.append("Perigee below surface (alt %.0f km) - check MM/ECC" % alt_p)
    if mm > 17.5:
        warn.append("MM %.3f very high - decaying/re-entry or typo?" % mm)
    if mm < 0.5:
        warn.append("MM %.3f very low - beyond GEO or typo?" % mm)
    # classify
    if 0.95 < mm < 1.05 and ecc < 0.01:
        note.append("Looks GEO/GSO (mm~1.00)")
    elif mm > 11.0:
        note.append("Looks LEO (alt %.0f-%.0f km)" % (alt_p, alt_a))
    elif mm > 1.5:
        note.append("Looks MEO (alt %.0f-%.0f km)" % (alt_p, alt_a))
    if ecc > 0.5:
        note.append("Highly eccentric (Molniya/HEO-like)")
    if inc > 90.0:
        note.append("Retrograde / sun-synchronous-ish (inc>90)")
    note.append("Derived: a=%.0f km, period=%.2f min" % (a, 1440.0 / mm))
    note.append("Perigee alt %.0f km, apogee alt %.0f km" % (alt_p, alt_a))
    return warn, note


def ask(p, d):
    try:
        s = input("%s [%s]: " % (p, d)).strip()
    except EOFError:
        return d
    if s == "":
        return d
    try:
        return float(s)
    except ValueError:
        return d


def main():
    print("ElCheck - element-set sanity check")
    inc = ask("INC", 101.9899)
    ecc = ask("ECC", 0.0012609)
    raan = ask("RAAN", 184.6033)
    argp = ask("ARGP", 124.3014)
    ma = ask("MA", 247.3322)
    mm = ask("MM", 12.53698149)
    warn, note = check(inc, ecc, raan, argp, ma, mm)
    print("")
    if warn:
        print("WARNINGS:")
        for w in warn:
            print("  ! " + w)
    else:
        print("No range problems found.")
    print("Notes:")
    for nt in note:
        print("  - " + nt)


if __name__ == "__main__":
    main()
