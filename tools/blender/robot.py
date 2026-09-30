"""Bouwt de Diepgang-robot en exporteert hem als GLB (GDD §8: afgeronde lijven, groot
schermgezicht, antenne, kleine ledematen).

Gebruik:
    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup \
        --python tools/blender/robot.py -- game/assets/models/robot.glb

Conventies voor Godot:
- De robot kijkt naar Blender +Y; na glTF-export (Y-up) is dat Godot -Z (vooruit).
- Oorsprong tussen de voeten. Totale hoogte ±1,4 m (zelfde als de capsule).
- Onderdelen die bewegen zijn eigen objecten met hun draaipunt als oorsprong:
  Torso, Head, Antenna, Arm_L, Arm_R, Leg_L, Leg_R. Screen is een vlak met UV 0..1.
- Materiaalnamen: Body (spelerskleur, wordt in Godot vervangen), Trim, Metal, Screen, Lens.
"""

import sys
from pathlib import Path

import bpy
from mathutils import Vector

OUT = Path(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else Path("robot.glb")


def material(name: str, color, metallic=0.0, roughness=0.5, emission=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    try:
        mat.use_nodes = True
    except AttributeError:
        pass
    bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat.node_tree else None
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        if emission:
            bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
            bsdf.inputs["Emission Strength"].default_value = 3.0
    return mat


def finish(obj, name, mat, bevel=0.0, segments=3, subsurf=0, parent=None, origin=None):
    obj.name = name
    obj.data.name = name
    obj.data.materials.append(mat)
    if bevel > 0:
        m = obj.modifiers.new("Bevel", "BEVEL")
        m.width = bevel
        m.segments = segments
        m.limit_method = "NONE"
    if subsurf:
        m = obj.modifiers.new("Subsurf", "SUBSURF")
        m.levels = subsurf
        m.render_levels = subsurf
    for p in obj.data.polygons:
        p.use_smooth = True
    if origin is not None:
        set_origin(obj, Vector(origin))
    if parent is not None:
        obj.parent = parent
        obj.matrix_parent_inverse = parent.matrix_world.inverted()
    return obj


def set_origin(obj, world_point: Vector):
    """Verplaatst de oorsprong naar een punt zonder de geometrie te verschuiven."""
    offset = world_point - obj.location
    obj.data.transform(__import__("mathutils").Matrix.Translation(-offset))
    obj.location = world_point


def cube(size, loc):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return o


def cylinder(radius, depth, loc, rot=(0, 0, 0), verts=24):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=loc, rotation=rot, vertices=verts)
    o = bpy.context.active_object
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return o


def sphere(radius, loc, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=loc, segments=24, ring_count=12)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return o


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target="MESH")  # modifiers toepassen
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    return o


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    body = material("Body", (0.95, 0.55, 0.12), roughness=0.45)
    trim = material("Trim", (0.06, 0.065, 0.075), roughness=0.6)
    metal = material("Metal", (0.45, 0.46, 0.5), metallic=0.8, roughness=0.35)
    screen = material("Screen", (0.01, 0.015, 0.02), roughness=0.15)
    lens = material("Lens", (1.0, 0.85, 0.6), emission=(1.0, 0.8, 0.5))

    bpy.ops.object.empty_add(location=(0, 0, 0))
    root = bpy.context.active_object
    root.name = "Robot"

    # Romp: afgeronde doos, oorsprong op de heup (daar hangen de benen).
    torso = finish(cube((0.46, 0.38, 0.36), (0, 0, 0.56)), "Torso", body, bevel=0.1, segments=4,
                   parent=root, origin=(0, 0, 0.4))
    belt = finish(cube((0.48, 0.4, 0.06), (0, 0, 0.43)), "Belt", trim, bevel=0.03, parent=torso)
    pack = finish(cube((0.34, 0.14, 0.3), (0, -0.24, 0.58)), "Pack", trim, bevel=0.04, parent=torso)
    for i, z in enumerate((0.5, 0.6)):
        finish(cube((0.28, 0.03, 0.035), (0, -0.315, z)), f"PackStripe{i}", body, bevel=0.01, parent=torso)

    # Nek en hoofd. Hoofd draait rond de nek (knikken = kijkhoek).
    finish(cylinder(0.07, 0.12, (0, 0, 0.8)), "Neck", metal, parent=torso)
    head = finish(cube((0.66, 0.5, 0.46), (0, 0, 1.07)), "Head", body, bevel=0.12, segments=5,
                  parent=torso, origin=(0, 0, 0.84))
    # Rand rond het scherm + het scherm zelf (vlak met nette UV).
    finish(cube((0.56, 0.04, 0.34), (0, 0.24, 1.07)), "Bezel", trim, bevel=0.05, segments=3, parent=head)
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, 0.262, 1.07), rotation=(1.5708, 0, 0))
    scr = bpy.context.active_object
    scr.scale = (0.5, 0.29, 1.0)  # plane size 1 → 0,5 × 0,29 m
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    # Na de rotatie wijst de normaal naar achteren (-Y): omdraaien, zodat het scherm vooruit kijkt.
    # UV-v blijft omhoog; u loopt van rechts naar links gezien van voren (de shader houdt daar rekening mee).
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.flip_normals()
    bpy.ops.object.mode_set(mode="OBJECT")
    finish(scr, "Screen", screen, parent=head)
    # Oortjes en helmlamp.
    for side, x in (("L", -0.345), ("R", 0.345)):
        finish(cylinder(0.07, 0.05, (x, 0, 1.07), rot=(0, 1.5708, 0)), f"Ear_{side}", trim, bevel=0.015, parent=head)
    finish(cylinder(0.045, 0.06, (0.18, 0.2, 1.33), rot=(1.5708, 0, 0)), "LampBody", metal, bevel=0.01, parent=head)
    finish(cylinder(0.035, 0.012, (0.18, 0.232, 1.33), rot=(1.5708, 0, 0)), "LampLens", lens, parent=head)

    # Antenne: oorsprong aan de voet, zodat hij kan meeveren.
    ant = finish(cylinder(0.012, 0.22, (-0.16, -0.05, 1.41)), "Antenna", metal, parent=head, origin=(-0.16, -0.05, 1.3))
    finish(sphere(0.038, (-0.16, -0.05, 1.54)), "AntennaTip", body, parent=ant)

    # Armen: oorsprong aan de schouder.
    for side, x in (("L", -0.3), ("R", 0.3)):
        arm = finish(cylinder(0.055, 0.26, (x, 0, 0.5)), f"Arm_{side}", trim, bevel=0.02, parent=torso, origin=(x, 0, 0.65))
        finish(sphere(0.085, (x, 0, 0.62)), f"Shoulder_{side}", body, parent=arm)
        finish(sphere(0.075, (x, 0.01, 0.36), scale=(1.0, 1.1, 0.9)), f"Hand_{side}", body, parent=arm)

    # Benen: oorsprong aan de heup, voeten plat en iets naar voren.
    for side, x in (("L", -0.13), ("R", 0.13)):
        leg = finish(cylinder(0.06, 0.26, (x, 0, 0.21)), f"Leg_{side}", trim, bevel=0.02, parent=root, origin=(x, 0, 0.4))
        finish(cube((0.16, 0.26, 0.09), (x, 0.03, 0.045)), f"Foot_{side}", body, bevel=0.035, segments=3, parent=leg)

    # Modifiers toepassen bij export; enkel onze objecten.
    bpy.ops.object.select_all(action="SELECT")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", export_apply=True, export_yup=True)
    print(f"[robot] geschreven: {OUT}")


main()
