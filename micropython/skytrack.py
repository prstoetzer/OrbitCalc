# SkyTrack - ASCII polar sky chart of a pass. MicroPython / CPython.
# A text polar plot (concentric elevation rings, N/E/S/W) showing the
# pass arc with time ticks - the print companion to the graphical
# PicoCalc polar plot, for platforms without graphics. Same core.

import math
from pointing import (Sat, find_pass, maiden, cal, jd, RAD)

W = 41   # grid width  (odd)
H = 21   # grid height (odd)


def ask(p, d):
    try:
        s = input("%s [%s]: " % (p, d)).strip()
    except EOFError:
        return d
    if s == "":
        return d
    try:
        return float(s) if ("." in s or "-" in s or "e" in s.lower()) else int(s)
    except ValueError:
        return d


def main():
    print("SkyTrack - ASCII sky chart")
    g = input("Grid [FM18LV]: ").strip() or "FM18LV"
    la, lo = maiden(g)
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
    sat = Sat(inc, ecc, raan, argp, ma, mm, jd(ey, emo, ed, eh, emi, es))
    now = jd(ny, nmo, nd, nh, nmi, 0)
    pr = find_pass(sat, now, la, lo)
    if pr is None:
        print("No pass within 14 days.")
        return
    aos, tca, los, mel = pr
    cx = W // 2
    cy = H // 2
    grid = [[" "] * W for _ in range(H)]
    # draw horizon ring + 30/60 rings and compass
    for ang in range(0, 360, 2):
        a = ang * math.pi / 180.0
        for (rr_el, ch) in ((0.0, "."), (30.0, "."), (60.0, ".")):
            rad = (90.0 - rr_el) / 90.0
            x = int(round(cx + rad * (W // 2) * math.sin(a)))
            y = int(round(cy - rad * (cy) * math.cos(a)))
            if 0 <= x < W and 0 <= y < H and grid[y][x] == " ":
                grid[y][x] = ch
    grid[cy][cx] = "+"
    # plot the pass arc
    n = 60
    pts = []
    for k in range(n + 1):
        t = aos + (los - aos) * k / n
        el, az, rng = sat.look(t, la, lo)
        if el < 0:
            continue
        rad = (90.0 - el * RAD) / 90.0
        x = int(round(cx + rad * (W // 2) * math.sin(az)))
        y = int(round(cy - rad * (cy) * math.cos(az)))
        if 0 <= x < W and 0 <= y < H:
            grid[y][x] = "*"
            pts.append((k, x, y))
    # mark AOS(A), TCA(T), LOS(L)
    def mark(t, label):
        el, az, rng = sat.look(t, la, lo)
        if el < 0:
            el = 0.0
        rad = (90.0 - el * RAD) / 90.0
        x = int(round(cx + rad * (W // 2) * math.sin(az)))
        y = int(round(cy - rad * (cy) * math.cos(az)))
        if 0 <= x < W and 0 <= y < H:
            grid[y][x] = label
    mark(aos, "A")
    mark(tca, "T")
    mark(los, "L")
    # compass labels
    grid[0][cx] = "N"
    grid[H - 1][cx] = "S"
    grid[cy][W - 1] = "E"
    grid[cy][0] = "W"
    cal(aos)
    mo, d, h, mi = cal(aos)
    z, z2, h2, m2 = cal(los)
    print("")
    print("Pass %02d:%02d-%02d:%02dZ  MaxEl %.0f  (A=AOS T=TCA L=LOS)"
          % (h, mi, h2, m2, mel * RAD))
    for row in grid:
        print("".join(row))


if __name__ == "__main__":
    main()
