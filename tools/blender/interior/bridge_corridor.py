"""De gang tussen werkdek en brug: achtkantig profiel, schotten met geel-zwarte stijlen aan beide
uiteinden, kabelgoten en leidingen, de spuitcabine (kast met spiegel en verf, bakboord) en het
firmabord (stuurboord). Plancoördinaten; zie bridge_kit.py."""

import math
import random

from bridge_kit import box, grating, plate_grid, prism, text
from bridge_props import Frame, paint_can, splat, spray_can, sticky
from layout import CORRIDOR, WALL, G, block, slab

Y0 = 1.2
H = 2.6
CH = 0.55
NICHE = (5.85, 7.0, 27.2, 29.2)  # spuitcabine: x van achterwand tot gang, z
RIBS = (26.9, 29.45)


def build(ctx, g):
    S, R, RD, P, D, L, K = g["shell"], g["roof"], g["roofd"], g["props"], g["detail"], g["glow"], g["deck"]
    x0, x1, z0, z1 = CORRIDOR
    top = Y0 + H
    rng = random.Random(11)
    # --- Vloer (ook onder de deuropening in de achterwand van de brug) ----------------------------
    slab(S, x0, x1, 26.0, z1, Y0 - 0.03, "Soot", Y0 - 0.3)
    ctx.col_box(x0, x1, Y0 - 0.3, Y0, 26.0, z1)
    plate_grid(K, 8.35, 11.65, 26.65, 29.65, Y0, 1.1, 1.0, "Floor")
    for (a, b_) in ((7.3, 8.35), (11.65, 12.7)):
        grating(K, a, b_, 26.65, 29.65, Y0, along="z", pitch=0.075)
    # --- Wanden, schuine hoeken, plafond ----------------------------------------------------------
    nx0, nx1, nz0, nz1 = NICHE
    for (a, b_) in ((z0, nz0), (nz1, z1)):
        block(S, x0 - 0.15, x0 + 0.15, Y0, top - CH, a, b_, WALL)
        ctx.col_box(x0 - 0.15, x0 + 0.15, Y0, top - CH, a, b_)
    block(S, x0 - 0.15, x0 + 0.15, 3.05, top - CH, nz0, nz1, WALL)
    block(S, x1 - 0.15, x1 + 0.15, Y0, top - CH, z0, z1, WALL)
    ctx.col_box(x1 - 0.15, x1 + 0.15, Y0, top, z0, z1)
    block(R, x0, x1, top, top + 0.3, z0, z1, WALL)
    for sx, x in ((1, x0), (-1, x1)):
        R.box(G(x + sx * CH / 2, top - CH / 2, (z0 + z1) / 2), (CH * 1.42, 0.25, z1 - z0),
              u=(sx, 1, 0), v=(-1, sx, 0) if sx > 0 else (1, -sx, 0), material=WALL)
        # Plint: schuin van wand naar vloer.
        xs = x + sx * 0.15
        zs = [(z0 + 0.3, nz0), (nz1, z1 - 0.3)] if sx > 0 else [(z0 + 0.3, z1 - 0.3)]
        for (a, b_) in zs:
            prism(S, [(xs, Y0), (xs + sx * 0.18, Y0), (xs, Y0 + 0.18)], (0, 0, a), (0, 0, 1), b_ - a, "DarkSteel")
            ctx.col_box(min(xs, xs + sx * 0.12), max(xs, xs + sx * 0.12), Y0, Y0 + 0.1, a, b_)
        # Witte ledlijn waar wand en schuine hoek elkaar raken.
        lx = x + sx * 0.16
        box(L, (lx, top - CH - 0.02, (z0 + z1) / 2), (0.015, 0.02, z1 - z0 - 0.7), "LedWhite")
    # --- Spanten en schotten ----------------------------------------------------------------------
    for zr in RIBS:
        rib(ctx, g, zr, 0.14)
    bulkhead(ctx, g, 25.86, 26.6, "BRUG", +1)
    bulkhead(ctx, g, 29.7, 30.0, "WERKDEK", -1)
    # Brugzijde van het schot: stijlen met strepen en een kopbord in de achterwand van de brug.
    for (a, b_) in ((6.62, 7.0), (13.0, 13.38)):
        block(P, a, b_, Y0, 4.2, 25.86, 26.0, "DarkSteel")
        ctx.col_box(a, b_, Y0, 4.2, 25.86, 26.0)
        block(D, a + 0.06, b_ - 0.06, Y0 + 0.05, Y0 + 1.6, 25.85, 25.86, "Hazard")
        block(L, a + 0.16, b_ - 0.16, Y0 + 1.75, 3.9, 25.845, 25.86, "LedAmber")
    block(P, 6.62, 13.38, 3.8, 4.2, 25.86, 26.0, "DarkSteel")
    block(D, 8.6, 11.4, 3.86, 4.14, 25.845, 25.86, "DecalDark")
    text(D, "WERKDEK", 0.17, (10.0, 4.0, 25.842), (0, 0, -1), "Yellow")
    # Drempel met strepen in de deuropening.
    block(D, 7.35, 12.65, Y0 - 0.004, Y0 + 0.004, 26.02, 26.28, "Hazard")
    # --- Plafond: lichtbakken, rooster, kabelgoot (bakboord) en leidingen (stuurboord) --------------
    for (a, b_) in ((26.95, 27.95), (28.45, 29.45)):
        box(RD, (10.0, top - 0.05, (a + b_) / 2), (0.36, 0.1, b_ - a), "Anthracite")
        box(L, (10.0, top - 0.105, (a + b_) / 2), (0.26, 0.012, b_ - a - 0.1), "LedWhite")
    for k in range(5):
        box(RD, (10.0, top - 0.02, 28.2 - 0.12 + k * 0.06), (0.7, 0.03, 0.025), "DarkSteel")
    box(RD, (10.0, top - 0.01, 28.2), (0.8, 0.02, 0.36), "Soot")
    s = (1 / math.sqrt(2), 1 / math.sqrt(2), 0)
    nrm = (1 / math.sqrt(2), -1 / math.sqrt(2), 0)
    c = (x0 + 0.381, top - CH / 2 - 0.112, (z0 + z1) / 2)
    box(RD, c, (0.32, 0.03, z1 - z0 - 0.7), "DarkSteel", u=s, v=nrm)
    for k, m in enumerate(("Rubber", "Red", "Rubber", "Copper")):
        p = [c[i] + s[i] * (-0.1 + k * 0.065) + nrm[i] * 0.04 for i in range(3)]
        RD.cyl(G(p[0], p[1], z0 + 0.35), (0, 0, 1), z1 - z0 - 0.7, 0.022, 6, m)
    for (px, py, r, m) in ((x1 - 0.95, top - 0.08, 0.045, "Steel"), (x1 - 1.1, top - 0.06, 0.032, "Copper")):
        RD.pipe([G(px, py, z0 + 0.3), G(px, py, z1 - 0.3)], r, 8, m, clamps=0.9)
    # Bordje aan het plafond: de nooduitgang (tegen betaling).
    for sx in (-0.3, 0.3):
        box(RD, (10.0 + sx, top - 0.19, 27.0), (0.015, 0.38, 0.015), "Steel")
    box(D, (10.0, top - 0.48, 27.0), (0.7, 0.2, 0.05), "Green")
    text(D, "NOODUITGANG", 0.07, (10.0, top - 0.46, 27.03), (0, 0, 1), "Cream")
    text(D, "(BETALEND)", 0.04, (10.0, top - 0.53, 27.03), (0, 0, 1), "Cream")
    text(D, "NOODUITGANG", 0.07, (10.0, top - 0.46, 26.97), (0, 0, -1), "Cream")
    text(D, "(BETALEND)", 0.04, (10.0, top - 0.53, 26.97), (0, 0, -1), "Cream")
    paint_booth(ctx, g, rng)
    company_board(ctx, g, rng)
    ctx.glow("ffe0bc", (10.0, top - 0.35, 28.2))


def rib(ctx, g, zc, depth):
    """Spant: achtkantig, 0,14 m in de gang, met een amberen ledstrook aan de binnenkant."""
    P, L = g["props"], g["glow"]
    x0, x1 = CORRIDOR[0], CORRIDOR[1]
    top = Y0 + H
    za, zb = zc - depth / 2, zc + depth / 2
    for sx, x in ((1, x0 + 0.15), (-1, x1 - 0.15)):
        a, b_ = sorted((x, x + sx * 0.14))
        block(P, a, b_, Y0, top - CH, za, zb, "DarkSteel")
        ctx.col_box(a, b_, Y0, top - CH, za, zb)
        lx = x + sx * 0.14
        block(L, min(lx, lx + sx * 0.008), max(lx, lx + sx * 0.008), Y0 + 0.5, top - CH - 0.35, zc - 0.01, zc + 0.01,
              "LedWhite")
        prism(P, [(x, 3.18), (x + sx * 0.14, 3.18), (x + sx * 0.62, 3.66), (x + sx * 0.62, top + 0.02),
                  (x + sx * 0.5, top + 0.02), (x, 3.32)], (0, 0, za), (0, 0, 1), depth, "DarkSteel")
    block(P, x0 + 0.77, x1 - 0.77, top - 0.14, top, za, zb, "DarkSteel")


def bulkhead(ctx, g, za, zb, title, facing):
    """Schot aan een uiteinde van de gang: dikke achtkantige deurlijst, geel-zwarte stijlen, een
    half opgetrokken deur met een gestreepte onderrand, en een kopbord."""
    P, D, L = g["props"], g["detail"], g["glow"]
    x0, x1 = CORRIDOR[0], CORRIDOR[1]
    top = Y0 + H
    ix0, ix1, iy1, ich = x0 + 0.38, x1 - 0.38, top - 0.27, 0.42
    for sx, xo, xi in ((1, x0, ix0), (-1, x1, ix1)):
        prism(P, [(xo, Y0), (xi, Y0), (xi, iy1 - ich), (xi + sx * ich, iy1), (xi + sx * ich, top),
                  (xo + sx * CH, top), (xo, top - CH)], (0, 0, za), (0, 0, 1), zb - za, "DarkSteel")
        a, b_ = sorted((xo, xi))
        ctx.col_box(a, b_, Y0, top, za, zb)
        hx = xi + sx * 0.006
        block(D, min(hx, xi), max(hx, xi), Y0 + 0.02, Y0 + 1.5, za + 0.03, zb - 0.03, "Hazard")
    block(P, ix0 + ich, ix1 - ich, iy1, top, za, zb, "DarkSteel")
    block(L, ix0 + ich + 0.1, ix1 - ich - 0.1, iy1 - 0.008, iy1, (za + zb) / 2 - 0.02, (za + zb) / 2 + 0.02,
          "LedWhite")
    # Deur: opgetrokken in het plafond, de onderrand hangt nog net zichtbaar.
    dz = (za + zb) / 2
    block(P, ix0 + ich + 0.02, ix1 - ich - 0.02, iy1 - 0.14, iy1, dz - 0.035, dz + 0.035, "Anthracite")
    block(D, ix0 + ich + 0.02, ix1 - ich - 0.02, iy1 - 0.14, iy1 - 0.08, dz - 0.037, dz + 0.037, "Hazard")
    # Kopbord aan de gangkant.
    face = zb if facing > 0 else za
    block(D, 8.8, 11.2, iy1 + 0.03, top - 0.03, min(face, face + facing * 0.012), max(face, face + facing * 0.012),
          "DecalDark")
    text(D, title, 0.15, (10.0, (iy1 + top) / 2, face + facing * 0.014), (0, 0, facing), "Yellow")


def paint_booth(ctx, g, rng):
    """Spuitcabine in een nis in de bakboordwand: kastje, spiegel, verfrek, spuitarm aan een rail."""
    S, R, RD, P, D, L, K = g["shell"], g["roof"], g["roofd"], g["props"], g["detail"], g["glow"], g["deck"]
    nx0, nx1, nz0, nz1 = NICHE
    zc = (nz0 + nz1) / 2
    ceil = 3.05
    slab(S, nx0, nx1, nz0, nz1, Y0 - 0.03, "Soot", Y0 - 0.3)
    ctx.col_box(nx0, nx1, Y0 - 0.3, Y0, nz0, nz1)
    grating(K, 6.0, 6.95, nz0 + 0.02, nz1 - 0.02, Y0, along="x", pitch=0.07)
    block(S, nx0, 6.0, Y0, ceil + 0.2, nz0 - 0.15, nz1 + 0.15, WALL)
    ctx.col_box(nx0, 6.0, Y0, ceil, nz0, nz1)
    for (a, b_) in ((nz0 - 0.15, nz0), (nz1, nz1 + 0.15)):
        block(S, nx0, nx1, Y0, ceil + 0.2, a, b_, WALL)
        ctx.col_box(nx0, nx1, Y0, ceil, a, b_)
    block(R, nx0, 7.15, ceil, ceil + 0.2, nz0 - 0.15, nz1 + 0.15, WALL)
    # Amberen lichtrib rond de opening, geel-zwarte stijlen naast de opening.
    for z in (nz0 + 0.03, nz1 - 0.03):
        block(L, 7.13, 7.17, Y0 + 0.1, ceil - 0.02, z - 0.018, z + 0.018, "LedAmber")
    block(L, 7.13, 7.17, ceil - 0.05, ceil - 0.02, nz0 + 0.03, nz1 - 0.03, "LedAmber")
    for (a, b_) in ((RIBS[0] + 0.08, nz0 - 0.02), (nz1 + 0.02, RIBS[1] - 0.08)):
        block(D, 7.15, 7.157, Y0 + 0.05, Y0 + 1.6, a, b_, "Hazard")
    # Kopbord boven de opening.
    block(P, 7.15, 7.2, ceil + 0.01, 3.24, nz0 + 0.25, nz1 - 0.25, "DarkSteel")
    text(D, "SPUITCABINE", 0.12, (7.203, ceil + 0.12, zc), (1, 0, 0), "Yellow")
    # Spiegel op de achterwand.
    fr = Frame((6.0, 0.0, zc), (1, 0, 0))
    fr.box(P, 0, 2.22, 0.03, 0.86, 1.62, 0.05, "DarkSteel")
    fr.box(D, 0, 2.22, 0.058, 0.76, 1.5, 0.006, "Mirror")
    fr.box(L, 0, 3.0, 0.05, 0.7, 0.02, 0.03, "LedWhite")
    fr.box(D, 0, 2.86, 0.062, 0.5, 0.07, 0.003, "DecalDark")
    fr.text(D, "GLIMLACHEN IS VERPLICHT", 0.026, 0, 2.86, 0.0645, "Cream")
    # Kastje (bakboord van de spiegel, kant van de brug).
    lz0, lz1 = nz0 + 0.02, nz0 + 0.55
    block(P, 6.0, 6.5, Y0, 3.0, lz0, lz1, "DarkSteel")
    ctx.col_box(6.0, 6.55, Y0, 3.0, lz0, lz1)
    block(P, 6.5, 6.53, Y0 + 0.08, 2.94, lz0 + 0.02, lz1 - 0.02, "GreyGreen")
    for k in range(6):
        block(D, 6.53, 6.536, 2.6 + k * 0.045, 2.62 + k * 0.045, lz0 + 0.12, lz1 - 0.12, "Soot")
    block(D, 6.53, 6.56, 1.95, 2.25, lz1 - 0.1, lz1 - 0.07, "Steel")
    block(D, 6.53, 6.56, 2.0, 2.08, lz1 - 0.14, lz1 - 0.09, "Yellow")  # hangslot
    block(D, 6.53, 6.535, 2.42, 2.5, lz0 + 0.1, lz1 - 0.1, "Cream")  # naamkaartje
    sticky(D, Frame((6.535, 0.0, lz0 + 0.18), (1, 0, 0)), 0, 1.75, 0, rng)
    # Verfrek (aan de kant van het werkdek) met blikken en spuitbussen.
    sz0, sz1 = nz1 - 0.52, nz1 - 0.02
    for z in (sz0, sz1 - 0.03):
        block(P, 6.0, 6.42, Y0, 2.95, z, z + 0.03, "DarkSteel")
    for y in (1.3, 1.78, 2.26, 2.74):
        block(P, 6.0, 6.42, y - 0.03, y, sz0 + 0.03, sz1 - 0.03, "DarkSteel")
    ctx.col_box(6.0, 6.45, Y0, 2.95, sz0, sz1)
    colors = ["Red", "Blue", "Yellow", "PlayerColor", "Green", "Cream", "Red", "PlayerColor", "Blue"]
    k = 0
    for y in (1.3, 1.78, 2.26):
        for j in range(3):
            z = sz0 + 0.1 + j * 0.15
            if (y, j) == (2.26, 2):
                spray_can(D, 6.2, y, z, "PlayerColor")
                spray_can(D, 6.32, y, z - 0.04, "Red")
            else:
                paint_can(D, 6.2 + rng.uniform(-0.03, 0.05), y, z, 0.06, 0.13, colors[k % len(colors)], rng)
            k += 1
    for j in range(4):
        spray_can(D, 6.12 + j * 0.07, 2.74, sz0 + 0.12 + (j % 2) * 0.18, rng.choice(["Blue", "Green", "Yellow", "Red"]))
    # Spuitarm: rail onder het plafond, wagentje, telescooparm, kop met mondstuk.
    block(RD, 6.45, 6.55, ceil - 0.07, ceil, nz0 + 0.2, nz1 - 0.2, "DarkSteel")
    block(D, 6.38, 6.62, ceil - 0.2, ceil - 0.07, zc + 0.1, zc + 0.36, "Yellow")
    D.cyl(G(6.5, ceil - 0.2, zc + 0.23), (0, -1, 0), 0.1, 0.035, 10, "Steel")
    D.cyl(G(6.5, ceil - 0.3, zc + 0.23), (0, -1, 0), 0.07, 0.06, 12, "DarkSteel")
    D.cyl(G(6.5, ceil - 0.37, zc + 0.23), (0.6, -1, 0), 0.06, 0.03, 10, "DarkSteel", r2=0.012)
    D.cyl(G(6.5, ceil - 0.27, zc + 0.23), (0, -1, 0), 0.012, 0.064, 12, "PlayerColor")
    D.pipe([G(6.5, ceil - 0.14, zc + 0.36), G(6.3, ceil - 0.25, zc + 0.5), G(6.04, ceil - 0.3, zc + 0.55)], 0.016, 6,
           "Rubber")
    # Spuitpistool aan een haak op de zijwand, met een slang.
    hz = nz0 + 0.004
    block(D, 6.72, 6.76, 2.42, 2.46, hz, hz + 0.08, "Steel")
    fr2 = Frame((6.74, 0.0, hz + 0.09), (0, 0, 1))
    fr2.box(D, 0, 2.3, 0.0, 0.05, 0.16, 0.04, "Yellow")
    fr2.box(D, 0.07, 2.4, 0.0, 0.16, 0.05, 0.05, "DarkSteel")
    fr2.cyl(D, 0.17, 2.4, 0.0, (1, 0, 0), 0.06, 0.012, 8, "Steel")
    D.pipe([G(6.74, 2.22, hz + 0.09), G(6.7, 1.8, hz + 0.12), G(6.62, 1.5, hz + 0.08), G(6.3, 1.45, hz + 0.05),
            G(6.04, 1.6, hz + 0.05)], 0.014, 6, "Rubber")
    # Verfvlekken op vloer en wanden, een lekbak.
    block(D, 6.2, 6.8, Y0 + 0.002, Y0 + 0.03, zc - 0.05, zc + 0.5, "Steel")
    for (x, z, r, m) in ((6.6, 28.0, 0.12, "PlayerColor"), (6.35, 27.85, 0.08, "Red"), (6.75, 28.6, 0.1, "Blue"),
                         (7.4, 28.3, 0.07, "PlayerColor"), (6.5, 28.95, 0.06, "Yellow")):
        splat(D, x, Y0 + 0.004, z, r, m, rng)
    for (y, z, r, m) in ((1.3, 28.0, 0.06, "PlayerColor"), (1.25, 28.45, 0.05, "Blue"), (2.0, 27.0, 0.05, "Red")):
        splat(D, 6.002, y, z, r, m, rng, normal="+x")
    block(D, 6.55, 6.95, 2.72, 2.88, nz1 - 0.006, nz1, "Cream")
    text(D, "VERF OP EIGEN KOSTEN", 0.03, (6.75, 2.8, nz1 - 0.008), (0, 0, -1), "DecalDark")
    ctx.anchor("Locker", (CORRIDOR[0] + 1.3, Y0, zc), 90)
    ctx.glow("ffb060", (6.3, 2.92, zc))


def company_board(ctx, g, rng):
    """Het firmabord: een scherm in een geel kader met DIG-opschrift (de inhoud komt uit Godot)."""
    P, D = g["props"], g["detail"]
    x = CORRIDOR[1] - 0.18
    zc, yc, w, h = 28.2, 2.5, 1.7, 0.95
    ctx.shared["screens"].append(("Company_Board", (x, yc, zc), (-1.0, 0.0, 0.0), w, h))
    block(P, x + 0.012, CORRIDOR[1] - 0.15, yc - h / 2 - 0.1, yc + h / 2 + 0.1, zc - w / 2 - 0.1, zc + w / 2 + 0.1,
          "Anthracite")
    t = 0.07
    for (y0, y1, a, b_) in ((yc + h / 2, yc + h / 2 + t, zc - w / 2 - t, zc + w / 2 + t),
                            (yc - h / 2 - t, yc - h / 2, zc - w / 2 - t, zc + w / 2 + t),
                            (yc - h / 2, yc + h / 2, zc - w / 2 - t, zc - w / 2),
                            (yc - h / 2, yc + h / 2, zc + w / 2, zc + w / 2 + t)):
        block(P, x - 0.02, x + 0.012, y0, y1, a, b_, "Yellow")
    for ay in (-1, 1):
        for az in (-1, 1):
            block(D, x - 0.025, x - 0.019, yc + ay * (h / 2 + t / 2) - 0.03, yc + ay * (h / 2 + t / 2) + 0.03,
                  zc + az * (w / 2 + t / 2) - 0.03, zc + az * (w / 2 + t / 2) + 0.03, "DecalDark")
    text(D, "DIG", 0.06, (x - 0.022, yc - h / 2 - t / 2, zc + w / 2 - 0.15), (-1, 0, 0), "DecalDark")
    # Kopbord op de schuine hoek erboven: leesbaar als je opkijkt.
    n = (-1 / math.sqrt(2), -1 / math.sqrt(2), 0.0)
    s = (-1 / math.sqrt(2), 1 / math.sqrt(2), 0.0)
    cpt = (12.6, 3.47, zc)
    box(P, cpt, (0.36, 0.04, 1.9), "DecalDark", u=s, v=n)
    text(D, "KWARTAALCIJFERS", 0.12, (cpt[0] + n[0] * 0.022, cpt[1] + n[1] * 0.022, zc), n, "Yellow", up=s)
    # Plankje eronder met een bonnenprinter, en het bordje over de kosten van het bordje.
    block(P, 12.62, x, 1.82, 1.86, zc - 0.65, zc + 0.65, "DarkSteel")
    block(D, 12.66, 12.77, 1.86, 1.96, zc + 0.3, zc + 0.55, "Cream")
    block(D, 12.655, 12.66, 1.89, 1.91, zc + 0.33, zc + 0.52, "Soot")
    block(D, 12.648, 12.652, 1.7, 1.9, zc + 0.37, zc + 0.47, "Cream")
    block(D, CORRIDOR[1] - 0.155, CORRIDOR[1] - 0.15, 1.45, 1.66, zc - 0.62, zc + 0.12, "Cream")
    text(D, "KOSTEN VAN DIT BORDJE WORDEN", 0.034, (CORRIDOR[1] - 0.157, 1.6, zc - 0.25), (-1, 0, 0), "DecalDark")
    text(D, "INGEHOUDEN OP UW LOON", 0.034, (CORRIDOR[1] - 0.157, 1.52, zc - 0.25), (-1, 0, 0), "DecalDark")
    fr = Frame((x - 0.021, 0.0, zc), (-1, 0, 0))
    sticky(D, fr, -(w / 2 + 0.035), yc + 0.3, 0.0, rng)
    sticky(D, fr, -(w / 2 + 0.04), yc + 0.18, 0.0, rng)
    ctx.col_box(12.6, CORRIDOR[1] - 0.15, Y0, yc + h / 2 + 0.1, zc - w / 2 - 0.1, zc + w / 2 + 0.1)
