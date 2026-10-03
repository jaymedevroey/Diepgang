"""De Ekster: moederschip van DIG (GDD v3 §1, §3, §8). Basis tussen diensten.

Gebruik:
    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup \
        --python tools/blender/ekster.py -- game/assets/models/ekster.glb

Maten in Godot-coördinaten (zie kit.py). Oorsprong = midden van de dropbaai op vloerhoogte.
-z = boeg (voor), +z = achtersteven. Indeling:
  hangar     x -11..11, y 0..9, z -22..16, met de dropbaai in de vloer (x -3.8..3.8, z -10.5..6)
  boeg       opdrachtterminal met groot scherm, venster op de ruimte
  achter     taxatiepoort met lopende band en verkoopluik in de linkerwand
  rechts     museumzaal (x 11..25, z 0..16): drie skeletsokkels en vier zuilen
  links      werkbank
Objecten (namen gebruikt door de game):
  Interior        alles binnen waar je tegen loopt (collision in Godot)
  Hull            buitenkant (gezien vanaf de planeet), geen collision
  Glass           ramen
  BayDoor_L/R     luiken van de dropbaai (oorsprong op het scharnier aan de buitenkant; klappen omlaag)
  Grapple         grijper boven de baai (zakt bij het ophalen); GrappleCable = kabel (wordt geschaald)
  TerminalScreen, AppraisalScreen   schermen met UV 0..1
  Lege punten: Lamp_n, Spawn_n, Terminal_Use, Workbench, Appraise_In, Appraise_Scan, Sell_Chute,
               Mount_n (skeletsokkels), Pedestal_n, Mol_Dock, Grapple_Top
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.append(str(Path(__file__).resolve().parent))
from kit import (G, PARTS, bake_wear, box, cyl, empty, export_glb, join_group, mat, octagon, parent_to,  # noqa: E402
                 prism, sphere, sweep, text, torus, tube, tri_count, boolean, unregister, loft)

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = Path(ARGS[0]) if ARGS else Path("ekster.glb")

HX = 11.0  # halve breedte hangar
Y1 = 9.0  # plafond
Z0, Z1 = -22.0, 16.0
BAY = (-3.8, 3.8, -10.5, 6.0)  # x0, x1, z0, z1
WALL = 0.3
MUS = (11.0, 25.0, 0.0, 16.0, 7.0)  # x0, x1, z0, z1, hoogte
DOOR_Z = (6.0, 11.0)  # museumdeur in de rechterwand
CHUTE_Z = 12.5  # verkoopluik in de linkerwand

EMPTIES = {}


def mark(name, pos, rot=(0, 0, 0)):
    EMPTIES[name] = (pos, rot)


# ======================================================================================
# Binnen
# ======================================================================================

def build_floor(g):
    x0, x1, z0, z1 = BAY
    # Vloer rond de baai.
    for (a, b, c, d) in ((-HX, x0, Z0, Z1), (x1, HX, Z0, Z1), (x0, x1, Z0, z0), (x0, x1, z1, Z1)):
        box((b - a, 0.2, d - c), ((a + b) / 2, -0.1, (c + d) / 2), "Floor", g, bevel=0.0)
    # Hazardrand rond de baai.
    for (sx, sz, px, pz) in (((x1 - x0) + 0.6, 0.3, 0, z0 - 0.15), ((x1 - x0) + 0.6, 0.3, 0, z1 + 0.15),
                             (0.3, z1 - z0, x0 - 0.15, (z0 + z1) / 2), (0.3, z1 - z0, x1 + 0.15, (z0 + z1) / 2)):
        box((sx, 0.03, sz), (px, 0.015, pz), "Hazard", g, bevel=0.0)
    # Schacht onder de baai tot de romp.
    for (sx, sz, px, pz) in ((x1 - x0, 0.2, 0, z0 - 0.1), ((x1 - x0), 0.2, 0, z1 + 0.1),
                             (0.2, z1 - z0, x0 - 0.1, (z0 + z1) / 2), (0.2, z1 - z0, x1 + 0.1, (z0 + z1) / 2)):
        box((sx, 3.3, sz), (px, -1.85, pz), "DarkSteel", g, bevel=0.0)
    # Looppaden in vloerplaten (decor): ribbels.
    for z in range(int(Z0) + 2, int(Z1) - 1, 2):
        for xs in (-1, 1):
            box((HX - 4.4, 0.02, 0.06), (xs * (HX + 4.2) / 2, 0.01, z), "DarkSteel", g, bevel=0.0)


def build_bay_doors():
    x0, x1, z0, z1 = BAY
    for side, (a, b) in (("L", (x0, 0.0)), ("R", (0.0, x1))):
        g = f"BayDoor_{side}"
        box((b - a - 0.02, 0.24, z1 - z0 - 0.04), ((a + b) / 2, -0.13, (z0 + z1) / 2), "Anthracite", g, bevel=0.04)
        # Hazardstrook langs de naad, ribben onderaan, scharnierbussen aan de buitenrand.
        seam = b - 0.26 if side == "L" else a + 0.26
        box((0.5, 0.02, z1 - z0 - 0.2), (seam, 0.0, (z0 + z1) / 2), "Hazard", g, bevel=0.0)
        for z in (z0 + 2, (z0 + z1) / 2, z1 - 2):
            box((b - a - 0.4, 0.12, 0.25), ((a + b) / 2, -0.3, z), "DarkSteel", g, bevel=0.02)
        hinge = a if side == "L" else b
        for z in (z0 + 1.0, (z0 + z1) / 2, z1 - 1.0):
            cyl(0.12, 0.8, (hinge, -0.13, z), "Steel", g, axis="z", verts=12, bevel=0.01)


def build_walls(g):
    # Linker- en rechterwand, met de museumdeur rechts en het verkoopluik links.
    for s in (-1, 1):
        x = s * (HX + WALL / 2)
        if s > 0:
            segs = ((Z0, DOOR_Z[0]), (DOOR_Z[1], Z1))
            box((WALL, Y1 - 5.0, DOOR_Z[1] - DOOR_Z[0]), (x, 5.0 + (Y1 - 5.0) / 2, sum(DOOR_Z) / 2), "Panel", g, bevel=0.0)
        else:
            segs = ((Z0, CHUTE_Z - 0.8), (CHUTE_Z + 0.8, Z1))
            box((WALL, 0.7, 1.6), (x, 0.35, CHUTE_Z), "Panel", g, bevel=0.0)
            box((WALL, Y1 - 1.9, 1.6), (x, 1.9 + (Y1 - 1.9) / 2, CHUTE_Z), "Panel", g, bevel=0.0)
        for (a, b) in segs:
            box((WALL, Y1, b - a), (x, Y1 / 2, (a + b) / 2), "Panel", g, bevel=0.0)
        # Lambrisering en ribben.
        box((0.12, 1.2, Z1 - Z0), (x - s * 0.2, 0.6, (Z0 + Z1) / 2), "DarkSteel", g, bevel=0.0)
        for z in range(int(Z0) + 2, int(Z1), 4):
            if s > 0 and DOOR_Z[0] - 0.3 < z < DOOR_Z[1] + 0.3:
                continue
            box((0.35, Y1, 0.4), (x - s * 0.28, Y1 / 2, z), "Anthracite", g, bevel=0.04)
    # Achterwand.
    box((2 * HX + 2 * WALL, Y1, WALL), (0, Y1 / 2, Z1 + WALL / 2), "Panel", g, bevel=0.0)
    # Boeg: wand met een breed venster (y 2.6..7, x -8..8).
    zb = Z0 - WALL / 2
    box((2 * HX + 2 * WALL, 2.6, WALL), (0, 1.3, zb), "Panel", g, bevel=0.0)
    box((2 * HX + 2 * WALL, Y1 - 7.0, WALL), (0, 7.0 + (Y1 - 7.0) / 2, zb), "Panel", g, bevel=0.0)
    for s in (-1, 1):
        box((HX - 8.0 + WALL, 4.4, WALL), (s * (8.0 + (HX - 8.0 + WALL) / 2), 4.8, zb), "Panel", g, bevel=0.0)
    for x in (-4.0, 0.0, 4.0):  # stijlen in het venster
        box((0.3, 4.4, 0.4), (x, 4.8, zb + 0.05), "Anthracite", g, bevel=0.04)
    box((16.4, 0.3, 0.6), (0, 2.5, zb + 0.15), "Anthracite", g, bevel=0.04)
    box((16.4, 0.3, 0.6), (0, 7.1, zb + 0.15), "Anthracite", g, bevel=0.04)
    # Plafond met spanten.
    box((2 * HX + 2 * WALL, 0.3, Z1 - Z0 + 2 * WALL), (0, Y1 + 0.15, (Z0 + Z1) / 2), "Panel", g, bevel=0.0)
    for z in range(int(Z0) + 2, int(Z1), 4):
        box((2 * HX, 0.5, 0.4), (0, Y1 - 0.25, z), "Anthracite", g, bevel=0.04)
    # Rail voor de grijper boven de baai.
    for x in (-1.6, 1.6):
        box((0.35, 0.45, Z1 - Z0 - 4), (x, Y1 - 0.6, (Z0 + Z1) / 2), "Yellow", g, bevel=0.04)
    # Leidingen langs het plafond.
    for x, r, m in ((-9.5, 0.12, "Copper"), (-9.0, 0.08, "Red"), (9.4, 0.12, "Blue"), (8.9, 0.07, "Steel")):
        tube([(x, Y1 - 0.6, Z0 + 0.5), (x, Y1 - 0.6, Z1 - 0.5)], r, m, g, verts=10)


def build_terminal(g):
    # Lessenaar die naar de bemanning kantelt, groot scherm erboven, aan de boeg.
    zc = -17.6
    box((6.4, 1.0, 1.2), (0, 0.5, zc), "Anthracite", g, bevel=0.06)
    box((6.2, 0.1, 1.1), (0, 1.08, zc + 0.05), "DarkSteel", g, bevel=0.03, rot=(18, 0, 0))
    for i, x in enumerate((-2.4, -1.6, -0.8, 0.8, 1.6, 2.4)):
        cyl(0.07, 0.05, (x, 1.18, zc + 0.15), "Yellow" if i % 2 else "Red", g, verts=12, bevel=0.01, rot=(18, 0, 0))
    box((5.6, 3.3, 0.3), (0, 3.6, -19.6), "Anthracite", g, bevel=0.08)
    for x in (-2.9, 2.9):
        box((0.25, 2.2, 0.25), (x, 1.1, -19.5), "DarkSteel", g, bevel=0.03)
    text("OPDRACHTEN", 0.3, (0, 5.5, -19.4), (0, 0, 0), "DecalLight", g, extrude=0.02)
    mark("Terminal_Use", (0, 1.1, zc + 0.8))


def build_terminal_screen():
    quad("TerminalScreen", (0, 3.6, -19.43), 5.0, 2.8)


def quad(name, center, w, h, normal=(0, 0, 1), rot_y=0.0):
    """Scherm met UV 0..1 (zoals het camerascherm van de Mol)."""
    cx, cy, cz = center
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    c, s = math.cos(math.radians(rot_y)), math.sin(math.radians(rot_y))
    pts = []
    for (dx, dy, t) in ((-w / 2, -h / 2, (0, 1)), (w / 2, -h / 2, (1, 1)), (w / 2, h / 2, (1, 0)), (-w / 2, h / 2, (0, 0))):
        x = cx + dx * c
        z = cz - dx * s
        pts.append((bm.verts.new(G(x, cy + dy, z)), t))
    f = bm.faces.new([p[0] for p in pts])
    for loop, (_, t) in zip(f.loops, pts):
        loop[uv].uv = t
    f.normal_update()
    nx, nz = math.sin(math.radians(rot_y)), math.cos(math.radians(rot_y))
    if f.normal.dot(G(nx, 0, nz)) < 0:
        f.normal_flip()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat("Screen"))
    PARTS[name] = [o]


def build_appraisal(g):
    # Lopende band van het midden naar het verkoopluik, met een poort (scanner) erover.
    x_in, x_out, z = -4.5, -HX - 0.1, CHUTE_Z
    box((x_in - x_out, 0.7, 1.3), ((x_in + x_out) / 2, 0.35, z), "Anthracite", g, bevel=0.04)
    box((x_in - x_out - 0.2, 0.06, 1.0), ((x_in + x_out) / 2, 0.73, z), "Rubber", g, bevel=0.0)
    for x in range(int(x_out) + 1, int(x_in)):
        cyl(0.07, 1.05, (x + 0.5, 0.7, z), "Steel", g, axis="x" if False else "z", verts=10, bevel=0.0)
    # Poort.
    xs = -7.5
    for dz in (-0.85, 0.85):
        box((0.35, 2.6, 0.35), (xs, 1.3, z + dz), "Yellow", g, bevel=0.05)
    box((0.5, 0.45, 2.1), (xs, 2.75, z), "Yellow", g, bevel=0.06)
    box((0.06, 0.2, 1.4), (xs + 0.2, 2.5, z), "Lens", g, bevel=0.0)  # scanlicht
    box((0.4, 1.3, 2.2), (xs, 3.9, z), "Anthracite", g, bevel=0.05)
    text("TAXATIE", 0.26, (xs + 0.22, 4.8, z), (0, 90, 0), "DecalDark", g, extrude=0.02)
    # Verkoopluik: klep in de wand met "VERKOOP".
    box((0.2, 1.3, 1.7), (-HX + 0.05, 1.25, z), "DarkSteel", g, bevel=0.03)
    text("VERKOOP", 0.22, (-HX + 0.2, 2.3, z), (0, 90, 0), "DecalLight", g, extrude=0.02)
    # Tafel waar je vondsten op de band zet.
    box((1.4, 0.8, 1.6), (x_in + 0.7, 0.4, z), "Steel", g, bevel=0.04)
    mark("Appraise_In", (x_in + 0.6, 0.95, z))
    mark("Appraise_Scan", (xs, 0.9, z))
    mark("Sell_Chute", (-HX + 0.4, 0.9, z))


def build_appraisal_screen():
    quad("AppraisalScreen", (-7.27, 3.9, CHUTE_Z), 1.9, 1.05, rot_y=90.0)


def build_museum(g):
    x0, x1, z0, z1, h = MUS
    # Vloer, wanden, plafond.
    box((x1 - x0, 0.2, z1 - z0), ((x0 + x1) / 2, -0.1, (z0 + z1) / 2), "Wood", g, bevel=0.0)
    box((x1 - x0, 0.3, z1 - z0), ((x0 + x1) / 2, h + 0.15, (z0 + z1) / 2), "Panel", g, bevel=0.0)
    box((WALL, h, z1 - z0), (x1 + WALL / 2, h / 2, (z0 + z1) / 2), "Cream", g, bevel=0.0)
    for zz in (z0 - WALL / 2, z1 + WALL / 2):
        box((x1 - x0 + WALL, h, WALL), ((x0 + x1) / 2, h / 2, zz), "Cream", g, bevel=0.0)
    # Rechterwand van de hangar loopt hier door, met de deur: lijst rond de deur.
    for zz in DOOR_Z:
        box((0.6, 5.0, 0.3), (HX + 0.15, 2.5, zz), "Yellow", g, bevel=0.04)
    box((0.6, 0.4, DOOR_Z[1] - DOOR_Z[0] + 0.3), (HX + 0.15, 5.0, sum(DOOR_Z) / 2), "Yellow", g, bevel=0.04)
    text("MUSEUM", 0.34, (HX - 0.17, 5.0, sum(DOOR_Z) / 2), (0, -90, 0), "DecalDark", g, extrude=0.02)
    # Drie skeletsokkels tegen de achterwand, elk met een lijst en een bordje.
    for i, z in enumerate((3.2, 8.0, 12.8)):
        box((2.6, 0.5, 3.8), (x1 - 2.0, 0.25, z), "Anthracite", g, bevel=0.05)
        box((2.4, 0.06, 3.6), (x1 - 2.0, 0.52, z), "Cream", g, bevel=0.0)
        box((0.1, 3.6, 0.1), (x1 - 0.9, 2.3, z - 1.6), "Steel", g, bevel=0.0)
        box((0.1, 3.6, 0.1), (x1 - 0.9, 2.3, z + 1.6), "Steel", g, bevel=0.0)
        box((0.1, 0.1, 3.3), (x1 - 0.9, 4.1, z), "Steel", g, bevel=0.0)
        box((0.6, 0.4, 0.06), (x1 - 3.4, 0.6, z), "DarkSteel", g, bevel=0.01, rot=(0, 90, 0))
        mark(f"Mount_{i}", (x1 - 2.0, 0.55, z), (0, -90, 0))
    # Vier zuilen in het midden voor relieken, geodes, goud.
    for i, (x, z) in enumerate(((x0 + 4.0, 4.5), (x0 + 4.0, 11.5), (x0 + 8.0, 4.5), (x0 + 8.0, 11.5))):
        cyl(0.45, 1.0, (x, 0.5, z), "Cream", g, verts=16, bevel=0.03)
        cyl(0.55, 0.1, (x, 1.05, z), "Anthracite", g, verts=16, bevel=0.02)
        mark(f"Pedestal_{i}", (x, 1.1, z))
    text("COLLECTIE VAN DE RAAD VAN BESTUUR", 0.28, (x1 - 0.02, 5.6, (z0 + z1) / 2), (0, -90, 0), "DecalDark", g, extrude=0.02)
    for i, z in enumerate((4.0, 12.0)):
        mark(f"Lamp_m{i}", ((x0 + x1) / 2, h - 0.6, z))


def build_workbench(g):
    x, z = -HX + 0.7, -6.0
    box((1.2, 0.9, 3.0), (x, 0.45, z), "Wood", g, bevel=0.03)
    box((1.3, 0.08, 3.1), (x, 0.92, z), "Steel", g, bevel=0.02)
    box((0.1, 1.6, 3.0), (-HX + 0.08, 1.9, z), "DarkSteel", g, bevel=0.02)  # gereedschapsbord
    for dz in (-1.0, -0.4, 0.3, 1.0):
        box((0.06, 0.5, 0.08), (-HX + 0.16, 2.0, z + dz), "Yellow", g, bevel=0.01)
    text("WERKBANK", 0.2, (-HX + 0.15, 2.9, z), (0, 90, 0), "DecalLight", g, extrude=0.02)
    mark("Workbench", (x + 0.6, 1.0, z))


def build_decor(g):
    # Kratten en vaten bij de achterwand rechts.
    for (x, y, z, s) in ((8.5, 0.6, 13.6, 1.2), (9.6, 0.6, 12.2, 1.2), (8.6, 1.75, 13.5, 1.0), (6.9, 0.45, 14.4, 0.9)):
        box((s, s, s), (x, y, z), "Wood", g, bevel=0.04)
    for (x, z) in ((5.6, 14.8), (5.0, 14.0)):
        cyl(0.35, 1.0, (x, 0.5, z), "Red", g, verts=16, bevel=0.03)
    # Koffieautomaat aan de boeg links.
    box((0.8, 1.9, 0.6), (-9.6, 0.95, -20.6), "Red", g, bevel=0.05)
    box((0.6, 0.5, 0.05), (-9.6, 1.3, -20.28), "DecalDark", g, bevel=0.0)
    # Opschriften.
    text("DIG", 1.4, (HX - 0.02, 6.2, -10.0), (0, -90, 0), "Yellow", g, extrude=0.06)
    text("DIEPGANG INTERPLANETAIRE GRONDWERKEN", 0.26, (HX - 0.02, 5.1, -10.0), (0, -90, 0), "DecalLight", g, extrude=0.02)
    text("DE EKSTER", 0.8, (-HX + 0.02, 6.4, 0.0), (0, 90, 0), "DecalDark", g, extrude=0.04)
    # Op de vloer voor en achter de baai, leesbaar voor wie eraan komt.
    text("HOU AFSTAND · DROPBAAI", 0.3, (0, 0.02, BAY[2] - 0.8), (-90, 180, 0), "DecalDark", g, extrude=0.005)
    text("HOU AFSTAND · DROPBAAI", 0.3, (0, 0.02, BAY[3] + 1.6), (-90, 0, 0), "DecalDark", g, extrude=0.005)
    # Loopbrug langs de rechterwand (decor, hoog).
    box((1.4, 0.12, Z1 - Z0 - 6), (HX - 0.9, 4.6, (Z0 + Z1) / 2 - 2), "DarkSteel", g, bevel=0.02)
    tube([(HX - 1.6, 5.6, Z0 + 1), (HX - 1.6, 5.6, Z1 - 7)], 0.04, "Yellow", g, verts=8)
    # Lampen aan het plafond.
    n = 0
    for z in (-18.0, -11.0, -4.0, 3.0, 10.0):
        for x in (-6.5, 6.5):
            cyl(0.35, 0.18, (x, Y1 - 0.35, z), "Anthracite", g, verts=14, bevel=0.02)
            cyl(0.28, 0.06, (x, Y1 - 0.47, z), "Bulb", g, verts=14, bevel=0.0)
            mark(f"Lamp_{n}", (x, Y1 - 0.9, z))
            n += 1


def build_grapple():
    g = "Grapple"
    # Naaf met vier klauwen; oorsprong = bovenkant (aan de kabel).
    cyl(1.3, 0.8, (0, -0.4, 0), "Yellow", g, verts=20, bevel=0.06)
    cyl(0.6, 0.6, (0, 0.2, 0), "DarkSteel", g, verts=16, bevel=0.04)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        dx, dz = math.cos(a), math.sin(a)
        p0 = (dx * 1.0, -0.6, dz * 1.0)
        p1 = (dx * 2.0, -1.5, dz * 2.0)
        p2 = (dx * 1.9, -2.6, dz * 1.9)
        p3 = (dx * 1.4, -3.0, dz * 1.4)
        loft([p0, p1, p2, p3], [0.22, 0.2, 0.17, 0.08], "Anthracite", g, verts=8)
        sphere(0.2, p1, "Steel", g, segments=10, rings=5)
    box((0.6, 0.15, 0.6), (0, -0.85, 0), "Lens", g, bevel=0.0)
    g2 = "GrappleCable"
    cyl(0.09, 1.0, (0, -0.5, 0), "Steel", g2, verts=10, bevel=0.0)


HULL_X = (-13.0, 27.0)  # romp rond hangar én museum
HULL_Y = (-3.5, 12.5)
HULL_Z = (-27.0, 20.0)


def _drop_bottom(obj):
    """Bodemvlak van de romp weg: er komt een bodemplaat met een gat voor de baai in de plaats.
    (Een boolean door een gesloten romp gaf vlakken dwars door de hangar.)"""
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bottom = [f for f in bm.faces if f.normal.z < -0.9]  # Blender z = Godot y
    bmesh.ops.delete(bm, geom=bottom, context="FACES")
    bm.to_mesh(me)
    bm.free()


def build_hull():
    g = "Hull"
    x0, x1 = HULL_X
    y0, y1 = HULL_Y
    z0, z1 = HULL_Z
    cx, w = (x0 + x1) / 2, x1 - x0
    hull = prism([(x + cx, y) for (x, y) in octagon(w, 0, 3.4, y0, y1)], z0, z1, "Anthracite", g, bevel=0.0)
    _drop_bottom(hull)
    # Bodemplaat (wit, de buik van een ekster) rond de baai.
    bx0, bx1, bz0, bz1 = BAY
    fx0, fx1 = x0 + 3.4, x1 - 3.4
    for (a, b, c, d) in ((fx0, bx0, z0, z1), (bx1, fx1, z0, z1), (bx0, bx1, z0, bz0), (bx0, bx1, bz1, z1)):
        box((b - a, 0.3, d - c), ((a + b) / 2, y0 + 0.15, (c + d) / 2), "Cream", g, bevel=0.0)
    # Witte flankpanelen (ekster) en gele DIG-banden.
    for s, x in ((-1, x0 - 0.06), (1, x1 + 0.06)):
        box((0.12, 5.0, z1 - z0 - 6.0), (x, 3.2, (z0 + z1) / 2 + 1.0), "Cream", g, bevel=0.05)
        for z in (-21.0, -7.0, 7.0):
            box((0.16, 9.0, 1.4), (x + s * 0.03, 4.0, z), "Yellow", g, bevel=0.05)
    text("DIG", 3.2, (x0 - 0.14, 3.4, -14.0), (0, -90, 0), "Anthracite", g, extrude=0.1)
    text("DE EKSTER", 1.6, (x1 + 0.14, 3.4, -14.0), (0, 90, 0), "Anthracite", g, extrude=0.08)
    text("DIG", 3.2, (x1 + 0.14, 3.4, 12.0), (0, 90, 0), "Anthracite", g, extrude=0.1)
    # Boegvenster van buiten: donker glas met een gele lijst.
    box((16.6, 4.8, 0.2), (0, 4.8, z0 - 0.08), "Glass", "Glass", bevel=0.0)
    box((17.4, 0.4, 0.3), (0, 2.3, z0 - 0.1), "Yellow", g, bevel=0.05)
    box((17.4, 0.4, 0.3), (0, 7.3, z0 - 0.1), "Yellow", g, bevel=0.05)
    # Motoren achteraan, met gloeiende uitlaten.
    for x in (-6.0, 7.0, 20.0):
        cyl(3.0, 7.0, (x, 4.0, z1 + 3.0), "DarkSteel", g, axis="z", verts=24, bevel=0.12)
        cyl(2.4, 0.5, (x, 4.0, z1 + 6.6), "LensOrange", g, axis="z", verts=24, bevel=0.0)
        torus(3.0, 0.25, (x, 4.0, z1 + 6.4), "Steel", g, axis="z", major_seg=28, minor_seg=6)
        box((0.6, 1.2, 6.0), (x, 7.2, z1 + 2.6), "Yellow", g, bevel=0.05)
    # Stuurvinnen onderaan en een staart (ekster).
    for x in (-10.0, 24.0):
        box((0.5, 4.0, 7.0), (x, y0 - 1.6, 12.0), "Anthracite", g, bevel=0.1, rot=(0, 0, 0))
    box((1.0, 6.0, 9.0), (cx, y1 + 2.4, 15.0), "Anthracite", g, bevel=0.15)
    box((1.04, 2.0, 7.0), (cx, y1 + 4.4, 15.6), "Cream", g, bevel=0.1)
    # Brug en antenne bovenop.
    box((9.0, 3.2, 11.0), (0, y1 + 1.5, -15.0), "Anthracite", g, bevel=0.3)
    box((8.0, 0.9, 0.3), (0, y1 + 2.2, -20.55), "Glass", "Glass", bevel=0.0)
    tube([(0, y1 + 3.1, -12.0), (0, y1 + 9.0, -12.0)], 0.14, "Steel", g, verts=8)
    sphere(0.45, (0, y1 + 9.3, -12.0), "LensRed", g, segments=10, rings=5)
    # Navigatielichten en schijnwerpers rond de baai (onderkant).
    for (x, m) in ((x0 - 0.2, "LensRed"), (x1 + 0.2, "Lens")):
        sphere(0.45, (x, 1.0, -22.0), m, g, segments=10, rings=5)
    for i, (x, z) in enumerate(((bx0 - 1.0, bz0 - 1.0), (bx1 + 1.0, bz0 - 1.0), (bx0 - 1.0, bz1 + 1.0), (bx1 + 1.0, bz1 + 1.0))):
        cyl(0.45, 0.4, (x, y0 - 0.15, z), "DarkSteel", g, verts=14, bevel=0.03)
        cyl(0.35, 0.06, (x, y0 - 0.37, z), "Lens", g, verts=14, bevel=0.0)
        mark(f"BayLight_{i}", (x, y0 - 0.5, z), (-90, 0, 0))


def build_glass():
    g = "Glass"
    box((16.0, 4.4, 0.06), (0, 4.8, Z0 - WALL - 0.05), "Glass", g, bevel=0.0)
    mark("Window_Glass", (0, 4.8, Z0 - WALL - 0.05))


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    g = "Interior"
    build_floor(g)
    build_walls(g)
    build_terminal(g)
    build_appraisal(g)
    build_museum(g)
    build_workbench(g)
    build_decor(g)
    build_bay_doors()
    build_grapple()
    build_terminal_screen()
    build_appraisal_screen()
    build_glass()
    build_hull()
    mark("Mol_Dock", (0, 2.73, -1.5))
    mark("Grapple_Top", (0, Y1 - 0.4, -1.0))
    # Achter de Mol, met zicht op de open laadklep en verderop het boegvenster.
    for i in range(4):
        mark(f"Spawn_{i}", (-2.4 + i * 1.6, 0.1, 10.5))

    root = bpy.data.objects.new("Ekster", None)
    bpy.context.collection.objects.link(root)
    objects = {}
    for name in ("Interior", "Hull", "Glass", "GrappleCable", "TerminalScreen", "AppraisalScreen"):
        objects[name] = join_group(name, name)
    objects["BayDoor_L"] = join_group("BayDoor_L", "BayDoor_L", origin=(BAY[0], -0.13, (BAY[2] + BAY[3]) / 2))
    objects["BayDoor_R"] = join_group("BayDoor_R", "BayDoor_R", origin=(BAY[1], -0.13, (BAY[2] + BAY[3]) / 2))
    objects["Grapple"] = join_group("Grapple", "Grapple")
    for name, o in objects.items():
        if o is None:
            continue
        if name not in ("Glass", "TerminalScreen", "AppraisalScreen"):
            bake_wear(o, strength=4.0, seed=hash(name) % 1000)
        parent_to(o, root)
    for name, (pos, rot) in EMPTIES.items():
        empty(name, pos, rot, parent=root)

    total = 0
    for name, o in objects.items():
        if o:
            n = tri_count(o)
            total += n
            print(f"[ekster] {name:16s} {n:7d} driehoeken")
    print(f"[ekster] totaal {total} driehoeken")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    export_glb(OUT)
    print(f"[ekster] geschreven: {OUT}")


main()
