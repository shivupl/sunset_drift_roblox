"""Blender: simplify one store mesh for upload, and render it for a look.

    blender -b --factory-startup --python tools/carbody/simplify.py -- \
        assets/cars/kruzer80/rim_source.obj assets/cars/kruzer80/Rim.obj 0.3 /tmp/rim.png

An optional fifth argument is the store texture (PNG) to render it with,
to check the UVs survived. Welds the flat-shaded duplicate vertices, collapses to `ratio` of the
triangles, smooths normals below 35 degrees, and writes an OBJ for Studio's
3D Importer (Y up, -Z forward, as the source). The source OBJs come out of
Studio's cache (rbxcache.py). Kruzer 80: rim 9,822 -> 2,946 (0.3, the same
to the eye; 0.16 faceted the lip), hub 3,720 -> 520 (0.14).
"""
import bpy, sys, math
args = sys.argv[sys.argv.index("--") + 1:]
src, dst, ratio, png = args[0], args[1], float(args[2]), args[3]
texture = args[4] if len(args) > 4 else None
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=src, forward_axis='NEGATIVE_Z', up_axis='Y')
ob = bpy.context.selected_objects[0]
bpy.context.view_layer.objects.active = ob
# weld the flat-shaded duplicates first so the collapse sees one surface
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.remove_doubles(threshold=1e-4); bpy.ops.object.mode_set(mode='OBJECT')
before = len(ob.data.polygons)
if ratio < 1:
    mod = ob.modifiers.new("dec", "DECIMATE"); mod.ratio = ratio; mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier="dec")
bpy.ops.object.shade_auto_smooth(angle=math.radians(35))
after = len(ob.data.polygons)
bpy.ops.wm.obj_export(filepath=dst, export_selected_objects=True, forward_axis='NEGATIVE_Z', up_axis='Y', export_materials=False, export_triangulated_mesh=True, export_normals=True, export_uv=True)
# a quick look: workbench render facing the wheel's outer face
scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'; scene.render.resolution_x = 400; scene.render.resolution_y = 400
scene.display.shading.light = 'STUDIO'; scene.display.shading.show_cavity = True
if texture:
    # show the store texture on it, to see the UVs survived
    mat = bpy.data.materials.new("tex"); mat.use_nodes = True
    node = mat.node_tree.nodes.new("ShaderNodeTexImage"); node.image = bpy.data.images.load(texture)
    mat.node_tree.links.new(node.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    ob.data.materials.clear(); ob.data.materials.append(mat)
    scene.display.shading.color_type = 'TEXTURE'
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scene.collection.objects.link(cam); scene.camera = cam
d = max(ob.dimensions) * 1.9
cam.location = (-d, d * 0.25, d * 0.35); 
cam.rotation_euler = (math.radians(80), 0, math.radians(-100))
bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True)
bpy.ops.view3d.camera_to_view_selected() if False else None
cons = cam.constraints.new('TRACK_TO'); cons.target = ob; cons.track_axis = 'TRACK_NEGATIVE_Z'; cons.up_axis = 'UP_Y'
scene.render.filepath = png
bpy.ops.render.render(write_still=True)
print("TRIS", before, after)
