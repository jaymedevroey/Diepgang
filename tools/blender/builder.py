"""Snelle mesh-bouwer en een bibliotheek van "greebles" (kleine technische details) voor grote
modellen als De Ekster. Zie docs/research/schip-bouwen-in-blender.md.

Waarom: kit.box/cyl maken per onderdeel een Blender-object via bpy.ops; voor duizenden details
is dat te traag. Builder schrijft alles in één bmesh per groep (met materiaalnummers), en de
afschuining komt achteraf als één Bevel-modifier.

Coördinaten in Godot (x rechts, y omhoog, −z = voor), zoals kit.py. Een "vlak" (Patch) is een
rechthoek op een oppervlak: oorsprong, u- en v-richting (langs het vlak) en de normaal (naar buiten).
Detail wordt in clusters gelegd (±30% van het vlak), de rest blijft rustig (70/30-regel).
"""

import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

from kit import G, PARTS, mat


class Builder:
    """Eén mesh in opbouw. Materialen per vlak (paletnamen uit kit.PALETTE)."""

    def __init__(self, name: str):
        self.name = name
        self.bm = bmesh.new()
        self.mats: list[str] = []

    def _mi(self, material: str) -> int:
        if material not in self.mats:
            self.mats.append(material)
        return self.mats.index(material)

    def _verts(self, pts):
        return [self.bm.verts.new(G(*p)) for p in pts]

    def box(self, center, size, u=(1, 0, 0), v=(0, 1, 0), material="Panel"):
        """Doos met halve maten langs u, v en n = u × v (Godot-vectoren)."""
        c = Vector(center)
        U = Vector(u).normalized() * size[0] / 2
        V = Vector(v).normalized() * size[1] / 2
        N = Vector(u).cross(Vector(v)).normalized() * size[2] / 2
        p = [c + sx * U + sy * V + sz * N for sz in (-1, 1) for sy in (-1, 1) for sx in (-1, 1)]
        vs = self._verts(p)
        mi = self._mi(material)
        for f in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)):
            face = self.bm.faces.new([vs[i] for i in f])
            face.material_index = mi
        return self

    def prism(self, profile, start, axis, length, up=(0, 1, 0), material="Panel"):
        """Profiel [(x, y)] in het vlak loodrecht op `axis`, uitgerekt over `length`."""
        A = Vector(axis).normalized()
        Up = Vector(up)
        X = Up.cross(A).normalized()
        Y = A.cross(X).normalized()
        s = Vector(start)
        a = self._verts([s + X * x + Y * y for x, y in profile])
        b = self._verts([s + A * length + X * x + Y * y for x, y in profile])
        mi = self._mi(material)
        n = len(profile)
        faces = [self.bm.faces.new(list(reversed(a))), self.bm.faces.new(b)]
        for i in range(n):
            j = (i + 1) % n
            faces.append(self.bm.faces.new([a[i], a[j], b[j], b[i]]))
        for f in faces:
            f.material_index = mi
        return self

    def cyl(self, start, axis, length, radius, segs=12, material="Steel", r2=None):
        """Cilinder (of kegel met r2) van `start` langs `axis`."""
        A = Vector(axis).normalized()
        ref = Vector((0, 1, 0)) if abs(A.y) < 0.9 else Vector((1, 0, 0))
        X = ref.cross(A).normalized()
        Y = A.cross(X).normalized()
        s = Vector(start)
        r_end = radius if r2 is None else r2
        a = self._verts([s + (X * math.cos(t) + Y * math.sin(t)) * radius for t in (2 * math.pi * k / segs for k in range(segs))])
        b = self._verts([s + A * length + (X * math.cos(t) + Y * math.sin(t)) * r_end for t in (2 * math.pi * k / segs for k in range(segs))])
        mi = self._mi(material)
        faces = [self.bm.faces.new(list(reversed(a))), self.bm.faces.new(b)]
        for i in range(segs):
            j = (i + 1) % segs
            faces.append(self.bm.faces.new([a[i], a[j], b[j], b[i]]))
        for f in faces:
            f.material_index = mi
        return self

    def pipe(self, points, radius, segs=8, material="Steel", clamps=0.0):
        """Leiding langs punten (rechte stukken met een bol in elke knik); klemmen om de `clamps` m."""
        for p0, p1 in zip(points, points[1:]):
            d = Vector(p1) - Vector(p0)
            self.cyl(p0, d, d.length, radius, segs, material)
            if clamps > 0:
                k = int(d.length / clamps)
                for i in range(1, k):
                    c = Vector(p0) + d * (i / k)
                    self.cyl(c - d.normalized() * 0.06, d, 0.12, radius * 1.45, segs, "DarkSteel")
        for p in points[1:-1]:
            self.cyl(Vector(p) - Vector((0, radius, 0)), (0, 1, 0), radius * 2, radius * 1.15, segs, material)
        return self

    def to_object(self, group: str, bevel=0.0, segments=1, angle=40.0):
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        o = bpy.data.objects.new(self.name, me)
        bpy.context.collection.objects.link(o)
        for m in self.mats:
            o.data.materials.append(mat(m))
        if bevel > 0:
            b = o.modifiers.new("Bevel", "BEVEL")
            b.width = bevel
            b.segments = segments
            b.limit_method = "ANGLE"
            b.angle_limit = math.radians(angle)
            b.use_clamp_overlap = True
        for p in o.data.polygons:
            p.use_smooth = False
        PARTS.setdefault(group, []).append(o)
        return o


class Patch:
    """Rechthoek op een oppervlak: oorsprong (een hoek), u- en v-richting met lengtes, normaal naar buiten."""

    def __init__(self, origin, u, v, size_u, size_v, normal=None):
        self.o = Vector(origin)
        self.u = Vector(u).normalized()
        self.v = Vector(v).normalized()
        self.n = Vector(normal).normalized() if normal else self.u.cross(self.v).normalized()
        self.su = size_u
        self.sv = size_v

    def at(self, a, b, h=0.0):
        return self.o + self.u * a + self.v * b + self.n * h


# --- Greebles -----------------------------------------------------------------------------

def panels(b: Builder, p: Patch, rng: random.Random, cell=(4.0, 2.5), lift=0.08, gap=0.12, material="Panel",
           alt=None, alt_chance=0.12, thick=0.12):
    """Gelaagde platen op een vlak: een raster met ongelijke stroken (70/30), elke plaat iets
    opgetild, af en toe een plaat in een andere kleur (vervangen, van een andere firma)."""
    us = _splits(p.su, cell[0], rng)
    vs = _splits(p.sv, cell[1], rng)
    for (u0, u1) in us:
        for (v0, v1) in vs:
            m = material
            if isinstance(alt, list):  # [(materiaal, kans), ...]
                r = rng.random()
                for name, chance in alt:
                    if r < chance:
                        m = name
                        break
                    r -= chance
            elif alt and rng.random() < alt_chance:
                m = alt
            h = lift + (0.05 if rng.random() < 0.25 else 0.0)
            c = p.at((u0 + u1) / 2, (v0 + v1) / 2, h - thick / 2)
            b.box(c, (u1 - u0 - gap, v1 - v0 - gap, thick), p.u, p.v, m)


def _splits(total, cell, rng):
    """Deel een lengte in stroken rond `cell`, ongelijk (soms 1/3 – 2/3)."""
    n = max(1, round(total / cell))
    cuts = [0.0]
    for i in range(1, n):
        cuts.append(total * i / n + rng.uniform(-0.18, 0.18) * total / n)
    cuts.append(total)
    return list(zip(cuts, cuts[1:]))


def ribs(b: Builder, p: Patch, spacing=3.0, depth=0.5, width=0.4, material="DarkSteel"):
    """Spanten dwars over een vlak (ritme)."""
    k = int(p.su / spacing)
    for i in range(1, k):
        c = p.at(i * p.su / k, p.sv / 2, depth / 2)
        b.box(c, (width, p.sv, depth), p.u, p.v, material)


def vent(b: Builder, p: Patch, a, bb, w, h, slats=6, material="DarkSteel"):
    """Rooster: een kader met lamellen."""
    b.box(p.at(a, bb, 0.06), (w, h, 0.12), p.u, p.v, "Anthracite")
    for i in range(slats):
        y = bb - h / 2 + (i + 0.5) * h / slats
        b.box(p.at(a, y, 0.16), (w * 0.9, h / slats * 0.45, 0.1), p.u, p.v, material)


def cluster(b: Builder, p: Patch, rng: random.Random, a, bb, w, h, density=1.0):
    """Een cluster technisch detail in een rechthoek (a, bb = midden): dozen in lagen, tanks
    langs u, leidingen met klemmen, een rooster. Het meeste ligt langs u (de lengterichting)."""
    lo_u, lo_v = a - w / 2, bb - h / 2
    # Basisplaat.
    b.box(p.at(a, bb, 0.1), (w, h, 0.2), p.u, p.v, "DarkSteel")
    count = int(6 * density * (w * h) / 12.0) + 3
    for _ in range(count):
        kind = rng.random()
        cu = lo_u + rng.uniform(0.1, 0.9) * w
        cv = lo_v + rng.uniform(0.1, 0.9) * h
        if kind < 0.45:  # dozen, soms gestapeld
            sw = rng.uniform(0.6, 2.4)
            sh = rng.uniform(0.4, 1.4)
            sd = rng.uniform(0.3, 1.2)
            m = rng.choice(["Anthracite", "DarkSteel", "Panel", "Panel", "Cream"])
            b.box(p.at(cu, cv, 0.2 + sd / 2), (sw, sh, sd), p.u, p.v, m)
            if rng.random() < 0.35:
                b.box(p.at(cu + rng.uniform(-0.2, 0.2), cv, 0.2 + sd + sd * 0.3), (sw * 0.6, sh * 0.7, sd * 0.6), p.u, p.v, "DarkSteel")
        elif kind < 0.65:  # tank langs u
            r = rng.uniform(0.25, 0.6)
            ln = rng.uniform(1.2, min(4.0, w))
            b.cyl(p.at(cu - ln / 2, cv, 0.2 + r), p.u, ln, r, 12, rng.choice(["Steel", "Panel", "Yellow"]))
        elif kind < 0.85:  # leiding langs u met een knik naar beneden
            r = rng.uniform(0.06, 0.16)
            ln = rng.uniform(1.5, w)
            hh = 0.2 + rng.uniform(0.2, 0.6)
            p0 = p.at(max(lo_u, cu - ln / 2), cv, hh)
            p1 = p.at(min(lo_u + w, cu + ln / 2), cv, hh)
            b.pipe([p0, p1], r, 8, rng.choice(["Steel", "Copper", "DarkSteel"]), clamps=0.8)
        else:
            vent(b, p, cu, cv, rng.uniform(0.8, 1.6), rng.uniform(0.5, 1.0), 5)


def pipe_run(b: Builder, p: Patch, rng: random.Random, v_pos, count=3, radius=0.18, h=0.35, material="Steel"):
    """Bundel evenwijdige leidingen over de hele lengte van een vlak (langs u), met klemmen."""
    for i in range(count):
        r = radius * rng.uniform(0.6, 1.0)
        vv = v_pos + i * radius * 2.6
        b.pipe([p.at(0.2, vv, h + i * 0.04), p.at(p.su - 0.2, vv, h + i * 0.04)], r, 8,
               material if i % 3 else "Copper", clamps=1.6)


def lights_row(b: Builder, p: Patch, v_pos, spacing=4.0, size=0.25, material="Lens"):
    """Rij lampjes (navigatie, schaal)."""
    k = int(p.su / spacing)
    for i in range(k + 1):
        b.box(p.at(i * p.su / max(k, 1), v_pos, 0.15), (size, size, 0.2), p.u, p.v, material)


def windows(b: Builder, p: Patch, v_pos, spacing=1.6, w=0.7, h=0.9, material="Cyan"):
    """Rij kleine ramen (schaal: ±0,7 × 0,9 m) met een donker kader."""
    k = int(p.su / spacing)
    for i in range(k):
        c = (i + 0.5) * p.su / k
        b.box(p.at(c, v_pos, 0.05), (w + 0.25, h + 0.25, 0.1), p.u, p.v, "Anthracite")
        b.box(p.at(c, v_pos, 0.1), (w, h, 0.08), p.u, p.v, material)


def hazard_frame(b: Builder, p: Patch, a, bb, w, h, t=0.5):
    """Geel-zwarte rand rond een opening (luik, baai)."""
    for (cu, cv, sw, sh) in ((a, bb - h / 2 - t / 2, w + 2 * t, t), (a, bb + h / 2 + t / 2, w + 2 * t, t),
                             (a - w / 2 - t / 2, bb, t, h), (a + w / 2 + t / 2, bb, t, h)):
        b.box(p.at(cu, cv, 0.08), (sw, sh, 0.16), p.u, p.v, "Hazard")
