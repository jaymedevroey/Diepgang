"""Kleine rekwisieten voor de brug en de gang: goedkope monitoren, mokken, verfblikken, affiches.
DIG bespaart op alles: geen twee monitoren van hetzelfde merk, plakband, gele briefjes."""

import math

from mathutils import Vector

from bridge_kit import sphere, text
from layout import G


class Frame:
    """Lokaal assenstelsel op een plekpunt: a = naar rechts (gezien van voren), h = omhoog,
    d = naar voren (de kant waar de kijker staat)."""

    def __init__(self, origin, facing, tilt=0.0):
        self.o = Vector(origin)
        self.f = Vector(facing).normalized()
        self.u = Vector((0.0, 1.0, 0.0))
        self.r = (-self.f).cross(self.u).normalized()
        if tilt:  # graden: de voorkant kijkt omlaag, de bovenkant leunt naar de kijker
            t = math.radians(tilt)
            self.f, self.u = self.f * math.cos(t) - self.u * math.sin(t), self.u * math.cos(t) + self.f * math.sin(t)

    def p(self, a, h, d=0.0):
        return tuple(self.o + self.r * a + self.u * h + self.f * d)

    def box(self, b, a, h, d, sa, sh, sd, material, roll=0.0):
        r, u = self.r, self.u
        if roll:
            c, s = math.cos(roll), math.sin(roll)
            r, u = r * c + u * s, u * c - r * s
        b.box(G(*self.p(a, h, d)), (sa, sh, sd), r, u, material)

    def cyl(self, b, a, h, d, axis, length, radius, segs, material, r2=None):
        ax = self.r * axis[0] + self.u * axis[1] + self.f * axis[2]
        b.cyl(G(*self.p(a, h, d)), tuple(ax), length, radius, segs, material, r2)

    def text(self, b, body, size, a, h, d, material, align="CENTER"):
        text(b, body, size, self.p(a, h, d), tuple(self.f), material, align=align)


def sticky(b, fr, a, h, d, rng):
    fr.box(b, a, h, d, 0.075, 0.075, 0.004, rng.choice(["Yellow", "Yellow", "Cream"]), roll=rng.uniform(-0.25, 0.25))


def monitor(P, D, fr, a, h, d, w, hh, screen, rng, shell="Anthracite", crt=True, sad=False, taped=False):
    """Goedkope monitor: bezel in vier latten, scherm iets dieper, behuizing erachter, voet.
    (a, h, d) = midden van het scherm."""
    t = 0.035
    fr.box(P, a, h + hh / 2 + t / 2, d, w + 2 * t, t, 0.06, shell)
    fr.box(P, a, h - hh / 2 - t / 2 - 0.02, d, w + 2 * t, t + 0.04, 0.06, shell)
    fr.box(P, a - w / 2 - t / 2, h, d, t, hh, 0.06, shell)
    fr.box(P, a + w / 2 + t / 2, h, d, t, hh, 0.06, shell)
    fr.box(D, a, h, d + 0.012, w, hh, 0.006, screen)
    if crt:  # bolle achterkant, op een korte hals
        fr.box(P, a, h - 0.01, d - 0.16, w * 0.85, hh * 0.85, 0.26, shell)
        fr.box(P, a, h - 0.03, d - 0.34, w * 0.5, hh * 0.5, 0.14, shell)
        fr.box(D, a, h - hh / 2 - 0.11, d - 0.12, 0.12, 0.1, 0.12, "DarkSteel")
    else:
        fr.box(P, a, h, d - 0.05, w * 0.95, hh * 0.9, 0.05, shell)
        fr.box(D, a, h - hh / 2 - 0.08, d - 0.06, 0.06, 0.16, 0.04, "DarkSteel")
    fr.box(D, a, h - hh / 2 - 0.16, d - 0.08, w * 0.5, 0.02, 0.22, "DarkSteel")
    if sad:  # vastgelopen: een blauw scherm met een droevig gezicht
        fr.text(D, ":(", hh * 0.35, a - w * 0.22, h + hh * 0.12, d + 0.017, "Cream")
        for j in range(3):
            fr.box(D, a - w * 0.08, h - hh * 0.18 - j * hh * 0.09, d + 0.017, w * 0.6, hh * 0.035, 0.002, "Cream")
    else:  # regels tekst
        for j in range(4):
            fr.box(D, a - w * 0.1 + rng.uniform(-0.02, 0.02), h + hh * 0.3 - j * hh * 0.16, d + 0.017,
                   w * rng.uniform(0.45, 0.7), hh * 0.04, 0.002, "Soot")
    for _ in range(rng.randint(1, 3)):
        side = rng.choice([-1, 1])
        sticky(D, fr, a + side * (w / 2 + 0.01), h + rng.uniform(-hh / 3, hh / 2), d + 0.034, rng)
    if taped:  # gebarsten hoek, met plakband in een kruis
        for s in (-1, 1):
            fr.box(D, a + w * 0.32, h + hh * 0.3, d + 0.02, 0.26, 0.035, 0.003, "HullLight", roll=s * 0.7)


def mug(b, fr, a, h, d, material):
    fr.cyl(b, a, h, d, (0, 1, 0), 0.095, 0.04, 12, material)
    fr.cyl(b, a, h + 0.08, d, (0, 1, 0), 0.006, 0.033, 12, "Soot")
    fr.box(b, a + 0.05, h + 0.05, d, 0.02, 0.055, 0.012, material)


def papers(b, fr, a, h, d, rng, n=4):
    for i in range(n):
        fr.box(b, a + rng.uniform(-0.02, 0.02), h + 0.004 + i * 0.006, d + rng.uniform(-0.02, 0.02), 0.21, 0.005,
               0.29, "Cream" if i % 3 else "Panel", roll=0.0)


def keyboard(b, fr, a, h, d, w=0.42):
    fr.box(b, a, h + 0.012, d, w, 0.024, 0.15, "DarkSteel")
    fr.box(b, a - 0.03, h + 0.027, d, w - 0.1, 0.008, 0.11, "Anthracite")


def paint_can(b, x, y, z, r, hgt, color, rng):
    """Verfblik: blikken romp, gekleurd etiket, deksel met een druip."""
    b.cyl(G(x, y, z), (0, 1, 0), hgt, r, 12, "Steel")
    b.cyl(G(x, y + hgt * 0.2, z), (0, 1, 0), hgt * 0.55, r + 0.003, 12, color)
    b.cyl(G(x, y + hgt, z), (0, 1, 0), 0.006, r * 0.92, 12, color)
    a = rng.uniform(0, 2 * math.pi)
    b.box(G(x + (r + 0.002) * math.sin(a), y + hgt * 0.82, z - (r + 0.002) * math.cos(a)), (0.018, hgt * 0.3, 0.006),
          (math.cos(a), 0, math.sin(a)), (0, 1, 0), color)


def spray_can(b, x, y, z, color):
    b.cyl(G(x, y, z), (0, 1, 0), 0.17, 0.032, 10, color)
    b.cyl(G(x, y + 0.17, z), (0, 1, 0), 0.03, 0.026, 10, "Cream")
    b.cyl(G(x, y + 0.2, z), (0, 1, 0), 0.015, 0.008, 6, "DarkSteel")


def splat(b, x, y, z, r, color, rng, normal="y"):
    """Verfvlek: een plat, onregelmatig vlekje met een paar spatjes."""
    for k in range(4):
        rr = r * (1.0 if k == 0 else rng.uniform(0.15, 0.35))
        ox = 0.0 if k == 0 else rng.uniform(-1.6, 1.6) * r
        oz = 0.0 if k == 0 else rng.uniform(-1.6, 1.6) * r
        if normal == "y":
            b.cyl(G(x + ox, y, z + oz), (0, 1, 0), 0.003, rr, 9, color)
        else:  # op een wand loodrecht op x
            b.cyl(G(x, y + ox, z + oz), (1 if normal == "+x" else -1, 0, 0), 0.003, rr, 9, color)


def poster(P, D, fr, a, h, d, w, hh, lines, frame="DarkSteel", paper="Cream", ink="DecalDark"):
    """Affiche in een kader: [(tekst, grootte, hoogte_t.o.v._midden, materiaal?)]."""
    fr.box(P, a, h, d, w + 0.06, hh + 0.06, 0.03, frame)
    fr.box(D, a, h, d + 0.017, w, hh, 0.004, paper)
    for ln in lines:
        body, size, dy = ln[0], ln[1], ln[2]
        m = ln[3] if len(ln) > 3 else ink
        fr.text(D, body, size, a, h + dy, d + 0.0205, m)


def trash_bin(P, D, x, y, z, rng):
    P.cyl(G(x, y, z), (0, 1, 0), 0.42, 0.19, 16, "DarkSteel", r2=0.21)
    D.cyl(G(x, y + 0.42, z), (0, 1, 0), 0.025, 0.215, 16, "Steel")
    for k in range(4):
        sphere(D, (x + rng.uniform(-0.1, 0.1), y + 0.43 + rng.uniform(0, 0.05), z + rng.uniform(-0.1, 0.1)),
               rng.uniform(0.04, 0.06), "Cream", 1)
