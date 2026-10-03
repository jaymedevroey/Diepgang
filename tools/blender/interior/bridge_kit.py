"""Hulpfuncties voor de brug en de gang (zone_bridge.py): profielen, ringen, doeken, tekst.

Alle posities in PLANcoördinaten (x, y, z) zoals layout.py; richtingen (assen, normalen) zijn in
plan en Godot gelijk. Alles komt in een Builder (één mesh per groep), niet in losse objecten.
Hoek θ rond een verticale as: 0 = naar het raam (−z), 90° = naar stuurboord (+x).
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

import kit
from layout import G


def V(x, y, z):
    """Plan → Blender."""
    return kit.G(*G(x, y, z))


def _faces(b, faces, material, recalc=True):
    if recalc:
        bmesh.ops.recalc_face_normals(b.bm, faces=faces)
    mi = b._mi(material)
    for f in faces:
        f.material_index = mi
    return faces


def box(b, c, size, material, u=(1, 0, 0), v=(0, 1, 0)):
    """Doos rond plekpunt c, maten langs u, v en u × v."""
    b.box(G(*c), size, u, v, material)


def tbox(b, a, c, w, h, material, up=(0, 1, 0)):
    """Balk van punt a naar punt c (plan), doorsnede w × h (h langs `up`)."""
    A, C = Vector(a), Vector(c)
    d = C - A
    U = Vector(up)
    U = (U - d.normalized() * U.dot(d.normalized())).normalized()
    b.box(G(*((A + C) / 2)), (d.length, h, w), d, U, material)


def vprism(b, pts, y0, y1, material):
    """Verticaal geëxtrudeerde veelhoek [(x, z)] tussen y0 en y1."""
    lo = [b.bm.verts.new(V(x, y0, z)) for x, z in pts]
    hi = [b.bm.verts.new(V(x, y1, z)) for x, z in pts]
    area = sum(p.co.x * q.co.y - q.co.x * p.co.y for p, q in zip(hi, hi[1:] + hi[:1]))
    if area < 0:
        lo.reverse()
        hi.reverse()
    n = len(pts)
    faces = [b.bm.faces.new(hi), b.bm.faces.new(list(reversed(lo)))]
    for i in range(n):
        j = (i + 1) % n
        faces.append(b.bm.faces.new([lo[i], lo[j], hi[j], hi[i]]))
    return _faces(b, faces, material, recalc=False)


def prism(b, profile, start, axis, length, material, up=(0, 1, 0)):
    """Profiel [(px, py)] (px = up × as, py = up), uitgerekt van `start` (plan) langs `axis`."""
    area = sum(p[0] * q[1] - q[0] * p[1] for p, q in zip(profile, profile[1:] + profile[:1]))
    if area < 0:
        profile = list(reversed(profile))
    b.prism(profile, G(*start), axis, length, up, material)


def revolve(b, center, profile, segs, material, a0=0.0, a1=2 * math.pi, axis=(0, 1, 0), ref=(0, 0, -1)):
    """Gesloten profiel [(r, h)] gedraaid rond een as door `center` (plan), van hoek a0 tot a1.
    Hoek 0 ligt in richting `ref`; h loopt langs `axis`."""
    C = Vector(G(*center))
    A = Vector(axis).normalized()
    R = Vector(ref)
    R = R - A * R.dot(A)
    if R.length < 1e-6:
        R = A.cross(Vector((1, 0, 0))) if abs(A.x) < 0.9 else A.cross(Vector((0, 0, 1)))
    R.normalize()
    S = R.cross(A).normalized()
    full = abs((a1 - a0) - 2 * math.pi) < 1e-6
    n = segs if full else segs + 1
    rings = []
    for k in range(n):
        t = a0 + (a1 - a0) * k / segs
        d = R * math.cos(t) + S * math.sin(t)
        rings.append([b.bm.verts.new(kit.G(*(C + A * h + d * r))) for r, h in profile])
    m = len(profile)
    faces = []
    for k in range(segs):
        r0, r1 = rings[k], rings[(k + 1) % n]
        for i in range(m):
            j = (i + 1) % m
            faces.append(b.bm.faces.new([r0[i], r0[j], r1[j], r1[i]]))
    if not full:
        faces.append(b.bm.faces.new(rings[0]))
        faces.append(b.bm.faces.new(list(reversed(rings[-1]))))
    return _faces(b, faces, material)


def ring_point(center, axis, radius, t, ref=(0, 0, -1)):
    """Punt op een cirkel rond `axis` (zelfde hoekafspraak als revolve), in plan."""
    A = Vector(axis).normalized()
    R = Vector(ref)
    R = (R - A * R.dot(A)).normalized()
    S = R.cross(A).normalized()
    return tuple(Vector(center) + (R * math.cos(t) + S * math.sin(t)) * radius)


def ring(b, center, r0, r1, y0, y1, segs, material, a0=0.0, a1=2 * math.pi):
    """Platte ring (of ringstuk) rond een verticale as, tussen y0 en y1."""
    cx, _, cz = center
    return revolve(b, (cx, 0.0, cz), [(r0, y0), (r1, y0), (r1, y1), (r0, y1)], segs, material, a0, a1)


def band(b, center, radius, width, thick, segs, material, axis=(0, 1, 0), ref=(0, 0, -1)):
    """Dunne ring (hologramlijn) in het vlak loodrecht op `axis`."""
    return revolve(b, center, [(radius - thick / 2, -width / 2), (radius + thick / 2, -width / 2),
                               (radius + thick / 2, width / 2), (radius - thick / 2, width / 2)],
                   segs, material, axis=axis, ref=ref)


def cone_open(b, base, axis, length, r0, r1, segs, material):
    """Open kegelmantel zonder deksels (lichtbundel), normalen naar buiten."""
    A = Vector(axis).normalized()
    ref = Vector((0, 1, 0)) if abs(A.y) < 0.9 else Vector((1, 0, 0))
    X = ref.cross(A).normalized()
    Y = A.cross(X).normalized()
    s = Vector(G(*base))
    lo = [b.bm.verts.new(kit.G(*(s + (X * math.cos(t) + Y * math.sin(t)) * r0))) for t in
          (2 * math.pi * k / segs for k in range(segs))]
    hi = [b.bm.verts.new(kit.G(*(s + A * length + (X * math.cos(t) + Y * math.sin(t)) * r1))) for t in
          (2 * math.pi * k / segs for k in range(segs))]
    faces = [b.bm.faces.new([lo[i], lo[(i + 1) % segs], hi[(i + 1) % segs], hi[i]]) for i in range(segs)]
    return _faces(b, faces, material, recalc=False)


def circle_pts(cx, cz, r, segs, zmin=None, zmax=None, a0=0.0):
    """Punten op een cirkel (plan x, z), eventueel afgesneden door z ≥ zmin en z ≤ zmax."""
    pts = [(cx + r * math.sin(a0 + 2 * math.pi * k / segs), cz - r * math.cos(a0 + 2 * math.pi * k / segs))
           for k in range(segs)]
    if zmin is not None:
        pts = clip(pts, lambda p: p[1] - zmin)
    if zmax is not None:
        pts = clip(pts, lambda p: zmax - p[1])
    return pts


def clip(pts, f):
    """Sutherland-Hodgman: houd het deel waar f(p) ≥ 0."""
    out = []
    n = len(pts)
    for i in range(n):
        p, q = pts[i], pts[(i + 1) % n]
        fp, fq = f(p), f(q)
        if fp >= 0:
            out.append(p)
        if (fp >= 0) != (fq >= 0):
            t = fp / (fp - fq)
            out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
    return out


def arcs_inside(cz, r, zmin, zmax):
    """Hoekbereiken (θ0, θ1) van een cirkel rond z = cz die tussen zmin en zmax liggen."""
    hi = (cz - zmin) / r  # cos θ ≤ hi
    lo = (cz - zmax) / r  # cos θ ≥ lo
    a_hi = 0.0 if hi >= 1 else math.acos(max(-1.0, hi))
    a_lo = math.pi if lo <= -1 else math.acos(min(1.0, lo))
    if a_hi == 0.0 and a_lo == math.pi:
        return [(0.0, 2 * math.pi)]
    if a_hi == 0.0:
        return [(-a_lo, a_lo)]
    if a_lo == math.pi:
        return [(a_hi, 2 * math.pi - a_hi)]
    return [(a_hi, a_lo), (2 * math.pi - a_lo, 2 * math.pi - a_hi)]


def sphere(b, center, r, material, subdiv=2):
    ret = bmesh.ops.create_icosphere(b.bm, subdivisions=subdiv, radius=r,
                                     matrix=Matrix.Translation(V(*center)), calc_uvs=False)
    faces = list({f for v in ret["verts"] for f in v.link_faces})
    return _faces(b, faces, material, recalc=False)


def diamond(b, center, r, h, material):
    """Ruitvormige markering (twee piramides op elkaar)."""
    cx, cy, cz = center
    mid = [b.bm.verts.new(V(cx + r * math.sin(a), cy, cz - r * math.cos(a)))
           for a in (0, math.pi / 2, math.pi, 3 * math.pi / 2)]
    top = b.bm.verts.new(V(cx, cy + h, cz))
    bot = b.bm.verts.new(V(cx, cy - h, cz))
    faces = []
    for i in range(4):
        j = (i + 1) % 4
        faces.append(b.bm.faces.new([mid[i], mid[j], top]))
        faces.append(b.bm.faces.new([mid[j], mid[i], bot]))
    return _faces(b, faces, material)


def cloth(b, cols, y_top, rows, thick, material_at, normal=(0, 0, -1)):
    """Doek (banier): kolommen [(x, z, y_onder)], rijen als fracties van boven (0) naar onder (1).
    material_at(rij, kolom) kiest het materiaal per vak. Dikte langs −normal."""
    N = Vector(normal).normalized()
    front, back = [], []
    for (x, z, yb) in cols:
        f_col, b_col = [], []
        for t in rows:
            y = y_top + (yb - y_top) * t
            p = Vector((x, y, z))
            f_col.append(b.bm.verts.new(V(*p)))
            b_col.append(b.bm.verts.new(V(*(p - N * thick))))
        front.append(f_col)
        back.append(b_col)
    nc, nr = len(cols), len(rows)
    groups = {}
    for i in range(nc - 1):
        for j in range(nr - 1):
            m = material_at(j, i)
            groups.setdefault(m, []).append(b.bm.faces.new([front[i][j], front[i + 1][j], front[i + 1][j + 1], front[i][j + 1]]))
            groups.setdefault("_back", []).append(b.bm.faces.new([back[i][j + 1], back[i + 1][j + 1], back[i + 1][j], back[i][j]]))
    edge = []
    for i in range(nc - 1):  # boven en onder
        edge.append(b.bm.faces.new([front[i][0], back[i][0], back[i + 1][0], front[i + 1][0]]))
        edge.append(b.bm.faces.new([front[i + 1][-1], back[i + 1][-1], back[i][-1], front[i][-1]]))
    for j in range(nr - 1):  # zijkanten
        edge.append(b.bm.faces.new([front[0][j + 1], back[0][j + 1], back[0][j], front[0][j]]))
        edge.append(b.bm.faces.new([front[-1][j], back[-1][j], back[-1][j + 1], front[-1][j + 1]]))
    allf = [f for fs in groups.values() for f in fs] + edge
    bmesh.ops.recalc_face_normals(b.bm, faces=allf)
    for m, fs in groups.items():
        mi = b._mi(material_at(0, 0) if m == "_back" else m)
        for f in fs:
            f.material_index = mi
    mi = b._mi(material_at(0, 0))
    for f in edge:
        f.material_index = mi


def text(b, body, size, pos, normal, material, up=(0, 1, 0), align="CENTER", extrude=0.0, res=2, spacing=1.0):
    """Tekst als mesh in een Builder: midden op `pos` (plan), leesbaar vanaf de kant van `normal`."""
    cu = bpy.data.curves.new("txt", "FONT")
    cu.body = body
    cu.size = size
    cu.extrude = extrude
    cu.align_x = align
    cu.align_y = "CENTER"
    cu.resolution_u = res
    cu.space_character = spacing
    o = bpy.data.objects.new("txt", cu)
    bpy.context.collection.objects.link(o)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    N = Vector(normal).normalized()
    U = Vector(up)
    U = (U - N * U.dot(N)).normalized()
    R = (-N).cross(U)
    P0 = Vector(G(*pos))
    vs = [b.bm.verts.new(kit.G(*(P0 + R * v.co.x + U * v.co.y + N * v.co.z))) for v in me.vertices]
    mi = b._mi(material)
    for p in me.polygons:
        try:
            f = b.bm.faces.new([vs[i] for i in p.vertices])
            f.material_index = mi
        except ValueError:
            pass
    bpy.data.objects.remove(o)
    bpy.data.curves.remove(cu)
    bpy.data.meshes.remove(me)


def plate_grid(b, x0, x1, z0, z1, y, cell_x, cell_z, material, gap=0.025, thick=0.03, skip=None, alt=None, worn=None):
    """Vloerplaten (bovenkant op y) in een raster met naden. `skip(cx, cz)` laat platen weg;
    `worn(cx, cz)` = True: een gesleten plaat (FloorWorn) op een looppad."""
    nx = max(1, round((x1 - x0) / cell_x))
    nz = max(1, round((z1 - z0) / cell_z))
    for i in range(nx):
        for j in range(nz):
            a0 = x0 + (x1 - x0) * i / nx
            a1 = x0 + (x1 - x0) * (i + 1) / nx
            c0 = z0 + (z1 - z0) * j / nz
            c1 = z0 + (z1 - z0) * (j + 1) / nz
            cx, cz = (a0 + a1) / 2, (c0 + c1) / 2
            if skip and skip(cx, cz):
                continue
            m = material
            if alt and alt(i, j):
                m = alt(i, j)
            if worn and worn(cx, cz):
                m = "FloorWorn"
            box(b, (cx, y - thick / 2, cz), (a1 - a0 - gap, thick, c1 - c0 - gap), m)


def grating(b, x0, x1, z0, z1, y, along="x", pitch=0.07, bar=0.025, material="DarkSteel", frame="DarkSteel"):
    """Rooster: staven langs x of z met een kader, bovenkant op y (de put eronder is donker)."""
    if along == "x":
        n = int((z1 - z0) / pitch)
        for k in range(n):
            z = z0 + (k + 0.5) * (z1 - z0) / n
            box(b, ((x0 + x1) / 2, y - 0.02, z), (x1 - x0, 0.04, bar), material)
        for x in (x0 + 0.02, x1 - 0.02):
            box(b, (x, y - 0.025, (z0 + z1) / 2), (0.04, 0.05, z1 - z0), frame)
        k = int((x1 - x0) / 1.0)
        for i in range(1, k):
            box(b, (x0 + i * (x1 - x0) / k, y - 0.03, (z0 + z1) / 2), (0.03, 0.04, z1 - z0), frame)
    else:
        n = int((x1 - x0) / pitch)
        for k in range(n):
            x = x0 + (k + 0.5) * (x1 - x0) / n
            box(b, (x, y - 0.02, (z0 + z1) / 2), (bar, 0.04, z1 - z0), material)
        for z in (z0 + 0.02, z1 - 0.02):
            box(b, ((x0 + x1) / 2, y - 0.025, z), (x1 - x0, 0.05, 0.04), frame)
        k = int((z1 - z0) / 1.0)
        for i in range(1, k):
            box(b, ((x0 + x1) / 2, y - 0.03, z0 + i * (z1 - z0) / k), (x1 - x0, 0.04, 0.03), frame)


def oct_profile(w, h, ch):
    """Afgeschuinde rechthoek rond (0, 0)."""
    return kit.octagon(w, h, ch)


def beam(b, a, c, w, h, ch, material, up=(0, 1, 0)):
    """Afgeschuinde balk (achtkantig profiel) van a naar c (plan)."""
    A, C = Vector(a), Vector(c)
    d = C - A
    prism(b, oct_profile(w, h, ch), tuple(A), tuple(d.normalized()), d.length, material, up)
