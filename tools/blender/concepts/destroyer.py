"""De Ekster in Helldivers-stijl: enkel de vorm (klei), om samen met Jayme aan te schaven.

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup \
        --python tools/blender/concepts/destroyer.py -- [variant]

Vormtaal (Super Destroyer, Helldivers 2): lang en laag (±5:1); een zware hoekige boeg die naar
onder uitsteekt als een kaak; een lange ruggengraat; achteraan twee losse armen met motoren en
open ruimte tussen arm en romp; schuine vlakken in plaats van dozen; lange horizontale lijnen;
een brugtoren uit het midden; achteraan een muur van ronde motoren.
Eigen draai: de boeg als de snavel van een ekster, de armen als zijn lange staartveren.

Godot-assen (x rechts, y omhoog, −z = boeg). Oorsprong = waar de Mol hangt (Mol_Dock).
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.append(str(Path(__file__).resolve().parent.parent))
import kit  # noqa: E402
from kit import G, PARTS, empty, export_glb, mat  # noqa: E402

REPO = Path(__file__).resolve().parents[3]
OUT = REPO / "game/assets/models/concepts"
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
VARIANT = ARGS[0] if ARGS else "a"


def section(W, T, B, s, c, k):
    """Doorsnede (x, y), tegen de klok in vanaf onderaan links:
    W halve breedte, T boven, B onder (kiel), s afschuining van de schouder, c hoogte waar de kin
    begint (schuin naar de kiel), k halve breedte van de kiel."""
    return [(-k, B), (k, B), (W, c), (W, T - s), (W - s, T), (-W + s, T), (-W, T - s), (-W, c)]


def loft(name, stations, material="HullGrey", group="Hull", x=0.0, y=0.0, roll_deg=0.0, cap=True):
    """Hoekige romp door doorsneden [(z, W, T, B, s, c, k), ...], rechte stukken ertussen (geen
    afronding: vlakke platen, scherpe overgangen). Optioneel verschoven en gekanteld rond z."""
    bm = bmesh.new()
    rings = []
    r = math.radians(roll_deg)
    cr, sr = math.cos(r), math.sin(r)
    for (z, W, T, B, s, c, k) in stations:
        ring = []
        for (px, py) in section(W, T, B, s, c, k):
            rx, ry = px * cr - py * sr, px * sr + py * cr
            ring.append(bm.verts.new(G(rx + x, ry + y, z)))
        rings.append(ring)
    n = len(rings[0])
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new([a[i], a[j], b[j], b[i]])
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat(material))
    PARTS.setdefault(group, []).append(o)
    return o


def plate(name, pts, thick, material="HullGrey", group="Hull"):
    """Vlakke plaat (vin, kaak, pyloon) uit een veelhoek met dikte."""
    bm = bmesh.new()
    vs = [bm.verts.new(G(*p)) for p in pts]
    f = bm.faces.new(vs)
    f.normal_update()
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    moved = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=moved, vec=f.normal * thick)
    bmesh.ops.translate(bm, verts=bm.verts, vec=-f.normal * thick * 0.5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat(material))
    PARTS.setdefault(group, []).append(o)
    return o


def engine_ring(name, center, radius, depth=2.5, group="Hull"):
    """Ronde motor achteraan: een kraag en een gloeiende schijf, iets verzonken."""
    cx, cy, cz = center
    kit.cyl(radius * 1.12, depth, (cx, cy, cz + depth / 2), "HullDark", group, axis="z", verts=24, bevel=0.15)
    kit.cyl(radius, 0.3, (cx, cy, cz + depth + 0.05), "Lens", group, axis="z", verts=24, bevel=0.0)


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    PARTS.clear()
    kit._MATS.clear()
    g = "Hull"
    # Verhoudingen afgemeten op de Super Destroyer (zijaanzicht): boeg ±20% van de lengte en
    # ±18% hoog met de kaak, middenstuk ±24% en ±15% hoog, de rest een lange smalle rug (±8%).
    # --- Boeg: een hamerkop met een vlakke, afgeschuinde voorkant en een getrapte bovenkant.
    loft("Prow", [
        (-80, 13.0, 9.0, -5.0, 3.5, -1.0, 6.0),
        (-74, 15.5, 10.0, -6.5, 3.5, -1.5, 7.0),
        (-52, 15.5, 10.0, -7.0, 3.5, -1.5, 7.0),
        (-48, 14.0, 10.0, -7.0, 3.0, -1.5, 7.0),
    ])
    loft("Brow", [
        (-76, 9.0, 13.0, 8.0, 2.5, 9.0, 8.0),
        (-56, 10.5, 13.5, 8.0, 2.5, 9.0, 9.5),
        (-50, 10.5, 13.5, 8.0, 2.5, 9.0, 9.5),
    ])
    # De kaak: een wigvormig blad onder de boeg, het diepst achteraan (zoals bij de destroyer).
    loft("Jaw", [
        (-79, 8.0, -4.0, -7.0, 1.0, -5.0, 3.0),
        (-60, 9.0, -4.0, -17.0, 1.0, -8.0, 2.0),
        (-52, 8.0, -4.0, -18.0, 1.0, -9.0, 2.0),
        (-48, 6.0, -4.0, -9.0, 1.0, -6.0, 2.5),
    ], "HullDark")
    # --- Middenstuk: hoog, met de baai van de Mol in de buik en brede zijbaaien onderaan.
    loft("Mid", [
        (-48, 12.5, 10.5, -10.0, 3.0, -4.0, 5.0),
        (-14, 12.5, 10.5, -10.0, 3.0, -4.0, 5.0),
        (-6, 9.0, 10.0, -7.0, 2.5, -3.0, 4.0),
    ])
    loft("MidLower", [
        (-46, 14.5, 2.0, -7.5, 1.5, -4.5, 9.0),
        (-16, 14.5, 2.0, -7.5, 1.5, -4.5, 9.0),
        (-10, 11.5, 2.0, -6.5, 1.5, -4.0, 7.0),
    ], "HullDark")
    # --- Ruggengraat: lang, smal en laag; onderaan hangende laadkasten.
    loft("Spine", [
        (-8, 7.0, 9.0, -5.0, 2.0, -1.5, 3.5),
        (64, 6.5, 9.0, -5.0, 2.0, -1.5, 3.5),
    ])
    for (z, L) in ((8, 10), (22, 12), (38, 10), (52, 8)):
        loft(f"Pod{z}", [(z, 4.0, -5.0, -9.0, 1.0, -7.5, 3.0), (z + L, 4.0, -5.0, -9.0, 1.0, -7.5, 3.0)], "HullDark")
    # --- Motorblok achteraan: breder, met een muur van ronde motoren.
    loft("EngineBlock", [
        (62, 9.0, 9.0, -5.0, 2.5, -1.5, 4.0),
        (68, 12.5, 10.0, -7.0, 3.0, -2.0, 6.0),
        (82, 12.5, 10.0, -7.0, 3.0, -2.0, 6.0),
    ], "HullDark")
    for (ex, ey, r) in ((-7.0, 4.5, 3.2), (0, 5.0, 3.4), (7.0, 4.5, 3.2), (-3.8, -2.6, 2.9), (3.8, -2.6, 2.9)):
        engine_ring(f"Eng{ex}{ey}", (ex, ey, 82), r)
    # --- Twee armen (staartveren): hoge platte platen, schuin afgesneden vooraan, licht naar buiten
    # gekanteld, met grote motorkasten achteraan. Open ruimte tussen arm en romp.
    tilt = 32.0 if VARIANT == "a" else 0.0
    for s in (-1, 1):
        arm_x = s * 19
        # Brede, platte bladen, schuin naar buiten gekanteld (zoals de motorarmen van de destroyer);
        # vooraan schuin afgesneden, achteraan een zware motorkast.
        loft(f"Arm{s}", [
            (16, 3.0, 1.2, -1.2, 0.6, -0.6, 2.0),
            (26, 7.0, 1.8, -1.8, 0.8, -0.9, 6.0),
            (64, 7.5, 1.8, -1.8, 0.8, -0.9, 6.5),
            (70, 7.5, 4.0, -4.0, 1.5, -2.0, 6.0),
            (86, 7.5, 4.0, -4.0, 1.5, -2.0, 6.0),
        ], "HullGrey", x=arm_x, y=1.0, roll_deg=-s * tilt)
        c, sn = math.cos(math.radians(tilt)), math.sin(math.radians(tilt))
        for lx in (-3.6, 3.6):
            ex = arm_x + (lx * c) * 1.0
            ey = 1.0 + (-s * lx) * sn * -1.0 if False else 1.0 - s * lx * sn * -1.0
            engine_ring(f"ArmEng{s}{lx}", (arm_x + lx * c, 1.0 + lx * (-s) * (-sn), 86), 2.6)
        # Schuine pylonen die de arm aan de romp hangen (je ziet erdoor).
        for z0 in (24.0, 50.0):
            plate(f"Pylon{s}{z0}", [(s * 6.0, 5.0, z0), (s * 15.0, 2.0, z0 + 5), (s * 15.0, 2.0, z0 + 12), (s * 6.0, 5.0, z0 + 9)], 1.4)
    # --- Brugtoren uit het midden, getrapt, met een raamband.
    loft("Bridge", [
        (-28, 4.5, 16.0, 9.0, 1.5, 10.0, 3.5),
        (-10, 5.0, 16.5, 9.0, 1.5, 10.0, 4.0),
    ], "HullGrey", x=5.0)
    loft("BridgeTop", [
        (-25, 3.5, 19.5, 16.0, 1.0, 16.5, 3.0),
        (-14, 3.5, 19.5, 16.0, 1.0, 16.5, 3.0),
    ], "HullGrey", x=5.0)
    kit.box((6.8, 0.9, 0.3), (5.0, 18.2, -25.15), "Cyan", g, bevel=0.0)
    # --- Lange lijnen: een rail over de rug en langs de flanken.
    kit.box((1.2, 1.2, 70.0), (0, 9.6, 28.0), "HullDark", g, bevel=0.1)
    for s in (-1, 1):
        kit.box((0.7, 0.9, 70.0), (s * 12.7, 6.0, -28.0), "HullDark", g, bevel=0.1)
    # --- De Mol in de baai (schaal) en de opening in de buik.
    kit.box((8.0, 0.2, 16.0), (0, -10.05, -31.5), "Soot", g, bevel=0.0)
    body = Path(__file__).resolve().parent
    # Mol ter schaal: een gele pil.
    from shapes import hull as pill  # noqa: E402
    pill("Mol", [(-38.0, 1.2, -10.5, -11.5, 2, 2), (-36.5, 3.0, -8.4, -13.6, 2.4, 2.4), (-27.5, 3.2, -8.25, -13.75, 5, 5),
                 (-25.0, 3.2, -8.25, -13.75, 5, 5)], "Yellow", g, n=24, sub=2, point_ends=False)
    # Samenvoegen met een afschuining per laag.
    root = bpy.data.objects.new(f"Ekster_hd_{VARIANT}", None)
    bpy.context.collection.objects.link(root)
    for o in PARTS[g]:
        bev = o.modifiers.new("Bevel", "BEVEL")
        bev.width = 0.35 if o.name in ("Prow", "Brow", "Jaw", "Mid", "MidLower", "Spine", "EngineBlock") or o.name.startswith("Arm") else 0.12
        bev.segments = 1
        bev.limit_method = "ANGLE"
        bev.angle_limit = math.radians(25)
        for p in o.data.polygons:
            p.use_smooth = False
        o.parent = root
    empty("Mol_Dock", (0, -11.0, -31.5), parent=root)
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"helldivers_{VARIANT}.glb"
    export_glb(path)
    print(f"[destroyer] {VARIANT} -> {path}")


sys.path.append(str(Path(__file__).resolve().parent))
build()
