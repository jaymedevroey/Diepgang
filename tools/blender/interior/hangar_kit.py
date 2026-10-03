"""Hulpstukken voor de hangar (zone_hangar.py): profielen, tekst, armaturen en DIG-rommel.

Alles in PLANcoördinaten (zie layout.py): x bakboord → stuurboord, y omhoog, z raam → achteraan.
Richtingen zijn in plan en Godot gelijk (G verschuift enkel).
"""

import math
import random
from pathlib import Path

import bpy
from mathutils import Vector

import kit
from layout import G, block

REPO = Path(__file__).resolve().parents[3]
FONT = REPO / "game/assets/fonts/Bungee-Regular.ttf"  # het lettertype van de borden in de UI
CAP = 0.294  # hoogte van een hoofdletter in Bungee bij grootte 1 (gemeten in Blender)

# Nieuwe materialen. Ook toevoegen aan MolVisual (Godot): naam, kleur, metallic, roughness, emissie.
NEW_MATS = {
    "ScreenGlow": ((0.5, 0.78, 0.28), 0.0, 0.35, ((0.5, 0.78, 0.28), 0.6)),  # geelgroen consolebeeld
    "ScreenAmber": ((1.0, 0.6, 0.22), 0.0, 0.35, ((1.0, 0.56, 0.18), 0.8)),  # DIG-beeld, prijzen
    # Valschacht: waarschuwingsstroken (Shaft_Lights, de drop-effecten laten ze knipperen).
    "ShaftLight": ((1.0, 0.5, 0.2), 0.0, 0.3, ((1.0, 0.45, 0.15), 2.0)),
    # Rooster van de galerij: lichter en minder metaalachtig dan DarkSteel, zodat licht erop blijft liggen.
    "Grating": ((0.3, 0.31, 0.32), 0.55, 0.5, None),
}
kit.PALETTE.update(NEW_MATS)

# Ongelijke wandplaten: een goedkope firma koopt platen waar ze goedkoop zijn.
MISMATCH = [("Anthracite", 0.14), ("GreyGreen", 0.08), ("HullGrey", 0.06)]


def P(x, y, z):
    return Vector(G(x, y, z))


def box(b, x0, x1, y0, y1, z0, z1, m):
    block(b, min(x0, x1), max(x0, x1), min(y0, y1), max(y0, y1), min(z0, z1), max(z0, z1), m)


def obox(b, c, size, u, v, m):
    """Gedraaide doos: midden c (plan), maten langs u, v en u × v."""
    b.box(G(*c), size, u=u, v=v, material=m)


def _area(pts):
    n = len(pts)
    return sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n)) / 2


def prism(b, profile, origin, eu, ev, axis, length, m):
    """Profiel [(u, v)] in het vlak (eu, ev) rond `origin` (plan), uitgerekt langs `axis`."""
    pts = list(profile)
    if _area(pts) < 0:
        pts.reverse()
    O = P(*origin)
    U = Vector(eu).normalized()
    W = Vector(ev).normalized()
    A = Vector(axis).normalized()
    if U.cross(W).dot(A) < 0:
        pts.reverse()
    a = b._verts([O + U * u + W * v for u, v in pts])
    c = b._verts([O + U * u + W * v + A * length for u, v in pts])
    mi = b._mi(m)
    n = len(pts)
    faces = [b.bm.faces.new(list(reversed(a))), b.bm.faces.new(c)]
    for i in range(n):
        j = (i + 1) % n
        faces.append(b.bm.faces.new([a[i], a[j], c[j], c[i]]))
    for f in faces:
        f.material_index = mi


def rect(w, h):
    return [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]


def beam(b, p0, p1, w, h, m, up=(0, 1, 0), ch=0.05):
    """Afgeschuinde balk van p0 naar p1 (plan): breedte w (opzij), hoogte h (langs `up`)."""
    a = Vector(p0)
    A = Vector(p1) - a
    length = A.length
    A.normalize()
    X = Vector(up).cross(A)
    if X.length < 1e-6:
        X = Vector((1, 0, 0)).cross(A)
    X.normalize()
    Y = A.cross(X)
    prof = kit.octagon(w, h, ch) if ch > 0 else rect(w, h)
    prism(b, prof, p0, X, Y, A, length, m)


def ibeam(b, p0, p1, w, h, m, up=(0, 1, 0), flange=0.05, web=0.05):
    """I-profiel van p0 naar p1."""
    prof = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, -h / 2 + flange), (web / 2, -h / 2 + flange),
            (web / 2, h / 2 - flange), (w / 2, h / 2 - flange), (w / 2, h / 2), (-w / 2, h / 2),
            (-w / 2, h / 2 - flange), (-web / 2, h / 2 - flange), (-web / 2, -h / 2 + flange), (-w / 2, -h / 2 + flange)]
    a = Vector(p0)
    A = Vector(p1) - a
    length = A.length
    A.normalize()
    X = Vector(up).cross(A).normalized()
    Y = A.cross(X)
    prism(b, prof, p0, X, Y, A, length, m)


def frame_of(normal, up=(0, 1, 0)):
    """Rechts, boven en normaal van een vlak met normaal `normal` (zoals je ernaar kijkt)."""
    N = Vector(normal).normalized()
    R = Vector(up).cross(N).normalized()
    return R, N.cross(R), N


def fbox(b, center, normal, su, sv, t, m, up=(0, 1, 0), lift=0.0, du=0.0, dv=0.0):
    """Doos op een vlak: `center` ligt op het vlak, de doos steekt t uit langs de normaal.
    su langs rechts, sv langs boven; du/dv verschuiven het midden binnen het vlak."""
    R, U, N = frame_of(normal, up)
    c = Vector(center) + R * du + U * dv + N * (lift + t / 2)
    b.box(G(*c), (su, sv, t), u=tuple(R), v=tuple(U), material=m)


def screen_ui(b, center, normal, w, h, m="ScreenGlow", up=(0, 1, 0), lift=0.0, seed=0):
    """Beeld op een scherm (dunne lijnen): kader, kopbalk, regels 'tekst' en een staafgrafiek."""
    rnd = random.Random(seed)
    t = 0.003
    for (du, dv, sw, sh) in ((0, h / 2 - 0.012, w - 0.03, 0.006), (0, -h / 2 + 0.012, w - 0.03, 0.006),
                             (-w / 2 + 0.012, 0, 0.006, h - 0.03), (w / 2 - 0.012, 0, 0.006, h - 0.03)):
        fbox(b, center, normal, sw, sh, t, m, up, lift, du, dv)
    fbox(b, center, normal, w * 0.42, h * 0.07, t, m, up, lift, du=-w * 0.22, dv=h * 0.34)
    for i in range(5):
        lw = w * rnd.uniform(0.15, 0.42)
        fbox(b, center, normal, lw, h * 0.03, t, m, up, lift, du=-w * 0.42 + lw / 2, dv=h * 0.2 - i * h * 0.11)
    for k in range(5):
        bh = h * rnd.uniform(0.08, 0.42)
        fbox(b, center, normal, w * 0.04, bh, t, m, up, lift, du=w * 0.14 + k * w * 0.06, dv=-h * 0.36 + bh / 2)


def vent_on(b, center, normal, w, h, slats=6, up=(0, 1, 0), lift=0.0):
    """Rooster op een vlak: kader en schuine lamellen."""
    fbox(b, center, normal, w, h, 0.035, "Anthracite", up, lift)
    fbox(b, center, normal, w - 0.06, h - 0.06, 0.04, "Soot", up, lift)
    for i in range(slats):
        dv = -h / 2 + 0.05 + (i + 0.5) * (h - 0.1) / slats
        fbox(b, center, normal, w - 0.08, (h - 0.1) / slats * 0.55, 0.03, "DarkSteel", up, lift + 0.035, dv=dv)


def hatch_on(b, center, normal, w, h, m="DarkSteel", up=(0, 1, 0), lift=0.0, handle=True):
    """Luikje (kader van vier latten en een handgreep) op een plaat."""
    t = 0.035
    for (du, dv, sw, sh) in ((0, h / 2 - t / 2, w, t), (0, -h / 2 + t / 2, w, t), (-w / 2 + t / 2, 0, t, h), (w / 2 - t / 2, 0, t, h)):
        fbox(b, center, normal, sw, sh, 0.012, m, up, lift, du, dv)
    if handle:
        fbox(b, center, normal, 0.04, 0.16, 0.035, "Steel", up, lift, du=w / 2 - 0.12)


def cyl(b, p0, axis, length, r, m, segs=12, r2=None):
    b.cyl(G(*p0), axis, length, r, segs, m, r2)


def pipe(b, pts, r, m, segs=8, clamps=0.0):
    b.pipe([G(*p) for p in pts], r, segs, m, clamps)


# --- Tekst ------------------------------------------------------------------------------------------

def text(b, body, height, center, normal, up, m, fit=None, align="CENTER", lift=0.004, res=2):
    """Platte tekst (Bungee) op een vlak: `height` = hoogte van de hoofdletters, `fit` = max. breedte.
    Geeft (breedte, hoogte) terug."""
    cu = bpy.data.curves.new("txt", "FONT")
    cu.body = body
    cu.font = bpy.data.fonts.load(str(FONT), check_existing=True)
    cu.size = 1.0
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.resolution_u = res
    ob = bpy.data.objects.new("txt", cu)
    bpy.context.collection.objects.link(ob)
    ev = ob.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = ev.to_mesh()
    xs = [v.co.x for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    out = (0.0, 0.0)
    if xs:
        w = max(xs) - min(xs)
        s = height / CAP
        if fit and w * s > fit:
            s = fit / w
        cx = (max(xs) + min(xs)) / 2
        if align == "LEFT":
            cx = min(xs)
        elif align == "RIGHT":
            cx = max(xs)
        cy = (max(ys) + min(ys)) / 2
        N = Vector(normal).normalized()
        Up = Vector(up)
        R = Up.cross(N).normalized()
        Up = N.cross(R)
        C = P(*center) + N * lift
        verts = b._verts([C + R * ((v.co.x - cx) * s) + Up * ((v.co.y - cy) * s) for v in me.vertices])
        mi = b._mi(m)
        for poly in me.polygons:
            try:
                f = b.bm.faces.new([verts[i] for i in poly.vertices])
                f.material_index = mi
            except ValueError:
                pass
        out = (w * s, (max(ys) - min(ys)) * s)
    ev.to_mesh_clear()
    bpy.data.objects.remove(ob)
    bpy.data.curves.remove(cu)
    return out


def plate(b, d, body, center, normal, up, w, h, bg="DecalDark", fg="Yellow", height=None, border=None, depth=0.02):
    """Bordje: plaat (w × h) met tekst, op een wand met normaal `normal`. `d` krijgt de tekst."""
    N = Vector(normal).normalized()
    Up = Vector(up)
    R = Up.cross(N).normalized()
    Up = N.cross(R)
    c = Vector(center)
    obox(b, tuple(c + N * depth / 2), (w, h, depth), tuple(R), tuple(Up), bg)
    if border:
        t = 0.025
        for (du, dv, sw, sh) in ((0, h / 2 - t / 2, w, t), (0, -h / 2 + t / 2, w, t), (w / 2 - t / 2, 0, t, h), (-w / 2 + t / 2, 0, t, h)):
            obox(d, tuple(c + R * du + Up * dv + N * (depth + 0.003)), (sw, sh, 0.006), tuple(R), tuple(Up), border)
    text(d, body, height or h * 0.5, tuple(c + N * depth), tuple(N), tuple(Up), fg, fit=w * 0.88)


# --- DIG-rommel ---------------------------------------------------------------------------------------

def tape_x(b, center, normal, up, size, m="CutterSteel"):
    """Een kruis van tape (een herstelling)."""
    N = Vector(normal).normalized()
    Up = Vector(up)
    R = Up.cross(N).normalized()
    Up = N.cross(R)
    c = Vector(center) + N * 0.006
    for s in (1, -1):
        d = (R + Up * s).normalized()
        e = N.cross(d)
        obox(b, tuple(c), (size, 0.07, 0.006), tuple(d), tuple(e), m)


def taped_crack(b, center, normal, length=0.6, angle=30.0, pieces=3, up=(0, 1, 0)):
    """Een barst (donkere lijn) met een paar stukjes tape erover: een DIG-herstelling."""
    R, U, N = frame_of(normal, up)
    a = math.radians(angle)
    d = R * math.cos(a) + U * math.sin(a)
    e = N.cross(d)
    c = Vector(center)
    obox(b, tuple(c + N * 0.003), (length, 0.014, 0.006), tuple(d), tuple(e), "Soot")
    for i in range(pieces):
        t = (i + 0.5) / pieces - 0.5
        k = 1 if i % 2 else -1
        dd = (e + d * 0.25 * k).normalized()
        obox(b, tuple(c + d * (t * length * 0.85) + N * 0.007), (0.17, 0.055, 0.005), tuple(dd), tuple(N.cross(dd)), "HullLight")


def tape_strip(b, center, normal, along, length, m="CutterSteel", width=0.07):
    N = Vector(normal).normalized()
    A = Vector(along).normalized()
    obox(b, tuple(Vector(center) + N * 0.006), (length, width, 0.006), tuple(A), tuple(N.cross(A)), m)


def crate(b, d, x, z, w, depth, h, m, rot=0.0, y=0.0, label=None, label_m="DecalDark", lid=True):
    """Kist met hoekprofielen en een opschrift (gestolen bij een andere firma)."""
    a = math.radians(rot)
    u = (math.cos(a), 0, math.sin(a))
    v = (0, 1, 0)
    n = (-math.sin(a), 0, math.cos(a))  # u × v
    obox(b, (x, y + h / 2, z), (w, h, depth), u, v, m)
    U = Vector(u)
    Nn = Vector(n)
    base = Vector((x, y, z))
    # Hoekprofielen en banden.
    for su in (-1, 1):
        for sn in (-1, 1):
            c = base + U * (su * (w / 2 - 0.03)) + Nn * (sn * (depth / 2 - 0.03)) + Vector((0, h / 2, 0))
            obox(d, tuple(c), (0.07, h + 0.01, 0.07), u, v, "DarkSteel")
    for yy in (0.06, h - 0.06):
        obox(d, tuple(base + Vector((0, yy, 0))), (w + 0.012, 0.05, depth + 0.012), u, v, "DarkSteel")
    if lid:
        obox(d, tuple(base + Vector((0, h + 0.012, 0))), (w - 0.1, 0.024, depth - 0.1), u, v, m)
    if label:
        text(d, label, min(0.11, h * 0.18), tuple(base + Nn * (depth / 2) + Vector((0, h * 0.55, 0))), n, (0, 1, 0),
             label_m, fit=w * 0.8, res=1)


def bulkhead_lamp(b, d, center, normal, lens="Lens"):
    """Wandlamp met kooi: behuizing, lens, drie staafjes."""
    N = Vector(normal).normalized()
    R = Vector((0, 1, 0)).cross(N).normalized()
    c = Vector(center)
    obox(b, tuple(c + N * 0.06), (0.36, 0.26, 0.12), tuple(R), (0, 1, 0), "DarkSteel")
    obox(d, tuple(c + N * 0.15), (0.26, 0.15, 0.06), tuple(R), (0, 1, 0), lens)
    for du in (-0.09, 0.0, 0.09):
        obox(d, tuple(c + N * 0.2 + R * du), (0.018, 0.2, 0.018), tuple(R), (0, 1, 0), "DarkSteel")
    obox(d, tuple(c + N * 0.2 + Vector((0, 0.1, 0))), (0.3, 0.018, 0.1), tuple(R), (0, 1, 0), "DarkSteel")
    obox(d, tuple(c + N * 0.2 - Vector((0, 0.1, 0))), (0.3, 0.018, 0.1), tuple(R), (0, 1, 0), "DarkSteel")


def hang_fixture(b, d, x, z, y, length, axis="z", top=9.0, lens="LedWhite"):
    """Hangende lichtbak (zichtbaar armatuur): behuizing, lens onderaan, twee stangen."""
    if axis == "z":
        box(b, x - 0.2, x + 0.2, y, y + 0.16, z - length / 2, z + length / 2, "DarkSteel")
        box(d, x - 0.13, x + 0.13, y - 0.012, y, z - length / 2 + 0.08, z + length / 2 - 0.08, lens)
        ends = [(x, z - length / 2 + 0.25), (x, z + length / 2 - 0.25)]
    else:
        box(b, x - length / 2, x + length / 2, y, y + 0.16, z - 0.2, z + 0.2, "DarkSteel")
        box(d, x - length / 2 + 0.08, x + length / 2 - 0.08, y - 0.012, y, z - 0.13, z + 0.13, lens)
        ends = [(x - length / 2 + 0.25, z), (x + length / 2 - 0.25, z)]
    for (ex, ez) in ends:
        cyl(d, (ex, y + 0.16, ez), (0, 1, 0), top - y - 0.16, 0.015, "Steel", segs=6)
