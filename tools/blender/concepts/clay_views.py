"""Kleibeelden van een model (enkel de vorm): zijkant, boven, voor, en drie schuine beelden.
Workbench, studiolicht met holtes, alles in één grijze kleur. Voor snel schaven aan de vorm.

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup \
        --python tools/blender/concepts/clay_views.py -- game/assets/models/concepts/x.glb logs/clay/x

Godot-assen in de glb: Blender-assen na import (y omhoog wordt z omhoog). Boeg = Blender +y.
"""

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

REPO = Path(__file__).resolve().parents[3]
ARGS = sys.argv[sys.argv.index("--") + 1:]
SRC = Path(ARGS[0]) if Path(ARGS[0]).is_absolute() else REPO / ARGS[0]
OUT = Path(ARGS[1]) if Path(ARGS[1]).is_absolute() else REPO / ARGS[1]
OUT.parent.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SRC))
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.render.resolution_x = 960
sc.render.resolution_y = 540
sc.world = bpy.data.worlds.new("W")
sc.world.color = (0.62, 0.64, 0.68)
sh = sc.display.shading
sh.light = "STUDIO"
sh.color_type = "MATERIAL" if "color" in ARGS[2:] else "SINGLE"
sh.single_color = (0.62, 0.6, 0.57)
sh.show_cavity = True
sh.cavity_type = "BOTH"
sh.show_shadows = True
sh.shadow_intensity = 0.6
sc.view_settings.view_transform = "Standard"

meshes = [o for o in sc.objects if o.type == "MESH"]
lo = Vector((1e9, 1e9, 1e9))
hi = Vector((-1e9, -1e9, -1e9))
for o in meshes:
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        lo = Vector(map(min, lo, w))
        hi = Vector(map(max, hi, w))
center = (lo + hi) / 2
size = hi - lo
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.clip_end = 10000


def aim(pos, target):
    d = (target - pos).normalized()
    cam.location = pos
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def shot(name):
    sc.render.filepath = str(OUT) + f"_{name}.png"
    bpy.ops.render.render(write_still=True)


cam.data.type = "ORTHO"
far = 1000
cam.data.ortho_scale = max(size.y, size.z * 1.8) * 1.1
aim(center + Vector((-far, 0, 0)), center)
shot("zij")
cam.data.ortho_scale = max(size.y, size.x * 1.8) * 1.1
cam.location = center + Vector((0, 0, far))
cam.rotation_euler = (0, 0, math.radians(-90))
shot("boven")
cam.location = center + Vector((0, 0, -far))
cam.rotation_euler = (math.radians(180), 0, math.radians(-90))
shot("onder")
cam.data.ortho_scale = max(size.x, size.z * 1.8) * 1.15
aim(center + Vector((0, -far, 0)), center)
shot("achter")
cam.data.type = "PERSP"
cam.data.sensor_fit = "VERTICAL"
cam.data.angle = math.radians(38)
dist = size.length * 1.15
for name, d in (("voor_onder", (-0.55, 0.65, -0.45)), ("achter_onder", (0.5, -0.7, -0.45)), ("boven34", (-0.6, 0.5, 0.5))):
    aim(center + Vector(d).normalized() * dist, center)
    shot(name)
print("[clay]", OUT)
