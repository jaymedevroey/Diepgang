"""Ontwerpschetsen voor De Ekster: vier richtingen als grove vormen, met silhouetten en metingen.
Zie docs/research/schip-ontwerp.md (§6) en schip-bouwen-in-blender.md (§5, §6).

Gebruik:
    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup \
        --python tools/blender/concepts/ekster_concepts.py -- logs/concepts
Daarna het blad samenstellen: py -3.11 tools/blender/concepts/sheet.py logs/concepts

Per richting: silhouet van opzij, van boven en van voor (zwart op wit, orthografisch), een beeld
schuin van onder (studiolicht, kleur per materiaal), en hoe je het ziet vanaf de planeet (340 m
lager, 75° beeldhoek). Ter schaal: de Mol (13 m, geel) en een speler (1,8 m).
"""

import json
import math
import os
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

sys.path.append(str(Path(__file__).resolve().parent.parent))
sys.path.append(str(Path(__file__).resolve().parent))
from kit import G, PARTS, box, cyl, mat, sphere, torus, tube  # noqa: E402
from shapes import hull, lattice_tower, plate  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
REPO = Path(__file__).resolve().parents[3]
OUT = Path(ARGS[0]) if ARGS else Path("logs/concepts")
if not OUT.is_absolute():
    OUT = REPO / OUT  # Blender start niet in de repo
OUT.mkdir(parents=True, exist_ok=True)

MOL = (6.4, 5.5, 13.0)


def mol(center, group):
    """De Mol ter schaal (grove pil, geel) met een speler ernaast."""
    cx, cy, cz = center
    hull(f"{group}_Mol", [(cz - 6.5, 1.2, cy + 0.5, cy - 0.5, 2, 2), (cz - 5.0, 3.0, cy + 2.6, cy - 2.6, 2.4, 2.4),
                          (cz + 4.0, 3.2, cy + 2.75, cy - 2.75, 5, 5), (cz + 6.5, 3.2, cy + 2.75, cy - 2.75, 5, 5)],
         "Yellow", group, n=24, sub=2, point_ends=False)
    cyl(0.35, 1.8, (cx + 4.2, cy - 1.85, cz + 2.0), "Red", group, verts=8, bevel=0.0)


# =====================================================================================
# A. Skycrane-ekster: kop, korte ronde vleugels, lange getrapte staart, de Mol onder de buik.
# =====================================================================================

def concept_a(g):
    body = [
        (-50, 1.2, 2.0, -0.5, 2.4, 2.4),
        (-44, 5.5, 5.5, -2.5, 2.6, 3.0),
        (-34, 10.5, 9.5, -5.0, 3.0, 3.6),
        (-22, 14.0, 11.5, -6.5, 3.4, 4.2),
        (-8, 13.0, 11.5, -6.0, 3.4, 4.2),
        (3, 9.0, 10.0, -3.0, 3.0, 3.2),
        (13, 4.2, 7.0, 0.5, 2.6, 2.6),
        (40, 3.0, 6.0, 1.6, 2.6, 2.6),
        (58, 2.4, 5.4, 2.4, 2.4, 2.4),
    ]
    hull("A_Body", body, "Anthracite", g, n=40, sub=4)
    # Witte buik (ekster) als schaal onder de borst.
    belly = [(z, hw * 0.9, bot + 4.0, bot - 0.3, 2.4, 3.2) for (z, hw, top, bot, et, eb) in body[1:6]]
    hull("A_Belly", belly, "Cream", g, n=40, sub=4)
    # Brug: een "oog" van glas op de kop.
    for s in (-1, 1):
        box((0.4, 1.6, 7.0), (s * 7.4, 5.2, -38.0), "Cyan", g, bevel=0.2, rot=(0, s * 14, 0))
    # Korte, ronde vleugels met witte punten, licht naar achter en omhoog.
    for s in (-1, 1):
        plate(f"A_Wing{s}", [(s * 12.5, 3.0, -27), (s * 30, 5.5, -21), (s * 38, 7.0, -15), (s * 40, 7.4, -9),
                             (s * 36, 6.6, -4), (s * 24, 4.5, -3), (s * 12.5, 2.5, -2)], 2.4, "Anthracite", g)
        plate(f"A_WingTip{s}", [(s * 30.5, 5.8, -20.5), (s * 38, 7.1, -15), (s * 40.2, 7.5, -9), (s * 36.2, 6.7, -4.2),
                                (s * 31, 5.9, -4.8)], 2.6, "Cream", g)
        # Motoren onder de vleugelwortel.
        cyl(3.2, 15.0, (s * 17.0, 0.5, -10.0), "DarkSteel", g, axis="z", verts=20, bevel=0.3)
        cyl(2.5, 0.6, (s * 17.0, 0.5, -2.3), "LensOrange", g, axis="z", verts=20, bevel=0.0)
    # Getrapte staart: middelste vin het langst, met blauwgroene punten.
    for i, (ang, length) in enumerate(((0, 34), (9, 29), (-9, 29), (18, 23), (-18, 23))):
        a = math.radians(ang)
        x0, z0 = 0.0, 52.0
        x1, z1 = x0 + math.sin(a) * length, z0 + math.cos(a) * length
        w0, w1 = 2.2, 3.4
        px, pz = math.cos(a), -math.sin(a)
        plate(f"A_Tail{i}", [(x0 - px * w0, 4.0, z0 - pz * w0), (x1 - px * w1, 4.6, z1 - pz * w1),
                             (x1 + px * w1, 4.6, z1 + pz * w1), (x0 + px * w0, 4.0, z0 + pz * w0)], 0.9, "Anthracite", g)
        plate(f"A_TailTip{i}", [(x1 - px * w1 - math.sin(a) * 6, 4.5, z1 - pz * w1 - math.cos(a) * 6), (x1 - px * w1, 4.6, z1 - pz * w1),
                                (x1 + px * w1, 4.6, z1 + pz * w1), (x1 + px * w1 - math.sin(a) * 6, 4.5, z1 + pz * w1 - math.cos(a) * 6)],
              1.0, "Blue", g)
    # De Mol onder de buik, tussen vier grijparmen.
    mol((0, -9.5, -15.0), g)
    for sx in (-1, 1):
        for sz in (-22.0, -8.0):
            tube([(sx * 5.5, -5.0, sz), (sx * 4.2, -9.0, sz), (sx * 3.4, -11.0, sz)], 0.45, "Yellow", g, verts=8)
    # Rug: antennemast (asymmetrisch).
    tube([(3.0, 11.0, -14.0), (3.0, 22.0, -12.0)], 0.35, "Steel", g, verts=8)


# =====================================================================================
# B. Glomar: omgebouwd boorschip met een boortoren boven het gat waarin de Mol hangt.
# =====================================================================================

def concept_b(g):
    hullst = [
        (-56, 3.0, 8.0, 2.0, 4, 3),
        (-49, 10.0, 8.5, -3.0, 5, 3),
        (-38, 15.0, 8.0, -6.5, 6, 4),
        (-15, 16.0, 7.5, -7.5, 7, 5),
        (22, 16.0, 7.5, -7.5, 7, 5),
        (42, 15.0, 7.5, -6.5, 6, 4),
        (54, 13.0, 8.0, -4.5, 6, 4),
    ]
    hull("B_Hull", hullst, "Anthracite", g, n=40, sub=3, point_ends=False)
    hull("B_Belly", [(z, hw * 0.93, bot + 3.0, bot - 0.3, 6, 4) for (z, hw, top, bot, et, eb) in hullst[1:6]], "Cream", g, n=40, sub=3)
    # Witte "schouders" langs het dek.
    for s in (-1, 1):
        box((1.0, 2.2, 60.0), (s * 15.7, 5.0, 0.0), "Cream", g, bevel=0.3)
    # Opbouw achteraan links, gestapeld en uit het midden.
    box((20.0, 8.0, 18.0), (-4.0, 12.0, 38.0), "Anthracite", g, bevel=0.6)
    box((14.0, 6.0, 12.0), (-6.0, 19.0, 36.0), "Cream", g, bevel=0.5)
    box((12.0, 1.4, 0.6), (-6.0, 19.5, 29.9), "Cyan", g, bevel=0.1)
    box((8.0, 5.0, 8.0), (-8.0, 24.5, 37.0), "Anthracite", g, bevel=0.4)
    tube([(-8.0, 27.0, 37.0), (-8.0, 36.0, 38.0)], 0.3, "Steel", g, verts=8)
    cyl(2.0, 9.0, (6.0, 19.0, 44.0), "Red", g, verts=16, bevel=0.2)  # schoorsteen van een andere firma
    # Boortoren midscheeps, boven het gat.
    lattice_tower((0.0, 7.5, -4.0), 38.0, 6.5, 6, 0.4, "Yellow", g)
    box((10.0, 1.2, 10.0), (0.0, 8.1, -4.0), "Yellow", g, bevel=0.2)
    # De Mol hangt in het gat onder de toren.
    mol((0.0, -8.0, -4.0), g)
    tube([(0.0, 38.0, -4.0), (0.0, -4.0, -4.0)], 0.2, "Steel", g, verts=6)
    # Kranen op het voordek.
    box((2.0, 2.0, 22.0), (-9.0, 13.0, -36.0), "Yellow", g, bevel=0.2, rot=(-20, 25, 0))
    cyl(2.0, 4.0, (-9.0, 9.5, -30.0), "Yellow", g, verts=12, bevel=0.2)
    # Vier motorgondels aan uitleggers, één ervan in een vreemde kleur (vervangen).
    for (x, z, m) in ((-24, -28, "DarkSteel"), (24, -28, "DarkSteel"), (-24, 26, "Blue"), (24, 26, "DarkSteel")):
        box((8.0, 2.0, 5.0), (x * 0.72, 0.0, z), "Anthracite", g, bevel=0.3)
        cyl(4.0, 18.0, (x, 0.0, z), m, g, axis="z", verts=20, bevel=0.3)
        cyl(3.2, 0.6, (x, 0.0, z + 9.2), "LensOrange", g, axis="z", verts=20, bevel=0.0)
    # Opgelapte platen.
    box((0.4, 4.0, 6.0), (16.1, -1.0, 12.0), "Red", g, bevel=0.1)
    box((0.4, 3.0, 5.0), (-16.1, 0.0, -20.0), "Panel", g, bevel=0.1)


# =====================================================================================
# C. Fabriekstrawler: lange lage romp, brug vooraan, A-portaal achteraan dat de Mol ophijst.
# =====================================================================================

def concept_c(g):
    hullst = [
        (-52, 2.5, 5.0, 0.5, 3, 3),
        (-44, 9.0, 6.5, -3.0, 4, 3),
        (-32, 12.5, 6.5, -5.0, 5, 4),
        (28, 12.5, 6.5, -5.0, 5, 4),
        (44, 11.5, 6.5, -4.5, 5, 4),
        (50, 10.5, 6.5, -4.0, 5, 4),
    ]
    hull("C_Hull", hullst, "Anthracite", g, n=40, sub=3, point_ends=False)
    hull("C_Belly", [(z, hw * 0.92, bot + 2.5, bot - 0.3, 5, 4) for (z, hw, top, bot, et, eb) in hullst[1:5]], "Cream", g, n=40, sub=3)
    # Brugblok vooraan, hoog, met een raamband.
    hull("C_Bridge", [(-42, 6.0, 20.0, 6.0, 5, 6), (-36, 9.0, 22.0, 6.0, 6, 6), (-27, 9.0, 21.0, 6.0, 6, 6), (-24, 7.0, 19.0, 6.0, 6, 6)],
         "Cream", g, n=32, sub=2, point_ends=False)
    box((15.0, 1.6, 0.6), (0.0, 19.0, -39.5), "Cyan", g, bevel=0.1, rot=(-12, 0, 0))
    # Verwerkingsschoorstenen langs de rug.
    for i, (x, z, h) in enumerate(((-5, -14, 14), (5, -4, 11), (-4, 8, 16), (4, 18, 10))):
        cyl(2.2, h, (x, 6.0 + h / 2, z), "DarkSteel" if i % 2 else "Anthracite", g, verts=16, bevel=0.2)
        cyl(2.5, 0.8, (x, 6.0 + h, z), "Yellow", g, verts=16, bevel=0.1)
    # A-portaal op de achtersteven, de Mol hangt erachter.
    for s in (-1, 1):
        tube([(s * 10.0, 6.5, 44.0), (s * 5.0, 30.0, 54.0)], 0.9, "Yellow", g, verts=10)
    tube([(-5.5, 30.0, 54.0), (5.5, 30.0, 54.0)], 1.0, "Yellow", g, verts=10)
    tube([(0.0, 30.0, 54.0), (0.0, 1.0, 58.0)], 0.2, "Steel", g, verts=6)
    mol((0.0, -2.0, 58.5), g)
    # Uitklapbare stabilisatoren als vleugels.
    for s in (-1, 1):
        plate(f"C_Stab{s}", [(s * 12.0, 1.0, -10.0), (s * 30.0, 2.0, -6.0), (s * 30.0, 2.0, 4.0), (s * 12.0, 1.0, 6.0)], 1.2, "Cream", g)
        cyl(2.6, 10.0, (s * 30.0, 2.0, -1.0), "DarkSteel", g, axis="z", verts=16, bevel=0.2)
        cyl(2.0, 0.5, (s * 30.0, 2.0, 4.3), "LensOrange", g, axis="z", verts=16, bevel=0.0)


# =====================================================================================
# D. Het nest: koepel met gestolen modules, een gat onderaan en een lange staart.
# =====================================================================================

def concept_d(g):
    hull("D_Dome", [(-26, 4.0, 4.0, -2.0, 2, 2), (-20, 17.0, 14.0, -9.0, 2.2, 2.6), (-8, 25.0, 19.0, -12.0, 2.2, 2.8),
                    (8, 25.0, 19.0, -12.0, 2.2, 2.8), (20, 17.0, 14.0, -9.0, 2.2, 2.6), (26, 4.0, 4.0, -2.0, 2, 2)],
         "Anthracite", g, n=48, sub=3)
    hull("D_Belly", [(-18, 14.0, -5.0, -10.5, 2.2, 2.6), (0, 22.0, -5.0, -12.3, 2.2, 2.8), (18, 14.0, -5.0, -10.5, 2.2, 2.6)],
         "Cream", g, n=48, sub=3)
    torus(25.5, 1.2, (0.0, 2.0, 0.0), "Yellow", g, major_seg=48, minor_seg=8)
    # Gestolen modules in andere kleuren, half overgeschilderd.
    cyl(5.0, 22.0, (-27.0, 4.0, -12.0), "Blue", g, axis="x", verts=20, bevel=0.3)
    box((6.0, 6.0, 6.0), (-34.0, 4.0, -12.0), "Yellow", g, bevel=0.3)
    box((14.0, 10.0, 16.0), (26.0, 0.0, 6.0), "Red", g, bevel=0.5)
    box((6.0, 10.2, 8.0), (30.0, 0.0, 4.0), "Yellow", g, bevel=0.3)
    cyl(4.0, 14.0, (6.0, 22.0, -6.0), "Green", g, verts=18, bevel=0.3)
    cyl(6.0, 3.0, (6.0, 30.0, -6.0), "Panel", g, verts=18, bevel=0.3)
    box((10.0, 7.0, 10.0), (-10.0, 17.0, 10.0), "Panel", g, bevel=0.4)
    box((9.0, 1.2, 0.5), (-10.0, 18.0, 4.8), "Cyan", g, bevel=0.1)
    # Lange staart: antenne- en motorboom.
    hull("D_Tail", [(22, 4.0, 5.0, -3.0, 3, 3), (40, 2.2, 3.0, -1.0, 3, 3), (70, 1.6, 2.4, -0.4, 3, 3)], "Anthracite", g, n=24, sub=2,
         point_ends=False)
    for s in (-1, 1):
        cyl(2.6, 9.0, (s * 4.0, 1.0, 72.0), "DarkSteel", g, axis="z", verts=16, bevel=0.2)
        cyl(2.0, 0.5, (s * 4.0, 1.0, 76.7), "LensOrange", g, axis="z", verts=16, bevel=0.0)
    # Drop-schacht onderaan, de Mol erin.
    cyl(7.5, 4.0, (0.0, -12.5, 0.0), "DarkSteel", g, verts=24, bevel=0.2)
    mol((0.0, -17.5, 0.0), g)


CONCEPTS = {
    "A": ("Skycrane-ekster", concept_a),
    "B": ("Glomar (boorschip)", concept_b),
    "C": ("Fabriekstrawler", concept_c),
    "D": ("Het nest", concept_d),
}


# =====================================================================================
# Renderen en meten
# =====================================================================================

def collection_of(group: str) -> bpy.types.Collection:
    col = bpy.data.collections.new(group)
    bpy.context.scene.collection.children.link(col)
    for o in PARTS.get(group, []):
        for c in o.users_collection:
            c.objects.unlink(o)
        col.objects.link(o)
    return col


def bounds(objs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def camera() -> bpy.types.Object:
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    return cam


def aim(cam, pos_b: Vector, target_b: Vector, up=(0, 0, 1)):
    d = (target_b - pos_b).normalized()
    cam.location = pos_b
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def render(path: Path) -> np.ndarray:
    sc = bpy.context.scene
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(str(path))
    px = np.array(img.pixels[:]).reshape(img.size[1], img.size[0], 4)[::-1]
    bpy.data.images.remove(img)
    return px


def metrics(mask: np.ndarray) -> dict:
    ys, xs = np.nonzero(mask)
    box_area = (xs.max() - xs.min() + 1) * (ys.max() - ys.min() + 1)
    m = mask.astype(np.float32)
    k = np.ones((5, 5), np.float32) / 25.0
    pad = np.pad(m, 2)
    blur = sum(pad[i:i + m.shape[0], j:j + m.shape[1]] * k[i, j] for i in range(5) for j in range(5))
    gy, gx = np.gradient(blur)
    edge = (blur > 0.15) & (blur < 0.85)
    ang = np.degrees(np.arctan2(gy[edge], gx[edge])) % 90.0
    axis = np.minimum(ang, 90.0 - ang) < 5.0
    return {"vulling": round(float(mask.sum() / box_area), 3), "rechte_omtrek": round(float(axis.mean()), 3)}


def silhouette_mode():
    sh = bpy.context.scene.display.shading
    sh.light = "FLAT"
    sh.color_type = "SINGLE"
    sh.single_color = (0.0, 0.0, 0.0)
    sh.show_cavity = False
    sh.show_shadows = False
    bpy.context.scene.world.color = (1.0, 1.0, 1.0)


def studio_mode(bg=(0.72, 0.75, 0.8)):
    sh = bpy.context.scene.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    sh.show_shadows = True
    bpy.context.scene.world.color = bg


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.world = bpy.data.worlds.new("W")
    sc.view_settings.view_transform = "Standard"
    sc.render.film_transparent = False
    sc.render.resolution_x = 640
    sc.render.resolution_y = 400
    sc.display.shading.show_object_outline = False
    cols = {}
    for key, (title, build) in CONCEPTS.items():
        build(key)
        cols[key] = collection_of(key)
    cam = camera()
    report = {}
    for key, col in cols.items():
        for k2, c2 in cols.items():
            c2.hide_render = k2 != key
        objs = list(col.objects)
        lo, hi = bounds(objs)
        center = (lo + hi) / 2
        size = hi - lo  # Blender-assen: x, y (= −Godot z), z (= Godot y)
        cam.data.type = "ORTHO"
        res = {"titel": CONCEPTS[key][0], "lengte_m": round(size.y, 1), "breedte_m": round(size.x, 1), "hoogte_m": round(size.z, 1)}
        silhouette_mode()
        far = 400.0
        views = {
            # zijkant: boeg links (camera aan de linkerkant van het schip, kijkt naar rechts)
            "zij": (center + Vector((-far, 0, 0)), max(size.y, size.z * 1.6) * 1.08),
            "boven": (center + Vector((0, 0, far)), max(size.y, size.x * 1.6) * 1.08),
            "voor": (center + Vector((0, far, 0)), max(size.x, size.z * 1.6) * 1.15),  # Blender +y = Godot −z (boeg)
        }
        for name, (pos, scale) in views.items():
            cam.data.ortho_scale = scale
            aim(cam, pos, center)
            if name == "boven":
                cam.rotation_euler = (0.0, 0.0, math.radians(-90.0))  # boeg links, zoals de zijkant
            px = render(OUT / f"{key}_{name}.png")
            res[name] = metrics(px[..., 0] < 0.5)
        # Schuin van onder, studiolicht.
        studio_mode()
        cam.data.type = "PERSP"
        cam.data.sensor_fit = "VERTICAL"
        cam.data.angle = math.radians(40.0)
        cam.data.clip_end = 5000.0
        dist = size.length * 0.95
        aim(cam, center + Vector((-0.6, 0.55, -0.42)).normalized() * dist, center)
        render(OUT / f"{key}_onder.png")
        aim(cam, center + Vector((0.7, 0.45, 0.35)).normalized() * dist, center)
        render(OUT / f"{key}_boven34.png")
        # Vanaf de planeet: 340 m lager, iets opzij, 75° verticale beeldhoek.
        studio_mode(bg=(0.85, 0.66, 0.52))
        cam.data.angle = math.radians(75.0)
        aim(cam, center + Vector((60.0, -110.0, -340.0)), center)
        render(OUT / f"{key}_planeet.png")
        report[key] = res
        print(f"[concepts] {key} {json.dumps(res, ensure_ascii=False)}")
    (OUT / "concepts.json").write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")


main()
