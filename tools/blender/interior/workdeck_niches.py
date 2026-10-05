"""De vier upgradenissen van het werkdek als diorama's: elk één held, een eigen licht en DIG-humor.

Niche_Tools  (x 0..3,   z 31..35): werkbank met bankschroef, schaduwbord met omtrekken.
Niche_Supply (x 0..3,   z 35..39): uitgiftebalie met rolluik en luik, rekken met dozen.
Niche_Free_A (x 17..20, z 31..35): HUMAN RESOURCES, een verlaten kantoortje achter een ketting.
Niche_Free_B (x 17..20, z 35..39): BREAK ROOM, de lounge van de directie achter een fluwelen koord.
(Tot 2026-10-05 "in aanbouw" en "binnenkort": ontwikkelaarstaal in de wereld, release-audit ui-02.)
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
    shell(ctx, S, R, PN, D, RD, P, n, rng, "TOOLS", "LedGreen",
          back_skip=lambda a, c: board[0] - 0.2 < a < board[1] + 0.2 and c > 0.6,
          side_skip=(lambda a, c: 1.5 < a < 2.6 and 0.6 < c < 1.8, None))
    # Schaduwbord: gele plaat met donkere omtrekken; wat er hangt, hangt erop. Drie zijn weg.
    ac, cc = (board[0] + board[1]) / 2, (board[2] + board[3]) / 2
    bf.box(P, ac, cc, 0.0, (board[1] - board[0] + 0.08, board[3] - board[2] + 0.08, 0.03), "DarkSteel")
    bf.box(D, ac, cc, 0.03, (board[1] - board[0], board[3] - board[2], 0.006), "Yellow")
    h = 0.037
    text(D, "SHADOW BOARD", 0.05, bf.at(ac, board[3] - 0.07, h), tuple(bf.n), "DecalDark")
    text(D, "MISSING TOOLS WILL BE DEDUCTED FROM YOUR WAGES", 0.028, bf.at(ac, board[2] + 0.05, h),
         tuple(bf.n), "DecalDark", max_w=2.3)
    tools = [(0.9, PICK, False, "IN REPAIR"), (1.35, SHOVEL, True, None), (1.85, DRILL, False, "MISSING"),
             (2.3, SCANNER, False, "LENT TO: ???"), (2.68, HAMMER, True, None), (2.98, WRENCH, True, None)]
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
    for i, row in enumerate(("PICKAXE MK2 .... €450", "DRILL MK1 ...... €900", "SCANNER+ ..... €1,200")):
        text(D, row, 0.026, f.at(2.2, 1.34 - i * 0.06), (0, 0, 1), "ScreenAmber", lift=0.002, max_w=0.68)
    text(D, "PRICES SUBJECT TO CHANGE", 0.018, f.at(2.2, 1.06), (0, 0, 1), "ScreenAmber", lift=0.002, max_w=0.6)
    for i, m in enumerate(("LedAmber", "LedAmber", "LensRed", "LedGreen")):
        blk(D, 1.92 + i * 0.17, 2.02 + i * 0.17, 2.02, 2.1, 31.27, 31.29, m)
    ctx.col_box(1.75, 2.65, 1.95, 2.85, 31.15, 31.3)
    # Affiche op de andere zijwand (z 34,85, kijkt −z).
    sf, _ = n.side_face(True)
    sign(D, D, sf, 3.0 - 1.95, 1.55, 0.95, 1.05, [("PICKAXE MK2", 0.08), ("NOW WITH HANDLE*", 0.05), ("", 0.26),
                                                   ("*HANDLE SOLD", 0.035), ("SEPARATELY", 0.035)],
         bg="Red", fg="Cream", gap=0.5, h0=0.07)
    _shape(D, sf, 1.05, 1.54, 0.101, PICK, "Yellow", 0.55)
    # Rubberen mat voor de bank.
    blk(D, 1.3, 2.1, Y0 + 0.018, Y0 + 0.026, 32.0, 34.0, "Anthracite")
    for k in range(6):
        blk(D, 1.35, 2.05, Y0 + 0.026, Y0 + 0.03, 32.12 + k * 0.33, 32.2 + k * 0.33, "HullDark")
    ctx.col_box(0.2, 1.2, Y0, 2.1, z0, z1)


# --- Uitgifte: balie met rolluik en luik, rekken met dozen ----------------------------------------------

def niche_supply(ctx, S, R, PN, D, RD, P, rng):
    n = Niche("Niche_Supply", *NICHES["Niche_Supply"])
    shell(ctx, S, R, PN, D, RD, P, n, rng, "SUPPLIES", "LedGreen", back_skip=lambda a, c: c < 1.95)
    # Rek tegen de achterwand.
    for x in (0.22, 0.72):
        for z in (35.4, 36.95, 38.5):
            blk(P, x - 0.02, x + 0.02, Y0, 3.1, z - 0.02, z + 0.02, "DarkSteel")
    shelves = (1.32, 1.82, 2.32, 2.82)
    for y in shelves:
        blk(P, 0.2, 0.76, y, y + 0.025, 35.38, 38.52, "DarkSteel")
        blk(D, 0.74, 0.76, y + 0.025, y + 0.06, 35.38, 38.52, "Yellow")
    items = [
        (0, 35.5, 36.2, 0.32, "Cardboard", "ROPE"), (0, 36.35, 36.9, 0.4, "Cardboard", "SCANNERS"),
        (0, 37.05, 37.6, 0.28, "GreyGreen", ""), (0, 37.7, 38.4, 0.36, "Cardboard", "LADDERS?"),
        (1, 35.45, 36.0, 0.3, "Cardboard", "HEADLAMPS"), (1, 36.1, 36.85, 0.42, "DarkSteel", ""),
        (1, 37.6, 38.45, 0.3, "Cardboard", "WALKIE-TALKIES"),
        (2, 35.5, 36.3, 0.36, "Cardboard", "BROKEN"), (2, 37.1, 37.7, 0.24, "Cardboard", ""),
        (2, 37.75, 38.45, 0.38, "Yellow", "SPARE"),
        (3, 35.45, 36.1, 0.22, "Cardboard", ""), (3, 36.2, 37.2, 0.28, "Cardboard", "ARCHIVE 2163"),
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
    text(D, "SUPPLY HATCH", 0.035, cf.at(1.5, 0.74, 0.0), (1, 0, 0), "Yellow")
    # Een pakje dat net uit het luik glijdt (wat je koopt, komt hieruit).
    blk(D, 2.3, 2.62, 1.52, 1.58, 36.86, 37.16, "Cardboard")
    blk(D, 2.3, 2.622, 1.58, 1.584, 36.99, 37.03, "DuctTape")
    # Prijslijst op de zijwand (z 35,15, kijkt +z), voor de balie.
    blk(P, 2.08, 2.92, 2.35, 3.25, 35.15, 35.2, "Anthracite")
    blk(D, 2.12, 2.88, 2.39, 3.21, 35.2, 35.204, "Screen")
    pf = Face((0.0, Y0, 35.204), (1, 0, 0), (0, 1, 0))
    text(D, "PRICES", 0.05, pf.at(2.5, 1.9), (0, 0, 1), "ScreenAmber", lift=0.002)
    for i, row in enumerate(("ROPE ......... €40", "HEADLAMP ..... €75", "LADDER ...... €120", "SCANNER ..... €300",
                             "WALKIE-TALKIE €150")):
        text(D, row, 0.024, pf.at(2.5, 1.76 - i * 0.075), (0, 0, 1), "ScreenAmber", lift=0.002, max_w=0.66)
    text(D, "SUBJECT TO CHANGE", 0.018, pf.at(2.5, 1.27), (0, 0, 1), "LensRed", lift=0.002)
    sign(D, D, cf, 2.55, 0.62, 0.62, 0.14, [("NO RETURNS", 0.018), ("NO EXCHANGES EITHER", 0.018)],
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
    text(D, "COUNTER", 0.1, (2.36, 3.46, 37.55), (1, 0, 0), "Yellow")
    text(D, "OPEN: TUE 10:00 - 10:05", 0.035, (2.36, 3.36, 37.55), (1, 0, 0), "Cream")
    blk(D, 2.36, 2.38, 3.33, 3.59, 35.7, 36.4, "Screen")
    text(D, "NOW: 12", 0.06, (2.38, 3.51, 36.05), (1, 0, 0), "ScreenAmber", lift=0.002)
    text(D, "YOU: 4818", 0.045, (2.38, 3.4, 36.05), (1, 0, 0), "ScreenAmber", lift=0.002)
    # Op de balie: bel, kaartje, nummerautomaat.
    cyl(D, (2.3, 2.08, 36.0), (0, 1, 0), 0.015, 0.06, 10, "DarkSteel")
    cyl(D, (2.3, 2.095, 36.0), (0, 1, 0), 0.05, 0.05, 10, "Steel", r2=0.015)
    box(D, (2.38, 2.15, 36.35), (0.012, 0.12, 0.26), u=(0.97, 0.26, 0), v=(-0.26, 0.97, 0), m="Cream")
    lines(D, [("RING FOR SERVICE", 0.02), ("SERVICE NOT GUARANTEED", 0.013)], (2.388, 2.152, 36.35),
          (0.97, 0.26, 0), "DecalDark", up=(-0.26, 0.97, 0), gap=0.7, max_w=0.23)
    cyl(D, (2.38, 2.08, 38.25), (0, 1, 0), 0.48, 0.02, 6, "DarkSteel")
    blk(D, 2.32, 2.44, 2.56, 2.72, 38.17, 38.33, "Red")
    blk(D, 2.44, 2.46, 2.6, 2.62, 38.22, 38.28, "Cream")
    text(D, "TAKE A NUMBER", 0.022, (2.44, 2.68, 38.25), (1, 0, 0), "Cream", max_w=0.15)
    # Hanglamp boven de balie.
    cyl(D, (1.3, 3.36, 37.0), (0, 1, 0), 0.44, 0.008, 6, "Rubber")
    cyl(D, (1.3, 3.36, 37.0), (0, -1, 0), 0.16, 0.05, 12, "Anthracite", r2=0.2)
    cyl(D, (1.3, 3.2, 37.0), (0, -1, 0), 0.006, 0.17, 12, "Bulb")
    ctx.glow("ffd6aa", (1.35, 3.05, 37.0))
    # Op de vloer: wachtlijn.
    blk(D, 2.82, 2.88, Y0 + 0.018, Y0 + 0.022, 35.9, 38.1, "Yellow")
    text(D, "WAIT HERE", 0.07, (2.68, Y0 + 0.02, 37.0), (0, 1, 0), "Yellow", up=(-1, 0, 0))
    ctx.col_box(1.72, 2.52, Y0, 3.62, 35.45, 38.55)
    ctx.col_box(0.18, 0.78, Y0, 3.1, 35.36, 38.54)
    ctx.col_box(0.88, 1.38, Y0, 1.62, 35.35, 35.9)


# --- Vrij A: HUMAN RESOURCES (een verlaten kantoortje achter een ketting) ------------------------------
# Release-audit ui-02/binnen-13: geen "in aanbouw" of "binnenkort" meer, maar een afgewerkte DIG-kamer
# zonder belofte. De nis blijft een haakpunt (Niche_Free_A in het midden van de vloer): wat F1 hier later
# zet, vervangt deze aankleding. De uitlegbox van het spel (Ekster._free_ahead) komt vóór het bureau.

def _stanchion(D, x, z, base, post, top, h=0.92):
    """Paaltje voor een afzetting: voet, paal, kop."""
    cyl(D, (x, Y0, z), (0, 1, 0), 0.045, 0.16, 12, base)
    cyl(D, (x, Y0 + 0.045, z), (0, 1, 0), h - 0.06, 0.032, 10, post)
    cyl(D, (x, Y0 + h - 0.02, z), (0, 1, 0), 0.06, 0.05, 10, top)


def _plant(D, P, x, z, dead):
    """Kamerplant in een pot: dood (bruin, hangend) of levend (groen, rechtop)."""
    cyl(P, (x, Y0, z), (0, 1, 0), 0.32, 0.14, 12, "RedOxide" if dead else "Anthracite", r2=0.18)
    cyl(D, (x, Y0 + 0.29, z), (0, 1, 0), 0.02, 0.165, 12, "Soot")
    cyl(D, (x, Y0 + 0.3, z), (0, 1, 0), 0.32 if dead else 0.45, 0.014, 6, "Wood" if dead else "Green")
    leaves = 5 if dead else 7
    for k in range(leaves):
        t = 2 * math.pi * k / leaves + 0.3
        if dead:  # slap, naar beneden
            y, tilt, m = Y0 + 0.5 + 0.04 * (k % 2), -0.65, "Cardboard"
        else:
            y, tilt, m = Y0 + 0.55 + 0.08 * (k % 3), 0.55, "Green"
        dx, dz = math.cos(t), math.sin(t)
        c = (x + dx * 0.13, y + tilt * 0.06, z + dz * 0.13)
        box(D, c, (0.26, 0.012, 0.09), u=(dx, tilt * 0.6, dz), v=(-dz, 0, dx), m=m)


def niche_free_a(ctx, S, R, PN, D, RD, P, rng):
    n = Niche("Niche_Free_A", *NICHES["Niche_Free_A"])
    bf = n.back_face()  # a = z − 31,15, c = y − 1,2, kijkt naar het dek (−x)
    shell(ctx, S, R, PN, D, RD, P, n, rng, "HUMAN RESOURCES", "LensRed")
    # Vloerbedekking (versleten kantoortapijt) en een geel-zwarte drempel.
    blk(D, 18.15, 19.8, Y0 + 0.012, Y0 + 0.02, 31.6, 34.4, "GreyGreen")
    blk(D, 17.0, 17.22, Y0 + 0.018, Y0 + 0.022, 31.4, 34.6, "Hazard")
    # Bureau (naar het dek): blad, wangen en een voorpaneel.
    blk(P, 18.72, 19.36, 1.9, 1.95, 32.15, 33.85, "Wood")
    for (za, zb) in ((32.2, 32.27), (33.73, 33.8)):
        blk(P, 18.76, 19.32, Y0, 1.9, za, zb, "GreyGreen")
    blk(P, 18.76, 18.8, 1.3, 1.88, 32.27, 33.73, "GreyGreen")
    box(D, (18.758, 1.62, 33.0), (0.006, 0.05, 1.3), m="DarkSteel")  # naad
    ctx.col_box(18.72, 19.36, Y0, 1.95, 32.15, 33.85)
    # Naambordje op de rand, schuin naar het dek.
    box(D, (18.84, 1.985, 32.75), (0.07, 0.5, 0.03), u=(0.5, 0.866, 0), v=(0, 0, 1), m="Brass")
    text(D, "HEAD OF HR", 0.026, (18.818, 1.99, 32.75), (-0.866, 0.5, 0), "DecalDark", up=(0.5, 0.866, 0),
         max_w=0.42)
    # Kaartje "ben zo terug" (dat stond er al toen het schip werd gekocht).
    box(D, (18.95, 2.08, 33.25), (0.4, 0.26, 0.012), u=(0, 0, 1), v=(0.17, 0.985, 0), m="Cream")
    lines(D, [("BACK IN", 0.05), ("5 MINUTES", 0.05), ("(SINCE 2161)", 0.028)], (18.942, 2.09, 33.25),
          (-0.985, 0.17, 0), "DecalDark", up=(0.17, 0.985, 0), gap=0.45, max_w=0.34)
    # Stapel klachten, een bel zonder klepel, een mok.
    for i, (dz, hh) in enumerate(((0.0, 0.11), (0.33, 0.2), (0.62, 0.07))):
        blk(D, 19.0, 19.3, 1.95, 1.95 + hh, 32.35 + dz, 32.58 + dz, "Cream")
        blk(D, 19.0, 19.3, 1.95 + hh * 0.5, 1.95 + hh * 0.5 + 0.012, 32.35 + dz, 32.58 + dz, "Cardboard")
    text(D, "COMPLAINTS", 0.022, (18.998, 2.05, 32.795), (-1, 0, 0), "Red", max_w=0.2)
    cyl(D, (18.86, 1.95, 32.36), (0, 1, 0), 0.015, 0.045, 12, "DarkSteel")
    cyl(D, (18.86, 1.965, 32.36), (0, 1, 0), 0.04, 0.04, 12, "Steel", r2=0.012)
    cyl(D, (19.18, 1.95, 33.62), (0, 1, 0), 0.1, 0.04, 10, "Cream")
    # Bankierslamp (het enige licht dat nog brandt).
    cyl(D, (19.2, 1.95, 33.25), (0, 1, 0), 0.025, 0.07, 12, "Brass")
    cyl(D, (19.2, 1.975, 33.25), (0, 1, 0), 0.22, 0.012, 6, "Brass")
    cyl(D, (19.14, 2.2, 33.08), (0, 0, 1), 0.34, 0.07, 12, "Green")
    cyl(D, (19.14, 2.14, 33.1), (0, 0, 1), 0.3, 0.025, 8, "Bulb")
    # Het licht zelf iets vóór de lamp: anders staat alles op het bureau in tegenlicht (onleesbaar).
    ctx.glow("ffc98a", (18.7, 2.35, 33.1), e=1.1)
    # Bureaustoel, leeg, half weggedraaid.
    rot = (math.cos(0.35), 0, math.sin(0.35))
    box(P, (19.5, 1.68, 33.0), (0.44, 0.08, 0.46), u=rot, v=(0, 1, 0), m="Leather")
    box(P, (19.69, 2.02, 33.07), (0.08, 0.56, 0.44), u=rot, v=(0, 1, 0), m="Leather")
    cyl(D, (19.5, Y0 + 0.06, 33.0), (0, 1, 0), 0.38, 0.03, 8, "Steel")
    for k in range(5):
        t = 2 * math.pi * k / 5
        box(D, (19.5 + 0.15 * math.cos(t), Y0 + 0.05, 33.0 + 0.15 * math.sin(t)), (0.3, 0.03, 0.05),
            u=(math.cos(t), 0, math.sin(t)), v=(0, 1, 0), m="DarkSteel")
    # Archiefkast met vier laden (naar het dek), één staat open met papieren.
    blk(P, 19.22, 19.8, Y0, 2.62, 31.25, 31.8, "GreyGreen")
    ctx.col_box(19.22, 19.8, Y0, 2.62, 31.25, 31.8)
    labels = ("COMPLAINTS", "COMPLAINTS", "MORE COMPLAINTS", "UNREAD")
    for i, label in enumerate(labels):
        y = 2.32 - i * 0.34
        dx = -0.22 if i == 2 else 0.0  # de derde la staat open
        blk(P, 19.17 + dx, 19.22 + dx, y - 0.14, y + 0.14, 31.28, 31.77, "HullLight")
        if dx:
            blk(P, 19.0, 19.22, y - 0.14, y + 0.1, 31.3, 31.32, "HullLight")
            blk(P, 19.0, 19.22, y - 0.14, y + 0.1, 31.73, 31.75, "HullLight")
            for k in range(4):
                blk(D, 19.02 + k * 0.045, 19.035 + k * 0.045, y + 0.08, y + 0.2 + 0.02 * (k % 2), 31.34, 31.72,
                    "Cream")
        blk(D, 19.16 + dx, 19.17 + dx, y - 0.01, y + 0.02, 31.43, 31.62, "Steel")
        blk(D, 19.165 + dx, 19.17 + dx, y + 0.05, y + 0.1, 31.4, 31.65, "Cream")
        text(D, label, 0.016, (19.163 + dx, y + 0.075, 31.525), (-1, 0, 0), "DecalDark", max_w=0.22)
    # Affiche op de achterwand, boven het bureau.
    sign(D, D, bf, 1.85, 1.55, 1.15, 0.62, [("YOU ARE A", 0.06), ("VALUED ASSET", 0.1), ("(DEPRECIATING)", 0.045)],
         bg="DecalLight", fg="DecalDark", border="Red", gap=0.5, h0=0.07)
    tape(D, bf, 1.3, 1.82, 1.42, 1.9, 0.105, 0.05)
    tape(D, bf, 2.28, 1.82, 2.4, 1.9, 0.105, 0.05)
    # Dode kamerplant in de hoek.
    _plant(D, P, 19.45, 34.45, dead=True)
    # Afzetting: twee gele paaltjes met een geel-zwarte ketting en het bordje.
    for z in (31.7, 34.3):
        _stanchion(D, 17.28, z, "Yellow", "Yellow", "DarkSteel")
    cable(D, (17.28, 2.08, 31.7), (17.28, 2.08, 34.3), 0.2, 0.02, 10, "Hazard")
    ff = Face((17.25, Y0, 31.0), (0, 0, 1), (0, 1, 0))  # kijkt naar het dek (−x), a = z − 31
    for dz in (-0.22, 0.22):  # haakjes aan de ketting
        box(D, (17.265, 1.93, 33.0 + dz), (0.01, 0.07, 0.012), m="Steel")
    sign(D, D, ff, 2.0, 0.66, 0.7, 0.3, [("CLOSED", 0.09), ("NO HUMANS LEFT", 0.045)], bg="Red", fg="DecalLight",
         gap=0.45, tilt=-3)
    ctx.col_box(17.18, 17.36, Y0, 2.3, 31.55, 34.45)


# --- Vrij B: BREAK ROOM (de lounge van de directie, achter een fluwelen koord) -----------------------------

def niche_free_b(ctx, S, R, PN, D, RD, P, rng):
    n = Niche("Niche_Free_B", *NICHES["Niche_Free_B"])
    bf = n.back_face()  # a = z − 35,15
    shell(ctx, S, R, PN, D, RD, P, n, rng, "BREAK ROOM", "LensRed")
    # Rood tapijt met een gouden rand (het enige tapijt aan boord).
    blk(D, 17.9, 19.8, Y0 + 0.012, Y0 + 0.022, 35.55, 38.45, "Red")
    for (za, zb) in ((35.62, 35.66), (38.34, 38.38)):
        blk(D, 17.97, 19.73, Y0 + 0.022, Y0 + 0.026, za, zb, "Yellow")
    for x in (17.97, 19.69):
        blk(D, x, x + 0.04, Y0 + 0.022, Y0 + 0.026, 35.62, 38.38, "Yellow")
    blk(D, 17.0, 17.22, Y0 + 0.018, Y0 + 0.022, 35.4, 38.6, "Hazard")
    # Clubfauteuil (naar het dek): voet, zitting, dikke leuningen, hoge rug.
    cx, cz = 19.3, 37.35
    blk(P, cx - 0.32, cx + 0.38, Y0 + 0.08, 1.62, cz - 0.4, cz + 0.4, "Leather")
    blk(P, cx - 0.34, cx + 0.3, 1.62, 1.72, cz - 0.3, cz + 0.3, "Leather")  # kussen
    blk(P, cx + 0.22, cx + 0.42, 1.62, 2.38, cz - 0.42, cz + 0.42, "Leather")  # rug
    cyl(P, (cx + 0.32, 2.38, cz - 0.42), (0, 0, 1), 0.84, 0.1, 10, "Leather")
    for s in (-1, 1):  # leuningen met een ronde voorkant
        blk(P, cx - 0.36, cx + 0.3, 1.62, 1.86, cz + s * 0.42 - 0.08, cz + s * 0.42 + 0.08, "Leather")
        cyl(P, (cx - 0.36, 1.86, cz + s * 0.42), (1, 0, 0), 0.66, 0.08, 10, "Leather")
    for (dx, dz) in ((-0.28, -0.34), (-0.28, 0.34), (0.34, -0.34), (0.34, 0.34)):
        cyl(D, (cx + dx, Y0, cz + dz), (0, 1, 0), 0.08, 0.035, 8, "Brass")
    ctx.col_box(cx - 0.4, cx + 0.44, Y0, 2.4, cz - 0.52, cz + 0.52)
    # Bijzettafel met koffie (porselein) en een kaartje.
    tx, tz = 19.3, 36.45
    cyl(D, (tx, Y0, tz), (0, 1, 0), 0.03, 0.17, 14, "Brass")
    cyl(D, (tx, Y0 + 0.03, tz), (0, 1, 0), 0.6, 0.025, 8, "Brass")
    cyl(P, (tx, 1.83, tz), (0, 1, 0), 0.04, 0.24, 18, "Wood")
    cyl(D, (tx - 0.04, 1.87, tz + 0.06), (0, 1, 0), 0.008, 0.07, 14, "Cream")
    cyl(D, (tx - 0.04, 1.878, tz + 0.06), (0, 1, 0), 0.07, 0.035, 12, "Cream")
    box(D, (tx - 0.1, 1.92, tz - 0.08), (0.16, 0.1, 0.01), u=(0, 0, 1), v=(0.3, 0.954, 0), m="Cream")
    lines(D, [("RESERVED", 0.026), ("MANAGEMENT", 0.016)], (tx - 0.1057, 1.9218, tz - 0.08), (-0.954, 0.3, 0),
          "DecalDark", up=(0.3, 0.954, 0), gap=0.4, max_w=0.15)
    ctx.col_box(tx - 0.25, tx + 0.25, Y0, 1.87, tz - 0.25, tz + 0.25)
    # Staande lamp met een stoffen kap: warm licht, het gezelligste plekje van het schip.
    lx, lz = 19.45, 38.35
    cyl(D, (lx, Y0, lz), (0, 1, 0), 0.03, 0.16, 14, "Brass")
    cyl(D, (lx, Y0 + 0.03, lz), (0, 1, 0), 1.42, 0.018, 8, "Brass")
    cyl(D, (lx, 2.42, lz), (0, 1, 0), 0.32, 0.24, 14, "Cream", r2=0.16)
    cyl(D, (lx, 2.46, lz), (0, 1, 0), 0.12, 0.05, 10, "Bulb")
    ctx.glow("ffc07a", (lx - 0.1, 2.4, lz - 0.1), e=1.6)
    # Koelkastje met een hangslot: de lunch van de directie.
    blk(P, 19.25, 19.8, Y0, 2.0, 35.3, 35.9, "Cream")
    blk(D, 19.235, 19.25, 1.25, 1.95, 35.33, 35.87, "Cream")
    blk(D, 19.22, 19.235, 1.58, 1.62, 35.33, 35.87, "DarkSteel")
    blk(D, 19.2, 19.235, 1.7, 1.86, 35.8, 35.84, "Steel")
    blk(D, 19.18, 19.215, 1.66, 1.74, 35.76, 35.86, "Brass")  # hangslot
    torus(D, (19.2, 1.77, 35.81), (1, 0, 0), 0.03, 0.007, 10, 4, "Steel")
    box(D, (19.234, 1.86, 35.55), (0.004, 0.12, 0.34), m="DecalLight")
    lines(D, [("MANAGEMENT LUNCH", 0.02), ("DO NOT TOUCH", 0.016)], (19.231, 1.86, 35.55), (-1, 0, 0), "Red",
          gap=0.5, max_w=0.3)
    ctx.col_box(19.18, 19.8, Y0, 2.0, 35.3, 35.9)
    # Ingelijst affiche op de achterwand (koperen lijst).
    sign(D, D, bf, 2.2, 1.6, 1.1, 0.6, [("RELAX.", 0.1), ("YOU'VE EARNED IT.", 0.055), ("(NOT YOU)", 0.04)],
         bg="Cream", fg="DecalDark", border="Brass", gap=0.5, h0=0.07)
    # Levende kamerplant (de enige die water krijgt).
    _plant(D, P, 18.3, 38.5, dead=False)
    # Fluwelen koord tussen koperen paaltjes, met het bordje.
    for z in (35.7, 38.3):
        _stanchion(D, 17.28, z, "Brass", "Brass", "Brass")
    cable(D, (17.28, 2.06, 35.7), (17.28, 2.06, 38.3), 0.18, 0.026, 10, "Red")
    ff = Face((17.25, Y0, 35.0), (0, 0, 1), (0, 1, 0))  # kijkt naar het dek (−x), a = z − 35
    sign(D, D, ff, 2.0, 0.66, 0.72, 0.28, [("MANAGEMENT ONLY", 0.055), ("YOUR BREAK: QUARTER 7", 0.03)],
         bg="DecalDark", fg="Yellow", border="Brass", gap=0.5)
    ctx.col_box(17.18, 17.36, Y0, 2.3, 35.55, 38.45)


def build_niches(ctx, S, R, PN, D, RD, P, rng):
    niche_tools(ctx, S, R, PN, D, RD, P, rng)
    niche_supply(ctx, S, R, PN, D, RD, P, rng)
    niche_free_a(ctx, S, R, PN, D, RD, P, rng)
    niche_free_b(ctx, S, R, PN, D, RD, P, rng)
