"""Bouwt de binnenkant van De Ekster (de hub) uit de zones: game/assets/models/ekster_hub.glb.

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup \
        --python tools/blender/interior/build.py [-- --out=pad.glb] [-- --zones=hangar,bridge]
Daarna: tools\\godot.cmd --headless --path game --import
Beelden: tools\\godot.cmd --path game --resolution 1600x900 -- --scenario=interior_preview --model=res://assets/models/ekster_hub.glb --no-steam

Elke zone (zone_*.py) heeft een build(ctx). Faalt een zone, dan meldt het script dat en gaan de
andere door (zodat wie aan één zone werkt, de rest niet stuk maakt). Contract: layout.py.
"""

import importlib
import math
import sys
import traceback
from pathlib import Path

import bmesh
import bpy

HERE = Path(__file__).resolve().parent
sys.path.append(str(HERE))
sys.path.append(str(HERE.parent))
import kit  # noqa: E402
from builder import Builder  # noqa: E402
from kit import PARTS, empty, export_glb  # noqa: E402
import layout  # noqa: E402

REPO = HERE.parents[2]
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = REPO / "game/assets/models/ekster_hub.glb"
ZONES = ["zone_hangar", "zone_bridge", "zone_workdeck"]
for a in ARGS:
    if a.startswith("--out="):
        OUT = Path(a.split("=", 1)[1])
        if not OUT.is_absolute():
            OUT = REPO / OUT
    if a.startswith("--zones="):
        ZONES = ["zone_" + z for z in a.split("=", 1)[1].split(",")]

BEVEL = {"Shell": 0.03, "Props": 0.03, "Roof": 0.03}


def screen_quad(name, pos, normal, width, height):
    """Plat scherm met UV 0..1 (u naar rechts, v naar beneden, gezien vanaf de normaal)."""
    from mathutils import Vector
    n = Vector(normal).normalized()
    up = Vector((0, 1, 0))
    right = up.cross(n).normalized()
    c = Vector(layout.G(*pos))
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    corners = [(-1, -1, (0, 1)), (1, -1, (1, 1)), (1, 1, (1, 0)), (-1, 1, (0, 0))]
    verts = [bm.verts.new(kit.G(*(c + right * sx * width / 2 + up * sy * height / 2))) for sx, sy, _ in corners]
    f = bm.faces.new(verts)
    for loop, (_, _, t) in zip(f.loops, corners):
        loop[uv].uv = t
    f.normal_update()
    if f.normal.dot(kit.G(*n)) < 0:
        f.normal_flip()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(kit.mat("Screen"))
    return o


def door(name, hinge, extent):
    """Luikhelft met de oorsprong op het scharnier: x van extent[0] tot extent[1] t.o.v. het
    scharnier, lengte extent[2] langs z."""
    import hangar_doors
    x0, x1, length = extent
    b = Builder(name)
    # Detail in hangar_doors.py; de voetafdruk in x en z blijft die van de oude doos (contract).
    assert abs(abs(x1 - x0) - 4.0) < 1e-6 and abs(length - 14.0) < 1e-6, "luikmaat veranderd: hangar_doors nakijken"
    hangar_doors.door_mesh(b, 1 if x1 > 0 else -1, layout.MOL_DOCK_Z - hinge[2])
    o = b.to_object(name, bevel=0.008)
    o.location = kit.G(*layout.G(*hinge))
    return o


def part(name, b, pivot):
    """Een los onderdeel met een eigen naam (contract): de Builder `b` is in plancoördinaten gebouwd,
    de oorsprong komt op `pivot` (plan; None = de oorsprong van de hub), zodat het spel het kan draaien."""
    from mathutils import Matrix
    o = b.to_object(name, bevel=0.0 if name == "Shaft_Lights" else 0.02)
    if pivot is not None:
        p = kit.G(*layout.G(*pivot))
        o.data.transform(Matrix.Translation(-p))
        o.location = p
    return o


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit._MATS.clear()
    PARTS.clear()
    shared = {"builders": {}, "anchors": [], "collision": Builder("Collision"), "doors": [], "screens": [], "parts": []}
    failed = []
    for zone in ZONES:
        try:
            mod = importlib.import_module(zone)
            mod.build(layout.Ctx(zone.replace("zone_", "").capitalize(), shared))
        except Exception:
            failed.append(zone)
            print(f"[hub] ZONE MISLUKT: {zone}")
            traceback.print_exc()
    root = bpy.data.objects.new("Ekster_Hub", None)
    bpy.context.collection.objects.link(root)
    for name, b in shared["builders"].items():
        group = name.split("_", 1)[1]
        o = b.to_object(name, bevel=BEVEL.get(group, 0.0), segments=1, angle=40.0)
        o.parent = root
    col = shared["collision"].to_object("Collision")
    col.parent = root
    for name, hinge, extent in shared["doors"]:
        door(name, hinge, extent).parent = root
    for name, b, pivot in shared["parts"]:
        part(name, b, pivot).parent = root
    for name, pos, normal, w, h in shared["screens"]:
        screen_quad(name, pos, normal, w, h).parent = root
    for name, pos, rot in shared["anchors"]:
        empty(name, pos, rot, parent=root)
    for name, frm, to in layout.CAMERAS:
        empty("Cam_" + name, layout.G(*frm), parent=root)
        empty("Look_" + name, layout.G(*to), parent=root)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    export_glb(OUT)
    print(f"[hub] -> {OUT}" + (f" (MISLUKT: {', '.join(failed)})" if failed else ""))


build()
