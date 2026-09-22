"""Render a cleaned body the way the game assembles it (Blender script).

    blender -b --factory-startup --python tools/carbody/fbx_preview.py -- kamri_s [out_prefix]

Loads assets/cars/<car>/*.obj (car space), puts the wheel pieces on the four
hubs as BodyBuilder does (right-hand wheels turned 180 degrees about Y),
colours each piece like its catalog entry, and writes PNGs from a few angles.
"""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
COLOURS = {
    "Body": (0.92, 0.92, 0.9, 1),
    "Glass": (0.08, 0.11, 0.13, 1),
    "HeadLamps": (0.97, 0.95, 0.88, 1),
    "TailLamps": (0.75, 0.05, 0.06, 1),
    "Trim": (0.09, 0.09, 0.1, 1),
    "Interior": (0.16, 0.16, 0.17, 1),
    "Tyre": (0.06, 0.06, 0.06, 1),
    "Rim": (0.7, 0.72, 0.75, 1),
}


def main(car_id, prefix, wheelbase=2.775, track=1.575):
    folder = os.path.join(ROOT, "assets", "cars", car_id)
    summary = json.load(open(os.path.join(folder, "summary.json")))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # Car space is Y up; Blender is Z up.
    to_blender = Matrix.Rotation(math.radians(90), 4, "X")
    radius = summary["pieces"]["Tyre"]["sizeM"][1] / 2
    objs = []
    for name in summary["pieces"]:
        bpy.ops.wm.obj_import(filepath=os.path.join(folder, f"{name}.obj"), forward_axis="Y", up_axis="Z")
        ob = bpy.context.selected_objects[0]
        ob.name = name
        m = bpy.data.materials.new(name)
        m.diffuse_color = COLOURS.get(name, (0.5, 0.5, 0.5, 1))
        ob.data.materials.clear()
        ob.data.materials.append(m)
        if name in ("Tyre", "Rim"):
            hubs = []
            for side in (-1, 1):
                for end in (-1, 1):
                    at = Matrix.Translation((side * track / 2, radius, end * wheelbase / 2))
                    turn = Matrix.Rotation(math.pi, 4, "Y") if side > 0 else Matrix()
                    hubs.append(at @ turn)
            for i, hub in enumerate(hubs):
                w = ob if i == 0 else ob.copy()
                if i:
                    bpy.context.scene.collection.objects.link(w)
                w.matrix_world = to_blender @ hub
                objs.append(w)
        else:
            ob.matrix_world = to_blender
            objs.append(ob)
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.display.shading.light = "STUDIO"
    scn.display.shading.color_type = "MATERIAL"
    scn.display.shading.show_cavity = True
    scn.display.shading.show_object_outline = False
    scn.render.resolution_x, scn.render.resolution_y = 1400, 800
    cd = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cd)
    scn.collection.objects.link(cam)
    scn.camera = cam
    cd.type = "ORTHO"
    cd.ortho_scale = 5.6
    target = Vector((0, 0, 0.7))
    # Blender frame after to_blender: car -Z (forward) is Blender +Y... check:
    # to_blender maps (x, y, z) -> (x, -z, y), so forward (0,0,-1) -> (0,1,0).
    views = {
        "front34": Vector((-1.1, 1.3, 0.55)),
        "rear34": Vector((1.1, -1.3, 0.55)),
        "side": Vector((-1, 0, 0.02)),
        "front": Vector((0, 1, 0.08)),
        "rear": Vector((0, -1, 0.1)),
        "top": Vector((0, 0.001, 1)),
    }
    out = []
    for view, d in views.items():
        cam.location = target + d.normalized() * 12
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = f"{prefix}_{view}.png"
        bpy.ops.render.render(write_still=True)
        out.append(scn.render.filepath)
    print("[fbx_preview]", out)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    car = argv[0] if argv else "kamri_s"
    prefix = argv[1] if len(argv) > 1 else os.path.join(ROOT, "assets", "cars", car, "preview")
    main(car, prefix)
