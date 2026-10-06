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
  TitanSkull Pelvis TitanFemur      grote, zware skeletstukken (Fossielwereld, release-audit F3):
  Spine Tusk                        met twee dragen of alleen slepen
  Glowshard Bloom                   breekbare, lichtgevende kristallen (Kristalmaan)
  Chunk_0..2                        puinbrokjes (eenheidsgrootte, in Godot geschaald en gekleurd)

Referenties voor de nieuwe stukken (ter goedkeuring van Jayme, F3):
  TitanSkull   ceratopsiden (Triceratops, Styracosaurus): een kraag met gaten en knobbels op de rand,
               twee hoorns boven de ogen, een korte neushoorn en een donkere snavel. Ander silhouet
               dan de raptorachtige Skull, zodat je "groot beest" leest van ver.
  Pelvis       een bekken zoals in een museum vooraan gezien (golf 3: herwerkt, ter goedkeuring van
               Jayme): twee schotelvormige vleugels (darmbeen) met een dikke kam rond een heiligbeen,
               heupkommen opzij, en onderaan zit- en schaambeen als een plaat met een ovaal gat
               (foramen obturatum) die in de schaamvoeg samenkomt. Geen ringen meer.
  TitanFemur   het dijbeen van een sauropode: zelfde vorm als Femur, maar plomp en 1,4 m lang.
  Spine        drie vergroeide wervels op een rij (een stuk ruggengraat zoals in een fossielbed).
  Tusk         slagtand van een mammoet: een gebogen kegel met groeiringen.
  Glowshard    kwartsgroep (zeszijdige prisma's met een punt) uit een rotsvoet, cyaan gloeiend:
               leesbaar als "kristal" zoals de Morkite en Nitra in Deep Rock Galactic.
  Bloom        woestijnroos (seleniet): een roset van dunne bladen rond een gloeiende kern; ziet er
               broos uit, en dat is ze ook (R.E.P.O.: breekbare buit verliest waarde bij elke klap).
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
    # Lichtgevende kristallen (Kristalmaan); in Godot eigen materiaal (FindKinds._material).
    "GlowCyan": ((0.35, 0.92, 1.0), 0.0, 0.12, ((0.3, 0.9, 1.0), 2.5)),
    "GlowPink": ((0.95, 0.5, 0.85), 0.0, 0.12, ((1.0, 0.45, 0.85), 2.5)),
})


def plate(radius, pos, scale, rot, material, group, segments=24, rings=12):
    """Afgeplatte ellipsoïde (bladvormig bot, kraag), gedraaid rond Godot-assen (graden)."""
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, segments=segments, ring_count=rings, location=G(*pos))
    o = bpy.context.active_object
    o.scale = kit.GS(*scale)
    o.rotation_euler = kit._godot_euler(rot)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return kit._finish(o, material, group, 0.0)


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


# --- Grote skeletten (Fossielwereld): met twee dragen ---------------------------------------

# Kop van het titanbeest (van achter naar de snavel): z, hoogte van de as, halve breedte, halve hoogte.
TITAN = [
    (0.46, 0.06, 0.16, 0.15), (0.38, 0.08, 0.3, 0.25), (0.24, 0.07, 0.34, 0.28), (0.06, 0.04, 0.32, 0.26),
    (-0.12, 0.0, 0.27, 0.22), (-0.3, -0.04, 0.21, 0.18), (-0.46, -0.07, 0.15, 0.14), (-0.58, -0.09, 0.1, 0.1),
    (-0.66, -0.11, 0.05, 0.06),
]


def build_titan_skull():
    """Schedel van een titanbeest (ceratopside): kraag met twee gaten en knobbels op de rand, twee lange
    hoorns boven de ogen, een korte neushoorn, een donkere snavel en een zware onderkaak. ±1,5 m."""
    g = "TitanSkull"
    head = loft([(0, y, z) for z, y, _rx, _ry in TITAN], [(rx, ry) for _z, _y, rx, ry in TITAN], "Bone", g,
                verts=16, up=(0, 1, 0), profile=SKULL_PROFILE)
    head.data.materials.append(kit.mat("BoneDark"))
    for s in (-1, 1):
        _carve(head, (s * 0.27, 0.12, -0.04), 0.085, (0.7, 1.0, 1.15))   # oogkas
        _carve(head, (s * 0.06, -0.02, -0.6), 0.04, (0.8, 1.0, 1.4))     # neusgat
    # Kraag: een schild dat vanaf de achterkant van de schedel schuin naar achter en omhoog staat, met
    # een dikke rand, knobbels op die rand en twee gaten (fenestrae).
    tilt = math.radians(40)
    fc = Vector((0.0, 0.3, 0.5))  # midden van de kraag (de onderrand zit in de achterkant van de kop)
    rx, ry = 0.64, 0.56

    def on_frill(x, yl, out=0.0):
        """Punt in het vlak van de kraag (x opzij, yl omhoog in het schild), `out` naar achter erbuiten."""
        return (fc.x + x, fc.y + yl * math.cos(tilt) - out * math.sin(tilt), fc.z + yl * math.sin(tilt) + out * math.cos(tilt))

    frill = plate(1.0, tuple(fc), (rx, ry, 0.07), (40, 0, 0), "Bone", g, segments=32, rings=14)
    frill.data.materials.append(kit.mat("BoneDark"))
    for s in (-1, 1):
        cut = sphere(0.12, on_frill(s * 0.27, 0.16), "BoneDark", "_cut", scale=(1.0, 1.0, 1.0), segments=20, rings=10)
        unregister(cut)
        boolean(frill, cut)
    rim = [on_frill(math.sin(a) * rx * 0.95, math.cos(a) * ry * 0.95) for a in
           (math.radians(-118 + k * 236 / 23) for k in range(24))]
    kit.tube(rim, 0.04, "Bone", g, verts=10)
    # Knobbels op de rand van de kraag (epoccipitalia), van links naar rechts over de top.
    for k in range(13):
        a = math.radians(-108 + k * 216 / 12)
        p = on_frill(math.sin(a) * rx * 1.0, math.cos(a) * ry * 1.0)
        sphere(0.055 if k % 2 == 0 else 0.042, p, "Bone", g, scale=(1.0, 1.0, 0.85), segments=12, rings=6)
    for s in (-1, 1):
        # Hoorns boven de ogen: dik aan de voet, naar voren en omhoog, licht naar binnen gebogen.
        loft([(s * 0.2, 0.22, 0.04), (s * 0.25, 0.42, -0.14), (s * 0.24, 0.58, -0.36), (s * 0.19, 0.66, -0.58)],
             [0.085, 0.06, 0.035, 0.0], "Bone", g, verts=14)
        torus(0.08, 0.018, (s * 0.2, 0.235, 0.03), "Bone", g, axis="y", major_seg=16, minor_seg=6)  # voetring
        # Jukbeen: een punt opzij onder het oog.
        loft([(s * 0.3, -0.02, 0.0), (s * 0.4, -0.08, 0.04), (s * 0.46, -0.16, 0.06)], [0.06, 0.04, 0.0], "Bone", g, verts=10)
    # Neushoorn en snavel.
    loft([(0, 0.08, -0.46), (0, 0.18, -0.52), (0, 0.27, -0.56)], [0.05, 0.03, 0.0], "Bone", g, verts=10)
    loft([(0, -0.06, -0.6), (0, -0.1, -0.7), (0, -0.17, -0.76), (0, -0.25, -0.76)], [(0.06, 0.06), (0.05, 0.05),
         (0.03, 0.035), 0.0], "BoneDark", g, verts=12)
    # Onderkaak: twee zware takken die vooraan in een donkere ondersnavel samenkomen.
    for s in (-1, 1):
        loft([(s * 0.27, -0.16, 0.32), (s * 0.25, -0.24, 0.12), (s * 0.19, -0.27, -0.12), (s * 0.11, -0.28, -0.36),
              (s * 0.03, -0.29, -0.55)], [(0.04, 0.09), (0.045, 0.1), (0.04, 0.08), (0.035, 0.06), (0.03, 0.05)],
             "Bone", g, verts=12, up=(0, 1, 0))
        sphere(0.06, (s * 0.27, -0.12, 0.34), "Bone", g, segments=12, rings=6)  # kaakgewricht
    loft([(0, -0.29, -0.55), (0, -0.3, -0.66), (0, -0.27, -0.72)], [0.055, 0.04, 0.0], "BoneDark", g, verts=10)


def _sheet(g, grid, thick, material="Bone", subdiv=1):
    """Een gebogen botblad uit een raster Godot-punten [rij][kolom], met dikte (solidify) en afgerond
    (subsurf): het darmbeen van het bekken."""
    bm = bmesh.new()
    vs = [[bm.verts.new(G(*p)) for p in row] for row in grid]
    for r in range(len(grid) - 1):
        for c in range(len(grid[0]) - 1):
            bm.faces.new([vs[r][c], vs[r][c + 1], vs[r + 1][c + 1], vs[r + 1][c]])
    me = bpy.data.meshes.new("sheet")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("sheet", me)
    bpy.context.collection.objects.link(o)
    sol = o.modifiers.new("Solid", "SOLIDIFY")
    sol.thickness = thick
    sol.offset = 0.0
    if subdiv:
        sub = o.modifiers.new("Sub", "SUBSURF")
        sub.levels = subdiv
        sub.render_levels = subdiv
    return kit._finish(o, material, g, 0.0)


def build_pelvis():
    """Bekken van een titanbeest, vooraan gezien (golf 3, binnen2-08: "twee schijven en twee rubberen
    ringen"). Referentie: een bekken in een museum (mens, paard, sauropode): twee brede, schotelvormige
    vleugels (darmbeen) met een dikke kam bovenaan, het heiligbeen als wig in het midden, opzij de
    heupkommen, en onderaan het zit- en schaambeen als een plaat met een ovaal gat (het foramen
    obturatum) die vooraan in de schaamvoeg samenkomt. Geen ringen of torussen. ±1,25 m breed."""
    g = "Pelvis"
    for s in (-1, 1):
        # Darmbeen: een gebogen blad van de kam (bovenaan, een boog naar buiten) naar de hals boven de
        # heupkom. Het midden wijkt naar achter (een schotel, hol naar voren), de buitenrand komt naar voren.
        F = Vector((s * 0.24, 0.02, 0.0))
        J = Vector((s * 0.11, 0.02, -0.05))  # bij het heiligbeen
        A = Vector((s * 0.33, -0.15, 0.03))  # hals boven de heupkom
        cols, rows = 9, 6
        grid = []
        crest = []
        for r in range(rows):
            v = r / (rows - 1)
            row = []
            for c in range(cols):
                u = c / (cols - 1)
                th = math.radians(108 - 100 * u)
                R = 0.37 + 0.05 * math.sin(math.pi * u)
                top = F + Vector((s * math.cos(th) * R, math.sin(th) * R, 0.0))
                bot = J.lerp(A, u ** 0.8)
                p = top.lerp(bot, v ** 0.85)
                p.z += -0.15 * math.sin(math.pi * u) * (1.0 - v) * math.sin(math.pi * (0.2 + 0.8 * v)) + 0.17 * u * u * (1.0 - v)
                row.append(tuple(p))
                if r == 0:
                    crest.append(tuple(p))
            grid.append(row)
        _sheet(g, grid, 0.05)
        # Darmkam: een dikke, ronde rand bovenaan.
        loft(crest, [0.03, 0.038, 0.042, 0.042, 0.04, 0.038, 0.034, 0.03, 0.026], "Bone", g, verts=10)
        # Heupkom: een bolle kom opzij met een donkere holte (de kop van het dijbeen paste hierin).
        cup = Vector((s * 0.38, -0.2, 0.04))
        sphere(0.095, tuple(cup), "Bone", g, scale=(0.8, 1.0, 1.0), segments=16, rings=8)
        cyl(0.062, 0.03, (cup.x + s * 0.06, cup.y, cup.z), "BoneDark", g, axis="x", verts=18, bevel=0.0)
        # Zitbeenknobbel onderaan opzij, en de verbinding met de heupkom.
        sphere(0.07, (s * 0.31, -0.47, 0.03), "Bone", g, scale=(1.0, 0.8, 0.9), segments=12, rings=6)
        loft([(s * 0.36, -0.24, 0.04), (s * 0.31, -0.3, 0.05)], [0.06, 0.055], "Bone", g, verts=10)
    # Zit- en schaambeen: één brede plaat onder de heupkommen, met links en rechts een gat als een
    # traan (foramen obturatum) en onderaan in het midden de schaamboog (een omgekeerde U).
    pl = plate(1.0, (0.0, -0.37, 0.05), (0.43, 0.16, 0.05), (0, 0, 0), "Bone", g)
    for s in (-1, 1):
        cut = sphere(0.1, (s * 0.2, -0.36, 0.05), "Bone", "_cut", scale=(0.62, 0.85, 2.5), segments=20, rings=10)
        unregister(cut)
        boolean(pl, cut)
    arch = sphere(0.13, (0.0, -0.53, 0.05), "Bone", "_cut", scale=(1.0, 1.0, 2.5), segments=20, rings=10)
    unregister(arch)
    boolean(pl, arch)
    # Schaamvoeg vooraan in het midden, waar beide platen samenkomen.
    loft([(0.0, -0.27, 0.09), (0.0, -0.33, 0.1), (0.0, -0.39, 0.09)], [(0.06, 0.045), (0.065, 0.05), (0.05, 0.04)], "Bone", g, verts=12, up=(0, 0, 1))
    # Heiligbeen: een wig in het midden, achter de vleugels, met dwarse richels (vergroeide wervels),
    # donkere gaatjes en een doornkam.
    loft([(0, 0.24, -0.08), (0, 0.1, -0.07), (0, -0.04, -0.05), (0, -0.18, -0.03)],
         [(0.14, 0.06), (0.12, 0.055), (0.09, 0.05), (0.035, 0.035)], "Bone", g, verts=12, up=(0, 0, 1))
    for k in range(4):
        y = 0.2 - k * 0.11
        w = 0.13 - k * 0.025
        loft([(-w, y, -0.03), (0.0, y + 0.01, -0.015), (w, y, -0.03)], [0.016, 0.02, 0.016], "Bone", g, verts=8)
        for sx in (-1, 1):
            sphere(0.018, (sx * w * 0.55, y - 0.05, -0.02), "BoneDark", g, segments=8, rings=4)
    loft([(0, 0.24, -0.12), (0, 0.04, -0.13), (0, -0.12, -0.09)], [0.025, 0.03, 0.015], "Bone", g, verts=8)
    # Een barst over de linkervleugel.
    box((0.16, 0.012, 0.01), (-0.36, 0.16, 0.06), "BoneDark", g, bevel=0.0, rot=(0, 0, 32))


def build_titan_femur():
    """Dijbeen van een sauropode: plomp, met een grote kop en knobbels. ±1,4 m."""
    g = "TitanFemur"
    n = 7
    L = 0.6
    pts = [(-L + 2 * L * i / (n - 1), 0.03 * math.sin(i / (n - 1) * math.pi), 0) for i in range(n)]
    loft(pts, [0.15, 0.12, 0.1, 0.095, 0.1, 0.12, 0.15], "Bone", g, verts=16, up=(0, 0, 1))
    sphere(0.17, (L + 0.1, 0.1, 0.0), "Bone", g, segments=18, rings=9)  # kop
    sphere(0.12, (L + 0.02, -0.09, 0.07), "Bone", g, segments=14, rings=7)  # trochanter
    loft([(L - 0.02, 0.0, 0.0), (L + 0.07, 0.07, 0.0)], [0.13, 0.12], "Bone", g, verts=14)  # hals
    for s in (-1, 1):
        sphere(0.15, (-L - 0.04, -0.03, s * 0.09), "Bone", g, scale=(1.0, 0.9, 0.8), segments=16, rings=8)
    box((0.3, 0.012, 0.02), (0.05, 0.08, 0.098), "BoneDark", g, bevel=0.0, rot=(0, 0, 9))  # barst
    box((0.18, 0.01, 0.016), (-0.25, 0.05, -0.1), "BoneDark", g, bevel=0.0, rot=(0, 0, -14))


def _big_vertebra(g, z, scale):
    """Eén grote wervel rond (0, 0, z): wervellichaam langs z, boog, doorn omhoog, uitsteeksels opzij."""
    cyl(0.12 * scale, 0.15 * scale, (0, -0.05 * scale, z), "Bone", g, axis="z", verts=20, bevel=0.03, segments=3)
    torus(0.075 * scale, 0.03 * scale, (0, 0.11 * scale, z), "Bone", g, axis="z", major_seg=18, minor_seg=8)
    cyl(0.045 * scale, 0.16 * scale, (0, 0.11 * scale, z), "BoneDark", g, axis="z", verts=12, bevel=0.0)
    # Doorn: een plat blad naar boven en wat naar achter (geen hoorn), met een afgeronde top.
    loft([(0, 0.15 * scale, z), (0, 0.25 * scale, z + 0.02 * scale), (0, 0.33 * scale, z + 0.05 * scale),
          (0, 0.355 * scale, z + 0.06 * scale)],
         [(0.024 * scale, 0.06 * scale), (0.02 * scale, 0.055 * scale), (0.017 * scale, 0.045 * scale), 0.0],
         "Bone", g, verts=12, up=(0, 0, 1))
    for s in (-1, 1):
        loft([(s * 0.06 * scale, 0.08 * scale, z), (s * 0.17 * scale, 0.11 * scale, z), (s * 0.25 * scale, 0.13 * scale, z + 0.02 * scale)],
             [0.03 * scale, 0.022 * scale, 0.012 * scale], "Bone", g, verts=10, up=(0, 0, 1))


def build_spine():
    """Stuk ruggengraat: drie vergroeide wervels op een rij (zoals ze in een fossielbed liggen). ±0,8 m."""
    g = "Spine"
    sc = 1.55
    for k in range(3):
        _big_vertebra(g, (k - 1) * 0.26, sc)
    for k in range(2):  # tussenwervelschijf (donker, versteend)
        cyl(0.1 * sc, 0.035, (0, -0.05 * sc, (k - 0.5) * 0.26), "BoneDark", g, axis="z", verts=18, bevel=0.0)


def build_tusk():
    """Slagtand: een gebogen kegel met groeiringen en een donkere wortel. ±1,2 m langs de boog."""
    g = "Tusk"
    n = 12
    pts = []
    radii = []
    R = 0.55
    for i in range(n):
        k = i / (n - 1)
        a = math.radians(-55 + 150 * k)
        pts.append((0.06 * math.sin(k * math.pi), math.sin(a) * R - 0.05, -math.cos(a) * R + 0.25))
        radii.append(0.11 * (1.0 - k) ** 0.75 + 0.004)
    radii[-1] = 0.0
    loft(pts, radii, "Bone", g, verts=18, up=(1, 0, 0), twist=40.0)
    # Wortel: een donkere, iets dikkere voet (waar hij in de kaak zat), met een donkere holte.
    loft(pts[:2], [radii[0] + 0.01, radii[1] + 0.008], "BoneDark", g, verts=18, up=(1, 0, 0))


# --- Kristallen (Kristalmaan): lichtgevend en breekbaar --------------------------------------

def _crystal(g, base, direction, length, radius, material, twist=0.0, sides=6):
    """Zeszijdig prisma met een punt (kwarts), vanaf `base` langs `direction`."""
    d = Vector(direction).normalized()
    b = Vector(base)
    prof = [(math.cos(i / sides * math.tau), math.sin(i / sides * math.tau)) for i in range(sides)]
    loft([tuple(b), tuple(b + d * length * 0.72), tuple(b + d * length)], [radius, radius * 0.92, 0.0], material, g,
         verts=sides, profile=prof, twist=twist, smooth=False)


def build_glowshard():
    """Groep cyaan gloeiende kwartskristallen uit een rotsvoet. ±0,45 m."""
    g = "Glowshard"
    lumpy("base", 0.14, (1.25, 0.55, 1.05), "Rock", g, seed=41, amp=0.22, subdiv=2, pos=(0, -0.13, 0))
    rng = random.Random(17)
    spec = [((0, 1, 0), 0.42, 0.06), ((0.45, 1, 0.15), 0.33, 0.05), ((-0.4, 1, -0.2), 0.3, 0.048),
            ((0.1, 1, -0.55), 0.26, 0.042), ((-0.25, 1, 0.5), 0.24, 0.04), ((0.6, 0.7, -0.4), 0.18, 0.032)]
    for d, length, r in spec:
        base = (rng.uniform(-0.04, 0.04), -0.1, rng.uniform(-0.04, 0.04))
        _crystal(g, base, d, length, r, "GlowCyan", twist=rng.uniform(0, 30))


def build_bloom():
    """Kristalroos (woestijnroos): een roset van dunne roze bladen rond een gloeiende kern. ±0,5 m."""
    g = "Bloom"
    sphere(0.075, (0, 0.0, 0), "GlowPink", g, segments=16, rings=8)
    lumpy("foot", 0.09, (1.3, 0.5, 1.3), "Rock", g, seed=7, amp=0.2, subdiv=2, pos=(0, -0.09, 0))
    rng = random.Random(5)
    blade = [(1.0, 0.0), (0.0, 0.22), (-1.0, 0.0), (0.0, -0.22)]  # plat, ruitvormig
    for ring, (count, tilt, length) in enumerate(((9, 22, 0.24), (7, 48, 0.2), (5, 72, 0.15))):
        for k in range(count):
            a = k / count * math.tau + ring * 0.4 + rng.uniform(-0.1, 0.1)
            e = math.radians(tilt + rng.uniform(-6, 6))
            d = Vector((math.cos(a) * math.cos(e), math.sin(e), math.sin(a) * math.cos(e)))
            base = d * 0.05
            tip = base + d * length
            mid = base + d * length * 0.6
            w = 0.075 - ring * 0.012
            loft([tuple(base), tuple(mid), tuple(tip)], [(w * 0.6, 0.012), (w, 0.012), 0.0],
                 "GlowPink" if (k + ring) % 3 else "Quartz", g, verts=4, profile=blade, up=(0, 1, 0), smooth=False)


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

BONES = ("Femur", "Vertebra", "Rib", "Skull", "Claw", "TitanSkull", "Pelvis", "TitanFemur", "Spine", "Tusk")
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
        # F3 (release-audit ontwerp-5/8): grote skeletstukken en breekbare kristallen.
        "TitanSkull": build_titan_skull, "Pelvis": build_pelvis, "TitanFemur": build_titan_femur,
        "Spine": build_spine, "Tusk": build_tusk, "Glowshard": build_glowshard, "Bloom": build_bloom,
    }
    for fn in builders.values():
        fn()
    build_chunks()
    for name in ("Skull", "TitanSkull", "Pelvis", "TitanFemur", "Spine", "Tusk", "Glowshard", "Bloom"):
        _center_group(name)
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
