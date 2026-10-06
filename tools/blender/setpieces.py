"""Set pieces in de grotten van Diepgang (release-audit golf 3, binnen-01 en binnen2-06): props die
CaveSetPieces (game/src/terrain/cave_set_pieces.gd) in grotten uit de seed zet. Enkel props: het
terrein zelf verandert er niet door (TerrainAPI: terrein kan enkel weggenomen worden).

Gebruik:
    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup \\
        --python tools/blender/setpieces.py -- game/assets/models/setpieces.glb

Godot-coördinaten; elk object staat met zijn voet op de oorsprong (y = 0 is de vloer) en zijn voorkant
naar +z. Objecten:
  CampTent        A-tent van DIG met een open flap, een lampjesslinger en scheerlijnen (±2,6 × 2 m)
  CampLamp        werflamp op een driepoot (2,2 m) met kabel; de lamp kijkt naar +z, 30° omlaag
  CampCrate       houten DIG-kist (0,8 m) met stencil
  CampToolbox     lange gele gereedschapskist met gevarenband
  CampBarrel      rood brandstofvat
  CampTable       klaptafel met radio, mok, lantaarn en kaarten
  CampChair       vouwstoel
  CampSign        A-bord "DIG FIELD CAMP · BACK IN 5 MIN" (de vorige ploeg kwam nooit terug)
  CampGenerator   kleine generator met uitlaat
  MineFrame       houten stut (twee palen en een kap) met een kooilamp, voor de oude toegangsgang
  Ribcage         reusachtige ribbenkast: een gebogen ruggengraat met 7 paar ribben die in de vloer
                  steken (±8 m lang, 3 m hoog)
  CrystalCluster  reuzenkristallen (1,2-3,2 m) uit een rotsvoet, voor de geodekamer

Referenties (ter goedkeuring van Jayme, golf 3):
  Kamp         Subnautica (de basis van de Degasi: verlaten kamp met lampen die nog branden en
               notities), Astroneer (wrakken met buit in grotten), Deep Rock Galactic (de werflampen en
               de stalen kisten van de dwergen), en echte expeditiekampen: een A-tent, werflampen op een
               driepoot, kisten, een klaptafel met radio. De DIG-humor op het bord.
  Stut         oude mijngangen: houten stutten (twee palen en een kap) met een kooilamp eraan.
  Ribbenkast   Dinosaur National Monument (de botwand: botten in situ in de rots), Wadi Al-Hitan
               (walvisskeletten in het zand), en de ribbenkast van een sauropode in een museum: ribben
               als bogen die in de grond verdwijnen. Vormen dik en chunky (stijlgids: geen dunne
               staafjes).
  Kristallen   de geode van Pulpí en de kristalgrot van Naica (reuzenkristallen tot meters lang),
               Deep Rock Galactic (Crystalline Caverns): zeskantige prisma's met een punt, in waaiers.
"""

import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector, noise

sys.path.append(str(Path(__file__).parent))
import kit  # noqa: E402
from kit import PARTS, bake_wear, box, cyl, export_glb, join_group, loft, parent_to, sphere, text, tri_count, tube  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = Path(ARGS[0]) if ARGS else Path("game/assets/models/setpieces.glb")

kit.PALETTE.update({
    # Tentdoek: verbleekt DIG-geel, en een koel blauwgrijs zeil (contrast met de warme klei).
    "Canvas": ((0.78, 0.6, 0.26), 0.0, 0.85, None),
    "Tarp": ((0.2, 0.3, 0.4), 0.0, 0.7, None),
    "TentShadow": ((0.05, 0.045, 0.04), 0.0, 0.95, None),
    "Bone": ((0.88, 0.82, 0.67), 0.0, 0.65, None),
    "BoneDark": ((0.30, 0.22, 0.14), 0.0, 0.85, None),
    "Rock": ((0.42, 0.37, 0.33), 0.0, 0.92, None),
    # Reuzenkristal: in Godot een eigen gloeiend materiaal in de kleur van de planeet.
    "Crystal": ((0.7, 0.95, 1.0), 0.0, 0.1, ((0.4, 0.9, 1.0), 1.5)),
    "Paper": ((0.92, 0.9, 0.82), 0.0, 0.8, None),
    "LedRedSoft": ((1.0, 0.18, 0.1), 0.0, 0.3, ((1.0, 0.18, 0.1), 0.7)),
})


# --- Het kamp ---------------------------------------------------------------------------

def build_tent():
    """A-tent langs z (de ingang vooraan, +z), 2,6 m lang, 2 m breed, 1,5 m hoog."""
    g = "CampTent"
    L, W, H = 2.6, 2.0, 1.45
    slope = math.degrees(math.atan2(H, W / 2))
    side = math.hypot(H, W / 2)
    for s in (-1, 1):
        # Een doekhelft: een dun blok dat van de nok naar de grond loopt (licht doorgezakt: 2 delen).
        mx, my = s * W / 4, H / 2
        box((side, 0.03, L), (mx, my, 0.0), "Canvas", g, bevel=0.01, rot=(0, 0, -s * slope))
        # Gele rand onderaan het doek.
        box((0.22, 0.035, L + 0.02), (s * (W / 2 - 0.09), 0.08, 0.0), "Yellow", g, bevel=0.0, rot=(0, 0, -s * slope))
    # Achterwand (driehoek) en de ingang: een donkere driehoek met opgerolde flappen.
    from kit import prism
    prism([(-W / 2, 0.0), (W / 2, 0.0), (0.0, H)], -L / 2 - 0.02, -L / 2 + 0.02, "Canvas", g, bevel=0.0)
    prism([(-W / 2 + 0.25, 0.0), (W / 2 - 0.25, 0.0), (0.0, H - 0.32)], L / 2 - 0.12, L / 2 - 0.08, "TentShadow", g, bevel=0.0)
    prism([(-W / 2, 0.0), (-W / 2 + 0.25, 0.0), (0.0, H - 0.0), (0.0, H - 0.32)], L / 2 - 0.05, L / 2 - 0.01, "Canvas", g, bevel=0.0)
    for s in (-1, 1):
        # Opgerolde flap: een rol langs de schuine rand.
        a = Vector((s * 0.12, H - 0.25, L / 2 + 0.02))
        b = Vector((s * (W / 2 - 0.2), 0.2, L / 2 + 0.02))
        loft([tuple(a), tuple((a + b) / 2 + Vector((s * 0.04, 0.02, 0.03))), tuple(b)], [0.06, 0.075, 0.06], "Canvas", g, verts=8)
    # Palen voor en achter, nokbalk, scheerlijnen en haringen.
    for z in (-L / 2 - 0.04, L / 2 + 0.04):
        cyl(0.025, H + 0.25, (0.0, (H + 0.25) / 2, z), "Anthracite", g, verts=8, bevel=0.0)
    cyl(0.02, L + 0.2, (0.0, H + 0.02, 0.0), "Anthracite", g, axis="z", verts=8, bevel=0.0)
    for z in (-L / 2 - 0.04, L / 2 + 0.04):
        dz = 1.0 if z > 0 else -1.0
        top = (0.0, H + 0.2, z)
        peg = (0.0, 0.0, z + dz * 1.1)
        tube([top, peg], 0.008, "Yellow", g, verts=4)
        cyl(0.02, 0.18, (peg[0], 0.05, peg[2]), "DarkSteel", g, verts=6, bevel=0.0)
    for s in (-1, 1):
        for z in (-0.9, 0.9):
            peg = (s * (W / 2 + 0.55), 0.0, z)
            tube([(s * (W / 2 - 0.1), 0.25, z), peg], 0.007, "Yellow", g, verts=4)
            cyl(0.018, 0.16, (peg[0], 0.05, peg[2]), "DarkSteel", g, verts=6, bevel=0.0)
    # Grondzeil dat vooraan uitsteekt, en een slaapzak in de schaduw.
    box((W + 0.1, 0.02, 0.8), (0.0, 0.01, L / 2 + 0.35), "Tarp", g, bevel=0.0)
    loft([(-0.5, 0.1, 0.4), (-0.1, 0.12, 0.6), (0.3, 0.1, 0.75)], [0.13, 0.15, 0.12], "Red", g, verts=10)
    # Lampjesslinger: van de voorste paal naar een stokje 2,4 m voor de tent, licht doorhangend.
    pole = (0.95, 0.0, L / 2 + 2.4)
    cyl(0.02, 1.9, (pole[0], 0.95, pole[2]), "Anthracite", g, verts=6, bevel=0.0)
    a = Vector((0.0, H + 0.2, L / 2 + 0.04))
    b = Vector((pole[0], 1.88, pole[2]))
    pts = []
    n = 8
    for i in range(n + 1):
        t = i / n
        p = a.lerp(b, t) + Vector((0.0, -0.32 * math.sin(t * math.pi), 0.0))
        pts.append(tuple(p))
    tube(pts, 0.007, "Rubber", g, verts=4)
    for i in range(1, n):
        p = Vector(pts[i])
        cyl(0.012, 0.04, (p.x, p.y - 0.03, p.z), "Rubber", g, verts=6, bevel=0.0)
        sphere(0.035, (p.x, p.y - 0.075, p.z), "Bulb", g, segments=8, rings=4)


def build_lamp():
    """Werflamp op een driepoot: de kop kijkt naar +z en 30° omlaag. Kop op (0, 2.15, 0)."""
    g = "CampLamp"
    top = Vector((0.0, 1.55, 0.0))
    for k in range(3):
        a = k * math.tau / 3 + 0.4
        foot = Vector((math.cos(a) * 0.62, 0.0, math.sin(a) * 0.62))
        tube([tuple(foot), tuple(top)], 0.022, "Yellow", g, verts=6)
        cyl(0.035, 0.03, (foot.x, 0.015, foot.z), "Rubber", g, verts=8, bevel=0.0)
    cyl(0.045, 0.16, (0.0, 1.55, 0.0), "Anthracite", g, verts=10, bevel=0.01)
    cyl(0.022, 0.65, (0.0, 1.85, 0.0), "Steel", g, verts=8, bevel=0.0)
    # Beugel en lampkop (afgeschuind blok met een groot glas en ribbels).
    box((0.42, 0.05, 0.05), (0.0, 2.15, 0.0), "Anthracite", g, bevel=0.01)
    head_rot = (-30, 0, 0)
    box((0.36, 0.3, 0.16), (0.0, 2.17, 0.0), "Anthracite", g, bevel=0.03, rot=head_rot)
    hz, hy = math.cos(math.radians(30)) * 0.085, -math.sin(math.radians(30)) * 0.085
    box((0.31, 0.25, 0.02), (0.0, 2.17 + hy, hz), "Lens", g, bevel=0.0, rot=head_rot)
    for k in range(4):
        x = -0.12 + k * 0.08
        box((0.02, 0.3, 0.06), (x, 2.17 - hy * 1.1, -hz * 1.1), "DarkSteel", g, bevel=0.0, rot=head_rot)
    # Kabel naar de grond en verder, in een slordige boog.
    tube([(0.05, 1.5, 0.0), (0.15, 0.8, 0.05), (0.3, 0.05, 0.1), (0.9, 0.02, 0.3), (1.5, 0.02, 0.0)], 0.015, "Rubber", g, verts=5)


def build_crate():
    g = "CampCrate"
    s = 0.8
    box((s, s * 0.85, s), (0.0, s * 0.425, 0.0), "Wood", g, bevel=0.03)
    for dy in (0.06, s * 0.85 - 0.06):
        box((s + 0.02, 0.08, s + 0.02), (0.0, dy, 0.0), "Anthracite", g, bevel=0.01)
    for sx in (-1, 1):
        box((0.08, s * 0.85 + 0.01, s + 0.02), (sx * (s / 2 - 0.05), s * 0.425, 0.0), "Anthracite", g, bevel=0.01)
    text("DIEPGANG", s * 0.12, (0.0, s * 0.45, s / 2 + 0.012), (0, 0, 0), "DecalDark", g, extrude=0.004)
    text("FRAGILE", s * 0.07, (0.0, s * 0.3, s / 2 + 0.012), (0, 0, 0), "Red", g, extrude=0.004)


def build_toolbox():
    g = "CampToolbox"
    box((1.2, 0.45, 0.5), (0.0, 0.225, 0.0), "Yellow", g, bevel=0.03)
    box((1.22, 0.1, 0.52), (0.0, 0.4, 0.0), "Hazard", g, bevel=0.01)
    for sx in (-0.4, 0.4):
        box((0.2, 0.05, 0.05), (sx, 0.48, 0.0), "Anthracite", g, bevel=0.01)
    for sx in (-0.5, 0.5):
        box((0.06, 0.12, 0.04), (sx, 0.3, 0.27), "DarkSteel", g, bevel=0.01)


def build_barrel():
    g = "CampBarrel"
    cyl(0.3, 0.88, (0.0, 0.44, 0.0), "Red", g, verts=18, bevel=0.03)
    for dy in (0.18, 0.7):
        cyl(0.315, 0.05, (0.0, dy, 0.0), "DarkSteel", g, verts=18, bevel=0.01)
    cyl(0.05, 0.03, (0.14, 0.89, 0.05), "DarkSteel", g, verts=8, bevel=0.0)
    text("FUEL", 0.12, (0.0, 0.45, 0.305), (0, 0, 0), "DecalLight", g, extrude=0.004)


def build_table():
    g = "CampTable"
    W, D, H = 1.2, 0.6, 0.74
    box((W, 0.04, D), (0.0, H, 0.0), "Wood", g, bevel=0.01)
    for sx in (-1, 1):
        # Gekruiste klappoten.
        tube([(sx * (W / 2 - 0.08), 0.0, -D / 2 + 0.05), (sx * (W / 2 - 0.08), H - 0.02, D / 2 - 0.05)], 0.018, "DarkSteel", g, verts=6)
        tube([(sx * (W / 2 - 0.08), 0.0, D / 2 - 0.05), (sx * (W / 2 - 0.08), H - 0.02, -D / 2 + 0.05)], 0.018, "DarkSteel", g, verts=6)
    top = H + 0.02
    # Radio met antenne en een schaal.
    box((0.32, 0.2, 0.16), (-0.33, top + 0.1, -0.08), "Anthracite", g, bevel=0.02)
    cyl(0.045, 0.02, (-0.4, top + 0.12, 0.0), "DarkSteel", g, axis="z", verts=12, bevel=0.0)
    box((0.1, 0.05, 0.01), (-0.27, top + 0.14, 0.0), "LedAmber", g, bevel=0.0)
    tube([(-0.2, top + 0.2, -0.12), (-0.12, top + 0.62, -0.18)], 0.006, "Steel", g, verts=4)
    # Mok, thermos, lantaarn, kaarten en een notitieboek.
    cyl(0.045, 0.1, (0.05, top + 0.05, 0.12), "Yellow", g, verts=12, bevel=0.005)
    cyl(0.05, 0.3, (0.18, top + 0.15, -0.15), "Green", g, verts=12, bevel=0.01)
    cyl(0.055, 0.04, (0.18, top + 0.32, -0.15), "Anthracite", g, verts=12, bevel=0.005)
    cyl(0.07, 0.04, (0.42, top + 0.02, 0.05), "Anthracite", g, verts=10, bevel=0.0)
    cyl(0.05, 0.13, (0.42, top + 0.105, 0.05), "Bulb", g, verts=10, bevel=0.0)
    cyl(0.06, 0.03, (0.42, top + 0.19, 0.05), "Anthracite", g, verts=10, bevel=0.0)
    box((0.42, 0.006, 0.3), (0.0, top + 0.003, -0.02), "Paper", g, bevel=0.0, rot=(0, 8, 0))
    box((0.2, 0.025, 0.14), (0.28, top + 0.013, 0.16), "Blue", g, bevel=0.003, rot=(0, -14, 0))


def build_chair():
    g = "CampChair"
    for sx in (-1, 1):
        tube([(sx * 0.24, 0.0, 0.22), (sx * 0.24, 0.42, -0.02), (sx * 0.24, 0.85, -0.25)], 0.014, "Steel", g, verts=6)
        tube([(sx * 0.24, 0.0, -0.22), (sx * 0.24, 0.42, 0.06)], 0.014, "Steel", g, verts=6)
    box((0.5, 0.02, 0.36), (0.0, 0.42, 0.02), "Tarp", g, bevel=0.0, rot=(-6, 0, 0))
    box((0.5, 0.36, 0.02), (0.0, 0.66, -0.15), "Tarp", g, bevel=0.0, rot=(-20, 0, 0))


def build_sign():
    """A-bord: geel, met de DIG-grap van de vorige ploeg (tekst in het Engels)."""
    g = "CampSign"
    tilt = 14
    for sz in (-1, 1):
        box((0.75, 1.0, 0.03), (0.0, 0.48, sz * 0.12), "Yellow", g, bevel=0.01, rot=(sz * -tilt, 0, 0))
    a = math.radians(tilt)
    fy, fz = 0.0, 0.12 + 0.02
    rot = (-tilt, 0, 0)
    text("DIG FIELD CAMP", 0.085, (0.0, 0.8, fz + math.sin(a) * 0.32 - 0.03), rot, "DecalDark", g, extrude=0.004)
    text("BACK IN", 0.12, (0.0, 0.58, fz + math.sin(a) * 0.1 - 0.0), rot, "Red", g, extrude=0.004)
    text("5 MIN", 0.16, (0.0, 0.4, fz - math.sin(a) * 0.08 + 0.03), rot, "Red", g, extrude=0.004)
    box((0.62, 0.02, 0.01), (0.0, 0.25, fz - math.sin(a) * 0.23 + 0.04), "DecalDark", g, bevel=0.0, rot=rot)


def build_generator():
    g = "CampGenerator"
    box((0.9, 0.5, 0.55), (0.0, 0.33, 0.0), "Yellow", g, bevel=0.04)
    for sx in (-0.42, 0.42):
        tube([(sx, 0.08, -0.29), (sx, 0.62, -0.29), (sx, 0.62, 0.29), (sx, 0.08, 0.29)], 0.02, "Anthracite", g, verts=6)
    box((0.92, 0.08, 0.57), (0.0, 0.54, 0.0), "Hazard", g, bevel=0.01)
    box((0.36, 0.26, 0.02), (-0.15, 0.32, 0.285), "Anthracite", g, bevel=0.01)
    cyl(0.04, 0.2, (0.3, 0.68, -0.1), "DarkSteel", g, verts=8, bevel=0.0)
    box((0.06, 0.04, 0.01), (0.12, 0.38, 0.29), "LedRedSoft", g, bevel=0.0)


def build_mine_frame():
    """Houten stut voor de oude toegangsgang: twee schuine palen, een kap en een kooilamp."""
    g = "MineFrame"
    Hh, Wd = 2.5, 2.3
    for sx in (-1, 1):
        box((0.18, Hh, 0.18), (sx * Wd / 2, Hh / 2, 0.0), "Wood", g, bevel=0.02, rot=(0, 0, sx * 4))
        box((0.22, 0.1, 0.22), (sx * Wd / 2, 0.05, 0.0), "Wood", g, bevel=0.01)
    box((Wd + 0.5, 0.2, 0.2), (0.0, Hh + 0.08, 0.0), "Wood", g, bevel=0.02)
    for sx in (-1, 1):
        box((0.08, 0.3, 0.24), (sx * (Wd / 2 - 0.22), Hh - 0.12, 0.0), "Wood", g, bevel=0.01, rot=(0, 0, sx * 45))
    # Kooilamp aan de kap, met een kabel langs de kap.
    cyl(0.02, 0.18, (0.35, Hh - 0.1, 0.0), "Rubber", g, verts=6, bevel=0.0)
    cyl(0.07, 0.03, (0.35, Hh - 0.2, 0.0), "Anthracite", g, verts=10, bevel=0.0)
    sphere(0.06, (0.35, Hh - 0.27, 0.0), "Bulb", g, segments=10, rings=5)
    for k in range(4):
        a = k * math.pi / 2
        tube([(0.35 + math.cos(a) * 0.075, Hh - 0.2, math.sin(a) * 0.075), (0.35 + math.cos(a) * 0.06, Hh - 0.35, math.sin(a) * 0.06)], 0.006, "Anthracite", g, verts=4)
    tube([(-Wd / 2 - 0.2, Hh - 0.05, 0.12), (0.35, Hh - 0.05, 0.12)], 0.012, "Rubber", g, verts=4)


# --- De ribbenkast --------------------------------------------------------------------------

def build_ribcage():
    """Een reusachtige ribbenkast in de vloer: een licht gebogen ruggengraat langs x (±8 m, 2,6 m hoog)
    met 8 paar platte ribben die als een ton naar buiten en naar beneden buigen en in de vloer
    verdwijnen. Alles dik en chunky (stijlgids: geen dunne staafjes)."""
    g = "Ribcage"
    rng = random.Random(7)
    n = 11
    spine = []
    for i in range(n):
        t = i / (n - 1)
        x = -4.4 + 8.8 * t
        y = 2.3 + 0.55 * math.sin(t * math.pi) - 0.7 * t  # zakt naar de staart
        z = 0.3 * math.sin(t * 2.4)
        spine.append(Vector((x, y, z)))
    for i, p in enumerate(spine):
        s = 1.0 - 0.38 * (i / (n - 1))
        # Wervellichaam: een spoel (smal in het midden), langs de rug.
        loft([tuple(p + Vector((-0.27 * s, 0, 0))), tuple(p + Vector((-0.2 * s, 0, 0))), tuple(p),
              tuple(p + Vector((0.2 * s, 0, 0))), tuple(p + Vector((0.27 * s, 0, 0)))],
             [0.2 * s, 0.3 * s, 0.24 * s, 0.3 * s, 0.2 * s], "Bone", g, verts=14, up=(0, 1, 0))
        # Wervelboog en doorn: een platte, brede doorn omhoog en wat naar achter.
        loft([tuple(p + Vector((0, 0.2 * s, 0))), tuple(p + Vector((0.08 * s, 0.6 * s, 0))), tuple(p + Vector((0.22 * s, 1.0 * s, 0)))],
             [(0.07 * s, 0.17 * s), (0.06 * s, 0.13 * s), (0.04 * s, 0.07 * s)], "Bone", g, verts=10, up=(1, 0, 0))
        sphere(0.09 * s, tuple(p + Vector((0.24 * s, 1.03 * s, 0))), "Bone", g, segments=10, rings=5)
        for sz in (-1, 1):
            loft([tuple(p + Vector((0, 0.12, sz * 0.22 * s))), tuple(p + Vector((0.04, 0.2, sz * 0.55 * s)))],
                 [0.1 * s, 0.07 * s], "Bone", g, verts=8)
        if i < n - 1:
            q = spine[i + 1]
            loft([tuple(p.lerp(q, 0.38)), tuple(p.lerp(q, 0.62))], [0.18 * s, 0.18 * s], "BoneDark", g, verts=10, up=(0, 1, 0))
    # Ribben: plat (breed langs de rug, dun naar buiten), een ton die naar buiten en dan naar beneden
    # buigt, tot onder de vloer.
    for i in range(1, 9):
        p = spine[i]
        s = 1.0 - 0.32 * abs(i - 4.0) / 4.0
        for sz in (-1, 1):
            W = (2.2 + 0.4 * s) * (1.0 + rng.uniform(-0.05, 0.05))
            H = p.y + 0.5
            pts = []
            radii = []
            m = 11
            for k in range(m):
                t = k / (m - 1)
                phi = t * math.pi * 0.78
                side = 0.25 + W * math.sin(phi)
                y = p.y + 0.15 * math.sin(t * math.pi * 0.6) - (1.0 - math.cos(phi)) * H * 0.62
                back = 0.32 * t + rng.uniform(-0.03, 0.03)
                pts.append((p.x + back, y, p.z + sz * side))
                radii.append(((0.11 - 0.035 * t) * s, (0.2 - 0.06 * t) * s))
            loft(pts, radii, "Bone", g, verts=10, up=(1, 0, 0))
            sphere(0.17 * s, (p.x, p.y + 0.05, p.z + sz * 0.3), "Bone", g, scale=(1.0, 0.8, 1.0), segments=10, rings=5)
    # Een paar losse, gebroken ribstukken op de vloer.
    for k in range(3):
        x = rng.uniform(-3.5, 3.5)
        z = rng.choice((-1, 1)) * rng.uniform(3.3, 4.0)
        a = rng.uniform(0, math.tau)
        L = rng.uniform(1.0, 1.7)
        d = Vector((math.cos(a), 0.0, math.sin(a)))
        c = Vector((x, 0.1, z))
        loft([tuple(c - d * L / 2), tuple(c + Vector((0, 0.12, 0))), tuple(c + d * L / 2)], [(0.1, 0.16), (0.11, 0.18), (0.08, 0.12)],
             "Bone", g, verts=8, up=(0, 1, 0))


# --- Reuzenkristallen --------------------------------------------------------------------------

def _prism(g, base, direction, length, radius, material, twist=0.0):
    """Zeskantig kristal met een punt (zoals finds._crystal), van `base` in `direction`."""
    d = Vector(direction).normalized()
    b = Vector(base)
    prof = [(math.cos(twist + k * math.tau / 6), math.sin(twist + k * math.tau / 6)) for k in range(6)]
    loft([tuple(b - d * 0.3), tuple(b + d * length * 0.78), tuple(b + d * length)], [radius, radius * 0.94, 0.0],
         material, g, profile=prof, smooth=False, up=(0, 0, 1) if abs(d.z) < 0.9 else (1, 0, 0))


def build_crystal_cluster():
    g = "CrystalCluster"
    rng = random.Random(23)
    # Rotsvoet: een platte, gehakte klomp.
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=kit.G(0.0, 0.1, 0.0))
    o = bpy.context.active_object
    for v in o.data.vertices:
        dvec = v.co.normalized()
        v.co = dvec * (1.0 + noise.noise(dvec * 1.9 + Vector((3.1, 0, 0))) * 0.3)
    o.scale = kit.GS(1.3, 0.45, 1.1)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    kit._finish(o, "Rock", g, 0.0, smooth=False)
    # Waaier van reuzenkristallen: één grote in het midden, de rest schuin naar buiten.
    specs = [((0.0, 0.2, 0.0), (0.08, 1.0, -0.05), 3.2, 0.42)]
    for k in range(7):
        a = k * math.tau / 7 + rng.uniform(-0.3, 0.3)
        out = rng.uniform(0.35, 0.8)
        d = (math.cos(a) * out, 1.0, math.sin(a) * out)
        base = (math.cos(a) * rng.uniform(0.3, 0.7), 0.15, math.sin(a) * rng.uniform(0.3, 0.6))
        specs.append((base, d, rng.uniform(1.2, 2.4), rng.uniform(0.17, 0.32)))
    for base, d, L, r in specs:
        _prism(g, base, d, L, r, "Crystal", twist=rng.uniform(0, 1))


# --- Uitvoer ------------------------------------------------------------------------------------

def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    builders = {
        "CampTent": build_tent, "CampLamp": build_lamp, "CampCrate": build_crate, "CampToolbox": build_toolbox,
        "CampBarrel": build_barrel, "CampTable": build_table, "CampChair": build_chair, "CampSign": build_sign,
        "CampGenerator": build_generator, "MineFrame": build_mine_frame, "Ribcage": build_ribcage,
        "CrystalCluster": build_crystal_cluster,
    }
    for fn in builders.values():
        fn()
    root = bpy.data.objects.new("SetPieces", None)
    bpy.context.collection.objects.link(root)
    total = 0
    for name in builders:
        o = join_group(name, name)
        if o is None:
            print(f"[setpieces] LEEG: {name}")
            continue
        bake_wear(o, strength=8.0 if name == "Ribcage" else 6.0, seed=sum(map(ord, name)) % 997)
        parent_to(o, root)
        n = tri_count(o)
        total += n
        print(f"[setpieces] {name:15s} {n:6d} driehoeken")
    print(f"[setpieces] totaal {total}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    export_glb(OUT)
    print(f"[setpieces] geschreven: {OUT}")


main()
