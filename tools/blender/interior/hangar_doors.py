"""De baailuiken (BayDoor_L/R) in detail: platen met antislipribbels, een geel-zwarte naad in het
midden, het opschrift, sporen van de rupsen en olie onder de Mol, roet van de drops op de
binnenkant (zichtbaar als ze open hangen), en ribben en scharnierogen aan de onderkant.

Contract (layout.py, ekster.gd): oorsprong op het scharnier, en de voetafdruk in x en z blijft
EXACT die van de oude luiken (x 0,025..3,975 vanaf het scharnier, z ±6,95): Ekster bouwt de botsvorm
en de baai (`bay`) uit de AABB van de luiken. Enkel naar onder (y) mag er iets bij. De bovenkant
blijft onder de vloer (≤ −0,02 m absoluut).

Coördinaten: Godot, lokaal t.o.v. het scharnier. De plan-helpers uit hangar_kit krijgen een plek
met (7, 0, 9) erbij, zodat G() er weer de lokale plek van maakt.
"""

import math
import random

from hangar_kit import text

U0, U1 = 0.025, 3.975  # vanaf het scharnier tot de naad
ZH = 6.95  # halve lengte
TOP = -0.005  # bovenkant van de platen (lokaal; het scharnier ligt 2 cm onder de vloer)


def _plan(x, y, z):
    return (x + 7.0, y, z + 9.0)


def door_mesh(b, sx, mol_dz):
    """Luikhelft in Builder `b`. sx = +1 (bakboord, naad op x = +4) of −1 (stuurboord, naad op −4).
    mol_dz: waar het midden van de Mol staat t.o.v. het scharnier (z)."""
    rng = random.Random(41 if sx > 0 else 43)

    def B(u0, u1, y0, y1, z0, z1, m):
        x0, x1 = sorted((sx * u0, sx * u1))
        b.box(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, abs(z1 - z0)), material=m)

    # Kern: de dikke plaat (zoals vroeger) en een stalen naadlip.
    B(U0, U1, -0.1, -0.02, -ZH, ZH, "Anthracite")  # tot aan het scharnier enkel de dunne bovenplaat
    B(0.2, U1, -0.32, -0.1, -ZH, ZH, "Anthracite")  # dan pas de dikke kern (blijft open onder de vloer)
    B(3.94, U1, -0.32, TOP + 0.002, -ZH, ZH, "Steel")
    # Bovenplaten: vier stuks met naden, antislipribbels dwars.
    zs = [-6.9, -3.45, 0.0, 3.45, 6.9]
    for za, zb in zip(zs, zs[1:]):
        za, zb = za + 0.02, zb - 0.02
        B(0.14, 3.56, -0.02, TOP, za, zb, "Floor" if rng.random() > 0.2 else "HullGrey")
        z = za + 0.25
        while z < zb - 0.2:
            B(0.3, 3.4, TOP, TOP + 0.003, z - 0.02, z + 0.02, "DarkSteel")
            z += 0.42
    # Geel-zwart langs de naad (van bovenaf zie je meteen: dit gaat open) en een stalen strook aan het scharnier.
    B(3.6, 3.93, -0.02, TOP, -6.9, 6.9, "Hazard")
    B(0.03, 0.12, -0.02, TOP, -6.9, 6.9, "Steel")
    for zz in (-5.6, -2.0, 2.0, 5.6):  # tilogen (verzonken)
        B(0.5, 0.7, TOP, TOP + 0.002, zz - 0.15, zz + 0.15, "Soot")
    # Opschrift aan de buitenkant (te lezen vanaf de looproute langs de baai).
    up = (sx, 0, 0)
    text(b, "BAY 1" if sx > 0 else "MAX 14 T", 0.22, _plan(sx * 0.42, TOP + 0.003, 4.6), (0, 1, 0), up,
         "DecalDark", fit=2.0)
    text(b, "DO NOT OPEN DURING USE", 0.07, _plan(sx * 0.42, TOP + 0.003, -3.2), (0, 1, 0), up, "DecalDark",
         fit=2.6, res=1)
    # Sporen van de rupsen (de Mol staat hier tussen twee drops) en olie eronder.
    for c in (2.31, 2.69):
        B(c - 0.04, c + 0.04, TOP, TOP + 0.002, mol_dz - 3.3, mol_dz + 3.8, "Rubber")
    # Roet van de stuwraketten: een waaier op het binnenste deel (zichtbaar als de luiken open hangen).
    for k, (r, m) in enumerate(((1.6, "Anthracite"), (1.05, "Soot"), (0.55, "Soot"))):
        _blot(b, sx, 3.75 - r * 0.35, mol_dz + 0.3, r, TOP + 0.004 + k * 0.001, m, rng, squash=0.55)
    for (u, z, r) in ((3.3, mol_dz - 2.2, 0.42), (2.9, mol_dz + 2.6, 0.28), (3.5, mol_dz + 3.4, 0.2)):
        _blot(b, sx, u, z, r, TOP + 0.007, "Soot", rng)
    # Onderkant (zie je als ze open hangen): rand, ribben, een langsligger en scharnierogen.
    B(0.3, U1 - 0.02, -0.4, -0.32, -ZH + 0.02, -ZH + 0.14, "DarkSteel")
    B(0.3, U1 - 0.02, -0.4, -0.32, ZH - 0.14, ZH - 0.02, "DarkSteel")
    z = -ZH + 1.55
    while z < ZH - 1.0:
        B(0.3, 3.9, -0.4, -0.32, z - 0.05, z + 0.05, "DarkSteel")
        z += 1.6
    B(1.95, 2.05, -0.4, -0.32, -ZH + 0.14, ZH - 0.14, "DarkSteel")
    for zz in (-5.6, -2.0, 2.0, 5.6):
        x0, x1 = sorted((sx * 0.04, sx * 0.24))
        b.cyl(((x0 + x1) / 2, -0.2, zz - 0.2), (0, 0, 1), 0.4, 0.08, 12, "Steel")
        B(0.3, 0.5, -0.4, -0.32, zz - 0.25, zz + 0.25, "DarkSteel")


def _blot(b, sx, u, z, r, y, m, rng, squash=1.0):
    """Onregelmatige vlek (veelhoek) op de bovenkant, binnen de voetafdruk van het luik."""
    n = 10
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        rr = r * rng.uniform(0.7, 1.15)
        uu = min(3.93, max(0.15, u + math.cos(a) * rr * squash))
        zz = min(ZH - 0.1, max(-ZH + 0.1, z + math.sin(a) * rr))
        pts.append((sx * uu, zz))
    top = [b.bm.verts.new(_g(x, y, z_)) for x, z_ in pts]
    # Tegen de klok rond (u, z) geeft een normaal naar onder; gespiegeld (sx < 0) keert dat om.
    f = b.bm.faces.new(list(reversed(top)) if sx > 0 else top)
    f.material_index = b._mi(m)


def _g(x, y, z):
    import kit
    return kit.G(x, y, z)
