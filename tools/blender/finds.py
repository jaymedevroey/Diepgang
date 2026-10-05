"""Vondsten en puin van Diepgang (GDD §4: vondstfamilies; stijlgids: botten ivoor met okervlekken,
relieken brons en goud, rommel herkenbaar en grappig).

Gebruik:
    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup \\
        --python tools/blender/finds.py -- game/assets/models/finds.glb

Godot-coördinaten, elk object rond zijn eigen middelpunt (de korst is een ellipsoïde rond de oorsprong).
Objecten (namen = FindKinds.KEYS in Godot):
  Femur Vertebra Rib Skull Claw     skeletten (zandsteen)
  Lamp                              oude mijnwerkerslamp (zandsteen)
  Coins Bottle Gnome Tv             klei: muntenbuidel, oude fles, tuinkabouter, oude tv
  Geode Gold                        diep zandsteen: opengebroken geode, goudklomp
  Chunk_0..2                        puinbrokjes (eenheidsgrootte, in Godot geschaald en gekleurd)
"""

import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

sys.path.append(str(Path(__file__).parent))
import kit  # noqa: E402
from kit import G, PARTS, bake_wear, boolean, box, cyl, export_glb, join_group, loft, parent_to, sphere, tri_count, torus, unregister  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = Path(ARGS[0]) if ARGS else Path("game/assets/models/finds.glb")

kit.PALETTE.update({
    "Bone": ((0.88, 0.82, 0.67), 0.0, 0.65, None),
    "BoneDark": ((0.30, 0.22, 0.14), 0.0, 0.85, None),
    "Gold": ((1.0, 0.76, 0.26), 1.0, 0.28, None),
    "Brass": ((0.74, 0.54, 0.26), 0.85, 0.4, None),
    "GlassGreen": ((0.22, 0.5, 0.28), 0.0, 0.08, None),
    "Skin": ((0.95, 0.72, 0.6), 0.0, 0.55, None),
    "Amethyst": ((0.62, 0.38, 0.88), 0.0, 0.15, ((0.55, 0.3, 0.9), 0.8)),
    "Rock": ((0.42, 0.37, 0.33), 0.0, 0.92, None),
    "Quartz": ((0.92, 0.9, 0.86), 0.0, 0.35, None),
    "Green": ((0.3, 0.55, 0.22), 0.0, 0.7, None),
})


def lumpy(name, radius, scale, material, group, seed, amp=0.25, subdiv=2, flat=True, pos=(0, 0, 0)):
    """Onregelmatige klomp (geode, goud, puin): icosfeer met ruis op de straal."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=1.0, location=G(*pos))
    o = bpy.context.active_object
    o.name = name
    rng = random.Random(seed)
    for v in o.data.vertices:
        d = v.co.normalized()
        k = 1.0 + noise.noise(d * 1.7 + Vector((seed * 1.3, 0, 0))) * amp + rng.uniform(-amp, amp) * 0.25
        v.co = d * k
    o.scale = kit.GS(*(radius * s for s in scale))
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    kit._finish(o, material, group, 0.0, smooth=not flat)
    return o


# --- Skeletten ------------------------------------------------------------------------

def build_femur():
    g = "Femur"
    n = 7
    pts = [(-0.27 + 0.54 * i / (n - 1), 0.012 * math.sin(i / (n - 1) * math.pi), 0) for i in range(n)]
    loft(pts, [0.05, 0.043, 0.038, 0.036, 0.038, 0.043, 0.05], "Bone", g, verts=14, up=(0, 0, 1))
    sphere(0.072, (0.335, 0.045, 0.0), "Bone", g, segments=16, rings=8)  # kop
    sphere(0.056, (0.295, -0.035, 0.03), "Bone", g, segments=14, rings=7)  # trochanter
    for s in (-1, 1):  # gewrichtsknobbels onderaan
        sphere(0.06, (-0.315, -0.012, s * 0.04), "Bone", g, scale=(1, 0.9, 0.85), segments=14, rings=7)
    box((0.12, 0.006, 0.01), (0.02, 0.03, 0.0365), "BoneDark", g, bevel=0.0, rot=(0, 0, 12))  # barstje


def build_vertebra():
    g = "Vertebra"
    cyl(0.085, 0.095, (0, -0.045, 0), "Bone", g, axis="z", verts=18, bevel=0.022, segments=3)
    torus(0.052, 0.021, (0, 0.06, 0), "Bone", g, axis="z", major_seg=18, minor_seg=8)
    loft([(0, 0.09, 0.0), (0, 0.17, 0.02), (0, 0.25, 0.05)], [(0.026, 0.016), (0.018, 0.011), 0.0], "Bone", g, verts=10, up=(0, 0, 1))
    for s in (-1, 1):
        loft([(s * 0.04, 0.05, 0.0), (s * 0.1, 0.07, 0.0), (s * 0.16, 0.09, 0.01)], [0.021, 0.016, 0.009], "Bone", g, verts=10, up=(0, 0, 1))
    cyl(0.03, 0.1, (0, 0.06, 0), "BoneDark", g, axis="z", verts=12, bevel=0.0)  # zenuwkanaal (donker gat)


def build_rib():
    """Rib: brede, platte boog (geen dun noedeltje) met een kop en knobbel aan het wervel-uiteinde,
    licht getordeerd en een tikje uit het vlak gebogen. Lengte en boog zoals voorheen (±0,64 m)."""
    g = "Rib"
    n = 13
    pts = []
    radii = []
    for i in range(n):
        k = i / (n - 1)
        a = math.radians(-70 + 142 * k)
        pts.append((math.sin(a) * 0.32, math.cos(a) * 0.32 - 0.26, 0.022 * math.sin(k * math.pi) - 0.008 * k))
        # rx = dikte in het vlak van de boog, ry = breedte dwars erop (plat en breed, zoals een echte rib)
        radii.append((0.024 - 0.006 * k, 0.032 + 0.008 * math.sin(k * math.pi * 0.8) - 0.006 * k))
    radii[-2] = (0.016, 0.026)
    radii[-1] = (0.01, 0.016)  # afgerond uiteinde, geen spits
    loft(pts, radii, "Bone", g, verts=12, up=(0, 0, 1), twist=28.0)
    # Hals en kop aan het wervel-uiteinde: buigt naar binnen en eindigt in een dikke knobbel.
    p0 = Vector(pts[0])
    neck = [tuple(p0), tuple(p0 + Vector((0.006, -0.03, 0.004))), tuple(p0 + Vector((0.022, -0.055, 0.01)))]
    loft(neck, [(0.024, 0.032), (0.021, 0.028), (0.021, 0.026)], "Bone", g, verts=12, up=(0, 0, 1))
    sphere(0.035, tuple(p0 + Vector((0.03, -0.068, 0.012))), "Bone", g, scale=(1.0, 0.9, 1.05), segments=16, rings=8)  # kop
    sphere(0.024, tuple(p0 + Vector((-0.018, 0.004, 0.006))), "Bone", g, segments=12, rings=6)  # knobbel (tuberkel)


# Bovenschedel (van achter naar de snuit): z, hoogte van de as, halve breedte, halve hoogte.
SKULL = [
    (0.275, 0.07, 0.06, 0.055), (0.25, 0.065, 0.112, 0.098), (0.195, 0.06, 0.148, 0.124),
    (0.12, 0.052, 0.158, 0.13), (0.04, 0.036, 0.144, 0.118), (-0.05, 0.018, 0.12, 0.1),
    (-0.14, 0.003, 0.1, 0.085), (-0.23, -0.01, 0.082, 0.07), (-0.3, -0.02, 0.066, 0.058),
    (-0.345, -0.028, 0.05, 0.046), (-0.372, -0.033, 0.026, 0.024),
]
# Doorsnede: platte onderkant (de tandrij), bolle wangen, smallere top.
SKULL_PROFILE = [(0.0, -0.78), (0.5, -0.8), (0.86, -0.62), (1.0, -0.25), (0.98, 0.15), (0.82, 0.52),
                 (0.5, 0.82), (0.0, 1.0), (-0.5, 0.82), (-0.82, 0.52), (-0.98, 0.15), (-1.0, -0.25),
                 (-0.86, -0.62), (-0.5, -0.8)]
JAW_OPEN = -7.0  # graden rond x door het kaakscharnier (negatief = mond open)
JAW_HINGE = (0.0, -0.072, 0.222)


def _skull_at(z):
    """(as-hoogte, halve breedte, halve hoogte) van de bovenschedel op diepte z."""
    for a, b in zip(SKULL, SKULL[1:]):
        if b[0] <= z <= a[0]:
            k = (a[0] - z) / (a[0] - b[0])
            return tuple(a[i] + (b[i] - a[i]) * k for i in range(1, 4))
    return SKULL[-1][1:] if z < SKULL[-1][0] else SKULL[0][1:]


def _carve(target, pos, radius, scale, material="BoneDark"):
    """Holte in de schedel (boolean); de wanden krijgen het materiaal van de snijvorm (donker)."""
    cutter = sphere(radius, pos, material, "_cut", scale=scale, segments=20, rings=10)
    unregister(cutter)
    boolean(target, cutter)


def build_skull():
    """Schedel van een buitenaards dino-achtig beest (de duurste vondst): wigvormig silhouet,
    diepe oogkassen onder een wenkbrauwrand met hoorntjes, een gat voor het oog (antorbitaal),
    neusgaten vooraan, een rij tanden in de bovenkaak en een losse onderkaak die op een kier staat."""
    g = "Skull"
    head = loft([(0, y, z) for z, y, _rx, _ry in SKULL], [(rx, ry) for _z, _y, rx, ry in SKULL], "Bone", g,
                verts=14, up=(0, 1, 0), profile=SKULL_PROFILE)
    head.data.materials.append(kit.mat("BoneDark"))
    for s in (-1, 1):
        _carve(head, (s * 0.142, 0.096, 0.108), 0.058, (0.78, 1.0, 1.12))       # oogkas
        _carve(head, (s * 0.124, 0.022, -0.075), 0.04, (0.62, 0.72, 1.55))       # gat voor het oog
        _carve(head, (s * 0.142, 0.012, 0.212), 0.034, (0.8, 1.05, 0.95))        # slaapgat achter het oog
        _carve(head, (s * 0.022, -0.004, -0.356), 0.021, (0.85, 0.9, 1.45))      # neusgat
    for s in (-1, 1):
        # Wenkbrauwrand die over de oogkas hangt, met een hoorntje erop.
        loft([(s * 0.115, 0.142, 0.175), (s * 0.132, 0.156, 0.115), (s * 0.124, 0.145, 0.045), (s * 0.098, 0.12, -0.012)],
             [(0.014, 0.012), (0.028, 0.026), (0.024, 0.022), (0.012, 0.012)], "Bone", g, verts=12, up=(0, 1, 0))
        # Hoorn naar achter geveegd (geen oor): vanaf de wenkbrauw schuin omhoog en naar achteren.
        loft([(s * 0.12, 0.156, 0.122), (s * 0.138, 0.19, 0.168), (s * 0.15, 0.208, 0.222), (s * 0.156, 0.211, 0.268)],
             [0.027, 0.018, 0.009, 0.0], "Bone", g, verts=10)
        # Jukbeen: brede rand onder het oog, geeft het silhouet een wang.
        loft([(s * 0.14, -0.018, 0.222), (s * 0.15, -0.026, 0.13), (s * 0.14, -0.032, 0.035), (s * 0.114, -0.036, -0.06)],
             [(0.02, 0.026), (0.022, 0.03), (0.019, 0.024), (0.01, 0.012)], "Bone", g, verts=10, up=(0, 1, 0))
        sphere(0.03, (s * 0.142, -0.066, 0.222), "Bone", g, segments=14, rings=7)  # kaakgewricht
        # Tanden in de bovenkaak: voorin langer, naar achter kleiner; licht naar achter gebogen.
        for k in range(8):
            z = -0.334 + k * 0.047
            yc, rx, ry = _skull_at(z)
            root = Vector((s * 0.72 * rx, yc - 0.64 * ry, z))
            length = 0.056 - k * 0.0035
            r = 0.0145 - k * 0.0007
            mid = root + Vector((-s * 0.002, -length * 0.55, 0.002))
            tip = root + Vector((-s * 0.005, -length, 0.01))
            loft([tuple(root), tuple(mid), tuple(tip)], [r, r * 0.68, 0.0], "Quartz", g, verts=8)
    # Middenkam bovenop.
    loft([(0, 0.17, 0.25), (0, 0.19, 0.17), (0, 0.186, 0.09), (0, 0.15, 0.0)], [(0.011, 0.018), (0.013, 0.022),
         (0.012, 0.018), (0.006, 0.006)], "Bone", g, verts=10, up=(0, 1, 0))
    # Onderkaak: twee takken die vooraan samenkomen, met kleinere tanden naar boven; staat op een kier.
    jaw_parts = []
    for s in (-1, 1):
        ramus = [(s * 0.142, -0.078, 0.226), (s * 0.135, -0.097, 0.14), (s * 0.118, -0.107, 0.04),
                 (s * 0.094, -0.112, -0.07), (s * 0.066, -0.114, -0.18), (s * 0.036, -0.114, -0.27), (s * 0.006, -0.112, -0.33)]
        rr = [(0.024, 0.044), (0.025, 0.05), (0.024, 0.044), (0.023, 0.036), (0.022, 0.03), (0.021, 0.026), (0.022, 0.024)]
        jaw_parts.append(loft(ramus, rr, "Bone", g, verts=12, up=(0, 1, 0)))
        for k in range(5):
            i = 5 - k
            base = Vector(ramus[i]) * 0.65 + Vector(ramus[i - 1]) * 0.35
            root = base + Vector((0, rr[i][1] * 0.75, 0))
            jaw_parts.append(loft([tuple(root), tuple(root + Vector((0, 0.04 - k * 0.003, -0.004)))],
                                  [0.0125 - k * 0.0007, 0.0], "Quartz", g, verts=8))
    hinge = G(*JAW_HINGE)
    m = Matrix.Translation(hinge) @ Matrix.Rotation(math.radians(JAW_OPEN), 4, "X") @ Matrix.Translation(-hinge)
    for o in jaw_parts:
        o.data.transform(m)


def build_claw():
    g = "Claw"
    pts = [(0, -0.03, 0.11), (0, 0.035, 0.05), (0, 0.06, -0.03), (0, 0.045, -0.11), (0, -0.01, -0.17), (0, -0.08, -0.205)]
    loft(pts, [(0.045, 0.03), (0.04, 0.027), (0.032, 0.022), (0.024, 0.016), (0.014, 0.01), 0.0], "Bone", g, verts=12, up=(1, 0, 0))
    sphere(0.046, (0, -0.04, 0.125), "Bone", g, segments=14, rings=7)
    loft(pts[-3:], [(0.026, 0.018), (0.016, 0.011), 0.0], "BoneDark", g, verts=12, up=(1, 0, 0))  # donkere punt


# --- Relieken en metalen -----------------------------------------------------------------

def build_lamp():
    g = "Lamp"
    cyl(0.066, 0.06, (0, -0.135, 0), "Brass", g, verts=18, bevel=0.012)  # brandstoftank
    torus(0.062, 0.008, (0, -0.105, 0), "Brass", g, axis="y", major_seg=18, minor_seg=6)
    cyl(0.05, 0.13, (0, -0.035, 0), "Glass", g, verts=18, bevel=0.0)
    cyl(0.006, 0.05, (0, -0.07, 0), "Anthracite", g, verts=6, bevel=0.0)  # lont
    for k in range(4):
        a = k * math.tau / 4 + 0.4
        cyl(0.0045, 0.14, (math.cos(a) * 0.058, -0.035, math.sin(a) * 0.058), "Brass", g, verts=6, bevel=0.0)
    torus(0.058, 0.005, (0, 0.035, 0), "Brass", g, axis="y", major_seg=18, minor_seg=5)
    cyl(0.062, 0.05, (0, 0.06, 0), "Brass", g, verts=18, bevel=0.01, r2=0.03)  # dak
    cyl(0.022, 0.04, (0, 0.1, 0), "Brass", g, verts=12, bevel=0.005)  # schoorsteentje
    torus(0.045, 0.0065, (0, 0.15, 0), "Brass", g, axis="z", major_seg=18, minor_seg=6)  # hengsel


def build_coins():
    g = "Coins"
    sphere(0.075, (0, -0.025, 0), "Leather", g, scale=(1.1, 0.8, 1.0), segments=16, rings=8)
    cyl(0.03, 0.045, (0, 0.04, 0), "Leather", g, verts=12, bevel=0.01, r2=0.042)
    torus(0.033, 0.006, (0, 0.035, 0), "DecalDark", g, axis="y", major_seg=14, minor_seg=5)
    rng = random.Random(4)
    for k in range(7):  # uitgerolde munten
        a = rng.uniform(-1.2, 1.4)
        d = rng.uniform(0.08, 0.12)
        cyl(0.022, 0.005, (math.cos(a) * d, -0.075, math.sin(a) * d), "Gold", g, verts=14, bevel=0.0015,
            rot=(rng.uniform(-25, 25), 0, rng.uniform(-25, 25)))
    for k in range(4):  # stapeltje
        cyl(0.022, 0.0055, (0.075, -0.075 + k * 0.006, -0.065), "Gold", g, verts=14, bevel=0.0015, rot=(0, k * 17, 0))


def build_gold():
    g = "Gold"
    lumpy("gold", 0.11, (1.2, 0.8, 1.0), "Gold", g, seed=21, amp=0.3, subdiv=3, flat=False)
    lumpy("quartz", 0.045, (1.0, 0.8, 1.0), "Quartz", g, seed=5, amp=0.25, subdiv=1, pos=(0.09, 0.03, 0.04))
    lumpy("quartz2", 0.035, (1.0, 0.9, 1.0), "Quartz", g, seed=9, amp=0.25, subdiv=1, pos=(-0.08, -0.04, -0.05))


def build_geode():
    g = "Geode"
    outer = lumpy("geode", 0.135, (1.0, 0.85, 1.1), "Rock", g, seed=13, amp=0.12, subdiv=3)
    hollow = sphere(0.1, (0, 0, 0), "Rock", "_cut", scale=(1.0, 0.82, 1.05), segments=24, rings=12)
    unregister(hollow)
    boolean(outer, hollow)
    cut = box((0.3, 0.4, 0.4), (0.19, 0, 0), "Rock", "_cut", bevel=0.0)
    unregister(cut)
    boolean(outer, cut)
    # Kristallen in de holte, naar het midden gericht (enkel waar je ze door de opening ziet).
    rng = random.Random(3)
    for k in range(34):
        d = Vector((rng.uniform(-1.0, 0.25), rng.uniform(-1, 1), rng.uniform(-1, 1))).normalized()
        base = Vector((d.x * 0.1, d.y * 0.082, d.z * 0.105))
        tip = base * rng.uniform(0.45, 0.7)
        loft([tuple(base), tuple(tip)], [rng.uniform(0.012, 0.022), 0.0], "Amethyst", g, verts=6, smooth=False)


# --- Rommel -----------------------------------------------------------------------------

def build_bottle():
    g = "Bottle"
    loft([(0, -0.14, 0), (0, -0.13, 0), (0, 0.02, 0), (0, 0.06, 0), (0, 0.095, 0), (0, 0.13, 0)],
         [0.047, 0.05, 0.05, 0.032, 0.016, 0.016], "GlassGreen", g, verts=18, up=(0, 0, 1))
    torus(0.017, 0.0045, (0, 0.13, 0), "GlassGreen", g, axis="y", major_seg=14, minor_seg=5)
    cyl(0.013, 0.032, (0, 0.142, 0), "Wood", g, verts=10, bevel=0.003)
    cyl(0.0515, 0.07, (0, -0.05, 0), "Cream", g, verts=18, bevel=0.0)  # etiket
    cyl(0.052, 0.012, (0, -0.03, 0), "Red", g, verts=18, bevel=0.0)


def build_gnome():
    g = "Gnome"
    cyl(0.09, 0.03, (0, -0.2, 0), "Green", g, verts=18, bevel=0.01)  # grasvoetje
    for s in (-1, 1):
        sphere(0.034, (s * 0.034, -0.17, -0.012), "Wood", g, scale=(1, 0.6, 1.4), segments=12, rings=6)  # laarzen
    cyl(0.075, 0.15, (0, -0.085, 0), "Blue", g, verts=18, bevel=0.02, r2=0.055)  # jas
    torus(0.068, 0.009, (0, -0.105, 0), "Anthracite", g, axis="y", major_seg=18, minor_seg=6)  # riem
    box((0.03, 0.026, 0.012), (0, -0.105, -0.075), "Gold", g, bevel=0.004)
    for s in (-1, 1):
        loft([(s * 0.055, -0.02, 0.0), (s * 0.075, -0.06, -0.03), (s * 0.04, -0.075, -0.07)], [0.022, 0.02, 0.018], "Blue", g, verts=10)
        sphere(0.02, (s * 0.03, -0.075, -0.075), "Skin", g, segments=10, rings=5)  # handjes op de buik
    sphere(0.056, (0, 0.03, 0), "Skin", g, segments=16, rings=8)  # hoofd
    sphere(0.058, (0, -0.012, -0.03), "Cream", g, scale=(1.0, 1.25, 0.65), segments=14, rings=7)  # baard
    sphere(0.017, (0, 0.035, -0.056), "Skin", g, segments=10, rings=5)  # neus
    for s in (-1, 1):
        sphere(0.0065, (s * 0.021, 0.052, -0.048), "DecalDark", g, segments=8, rings=4)
    loft([(0, 0.06, 0.005), (0, 0.13, 0.0), (0.015, 0.19, 0.015), (0.04, 0.235, 0.035)],
         [0.062, 0.045, 0.024, 0.0], "Red", g, verts=16)  # puntmuts, het puntje knakt opzij


def build_tv():
    g = "Tv"
    box((0.5, 0.38, 0.4), (0, 0.0, 0.02), "Wood", g, bevel=0.04, segments=3)
    box((0.39, 0.3, 0.03), (-0.045, 0.012, -0.17), "Anthracite", g, bevel=0.03, segments=3)
    sphere(0.17, (-0.045, 0.012, -0.175), "Screen", g, scale=(1.0, 0.78, 0.22), segments=20, rings=10)  # bolle beeldbuis
    for k, y in enumerate((0.07, -0.02)):
        cyl(0.022, 0.03, (0.195, y, -0.19), "Anthracite", g, axis="z", verts=14, bevel=0.004)
        box((0.004, 0.02, 0.008), (0.195, y + 0.01, -0.207), "Cream", g, bevel=0.0)
    for k in range(4):
        box((0.06, 0.006, 0.006), (0.195, -0.09 - k * 0.018, -0.181), "DecalDark", g, bevel=0.0)  # luidspreker
    for x in (-0.2, 0.2):
        for z in (-0.14, 0.17):
            cyl(0.016, 0.07, (x, -0.22, z), "DarkSteel", g, verts=10, bevel=0.003, r2=0.01)
    sphere(0.032, (0.0, 0.2, 0.09), "Anthracite", g, scale=(1, 0.6, 1), segments=12, rings=6)
    for s in (-1, 1):
        kit.tube([(0, 0.21, 0.09), (s * 0.19, 0.44, 0.04)], 0.005, "Steel", g, verts=6)
        sphere(0.009, (s * 0.19, 0.44, 0.04), "Steel", g, segments=8, rings=4)


# --- Puin -------------------------------------------------------------------------------

def build_chunks():
    for k in range(3):
        g = f"Chunk_{k}"
        lumpy(g, 0.5, (1.0, 0.75 + 0.1 * k, 0.9), "Rock", g, seed=31 + k * 7, amp=0.35, subdiv=1)


# --- Okervlekken op botten ------------------------------------------------------------------

BONES = ("Femur", "Vertebra", "Rib", "Skull", "Claw")
BONE_WEAR = 10.0  # sterkere slijtage-bake voor botten (andere vondsten 6)


def _smooth(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def stain(obj, seed, amount=1.0):
    """Okervlekken: ruisvlekken in kanaal G (vuil) van de slijtagekleur, enkel op Bone-vlakken.
    De Bone-shader in Godot (MolVisual.MATS) kleurt vuil oker; zonder dit kwam er enkel vuil in
    de (weinige) holtes en bleven de botten egaal."""
    me = obj.data
    attr = me.color_attributes.get("Col")
    if attr is None:
        return
    bone = {i for i, m in enumerate(me.materials) if m is not None and m.name == "Bone"}
    on_bone = [False] * len(me.vertices)
    for poly in me.polygons:
        if poly.material_index in bone:
            for v in poly.vertices:
                on_bone[v] = True
    off = Vector((seed * 3.17, seed * 1.71, seed * 0.93))
    for v in me.vertices:
        if not on_bone[v.index]:
            continue
        q = v.co * 9.0 + off
        n = noise.noise(q) * 0.7 + noise.noise(q * 2.7) * 0.3
        patch = _smooth(-0.04, 0.32, n) * amount
        c = attr.data[v.index].color
        attr.data[v.index].color = (c[0], max(c[1], patch), c[2], c[3])


def _center_group(group):
    """Schuift alle onderdelen van een groep zodat het midden van de omhullende doos in de oorsprong ligt."""
    objs = PARTS.get(group, [])
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (lo + hi) / 2
    for o in objs:
        o.matrix_world = Matrix.Translation(-c) @ o.matrix_world
    bpy.context.view_layer.update()
    size = hi - lo
    print(f"[finds] {group}: maat (Godot) x {size.x:.3f}  y {size.z:.3f}  z {size.y:.3f}")


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    builders = {
        "Femur": build_femur, "Vertebra": build_vertebra, "Rib": build_rib, "Skull": build_skull,
        "Claw": build_claw, "Lamp": build_lamp, "Coins": build_coins, "Bottle": build_bottle,
        "Gnome": build_gnome, "Tv": build_tv, "Geode": build_geode, "Gold": build_gold,
    }
    for fn in builders.values():
        fn()
    build_chunks()
    _center_group("Skull")
    root = bpy.data.objects.new("Finds", None)
    bpy.context.collection.objects.link(root)
    names = list(builders.keys()) + [f"Chunk_{k}" for k in range(3)]
    total = 0
    for name in names:
        o = join_group(name, name)
        if o is None:
            print(f"[finds] LEEG: {name}")
            continue
        if name in BONES:
            bake_wear(o, strength=BONE_WEAR, seed=hash(name) % 1000)
            stain(o, seed=sum(map(ord, name)) % 97)
        elif not name.startswith("Chunk"):
            bake_wear(o, strength=6.0, seed=hash(name) % 1000)
        parent_to(o, root)
        n = tri_count(o)
        total += n
        print(f"[finds] {name:9s} {n:6d} driehoeken")
    print(f"[finds] totaal {total}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    export_glb(OUT)
    print(f"[finds] geschreven: {OUT}")


main()
