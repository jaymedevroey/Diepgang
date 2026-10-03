"""Zone WERKDEK + LAADREK: het werkdek met vier upgradenissen en de tv, en het laadrek (spawn).

Plan: werkdek x 3..17, z 30..40 op +1,2, plafond 3,6 m (3,0 aan de zijkanten). Nissen 3 × 4 m,
plafond 2,6: Niche_Tools (x 0..3, z 31..35, gereedschapsbank met schaduwbord), Niche_Supply (x 0..3,
z 35..39, uitgifte met luik), Niche_Free_A/B (x 17..20, vrij voor later). Tv tegen de voorwand
(DIG-nieuws), het DIG-logo in de vloer. Laadrek x 6..14, z 41,2..44 op +0,6, plafond 2,4, met 4
treden omlaag vanaf het werkdek; capsules en Spawn_0..3.
Zie layout.py voor het contract (ankerpunten) met het spel.
"""

from layout import NICHES, RACK, TRIM, WALL, WORKDECK, Ctx, G, block, slab, stairs_z


def niche(ctx, b, x0, x1, z0, z1, side, title, anchor):
    """Upgradenis (+1,2): 3 × 4 m, plafond 2,6, afgeschuind, open naar het dek, amberen lichtrib."""
    y0, h = 1.2, 2.6
    slab(b, x0, x1, z0, z1, y0, "Floor", y0 - 0.3)
    ctx.col_box(x0, x1, -0.6, y0, z0, z1)
    block(b, x0, x1, y0 + h, y0 + h + 0.3, z0, z1, WALL)
    back = x0 if side < 0 else x1
    block(b, back - 0.15, back + 0.15, y0, y0 + h, z0, z1, WALL)
    ctx.col_box(back - 0.15, back + 0.15, y0, y0 + h, z0, z1)
    for z in (z0, z1):
        block(b, x0, x1, y0, y0 + h, z - 0.15, z + 0.15, WALL)
        ctx.col_box(x0, x1, y0, y0 + h, z - 0.15, z + 0.15)
    cx = back - side * 0.3
    b.box(G(cx, y0 + h - 0.3, (z0 + z1) / 2), (0.85, 0.2, z1 - z0), u=(-side, 1, 0),
          v=(1, side, 0) if side < 0 else (-1, -side, 0), material=WALL)
    front = x1 if side < 0 else x0
    for z in (z0 + 0.2, z1 - 0.2):
        block(b, front - 0.08, front + 0.08, y0, y0 + h, z - 0.05, z + 0.05, "LedAmber")
    block(b, front - 0.08, front + 0.08, y0 + h - 0.1, y0 + h, z0 + 0.2, z1 - 0.2, "LedAmber")
    ctx.anchor(anchor, ((x0 + x1) / 2, y0, (z0 + z1) / 2), 90 if side < 0 else -90)
    ctx.sign(title, (front - side * 0.6, y0 + h - 0.05, (z0 + z1) / 2), 90 if side < 0 else -90)
    ctx.glow("ffb060", ((x0 + x1) / 2, y0 + h - 0.4, (z0 + z1) / 2))


def build(ctx: Ctx):
    shell = ctx.b("Shell")
    steps = ctx.b("Steps")
    props = ctx.b("Props")
    roof = ctx.b("Roof")
    wx0, wx1, wz0, wz1 = WORKDECK

    # --- Werkdek (+1,2) ----------------------------------------------------------------------------
    slab(shell, wx0, wx1, wz0, wz1, 1.2)
    ctx.col_box(wx0, wx1, -0.6, 1.2, wz0, wz1)
    block(roof, wx0, wx1, 4.8, 5.1, wz0, wz1, WALL)
    for x in (wx0, wx1 - 2.0):
        block(roof, x, x + 2.0, 4.2, 4.8, wz0, wz1, WALL)
    for z in (31.0, 33.5, 36.0, 38.5):
        for side in (0, 1):
            x = 5.0 if side == 0 else 15.0
            sx = 1 if side == 0 else -1
            roof.box(G(x + sx * 0.6, 4.5, z), (0.25, 0.9, 0.25), u=(1, 0, 0), v=(sx * 1.2, 0.6, 0), material=TRIM)
    # Voorwand (met de gangopening), achterwand (opening naar het laadrek), zijkanten (nissen).
    for (x0, x1, y0, y1, z0, z1) in ((3, 7, 1.2, 4.8, 29.85, 30.15), (13, 17, 1.2, 4.8, 29.85, 30.15),
                                     (7, 13, 3.8, 4.8, 29.85, 30.15), (3, 6, 1.2, 4.8, 39.85, 40.15),
                                     (14, 17, 1.2, 4.8, 39.85, 40.15), (6, 14, 3.0, 4.8, 39.85, 40.15)):
        block(shell, x0, x1, y0, y1, z0, z1, WALL)
        ctx.col_box(x0, x1, y0, y1, z0, z1)
    for x in (wx0, wx1):
        for (z0, z1, y0) in ((30, 31, 1.2), (39, 40, 1.2), (31, 39, 3.8)):
            block(shell, x - 0.15, x + 0.15, y0, 4.8, z0, z1, WALL)
            ctx.col_box(x - 0.15, x + 0.15, y0, 4.8, z0, z1)
    titles = {"Niche_Tools": "GEREEDSCHAP", "Niche_Supply": "UITGIFTE", "Niche_Free_A": "LATER", "Niche_Free_B": "LATER"}
    for name, (x0, x1, z0, z1) in NICHES.items():
        niche(ctx, shell, x0, x1, z0, z1, -1 if x0 < 10 else 1, titles[name], name)
    # Gereedschapsbank met een schaduwbord, en de uitgifte: een balie met een luik.
    block(props, 0.15, 0.4, 1.9, 3.4, 31.6, 34.4, TRIM)
    block(props, 0.4, 1.5, 1.2, 2.15, 31.8, 34.2, "Anthracite")
    block(props, 0.4, 1.5, 2.15, 2.2, 31.8, 34.2, "Yellow")
    ctx.col_box(0.4, 1.5, 1.2, 2.2, 31.8, 34.2)
    block(props, 1.6, 2.4, 1.2, 2.2, 35.6, 38.4, "Anthracite")
    block(props, 1.6, 2.4, 2.2, 2.25, 35.6, 38.4, "Yellow")
    block(props, 0.15, 0.25, 1.9, 3.0, 36.5, 37.5, "Screen")
    ctx.col_box(1.6, 2.4, 1.2, 2.25, 35.6, 38.4)
    # Tv tegen de voorwand (TV_Screen met UV, naar achteren +z), het DIG-logo in de vloer.
    block(props, 3.5, 6.5, 2.3, 4.0, 30.15, 30.3, "Anthracite")
    ctx.shared["screens"].append(("TV_Screen", (5.0, 3.15, 30.32), (0.0, 0.0, 1.0), 2.8, 1.55))
    props.cyl(G(10.0, 1.2, 35.0), (0, 1, 0), 0.012, 2.2, 6, "Yellow")
    props.cyl(G(10.0, 1.2, 35.0), (0, 1, 0), 0.015, 1.8, 6, "Floor")
    ctx.sign("WERKDEK", (10.0, 4.3, 30.4), 0)
    for p in ((6.0, 4.6, 33.0), (14.0, 4.6, 33.0), (6.0, 4.6, 37.0), (14.0, 4.6, 37.0)):
        ctx.glow("ffb060", p)

    # --- Laadrek (+0,6, plafond 2,4) ----------------------------------------------------------------
    rx0, rx1, rz0, rz1 = RACK
    stairs_z(ctx, steps, rx0, rx1, 40.0, 1.2, -4, 1)
    slab(shell, rx0, rx1, rz0, rz1, 0.6)
    ctx.col_box(rx0, rx1, -0.6, 0.6, rz0, rz1)
    block(roof, rx0, rx1, 3.0, 3.3, 40.0, rz1 + 0.3, WALL)
    for x in (rx0, rx1):
        block(shell, x - 0.15, x + 0.15, 0.6, 3.0, 40.0, rz1 + 0.3, WALL)
        ctx.col_box(x - 0.15, x + 0.15, 0.6, 3.0, 40.0, rz1 + 0.3)
    block(shell, rx0, rx1, 0.6, 3.0, rz1, rz1 + 0.3, WALL)
    ctx.col_box(rx0, rx1, 0.6, 3.0, rz1, rz1 + 0.3)
    for i, x in enumerate((7.0, 9.0, 11.0, 13.0)):
        props.cyl(G(x, 0.6, 43.3), (0, 1, 0), 2.1, 0.7, 16, TRIM)
        block(props, x - 0.4, x + 0.4, 2.3, 2.38, 42.55, 42.65, "Cyan")
        ctx.anchor(f"Spawn_{i}", (x, 0.6, 42.1), 0)
    ctx.sign("LAADREK", (10.0, 2.75, 41.3), 180)
    ctx.glow("7fd8e8", (10.0, 2.6, 42.5))
