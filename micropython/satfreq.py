# SatFreq - amateur-satellite frequency & mode reference card.
# MicroPython / CPython. A quick lookup of uplink/downlink frequencies,
# mode, transponder inversion, and access tone for the common birds.
# Pairs with freqplan.py (which asks you to type frequencies).
#
# DATA IS A SNAPSHOT - satellites come and go and frequencies are
# occasionally adjusted. Verify against the current AMSAT frequency
# list before an important pass. Edit the CATALOG below to taste.
# Last reviewed: 2026-06.

# Each entry: (name, uplink_MHz, downlink_MHz, mode, inverting, tone, notes)
#   mode:      "FM", "SSB/CW" (linear), "APRS", "SSTV", "BEACON"
#   inverting: 1 if a linear inverting transponder (uplink tunes opposite),
#              0 for FM / non-inverting
#   tone:      CTCSS Hz for FM access, or "" if none / N/A
CATALOG = [
    ("AO-7-A",   145.850, 29.400,  "SSB/CW", 0, "", "Mode A, non-inv, sunlight only"),
    ("AO-7-B",   432.125, 145.975, "SSB/CW", 1, "", "Mode B, inverting, sunlight only"),
    ("AO-27",    145.850, 436.795, "FM",     0, "", "FM, schedule-gated"),
    ("AO-91",    435.250, 145.960, "FM",     0, "67.0", "FM, Fox-1; 67Hz tone"),
    ("SO-50",    145.850, 436.795, "FM",     0, "67.0", "67Hz; 74.4Hz arms 10-min timer"),
    ("ISS-FM",   145.990, 437.800, "FM",     0, "67.0", "Cross-band FM repeater"),
    ("ISS-APRS", 145.825, 145.825, "APRS",   0, "", "APRS digipeater (simplex)"),
    ("FO-29",    145.900, 435.800, "SSB/CW", 1, "", "Linear inverting, schedule-gated"),
    ("RS-44",    145.965, 435.640, "SSB/CW", 1, "", "Linear inverting; wide passband"),
    ("PO-101",   437.500, 145.900, "FM",     0, "141.3", "Diwata-2 FM, schedule-gated"),
    ("TEVEL-FM", 145.970, 436.400, "FM",     0, "67.0", "TEVEL CubeSats (per-sat varies)"),
    ("QO-100",   2400.250, 10489.750, "SSB/CW", 1, "", "GEO NB transponder (Es'hail-2)"),
]


def show(rec):
    name, up, dn, mode, inv, tone, notes = rec
    print(name)
    print("  Up   : %.3f MHz" % up)
    print("  Down : %.3f MHz" % dn)
    inv_s = "inverting" if inv else "non-inv"
    print("  Mode : %s (%s)" % (mode, inv_s))
    if tone:
        print("  Tone : %s Hz" % tone)
    if notes:
        print("  Note : %s" % notes)


def main():
    print("SatFreq - frequency/mode reference")
    print("(snapshot 2026-06; verify before a pass)")
    print("Enter a name (or part), L=list, Q=quit")
    while True:
        try:
            q = input("> ").strip()
        except EOFError:
            return
        if q == "":
            continue
        ql = q.lower()
        if ql in ("q", "quit", "exit"):
            return
        if ql in ("l", "list"):
            for rec in CATALOG:
                print("  " + rec[0])
            continue
        hits = [r for r in CATALOG if ql in r[0].lower()]
        if not hits:
            print("No match. L lists all.")
            continue
        for rec in hits:
            show(rec)


if __name__ == "__main__":
    main()
