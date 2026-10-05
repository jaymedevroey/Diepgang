"""Zone BRUG + GANG: de brug met de opdrachttafel op een verhoging, en de lage gang naar het werkdek.

Plan: brug x 0..20, z 21..26 op +1,2; plafond 4 m vooraan, luifel op 3 m vanaf z 23,5. De trap van
8 treden van de kade (x 6..9,5, z 18,6..21). Verhoging Ø 4 m op +1,8 (4 ringtreden) rond (3,3, 23,4), bakboord: weg uit de looplijn gang → trap.
Gang x 7..13, z 26,3..30 op +1,2, plafond 2,6, afgeschuind (achtkantig), met de kast (cosmetica) en
het firmabord. Zie layout.py voor het contract (ankerpunten) met het spel.

Afwerking "Helldivers + DIG": donker staal met afgeschuinde profielen, witte ledranden, amberen
lichtribben, geel-zwarte stijlen, banieren; en DIG: goedkope monitoren van verschillende merken,
plakband, gele briefjes, cynische bordjes. Onderdelen: bridge_table.py (verhoging, tafel, hologram,
lichtkroon), bridge_corridor.py (gang, schotten, spuitcabine, firmabord), bridge_props.py (kleine
rekwisieten), bridge_kit.py (vormen en tekst).

Afwijkingen van het blokmodel (op vraag van de schermen): Terminal_Screen hangt hoger (midden y 3,55,
onderrand 3,1, bovenrand 4,0) als dubbelzijdig hologram zonder iets massiefs ervoor of erachter;
Company_Board is 1,7 × 0,95 m tussen de spanten van de gang. De verhoging botst als kegel (helling van
34°), niet als treden. Geen Sign_-punten meer: de opschriften zitten nu in het model.
"""

import math
import random

import kit
from builder import Patch, panels
from layout import BRIDGE, TREAD, WALL, Ctx, G, block, slab, stairs_z

import bridge_corridor
import bridge_table
from bridge_kit import beam, box, cloth, grating, oct_profile, plate_grid, prism, tbox, text
from bridge_props import Frame, keyboard, monitor, mug, papers, poster, sticky, trash_bin

# Nieuwe materialen (naam: kleur, metallic, roughness, emissie). In Godot (MolVisual.palette_material)
# vallen onbekende namen terug op het materiaal uit de glb.
kit.PALETTE.update({
    "HoloCyan": ((0.12, 0.62, 1.0), 0.0, 0.3, ((0.1, 0.6, 1.0), 2.0)),
    "HoloCore": ((0.01, 0.06, 0.12), 0.0, 0.4, ((0.02, 0.18, 0.4), 1.0)),
    "HoloBeam": ((0.12, 0.6, 1.0), 0.0, 0.3, ((0.1, 0.5, 1.0), 0.8)),
    "ScreenGreen": ((0.25, 0.55, 0.05), 0.0, 0.35, ((0.32, 0.72, 0.04), 1.0)),
    "ScreenAmber": ((0.8, 0.3, 0.03), 0.0, 0.35, ((1.0, 0.36, 0.03), 1.0)),
    "ScreenBlue": ((0.03, 0.1, 0.6), 0.0, 0.35, ((0.02, 0.1, 0.8), 1.0)),
    "Mirror": ((0.62, 0.64, 0.66), 1.0, 0.1, None),
})

Y = 1.2  # vloer van de brug


def _materials():
    """De bundel van het hologram is doorzichtig (zoals Glass in kit.py)."""
    m = kit.mat("HoloBeam")
    bsdf = m.node_tree.nodes.get("Principled BSDF") if m.node_tree else None
    if bsdf:
        bsdf.inputs["Alpha"].default_value = 0.16
    try:
        m.surface_render_method = "BLENDED"
    except AttributeError:
        pass


def build(ctx: Ctx):
    _materials()
    g = {k: ctx.b(n) for k, n in (("shell", "Shell"), ("steps", "Steps"), ("rails", "Rails"), ("props", "Props"),
                                  ("detail", "Detail"), ("holo", "Holo"), ("glow", "Glow"), ("deck", "Deck"),
                                  ("roof", "Roof"), ("roofd", "RoofDetail"))}
    rng = random.Random(3)
    floor(ctx, g)
    front_edge(ctx, g, rng)
    railing(ctx, g, 0.2, 6.0, 21.05)
    railing(ctx, g, 9.5, 16.0, 21.05)
    stair(ctx, g)
    bridge_table.build_dais(ctx, g)
    bridge_table.build_table(ctx, g)
    bridge_table.build_screen(ctx, g)
    bridge_table.build_crown(ctx, g)
    back_wall(ctx, g, rng)
    port_console(ctx, g, rng)
    starboard_console(ctx, g, rng)
    side_walls(ctx, g, rng)
    overhang(ctx, g)
    fascia(ctx, g, rng)
    bridge_corridor.build(ctx, g)
    ctx.glow("6fd6ff", (13.0, 3.0, 22.6))


# --- Vloer -----------------------------------------------------------------------------------------

def _seg_dist(p, a, b):
    ax, az = a
    dx, dz = b[0] - ax, b[1] - az
    t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - az) * dz) / (dx * dx + dz * dz)))
    return math.hypot(p[0] - ax - t * dx, p[1] - az - t * dz)


def floor(ctx, g):
    x0, x1, z0, z1 = BRIDGE
    slab(g["shell"], x0, x1, z0, z1, Y - 0.03, "Soot")
    ctx.col_box(x0, x1, -0.6, Y, z0, z1)
    dx, dz, _ = bridge_table.DAIS

    def skip(cx, cz):
        if math.hypot(cx - dx, cz - dz) < 2.0:
            return True
        return cz > 24.3 and cx > 13.2

    def alt(i, j):
        return "HullDark" if (i * 7 + j * 3) % 11 == 0 else None

    def worn(cx, cz):  # looppaden: gang → terminal en gang → trap naar de kade
        use = bridge_table.USE
        return min(_seg_dist((cx, cz), (10.0, 26.0), (use[0] + 0.6, use[2] + 0.4)),
                   _seg_dist((cx, cz), (10.0, 26.0), (7.75, 21.3))) < 0.75

    plate_grid(g["deck"], x0, x1, z0, 24.3, Y, 1.25, 1.1, "Floor", skip=skip, alt=alt, worn=worn)
    plate_grid(g["deck"], x0, 13.2, 24.3, z1, Y, 1.25, 0.85, "Floor", skip=skip, alt=alt, worn=worn)
    # Roosters waar de technici staan (voor de consoles en eronder).
    grating(g["deck"], 13.25, 19.95, 24.32, 25.98, Y, along="x")
    # Geel-zwart aan de trapkop, en pijlen naar de trap.
    block(g["detail"], 6.0, 9.5, Y - 0.005, Y + 0.004, 21.02, 21.3, "Hazard")
    for k in range(3):
        z = 22.0 + k * 0.45
        for s in (-1, 1):
            tbox(g["detail"], (7.75, Y + 0.002, z), (7.75 + s * 0.32, Y + 0.002, z + 0.26), 0.07, 0.006, "Yellow")


# --- Rand van de brug boven de kade ------------------------------------------------------------------

def front_edge(ctx, g, rng):
    for (a, c) in ((0.0, 6.0), (9.5, 16.0)):
        # Neus: een afgeschuinde stalen lip met een witte ledstrook erop.
        prism(g["shell"], [(-21.0, Y), (-20.86, Y), (-20.86, Y - 0.08), (-20.92, Y - 0.16), (-21.0, Y - 0.16)],
              (a, 0, 0), (1, 0, 0), c - a, "DarkSteel")
        block(g["glow"], a + 0.05, c - 0.05, Y, Y + 0.008, 20.885, 20.915, "LedWhite")
        # Gevel naar de kade: platen, spanten om de 1,6 m, oranje lampjes, een plint.
        panels(g["shell"], Patch(G(c, 0.14, 20.985), (-1, 0, 0), (0, 1, 0), c - a, Y - 0.32), rng,
               cell=(1.6, 0.9), lift=0.05, gap=0.05, material="HullDark",
               alt=[("GreyGreen", 0.15), ("Anthracite", 0.15)], thick=0.08)
        n = max(1, round((c - a) / 1.6))
        for i in range(n + 1):
            x = a + (c - a) * i / n
            x = min(max(x, a + 0.08), c - 0.08)
            block(g["props"], x - 0.07, x + 0.07, 0.0, Y - 0.16, 20.86, 20.99, "DarkSteel")
            if 0 < i < n:
                block(g["glow"], x - 0.04, x + 0.04, 0.22, 0.27, 20.855, 20.86, "LensOrange")
        block(g["shell"], a, c, 0.0, 0.14, 20.9, 21.0, "Anthracite")
        ctx.col_box(a, c, 0.0, Y, 20.85, 21.0)
    # Wegwijzers naar de trap, vanaf de kade te lezen.
    for (a, c, arrow) in ((4.66, 5.76, 1), (9.74, 10.84, -1)):
        xm = (a + c) / 2
        block(g["detail"], a, c, 0.5, 0.92, 20.86, 20.876, "Yellow")
        text(g["detail"], "BRIDGE", 0.17, (xm - arrow * 0.14, 0.71, 20.857), (0, 0, -1), "DecalDark")
        prism(g["detail"], [(0.0, 0.1), (0.0, -0.1), (0.17 * arrow, 0.0)], (xm + arrow * 0.2, 0.71, 20.857),
              (0, 0, 1), 0.003, "DecalDark")


def railing(ctx, g, ax, cx, z):
    """Reling van 0,9 m: palen, een achtkantige bovenbuis met ledstrook, twee tussenbuizen, een
    gestreepte schopplaat."""
    R = g["rails"]
    length = cx - ax
    n = max(1, round(length / 1.45))
    for i in range(n + 1):
        x = ax + length * i / n
        box(R, (x, Y + 0.45, z), (0.06, 0.9, 0.09), "DarkSteel")
        box(R, (x, Y + 0.012, z), (0.15, 0.024, 0.17), "DarkSteel")
    prism(R, oct_profile(0.1, 0.07, 0.022), (ax - 0.05, Y + 0.93, z), (1, 0, 0), length + 0.1, "DarkSteel")
    for yy in (0.42, 0.66):
        box(R, ((ax + cx) / 2, Y + yy, z), (length, 0.035, 0.035), "DarkSteel")
    box(R, ((ax + cx) / 2, Y + 0.09, z - 0.02), (length, 0.14, 0.02), "Hazard")
    ctx.shared["collision"].box(G((ax + cx) / 2, Y + 0.5, z), (length, 1.0, 0.12), material="Soot")


def stair(ctx, g):
    """De trap van 8 treden met wangen, leuningen en geel-zwarte randen."""
    z_start = 21.0 - 8 * TREAD
    stairs_z(ctx, g["steps"], 6.0, 9.5, z_start, 0.0, 8, 1)
    for i in range(8):  # antislipstrook achter elke ledneus
        top = 0.15 * (i + 1)
        za = z_start + TREAD * i
        block(g["detail"], 6.2, 9.3, top, top + 0.004, za + 0.06, za + 0.12, "Soot")
    col = ctx.shared["collision"]
    for (xa, xb, outer) in ((5.86, 6.0, 5.86), (9.5, 9.64, 9.64)):
        cheek = [(-18.3, 0.0), (-18.3, 0.25), (-21.0, 1.6), (-21.0, 0.0)]
        prism(g["shell"], cheek, (xa, 0, 0), (1, 0, 0), xb - xa, "HullDark")
        so = -1 if outer < 7 else 1
        prism(g["detail"], [(-18.3, 0.13), (-18.3, 0.25), (-21.0, 1.6), (-21.0, 1.48)],
              (outer if so > 0 else outer - 0.006, 0, 0), (1, 0, 0), 0.006, "Hazard")
        xm = (xa + xb) / 2
        # Leuning: van onder aan de trap tot de bovenbuis van de reling.
        beam(g["rails"], (xm, 1.05, 18.4), (xm, 2.13, 21.05), 0.09, 0.07, 0.02, "DarkSteel")
        for zp in (18.45, 19.75):
            ytop = 1.05 + (zp - 18.4) * (1.08 / 2.65)
            ybot = 0.25 + (zp - 18.3) * 0.5
            box(g["rails"], (xm, (ytop + ybot) / 2, zp), (0.06, ytop - ybot, 0.07), "DarkSteel")
        prism(col, [(-18.3, 0.0), (-18.3, 1.1), (-21.05, 2.18), (-21.05, 0.0)], (xa, 0, 0), (1, 0, 0), xb - xa,
              "Soot")


# --- Achterwand met consoles -----------------------------------------------------------------------

def back_wall(ctx, g, rng):
    S = g["shell"]
    block(S, 0, 7, Y, 4.5, 26.0, 26.3, WALL)
    block(S, 13, 20, Y, 4.5, 26.0, 26.3, WALL)
    block(S, 7, 13, 3.8, 4.5, 26.0, 26.3, WALL)
    ctx.col_box(0, 7, Y, 4.5, 26.0, 26.3)
    ctx.col_box(13, 20, Y, 4.5, 26.0, 26.3)
    # Platen op de wand boven de consoles, af en toe een plaat van een andere leverancier.
    for (a, c) in ((0.0, 6.62), (13.38, 20.0)):
        panels(S, Patch(G(c, 2.35, 26.0), (-1, 0, 0), (0, 1, 0), c - a, 4.2 - 2.35), rng, cell=(1.7, 0.95),
               lift=0.02, gap=0.05, material="HullDark", alt=[("GreyGreen", 0.14), ("HullGrey", 0.1)], thick=0.08)
    # Plint langs de vrije stukken wand.
    for (a, c) in ((5.5, 6.62), (13.38, 15.6)):
        block(S, a, c, Y, Y + 0.14, 25.92, 26.0, "Anthracite")
    # Ideeënbus (die rechtstreeks in de vuilnisbak uitkomt), met het affiche erboven.
    fr = Frame((0.0, 0.0, 26.0), (0, 0, -1))
    P, D = g["props"], g["detail"]
    bx = 6.05
    fr.box(P, -bx, 2.47, 0.16, 0.36, 0.42, 0.2, "Yellow")
    fr.box(D, -bx, 2.62, 0.262, 0.2, 0.025, 0.006, "Soot")
    fr.text(D, "SUGGESTION", 0.046, -bx, 2.5, 0.263, "DecalDark")
    fr.text(D, "BOX", 0.046, -bx, 2.43, 0.263, "DecalDark")
    D.pipe([G(bx, 2.26, 25.86), G(bx, 1.95, 25.8), G(bx, 1.66, 25.76)], 0.035, 8, "DarkSteel")
    trash_bin(P, D, bx, Y, 25.74, rng)
    ctx.col_box(bx - 0.23, bx + 0.23, Y, 2.7, 25.5, 26.0)
    poster(P, D, fr, -bx, 3.35, 0.09, 0.95, 0.62,
           [("YOUR OPINION", 0.1, 0.13), ("COUNTS", 0.16, -0.04), ("(NOT)", 0.032, -0.23)])
    # Werknemer van het kwartaal (stuurboord).
    poster(P, D, fr, -17.6, 3.42, 0.09, 0.72, 0.95,
           [("EMPLOYEE OF", 0.058, 0.39), ("THE QUARTER", 0.058, 0.32)], frame="Yellow")
    fr.box(D, -17.6, 3.33, 0.11, 0.48, 0.5, 0.004, "DecalDark")
    fr.text(D, "[VACANT]", 0.075, -17.6, 3.33, 0.1135, "Cream")
    fr.box(D, -17.6, 2.99, 0.11, 0.42, 0.06, 0.004, "Yellow")
    fr.text(D, "APPLY NOW", 0.034, -17.6, 2.99, 0.1135, "DecalDark")


def console_bank(ctx, g, x0, x1, rng, wedges):
    """Bureauconsole tegen de achterwand: kast met deurtjes, plat bureaublad met schuine
    bedieningspanelen, een verhoging voor de monitoren."""
    P, D, L = g["props"], g["detail"], g["glow"]
    w = x1 - x0
    zf = 24.95  # voorrand van het blad
    block(P, x0, x1, Y + 0.12, 1.96, 25.1, 26.0, "Anthracite")
    block(g["shell"], x0 + 0.04, x1 - 0.04, Y, Y + 0.12, 25.2, 26.0, "Soot")
    n = max(2, round(w / 0.85))
    for i in range(n):
        a = x0 + w * i / n
        c = x0 + w * (i + 1) / n
        block(D, a + 0.04, c - 0.04, Y + 0.18, 1.9, 25.088, 25.1, "HullDark" if i % 3 else "GreyGreen")
        block(D, c - 0.16, c - 0.12, 1.5, 1.7, 25.075, 25.088, "Steel")
        if i % 2 == 0:
            for j in range(5):
                block(D, a + 0.15, c - 0.25, 1.3 + j * 0.035, 1.315 + j * 0.035, 25.082, 25.088, "Soot")
    block(P, x0 - 0.02, x1 + 0.02, 1.96, 2.0, zf, 26.0, "DarkSteel")
    block(L, x0, x1, 1.95, 1.958, zf + 0.01, zf + 0.03, "LedWhite")
    block(P, x0, x1, 2.0, 2.3, 25.6, 26.0, "Anthracite")
    ctx.col_box(x0, x1, Y, 2.35, zf, 26.0)
    # Schuine panelen: voorrand (z 25,2, y 2,03), achterrand (z 25,6, y 2,18).
    v = (0.0, -0.15, -0.4)
    ln = math.hypot(v[1], v[2])
    nrm = (0.0, 0.4 / ln, -0.15 / ln)
    for (xa, xb) in wedges:
        prism(P, [(-25.2, 2.0), (-25.6, 2.0), (-25.6, 2.18), (-25.2, 2.03)], (xa, 0, 0), (1, 0, 0), xb - xa,
              "DarkSteel")

        def on(xx, s, off):
            return (xx, 2.03 + 0.15 * s + nrm[1] * off, 25.2 + 0.4 * s + nrm[2] * off)

        xc = (xa + xb) / 2
        box(D, on(xc, 0.55, 0.004), (xb - xa - 0.16, 0.2, 0.008),
            rng.choice(["ScreenGreen", "ScreenGreen", "ScreenAmber"]), u=(1, 0, 0), v=v)
        for j in range(3):
            box(D, on(xc - 0.03 * j, 0.68 - 0.1 * j, 0.0095), ((xb - xa) * (0.45 - 0.08 * j), 0.012, 0.002), "Soot",
                u=(1, 0, 0), v=v)
        k = int((xb - xa - 0.1) / 0.075)
        for j in range(k):
            box(D, on(xa + 0.08 + j * 0.075, 0.15, 0.01), (0.04, 0.035, 0.02),
                rng.choice(["LensRed", "Cyan", "LensOrange", "DarkSteel", "DarkSteel"]), u=(1, 0, 0), v=v)
        keyboard(D, Frame((xc, 2.0, 25.06), (0, 0, -1)), 0, 0, 0, min(0.42, xb - xa - 0.1))


# De consoles staan aan stuurboord tegen de achterwand (waar eerst de verhoging stond): OX schuift de
# vroegere bakboordconsole op.
OX = 12.9


def port_console(ctx, g, rng):
    x0, x1 = 0.45 + OX, 5.45 + OX
    console_bank(ctx, g, x0, x1, rng, [(0.55 + OX, 1.35 + OX), (2.45 + OX, 3.25 + OX), (4.35 + OX, 5.15 + OX)])
    P, D = g["props"], g["detail"]
    fr = Frame((0.0, 0.0, 26.0), (0, 0, -1))
    for (x, w, hh, scr, shell, crt, sad, taped) in (
            (0.95, 0.42, 0.33, "ScreenGreen", "Cream", True, False, False),
            (1.85, 0.62, 0.36, "ScreenAmber", "Anthracite", False, False, False),
            (2.85, 0.42, 0.32, "ScreenBlue", "Anthracite", True, True, False),
            (3.85, 0.56, 0.33, "ScreenGreen", "HullGrey", False, False, True),
            (4.85, 0.36, 0.28, "ScreenGreen", "Cream", True, False, False)):
        # 10° gekanteld: het midden ligt ±0,25 m boven het oog van een robot (1,2 m boven de vloer).
        ft = Frame((x + OX, 2.3 + 0.17 + hh / 2, 26.0 - 0.42), (0, 0, -1), tilt=10)
        monitor(P, D, ft, 0.0, 0.0, 0.0, w, hh, scr, rng, shell=shell, crt=crt, sad=sad, taped=taped)
    for (x, m) in ((1.62, "Cream"), (2.12, "Red"), (4.02, "Blue")):
        mug(D, Frame((x + OX, 2.0, 25.08), (0, 0, -1)), 0, 0, 0, m)
    papers(D, Frame((3.7 + OX, 2.0, 25.1), (0, 0, -1)), 0, 0, 0, rng)
    # Klok: tijd is geld.
    cxk = -(2.85 + OX)
    fr.cyl(P, cxk, 3.62, 0.07, (0, 0, 1), 0.05, 0.2, 24, "DarkSteel")
    fr.cyl(D, cxk, 3.62, 0.12, (0, 0, 1), 0.006, 0.17, 24, "Cream")
    fr.box(D, cxk + 0.03, 3.62 + 0.04, 0.13, 0.012, 0.11, 0.006, "DecalDark", roll=-0.6)
    fr.box(D, cxk - 0.04, 3.62 + 0.0, 0.13, 0.08, 0.012, 0.006, "DecalDark", roll=0.3)
    fr.box(D, cxk, 3.355, 0.09, 0.42, 0.07, 0.01, "Cream")
    fr.text(D, "TIME IS MONEY", 0.04, cxk, 3.355, 0.0965, "DecalDark")


def starboard_console(ctx, g, rng):
    """Naast de consoles: de koffieautomaat (de consolebank zelf is de verschoven bakboordconsole)."""
    P, D = g["props"], g["detail"]
    # Koffieautomaat (buiten gebruik).
    cx0, cx1 = 19.05, 19.88
    block(P, cx0, cx1, Y, 2.75, 25.35, 26.0, "Cream")
    block(P, cx0 + 0.05, cx1 - 0.05, Y + 0.25, 2.5, 25.32, 25.35, "DarkSteel")
    block(D, cx0 + 0.22, cx1 - 0.22, 1.65, 1.98, 25.31, 25.322, "Soot")
    block(D, cx0 + 0.2, cx1 - 0.2, 1.63, 1.66, 25.24, 25.322, "Steel")
    mug(D, Frame((19.465, 1.66, 25.29), (0, 0, -1)), 0, 0, 0, "Cream")
    block(D, cx0 + 0.15, cx1 - 0.15, 2.12, 2.24, 25.31, 25.322, "ScreenAmber")
    for j in range(4):
        block(D, cx0 + 0.16 + j * 0.13, cx0 + 0.24 + j * 0.13, 2.3, 2.36, 25.305, 25.322,
              "LensOrange" if j else "LensRed")
    text(D, "COFFEE", 0.11, (19.465, 2.58, 25.315), (0, 0, -1), "Red")
    block(D, cx0 + 0.12, cx1 - 0.12, 2.04, 2.1, 25.317, 25.322, "Yellow")
    text(D, "€2 + CUP €1", 0.026, (19.465, 2.07, 25.314), (0, 0, -1), "DecalDark")
    fr2 = Frame((19.47, 1.82, 25.30), (0, 0, -1))
    fr2.box(D, 0.08, 0.0, 0.0, 0.3, 0.17, 0.003, "Cream", roll=0.08)
    fr2.text(D, "OUT OF", 0.045, 0.08, 0.03, 0.002, "DecalDark")
    fr2.text(D, "ORDER", 0.045, 0.08, -0.03, 0.002, "DecalDark")
    for k in range(3):
        mug(D, Frame((19.3 + k * 0.14, 2.75 + (0.1 if k == 1 else 0.0), 25.7), (0, 0, -1)), 0, 0, 0,
            ["Cream", "Red", "Blue"][k])
    ctx.col_box(cx0, cx1, Y, 2.75, 25.3, 26.0)


# --- Zijwanden ----------------------------------------------------------------------------------------

def side_walls(ctx, g, rng):
    P, D, L = g["props"], g["detail"], g["glow"]
    # Kolommen onder de rand van de luifel (bakboord en stuurboord).
    for (a, c) in ((0.0, 0.34), (19.66, 20.0)):
        beam(P, ((a + c) / 2, Y, 23.5), ((a + c) / 2, 4.2, 23.5), 0.34, 0.36, 0.07, "DarkSteel", up=(0, 0, -1))
        block(L, a + 0.12, c - 0.12, Y + 0.3, 3.9, 23.31, 23.32, "LedAmber")
        ctx.col_box(a, c, Y, 4.2, 23.32, 23.68)
    S = g["shell"]
    for (z0, z1, y0) in ((21.0, 23.3, Y), (23.7, 25.9, 2.35)):
        panels(S, Patch(G(0.0, y0, z1), (0, 0, -1), (0, 1, 0), z1 - z0, 4.15 - y0), rng, cell=(1.2, 1.0), lift=0.02,
               gap=0.05, material="HullDark", alt=[("GreyGreen", 0.15), ("Anthracite", 0.15)], thick=0.08)
    for (z0, z1, y0) in ((21.0, 23.3, Y), (23.7, 25.3, Y)):
        panels(S, Patch(G(20.0, y0, z0), (0, 0, 1), (0, 1, 0), z1 - z0, 4.15 - y0), rng, cell=(1.2, 1.0), lift=0.02,
               gap=0.05, material="HullDark", alt=[("GreyGreen", 0.15), ("Anthracite", 0.15)], thick=0.08)
    for (x0, x1) in ((0.0, 0.1), (19.9, 20.0)):
        block(S, x0, x1, Y, Y + 0.15, 21.0, 23.32, "Anthracite")
    # Koersbord (bakboordwand), met een rood gloeiend doel en een kooilamp erboven. ("Dagen zonder
    # ongeval" hing hier ook al; dat bord hangt nu enkel bij de baai, waar de ongevallen gebeuren.)
    fr = Frame((0.0, 0.0, 22.3), (1, 0, 0))
    fr.box(P, 0, 2.65, 0.11, 1.3, 0.85, 0.06, "DarkSteel")
    fr.box(D, 0, 2.86, 0.142, 1.2, 0.36, 0.004, "Yellow")
    fr.text(D, "HEADING", 0.11, 0, 2.86, 0.145, "DecalDark")
    fr.box(D, 0, 2.47, 0.142, 1.1, 0.34, 0.004, "Soot")
    fr.text(D, "PROFIT", 0.2, 0, 2.5, 0.145, "LensRed")
    fr.text(D, "ARRIVAL: WHEN IT SUITS US", 0.03, 0, 2.34, 0.145, "Cream")
    fr.box(P, 0, 3.32, 0.12, 0.2, 0.06, 0.1, "DarkSteel")
    fr.box(P, 0, 3.3, 0.24, 0.04, 0.03, 0.2, "DarkSteel")
    fr.cyl(L, 0, 3.24, 0.32, (0, 1, 0), 0.05, 0.05, 10, "Bulb")
    for (da, dd) in ((0.055, 0.0), (-0.055, 0.0), (0.0, 0.055), (0.0, -0.055)):
        fr.box(D, da, 3.25, 0.32 + dd, 0.008, 0.1, 0.008, "DarkSteel")
    fr.cyl(D, 0, 3.2, 0.32, (0, 1, 0), 0.012, 0.065, 10, "DarkSteel")
    ctx.glow("ffc890", (0.45, 3.15, 22.3))
    ctx.col_box(0.0, 0.2, 2.2, 3.1, 21.6, 23.0)
    # Reparatieset (stuurboordwand), leeg, en een blusser.
    fr = Frame((20.0, 0.0, 22.2), (-1, 0, 0))
    fr.box(P, 0, 2.55, 0.11, 0.62, 0.5, 0.18, "Cream")
    fr.box(D, 0, 2.55, 0.201, 0.5, 0.06, 0.004, "Red")
    fr.text(D, "REPAIR KIT", 0.05, 0, 2.7, 0.203, "DecalDark")
    sticky(D, fr, 0.12, 2.42, 0.203, random.Random(5))
    fr.text(D, "EMPTY", 0.022, 0.12, 2.42, 0.2055, "DecalDark")
    fr.cyl(P, -0.5, Y + 0.05, 0.12, (0, 1, 0), 0.5, 0.075, 12, "Red")
    fr.cyl(D, -0.5, Y + 0.55, 0.12, (0, 1, 0), 0.07, 0.03, 8, "DarkSteel")
    ctx.col_box(19.75, 20.0, Y, 2.85, 21.6, 22.55)


# --- Luifel ---------------------------------------------------------------------------------------------

def overhang(ctx, g):
    R, RD, L = g["roof"], g["roofd"], g["glow"]
    block(R, 0, 20, 4.2, 4.5, 23.5, 26.3, WALL)
    # Wenkbrauw: de afgeschuinde voorrand, met een witte ledlijn eronder.
    prism(R, [(-23.5, 4.14), (-23.36, 4.14), (-23.28, 4.22), (-23.28, 4.54), (-23.36, 4.62), (-23.5, 4.62)],
          (0, 0, 0), (1, 0, 0), 20.0, "DarkSteel")
    block(L, 0.4, 19.6, 4.13, 4.14, 23.32, 23.36, "LedWhite")
    # Plafondvakken en dwarsliggers met amberen lichtribben (niet boven de tafel: daar hangt de kroon).
    xs = [1.25, 3.85, 6.45, 9.05, 16.95, 19.55]
    edges = [0.0] + xs[:4] + [11.7, 14.3] + xs[4:] + [20.0]
    for a, c in zip(edges, edges[1:]):
        block(R, a + 0.12, c - 0.12, 4.16, 4.2, 23.62, 25.92, "Anthracite" if c - a > 2.0 else "HullDark")
    for x in xs:
        beam(R, (x, 4.08, 23.5), (x, 4.08, 26.0), 0.2, 0.24, 0.05, "DarkSteel")
        block(L, x - 0.025, x + 0.025, 3.954, 3.962, 23.6, 25.9, "LedAmber")
    # Kabelgoot over de hele breedte, achter de kroon langs.
    block(RD, 0.2, 19.8, 3.86, 3.875, 25.48, 25.78, "DarkSteel")
    for z in (25.48, 25.765):
        block(RD, 0.2, 19.8, 3.875, 3.93, z, z + 0.015, "DarkSteel")
    for k, m in enumerate(("Rubber", "Red", "Rubber", "Yellow", "Rubber")):
        RD.cyl(G(0.2, 3.9 + (k % 2) * 0.02, 25.53 + k * 0.05), (1, 0, 0), 19.6, 0.02, 6, m)
    for x in xs:
        block(RD, x - 0.02, x + 0.02, 3.875, 3.96, 25.6, 25.64, "Steel")
        block(RD, x - 0.14, x + 0.14, 3.88, 3.96, 24.1, 24.32, "Anthracite")
        block(RD, x - 0.1, x + 0.1, 3.874, 3.88, 24.14, 24.28, "DarkSteel")
    for (x, z) in ((2.55, 23.95), (5.15, 25.2), (18.25, 23.95), (10.4, 25.2)):
        block(RD, x - 0.4, x + 0.4, 4.13, 4.16, z - 0.18, z + 0.18, "Soot")
        for k in range(6):
            block(RD, x - 0.37, x + 0.37, 4.12, 4.135, z - 0.15 + k * 0.06, z - 0.13 + k * 0.06, "DarkSteel")
    # Armaturen boven de consoles.
    for x in (2.55, 5.15, 18.25, 15.7):
        block(RD, x - 0.45, x + 0.45, 3.8, 3.86, 24.55, 24.85, "Anthracite")
        block(L, x - 0.4, x + 0.4, 3.792, 3.8, 24.59, 24.81, "LedCool")  # brug: koud wit
        for xx in (x - 0.35, x + 0.35):
            block(RD, xx - 0.012, xx + 0.012, 3.86, 4.2, 24.69, 24.71, "Steel")
    ctx.glow("d6e6ff", (3.85, 3.7, 24.9))
    ctx.glow("d6e6ff", (17.2, 3.7, 24.9))
    sx, sz = 8.4, 23.75
    block(RD, sx - 0.03, sx + 0.03, 3.98, 4.2, sz - 0.03, sz + 0.03, "Steel")
    RD.cyl(G(sx, 3.98, sz), (0, -1, 0), 0.22, 0.13, 12, "Anthracite", r2=0.17)
    RD.cyl(G(sx, 3.755, sz), (0, -1, 0), 0.006, 0.15, 12, "LedCool")
    ctx.spot("d8e8ff", (sx, 3.72, sz))


# --- Wand boven de luifel (naar de hangar) -------------------------------------------------------------

def fascia(ctx, g, rng):
    S, P, D, L = g["shell"], g["props"], g["detail"], g["glow"]
    block(S, 0, 20, 4.2, 9.4, 23.5, 23.8, WALL)
    bays = [(0.0, 0.6), (4.95, 5.45), (14.55, 15.05), (19.4, 20.0)]
    for (a, c) in bays:  # pilasters met schuine liggers naar het hangarplafond
        x = (a + c) / 2
        beam(P, (x, 4.62, 23.32), (x, 9.0, 23.32), c - a, 0.36, 0.08, "DarkSteel", up=(0, 0, -1))
        beam(P, (x, 7.3, 23.2), (x, 8.98, 21.9), 0.24, 0.24, 0.05, "DarkSteel")
        block(L, x - 0.04, x + 0.04, 8.1, 8.2, 23.135, 23.14, "LensOrange")
    for (a, c) in ((0.6, 4.95), (5.45, 14.55), (15.05, 19.4)):
        panels(S, Patch(G(c, 4.64, 23.5), (-1, 0, 0), (0, 1, 0), c - a, 4.34), rng, cell=(2.2, 1.45), lift=0.03,
               gap=0.06, material="HullDark", alt=[("GreyGreen", 0.18), ("HullGrey", 0.12)], thick=0.1)
    # Leidingen boven de wenkbrauw.
    for (y, r, m) in ((4.82, 0.07, "Steel"), (4.98, 0.05, "Copper")):
        P.pipe([G(0.3, y, 23.3), G(19.7, y, 23.3)], r, 8, m, clamps=1.8)
    # Het DIG-embleem: een gele zeshoek, de letters, de naam en een slogan.
    hexo = [(1.3 * math.cos(math.radians(30 + 60 * k)), 1.3 * math.sin(math.radians(30 + 60 * k))) for k in range(6)]
    hexi = [(1.08 * math.cos(math.radians(30 + 60 * k)), 1.08 * math.sin(math.radians(30 + 60 * k))) for k in range(6)]
    prism(P, hexo, (10.0, 7.15, 23.44), (0, 0, -1), 0.08, "Yellow")
    prism(D, hexi, (10.0, 7.15, 23.36), (0, 0, -1), 0.012, "DecalDark")
    text(D, "DIG", 0.95, (10.0, 7.12, 23.345), (0, 0, -1), "Yellow", extrude=0.015, res=3)
    block(P, 5.7, 14.3, 5.35, 5.78, 23.4, 23.42, "DecalDark")
    text(D, "DIEPGANG INTERPLANETARY GROUNDWORKS", 0.25, (10.0, 5.565, 23.397), (0, 0, -1), "Cream")
    block(P, 7.6, 12.4, 4.9, 5.2, 23.405, 23.42, "DecalDark")
    text(D, "PROFIT IS A TEAM EFFORT", 0.15, (10.0, 5.05, 23.402), (0, 0, -1), "Yellow")
    # Twee banieren (zwart met gele rand en een zwaluwstaart).
    for (x, lines) in ((2.78, ("DIG", "DEEPER")), (17.22, ("COMPLAINING", "COSTS EXTRA"))):
        banner(g, x, lines)


def banner(g, x, lines):
    P, D = g["props"], g["detail"]
    y_top, y_bot, w = 8.45, 5.15, 1.6
    P.cyl(G(x - w / 2 - 0.12, y_top + 0.05, 23.3), (1, 0, 0), w + 0.24, 0.03, 8, "Steel")
    for s in (-1, 1):
        block(P, x + s * (w / 2 + 0.08) - 0.03, x + s * (w / 2 + 0.08) + 0.03, y_top, y_top + 0.12, 23.3, 23.44,
              "DarkSteel")
        P.cyl(G(x + s * (w / 2 + 0.12), y_top + 0.05, 23.3), (s, 0, 0), 0.05, 0.045, 8, "DarkSteel")
    offs = [-0.5, -0.46, -0.25, 0.0, 0.25, 0.46, 0.5]
    tail = [0.0, 0.05, 0.22, 0.4, 0.22, 0.05, 0.0]
    cols = [(x + o * w, 23.33 + 0.018 * math.sin(i * 1.3), y_bot + t) for i, (o, t) in enumerate(zip(offs, tail))]
    rows = [0.0, 0.03, 0.055, 0.5, 0.93, 1.0]

    def mat(r, c):
        if c in (0, len(offs) - 2) or r in (1, 4):
            return "Yellow"
        return "DecalDark"

    cloth(D, cols, y_top, rows, 0.012, mat)
    zt = 23.33 - 0.025
    text(D, "DIG", 0.56, (x, 7.75, zt), (0, 0, -1), "Yellow")
    hexo = [(x + 0.32 * math.cos(math.radians(30 + 60 * k)), 0.32 * math.sin(math.radians(30 + 60 * k)))
            for k in range(6)]
    for k in range(6):
        a, c = hexo[k], hexo[(k + 1) % 6]
        tbox(D, (a[0], 6.85 + a[1], zt), (c[0], 6.85 + c[1], zt), 0.05, 0.004, "Yellow", up=(0, 0, 1))
    prism(D, [(-0.13, 0.08), (0.13, 0.08), (0.0, -0.16)], (x, 6.85, zt + 0.004), (0, 0, -1), 0.006, "Yellow")
    for i, ln in enumerate(lines):
        text(D, ln, 0.17 if len(ln) < 8 else 0.14, (x, 6.15 - i * 0.24, zt), (0, 0, -1), "Cream")
