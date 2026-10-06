"""De Graafworm, "the Gulper", en het lichtbaken (GDD §6, §8: "de worm is een segmentketting";
stijlgids: wat van de diepte is, is groot, oud en koud of gevaarlijk gekleurd). Ter goedkeuring van
Jayme (pakket F2, herwerkt in golf 3 / G1).

Referenties (korte studie, zie het rapport van G1):
- Tremors (graboids): een snavel van drie flappen die openklapt, met haakvormige tongen erin; de
  grond verraadt hem (rimpels, stof) en barst open.
- Dune (zandwormen, 2021): een ronde muil met lagen naar binnen wijzende tanden; geribbeld lijf.
- Lamprei: een vlezige zuigschijf met concentrische kransen tanden (leest meteen als "muil").
- Subnautica (Reaper, Ghost Leviathan) en diepzeevissen: lichtgevende strepen en stippen, zodat het
  silhouet in het donker leest.
- DRG (Glyphids): chunky pantser met gloeiende plekken die je in een donkere grot ziet.
Wat ronde 2 afkeurde: een zwarte ribbelbuis in het donker, en een kop van vier gelijke platen rond een
felle ronde schijf ("een straalmotor").
Keuze: drie ongelijke flappen (geen waaier van vier), een vlezige, natte muil met drie kransen tanden en
drie tongen, de gloed klein en diep in de keel. Het lijf: leiblauwe, natte pantserringen met tussen de
platen gloeiende amberen naden en een rij lichtstippen op de flanken, en een bleke buik. Oranje = gevaar
(dezelfde kleur als de worm op de sonar en in de HUD).

Gebruik:
    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup \\
        --python tools/blender/worm.py -- game/assets/models/worm.glb

Godot-coördinaten (kit.G). Objecten:
  Worm_Head     oorsprong achteraan de kop (daar hangt het eerste segment), de kop wijst naar −z
    Jaw_0..2    flappen (boven, rechtsonder, linksonder), oorsprong op het scharnier aan de lip
  Worm_Segment  een gepantserde ring, oorsprong in het midden, 1,45 m lang langs z
  Worm_Tail     de staart, oorsprong vooraan, loopt naar +z
  Beacon        het lichtbaken: een geel staafje met een gloeiende amberen kop, oorsprong onderaan
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy

sys.path.append(str(Path(__file__).parent))
import kit  # noqa: E402
from kit import box, cyl, export_glb, join_group, loft, parent_to, sphere, torus, tri_count  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = Path(ARGS[0]) if ARGS else Path("game/assets/models/worm.glb")

kit.PALETTE.update({
    # Koud en oud, maar nat: leiblauw pantser met glans, donkerder tussen de platen.
    "WormPlate": ((0.29, 0.32, 0.39), 0.1, 0.32, None),
    "WormPlateDark": ((0.12, 0.13, 0.17), 0.1, 0.42, None),
    "WormEdge": ((0.46, 0.20, 0.11), 0.2, 0.5, None),
    # Vlees: nat en rood (de muil, tussen de platen), een bleke buik.
    "WormFlesh": ((0.50, 0.20, 0.18), 0.0, 0.28, None),
    "WormLip": ((0.46, 0.15, 0.15), 0.0, 0.22, None),
    "WormMaw": ((0.62, 0.22, 0.22), 0.0, 0.25, None),
    "WormTongue": ((0.78, 0.36, 0.36), 0.0, 0.2, None),
    "WormBelly": ((0.80, 0.72, 0.60), 0.0, 0.45, None),
    "WormTooth": ((0.90, 0.86, 0.74), 0.0, 0.35, None),
    # Flappen: oud, verbleekt pantser (lichter dan het lijf, zodat de kop in het licht leest).
    "WormMandible": ((0.56, 0.50, 0.42), 0.05, 0.45, None),
    # Wat gloeit: de naden, de lichtstippen en diep in de keel (oranje = gevaar).
    "WormGlow": ((1.0, 0.42, 0.12), 0.0, 0.4, ((1.0, 0.34, 0.07), 2.4)),
    "WormThroat": ((1.0, 0.40, 0.10), 0.0, 0.4, ((1.0, 0.35, 0.06), 7.0)),
})

HEAD_X = 0.0
SEG_X = 5.0
TAIL_X = 10.0
BEACON_X = 15.0


def ring_z(points_z, radii, x, material, group, verts=20, bevel=0.03):
    """Een ronde buis langs z (Godot) rond x, met een straal per punt."""
    return loft([(x, 0.0, z) for z in points_z], radii, material, group, verts=verts, up=(0, 1, 0), bevel=bevel)


def ring_open(points_z, radii, x, material, group, verts=24, bevel=0.0):
    """Zoals ring_z, maar zonder deksels: een open buis (de muil is een trechter waar je in kijkt; de
    materialen zijn dubbelzijdig)."""
    o = ring_z(points_z, radii, x, material, group, verts=verts, bevel=bevel)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    caps = [f for f in bm.faces if len(f.verts) > 4]
    bmesh.ops.delete(bm, geom=caps, context="FACES_ONLY")
    bm.to_mesh(o.data)
    bm.free()
    return o


def photophores(x, z, r, group, count=2, size=0.075):
    """Lichtstippen op de flanken (links en rechts), een beetje onder het midden."""
    for side in (-1.0, 1.0):
        for k in range(count):
            a = math.radians(-12.0 - 22.0 * k)
            p = (x + side * math.cos(a) * r, math.sin(a) * r, z - 0.18 * k)
            sphere(size, p, "WormGlow", group, segments=10, rings=5)


def build_head():
    g = "Worm_Head"
    x = HEAD_X
    # Schedel: van de nek (z 0) tot de lip (z −2,0), iets dikker in het midden.
    ring_open([0.05, -0.4, -1.0, -1.6, -2.0], [1.0, 1.1, 1.17, 1.14, 1.04], x, "WormPlateDark", g, verts=24)
    # Twee overlappende pantserringen (dakpannen), met een gloeiende naad ertussen.
    for z0, r in ((-0.15, 1.17), (-0.85, 1.24)):
        ring_z([z0 - 0.62, z0 - 0.5, z0 - 0.1, z0], [r * 0.96, r, r * 1.03, r * 0.99], x, "WormPlate", g, verts=24, bevel=0.05)
        torus(r * 0.97, 0.035, (x, 0.0, z0 + 0.03), "WormGlow", g, axis="z", major_seg=40, minor_seg=6)
    # Bleke kin onderaan, en lichtstippen op de wangen.
    box((1.0, 0.24, 1.5), (x, -1.08, -0.9), "WormBelly", g, bevel=0.1)
    photophores(x, -0.55, 1.2, g, count=3)
    # Knobbels bovenop (oud, verweerd).
    for i, z in enumerate((-0.4, -1.1)):
        for side in (-1.0, 1.0):
            a = math.radians(62.0 + 12.0 * i) * side
            p = (x + math.sin(a) * 1.2, math.cos(a) * 1.2, z)
            cyl(0.12, 0.3, p, "WormPlateDark", g, verts=8, bevel=0.03, r2=0.03, rot=(0.0, 0.0, -math.degrees(a)))
    # De muil: een dikke, natte lip, een vlezige schijf die naar binnen zakt, drie kransen tanden die
    # naar de keel wijzen (lamprei, Dune), en de gloed klein en diep in de keel.
    torus(0.86, 0.22, (x, 0.0, -2.12), "WormLip", g, axis="z", major_seg=40, minor_seg=12)
    # Een trechter van vlees die naar de keel zakt (open: je kijkt erin), met een donkere bodem achter
    # de gloed van de keel.
    ring_open([-2.2, -1.95, -1.7, -1.4, -1.2], [0.86, 0.68, 0.48, 0.26, 0.2], x, "WormMaw", g, verts=24)
    cyl(0.22, 0.04, (x, 0.0, -1.22), "WormFlesh", g, axis="z", verts=16, bevel=0.0)
    for ring, (rr, zz, n, ln) in enumerate(((0.78, -2.2, 18, 0.34), (0.64, -1.94, 14, 0.29), (0.45, -1.68, 10, 0.23))):
        for i in range(n):
            a = (i + 0.5 * ring) / n * math.tau
            p = (x + math.cos(a) * rr, math.sin(a) * rr, zz)
            # Een kegel wijst langs +y; rond z draaien met a + 90° laat hem naar de as wijzen, en iets
            # naar voren kantelen (naar de prooi).
            cyl(0.085 if ring == 0 else 0.07, ln, p, "WormTooth", g, verts=6, bevel=0.0, r2=0.0,
                rot=(-25.0, 0.0, math.degrees(a) + 90.0))
    sphere(0.15, (x, 0.0, -1.5), "WormThroat", g, segments=12, rings=6)
    # Drie tongen met een haak (Tremors), die uit de keel naar buiten krullen.
    for k in range(3):
        a = math.radians(90.0 + 120.0 * k + 15.0)
        rad = (math.cos(a), math.sin(a))
        pts = [(x + rad[0] * 0.08, rad[1] * 0.08, -1.5), (x + rad[0] * 0.25, rad[1] * 0.25, -1.95),
               (x + rad[0] * 0.5, rad[1] * 0.5, -2.35), (x + rad[0] * 0.62, rad[1] * 0.62, -2.6),
               (x + rad[0] * 0.55, rad[1] * 0.55, -2.78)]
        loft(pts, [0.11, 0.1, 0.085, 0.06, 0.0], "WormTongue", g, verts=8, up=(rad[0], rad[1], 0.0))
    head = join_group(g, "Worm_Head", origin=(x, 0.0, 0.0))
    # Drie flappen (geen waaier van vier): elk een gebogen blad, pantser buiten en vlees binnen, met
    # tanden langs de binnenrand. Dicht vormen ze een snavel; open klappen ze naar buiten (WormVisual
    # draait ze rond hun raaklijn). De bovenste is langer: geen symmetrische straalmotor.
    for k in range(3):
        jg = "Jaw_%d" % k
        a = math.pi / 2.0 - k * math.tau / 3.0  # boven, rechtsonder, linksonder
        rad = (math.cos(a), math.sin(a))
        length = 1.35 if k == 0 else 1.15
        hinge = (x + rad[0] * 0.98, rad[1] * 0.98, -2.15)
        mid = (x + rad[0] * 0.72, rad[1] * 0.72, -2.15 - length * 0.55)
        tip = (x + rad[0] * 0.14, rad[1] * 0.14, -2.15 - length)
        loft([hinge, mid, tip], [(0.95, 0.14), (0.7, 0.12), (0.08, 0.05)], "WormMandible", jg, verts=10,
             up=(rad[0], rad[1], 0.0), bevel=0.0)
        inner = [(p[0] - rad[0] * 0.09, p[1] - rad[1] * 0.09, p[2]) for p in (hinge, mid, tip)]
        loft(inner, [(0.85, 0.08), (0.6, 0.07), (0.06, 0.03)], "WormLip", jg, verts=10, up=(rad[0], rad[1], 0.0), bevel=0.0)
        # Een gloeiende rand aan het scharnier en vier tanden aan de binnenkant.
        loft([(hinge[0] + rad[0] * 0.05, hinge[1] + rad[1] * 0.05, -2.12), (hinge[0] + rad[0] * 0.05, hinge[1] + rad[1] * 0.05, -2.24)],
             [(0.7, 0.06), (0.7, 0.06)], "WormGlow", jg, verts=8, up=(rad[0], rad[1], 0.0))
        for t in range(4):
            f = 0.2 + t * 0.19
            base = (hinge[0] + (tip[0] - hinge[0]) * f - rad[0] * 0.14, hinge[1] + (tip[1] - hinge[1]) * f - rad[1] * 0.14,
                    hinge[2] + (tip[2] - hinge[2]) * f)
            cyl(0.055, 0.24 - t * 0.03, base, "WormTooth", jg, verts=6, bevel=0.0, r2=0.0, rot=(0.0, 0.0, math.degrees(a) + 90.0))
        j = join_group(jg, "Jaw_%d" % k, origin=hinge)
        parent_to(j, head)
    return head


def build_segment():
    g = "Worm_Segment"
    x = SEG_X
    # Nat vlees tussen de platen, de pantserring erover (dakpannen), een bleke buik.
    ring_z([0.75, 0.4, -0.4, -0.75], [0.93, 0.99, 1.0, 0.96], x, "WormFlesh", g, verts=22, bevel=0.0)
    ring_z([0.35, 0.2, -0.45, -0.75], [1.04, 1.12, 1.16, 1.1], x, "WormPlate", g, verts=24, bevel=0.05)
    # De naad tussen de platen gloeit (in het donker zie je de ringen van het lijf).
    torus(1.06, 0.038, (x, 0.0, 0.4), "WormGlow", g, axis="z", major_seg=40, minor_seg=6)
    box((1.05, 0.24, 1.25), (x, -1.08, -0.15), "WormBelly", g, bevel=0.09)
    # Lichtstippen op de flanken.
    photophores(x, -0.1, 1.15, g, count=2)
    # Twee rugstekels.
    for z in (-0.15, -0.55):
        cyl(0.16, 0.36, (x, 1.22, z), "WormPlateDark", g, verts=8, bevel=0.03, r2=0.03, rot=(-20.0, 0.0, 0.0))
    return join_group(g, "Worm_Segment", origin=(x, 0.0, 0.0))


def build_tail():
    g = "Worm_Tail"
    x = TAIL_X
    ring_z([0.0, 0.5, 1.1, 1.7, 2.3, 2.6], [0.92, 0.86, 0.7, 0.5, 0.25, 0.0], x, "WormPlate", g, verts=20, bevel=0.0)
    for z, r in ((0.45, 0.86), (1.1, 0.7)):
        torus(r, 0.045, (x, 0.0, z), "WormGlow", g, axis="z", major_seg=32, minor_seg=6)
    box((0.75, 0.18, 1.2), (x, -0.78, 0.6), "WormBelly", g, bevel=0.07)
    photophores(x, 0.8, 0.82, g, count=1, size=0.06)
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
