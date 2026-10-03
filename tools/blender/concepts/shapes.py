"""Vormbouwstenen voor schetsen en het echte schip (docs/research/schip-bouwen-in-blender.md).

Coördinaten in Godot (x rechts, y omhoog, −z = voor), zoals kit.py. Een romp is een loft door
doorsneden: elke doorsnede is een superellips met eigen breedte, boven- en onderkant en
"hoekigheid" (exponent: 2 = ellips, 4–6 = afgeronde rechthoek). Tussen de opgegeven doorsneden
wordt glad geïnterpoleerd (Catmull-Rom op de parameters), zodat de romp versmalt en buigt.
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

from kit import G, PARTS, mat


def _cr(p0, p1, p2, p3, t):
    t2, t3 = t * t, t * t * t
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)


def _interp_stations(stations, sub):
    """stations: [(z, half_w, top, bottom, exp_top, exp_bot), ...] → fijnere lijst (Catmull-Rom)."""
    out = []
    n = len(stations)
    for i in range(n - 1):
        p0 = stations[max(i - 1, 0)]
        p1, p2 = stations[i], stations[i + 1]
        p3 = stations[min(i + 2, n - 1)]
        for k in range(sub):
            t = k / sub
            out.append(tuple(_cr(p0[j], p1[j], p2[j], p3[j], t) for j in range(6)))
    out.append(stations[-1])
    return out


def _ring(half_w, top, bottom, e_top, e_bot, n):
    """Superellips: punten tegen de klok in (x, y), begint onderaan in het midden."""
    yc = (top + bottom) / 2
    b_top = top - yc
    b_bot = yc - bottom
    pts = []
    for i in range(n):
        t = -math.pi / 2 + 2 * math.pi * i / n
        c, s = math.cos(t), math.sin(t)
        e = e_top if s >= 0 else e_bot
        x = max(half_w, 0.01) * math.copysign(abs(c) ** (2.0 / e), c)
        y = yc + (b_top if s >= 0 else b_bot) * math.copysign(abs(s) ** (2.0 / e), s)
        pts.append((x, y))
    return pts


def hull(name, stations, material, group, n=32, sub=3, x_offset=0.0, point_ends=True):
    """Loft door doorsneden langs z. stations: (z, halve breedte, boven-y, onder-y, exp boven, exp onder)."""
    st = _interp_stations(sorted(stations, key=lambda s: s[0]), sub)
    bm = bmesh.new()
    rings = []
    for (z, hw, top, bot, et, eb) in st:
        rings.append([bm.verts.new(G(x + x_offset, y, z)) for (x, y) in _ring(hw, top, bot, et, eb, n)])
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new([a[i], a[j], b[j], b[i]])
    for ring, first in ((rings[0], True), (rings[-1], False)):
        if point_ends:
            cx = sum(v.co.x for v in ring) / n
            cy = sum(v.co.y for v in ring) / n
            cz = sum(v.co.z for v in ring) / n
            tip = bm.verts.new((cx, cy, cz))
            for i in range(n):
                j = (i + 1) % n
                bm.faces.new([ring[j], ring[i], tip] if first else [ring[i], ring[j], tip])
        else:
            bm.faces.new(list(reversed(ring)) if first else ring)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat(material))
    PARTS.setdefault(group, []).append(o)
    return o


def plate(name, corners, thickness, material, group):
    """Vlakke plaat (vleugel, vin) uit een veelhoek in een vlak, met dikte. corners: Godot-punten."""
    bm = bmesh.new()
    vs = [bm.verts.new(G(*c)) for c in corners]
    f = bm.faces.new(vs)
    f.normal_update()
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    moved = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=moved, vec=f.normal * thickness)
    bmesh.ops.translate(bm, verts=bm.verts, vec=-f.normal * thickness * 0.5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat(material))
    PARTS.setdefault(group, []).append(o)
    return o


def lattice_tower(base, top_y, half_w, levels, radius, material, group):
    """Vakwerktoren (boortoren): vier staanders die naar boven versmallen, met regels en kruisen."""
    from kit import tube
    bx, by, bz = base
    for sx in (-1, 1):
        for sz in (-1, 1):
            tube([(bx + sx * half_w, by, bz + sz * half_w), (bx + sx * half_w * 0.35, top_y, bz + sz * half_w * 0.35)], radius, material, group, verts=6)
    for k in range(levels + 1):
        t = k / levels
        y = by + (top_y - by) * t
        w = half_w * (1 - 0.65 * t)
        pts = [(bx - w, y, bz - w), (bx + w, y, bz - w), (bx + w, y, bz + w), (bx - w, y, bz + w), (bx - w, y, bz - w)]
        tube(pts, radius * 0.7, material, group, verts=6)
        if k < levels:
            y2 = by + (top_y - by) * (k + 1) / levels
            w2 = half_w * (1 - 0.65 * (k + 1) / levels)
            tube([(bx - w, y, bz - w), (bx + w2, y2, bz - w2)], radius * 0.6, material, group, verts=6)
            tube([(bx + w, y, bz + w), (bx - w2, y2, bz + w2)], radius * 0.6, material, group, verts=6)
