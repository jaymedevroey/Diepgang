"""Gereedschap van Diepgang BV: houweel, boor (met losse boorspiraal) en de robothandschoen.

Gebruik:
    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup \\
        --python tools/blender/tools.py -- game/assets/models/tools.glb

Stijlgids: Diepgang-geel met antraciet, dikke grepen, kale stalen koppen, tape en een sticker,
1,2-1,4x realistisch. Godot-coördinaten, oorsprong van elk gereedschap = midden van de greep (hand).
Objecten:
  Pickaxe     steel langs +y, punt naar -z, beitel naar +z, kop op y 0,52
  Drill       pistoolgreep in de oorsprong, behuizing langs -z op y 0,13
  Drill_Bit   boorspiraal, draaipunt vooraan de klauwplaat (0, 0,13, -0,29), draait rond z
  Glove       gesloten robothand rond een verticale greep (straal 0,031) door de oorsprong: pantserplaat
              en duim in PlayerColor, gelede antraciet vingers vooraan (−z) om de greep, korte donkere
              onderarm naar achteren-onder-rechts (+z, −y, +x), ±0,15 m vanaf de pols
  Glove_Open  open rechterhand om te dragen: oorsprong = midden van de handpalm, palm naar −x, vingers
              vooruit (−z) en ±35° gekruld, duim bovenaan; onderarm naar +z (en licht −y, +x).
              Linkerhand in Godot: gespiegeld met scale.x = −1
"""

import math
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).parent))
import kit  # noqa: E402
from kit import G, PARTS, bake_wear, box, cyl, export_glb, join_group, loft, parent_to, sphere, text, tri_count, torus, tube  # noqa: E402

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = Path(ARGS[0]) if ARGS else Path("game/assets/models/tools.glb")

HEAD_Y = 0.52
BIT_PIVOT = (0.0, 0.13, -0.29)


def build_pickaxe():
    g = "Pickaxe"
    # Steel: geel geverfd staal, dik.
    cyl(0.024, 0.58, (0, 0.18, 0), "Yellow", g, verts=12, bevel=0.004)
    # Rubberen greep met ribbels en een stalen knop onderaan.
    cyl(0.031, 0.27, (0, 0.02, 0), "Rubber", g, verts=14, bevel=0.008)
    for y in (-0.085, -0.035, 0.015, 0.065, 0.115):
        torus(0.031, 0.0065, (0, y, 0), "Rubber", g, axis="y", major_seg=16, minor_seg=6)
    sphere(0.037, (0, -0.125, 0), "DarkSteel", g, scale=(1, 0.65, 1), segments=14, rings=7)
    # Zwarte tape vlak onder de kop, en een geel-zwarte band.
    cyl(0.0275, 0.075, (0, 0.40, 0), "Anthracite", g, verts=12, bevel=0.003)
    for k in range(3):
        torus(0.0275, 0.0025, (0, 0.37 + k * 0.025, 0), "Anthracite", g, axis="y", major_seg=14, minor_seg=4)
    cyl(0.0258, 0.03, (0, 0.31, 0), "Hazard", g, verts=12, bevel=0.0)

    # Kop: oog (blok) met bouten en een wig bovenop.
    box((0.066, 0.092, 0.104), (0, HEAD_Y, 0), "Anthracite", g, bevel=0.014, segments=3)
    for s in (-1, 1):
        for (y, z) in ((HEAD_Y + 0.025, 0.026), (HEAD_Y - 0.025, -0.026)):
            cyl(0.0095, 0.074, (0, y, z), "Steel", g, axis="x", verts=10, bevel=0.002)
    box((0.03, 0.012, 0.052), (0, HEAD_Y + 0.05, 0), "Steel", g, bevel=0.004)
    # Punt naar voren: gebogen, spits, kaal staal; de voet is nog geel geverfd.
    spike = [(0, HEAD_Y + 0.008, -0.045), (0, HEAD_Y + 0.006, -0.1), (0, HEAD_Y - 0.004, -0.165),
             (0, HEAD_Y - 0.024, -0.23), (0, HEAD_Y - 0.054, -0.29), (0, HEAD_Y - 0.09, -0.34)]
    loft(spike, [(0.027, 0.033), (0.023, 0.029), (0.018, 0.023), (0.013, 0.017), (0.0075, 0.0095), 0.0],
         "CutterSteel", g, verts=10, up=(0, 1, 0))
    loft(spike[:2], [(0.029, 0.035), (0.0255, 0.031)], "Yellow", g, verts=10, up=(0, 1, 0))
    # Brede beitel naar achteren, plat en licht omlaag gebogen.
    adze = [(0, HEAD_Y + 0.006, 0.045), (0, HEAD_Y + 0.002, 0.1), (0, HEAD_Y - 0.012, 0.16), (0, HEAD_Y - 0.035, 0.215)]
    loft(adze, [(0.029, 0.026), (0.034, 0.018), (0.04, 0.012), (0.046, 0.006)], "CutterSteel", g, verts=12, up=(0, 1, 0))
    loft(adze[:2], [(0.031, 0.028), (0.035, 0.02)], "Yellow", g, verts=12, up=(0, 1, 0))
    # Sticker van de firma op het oog.
    for s in (-1, 1):
        box((0.003, 0.056, 0.07), (s * 0.034, HEAD_Y - 0.004, 0), "Yellow", g, bevel=0.0)
        text("DG", 0.034, (s * 0.0362, HEAD_Y - 0.006, 0), (0, 90 * s, 0), "DecalDark", g, extrude=0.0015)


def build_drill():
    g = "Drill"
    by = BIT_PIVOT[1]
    # Pistoolgreep (rubber) met vingerribbels en een rode trekker.
    box((0.054, 0.155, 0.068), (0, 0.0, 0.006), "Rubber", g, bevel=0.016, segments=3, rot=(-15, 0, 0))
    for k in range(3):
        box((0.056, 0.012, 0.018), (0, -0.04 + k * 0.035, -0.024 + k * 0.009), "Rubber", g, bevel=0.005, rot=(-15, 0, 0))
    box((0.02, 0.042, 0.022), (0, 0.062, -0.045), "Red", g, bevel=0.006, rot=(-25, 0, 0))
    box((0.04, 0.012, 0.07), (0, 0.04, -0.03), "Anthracite", g, bevel=0.004)  # trekkerbeugel
    # Behuizing: dikke gele cilinder, achteraan een antraciet kap.
    cyl(0.074, 0.31, (0, by, -0.05), "Yellow", g, axis="z", verts=22, bevel=0.012, segments=3)
    sphere(0.072, (0, by, 0.103), "Anthracite", g, scale=(1, 0.3, 1), segments=20, rings=8)  # platte achterkap
    # Koelsleuven op beide flanken.
    for s in (-1, 1):
        for k in range(4):
            box((0.008, 0.011, 0.058), (s * 0.072, by - 0.03 + k * 0.02, 0.03), "Anthracite", g, bevel=0.002)
    # Geel-zwarte band en koelribben vooraan, stalen kraag, klauwplaat.
    cyl(0.0755, 0.03, (0, by, -0.135), "Hazard", g, axis="z", verts=22, bevel=0.0)
    for z in (-0.168, -0.183, -0.198):
        torus(0.067, 0.008, (0, by, z), "DarkSteel", g, axis="z", major_seg=22, minor_seg=6)
    cyl(0.057, 0.03, (0, by, -0.217), "Steel", g, axis="z", verts=18, bevel=0.005)
    cyl(0.045, 0.06, (0, by, -0.26), "DarkSteel", g, axis="z", verts=16, bevel=0.006)
    for k in range(3):  # klemklauwen
        a = k * math.tau / 3
        box((0.012, 0.012, 0.05), (math.cos(a) * 0.04, by + math.sin(a) * 0.04, -0.262), "Steel", g, bevel=0.003)
    # Draaggreep boven, met een lampje vooraan.
    tube([(0, by + 0.068, 0.06), (0, by + 0.13, 0.045), (0, by + 0.14, -0.07), (0, by + 0.075, -0.115)], 0.017, "Anthracite", g, verts=10)
    cyl(0.024, 0.026, (0, by + 0.075, -0.175), "Anthracite", g, axis="z", verts=16, bevel=0.004)
    cyl(0.017, 0.006, (0, by + 0.075, -0.19), "Lens", g, axis="z", verts=16, bevel=0.0)
    # Accupak onder de achterkant, met een gele streep en een ledje.
    box((0.088, 0.072, 0.13), (0, -0.085, 0.04), "Anthracite", g, bevel=0.012, segments=3)
    box((0.09, 0.013, 0.132), (0, -0.07, 0.04), "Yellow", g, bevel=0.002)
    for s in (-1, 1):
        sphere(0.0075, (s * 0.0445, -0.095, -0.005), "Cyan", g, segments=10, rings=5)
    # Label op de flank.
    for s in (-1, 1):
        box((0.003, 0.04, 0.1), (s * 0.075, by - 0.005, -0.06), "Cream", g, bevel=0.0)
        text("DRILL T1", 0.017, (s * 0.0772, by - 0.006, -0.06), (0, 90 * s, 0), "DecalDark", g, extrude=0.0015)


def build_bit():
    g = "Drill_Bit"
    x, y, z = BIT_PIVOT
    # Spiraalboor: een platte doorsnede die over de lengte 3 keer rond draait, spits vooraan.
    n = 14
    pts = [(x, y, z - 0.25 * i / (n - 1)) for i in range(n)]
    radii = []
    for i in range(n):
        k = i / (n - 1)
        r = 0.031 * (1.0 - 0.25 * k)
        if i == n - 1:
            r = 0.0
        elif i == n - 2:
            r *= 0.45
        radii.append((r, r * 0.42))
    loft(pts, radii, "CutterSteel", g, verts=12, up=(0, 1, 0), twist=1080.0)
    cyl(0.026, 0.02, (x, y, z - 0.01), "DarkSteel", g, axis="z", verts=12, bevel=0.003)  # schacht in de klauwplaat


# --- Robothand (first person) ---------------------------------------------------------
# Zelfde stijl als de robot (robot.py): spelerskleur voor de pantserplaat en de duim, antraciet
# vingers en onderarm, donker staal op de gewrichten. Dik en afgerond, geen dunne stokjes.

GRIP_R = 0.031  # straal van de greep die de gesloten hand omvat
# Vingers van boven (wijsvinger) naar onder (pink): hoogte y en een maatfactor.
FINGERS = ((0.039, 1.0), (0.013, 1.03), (-0.013, 0.97), (-0.039, 0.88))
HAND_YAW = -32.0  # graden rond y: de handrug draait iets naar de camera (+z)


def _frame(p0, p1, up=(0, 1, 0)):
    """Rechtshandige basis (Godot) langs p0→p1: (u, side, t), u = de `up`-richting loodrecht op t."""
    a, b = Vector(p0), Vector(p1)
    t = b - a
    length = t.length
    t.normalize()
    side = t.cross(Vector(up))
    if side.length < 1e-6:
        side = t.cross(Vector((1, 0, 0)))
    side.normalize()
    u = side.cross(t).normalized()
    return a, b, u, side, t, length


def _place(o, centre, axes, scale):
    """Zet een primitief (eenheidsgrootte, rond de oorsprong) op een Godot-plek met eigen assen."""
    cols = [G(*ax) * s for ax, s in zip(axes, scale)]
    p = G(*centre)
    o.matrix_world = Matrix(((cols[0].x, cols[1].x, cols[2].x, p.x), (cols[0].y, cols[1].y, cols[2].y, p.y),
                             (cols[0].z, cols[1].z, cols[2].z, p.z), (0, 0, 0, 1)))
    bpy.context.view_layer.update()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def obox(p0, p1, w, h, up, material, group, bevel=0.006, segments=3):
    """Afgerond blok van p0 naar p1 (Godot): breedte w opzij, dikte h langs `up` (kootjes, platen)."""
    a, b, u, side, t, length = _frame(p0, p1, up)
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    _place(bpy.context.active_object, (a + b) / 2, (u, side, t), (h, w, length))
    return kit._finish(bpy.context.active_object, material, group, bevel, segments)


def rod(p0, p1, r, material, group, r2=None, verts=18, bevel=0.003, segments=2):
    """Cilinder (of kegel met eindstraal r2) van p0 naar p1 (Godot)."""
    a, b, u, side, t, length = _frame(p0, p1)
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=1.0, depth=1.0, vertices=verts)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=1.0, radius2=r2 / r, depth=1.0, vertices=verts)
    _place(bpy.context.active_object, (a + b) / 2, (u, side, t), (r, r, length))
    return kit._finish(bpy.context.active_object, material, group, bevel, segments)


def cap(centre, axis_dir, r, depth, material, group, segments=18, rings=9):
    """Afgeplatte bol (dop) met straal r opzij en halve dikte `depth` langs axis_dir."""
    c = Vector(centre)
    _a, _b, u, side, t, _len = _frame(c, c + Vector(axis_dir))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=segments, ring_count=rings)
    _place(bpy.context.active_object, c, (u, side, t), (r, r, depth))
    return kit._finish(bpy.context.active_object, material, group, 0.0)


def _rot_y(p, deg):
    """Godot-punt draaien rond y (positief: +x draait naar −z)."""
    a = math.radians(deg)
    x, y, z = p
    return Vector((math.cos(a) * x + math.sin(a) * z, y, -math.sin(a) * x + math.cos(a) * z))


def _around(alpha_deg, radius, y):
    """Punt rond de greep: hoek vanaf +x naar −z (vooraan), op hoogte y."""
    a = math.radians(alpha_deg)
    return Vector((math.cos(a) * radius, y, -math.sin(a) * radius))


def forearm(wrist, direction, g, length=0.135, r=0.033):
    """Korte donkere onderarm zoals bij de robot: kogelgewricht, manchet in de spelerskleur,
    antraciet buis met twee ribbels en een ronde dop. Geeft het eindpunt (achterkant van de dop)."""
    w = Vector(wrist)
    d = Vector(direction).normalized()
    sphere(r * 0.72, tuple(w), "DarkSteel", g, segments=16, rings=8)  # polsgewricht
    rod(w + d * 0.022, w + d * 0.05, r * 1.2, "PlayerColor", g, verts=20, bevel=0.007, segments=3)  # manchet
    rod(w + d * 0.045, w + d * length, r, "Anthracite", g, r2=r * 1.06, verts=18, bevel=0.0)
    for k in (0.4, 0.62):  # segmentringen
        c = w + d * (0.045 + (length - 0.045) * k)
        rod(c - d * 0.006, c + d * 0.006, r * 1.12, "DarkSteel", g, verts=18, bevel=0.003, segments=2)
    rod(w + d * (length - 0.012), w + d * length, r * 1.14, "DarkSteel", g, verts=18, bevel=0.003, segments=2)
    cap(w + d * length, d, r * 1.06, r * 0.62, "Anthracite", g)
    end = w + d * (length + r * 0.62)
    return end


def _finger(g, joints, w, h, ups):
    """Vinger uit twee afgeronde kootjes (antraciet) met een stalen scharnier per vinger."""
    (p0, p1, p2), (up1, up2) = joints, ups
    obox(p0, p1, w, h, up1, "Anthracite", g, bevel=0.0075, segments=3)
    obox(p1, p2, w * 0.96, h * 0.95, up2, "Anthracite", g, bevel=0.0075, segments=3)
    # Scharnier: korte stalen as dwars door het gewricht, net zo breed als de vinger (elk zijn eigen
    # knokkel, geen doorlopende balk) en dikker dan het kootje zodat hij aan de buitenkant uitsteekt.
    rod(p1 - Vector((0, w * 0.45, 0)), p1 + Vector((0, w * 0.45, 0)), h * 0.47, "DarkSteel", g, verts=14, bevel=0.002)


def build_glove():
    """Gesloten hand rond een verticale greep (straal GRIP_R) door de oorsprong.
    Eerst opgebouwd als 'handdruk' (handrug naar +x, pols naar +z, vingers krullen vooraan om de
    greep naar −x), daarna HAND_YAW rond y gedraaid zodat de handrug iets naar de camera kijkt."""
    g = "Glove"
    rot = lambda p: _rot_y(p, HAND_YAW)  # noqa: E731
    up_x = rot((1, 0, 0))
    # Handpalm (antraciet) en de bolle pantserplaat op de handrug (spelerskleur).
    obox(rot((0.043, 0, 0.05)), rot((0.043, 0, -0.03)), 0.098, 0.026, up_x, "Anthracite", g, bevel=0.009)
    obox(rot((0.063, 0.002, 0.052)), rot((0.063, 0.002, -0.026)), 0.108, 0.025, up_x, "PlayerColor", g,
         bevel=0.0105, segments=4)
    cap(rot((0.071, 0.002, 0.014)), up_x, 0.04, 0.012, "PlayerColor", g)  # bolling op de plaat
    for s in (-1, 1):  # twee boutjes
        sphere(0.0055, tuple(rot((0.0755, 0.002 + s * 0.036, 0.034))), "Steel", g, segments=10, rings=5)
    for y, k in FINGERS:
        mcp = rot(Vector((0.049, y, -0.035)))
        pip = rot(_around(116, 0.047, y))
        tip = rot(_around(190 - (1 - k) * 40, 0.045, y))
        up1 = rot(_around(78, 1.0, 0))
        up2 = rot(_around(156, 1.0, 0))
        _finger(g, (mcp, pip, tip), 0.0235 * k, 0.0245 * k, (up1, up2))
        sphere(0.0128 * k, tuple(rot((0.055, y, -0.038))), "DarkSteel", g, scale=(1, 0.85, 1), segments=14, rings=7)
    # Duim (spelerskleur, dik en kort): van de muis over de achterkant (+z, naar de camera), de top
    # rust schuin omlaag op de wijsvinger.
    t0 = rot(_around(-24, 0.058, 0.05))
    t1 = rot(_around(-86, 0.055, 0.053))
    t2 = rot(_around(-136, 0.05, 0.042))
    sphere(0.02, tuple(t0), "DarkSteel", g, segments=14, rings=7)
    obox(t0, t1, 0.034, 0.032, (0, 1, 0), "PlayerColor", g, bevel=0.0115, segments=3)
    obox(t1, t2 + (t2 - t1).normalized() * 0.006, 0.03, 0.029, (0, 1, 0), "PlayerColor", g, bevel=0.0115, segments=3)
    rod(t1 - Vector((0, 0.014, 0)), t1 + Vector((0, 0.014, 0)), 0.0145, "DarkSteel", g, verts=14, bevel=0.002)
    # Pols en korte onderarm, naar achteren-onder-rechts (+z, −y, +x): rechtsonder uit beeld.
    # Vrij steil omlaag: in de rusthouding loopt hij dan naar de hoek rechtsonder, en bij het
    # inslaan wijst hij minder naar boven in beeld.
    wrist = rot((0.046, -0.02, 0.062))
    end = forearm(wrist, (0.3, -0.72, 0.62), g)
    print(f"[tools] Glove: pols {tuple(round(c, 3) for c in wrist)}, einde onderarm {tuple(round(c, 3) for c in end)}")


def build_glove_open():
    """Open rechterhand om iets te dragen. Oorsprong = midden van de handpalm (het contactvlak),
    palm naar −x (naar het midden van het beeld), vingers vooruit (−z) en ±35° gekruld,
    duim bovenaan schuin vooruit-omhoog, onderarm naar achteren (+z) en licht omlaag.
    In Godot gespiegeld (scale.x = −1) voor de linkerhand."""
    g = "Glove_Open"
    obox((0.012, 0, 0.036), (0.012, 0, -0.034), 0.096, 0.024, (1, 0, 0), "Anthracite", g, bevel=0.009)
    obox((0.033, 0.002, 0.042), (0.033, 0.002, -0.03), 0.106, 0.024, (1, 0, 0), "PlayerColor", g,
         bevel=0.0105, segments=4)
    cap((0.041, 0.002, 0.006), (1, 0, 0), 0.04, 0.012, "PlayerColor", g)
    for s in (-1, 1):
        sphere(0.0055, (0.0455, 0.002 + s * 0.036, 0.026), "Steel", g, segments=10, rings=5)
    for y, k in FINGERS:
        mcp = Vector((0.016, y, -0.04))
        a1, a2 = math.radians(14), math.radians(36)  # kromming per kootje (naar de palm, −x)
        d1 = Vector((-math.sin(a1), 0, -math.cos(a1)))
        d2 = Vector((-math.sin(a2), 0, -math.cos(a2)))
        pip = mcp + d1 * 0.04 * k
        tip = pip + d2 * (0.036 if k >= 0.95 else 0.032) * k
        up1 = Vector((math.cos(a1), 0, -math.sin(a1)))
        up2 = Vector((math.cos(a2), 0, -math.sin(a2)))
        _finger(g, (mcp, pip, tip), 0.0235 * k, 0.0245 * k, (up1, up2))
        sphere(0.0128 * k, (0.03, y, -0.042), "DarkSteel", g, scale=(1, 0.85, 1), segments=14, rings=7)
    # Duim bovenaan, schuin vooruit-omhoog en iets naar de palmkant.
    t0 = Vector((0.008, 0.05, 0.006))
    t1 = t0 + Vector((-0.28, 0.5, -0.82)).normalized() * 0.036
    t2 = t1 + Vector((-0.42, 0.22, -0.88)).normalized() * 0.03
    sphere(0.019, tuple(t0), "DarkSteel", g, segments=14, rings=7)
    obox(t0, t1, 0.032, 0.03, (1, 0, 0), "PlayerColor", g, bevel=0.011, segments=3)
    obox(t1, t2, 0.029, 0.027, (1, 0, 0), "PlayerColor", g, bevel=0.011, segments=3)
    rod(t1 - Vector((0.0145, 0, 0)), t1 + Vector((0.0145, 0, 0)), 0.0135, "DarkSteel", g, verts=14, bevel=0.002)
    # Rubberen grijpkussens in de palm.
    for z in (-0.016, 0.016):
        obox((0.0, 0.002, z + 0.011), (0.0, 0.002, z - 0.011), 0.078, 0.008, (1, 0, 0), "Rubber", g, bevel=0.0035)
    wrist = (0.024, -0.006, 0.062)
    end = forearm(wrist, (0.12, -0.24, 0.96), g, length=0.15)  # licht naar buiten, naar de schouder
    print(f"[tools] Glove_Open: pols {wrist}, einde onderarm {tuple(round(c, 3) for c in end)}")


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_pickaxe()
    build_drill()
    build_bit()
    build_glove()
    build_glove_open()
    root = bpy.data.objects.new("Tools", None)
    bpy.context.collection.objects.link(root)
    objects = {
        "Pickaxe": join_group("Pickaxe", "Pickaxe"),
        "Drill": join_group("Drill", "Drill"),
        "Drill_Bit": join_group("Drill_Bit", "Drill_Bit", origin=BIT_PIVOT),
        "Glove": join_group("Glove", "Glove"),
        "Glove_Open": join_group("Glove_Open", "Glove_Open"),
    }
    for name, o in objects.items():
        bake_wear(o, strength=6.0, seed=hash(name) % 1000)
        parent_to(o, root)
        print(f"[tools] {name:10s} {tri_count(o):6d} driehoeken")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    export_glb(OUT)
    print(f"[tools] geschreven: {OUT}")


main()
