"""Turn a Creator Store car, exported from Studio, into game body pieces
(Blender script).

    BLENDER_NUMPY_PATH=... blender -b --factory-startup --python tools/carbody/store_body.py -- kamri07

The store model is stripped in Studio first (scripts, GUIs, sounds, lights,
invisible parts, badges that are whole parts), every part renamed P<index>,
its colour, material and transparency saved to assets/cars/<car>/parts.csv,
and the model exported with Export Selection. Studio writes world
coordinates in studs; the car was placed facing world -Z with its left on
-X, which is already car space (RIG_SPEC.md section 1) apart from the origin
and the unit.

This script:
  1. imports the export, one object per part group;
  2. casts rays at the car from every direction (glass lets them through)
     and deletes parts nothing reaches, plus the listed engine bay;
  3. cuts badge and lettering islands off the parts that carry them;
  4. sorts every part into a piece by what it is (paint, glass, lamps,
     chrome, trim, interior...), decimates each piece to a budget;
  5. scales studs to metres so the wheel centres sit on the real wheelbase,
     moves the origin to the ground under the wheelbase centre, and writes
     one OBJ per piece plus all of them in one OBJ for Studio's 3D Importer,
     and summary.json (sizes, offsets, colours) for the catalog.
"""
import os
import sys

if os.environ.get("BLENDER_NUMPY_PATH"):
    sys.path.insert(0, os.environ["BLENDER_NUMPY_PATH"])

import csv
import json
import math

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

CARS = {
    "kamri07": {
        "title": "Kamri '07: a mid-2000s Japanese saloon from the Creator Store (asset 876308553), debadged and cut down for the game.",
        "export": "camry_exp/camry_edit.obj",
        "wheelbaseM": 2.775,
        # Parts deleted outright: the engine bay under the bonnet (seen by a
        # handful of stray rays through the grille, never by a player).
        "remove": ["p173", "p191", "p39", "p171"],
        # Parts hit by fewer rays than this (of about 2.4 million) are stacked
        # duplicates or hidden brackets.
        "minHits": 8,
        # Badge islands: (part, keep-test). An island is cut when the test
        # says so. Studs, world coordinates as exported.
        "badges": {
            # The boot strip carries the maker's oval (centre, under half a
            # stud wide) and the model's script lettering (left of x 58.3).
            "p169": lambda c, s: (abs(c.x - 60.008) < 0.3 and s.x < 0.5) or (c.x < 58.3 and s.x < 0.2),
        },
        "glass": ["p34", "p72", "p153", "p155", "p37", "p172", "p126"],
        "lenses": ["p64", "p198"],
        "paint": ["p62", "p192", "p63", "p40", "p127", "p190", "p107", "p61", "p122", "p151", "p93", "p124", "p92", "p70", "p165", "p102"],
        # Car-space Z (metres, forward is -Z) where the front cabin ends.
        "cabinSplitM": 0.35,
        # Interior islands smaller than this (studs, largest side) that sit
        # wholly below the window line are deleted.
        "smallStuds": 1.2,
        # Side windows: their bottom edge is the window line.
        "sideGlass": ["p34", "p72", "p153", "p155"],
        # The front-left wheel is the one the game mirrors to all four hubs.
        "tyre": "tyrefl",
        "rim": "rimfl",
        "budgets": {
            # Planar-only (see decimate): 10,477. Leave the collapse out of it.
            "Body": 11000,
            "Glass": 1200,
            "Lenses": 1500,
            "TailLamps": 1200,
            "Indicators": 300,
            "Chrome": 1500,
            "Trim": 3000,
            "Grey": 1500,
            # The cabin, split at the front seat backs: the front (dash, wheel,
            # front seats) is what a player looks at through the windscreen
            # and side glass; the back is trimmed far harder. Small interior
            # pieces entirely below the window line are deleted.
            "InteriorDark": (2600, 500),
            "InteriorLight": (1600, 300),
            "Tyre": 900,
            "Rim": 900,
        },
    },
}

# Piece looks in the game: colour, material, transparency, cast shadow.
LOOKS = {
    "Body": {"paint": True},
    "Glass": {"color": [24, 30, 34], "material": "Glass", "transparency": 0.35, "castShadow": False},
    "Lenses": {"color": [200, 205, 210], "material": "Glass", "transparency": 0.7, "castShadow": False},
    "TailLamps": {"color": [150, 8, 10], "material": "Glass", "castShadow": False},
    "Indicators": {"color": [230, 140, 20], "material": "Glass", "castShadow": False},
    "Chrome": {"color": [205, 207, 210], "material": "Metal"},
    "Trim": {"color": [22, 22, 24], "material": "Plastic"},
    "Grey": {"color": [70, 70, 74], "material": "Plastic"},
    "InteriorDark": {"color": [28, 28, 30], "castShadow": False},
    "InteriorLight": {"color": [120, 116, 108], "castShadow": False},
    "Tyre": {"color": [24, 24, 26], "material": "Rubber"},
    "Rim": {"color": [188, 190, 194], "material": "Metal"},
}


def activate(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def part_key(name, keys):
    low = name.lower()
    for k in keys:
        if low.startswith(k):
            return k
    return None


def visibility(objs, glass_names, directions=400, grid=150):
    """First-hit counts per object over rays from every direction; glass
    counts a hit and lets the ray through. Returns (hits, through_glass,
    face_hits) where face_hits[object] is a list per polygon."""
    verts, polys, owner, local = [], [], [], []
    for oi, o in enumerate(objs):
        base = len(verts)
        mw = o.matrix_world
        verts.extend(mw @ v.co for v in o.data.vertices)
        for p in o.data.polygons:
            polys.append([base + i for i in p.vertices])
            owner.append(oi)
            local.append(p.index)
    face_hits = [[0] * len(o.data.polygons) for o in objs]
    bvh = BVHTree.FromPolygons(verts, polys)
    glass = {i for i, o in enumerate(objs) if o.name in glass_names}
    lo = Vector((min(v.x for v in verts), min(v.y for v in verts), min(v.z for v in verts)))
    hi = Vector((max(v.x for v in verts), max(v.y for v in verts), max(v.z for v in verts)))
    c = (lo + hi) / 2
    R = (hi - lo).length / 2 * 1.02
    hits = [0] * len(objs)
    behind = [0] * len(objs)
    golden = math.pi * (3 - math.sqrt(5))
    for k in range(directions):
        y = 1 - 2 * (k + 0.5) / directions
        r = math.sqrt(1 - y * y)
        d = Vector((r * math.cos(golden * k), y, r * math.sin(golden * k)))
        up = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))
        u = d.cross(up).normalized()
        v = d.cross(u).normalized()
        for i in range(grid):
            for j in range(grid):
                a = (i + 0.5) / grid * 2 - 1
                b = (j + 0.5) / grid * 2 - 1
                if a * a + b * b > 1:
                    continue
                o = c + d * R * 2 + u * (a * R) + v * (b * R)
                through = False
                for _ in range(6):
                    loc, _n, idx, _d = bvh.ray_cast(o, -d)
                    if loc is None:
                        break
                    oi = owner[idx]
                    hits[oi] += 1
                    face_hits[oi][local[idx]] += 1
                    if oi in glass:
                        through = True
                        o = loc - d * 1e-3
                        continue
                    if through:
                        behind[oi] += 1
                    break
    return hits, behind, face_hits


def cull_unseen_faces(ob, seen, rounds=3):
    """Delete the faces no ray reached (the inner skin of a panel, the back
    of a bumper), keeping any unseen face most of whose neighbours were seen
    so a small visible face that slipped between rays does not become a hole.
    Neighbours are found by shared corner positions: Studio's export gives
    every triangle its own corners."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    key = lambda co: (round(co.x, 4), round(co.y, 4), round(co.z, 4))
    by_corner = {}
    for f in bm.faces:
        for v in f.verts:
            by_corner.setdefault(key(v.co), []).append(f.index)
    keep = [h > 0 for h in seen]
    for _ in range(rounds):
        grown = list(keep)
        for f in bm.faces:
            if keep[f.index]:
                continue
            nbrs = {n for v in f.verts for n in by_corner[key(v.co)] if n != f.index}
            if nbrs and sum(1 for n in nbrs if keep[n]) >= 0.6 * len(nbrs):
                grown[f.index] = True
        keep = grown
    doomed = [f for f in bm.faces if not keep[f.index]]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bm.to_mesh(ob.data)
    bm.free()
    return len(doomed)


def cut_islands(ob, test):
    """Delete the islands of ob that test(centre, size) picks."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    seen = set()
    doomed = []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack = [f]
        seen.add(f.index)
        comp = []
        while stack:
            g = stack.pop()
            comp.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        vs = [ob.matrix_world @ v.co for g in comp for v in g.verts]
        lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
        hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
        if test((lo + hi) / 2, hi - lo):
            doomed.extend(comp)
    n = len(doomed)
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bm.to_mesh(ob.data)
    bm.free()
    return n


def trim_interior(ob, belt_y, small, split_z, budgets):
    """Delete small islands wholly below the window line, then decimate the
    front and rear cabin to their own budgets. World coordinates (studs)."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    seen = set()
    doomed = []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack = [f]
        seen.add(f.index)
        comp = []
        while stack:
            g = stack.pop()
            comp.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        vs = [v.co for g in comp for v in g.verts]
        lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
        hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
        if hi.y < belt_y and max(hi - lo) < small:
            doomed.extend(comp)
    dropped = len(doomed)
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    # Split front and rear.
    bm.faces.ensure_lookup_table()
    rear = [f for f in bm.faces if f.calc_center_median().z > split_z]
    rear_bm = bmesh.new()
    vmap = {}
    for f in rear:
        vs = []
        for v in f.verts:
            if v not in vmap:
                vmap[v] = rear_bm.verts.new(v.co)
            vs.append(vmap[v])
        try:
            rear_bm.faces.new(vs)
        except ValueError:
            pass
    bmesh.ops.delete(bm, geom=rear, context="FACES")
    bm.to_mesh(ob.data)
    bm.free()
    rear_me = bpy.data.meshes.new(ob.name + "_rear")
    rear_bm.to_mesh(rear_me)
    rear_bm.free()
    rear_ob = bpy.data.objects.new(ob.name + "_rear", rear_me)
    bpy.context.scene.collection.objects.link(rear_ob)
    decimate(ob, budgets[0])
    decimate(rear_ob, budgets[1])
    activate(ob)
    rear_ob.select_set(True)
    bpy.ops.object.join()
    return dropped


def classify(key, row, interior):
    """Which piece a part goes in."""
    r, g, b = int(row["r"]), int(row["g"]), int(row["b"])
    grey = (r + g + b) / 3
    if interior:
        return "InteriorLight" if grey > 90 else "InteriorDark"
    if r > 100 and g < 20:
        return "TailLamps"
    if r > 180 and 100 < g < 170 and b < 40:
        return "Indicators"
    if grey >= 175:
        return "Chrome"
    if grey < 70:
        return "Trim"
    return "Grey"


def decimate(ob, budget):
    have = tris(ob)
    if have <= budget:
        return
    # Near-flat areas first (5 degrees): merging them changes nothing you can
    # see. On this car that alone takes the paint from 21,330 to 10,477, so
    # the body never needs the collapse below, which folds the long, gently
    # curved door skins into creases.
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(float(os.environ.get("STORE_PLANAR_DEG", "5.0"))), use_dissolve_boundaries=False, verts=bm.verts, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.to_mesh(ob.data)
    bm.free()
    if tris(ob) <= budget:
        return
    activate(ob)
    mod = ob.modifiers.new("dec", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.use_collapse_triangulate = True
    lo, hi = 0.0, 1.0
    for _ in range(12):
        mod.ratio = (lo + hi) / 2
        ev = ob.evaluated_get(bpy.context.evaluated_depsgraph_get())
        count = sum(len(p.vertices) - 2 for p in ev.data.polygons)
        if count > budget:
            hi = mod.ratio
        else:
            lo = mod.ratio
        if abs(count - budget) < budget * 0.01:
            break
    if count > budget:
        mod.ratio = lo
    bpy.ops.object.modifier_apply(modifier=mod.name)


def weld_single_sided(ob, centre, outward):
    """Studio exports every triangle with its own corners, and double-sided
    panels carry each face twice, back to back. Weld the corners, then keep
    one face of each back-to-back pair: the one facing away from the car's
    centre for outside pieces. Decimating both skins folds them together."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-3)
    bm.faces.ensure_lookup_table()
    pairs = {}
    for f in bm.faces:
        pairs.setdefault(frozenset(v.index for v in f.verts), []).append(f)
    doomed = []
    for faces in pairs.values():
        if len(faces) < 2:
            continue
        if outward:
            faces.sort(key=lambda f: -f.normal.dot(f.calc_center_median() - centre))
        doomed.extend(faces[1:])
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-5)
    bm.to_mesh(ob.data)
    bm.free()
    return len(doomed)


def keep_normals(ob, high):
    """Copy the full-detail mesh's normals onto the decimated one, so it
    shades like the original instead of like its own coarser facets."""
    activate(ob)
    mod = ob.modifiers.new("normals", "DATA_TRANSFER")
    mod.object = high
    mod.use_loop_data = True
    mod.data_types_loops = {"CUSTOM_NORMAL"}
    # The nearest corner whose face points the same way: panels have an
    # inner skin a few millimetres behind the outer one, and plain nearest
    # picks it up and shades the paint with inward normals.
    mod.loop_mapping = "NEAREST_POLYNOR"
    bpy.ops.object.modifier_apply(modifier=mod.name)


def finish(ob, angle_deg=40, custom_normals=False):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    if not custom_normals:
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    activate(ob)
    if not custom_normals:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle_deg))
        # Area-weighted normals: the planar pass leaves long slivers across
        # flat panels, and plain smoothing lets each sliver pull the shading
        # as hard as a big face, which streaks the doors.
        mod = ob.modifiers.new("weighted", "WEIGHTED_NORMAL")
        mod.mode = "FACE_AREA"
        mod.keep_sharp = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if not ob.data.uv_layers:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
        bpy.ops.object.mode_set(mode="OBJECT")


def bounds(ob):
    ps = [ob.matrix_world @ v.co for v in ob.data.vertices]
    lo = Vector((min(p.x for p in ps), min(p.y for p in ps), min(p.z for p in ps)))
    hi = Vector((max(p.x for p in ps), max(p.y for p in ps), max(p.z for p in ps)))
    return lo, hi


def export(ob, path):
    activate(ob)
    bpy.ops.wm.obj_export(filepath=path, export_selected_objects=True, forward_axis="Y", up_axis="Z",
                          export_materials=False, export_normals=True, export_uv=True, apply_modifiers=True)


def build(car_id):
    car = CARS[car_id]
    out = os.path.join(ROOT, "assets", "cars", car_id)
    rows = {r["name"].replace("_", "").lower(): r for r in csv.DictReader(open(os.path.join(out, "parts.csv")))}
    keys = sorted(rows, key=len, reverse=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    # Identity axes: Blender holds the file's own coordinates (Y up), which
    # are already car-space directions.
    bpy.ops.wm.obj_import(filepath=os.path.join(ROOT, car["export"]), forward_axis="Y", up_axis="Z",
                          use_split_groups=True, use_split_objects=True)
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in objs:
        o["part"] = part_key(o.name, keys) or ""
    report = {"source": {"file": car["export"], "triangles": sum(tris(o) for o in objs), "parts": len({o["part"] for o in objs})}}

    # 1. What can be seen.
    glass_names = {o.name for o in objs if o["part"] in car["glass"]}
    hits, behind, face_hits = visibility(objs, glass_names)
    unseen = {}
    for o, fh in zip(objs, face_hits):
        unseen[o.name] = fh
    part_hits, part_behind = {}, {}
    for o, h, bh in zip(objs, hits, behind):
        part_hits[o["part"]] = part_hits.get(o["part"], 0) + h
        part_behind[o["part"]] = part_behind.get(o["part"], 0) + bh
    removed = {}
    for o in list(objs):
        p = o["part"]
        wheel = p.startswith("tyre") or p.startswith("rim")
        if (p in car["remove"] or part_hits[p] < car["minHits"]) and not wheel:
            removed[p] = removed.get(p, 0) + tris(o)
            objs.remove(o)
            bpy.data.objects.remove(o)
    report["removed"] = {"parts": sorted(removed), "triangles": sum(removed.values())}

    # 1b. The unseen faces of everything outside the cabin: the inner skins
    # of panels. Interior parts are seen only through glass and keep theirs.
    culled = 0
    for o in objs:
        p = o["part"]
        inside = part_behind.get(p, 0) > 0.5 * part_hits.get(p, 1)
        if not inside and p not in car["glass"] and not p.startswith("tyre") and not p.startswith("rim"):
            culled += cull_unseen_faces(o, unseen[o.name])
    report["unseenFacesCulled"] = culled

    # 2. Badges.
    cut = 0
    for o in objs:
        test = car["badges"].get(o["part"])
        if test:
            cut += cut_islands(o, test)
    report["badgeFacesCut"] = cut

    belt = min(bounds(o)[0].y for o in objs if o["part"] in car["sideGlass"])
    report["windowLineStuds"] = round(belt, 3)

    # 3. Sort into pieces.
    groups = {}
    wheel_centre = None
    for o in list(objs):
        p = o["part"]
        if p == car["tyre"]:
            name = "Tyre"
            lo, hi = bounds(o)
            wheel_centre = (lo + hi) / 2
        elif p == car["rim"]:
            name = "Rim"
        elif p.startswith("tyre") or p.startswith("rim"):
            bpy.data.objects.remove(o)
            continue
        elif p in car["glass"]:
            name = "Glass"
        elif p in car["lenses"]:
            name = "Lenses"
        elif p in car["paint"]:
            name = "Body"
        else:
            # Seen mostly through the glass: interior.
            interior = part_behind.get(p, 0) > 0.5 * part_hits.get(p, 1)
            name = classify(p, rows[p], interior)
        groups.setdefault(name, []).append(o)

    # 4. Scale and origin from the wheels: studs to metres so the wheel
    # centres sit on the real wheelbase; origin on the ground under the
    # wheelbase centre.
    tyres = {}
    for k in ("tyrefl", "tyrefr", "tyrerl", "tyrerr"):
        r = rows[k]
        tyres[k] = r
    fl, rl, fr = rows["tyrefl"], rows["tyrerl"], rows["tyrefr"]
    wheelbase_studs = abs(float(fl["cz"]) - float(rl["cz"]))
    track_studs = abs(float(fl["cx"]) - float(fr["cx"]))
    s = car["wheelbaseM"] / wheelbase_studs
    radius_studs = float(fl["sy"]) / 2
    ground = wheel_centre.y - radius_studs
    # Wheel centres in world: FL is at wheel_centre; the rear axle is
    # wheelbase_studs further back (+Z world, since the car faces -Z).
    mid_z = wheel_centre.z + wheelbase_studs / 2
    mid_x = wheel_centre.x + track_studs / 2
    to_car = Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-mid_x, -ground, -mid_z)))
    report["scale"] = {"metresPerStud": round(s, 5), "wheelbaseStuds": round(wheelbase_studs, 3), "trackM": round(track_studs * s, 4), "wheelRadiusM": round(radius_studs * s, 4)}

    car_centre = Vector((mid_x, ground + 2.5, mid_z))
    report["pieces"] = {}
    everything = []
    for name in CARS[car_id]["budgets"]:
        parts = groups.get(name)
        if not parts:
            continue
        activate(parts[0])
        for p in parts[1:]:
            p.select_set(True)
        bpy.ops.object.join()
        ob = bpy.context.view_layer.objects.active
        ob.name = name
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        before = tris(ob)
        dropped_faces = weld_single_sided(ob, car_centre, outward=not name.startswith("Interior"))
        report.setdefault("backFacesDropped", {})[name] = dropped_faces
        budget = car["budgets"][name]
        # For experiments: STORE_BUDGET_<Piece>=n overrides one budget.
        if os.environ.get(f"STORE_BUDGET_{name}"):
            budget = int(os.environ[f"STORE_BUDGET_{name}"])
        if isinstance(budget, tuple):
            # Window line: the bottom of the side glass. The cabin split in
            # world studs (the car faces -Z, so behind is +Z).
            split_z = mid_z + car["cabinSplitM"] / s
            dropped = trim_interior(ob, belt, car["smallStuds"], split_z, budget)
            ob = bpy.context.view_layer.objects.active
            ob.name = name
            report.setdefault("interiorSmallFacesDropped", {})[name] = dropped
        else:
            decimate(ob, budget)
        ob.data.transform(to_car)
        if name in ("Tyre", "Rim"):
            ob.data.transform(Matrix.Translation(-(to_car @ wheel_centre)))
        finish(ob, 50 if name == "Tyre" else 40)
        lo, hi = bounds(ob)
        entry = {
            "sourceTriangles": before,
            "triangles": tris(ob),
            "sizeM": [round(v, 4) for v in (hi - lo)],
            "offsetM": [round(v, 4) for v in (lo + hi) / 2],
        }
        entry.update(LOOKS[name])
        report["pieces"][name] = entry
        export(ob, os.path.join(out, f"{name}.obj"))
        everything.append(ob)

    # One file for Studio's 3D Importer: every piece as its own object.
    bpy.ops.object.select_all(action="DESELECT")
    for ob in everything:
        ob.select_set(True)
    bpy.ops.wm.obj_export(filepath=os.path.join(out, f"{car_id}_all.obj"), export_selected_objects=True, forward_axis="Y", up_axis="Z",
                          export_materials=False, export_normals=True, export_uv=True, apply_modifiers=True)

    wheels = sum(report["pieces"][k]["triangles"] for k in ("Tyre", "Rim") if k in report["pieces"])
    report["wholeCarTriangles"] = sum(v["triangles"] for k, v in report["pieces"].items() if k not in ("Tyre", "Rim")) + 4 * wheels
    report["title"] = car["title"]
    with open(os.path.join(out, "summary.json"), "w") as fh:
        json.dump(report, fh, indent=2)
    print("[store_body]", json.dumps(report))


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    build(argv[0] if argv else "kamri07")
