"""De Ekster van buiten: het moederschip zoals je het vanaf de planeet en tijdens de drop ziet.
Vorm goedgekeurd door Jayme op 2026-10-03 (Helldivers-stijl, docs/research/schip-ontwerp.md);
de binnenkant is een apart model (de hub). Details komen laag per laag bovenop de vorm.

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup \
        --python tools/blender/ekster_exterior.py -- [lagen] [uit.glb]

lagen: komma-lijst uit panels,trims,hatches,bay,lights,engines,greebles,armor,deck,radiators,underside,paint
(standaard: alles)
Godot-assen (x rechts, y omhoog, −z = boeg). De oorsprong is het midden van het schip; het lege
punt Mol_Dock geeft de plek van de Mol in de baai.
"""

import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

sys.path.append(str(Path(__file__).resolve().parent))
import kit  # noqa: E402
from builder import Builder, Patch, cluster, panels, pipe_run, vent  # noqa: E402
from kit import G, PARTS, bake_wear, empty, export_glb, mat, text  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ALL = ["panels", "trims", "hatches", "bay", "lights", "engines", "greebles", "armor", "deck", "radiators", "underside", "paint"]
LAYERS = ARGS[0].split(",") if ARGS and ARGS[0] not in ("all", "") else ALL
OUT = Path(ARGS[1]) if len(ARGS) > 1 else REPO / "game/assets/models/ekster_exterior.glb"
if not OUT.is_absolute():
    OUT = REPO / OUT

TILT = 32.0  # kanteling van de armen
ARM_X = 19.0
ARM_Y = 1.0


# =====================================================================================
# De vorm (goedgekeurd). Doorsnede: (z, W halve breedte, T boven, B kiel, s schouder,
# c begin van de kin, k halve kielbreedte).
# =====================================================================================

SHAPE = {
    "Prow": ([(-80, 13.0, 9.0, -5.0, 3.5, -1.0, 6.0), (-74, 15.5, 10.0, -6.5, 3.5, -1.5, 7.0),
              (-52, 15.5, 10.0, -7.0, 3.5, -1.5, 7.0), (-48, 14.0, 10.0, -7.0, 3.0, -1.5, 7.0)], "HullGrey", 0.0, 0.0, 0.0),
    "Brow": ([(-76, 9.0, 13.0, 8.0, 2.5, 9.0, 8.0), (-56, 10.5, 13.5, 8.0, 2.5, 9.0, 9.5),
              (-50, 10.5, 13.5, 8.0, 2.5, 9.0, 9.5)], "HullGrey", 0.0, 0.0, 0.0),
    "Jaw": ([(-79, 8.0, -4.0, -7.0, 1.0, -5.0, 3.0), (-60, 9.0, -4.0, -17.0, 1.0, -8.0, 2.0),
             (-52, 8.0, -4.0, -18.0, 1.0, -9.0, 2.0), (-48, 6.0, -4.0, -9.0, 1.0, -6.0, 2.5)], "HullDark", 0.0, 0.0, 0.0),
    "Mid": ([(-48, 12.5, 10.5, -10.0, 3.0, -4.0, 5.0), (-14, 12.5, 10.5, -10.0, 3.0, -4.0, 5.0),
             (-6, 9.0, 10.0, -7.0, 2.5, -3.0, 4.0)], "HullGrey", 0.0, 0.0, 0.0),
    "MidLower": ([(-46, 14.5, 2.0, -7.5, 1.5, -4.5, 9.0), (-16, 14.5, 2.0, -7.5, 1.5, -4.5, 9.0),
                  (-10, 11.5, 2.0, -6.5, 1.5, -4.0, 7.0)], "HullDark", 0.0, 0.0, 0.0),
    "Spine": ([(-8, 7.0, 9.0, -5.0, 2.0, -1.5, 3.5), (64, 6.5, 9.0, -5.0, 2.0, -1.5, 3.5)], "HullGrey", 0.0, 0.0, 0.0),
    "EngineBlock": ([(62, 9.0, 9.0, -5.0, 2.5, -1.5, 4.0), (68, 12.5, 10.0, -7.0, 3.0, -2.0, 6.0),
                     (82, 12.5, 10.0, -7.0, 3.0, -2.0, 6.0)], "HullDark", 0.0, 0.0, 0.0),
    "Bridge": ([(-28, 4.5, 16.0, 9.0, 1.5, 10.0, 3.5), (-10, 5.0, 16.5, 9.0, 1.5, 10.0, 4.0)], "HullGrey", 5.0, 0.0, 0.0),
    "BridgeTop": ([(-25, 3.5, 19.5, 16.0, 1.0, 16.5, 3.0), (-14, 3.5, 19.5, 16.0, 1.0, 16.5, 3.0)], "HullGrey", 5.0, 0.0, 0.0),
}
for _s in (-1, 1):
    SHAPE[f"Arm{_s}"] = ([(16, 3.0, 1.2, -1.2, 0.6, -0.6, 2.0), (26, 7.0, 1.8, -1.8, 0.8, -0.9, 6.0),
                          (64, 7.5, 1.8, -1.8, 0.8, -0.9, 6.5), (70, 7.5, 4.0, -4.0, 1.5, -2.0, 6.0),
                          (86, 7.5, 4.0, -4.0, 1.5, -2.0, 6.0)], "HullGrey", _s * ARM_X, ARM_Y, -_s * TILT)
PODS = [(8, 10), (22, 12), (38, 10), (52, 8)]
ENGINES = [(-7.0, 4.5, 3.2), (0, 5.0, 3.4), (7.0, 4.5, 3.2), (-3.8, -2.6, 2.9), (3.8, -2.6, 2.9)]
MOL_DOCK = (0.0, -11.0, -31.5)


def section(W, T, B, s, c, k):
    return [(-k, B), (k, B), (W, c), (W, T - s), (W - s, T), (-W + s, T), (-W, T - s), (-W, c)]


def _xf(px, py, x, y, roll):
    r = math.radians(roll)
    return (px * math.cos(r) - py * math.sin(r) + x, px * math.sin(r) + py * math.cos(r) + y)


def loft(name, stations, material, x=0.0, y=0.0, roll=0.0, group="Hull"):
    bm = bmesh.new()
    rings = []
    for (z, W, T, B, s, c, k) in stations:
        rings.append([bm.verts.new(G(*_xf(px, py, x, y, roll), z)) for (px, py) in section(W, T, B, s, c, k)])
    n = len(rings[0])
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new([a[i], a[j], b[j], b[i]])
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
    """Vlakke plaat (pyloon) uit een veelhoek met dikte."""
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


def face_patch(part, z0, z1, edge, inset=0.0):
    """Vlak van een romponderdeel tussen z0 en z1, voor de rand `edge` van de doorsnede:
    0 kiel, 1 rechterkin, 2 rechterzij, 3 rechterschouder, 4 rug, 5 linkerschouder, 6 linkerzij,
    7 linkerkin. Gebruikt de doorsnede van het eerste station met z <= z0 (rechte stukken)."""
    stations, _m, x, y, roll = SHAPE[part]
    st = [s for s in stations if s[0] <= z0][-1]
    pts = section(*st[1:])
    pa = Vector((*_xf(*pts[edge], x, y, roll), z0))
    pb = Vector((*_xf(*pts[(edge + 1) % 8], x, y, roll), z0))
    v = pb - pa
    d = v.normalized()
    nrm = Vector((d.y, -d.x, 0.0))
    o = pa + d * inset
    return Patch(o + nrm * 0.01, (0, 0, 1), tuple(d), z1 - z0, v.length - 2 * inset, normal=tuple(nrm))


# =====================================================================================
# Lagen
# =====================================================================================

def layer_panels(b: Builder, rng):
    """Gelaagde platen op de grote vlakken: dit maakt van een vorm een romp."""
    jobs = [
        ("Prow", -74, -52, (2, 6, 4, 7)), ("Brow", -56, -50, (2, 6, 4)), ("Mid", -48, -14, (2, 3, 4, 5, 6)),
        ("MidLower", -46, -16, (0, 1, 2, 6, 7)), ("Spine", -8, 62, (2, 3, 4, 5, 6)), ("EngineBlock", 68, 82, (2, 3, 4, 5, 6)),
        ("Jaw", -60, -52, (1, 7)),
    ]
    for part, z0, z1, edges in jobs:
        for e in edges:
            p = face_patch(part, z0, z1, e, inset=0.25)
            if p.sv < 1.2:
                continue
            panels(b, p, rng, cell=(5.5, 2.6), lift=0.1, gap=0.16, material=SHAPE[part][1],
                   alt=[("HullLight", 0.12), ("HullDark", 0.1), ("Anthracite", 0.05)], thick=0.12)
    for s in (-1, 1):
        for e in (3, 4, 5):  # bovenkant en schouders van de armen
            p = face_patch(f"Arm{s}", 26, 64, e, inset=0.2)
            if p.sv > 1.0:
                panels(b, p, rng, cell=(7.5, 3.0), lift=0.08, gap=0.16, material="HullGrey",
                       alt=[("HullLight", 0.06), ("HullDark", 0.05)], thick=0.1)


def layer_trims(b: Builder, rng):
    """Lange lijnen en gele randen (zoals de destroyer): de silhouetten lezen beter, en geel =
    werk (DIG)."""
    for s in (-1, 1):
        # Gele lijn langs de onderrand van de wenkbrauw en de bovenrand van het middenstuk.
        b.box((s * 10.7, 8.25, -63.0), (0.4, 0.8, 26.0), material="Yellow")
        b.box((s * 12.65, 7.2, -31.0), (0.4, 0.8, 34.0), material="Yellow")
        b.box((s * 15.65, 1.5, -63.0), (0.4, 0.6, 22.0), material="Yellow")
        # Gestreepte buitenrand van de armen.
        p = face_patch(f"Arm{s}", 26, 64, 2, inset=0.0)
        b.box(p.at(19.0, p.sv * 0.5, 0.12), (38.0, max(p.sv * 0.6, 0.6), 0.2), p.u, p.v, "Hazard")
        # Lange flankrail.
        b.box((s * 15.65, -2.0, -31.0), (0.5, 0.6, 30.0), material="Anthracite")
        b.box((s * 7.3, 4.0, 27.0), (0.5, 0.5, 66.0), material="Anthracite")
    # Kale, afgesleten randen langs de schouders van de grote stukken (stijlgids: "afgeschuinde
    # randen vangen licht"): van ver een lichte lijn die het silhouet tekent.
    for part, z0, z1 in (("Prow", -74, -52), ("Mid", -48, -14), ("Spine", -8, 62), ("EngineBlock", 68, 82)):
        st = [q for q in SHAPE[part][0] if q[0] <= z0][-1]
        _z, Wd, T, _B, s_, _c, _k = st
        for side in (-1, 1):
            # Op de schuine schouder, dicht bij de rug (3/4 van de schouder), net erboven.
            cx, cy = side * (Wd - s_ * 0.75) + side * 0.06, T - s_ * 0.25 + 0.06
            v = (-side * 0.7071, 0.7071, 0.0)
            b.box((cx, cy, (z0 + z1) / 2), ((z1 - z0) - 0.6, 0.45, 0.1), (0, 0, 1), v, "CutterSteel")
    # Een gele band rond het motorblok (DIG: geel = werk).
    eb = [q for q in SHAPE["EngineBlock"][0] if q[0] <= 70][-1]
    for (cx, cy, sx, sy) in ((0, eb[2] + 0.06, eb[1] * 2 - eb[4] * 2, 0.12), (eb[1] + 0.06, (eb[2] + eb[3]) / 2, 0.12, eb[2] - eb[3] - 2.0),
                             (-eb[1] - 0.06, (eb[2] + eb[3]) / 2, 0.12, eb[2] - eb[3] - 2.0)):
        b.box((cx, cy, 72.0), (sx, sy, 2.2), material="Yellow")
    # Rugrail met spanten (ritme).
    b.box((0, 9.7, 28.0), (1.6, 1.0, 70.0), material="HullDark")
    for z in range(-6, 63, 4):
        b.box((0, 9.25, z), (8.0, 0.6, 0.6), material="HullDark")


def layer_hatches(b: Builder, rng):
    """Zijbaaien met gele kaders (zoals de luiken van de destroyer), en roosters onderaan."""
    for s in (-1, 1):
        side = face_patch("Mid", -48, -14, 2 if s > 0 else 6)
        for i in range(3):
            u = 6.5 + i * 9.0
            v = side.sv * 0.55
            w, h = 7.0, side.sv * 0.6
            b.box(side.at(u, v, 0.08), (w + 0.9, h + 0.9, 0.16), side.u, side.v, "Yellow")
            b.box(side.at(u, v, 0.12), (w, h, 0.18), side.u, side.v, "HullDark")
            for k in range(3):
                b.box(side.at(u - w / 2 + 1.2 + k * 2.3, v, 0.28), (1.4, h * 0.85, 0.12), side.u, side.v, "Anthracite")
            b.box(side.at(u + w / 2 - 0.4, v + h / 2 - 0.4, 0.3), (0.35, 0.35, 0.2), side.u, side.v, "NavRed")
        low = face_patch("MidLower", -46, -16, 2 if s > 0 else 6)
        for i in range(4):
            vent(b, low, 4.0 + i * 7.0, low.sv * 0.5, 4.0, low.sv * 0.6, 5)


def layer_bay(b: Builder, rng):
    """De baai van de Mol in de buik: een opening met gevarenrand, twee luiken die opzij schuiven,
    schijnwerpers op de hoeken en een grijper boven de Mol."""
    mx, my, mz = MOL_DOCK
    keel = SHAPE["Mid"][0][0][3]  # onderkant van het middenstuk (y)
    w, l = 9.0, 17.0
    b.box((0, keel - 0.06, mz), (w, 0.14, l), material="Soot")
    for (cx, cz, sx, sz) in ((0, mz - l / 2 - 0.45, w + 1.8, 0.9), (0, mz + l / 2 + 0.45, w + 1.8, 0.9),
                             (-w / 2 - 0.45, mz, 0.9, l), (w / 2 + 0.45, mz, 0.9, l)):
        b.box((cx, keel - 0.12, cz), (sx, 0.25, sz), material="Hazard")
    for s in (-1, 1):  # luiken open, opzij geschoven onder de romp
        b.box((s * (w / 2 + 3.4), keel - 0.45, mz), (w / 2, 0.4, l - 0.6), material="HullDark")
        b.box((s * (w / 2 + 3.4), keel - 0.68, mz), (w / 2 - 0.6, 0.1, l - 1.4), material="Anthracite")
    for (cx, cz) in ((-w / 2 - 1.4, mz - l / 2 - 1.4), (w / 2 + 1.4, mz - l / 2 - 1.4), (-w / 2 - 1.4, mz + l / 2 + 1.4), (w / 2 + 1.4, mz + l / 2 + 1.4)):
        b.box((cx, keel - 0.35, cz), (1.4, 0.6, 1.4), material="DarkSteel")
        b.box((cx, keel - 0.7, cz), (1.0, 0.12, 1.0), material="Lens")
    # De grijper zelf hangt in de game (EksterExterior), aan een kabel die kan zakken.


def layer_lights(b: Builder, rng):
    """Ramen en lichtjes: schaal (rijen kleine ramen), navigatie (rood links, groen rechts), en
    looplichten langs de randen die het silhouet tekenen."""
    # Brugramen.
    b.box((5.0, 18.2, -25.15), (6.8, 0.9, 0.3), material="Cyan")
    for s in (-1, 1):
        b.box((5.0 + s * 3.55, 12.8, -19.0), (0.2, 0.7, 14.0), material="Cyan")
    # Rijen kleine ramen op het middenstuk en de boeg.
    for s in (-1, 1):
        for (part, z0, z1, row) in (("Mid", -46, -16, 0.86), ("Prow", -72, -54, 0.78)):
            side = face_patch(part, z0, z1, 2 if s > 0 else 6)
            n = int((z1 - z0) / 1.6)
            for i in range(n):
                b.box(side.at(0.8 + i * 1.6, side.sv * row, 0.14), (0.7, 0.5, 0.12), side.u, side.v,
                      "Cyan" if rng.random() > 0.3 else "Anthracite")
    # Navigatielichten.
    b.box((-15.8, 6.0, -78.0), (0.6, 0.6, 0.6), material="NavRed")
    b.box((15.8, 6.0, -78.0), (0.6, 0.6, 0.6), material="NavGreen")
    for s in (-1, 1):
        ax, ay = _xf(s * 7.5, 0.0, s * ARM_X, ARM_Y, -s * TILT)
        b.box((ax, ay, 84.0), (0.6, 0.6, 0.6), material="NavRed" if s < 0 else "NavGreen")
    # Looplichten langs de onderranden van boeg, middenstuk en armen.
    for s in (-1, 1):
        for z in range(-78, -14, 3):
            b.box((s * (15.3 if z < -50 else 14.3), -2.2 if z < -50 else -5.0, z), (0.25, 0.25, 0.25), material="RunLight")
        for z in range(28, 66, 3):
            ax, ay = _xf(s * 7.0, -1.2, s * ARM_X, ARM_Y, -s * TILT)
            b.box((ax, ay, z), (0.25, 0.25, 0.25), material="RunLight")
    # Schijnwerpers onder de kaak.
    for x in (-4, 4):
        b.box((x, -17.6, -54.0), (1.0, 0.4, 1.0), material="Lens")


def layer_engines(b: Builder, rng):
    """Motoren als bloemen (zoals de destroyer): kraag, bladen eromheen, verzonken straalpijp met
    een felle kern."""
    def engine(cx, cy, z, r):
        b.cyl((cx, cy, z - 0.2), (0, 0, 1), 2.6, r * 1.15, 24, "HullDark")
        b.cyl((cx, cy, z + 2.3), (0, 0, 1), 0.5, r * 1.2, 24, "Yellow")
        for k in range(8):  # bladen
            a = 2 * math.pi * k / 8 + math.pi / 8
            px, py = cx + math.cos(a) * r * 1.02, cy + math.sin(a) * r * 1.02
            b.box((px, py, z + 2.9), (r * 0.62, 0.35, 1.4), u=(-math.sin(a), math.cos(a), 0), v=(math.cos(a), math.sin(a), 0),
                  material="HullGrey")
        b.cyl((cx, cy, z + 2.4), (0, 0, 1), 1.0, r * 0.82, 20, "Soot", r2=r * 0.66)
        b.cyl((cx, cy, z + 3.42), (0, 0, 1), 0.15, r * 0.62, 20, "EngineGlow")
    for (ex, ey, r) in ENGINES:
        engine(ex, ey, 82.0, r)
    for s in (-1, 1):
        for lx in (-3.6, 3.6):
            x, y = _xf(lx, 0.0, s * ARM_X, ARM_Y, -s * TILT)
            engine(x, y, 86.0, 2.5)


def layer_greebles(b: Builder, rng):
    """Detail in clusters waar de functie zit: onder de rug (laadkasten), op het motorblok, langs
    de rug (leidingen), bij de brug (antennes, radar), op de boeg (sensoren). Rustige vlakken
    ertussen (70/30)."""
    for (z, L) in PODS:
        bot = Patch((-3.0, -9.05, z), (0, 0, 1), (1, 0, 0), L, 6.0, normal=(0, -1, 0))
        cluster(b, bot, rng, L / 2, 3.0, L - 1.0, 5.0, density=1.4)
        for s in (-1, 1):
            b.box((s * 4.05, -7.0, z + L / 2), (0.2, 1.2, L - 1.0), material="HullLight")
    top = face_patch("EngineBlock", 68, 82, 4)
    cluster(b, top, rng, 7.0, top.sv / 2, 12.0, top.sv - 2.0, density=1.3)
    for s in (-1, 1):
        side = face_patch("Spine", -8, 62, 2 if s > 0 else 6)
        pipe_run(b, side, rng, side.sv * 0.25, 3, 0.25, 0.45)
    # Brug: antennes en een radarschotel.
    b.cyl((3.0, 19.5, -20.0), (0, 1, 0), 6.0, 0.18, 8, "Steel")
    b.cyl((7.0, 19.5, -18.0), (0, 1, 0), 3.5, 0.14, 8, "Steel")
    b.cyl((5.0, 19.5, -16.5), (0, 1, 0), 1.2, 0.5, 10, "DarkSteel")
    b.cyl((5.0, 20.7, -16.5), (0, 1, 0), 0.4, 2.2, 16, "HullLight", r2=1.4)
    b.box((3.0, 25.6, -20.0), (0.3, 0.3, 0.3), material="NavRed")
    # Boeg: sensorbulten en een stuk vakwerk op de wenkbrauw.
    for x in (-5.0, 5.0):
        b.box((x, 13.9, -66.0), (2.5, 0.8, 4.0), material="HullDark")
        b.cyl((x, 14.3, -66.0), (0, 1, 0), 0.9, 0.8, 12, "Steel")
    top_mid = face_patch("Mid", -48, -14, 4)
    cluster(b, top_mid, rng, 6.0, top_mid.sv / 2, 7.0, top_mid.sv - 2.0, density=1.1)
    cluster(b, top_mid, rng, 30.0, top_mid.sv * 0.3, 6.0, top_mid.sv * 0.5, density=1.0)


def layer_armor(b: Builder, rng):
    """Gelaagde pantserplaten die de grote vlakken breken: de voorkant van de boeg (lamellen,
    schijnwerpers, twee "ogen") en losse platen op de flanken van de rug."""
    # Voorkant van de boeg: een verzonken kader met drie lamellen en schijnwerpers.
    front = Patch((-11.0, -3.6, -80.0), (1, 0, 0), (0, 1, 0), 22.0, 11.0, normal=(0, 0, -1))
    b.box(front.at(11.0, 5.5, 0.15), (19.5, 9.5, 0.3), front.u, front.v, "HullDark")
    for k in range(3):
        b.box(front.at(11.0, 2.6 + k * 2.6, 0.45), (18.0, 1.4, 0.35), front.u, front.v, "HullGrey")
    for x in (-8.0, 8.0):
        b.box((x, 3.0, -80.6), (2.2, 1.4, 0.6), material="DarkSteel")
        b.box((x, 3.0, -80.95), (1.8, 1.0, 0.12), material="Lens")
    # Twee ogen op de voorkant van de wenkbrauw (de ekster kijkt naar beneden).
    for x in (-4.5, 4.5):
        b.cyl((x, 10.6, -76.3), (0, 0, -1), 0.5, 1.3, 16, "DarkSteel")
        b.cyl((x, 10.6, -76.75), (0, 0, -1), 0.12, 0.95, 16, "Cyan")
    # Losse pantserplaten op de flanken van de rug, om en om hoger en lager (breekt de lange lijn).
    for s in (-1, 1):
        for i, z in enumerate(range(0, 60, 9)):
            h = 4.2 if i % 2 == 0 else 3.2
            y = 3.2 if i % 2 == 0 else 1.6
            b.box((s * 7.45, y, z + 4.0), (0.6, h, 7.6), material="HullGrey" if i % 3 else "HullLight")
            b.box((s * 7.8, y + h / 2 - 0.3, z + 4.0), (0.3, 0.3, 7.0), material="HullDark")


def layer_deck(b: Builder, rng):
    """Op het dek: containers met gestolen lading op de rug (kleuren van andere firma's), een
    kraan, luiken en een sensormast. Het verhaal van DIG in één oogopslag."""
    colors = ["RedOxide", "Cream", "Anthracite", "Yellow", "HullLight", "RedOxide", "GreyGreen"]
    for i, z in enumerate(range(6, 56, 7)):
        for x in (-3.2, 3.2):
            if rng.random() < 0.8:
                c = colors[rng.randrange(len(colors))]
                h = 2.6 if rng.random() < 0.7 else 5.2
                b.box((x, 9.0 + h / 2 + 0.05, z), (2.5, h, 6.0), material=c)
                for k in range(5):  # ribbels
                    b.box((x + (1.28 if x > 0 else -1.28), 9.0 + h / 2, z - 2.4 + k * 1.2), (0.08, h * 0.9, 0.12), material=c)
    # Kraan op het middenstuk: een mast met een schuine giek.
    b.box((-8.0, 12.5, -40.0), (1.4, 4.0, 1.4), material="Yellow")
    b.prism([(-0.4, -0.4), (0.4, -0.4), (0.4, 0.4), (-0.4, 0.4)], (-8.0, 14.3, -40.0), (0.6, 0.35, 0.72), 14.0, (0, 1, 0), "Yellow")
    b.cyl((-8.0, 10.5, -40.0), (0, 1, 0), 0.6, 1.6, 12, "DarkSteel")
    # Luiken op het dek.
    top = face_patch("Mid", -48, -14, 4)
    for u in (24.0, 29.0):
        b.box(top.at(u, top.sv * 0.25, 0.1), (3.2, 3.2, 0.2), top.u, top.v, "Hazard")
        b.box(top.at(u, top.sv * 0.25, 0.25), (2.6, 2.6, 0.2), top.u, top.v, "HullDark")


def layer_radiators(b: Builder, rng):
    """Koelvinnen: op het motorblok en schuin op de armen bij de motorkasten."""
    for s in (-1, 1):
        for k in range(7):
            b.box((s * 10.5, 11.2, 68.5 + k * 1.8), (3.0, 2.4, 0.25), material="HullDark")
        for k in range(6):
            x, y = _xf(0.0, 4.6, s * ARM_X, ARM_Y, -s * TILT)
            b.box((x, y, 71.0 + k * 2.4), (8.0, 1.6, 0.3), u=(math.cos(math.radians(-s * TILT)), math.sin(math.radians(-s * TILT)), 0),
                  v=(-math.sin(math.radians(-s * TILT)), math.cos(math.radians(-s * TILT)), 0), material="HullDark")


def layer_underside(b: Builder, rng):
    """De buik, ons heldenvlak: een kiel met lichtjes, ribben onder de rug, details tussen de kasten."""
    for z in range(-46, -14, 2):
        b.box((0, -10.2, z), (2.0, 0.2, 0.25), material="HullDark") if z < -41 or z > -22 else None
    for s in (-1, 1):
        for z in range(-45, -16, 3):
            b.box((s * 6.5, -10.15, z), (0.3, 0.2, 0.3), material="BellyLight")
        for z in range(-6, 62, 3):
            b.box((s * 3.0, -5.15, z), (0.25, 0.2, 0.25), material="BellyLight")
    for z in range(-6, 62, 4):
        b.box((0, -5.2, z), (5.0, 0.4, 0.5), material="HullDark")


def layer_emblem(group):
    """Een ekster als embleem (zwart-wit, met lange staart) op de flanken van de boeg."""
    # Gedrongen ekster naar de boeg: kop met snavel, ronde borst, lange staart; wit op buik en schouder.
    bird = [(2.3, 1.55), (1.6, 1.42), (1.5, 1.2), (1.3, 0.75), (0.6, 0.35), (-0.2, 0.35), (-2.9, 0.75),
            (-2.9, 0.98), (-0.4, 0.98), (0.4, 1.42), (0.9, 1.78), (1.3, 1.9), (1.7, 1.8)]
    belly = [(0.55, 0.42), (1.18, 0.78), (1.25, 1.1), (0.75, 1.0), (0.2, 0.55)]
    wing = [(-0.3, 1.0), (0.45, 1.32), (0.2, 1.06), (-0.4, 0.92)]
    scale = 1.4
    for s in (-1, 1):
        x = s * 15.9
        for pts, m, off in ((bird, "Anthracite", 0.06), (belly, "Cream", 0.12), (wing, "Cream", 0.12)):
            world = [(x + s * off, 3.2 + (py - 1.1) * scale, -57.0 - (px + 0.3) * scale) for (px, py) in pts]
            plate(f"Emblem{s}{m}{off}{len(pts)}", world, 0.08, m, group)
        b2 = Builder(f"EmblemBack{s}")
        b2.cyl((s * 15.82, 3.2, -57.0), (s, 0, 0), 0.05, 4.2, 32, "Cream")
        b2.to_object(group)


def layer_paint(group):
    """Opschriften: groot DIG op de armen en de flank, de naam op de boeg, een registratienummer."""
    # Groot DIG op de flanken van de rug (zoals de naam op de destroyer), leesbaar van opzij.
    text("DIG", 4.2, (-7.8, 3.2, 40.0), (0, -90, 0), "Yellow", group, extrude=0.06)
    text("DIG", 4.2, (7.8, 3.2, 40.0), (0, 90, 0), "Yellow", group, extrude=0.06)
    # Vóór de panelen (die steken ±0,3 m uit de romp).
    text("THE MAGPIE", 2.05, (-15.95, 4.6, -67.8), (0, -90, 0), "Cream", group, extrude=0.04)
    text("THE MAGPIE", 2.05, (15.95, 4.6, -67.8), (0, 90, 0), "Cream", group, extrude=0.04)
    text("DIG-0017", 1.3, (-15.95, -0.3, -67.8), (0, -90, 0), "Yellow", group, extrude=0.04)
    text("DIG-0017", 1.3, (15.95, -0.3, -67.8), (0, 90, 0), "Yellow", group, extrude=0.04)


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    PARTS.clear()
    kit._MATS.clear()
    rng = random.Random(17)
    for name, (stations, material, x, y, roll) in SHAPE.items():
        loft(name, stations, material, x, y, roll)
    for (z, L) in PODS:
        loft(f"Pod{z}", [(z, 4.0, -5.0, -9.0, 1.0, -7.5, 3.0), (z + L, 4.0, -5.0, -9.0, 1.0, -7.5, 3.0)], "HullDark")
    for s in (-1, 1):  # pylonen die de armen aan de romp hangen
        for z0 in (24.0, 50.0):
            plate(f"Pylon{s}{z0}", [(s * 6.0, 5.0, z0), (s * 15.0, 2.0, z0 + 5), (s * 15.0, 2.0, z0 + 12), (s * 6.0, 5.0, z0 + 9)], 1.4)
    for o in PARTS["Hull"]:
        bev = o.modifiers.new("Bevel", "BEVEL")
        bev.width = 0.35 if not o.name.startswith(("Pod", "Pylon")) else 0.15
        bev.segments = 1
        bev.limit_method = "ANGLE"
        bev.angle_limit = math.radians(25)
    detail = Builder("Detail")
    for layer in LAYERS:
        if layer == "paint":
            continue
        globals()[f"layer_{layer}"](detail, rng)
    detail.to_object("Hull", bevel=0.05, segments=1)
    if "paint" in LAYERS:
        layer_paint("Hull")
        layer_emblem("Hull")
    root = bpy.data.objects.new("EksterExterior", None)
    bpy.context.collection.objects.link(root)
    for o in PARTS["Hull"]:
        for p in o.data.polygons:
            p.use_smooth = False
        bake_wear(o, strength=5.0, seed=hash(o.name) % 997)
        o.parent = root
    empty("Mol_Dock", MOL_DOCK, parent=root)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    export_glb(OUT)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in PARTS["Hull"])
    print(f"[exterior] lagen {','.join(LAYERS)}: {tris} driehoeken (voor afschuining) -> {OUT}")


build()
