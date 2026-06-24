# FreqPlan - Doppler tuning schedule for a pass. MicroPython / CPython.
# Prints the dial frequencies to set across a pass for a satellite's
# downlink (and uplink, with inverting-transponder sense handled), so you
# have a printed tuning "cheat sheet". Reuses the pointing.py propagator.
#
# Doppler: range-rate by 1-second finite difference; observed downlink
# f_obs = f*(1 - rdot/c). For an INVERTING linear transponder the uplink
# you transmit must be PRE-corrected with the opposite sense so the signal
# lands on the same transponder slot.

import math
try:
    import pointing as P
except ImportError:
    P = None

C = 299792.458   # km/s
RAD = 180.0 / math.pi


def range_rate(sat, j, la, lo):
    dt = 1.0 / 86400.0
    _, _, r0 = sat.look(j - dt, la, lo)
    _, _, r1 = sat.look(j + dt, la, lo)
    return (r1 - r0) / 2.0


def ask(p, d):
    try:
        s = input("%s [%s]: " % (p, d)).strip()
    except EOFError:
        return d
    if s == "":
        return d
    try:
        return float(s) if ("." in s or "e" in s.lower() or "-" in s) else int(s)
    except ValueError:
        return d


def main():
    if P is None:
        print("Needs pointing.py alongside this file.")
        return
    print("FreqPlan - Doppler tuning schedule")
    g = input("Grid [FM18LV]: ").strip() or "FM18LV"
    la, lo = P.maiden(g)
    inc = ask("INC", 101.9899)
    ecc = ask("ECC", 0.0012609)
    raan = ask("RAAN", 184.6033)
    argp = ask("ARGP", 124.3014)
    ma = ask("MA", 247.3322)
    mm = ask("MM", 12.53698149)
    ey = ask("Ep Yr", 2026)
    emo = ask("Ep Mo", 6)
    ed = ask("Ep Dy", 20)
    eh = ask("Ep Hr", 7)
    emi = ask("Ep Mi", 46)
    es = ask("Ep Sec", 20.6)
    ny = ask("Now Yr", 2026)
    nmo = ask("Now Mo", 6)
    nd = ask("Now Dy", 22)
    nh = ask("Now Hr", 0)
    nmi = ask("Now Mi", 0)
    fdn = ask("Downlink MHz", 145.95)
    fup = ask("Uplink MHz", 435.10)
    invert = ask("Inverting transp? 1/0", 1)
    step = ask("Step seconds", 60)
    sat = P.Sat(inc, ecc, raan, argp, ma, mm, P.jd(ey, emo, ed, eh, emi, es))
    now = P.jd(ny, nmo, nd, nh, nmi, 0)
    pr = P.find_pass(sat, now, la, lo)
    if pr is None:
        print("No pass within 14 days.")
        return
    aos, tca, los, mel = pr
    mo, d, h, mi = P.cal(aos)
    print("")
    print("DOPPLER PLAN  %02d/%02d  MaxEl %.0f" % (d, mo, mel * RAD))
    print("UTC     DnDial   UpDial   ShiftHz")
    t = aos
    while t <= los + 1e-9:
        rr = range_rate(sat, t, la, lo)
        dshift = -fdn * 1e6 * rr / C
        # downlink dial = where the signal appears
        dn_dial = fdn + dshift / 1e6
        # uplink correction: invert sense for inverting transponders
        ushift = -fup * 1e6 * rr / C
        if invert:
            up_dial = fup - ushift / 1e6
        else:
            up_dial = fup + ushift / 1e6
        _, _, hh, mm2 = P.cal(t)
        print("%02d:%02d  %8.4f %8.4f %+6.0f" %
              (hh, mm2, dn_dial, up_dial, dshift))
        t += step / 86400.0


if __name__ == "__main__":
    main()
