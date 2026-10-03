"""De vier upgradenissen van het werkdek als diorama's: elk één held, een eigen licht en DIG-humor.

Niche_Tools  (x 0..3,   z 31..35): werkbank met bankschroef, schaduwbord met omtrekken.
Niche_Supply (x 0..3,   z 35..39): uitgiftebalie met rolluik en luik, rekken met dozen.
Niche_Free_A (x 17..20, z 31..35): IN AANBOUW, steiger voor een gestripte wand.
Niche_Free_B (x 17..20, z 35..39): BINNENKORT, ladder, kabelhaspel, nieuwe platen, bouwlamp.
Onderdeel van zone_workdeck.py. Plancoördinaten (layout.py). Vloer +1,2, plafond 3,8."""

import math

from layout import NICHES, WALL, block, slab
from workdeck_kit import Face, blk, box, cable, cyl, lines, sign, tape, text, torus
from workdeck_room import Plane, ceil_plate, floor_plate, frame_x, panel_wall, prism_x, prism_z, strip_line

Y0, YN, YS = 1.2, 3.8, 4.2


class Niche:
    def __init__(self, name, x0, x1, z0, z1):
        self.name = name
        self.side = -1 if x0 < 10 else 1
        self.x0, self.x1, self.z0, self.z1 = x0, x1, z0, z1
        self.wall = x0 if self.side < 0 else x1  # midden van de achterwand
        self.back = self.wall - self.side * 0.15  # binnenvlak van de achterwand
        self.front = x1 if self.side < 0 else x0  # vlak van de dekwand
        self.into = -self.side  # richting (x) van de achterwand naar het dek
        self.zi0, self.zi1 = z0 + 0.15, z1 - 0.15
        self.zc = (z0 + z1) / 2

    def x(self, d):
        return self.back + self.into * d

    def xs(self, d0, d1):
        return tuple(sorted((self.x(d0), self.x(d1))))

    def back_face(self):
        if self.side < 0:
            return Face((self.back, Y0, self.zi1), (0, 0, -1), (0, 1, 0))
        return Face((self.back, Y0, self.zi0), (0, 0, 1), (0, 1, 0))

    def a_back(self, z):
        return (self.zi1 - z) if self.side < 0 else (z - self.zi0)

    def side_face(self, hi):
        """Zijwand: hi=False op zi0 (kijkt +z), hi=True op zi1 (kijkt −z). Geeft (vlak, a(x))."""
        xmin, xmax = sorted((self.back, self.front))
        if not hi:
            return Face((xmin, Y0, self.zi0), (1, 0, 0), (0, 1, 0)), (lambda x: x - xmin)
        return Face((xmax, Y0, self.zi1), (-1, 0, 0), (0, 1, 0)), (lambda x: xmax - x)


def shell(ctx, S, R, PN, D, RD, P, n, rng, title, status, back_skip=None, side_skip=(None, None)):
    """Vloer, wanden, plafond met schuine hoeken, platen, de poort met de amberen lichtrib, het
    hangende naambord en het statuslampje."""
    x0, x1, z0, z1 = n.x0, n.x1, n.z0, n.z1
    slab(S, x0, x1, z0, z1, Y0, "Floor", Y0 - 0.3)
    ctx.col_box(x0, x1, -0.6, Y0, z0, z1)
    block(R, x0, x1, YN, YN + 0.3, z0, z1, WALL)
    block(S, n.wall - 0.15, n.wall + 0.15, Y0, YN, z0, z1, WALL)
    ctx.col_box(n.wall - 0.15, n.wall + 0.15, Y0, YN, z0, z1)
    for z in (z0,) + ((z1,) if z1 == 39.0 else ()):
        block(S, x0, x1, Y0, YN, z - 0.15, z + 0.15, WALL)
        ctx.col_box(x0, x1, Y0, YN, z - 0.15, z + 0.15)
    xa, xb = sorted((n.back, n.front))
    # Vloerplaten.
    xm = (xa + xb) / 2
    zm = n.zc
    for (p0, p1) in ((xa, xm), (xm, xb)):
        for (q0, q1) in ((n.zi0, zm), (zm, n.zi1)):
            floor_plate(PN, p0 + 0.02, p1 - 0.02, q0 + 0.02, q1 - 0.02, Y0, 0.016, 0.012, "Floor")
    # Schuine hoeken bovenaan (achthoekig profiel), met een amberen strook langs de achterkant.
    bx = n.back
    prism_z(PN, [(bx, 3.15), (bx + n.into * 0.65, YN), (bx, YN)], n.zi0, n.zi1, "HullDark")
    prism_x(PN, [(n.zi0, 3.45), (n.zi0 + 0.35, YN), (n.zi0, YN)], xa, xb, "HullDark")
    prism_x(PN, [(n.zi1, 3.45), (n.zi1, YN), (n.zi1 - 0.35, YN)], xa, xb, "HullDark")
    t = (n.into * 0.7071, 0.7071, 0.0)
    nn = (n.into * 0.7071, -0.7071, 0.0)
    mid = (bx + n.into * 0.325 + nn[0] * 0.006, 3.475 + nn[1] * 0.006, n.zc)
    box(D, mid, (0.035, 0.012, n.zi1 - n.zi0 - 0.8), u=t, v=nn, m="LedAmber")
    # Plafondplaten.
    ceil_plate(RD, *sorted((n.x(0.7), n.x(2.8))), n.zi0 + 0.38, n.zi1 - 0.38, YN, 0.04, 0.025, "HullDark")
    # Platen op de achterwand en de zijwanden.
    rows = [(0.0, 0.45, "Anthracite"), (0.45, 1.2, "HullDark"), (1.2, 1.95, "HullDark")]
    w = n.zi1 - n.zi0
    panel_wall(PN, n.back_face(), [0.0, w * 0.27, w * 0.52, w * 0.76, w], rows, rng, skip=back_skip)
    for hi in (False, True):
        f, _ = n.side_face(hi)
        panel_wall(PN, f, [0.0, 0.95, 1.9, 2.85], [(0.0, 0.45, "Anthracite"), (0.45, 1.2, "HullDark"),
                                                   (1.2, 2.25, "HullDark")], rng, skip=side_skip[1 if hi else 0])
    # Poort op het dek: kader met afgeschuinde bovenhoeken, amberen lichtrib op de voorkant.
    za, zb = z0 + 0.34, z1 - 0.34
    inner = [(za, Y0), (za, 3.38), (za + 0.42, YN), (zb - 0.42, YN), (zb, 3.38), (zb, Y0)]
    outer = [(z0 + 0.22, Y0), (z0 + 0.22, 3.5), (z0 + 0.92, YS), (z1 - 0.92, YS), (z1 - 0.22, 3.5), (z1 - 0.22, Y0)]
    fx = n.front + n.into * 0.3
    frame_x(P, inner, outer, n.front, fx, "Anthracite")
    strip_line(D, [(z0 + 0.28, Y0 + 0.08), (z0 + 0.28, 3.44), (z0 + 0.84, 4.0), (z1 - 0.84, 4.0), (z1 - 0.28, 3.44),
                   (z1 - 0.28, Y0 + 0.08)], Plane("x", fx, n.into), 0.045, "LedAmber")
    for (q0, q1) in ((z0 + 0.22, za), (zb, z1 - 0.22)):
        ctx.col_box(min(n.front, fx), max(n.front, fx), Y0, YN, q0, q1)
    box(D, (fx + n.into * 0.012, 4.12, n.zc), (0.024, 0.05, 0.2), m=status)
    # Hangend naambord voor de nis.
    sx = n.front + n.into * 0.6
    box(P, (sx, 4.0, n.zc), (0.05, 0.3, 1.8), m="Anthracite")
    text(D, title, 0.13, (sx + n.into * 0.025, 4.025, n.zc), (n.into, 0, 0), "Yellow", max_w=1.6)
    box(D, (sx + n.into * 0.028, 3.89, n.zc), (0.006, 0.012, 1.6), m="LedAmber")
    for dz in (-0.75, 0.75):
        cyl(D, (sx, 4.15, n.zc + dz), (0, 1, 0), 0.06, 0.012, 6, "Steel")
    ctx.anchor(n.name, ((x0 + x1) / 2, Y0, n.zc), 90 if n.side < 0 else -90)


# --- Gereedschap: werkbank, bankschroef, schaduwbord ------------------------------------------------

def _shape(D, f, a, c, h, parts, m, scale=1.0):
    """Omtrek of voorwerp uit dozen [(da, dc, w, hh, hoek)] op een vlak."""
    for (da, dc, w, hh, ang) in parts:
        f.tilted(D, a + da * scale, c + dc * scale, h, (w * scale, hh * scale, 0.004), ang, m)


PICK = [(0, -0.05, 0.05, 0.6, 0), (-0.13, 0.25, 0.28, 0.06, -12), (0.13, 0.25, 0.28, 0.06, 12)]
SHOVEL = [(0, 0.08, 0.04, 0.5, 0), (0, 0.34, 0.14, 0.04, 0), (0, -0.25, 0.2, 0.24, 0)]
DRILL = [(0.02, 0.06, 0.3, 0.1, 0), (-0.06, -0.07, 0.07, 0.18, -10), (0.2, 0.06, 0.08, 0.05, 0), (0.3, 0.06, 0.12, 0.015, 0)]
SCANNER = [(0, 0, 0.14, 0.22, 0), (0.04, 0.15, 0.02, 0.1, 0)]
HAMMER = [(0, -0.05, 0.04, 0.32, 0), (0, 0.12, 0.16, 0.06, 0)]
WRENCH = [(0, -0.02, 0.035, 0.3, 0), (0, 0.15, 0.09, 0.07, 0), (0, -0.18, 0.07, 0.07, 0)]


def niche_tools(ctx, S, R, PN, D, RD, P, rng):
    n = Niche("Niche_Tools", *NICHES["Niche_Tools"])
    bf = n.back_face()
    board = (0.55, 3.15, 1.0, 1.9)  # a0, a1, c0, c1 op de achterwand
    shell(ctx, S, R, PN, D, RD, P, n, rng, "GEREEDSCHAP", "LedGreen",
          back_skip=lambda a, c: board[0] - 0.2 < a < board[1] + 0.2 and c > 0.6,
          side_skip=(lambda a, c: 1.5 < a < 2.6 and 0.6 < c < 1.8, None))
    # Schaduwbord: gele plaat met donkere omtrekken; wat er hangt, hangt erop. Drie zijn weg.
    ac, cc = (board[0] + board[1]) / 2, (board[2] + board[3]) / 2
    bf.box(P, ac, cc, 0.0, (board[1] - board[0] + 0.08, board[3] - board[2] + 0.08, 0.03), "DarkSteel")
    bf.box(D, ac, cc, 0.03, (board[1] - board[0], board[3] - board[2], 0.006), "Yellow")
    h = 0.037
    text(D, "SCHADUWBORD", 0.05, bf.at(ac, board[3] - 0.07, h), tuple(bf.n), "DecalDark")
    text(D, "ONTBREKEND GEREEDSCHAP WORDT INGEHOUDEN OP UW LOON", 0.028, bf.at(ac, board[2] + 0.05, h),
         tuple(bf.n), "DecalDark", max_w=2.3)
    tools = [(0.9, PICK, False, "IN REPARATIE"), (1.35, SHOVEL, True, None), (1.85, DRILL, False, "ONTBREEKT"),
             (2.3, SCANNER, False, "UITGELEEND AAN: ???"), (2.68, HAMMER, True, None), (2.98, WRENCH, True, None)]
    for a, parts, present, note in tools:
        _shape(D, bf, a, 1.47, h, parts, "DecalDark", 1.12)
        cyl(D, bf.at(a, 1.47 + 0.2, 0.036), tuple(bf.n), 0.05, 0.012, 6, "Steel")  # haak
        if note:
            bf.tilted(D, a, 1.2, h + 0.002, (0.2, 0.07, 0.003), -4, "Cream")
            text(D, note, 0.018, bf.at(a, 1.2, h + 0.006), tuple(bf.n), "Red", max_w=0.18, tilt=-4)
    # De drie die er hangen: schop, hamer, sleutel (hout en staal).
    a = 1.35
    bf.box(D, a, 1.55, h, (0.035, 0.48, 0.03), "Wood")
    bf.box(D, a, 1.81, h, (0.13, 0.035, 0.03), "DarkSteel")
    bf.box(D, a, 1.22, h, (0.19, 0.22, 0.012), "Steel")
    a = 2.68
    bf.box(D, a, 1.42, h, (0.035, 0.3, 0.03), "Wood")
    bf.box(D, a, 1.6, h, (0.15, 0.055, 0.05), "DarkSteel")
    a = 2.98
    bf.box(D, a, 1.45, h, (0.03, 0.29, 0.015), "Steel")
    bf.box(D, a, 1.62, h, (0.085, 0.065, 0.015), "Steel")
    bf.box(D, a, 1.27, h, (0.065, 0.065, 0.015), "Steel")
    # Werkbank (0,9 m diep): houten blad, stalen rand en poten, legplank, ladeblok.
    z0, z1 = 31.55, 34.45
    blk(P, 0.2, 1.12, 2.0, 2.07, z0, z1, "Wood")
    blk(D, 1.12, 1.15, 1.96, 2.07, z0, z1, "DarkSteel")
    blk(D, 1.06, 1.1, 1.88, 2.0, z0 + 0.05, z1 - 0.05, "Anthracite")
    for (x, z) in ((0.28, z0 + 0.08), (1.04, z0 + 0.08), (0.28, z1 - 0.08), (1.04, z1 - 0.08)):
        blk(P, x - 0.04, x + 0.04, Y0, 2.0, z - 0.04, z + 0.04, "DarkSteel")
    blk(P, 0.24, 1.08, 1.4, 1.43, z0 + 0.05, z1 - 0.05, "DarkSteel")
    blk(D, 0.26, 1.06, 1.26, 1.3, z1 - 0.1, z1 - 0.06, "DarkSteel")
    blk(D, 0.26, 1.06, 1.26, 1.3, z0 + 0.06, z0 + 0.1, "DarkSteel")
    blk(P, 0.25, 1.06, 1.45, 1.98, 31.67, 32.4, "Anthracite")
    for (y0, y1, m, out) in ((1.47, 1.63, "Red", 0.0), (1.65, 1.8, "Red", 0.18), (1.82, 1.96, "HullGrey", 0.0)):
        blk(D, 1.06 + out, 1.08 + out, y0, y1, 31.69, 32.38, m)
        blk(D, 1.08 + out, 1.1 + out, (y0 + y1) / 2 - 0.015, (y0 + y1) / 2 + 0.015, 31.95, 32.12, "Steel")
        if out:
            blk(D, 1.06, 1.06 + out, y0 + 0.01, y1 - 0.03, 31.7, 31.72, m)
            blk(D, 1.06, 1.06 + out, y0 + 0.01, y1 - 0.03, 32.35, 32.37, m)
            blk(D, 1.06, 1.06 + out, y0 + 0.01, y0 + 0.02, 31.7, 32.37, "Soot")
    # Op de legplank: gereedschapskist, rol kabel, oliekan.
    blk(P, 0.4, 0.95, 1.43, 1.66, 33.2, 33.75, "Red")
    blk(D, 0.62, 0.73, 1.66, 1.7, 33.3, 33.65, "DarkSteel")
    torus(D, (0.65, 1.47, 34.05), (0, 1, 0), 0.15, 0.03, 12, 5, "Rubber")
    cyl(D, (0.5, 1.43, 32.8), (0, 1, 0), 0.22, 0.07, 10, "Yellow")
    cyl(D, (0.5, 1.65, 32.8), (0.4, 1, 0), 0.12, 0.012, 6, "Yellow")
    # Bankschroef (held) vooraan rechts, met een houweel erin dat met tape gerepareerd wordt.
    zc = 34.0
    blk(P, 0.84, 1.16, 2.07, 2.11, zc - 0.15, zc + 0.15, "DarkSteel")
    blk(P, 0.85, 1.2, 2.11, 2.27, zc - 0.1, zc + 0.1, "Blue")
    blk(P, 0.84, 0.95, 2.27, 2.42, zc - 0.15, zc + 0.15, "Blue")
    blk(P, 1.07, 1.18, 2.27, 2.42, zc - 0.15, zc + 0.15, "Blue")
    blk(D, 0.95, 0.97, 2.29, 2.41, zc - 0.14, zc + 0.14, "Steel")
    blk(D, 1.05, 1.07, 2.29, 2.41, zc - 0.14, zc + 0.14, "Steel")
    blk(D, 0.74, 0.84, 2.3, 2.4, zc - 0.08, zc + 0.08, "DarkSteel")  # aambeeldje
    cyl(D, (1.18, 2.22, zc), (1, 0, 0), 0.24, 0.022, 8, "Steel")
    cyl(D, (1.4, 2.22, zc - 0.13), (0, 0, 1), 0.26, 0.012, 6, "Steel")
    for dz in (-0.135, 0.135):
        cyl(D, (1.4, 2.22, zc + dz - 0.02), (0, 0, 1), 0.04, 0.022, 6, "Steel")
    cyl(D, (1.01, 2.2, zc), (0, 1, 0), 0.82, 0.022, 8, "Wood")
    for y in (2.5, 2.66, 2.74):
        cyl(D, (1.01, y, zc), (0, 1, 0), 0.05, 0.027, 8, "DuctTape")
    blk(D, 0.97, 1.05, 2.98, 3.07, zc - 0.17, zc + 0.17, "DarkSteel")
    blk(D, 0.96, 1.06, 2.97, 3.08, zc - 0.05, zc + 0.05, "Yellow")
    for s in (-1, 1):
        a = math.radians(14)
        box(D, (1.01, 3.025 - math.sin(a) * 0.09, zc + s * (0.17 + math.cos(a) * 0.09)), (0.07, 0.07, 0.2),
            u=(1, 0, 0), v=(0, math.cos(a), s * math.sin(a)), m="DarkSteel")
    # Slijpmachine en een bakje bouten.
    cyl(P, (0.55, 2.19, 32.6), (0, 0, 1), 0.36, 0.08, 12, "DarkSteel")
    for z in (32.52, 32.96):
        cyl(P, (0.55, 2.19, z), (0, 0, 1), 0.07, 0.12, 12, "Anthracite")
    blk(D, 0.45, 0.65, 2.07, 2.12, 32.65, 32.9, "DarkSteel")
    blk(D, 0.55, 0.85, 2.07, 2.1, 33.25, 33.5, "Anthracite")
    for i in range(5):
        cyl(D, (0.6 + 0.05 * i, 2.1, 33.32 + 0.03 * (i % 2)), (0, 1, 0), 0.02, 0.012, 6, "Steel")
    # Bureaulamp met een gloeilamp.
    cyl(D, (0.32, 2.07, 33.0), (0, 1, 0), 0.03, 0.07, 10, "DarkSteel")
    cyl(D, (0.32, 2.1, 33.0), (0.15, 1, 0.05), 0.52, 0.014, 6, "Steel")
    cyl(D, (0.4, 2.61, 33.03), (0.9, -0.3, 0), 0.34, 0.014, 6, "Steel")
    cyl(D, (0.72, 2.5, 33.03), (0.35, -0.94, 0), 0.14, 0.045, 10, "Yellow", r2=0.11)
    cyl(D, (0.769, 2.369, 33.03), (0.35, -0.94, 0), 0.006, 0.1, 10, "Bulb")
    # Lichtbak in het nisplafond (warm).
    blk(RD, 1.5, 1.72, 3.7, 3.8, 32.1, 33.9, "Anthracite")
    blk(RD, 1.54, 1.68, 3.69, 3.7, 32.15, 33.85, "Lens")
    ctx.glow("ffd2a0", (1.6, 3.4, 33.0))
    # Upgradeterminal op de zijwand (z 31,15, kijkt +z).
    blk(P, 1.75, 2.65, 1.95, 2.85, 31.15, 31.27, "Anthracite")
    blk(D, 1.82, 2.58, 2.18, 2.76, 31.27, 31.276, "Screen")
    f = Face((0.0, Y0, 31.276), (1, 0, 0), (0, 1, 0))
    text(D, "UPGRADES", 0.05, f.at(2.2, 1.47), (0, 0, 1), "ScreenAmber", lift=0.002)
    for i, row in enumerate(("HOUWEEL MK2 ..... 450", "BOOR MK1 ........ 900", "SCANNER+ ........ 1200")):
        text(D, row, 0.026, f.at(2.2, 1.34 - i * 0.06), (0, 0, 1), "ScreenAmber", lift=0.002, max_w=0.68)
    text(D, "PRIJZEN ONDER VOORBEHOUD", 0.018, f.at(2.2, 1.06), (0, 0, 1), "ScreenAmber", lift=0.002, max_w=0.6)
    for i, m in enumerate(("LedAmber", "LedAmber", "LensRed", "LedGreen")):
        blk(D, 1.92 + i * 0.17, 2.02 + i * 0.17, 2.02, 2.1, 31.27, 31.29, m)
    ctx.col_box(1.75, 2.65, 1.95, 2.85, 31.15, 31.3)
    # Affiche op de andere zijwand (z 34,85, kijkt −z).
    sf, _ = n.side_face(True)
    sign(D, D, sf, 3.0 - 1.95, 1.55, 0.95, 1.05, [("HOUWEEL MK2", 0.08), ("NU MET HANDVAT*", 0.05), ("", 0.18),
                                                   ("*HANDVAT APART", 0.035), ("VERKRIJGBAAR", 0.035)],
         bg="Red", fg="Cream", gap=0.5, h0=0.07)
    _shape(D, sf, 1.05, 1.52, 0.101, PICK, "Yellow", 0.55)
    # Rubberen mat voor de bank.
    blk(D, 1.3, 2.1, Y0 + 0.018, Y0 + 0.026, 32.0, 34.0, "Anthracite")
    for k in range(6):
        blk(D, 1.35, 2.05, Y0 + 0.026, Y0 + 0.03, 32.12 + k * 0.33, 32.2 + k * 0.33, "HullDark")
    ctx.col_box(0.2, 1.2, Y0, 2.1, z0, z1)


# --- Uitgifte: balie met rolluik en luik, rekken met dozen ----------------------------------------------

def niche_supply(ctx, S, R, PN, D, RD, P, rng):
    n = Niche("Niche_Supply", *NICHES["Niche_Supply"])
    shell(ctx, S, R, PN, D, RD, P, n, rng, "UITGIFTE", "LedGreen", back_skip=lambda a, c: c < 1.95)
    # Rek tegen de achterwand.
    for x in (0.22, 0.72):
        for z in (35.4, 36.95, 38.5):
            blk(P, x - 0.02, x + 0.02, Y0, 3.1, z - 0.02, z + 0.02, "DarkSteel")
    shelves = (1.32, 1.82, 2.32, 2.82)
    for y in shelves:
        blk(P, 0.2, 0.76, y, y + 0.025, 35.38, 38.52, "DarkSteel")
        blk(D, 0.74, 0.76, y + 0.025, y + 0.06, 35.38, 38.52, "Yellow")
    items = [
        (0, 35.5, 36.2, 0.32, "Cardboard", "TOUW"), (0, 36.35, 36.9, 0.4, "Cardboard", "SCANNERS"),
        (0, 37.05, 37.6, 0.28, "GreyGreen", ""), (0, 37.7, 38.4, 0.36, "Cardboard", "LADDERS?"),
        (1, 35.45, 36.0, 0.3, "Cardboard", "HELMLAMPEN"), (1, 36.1, 36.85, 0.42, "DarkSteel", ""),
        (1, 37.6, 38.45, 0.3, "Cardboard", "WALKIETALKIES"),
        (2, 35.5, 36.3, 0.36, "Cardboard", "DEFECT"), (2, 37.1, 37.7, 0.24, "Cardboard", ""),
        (2, 37.75, 38.45, 0.38, "Yellow", "RESERVE"),
        (3, 35.45, 36.1, 0.22, "Cardboard", ""), (3, 36.2, 37.2, 0.28, "Cardboard", "ARCHIEF 2163"),
    ]
    for (k, za, zb, hh, m, label) in items:
        y = shelves[k] + 0.025
        blk(P if m != "Cardboard" else D, 0.26, 0.7, y, y + hh, za, zb, m)
        if label:
            text(D, label, min(0.045, hh * 0.25), (0.7, y + hh * 0.55, (za + zb) / 2), (1, 0, 0),
                 "DecalDark" if m != "DarkSteel" else "Yellow", max_w=(zb - za) * 0.85)
    torus(D, (0.48, shelves[1] + 0.06, 37.25), (0, 1, 0), 0.16, 0.045, 12, 5, "Wood")
    for i in range(3):  # helmlampen
        z = 36.95 + i * 0.2
        cyl(D, (0.48, shelves[2] + 0.025, z), (0, 1, 0), 0.08, 0.07, 10, "Yellow")
        cyl(D, (0.55, shelves[2] + 0.07, z), (1, 0, 0), 0.03, 0.03, 8, "Lens" if i != 1 else "DarkSteel")
    # Kist met een rol touw, ladder tegen de zijwand.
    blk(P, 0.88, 1.38, Y0, 1.62, 35.35, 35.9, "DarkSteel")
    torus(D, (1.13, 1.67, 35.62), (0, 1, 0), 0.17, 0.05, 12, 5, "Wood")
    for x in (1.0, 1.42):
        cyl(D, (x, Y0, 38.55), (0, 1, 0.1), 2.2, 0.022, 6, "Steel")
    for i in range(7):
        y = Y0 + 0.25 + i * 0.28
        cyl(D, (1.0, y, 38.55 + (y - Y0) * 0.1), (1, 0, 0), 0.42, 0.014, 6, "Steel")
    # Balie (0,9 m) met een stalen blad en een gele rand.
    blk(P, 1.8, 2.42, Y0, 2.02, 35.5, 38.5, "Anthracite")
    blk(P, 1.72, 2.5, 2.02, 2.08, 35.45, 38.55, "DarkSteel")
    blk(D, 2.5, 2.52, 2.03, 2.08, 35.45, 38.55, "Yellow")
    cf = Face((2.42, Y0, 38.5), (0, 0, -1), (0, 1, 0))  # voorkant van de balie (kijkt +x), a = 38,5 − z
    panel_wall(PN, cf, [0.0, 0.95, 2.05, 3.0], [(0.1, 0.82, "HullDark")], rng,
               skip=lambda a, c: 1.0 < a < 2.0, lift=0.03, ch=0.02)
    cf.box(D, 1.5, 0.05, 0.0, (3.0, 0.1, 0.01), "Hazard")
    # Uitgifteluik: geel-zwart kader, donker gat, schuine klep (wat je koopt, glijdt hieruit).
    for (da, dc, w, hh) in ((0, 0.65, 0.68, 0.04), (0, 0.3, 0.68, 0.04), (-0.32, 0.475, 0.04, 0.31), (0.32, 0.475, 0.04, 0.31)):
        cf.box(D, 1.5 + da, dc, 0.0, (w, hh, 0.015), "Hazard")
    cf.box(D, 1.5, 0.475, 0.0, (0.6, 0.31, 0.004), "Soot")
    s30, c30 = math.sin(math.radians(30)), math.cos(math.radians(30))
    box(D, (2.43 + s30 * 0.15, 1.85 - c30 * 0.15, 37.0), (0.58, 0.3, 0.015), u=(0, 0, 1), v=(-s30, c30, 0),
        m="DarkSteel")
    text(D, "UITGIFTELUIK", 0.035, cf.at(1.5, 0.74, 0.0), (1, 0, 0), "Yellow")
    # Een pakje dat net uit het luik glijdt (wat je koopt, komt hieruit).
    blk(D, 2.3, 2.62, 1.52, 1.58, 36.86, 37.16, "Cardboard")
    blk(D, 2.3, 2.622, 1.58, 1.584, 36.99, 37.03, "DuctTape")
    # Prijslijst op de zijwand (z 35,15, kijkt +z), voor de balie.
    blk(P, 2.08, 2.92, 2.35, 3.25, 35.15, 35.2, "Anthracite")
    blk(D, 2.12, 2.88, 2.39, 3.21, 35.2, 35.204, "Screen")
    pf = Face((0.0, Y0, 35.204), (1, 0, 0), (0, 1, 0))
    text(D, "PRIJZEN", 0.05, pf.at(2.5, 1.9), (0, 0, 1), "ScreenAmber", lift=0.002)
    for i, row in enumerate(("TOUW .......... 40", "HELMLAMP ...... 75", "LADDER ....... 120", "SCANNER ...... 300",
                             "WALKIETALKIE . 150")):
        text(D, row, 0.024, pf.at(2.5, 1.76 - i * 0.075), (0, 0, 1), "ScreenAmber", lift=0.002, max_w=0.66)
    text(D, "ONDER VOORBEHOUD", 0.018, pf.at(2.5, 1.27), (0, 0, 1), "LensRed", lift=0.002)
    sign(D, D, cf, 2.55, 0.62, 0.62, 0.14, [("KOSTEN VAN DIT BORDJE WORDEN", 0.018), ("INGEHOUDEN OP UW LOON", 0.018)],
         bg="Cream", fg="DecalDark", depth=0.006, gap=0.6, h0=0.05)
    # Loket: stijlen, rolluikkast, half neergelaten rolluik.
    for (za, zb) in ((35.5, 35.62), (38.38, 38.5)):
        blk(P, 1.98, 2.12, 2.08, 3.3, za, zb, "DarkSteel")
    blk(P, 1.88, 2.36, 3.3, 3.62, 35.45, 38.55, "Anthracite")
    for i in range(8):
        y = 3.27 - i * 0.065
        blk(D, 2.02, 2.06, y - 0.052, y, 35.62, 38.38, "HullGrey")
    blk(D, 2.0, 2.09, 2.72, 2.77, 35.62, 38.38, "DarkSteel")
    blk(D, 2.09, 2.12, 2.73, 2.76, 36.9, 37.1, "Steel")
    text(D, "LOKET", 0.1, (2.36, 3.46, 37.55), (1, 0, 0), "Yellow")
    text(D, "OPEN: DI 10:00 - 10:05", 0.035, (2.36, 3.36, 37.55), (1, 0, 0), "Cream")
    blk(D, 2.36, 2.38, 3.33, 3.59, 35.7, 36.4, "Screen")
    text(D, "NU: 12", 0.06, (2.38, 3.51, 36.05), (1, 0, 0), "ScreenAmber", lift=0.002)
    text(D, "U: 4818", 0.045, (2.38, 3.4, 36.05), (1, 0, 0), "ScreenAmber", lift=0.002)
    # Op de balie: bel, kaartje, nummerautomaat.
    cyl(D, (2.3, 2.08, 36.0), (0, 1, 0), 0.015, 0.06, 10, "DarkSteel")
    cyl(D, (2.3, 2.095, 36.0), (0, 1, 0), 0.05, 0.05, 10, "Steel", r2=0.015)
    box(D, (2.38, 2.15, 36.35), (0.012, 0.12, 0.26), u=(0.97, 0.26, 0), v=(-0.26, 0.97, 0), m="Cream")
    lines(D, [("BEL VOOR SERVICE", 0.02), ("SERVICE NIET GEGARANDEERD", 0.013)], (2.388, 2.152, 36.35),
          (0.97, 0.26, 0), "DecalDark", up=(-0.26, 0.97, 0), gap=0.7)
    cyl(D, (2.38, 2.08, 38.25), (0, 1, 0), 0.48, 0.02, 6, "DarkSteel")
    blk(D, 2.32, 2.44, 2.56, 2.72, 38.17, 38.33, "Red")
    blk(D, 2.44, 2.46, 2.6, 2.62, 38.22, 38.28, "Cream")
    text(D, "NEEM EEN NUMMER", 0.022, (2.44, 2.68, 38.25), (1, 0, 0), "Cream", max_w=0.15)
    # Hanglamp boven de balie.
    cyl(D, (1.3, 3.36, 37.0), (0, 1, 0), 0.44, 0.008, 6, "Rubber")
    cyl(D, (1.3, 3.36, 37.0), (0, -1, 0), 0.16, 0.05, 12, "Anthracite", r2=0.2)
    cyl(D, (1.3, 3.2, 37.0), (0, -1, 0), 0.006, 0.17, 12, "Bulb")
    ctx.glow("ffd6aa", (1.35, 3.05, 37.0))
    # Op de vloer: wachtlijn.
    blk(D, 2.82, 2.88, Y0 + 0.018, Y0 + 0.022, 35.9, 38.1, "Yellow")
    text(D, "WACHT HIER", 0.07, (2.68, Y0 + 0.02, 37.0), (0, 1, 0), "Yellow", up=(-1, 0, 0))
    ctx.col_box(1.72, 2.52, Y0, 3.62, 35.45, 38.55)
    ctx.col_box(0.18, 0.78, Y0, 3.1, 35.36, 38.54)
    ctx.col_box(0.88, 1.38, Y0, 1.62, 35.35, 35.9)


# --- Vrij A: IN AANBOUW (steiger voor een gestripte wand) ----------------------------------------------

def niche_free_a(ctx, S, R, PN, D, RD, P, rng):
    n = Niche("Niche_Free_A", *NICHES["Niche_Free_A"])
    bf = n.back_face()  # a = z − 31,15
    strip = (0.8, 2.6, 0.4, 1.85)
    shell(ctx, S, R, PN, D, RD, P, n, rng, "IN AANBOUW", "LensOrange",
          back_skip=lambda a, c: strip[0] - 0.1 < a < strip[1] + 0.1 and strip[2] - 0.1 < c < strip[3] + 0.1)
    # Gestripte wand: kale plaat, spanten, isolatie (één hangt los), kabels die eruit hangen.
    a0, a1, c0, c1 = strip
    bf.box(D, (a0 + a1) / 2, (c0 + c1) / 2, 0.0, (a1 - a0, c1 - c0, 0.004), "Soot")
    for a in (0.9, 1.5, 2.1, 2.5):
        bf.plate(PN, a - 0.04, a + 0.04, c0, c1, 0.0, 0.12, 0.015, "DarkSteel")
    for (a, c, ang) in ((1.2, 1.4, 0), (1.8, 0.85, 0), (1.8, 1.45, 0), (2.3, 1.1, 14)):
        bf.tilted(PN, a, c, 0.004, (0.5, 0.52, 0.07), ang, "Padded")
    for (aa, ab, sag, m) in ((1.0, 1.4, 0.35, "Red"), (1.6, 2.0, 0.55, "Rubber"), (2.15, 2.4, 0.25, "Yellow")):
        cable(D, bf.at(aa, c1 - 0.05, 0.08), bf.at(ab, c1 - 0.1, 0.08), sag, 0.016, 6, m)
    tape(D, bf, 3.0, 0.7, 3.5, 1.2, 0.07, 0.06)
    tape(D, bf, 3.0, 1.2, 3.5, 0.7, 0.074, 0.06)
    # Steiger: staanders, liggers, kortelingen, schoor, planken, voetplaten.
    xf, xb = 18.95, 19.6
    zs = (31.5, 33.0, 34.5)
    for x in (xf, xb):
        for z in zs:
            cyl(D, (x, Y0, z), (0, 1, 0), 2.45, 0.025, 6, "Steel")
            blk(D, x - 0.07, x + 0.07, Y0 + 0.016, Y0 + 0.03, z - 0.07, z + 0.07, "DarkSteel")
        for y in (1.35, 2.35, 3.35):
            cyl(D, (x, y, zs[0] - 0.08), (0, 0, 1), 3.16, 0.022, 6, "Steel")
    for z in zs:
        cyl(D, (xf - 0.06, 2.35, z), (1, 0, 0), 0.72, 0.022, 6, "Steel")
    d = (0.0, 2.0, 1.5)
    ln = math.hypot(d[1], d[2])
    cyl(D, (xf, 1.35, 33.0), (0, d[1] / ln, d[2] / ln), ln, 0.02, 6, "Steel")
    for i in range(3):
        x0 = 18.92 + i * 0.235
        blk(P, x0, x0 + 0.215, 2.38, 2.42, 31.42, 33.08, "Wood")
    cyl(D, (19.3, 2.42, 31.85), (0, 1, 0), 0.22, 0.12, 12, "Panel", r2=0.14)
    blk(P, 19.12, 19.5, 2.42, 2.62, 32.35, 32.85, "Red")
    for y in (1.62, 1.72, 1.82):
        cyl(D, (xf, y, 33.0), (0, 1, 0), 0.05, 0.03, 6, "Hazard")
    # Borden op de steiger (naar het dek).
    sf = Face((xf - 0.04, Y0, 31.15), (0, 0, 1), (0, 1, 0))
    sign(P, D, sf, 2.6, 1.55, 1.3, 0.62, [("IN AANBOUW", 0.11), ("BETREDEN OP EIGEN KOSTEN", 0.035)],
         bg="Yellow", fg="DecalDark", border="Hazard", gap=0.6)
    sign(P, D, sf, 1.1, 1.9, 1.25, 0.42, [("BINNENKORT:", 0.06), ("IETS WAT U", 0.05), ("ZELF BETAALT", 0.05)],
         bg="DecalLight", fg="DecalDark", tilt=3, gap=0.4)
    for z in (31.75, 32.75):
        cyl(D, (xf - 0.03, 3.27, z), (0, 1, 0), 0.1, 0.006, 4, "Steel")
    # Kisten bij de opening, bok met geel-zwart.
    blk(P, 17.35, 18.15, Y0, 1.8, 34.0, 34.75, "Wood")
    for (x, z) in ((17.35, 34.0), (18.15, 34.0), (17.35, 34.75), (18.15, 34.75)):
        blk(D, x - 0.03, x + 0.03, Y0, 1.8, z - 0.03, z + 0.03, "DarkSteel")
    lines(D, [("NIET OPENEN", 0.05), ("VOOR Q7", 0.05)], (17.346, 1.5, 34.375), (-1, 0, 0), "DecalDark", gap=0.4)
    box(P, (17.75, 2.02, 34.35), (0.6, 0.44, 0.55), u=(math.cos(0.18), 0, math.sin(0.18)), v=(0, 1, 0), m="GreyGreen")
    text(D, "BREEKBAAR (WSL.)", 0.035, (17.75, 2.25, 34.35), (0, 1, 0), "DecalDark", up=(0, 0, -1), max_w=0.5)
    ctx.col_box(17.32, 18.2, Y0, 2.25, 33.95, 34.8)
    blk(D, 18.3, 18.42, 1.95, 2.05, 31.4, 32.7, "Hazard")
    for z in (31.5, 32.6):
        for dx in (-0.2, 0.2):
            dd = (-dx, 0.8, 0.0)
            ln = math.hypot(dx, 0.8)
            cyl(D, (18.36 + dx, Y0, z), (dd[0] / ln, dd[1] / ln, 0), ln, 0.02, 6, "Steel")
    ctx.col_box(18.1, 18.6, Y0, 2.05, 31.4, 32.7)
    # Bouwlamp in een kooi aan het plafond.
    cyl(D, (18.2, 3.24, 33.2), (0, 1, 0), 0.56, 0.008, 4, "Rubber")
    cyl(D, (18.2, 3.2, 33.2), (0, 1, 0), 0.05, 0.06, 8, "DarkSteel")
    cyl(D, (18.2, 3.06, 33.2), (0, 1, 0), 0.14, 0.035, 8, "Bulb")
    for k in range(4):
        t = k * math.pi / 2
        cyl(D, (18.2 + 0.06 * math.cos(t), 3.04, 33.2 + 0.06 * math.sin(t)), (0, 1, 0), 0.17, 0.005, 4, "DarkSteel")
    torus(D, (18.2, 3.04, 33.2), (0, 1, 0), 0.06, 0.006, 8, 4, "DarkSteel")
    ctx.glow("ffe2b0", (18.2, 2.95, 33.2))
    # Vloer: afdekzeil, verfspatten, geel-zwarte drempel.
    box(D, (19.25, Y0 + 0.02, 33.0), (1.1, 0.006, 3.3), u=(math.cos(0.03), 0, math.sin(0.03)), v=(0, 1, 0), m="Cream")
    for (x, z, r, m) in ((19.0, 32.2, 0.08, "Yellow"), (19.5, 33.6, 0.05, "Red"), (19.2, 34.1, 0.06, "Yellow")):
        cyl(D, (x, Y0 + 0.023, z), (0, 1, 0), 0.003, r, 8, m)
    blk(D, 17.0, 17.22, Y0 + 0.018, Y0 + 0.022, 31.4, 34.6, "Hazard")


# --- Vrij B: BINNENKORT (ladder, haspel, nieuwe platen, bouwlamp) ---------------------------------------

def niche_free_b(ctx, S, R, PN, D, RD, P, rng):
    n = Niche("Niche_Free_B", *NICHES["Niche_Free_B"])
    bf = n.back_face()  # a = z − 35,15
    hole = (1.3, 2.7, 0.45, 1.2)  # ontbrekende plaat
    shell(ctx, S, R, PN, D, RD, P, n, rng, "BINNENKORT", "LensOrange",
          back_skip=lambda a, c: (hole[0] < a < hole[1] and hole[2] < c < hole[3]) or (2.6 < a < 3.7 and 0.9 < c < 1.8))
    # Waar een plaat ontbreekt: kaal, met gespoten tekst; een scheve plaat hangt aan één hoek.
    bf.box(D, (hole[0] + hole[1]) / 2, (hole[2] + hole[3]) / 2, 0.0, (hole[1] - hole[0], hole[3] - hole[2], 0.004), "Soot")
    text(D, "HIER KOMT IETS", 0.065, bf.at(2.0, 0.95, 0.004), tuple(bf.n), "Red", tilt=4, max_w=1.2)
    bf.box(D, 2.0, 0.75, 0.006, (0.5, 0.03, 0.002), "Red")
    bf.tilted(D, 2.25, 0.72, 0.006, (0.12, 0.03, 0.002), -35, "Red")
    bf.tilted(PN, 3.1, 1.32, 0.0, (0.9, 0.75, 0.04), 8, "GreyGreen")
    tape(D, bf, 2.6, 1.6, 2.9, 1.75, 0.045, 0.06)
    sign(D, D, bf, 2.0, 1.55, 1.2, 0.5, [("UPGRADE IN ONTWIKKELING", 0.045), ("OPLEVERING: BINNENKORT*", 0.04),
                                         ("*BINNENKORT IS GEEN DATUM", 0.025)], bg="Yellow", fg="DecalDark", gap=0.6,
         h0=0.07)
    # Trapladder (A-vorm) tegen de achterwand, opzij.
    zl = (35.5, 35.95)
    for z in zl:
        cyl(D, (18.95, Y0, z), (0.25 / 1.57, 1.55 / 1.57, 0), 1.57, 0.022, 6, "Steel")
        cyl(D, (19.6, Y0, z), (-0.3 / 1.58, 1.55 / 1.58, 0), 1.58, 0.022, 6, "Steel")
    for i in range(5):
        y = Y0 + 0.3 + i * 0.28
        x = 18.95 + (y - Y0) * 0.25 / 1.55
        cyl(D, (x, y, zl[0]), (0, 0, 1), 0.45, 0.016, 6, "Steel")
        box(D, (x + 0.02, y + 0.012, 35.725), (0.07, 0.012, 0.43), m="DarkSteel")
    blk(P, 19.12, 19.42, 2.72, 2.82, 35.45, 36.0, "Yellow")
    blk(D, 19.16, 19.38, 2.82, 2.94, 35.6, 35.85, "DarkSteel")
    ctx.col_box(18.9, 19.65, Y0, 2.85, 35.45, 36.0)
    # Kabelhaspel (staand), en nieuwe wandplaten tegen de zijwand (in vier kleuren).
    cyl(P, (17.8, Y0, 35.78), (0, 1, 0), 0.05, 0.38, 14, "Wood")
    cyl(P, (17.8, Y0 + 0.05, 35.78), (0, 1, 0), 0.47, 0.32, 14, "Rubber")
    cyl(P, (17.8, Y0 + 0.52, 35.78), (0, 1, 0), 0.05, 0.38, 14, "Wood")
    cable(D, (18.1, Y0 + 0.3, 35.95), (18.6, Y0 + 0.02, 36.6), 0.05, 0.02, 5, "Rubber")
    ctx.col_box(17.4, 18.2, Y0, 1.8, 35.38, 36.18)
    for i, m in enumerate(("GreyGreen", "RedOxide", "HullLight", "Yellow")):
        zb = 38.42 + i * 0.06
        box(P, (19.1, 2.0, zb + 0.12), (0.95, 1.6, 0.035), u=(1, 0, 0), v=(0, 1, 0.15), m=m)
    ctx.col_box(18.6, 19.6, Y0, 2.8, 38.45, 38.85)
    # Bouwlamp op een driepoot, gericht op het bord.
    hub = (18.62, 2.0, 37.95)
    for k in range(3):
        t = k * 2 * math.pi / 3 + 0.4
        foot = (hub[0] + 0.32 * math.cos(t), Y0, hub[2] + 0.32 * math.sin(t))
        d = (hub[0] - foot[0], hub[1] - foot[1], hub[2] - foot[2])
        ln = math.sqrt(sum(v * v for v in d))
        cyl(D, foot, tuple(v / ln for v in d), ln, 0.016, 6, "DarkSteel")
    cyl(D, hub, (0, 1, 0), 0.62, 0.02, 6, "DarkSteel")
    u = (0.8, 0, -0.6)
    box(P, (18.67, 2.66, 37.91), (0.12, 0.26, 0.36), u=u, v=(0, 1, 0), m="Yellow")
    box(D, (18.67 + u[0] * 0.065, 2.66, 37.91 + u[2] * 0.065), (0.012, 0.2, 0.3), u=u, v=(0, 1, 0), m="LedWhite")
    cable(D, (18.62, 2.0, 37.95), (19.4, Y0 + 0.02, 38.3), 0.4, 0.014, 8, "Rubber")
    ctx.glow("fff0d0", (19.05, 2.6, 37.55))
    ctx.col_box(18.27, 18.97, Y0, 2.8, 37.6, 38.3)
    # Verfpotten en een rollerbak.
    for (x, z, m) in ((19.35, 36.75, "Red"), (19.55, 37.0, "Blue")):
        cyl(D, (x, Y0, z), (0, 1, 0), 0.18, 0.09, 10, m)
        cyl(D, (x, Y0 + 0.18, z), (0, 1, 0), 0.012, 0.092, 10, "DarkSteel")
    box(D, (19.3, Y0 + 0.05, 37.35), (0.3, 0.06, 0.4), u=(1, 0, 0), v=(0, 1, -0.15), m="DarkSteel")
    blk(D, 17.0, 17.22, Y0 + 0.018, Y0 + 0.022, 35.4, 38.6, "Hazard")


def build_niches(ctx, S, R, PN, D, RD, P, rng):
    niche_tools(ctx, S, R, PN, D, RD, P, rng)
    niche_supply(ctx, S, R, PN, D, RD, P, rng)
    niche_free_a(ctx, S, R, PN, D, RD, P, rng)
    niche_free_b(ctx, S, R, PN, D, RD, P, rng)
