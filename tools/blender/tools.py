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
  Glove       robothand rond een verticale greep in de oorsprong, met onderarm (materiaal PlayerColor)
"""

import math
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).parent))
import kit  # noqa: E402
from kit import G, PARTS, bake_wear, box, cyl, export_glb, join_group, loft, parent_to, sphere, text, tri_count, torus, tube  # noqa: E402

import bpy  # noqa: E402

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


def build_glove():
    g = "Glove"
    # Handrug in de spelerskleur, gelede antraciet vingers rond de greep, duim erover.
    box((0.07, 0.105, 0.06), (0.028, 0.0, 0.03), "PlayerColor", g, bevel=0.022, segments=3, rot=(0, -10, -6))
    for k, yy in enumerate((-0.04, -0.013, 0.014, 0.041)):
        # Vingers: voorste kootje voor de greep, tweede kootje krult links terug.
        cyl(0.0165, 0.052, (0.004, yy, -0.032), "Anthracite", g, axis="x", verts=10, bevel=0.005)
        sphere(0.018, (-0.026, yy, -0.022), "Anthracite", g, segments=10, rings=5)
        cyl(0.015, 0.03, (-0.034, yy, 0.002), "Anthracite", g, axis="z", verts=10, bevel=0.004)
    cyl(0.017, 0.062, (-0.018, 0.058, 0.012), "PlayerColor", g, verts=10, bevel=0.006, rot=(-40, 0, 35))  # duim
    # Pols en onderarm (crème romp, gekleurde manchet), naar rechtsonder-achter uit beeld.
    cyl(0.047, 0.045, (0.05, -0.06, 0.07), "PlayerColor", g, verts=16, bevel=0.008, rot=(55, 0, -35))
    loft([(0.06, -0.075, 0.085), (0.1, -0.15, 0.2), (0.13, -0.21, 0.31)], [0.04, 0.044, 0.048], "Cream", g, verts=14)
    torus(0.046, 0.007, (0.105, -0.16, 0.215), "Anthracite", g, axis="z", major_seg=16, minor_seg=5)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_pickaxe()
    build_drill()
    build_bit()
    build_glove()
    root = bpy.data.objects.new("Tools", None)
    bpy.context.collection.objects.link(root)
    objects = {
        "Pickaxe": join_group("Pickaxe", "Pickaxe"),
        "Drill": join_group("Drill", "Drill"),
        "Drill_Bit": join_group("Drill_Bit", "Drill_Bit", origin=BIT_PIVOT),
        "Glove": join_group("Glove", "Glove"),
    }
    for name, o in objects.items():
        bake_wear(o, strength=6.0, seed=hash(name) % 1000)
        parent_to(o, root)
        print(f"[tools] {name:10s} {tri_count(o):6d} driehoeken")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    export_glb(OUT)
    print(f"[tools] geschreven: {OUT}")


main()
