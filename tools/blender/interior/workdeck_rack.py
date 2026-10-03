"""Laadrek (+0,6, plafond 2,4): vier laadcapsules in de geest van de cryokamers van de Super Destroyer
(kabels, statuslampjes, cyaan), de trap van 4 treden naar het werkdek, en DIG-bordjes.
Spawn_0..3 staan voor de capsules en kijken naar voren (−z). Onderdeel van zone_workdeck.py."""

from layout import RACK, RISER, TREAD, WALL, block, slab
from workdeck_kit import Face, blk, box, cable, cyl, lines, sign, slab_poly, tape, text, torus, wall_seg
from workdeck_room import Plane, ceil_plate, floor_plate, panel_wall, prism_z, strip_line

YF, YT = 0.6, 3.0  # vloer en plafond van het laadrek
PODS = (7.0, 9.0, 11.0, 13.0)
ZF = 42.42  # voorkant van de capsules


def shell(ctx, S, R, ST, PN, D, RD, rng):
    rx0, rx1, rz0, rz1 = RACK
    # Trap van 4 treden omlaag (zelfde maten als layout.stairs_z), met een stalen neus en een smalle
    # ledlijn erop, en de helling in de botsvorm. Rustig gehouden: dit is het eerste beeld van elke
    # dienst (vroeger gaven ledlijnen op neus én stootbord acht fel gloeiende strepen onderin het beeld).
    for i in range(4):
        top = 1.2 - RISER * i
        za, zb = 40.0 + TREAD * i, 40.0 + TREAD * (i + 1)
        blk(ST, rx0, rx1, 0.0, top, za, zb, "Floor")
        blk(ST, rx0 + 0.15, rx1 - 0.15, top - 0.05, top + 0.006, zb - 0.05, zb, "DarkSteel")
        # Kaal gesleten in het midden, waar elke robot van de laadcapsules naar het werkdek stapt.
        blk(D, 8.6, 11.4, top + 0.006, top + 0.008, zb - 0.05, zb - 0.004, "Steel")
        for x in (rx0 + 0.3, 11.5):  # ledlijn enkel naast het looppad (niet erover: daar is hij weggesleten)
            blk(D, x, x + (8.5 - rx0 - 0.3 if x < 10 else rx1 - 0.3 - 11.5), top + 0.006, top + 0.01, zb - 0.032,
                zb - 0.022, "LedWhite")
        for x in (rx0 + 0.15, rx1 - 0.35):  # geel-zwart aan de uiteinden
            blk(D, x, x + 0.2, top + 0.001, top + 0.005, za + 0.02, zb - 0.06, "Hazard")
        # Stootbord (kijkt naar het laadrek): een donkere plaat met schoppen van robotvoeten.
        lo = top - RISER
        blk(D, rx0 + 0.3, rx1 - 0.3, lo + 0.035, top - 0.055, zb, zb + 0.008, "DarkSteel")
        for xs in (9.1, 9.9, 10.6):
            blk(D, xs, xs + 0.22, lo + 0.04, lo + 0.07, zb + 0.008, zb + 0.01, "Steel")
    ctx.col_ramp(rx0, rx1, 41.2, 40.0, YF, 1.2)
    # Latei op de overgang naar het werkdek (kant laadrek), met een waarschuwing.
    blk(R, rx0, rx1, 2.82, YT, 40.0, 40.26, "Anthracite")
    ctx.col_box(rx0, rx1, 2.82, YT, 40.0, 40.26)
    blk(D, rx0 + 0.2, rx1 - 0.2, 2.84, 2.98, 40.26, 40.272, "Hazard")
    blk(D, 8.6, 11.4, 2.85, 2.97, 40.272, 40.276, "DecalDark")
    text(D, "LET OP UW HOOFD", 0.065, (10.0, 2.91, 40.276), (0, 0, 1), "Yellow")
    slab(S, rx0, rx1, rz0, rz1, YF)
    ctx.col_box(rx0, rx1, -0.6, YF, rz0, rz1)
    block(R, rx0, rx1, YT, YT + 0.3, 40.0, rz1 + 0.3, WALL)
    ctx.col_box(rx0, rx1, YT, YT + 0.3, 40.0, rz1 + 0.3)  # een springende robot raakt het plafond
    for x in (rx0, rx1):
        block(S, x - 0.15, x + 0.15, YF, YT, 40.0, rz1 + 0.3, WALL)
        ctx.col_box(x - 0.15, x + 0.15, YF, YT, 40.0, rz1 + 0.3)
    block(S, rx0, rx1, YF, YT, rz1, rz1 + 0.3, WALL)
    ctx.col_box(rx0, rx1, YF, YT, rz1, rz1 + 0.3)
    # Vloerplaten.
    for i in range(4):  # de middelste twee zijn gesleten (de weg naar de trap)
        x0 = 6.15 + i * 1.925
        floor_plate(PN, x0 + 0.02, x0 + 1.905, rz0 + 0.02, 42.4, YF, 0.016, 0.012,
                    "FloorWorn" if i in (1, 2) else "Floor")
    # Rubberen strips op de treden (grip).
    for i in range(1, 4):
        top = 1.2 - 0.15 * i
        z = 40.0 + 0.3 * i
        for dz in (0.11, 0.2):
            blk(D, 6.4, 13.6, top, top + 0.004, z + dz, z + dz + 0.05, "Rubber")
    # Schuine hoeken boven (achthoekig, zoals de cryokamer), met cyaan ledstroken.
    prism_z(PN, [(6.15, 2.55), (6.6, YT), (6.15, YT)], 40.15, 44.0, "HullDark")
    prism_z(PN, [(13.85, 2.55), (13.85, YT), (13.4, YT)], 40.15, 44.0, "HullDark")
    for s, x in ((1, 6.375), (-1, 13.625)):
        t = (s * 0.7071, 0.7071, 0.0)
        nn = (s * 0.7071, -0.7071, 0.0)
        box(D, (x + nn[0] * 0.006, 2.775 + nn[1] * 0.006, 42.1), (0.04, 0.012, 3.7), u=t, v=nn, m="LedCyanSoft")
    # Zijwanden: platen, buizen, bordjes.
    lf = Face((6.15, YF, 44.0), (0, 0, -1), (0, 1, 0))  # links, kijkt +x, a = 44 − z
    rf = Face((13.85, YF, 40.0), (0, 0, 1), (0, 1, 0))  # rechts, kijkt −x, a = z − 40
    rows = [(0.0, 0.4, "Anthracite"), (0.4, 1.15, "HullDark"), (1.15, 1.95, "HullDark")]
    panel_wall(PN, lf, [1.55, 2.3, 3.05, 4.0], rows, rng)
    panel_wall(PN, rf, [0.0, 0.95, 1.7, 2.45], rows, rng)
    for x, s in ((6.15, 1), (13.85, -1)):
        pipe_z = (40.25, 42.3)
        for (dy, r, m) in ((2.2, 0.045, "Steel"), (2.33, 0.035, "Copper"), (2.43, 0.03, "Steel")):
            cyl(D, (x + s * 0.09, dy, pipe_z[0]), (0, 0, 1), pipe_z[1] - pipe_z[0], r, 8, m)
        for z in (40.6, 41.6):
            blk(D, *sorted((x, x + s * 0.14)), 2.12, 2.5, z - 0.03, z + 0.03, "DarkSteel")
    sign(D, D, lf, 2.95, 1.25, 1.65, 0.42, [("OPLADEN IS EEN GUNST,", 0.065), ("GEEN RECHT", 0.065)],
         bg="Yellow", fg="DecalDark", border="DecalDark", gap=0.45, h0=0.07)
    sign(D, D, rf, 1.25, 1.25, 1.65, 0.42, [("STROOMVERBRUIK WORDT", 0.05), ("VERREKEND MET UW LOON", 0.05)],
         bg="DecalDark", fg="Yellow", gap=0.5, h0=0.07)
    # Plafond: platen, een lichtbak langs x (koel wit) en een kabelgoot naar de capsules.
    for (x0, x1) in ((6.62, 8.5), (8.6, 10.0), (10.0, 11.4), (11.5, 13.38)):
        ceil_plate(RD, x0 + 0.02, x1 - 0.02, 40.2, 41.45, YT, 0.035, 0.02, "HullDark")
    blk(RD, 6.8, 13.2, 2.86, 2.97, 41.62, 41.88, "Anthracite")
    blk(RD, 6.85, 13.15, 2.85, 2.86, 41.67, 41.83, "LedWhite")
    for x in (6.8, 13.2):
        blk(RD, x - 0.03, x + 0.03, 2.84, 2.99, 41.6, 41.9, "DarkSteel")
    blk(RD, 6.6, 13.4, 2.9, 2.92, 42.0, 42.35, "DarkSteel")
    for z in (42.0, 42.35):
        blk(RD, 6.6, 13.4, 2.92, 2.96, z - 0.01, z + 0.01, "DarkSteel")
    for i, (dz, m) in enumerate(((42.08, "Rubber"), (42.17, "Red"), (42.26, "Rubber"))):
        cyl(RD, (6.6, 2.955, dz), (1, 0, 0), 6.8, 0.03, 6, m)
    ctx.glow("7fdcf0", (8.0, 2.8, 41.25))
    ctx.glow("7fdcf0", (12.0, 2.8, 41.25))


def pod(ctx, P, PN, D, px, i):
    """Laadcapsule: halve achthoek, open aan de voorkant, cyaan licht onder de hoed, een laadkabel in de
    rug, en per capsule een warme statusrand (amber = laden, rood = defect) met een laadmeter."""
    zb = 43.98
    foot = [(px - 0.78, ZF + 0.05), (px + 0.78, ZF + 0.05), (px + 0.78, 43.55), (px + 0.45, zb), (px - 0.45, zb),
            (px - 0.78, 43.55)]
    slab_poly(P, foot, YF, YF + 0.12, "Anthracite", inset=0.03)
    for k in range(5):  # rooster in de vloer van de capsule
        blk(D, px - 0.5, px + 0.5, YF + 0.12, YF + 0.135, 42.75 + k * 0.2, 42.8 + k * 0.2, "DarkSteel")
    # Wanden (achter, schuin, zij), een hoed bovenaan, een kroon tot het plafond.
    segs = [((px - 0.78, ZF + 0.25), (px - 0.78, 43.55)), ((px - 0.78, 43.55), (px - 0.45, zb)),
            ((px - 0.45, zb), (px + 0.45, zb)), ((px + 0.45, zb), (px + 0.78, 43.55)),
            ((px + 0.78, 43.55), (px + 0.78, ZF + 0.25))]
    for p, q in segs:
        wall_seg(P, p, q, YF + 0.12, 2.62, 0.06, "HullDark")
    slab_poly(P, foot, 2.62, 2.72, "Anthracite")
    blk(P, px - 0.5, px + 0.5, 2.72, YT, 43.05, 44.0, "Anthracite")
    for dx in (-0.25, 0.0, 0.25):  # slangen van de kroon naar het plafond
        cyl(D, (px + dx, 2.72, 43.02), (0, 1, 0), 0.28, 0.04, 8, "Rubber")
        cyl(D, (px + dx, 2.8, 43.02), (0, 1, 0), 0.05, 0.05, 8, "DarkSteel")
    # Binnenkant: ribben, kussen in de rug, en enkel het cyaan lichtpaneel onder de hoed (de vroegere
    # cyaan stroken langs de wanden maakten van het rek één vlakke cyaan muur).
    for dx in (-0.3, 0.3):
        blk(D, px + dx - 0.03, px + dx + 0.03, 0.8, 2.55, zb - 0.07, zb - 0.03, "DarkSteel")
    blk(D, px - 0.24, px + 0.24, 1.05, 2.3, zb - 0.09, zb - 0.03, "Rubber")
    for k in range(5):  # kussens in de rug
        blk(D, px - 0.22, px + 0.22, 1.08 + k * 0.245, 1.3 + k * 0.245, zb - 0.11, zb - 0.09, "HullGrey")
    blk(D, px - 0.45, px + 0.45, 2.605, 2.62, 42.75, 43.6, "LedCyanSoft")
    # Laadkabel: dik, uit de hoed, in een lus naar een gele stekker op schouderhoogte van de robot.
    cyl(D, (px + 0.32, 2.6, 43.72), (0, -1, 0), 0.08, 0.075, 10, "DarkSteel")  # doorvoer in de hoed
    cable(D, (px + 0.32, 2.56, 43.72), (px + 0.1, 1.98, 43.5), 0.4, 0.055, 12, "Rubber", 8)
    blk(D, px + 0.0, px + 0.2, 1.84, 2.02, 43.36, 43.52, "Yellow")  # stekker
    blk(D, px + 0.0, px + 0.2, 1.84, 1.87, 43.355, 43.52, "Hazard")
    for dx in (0.06, 0.14):
        cyl(D, (px + dx, 1.93, 43.36), (0, 0, -1), 0.06, 0.012, 6, "Steel")
    torus(D, (px + 0.14, 1.6, 43.82), (0, 0, 1), 0.07, 0.013, 10, 4, "Rubber")
    # Voorkader met geel-zwart onderaan en een cyaan ledrand; bovenaan het statusbord.
    defect = i == 2
    for s in (-1, 1):
        blk(P, *sorted((px + s * 0.7, px + s * 0.88)), YF, 2.62, ZF, ZF + 0.28, "Anthracite")
        if s > 0:
            blk(D, *sorted((px + s * 0.71, px + s * 0.87)), YF + 0.15, 1.15, ZF - 0.012, ZF, "Hazard")
            continue
        # Laadmeter op de andere stijl: vijf blokjes, bijna allemaal uit (iedereen staat op 1 à 11%).
        blk(D, px - 0.86, px - 0.72, 0.78, 1.17, ZF - 0.01, ZF, "DecalDark")
        for k in range(5):
            yk = 0.8 + k * 0.073
            on = k < (1, 1, 0, 1)[i]
            blk(D, px - 0.84, px - 0.74, yk, yk + 0.055, ZF - 0.014, ZF - 0.01,
                ("LedRedSoft" if defect else "LedAmberSoft") if on else "Soot")
    blk(P, px - 0.88, px + 0.88, 2.36, 2.74, ZF, ZF + 0.28, "Anthracite")
    for s in (-1, 1):
        x = px + s * 0.7
        prism_z(P, [(x, 2.36), (x, 2.1), (x - s * 0.26, 2.36)], ZF, ZF + 0.26, "Anthracite")
        prism_z(P, [(x, YF + 0.12), (x, YF + 0.3), (x - s * 0.18, YF + 0.12)], ZF, ZF + 0.26, "Anthracite")
        for z in (42.95, 43.3):
            blk(D, *sorted((px + s * 0.75, px + s * 0.7)), 0.8, 2.55, z - 0.025, z + 0.025, "DarkSteel")
        cyl(D, (px + s * 0.42, 2.62, 43.9), (0, -1, 0), 1.75, 0.03, 6, "Rubber")
    strip_line(D, [(px - 0.79, 1.22), (px - 0.79, 2.42), (px + 0.79, 2.42), (px + 0.79, 1.22)],
               Plane("z", ZF, -1), 0.03, "LedRedSoft" if defect else "LedAmberSoft")
    zf = ZF
    blk(D, px - 0.27, px + 0.27, 2.5, 2.68, zf - 0.012, zf, "Screen")
    text(D, ("LADEN 3%", "LADEN 11%", "DEFECT", "LADEN 1%")[i], 0.05, (px, 2.59, zf - 0.012), (0, 0, -1),
         "ScreenAmber" if defect else "ScreenCyan", lift=0.002)
    text(D, f"0{i + 1}", 0.1, (px - 0.6, 2.59, zf), (0, 0, -1), "Yellow")
    cyl(D, (px + 0.6, 2.59, zf), (0, 0, -1), 0.012, 0.03, 8, "LensRed" if defect else "LedGreen")
    if defect:
        f = Face((px, 2.59, zf - 0.016), (-1, 0, 0), (0, 1, 0))
        tape(D, f, -0.3, -0.1, 0.3, 0.1, 0.0, 0.05)
        tape(D, f, -0.3, 0.1, 0.3, -0.1, 0.004, 0.05)
        sign(D, D, Face((px + 0.79, YF, ZF), (-1, 0, 0), (0, 1, 0)), 0.0, 1.05, 0.3, 0.3,
             [("DEFECT", 0.04), ("MELD BIJ", 0.022), ("FACILITAIR", 0.022), ("(GESLOTEN)", 0.018)],
             bg="Cream", fg="DecalDark", depth=0.004, tilt=5, gap=0.5, h0=0.014)
    # Kabels tussen de kronen (hangen door).
    if i < 3:
        cable(D, (px + 0.5, 2.92, 43.5), (px + 1.5, 2.92, 43.5), 0.32, 0.035, 8, "Rubber")
        cable(D, (px + 0.5, 2.95, 43.75), (px + 1.5, 2.95, 43.75), 0.2, 0.025, 8, "Red" if i == 1 else "Rubber")
    # Vloervak voor de capsule (de spawnplek), met het nummer.
    for (x0, x1, z0, z1) in ((px - 0.6, px + 0.6, 41.62, 41.67), (px - 0.6, px + 0.6, 42.33, 42.38),
                             (px - 0.6, px - 0.55, 41.62, 42.38), (px + 0.55, px + 0.6, 41.62, 42.38)):
        blk(D, x0, x1, YF + 0.017, YF + 0.021, z0, z1, "Yellow")
    text(D, f"0{i + 1}", 0.16, (px, YF + 0.02, 41.85), (0, 1, 0), "Yellow", up=(0, 0, 1))
    ctx.col_box(px - 0.88, px + 0.88, YF, YT, ZF - 0.02, 44.0)
    ctx.anchor(f"Spawn_{i}", (px, YF, 42.1), 0)


def back_wall(D):
    """Achterwand tussen de capsules: leidingen en een zekeringkastje."""
    for k, x in enumerate((8.0, 10.0, 12.0)):
        for dx, r, m in ((-0.12, 0.05, "Steel"), (0.0, 0.035, "Copper"), (0.12, 0.05, "Steel")):
            cyl(D, (x + dx, YF, 43.9), (0, 1, 0), YT - YF, r, 8, m)
        blk(D, x - 0.17, x + 0.17, 1.35, 1.75, 43.7, 43.96, "Anthracite")
        cyl(D, (x + 0.1, 1.68, 43.7), (0, 0, -1), 0.012, 0.018, 6, "LedGreen" if k != 1 else "LensRed")
        lines(D, [("ZEKERINGEN", 0.022), ("NIET AANKOMEN", 0.016)], (x, 1.5, 43.7), (0, 0, -1), "Yellow", gap=0.6)


def build_rack(ctx, S, R, ST, P, PN, D, RD, rng):
    shell(ctx, S, R, ST, PN, D, RD, rng)
    for i, px in enumerate(PODS):
        pod(ctx, P, PN, D, px, i)
    back_wall(D)
