"""Zone BRUG + GANG: de brug met de opdrachttafel op een verhoging, en de lage gang naar het werkdek.

Plan: brug x 0..20, z 21..26 op +1,2; plafond 4 m vooraan, luifel op 3 m vanaf z 23,5. De trap van
8 treden van de kade (x 6..9,5, z 18,6..21). Verhoging Ø 4 m op +1,8 (4 ringtreden) rond (13, 23,4).
Gang x 7..13, z 26,3..30 op +1,2, plafond 2,6, afgeschuind (achtkantig), met de kast (cosmetica) en
het firmabord. Zie layout.py voor het contract (ankerpunten) met het spel.
"""

from layout import (BRIDGE, CORRIDOR, DAIS, RISER, TREAD, TRIM, WALL, Ctx, G, block, led, rail, slab, stairs_z)


def chamfer_room(ctx, b, x0, x1, y0, height, z0, z1, ch=0.55):
    """Achtkantige gang langs z: vloer, wanden, plafond, schuine hoeken boven, spanten om de 2 m."""
    slab(b, x0, x1, z0, z1, y0, "Floor", y0 - 0.3)
    block(b, x0, x1, y0 + height, y0 + height + 0.3, z0, z1, WALL)
    for side, x in ((0, x0), (1, x1)):
        block(b, x - 0.15, x + 0.15, y0, y0 + height - ch, z0, z1, WALL)
        ctx.col_box(x - 0.15, x + 0.15, y0, y0 + height, z0, z1)
        sx = 1 if side == 0 else -1
        b.box(G(x + sx * ch / 2, y0 + height - ch / 2, (z0 + z1) / 2), (ch * 1.42, 0.25, z1 - z0),
              u=(sx, 1, 0), v=(-1, sx, 0) if sx > 0 else (1, -sx, 0), material=WALL)
    ctx.col_box(x0, x1, y0 - 0.3, y0, z0, z1)
    z = z0 + 1.0
    while z < z1 - 0.5:
        for x in (x0 + 0.12, x1 - 0.12):
            block(b, x - 0.12, x + 0.12, y0, y0 + height - ch, z - 0.12, z + 0.12, TRIM)
        block(b, x0 + ch, x1 - ch, y0 + height - 0.12, y0 + height, z - 0.12, z + 0.12, TRIM)
        z += 2.0


def build(ctx: Ctx):
    shell = ctx.b("Shell")
    steps = ctx.b("Steps")
    rails = ctx.b("Rails")
    props = ctx.b("Props")
    roof = ctx.b("Roof")
    x0, x1, z0, z1 = BRIDGE

    # --- Brug (+1,2) ------------------------------------------------------------------------------
    slab(shell, x0, x1, z0, z1, 1.2)
    ctx.col_box(x0, x1, -0.6, 1.2, z0, z1)
    led(shell, 0, 6, 1.2, 20.9, 21.0)
    led(shell, 9.5, 16, 1.2, 20.9, 21.0)
    rail(rails, (0.2, 21.05), (6.0, 21.05), 1.2, ctx)
    rail(rails, (9.5, 21.05), (16.0, 21.05), 1.2, ctx)
    stairs_z(ctx, steps, 6.0, 9.5, 21.0 - 8 * TREAD, 0.0, 8, 1)
    # Luifel: achter op de brug een lager plafond (op 4,2 m), de muur erboven tot het hangarplafond.
    block(roof, 0, 20, 4.2, 4.5, 23.5, 26.3, WALL)
    block(shell, 0, 20, 4.2, 9.4, 23.5, 23.8, WALL)
    led(shell, 0.2, 19.8, 4.17, 23.45, 23.5)
    # Achterwand van de brug, met de opening naar de gang.
    block(shell, 0, 7, 1.2, 4.5, 26.0, 26.3, WALL)
    block(shell, 13, 20, 1.2, 4.5, 26.0, 26.3, WALL)
    block(shell, 7, 13, 3.8, 4.5, 26.0, 26.3, WALL)
    ctx.col_box(0, 7, 1.2, 4.5, 26.0, 26.3)
    ctx.col_box(13, 20, 1.2, 4.5, 26.0, 26.3)

    # --- Verhoging (+1,8, Ø 4 m) met 4 ringtreden, en de opdrachttafel ---------------------------
    dx, dz, r0 = DAIS
    for i, r in enumerate((r0 + 0.9, r0 + 0.6, r0 + 0.3, r0)):
        props.cyl(G(dx, 1.2, dz), (0, 1, 0), RISER * (i + 1), r, 40, "Floor")
        props.cyl(G(dx, 1.2 + RISER * (i + 1), dz), (0, 1, 0), 0.012, r + 0.005, 40, "LedWhite")
        ctx.shared["collision"].cyl(G(dx, 1.2, dz), (0, 1, 0), RISER * (i + 1), r, 16, "Soot")
    props.cyl(G(dx, 1.8, dz), (0, 1, 0), 0.9, 1.25, 32, "Anthracite")
    props.cyl(G(dx, 2.7, dz), (0, 1, 0), 0.04, 1.15, 32, "Screen")
    props.cyl(G(dx, 2.74, dz), (0, 1, 0), 0.02, 0.5, 24, "Cyan")  # de planeet als hologram
    ctx.shared["collision"].cyl(G(dx, 1.8, dz), (0, 1, 0), 0.95, 1.25, 16, "Soot")
    # Scherm boven de tafel (Terminal_Screen, met UV): naar de gang toe (+z).
    ctx.shared["screens"].append(("Terminal_Screen", (dx, 3.3, dz + 0.6), (0.0, 0.0, 1.0), 2.0, 0.9))
    ctx.anchor("Terminal_Use", (dx, 1.8, dz + 1.6), 0)
    ctx.sign("OPDRACHTEN", (dx, 3.9, 21.5), 180)
    ctx.spot("bfe8ff", (dx, 4.15, dz))
    ctx.glow("ffb060", (4.0, 3.6, 24.5))
    ctx.lamp((17.0, 4.0, 24.8))

    # --- Gang (+1,2, plafond 2,6) -----------------------------------------------------------------
    cx0, cx1, cz0, cz1 = CORRIDOR
    chamfer_room(ctx, shell, cx0, cx1, 1.2, 2.6, cz0, cz1)
    # Kast met spuitcabine (bakboord) en het firmabord (stuurboord).
    block(props, cx0 + 0.15, cx0 + 0.7, 1.2, 3.2, 27.2, 29.2, "Red")
    ctx.col_box(cx0 + 0.15, cx0 + 0.7, 1.2, 3.2, 27.2, 29.2)
    ctx.anchor("Locker", (cx0 + 1.3, 1.2, 28.2), 90)
    ctx.sign("KAST", (cx0 + 0.75, 3.25, 28.2), 90)
    block(props, cx1 - 0.15, cx1 - 0.1, 1.8, 3.2, 27.0, 29.4, "Anthracite")
    ctx.shared["screens"].append(("Company_Board", (cx1 - 0.18, 2.5, 28.2), (-1.0, 0.0, 0.0), 2.2, 1.2))
    ctx.sign("FIRMA", (cx1 - 0.25, 3.3, 28.2), -90)
    ctx.glow("ffb060", (10.0, 3.3, 28.0))
