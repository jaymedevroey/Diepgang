"""Hangar, de ruimte zelf: vloer en baairand, wanden in drie lagen, het raam en het plafond.

Plancoördinaten (layout.py). Wordt aangeroepen door zone_hangar.build().
"""

import math

from hangar_kit import (MISMATCH, beam, box, cyl, fbox, hang_fixture, hatch_on, pipe, prism, screen_ui, taped_crack,
                        vent_on)
from layout import BAY, HANGAR_TOP, TRIM, WALL, G, led, slab

FRAMES = (3.0, 7.0, 11.0, 15.0, 19.0)  # spanten in de wanden en liggers in het plafond, om de 4 m
CH_LOW = 7.95  # hier begint de schuine hoek tussen wand en plafond (1,05 m breed, 45°)
WALL_END = 21.0  # wanden van de hangar tot aan de brug
HZ = 0.4  # gevarenrand rond de baai
ST = 0.25  # stalen rand daarbuiten (met vloerlampjes)


def pick(rng, base, alt):
    r = rng.random()
    for m, p in alt:
        if r < p:
            return m
        r -= p
    return base


def sub_rect(rects, cut):
    """Rechthoeken (x0, x1, z0, z1) min één rechthoek."""
    out = []
    cx0, cx1, cz0, cz1 = cut
    for (x0, x1, z0, z1) in rects:
        if x1 <= cx0 or x0 >= cx1 or z1 <= cz0 or z0 >= cz1:
            out.append((x0, x1, z0, z1))
            continue
        if x0 < cx0:
            out.append((x0, cx0, z0, z1))
        if x1 > cx1:
            out.append((cx1, x1, z0, z1))
        ix0, ix1 = max(x0, cx0), min(x1, cx1)
        if z0 < cz0:
            out.append((ix0, ix1, z0, cz0))
        if z1 > cz1:
            out.append((ix0, ix1, cz1, z1))
    return out


def plates(b, rng, x0, x1, z0, z1, nx, nz, y=0.0, cuts=(), gap=0.035, t=0.015, worn=()):
    """Vloerplaten op een donkere onderlaag: de naden lezen als lijnen, een paar platen zijn vervangen.
    Platen met hun midden in een rechthoek uit `worn` zijn glad gesleten (looppad)."""
    xs = [x0 + (x1 - x0) * i / nx for i in range(nx + 1)]
    zs = [z0 + (z1 - z0) * i / nz for i in range(nz + 1)]
    for i in range(nx):
        for j in range(nz):
            rs = [(xs[i], xs[i + 1], zs[j], zs[j + 1])]
            for c in cuts:
                rs = sub_rect(rs, c)
            m = pick(rng, "Floor", (("DarkSteel", 0.1), ("Anthracite", 0.07)))
            cx, cz = (xs[i] + xs[i + 1]) / 2, (zs[j] + zs[j + 1]) / 2
            if any(w[0] <= cx <= w[1] and w[2] <= cz <= w[3] for w in worn):
                m = "FloorWorn"
            for (a0, a1, c0, c1) in rs:
                if a1 - a0 < 0.15 or c1 - c0 < 0.15:
                    continue
                box(b, a0 + gap / 2, a1 - gap / 2, y, y + t, c0 + gap / 2, c1 - gap / 2, m)


# --- Vloer en baai ------------------------------------------------------------------------------------

GRATES = ((1.6, 2.2, 14.8, 15.6), (12.0, 12.6, 14.8, 15.6), (14.6, 15.2, 16.0, 16.6))
GUTTERS = ((0.64, 0.94, 0.7, 16.4), (15.55, 15.85, 2.6, 16.9))  # roosters langs de wanden (techniek eronder)
CONVEYOR = (10.3, 13.7, 17.3, 19.3)
STAIRS_BRIDGE = (6.0, 9.5, 18.6, 21.0)
# Naast de scharnieren van de luiken is de vloer dun: een open luik draait er met zijn dikte onderdoor.
HINGE_GAPS = ((2.35, 3.0, 2.0, 16.0), (11.0, 11.65, 2.0, 16.0))


def floor(ctx, B, rng):
    shell, det = B["shell"], B["det"]
    for (x0, x1, z0, z1) in ((0, 16, 16, 21), (0, 3, 0, 16), (11, 16, 2.5, 16), (3, 12, 0, 2), (11, 12, 2, 2.5)):
        rs = [(x0, x1, z0, z1)]
        for g in GUTTERS:  # de goten zijn echt verdiept
            rs = sub_rect(rs, (g[0] - 0.03, g[1] + 0.03, g[2] - 0.03, g[3] + 0.03))
        for h in HINGE_GAPS:
            rs = sub_rect(rs, h)
        for (a0, a1, c0, c1) in rs:
            slab(shell, a0, a1, c0, c1, 0.0, "Soot")
        ctx.col_box(x0, x1, -0.6, 0.0, z0, z1)
    for g in GUTTERS:
        slab(shell, g[0] - 0.03, g[1] + 0.03, g[2] - 0.03, g[3] + 0.03, -0.12, "Soot")
    for (x0, x1, z0, z1) in HINGE_GAPS:  # dun: het scharnierende luik zwaait eronder door
        slab(shell, x0, x1, z0, z1, 0.0, "Soot", bottom=-0.05)
    bx0, bx1, bz0, bz1 = BAY
    o0, o1, q0, q1 = bx0 - HZ - ST, bx1 + HZ + ST, bz0 - HZ - ST, bz1 + HZ + ST  # 2,35 · 11,65 · 1,35 · 16,65
    grate_cuts = list(GRATES) + list(GUTTERS)
    plates(shell, rng, 0.0, o0, 0.0, q1, 1, 8, cuts=grate_cuts)
    plates(shell, rng, o0, 11.65, 0.0, q0, 4, 1)
    plates(shell, rng, o1, 16.0, 2.5, q1, 2, 7, cuts=grate_cuts)
    plates(shell, rng, 0.0, 16.0, q1, 21.0, 8, 2, cuts=[STAIRS_BRIDGE, CONVEYOR, (14.85, 16.0, 16.9, 19.7)] + grate_cuts,
           worn=[(5.5, 10.5, 16.6, 19.0)])
    plates(shell, rng, 12.2, 16.0, 0.0, 1.3, 2, 1, y=-0.6)
    # Rand van de put: geel-zwart op de vloer, een ledstrook op de muur.
    box(shell, 11.65, 12.0, 0.0, 0.018, 0.0, 2.5, "Hazard")
    led(det, 12.0, 12.2, 0.0, 0.0, 2.5)

    # Baai: geel-zwarte rand, stalen rand met oranje vloerlampjes, scharnieren, hoekplaten.
    for (a0, a1, c0, c1) in ((bx0 - HZ, bx1 + HZ, bz0 - HZ, bz0), (bx0 - HZ, bx1 + HZ, bz1, bz1 + HZ),
                             (bx0 - HZ, bx0, bz0, bz1), (bx1, bx1 + HZ, bz0, bz1)):
        box(shell, a0, a1, 0.0, 0.018, c0, c1, "Hazard")
    for (a0, a1, c0, c1) in ((o0, o1, q0, bz0 - HZ), (o0, o1, bz1 + HZ, q1), (o0, bx0 - HZ, bz0 - HZ, bz1 + HZ),
                             (bx1 + HZ, o1, bz0 - HZ, bz1 + HZ)):
        box(shell, a0, a1, 0.0, 0.022, c0, c1, "DarkSteel")
    for z in (2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 14.0, 16.0):
        for x in (o0 + ST / 2, o1 - ST / 2):
            box(det, x - 0.055, x + 0.055, 0.022, 0.03, z - 0.055, z + 0.055, "LensOrange")
    for x in (3.0, 5.0, 7.0, 9.0, 11.0):
        box(det, x - 0.055, x + 0.055, 0.022, 0.03, q0 + ST / 2 - 0.055, q0 + ST / 2 + 0.055, "LensOrange")
    for x in (3.0, 4.5, 9.5, 11.0):  # achterrand: niet onder de klep
        box(det, x - 0.055, x + 0.055, 0.022, 0.03, q1 - ST / 2 - 0.055, q1 - ST / 2 + 0.055, "LensOrange")
    for x in (bx0 - 0.07, bx1 + 0.07):  # scharnieren van de luiken
        z = bz0 + 0.6
        while z < bz1 - 0.3:
            box(det, x - 0.06, x + 0.06, 0.0, 0.026, z - 0.22, z + 0.22, "Steel")
            z += 1.6
    for (cx, cz) in ((o0, q0), (o1, q0), (o0, q1), (o1, q1)):
        box(shell, cx - 0.4, cx + 0.4, 0.0, 0.028, cz - 0.4, cz + 0.4, "DarkSteel")
        for (dx, dz) in ((-0.3, -0.3), (0.3, -0.3), (-0.3, 0.3), (0.3, 0.3)):
            cyl(det, (cx + dx, 0.028, cz + dz), (0, 1, 0), 0.012, 0.03, "Steel", segs=6)
    # Goten met een rooster langs de wanden: kabels en een leiding eronder.
    for (x0, x1, z0, z1) in GUTTERS:
        box(shell, x0 - 0.03, x1 + 0.03, -0.12, 0.016, z0 - 0.03, z0, "Anthracite")
        box(shell, x0 - 0.03, x1 + 0.03, -0.12, 0.016, z1, z1 + 0.03, "Anthracite")
        for (a, c) in ((x0 - 0.03, x0), (x1, x1 + 0.03)):
            box(shell, a, c, -0.12, 0.016, z0, z1, "Anthracite")
        box(det, x0, x1, -0.12, -0.11, z0, z1, "Soot")
        cyl(det, (x0 + 0.08, -0.07, z0), (0, 0, 1), z1 - z0, 0.03, "Red", segs=6)
        cyl(det, (x1 - 0.1, -0.06, z0), (0, 0, 1), z1 - z0, 0.045, "Steel", segs=8)
        z = z0 + 0.04
        while z < z1 - 0.02:
            box(det, x0, x1, -0.03, 0.012, z - 0.012, z + 0.012, "DarkSteel")
            z += 0.065
    # Afvoerroosters.
    for (x0, x1, z0, z1) in GRATES:
        box(shell, x0, x1, -0.05, 0.016, z0, z1, "Anthracite")
        box(det, x0 + 0.04, x1 - 0.04, -0.04, -0.03, z0 + 0.04, z1 - 0.04, "Soot")
        z = z0 + 0.08
        while z < z1 - 0.06:
            box(det, x0 + 0.04, x1 - 0.04, -0.03, 0.014, z - 0.015, z + 0.015, "DarkSteel")
            z += 0.07


# --- Wanden -------------------------------------------------------------------------------------------

def side_wall(ctx, B, side, rng):
    """Een zijwand in drie lagen: spanten om de 4 m (met amberen lichtrib), ongelijke platen, en
    uitrusting (leidingen, kabelgoot). side 0 = bakboord (x = 0, vloer 0), 1 = galerij (x = 20, +1,2)."""
    shell, det, roof, rdet = B["shell"], B["det"], B["roof"], B["rdet"]
    s = 1 if side == 0 else -1
    xw = 0.0 if side == 0 else 20.0
    y0 = 0.0 if side == 0 else 1.2
    N = (s, 0, 0)

    def X(d):
        return xw + s * d

    def bx(b, d0, d1, ya, yb, za, zb, m):
        box(b, X(d0), X(d1), ya, yb, za, zb, m)

    # Schuine hoek naar het plafond (een wig), met platen erop.
    prism(roof, [(0, CH_LOW), (1.05, 9.0), (0, 9.0)], (xw, 0, 0.0), (s, 0, 0), (0, 1, 0), (0, 0, 1), 23.5, WALL)
    slope_n = (s, -1, 0)
    edges = [0.65] + [v for zf in FRAMES for v in (zf - 0.3, zf + 0.3)] + [23.4]
    for za, zb in zip(edges[0::2], edges[1::2]):
        m = pick(rng, WALL, MISMATCH)
        c = (X(0.525), CH_LOW + 0.525, (za + zb) / 2)
        fbox(roof, c, slope_n, zb - za - 0.12, 1.25, 0.05, m, up=(s, 1, 0))
        if zb - za > 2.0:
            vent_on(rdet, c, slope_n, 0.9, 0.5, 5, up=(s, 1, 0), lift=0.05)

    # Plint, datumband (2,7 m), kroonlijst onder de schuine hoek.
    bx(shell, 0, 0.1, y0, y0 + 0.28, 0.6, WALL_END, "DarkSteel")
    bx(shell, 0, 0.15, y0 + 2.62, y0 + 2.86, 0.6, WALL_END, TRIM)
    bx(shell, 0, 0.13, CH_LOW - 0.17, CH_LOW, 0.6, 23.5, TRIM)
    ctx.col_box(min(X(0), X(0.12)), max(X(0), X(0.12)), y0, y0 + 2.9, 0.0, WALL_END)

    # Platen tussen de spanten: drie rijen, ongelijk en hier en daar vervangen.
    bays = list(zip(edges[0::2], edges[1::2]))
    for (za, zb) in bays:
        zb = min(zb, WALL_END)
        if zb - za < 0.5:
            continue
        for (ya, yb, split) in ((y0 + 0.3, y0 + 2.6, True), (y0 + 2.88, y0 + 5.3, True), (y0 + 5.62, CH_LOW - 0.19, False)):
            cuts = [za, zb]
            if split and zb - za > 2.0:
                cuts = [za, za + (zb - za) * rng.uniform(0.38, 0.62), zb]
            for pa, pb in zip(cuts, cuts[1:]):
                m = pick(rng, WALL, MISMATCH)
                lift = 0.0 if rng.random() < 0.75 else 0.025
                c = (X(0.0), (ya + yb) / 2, (pa + pb) / 2)
                fbox(shell, c, N, pb - pa - 0.05, yb - ya - 0.05, 0.055 + lift, m)
                r = rng.random()
                if r < 0.18 and yb - ya > 1.5:
                    hatch_on(det, c, N, min(0.9, pb - pa - 0.4), min(1.1, yb - ya - 0.5), lift=0.055 + lift)
                elif r < 0.3:
                    vent_on(det, (c[0], ya + 0.45, c[2]), N, min(1.1, pb - pa - 0.3), 0.42, 5, lift=0.055 + lift)
                elif r < 0.37:
                    taped_crack(det, (X(0.055 + lift), c[1] + rng.uniform(-0.3, 0.3), c[2] + rng.uniform(-0.3, 0.3)), N,
                                rng.uniform(0.45, 0.8), rng.uniform(-60, 60))

    # Spanten: afgeschuinde kolom, voet, amberen lichtrib, en een rib die de schuine hoek volgt.
    for zf in FRAMES:
        ya = y0
        if side == 0 and zf == 19.0:  # boven de automaat: het spant rust op een console
            ya = 3.0
            prism(shell, [(0, 2.5), (0.5, 3.0), (0, 3.0)], (xw, 0, zf - 0.3), (s, 0, 0), (0, 1, 0), (0, 0, 1), 0.6, TRIM)
        prof = [(0, -0.3), (0.42, -0.3), (0.5, -0.22), (0.5, 0.22), (0.42, 0.3), (0, 0.3)]
        prism(shell, prof, (xw, ya, zf), (s, 0, 0), (0, 0, 1), (0, 1, 0), CH_LOW + 0.5 - ya, TRIM)
        beam(roof, (X(0.127), CH_LOW - 0.127, zf), (X(1.2), 9.0 - 0.15, zf), 0.36, 0.6, TRIM, up=(0, 0, 1), ch=0.06)
        if ya == y0:
            bx(shell, 0, 0.6, y0, y0 + 0.32, zf - 0.37, zf + 0.37, "DarkSteel")
            ctx.col_box(min(X(0), X(0.6)), max(X(0), X(0.6)), y0, CH_LOW, zf - 0.37, zf + 0.37)
        rib0 = max(ya, y0) + 0.9
        bx(det, 0.5, 0.515, rib0, y0 + 4.6, zf - 0.07, zf + 0.07, "Anthracite")
        bx(det, 0.515, 0.525, rib0 + 0.05, y0 + 4.55, zf - 0.025, zf + 0.025, "LedAmber")
        # Bouten op de voet van het spant.
        for dz in (-0.2, 0.2):
            cyl(det, (X(0.5), y0 + 5.0, zf + dz), N, 0.03, 0.035, "Steel", segs=6)
            cyl(det, (X(0.5), y0 + 6.6, zf + dz), N, 0.03, 0.035, "Steel", segs=6)

    # Leidingen (door de spanten heen) en een kabelgoot voor de spanten.
    for k, (r, m) in enumerate(((0.07, "Steel"), (0.05, "Copper"), (0.085, "DarkSteel"))):
        yy = y0 + 3.08 + k * 0.21
        dd = 0.19 + (k % 2) * 0.05
        pipe(det, [(X(dd), yy, 0.7), (X(dd), yy, WALL_END)], r, m, clamps=1.7)
    yt = y0 + 5.42
    for dd in (0.58, 0.88):
        bx(det, dd - 0.015, dd + 0.015, yt, yt + 0.11, 0.7, WALL_END, "DarkSteel")
    z = 0.85
    while z < WALL_END - 0.1:
        bx(det, 0.58, 0.88, yt, yt + 0.02, z - 0.02, z + 0.02, "DarkSteel")
        z += 0.4
    for k, m in enumerate(("Rubber", "Red", "Rubber", "Blue")):
        cyl(det, (X(0.63 + k * 0.07), yt + 0.05, 0.7), (0, 0, 1), WALL_END - 0.7, 0.026, m, segs=6)
    for zf in FRAMES:
        bx(det, 0.5, 0.9, yt - 0.09, yt, zf - 0.05, zf + 0.05, "DarkSteel")

    # Consoles voor de kraanbaan (enkel bakboord; stuurboord hangt hij aan de liggers).
    if side == 0:
        for zf in FRAMES:
            prism(shell, [(0.5, 6.35), (0.92, 7.07), (0.5, 7.07)], (xw, 0, zf - 0.2), (s, 0, 0), (0, 1, 0), (0, 0, 1), 0.4, TRIM)


# --- Raam -------------------------------------------------------------------------------------------

MULLIONS = [(1.0 + i * 2.25, 0.6 if i % 2 == 0 else -0.6) for i in range(9)]


def window(ctx, B):
    shell, det, glass, roof, rdet = B["shell"], B["det"], B["glass"], B["roof"], B["rdet"]
    box(shell, 0, 12, -0.6, 0.7, -0.3, 0.0, WALL)
    box(shell, 16, 20, -0.6, 1.9, -0.3, 0.0, WALL)
    box(shell, 0, 20, 8.5, 9.4, -0.3, 0.0, WALL)
    ctx.col_box(0, 20, -1.0, 9.4, -0.4, 0.0)  # glas: niet door te lopen
    glass.box(G(10, 4.6, -0.15), (20, 7.8, 0.05), material="Glass")
    glass.box(G(14, 0.05, -0.15), (4, 1.3, 0.05), material="Glass")
    ctx.anchor("Window_Glass", (10.0, 4.6, -0.15))

    # Dwarsregels: borstwering, midden, kop (afgeschuind naar binnen).
    for (y, h) in ((0.7, 0.24), (4.6, 0.2), (8.5, 0.28)):
        prof = [(-0.32, -h / 2), (0.04, -h / 2), (0.13, -h / 2 + 0.06), (0.13, h / 2 - 0.06), (0.04, h / 2), (-0.32, h / 2)]
        prism(shell, prof, (0, y, 0), (0, 0, 1), (0, 1, 0), (1, 0, 0), 20.0, TRIM)
    # Schuine stijlen (zoals de brug van de Super Destroyer): diep, afgeschuind, met een binnenvin.
    for (x, tilt) in MULLIONS:
        A = (tilt, 7.8, 0.0)
        L = math.hypot(tilt, 7.8)
        Xd = (7.8 / L, -tilt / L, 0.0)
        p0 = (x - tilt / 2, 0.7, 0.0)
        prof = [(-0.17, -0.32), (0.17, -0.32), (0.17, 0.1), (0.1, 0.21), (-0.1, 0.21), (-0.17, 0.1)]
        prism(shell, prof, p0, Xd, (0, 0, 1), A, L, TRIM)
        prism(det, [(-0.035, 0.2), (0.035, 0.2), (0.035, 0.33), (-0.035, 0.33)], p0, Xd, (0, 0, 1), A, L, "Anthracite")
        if x < 12.0:  # schoren op de vensterbank
            xf = x - tilt / 2 + tilt * 0.12
            prism(shell, [(0.05, 0.84), (0.44, 0.73), (0.05, 1.5)], (xf - 0.04, 0, 0), (0, 0, 1), (0, 1, 0), (1, 0, 0), 0.08, TRIM)
        # Kopschoor naar het plafond.
        xt = x + tilt / 2 - tilt * 0.06
        prism(roof, [(0.1, 8.35), (0.1, 8.95), (0.62, 8.95)], (xt - 0.05, 0, 0), (0, 0, 1), (0, 1, 0), (1, 0, 0), 0.1, TRIM)
    # Onder de dwarsregel in de put: één stijl.
    box(shell, 13.95, 14.25, -0.6, 0.6, -0.3, 0.12, TRIM)

    # Hoekkolommen tussen raam en zijwand (afgeschuind, met een amberen strook).
    for side in (0, 1):
        s = 1 if side == 0 else -1
        xw = 0.0 if side == 0 else 20.0
        ya = 0.0 if side == 0 else 1.2
        prism(shell, [(0, 0), (0.64, 0), (0.64, 0.16), (0.16, 0.64), (0, 0.64)], (xw, ya, 0), (s, 0, 0), (0, 0, 1),
              (0, 1, 0), CH_LOW + 0.3 - ya, TRIM)
        ctx.col_box(min(xw, xw + s * 0.64), max(xw, xw + s * 0.64), ya, CH_LOW, 0.0, 0.64)
        n = (s, 0, 1)
        fbox(det, (xw + s * 0.4, ya + 3.0, 0.4), n, 0.16, 4.2, 0.012, "Anthracite")
        fbox(det, (xw + s * 0.4, ya + 3.0, 0.4), n, 0.05, 4.1, 0.02, "LedAmber")

    # Vensterbank-console (hangar, x 0,64..12): schuine bovenkant met schermpjes en lampjes.
    sill = [(0, 0), (0.45, 0), (0.45, 0.7), (0.4, 0.74), (0.0, 0.86)]
    prism(shell, sill, (0.64, 0, 0), (0, 0, 1), (0, 1, 0), (1, 0, 0), 11.36, "Anthracite")
    ctx.col_box(0.64, 12.0, 0.0, 0.86, 0.0, 0.46)
    box(det, 0.7, 11.95, 0.0, 0.1, 0.45, 0.47, "DarkSteel")
    box(det, 0.7, 11.95, 0.655, 0.67, 0.45, 0.462, "LedWhite")
    top_n = (0, 0.958, 0.287)
    top_up = (0, 0.287, -0.958)
    for i, x in enumerate((1.6, 3.9, 6.2, 8.5, 10.8)):
        vent_on(det, (x, 0.34, 0.45), (0, 0, 1), 1.1, 0.36, 5)
        c = (x + 0.6, 0.8, 0.2)
        fbox(det, c, top_n, 0.5, 0.26, 0.012, "Screen", up=top_up)
        screen_ui(det, c, top_n, 0.48, 0.24, up=top_up, lift=0.012, seed=i)
        for k in range(4):
            fbox(det, (x - 0.3 + k * 0.09, 0.8, 0.2), top_n, 0.04, 0.04, 0.012,
                 ("LensRed", "LedAmber", "NavGreen", "LedAmber")[(k + i) % 4], up=top_up)
    # Galerij: dezelfde bank, 1,2 m hoger (het uitkijkpunt).
    gsill = [(0, 1.2), (0.45, 1.2), (0.45, 1.9), (0.4, 1.94), (0.0, 2.06)]
    prism(shell, gsill, (16.0, 0, 0), (0, 0, 1), (0, 1, 0), (1, 0, 0), 3.36, "Anthracite")
    ctx.col_box(16.0, 19.36, 1.2, 2.06, 0.0, 0.46)
    box(det, 16.05, 19.3, 1.855, 1.87, 0.45, 0.462, "LedWhite")
    vent_on(det, (17.7, 1.5, 0.45), (0, 0, 1), 1.6, 0.4, 6)
    # Put: voetlijst onder het glas (geen leuning: het uitzicht blijft vrij).
    box(shell, 12.2, 16.0, -0.6, -0.42, 0.0, 0.16, TRIM)
    box(det, 12.25, 15.95, -0.43, -0.415, 0.16, 0.172, "LedWhite")
    ctx.col_box(12.2, 16.0, -0.6, -0.42, 0.0, 0.16)

    # Kop: schuine plafondrand boven het glas.
    prism(roof, [(0, 8.25), (0.0, 9.0), (0.75, 9.0)], (0, 0, 0), (0, 0, 1), (0, 1, 0), (1, 0, 0), 20.0, WALL)


# --- Plafond ----------------------------------------------------------------------------------------

def ceiling(ctx, B, rng):
    roof, rdet = B["roof"], B["rdet"]
    box(roof, -0.3, 20.3, HANGAR_TOP, HANGAR_TOP + 0.4, -0.5, 23.5, WALL)
    # Hoofdliggers (kokers, afgeschuind) met een flens, schotjes en een ledstrook eronder.
    for zf in FRAMES:
        beam(roof, (0.35, 8.65, zf), (19.65, 8.65, zf), 0.45, 0.7, TRIM, ch=0.08)
        box(roof, 0.9, 19.1, 8.255, 8.305, zf - 0.3, zf + 0.3, "DarkSteel")
        x = 1.6
        while x < 18.6:
            for sz in (-1, 1):
                box(rdet, x - 0.025, x + 0.025, 8.305, 8.95, zf + sz * 0.225, zf + sz * 0.29, "DarkSteel")
            x += 1.5
        box(rdet, 1.2, 18.8, 8.243, 8.255, zf - 0.018, zf + 0.018, "LedSodium")  # natrium (nostromo-stijl §3)
    # Gordingen langs z.
    xe = [1.05, 4.0, 8.0, 12.0, 16.0, 18.95]
    for xp in xe[1:-1]:
        beam(roof, (xp, 8.86, 0.75), (xp, 8.86, 23.5), 0.2, 0.28, TRIM, ch=0.03)
    # Plafondplaten in elk vak.
    ze = [0.75] + list(FRAMES) + [23.5]
    for xa, xb in zip(xe, xe[1:]):
        for za, zb in zip(ze, ze[1:]):
            xa1, xb1 = xa + 0.1, xb - 0.1
            za1, zb1 = za + 0.23, zb - 0.23
            xm = (xa1 + xb1) / 2 + rng.uniform(-0.3, 0.3)
            zm = (za1 + zb1) / 2 + rng.uniform(-0.3, 0.3)
            for (p0, p1) in ((xa1, xm), (xm, xb1)):
                for (q0, q1) in ((za1, zm), (zm, zb1)):
                    m = pick(rng, WALL, MISMATCH)
                    box(roof, p0 + 0.03, p1 - 0.03, 8.93 - (0.03 if rng.random() < 0.2 else 0.0), 8.995, q0 + 0.03, q1 - 0.03, m)
    # Kabelgoten langs z, een luchtkoker en een sprinklerleiding.
    for xg in (2.9, 17.1):
        for dx in (-0.2, 0.2):
            box(rdet, xg + dx - 0.015, xg + dx + 0.015, 8.42, 8.52, 0.8, 23.4, "DarkSteel")
        z = 0.9
        while z < 23.3:
            box(rdet, xg - 0.2, xg + 0.2, 8.42, 8.44, z - 0.02, z + 0.02, "DarkSteel")
            z += 0.45
        for k, m in enumerate(("Rubber", "Rubber", "Red")):
            cyl(rdet, (xg - 0.1 + k * 0.1, 8.47, 0.8), (0, 0, 1), 22.6, 0.028, m, segs=6)
    xd = 10.6
    cyl(roof, (xd, 8.62, 0.8), (0, 0, 1), 22.6, 0.24, "CutterSteel", segs=16)
    for zf in FRAMES:
        cyl(rdet, (xd, 8.62, zf - 0.3), (0, 0, 1), 0.06, 0.29, "DarkSteel", segs=16)
        cyl(rdet, (xd, 8.62, zf + 0.24), (0, 0, 1), 0.06, 0.29, "DarkSteel", segs=16)
    for zz in (5.0, 13.0, 17.0, 21.0):
        box(roof, xd - 0.3, xd + 0.3, 8.22, 8.4, zz - 0.3, zz + 0.3, "DarkSteel")
        vent_on(rdet, (xd, 8.22, zz), (0, -1, 0), 0.5, 0.5, 4, up=(0, 0, 1))
    for zs in (5.0, 17.0):
        cyl(rdet, (1.1, 8.78, zs), (1, 0, 0), 17.8, 0.035, "Red", segs=6)
        x = 2.0
        while x < 18.5:
            cyl(rdet, (x, 8.66, zs), (0, 1, 0), 0.12, 0.02, "Steel", segs=6)
            x += 3.0
    # Hangende lichtbakken (elk licht heeft een armatuur die je ziet).
    for (x, z) in ((1.95, 5.0), (1.95, 13.0), (13.8, 5.0), (13.8, 13.0), (18.0, 5.0), (18.0, 13.0), (18.0, 17.0)):
        hang_fixture(roof, rdet, x, z, 8.2, 2.2, "z", top=8.93, lens="LedWarm")
    for (x, z) in ((2.6, 17.4), (6.6, 17.4), (12.0, 17.4), (2.6, 20.6), (12.4, 20.6), (16.0, 20.6)):
        hang_fixture(roof, rdet, x, z, 8.2, 2.2, "x", top=8.93, lens="LedWarm")
