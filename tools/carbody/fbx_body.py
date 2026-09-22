"""Clean an external car mesh into game body pieces (Blender script).

    blender -b --factory-startup --python tools/carbody/fbx_body.py -- kamri_s

Takes one fused, AI-sculpted car mesh (an FBX export with no UVs, one
material and everything welded into a few islands) and turns it into the
pieces RIG_SPEC.md section 7 asks for:

    Body       paint: shell, mirrors, door handles
    Glass      windscreen, rear screen, and the side windows (holes, filled)
    HeadLamps  TailLamps   lenses, cut out of the shell by outline
    Trim       grille, intakes, wipers, exhausts, antenna, underbody
    Interior   seats, wheel, dash
    Tyre, Rim  one left wheel in wheel space, split at the rim edge

On the way: welded, brand badges flattened off the shell, the paint lightly
smoothed (AI sculpts are lumpy), each piece decimated to a triangle budget,
smoothed by angle, UV projected, and moved into car space. Writes one OBJ
per piece (car space, metres; the wheel pieces in wheel space) and a
summary.json into assets/cars/<car>/. tools/carbody/fbx_pieces.py turns
those into the Luau data module the game loads.

The source's own axes: Z up, -Y forward, +X the car's left, normalised to
1 unit long. The CARS table says where its features are in those units, so
a second model needs a new entry, not new code.

Blender 5.2's bundled numpy is built for macOS 26. On an older macOS, pip
install numpy (the macosx_11_0 wheel) somewhere and set BLENDER_NUMPY_PATH
to that folder; the FBX importer needs it.
"""
import os
import sys

if os.environ.get("BLENDER_NUMPY_PATH"):
    sys.path.insert(0, os.environ["BLENDER_NUMPY_PATH"])

import json
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# ---------------------------------------------------------------------------
# Per-model settings, in the source's normalised units. Outlines are (x, z)
# polygons seen from the front or back, for the car's +X side; they are
# mirrored to the other side.
# ---------------------------------------------------------------------------
CARS = {
    "kamri_s": {
        "source": "white toyota car 3d model.fbx",
        "title": "Kamri S: the owner's sculpted XV40-shape saloon, cleaned for the game. No make or badge.",
        # Real wheelbase and track (the Kamri rig's): the model is scaled so
        # its wheel centres land on them. Y and Z share one scale so the
        # wheels stay round; X has its own so the track is right.
        "wheelbaseM": 2.775,
        "trackM": 1.575,
        # Front zone: faces past this Y (towards -Y) are the nose, past
        # rearY the tail.
        "noseY": -0.40,
        "tailY": 0.40,
        "headLamp": [(0.193, 0.187), (0.119, 0.187), (0.104, 0.148), (0.118, 0.146), (0.188, 0.170)],
        "tailLamp": [(0.193, 0.2125), (0.111, 0.2125), (0.096, 0.1764), (0.1167, 0.17), (0.190, 0.1903)],
        # Dark recesses in the nose: grille (a chevron), lower intake, fogs.
        "noseTrim": [
            [(-0.119, 0.186), (0.119, 0.186), (0.101, 0.153), (0.0, 0.137), (-0.101, 0.153)],
            [(-0.089, 0.097), (0.089, 0.097), (0.081, 0.072), (-0.081, 0.072)],
            [(0.133, 0.108), (0.179, 0.108), (0.179, 0.075), (0.133, 0.075)],
            [(-0.133, 0.108), (-0.179, 0.108), (-0.179, 0.075), (-0.133, 0.075)],
            # Where the nose badge was: pressed flat and made part of the
            # grille, so what is left of its outline reads as grille.
            [(-0.03, 0.197), (0.03, 0.197), (0.03, 0.163), (-0.03, 0.163)],
        ],
        # Bumps to press flat into the surface around them: the two badges,
        # and the interior mirror the sculpt fused into the windscreen.
        # (y range, (x, z) centre, (x, z) radii, which way the skin faces
        # in y: -1 forward, +1 back).
        "flatten": [
            ((-0.6, -0.40), (0.0, 0.179), (0.024, 0.015), -1),
            ((0.40, 0.6), (0.0, 0.2194), (0.024, 0.013), 1),
            ((-0.2, -0.05), (0.08, 0.29), (0.035, 0.025), -1),
        ],
        # Windscreen and rear screen: (x, y) outlines seen from above, for
        # faces above zMin that face up. Traced off a top view.
        "windscreen": {"outline": [(0.0, -0.106), (0.132, -0.109), (0.167, -0.24), (0.09, -0.262), (0.0, -0.268)], "zMin": 0.215, "anyFacing": True},
        "rearScreen": {"outline": [(0.0, 0.232), (0.136, 0.235), (0.128, 0.37), (0.0, 0.372)], "zMin": 0.225},
        # Side windows: the openings run straight into the door cards, so
        # there is no edge loop to fill. Panes are built on these (y, z)
        # outlines (traced off a side view), each point pushed out to the
        # frame's outer skin and set back a hair inside it.
        "sideWindows": [
            [(-0.164, 0.2232), (-0.12, 0.268), (-0.08, 0.294), (-0.04, 0.308), (0.014, 0.3128), (-0.006, 0.2288)],
            [(0.0472, 0.3128), (0.12, 0.31), (0.172, 0.298), (0.216, 0.274), (0.24, 0.252), (0.262, 0.236), (0.048, 0.2312)],
        ],
        "glassInset": 0.003,
        # Tyre/rim split, as a fraction of the tyre radius (vertices cluster
        # at 0.70 on the rim lip and from 0.77 on the tyre).
        "rimFraction": 0.735,
        "budgets": {
            "Body": 4600,
            "Glass": 600,
            "HeadLamps": 180,
            "TailLamps": 160,
            "Trim": 900,
            "Interior": 600,
            "Tyre": 700,
            "Rim": 560,
        },
        "smoothBody": {"factor": 0.35, "iterations": 3},
    },
}


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------


def inside(poly, x, z):
    """Even-odd point in polygon."""
    hit = False
    n = len(poly)
    for i in range(n):
        x1, z1 = poly[i]
        x2, z2 = poly[(i + 1) % n]
        if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1:
            hit = not hit
    return hit


def in_mirrored(poly, x, z):
    return inside(poly, abs(x), z)


def islands(bm):
    """Face index -> island id, and per island (min, max, faces)."""
    isl = [-1] * len(bm.faces)
    boxes = []
    for f in bm.faces:
        if isl[f.index] >= 0:
            continue
        nid = len(boxes)
        lo = Vector((9, 9, 9))
        hi = Vector((-9, -9, -9))
        count = 0
        stack = [f]
        isl[f.index] = nid
        while stack:
            g = stack.pop()
            count += 1
            for v in g.verts:
                lo = Vector((min(lo.x, v.co.x), min(lo.y, v.co.y), min(lo.z, v.co.z)))
                hi = Vector((max(hi.x, v.co.x), max(hi.y, v.co.y), max(hi.z, v.co.z)))
            for e in g.edges:
                for h in e.link_faces:
                    if isl[h.index] < 0:
                        isl[h.index] = nid
                        stack.append(h)
        boxes.append((lo, hi, count))
    return isl, boxes


def island_class(lo, hi):
    c = (lo + hi) / 2
    s = hi - lo
    if s.y > 0.9:
        return "shell"
    if abs(s.y - 0.146) < 0.01 and abs(s.z - 0.146) < 0.01:
        # The front-left wheel (+X is the source's left, -Y its front) is
        # the one the game mirrors to all four hubs; the rest are dropped.
        return "wheel" if c.x > 0 and c.y < 0 else "drop"
    if abs(s.y - 0.079) < 0.005 and s.x < 0.012:
        return "drop"  # brake calipers: they would spin with the wheel
    if abs(c.x) > 0.19 and 0.2 < c.z < 0.27 and s.x > 0.04:
        return "paint"  # mirrors
    if abs(c.x) > 0.195 and s.x < 0.012 and 0.18 < c.z < 0.22:
        return "paint"  # door handles
    if abs(c.x) < 0.175 and -0.2 < c.y < 0.33 and 0.06 < c.z < 0.33 and not (c.z > 0.315 and s.z < 0.01) and s.x < 0.2:
        return "interior"
    if abs(c.x) > 0.11 and c.y < -0.40 and c.z > 0.14:
        return "head"  # projector inserts behind the headlamp lens
    return "trim"


def shell_class(car, f):
    c = f.calc_center_median()
    n = f.normal
    ax = abs(c.x)
    w, r = car["windscreen"], car["rearScreen"]
    for g in (w, r):
        # The windscreen takes everything inside its outline: the sculpt's
        # fused mirror left inward-facing faces there. The rear screen keeps
        # the facing test so the parcel shelf under it stays paint.
        if c.z > g["zMin"] and (g.get("anyFacing") or n.z > -0.3) and in_mirrored(g["outline"], c.x, c.y):
            return "glass"
    if c.y < car["noseY"]:
        if in_mirrored(car["headLamp"], c.x, c.z):
            return "head"
        for poly in car["noseTrim"]:
            if inside(poly, c.x, c.z):
                return "trim"
    if c.y > car["tailY"] and in_mirrored(car["tailLamp"], c.x, c.z):
        return "tail"
    return "paint"


def absorb_specks(bm, cls, max_area=0.0012, enclosed=0.8):
    """A small patch of one class inside another (flecks of paint on the
    glass, glass on the bonnet) takes the class around it. cls maps face ->
    class name and is updated in place. Returns how many faces moved."""
    seen = set()
    moved = 0
    for f in bm.faces:
        if f in seen:
            continue
        k = cls[f]
        comp = [f]
        seen.add(f)
        i = 0
        while i < len(comp):
            g = comp[i]
            i += 1
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen and cls[h] == k:
                        seen.add(h)
                        comp.append(h)
        area = sum(g.calc_area() for g in comp)
        if area >= max_area:
            continue
        around = {}
        members = set(comp)
        for g in comp:
            for e in g.edges:
                for h in e.link_faces:
                    if h not in members:
                        around[cls[h]] = around.get(cls[h], 0) + 1
        if not around:
            continue
        best = max(around, key=around.get)
        if around[best] >= enclosed * sum(around.values()):
            for g in comp:
                cls[g] = best
            moved += len(comp)
    return moved


def refine(bm, zone, max_len, passes=4):
    """Split long edges inside a zone so region outlines cut cleanly."""
    for _ in range(passes):
        long = [e for e in bm.edges if e.calc_length() > max_len and zone((e.verts[0].co + e.verts[1].co) / 2)]
        if not long:
            break
        bmesh.ops.subdivide_edges(bm, edges=long, cuts=1, use_grid_fill=False)
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])


def flatten_badge(bm, yrange, centre, radii, sign):
    """Press a raised badge flat: project the verts inside the ellipse onto
    the plane through the ring of verts just outside it."""
    cx, cz = centre
    rx, rz = radii

    def at_end(v):
        return yrange[0] < v.co.y < yrange[1]

    def q(v):
        return ((v.co.x - cx) / rx) ** 2 + ((v.co.z - cz) / rz) ** 2

    ends = [v for v in bm.verts if at_end(v)]
    inner = [v for v in ends if q(v) <= 1.0]
    ring = [v for v in ends if 1.3 <= q(v) <= 2.2]
    if len(ring) < 3 or not inner:
        return 0
    # The badge sits proud of the panel: keep only the ring verts on the
    # outer skin (the furthest forward, or back, at each spot).
    ring.sort(key=lambda v: sign * v.co.y, reverse=True)
    ring = ring[: max(3, len(ring) // 2)]
    centroid = sum((v.co for v in ring), Vector()) / len(ring)
    # Least squares plane y = a x + b z + c through the ring.
    sxx = sxz = szz = sx = sz = sy = sxy = szy = 0.0
    for v in ring:
        x, y, z = v.co
        sxx += x * x
        sxz += x * z
        szz += z * z
        sx += x
        sz += z
        sy += y
        sxy += x * y
        szy += z * y
    n = len(ring)
    m = Matrix(((sxx, sxz, sx), (sxz, szz, sz), (sx, sz, n)))
    try:
        a, b, c = m.inverted() @ Vector((sxy, szy, sy))
    except ValueError:
        a, b, c = 0.0, 0.0, centroid.y
    moved = 0
    for v in inner:
        # Only the skin: whatever sits deeper (the cabin behind a
        # windscreen, the inside of a bumper) stays where it is.
        on_plane = a * v.co.x + b * v.co.z + c
        if abs(v.co.y - on_plane) < 0.02:
            v.co.y = on_plane
            moved += 1
    return moved


def boundary_loops(bm, faces):
    """Closed boundary loops of a face set: lists of verts."""
    fs = set(faces)
    edges = [e for f in faces for e in f.edges if sum(1 for g in e.link_faces if g in fs) == 1]
    nbr = {}
    for e in edges:
        a, b = e.verts
        nbr.setdefault(a, []).append(b)
        nbr.setdefault(b, []).append(a)
    seen = set()
    loops = []
    for start in nbr:
        if start in seen:
            continue
        loop = [start]
        seen.add(start)
        prev, cur = None, start
        while True:
            nxt = [w for w in nbr[cur] if w is not prev and w not in seen]
            if not nxt:
                break
            prev, cur = cur, nxt[0]
            seen.add(cur)
            loop.append(cur)
        if len(loop) > 2:
            loops.append(loop)
    return loops


# ---------------------------------------------------------------------------
# Objects
# ---------------------------------------------------------------------------


def new_object(name, bm_src, faces):
    """A new mesh object holding a copy of the given faces."""
    bm = bmesh.new()
    vmap = {}
    for f in faces:
        vs = []
        for v in f.verts:
            if v not in vmap:
                vmap[v] = bm.verts.new(v.co)
            vs.append(vmap[v])
        try:
            bm.faces.new(vs)
        except ValueError:
            pass  # duplicate face in the source
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def activate(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def weld(ob, dist):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=dist)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=dist * 0.1)
    bm.to_mesh(ob.data)
    bm.free()


def smooth(ob, factor, iterations):
    """Laplacian smoothing that leaves open borders where they are, so the
    pieces still meet."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    inner = [v for v in bm.verts if not v.is_boundary]
    for _ in range(iterations):
        bmesh.ops.smooth_laplacian_vert(bm, verts=inner, lambda_factor=factor, lambda_border=0.0, use_x=True, use_y=True, use_z=True, preserve_volume=True)
    bm.to_mesh(ob.data)
    bm.free()


def unrefine(ob):
    """Dissolve the flat splits refine() made, so they cost no budget."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.5), use_dissolve_boundaries=False, verts=bm.verts, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()


def protect_small_islands(ob, budget):
    """Small parts (wipers, handles, badges of trim) fall apart under a
    global collapse. Put islands under a size in a vertex group the
    decimator skips, as long as they leave most of the budget to the rest."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    isl, boxes = islands(bm)
    counts = [b[2] for b in boxes]
    limit = 600
    while limit > 20 and sum(c for c in counts if c < limit) > budget * 0.45:
        limit //= 2
    keep = {i for i, c in enumerate(counts) if c < limit}
    verts = {v.index for f in bm.faces if isl[f.index] in keep for v in f.verts}
    kept = sum(counts[i] for i in keep)
    bm.free()
    if not verts:
        return None, 0
    g = ob.vertex_groups.new(name="protect")
    g.add(list(verts), 1.0, "REPLACE")
    return g.name, kept


def decimate(ob, budget):
    """Collapse to the budget. The collapse ratio does not map exactly to a
    triangle count, so search it on the evaluated mesh before applying."""
    have = tris(ob)
    if have <= budget:
        return
    group, kept = protect_small_islands(ob, budget)
    activate(ob)
    mod = ob.modifiers.new("dec", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.use_collapse_triangulate = True
    if group:
        mod.vertex_group = group
        mod.invert_vertex_group = True
    lo, hi = 0.0, 1.0
    for _ in range(12):
        mod.ratio = (lo + hi) / 2
        dg = bpy.context.evaluated_depsgraph_get()
        ev = ob.evaluated_get(dg)
        count = sum(len(p.vertices) - 2 for p in ev.data.polygons)
        if count > budget:
            hi = mod.ratio
        else:
            lo = mod.ratio
        if abs(count - budget) < budget * 0.01:
            break
    mod.ratio = lo if count > budget else mod.ratio
    bpy.ops.object.modifier_apply(modifier=mod.name)


def finish(ob, angle_deg=35):
    """Triangulate, smooth by angle, and project UVs."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    activate(ob)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle_deg))
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")


def bounds(ob):
    ps = [ob.matrix_world @ v.co for v in ob.data.vertices]
    lo = Vector((min(p.x for p in ps), min(p.y for p in ps), min(p.z for p in ps)))
    hi = Vector((max(p.x for p in ps), max(p.y for p in ps), max(p.z for p in ps)))
    return lo, hi


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------


def build(car_id):
    car = CARS[car_id]
    out = os.path.join(ROOT, "assets", "cars", car_id)
    os.makedirs(out, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT, car["source"]))
    src = [o for o in bpy.data.objects if o.type == "MESH"][0]
    activate(src)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    report = {"source": {"file": car["source"], "triangles": tris(src)}}

    bm = bmesh.new()
    bm.from_mesh(src.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bm.faces.ensure_lookup_table()
    isl, boxes = islands(bm)
    icls = [island_class(lo, hi) for lo, hi, _ in boxes]
    shell = icls.index("shell")
    wheel_box = boxes[icls.index("wheel")]

    # Refine the shell where outlines cut it, then flatten the badges.
    shell_faces = [f for f in bm.faces if isl[f.index] == shell]
    shell_bm = bmesh.new()
    vmap = {}
    for f in shell_faces:
        vs = []
        for v in f.verts:
            if v not in vmap:
                vmap[v] = shell_bm.verts.new(v.co)
            vs.append(vmap[v])
        try:
            shell_bm.faces.new(vs)
        except ValueError:
            pass
    refine(shell_bm, lambda p: p.y < car["noseY"] or p.y > car["tailY"] or p.z > 0.215, 0.004)
    flattened = sum(flatten_badge(shell_bm, yr, c, r, sign) for yr, c, r, sign in car["flatten"])
    shell_bm.normal_update()
    shell_bm.faces.ensure_lookup_table()

    groups = {k: [] for k in ("paint", "glass", "head", "tail", "trim", "interior", "wheel")}
    cls = {f: shell_class(car, f) for f in shell_bm.faces}
    report["specksAbsorbed"] = absorb_specks(shell_bm, cls)
    for f in shell_bm.faces:
        groups[cls[f]].append(f)

    # Side windows: panes on the traced outlines, both sides.
    frame = [v.co for v in shell_bm.verts if v.co.z > 0.2]
    panes = []
    for outline in car["sideWindows"]:
        for side in (1, -1):
            ring = []
            for y, z in outline:
                near = [c.x * side for c in frame if abs(c.y - y) < 0.012 and abs(c.z - z) < 0.012 and c.x * side > 0]
                x = (max(near) if near else 0.17) - car["glassInset"]
                ring.append(Vector((x * side, y, z)))
            panes.append(ring)
    glass_bm = bmesh.new()
    for ring in panes:
        centre = sum(ring, Vector()) / len(ring)
        vs = [glass_bm.verts.new(p) for p in ring]
        c = glass_bm.verts.new(centre)
        for i in range(len(vs)):
            f = glass_bm.faces.new((c, vs[i - 1], vs[i]))
            f.normal_update()
            if f.normal.x * centre.x < 0:
                f.normal_flip()
    report["sideWindowPanes"] = len(panes)
    report["badgeVertsFlattened"] = flattened

    objs = {}
    objs["Body"] = [new_object("Body_shell", shell_bm, groups["paint"])]
    objs["Glass"] = [new_object("Glass", shell_bm, groups["glass"]), new_object("Glass_side", glass_bm, list(glass_bm.faces))]
    objs["HeadLamps"] = [new_object("HeadLamps_shell", shell_bm, groups["head"])]
    objs["TailLamps"] = [new_object("TailLamps", shell_bm, groups["tail"])]
    objs["Trim"] = [new_object("Trim_shell", shell_bm, groups["trim"])]
    objs["Interior"] = []
    wheel_faces = []
    for k in ("paint", "trim", "interior", "head"):
        faces = [f for f in bm.faces if icls[isl[f.index]] == k]
        if faces:
            ob = new_object(f"{k}_parts", bm, faces)
            target = {"paint": "Body", "trim": "Trim", "interior": "Interior", "head": "HeadLamps"}[k]
            objs[target].append(ob)
    wheel_faces = [f for f in bm.faces if icls[isl[f.index]] == "wheel"]
    wheel_bm = bmesh.new()
    wmap = {}
    for f in wheel_faces:
        vs = []
        for v in f.verts:
            if v not in wmap:
                wmap[v] = wheel_bm.verts.new(v.co)
            vs.append(wmap[v])
        try:
            wheel_bm.faces.new(vs)
        except ValueError:
            pass
    refine(wheel_bm, lambda p: True, 0.003)
    wheel_bm.normal_update()
    wheel_faces = list(wheel_bm.faces)

    # Tyre and rim: split the front-left wheel at the rim's edge.
    lo, hi, _ = wheel_box
    wc = (lo + hi) / 2
    radius = (hi.z - lo.z) / 2
    tyre_f, rim_f = [], []
    for f in wheel_faces:
        p = f.calc_center_median()
        r = math.hypot(p.y - wc.y, p.z - wc.z)
        (tyre_f if r > car["rimFraction"] * radius else rim_f).append(f)
    objs["Tyre"] = [new_object("Tyre", wheel_bm, tyre_f)]
    objs["Rim"] = [new_object("Rim", wheel_bm, rim_f)]

    # Join each piece's parts.
    pieces = {}
    for name, parts in objs.items():
        parts = [p for p in parts if len(p.data.polygons) > 0]
        if not parts:
            continue
        activate(parts[0])
        for p in parts[1:]:
            p.select_set(True)
        bpy.ops.object.join()
        ob = bpy.context.view_layer.objects.active
        ob.name = name
        pieces[name] = ob

    # Scale into metres. Wheel centres: the source's are symmetric, so the
    # front-left one gives the wheelbase and track.
    wheels = [b for b, k in zip(boxes, icls) if abs((b[1] - b[0]).y - 0.146) < 0.01 and abs((b[1] - b[0]).z - 0.146) < 0.01]
    ys = sorted({round((b[0].y + b[1].y) / 2, 4) for b in wheels})
    xs = sorted({round((b[0].x + b[1].x) / 2, 4) for b in wheels})
    wheelbase = ys[-1] - ys[0]
    track = xs[-1] - xs[0]
    s = car["wheelbaseM"] / wheelbase
    sx = car["trackM"] / track
    mid_y = (ys[-1] + ys[0]) / 2
    # Source (x, y, z) -> car space (X right, Y up, -Z forward):
    # X = -x * sx, Y = z * s, Z = (y - mid_y) * s.
    to_car = Matrix(((-sx, 0, 0, 0), (0, 0, s, 0), (0, s, 0, -mid_y * s), (0, 0, 0, 1)))
    report["scale"] = {"x": round(sx, 4), "yz": round(s, 4), "sourceWheelbase": round(wheelbase, 4), "sourceTrack": round(track, 4)}

    report["pieces"] = {}
    for name, ob in pieces.items():
        before = tris(ob)
        weld(ob, 1e-5)
        unrefine(ob)
        if name == "Body":
            sb = car["smoothBody"]
            smooth(ob, sb["factor"], sb["iterations"])
        decimate(ob, car["budgets"][name])
        # Into car space. A reflection in X plus a Y/Z swap is two
        # reflections, a proper rotation, so the winding survives.
        ob.data.transform(to_car)
        if name in ("Tyre", "Rim"):
            # Wheel space: origin at the wheel centre.
            centre = to_car @ wc
            ob.data.transform(Matrix.Translation(-centre))
        finish(ob, 35 if name != "Tyre" else 50)
        lo_, hi_ = bounds(ob)
        report["pieces"][name] = {
            "sourceTriangles": before,
            "triangles": tris(ob),
            "sizeM": [round(v, 4) for v in (hi_ - lo_)],
            "offsetM": [round(v, 4) for v in (lo_ + hi_) / 2],
        }
        # OBJ, already in car space: no axis conversion on the way out.
        activate(ob)
        bpy.ops.wm.obj_export(
            filepath=os.path.join(out, f"{name}.obj"),
            export_selected_objects=True,
            forward_axis="Y",
            up_axis="Z",
            export_materials=False,
            export_normals=True,
            export_uv=True,
            apply_modifiers=True,
        )
    four = sum(v["triangles"] for k, v in report["pieces"].items() if k not in ("Tyre", "Rim"))
    four += 4 * sum(report["pieces"][k]["triangles"] for k in ("Tyre", "Rim") if k in report["pieces"])
    report["wholeCarTriangles"] = four
    report["title"] = car["title"]
    with open(os.path.join(out, "summary.json"), "w") as fh:
        json.dump(report, fh, indent=2)
    print("[fbx_body]", json.dumps(report))
    return pieces


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    build(argv[0] if argv else "kamri_s")
