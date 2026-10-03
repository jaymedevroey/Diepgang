"""De valschacht onder de dropbaai en de klemmen die de Mol vasthouden (zone_hangar.py).

Tijdens het aftellen gaan de luiken open en valt de Mol ±7 m door deze schacht, voor hij naar het
buitenschip springt. Zonder schacht keek je door de open baai recht in de lucht onder het schip.
Plancoördinaten (layout.py).

- Schacht: wanden van −0,61 tot −8 m, binnenkant x 1,75..12,25 en z 1,75..16,25. Ruimer dan de baai
  (x 3..11): een open luik zwaait tot 1,1 m voorbij de rand (DOOR_OPEN_DEG 100°, met de ribben
  eronder). Geen bodem en geen botsvorm onderaan: wie valt, valt erdoor (Ekster.below_floor). Wat je
  ver onder het schip ziet, is van de hemel/het terrein, niet van dit model.
- Shaft_Lights: aparte emissieve mesh (stroken in de schacht), zodat de drop-effecten ze kunnen
  laten knipperen.
- Clamp_0..3: klemarmen (aparte meshes) die de Mol onder de onderrand van zijn romp vasthouden. Ze
  hangen aan een paal op de baairand; oorsprong op het scharnier bovenaan de paal, as = z (langs de
  Mol). Loslaten: Clamp_0/1 (bakboord) rotation.z = −CLAMP_OPEN_DEG, Clamp_2/3 (stuurboord) +: de
  haak zwaait meteen naar buiten en omlaag, weg van de romp (kan tegelijk met het lossen).
"""

import math
import random

from builder import Builder
from hangar_kit import MISMATCH, beam, box, cyl, fbox, obox, vent_on
from hangar_room import pick
from layout import TRIM, WALL

SX0, SX1 = 1.75, 12.25  # binnenkant van de schacht
SZ0, SZ1 = 1.75, 16.25
TOP, BOT = -0.61, -8.0  # 1 cm onder de vloerplaten (geen gelijke vlakken met de put)
T = 0.3  # wanddikte
LIP = 0.6  # dikte van de buitenromp onderaan
RIB_Y = (-1.9, -3.5, -5.1, -6.7)
CLAMP_OPEN_DEG = 35.0  # verder raakt de haak de paal; +: de arm zwaait in de romp van de Mol
# Onderrand van de romp van de Mol (gemeten in mol.glb, lokaal x ±2,4, y −1,2; daaronder een schuine
# kant met normaal (±0,77, −0,63)), op z −3 en +3 van de as.
HULL_EDGE = (2.4, -1.2)
CHAMFER_N = (0.77, 0.63)


def _walls(ctx, B, rng):
    shell, det, props = B["shell"], B["det"], B["props"]
    walls = ((SX0 - T, SX0, SZ0 - T, SZ1 + T), (SX1, SX1 + T, SZ0 - T, SZ1 + T),
             (SX0, SX1, SZ0 - T, SZ0), (SX0, SX1, SZ1, SZ1 + T))
    for (x0, x1, z0, z1) in walls:
        box(shell, x0, x1, BOT, TOP, z0, z1, WALL)
        ctx.col_box(x0, x1, BOT, TOP, z0, z1)
    # Spanten rond de schacht (binnenkant), met platen ertussen (een paar van een andere leverancier).
    for y in RIB_Y:
        for (x0, x1, z0, z1) in ((SX0, SX0 + 0.1, SZ0, SZ1), (SX1 - 0.1, SX1, SZ0, SZ1),
                                 (SX0, SX1, SZ0, SZ0 + 0.1), (SX0, SX1, SZ1 - 0.1, SZ1)):
            box(props, x0, x1, y - 0.14, y + 0.14, z0, z1, TRIM)
    faces = (((SX0, 0, 0), (1, 0, 0), SZ0, SZ1, "z"), ((SX1, 0, 0), (-1, 0, 0), SZ0, SZ1, "z"),
             ((0, 0, SZ0), (0, 0, 1), SX0, SX1, "x"), ((0, 0, SZ1), (0, 0, -1), SX0, SX1, "x"))
    bands = [(RIB_Y[0] + 0.14, TOP - 0.5)] + [(a + 0.14, b - 0.14) for a, b in zip(RIB_Y[1:], RIB_Y)] + \
            [(BOT + 0.05, RIB_Y[-1] - 0.14)]
    for (o, n, a0, a1, along) in faces:
        k = int((a1 - a0) / 2.1) + 1
        for i in range(k):
            pa = a0 + (a1 - a0) * i / k
            pb = a0 + (a1 - a0) * (i + 1) / k
            for (yb, yt) in bands:
                m = pick(rng, WALL, MISMATCH)
                c = (o[0], (yb + yt) / 2, (pa + pb) / 2) if along == "z" else ((pa + pb) / 2, (yb + yt) / 2, o[2])
                fbox(det, c, n, pb - pa - 0.06, yt - yb - 0.06, 0.035, m)
                if rng.random() < 0.2 and yt - yb > 1.0:
                    vent_on(det, c, n, min(0.9, pb - pa - 0.5), 0.4, 4, lift=0.035)
    # Geel-zwarte band bovenaan (onder de vloer), zichtbaar als de luiken open zijn.
    for (x0, x1, z0, z1) in ((SX0, SX0 + 0.012, SZ0, SZ1), (SX1 - 0.012, SX1, SZ0, SZ1),
                             (SX0, SX1, SZ0, SZ0 + 0.012), (SX0, SX1, SZ1 - 0.012, SZ1)):
        box(det, x0, x1, TOP - 0.45, TOP - 0.05, z0, z1, "Hazard")
    # Langsbalken onder de vloerrand naast de scharnieren (achter de zwaai van de open luiken).
    for (x0, x1) in ((SX0, 2.3), (11.7, SX1)):
        box(props, x0, x1, -0.86, TOP, SZ0, SZ1, TRIM)
    # Geleiderails voor en achter (neus en staart van de Mol glijden erlangs).
    for z, s in ((SZ0, 1), (SZ1, -1)):
        for x in (5.2, 8.8):
            box(props, x - 0.12, x + 0.12, BOT + 0.2, TOP - 0.1, z, z + s * 0.06, TRIM)
            box(props, x - 0.04, x + 0.04, BOT + 0.2, TOP - 0.1, z + s * 0.06, z + s * 0.16, TRIM)
            box(det, x - 0.1, x + 0.1, BOT + 0.2, TOP - 0.1, z + s * 0.16, z + s * 0.19, "Steel")
            for y in RIB_Y:
                box(det, x - 0.16, x + 0.16, y - 0.06, y + 0.06, z, z + s * 0.2, TRIM)


def _hull(ctx, B):
    """Buitenromp onderaan en de buitenluiken (open, hangend onder het schip)."""
    shell, det = B["shell"], B["det"]
    for (x0, x1, z0, z1) in ((SX0 - T, SX0 + 0.2, SZ0 - T, SZ1 + T), (SX1 - 0.2, SX1 + T, SZ0 - T, SZ1 + T),
                             (SX0, SX1, SZ0 - T, SZ0 + 0.2), (SX0, SX1, SZ1 - 0.2, SZ1 + T)):
        box(shell, x0, x1, BOT - LIP, BOT, z0, z1, "HullGrey")
    for (x0, x1, z0, z1) in ((SX0 + 0.2, SX0 + 0.21, SZ0 + 0.2, SZ1 - 0.2), (SX1 - 0.21, SX1 - 0.2, SZ0 + 0.2, SZ1 - 0.2),
                             (SX0 + 0.2, SX1 - 0.2, SZ0 + 0.2, SZ0 + 0.21), (SX0 + 0.2, SX1 - 0.2, SZ1 - 0.21, SZ1 - 0.2)):
        box(det, x0, x1, BOT - LIP + 0.05, BOT - 0.05, z0, z1, "Hazard")
    a = math.radians(95.0)
    w = (SX1 - SX0 - 0.4) / 2
    ln = SZ1 - SZ0 - 0.6
    for (xh, s) in ((SX0 + 0.2, -1), (SX1 - 0.2, 1)):
        u = (-s * math.cos(a), -math.sin(a), 0.0)  # van het scharnier naar de punt (iets naar buiten)
        c = (xh + u[0] * w / 2, BOT - LIP + u[1] * w / 2, (SZ0 + SZ1) / 2)
        obox(shell, c, (w, ln, 0.22), u, (0, 0, 1), "HullGrey")
        # Ribben aan de binnenkant van het luik (naar de schacht toe) en een gevarenrand op de punt.
        for k in range(5):
            zz = SZ0 + 0.9 + k * (ln - 1.2) / 4
            obox(det, (c[0] - s * 0.15, c[1], zz), (w - 0.3, 0.12, 0.12), u, (0, 0, 1), TRIM)
        tip = (xh + u[0] * (w - 0.1), BOT - LIP + u[1] * (w - 0.1), (SZ0 + SZ1) / 2)
        obox(det, (tip[0] - s * 0.117, tip[1], tip[2]), (0.2, ln - 0.1, 0.012), u, (0, 0, 1), "Hazard")


def shaft(ctx, B):
    rng = random.Random(31)
    _walls(ctx, B, rng)
    _hull(ctx, B)


def shaft_lights(ctx):
    """Aparte mesh Shaft_Lights: verticale stroken in de hoeken en drie ringen (met kapjes in Props)."""
    L = Builder("Shaft_Lights")
    m = "ShaftLight"
    for (x, z, dx, dz) in ((SX0, SZ0, 1, 1), (SX1, SZ0, -1, 1), (SX0, SZ1, 1, -1), (SX1, SZ1, -1, -1)):
        box(L, x + dx * 0.25, x + dx * 0.31, BOT + 0.4, TOP - 0.6, z, z + dz * 0.012, m)
        box(L, x, x + dx * 0.012, BOT + 0.4, TOP - 0.6, z + dz * 0.25, z + dz * 0.31, m)
    for y in (-1.25, -4.3, -7.45):
        for (x0, x1, z0, z1) in ((SX0, SX0 + 0.04, SZ0, SZ1), (SX1 - 0.04, SX1, SZ0, SZ1),
                                 (SX0, SX1, SZ0, SZ0 + 0.04), (SX0, SX1, SZ1 - 0.04, SZ1)):
            box(L, x0, x1, y - 0.03, y + 0.03, z0, z1, m)
    ctx.shared["parts"].append(("Shaft_Lights", L, None))


def clamps(ctx, B, dock_z):
    """Vier klemmen: een gele paal op de baairand met bovenaan het scharnier, een gevorkte arm die
    schuin naar beneden onder de romp reikt, en een haak met een rubberen kussen tegen de schuine
    onderkant van de romp. Het vaste deel zit in Props (met botsvorm), de arm is Clamp_i."""
    props, det = B["props"], B["det"]
    i = 0
    for side in (-1, 1):  # bakboord, stuurboord
        for zc in (dock_z - 3.0, dock_z + 3.0):
            name = f"Clamp_{i}"
            i += 1

            def X(x):  # bakboord in plan-x; stuurboord gespiegeld rond x = 7
                return x if side < 0 else 14.0 - x

            def bx(b, x0, x1, y0, y1, z0, z1, m):
                box(b, min(X(x0), X(x1)), max(X(x0), X(x1)), y0, y1, z0, z1, m)

            # --- Vast: sokkel, paal, kop met het scharnier --------------------------------------
            bx(props, 1.95, 2.6, 0.0, 0.3, zc - 0.45, zc + 0.45, TRIM)
            bx(props, 2.28, 2.6, 0.3, 2.45, zc - 0.11, zc + 0.11, "Yellow")
            bx(det, 2.27, 2.282, 0.4, 1.6, zc - 0.1, zc + 0.1, "Hazard")
            bx(props, 2.25, 2.62, 2.45, 2.75, zc - 0.14, zc + 0.14, TRIM)
            for dz in (-0.33, 0.33):  # bouten op de sokkel
                cyl(det, (X(2.1), 0.3, zc + dz), (0, 1, 0), 0.03, 0.035, "Steel", segs=6)
            # Leiding van de vloer naar de kop (hydrauliek), aan de buitenkant van de paal.
            box(det, min(X(2.2), X(2.25)), max(X(2.2), X(2.25)), 0.3, 2.6, zc + 0.04, zc + 0.08, "Rubber")
            ctx.col_box(min(X(1.95), X(2.6)), max(X(1.95), X(2.6)), 0.0, 0.3, zc - 0.45, zc + 0.45)
            ctx.col_box(min(X(2.25), X(2.62)), max(X(2.25), X(2.62)), 0.3, 2.75, zc - 0.14, zc + 0.14)
            # --- Beweegt: Clamp_i ----------------------------------------------------------------
            A = Builder(name)
            px, py = X(2.45), 2.6
            kx, ky = X(4.3), 1.2  # knie, onder de onderrand van de romp
            cyl(A, (px, py, zc - 0.26), (0, 0, 1), 0.52, 0.13, TRIM, segs=12)  # as
            for dz in (-0.2, 0.2):  # gevorkte arm (de paal past ertussen bij het openen)
                beam(A, (px, py, zc + dz), (kx, ky, zc + dz), 0.28, 0.08, "Yellow", up=(0, 0, 1), ch=0.03)
            box(A, min(kx, X(4.05)), max(kx, X(4.05)), ky - 0.12, ky + 0.12, zc - 0.24, zc + 0.24, "Yellow")
            # Haakkop: een blok onder de onderrand, met een schuin rubberen kussen tegen de schuine
            # onderkant van de romp (de Mol rust erop).
            box(A, min(X(4.15), X(4.52)), max(X(4.15), X(4.52)), 1.08, 1.42, zc - 0.3, zc + 0.3, "Yellow")
            box(A, min(X(4.13), X(4.15)), max(X(4.13), X(4.15)), 1.12, 1.38, zc - 0.28, zc + 0.28, "Hazard")
            ex = 7.0 - HULL_EDGE[0]  # onderrand (bakboord), 2,73 + HULL_EDGE[1] hoog
            contact = (ex + 0.05, 2.73 + HULL_EDGE[1] - 0.062)  # 8 cm langs de schuine kant
            n = (CHAMFER_N[0], CHAMFER_N[1])  # naar de romp (schuin omhoog, naar binnen)
            pc = (contact[0] - n[0] * 0.04, contact[1] - n[1] * 0.04)
            bc = (pc[0] - n[0] * 0.07, pc[1] - n[1] * 0.07)
            nn = (-side * n[0], n[1], 0.0)
            tt = (side * n[1], n[0], 0.0)
            obox(A, (X(pc[0]), pc[1], zc), (0.08, 0.28, 0.6), nn, tt, "Rubber")
            obox(A, (X(bc[0]), bc[1], zc), (0.08, 0.32, 0.62), nn, tt, TRIM)
            ctx.shared["parts"].append((name, A, (px, py, zc)))
