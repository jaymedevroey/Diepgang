"""Zone HANGAR: de hangar met de Mol voor het raam, de kade, de galerij (Mol-werf) en de uitkijkput.

Plan: hangar x 0..16, z 0..21, vloer 0, plafond 9 m. Baaideuren x 3..11, z 2..16. Put x 12..16,
z 0..2,5 op −0,6. Galerij x 16..20 op +1,2 (open naar de hangar). Raamwand vooraan (z 0), glas van
0,7 tot 8,5 m. Portaalkraan op 7,5 m. Kade z 16..21: taxatiepoort, verkoopluik, automaat.
Zie layout.py voor het contract (ankerpunten) met het spel.
"""

import math

from layout import (BAY, GALLERY, HANGAR_TOP, PIT, TRACK_DOCK_Y, TRIM, WALL, Ctx, G, block, led, rail, slab,
                    stairs_z)


def build(ctx: Ctx):
    shell = ctx.b("Shell")
    steps = ctx.b("Steps")
    rails = ctx.b("Rails")
    glass = ctx.b("Glass")
    props = ctx.b("Props")
    roof = ctx.b("Roof")
    bx0, bx1, bz0, bz1 = BAY

    # --- Vloer rond de baai en de put ------------------------------------------------------------
    slab(shell, 0, 16, 16, 21, 0.0)  # kade
    slab(shell, 0, 3, 0, 16, 0.0)
    slab(shell, 11, 16, 2.5, 16, 0.0)
    slab(shell, 3, 12, 0, 2, 0.0)
    slab(shell, 11, 12, 2, 2.5, 0.0)
    for (x0, x1, z0, z1) in ((0, 16, 16, 21), (0, 3, 0, 16), (11, 16, 2.5, 16), (3, 12, 0, 2), (11, 12, 2, 2.5)):
        ctx.col_box(x0, x1, -0.6, 0.0, z0, z1)
    # Baaideuren: twee helften met de oorsprong op het scharnier (BayDoor_L/R, zie build.py).
    ctx.shared["doors"].append(("BayDoor_L", (bx0, -0.02, (bz0 + bz1) / 2), (0.0, 4.0, bz1 - bz0)))
    ctx.shared["doors"].append(("BayDoor_R", (bx1, -0.02, (bz0 + bz1) / 2), (-4.0, 0.0, bz1 - bz0)))
    for (ax, bx, az, bz) in ((2.6, 11.4, 1.6, 2.0), (2.6, 11.4, 16.0, 16.4), (2.6, 3.0, 2.0, 16.0), (11.0, 11.4, 2.0, 16.0)):
        block(shell, ax, bx, -0.02, 0.012, az, bz, "Hazard")
    ctx.anchor("Mol_Dock", ((bx0 + bx1) / 2, TRACK_DOCK_Y, (bz0 + bz1) / 2))
    # Uitkijkput (−0,6) voor het raam, met 4 treden vanaf de hangar.
    px0, px1, pz0, pz1 = PIT
    slab(shell, px0, px1, pz0, pz1, -0.6, "Floor", -1.0)
    ctx.col_box(px0, px1, -1.0, -0.6, pz0, pz1)
    stairs_z(ctx, steps, px0 + 0.5, px1 - 0.5, pz1, 0.0, -4, -1)
    block(shell, px0, px0 + 0.2, -0.6, 0.0, pz0, pz1, TRIM)
    ctx.col_box(px0, px0 + 0.2, -0.6, 0.0, pz0, pz1)
    # Galerij stuurboord (+1,2), open naar de hangar, met een reling.
    gx0, gx1, gz0, gz1 = GALLERY
    block(shell, gx0, gx1, -0.6, 1.2, gz0, gz1, WALL)
    ctx.col_box(gx0, gx1, -0.6, 1.2, gz0, gz1)
    led(shell, gx0 - 0.1, gx0, 1.2, gz0, gz1)
    rail(rails, (gx0 + 0.05, 0.3), (gx0 + 0.05, gz1), 1.2, ctx)

    # --- Wanden, plafond, liggers ------------------------------------------------------------------
    block(shell, -0.3, 0.0, -0.6, HANGAR_TOP, 0, 26, WALL)
    block(shell, 20.0, 20.3, -0.6, HANGAR_TOP, 0, 26, WALL)
    ctx.col_box(-0.3, 0.0, -0.6, HANGAR_TOP, 0, 26)
    ctx.col_box(20.0, 20.3, -0.6, HANGAR_TOP, 0, 26)
    block(roof, -0.3, 20.3, HANGAR_TOP, HANGAR_TOP + 0.4, -0.5, 23.5, WALL)
    for z in (3.0, 7.0, 11.0, 15.0, 19.0):
        for side in (0, 1):
            x = 0.0 if side == 0 else 20.0
            sx = 1 if side == 0 else -1
            roof.box(G(x + sx * 1.2, 7.9, z), (0.4, 2.8, 0.4), u=(1, 0, 0), v=(sx * 1.6, 1.0, 0), material=TRIM)
        block(roof, 0, 20, 8.75, 9.0, z - 0.2, z + 0.2, TRIM)

    # --- Raamwand: de hele voorkant, glas van 0,7 tot 8,5 m (in de put tot op de putvloer) -------
    block(shell, 0, 12, -0.6, 0.7, -0.3, 0.0, WALL)
    block(shell, 16, 20, -0.6, 1.9, -0.3, 0.0, WALL)
    block(shell, 0, 20, 8.5, 9.4, -0.3, 0.0, WALL)
    ctx.col_box(0, 20, -1.0, 9.4, -0.4, 0.0)  # glas: niet door te lopen
    glass.box(G(10, 4.6, -0.15), (20, 7.8, 0.05), material="Glass")
    glass.box(G(14, 0.05, -0.15), (4, 1.3, 0.05), material="Glass")
    for i in range(9):
        x = 1.0 + i * 2.25
        tilt = 0.6 if i % 2 == 0 else -0.6
        shell.box(G(x, 4.6, -0.15), (0.3, math.hypot(7.8, tilt), 0.35), u=(1, 0, 0), v=(tilt, 7.8, 0), material=TRIM)
    for y in (0.7, 4.6, 8.5):
        block(shell, 0, 20, y - 0.12, y + 0.12, -0.32, 0.02, TRIM)
    ctx.anchor("Window_Glass", (10.0, 4.6, -0.15))

    # --- Portaalkraan op 7,5 m ---------------------------------------------------------------------
    for x in (0.6, 15.4):
        block(props, x - 0.25, x + 0.25, 7.3, 7.7, 0.5, 20.5, "Yellow")
    block(props, 0.6, 15.4, 7.35, 7.85, 8.6, 9.4, "Yellow")
    block(props, 6.4, 7.6, 6.6, 7.35, 8.4, 9.6, TRIM)
    props.cyl(G(7.0, 6.6, 9.0), (0, -1, 0), 0.6, 0.06, 8, "Steel")

    # --- Kade: taxatiepoort, verkoopluik, automaat --------------------------------------------------
    for z in (17.1, 19.5):
        block(props, 11.85, 12.15, 0.0, 2.8, z - 0.15, z + 0.15, "Anthracite")
        block(props, 11.8, 12.2, 0.6, 2.4, z - 0.02, z + 0.02, "Cyan")
        ctx.col_box(11.85, 12.15, 0.0, 2.8, z - 0.15, z + 0.15)
    block(props, 11.85, 12.15, 2.8, 3.1, 16.95, 19.65, "Anthracite")
    block(props, 11.8, 12.2, 2.78, 2.82, 17.2, 19.4, "Cyan")
    # Scherm van de poort (Appraisal_Screen, apart object met UV): naar de kade (−x).
    ctx.shared["screens"].append(("Appraisal_Screen", (11.78, 3.25, 18.3), (0.0, 0.0, -1.0), 2.2, 0.55))
    ctx.anchor("Appraisal_Gate", (12.0, 0.0, 18.3))
    ctx.sign("TAXATIE", (12.0, 3.75, 18.3), 90)
    ctx.glow("4fe3f0", (12.0, 2.4, 18.3))
    block(props, 15.0, 16.0, 0.0, 1.0, 17.2, 19.4, TRIM)  # balie voor het luik in de galerijmuur
    block(props, 15.0, 16.0, 1.0, 1.06, 17.2, 19.4, "Yellow")
    block(props, 15.95, 16.0, 1.1, 1.18, 17.6, 19.0, "Screen")
    ctx.col_box(15.0, 16.0, 0.0, 1.06, 17.2, 19.4)
    ctx.anchor("Sell_Hatch", (14.4, 0.0, 18.3), -90)
    ctx.sign("VERKOOP", (15.4, 2.2, 18.3), -90)
    block(props, 0.0, 1.2, 0.0, 2.2, 17.5, 19.1, "Red")  # automaat
    block(props, 1.15, 1.2, 1.3, 1.8, 18.0, 18.6, "Screen")
    ctx.col_box(0.0, 1.2, 0.0, 2.2, 17.5, 19.1)
    ctx.anchor("Vending", (1.8, 0.0, 18.3), 90)
    ctx.sign("AUTOMAAT", (1.25, 2.6, 18.3), 90)

    # --- Galerij: de Mol-werf (console die de kraan stuurt) -----------------------------------------
    block(props, 16.6, 17.6, 1.2, 2.2, 8.0, 11.0, TRIM)
    block(props, 16.6, 17.0, 2.2, 2.9, 8.0, 11.0, "Screen")
    ctx.col_box(16.6, 17.6, 1.2, 2.9, 8.0, 11.0)
    ctx.anchor("Mol_Werf", (18.2, 1.2, 9.5), -90)
    ctx.sign("MOL-WERF", (17.7, 3.7, 9.5), -90)
    ctx.glow("ffc92e", (18.0, 3.4, 9.5))
    ctx.spot("9ec8ff", (13.0, 8.6, 3.0))
    for z in (4.0, 12.0):
        ctx.lamp((8.0, 8.4, z))
