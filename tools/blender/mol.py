"""De Mol: rijdende tunnelboormachine en basis van Diepgang BV (docs/de-mol.md).

Gebruik:
    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup \
        --python tools/blender/mol.py -- game/assets/models/mol.glb [--render <map>]

Maten in Godot-coördinaten (zie kit.py). Oorsprong = midden van de romp-as.
Objecten (namen gebruikt door de game):
  Hull       romp, schild, dak, rupsframes (vast)
  DrillHead  draaiende boorkop (draait rond z, oorsprong op de as)
  Hub        stilstaande naaf met lampen en camera
  Wheel_L_n / Wheel_R_n  wielen (draaien rond hun eigen x-as)
  TrackLink  één rupsschakel (de game legt ze langs het rupspad)
  Ramp       laadklep, scharnier onderaan achteraan
  Interior   alles binnen
  Monitor    camerascherm (UV 0..1)
  Sonar      sonarscherm achter de frontplaat van de sonarkast (UV 0..1)
  SonarLamp  echolampje op de sonarkast
  SonarPing  PING-knop op de sonarkast (oorsprong in het midden van de knop)
  Lever      vertrekhendel (draait rond x)
  Glass      patrijspoorten en ramen
  Lege punten (Node3D): lampen, camera, stoel, knoppen, uitlaten.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.append(str(Path(__file__).resolve().parent))
import kit  # noqa: E402
from kit import (G, PARTS, bake_wear, box, cyl, empty, export_glb, join_group, mat, octagon, parent_to,  # noqa: E402
                 prism, rivets, sphere, sweep, text, torus, tube, tri_count, boolean, unregister, _godot_euler)

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = Path(ARGS[0]) if ARGS else Path("mol.glb")
RENDER_DIR = Path(ARGS[ARGS.index("--render") + 1]) if "--render" in ARGS else None
TUNING = Path(__file__).resolve().parents[2] / "game" / "data" / "tuning"


def tuning(file, key, default):
    """Een waarde uit game/data/tuning/<file>.cfg: een opschrift zegt wat het spel doet (ui2-08)."""
    try:
        for line in (TUNING / f"{file}.cfg").read_text(encoding="utf-8").splitlines():
            if line.split("=")[0].strip() == key:
                return float(line.split("=", 1)[1].strip())
    except OSError:
        pass
    return default

# --- Maten (docs/de-mol.md) -----------------------------------------------------------
HULL_W, HULL_H, HULL_CH = 4.8, 4.2, 0.9
HULL_Z0, HULL_Z1 = -3.8, 4.2
IN_W, IN_Y0, IN_Y1, IN_CH = 4.2, -1.5, 1.8, 0.75
FLOOR_LIFT = 0.008  # vloerplaat net boven de romp (geen gedeeld vlak)
IN_Z0 = -3.6
SHIELD_R, SHIELD_Z0, SHIELD_Z1 = 2.8, -5.4, -3.8
HEAD_R = 3.0
TRACK_LEN_Z0, TRACK_LEN_Z1, TRACK_R = -3.3, 3.7, 0.5
PORTHOLE_Y, PORTHOLE_R = 0.3, 0.55
RAMP_HINGE = (0.0, IN_Y0, HULL_Z1)


def track_frame(side):
    """Matrix van het lokale rupsframe (x dwars, y omhoog, z langs) naar Godot."""
    ang = math.radians(30.0 * side)
    c = Vector((1.30 * side, -2.25, 0.0))
    return c, ang


def tf(side, p):
    """Lokaal rupspunt → Godot-punt."""
    c, ang = track_frame(side)
    x, y, z = p
    rx = x * math.cos(ang) - y * math.sin(ang)
    ry = x * math.sin(ang) + y * math.cos(ang)
    return (c.x + rx, c.y + ry, z)


# ======================================================================================
# Romp
# ======================================================================================

def build_hull():
    hull = prism(octagon(HULL_W, HULL_H, HULL_CH), HULL_Z0, HULL_Z1, "Yellow", "Hull", bevel=0.0)
    # Binnenruimte uitsnijden (achteraan open voor de laadklep).
    # Binnenwanden donker grijsgroen (binnen-14: geen egaal verlichte crème doos; het licht komt
    # van een paar warme lampjes, de wanden vangen het op en vallen daartussen weg).
    inner = prism(octagon(IN_W, 0, IN_CH, IN_Y0, IN_Y1, cut_bottom=False), IN_Z0, HULL_Z1 + 0.5, "GreyGreen", "_cut", bevel=0.0)
    unregister(inner)
    boolean(hull, inner)
    # Patrijspoorten links en rechts, cabineramen.
    for s in (-1, 1):
        c = cyl(PORTHOLE_R, 1.2, (s * 2.3, PORTHOLE_Y, 0.0), "GreyGreen", "_cut", axis="x", verts=32, bevel=0.0)
        unregister(c)
        boolean(hull, c)
        w = box((1.2, 0.55, 0.9), (s * 2.3, 0.55, -2.7), "GreyGreen", "_cut", bevel=0.0)
        unregister(w)
        boolean(hull, w)
    m = hull.modifiers.new("Bevel", "BEVEL")
    m.width = 0.07
    m.segments = 3
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(30)

    # Tweekleurig: antraciet onderrand en bovenrand-strip.
    for s in (-1, 1):
        box((0.03, 0.62, HULL_Z1 - HULL_Z0 - 0.3), (s * (HULL_W / 2 + 0.012), -0.86, 0.2), "Anthracite", "Hull", bevel=0.01)
        box((0.03, 0.08, HULL_Z1 - HULL_Z0 - 0.3), (s * (HULL_W / 2 + 0.012), 0.98, 0.2), "Anthracite", "Hull", bevel=0.005)
    # Paneelnaden (verticaal), niet door de patrijspoort.
    for z in (-1.5, 1.4, 3.0):
        for s in (-1, 1):
            box((0.025, 2.3, 0.05), (s * (HULL_W / 2 + 0.01), 0.0, z), "Anthracite", "Hull", bevel=0.0)
    # Klinknagels langs de randen en rond de patrijspoorten.
    pts = []
    z = HULL_Z0 + 0.25
    while z < HULL_Z1 - 0.2:
        for s in (-1, 1):
            pts.append((s * (HULL_W / 2 + 0.01), 1.12, z))
            pts.append((s * (HULL_W / 2 + 0.01), -1.12, z))
        z += 0.42
    for s in (-1, 1):
        for k in range(10):
            a = k / 10 * math.tau
            pts.append((s * (HULL_W / 2 + 0.04), PORTHOLE_Y + math.sin(a) * 0.74, math.cos(a) * 0.74))
    rivets(pts, 0.045, "Steel", "Hull")

    # Patrijspoortkaders en cabineraamkaders.
    for s in (-1, 1):
        torus(0.62, 0.075, (s * (HULL_W / 2 + 0.02), PORTHOLE_Y, 0.0), "Anthracite", "Hull", axis="x", major_seg=36, minor_seg=10)
        torus(0.56, 0.035, (s * (HULL_W / 2 + 0.03), PORTHOLE_Y, 0.0), "Steel", "Hull", axis="x", major_seg=36, minor_seg=6)
        box((0.06, 0.08, 1.05), (s * (HULL_W / 2 + 0.02), 0.86, -2.7), "Anthracite", "Hull", bevel=0.02)
        box((0.06, 0.08, 1.05), (s * (HULL_W / 2 + 0.02), 0.24, -2.7), "Anthracite", "Hull", bevel=0.02)
        for zz in (-3.2, -2.2):
            box((0.06, 0.66, 0.08), (s * (HULL_W / 2 + 0.02), 0.55, zz), "Anthracite", "Hull", bevel=0.02)
        box((0.02, 0.06, 0.95), (s * (HULL_W / 2 + 0.03), 0.55, -2.7), "Anthracite", "Hull", bevel=0.0)  # raamstijl

    # Opschriften.
    for s in (-1, 1):
        rot = (0, 90 * s, 0)
        text("DIG", 0.6, (s * (HULL_W / 2 + 0.02), 0.5, 2.45), rot, "DecalDark", "Hull")  # de firma (woordenlijst)
        text("THE MOLE  M-01", 0.24, (s * (HULL_W / 2 + 0.02), 0.08, 2.45), rot, "DecalDark", "Hull")
        # Waarschuwingsbalk vooraan op de flank.
        box((0.02, 0.5, 0.9), (s * (HULL_W / 2 + 0.015), -0.25, -3.25), "Hazard", "Hull", bevel=0.0)
    # Sticker (louche firma).
    box((0.012, 0.32, 0.62), (HULL_W / 2 + 0.022, -0.32, 0.95), "DecalLight", "Hull", bevel=0.0, rot=(0, 0, 6))
    text("SAFETY FIRST?", 0.075, (HULL_W / 2 + 0.03, -0.30, 0.95), (6, 90, 0), "Red", "Hull")

    # Zijmarkeringslampjes langs de onderrand (silhouet in het donker), hydraulische leiding, roosters.
    for s in (-1, 1):
        for z in (-3.2, -1.8, -0.4, 1.0, 2.4, 3.8):
            box((0.05, 0.08, 0.16), (s * (HULL_W / 2 + 0.03), -1.32, z), "LensOrange", "Hull", bevel=0.015)
        tube([(s * (HULL_W / 2 + 0.07), 0.82, -3.5), (s * (HULL_W / 2 + 0.07), 0.82, 3.9)], 0.035, "Steel", "Hull", verts=8)
        for z in (-2.9, -1.0, 0.9, 2.8):
            box((0.1, 0.08, 0.06), (s * (HULL_W / 2 + 0.04), 0.82, z), "Anthracite", "Hull", bevel=0.01)
        for i in range(6):
            box((0.03, 0.05, 0.42), (s * (HULL_W / 2 + 0.02), -0.15 + i * 0.09, 3.65), "Anthracite", "Hull", bevel=0.0)

    # Brandstoftank links, gereedschapskist en slanghaspel rechts.
    cyl(0.3, 2.3, (-2.62, -0.78, 1.05), "Anthracite", "Hull", axis="z", verts=20, bevel=0.06, segments=3)
    for z in (0.3, 1.8):
        torus(0.31, 0.03, (-2.62, -0.78, z), "Steel", "Hull", axis="z", major_seg=20, minor_seg=6)
    cyl(0.09, 0.12, (-2.62, -0.45, 2.0), "Yellow", "Hull", verts=12)
    text("DIESEL", 0.11, (-2.93, -0.78, 1.05), (0, -90, 0), "DecalLight", "Hull")
    box((0.32, 0.42, 0.95), (2.6, -0.78, -1.45), "Red", "Hull", bevel=0.04)
    box((0.34, 0.06, 0.97), (2.6, -0.54, -1.45), "Anthracite", "Hull", bevel=0.01)
    cyl(0.3, 0.22, (2.55, -0.72, 1.45), "Anthracite", "Hull", axis="x", verts=20, bevel=0.03)
    torus(0.24, 0.07, (2.67, -0.72, 1.45), "Rubber", "Hull", axis="x", major_seg=20, minor_seg=8)

    # Achterkant: waarschuwingsbalken naast de opening, achterlichten, spatlappen, werklamp.
    for s in (-1, 1):
        box((0.22, 2.8, 0.03), (s * 2.24, 0.1, HULL_Z1 + 0.012), "Hazard", "Hull", bevel=0.0)
        box((0.2, 0.14, 0.06), (s * 2.16, -1.25, HULL_Z1 + 0.02), "LensRed", "Hull", bevel=0.02)
        box((0.7, 0.45, 0.04), (s * 1.38, -2.45, 3.98), "Rubber", "Hull", bevel=0.01, rot=(0, 0, 30 * s))
    box((0.5, 0.16, 0.16), (0.0, 2.0, HULL_Z1 + 0.06), "Anthracite", "Hull", bevel=0.03)
    box((0.42, 0.1, 0.03), (0.0, 1.98, HULL_Z1 + 0.15), "Lens", "Hull", bevel=0.01)


def build_shield():
    cyl(SHIELD_R, SHIELD_Z1 - SHIELD_Z0, (0, 0, (SHIELD_Z0 + SHIELD_Z1) / 2), "Yellow", "Hull", axis="z", verts=48, bevel=0.1, segments=3)
    cyl(SHIELD_R + 0.025, 0.36, (0, 0, SHIELD_Z0 + 0.22), "Hazard", "Hull", axis="z", verts=48, bevel=0.02)
    cyl(SHIELD_R + 0.03, 0.12, (0, 0, SHIELD_Z1 - 0.12), "Anthracite", "Hull", axis="z", verts=48, bevel=0.02)
    # Voorplaat van het schild (achter de boorkop) donker.
    cyl(SHIELD_R - 0.05, 0.05, (0, 0, SHIELD_Z0 - 0.01), "Anthracite", "Hull", axis="z", verts=48, bevel=0.0)
    pts = []
    for k in range(36):
        a = k / 36 * math.tau
        pts.append((math.cos(a) * (SHIELD_R + 0.03), math.sin(a) * (SHIELD_R + 0.03), SHIELD_Z1 - 0.32))
    rivets(pts, 0.05, "Steel", "Hull")
    # Hydraulische vijzels tussen schild en romp (boven en opzij).
    for a in (60, 120, 200, 340):
        r = math.radians(a)
        p0 = (math.cos(r) * 2.2, math.sin(r) * 2.0, SHIELD_Z1 - 0.1)
        p1 = (math.cos(r) * 2.05, math.sin(r) * 1.85, HULL_Z0 + 1.1)
        tube([p0, p1], 0.09, "Steel", "Hull", verts=12)
        tube([p0, ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2)], 0.13, "Anthracite", "Hull", verts=12)


def build_roof():
    top = HULL_H / 2
    # Motorblok achteraan op het dak.
    box((2.0, 0.6, 2.5), (0, top + 0.3, 2.75), "Anthracite", "Hull", bevel=0.1, segments=3)
    box((1.7, 0.08, 2.2), (0, top + 0.62, 2.75), "DarkSteel", "Hull", bevel=0.03)
    for i in range(7):  # koelribben achteraan
        box((1.6, 0.04, 0.06), (0, top + 0.12 + i * 0.065, 4.02), "DarkSteel", "Hull", bevel=0.0)
    for s in (-1, 1):  # zijroosters
        for i in range(5):
            box((0.03, 0.32, 0.06), (s * 1.01, top + 0.3, 1.9 + i * 0.2), "DarkSteel", "Hull", bevel=0.0)
    # Twee uitlaten met regenkleppen.
    # Alles bovenop blijft binnen de tunnel (straal 3,15 m vanaf de as).
    for s in (-1, 1):
        cyl(0.11, 0.42, (s * 0.55, top + 0.69, 1.85), "Steel", "Hull", verts=16, bevel=0.02)
        cyl(0.14, 0.1, (s * 0.55, top + 0.55, 1.85), "Anthracite", "Hull", verts=16, bevel=0.02)
        box((0.26, 0.03, 0.24), (s * 0.55, top + 0.93, 1.8), "DarkSteel", "Hull", bevel=0.01, rot=(-20, 0, 0))
    cyl(0.2, 0.28, (0.0, top + 0.72, 3.55), "Yellow", "Hull", verts=20, bevel=0.04)  # luchtfilter
    cyl(0.22, 0.05, (0.0, top + 0.88, 3.55), "Anthracite", "Hull", verts=20, bevel=0.02)
    # Dakplaat, luik, zwaailichten, werklampen, antenne.
    box((2.6, 0.05, 4.6), (0, top + 0.025, -1.2), "DarkSteel", "Hull", bevel=0.02)
    cyl(0.42, 0.08, (0, top + 0.08, -0.6), "Yellow", "Hull", verts=28, bevel=0.03)
    torus(0.18, 0.025, (0, top + 0.16, -0.6), "Steel", "Hull", axis="x", major_seg=16, minor_seg=6)
    for s in (-1, 1):
        cyl(0.13, 0.12, (s * 1.0, top + 0.08, -3.2), "Anthracite", "Hull", verts=20, bevel=0.02)
        sphere(0.13, (s * 1.0, top + 0.16, -3.2), "LensOrange", "Hull", scale=(1, 1.1, 1), segments=16, rings=8)
        box((0.36, 0.22, 0.18), (s * 1.25, top + 0.2, -3.55), "Anthracite", "Hull", bevel=0.04, rot=(10, 25 * s, 0))
        box((0.3, 0.16, 0.03), (s * 1.27, top + 0.2, -3.65), "Lens", "Hull", bevel=0.01, rot=(10, 25 * s, 0))
    cyl(0.02, 0.7, (-0.85, top + 0.4, 3.75), "DarkSteel", "Hull", verts=8, bevel=0.0)
    sphere(0.045, (-0.85, top + 0.76, 3.75), "Red", "Hull", segments=8, rings=4)
    # Lichtbalk vooraan over het dak.
    box((1.7, 0.12, 0.16), (0, top + 0.18, -3.62), "Anthracite", "Hull", bevel=0.03)
    for i in range(4):
        x = -0.6 + i * 0.4
        box((0.26, 0.1, 0.03), (x, top + 0.18, -3.71), "Lens", "Hull", bevel=0.01)
    for s in (-1, 1):
        box((0.06, 0.2, 0.06), (s * 0.8, top + 0.08, -3.62), "Anthracite", "Hull", bevel=0.01)
    # Lier met kabel en haak (voor de latere lier-upgrade), voor het motorblok.
    cyl(0.22, 0.9, (0, top + 0.27, 1.0), "Yellow", "Hull", axis="x", verts=20, bevel=0.03)
    cyl(0.17, 0.92, (0, top + 0.27, 1.0), "DarkSteel", "Hull", axis="x", verts=20, bevel=0.0)
    for s in (-1, 1):
        box((0.08, 0.42, 0.42), (s * 0.5, top + 0.22, 1.0), "Anthracite", "Hull", bevel=0.03)
    torus(0.08, 0.02, (0, top + 0.2, 0.68), "Steel", "Hull", axis="x", major_seg=12, minor_seg=6)
    # Vastgesjorde kisten op het dak.
    for (x, z, sz) in ((-0.75, -1.9, 0.48), (-0.72, -1.4, 0.38), (0.78, -2.3, 0.44)):
        box((sz, sz * 0.8, sz), (x, top + 0.05 + sz * 0.4, z), "Wood", "Hull", bevel=0.03)
        box((sz + 0.02, sz * 0.82, 0.04), (x, top + 0.05 + sz * 0.4, z), "Yellow", "Hull", bevel=0.005)


def build_tracks():
    """Rupsframes (vast) en wielen (draaien). De schakels legt de game langs het pad."""
    zf, zr = TRACK_LEN_Z0 + TRACK_R, TRACK_LEN_Z1 - TRACK_R
    for side in (-1, 1):
        L = "L" if side < 0 else "R"
        # Binnen- en buitenplaat.
        for sx in (-0.38, 0.38):
            prism_pts = []
            box((0.06, 0.55, zr - zf + 0.2), tf(side, (sx, 0.0, (zf + zr) / 2)), "Anthracite", "Hull", bevel=0.03,
                rot=(0, 0, 30 * side))
        # Bovenste kap over de rups (geel) met rubberen rand.
        box((0.95, 0.1, zr - zf + 0.9), tf(side, (0.0, 0.62, (zf + zr) / 2)), "Yellow", "Hull", bevel=0.04, rot=(0, 0, 30 * side))
        # Wielen: aandrijving achter, spanwiel voor, 5 loopwielen onderaan.
        wheels = [(zr, TRACK_R - 0.06, True), (zf, TRACK_R - 0.08, False)]
        for i in range(5):
            wheels.append((zf + 0.55 + i * (zr - zf - 1.1) / 4, 0.33, False))
        for i, (z, r, sprocket) in enumerate(wheels):
            y = 0.0 if i < 2 else -TRACK_R + r + 0.02
            group = f"Wheel_{L}_{i}"
            center = tf(side, (0.0, y, z))
            cyl(r, 0.5, center, "DarkSteel", group, axis="x", verts=24, bevel=0.03, rot=(0, 0, 90 + 30 * side))
            cyl(r * 0.55, 0.56, center, "Yellow", group, axis="x", verts=16, bevel=0.02, rot=(0, 0, 90 + 30 * side))
            for k in range(6):  # bouten op de naaf
                a = k / 6 * math.tau
                p = tf(side, (0.29 * (1 if side > 0 else -1), y + math.sin(a) * r * 0.32, z + math.cos(a) * r * 0.32))
                sphere(0.025, p, "Steel", group, segments=6, rings=3)
            if sprocket:
                for k in range(12):
                    a = k / 12 * math.tau
                    p = tf(side, (0.0, y + math.sin(a) * (r + 0.04), z + math.cos(a) * (r + 0.04)))
                    box((0.3, 0.1, 0.1), p, "DarkSteel", group, bevel=0.02, rot=(math.degrees(-a), 0, 30 * side))
            PARTS[group + "_center"] = [center]

    # Eén rupsschakel (lokaal: x dwars, y = buitenkant, z = langs), oorsprong in het midden.
    box((0.86, 0.07, 0.17), (0, 0, 0), "DarkSteel", "TrackLink", bevel=0.015)
    box((0.86, 0.05, 0.05), (0, 0.055, 0.02), "DarkSteel", "TrackLink", bevel=0.012)
    box((0.12, 0.05, 0.12), (0, -0.05, 0), "Steel", "TrackLink", bevel=0.01)


# ======================================================================================
# Boorkop en naaf
# ======================================================================================

def tooth(base, direction, length=0.22, width=0.09, material="Steel", group="DrillHead"):
    """Vierkante piramide (snijtand) vanaf `base` in `direction` (Godot)."""
    d = Vector(direction).normalized()
    side = d.cross(Vector((0, 1, 0)))
    if side.length < 1e-3:
        side = d.cross(Vector((1, 0, 0)))
    side.normalize()
    up = side.cross(d).normalized()
    b = Vector(base)
    corners = [b + side * width / 2 + up * width / 2, b - side * width / 2 + up * width / 2,
               b - side * width / 2 - up * width / 2, b + side * width / 2 - up * width / 2]
    tip = b + d * length
    bm = bmesh.new()
    vs = [bm.verts.new(G(*c)) for c in corners]
    vt = bm.verts.new(G(*tip))
    bm.faces.new(vs)
    for i in range(4):
        bm.faces.new([vs[i], vs[(i + 1) % 4], vt])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("tooth")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("tooth", me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat(material))
    PARTS.setdefault(group, []).append(o)
    return o


# Kegel van de boorkop: brede voet achteraan, smalle punt vooraan.
CONE_BASE_R, CONE_BASE_Z = 2.95, -5.72
CONE_TIP_R, CONE_TIP_Z = 0.62, -7.45


def cone_point(t, angle, lift=0.0):
    """Punt op het kegeloppervlak (t=0 punt, t=1 voet), `lift` meter naar buiten langs de normaal."""
    r = CONE_TIP_R + (CONE_BASE_R - CONE_TIP_R) * t
    z = CONE_TIP_Z + (CONE_BASE_Z - CONE_TIP_Z) * t
    dr, dz = CONE_BASE_R - CONE_TIP_R, CONE_BASE_Z - CONE_TIP_Z
    n = Vector((dz, -dr)).normalized()  # (radiaal, z): naar buiten en naar voren
    if n.x < 0:
        n = -n
    r += n.x * lift
    z += n.y * lift if n.y < 0 else -n.y * lift
    return (math.cos(angle) * r, math.sin(angle) * r, z)


def build_drill_head():
    g = "DrillHead"
    # Voetplaat en kegel (gebouwd als prisma van ringen, zodat de punt zeker vooraan zit).
    cyl(HEAD_R, 0.3, (0, 0, -5.57), "DarkSteel", g, axis="z", verts=48, bevel=0.06, segments=3)
    bm = bmesh.new()
    seg = 48
    rings = []
    for t in (0.0, 1.0):
        ring = []
        for k in range(seg):
            a = k / seg * math.tau
            ring.append(bm.verts.new(G(*cone_point(t, a))))
        rings.append(ring)
    for k in range(seg):
        j = (k + 1) % seg
        bm.faces.new([rings[0][k], rings[0][j], rings[1][j], rings[1][k]])
    bm.faces.new(list(reversed(rings[0])))
    # Open mesh: normalen expliciet naar buiten zetten (weg van de as = Blender-Y, en de punt naar voren).
    for f in bm.faces:
        c = f.calc_center_median()
        f.normal_update()
        out = Vector((c.x, 0.0, c.z))
        if len(f.verts) > 4:
            out = Vector((0.0, 1.0, 0.0))  # dop op de punt wijst vooruit (Godot −z = Blender +y)
        if f.normal.dot(out) < 0:
            f.normal_flip()
    me = bpy.data.meshes.new("cone")
    bm.to_mesh(me)
    bm.free()
    cone = bpy.data.objects.new("cone", me)
    bpy.context.collection.objects.link(cone)
    cone.data.materials.append(mat("CutterSteel"))
    for p in cone.data.polygons:
        p.use_smooth = True
    PARTS.setdefault(g, []).append(cone)

    # Drie spiraalribben (zoals een boorpunt), geel, met tanden.
    turns = 3.4  # radialen dat een rib draait van punt tot voet
    for k in range(3):
        a0 = k / 3 * math.tau
        pts = []
        steps = 22
        for i in range(steps + 1):
            t = 0.04 + 0.95 * i / steps
            pts.append(cone_point(t, a0 + turns * (1 - t), lift=0.13))
        sweep(pts, 0.32, 0.3, "Yellow", g, up=(0, 0, -1), bevel=0.05)
        for i in range(2, steps + 1, 2):
            t = 0.04 + 0.95 * i / steps
            a = a0 + turns * (1 - t)
            base = cone_point(t, a, lift=0.26)
            outward = Vector((math.cos(a), math.sin(a), 0.0))
            tangent = Vector((-math.sin(a), math.cos(a), 0.0))
            d = outward * 0.45 + tangent * 0.35 + Vector((0, 0, -1.0))
            tooth(base, d, length=0.3, width=0.12)
    # Tanden rond de voet.
    for k in range(30):
        a = k / 30 * math.tau
        base = (math.cos(a) * 2.9, math.sin(a) * 2.9, -5.74)
        tooth(base, (math.cos(a) * 0.55, math.sin(a) * 0.55, -1.0), length=0.27, width=0.12)
    # Kraag rond de voet (gebouten).
    torus(2.93, 0.06, (0, 0, -5.42), "Steel", g, axis="z", major_seg=48, minor_seg=6)


def build_hub():
    g = "Hub"
    z0 = CONE_TIP_Z
    cyl(0.62, 0.42, (0, 0, z0 - 0.1), "Anthracite", g, axis="z", verts=32, bevel=0.06, segments=3)
    cyl(0.56, 0.08, (0, 0, z0 - 0.33), "Yellow", g, axis="z", verts=32, bevel=0.02)
    for k in range(6):  # lichtring
        a = k / 6 * math.tau + math.pi / 6
        cyl(0.07, 0.06, (math.cos(a) * 0.39, math.sin(a) * 0.39, z0 - 0.39), "Lens", g, axis="z", verts=12, bevel=0.0)
    cyl(0.12, 0.1, (0, 0, z0 - 0.4), "Screen", g, axis="z", verts=20, bevel=0.0)  # cameralens
    torus(0.14, 0.024, (0, 0, z0 - 0.43), "Steel", g, axis="z", major_seg=20, minor_seg=6)


# ======================================================================================
# Laadklep
# ======================================================================================

def build_ramp():
    g = "Ramp"
    z0, z1 = HULL_Z1 - 0.06, HULL_Z1 + 0.1
    prism(octagon(IN_W - 0.06, 0, IN_CH, IN_Y0 + 0.02, IN_Y1 - 0.02, cut_bottom=False), z0, z1, "Yellow", g, bevel=0.03)
    # Buitenkant: waarschuwingsrand en opschrift.
    for x in (-1.92, 1.92):
        box((0.18, 2.6, 0.02), (x, 0.0, z1 + 0.005), "Hazard", g, bevel=0.0)
    text("THE MOLE", 0.62, (0, 0.55, z1 + 0.012), (0, 0, 0), "DecalDark", g)
    text("DIG  ·  M-01", 0.16, (0, -0.1, z1 + 0.012), (0, 0, 0), "DecalDark", g)
    box((1.2, 0.08, 0.03), (0, -0.55, z1 + 0.01), "Anthracite", g, bevel=0.01)
    # Binnenkant: antislipribben (worden treden als hij open ligt).
    y = IN_Y0 + 0.3
    while y < IN_Y1 - 0.5:
        box((IN_W - 0.5, 0.05, 0.05), (0, y, z0 - 0.02), "Anthracite", g, bevel=0.01)
        y += 0.32
    # Scharnieren.
    for x in (-1.6, -0.5, 0.5, 1.6):
        cyl(0.07, 0.36, (x, IN_Y0 + 0.02, HULL_Z1 + 0.02), "Steel", g, axis="x", verts=12, bevel=0.01)


# ======================================================================================
# Slijtage buiten (release-audit binnen-12, ronde 2: "de Mol is nog schoon")
# ======================================================================================
# Zoals de hub (pakket A2: vuil onderaan, strepen, krassen, roet) maar voor een machine die door klei
# en rots boort: opgespat stof en modder van onderen (dicht bij de rupsen, dun naar boven), een korst
# op het schild achter de boorkop, roet rond de uitlaten, strepen onder de nagelrij en de patrijspoort,
# krassen en afgesprongen verf waar hij langs de tunnelwand schuurt. Platte, grillige vlekjes net boven
# de romp (scherpe randen, zoals de rest: gestileerd, geen texturen). Silhouet en binnenkant blijven.

kit.PALETTE.setdefault("Rock", ((0.42, 0.37, 0.33), 0.0, 0.92, None))  # opgedroogde modder (MolVisual.MATS)
# Fijn boorstof: lichter en warmer dan "Rock" (ook in MolVisual.MATS: een naam die de game niet kent,
# krijgt het ruwe glb-materiaal, en dat kleurt met de slijtage-vertexkleur blauw).
kit.PALETTE.setdefault("Dust", ((0.5, 0.42, 0.33), 0.0, 1.0, None))
WEAR_SEED = 2026


def _wear_poly(uv, origin, u, v, n, material, group):
    """Vlakke n-hoek: punten (a, b) in het vlak origin + u·a + v·b (Godot-vectoren), voorkant naar n."""
    bm = bmesh.new()
    vs = [bm.verts.new(G(*(origin + u * a + v * b))) for a, b in uv]
    f = bm.faces.new(vs)
    f.normal_update()
    if f.normal.dot(G(*n)) < 0.0:
        f.normal_flip()
    me = bpy.data.meshes.new("Wear")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("Wear", me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat(material))
    PARTS.setdefault(group, []).append(o)


def smoothstep_py(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _blob(rng, r, k=10):
    """Grillige vlek (r = straal): punten rond, met uitlopers."""
    raw = [r * (0.6 + 0.6 * rng.random()) for _ in range(k)]
    rad = [(raw[i - 1] + 2 * raw[i] + raw[(i + 1) % k]) / 4 for i in range(k)]
    return [(math.cos(i / k * math.tau) * rad[i], math.sin(i / k * math.tau) * rad[i]) for i in range(k)]


def _splat(rng, origin, u, v, n, r, material, group, drops=True):
    """Een vlek met een paar spatjes errond."""
    _wear_poly(_blob(rng, r), origin, u, v, n, material, group)
    if drops:
        for _ in range(rng.randint(0, 3)):
            a = rng.random() * math.tau
            d = r * rng.uniform(1.3, 2.2)
            o2 = origin + u * (math.cos(a) * d) + v * (math.sin(a) * d)
            _wear_poly(_blob(rng, r * rng.uniform(0.15, 0.35), 7), o2, u, v, n, material, group)


def _streak(rng, origin, u, v, n, w, length, material, group):
    """Streep die naar beneden (−v) uitloopt en smaller wordt."""
    _wear_poly([(-w / 2, 0), (w / 2, 0), (w * 0.12, -length), (-w * 0.12, -length)], origin, u, v, n, material, group)


def _line(origin, u, v, n, length, w, angle, material, group):
    """Dunne kras van `length` m onder een hoek (rad) in het vlak."""
    c, s = math.cos(angle), math.sin(angle)
    pts = [(-length / 2 * c - w / 2 * -s, -length / 2 * s - w / 2 * c), (length / 2 * c - w / 2 * -s, length / 2 * s - w / 2 * c),
           (length / 2 * c + w / 2 * -s, length / 2 * s + w / 2 * c), (-length / 2 * c + w / 2 * -s, -length / 2 * s + w / 2 * c)]
    _wear_poly(pts, origin, u, v, n, material, group)


def build_weathering():
    import random
    rng = random.Random(WEAR_SEED)
    V = Vector
    up = V((0, 1, 0))
    along = V((0, 0, 1))
    for s in (-1, 1):
        n = (s, 0, 0)
        side = V((s * (HULL_W / 2 + 0.006), 0, 0))
        band = V((s * (HULL_W / 2 + 0.033), 0, 0))
        # Een korst stof op de donkere onderband: een grillige rand over de hele lengte.
        k = 48
        top = []
        for i in range(k + 1):
            z = HULL_Z0 + 0.12 + (HULL_Z1 - HULL_Z0 - 0.24) * i / k
            end = 1.0 if (z < -2.6 or z > 2.9) else 0.0
            top.append((z, -1.14 + 0.1 + 0.16 * rng.random() + 0.2 * end * rng.random()))
        pts = [(HULL_Z1 - 0.12, -1.16), (HULL_Z0 + 0.12, -1.16)] + top
        _wear_poly([(b, a) for a, b in pts], band, up, along, n, "Dust", "Hull")
        # Een stofrand op het geel vlak boven de onderband (hoger vooraan en achteraan), en daarboven
        # opgespatte spikkels: veel en klein onderaan, schaars naar boven. Enkele grotere spatten bij de
        # uiteinden, waar de rupsen en de boorkop het meeste opgooien.
        k = 60
        rim = []
        for i in range(k + 1):
            z = HULL_Z0 + 0.12 + (HULL_Z1 - HULL_Z0 - 0.24) * i / k
            end = max(smoothstep_py(-1.8, -3.4, z), smoothstep_py(2.4, 3.9, z))
            rim.append((z, -0.5 + 0.04 + 0.1 * rng.random() ** 2 + 0.45 * end * (0.5 + 0.5 * rng.random())))
        pts = [(HULL_Z1 - 0.12, -0.56), (HULL_Z0 + 0.12, -0.56)] + rim
        _wear_poly([(b, a) for a, b in pts], side, up, along, n, "Dust", "Hull")
        for _ in range(260):
            z = rng.uniform(HULL_Z0 + 0.12, HULL_Z1 - 0.12)
            end = max(smoothstep_py(-1.8, -3.4, z), smoothstep_py(2.4, 3.9, z))
            y = -0.45 + 0.4 * end + (-math.log(max(rng.random(), 1e-3))) * (0.1 + 0.12 * end)
            if y > 1.05 or (abs(z) < 0.8 and abs(y - PORTHOLE_Y) < 0.8) or (-3.25 < z < -2.15 and 0.2 < y < 0.9):
                continue
            if 1.3 < z < 3.75 and y > -0.05:  # het opschrift blijft leesbaar
                continue
            r = 0.008 + 0.03 * rng.random() ** 2
            _wear_poly(_blob(rng, r, 7), side + V((0, y, z)), along, up, n, "Dust" if rng.random() < 0.85 else "Rock", "Hull")
        for _ in range(8):
            z = rng.choice((rng.uniform(HULL_Z0 + 0.2, -2.6), rng.uniform(2.9, HULL_Z1 - 0.2)))
            y = rng.uniform(-0.35, 0.05)
            _splat(rng, side + V((0, y, z)), along, up, n, rng.uniform(0.05, 0.1), "Dust", "Hull", drops=True)
        # De onderste schuine flank (vlak boven de rups): het vuilst, bijna helemaal onder het stof.
        p_top = V((s * HULL_W / 2, -(HULL_H / 2 - HULL_CH), 0))
        p_bot = V((s * (HULL_W / 2 - HULL_CH), -HULL_H / 2, 0))
        vdn = (p_bot - p_top).normalized()
        cn = V((s * 0.7071, -0.7071, 0))
        o_ch = p_top + cn * 0.008
        width = (p_bot - p_top).length
        k = 56
        edge_pts = []
        for i in range(k + 1):
            z = HULL_Z0 + 0.1 + (HULL_Z1 - HULL_Z0 - 0.2) * i / k
            edge_pts.append((z, 0.06 + 0.32 * rng.random() ** 1.5))
        poly = [(HULL_Z1 - 0.1, width - 0.05), (HULL_Z0 + 0.1, width - 0.05)] + edge_pts
        _wear_poly(poly, o_ch, along, vdn, tuple(cn), "Dust", "Hull")
        for _ in range(40):
            z = rng.uniform(HULL_Z0 + 0.1, HULL_Z1 - 0.1)
            d = rng.uniform(0.0, 0.12)
            _wear_poly(_blob(rng, rng.uniform(0.01, 0.035), 7), o_ch + along * z + vdn * d, along, vdn, tuple(cn), "Dust", "Hull")
        # Strepen onder de bovenste nagelrij en onder de patrijspoort (roest en vuil dat uitzakt).
        for _ in range(9):
            z = rng.uniform(HULL_Z0 + 0.3, HULL_Z1 - 0.3)
            if 1.3 < z < 3.75:
                continue
            _streak(rng, side + V((0, 1.09, z)), along, up, n, rng.uniform(0.025, 0.05), rng.uniform(0.25, 0.8), "Soot", "Hull")
        for dz in (-0.25, 0.18):
            _streak(rng, side + V((0, PORTHOLE_Y - 0.66, dz)), along, up, n, rng.uniform(0.04, 0.06), rng.uniform(0.35, 0.55),
                    "RedOxide", "Hull")
        # Krassen vooraan (waar hij langs de tunnelwand schuurt) en afgesprongen verf langs de randen.
        for _ in range(14):
            z = rng.uniform(HULL_Z0 + 0.2, -1.6)
            y = rng.choice((rng.uniform(0.88, 1.14), rng.uniform(-0.45, 0.12)))
            if -3.25 < z < -2.15 and 0.2 < y < 0.9:
                continue
            _line(side + V((0, y, z)), along, up, n, rng.uniform(0.18, 0.6), 0.012, rng.uniform(-0.3, 0.3), "Steel", "Hull")
        for _ in range(26):
            edge = rng.choice(("front", "back", "top"))
            if edge == "front":
                z, y = HULL_Z0 + rng.uniform(0.03, 0.12), rng.uniform(-0.5, 1.15)
            elif edge == "back":
                z, y = HULL_Z1 - rng.uniform(0.03, 0.12), rng.uniform(-0.5, 1.15)
            else:
                z, y = rng.uniform(HULL_Z0 + 0.2, HULL_Z1 - 0.2), 1.17 - rng.uniform(0.0, 0.05)
            _wear_poly(_blob(rng, rng.uniform(0.015, 0.05), 7), side + V((0, y, z)), along, up, n, "DarkSteel", "Hull")
        # Rupskap: stof op de gele kap boven de rups (schuin, in het rupsframe).
        nrm = V(tf(s, (0.0, 1.0, 0.0))) - V(tf(s, (0.0, 0.0, 0.0)))
        tx = V(tf(s, (1.0, 0.0, 0.0))) - V(tf(s, (0.0, 0.0, 0.0)))
        for _ in range(26):
            z = rng.uniform(TRACK_LEN_Z0 + 0.2, TRACK_LEN_Z1 - 0.2)
            x = rng.uniform(-0.4, 0.4)
            o = V(tf(s, (x, 0.675, z)))
            _splat(rng, o, tx, along, tuple(nrm), rng.uniform(0.03, 0.1), "Dust", "Hull", drops=False)

    # Het schild achter de boorkop: een korst boorstof vooraan, over de onderste helft, met een grillige
    # rand naar achteren en spikkels erachter.
    R = SHIELD_R + 0.04
    n_seg = 40
    a0, a1 = math.radians(-200), math.radians(20)
    for i in range(n_seg):
        aa, ab = a0 + (a1 - a0) * i / n_seg, a0 + (a1 - a0) * (i + 1) / n_seg
        lowa = 0.5 - 0.5 * math.sin((aa + ab) / 2)  # 1 onderaan, 0 bovenaan
        za = SHIELD_Z0 + 0.06
        zb = za + 0.15 + 0.55 * lowa * (0.6 + 0.4 * rng.random())
        quad = [V((math.cos(aa) * R, math.sin(aa) * R, za)), V((math.cos(ab) * R, math.sin(ab) * R, za)),
                V((math.cos(ab) * R, math.sin(ab) * R, zb)), V((math.cos(aa) * R, math.sin(aa) * R, zb))]
        mid = (quad[0] + quad[2]) * 0.5
        nn = V((mid.x, mid.y, 0)).normalized()
        _wear_poly([(0, 0), (1, 0), (1, 1), (0, 1)], quad[0], quad[1] - quad[0], quad[3] - quad[0], tuple(nn), "Dust", "Hull")
    for _ in range(140):
        a = rng.uniform(a0, a1)
        lowa = 0.5 - 0.5 * math.sin(a)
        z = SHIELD_Z0 + 0.2 + 0.6 * lowa + (-math.log(max(rng.random(), 1e-3))) * 0.25
        if z > SHIELD_Z1 - 0.08:
            continue
        o = V((math.cos(a) * R, math.sin(a) * R, z))
        t = V((-math.sin(a), math.cos(a), 0))
        _wear_poly(_blob(rng, 0.01 + 0.035 * rng.random() ** 2, 7), o, t, along, (math.cos(a), math.sin(a), 0),
                   "Dust" if rng.random() < 0.85 else "Rock", "Hull")

    # Achterkant: stof dat de rupsen opgooien, op de waarschuwingsbalken naast de opening en op de
    # strook onder de klep (niet in de opening zelf: daar is geen romp).
    for _ in range(40):
        if rng.random() < 0.6:
            x = rng.choice((-1, 1)) * rng.uniform(2.14, 2.34)
            y = -1.3 + (-math.log(max(rng.random(), 1e-3))) * 0.35
            if y > 0.6:
                continue
        else:
            x = rng.uniform(-1.4, 1.4)
            y = rng.uniform(-2.0, -1.6)
        _splat(rng, V((x, y, HULL_Z1 + 0.035)), V((1, 0, 0)), up, (0, 0, 1), rng.uniform(0.015, 0.06), "Dust", "Hull", drops=False)
    for _ in range(30):
        x = rng.uniform(-1.9, 1.9)
        y = IN_Y0 + 0.08 + rng.random() ** 2 * 0.7
        _splat(rng, V((x, y, HULL_Z1 + 0.108)), V((1, 0, 0)), up, (0, 0, 1), rng.uniform(0.02, 0.08), "Dust", "Ramp", drops=True)

    # Dak: roet rond de uitlaten (naar achteren uitgewaaid), stof in de hoeken van de dakplaat.
    top = HULL_H / 2
    for sx in (-1, 1):
        o = V((sx * 0.55, top + 0.766, 1.95))
        _wear_poly([(a * 1.3, b * 0.8 + 0.12) for a, b in _blob(rng, 0.2, 12)], o, V((1, 0, 0)), along, (0, 1, 0), "Soot", "Hull")
    for _ in range(18):
        x = rng.choice((-1, 1)) * rng.uniform(0.6, 1.25)
        z = rng.uniform(-3.4, 0.9)
        _splat(rng, V((x, top + 0.056, z)), V((1, 0, 0)), along, (0, 1, 0), rng.uniform(0.05, 0.16), "Dust", "Hull", drops=False)
    # Stencils (nieuwe tekst in het Engels).
    for s in (-1, 1):
        text("KEEP CLEAR", 0.085, (s * (HULL_W / 2 + 0.02), 0.08, -3.25), (0, 90 * s, 0), "DecalDark", "Hull")
    text("NO STEP", 0.11, (0.0, top + 0.068, -2.2), (-90, 0, 0), "DecalDark", "Hull")


# ======================================================================================
# Binnen
# ======================================================================================

def inner_profile_points(inset=0.06):
    hw = IN_W / 2 - inset
    top = IN_Y1 - inset
    ch = IN_CH
    return [(-hw, IN_Y0), (-hw, top - ch), (-hw + ch, top), (hw - ch, top), (hw, top - ch), (hw, IN_Y0)]


def build_interior():
    g = "Interior"
    length = HULL_Z1 - IN_Z0
    zc = (IN_Z0 + HULL_Z1) / 2
    # Vloerplaat 8 mm boven de uitgesneden romp: op hetzelfde vlak flikkert hij (z-fighting).
    box((IN_W - 0.02, 0.06, length - 0.02), (0, IN_Y0 - 0.03 + FLOOR_LIFT, zc), "Floor", g, bevel=0.0)
    # Spanten.
    for z in (-2.95, -1.6, 1.6, 3.05):
        sweep([(x, y, z) for x, y in inner_profile_points()], 0.14, 0.1, "Anthracite", g, up=(0, 0, 1), bevel=0.02)
    # Leidingen langs het plafond met beugels.
    for x, r, m in ((-1.05, 0.055, "Copper"), (-0.85, 0.04, "Red"), (1.0, 0.05, "Blue")):
        tube([(x, 1.55, IN_Z0 + 0.1), (x, 1.55, HULL_Z1 - 0.2)], r, m, g, verts=10)
        for z in (-2.95, -1.6, 1.6, 3.05):
            box((0.1, 0.18, 0.04), (x, 1.62, z), "Anthracite", g, bevel=0.01)
    # Kooilampen.
    for i, z in enumerate((-2.35, 0.0, 2.9)):
        cyl(0.12, 0.07, (0, IN_Y1 - 0.08, z), "Anthracite", g, verts=16, bevel=0.01)
        sphere(0.085, (0, IN_Y1 - 0.24, z), "Bulb", g, segments=12, rings=6)
        torus(0.12, 0.012, (0, IN_Y1 - 0.24, z), "Anthracite", g, axis="y", major_seg=16, minor_seg=4)
        torus(0.12, 0.012, (0, IN_Y1 - 0.24, z), "Anthracite", g, axis="x", major_seg=16, minor_seg=4)
        torus(0.12, 0.012, (0, IN_Y1 - 0.24, z), "Anthracite", g, axis="z", major_seg=16, minor_seg=4)

    build_cockpit(g)
    build_living(g)
    build_cargo(g)
    build_homely(g)


# Bedieningsconsole: een paneel dat DESK_TILT graden naar de bestuurder kantelt, van wand tot wand.
DESK_TILT = 35.0
DESK_C = (0.0, -0.5, -3.06)  # midden van het paneel
DESK_DEPTH = 0.82
_ta = math.radians(DESK_TILT)
DESK_N = (0.0, math.cos(_ta), math.sin(_ta))  # normaal: omhoog en naar de bestuurder
DESK_A = (0.0, math.sin(_ta), -math.cos(_ta))  # langs het paneel omhoog, weg van de bestuurder
DESK_ROT = (DESK_TILT, 0, 0)  # onderdeel evenwijdig met het paneel (lokale y = normaal)
DESK_TEXT = (DESK_TILT - 90.0, 0, 0)  # tekst die op het paneel ligt en naar de bestuurder leest
GAUGES = (-0.4, 0.0, 0.4)
BTN_AUTO = (-1.38, -1.1, -0.82)
BTN_RAMP_U, BTN_LIGHTS_U, BTN_HORN_U, LEVER_U = 0.64, 0.9, 1.16, 1.44


def desk(u, v, h=0.0):
    """Punt op het paneel: u = opzij, v = langs de helling (+ = verder weg), h = boven het paneel."""
    return (DESK_C[0] + u, DESK_C[1] + v * DESK_A[1] + h * DESK_N[1], DESK_C[2] + v * DESK_A[2] + h * DESK_N[2])


def desk_label(body, u, v, size=0.05, material="DecalLight", g="Interior"):
    text(body, size, desk(u, v, 0.036), DESK_TEXT, material, g, extrude=0.003)


def build_cockpit(g):
    w = IN_W - 0.04
    # Console: schuin paneel, voorschort en achterwand, van wand tot wand.
    box((w, 0.07, DESK_DEPTH), DESK_C, "Anthracite", g, bevel=0.025, rot=DESK_ROT)
    front = desk(0, -DESK_DEPTH / 2)
    box((w, front[1] - IN_Y0, 0.06), (0, (front[1] + IN_Y0) / 2, front[2] - 0.03), "Anthracite", g, bevel=0.02)
    back = desk(0, DESK_DEPTH / 2)
    box((w, back[1] - IN_Y0 + 0.02, 0.14), (0, (back[1] + IN_Y0) / 2, back[2] - 0.07), "Anthracite", g, bevel=0.03)
    # Rand en schroeven op het paneel.
    for v in (-DESK_DEPTH / 2 + 0.02, DESK_DEPTH / 2 - 0.02):
        box((w - 0.04, 0.02, 0.025), desk(0, v, 0.04), "Steel", g, bevel=0.005, rot=DESK_ROT)
    for u in (-1.95, -0.62, 0.62, 1.95):
        for v in (-0.33, 0.33):
            cyl(0.014, 0.012, desk(u, v, 0.04), "Steel", g, verts=8, bevel=0.0, rot=DESK_ROT)
    # Hazardstrook langs de voorrand.
    box((w - 0.1, 0.012, 0.05), desk(0, -DESK_DEPTH / 2 + 0.06, 0.036), "Hazard", g, bevel=0.0, rot=DESK_ROT)

    # Groot camerascherm (het scherm zelf is het object Monitor).
    box((2.0, 1.15, 0.12), (0, 0.55, -3.52), "Anthracite", g, bevel=0.04, segments=3)
    # Statusscherm links; rechts de sonar (build_sonar).
    box((0.75, 0.5, 0.08), (-1.45, 0.35, -3.38), "Anthracite", g, bevel=0.03, rot=(0, 22, 0))
    box((0.65, 0.4, 0.02), (-1.44, 0.35, -3.33), "Screen", g, bevel=0.0, rot=(0, 22, 0))
    build_sonar(g)

    # Meters: diepte, snelheid, brandstof. De naalden zijn aparte objecten (Needle_i) die in de game draaien.
    for u, name in zip(GAUGES, ("DEPTH", "SPEED", "FUEL")):
        v = 0.1
        cyl(0.135, 0.05, desk(u, v, 0.05), "Anthracite", g, verts=28, bevel=0.012, rot=DESK_ROT)
        cyl(0.115, 0.012, desk(u, v, 0.072), "Cream", g, verts=28, bevel=0.0, rot=DESK_ROT)
        for t in range(9):  # schaalstipjes over 270 graden
            a = math.radians(135 - t * 270 / 8)
            du, dv = -math.sin(a) * 0.094, math.cos(a) * 0.094
            cyl(0.008, 0.006, desk(u + du, v + dv, 0.079), "DecalDark" if t < 7 else "Red", g, verts=8,
                bevel=0.0, rot=DESK_ROT)
        desk_label(name, u, -0.11, size=0.04)
    # Autopiloot: drie gele knoppen met de diepte eronder.
    desk_label("AUTOPILOT", BTN_AUTO[1], 0.2, size=0.05)
    for u, d in zip(BTN_AUTO, ("CLAY", "SAND", "DEEP")):
        cyl(0.075, 0.03, desk(u, 0.02, 0.045), "Anthracite", g, verts=18, bevel=0.008, rot=DESK_ROT)
        cyl(0.06, 0.05, desk(u, 0.02, 0.07), "Yellow", g, verts=18, bevel=0.012, rot=DESK_ROT)
        desk_label(d, u, -0.14, size=0.045)
    # Klep (blauwe knop), lichten (tuimelschakelaars), toeter (rode paddenstoel).
    cyl(0.07, 0.03, desk(BTN_RAMP_U, 0.02, 0.045), "Anthracite", g, verts=16, bevel=0.008, rot=DESK_ROT)
    cyl(0.055, 0.05, desk(BTN_RAMP_U, 0.02, 0.07), "Blue", g, verts=16, bevel=0.012, rot=DESK_ROT)
    desk_label("RAMP", BTN_RAMP_U, -0.14)
    box((0.16, 0.03, 0.12), desk(BTN_LIGHTS_U, 0.02, 0.05), "Anthracite", g, bevel=0.01, rot=DESK_ROT)
    for du in (-0.04, 0.04):
        box((0.025, 0.07, 0.025), desk(BTN_LIGHTS_U + du, 0.03, 0.09), "Steel", g, bevel=0.006,
            rot=(DESK_TILT - 20, 0, 0))
    desk_label("LIGHTS", BTN_LIGHTS_U, -0.14)
    cyl(0.07, 0.04, desk(BTN_HORN_U, 0.02, 0.05), "Anthracite", g, verts=16, bevel=0.008, rot=DESK_ROT)
    sphere(0.075, desk(BTN_HORN_U, 0.02, 0.085), "Red", g, scale=(1, 0.55, 1), segments=14, rings=7)
    desk_label("HORN", BTN_HORN_U, -0.14)
    # Vertrekhendel: geel-zwart voetplaatje; de hendel zelf is het object Lever.
    box((0.2, 0.012, 0.26), desk(LEVER_U, 0.02, 0.037), "Hazard", g, bevel=0.0, rot=DESK_ROT)
    # LAUNCH: geel op een zwart plaatje, het best leesbare label op de console (ui-13).
    box((0.27, 0.006, 0.075), desk(LEVER_U, -0.17, 0.034), "DecalDark", g, bevel=0.0, rot=DESK_ROT)
    desk_label("LAUNCH", LEVER_U, -0.17, material="Yellow")
    # Mok koffie op de hoek (het is vroeg, het is altijd vroeg).
    cyl(0.045, 0.1, desk(-1.82, -0.18, 0.09), "Red", g, verts=16, bevel=0.005, rot=DESK_ROT)
    cyl(0.038, 0.005, desk(-1.82, -0.18, 0.141), "Wood", g, verts=16, bevel=0.0, rot=DESK_ROT)

    # Bakken waaruit de stuurhendels komen, met een rubberen hoes.
    for x in (-0.55, 0.55):
        box((0.26, 0.1, 0.3), (x, IN_Y0 + 0.05 + FLOOR_LIFT, -2.12), "Anthracite", g, bevel=0.02)
        cyl(0.075, 0.06, (x, IN_Y0 + 0.12, -2.12), "Rubber", g, verts=14, bevel=0.015)
    # Stoel.
    sz = -1.85
    cyl(0.12, 0.45, (0, IN_Y0 + 0.23, sz), "Anthracite", g, verts=16, bevel=0.02)
    box((0.62, 0.14, 0.58), (0, IN_Y0 + 0.52, sz), "Leather", g, bevel=0.06, segments=3)
    box((0.62, 0.78, 0.14), (0, IN_Y0 + 0.95, sz + 0.32), "Leather", g, bevel=0.06, segments=3, rot=(12, 0, 0))
    for s in (-1, 1):
        box((0.07, 0.07, 0.45), (s * 0.36, IN_Y0 + 0.75, sz + 0.05), "Anthracite", g, bevel=0.02)
    # Kleine zijramen-kozijnen binnen.
    for s in (-1, 1):
        box((0.05, 0.62, 0.95), (s * (IN_W / 2 - 0.02), 0.55, -2.7), "Anthracite", g, bevel=0.02)


def build_living(g):
    hw = IN_W / 2
    # Bankjes onder de patrijspoorten.
    for s in (-1, 1):
        box((0.45, 0.4, 1.1), (s * (hw - 0.25), IN_Y0 + 0.2, 0.0), "Anthracite", g, bevel=0.03)
        box((0.46, 0.12, 1.08), (s * (hw - 0.25), IN_Y0 + 0.46, 0.0), "Leather", g, bevel=0.05, segments=3)
    # Werkbank links met gereedschapsbord en bankschroef.
    zb = 1.05
    box((0.72, 0.07, 0.95), (-(hw - 0.38), -0.62, zb), "Wood", g, bevel=0.02)
    for dz in (-0.42, 0.42):
        for dx in (-0.3, 0.3):
            box((0.05, 0.85, 0.05), (-(hw - 0.38) + dx, -1.08, zb + dz), "Anthracite", g, bevel=0.01)
    box((0.6, 0.3, 0.85), (-(hw - 0.34), -0.9, zb), "Anthracite", g, bevel=0.02)  # lade
    box((0.3, 0.03, 0.04), (-(hw - 0.5), -0.88, zb), "Steel", g, bevel=0.005)
    box((0.04, 1.0, 1.0), (-(hw - 0.03), 0.15, zb), "Wood", g, bevel=0.01)  # bord (gaatjesplaat)
    for i, (y, z) in enumerate(((0.45, 0.75), (0.45, 1.05), (0.1, 0.8), (0.1, 1.3), (-0.2, 1.0))):
        box((0.03, 0.25, 0.05), (-(hw - 0.07), y, z), "Steel", g, bevel=0.01, rot=(0, 0, 15 * (i % 3 - 1)))
        torus(0.04, 0.012, (-(hw - 0.07), y + 0.14, z), "Steel", g, axis="x", major_seg=10, minor_seg=4)
    box((0.22, 0.14, 0.18), (-(hw - 0.55), -0.5, zb + 0.32), "Blue", g, bevel=0.02)  # bankschroef
    box((0.06, 0.06, 0.3), (-(hw - 0.55), -0.5, zb + 0.32), "Steel", g, bevel=0.01)
    # Kastjes rechts.
    for i in range(2):
        z = 0.78 + i * 0.44
        box((0.45, 1.95, 0.42), (hw - 0.25, IN_Y0 + 0.98, z), "Yellow", g, bevel=0.02)
        for k in range(4):
            box((0.01, 0.025, 0.25), (hw - 0.48, IN_Y0 + 1.6 + k * 0.05, z), "Anthracite", g, bevel=0.0)
        box((0.02, 0.18, 0.03), (hw - 0.48, IN_Y0 + 1.0, z + 0.12), "Steel", g, bevel=0.005)
    # Koffiehoek, brandblusser, poster.
    box((0.5, 0.05, 0.5), (-(hw - 0.27), -0.45, -1.25), "Wood", g, bevel=0.01)
    box((0.26, 0.38, 0.26), (-(hw - 0.24), -0.23, -1.25), "Anthracite", g, bevel=0.03)
    cyl(0.06, 0.12, (-(hw - 0.3), -0.35, -1.12), "Glass", g, verts=12, bevel=0.0)
    cyl(0.07, 0.38, (hw - 0.12, -1.0, -1.35), "Red", g, verts=14, bevel=0.03)
    sphere(0.07, (hw - 0.12, -0.8, -1.35), "Red", g, segments=10, rings=5)
    box((0.02, 0.62, 0.46), (hw - 0.01, 0.55, -1.05), "Padded", g, bevel=0.0)
    text("SAFETY?", 0.07, (hw - 0.025, 0.72, -1.05), (0, -90, 0), "DecalDark", g)
    text("NEVER", 0.055, (hw - 0.025, 0.6, -1.05), (0, -90, 0), "DecalDark", g)
    text("HEARD OF IT", 0.055, (hw - 0.025, 0.52, -1.05), (0, -90, 0), "DecalDark", g)
    text("DIG", 0.045, (hw - 0.025, 0.35, -1.05), (0, -90, 0), "Red", g)


def build_cargo(g):
    hw = IN_W / 2
    # Waarschuwingsranden op de vloer, sjorrails, wandrails.
    box((IN_W - 0.1, 0.012, 0.14), (0, IN_Y0 + 0.016, 1.62), "Hazard", g, bevel=0.0)
    for s in (-1, 1):
        box((0.14, 0.012, 2.5), (s * (hw - 0.12), IN_Y0 + 0.016, 2.9), "Hazard", g, bevel=0.0)
        tube([(s * 1.1, IN_Y0 + 0.05, 1.85), (s * 1.1, IN_Y0 + 0.05, 4.0)], 0.03, "Steel", g, verts=8)
        for y in (-0.7, 0.55):
            # Links loopt de onderste rail niet door de ertstrechter.
            z0 = 3.15 if (s < 0 and y < 0.0) else 1.75
            tube([(s * (hw - 0.06), y, z0), (s * (hw - 0.06), y, 4.05)], 0.03, "Steel", g, verts=8)
    # Kratten (decor) links voor in het laadruim.
    for (x, y, z, sz) in ((-1.55, IN_Y0 + 0.35, 1.95, 0.7), (-1.6, IN_Y0 + 0.95, 1.98, 0.5)):
        box((sz, sz, sz), (x, y, z), "Wood", g, bevel=0.03)
        for dz in (-sz / 2 + 0.06, sz / 2 - 0.06):
            box((sz + 0.02, sz + 0.02, 0.05), (x, y, z + dz), "Anthracite", g, bevel=0.01)
    text("CARGO HOLD", 0.16, (hw - 0.02, 0.9, 2.32), (0, -90, 0), "DecalDark", g)
    # De echte limiet uit de tuning (economy.cfg), met de upgrade erbij: "MAX 400 KG" sprak de hendel
    # tegen die bij 64 kg weigert (ui2-08).
    kg, kg2 = int(tuning("economy", "cargo_kg", 60.0)), int(tuning("economy", "cargo_kg_t2", 140.0))
    text(f"MAX {kg} KG  ·  HEAD OFFICE KNOWS", 0.06, (hw - 0.02, 0.72, 2.32), (0, -90, 0), "DecalDark", g)
    text(f"EXTENDED HOLD: {kg2} KG", 0.045, (hw - 0.02, 0.6, 2.32), (0, -90, 0), "DecalDark", g)
    build_hopper(g)
    # Bediening laadklep bij de klep.
    box((0.08, 0.32, 0.22), (hw - 0.04, -0.25, 3.7), "Anthracite", g, bevel=0.02)
    cyl(0.05, 0.05, (hw - 0.09, -0.25, 3.7), "Yellow", g, axis="x", verts=12, bevel=0.0)


# Ertstrechter (binnen-15): een brede trechtermond die uit de linkerwand van het laadruim steekt,
# op heuphoogte, met een rooster, een gele-zwarte rand, een geel bord met ORE en een pijl naar
# beneden, en een stortpijp naar de vloer. Erts dat ernaast viel, ligt op de vloer. Tussen de kratten
# en het laatste spant: de ingang langs de klep blijft vrij (looproute eerst), en ze steekt maar
# HOPPER_MX uit de wand.
HOPPER = (-1.83, -0.44, 2.7)  # midden van de mond (bovenkant)
HOPPER_MX, HOPPER_MZ = 0.48, 0.62  # mond: uit de wand, langs de wand


def build_hopper(g):
    hw = IN_W / 2
    hx, hy, hz = HOPPER
    mx, mz = HOPPER_MX, HOPPER_MZ
    depth = 0.46
    # Trechter (kegel met 4 zijden, 45° gedraaid, smal onderaan), platgedrukt tot de mond mx × mz.
    o = cyl(0.18, depth, (0, 0, 0), "Yellow", g, verts=4, bevel=0.012, r2=0.5, rot=(0, 45, 0))
    o.scale = (mx / 0.7, mz / 0.7, 1.0)  # Blender x = Godot x, Blender y = −Godot z
    o.location = G(hx, hy - depth / 2, hz)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    # De opening: donker, net onder de rand, met een rooster van stalen staven erover.
    box((mx - 0.08, 0.02, mz - 0.08), (hx, hy - 0.03, hz), "Soot", g, bevel=0.0)
    n = int((mz - 0.1) / 0.085)
    for k in range(-(n // 2), n // 2 + 1):
        box((mx - 0.06, 0.025, 0.022), (hx, hy + 0.012, hz + k * 0.085), "DarkSteel", g, bevel=0.004)
    box((0.022, 0.03, mz - 0.06), (hx, hy + 0.016, hz), "DarkSteel", g, bevel=0.004)
    # Rand met waarschuwingsstrepen.
    for sgn in (-1, 1):
        box((mx + 0.04, 0.035, 0.05), (hx, hy + 0.01, hz + sgn * (mz / 2 - 0.005)), "Hazard", g, bevel=0.006)
        box((0.05, 0.035, mz + 0.04), (hx + sgn * (mx / 2 - 0.005), hy + 0.01, hz), "Hazard", g, bevel=0.006)
    # Ophanging aan de wand en de stortpijp naar de vloer (in het onderstel).
    box((0.05, 0.7, mz - 0.02), (-(hw - 0.03), hy - 0.25, hz), "Anthracite", g, bevel=0.012)
    for sgn in (-1, 1):
        box((0.3, 0.05, 0.05), (-(hw - 0.17), hy - 0.4, hz + sgn * (mz / 2 - 0.06)), "Anthracite", g, bevel=0.008, rot=(0, 0, -35))
    tube([(hx, hy - depth + 0.02, hz), (hx, IN_Y0 + 0.08, hz), (-(hw - 0.05), IN_Y0 + 0.08, hz)], 0.07, "DarkSteel", g, verts=10)
    # Bord: geel, ORE, een pijl naar beneden.
    by = hy + 0.52
    box((0.03, 0.4, 0.5), (-(hw - 0.02), by, hz), "Yellow", g, bevel=0.01)
    text("ORE", 0.13, (-(hw - 0.04), by + 0.07, hz), (0, 90, 0), "DecalDark", g, extrude=0.004)
    # Pijl naar beneden: een steel en een punthaak (twee schuine balkjes).
    box((0.012, 0.11, 0.03), (-(hw - 0.04), by - 0.06, hz), "DecalDark", g, bevel=0.0)
    for sgn in (-1, 1):
        box((0.012, 0.075, 0.026), (-(hw - 0.04), by - 0.1, hz + sgn * 0.024), "DecalDark", g, bevel=0.0, rot=(sgn * 45, 0, 0))
    # Gemorst erts op de vloer onder de mond: kleine roestbruine brokjes.
    for i, (dx, dz, sz) in enumerate(((0.3, -0.2, 0.05), (0.42, 0.1, 0.035), (0.26, 0.24, 0.04), (0.5, -0.05, 0.03),
                                      (0.36, 0.3, 0.028), (0.58, 0.2, 0.025))):
        box((sz, sz * 0.8, sz * 1.1), (hx + dx, IN_Y0 + FLOOR_LIFT + sz * 0.4, hz + dz), "RedOxide" if i % 2 else "Copper", g,
            bevel=0.008, rot=(i * 23, i * 41, i * 17))


# Gezellig in het donker (binnen-14, de stijlgids: "warme lampjes, rommelig"): een slinger kleine
# lampjes langs het plafond, een bureaulamp op de werkbank, een donkere lambrisering met een rail,
# vuil op de vloer en rommel van vorige diensten op vaste plekken (mokken, tape, briefjes, stickers).
STRING_X = 0.45
STRING_Z = (-2.4, 3.6)


def build_homely(g):
    hw = IN_W / 2
    # Lambrisering: onderaan de wanden een donkere band met een rail erboven.
    zc = (IN_Z0 + HULL_Z1) / 2
    length = HULL_Z1 - IN_Z0 - 0.3
    for sgn in (-1, 1):
        box((0.02, 0.62, length), (sgn * (hw - 0.012), IN_Y0 + 0.31, zc), "HullDark", g, bevel=0.0)
        box((0.04, 0.035, length), (sgn * (hw - 0.025), IN_Y0 + 0.63, zc), "Anthracite", g, bevel=0.008)
    # Lampjesslinger aan haakjes langs het plafond, met een doorhangende draad.
    z0, z1 = STRING_Z
    y_hook = IN_Y1 - 0.1
    hooks = [z0 + (z1 - z0) * k / 5 for k in range(6)]
    pts = []
    for i in range(len(hooks) - 1):
        a, b = hooks[i], hooks[i + 1]
        for t in range(6):
            u = t / 6
            pts.append((STRING_X, y_hook - 0.09 * math.sin(math.pi * u), a + (b - a) * u))
        cyl(0.012, 0.03, (STRING_X, y_hook + 0.02, a), "Anthracite", g, verts=6, bevel=0.0)
    pts.append((STRING_X, y_hook, z1))
    tube(pts, 0.006, "Rubber", g, verts=5)
    for i in range(len(hooks) - 1):
        a, b = hooks[i], hooks[i + 1]
        for u in (0.25, 0.5, 0.75):
            z = a + (b - a) * u
            y = y_hook - 0.09 * math.sin(math.pi * u) - 0.035
            cyl(0.011, 0.02, (STRING_X, y + 0.025, z), "DarkSteel", g, verts=6, bevel=0.0)
            sphere(0.024, (STRING_X, y, z), "Bulb", g, segments=8, rings=5)
    # Bureaulamp op de werkbank (scharnierarm, kap naar het werkblad).
    zb = 1.05
    lx, lz = -(hw - 0.62), zb - 0.32
    top = -0.585
    cyl(0.07, 0.025, (lx, top + 0.012, lz), "Anthracite", g, verts=14, bevel=0.006)
    tube([(lx, top + 0.02, lz), (lx + 0.04, top + 0.3, lz + 0.05), (lx + 0.2, top + 0.42, lz + 0.12)], 0.012, "Steel", g, verts=6)
    cyl(0.03, 0.12, (lx + 0.22, top + 0.38, lz + 0.13), "Yellow", g, verts=12, bevel=0.005, r2=0.075, rot=(-150, 0, -25))
    sphere(0.022, (lx + 0.23, top + 0.35, lz + 0.14), "Bulb", g, segments=8, rings=5)
    # Rommel op de werkbank: een mok, een rol tape, een poetslap, een klembord tegen de wand.
    cyl(0.04, 0.09, (-(hw - 0.3), top + 0.045, zb + 0.05), "Blue", g, verts=14, bevel=0.005)
    torus(0.028, 0.008, (-(hw - 0.3) + 0.045, top + 0.05, zb + 0.05), "Blue", g, axis="z", major_seg=10, minor_seg=4)
    torus(0.045, 0.018, (-(hw - 0.48), top + 0.018, zb - 0.05), "HullLight", g, axis="y", major_seg=14, minor_seg=6)
    sphere(0.07, (-(hw - 0.62), top + 0.02, zb + 0.28), "RedOxide", g, scale=(1.3, 0.25, 0.9), segments=10, rings=5)
    box((0.012, 0.3, 0.22), (-(hw - 0.025), -0.12, zb + 0.36), "Wood", g, bevel=0.004)
    box((0.006, 0.24, 0.18), (-(hw - 0.032), -0.14, zb + 0.36), "Padded", g, bevel=0.0)
    for k in range(4):
        box((0.004, 0.006, 0.13 - k * 0.02), (-(hw - 0.036), -0.06 - k * 0.04, zb + 0.35), "DecalDark", g, bevel=0.0)
    # Briefjes van vorige diensten op de wand naast de werkbank en op het camerascherm.
    notes = (((-(hw - 0.058), 0.5, zb + 0.36), (0, 90, 6), "Yellow", "WHO TOOK\nMY MUG?"),
             ((-(hw - 0.058), 0.2, zb - 0.36), (0, 90, -8), "Padded", "PING\nSPARINGLY"),
             ((0.82, 1.07, -3.45), (0, 0, 4), "Yellow", "FEED\nTHE MOLE"))
    for pos, rot, m, body in notes:
        box((0.1, 0.1, 0.004), (0, 0, 0), m, g, bevel=0.0)
        note = PARTS[g][-1]
        place = Matrix.Translation(G(*pos)) @ _godot_euler(rot).to_matrix().to_4x4()
        note.matrix_world = place
        text(body, 0.018, (0, 0.005, 0.004), (0, 0, 0), "DecalDark", g, extrude=0.001)
        t = PARTS[g][-1]
        t.matrix_world = place @ t.matrix_world
    # Stickers op de kastjes (rechts): de firma, een smiley, een waarschuwing.
    for (y, z, m) in ((0.25, 0.7, "Red"), (-0.15, 0.95, "Blue"), (0.55, 1.12, "Green"), (-0.5, 0.62, "DecalLight")):
        cyl(0.045, 0.004, (hw - 0.475, y, z), m, g, axis="x", verts=16, bevel=0.0)
    text("DIG", 0.03, (hw - 0.479, 0.245, 0.7), (0, -90, 0), "DecalLight", g, extrude=0.001)
    # Een gereedschapskist en een opgerolde kabel in het laadruim, een thermos in de koffiehoek.
    box((0.5, 0.24, 0.26), (hw - 0.4, IN_Y0 + 0.13, 3.75), "Red", g, bevel=0.02)
    box((0.3, 0.03, 0.03), (hw - 0.4, IN_Y0 + 0.28, 3.75), "Anthracite", g, bevel=0.006)
    torus(0.16, 0.022, (hw - 0.06, -0.35, 2.55), "Rubber", g, axis="x", major_seg=16, minor_seg=5)
    torus(0.14, 0.02, (hw - 0.08, -0.37, 2.55), "Rubber", g, axis="x", major_seg=16, minor_seg=5)
    cyl(0.04, 0.2, (-(hw - 0.2), -0.32, -1.38), "Green", g, verts=12, bevel=0.01)
    # Vuil op de vloer: smalle sporen van laarzen en kratten die over de vloer schoven, en een paar
    # olievlekjes (niet egaal schoon; geen grote zwarte vlekken, die lezen als gaten).
    for (x, z, rx, rz, a) in ((0.35, 3.5, 0.55, 0.035, 12), (0.5, 3.2, 0.45, 0.03, 8), (-0.55, 2.7, 0.5, 0.03, -20),
                              (0.2, 0.9, 0.6, 0.03, 75), (-0.35, -0.2, 0.4, 0.025, 95), (0.6, -1.1, 0.07, 0.05, 0),
                              (-0.9, 1.6, 0.06, 0.045, 30)):
        o = cyl(1.0, 0.004, (x, IN_Y0 + FLOOR_LIFT + 0.004, z), "Soot", g, verts=16, bevel=0.0)
        o.scale = (rx, rz, 1.0)
        o.rotation_euler.z = math.radians(a)
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


# Sonar: een kast met een ronde beeldbuis, rechts naast het camerascherm en naar de piloot gedraaid.
# Alles wordt eerst in kastruimte gebouwd (u opzij, v omhoog, w naar de piloot) en daarna geplaatst.
SONAR_C = (1.50, 0.37, -3.28)
SONAR_ROT = (6.0, -32.0, 0.0)  # licht voorover (de piloot zit lager) en naar de stoel gedraaid
SONAR_BOX = (0.92, 0.74, -0.06)  # breedte, hoogte, midden v van kast en frontplaat
SONAR_SCREEN = (0.86, 0.56)  # scherm achter de frontplaat; 1 mm = 1 pixel in de game (860×560)
SONAR_SCOPE = ((-0.17, 0.0), 0.245)  # ronde opening: midden (u, v) en straal
SONAR_SLOT = ((0.11, -0.26), (0.415, 0.26))  # rechthoekige opening voor de dieptestrook en de tekst
SONAR_PING_C = [0.0, 0.0, 0.0]  # midden van de PING-knop (Godot), gezet door build_sonar


def sonar_matrix():
    return Matrix.Translation(G(*SONAR_C)) @ _godot_euler(SONAR_ROT).to_matrix().to_4x4()


def build_sonar(g):
    """Sonarkast (groep g), het scherm zelf als object Sonar (UV 0..1) en het echolampje als SonarLamp."""
    before = {k: len(v) for k, v in PARTS.items()}
    bw, bh, bv = SONAR_BOX
    knob_v = bv - bh / 2 + 0.095
    # Kast, beeldbuishals erachter, frontplaat met een ronde en een rechthoekige opening.
    box((bw, bh, 0.18), (0, bv, -0.09), "Anthracite", g, bevel=0.03, segments=3)
    box((0.56, 0.46, 0.15), (-0.08, -0.02, -0.25), "Anthracite", g, bevel=0.06, segments=3)
    plate = box((bw - 0.01, bh - 0.01, 0.02), (0, bv, 0.025), "DarkSteel", g, bevel=0.0)
    (su, sv), sr = SONAR_SCOPE
    hole = cyl(sr, 0.1, (su, sv, 0.025), "DarkSteel", "_cut", axis="z", verts=56, bevel=0.0)
    unregister(hole)
    boolean(plate, hole)
    (u0, v0), (u1, v1) = SONAR_SLOT
    slot = box((u1 - u0, v1 - v0, 0.1), ((u0 + u1) / 2, (v0 + v1) / 2, 0.025), "DarkSteel", "_cut", bevel=0.0)
    unregister(slot)
    boolean(plate, slot)
    # Chromen ring rond de beeldbuis, schroefjes, knoppen, opschrift, echolampje.
    torus(sr + 0.007, 0.012, (su, sv, 0.037), "Steel", g, axis="z", major_seg=56, minor_seg=8)
    for du in (-bw / 2 + 0.025, bw / 2 - 0.025):
        for dv in (bv + bh / 2 - 0.025, bv - bh / 2 + 0.025):
            cyl(0.009, 0.01, (du, dv, 0.038), "Steel", g, axis="z", verts=8, bevel=0.0)
    # PING-knop (object SonarPing, de game laat hem branden): oranje drukknop in een kraag met een
    # gele rand, zoals een noodknop, maar kleiner.
    pu = -0.33
    cyl(0.05, 0.016, (pu, knob_v, 0.042), "Yellow", g, axis="z", verts=28, bevel=0.004)
    cyl(0.043, 0.03, (pu, knob_v, 0.055), "Anthracite", g, axis="z", verts=28, bevel=0.005)
    cyl(0.034, 0.026, (pu, knob_v, 0.074), "LensOrange", "SonarPing", axis="z", verts=24, bevel=0.009)
    text("PING", 0.026, (pu, knob_v - 0.075, 0.036), (0, 0, 0), "DecalLight", g, extrude=0.002)
    for ku, label in ((-0.12, "BRIGHT"),):
        cyl(0.036, 0.02, (ku, knob_v, 0.045), "Anthracite", g, axis="z", verts=20, bevel=0.006)
        cyl(0.029, 0.03, (ku, knob_v, 0.06), "DarkSteel", g, axis="z", verts=20, bevel=0.006)
        box((0.007, 0.025, 0.006), (ku, knob_v + 0.016, 0.077), "DecalLight", g, bevel=0.0)
        text(label, 0.024, (ku, knob_v - 0.07, 0.036), (0, 0, 0), "DecalLight", g, extrude=0.002)
    text("SONAR", 0.058, (0.14, knob_v - 0.02, 0.036), (0, 0, 0), "DecalLight", g, extrude=0.003)
    cyl(0.027, 0.012, (0.36, knob_v, 0.04), "Anthracite", g, axis="z", verts=16, bevel=0.0)
    sphere(0.019, (0.36, knob_v, 0.047), "LensRed", "SonarLamp", scale=(1, 1, 0.6), segments=12, rings=6)
    text("ECHO", 0.02, (0.36, knob_v - 0.07, 0.036), (0, 0, 0), "DecalLight", g, extrude=0.002)
    # Het scherm: een vlak net achter de frontplaat, UV zoals het camerascherm.
    w, h = SONAR_SCREEN
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    corners = [(-w / 2, -h / 2, (0, 1)), (w / 2, -h / 2, (1, 1)), (w / 2, h / 2, (1, 0)), (-w / 2, h / 2, (0, 0))]
    f = bm.faces.new([bm.verts.new(G(x, y, 0.008)) for x, y, _ in corners])
    for loop, (_, _, t) in zip(f.loops, corners):
        loop[uv].uv = t
    f.normal_update()
    if f.normal.dot(G(0, 0, 1)) < 0:
        f.normal_flip()
    me = bpy.data.meshes.new("Sonar")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("Sonar", me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat("Screen"))
    PARTS.setdefault("Sonar", []).append(o)
    # Alles wat hier gemaakt is naar zijn plek in de cabine.
    m = sonar_matrix()
    for k, objs in PARTS.items():
        for obj in objs[before.get(k, 0):]:
            obj.matrix_world = m @ obj.matrix_world
    bpy.context.view_layer.update()
    # Midden van de PING-knop (Godot), als oorsprong van zijn object: daar komt de knop in de game.
    c = m @ G(pu, knob_v, 0.074)
    SONAR_PING_C[:] = [c.x, c.z, -c.y]


def build_monitor():
    """Camerascherm met UV 0..1 (u naar rechts, v naar beneden, gezien vanuit de cabine)."""
    w, h = 1.78, 0.98
    zc = -3.455
    yc = 0.55
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    corners = [(-w / 2, yc - h / 2, (0, 1)), (w / 2, yc - h / 2, (1, 1)), (w / 2, yc + h / 2, (1, 0)), (-w / 2, yc + h / 2, (0, 0))]
    vs = [bm.verts.new(G(x, y, zc)) for x, y, _ in corners]
    f = bm.faces.new(vs)
    for loop, (_, _, t) in zip(f.loops, corners):
        loop[uv].uv = t
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # Normaal moet naar de cabine (+z) wijzen.
    f.normal_update()
    if f.normal.dot(G(0, 0, 1)) < 0:
        f.normal_flip()
    me = bpy.data.meshes.new("Monitor")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("Monitor", me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat("Screen"))
    PARTS["Monitor"] = [o]


def build_lever():
    g = "Lever"
    base = desk(LEVER_U, 0.02, 0.05)
    n, a = DESK_N, DESK_A
    box((0.11, 0.05, 0.15), base, "Anthracite", g, bevel=0.015, rot=DESK_ROT)
    tip = (base[0], base[1] + n[1] * 0.3 + a[1] * 0.06, base[2] + n[2] * 0.3 + a[2] * 0.06)
    tube([base, tip], 0.022, "Steel", g, verts=10)
    sphere(0.055, tip, "Red", g, segments=14, rings=7)
    return base


NEEDLES = []
STICK_BASE = {"L": (-0.55, IN_Y0 + 0.1, -2.12), "R": (0.55, IN_Y0 + 0.1, -2.12)}


def build_sticks():
    """Twee stuurhendels zoals in een rupsvoertuig: duwen = vooruit, trekken = achteruit, verschil = draaien."""
    for side, base in STICK_BASE.items():
        g = f"Stick_{side}"
        x, y, z = base
        top = (x, -0.62, z - 0.08)
        cyl(0.05, 0.08, (x, y + 0.02, z), "Anthracite", g, verts=14, bevel=0.01)
        tube([(x, y + 0.05, z), top], 0.026, "Steel", g, verts=10)
        cyl(0.042, 0.2, (top[0], top[1] + 0.08, top[2] - 0.03), "Rubber", g, verts=14, bevel=0.012,
            rot=(-10, 0, 0))
        sphere(0.045, (top[0], top[1] + 0.19, top[2] - 0.05), "Yellow" if side == "L" else "Yellow", g,
               segments=12, rings=6)


def build_needles():
    """Naalden van de meters: elk een eigen object met het draaipunt in het midden van de wijzerplaat."""
    for k, u in enumerate(GAUGES):
        g = f"Needle_{k}"
        c = desk(u, 0.1, 0.086)
        length = 0.085
        box((0.011, 0.005, length), desk(u, 0.1 + length * 0.42, 0.086), "Red", g, bevel=0.0, rot=DESK_ROT)
        cyl(0.016, 0.012, c, "Anthracite", g, verts=10, bevel=0.0, rot=DESK_ROT)
        NEEDLES.append((g, c))


def build_glass():
    g = "Glass"
    for s in (-1, 1):
        cyl(PORTHOLE_R + 0.02, 0.03, (s * (HULL_W / 2 - 0.12), PORTHOLE_Y, 0.0), "Glass", g, axis="x", verts=32, bevel=0.0)
        box((0.03, 0.56, 0.9), (s * (HULL_W / 2 - 0.12), 0.55, -2.7), "Glass", g, bevel=0.0)


# ======================================================================================
# Hoofdprogramma
# ======================================================================================

def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_hull()
    build_shield()
    build_roof()
    build_tracks()
    build_drill_head()
    build_hub()
    build_ramp()
    build_weathering()
    build_interior()
    build_monitor()
    lever_base = build_lever()
    build_needles()
    build_sticks()
    build_glass()

    root = bpy.data.objects.new("Mol", None)
    bpy.context.collection.objects.link(root)

    objects = {}
    objects["Hull"] = join_group("Hull", "Hull")
    objects["DrillHead"] = join_group("DrillHead", "DrillHead")
    objects["Hub"] = join_group("Hub", "Hub")
    objects["Ramp"] = join_group("Ramp", "Ramp", origin=RAMP_HINGE)
    objects["Interior"] = join_group("Interior", "Interior")
    objects["Monitor"] = join_group("Monitor", "Monitor")
    objects["Sonar"] = join_group("Sonar", "Sonar")
    objects["SonarLamp"] = join_group("SonarLamp", "SonarLamp")
    objects["SonarPing"] = join_group("SonarPing", "SonarPing", origin=tuple(SONAR_PING_C))
    objects["Lever"] = join_group("Lever", "Lever", origin=lever_base)
    objects["Glass"] = join_group("Glass", "Glass")
    for g, c in NEEDLES:
        objects[g] = join_group(g, g, origin=c)
    for side, base in STICK_BASE.items():
        objects[f"Stick_{side}"] = join_group(f"Stick_{side}", f"Stick_{side}", origin=base)
    objects["TrackLink"] = join_group("TrackLink", "TrackLink")
    for side in ("L", "R"):
        for i in range(7):
            key = f"Wheel_{side}_{i}"
            center = PARTS[key + "_center"][0]
            objects[key] = join_group(key, key, origin=center)

    for name, o in objects.items():
        if o is None:
            continue
        if name not in ("Monitor", "Sonar", "Glass"):
            bake_wear(o, strength=5.0, seed=hash(name) % 1000)
        parent_to(o, root)

    # Ankerpunten voor de game.
    anchors = {
        "Cam_Feed": ((0, 0, -7.93), (0, 0, 0)),
        "Light_Hub": ((0, 0, -7.9), (0, 0, 0)),
        "Light_Bar": ((0, 2.28, -3.78), (-12, 0, 0)),
        "Light_Roof_L": ((-1.27, 2.3, -3.68), (-5, 25, 0)),
        "Light_Roof_R": ((1.27, 2.3, -3.68), (-5, -25, 0)),
        "Light_Rear": ((0, 1.98, 4.3), (-40, 180, 0)),
        "Beacon_L": ((-1.0, 2.28, -3.2), (0, 0, 0)),
        "Beacon_R": ((1.0, 2.28, -3.2), (0, 0, 0)),
        "Cage_0": ((0, IN_Y1 - 0.26, -2.35), (0, 0, 0)),
        "Cage_1": ((0, IN_Y1 - 0.26, 0.0), (0, 0, 0)),
        "Cage_2": ((0, IN_Y1 - 0.26, 2.9), (0, 0, 0)),
        "Seat_Head": ((0, IN_Y0 + 1.58, -1.9), (-8, 0, 0)),
        "Seat_Exit": ((0, IN_Y0, -1.2), (0, 0, 0)),
        "Btn_Auto_0": (desk(BTN_AUTO[0], 0.02, 0.07), DESK_ROT),
        "Btn_Auto_1": (desk(BTN_AUTO[1], 0.02, 0.07), DESK_ROT),
        "Btn_Auto_2": (desk(BTN_AUTO[2], 0.02, 0.07), DESK_ROT),
        "Btn_Horn": (desk(BTN_HORN_U, 0.02, 0.08), DESK_ROT),
        "Btn_Lights": (desk(BTN_LIGHTS_U, 0.02, 0.07), DESK_ROT),
        "Btn_Ramp_Cockpit": (desk(BTN_RAMP_U, 0.02, 0.07), DESK_ROT),
        "Btn_Ramp_Back": ((IN_W / 2 - 0.09, -0.25, 3.7), (0, 0, 0)),
        "Workbench": ((-(IN_W / 2 - 0.38), -0.5, 1.05), (0, 0, 0)),
        "Ore_Chute": ((HOPPER[0], HOPPER[1] + 0.12, HOPPER[2]), (0, 0, 0)),
        "Lamp_Bench": ((-(IN_W / 2 - 0.62) + 0.23, -0.585 + 0.33, 1.05 - 0.32 + 0.14), (-90, 0, 0)),
        "Lamp_String_0": ((STRING_X, IN_Y1 - 0.3, -1.4), (0, 0, 0)),
        "Lamp_String_1": ((STRING_X, IN_Y1 - 0.3, 1.6), (0, 0, 0)),
        "Lamp_Hopper": ((-(IN_W / 2 - 0.25), HOPPER[1] + 0.95, HOPPER[2]), (0, 0, 0)),
        "Exhaust_L": ((-0.55, 3.0, 1.85), (0, 0, 0)),
        "Exhaust_R": ((0.55, 3.0, 1.85), (0, 0, 0)),
        "Label_Depth": ((-1.44, 0.35, -3.31), (0, 22, 0)),
    }
    for name, (pos, rot) in anchors.items():
        empty(name, pos, rot, parent=root)

    total = 0
    for name, o in objects.items():
        if o:
            n = tri_count(o)
            total += n
            print(f"[mol] {name:12s} {n:7d} driehoeken")
    print(f"[mol] totaal {total} driehoeken")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    export_glb(OUT)
    print(f"[mol] geschreven: {OUT}")

    if RENDER_DIR:
        render_previews(root, objects)


def render_previews(root, objects):
    RENDER_DIR.mkdir(parents=True, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = 1280
    sc.render.resolution_y = 720
    world = bpy.data.worlds.new("w")
    sc.world = world
    world.color = (0.02, 0.016, 0.012)
    try:
        world.use_nodes = True
        world.node_tree.nodes["Background"].inputs[0].default_value = (0.035, 0.03, 0.025, 1)
        world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    except Exception:
        pass

    def light(kind, pos, energy, color=(1, 0.85, 0.7), size=4.0):
        ld = bpy.data.lights.new("l", kind)
        ld.energy = energy
        ld.color = color
        if kind == "AREA":
            ld.size = size
        o = bpy.data.objects.new("l", ld)
        sc.collection.objects.link(o)
        o.location = G(*pos)
        d = Vector((0, 0, 0)) - o.location
        o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        return o

    light("AREA", (8, 9, -10), 2500)
    light("AREA", (-9, 5, 6), 1500, (0.7, 0.8, 1.0))
    light("AREA", (0, 12, 0), 900)
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    sc.collection.objects.link(cam)
    sc.camera = cam

    def shot(name, pos, target, lens=35):
        cam.location = G(*pos)
        d = G(*target) - cam.location
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        cam_data.lens = lens
        sc.render.filepath = str(RENDER_DIR / f"{name}.png")
        bpy.ops.render.render(write_still=True)
        print(f"[mol] render {name}")

    shot("voor_schuin", (11, 4, -14), (0, 0, -2))
    shot("zij", (16, 1, 0.5), (0, 0, 0.5), lens=30)
    shot("achter_schuin", (-9, 5, 13), (0, 0, 1))
    # Laadklep open en een blik naar binnen.
    ramp = objects["Ramp"]
    ramp.rotation_euler.rotate_axis("X", math.radians(-120))
    shot("achter_open", (2.5, 1.2, 12), (0, -0.5, 0))
    # Binnen: verberg het dak tijdelijk niet; camera staat in het laadruim.
    shot("binnen_cabine", (0.6, 0.6, 2.8), (0, -0.2, -3.4), lens=18)
    shot("binnen_achter", (-0.4, 0.8, -1.4), (0.2, -0.6, 4.0), lens=18)
    shot("boorkop", (4.5, 1.5, -13), (0, 0, -6.2), lens=35)
    shot("dak", (6, 7, -6), (0, 2, 0), lens=30)


main()
