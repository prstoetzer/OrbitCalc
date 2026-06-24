# satfreq.py - frequency & mode reference card, Casio fx-9750GIII Python.
# Snapshot 2026-06; verify against current AMSAT list before a pass.
# MicroPython 1.9.4 safe dialect.

NM = ["AO-7-A", "AO-7-B", "AO-27", "AO-91", "SO-50", "ISS-FM",
      "ISS-AP", "FO-29", "RS-44", "PO-101", "TEVEL", "QO-100"]
UP = [145.850, 432.125, 145.850, 435.250, 145.850, 145.990,
      145.825, 145.900, 145.965, 437.500, 145.970, 2400.250]
DN = [29.400, 145.975, 436.795, 145.960, 436.795, 437.800,
      145.825, 435.800, 435.640, 145.900, 436.400, 10489.750]
MD = ["SSB", "SSB", "FM", "FM", "FM", "FM",
      "APRS", "SSB", "SSB", "FM", "FM", "SSB"]
INV = [0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1]
TN = ["", "", "", "67.0", "67.0", "67.0", "", "", "", "141.3", "67.0", ""]


def show(i):
    print(NM[i])
    print(" Up " + str(UP[i]))
    print(" Dn " + str(DN[i]))
    iv = "non-inv"
    if INV[i] == 1:
        iv = "invert"
    print(" " + MD[i] + " " + iv)
    if TN[i] != "":
        print(" Tone " + TN[i])


def main():
    print("SatFreq (fx-9750GIII)")
    print("snapshot 2026-06; verify!")
    while True:
        q = input("name/L/Q: ").strip().upper()
        if q == "":
            continue
        if q == "Q":
            return
        if q == "L":
            for i in range(len(NM)):
                print(" " + NM[i])
        else:
            hit = 0
            for i in range(len(NM)):
                if q in NM[i].upper():
                    show(i)
                    hit = 1
            if hit == 0:
                print("No match. L=list")


main()
