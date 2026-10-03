"""Zone HANGAR: de hangar met de Mol voor het raam, de kade, de galerij (Mol-werf) en de uitkijkput.

Plan: hangar x 0..16, z 0..21, vloer 0, plafond 9 m. Baaideuren x 3..11, z 2..16. Put x 12..16,
z 0..2,5 op −0,6. Galerij x 16..20 op +1,2 (open naar de hangar). Raamwand vooraan (z 0), glas van
0,7 tot 8,5 m. Portaalkraan op 7,5 m. Kade z 16..21: taxatiepoort, verkoopluik, automaat.
Zie layout.py voor het contract (ankerpunten) met het spel.

Afwerking "Helldivers + DIG-humor" (docs/research/schip-interieur-niveaus.md): donker staal,
afgeschuinde spanten om de 4 m met amberen lichtribben, schuine raamstijlen, witte ledstroken op
randen, geel-zwart aan de baai en de kraan; en een goedkope firma: ongelijke platen, tape,
gestolen kisten, cynische bordjes. Onderdelen: hangar_room.py (ruimte), hangar_posts.py (posten),
hangar_kit.py (hulpstukken en nieuwe materialen).
"""

import random

from hangar_kit import box, bulkhead_lamp, cyl
from hangar_posts import crane, gallery, gate, molwerf, sell_booth, signage, vending
from hangar_room import ceiling, floor, side_wall, window
from layout import BAY, PIT, TRACK_DOCK_Y, Ctx, stairs_z


def build(ctx: Ctx):
    B = {
        "shell": ctx.b("Shell"),
        "props": ctx.b("Props"),
        "roof": ctx.b("Roof"),
        "det": ctx.b("Detail"),
        "rdet": ctx.b("RoofDetail"),
        "glass": ctx.b("Glass"),
        "steps": ctx.b("Steps"),
        "rails": ctx.b("Rails"),
    }
    rng = random.Random(7)
    bx0, bx1, bz0, bz1 = BAY

    # --- De ruimte: vloer en baai, wanden, raam, plafond --------------------------------------------
    floor(ctx, B, rng)
    ctx.shared["doors"].append(("BayDoor_L", (bx0, -0.02, (bz0 + bz1) / 2), (0.0, 4.0, bz1 - bz0)))
    ctx.shared["doors"].append(("BayDoor_R", (bx1, -0.02, (bz0 + bz1) / 2), (-4.0, 0.0, bz1 - bz0)))
    ctx.anchor("Mol_Dock", ((bx0 + bx1) / 2, TRACK_DOCK_Y, (bz0 + bz1) / 2))
    # Zijwanden (de romp zelf loopt door tot de brug).
    box(B["shell"], -0.3, 0.0, -0.6, 9.0, 0, 26, "HullDark")
    box(B["shell"], 20.0, 20.3, -0.6, 9.0, 0, 26, "HullDark")
    ctx.col_box(-0.3, 0.0, -0.6, 9.0, 0, 26)
    ctx.col_box(20.0, 20.3, -0.6, 9.0, 0, 26)
    side_wall(ctx, B, 0, rng)
    side_wall(ctx, B, 1, rng)
    window(ctx, B)
    ceiling(ctx, B, rng)

    # Uitkijkput (−0,6) voor het raam, met 4 treden vanaf de hangar en dichte wangen opzij.
    px0, px1, pz0, pz1 = PIT
    box(B["shell"], px0, px1, -1.0, -0.6, pz0, pz1, "Soot")
    ctx.col_box(px0, px1, -1.0, -0.6, pz0, pz1)
    stairs_z(ctx, B["steps"], px0 + 0.5, px1 - 0.5, pz1, 0.0, -4, -1)
    box(B["shell"], px0, px0 + 0.2, -0.6, 0.0, pz0, pz1, "DarkSteel")
    ctx.col_box(px0, px0 + 0.2, -0.6, 0.0, pz0, pz1)
    for (a, c) in ((px0 + 0.2, px0 + 0.5), (px1 - 0.5, px1)):
        box(B["shell"], a, c, -0.6, 0.0, 1.3, pz1, "Anthracite")
        box(B["det"], a, c, 0.0, 0.016, 1.3, pz1, "Hazard")
        ctx.col_box(a, c, -0.6, 0.0, 1.3, pz1)

    # --- Posten ----------------------------------------------------------------------------------
    gallery(ctx, B, rng)
    crane(ctx, B)
    gate(ctx, B)
    sell_booth(ctx, B)
    vending(ctx, B)
    molwerf(ctx, B)
    signage(ctx, B, rng)

    # --- Licht (≤ 12 lampen en gloed, ≤ 3 spots), elk bij een armatuur die je ziet ----------------
    for z in (6.0, 13.0):
        bulkhead_lamp(B["shell"], B["det"], (0.06, 4.3, z), (1, 0, 0))
        ctx.glow("ffcf8f", (0.55, 4.1, z))
    for z in (5.0, 17.0):
        bulkhead_lamp(B["shell"], B["det"], (19.94, 5.5, z), (-1, 0, 0))
        ctx.glow("ffcf8f", (19.45, 5.3, z))
    ctx.glow("4fe3f0", (12.0, 2.4, 18.3))  # taxatiepoort
    ctx.glow("ffc92e", (18.0, 3.4, 9.5))  # Mol-werf
    ctx.glow("ffb060", (13.9, 2.2, 18.3))  # verkoopluik (niet te dicht: anders een hete rand op de kiosk)
    ctx.glow("ff9a5a", (1.8, 2.0, 18.3))  # automaat
    ctx.glow("ffd9a0", (6.6, 7.9, 17.4))  # lichtbak boven de kade
    ctx.glow("9ec8ff", (14.0, 0.4, 0.7))  # put, bij het glas
    for (x, z, col) in ((13.0, 3.0, "9ec8ff"), (10.0, 18.5, "ffe2b0")):
        cyl(B["rdet"], (x, 8.62, z), (0, 1, 0), 0.31, 0.2, "DarkSteel", segs=14)
        cyl(B["rdet"], (x, 8.6, z), (0, 1, 0), 0.02, 0.15, "LedWhite", segs=14)
        ctx.spot(col, (x, 8.5, z))
