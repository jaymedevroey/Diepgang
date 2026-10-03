"""Werkdek (+1,2): wanden in drie lagen, plafond met spanten en lichtbakken, vloerplaten met het
DIG-logo, de poorten naar de gang en het laadrek, de tv, en wat er aan de wanden hangt.
Onderdeel van zone_workdeck.py. Plancoördinaten (layout.py)."""

import math

from layout import WALL, WORKDECK, G, block, slab
from workdeck_kit import (Face, beam, blk, box, cable, chamfer_profile, cyl, frustum, lines, pipe, profile_beam, sign,
                          tape, text, torus)

Y0 = 1.2  # vloer van het werkdek
YC = 4.8  # plafond in het midden
YS = 4.2  # plafond aan de zijkanten
YN = 3.8  # bovenkant van de nissen en de gang
RINGS = (31.0, 35.0, 39.0)  # spanten (op de scheidingen tussen de nissen)
ALT = (("HullGrey", 0.10), ("GreyGreen", 0.08), ("RedOxide", 0.03))


def prism_z(b, pts, z0, z1, m):
    """Veelhoek in het x-y-vlak (plan), uitgerekt van z0 tot z1."""
    back = [(x, y, z0) for x, y in pts]
    front = [(x, y, z1) for x, y in pts]
    if _area(pts) * (1 if z1 > z0 else -1) < 0:
        back.reverse()
        front.reverse()
    frustum(b, back, front, m, cap_back=True)


def prism_x(b, pts, x0, x1, m):
    """Veelhoek in het z-y-vlak (punten (z, y)), uitgerekt van x0 tot x1."""
    back = [(x0, y, z) for z, y in pts]
    front = [(x1, y, z) for z, y in pts]
    # Gezien vanaf +x loopt z naar links: tegen de klok in (z, y) is met de klok mee rond +x.
    if _area(pts) * (1 if x1 > x0 else -1) > 0:
        back.reverse()
        front.reverse()
    frustum(b, back, front, m, cap_back=True)


def _area(pts):
    return sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1]
               for i in range(len(pts))) / 2


def frame_z(b, inner, outer, z0, z1, m):
    """Kader (poort) in het x-y-vlak: stukken tussen een binnen- en een buitenlijn, van z0 tot z1."""
    for i in range(len(inner) - 1):
        prism_z(b, [inner[i], inner[i + 1], outer[i + 1], outer[i]], z0, z1, m)


def frame_x(b, inner, outer, x0, x1, m):
    for i in range(len(inner) - 1):
        prism_x(b, [inner[i], inner[i + 1], outer[i + 1], outer[i]], x0, x1, m)


def strip_line(b, pts, plane, width, m):
    """Lichtstrook langs een open lijn van punten in een vlak. plane(p) → 3D-punt (plan) op het vlak,
    de strook ligt erop (dunne doos per stuk)."""
    for p, q in zip(pts, pts[1:]):
        a, c = plane(p), plane(q)
        d = tuple(c[i] - a[i] for i in range(3))
        ln = math.sqrt(sum(x * x for x in d))
        u = tuple(x / ln for x in d)
        nrm = plane.normal
        v = (nrm[1] * u[2] - nrm[2] * u[1], nrm[2] * u[0] - nrm[0] * u[2], nrm[0] * u[1] - nrm[1] * u[0])
        mid = tuple((a[i] + c[i]) / 2 + nrm[i] * 0.006 for i in range(3))
        b.box(G(*mid), (ln + width * 0.4, width, 0.012), u, v, m)


class Plane:
    """Vlak voor strip_line: vaste coördinaat (as 'x' of 'z') op `value`, punten als (in-vlak, y)."""

    def __init__(self, axis, value, sign_):
        self.axis, self.value = axis, value
        self.normal = (sign_, 0, 0) if axis == "x" else (0, 0, sign_)

    def __call__(self, p):
        a, y = p
        return (self.value, y, a) if self.axis == "x" else (a, y, self.value)


def panel_wall(pan, f, cols, rows, rng, skip=None, lift=0.05, gap=0.035, ch=0.03):
    """Platen op een wand: kolomgrenzen `cols` (langs u) en rijen [(c0, c1, materiaal)] (langs v).
    Af en toe een plaat in een andere kleur (vervangen, van een andere leverancier)."""
    for a0, a1 in zip(cols, cols[1:]):
        for c0, c1, base in rows:
            if skip and skip((a0 + a1) / 2, (c0 + c1) / 2):
                continue
            m = base
            if base == "HullDark":
                r = rng.random()
                for name, chance in ALT:
                    if r < chance:
                        m = name
                        break
                    r -= chance
            h = lift + (0.015 if rng.random() < 0.3 else 0.0)
            f.plate(pan, a0 + gap / 2, a1 - gap / 2, c0 + gap / 2, c1 - gap / 2, 0.0, h, ch, m)


def rib(pan, f, a, c0, c1, w=0.26, d=0.16, m="Anthracite"):
    f.plate(pan, a - w / 2, a + w / 2, c0, c1, 0.0, d, 0.06, m)


def floor_plate(b, x0, x1, z0, z1, y, h, ch, m):
    back = [(x0, y, z1), (x1, y, z1), (x1, y, z0), (x0, y, z0)]
    front = [(x0 + ch, y + h, z1 - ch), (x1 - ch, y + h, z1 - ch), (x1 - ch, y + h, z0 + ch), (x0 + ch, y + h, z0 + ch)]
    frustum(b, back, front, m)


def ceil_plate(b, x0, x1, z0, z1, y, h, ch, m):
    """Plaat onder een plafond op hoogte y, h naar beneden."""
    back = [(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)]
    front = [(x0 + ch, y - h, z0 + ch), (x1 - ch, y - h, z0 + ch), (x1 - ch, y - h, z1 - ch), (x0 + ch, y - h, z1 - ch)]
    frustum(b, back, front, m)


# --- Schaal ---------------------------------------------------------------------------------------

def shell(ctx, S, R):
    wx0, wx1, wz0, wz1 = WORKDECK
    slab(S, wx0, wx1, wz0, wz1, Y0)
    ctx.col_box(wx0, wx1, -0.6, Y0, wz0, wz1)
    # Plafond: midden op 4,8, zijkanten op 4,2, met een schuine overgang (Super Destroyer-profiel).
    block(R, wx0, wx1, YC, YC + 0.3, wz0, wz1, WALL)
    for x0, x1 in ((wx0, 5.0), (15.0, wx1)):
        block(R, x0, x1, YS, YC, wz0, wz1, WALL)
    prism_z(R, [(5.0, YS), (5.6, YC), (5.0, YC)], wz0, wz1, WALL)
    prism_z(R, [(15.0, YS), (15.0, YC), (14.4, YC)], wz0, wz1, WALL)
    # Voorwand (gangopening x 7..13 tot 3,8), achterwand (opening naar het laadrek x 6..14 tot 3,0).
    for (x0, x1, y0, y1, z0, z1) in ((3, 7, Y0, YC, 29.85, 30.15), (13, 17, Y0, YC, 29.85, 30.15),
                                     (7, 13, YN, YC, 29.85, 30.15), (3, 6, Y0, YC, 39.85, 40.15),
                                     (14, 17, Y0, YC, 39.85, 40.15), (6, 14, 3.0, YC, 39.85, 40.15)):
        block(S, x0, x1, y0, y1, z0, z1, WALL)
        ctx.col_box(x0, x1, y0, y1, z0, z1)
    for x in (wx0, wx1):
        for (z0, z1, y0) in ((30, 31, Y0), (39, 40, Y0), (31, 39, YN)):
            block(S, x - 0.15, x + 0.15, y0, YC, z0, z1, WALL)
            ctx.col_box(x - 0.15, x + 0.15, y0, YC, z0, z1)


# --- Spanten, kolommen, plafond -------------------------------------------------------------------

def pillars(ctx, P, D):
    """Kolommen op x 3 en 17 bij de nisscheidingen, met een voet en een knieplaat naar het plafond."""
    for z in RINGS:
        for side in (-1, 1):
            xw = 3.15 if side < 0 else 16.85  # wandvlak
            s = -side  # naar het dek toe
            x_in = xw + s * 0.32
            # Kolom: afgeschuind profiel, van de vloer tot het zijplafond.
            xa, xb = sorted((xw - s * 0.15, x_in))
            profile_beam(P, ((xa + xb) / 2, Y0, z), ((xa + xb) / 2, YS, z), chamfer_profile(xb - xa, 0.44, 0.08),
                         "Anthracite", up=(0, 0, 1))
            # Voet: bredere, afgeschuinde plaat.
            fx0, fx1 = sorted((xw - s * 0.15, xw + s * 0.5))
            frustum(P, [(fx0, Y0, z - 0.32), (fx1, Y0, z - 0.32), (fx1, Y0, z + 0.32), (fx0, Y0, z + 0.32)][::-1],
                    [(fx0 + 0.06, Y0 + 0.16, z - 0.26), (fx1 - 0.06, Y0 + 0.16, z - 0.26), (fx1 - 0.06, Y0 + 0.16, z + 0.26),
                     (fx0 + 0.06, Y0 + 0.16, z + 0.26)][::-1], "DarkSteel")
            # Knieplaat (driehoek) van de kolom naar het plafond, en een tweede, schuine schoor.
            kx = xw + s * 1.0
            prism_z(P, [(xw, 3.35), (kx, YS), (xw, YS)] if s > 0 else [(xw, 3.35), (xw, YS), (kx, YS)],
                    z - 0.07, z + 0.07, "DarkSteel")
            # Ledlijn op de voorkant van de kolom (wit, smal); de middelste kolommen dragen een banier.
            if z != 35.0:
                box(D, (x_in + s * 0.005, 3.25, z), (0.01, 1.1, 0.04), m="LedWhite")
            # Klinknagels op de voet.
            for dz in (-0.2, 0.2):
                cyl(D, (xw + s * 0.38, Y0 + 0.16, z + dz), (0, 1, 0), 0.025, 0.03, 6, "Steel")
            ctx.col_box(xa, xb, Y0, YS, z - 0.24, z + 0.24)
            ctx.col_box(fx0, fx1, Y0, Y0 + 0.16, z - 0.32, z + 0.32)


def ceiling(ctx, R, RD, rng):
    """Spanten (A-vorm), rug in het midden, kabelgoten, lichtbakken, plafondplaten en roosters."""
    # Spanten op de nisscheidingen: onder het zijplafond, schuin omhoog, onder het middenplafond.
    for z in RINGS:
        pts = [(3.15, 4.07), (5.0, 4.07), (5.72, 4.68), (14.28, 4.68), (15.0, 4.07), (16.85, 4.07)]
        for p, q in zip(pts, pts[1:]):
            beam(R, (p[0], p[1], z), (q[0], q[1], z), 0.32, 0.26, "Anthracite")
        for x in (5.0, 15.0):  # knoopplaten in de knik
            box(R, (x, 4.12, z), (0.42, 0.34, 0.36), m="DarkSteel")
        for x in (5.72, 14.28):
            box(R, (x, 4.66, z), (0.4, 0.3, 0.36), m="DarkSteel")
        # Bouten op de knoopplaten.
        for x in (4.88, 5.12, 14.88, 15.12):
            cyl(RD, (x, 4.0, z - 0.19), (0, 0, -1), 0.02, 0.03, 6, "Steel")
    # Rug in het midden (langs z) en de spot boven het logo.
    profile_beam(R, (10.0, 4.7, 30.15), (10.0, 4.7, 39.85), chamfer_profile(0.56, 0.22, 0.07), "Anthracite")
    cyl(R, (10.0, 4.6, 35.0), (0, -1, 0), 0.15, 0.36, 16, "DarkSteel")
    cyl(RD, (10.0, 4.45, 35.0), (0, -1, 0), 0.01, 0.3, 16, "LedWhite")
    torus(RD, (10.0, 4.45, 35.0), (0, 1, 0), 0.33, 0.028, 16, 4, "Anthracite")
    for a in range(4):  # beugels
        t = a * math.pi / 2 + math.pi / 4
        box(RD, (10.0 + 0.3 * math.cos(t), 4.62, 35.0 + 0.3 * math.sin(t)), (0.06, 0.18, 0.06), m="Steel")
    ctx.spot("dfe8ff", (10.0, 4.38, 35.0))
    # Lichtbakken langs z (wit), aan stangen; de diffusor onderaan.
    for x in (7.6, 12.4):
        profile_beam(RD, (x, 4.36, 30.5), (x, 4.36, 39.5), chamfer_profile(0.26, 0.13, 0.04), "Anthracite")
        box(RD, (x, 4.292, 35.0), (0.15, 0.012, 8.8), m="LedWhite")
        for z in (30.5, 39.5):
            box(RD, (x, 4.36, z), (0.3, 0.17, 0.05), m="DarkSteel")
        for z in (32.0, 34.0, 36.0, 38.0):
            cyl(RD, (x, 4.42, z), (0, 1, 0), 0.38, 0.018, 6, "Steel")
            box(RD, (x, 4.43, z), (0.3, 0.025, 0.06), m="DarkSteel")
    # Kabelgoten langs z, met kabels erin en één die eruit hangt (goedkoop gemonteerd).
    for x in (6.35, 13.65):
        box(RD, (x, 4.42, 35.0), (0.36, 0.02, 9.7), m="DarkSteel")
        for dx in (-0.17, 0.17):
            box(RD, (x + dx, 4.46, 35.0), (0.02, 0.08, 9.7), m="DarkSteel")
        for i, (dx, mm) in enumerate(((-0.09, "Rubber"), (0.0, "Red"), (0.09, "Rubber"), (0.045, "Yellow"))):
            cyl(RD, (x + dx, 4.455 + (0.035 if i == 3 else 0), 30.2), (0, 0, 1), 9.6, 0.028, 6, mm)
        for z in (31.8, 34.2, 35.8, 38.2):
            cyl(RD, (x, 4.43, z), (0, 1, 0), 0.37, 0.012, 6, "Steel")
    cable(RD, (13.55, 4.44, 32.2), (13.4, 4.44, 33.9), 0.42, 0.022, 8, "Rubber")
    cable(RD, (6.45, 4.44, 36.4), (6.6, 4.44, 37.6), 0.25, 0.022, 6, "Red")
    # Plafondplaten in het midden (tussen de spanten), roosters ertussen.
    for (z0, z1) in ((30.15, 30.84), (31.16, 34.84), (35.16, 38.84), (39.16, 39.85)):
        if z1 - z0 < 1.0:
            continue
        for (x0, x1) in ((5.75, 7.3), (7.9, 9.68), (10.32, 12.1), (12.7, 14.25)):
            n = 2
            for k in range(n):
                za = z0 + (z1 - z0) * k / n + 0.04
                zb = z0 + (z1 - z0) * (k + 1) / n - 0.04
                if (x0 > 9 and x0 < 11) and k == 0 and z0 > 35:
                    # rooster (ventilatie)
                    ceil_plate(RD, x0, x1, za, zb, YC, 0.03, 0.02, "Anthracite")
                    for i in range(9):
                        zz = za + 0.12 + i * (zb - za - 0.24) / 8
                        box(RD, ((x0 + x1) / 2, YC - 0.05, zz), (x1 - x0 - 0.2, 0.04, 0.025), m="DarkSteel")
                    continue
                m = "HullDark" if rng.random() > 0.15 else rng.choice(["HullGrey", "GreyGreen"])
                ceil_plate(RD, x0 + 0.03, x1 - 0.03, za, zb, YC, 0.05, 0.03, m)
    # Zijplafond (4,2): platen en een buis langs de rand.
    for x0, x1 in ((3.2, 4.95), (15.05, 16.8)):
        for (z0, z1) in ((30.2, 30.8), (31.2, 34.8), (35.2, 38.8), (39.2, 39.8)):
            ceil_plate(RD, x0, x1, z0 + 0.02, z1 - 0.02, YS, 0.04, 0.025, "HullDark")
    for x in (4.6, 15.4):
        pipe(RD, [(x, 4.1, 30.2), (x, 4.1, 39.8)], 0.05, 8, "Copper", clamps=1.5)
        pipe(RD, [(x - 0.13 if x < 10 else x + 0.13, 4.12, 30.2), (x - 0.13 if x < 10 else x + 0.13, 4.12, 39.8)],
             0.035, 8, "Steel", clamps=1.5)
    # Witte ledrand langs de schuine overgang.
    for x in (5.03, 14.97):
        box(RD, (x, YS - 0.01, 35.0), (0.03, 0.012, 9.7), m="LedWhite")


# --- Vloer -----------------------------------------------------------------------------------------

def floor(ctx, D, PN, rng):
    """Vloerplaten (loopstrook in het midden), lijnen, het DIG-logo, een reparatieplaat, pijlen."""
    y = Y0
    # Loopstrook x 7..13: platen 1,5 × 1,2 (licht).
    for i in range(4):
        x0 = 7.0 + i * 1.5
        z = 30.2
        while z < 39.5:
            z1 = min(z + 1.22, 39.5)
            floor_plate(PN, x0 + 0.02, x0 + 1.48, z + 0.02, z1 - 0.02, y, 0.018, 0.012, "Floor")
            z = z1
    # Zijkanten: grotere platen, af en toe een andere tint.
    for (xa, xb) in ((3.2, 7.0), (13.0, 16.8)):
        xs = [xa, (xa + xb) / 2, xb]
        for x0, x1 in zip(xs, xs[1:]):
            z = 30.2
            while z < 39.8:
                z1 = min(z + 1.95, 39.8)
                m = "Floor" if rng.random() > 0.12 else "HullGrey"
                floor_plate(PN, x0 + 0.025, x1 - 0.025, z + 0.025, z1 - 0.025, y, 0.016, 0.012, m)
                z = z1
    # Gele lijnen langs de loopstrook, met een onderbreking voor het logo.
    for x in (7.0, 13.0):
        for (z0, z1) in ((30.6, 32.6), (37.4, 39.4)):
            box(D, (x, y + 0.021, (z0 + z1) / 2), (0.07, 0.004, z1 - z0), m="Yellow")
    # Lampjes in de vloer langs de loopstrook (zoals een landingsbaan).
    for x in (7.0, 13.0):
        for z in (30.9, 32.95, 37.05, 39.1):
            cyl(D, (x, y, z), (0, 1, 0), 0.026, 0.045, 8, "DarkSteel")
            cyl(D, (x, y + 0.026, z), (0, 1, 0), 0.006, 0.03, 8, "LedAmber")
    # Pijlen (chevrons) op de loopstrook: van het laadrek naar de gang.
    for z in (38.3, 31.7):
        for k in range(3):
            zz = z + k * 0.32
            for s in (-1, 1):
                box(D, (10.0 + s * 0.17, y + 0.021, zz + 0.1), (0.42, 0.004, 0.09), u=(s * 0.8, 0, 0.6), v=(0, 1, 0),
                    m="Yellow")
    # Geel-zwart aan de rand van de trap naar het laadrek.
    box(D, (10.0, y + 0.021, 39.68), (7.4, 0.004, 0.3), m="Hazard")
    text(D, "LET OP: TREDEN", 0.12, (10.0, y + 0.024, 39.2), (0, 1, 0), "Yellow", up=(0, 0, 1))
    # DIG-logo in het midden (10, 35): zeshoekige plaat, gele rand, DIG, de volle naam.
    cx, cz = 10.0, 35.0
    hexo = [(cx + 2.15 * math.cos(math.radians(60 * k + 30)), cz + 2.15 * math.sin(math.radians(60 * k + 30)))
            for k in range(6)]
    hexi = [(cx + 2.07 * math.cos(math.radians(60 * k + 30)), cz + 2.07 * math.sin(math.radians(60 * k + 30)))
            for k in range(6)]
    frustum(PN, [(x, y, z) for x, z in reversed(hexo)], [(x, y + 0.024, z) for x, z in reversed(hexi)], "Anthracite")
    for k in range(6):
        a0, a1 = math.radians(60 * k + 30), math.radians(60 * k + 90)
        r0, r1 = 1.92, 1.72
        p = [(cx + r0 * math.cos(a0), cz + r0 * math.sin(a0)), (cx + r0 * math.cos(a1), cz + r0 * math.sin(a1)),
             (cx + r1 * math.cos(a1), cz + r1 * math.sin(a1)), (cx + r1 * math.cos(a0), cz + r1 * math.sin(a0))]
        frustum(D, [(x, y + 0.024, z) for x, z in reversed(p)], [(x, y + 0.03, z) for x, z in reversed(p)], "Yellow")
        # Lampjes in de hoeken van de zeshoek (één is kapot: DIG).
        lx, lz = cx + 2.0 * math.cos(a0), cz + 2.0 * math.sin(a0)
        cyl(D, (lx, y + 0.024, lz), (0, 1, 0), 0.014, 0.06, 8, "DarkSteel" if k == 4 else "LedAmber")
    text(D, "DIG", 0.95, (cx, y + 0.03, cz - 0.1), (0, 1, 0), "Yellow", up=(0, 0, -1))
    text(D, "DIEPGANG INTERPLANETAIRE GRONDWERKEN", 0.085, (cx, y + 0.03, cz + 0.8), (0, 1, 0), "Yellow",
         up=(0, 0, -1), max_w=2.9)
    text(D, "SINDS 2161 · ZONDER SCHADECLAIMS SINDS 2163", 0.05, (cx, y + 0.03, cz + 1.05), (0, 1, 0), "Yellow",
         up=(0, 0, -1), max_w=2.1)
    # Goedkope reparatie: een stalen plaat met bouten over een hoek van het logo.
    box(D, (cx + 1.55, y + 0.034, cz - 1.05), (0.9, 0.012, 0.62), u=(math.cos(0.3), 0, math.sin(0.3)), v=(0, 1, 0),
        m="HullGrey")
    for dx, dz in ((-0.38, -0.24), (0.38, -0.24), (-0.38, 0.24), (0.38, 0.24)):
        c, s = math.cos(0.3), math.sin(0.3)
        cyl(D, (cx + 1.55 + dx * c - dz * s, y + 0.04, cz - 1.05 + dx * s + dz * c), (0, 1, 0), 0.012, 0.025, 6, "Steel")
    # Luik in de vloer (techniek) rechts vooraan, met geel-zwarte hoeken.
    floor_plate(D, 14.3, 15.5, 31.0, 32.2, y + 0.018, 0.012, 0.01, "HullGrey")
    for (x, z) in ((14.38, 31.08), (15.42, 31.08), (14.38, 32.12), (15.42, 32.12)):
        box(D, (x, y + 0.033, z), (0.12, 0.004, 0.12), m="Hazard")
    box(D, (14.9, y + 0.034, 32.0), (0.3, 0.01, 0.04), m="Steel")
    # Gele waarschuwingsbok naast het luik (schoonmaak uitbesteed).
    for s in (-1, 1):
        box(D, (15.85, y + 0.31, 32.75 + s * 0.09), (0.36, 0.62, 0.025), u=(1, 0, 0), v=(0, 0.96, -s * 0.28),
            m="Yellow")
        lines(D, [("LET OP:", 0.04), ("GLAD", 0.06), ("SCHOONMAAK", 0.022), ("UITBESTEED", 0.022)],
              (15.85, y + 0.365, 32.75 + s * 0.103), (0, 0.28, s * 0.96), "DecalDark", up=(0, 0.96, -s * 0.28),
              gap=0.5)
    ctx.col_box(15.65, 16.05, y, y + 0.62, 32.55, 32.95)
    # Wand-vloer: een schuine plint langs de wanden (Super Destroyer-profiel).
    for (x0, x1, z, s) in ((3.15, 6.55, 30.15, 1), (13.45, 16.85, 30.15, 1), (3.15, 5.75, 39.85, -1),
                           (14.25, 16.85, 39.85, -1)):
        profile_beam(PN, (x0, y, z), (x1, y, z), [(0, 0), (0, 0.16), (-0.16, 0)] if s > 0 else
                     [(0, 0), (0.16, 0), (0, 0.16)], "Anthracite", up=(0, 1, 0))


# --- Poorten -------------------------------------------------------------------------------------

def portals(ctx, P, D):
    """Poort naar de gang (voorwand) en naar het laadrek (achterwand), met ledranden en bordjes."""
    # Gang: binnenlijn volgt de afgeschuinde gang (0,55 m schuin bovenaan).
    inner = [(7.15, Y0), (7.15, 3.25), (7.7, YN), (12.3, YN), (12.85, 3.25), (12.85, Y0)]
    outer = [(6.65, Y0), (6.65, 3.46), (7.52, 4.33), (12.48, 4.33), (13.35, 3.46), (13.35, Y0)]
    frame_z(P, inner, outer, 30.15, 30.5, "Anthracite")
    strip_line(D, [(6.97, 2.08), (6.97, 3.3), (7.65, 3.98), (12.35, 3.98), (13.03, 3.3), (13.03, 2.08)],
               Plane("z", 30.5, 1), 0.035, "LedWhite")
    for x0 in (6.65, 12.85):  # geel-zwart onderaan de stijlen
        box(D, (x0 + 0.25, 1.62, 30.506), (0.46, 0.8, 0.012), m="Hazard")
    for x in (6.65, 13.35):
        ctx.col_box(min(x, x + (0.5 if x < 10 else -0.5)), max(x, x + (0.5 if x < 10 else -0.5)), Y0, YN, 30.15, 30.56)
    # Bord boven de poort.
    box(P, (10.0, 4.55, 30.25), (3.6, 0.36, 0.2), m="Anthracite")
    text(D, "BRUG  ·  OPDRACHTEN", 0.15, (10.0, 4.55, 30.35), (0, 0, 1), "Yellow")
    box(D, (10.0, 4.41, 30.356), (3.3, 0.012, 0.012), m="LedAmber")
    # Laadrek: lager, met afgeschuinde hoeken (0,4 m). De voorkant kijkt naar −z.
    inner = [(6.15, Y0), (6.15, 2.6), (6.55, 3.0), (13.45, 3.0), (13.85, 2.6), (13.85, Y0)]
    outer = [(5.72, Y0), (5.72, 2.78), (6.37, 3.43), (13.63, 3.43), (14.28, 2.78), (14.28, Y0)]
    frame_z(P, inner, outer, 39.85, 39.5, "Anthracite")
    strip_line(D, [(6.0, 1.95), (6.0, 2.67), (6.48, 3.15), (13.52, 3.15), (14.0, 2.67), (14.0, 1.95)],
               Plane("z", 39.5, -1), 0.035, "LedWhite")
    for x in (5.72, 14.28):
        ctx.col_box(min(x, 6.15 if x < 10 else 13.85), max(x, 6.15 if x < 10 else 13.85), Y0, 3.0, 39.5, 39.85)
        box(D, ((x + (6.15 if x < 10 else 13.85)) / 2, 1.55, 39.494), (0.4, 0.7, 0.012), m="Hazard")
    box(P, (10.0, 3.75, 39.75), (3.2, 0.42, 0.2), m="Anthracite")
    text(D, "LAADREK", 0.2, (10.0, 3.75, 39.65), (0, 0, -1), "Yellow")
    box(D, (10.0, 3.6, 39.644), (2.9, 0.012, 0.012), m="LedAmber")


# --- Tv ------------------------------------------------------------------------------------------

def tv(ctx, P, D):
    """Tv op de voorwand: behuizing, kader, luidsprekerbalk, steunen, kabel, tape. TV_Screen ligt op
    z 30,32 (contract), 2 cm voor de behuizing."""
    blk(P, 3.5, 6.5, 2.3, 4.0, 30.15, 30.30, "Anthracite")
    blk(P, 3.42, 6.58, 3.925, 4.06, 30.15, 30.40, "DarkSteel")  # boven
    blk(P, 3.42, 3.6, 2.375, 3.925, 30.15, 30.40, "DarkSteel")  # links
    blk(P, 6.4, 6.58, 2.375, 3.925, 30.15, 30.40, "DarkSteel")  # rechts
    blk(P, 3.42, 6.58, 2.02, 2.375, 30.15, 30.44, "Anthracite")  # luidsprekerbalk
    ctx.shared["screens"].append(("TV_Screen", (5.0, 3.15, 30.32), (0.0, 0.0, 1.0), 2.8, 1.55))
    # Binnenrand rond het scherm (donker, iets terug).
    for (x0, x1, y0, y1) in ((3.6, 6.4, 3.905, 3.925), (3.6, 6.4, 2.375, 2.395), (3.6, 3.62, 2.375, 3.925),
                             (6.38, 6.4, 2.375, 3.925)):
        blk(D, x0, x1, y0, y1, 30.30, 30.36, "Soot")
    # Roosters links en rechts, logo in het midden, standby-lampje.
    for (x0, x1) in ((3.6, 4.6), (5.4, 6.4)):
        blk(D, x0, x1, 2.07, 2.33, 30.44, 30.445, "Soot")
        for i in range(7):
            yy = 2.09 + i * 0.035
            blk(D, x0 + 0.02, x1 - 0.02, yy, yy + 0.014, 30.445, 30.455, "DarkSteel")
    blk(D, 4.72, 5.28, 2.12, 2.29, 30.44, 30.452, "Yellow")
    text(D, "DIG", 0.09, (5.0, 2.205, 30.452), (0, 0, 1), "DecalDark")
    cyl(D, (6.49, 2.2, 30.44), (0, 0, 1), 0.012, 0.012, 8, "LensRed")
    box(P, (5.0, 4.1, 30.36), (3.3, 0.04, 0.32), u=(1, 0, 0), v=(0, 0.97, 0.24), m="Anthracite")  # kap
    for x in (3.47, 6.53):
        for y in (2.43, 3.87):
            blk(D, x - 0.06, x + 0.06, y - 0.06, y + 0.06, 30.4, 30.415, "DarkSteel")
            cyl(D, (x, y, 30.415), (0, 0, 1), 0.01, 0.018, 6, "Steel")
        # Handgreep opzij (U-vorm).
        xa, xb = (x + 0.05, x + 0.13) if x > 5 else (x - 0.13, x - 0.05)
        xo = x + (0.11 if x > 5 else -0.11)
        for y in (2.7, 3.1):
            blk(D, xa, xb, y, y + 0.04, 30.22, 30.28, "Steel")
        blk(D, xo - 0.02, xo + 0.02, 2.7, 3.14, 30.22, 30.28, "Steel")
    blk(D, 3.7, 4.3, 3.95, 4.02, 30.4, 30.412, "Soot")
    text(D, "LIVE", 0.04, (3.86, 3.985, 30.412), (0, 0, 1), "LensRed")
    cyl(D, (4.2, 3.985, 30.412), (0, 0, 1), 0.006, 0.014, 8, "LensRed")
    # Steunen onder de hoeken (L-beugels op de wand).
    for x in (3.85, 6.15):
        blk(D, x - 0.06, x + 0.06, 1.66, 2.02, 30.15, 30.19, "DarkSteel")
        blk(D, x - 0.06, x + 0.06, 1.98, 2.02, 30.15, 30.44, "DarkSteel")
        box(D, (x, 1.85, 30.295), (0.035, 0.39, 0.04), u=(0, 0, 1), v=(0, 0.77, 0.64), m="DarkSteel")
        for yy in (1.72, 1.92):
            cyl(D, (x, yy, 30.19), (0, 0, 1), 0.012, 0.018, 6, "Steel")
    # Gebarsten hoek, met tape vastgezet.
    f = Face((3.42, 2.02, 30.40), (1, 0, 0), (0, 1, 0))
    tape(D, f, 2.88, 1.88, 2.88, 2.07, 0.0, 0.06)
    tape(D, f, 2.96, 1.75, 3.17, 1.75, 0.0, 0.06)
    # Kabel naar een stopcontact.
    cable(D, (6.3, 2.02, 30.33), (6.62, 1.52, 30.2), 0.12, 0.014, 8, "Rubber")
    blk(D, 6.55, 6.7, 1.45, 1.6, 30.15, 30.19, "Cream")
    # Bordje onder de tv.
    sign(D, D, Face((3.15, Y0, 30.15), (1, 0, 0), (0, 1, 0)), 1.85, 0.62, 1.6, 0.24,
         [("DIG-NIEUWS · 24/7", 0.055), ("ER IS GEEN UITKNOP", 0.04)], bg="DecalDark", fg="Yellow")
    ctx.col_box(3.42, 6.58, 2.0, 4.06, 30.15, 30.45)


# --- Wanden --------------------------------------------------------------------------------------

def walls(ctx, P, D, PN, rng):
    """Voor- en achterwand in drie lagen (spanten, platen, uitrusting) en wat eraan hangt."""
    # Voorwand, vlak naar het dek (+z): a = x − 3,15, c = y − 1,2.
    front = Face((3.15, Y0, 30.15), (1, 0, 0), (0, 1, 0))
    rows = [(0.0, 0.5, "Anthracite"), (0.5, 1.75, "HullDark"), (1.75, 2.75, "HullDark"), (2.75, 3.6, "HullDark")]
    tv_cells = lambda a, c: 0.2 < a < 3.5 and 0.75 < c < 2.95  # noqa: E731
    panel_wall(PN, front, [0.0, 1.0, 2.0, 3.0, 3.5], rows, rng, skip=tv_cells)
    panel_wall(PN, front, [10.2, 11.1, 12.1, 13.0, 13.7], rows, rng)
    for a in (0.05, 13.62):
        rib(PN, front, a, 0.0, 3.6)
    # Achterwand, vlak naar het dek (−z): a = 16,85 − x.
    back = Face((16.85, Y0, 39.85), (-1, 0, 0), (0, 1, 0))
    panel_wall(PN, back, [0.0, 0.85, 1.75, 2.6], rows, rng)
    panel_wall(PN, back, [11.1, 12.0, 12.9, 13.7], rows, rng, skip=lambda a, c: a > 11.2 and c < 2.0)
    for a in (0.05, 13.62):
        rib(PN, back, a, 0.0, 3.6)
    # Uitrusting: buizen boven, in de hoeken verticale leidingen met een kraan.
    pipe(D, [(13.4, 3.98, 30.27), (16.4, 3.98, 30.27)], 0.055, 8, "Steel", clamps=1.1)
    pipe(D, [(13.4, 4.11, 30.25), (16.4, 4.11, 30.25)], 0.04, 8, "Copper", clamps=1.1)
    for (x, z, r, mm) in ((16.62, 30.32, 0.06, "Steel"), (16.46, 30.32, 0.045, "Copper"),
                          (3.25, 39.6, 0.06, "Steel"), (3.25, 39.76, 0.045, "Copper")):
        pipe(D, [(x, Y0, z), (x, 4.15, z)], r, 8, mm, clamps=0.9)
    torus(D, (16.62, 2.35, 30.44), (0, 0, 1), 0.11, 0.015, 12, 5, "Red")
    cyl(D, (16.62, 2.35, 30.32), (0, 0, 1), 0.12, 0.025, 6, "Steel")
    torus(D, (3.37, 2.35, 39.6), (1, 0, 0), 0.11, 0.015, 12, 5, "Red")
    cyl(D, (3.25, 2.35, 39.6), (1, 0, 0), 0.12, 0.025, 6, "Steel")

    # --- Voorwand rechts: werknemer van het kwartaal, prikklok -------------------------------------
    # Lijst met een lege foto.
    f = Face((3.15, Y0, 30.15), (1, 0, 0), (0, 1, 0))
    a, c = 14.5 - 3.15, 2.95 - Y0
    H = 0.07  # voor de wandplaten
    f.box(P, a, c, H, (1.5, 1.8, 0.05), "Yellow")
    f.box(D, a, c, H + 0.05, (1.36, 1.66, 0.006), "Cream")
    lines(D, [("WERKNEMER VAN", 0.075), ("HET KWARTAAL", 0.075)], f.at(a, c + 0.66, H + 0.056), (0, 0, 1),
          "DecalDark", gap=0.4)
    f.box(D, a, c + 0.05, H + 0.056, (0.78, 0.86, 0.004), "Soot")
    for k in range(10):  # stippellijn van een robotkop
        t = k / 10 * math.tau
        f.box(D, a + 0.24 * math.cos(t), c + 0.12 + 0.24 * math.sin(t), H + 0.06, (0.05, 0.02, 0.003), "DecalLight")
    f.box(D, a, c - 0.24, H + 0.06, (0.42, 0.03, 0.003), "DecalLight")
    text(D, "[VACANT]", 0.1, f.at(a, c + 0.05, H + 0.063), (0, 0, 1), "Red", tilt=12)
    lines(D, [("Q1: VACANT · Q2: VACANT", 0.035), ("Q3: VACANT · Q4: HERZIENING", 0.035),
              ("AANMELDEN KAN NIET", 0.035)], f.at(a, c - 0.6, H + 0.056), (0, 0, 1), "DecalDark", gap=0.6)
    for dx in (-0.6, 0.6):
        f.box(D, a + dx, c + 0.92, 0.0, (0.05, 0.08, H + 0.06), "Steel")
    # Prikklok met kaartenrek.
    a, c = 15.75 - 3.15, 2.42 - Y0
    f.box(P, a, c, 0.0, (0.46, 0.56, 0.22), "Anthracite")
    f.box(D, a, c + 0.12, 0.22, (0.34, 0.2, 0.006), "Cream")
    cyl(D, f.at(a, c + 0.12, 0.225), (0, 0, 1), 0.004, 0.08, 16, "Cream")
    f.tilted(D, a, c + 0.14, 0.23, (0.012, 0.06, 0.003), 25, "DecalDark")
    f.tilted(D, a + 0.02, c + 0.12, 0.23, (0.045, 0.01, 0.003), 0, "DecalDark")
    f.box(D, a, c - 0.1, 0.22, (0.2, 0.025, 0.01), "Soot")
    text(D, "PRIKKLOK", 0.035, f.at(a, c - 0.2, 0.22), (0, 0, 1), "Yellow")
    for k in range(6):
        aa = a + 0.42 + (k % 2) * 0.14
        cc = c + 0.2 - (k // 2) * 0.17
        f.box(D, aa, cc, 0.0, (0.12, 0.04, 0.12), "DarkSteel")
        if k != 3:
            f.box(D, aa, cc + 0.04, 0.09, (0.09, 0.12, 0.004), "Cream")
    sign(D, D, f, a + 0.2, c + 0.5, 0.82, 0.16, [("INPRIKKEN VERPLICHT", 0.032), ("UITPRIKKEN OPTIONEEL", 0.032)],
         bg="Cream", fg="DecalDark", gap=0.5, h0=0.07)
    ctx.col_box(15.5, 16.4, 2.1, 2.72, 30.15, 30.4)

    # --- Achterwand links: kluisjes (op mensenmaat), banier erboven --------------------------------
    b = Face((16.85, Y0, 39.85), (-1, 0, 0), (0, 1, 0))
    blk(P, 3.42, 5.66, Y0, 3.2, 39.3, 39.85, "GreyGreen")
    ctx.col_box(3.4, 5.68, Y0, 3.2, 39.25, 39.85)
    blk(D, 3.42, 5.66, Y0, Y0 + 0.08, 39.26, 39.3, "Anthracite")
    blk(D, 3.4, 5.68, 3.12, 3.2, 39.25, 39.3, "DarkSteel")
    colors = ["GreyGreen", "Red", "GreyGreen", "HullGrey"]
    for i in range(4):
        x0 = 3.44 + i * 0.56
        if i == 2:  # deur open (scharnier rechts)
            ang = math.radians(70)
            hx, hz = x0 + 0.52, 39.29
            dx, dz = -math.cos(ang), -math.sin(ang)
            box(P, (hx + dx * 0.25, 2.2, hz + dz * 0.25), (0.5, 1.9, 0.025), u=(dx, 0, dz), v=(0, 1, 0), m=colors[i])
            blk(D, x0 + 0.02, x0 + 0.5, 1.3, 3.1, 39.29, 39.3, "Soot")
            blk(D, x0 + 0.03, x0 + 0.49, 2.6, 2.62, 39.2, 39.29, "DarkSteel")
            blk(D, x0 + 0.1, x0 + 0.36, 2.62, 2.74, 39.21, 39.29, "Cardboard")
            continue
        blk(P, x0, x0 + 0.52, 1.28, 3.12, 39.27, 39.3, colors[i])
        for k in range(4):
            blk(D, x0 + 0.12, x0 + 0.4, 2.85 + k * 0.05, 2.87 + k * 0.05, 39.262, 39.268, "Soot")
        blk(D, x0 + 0.42, x0 + 0.46, 2.0, 2.2, 39.25, 39.27, "Steel")
        blk(D, x0 + 0.1, x0 + 0.42, 2.55, 2.63, 39.262, 39.268, "Cream")
    tape(D, b, 16.85 - 5.18, 0.8, 16.85 - 5.52, 1.3, 0.59, 0.05)
    sign(D, D, b, 16.85 - 5.34, 1.12, 0.26, 0.16, [("DEFECT", 0.04)], bg="Cream", fg="Red", depth=0.006, tilt=-6,
         h0=0.59)
    blk(D, 3.6, 4.2, 3.2, 3.46, 39.4, 39.74, "Cardboard")
    blk(D, 4.4, 4.85, 3.2, 3.38, 39.45, 39.74, "Cardboard")
    # Banier boven de kluisjes.
    blk(D, 3.4, 5.55, 4.08, 4.11, 39.68, 39.78, "Steel")
    blk(D, 3.5, 5.45, 3.52, 4.07, 39.75, 39.77, "DecalDark")
    lines(D, [("DIEPER GRAVEN.", 0.09), ("MINDER VRAGEN.", 0.09)], (4.475, 3.79, 39.75), (0, 0, -1), "Yellow", gap=0.5)
    blk(D, 3.5, 5.45, 3.56, 3.58, 39.744, 39.748, "Yellow")

    # --- Achterwand rechts: koelvloeistof, lege blusserhouder, banier ------------------------------
    blk(P, 15.6, 16.2, Y0, 2.15, 39.4, 39.85, "Panel")
    blk(D, 15.62, 16.18, Y0, 1.3, 39.38, 39.42, "DarkSteel")
    blk(D, 15.68, 16.12, 1.42, 1.98, 39.385, 39.4, "Soot")  # nis met kraan
    blk(D, 15.7, 16.1, 1.44, 1.47, 39.36, 39.4, "DarkSteel")  # lekbak
    blk(D, 15.86, 15.94, 1.86, 1.96, 39.33, 39.4, "Steel")  # kraan
    cyl(D, (15.9, 1.86, 39.355), (0, -1, 0), 0.04, 0.012, 6, "Steel")
    blk(D, 15.66, 16.14, 2.02, 2.1, 39.385, 39.4, "Blue")
    cyl(P, (15.9, 2.15, 39.62), (0, 1, 0), 0.5, 0.17, 12, "Blue")
    cyl(D, (15.9, 2.65, 39.62), (0, 1, 0), 0.04, 0.08, 8, "Blue")
    cyl(D, (16.28, 1.6, 39.6), (0, 1, 0), 0.5, 0.045, 8, "Cream")
    sign(D, D, b, 16.85 - 15.9, 1.75, 0.7, 0.24, [("KOELVLOEISTOF", 0.05), ("1 BEKER PER DIENST", 0.035)],
         bg="Blue", fg="DecalLight", gap=0.5, h0=0.07)
    ctx.col_box(15.55, 16.35, Y0, 2.7, 39.3, 39.85)
    # Lege houder van een brandblusser.
    blk(D, 14.72, 14.98, 1.75, 1.8, 39.7, 39.85, "DarkSteel")
    blk(D, 14.72, 14.98, 2.25, 2.3, 39.7, 39.85, "DarkSteel")
    blk(D, 14.82, 14.88, 1.75, 2.3, 39.82, 39.85, "DarkSteel")
    sign(D, D, b, 16.85 - 14.85, 1.4, 0.36, 0.3, [("BRANDBLUSSER", 0.035), ("OP AANVRAAG", 0.03), ("(FORMULIER B-12)", 0.022)],
         bg="Red", fg="DecalLight", gap=0.55, h0=0.07)
    # Banier.
    blk(D, 14.55, 16.55, 4.08, 4.11, 39.68, 39.78, "Steel")
    blk(D, 14.65, 16.45, 3.2, 4.07, 39.75, 39.77, "DecalDark")
    lines(D, [("VEILIGHEID:", 0.075), ("ONZE 7DE", 0.075), ("PRIORITEIT", 0.075)], (15.55, 3.66, 39.75), (0, 0, -1),
          "Yellow", gap=0.45)

    # --- Banieren aan de middelste kolommen (DIG, zwart en geel) -----------------------------------
    for side in (-1, 1):
        x = 3.47 if side < 0 else 16.53
        n = (-side, 0, 0)
        box(D, (x - side * 0.03, 4.12, 35.0), (0.03, 0.03, 0.72), m="Steel")
        box(D, (x - side * 0.01, 3.2, 35.0), (0.012, 1.8, 0.6), m="DecalDark")
        box(D, (x - side * 0.02, 2.38, 35.0), (0.012, 0.05, 0.6), m="Yellow")
        for k, ch in enumerate("DIG"):
            text(D, ch, 0.22, (x - side * 0.017, 3.72 - k * 0.32, 35.0), n, "Yellow")
        text(D, "DIEPER.", 0.05, (x - side * 0.017, 2.6, 35.0), n, "Yellow")
