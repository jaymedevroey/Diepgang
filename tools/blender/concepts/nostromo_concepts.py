"""Drie ontwerpen van De Ekster in Nostromo-stijl (docs/research/nostromo-stijl.md §4), als
modellen voor de vergelijking in Godot (scenario concept_preview).

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup \
        --python tools/blender/concepts/nostromo_concepts.py -- [a,b,c]

A  sleepboot met ertsbak    B  portaalkraan    C  omgekeerde kathedraal
Oorsprong: de plek waar de Mol hangt (as van de Mol, zoals Mol_Dock). Godot-assen.
"""

import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.append(str(Path(__file__).resolve().parent.parent))
from builder import Builder, Patch, cluster, hazard_frame, lights_row, pipe_run, ribs, vent, windows  # noqa: E402
from ekster_parts import (beam, block, capsule_tank, cluster_engine, grid_panel, hex_tower, hull_skin,  # noqa: E402
                          leg_folded, light_string, mast, radiator_stack, ram, side_block, studs, truss)
import kit  # noqa: E402
from kit import PARTS, bake_wear, empty, export_glb, text  # noqa: E402

REPO = Path(__file__).resolve().parents[3]
OUT = REPO / "game/assets/models/concepts"
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
WHICH = ARGS[0].split(",") if ARGS else ["a", "b", "c"]


def clamp_carriage(b: Builder, top_y, z, span=8.0):
    """Dakklem boven de Mol: een loopkat met twee kaken die op het dak van de Mol grijpen, met cilinders."""
    b.box((0, top_y - 0.8, z), (span, 1.6, 6.0), material="Yellow")
    b.box((0, top_y - 1.8, z), (3.0, 0.6, 3.0), material="DarkSteel")
    for s in (-1, 1):
        jaw_top = Vector((s * 3.2, top_y - 1.4, z))
        jaw_bot = Vector((s * 3.0, top_y - 4.4, z))
        b.box((jaw_top + jaw_bot) / 2, (0.7, 3.2, 4.4), material="Hazard")
        ram(b, (s * 1.2, top_y - 1.2, z - 2.0), (s * 2.8, top_y - 3.6, z - 1.8), 0.3)
        ram(b, (s * 1.2, top_y - 1.2, z + 2.0), (s * 2.8, top_y - 3.6, z + 1.8), 0.3)
    # Rails van de loopkat.
    for s in (-1, 1):
        beam(b, (s * 2.6, top_y + 0.2, z - 12), (s * 2.6, top_y + 0.2, z + 12), 0.6, 0.8, "DarkSteel")


def stencil(group, s, size, pos, rot, material="Yellow"):
    text(s, size, pos, rot, material, group, extrude=0.05)


# =====================================================================================
# A. Sleepboot met ertsbak
# =====================================================================================

def concept_a():
    g = "A"
    rng = random.Random(11)
    b = Builder("A_Hull")
    mol_top = 2.9  # dak van de Mol (lokaal), de klem grijpt daar
    trench_ceiling = 4.0
    # --- Neus: hamerkop met schuine bovenkant en vizier.
    side_block(b, [(-52, -7), (-52, -1), (-44, 7), (-40, 11), (-26, 13), (-24, -7)], -21, 21, "HullGrey")
    for s in (-1, 1):  # schuine wangen
        side_block(b, [(-50, -6), (-50, -1), (-43, 5), (-30, 7), (-28, -6)], s * 21, s * 24, "HullDark")
        block(b, s * 23 - 3, s * 23 + 3, -2, 4, -46, -36, 1.2, "HullLight")  # sensorbulten
    for i in range(7):  # vizier: ramen met luiken
        z = -42.5 + i * 2.2
        b.box((0, 9.0 + (z + 42.5) * 0.5 * 0.0, z), (26, 0.4, 1.4), material="DarkSteel")
    b.box((0, 8.6, -41.2), (24, 2.6, 0.4), u=(1, 0, 0), v=(0, 0.78, -0.62), material="Cyan")
    # --- Middenstuk: drie dekken met terugsprongen; onder een geul voor de Mol.
    for s in (-1, 1):
        block(b, min(s * 7.5, s * 30), max(s * 7.5, s * 30), -7, 4, -24, 30, 1.8, "HullGrey")
    block(b, -7.5, 7.5, trench_ceiling, 6, -24, 30, 0.4, "HullDark")
    block(b, -27, 27, 4, 12, -22, 26, 1.6, "HullGrey")
    block(b, -18, 18, 12, 18, -16, 20, 1.2, "HullLight")
    block(b, -9, 9, 18, 21, -6, 10, 0.8, "HullGrey")  # opbouw met antennes
    for x in (-5, 0, 4):
        mast(b, (x, 26 + x * 0.3, 2), 5 + abs(x), 0.15, "LensRed")
    # Kleine ramen per dek (schaal).
    for s in (-1, 1):
        windows(b, Patch((s * 27.05, 7.0, -18), (0, 0, 1), (0, 1, 0), 40, 2, normal=(s, 0, 0)), 0.5, spacing=2.4, w=0.8, h=0.7)
        windows(b, Patch((s * 18.05, 14.0, -12), (0, 0, 1), (0, 1, 0), 28, 2, normal=(s, 0, 0)), 0.5, spacing=2.4, w=0.8, h=0.7)
    # --- Motorblok: drie achthoekige clustermotoren en twee zeskantige torens.
    block(b, -30, 30, -6, 12, 26, 34, 2.0, "HullDark")
    for x in (-19, 0, 19):
        cluster_engine(b, (x, 3, 30), 7.5, 18, 19, "HullDark")
    for s in (-1, 1):
        hex_tower(b, (s * 9.5, -10, 46), 34, 3.6, "HullGrey")
    # --- Huid met platen en clusters: zijkanten en buik.
    for s in (-1, 1):
        side = Patch((s * 30.1, -6, -22), (0, 0, 1), (0, 1, 0), 50, 9.5, normal=(s, 0, 0))
        hull_skin(b, side, rng, [(8, 5, 8, 4), (38, 3.5, 10, 3)])
        pipe_run(b, side, rng, 8.6, 3, 0.2, 0.35)
    for s in (-1, 1):
        belly = Patch((s * 7.5, -7.05, -24), (0, 0, 1), (s, 0, 0), 54, 22, normal=(0, -1, 0))
        hull_skin(b, belly, rng, [(6, 6, 9, 6), (30, 12, 8, 5), (48, 6, 7, 6)], cell=(5.0, 3.5))
        light_string(b, (s * 8.2, -7.4, -22), (s * 8.2, -7.4, 28), 24, 0.25, 0.25, rng)
        light_string(b, (s * 29.5, -7.4, -20), (s * 29.5, -7.4, 24), 18, 0.35, 0.25, rng)
    # Geul: spanten, leidingen langs de wanden, lampen.
    ceiling = Patch((-7.5, trench_ceiling - 0.01, -22), (0, 0, 1), (1, 0, 0), 50, 15, normal=(0, -1, 0))
    ribs(b, ceiling, spacing=2.6, depth=0.8, width=0.5, material="HullDark")
    for s in (-1, 1):
        wall = Patch((s * 7.45, -6.5, -22), (0, 0, 1), (0, 1, 0), 50, 10, normal=(-s, 0, 0))
        pipe_run(b, wall, rng, 6.0, 4, 0.22, 0.4)
        lights_row(b, wall, 9.0, spacing=3.5, size=0.35, material="BellyLight")
    clamp_carriage(b, trench_ceiling, 0.0)
    # Poten in hun kokers naast de geul.
    for s in (-1, 1):
        block(b, s * 12 - 3, s * 12 + 3, -9, -6.9, -14, 4, 0.6, "HullDark")
        leg_folded(b, (s * 12, -8.5, -8), s, 10)
    # Hangende masten bij de neus (het "woud van antennes" dat eerst in beeld komt).
    for (x, z, L) in ((-10, -40, 9), (-6, -37, 6), (8, -42, 11), (12, -34, 7)):
        mast(b, (x, -6.5, z), L, 0.16, "LensRed")
    # Tanks op de rug.
    for s in (-1, 1):
        capsule_tank(b, (s * 22, 14, -12), (0, 0, 1), 18, 2.4, "HullLight")
    # --- Koppelarm naar de ertsbak (twee vakwerkliggers) en de bak zelf.
    for s in (-1, 1):
        truss(b, (s * 6, 12, 34), (s * 10, 6, 70), 3.0, 3.0, 9, 0.35)
    bar = Builder("A_Barge")
    block(bar, -32, 32, 2, 8, 70, 150, 1.0, "RedOxide")
    for x in (-30, -10, 10, 30):
        truss(bar, (x, 9, 70), (x, 9, 150), 2.0, 2.0, 16, 0.3)
    for z in range(72, 151, 10):
        beam(bar, (-32, 9.5, z), (32, 9.5, z), 0.5, 0.5, "RedOxide")
    for i, (x, z, h, r) in enumerate(((-18, 85, 30, 6), (14, 92, 38, 7), (-4, 118, 44, 8), (20, 132, 26, 5.5), (-22, 128, 20, 5))):
        hex_tower(bar, (x, 2 - h, z), h, r, "HullGrey", bands=4)
        tp = Patch((x - r * 0.87, 2 - h + 3, z - r * 0.5), (0, 1, 0), (0, 0, 1), h - 6, r, normal=(-1, 0, 0))
        for k in range(int((h - 6) / 7)):
            grid_panel(bar, tp, 3.5 + k * 7, r / 2, 5.5, r * 0.8, (3, 2))
        light_string(bar, (x + r * 0.9, 2 - h + 1, z), (x + r * 0.9, 1, z), int(h / 2.5), 0.0, 0.3, rng)
        mast(bar, (x, 2 - h, z), 6 + i * 2, 0.2, "LensRed")
    o = b.to_object(g, bevel=0.12, segments=1)
    ob = bar.to_object(g, bevel=0.1, segments=1)
    # DIG-sjabloon op de buik naast de geul en op de achterkant.
    stencil(g, "DIG", 9.0, (-19, -7.2, -4), (90, 90, 0), "HullLight")
    stencil(g, "EKSTER  DIG-0017", 2.6, (0, 13.0, 34.05), (0, 0, 0), "HullLight")
    return g, [o, ob]


# =====================================================================================
# B. Portaalkraan
# =====================================================================================

def concept_b():
    g = "B"
    rng = random.Random(23)
    b = Builder("B_Hull")
    # Voorblok: brug en woondek, getrapt, met een vizier vooraan.
    side_block(b, [(-50, -6), (-50, 0), (-45, 8), (-36, 12), (-16, 12), (-14, -6)], -16, 16, "HullGrey")
    block(b, -12, 12, 12, 18, -38, -18, 1.2, "HullLight")
    block(b, -7, 7, 18, 21, -32, -22, 0.8, "HullGrey")
    b.box((0, 9.5, -46.6), (24, 3.2, 0.4), u=(1, 0, 0), v=(0, 0.8, -0.6), material="Cyan")
    for s in (-1, 1):
        block(b, s * 16, s * 16 + s * 6, -4, 6, -44, -20, 1.0, "HullDark")  # zijkassen
        windows(b, Patch((s * 16.05, 4, -42), (0, 0, 1), (0, 1, 0), 24, 3, normal=(s, 0, 0)), 1.0, spacing=2.2)
    # Raam van het museum dat op de baai uitkijkt: donker glas achter dikke stijlen.
    b.box((0, 4, -13.9), (14, 5, 0.3), material="DarkSteel")
    b.box((0, 4, -13.7), (13, 4.2, 0.2), material="Glass")
    for x in (-4.4, 0, 4.4):
        b.box((x, 4, -13.5), (0.6, 5, 0.5), material="HullDark")
    # Achterblok: reactor en motoren.
    side_block(b, [(20, -8), (20, 10), (26, 16), (48, 16), (52, 8), (52, -8)], -18, 18, "HullGrey")
    for x in (-11, 0, 11):
        cluster_engine(b, (x, -1, 50), 5.2, 10, 7, "HullDark")
    radiator_stack(b, (0, 16, 30), 7, 22, 1.8, direction=(0, 0, 1), up=(1, 0, 0), material="HullDark")
    # Open vakwerkrug met de Mol in de ruimte ertussen.
    for s in (-1, 1):
        truss(b, (s * 10, 6, -14), (s * 10, 6, 21), 4.0, 5.0, 8, 0.45)
        truss(b, (s * 10, -5, -14), (s * 10, -5, 21), 3.0, 2.5, 8, 0.35)
        # Loopbrug met reling langs de rug.
        b.box((s * 10, 3.4, 3.5), (2.2, 0.15, 35), material="DarkSteel")
        for z in range(-13, 22, 2):
            b.box((s * (10 + 1.0), 4.0, z), (0.08, 1.1, 0.08), material="Yellow")
        b.box((s * 11, 4.55, 3.5), (0.08, 0.08, 35), material="Yellow")
        light_string(b, (s * 10, -6.6, -13), (s * 10, -6.6, 20), 16, 0.3, 0.25, rng)
    # Portaal over de rug met de loopkat en klem.
    beam(b, (-12, 9, -2), (12, 9, -2), 1.2, 1.6, "Yellow")
    beam(b, (-12, 9, 2), (12, 9, 2), 1.2, 1.6, "Yellow")
    clamp_carriage(b, 8.0, 0.0, span=9.0)
    b.cyl((0, 3.0, 0), (0, 1, 0), 5.0, 0.12, 6, "Steel")
    # Schijnwerpers op de Mol.
    for (x, z) in ((-9, -10), (9, -10), (-9, 16), (9, 16)):
        b.box((x, -6.5, z), (1.2, 0.8, 1.2), material="DarkSteel")
        b.box((x, -7.0, z), (0.9, 0.12, 0.9), material="Lens")
    # Huid en clusters op voor- en achterblok.
    for s in (-1, 1):
        hull_skin(b, Patch((s * 16.1, -6, -48), (0, 0, 1), (0, 1, 0), 34, 18, normal=(s, 0, 0)), rng, [(10, 6, 9, 5)])
        hull_skin(b, Patch((s * 18.1, -8, 20), (0, 0, 1), (0, 1, 0), 32, 18, normal=(s, 0, 0)), rng, [(18, 9, 10, 6)])
    hull_skin(b, Patch((-16, -6.05, -50), (0, 0, 1), (1, 0, 0), 36, 32, normal=(0, -1, 0)), rng, [(10, 16, 10, 8), (28, 8, 6, 6)], cell=(5, 3.5))
    hull_skin(b, Patch((-18, -8.05, 20), (0, 0, 1), (1, 0, 0), 32, 36, normal=(0, -1, 0)), rng, [(12, 18, 12, 10)], cell=(5, 3.5))
    for (x, z, L) in ((-6, -40, 10), (5, -36, 7), (12, -46, 9)):
        mast(b, (x, -6, z), L, 0.16, "LensRed")
    for s in (-1, 1):
        leg_folded(b, (s * 13, -6.5, -26), s, 9)
        leg_folded(b, (s * 14, -8.5, 34), s, 9)
    o = b.to_object(g, bevel=0.12, segments=1)
    stencil(g, "DIG", 7.0, (0, -6.3, -30), (90, 0, 0), "HullLight")
    return g, [o]


# =====================================================================================
# C. Omgekeerde kathedraal
# =====================================================================================

def concept_c():
    g = "C"
    rng = random.Random(37)
    b = Builder("C_Hull")
    # Lange platte romp: de bovenkant is rustig.
    block(b, -26, 26, 6, 15, -56, 56, 2.0, "HullGrey")
    block(b, -20, 20, 15, 18, -40, 40, 1.0, "HullLight")
    side_block(b, [(-62, 7), (-62, 11), (-56, 15), (-50, 15), (-50, 6)], -22, 22, "HullDark")  # neus
    # Hangende torens: stortkokers en tanks, de grootste is de dropschacht met de Mol in zijn mond.
    shaft_r = 8.5
    hex_tower(b, (0, -6, 0), 12, shaft_r, "HullDark", bands=2)
    hazard_frame(b, Patch((-shaft_r, -6.05, -shaft_r), (1, 0, 0), (0, 0, 1), shaft_r * 2, shaft_r * 2, normal=(0, -1, 0)),
                 shaft_r, shaft_r, shaft_r * 1.4, shaft_r * 1.6, 0.8)
    clamp_carriage(b, 6.0, 0.0, span=8)
    towers = [(-16, -34, 24, 6), (17, -28, 30, 5), (-18, 26, 34, 7), (15, 34, 20, 5.5), (0, -46, 14, 4.5), (2, 46, 26, 6)]
    for i, (x, z, h, r) in enumerate(towers):
        hex_tower(b, (x, 6 - h, z), h, r, "HullGrey" if i % 2 else "HullDark", bands=3)
        tp = Patch((x - r * 0.87, 6 - h + 2, z - r * 0.5), (0, 1, 0), (0, 0, 1), h - 4, r, normal=(-1, 0, 0))
        for k in range(int((h - 4) / 7)):
            grid_panel(b, tp, 3.5 + k * 7, r / 2, 5.5, r * 0.8, (3, 2))
        light_string(b, (x + r * 0.9, 6 - h + 1, z), (x + r * 0.9, 5, z), int(h / 2.2), 0.0, 0.28, rng)
        mast(b, (x, 6 - h, z), 4 + (i % 3) * 3, 0.18, "LensRed")
    for (x, z) in ((-8, -14), (9, 16), (-9, 20)):
        capsule_tank(b, (x, 1, z - 6), (0, 0, 1), 12, 3.0, "HullLight")
    # Brug-gondel onder de neus, kijkt neer op de drop.
    block(b, -7, 7, -2, 6, -54, -40, 1.5, "HullLight")
    b.box((0, -1.0, -54.3), (12, 2.4, 0.3), material="Cyan")
    b.box((0, -2.1, -47), (12, 0.3, 12), material="Cyan")
    # Huid en lichtsnoeren op de buik tussen de torens.
    for s in (-1, 1):
        belly = Patch((0, 5.95, -56), (0, 0, 1), (s, 0, 0), 112, 26, normal=(0, -1, 0))
        hull_skin(b, belly, rng, [(20, 12, 10, 8), (70, 18, 10, 6), (95, 8, 8, 6)], cell=(6, 4))
        light_string(b, (s * 25.5, 5.6, -54), (s * 25.5, 5.6, 54), 40, 0.4, 0.3, rng)
    for s in (-1, 1):
        side = Patch((s * 26.05, 6, -54), (0, 0, 1), (0, 1, 0), 108, 9, normal=(s, 0, 0))
        hull_skin(b, side, rng, [(30, 4.5, 10, 4), (80, 4.5, 12, 4)])
        windows(b, Patch((s * 26.1, 6, -50), (0, 0, 1), (0, 1, 0), 30, 9, normal=(s, 0, 0)), 6.5, spacing=2.2)
    # Achterkant: brede spiegel met 3 × 3 clustermotoren.
    block(b, -26, 26, 4, 17, 56, 62, 1.6, "HullDark")
    for x in (-15, 0, 15):
        for y in (6.5, 14.5):
            cluster_engine(b, (x, y, 60), 4.0, 6, 7, "HullDark")
    o = b.to_object(g, bevel=0.12, segments=1)
    stencil(g, "DIG", 10.0, (14, 5.8, 0), (90, 0, 0), "HullLight")
    stencil(g, "0017", 4.0, (0, 10, 62.1), (0, 0, 0), "HullLight")
    return g, [o]


def build(name, func):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    PARTS.clear()
    kit._MATS.clear()  # materialen van de vorige scène bestaan niet meer
    g, objs = func()
    root = bpy.data.objects.new(f"Ekster_{name}", None)
    bpy.context.collection.objects.link(root)
    for o in list(PARTS.get(g, [])):
        o.parent = root
        bake_wear(o, strength=4.0, seed=hash(o.name) % 997)
    empty("Mol_Dock", (0, 0, 0), parent=root)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in PARTS.get(g, []))
    path = OUT / f"nostromo_{name}.glb"
    export_glb(path)
    print(f"[nostromo] {name}: {tris} driehoeken (voor afschuining) -> {path}")


OUT.mkdir(parents=True, exist_ok=True)
for k, f in (("a", concept_a), ("b", concept_b), ("c", concept_c)):
    if k in WHICH:
        build(k, f)
