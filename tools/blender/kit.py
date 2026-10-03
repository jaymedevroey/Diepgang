"""Bouwstenen voor Blender-modellen van Diepgang (stijlgids: chunky, afgeschuind, één palet).

Alle maten en posities in GODOT-coördinaten (meter): x rechts, y omhoog, z naar achteren
(−z = vooruit). `G()` zet om naar Blender (z omhoog): Blender = (x, −z, y). Na glTF-export
(Y-up) komt alles weer exact op de Godot-plek terecht.

Gebruik in een model-script:
    import sys; sys.path.append(str(Path(__file__).parent)); from kit import *
"""

import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

# --- Assen ---------------------------------------------------------------------


def G(x, y, z):
    """Godot-punt → Blender-punt."""
    return Vector((x, -z, y))


def GS(sx, sy, sz):
    """Godot-afmetingen → Blender-afmetingen."""
    return Vector((sx, sz, sy))


# Rotaties: een Blender-primitief cilinder staat langs Blender-Z = Godot-Y.
AXIS_ROT = {
    "y": (0.0, 0.0, 0.0),            # rechtop
    "z": (math.radians(90), 0.0, 0.0),  # langs de rijrichting
    "x": (0.0, math.radians(90), 0.0),  # dwars
}


# --- Materialen -------------------------------------------------------------------

PALETTE = {
    # naam: (kleur, metallic, roughness, emissie)
    "Yellow": ((0.949, 0.718, 0.020), 0.15, 0.48, None),
    "Anthracite": ((0.137, 0.149, 0.169), 0.35, 0.55, None),
    "Steel": ((0.549, 0.565, 0.588), 0.9, 0.32, None),
    "DarkSteel": ((0.20, 0.205, 0.215), 0.85, 0.45, None),
    "CutterSteel": ((0.66, 0.66, 0.64), 0.45, 0.38, None),
    "Rubber": ((0.06, 0.06, 0.065), 0.0, 0.85, None),
    "Hazard": ((0.949, 0.718, 0.020), 0.15, 0.5, None),
    "Lens": ((1.0, 0.85, 0.6), 0.0, 0.1, ((1.0, 0.78, 0.45), 4.0)),
    "LensRed": ((1.0, 0.15, 0.08), 0.0, 0.1, ((1.0, 0.12, 0.05), 3.0)),
    "LensOrange": ((1.0, 0.45, 0.05), 0.0, 0.1, ((1.0, 0.4, 0.03), 3.0)),
    "Glass": ((0.55, 0.75, 0.8), 0.0, 0.05, None),
    "Screen": ((0.02, 0.03, 0.04), 0.0, 0.15, None),
    "Cream": ((0.913, 0.882, 0.827), 0.05, 0.6, None),
    "Panel": ((0.78, 0.76, 0.72), 0.1, 0.55, None),
    "Floor": ((0.24, 0.245, 0.25), 0.8, 0.5, None),
    "Wood": ((0.55, 0.36, 0.2), 0.0, 0.75, None),
    "Leather": ((0.42, 0.24, 0.13), 0.0, 0.6, None),
    "Red": ((0.78, 0.1, 0.07), 0.1, 0.45, None),
    "Copper": ((0.72, 0.42, 0.25), 0.9, 0.35, None),
    "Blue": ((0.15, 0.35, 0.6), 0.2, 0.5, None),
    "DecalDark": ((0.05, 0.05, 0.055), 0.0, 0.6, None),
    "DecalLight": ((0.95, 0.93, 0.88), 0.0, 0.6, None),
    "Bulb": ((1.0, 0.9, 0.7), 0.0, 0.2, ((1.0, 0.82, 0.55), 6.0)),
    "Cyan": ((0.31, 0.89, 0.94), 0.0, 0.2, ((0.31, 0.89, 0.94), 3.0)),
    "Green": ((0.3, 0.55, 0.22), 0.0, 0.7, None),
    # Nostromo-stijl (De Ekster): zinkgrijze romp in drie tinten, grijsgroen van een andere fabrikant,
    # menie voor vakwerk, roet, crème capitonnage binnen, en de lampjes op de buik.
    "HullGrey": ((0.420, 0.424, 0.408), 0.45, 0.6, None),
    "HullDark": ((0.298, 0.306, 0.294), 0.45, 0.62, None),
    "HullLight": ((0.541, 0.541, 0.514), 0.4, 0.58, None),
    "GreyGreen": ((0.369, 0.4, 0.353), 0.3, 0.62, None),
    "RedOxide": ((0.482, 0.247, 0.173), 0.2, 0.7, None),
    "Soot": ((0.169, 0.153, 0.141), 0.1, 0.85, None),
    "Padded": ((0.851, 0.827, 0.757), 0.0, 0.75, None),
    "BellyLight": ((1.0, 0.75, 0.48), 0.0, 0.3, ((1.0, 0.72, 0.42), 8.0)),
    "EngineGlow": ((0.75, 0.88, 1.0), 0.0, 0.2, ((0.7, 0.85, 1.0), 8.0)),
    "NavRed": ((1.0, 0.15, 0.1), 0.0, 0.2, ((1.0, 0.12, 0.08), 6.0)),
    "NavGreen": ((0.2, 1.0, 0.4), 0.0, 0.2, ((0.2, 1.0, 0.4), 6.0)),
    "RunLight": ((0.6, 0.85, 1.0), 0.0, 0.2, ((0.55, 0.8, 1.0), 5.0)),
    "PlayerColor": ((0.95, 0.55, 0.12), 0.1, 0.5, None),  # in Godot vervangen door de spelerskleur
}
_MATS = {}


def mat(name):
    if name in _MATS:
        return _MATS[name]
    color, metallic, rough, emission = PALETTE[name]
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1.0)
    try:
        m.use_nodes = True
    except AttributeError:
        pass
    bsdf = m.node_tree.nodes.get("Principled BSDF") if m.node_tree else None
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = rough
        if emission:
            bsdf.inputs["Emission Color"].default_value = (*emission[0], 1.0)
            bsdf.inputs["Emission Strength"].default_value = emission[1]
        if name == "Glass":
            bsdf.inputs["Alpha"].default_value = 0.35
            try:
                m.surface_render_method = "BLENDED"
            except AttributeError:
                pass
    _MATS[name] = m
    return m


# --- Onderdelen registreren -----------------------------------------------------------

PARTS = {}  # groepnaam -> [objecten]


def _finish(obj, material, group, bevel=0.0, segments=2, angle=35.0, smooth=True):
    obj.data.materials.clear()
    obj.data.materials.append(mat(material))
    if bevel > 0:
        m = obj.modifiers.new("Bevel", "BEVEL")
        m.width = bevel
        m.segments = segments
        m.limit_method = "ANGLE"
        m.angle_limit = math.radians(angle)
        m.harden_normals = False
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
    PARTS.setdefault(group, []).append(obj)
    return obj


def _active():
    return bpy.context.active_object


def box(size, pos, material, group, bevel=0.04, segments=2, rot=(0, 0, 0)):
    """Afgeschuind blok. size/pos in Godot; rot in graden rond Godot-assen (x, y, z)."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=G(*pos))
    o = _active()
    o.scale = GS(*size)
    o.rotation_euler = _godot_euler(rot)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _finish(o, material, group, bevel, segments)


def cyl(radius, depth, pos, material, group, axis="y", verts=24, bevel=0.02, segments=2, r2=None, rot=None):
    """Cilinder (of kegel als r2 gezet) langs een Godot-as."""
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, vertices=verts, location=G(*pos))
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=radius, radius2=r2, depth=depth, vertices=verts, location=G(*pos))
    o = _active()
    o.rotation_euler = AXIS_ROT[axis] if rot is None else _godot_euler(rot)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _finish(o, material, group, bevel, segments)


def sphere(radius, pos, material, group, scale=(1, 1, 1), segments=16, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, segments=segments, ring_count=rings, location=G(*pos))
    o = _active()
    o.scale = GS(*scale)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(o, material, group, 0.0)


def torus(major, minor, pos, material, group, axis="y", major_seg=32, minor_seg=8):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=major_seg,
                                     minor_segments=minor_seg, location=G(*pos))
    o = _active()
    o.rotation_euler = AXIS_ROT[axis]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _finish(o, material, group, 0.0)


def _godot_euler(rot):
    """Graden rond Godot x/y/z → Blender-euler. Godot y = Blender z, Godot z = −Blender y."""
    rx, ry, rz = (math.radians(a) for a in rot)
    m = (Matrix.Rotation(ry, 4, "Z") @ Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(-rz, 4, "Y"))
    return m.to_euler()


def prism(profile, z0, z1, material, group, bevel=0.06, segments=3, angle=30.0):
    """Extrudeert een 2D-profiel [(x, y), ...] (Godot, tegen de klok) van z0 tot z1."""
    bm = bmesh.new()
    front = [bm.verts.new(G(x, y, z0)) for x, y in profile]
    back = [bm.verts.new(G(x, y, z1)) for x, y in profile]
    n = len(profile)
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([front[i], back[i], back[j], front[j]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("prism")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("prism", me)
    bpy.context.collection.objects.link(o)
    return _finish(o, material, group, bevel, segments, angle)


def octagon(w, h, chamfer, y0=None, y1=None, cut_bottom=True, cut_top=True):
    """Afgeschuinde rechthoek (Godot x/y), gecentreerd, of tussen y0 en y1."""
    if y0 is None:
        y0, y1 = -h / 2, h / 2
    hw = w / 2
    cb = chamfer if cut_bottom else 0.0
    ct = chamfer if cut_top else 0.0
    pts = [(-hw + cb, y0), (hw - cb, y0), (hw, y0 + cb), (hw, y1 - ct), (hw - ct, y1), (-hw + ct, y1),
           (-hw, y1 - ct), (-hw, y0 + cb)]
    out = []
    for p in pts:  # dubbele punten weg (chamfer 0)
        if not out or (abs(out[-1][0] - p[0]) > 1e-6 or abs(out[-1][1] - p[1]) > 1e-6):
            out.append(p)
    if abs(out[0][0] - out[-1][0]) < 1e-6 and abs(out[0][1] - out[-1][1]) < 1e-6:
        out.pop()
    return out


def sweep(points, width, height, material, group, up=(0, 1, 0), closed=False, bevel=0.0):
    """Rechthoekig profiel langs een lijn (Godot-punten). `up` = richting van de hoogte."""
    bm = bmesh.new()
    rings = []
    upv = Vector(up)
    n = len(points)
    for i, p in enumerate(points):
        p = Vector(p)
        a = Vector(points[i - 1]) if (i > 0 or closed) else p
        b = Vector(points[(i + 1) % n]) if (i < n - 1 or closed) else p
        t = (b - a)
        if t.length < 1e-9:
            t = Vector((0, 0, 1))
        t.normalize()
        side = t.cross(upv)
        if side.length < 1e-6:
            side = t.cross(Vector((1, 0, 0)))
        side.normalize()
        u = side.cross(t).normalized()
        corners = [p + side * width / 2 + u * height / 2, p - side * width / 2 + u * height / 2,
                   p - side * width / 2 - u * height / 2, p + side * width / 2 - u * height / 2]
        rings.append([bm.verts.new(G(*c)) for c in corners])
    segs = n if closed else n - 1
    for i in range(segs):
        r0, r1 = rings[i], rings[(i + 1) % n]
        for k in range(4):
            bm.faces.new([r0[k], r0[(k + 1) % 4], r1[(k + 1) % 4], r1[k]])
    if not closed:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("sweep")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("sweep", me)
    bpy.context.collection.objects.link(o)
    return _finish(o, material, group, bevel, 2)


def loft(points, radii, material, group, verts=12, up=(0, 1, 0), twist=0.0, profile=None, smooth=True, bevel=0.0):
    """Buis met wisselende dikte langs Godot-punten (houweelpunt, botten, boorspiraal, kristallen).
    radii: per punt een getal of (rx, ry); 0 aan een uiteinde = spits. rx ligt opzij (t x up), ry langs up.
    profile: optionele doorsnede als lijst (x, y) rond (0, 0) met straal ~1, anders een cirkel.
    twist: graden draaiing van de doorsnede over de hele lengte."""
    pts = [Vector(p) for p in points]
    n = len(pts)
    if profile is None:
        profile = [(math.cos(i / verts * math.tau), math.sin(i / verts * math.tau)) for i in range(verts)]
    m = len(profile)
    upv = Vector(up)
    bm = bmesh.new()
    rings = []
    for i, p in enumerate(pts):
        a = pts[i - 1] if i > 0 else p
        b = pts[i + 1] if i < n - 1 else p
        t = b - a
        if t.length < 1e-9:
            t = Vector((0, 0, 1))
        t.normalize()
        side = t.cross(upv)
        if side.length < 1e-6:
            side = t.cross(Vector((1, 0, 0)))
        side.normalize()
        u = side.cross(t).normalized()
        r = radii[i]
        rx, ry = (r, r) if isinstance(r, (int, float)) else r
        if rx <= 1e-6 and ry <= 1e-6:
            rings.append([bm.verts.new(G(*p))])
            continue
        ang = math.radians(twist) * i / max(1, n - 1)
        ca, sa = math.cos(ang), math.sin(ang)
        ring = []
        for (x, y) in profile:
            xr, yr = x * ca - y * sa, x * sa + y * ca
            ring.append(bm.verts.new(G(*(p + side * xr * rx + u * yr * ry))))
        rings.append(ring)
    for i in range(n - 1):
        r0, r1 = rings[i], rings[i + 1]
        if len(r0) == 1 and len(r1) == 1:
            continue
        if len(r0) == 1:
            for k in range(m):
                bm.faces.new([r0[0], r1[k], r1[(k + 1) % m]])
        elif len(r1) == 1:
            for k in range(m):
                bm.faces.new([r0[k], r1[0], r0[(k + 1) % m]])
        else:
            for k in range(m):
                bm.faces.new([r0[k], r1[k], r1[(k + 1) % m], r0[(k + 1) % m]])
    if len(rings[0]) > 1:
        bm.faces.new(list(rings[0]))
    if len(rings[-1]) > 1:
        bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("loft")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("loft", me)
    bpy.context.collection.objects.link(o)
    return _finish(o, material, group, bevel, 2, smooth=smooth)


def tube(points, radius, material, group, verts=10, closed=False):
    """Buis langs Godot-punten (leidingen, relingen)."""
    cu = bpy.data.curves.new("tube", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = max(1, verts // 4)
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        sp.points[i].co = (*G(*p), 1.0)
    sp.use_cyclic_u = closed
    o = bpy.data.objects.new("tube", cu)
    bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = _active()
    o.select_set(False)
    return _finish(o, material, group, 0.0)


def rivets(points, radius, material, group):
    """Dikke bolkopklinknagels (afgeplatte halve bollen) op een lijst Godot-punten."""
    objs = []
    for p in points:
        objs.append(sphere(radius, p, material, group, scale=(1, 1, 1), segments=8, rings=4))
    return objs


def text(body, size, pos, rot, material, group, extrude=0.012, align="CENTER"):
    """Tekst als mesh. rot in graden rond Godot-assen; tekst ligt standaard in het Godot x/y-vlak, leest naar +z."""
    cu = bpy.data.curves.new("text", "FONT")
    cu.body = body
    cu.size = size
    cu.extrude = extrude
    cu.align_x = align
    cu.align_y = "CENTER"
    try:
        cu.font = bpy.data.fonts.load("<builtin>") if False else cu.font
    except Exception:
        pass
    o = bpy.data.objects.new("text", cu)
    bpy.context.collection.objects.link(o)
    # Blender-tekst ligt in het XY-vlak (normaal +Z). Rechtop zetten: normaal naar Godot +z (= Blender −y).
    base = Matrix.Rotation(math.radians(90), 4, "X")
    o.matrix_world = Matrix.Translation(G(*pos)) @ _godot_euler(rot).to_matrix().to_4x4() @ base
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = _active()
    o.select_set(False)
    return _finish(o, material, group, 0.0, smooth=False)


def boolean(target, cutter, operation="DIFFERENCE"):
    m = target.modifiers.new("Bool", "BOOLEAN")
    m.object = cutter
    m.operation = operation
    m.solver = "EXACT"
    try:
        m.material_mode = "TRANSFER"
    except AttributeError:
        pass
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.data.objects.remove(cutter, do_unlink=True)


def unregister(obj):
    for lst in PARTS.values():
        if obj in lst:
            lst.remove(obj)


# --- Samenvoegen, slijtage, export ---------------------------------------------------


def join_group(group, name, origin=(0, 0, 0)):
    """Past modifiers toe, voegt alle onderdelen van een groep samen tot één object `name`
    met oorsprong op `origin` (Godot)."""
    objs = PARTS.get(group, [])
    if not objs:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target="MESH")  # modifiers toepassen
    meshes = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    # Wereldpositie rechtstreeks in elke mesh zetten (niet vertrouwen op het actieve object).
    for o in meshes:
        o.data.transform(o.matrix_world)
        o.matrix_world = Matrix.Identity(4)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    o = meshes[0]
    o.name = name
    o.data.name = name
    off = G(*origin)
    o.data.transform(Matrix.Translation(-off))
    o.location = off
    # Matrix meteen bijwerken: anders leest de volgende stap (ouder koppelen) nog de oude.
    bpy.context.view_layer.update()
    PARTS[group] = [o]
    return o


def bake_wear(obj, strength=6.0, seed=0):
    """Vertexkleur 'Col': R = bolle rand (licht/slijtage), G = holte (vuil), B = willekeur per eiland.
    De machine-shader in Godot gebruikt dit (stijlgids: randen lichter, holtes donkerder)."""
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    curv = []
    for v in bm.verts:
        if not v.link_edges:
            curv.append(0.0)
            continue
        acc = 0.0
        for e in v.link_edges:
            d = e.other_vert(v).co - v.co
            if d.length > 1e-6:
                acc += d.normalized().dot(v.normal)
        curv.append(acc / len(v.link_edges))
    # Eilanden (losse onderdelen) een eigen willekeurige waarde.
    rng = random.Random(seed)
    island = [0.0] * len(bm.verts)
    seen = [False] * len(bm.verts)
    for v in bm.verts:
        if seen[v.index]:
            continue
        val = rng.random()
        stack = [v]
        seen[v.index] = True
        while stack:
            w = stack.pop()
            island[w.index] = val
            for e in w.link_edges:
                o = e.other_vert(w)
                if not seen[o.index]:
                    seen[o.index] = True
                    stack.append(o)
    bm.free()
    attr = me.color_attributes.get("Col") or me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i, c in enumerate(curv):
        edge = max(0.0, min(1.0, -c * strength))
        cavity = max(0.0, min(1.0, c * strength))
        attr.data[i].color = (edge, cavity, island[i], 1.0)
    me.color_attributes.active_color = attr
    try:
        me.color_attributes.render_color_index = me.color_attributes.find("Col")
    except Exception:
        pass


def empty(name, pos, rot=(0, 0, 0), parent=None):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o.matrix_world = Matrix.Translation(G(*pos)) @ _godot_euler(rot).to_matrix().to_4x4()
    if parent:
        o.parent = parent
        o.matrix_parent_inverse = parent.matrix_world.inverted()
    return o


def parent_to(child, parent):
    bpy.context.view_layer.update()
    mw = child.matrix_world.copy()
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()
    child.matrix_world = mw


def export_glb(path):
    bpy.ops.object.select_all(action="SELECT")
    kwargs = dict(filepath=str(path), export_format="GLB", export_apply=True, export_yup=True)
    for extra in ({"export_vertex_color": "ACTIVE"}, {"export_colors": True}, {}):
        try:
            bpy.ops.export_scene.gltf(**kwargs, **extra)
            return
        except TypeError:
            continue


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)
