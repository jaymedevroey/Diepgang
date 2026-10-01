"""Decor voor het hoofdmenu: de rand van de put rond de geparkeerde Mol.

Gebruik:
    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup \\
        --python tools/blender/menu_set.py -- game/assets/models/menu_set.glb

Godot-coördinaten: de Mol staat met zijn midden op de oorsprong, neus naar −z, rupsen op y = −2,73.
Objecten:
  Ground     heuvelachtige kleigrond met een afgrond rechts (de put), vertexkleuren
  Rocks      rotsblokken, vertexkleuren
  Props      lichtmast, kisten, vaten, hek met lint, werfbord (machine-materialen + vertexkleur-slijtage)
Ankers: Flood_Light (lamp van de mast, gericht op de Mol), Sign_Light, Cam_Start, Cam_Look
"""

import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

sys.path.append(str(Path(__file__).parent))
import kit  # noqa: E402
from kit import G, PARTS, bake_wear, box, cyl, empty, export_glb, join_group, parent_to, sphere, text, tri_count, tube  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = Path(ARGS[0]) if ARGS else Path("game/assets/models/menu_set.glb")
GROUND_Y = -2.75
EDGE_X = 13.0  # vanaf hier valt de grond weg in de put

kit.PALETTE["Clay"] = ((0.43, 0.29, 0.21), 0.0, 0.95, None)
kit.PALETTE["Rock"] = ((0.37, 0.33, 0.30), 0.0, 0.9, None)
kit.PALETTE["Concrete"] = ((0.55, 0.53, 0.5), 0.0, 0.9, None)


def ground_height(x, z):
    """Hoogte van de grond (Godot-y) op (x, z)."""
    p = Vector((x * 0.08, z * 0.08, 0.3))
    h = noise.noise(p) * 0.8 + noise.noise(p * 2.7) * 0.25
    # Een wal achter de Mol en een lichte kom rond de werkplek.
    h += 1.6 * math.exp(-((z - 22.0) ** 2) / 40.0) * (1.0 - math.exp(-(x * x) / 300.0))
    h *= min(1.0, (x * x + z * z) / 60.0)  # vlak waar de Mol staat
    # De put: rechts valt de grond steil weg.
    if x > EDGE_X:
        d = x - EDGE_X
        h -= d * d * 0.55 + d * 1.2
    return GROUND_Y + h


def build_ground():
    size, n = 90.0, 120
    bm = bmesh.new()
    verts = []
    for j in range(n + 1):
        row = []
        for i in range(n + 1):
            x = -size / 2 + size * i / n
            z = -size / 2 + size * j / n
            row.append(bm.verts.new(G(x, ground_height(x, z), z)))
        verts.append(row)
    for j in range(n):
        for i in range(n):
            bm.faces.new((verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
    me = bpy.data.meshes.new("Ground")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("Ground", me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(kit.mat("Clay"))
    for p in me.polygons:
        p.use_smooth = True
    # Vertexkleuren: klei met vlekken, donkerder in kuiltjes, lichter op ruggen, rood-bruine banden in de put.
    col = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    base = Vector((0.43, 0.29, 0.21))
    light = Vector((0.60, 0.42, 0.30))
    dark = Vector((0.24, 0.16, 0.12))
    for v in me.vertices:
        x, y = v.co.x, v.co.y  # Blender x, y (= Godot x, −z)
        gy = v.co.z
        n1 = noise.noise(Vector((x * 0.21, y * 0.21, 1.7))) * 0.5 + 0.5
        n2 = noise.noise(Vector((x * 0.9, y * 0.9, 4.2))) * 0.5 + 0.5
        c = base.lerp(light, n1 * 0.55).lerp(dark, (1.0 - n2) * 0.35)
        if gy < GROUND_Y - 1.0:  # wand van de put: banden
            band = 0.5 + 0.5 * math.sin(gy * 2.3 + noise.noise(Vector((x * 0.2, y * 0.2, 0))) * 2.0)
            c = c.lerp(Vector((0.55, 0.36, 0.24)), band * 0.5)
        col.data[v.index].color = (c.x, c.y, c.z, 1.0)
    me.color_attributes.active_color = col
    me.color_attributes.render_color_index = me.color_attributes.find("Col")
    PARTS.setdefault("Ground", []).append(o)


def rock(pos, size, seed, squash=0.7):
    rng = random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=G(*pos))
    o = bpy.context.active_object
    for v in o.data.vertices:
        d = v.co.normalized()
        k = 1.0 + noise.noise(d * 1.6 + Vector((seed, 0, 0))) * 0.35 + rng.uniform(-0.05, 0.05)
        v.co = d * k
    o.scale = (size * rng.uniform(0.8, 1.2), size * rng.uniform(0.8, 1.2), size * squash)
    o.rotation_euler = (0, 0, rng.uniform(0, math.tau))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(kit.mat("Rock"))
    for p in o.data.polygons:
        p.use_smooth = False  # gefacetteerd: chunky rots
    col = o.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for v in o.data.vertices:
        t = 0.5 + 0.5 * v.normal.z  # bovenkant lichter (stof), onderkant donker
        c = Vector((0.30, 0.27, 0.25)).lerp(Vector((0.55, 0.46, 0.38)), t * 0.8)
        col.data[v.index].color = (c.x, c.y, c.z, 1.0)
    o.data.color_attributes.active_color = col
    o.data.color_attributes.render_color_index = o.data.color_attributes.find("Col")
    PARTS.setdefault("Rocks", []).append(o)


def build_rocks():
    spots = [(-11, 9, 1.6), (-16, -4, 2.2), (-7, 18, 2.6), (9, 15, 1.4), (12.5, -9, 1.1), (-20, 14, 3.0),
             (6, -20, 2.4), (-4, -22, 1.8), (17, 6, 1.3), (-13, -16, 1.5)]
    for i, (x, z, s) in enumerate(spots):
        rock((x, ground_height(x, z) + s * 0.25, z), s, i * 7 + 3)


def build_floodlight(x, z):
    g = "Props"
    y = ground_height(x, z)
    box((1.2, 0.5, 1.2), (x, y + 0.2, z), "Concrete", g, bevel=0.06)
    h = 7.2
    for dx, dz in ((-0.22, -0.22), (0.22, -0.22), (0.22, 0.22), (-0.22, 0.22)):
        tube([(x + dx, y + 0.45, z + dz), (x + dx * 0.6, y + h, z + dz * 0.6)], 0.045, "Yellow", g, verts=8)
    k = 0.0
    while k < h - 0.6:  # schoorstijlen
        tube([(x - 0.22, y + 0.5 + k, z - 0.22), (x + 0.2, y + 1.1 + k, z - 0.2)], 0.025, "Yellow", g, verts=6)
        tube([(x + 0.22, y + 0.5 + k, z + 0.22), (x - 0.2, y + 1.1 + k, z + 0.2)], 0.025, "Yellow", g, verts=6)
        k += 0.8
    top = y + h
    box((1.6, 0.12, 0.3), (x, top + 0.05, z), "Anthracite", g, bevel=0.02)
    for i, dx in enumerate((-0.55, 0.0, 0.55)):
        box((0.42, 0.36, 0.3), (x + dx, top + 0.3, z), "Anthracite", g, bevel=0.04, rot=(-25, -35, 0))
        cyl(0.15, 0.04, (x + dx + 0.07, top + 0.27, z + 0.1), "Lens", g, verts=16, bevel=0.0, rot=(65, -35, 0))
    tube([(x + 0.3, top - 0.2, z), (x + 0.6, y + 2.0, z + 0.5), (x + 1.4, y + 0.05, z + 1.4)], 0.03, "Rubber", g, verts=6)
    box((0.5, 0.7, 0.35), (x + 0.4, y + 1.3, z + 0.3), "Anthracite", g, bevel=0.04)  # aansluitkast
    return (x, top + 0.3, z)


def barrel(x, z, material, tilt=0.0):
    g = "Props"
    y = ground_height(x, z)
    cyl(0.32, 0.9, (x, y + 0.45, z), material, g, verts=18, bevel=0.03, rot=(tilt, 0, 0))
    for dy in (0.2, 0.7):
        cyl(0.335, 0.05, (x, y + dy, z), "DarkSteel", g, verts=18, bevel=0.01, rot=(tilt, 0, 0))


def crate(x, z, s, rot_y):
    g = "Props"
    y = ground_height(x, z) + s / 2
    box((s, s, s), (x, y, z), "Wood", g, bevel=0.03, rot=(0, rot_y, 0))
    for dy in (-s / 2 + 0.06, s / 2 - 0.06):
        box((s + 0.02, 0.08, s + 0.02), (x, y + dy, z), "Anthracite", g, bevel=0.01, rot=(0, rot_y, 0))
    a = math.radians(rot_y)
    fx, fz = math.sin(a) * (s / 2 + 0.012), math.cos(a) * (s / 2 + 0.012)
    text("DIEPGANG", s * 0.14, (x + fx, y, z + fz), (0, rot_y, 0), "DecalDark", g, extrude=0.004)


def build_fence():
    g = "Props"
    z = -22.0
    posts = []
    while z < 22.0:
        x = EDGE_X - 1.2 + math.sin(z * 0.3) * 0.4
        y = ground_height(x, z)
        cyl(0.06, 1.2, (x, y + 0.55, z), "Yellow", g, verts=8, bevel=0.01)
        cyl(0.075, 0.12, (x, y + 1.1, z), "Red", g, verts=8, bevel=0.01)
        posts.append((x, y, z))
        z += 3.2
    for a, b in zip(posts, posts[1:]):
        for hgt in (0.65, 0.95):
            p0 = Vector((a[0], a[1] + hgt, a[2]))
            p1 = Vector((b[0], b[1] + hgt, b[2]))
            mid = (p0 + p1) / 2 + Vector((0, -0.06, 0))
            length = (p1 - p0).length
            yaw = math.degrees(math.atan2(p1.x - p0.x, p1.z - p0.z))
            box((0.01, 0.07, length), (mid.x, mid.y, mid.z), "Hazard", g, bevel=0.0, rot=(0, yaw, 0))


def build_sign(x, z):
    g = "Props"
    y = ground_height(x, z)
    for dx in (-1.0, 1.0):
        box((0.12, 2.4, 0.12), (x + dx, y + 1.2, z), "Anthracite", g, bevel=0.02, rot=(0, 30, 0))
    rot = (0, 30, 0)
    box((2.6, 1.3, 0.08), (x, y + 2.0, z), "Yellow", g, bevel=0.03, rot=rot)
    a = math.radians(30)
    fx, fz = math.sin(a) * 0.05, math.cos(a) * 0.05
    text("DIEPGANG BV", 0.3, (x + fx, y + 2.35, z + fz), rot, "DecalDark", g, extrude=0.006)
    text("PUT 7  ·  BOORPLOEG", 0.16, (x + fx, y + 1.95, z + fz), rot, "DecalDark", g, extrude=0.006)
    text("BETREDEN OP EIGEN RISICO", 0.11, (x + fx, y + 1.62, z + fz), rot, "Red", g, extrude=0.006)
    box((0.3, 0.12, 0.25), (x, y + 2.75, z), "Anthracite", g, bevel=0.03, rot=rot)
    cyl(0.07, 0.03, (x + fx, y + 2.7, z + fz * 1.6), "Bulb", g, verts=12, bevel=0.0, rot=(90, 30, 0))
    return (x + fx * 3, y + 2.6, z + fz * 3)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_ground()
    build_rocks()
    flood = build_floodlight(-17.0, -3.0)
    for (x, z, m, t) in ((6.2, 4.5, "Red", 0), (6.9, 5.2, "Blue", 0), (6.4, 6.0, "Yellow", 0), (8.0, 3.2, "Red", 90)):
        barrel(x, z, m, t)
    for (x, z, s, r) in ((-5.6, 6.2, 1.0, 12), (-6.4, 7.4, 0.8, -20), (-5.8, 7.0, 0.6, 40)):
        crate(x, z, s, r)
    build_fence()
    sign = build_sign(-10.5, 3.5)

    root = bpy.data.objects.new("MenuSet", None)
    bpy.context.collection.objects.link(root)
    objects = {
        "Ground": join_group("Ground", "Ground"),
        "Rocks": join_group("Rocks", "Rocks"),
        "Props": join_group("Props", "Props"),
    }
    bake_wear(objects["Props"], strength=5.0, seed=11)
    for o in objects.values():
        parent_to(o, root)
    # Lamp van de mast: richt op de Mol (oorsprong).
    to = Vector((0.0, -1.0, 0.0)) - Vector(flood)
    yaw = math.degrees(math.atan2(-to.x, -to.z))
    pitch = math.degrees(math.atan2(to.y, math.hypot(to.x, to.z)))
    empty("Flood_Light", flood, (pitch, yaw, 0), parent=root)
    empty("Sign_Light", sign, (0, 0, 0), parent=root)
    total = 0
    for name, o in objects.items():
        n = tri_count(o)
        total += n
        print(f"[menu_set] {name:8s} {n:7d} driehoeken")
    print(f"[menu_set] totaal {total} driehoeken")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    export_glb(OUT)
    print(f"[menu_set] geschreven: {OUT}")


main()
