"""Hulpmiddelen voor de zone WERKDEK + LAADREK (zone_workdeck.py): eigen materialen, vormen in
plancoördinaten (afgeschuinde platen, balken, profielen), tekst als mesh (Bungee) en bordjes.

Alle posities en richtingen in PLANcoördinaten (zie layout.py): x 0..20, y omhoog, z 0..44. Het plan
en Godot verschillen enkel in een verschuiving, dus richtingen zijn gelijk.
"""

import math
from pathlib import Path

import bpy
from mathutils import Vector

import kit
from layout import G

REPO = Path(__file__).resolve().parents[3]
FONTS = {
    "bungee": REPO / "game/assets/fonts/Bungee-Regular.ttf",
}
# Hoogte van een hoofdletter bij grootte 1 (gemeten in Blender 5.2).
CAP = {"bungee": 0.282}

# Nieuwe materialen (naam: kleur, metallic, roughness, emissie). Godot kent ze nog niet: daar komt
# het materiaal uit de glb (StandardMaterial3D) tot ze in MolVisual.MATS / EMISSIVE staan.
MATERIALS = {
    "DuctTape": ((0.52, 0.53, 0.55), 0.25, 0.45, None),
    "Cardboard": ((0.56, 0.42, 0.27), 0.0, 0.85, None),
    "ScreenAmber": ((1.0, 0.62, 0.2), 0.0, 0.3, ((1.0, 0.58, 0.16), 1.2)),
    "ScreenCyan": ((0.35, 0.86, 0.95), 0.0, 0.3, ((0.3, 0.84, 0.95), 1.2)),
    "LedGreen": ((0.35, 1.0, 0.5), 0.0, 0.3, ((0.3, 1.0, 0.45), 2.0)),
    "LedCyanSoft": ((0.4, 0.86, 0.95), 0.0, 0.3, ((0.35, 0.85, 0.95), 1.0)),
    # Statusrand van de laadcapsules: even fel als LedCyanSoft (LedAmber bloeit te hard op 1 m).
    "LedAmberSoft": ((1.0, 0.66, 0.32), 0.0, 0.3, ((1.0, 0.6, 0.26), 0.55)),
    "LedRedSoft": ((1.0, 0.25, 0.15), 0.0, 0.3, ((1.0, 0.18, 0.1), 0.7)),
}
kit.PALETTE.update(MATERIALS)


def V(p):
    """Plan → Godot als Vector."""
    return Vector(G(*p))


# --- Basisvormen ---------------------------------------------------------------------------------

def box(b, c, size, u=(1, 0, 0), v=(0, 1, 0), m="Anthracite"):
    """Doos rond plancentrum c: size langs u, v en u × v."""
    b.box(G(*c), size, u, v, m)


def blk(b, x0, x1, y0, y1, z0, z1, m):
    b.box(G((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)), material=m)


def cyl(b, p, axis, length, r, segs=10, m="Steel", r2=None):
    b.cyl(G(*p), axis, length, r, segs, m, r2)


def pipe(b, pts, r, segs=8, m="Steel", clamps=0.0):
    b.pipe([G(*p) for p in pts], r, segs, m, clamps)


def beam(b, p0, p1, w, h, m="Anthracite", up=(0, 1, 0)):
    """Rechte balk tussen twee planpunten; doorsnede w (opzij) × h (langs `up`)."""
    a, c = Vector(p0), Vector(p1)
    d = c - a
    upv = Vector(up)
    side = d.cross(upv)
    if side.length < 1e-6:
        side = d.cross(Vector((1, 0, 0)))
    vv = side.cross(d).normalized()
    b.box(G(*((a + c) / 2)), (d.length, h, w), tuple(d.normalized()), tuple(vv), m)


def faces_from(b, rings, m, caps=(True, True)):
    """Verbind ringen van Godot-punten (elk dezelfde lengte, tegen de klok gezien vanaf het einde)."""
    mi = b._mi(m)
    vs = [[b.bm.verts.new(kit.G(*p)) for p in ring] for ring in rings]
    n = len(rings[0])
    out = []
    for r0, r1 in zip(vs, vs[1:]):
        for i in range(n):
            j = (i + 1) % n
            out.append(b.bm.faces.new([r0[i], r0[j], r1[j], r1[i]]))
    if caps[0]:
        out.append(b.bm.faces.new(list(reversed(vs[0]))))
    if caps[1]:
        out.append(b.bm.faces.new(vs[-1]))
    for f in out:
        f.material_index = mi
    return out


def frustum(b, back, front, m, cap_back=False):
    """Afgeschuinde plaat: `back` en `front` zijn even lange lijsten planpunten, tegen de klok gezien
    van voor (buiten). Vlakken: voorkant en zijkanten (achterkant optioneel)."""
    mi = b._mi(m)
    B = [b.bm.verts.new(kit.G(*G(*p))) for p in back]
    F = [b.bm.verts.new(kit.G(*G(*p))) for p in front]
    n = len(B)
    fs = [b.bm.faces.new(F)]
    for i in range(n):
        j = (i + 1) % n
        fs.append(b.bm.faces.new([B[i], B[j], F[j], F[i]]))
    if cap_back:
        fs.append(b.bm.faces.new(list(reversed(B))))
    for f in fs:
        f.material_index = mi


def orient(pts, normal):
    """Zet een veelhoek (planpunten) tegen de klok rond `normal` (Newell)."""
    n = Vector((0.0, 0.0, 0.0))
    for i in range(len(pts)):
        a, c = Vector(pts[i]), Vector(pts[(i + 1) % len(pts)])
        n += Vector(((a.y - c.y) * (a.z + c.z), (a.z - c.z) * (a.x + c.x), (a.x - c.x) * (a.y + c.y)))
    return list(pts) if n.dot(Vector(normal)) >= 0 else list(reversed(pts))


def slab_poly(b, pts_xz, y0, y1, m, inset=0.0):
    """Plaat met een veelhoekige voetafdruk (punten (x, z)) van y0 tot y1, bovenrand afgeschuind."""
    base = orient([(x, y0, z) for x, z in pts_xz], (0, 1, 0))
    cx = sum(p[0] for p in base) / len(base)
    cz = sum(p[2] for p in base) / len(base)
    top = []
    for x, _, z in base:
        dx, dz = cx - x, cz - z
        d = math.hypot(dx, dz) or 1.0
        top.append((x + dx / d * inset, y1, z + dz / d * inset))
    frustum(b, base, top, m, cap_back=True)


def wall_seg(b, p, q, y0, y1, t, m):
    """Verticaal paneel (dikte t) tussen twee punten (x, z) op de vloer."""
    d = Vector((q[0] - p[0], 0, q[1] - p[1]))
    c = ((p[0] + q[0]) / 2, (y0 + y1) / 2, (p[1] + q[1]) / 2)
    b.box(G(*c), (d.length, y1 - y0, t), tuple(d.normalized()), (0, 1, 0), m)


class Face:
    """Een vlak in het plan: oorsprong (een hoek), u (langs), v (omhoog/langs) en normaal n = u × v."""

    def __init__(self, origin, u, v):
        self.o = Vector(origin)
        self.u = Vector(u).normalized()
        self.v = Vector(v).normalized()
        self.n = self.u.cross(self.v).normalized()

    def at(self, a, c, h=0.0):
        return tuple(self.o + self.u * a + self.v * c + self.n * h)

    def plate(self, b, a0, a1, c0, c1, h0, h1, ch, m, cap_back=False):
        """Afgeschuinde plaat van h0 tot h1 boven het vlak (ch = schuine rand)."""
        back = [self.at(a0, c0, h0), self.at(a1, c0, h0), self.at(a1, c1, h0), self.at(a0, c1, h0)]
        front = [self.at(a0 + ch, c0 + ch, h1), self.at(a1 - ch, c0 + ch, h1), self.at(a1 - ch, c1 - ch, h1),
                 self.at(a0 + ch, c1 - ch, h1)]
        frustum(b, back, front, m, cap_back)

    def box(self, b, a, c, h, size, m):
        """Doos met het midden op (a, c) en de achterkant op hoogte h: size = (langs u, langs v, dikte)."""
        b.box(G(*self.at(a, c, h + size[2] / 2)), size, tuple(self.u), tuple(self.v), m)

    def tilted(self, b, a, c, h, size, ang, m):
        """Doos gedraaid om de normaal (graden), voor scheve bordjes en tape."""
        r = math.radians(ang)
        u = self.u * math.cos(r) + self.v * math.sin(r)
        v = -self.u * math.sin(r) + self.v * math.cos(r)
        b.box(G(*self.at(a, c, h + size[2] / 2)), size, tuple(u), tuple(v), m)


def chamfer_profile(w, h, ch):
    """Achthoekig profiel (w × h, schuine hoeken ch), gecentreerd, tegen de klok."""
    hw, hh = w / 2, h / 2
    return [(-hw + ch, -hh), (hw - ch, -hh), (hw, -hh + ch), (hw, hh - ch), (hw - ch, hh), (-hw + ch, hh),
            (-hw, hh - ch), (-hw, -hh + ch)]


def profile_beam(b, p0, p1, profile, m, up=(0, 1, 0)):
    """Balk met een eigen doorsnede (lijst (x, y), tegen de klok) tussen twee planpunten."""
    a = Vector(G(*p0))
    d = Vector(G(*p1)) - a
    b.prism(profile, tuple(a), tuple(d), d.length, up, m)


def torus(b, c, axis, R, r, seg=16, ring=6, m="Rubber"):
    """Ring (rol touw, kabel) rond plancentrum c met as `axis`."""
    A = Vector(axis).normalized()
    ref = Vector((0, 1, 0)) if abs(A.y) < 0.9 else Vector((1, 0, 0))
    X = ref.cross(A).normalized()
    Y = A.cross(X).normalized()
    cc = V(c)
    rings = []
    for i in range(seg + 1):
        t = 2 * math.pi * i / seg
        radial = X * math.cos(t) + Y * math.sin(t)
        center = cc + radial * R
        rings.append([tuple(center + (radial * math.cos(s) + A * math.sin(s)) * r)
                      for s in (2 * math.pi * k / ring for k in range(ring))])
    faces_from(b, rings, m, caps=(False, False))


def cable(b, p0, p1, sag, r=0.025, n=8, m="Rubber", segs=6):
    """Doorhangende kabel tussen twee planpunten."""
    a, c = Vector(p0), Vector(p1)
    pts = []
    for i in range(n + 1):
        t = i / n
        p = a.lerp(c, t)
        p.y -= sag * 4 * t * (1 - t)
        pts.append(tuple(p))
    for q0, q1 in zip(pts, pts[1:]):
        d = Vector(q1) - Vector(q0)
        b.cyl(G(*q0), tuple(d), d.length + r * 0.6, r, segs, m)


# --- Tekst ---------------------------------------------------------------------------------------

_FONT_CACHE = {}


def _font(name):
    f = _FONT_CACHE.get(name)
    try:
        if f is not None:
            f.name  # noqa: B018  (ReferenceError na een nieuwe scène)
            return f
    except ReferenceError:
        pass
    f = bpy.data.fonts.load(str(FONTS[name]))
    _FONT_CACHE[name] = f
    return f


def text(b, body, height, pos, normal, m="DecalDark", up=(0, 1, 0), align="CENTER", font="bungee",
         lift=0.004, max_w=None, spacing=1.0, tilt=0.0):
    """Platte tekst (één regel) als mesh in Builder `b`. `height` = hoogte van een hoofdletter,
    `pos` = midden van de regel (plan), `normal` = waar de tekst naar kijkt, `up` = boven in de
    tekst. align LEFT/CENTER/RIGHT t.o.v. pos. max_w: smaller maken als de regel breder is.
    tilt: graden gedraaid om de normaal. Geeft de breedte terug."""
    cu = bpy.data.curves.new("wd_text", "FONT")
    cu.body = body
    cu.font = _font(font)
    cu.size = 1.0
    cu.resolution_u = 2
    cu.space_character = spacing
    o = bpy.data.objects.new("wd_text", cu)
    bpy.context.collection.objects.link(o)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.curves.remove(cu)
    if not me.vertices:
        bpy.data.meshes.remove(me)
        return 0.0
    xs = [v.co.x for v in me.vertices]
    x0, x1 = min(xs), max(xs)
    s = height / CAP[font]
    width = (x1 - x0) * s
    if max_w and width > max_w:
        s *= max_w / width
        width = max_w
    n = Vector(normal).normalized()
    upv = Vector(up)
    upv = (upv - n * upv.dot(n)).normalized()
    right = upv.cross(n).normalized()
    if tilt:
        r = math.radians(tilt)
        right, upv = right * math.cos(r) + upv * math.sin(r), -right * math.sin(r) + upv * math.cos(r)
    if align == "CENTER":
        ox = -(x0 + x1) / 2
    elif align == "LEFT":
        ox = -x0
    else:
        ox = -x1
    oy = -CAP[font] / 2
    c = Vector(pos) + n * lift
    mi = b._mi(m)
    vs = [b.bm.verts.new(kit.G(*G(*(c + right * ((v.co.x + ox) * s) + upv * ((v.co.y + oy) * s)))))
          for v in me.vertices]
    for p in me.polygons:
        try:
            f = b.bm.faces.new([vs[i] for i in p.vertices])
            f.material_index = mi
        except ValueError:
            pass
    bpy.data.meshes.remove(me)
    return width


def lines(b, rows, pos, normal, m="DecalDark", up=(0, 1, 0), gap=0.45, max_w=None, tilt=0.0, align="CENTER"):
    """Meerdere regels [(tekst, hoogte), ...] onder elkaar, het blok gecentreerd op pos."""
    n = Vector(normal).normalized()
    upv = Vector(up)
    upv = (upv - n * upv.dot(n)).normalized()
    if tilt:
        right = upv.cross(n).normalized()
        r = math.radians(tilt)
        upv = -right * math.sin(r) + upv * math.cos(r)
    total = sum(h for _, h in rows) + gap * sum(h for _, h in rows[1:])
    y = total / 2
    for i, (t, h) in enumerate(rows):
        if i:
            y -= gap * h
        y -= h / 2
        text(b, t, h, tuple(Vector(pos) + upv * y), normal, m, up, align, max_w=max_w, tilt=tilt)
        y -= h / 2


def sign(plate_b, text_b, f: Face, a, c, w, h, rows, bg="Yellow", fg="DecalDark", border=None, depth=0.025,
         tilt=0.0, gap=0.45, h0=0.0):
    """Bordje op een vlak: plaat (w × h) met het midden op (a, c), optioneel een rand, tekstregels."""
    if tilt:
        f.tilted(plate_b, a, c, h0, (w, h, depth), tilt, bg)
    else:
        f.box(plate_b, a, c, h0, (w, h, depth), bg)
    if border:
        t = 0.03
        for (da, dc, sw, sh) in ((0, h / 2 - t / 2, w, t), (0, -h / 2 + t / 2, w, t), (w / 2 - t / 2, 0, t, h),
                                 (-w / 2 + t / 2, 0, t, h)):
            r = math.radians(tilt)
            ra = da * math.cos(r) - dc * math.sin(r)
            rc = da * math.sin(r) + dc * math.cos(r)
            f.tilted(text_b, a + ra, c + rc, h0 + depth, (sw, sh, 0.004), tilt, border)
    lines(text_b, rows, f.at(a, c, h0 + depth), tuple(f.n), fg, tuple(f.v), gap, max_w=w * 0.86, tilt=tilt)


def tape(b, f: Face, a0, c0, a1, c1, h, width=0.05, m="DuctTape"):
    """Strook tape op een vlak van (a0, c0) naar (a1, c1)."""
    da, dc = a1 - a0, c1 - c0
    ln = math.hypot(da, dc)
    ang = math.degrees(math.atan2(dc, da))
    f.tilted(b, (a0 + a1) / 2, (c0 + c1) / 2, h, (ln, width, 0.003), ang, m)


def hazard_band(b, f: Face, a0, a1, c0, c1, h=0.0, depth=0.006):
    f.box(b, (a0 + a1) / 2, (c0 + c1) / 2, h, (a1 - a0, c1 - c0, depth), "Hazard")
