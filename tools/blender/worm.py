"""De Graafworm en het lichtbaken (GDD §6, §8: "de worm is een segmentketting"; stijlgids: wat van
de diepte is, is groot, oud en koud of gevaarlijk gekleurd). Ter goedkeuring van Jayme (pakket F2).

Referenties (korte studie, zie het rapport van pakket F2):
- Tremors (graboids): de grond verraadt hem (rimpels, stof), hij barst uit de grond en duikt terug.
- Dune (zandwormen): een ronde muil met kransen tanden; lawaai lokt hem ("thumpers").
- Lethal Company (Earth Leviathan): gerommel en schudden vooraf, dan een boog door de ruimte.
- Terraria (Eater of Worlds): kop, gepantserde segmenten en een staart als ketting.
- DRG (gepantserde Glyphids): dikke platen met een lichtere rand die de lamp vangt.
Keuze: blind (geen ogen: hij hoort), leiblauwe pantserplaten met roestige randen, een bleke buik,
vier kaken die als een snavel sluiten en openklappen, en een gloeiende oranje keel (het enige wat
licht geeft: gevaar). Chunky en afgeschuind, leesbaar als zwart silhouet.

Gebruik:
    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup \\
        --python tools/blender/worm.py -- game/assets/models/worm.glb

Godot-coördinaten (kit.G). Objecten:
  Worm_Head     oorsprong achteraan de kop (daar hangt het eerste segment), de kop wijst naar −z
    Jaw_0..3    kaken (boven, rechts, onder, links), oorsprong op het scharnier aan de rand van de muil
  Worm_Segment  een gepantserde ring, oorsprong in het midden, 1,45 m lang langs z
  Worm_Tail     de staart, oorsprong vooraan, loopt naar +z
  Beacon        het lichtbaken: een geel staafje met een gloeiende amberen kop, oorsprong onderaan
"""

import math
import sys
from pathlib import Path

import bpy

sys.path.append(str(Path(__file__).parent))
import kit  # noqa: E402
from kit import G, box, cyl, export_glb, join_group, loft, parent_to, sphere, torus, tri_count  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = Path(ARGS[0]) if ARGS else Path("game/assets/models/worm.glb")

kit.PALETTE.update({
    # Koud en oud: leiblauw pantser, donkerder tussen de platen, roest op de randen, bleke buik.
    "WormPlate": ((0.20, 0.22, 0.27), 0.15, 0.55, None),
    "WormPlateDark": ((0.11, 0.12, 0.15), 0.1, 0.62, None),
    "WormEdge": ((0.46, 0.20, 0.11), 0.2, 0.5, None),
    "WormFlesh": ((0.58, 0.42, 0.40), 0.0, 0.7, None),
    "WormFleshDark": ((0.22, 0.10, 0.09), 0.0, 0.8, None),
    "WormTooth": ((0.86, 0.82, 0.70), 0.0, 0.45, None),
    # Kaken: oud, verbleekt pantser (lichter dan het lijf, zodat de muil in het licht leest).
    "WormMandible": ((0.50, 0.45, 0.38), 0.05, 0.5, None),
    # De keel: het enige dat gloeit (oranje = gevaar).
    "WormThroat": ((1.0, 0.40, 0.10), 0.0, 0.4, ((1.0, 0.35, 0.06), 6.0)),
})

HEAD_X = 0.0
SEG_X = 5.0
TAIL_X = 10.0
BEACON_X = 15.0


def ring_z(points_z, radii, x, material, group, verts=20, bevel=0.03):
    """Een ronde buis langs z (Godot) rond x, met een straal per punt."""
    return loft([(x, 0.0, z) for z in points_z], radii, material, group, verts=verts, up=(0, 1, 0), bevel=bevel)


def build_head():
    g = "Worm_Head"
    x = HEAD_X
    # Schedel: van de nek (z 0) tot de muil (z −2,2), iets dikker in het midden.
    # (Vooraan dicht op −2,0: de keel ervoor moet zichtbaar blijven.)
    ring_z([0.05, -0.4, -1.0, -1.6, -2.0], [1.0, 1.1, 1.17, 1.14, 1.02], x, "WormPlateDark", g, verts=24)
    # Drie overlappende pantserringen (dakpannen van voor naar achter), met een roestige achterrand.
    for z0, r in ((-0.15, 1.16), (-0.8, 1.24), (-1.45, 1.22)):
        ring_z([z0 - 0.62, z0 - 0.5, z0 - 0.1, z0], [r * 0.96, r, r * 1.03, r * 0.99], x, "WormPlate", g, verts=24, bevel=0.06)
        torus(r * 0.99, 0.05, (x, 0.0, z0 + 0.02), "WormEdge", g, axis="z", major_seg=40, minor_seg=6)
    # Knobbels bovenop (oud, verweerd), twee rijen.
    for i, z in enumerate((-0.45, -1.1, -1.75)):
        for side in (-1.0, 1.0):
            a = math.radians(70.0 + 12.0 * i) * side
            p = (x + math.sin(a) * 1.18, math.cos(a) * 1.18, z)
            cyl(0.13, 0.32, p, "WormPlateDark", g, verts=8, bevel=0.03, r2=0.03, rot=(0.0, 0.0, -math.degrees(a)))
    # Muil: een dikke roestige lip, een donkere keel die naar binnen zakt, en de gloed diep in de keel.
    torus(0.86, 0.17, (x, 0.0, -2.25), "WormEdge", g, axis="z", major_seg=40, minor_seg=10)
    # De keel gloeit (een trechter naar binnen), met een donkere kern: diepte.
    ring_z([-2.12, -1.9, -1.5], [0.8, 0.55, 0.2], x, "WormThroat", g, verts=20, bevel=0.0)
    cyl(0.3, 0.04, (x, 0.0, -2.14), "WormFleshDark", g, axis="z", verts=20, bevel=0.0)
    torus(0.62, 0.08, (x, 0.0, -2.15), "WormFleshDark", g, axis="z", major_seg=32, minor_seg=6)
    # Een krans tanden in de lip, schuin naar binnen.
    for i in range(14):
        a = i / 14.0 * math.tau
        p = (x + math.cos(a) * 0.7, math.sin(a) * 0.7, -2.15)
        # Een kegel wijst langs +y; rond z draaien met a + 90° laat hem naar de as wijzen.
        cyl(0.07, 0.24, p, "WormTooth", g, verts=6, bevel=0.0, r2=0.0, rot=(0.0, 0.0, math.degrees(a) + 90.0))
    head = join_group(g, "Worm_Head", origin=(x, 0.0, 0.0))
    # Vier kaken: elk een gebogen blad met tanden aan de binnenkant, scharnierend op de lip. Dicht
    # vormen ze een snavel; open klappen ze naar buiten (WormVisual draait ze rond hun raaklijn).
    jaws = []
    for k in range(4):
        jg = "Jaw_%d" % k
        a = math.pi / 2.0 - k * math.pi / 2.0  # boven, rechts, onder, links
        rad = (math.cos(a), math.sin(a))
        hinge = (x + rad[0] * 0.95, rad[1] * 0.95, -2.3)
        mid = (x + rad[0] * 0.66, rad[1] * 0.66, -3.0)
        tip = (x + rad[0] * 0.12, rad[1] * 0.12, -3.5)
        loft([hinge, mid, tip], [(0.8, 0.13), (0.56, 0.11), (0.05, 0.04)], "WormMandible", jg, verts=10,
             up=(rad[0], rad[1], 0.0), bevel=0.0)
        # Roestige rand aan het scharnier en drie tanden aan de binnenkant.
        loft([(hinge[0] + rad[0] * 0.04, hinge[1] + rad[1] * 0.04, -2.28), (hinge[0] + rad[0] * 0.04, hinge[1] + rad[1] * 0.04, -2.45)],
             [(0.6, 0.11), (0.6, 0.11)], "WormEdge", jg, verts=8, up=(rad[0], rad[1], 0.0))
        for t in range(3):
            f = 0.25 + t * 0.22
            base = (hinge[0] + (tip[0] - hinge[0]) * f - rad[0] * 0.05, hinge[1] + (tip[1] - hinge[1]) * f - rad[1] * 0.05,
                    hinge[2] + (tip[2] - hinge[2]) * f)
            cyl(0.05, 0.2, (base[0] - rad[0] * 0.08, base[1] - rad[1] * 0.08, base[2]), "WormTooth", jg, verts=6, bevel=0.0, r2=0.0,
                rot=(0.0, 0.0, math.degrees(a) + 90.0))
        j = join_group(jg, "Jaw_%d" % k, origin=hinge)
        parent_to(j, head)
        jaws.append(j)
    return head


def build_segment():
    g = "Worm_Segment"
    x = SEG_X
    # Vlees tussen de platen, de pantserring erover (voor de helft dikker: dakpannen), een bleke buik.
    ring_z([0.75, 0.4, -0.4, -0.75], [0.92, 0.98, 1.0, 0.96], x, "WormFlesh", g, verts=22, bevel=0.0)
    ring_z([0.35, 0.2, -0.45, -0.75], [1.04, 1.12, 1.16, 1.1], x, "WormPlate", g, verts=24, bevel=0.06)
    torus(1.1, 0.055, (x, 0.0, 0.3), "WormEdge", g, axis="z", major_seg=40, minor_seg=6)
    box((0.9, 0.22, 1.25), (x, -1.06, -0.15), "WormFlesh", g, bevel=0.08)
    # Twee rugstekels.
    for z in (-0.15, -0.55):
        cyl(0.16, 0.36, (x, 1.22, z), "WormPlateDark", g, verts=8, bevel=0.03, r2=0.03, rot=(-20.0, 0.0, 0.0))
    return join_group(g, "Worm_Segment", origin=(x, 0.0, 0.0))


def build_tail():
    g = "Worm_Tail"
    x = TAIL_X
    ring_z([0.0, 0.5, 1.1, 1.7, 2.3, 2.6], [0.92, 0.86, 0.7, 0.5, 0.25, 0.0], x, "WormPlate", g, verts=20, bevel=0.0)
    for z, r in ((0.45, 0.88), (1.1, 0.72)):
        torus(r, 0.05, (x, 0.0, z), "WormEdge", g, axis="z", major_seg=32, minor_seg=6)
    box((0.7, 0.18, 1.2), (x, -0.78, 0.6), "WormFlesh", g, bevel=0.07)
    return join_group(g, "Worm_Tail", origin=(x, 0.0, 0.0))


def build_beacon():
    g = "Beacon"
    x = BEACON_X
    # Een fakkelstaaf van DIG: geel, een zwarte greep met waarschuwingsringen, een rubberen voet en een
    # amberen lenskop die gloeit.
    cyl(0.065, 0.035, (x, 0.0175, 0.0), "Rubber", g, verts=16, bevel=0.01)
    cyl(0.052, 0.27, (x, 0.17, 0.0), "Yellow", g, verts=16, bevel=0.012)
    cyl(0.058, 0.08, (x, 0.09, 0.0), "Anthracite", g, verts=16, bevel=0.01)
    for y in (0.235, 0.27):
        cyl(0.056, 0.014, (x, y, 0.0), "Anthracite", g, verts=16, bevel=0.0)
    cyl(0.062, 0.02, (x, 0.31, 0.0), "Steel", g, verts=16, bevel=0.006)
    sphere(0.056, (x, 0.345, 0.0), "Lens", g, scale=(1.0, 1.25, 1.0), segments=14, rings=7)
    return join_group(g, "Beacon", origin=(x, 0.0, 0.0))


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit._MATS.clear()
    root = bpy.data.objects.new("Worm", None)
    bpy.context.collection.objects.link(root)
    total = 0
    head = build_head()
    for o in [head, build_segment(), build_tail(), build_beacon()]:
        parent_to(o, root)
        n = tri_count(o)
        for c in o.children:
            n += tri_count(c)
        total += n
        print(f"[worm] {o.name:13s} {n:6d} driehoeken")
    print(f"[worm] totaal {total}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    export_glb(OUT)
    print(f"[worm] geschreven: {OUT}")


main()
