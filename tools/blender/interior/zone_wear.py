"""Zone WEAR: gebruikssporen over de hele hub (release-audit binnen-12: "geen slijtage, geen vuil").

De shader (game/src/ship/hub_surface.gdshader) legt overal vuil onderaan wanden, strepen, vlekken en
kale randen. Hier staan de sporen die een verhaal vertellen, enkel waar robots echt lopen of werken:
voetsporen langs de hoofdroute (laadrek → werkdek → gang → brug → trap → Mol → poort), olie onder de
Mol en de klemmen, vuil in de hoeken, strepen onder roosters, koffie bij het koffieapparaat, verf uit de
spuitcabine. Het zijn lege punten (Decal_SOORT_wBREEDTE_lLENGTE_n, maten in cm): Godot projecteert er
een zachte decal (HubLook.add_decals), met zachte randen die een vlak polygoon niet kan geven.
Vloerdecals projecteren naar beneden (−y), wanddecals in de wand (−z van het punt, zie wall()).
Plancoördinaten (layout.py)."""

import math

from layout import Ctx, G

# Vloerhoogte per zone (bovenkant van de platen).
Y_HANGAR = 0.015
Y_RACK = 0.616
Y_DECK = 1.218
Y_BRIDGE = 1.2
# Lengte van één stuk voetspoor (vier stappen): HubLook.FEET_LENGTH, zelfde getal.
FEET_L = 1.44


def decal(ctx, kind, pos, w, l, rot_y=0.0):
    """Vloerdecal: midden op `pos` (plan), w breed (x van het punt) en l lang (z), gedraaid om y (graden)."""
    i = len(ctx.shared["anchors"])
    ctx.shared["anchors"].append((f"Decal_{kind}_w{round(w * 100)}_l{round(l * 100)}_{i}", G(*pos), (0.0, rot_y, 0.0)))


def wall(ctx, kind, pos, normal, w, l):
    """Wanddecal op een verticaal vlak met normaal `normal` (x, z): w breed langs de wand, l hoog (naar
    beneden vanaf de bovenkant van de textuur)."""
    i = len(ctx.shared["anchors"])
    ry = math.degrees(math.atan2(normal[0], normal[1]))
    ctx.shared["anchors"].append((f"Decal_{kind}_w{round(w * 100)}_l{round(l * 100)}_{i}", G(*pos), (90.0, ry, 0.0)))


def feet(ctx, pts, y, kind="feet"):
    """Voetsporen langs een gebroken lijn [(x, z), ...]: stukken van FEET_L m, in de looprichting."""
    for p, q in zip(pts, pts[1:]):
        dx, dz = q[0] - p[0], q[1] - p[1]
        ln = math.hypot(dx, dz)
        n = max(1, int(ln / FEET_L))
        ang = math.degrees(math.atan2(-dx, -dz))  # −z van het punt wijst in de looprichting
        for k in range(n):
            t = (k + 0.5) * FEET_L / ln if n * FEET_L <= ln else (k + 0.5) / n
            decal(ctx, kind, (p[0] + dx * t, y, p[1] + dz * t), 0.45, FEET_L, ang)


def build(ctx: Ctx):
    # --- Hangar en kade -------------------------------------------------------------------------------
    # Olie waar de laadklep van de Mol op de kade komt en onder de klemmen (hydrauliek lekt).
    decal(ctx, "oil", (6.9, Y_HANGAR, 16.55), 1.3, 1.0, 20)
    decal(ctx, "oil", (7.9, Y_HANGAR, 17.35), 0.4, 0.4, 70)
    for (x, z) in ((1.72, 7.4), (1.72, 12.6), (12.28, 7.2), (12.28, 12.8)):
        decal(ctx, "oil", (x, Y_HANGAR, z), 0.6, 0.8, 35 * (1 if x < 7 else -1))
    decal(ctx, "oil", (10.05, Y_HANGAR, 19.55), 0.7, 0.5, 0)  # einde van de band
    # Vuil in de hoeken en langs de wanden van de kade, en rond de automaat en het luik.
    for (x, z, w, l, r) in ((0.9, 20.4, 1.6, 1.0, 10), (2.4, 19.1, 1.2, 0.8, -20), (15.2, 20.5, 1.4, 0.9, 0),
                            (13.9, 16.9, 1.0, 0.7, 30), (0.8, 14.5, 1.0, 2.2, 0), (0.8, 5.0, 1.0, 1.8, 0)):
        decal(ctx, "grime", (x, Y_HANGAR, z), w, l, r)
    # Voetsporen: uit de Mol naar de taxatiepoort (de draagroute), van de trap naar de Mol en terug,
    # en na de poort naar het luik en de trap.
    feet(ctx, [(7.2, 16.4), (8.9, 17.5), (10.3, 18.1)], Y_HANGAR)
    feet(ctx, [(6.6, 18.55), (6.7, 16.6)], Y_HANGAR)
    feet(ctx, [(8.9, 16.6), (8.9, 18.55)], Y_HANGAR)
    feet(ctx, [(13.7, 18.3), (14.9, 18.3)], Y_HANGAR)
    feet(ctx, [(13.7, 19.4), (11.0, 20.0), (9.2, 19.4)], Y_HANGAR)
    # Strepen onder de roosters en lampen aan de wanden van de hangar.
    for z in (6.0, 13.0):
        wall(ctx, "streak", (0.03, 3.6, z), (1, 0), 0.5, 1.6)
    # Schoppen onderaan de toonbank van het luik en de automaat.
    wall(ctx, "scuff", (14.97, 0.2, 18.3), (-1, 0), 2.2, 0.35)
    wall(ctx, "scuff", (1.11, 0.2, 18.3), (1, 0), 1.4, 0.3)

    # --- Brug --------------------------------------------------------------------------------------------
    feet(ctx, [(10.0, 26.0), (8.6, 23.4), (7.75, 21.4)], Y_BRIDGE)
    feet(ctx, [(10.4, 25.9), (5.9, 24.6)], Y_BRIDGE)
    # Koffie: wie bij het automaat in een plas stapte (onder het automaat ligt rooster).
    decal(ctx, "coffee", (16.9, Y_BRIDGE, 24.05), 0.5, 0.4, 10)
    feet(ctx, [(16.6, 24.0), (13.2, 23.3)], Y_BRIDGE, "feetcoffee")
    wall(ctx, "streak", (19.465, 1.95, 25.29), (0, -1), 0.35, 0.7)  # koffie die langs het automaat liep
    for (x, z, w, l) in ((0.6, 21.6, 1.0, 0.8), (19.3, 21.6, 1.0, 0.8), (12.6, 25.6, 1.2, 0.6)):
        decal(ctx, "grime", (x, Y_BRIDGE, z), w, l, 0)

    # --- Gang ----------------------------------------------------------------------------------------------
    # Verf aan de voeten: van de spuitcabine naar de brug, steeds minder (HubLook laat ze uitdoven).
    feet(ctx, [(8.6, 28.4), (9.8, 26.6)], Y_BRIDGE, "feetpaint")
    for (x, z) in ((7.5, 29.5), (12.5, 26.8)):
        decal(ctx, "grime", (x, 1.2, z), 0.9, 0.9, 0)

    # --- Werkdek -------------------------------------------------------------------------------------------
    feet(ctx, [(9.65, 39.4), (9.75, 30.3)], Y_DECK)
    feet(ctx, [(10.35, 30.3), (10.3, 39.4)], Y_DECK)
    feet(ctx, [(9.3, 36.9), (3.4, 37.1)], Y_DECK)
    feet(ctx, [(9.3, 33.2), (3.4, 33.0)], Y_DECK)
    for (x, z, w, l) in ((3.6, 30.5, 1.2, 0.8), (16.4, 30.5, 1.2, 0.8), (3.6, 39.5, 1.2, 0.8),
                         (16.4, 39.5, 1.2, 0.8), (2.7, 37.0, 0.9, 2.6)):
        decal(ctx, "grime", (x, Y_DECK, z), w, l, 0)
    wall(ctx, "scuff", (2.53, 1.42, 37.0), (1, 0), 2.6, 0.35)  # onderaan de balie van de voorraad

    # --- Laadrek -------------------------------------------------------------------------------------------
    for px in (7.0, 9.0, 11.0, 13.0):
        decal(ctx, "grime", (px, Y_RACK, 42.2), 1.0, 0.7, 0)
    feet(ctx, [(9.0, 42.0), (9.6, 40.6)], Y_RACK)
    feet(ctx, [(11.0, 42.0), (10.4, 40.6)], Y_RACK)
