"""Exhaust tips for the garage, modelled in Blender (garage round 3 §1).

Run it headless from the repo root:

    /opt/homebrew/bin/blender -b -P tools/cosmetics/exhaust_tips.py -- [--preview DIR]

It builds every tip style as a mesh, gives it smooth normals (sharp only where
a face turns more than SHARP_DEG, the band clamp's and the caps' edges),
optionally renders a preview PNG per style into DIR, and writes the meshes to
src/shared/CosmeticMeshes/ExhaustTips as MeshData modules (the same quantised
buffers as src/shared/CarMeshes, encoded by tools/carbody/meshkit.py) plus a
per-position colour buffer. Blender's own numpy does not load on this Mac
(built for a newer macOS), so the writing half runs in the system python3
(numpy, Pillow), called by this script with --write.

Every mesh is authored in its own tip space, metres before the car's scale:
the mouth centre (the middle of the lip's crest) at the origin, +Z out of
the mouth (the way the gas leaves, the car's back), +Y up, +X right. The
generated module records each piece's bounding-box centre in that space
(offsetM), so CarCosmetics places a tip at its mouth frame times offsetM, and
the ExhaustOutlet attachments at the mouths (CarCosmeticMounts.tipMouths)
stay exactly where they were. Each piece also records where its pipe goes in
(inletM, inletRadiusM) and its outer half size across (radiusM), which the
runtime and the specs read.

Colours are per position, multiplied by the MeshPart's Color (measured in
Studio 2026-09-28, BEHAVIOURS.md): white outside, so the item's tip colour
shows; dark on the first centimetre of inner wall; the slash tip's heat
colours (straw, blue, violet from the lip back) baked in, on a near-white
part. Each bore is left open behind that centimetre; CarCosmetics closes it
with a flat dark disc Part (the module's `bores`).

One mesh per style (a client holds only 8 EditableMeshes):
  Rolled    single and twin chrome: round, rolled lip, band clamp, a flared
            reducer onto the pipe.
  QuadPair  a pair of black quad tips on one Y inlet, in pair space; a quad
            car has two pairs, so two pipes.
  Slash     burnt titanium: the rolled tip, longer, its mouth cut at
            SLASH_DEG (bottom shorter), heat colours baked in.
  Oval      Big Oval Tip: a large oval rolled tip on a round reducer.

Also writes tools/cosmetics/out/<Style>.obj for uploading a style as a mesh
asset (tools/cosmetics/README.md).
"""

from __future__ import annotations

import json
import math
import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "src", "shared", "CosmeticMeshes", "ExhaustTips")
# OBJs of the same meshes for Studio's 3D Importer (the asset path:
# CosmeticsConfig.render.tipStyles[style].meshAssetId, tools/cosmetics/README.md).
OBJ_OUT = os.path.join(ROOT, "tools", "cosmetics", "out")

# The round tips' outer radius: CosmeticsConfig.render.tipRadiusM (0.09 m,
# garage round 2), which CarCosmeticMounts' spacing checks use; the spec
# checks the generated Rolled and Quad radius against it.
TIP_R = 0.09
# The quad pair's centre-to-centre gap: CosmeticsConfig.render.quadPairGapM
# (0.2 m). QuadPair's collector ends sit under the tips there (spec-checked).
QUAD_GAP = 0.2
# The pipe the tips sit on is CosmeticsConfig.render.pipeRadiusM (0.04 m);
# every inlet collar is a little wider so the pipe slides inside it.
INLET_R = 0.046
# Lip: the tube wall rolled over, this thick (so the inner wall sits this far
# in) and rolled on half of it.
WALL = 0.012
# Segments round a round tip, and round the oval (which is wider, so more).
SEGMENTS = 32
SEGMENTS_OVAL = 34
SEGMENTS_SLASH = 28
# Faces meeting at more than this are a hard edge (the clamp's edges, the
# caps); everything else is smooth.
SHARP_DEG = 38
# The slash cut: the mouth plane leans this far from upright, the bottom
# shorter (the top reaches back; a top cut short would tuck under the bumper,
# whose face is only 3 cm in from the mouth).
SLASH_DEG = 26
# At most this many triangles a piece (garage round 3 spec).
MAX_TRIS = 1500

# Grey levels (multiplied by the part colour in Roblox).
OUTSIDE = 1.0
HIDDEN = 0.55  # the collar's front cap, inside the pipe
INNER = [(0.0, 0.85), (0.004, 0.3), (0.008, 0.1), (1.0, 0.05)]  # depth past the lip -> grey
# How deep a tip's bore is, from the lip's crest to its flat dark floor:
# 1.6 cm (the lip's roll, then a centimetre of inner wall). Measured in
# Studio 2026-09-28: every car's tips sit only 3 cm past the bumper face
# (CarCosmeticMounts), and the bumper's underside sweeps down across the
# top of the tip from the mouth back (on the lekzas it reaches the tip's
# inner wall about 2.5 cm in), and the car's own pipe ends 6 cm (kruzer80)
# to 12.5 cm (krownvik, batrol) in. A 12 cm bore showed both inside the
# mouth, and 2.8 cm still a crescent of bumper at the top; round 2's solid
# bore cylinder hid them. The floor closes the tube in front of both.
BORE = [0.004, 0.007, 0.010]
DEEP = 0.035  # the bottom of the bore


def lerp(a, b, t):
    return a + (b - a) * t


def ramp(keys, x):
    """keys: [(x, value)] ascending; value may be a tuple."""
    if x <= keys[0][0]:
        return keys[0][1]
    for (x0, v0), (x1, v1) in zip(keys, keys[1:]):
        if x <= x1:
            t = (x - x0) / (x1 - x0) if x1 > x0 else 1
            if isinstance(v0, tuple):
                return tuple(lerp(a, b, t) for a, b in zip(v0, v1))
            return lerp(v0, v1, t)
    return keys[-1][1]


def grey(g):
    return (g, g, g)


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


# ---------------------------------------------------------------------------
# Profiles: a tip is a stack of rings along its axis. Ring: (ax, ay, h, z,
# colour) -- the section at z is the ellipse (ax cos t, ay sin t) with its two
# halves pulled apart by h (a stadium, for the quad pair's collector). The stack runs
# from the front (the inlet) round the lip and back down the inner wall.
# ---------------------------------------------------------------------------


def ring(r, z, colour=OUTSIDE, ay=None, h=0.0):
    return {"ax": r, "ay": r if ay is None else ay, "h": h, "z": z, "c": colour if isinstance(colour, tuple) else grey(colour)}


def lip_rings(ax, ay, colour_of_depth):
    """The rolled lip: the outer skin at (ax, ay) curls over through the
    crest at z = 0 and comes back as the inner wall WALL further in."""
    out = []
    rr = WALL / 2
    for deg in (30, 60, 90, 120, 150, 180):
        f = math.radians(deg)
        d = rr - rr * math.cos(f)  # how far in from the outer skin
        z = -rr + rr * math.sin(f)
        out.append(ring(ax - d, z, colour_of_depth(0.0), ay=ay - d))
    return out


def inner_rings(ax, ay, depths, colour_of_depth):
    """The inner wall from the lip down to its floor at the last depth, and
    the floor: flat, dark, darkest at the middle, like the pipe's bore seen
    down the tip."""
    ix, iy = ax - WALL, ay - WALL
    out = [ring(ix, -WALL / 2 - d, colour_of_depth(d), ay=iy) for d in depths]
    floor = -WALL / 2 - depths[-1]
    k = INLET_R / max(ix, iy)
    out.append(ring(ix * k, floor, colour_of_depth(depths[-1]), ay=iy * k))
    return out, floor


def inner_grey(d):
    return grey(ramp(INNER, d))


def rolled(length=0.13, band=True, reducer=True, ax=TIP_R, ay=TIP_R, colour_of_depth=inner_grey, outer_colour=None, barrel_stops=()):
    """A rolled tip `length` from the mouth to the band's back edge. Returns
    (rings, front cap colour or None, back cap point, inlet z)."""
    oc = outer_colour or (lambda z: grey(OUTSIDE))
    rings = []
    zb = -length  # the band's back edge / the barrel's front
    if reducer:
        # The collar the pipe slides into, then a flared S-curve reducer up
        # to the barrel, under the band clamp.
        zc = zb - 0.075
        rings += [
            ring(INLET_R, zc, oc(zc)),
            ring(INLET_R, zc + 0.022, oc(zc + 0.022)),
        ]
        for t in (0.25, 0.55, 0.85):
            s = t * t * (3 - 2 * t)
            z = lerp(zc + 0.022, zb - 0.032, t)
            rings.append(ring(lerp(INLET_R, ax * 0.97, s), z, oc(z), ay=lerp(INLET_R, ay * 0.97, s)))
        inlet = zc
    else:
        zc = zb - 0.012
        rings.append(ring(ax - 0.004, zc, oc(zc), ay=ay - 0.004))
        inlet = zc
    if band:
        # A band clamp round the barrel's front: 3.5 mm proud, 2.2 cm wide,
        # chamfered edges.
        rings += [
            ring(ax, zb - 0.030, oc(zb - 0.030), ay=ay),
            ring(ax + 0.0035, zb - 0.027, oc(zb - 0.027), ay=ay + 0.0035),
            ring(ax + 0.005, zb - 0.023, oc(zb - 0.023), ay=ay + 0.005),
            ring(ax + 0.005, zb - 0.008, oc(zb - 0.008), ay=ay + 0.005),
            ring(ax + 0.0035, zb - 0.004, oc(zb - 0.004), ay=ay + 0.0035),
            ring(ax, zb - 0.001, oc(zb - 0.001), ay=ay),
        ]
    else:
        rings.append(ring(ax, zb, oc(zb), ay=ay))
    # The barrel to the lip: straight, so one long band, plus a ring at each
    # of barrel_stops where a colour ramp needs one.
    for z in sorted(barrel_stops):
        rings.append(ring(ax, z, oc(z), ay=ay))
    rings.append(ring(ax, -WALL / 2, oc(-WALL / 2), ay=ay))
    lip = lip_rings(ax, ay, colour_of_depth)
    for r in lip[:3]:
        r["c"] = oc(0.0)
    rings += lip
    return rings, inlet


def build_style(name, rings, front_cap, back_cap, segments, slash_deg=0.0, slash_from=None, xoff=0.0):
    """Rings to triangles. front_cap: (z, colour) closing the first ring to
    its centre; back_cap: (z, colour) closing the last ring to a point on the
    axis. Returns vertices (x, y, z), colours, triangles (vertex ids)."""
    V, C, T = [], [], []
    shear = math.tan(math.radians(slash_deg))
    lip_z = -WALL / 2

    def slash_z(z, y):
        if not slash_deg:
            return z
        # Linear from nothing at slash_from to the whole cut at the lip, so
        # the barrel's lines stay straight; the lip and inner wall's mouth end
        # lie in the cut plane.
        s = min(1.0, max(0.0, (z - slash_from) / (lip_z - slash_from)))
        return z + shear * y * s

    ids = []
    for r in rings:
        row = []
        for k in range(segments):
            t = 2 * math.pi * (k + 0.5) / segments
            c, s = math.cos(t), math.sin(t)
            x = r["ax"] * c + (r["h"] if c > 0 else -r["h"])
            y = r["ay"] * s
            row.append(len(V))
            V.append((x + xoff, y, slash_z(r["z"], y)))
            C.append(r["c"])
        ids.append(row)
    for a, b in zip(ids, ids[1:]):
        for k in range(segments):
            k1 = (k + 1) % segments
            # Counter-clockwise seen from outside (Roblox's front face,
            # measured with a test triangle in Studio): the stack runs
            # front to back outside and back to front inside, so the inner
            # wall and floor face into the bore.
            T.append((a[k], b[k1], b[k]))
            T.append((a[k], a[k1], b[k1]))
    if front_cap:
        z, col = front_cap
        cid = len(V)
        V.append((xoff, 0.0, z))
        C.append(grey(col) if not isinstance(col, tuple) else col)
        row = ids[0]
        for k in range(segments):
            T.append((cid, row[(k + 1) % segments], row[k]))
    if back_cap:
        z, col = back_cap
        cid = len(V)
        V.append((xoff, 0.0, slash_z(z, 0.0)))
        C.append(grey(col) if not isinstance(col, tuple) else col)
        row = ids[-1]
        for k in range(segments):
            T.append((row[k], row[(k + 1) % segments], cid))
    return V, C, T


def signed_volume(V, T):
    """Six times the volume a closed triangle surface bounds: positive when
    every face points out (counter-clockwise from outside)."""
    vol = 0.0
    for a, b, c in T:
        ax_, ay_, az_ = V[a]
        bx, by, bz = V[b]
        cx, cy, cz = V[c]
        vol += ax_ * (by * cz - bz * cy) - ay_ * (bx * cz - bz * cx) + az_ * (bx * cy - by * cx)
    return vol


def slash_tilt(floor, slash_deg, slash_from):
    """The slash tip's bore floor lies in the plane z = floor + k * y (the
    cut, ramped as build_style's slash_z does); the tilt of that plane from
    upright, degrees, turning the disc about X."""
    if not slash_deg:
        return 0.0
    s = min(1.0, max(0.0, (floor - slash_from) / (-WALL / 2 - slash_from)))
    return math.degrees(math.atan(math.tan(math.radians(slash_deg)) * s))


def tip_stack(rings, inner, floor, front, xoff=0.0):
    """One tip: the closed stack (for the winding check) and the bore disc
    that closes its shell. The shell drops the floor (inner's last ring) and
    the back cap: a plain dark Part closes it in the game (CarCosmetics), a
    matte one, because Metal mirrors the world through a dark vertex colour
    (Studio 2026-09-28) and a separate bore mesh would cost an EditableMesh
    (a client holds 8, BEHAVIOURS.md)."""
    full = rings + inner
    return dict(full=full, shell=full[:-1], front=front, back=(floor, DEEP), xoff=xoff,
                bore=dict(x=xoff, z=floor, rx=inner[0]["ax"], ry=inner[0]["ay"]))


def styles():
    """Each style is one mesh (one EditableMesh on a client): its stacks,
    their bores, and where its pipe goes in."""
    out = {}

    # Rolled: 13 cm from the mouth to the band's back edge (the old
    # cylinder was 16 cm with nothing on it; the band and reducer now carry
    # the front, 20.5 cm overall to the collar).
    rings, inlet = rolled(length=0.13)
    inner, floor = inner_rings(TIP_R, TIP_R, BORE, inner_grey)
    out["Rolled"] = dict(stacks=[tip_stack(rings, inner, floor, (inlet, HIDDEN))], segments=SEGMENTS,
                         inlet=(0, 0, inlet), inletR=INLET_R, radius=(TIP_R, TIP_R), tips=1)

    # QuadPair: one pair of black tips on their Y inlet, in pair space (origin
    # at the pair's centre on its mouth plane, tips at x = +-QUAD_GAP/2). One
    # mesh for the pair, so the quad costs one EditableMesh; a quad car has
    # two pairs, so two pipes. Where the bumper curves forward over the outer
    # tip (quadOuterBumperZ) the whole pair turns a little about Y
    # (CarCosmeticMounts.quadPairFrames), so both mouths still sit on it.
    # Each tip: shorter, no reducer or band, its closed front on the Y.
    # The Y: a round collar 33 cm in, flaring over 13 cm into a stadium whose
    # round ends (7.5 x 8 cm) sit under the tips, straight back to 6 cm in:
    # inside both tips (behind their bore floors) and, between them, a housing
    # that joins the pair and hides the car's own pipe that ends between a
    # pair's tips (the lekzas' pipe ends showed over a smaller collector).
    half = QUAD_GAP / 2
    stacks = []
    for xoff in (-half, half):
        rings, front = rolled(length=0.14, band=False, reducer=False)
        inner, floor = inner_rings(TIP_R, TIP_R, BORE, inner_grey)
        stacks.append(tip_stack(rings, inner, floor, (front, OUTSIDE), xoff))
    AX, AY = 0.075, 0.08
    yr = [ring(INLET_R, -0.33), ring(INLET_R, -0.305)]
    for t in (0.2, 0.45, 0.7, 0.9, 1.0):
        s = t * t * (3 - 2 * t)
        z = lerp(-0.305, -0.175, t)
        yr.append(ring(lerp(INLET_R, AX, s), z, ay=lerp(INLET_R, AY, s), h=lerp(0.002, half, s)))
    yr.append(ring(AX, -0.06, ay=AY, h=half))
    stacks.append(dict(full=yr, shell=yr, front=(-0.33, HIDDEN), back=(-0.06, OUTSIDE), xoff=0.0, bore=None, closed=True))
    out["QuadPair"] = dict(stacks=stacks, segments=SEGMENTS, inlet=(0, 0, -0.33), inletR=INLET_R,
                           radius=(TIP_R, TIP_R), tips=2)

    # Slash: the rolled tip, 3 cm longer, its mouth cut SLASH_DEG (the
    # bottom 4.4 cm shorter than the middle, the top 4.4 cm longer), heat
    # colours from the lip back.
    heat = [
        (0.0, hexrgb("#E4C98A")),   # straw at the lip
        (0.014, hexrgb("#D09A55")),  # gold-bronze
        (0.03, hexrgb("#A0587A")),  # rose
        (0.05, hexrgb("#3E5CD8")),  # blue
        (0.09, hexrgb("#6E3FC4")),  # violet
        (0.13, hexrgb("#5A4FB0")),  # blue-violet to the band
        (0.16, hexrgb("#9C9AA4")),  # the band and reducer: plain titanium
    ]

    def heat_at(z):
        return ramp(heat, -z)

    def slash_inner(d):
        # The inner lip keeps the straw; the wall goes dark as the others.
        return heat_at(0.0) if d <= 0 else inner_grey(d)

    # Rings where the heat colours change (a straight barrel has none), paid
    # for with 28 segments round instead of 32.
    rings, inlet = rolled(length=0.16, outer_colour=heat_at, colour_of_depth=slash_inner,
                          barrel_stops=(-0.03, -0.05, -0.09, -0.13))
    inner, floor = inner_rings(TIP_R, TIP_R, BORE, slash_inner)
    st = tip_stack(rings, inner, floor, (inlet, HIDDEN))
    st["bore"]["tilt"] = slash_tilt(floor, SLASH_DEG, -0.16)
    out["Slash"] = dict(stacks=[st], segments=SEGMENTS_SLASH, inlet=(0, 0, inlet), inletR=INLET_R,
                        radius=(TIP_R, TIP_R), slash=SLASH_DEG, slash_from=-0.16, tips=1)

    # Oval: 25 x 16 cm across the barrel, 14 cm to the band, on the same
    # round collar (the reducer blends the oval into it).
    OX, OY = 0.125, 0.08
    rings, inlet = rolled(length=0.14, ax=OX, ay=OY)
    inner, floor = inner_rings(OX, OY, BORE, inner_grey)
    out["Oval"] = dict(stacks=[tip_stack(rings, inner, floor, (inlet, HIDDEN))], segments=SEGMENTS_OVAL,
                       inlet=(0, 0, inlet), inletR=INLET_R, radius=(OX, OY), tips=1)
    return out


def build_piece(name, st):
    """A style's mesh: its stacks' shells merged. Each stack is first built
    closed and checked to face out (counter-clockwise from outside)."""
    kw = dict(slash_deg=st.get("slash", 0.0), slash_from=st.get("slash_from"))
    V, C, T = [], [], []
    for stack in st["stacks"]:
        fv, _, ft = build_style(name, stack["full"], stack["front"], stack["back"], st["segments"], xoff=stack["xoff"], **kw)
        assert signed_volume(fv, ft) > 0, f"{name}: faces point in"
        closed = stack.get("closed", False)
        sv, sc, stris = build_style(name, stack["shell"], stack["front"], stack["back"] if closed else None,
                                    st["segments"], xoff=stack["xoff"], **kw)
        base = len(V)
        V += sv
        C += sc
        T += [(a + base, b + base, c + base) for a, b, c in stris]
    assert len(T) / st["tips"] <= MAX_TRIS, f"{name}: {len(T)} triangles for {st['tips']} tips"
    return V, C, T


def blender_main(argv):
    import bpy

    preview = None
    if "--preview" in argv:
        preview = argv[argv.index("--preview") + 1]
        os.makedirs(preview, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    dump = {}
    for name, st in styles().items():
        V, C, T = build_piece(name, st)
        me = bpy.data.meshes.new(name)
        me.from_pydata(V, [], T)
        me.validate()
        me.set_sharp_from_angle(angle=math.radians(SHARP_DEG))
        me.update()
        col = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        for i, c in enumerate(C):
            col.data[i].color = (*[srgb_to_linear(x) for x in c], 1.0)
        # Per-corner normals, as Blender shades them.
        corners = []
        for poly in me.polygons:
            tri = []
            for li in range(poly.loop_start, poly.loop_start + poly.loop_total):
                vi = me.loops[li].vertex_index
                n = me.corner_normals[li].vector
                tri.append((vi, (n.x, n.y, n.z)))
            corners.append(tri)
        bores = [dict(s["bore"]) for s in st["stacks"] if s["bore"]]
        dump[name] = dict(
            positions=[list(v) for v in V],
            colours=[list(c) for c in C],
            corners=[[[vi, list(n)] for vi, n in tri] for tri in corners],
            inlet=list(st["inlet"]),
            inletR=st["inletR"],
            radius=list(st["radius"]),
            tips=st["tips"],
            bores=bores,
        )
        print(f"[tips] {name}: {len(T)} triangles, {len(V)} vertices")
        obj = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(obj)
        # The bore discs, for the previews only (the game builds them as Parts).
        for k, b in enumerate(bores):
            n = 32
            dv = [(b["x"], 0.0, b["z"])] + [(b["x"] + b["rx"] * math.cos(2 * math.pi * i / n), b["ry"] * math.sin(2 * math.pi * i / n), b["z"]) for i in range(n)]
            tilt = math.radians(b.get("tilt", 0.0))
            dv = [(x, y, z + math.tan(tilt) * y) for x, y, z in dv]
            dm = bpy.data.meshes.new(f"{name}Disc{k}")
            dm.from_pydata(dv, [], [(0, 1 + i, 1 + (i + 1) % n) for i in range(n)])
            dobj = bpy.data.objects.new(f"{name}Disc{k}", dm)
            bpy.context.scene.collection.objects.link(dobj)

    if preview:
        render_previews(preview)

    path = os.path.join(preview or OUT, "exhaust_tips.json") if preview else os.path.join(ROOT, "tools", "cosmetics", ".exhaust_tips.json")
    with open(path, "w") as fh:
        json.dump(dump, fh)
    env = {k: v for k, v in os.environ.items() if not k.startswith("PYTHON")}
    subprocess.run(["python3", os.path.abspath(__file__), "--write", path], check=True, env=env)
    if not preview:
        os.remove(path)


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def render_previews(folder):
    """One PNG per style: rear three-quarter, a little low, like the
    garage's view of a tip, on a dark floor under a key and a rim light."""
    import bpy
    from mathutils import Vector

    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 640
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.36, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    scene.world = world

    def material(name, base, metallic, rough, use_attr):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = rough
        if use_attr:
            attr = m.node_tree.nodes.new("ShaderNodeVertexColor")
            attr.layer_name = "Col"
            mix = m.node_tree.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs["Factor"].default_value = 1.0
            mix.inputs[6].default_value = base
            m.node_tree.links.new(attr.outputs["Color"], mix.inputs[7])
            m.node_tree.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        else:
            bsdf.inputs["Base Color"].default_value = base
        return m

    looks = {
        "Rolled": material("chrome", (0.7, 0.71, 0.73, 1), 1.0, 0.12, True),
        "QuadPair": material("black", (0.025, 0.025, 0.03, 1), 0.8, 0.35, True),
        "Slash": material("ti", (0.85, 0.85, 0.85, 1), 1.0, 0.25, True),
        "Oval": material("chrome2", (0.7, 0.71, 0.73, 1), 1.0, 0.12, True),
    }
    bore = material("bore", (0.02, 0.02, 0.022, 1), 0.0, 0.9, False)
    objs = {o.name: o for o in scene.objects}
    for name, o in objs.items():
        o.data.materials.append(looks.get(name, bore))
        o.rotation_euler = (math.radians(90), 0, 0)  # tip space (y up, z back) to Blender (z up, -y back)

    floor_me = bpy.data.meshes.new("floor")
    floor_me.from_pydata([(-3, -3, 0), (3, -3, 0), (3, 3, 0), (-3, 3, 0)], [], [(0, 1, 2, 3)])
    floor = bpy.data.objects.new("floor", floor_me)
    floor.data.materials.append(material("floor", (0.16, 0.14, 0.12, 1), 0.0, 0.8, False))
    scene.collection.objects.link(floor)

    def light(kind, loc, energy, size=0.3):
        ld = bpy.data.lights.new(kind + str(loc), kind)
        ld.energy = energy
        if kind == "AREA":
            ld.size = size
        lo = bpy.data.objects.new(ld.name, ld)
        lo.location = loc
        direction = Vector((0, 0, 0.1)) - Vector(loc)
        lo.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(lo)

    light("AREA", (0.6, -0.9, 0.9), 60, 0.8)
    light("AREA", (-0.9, 0.3, 0.6), 25, 0.6)
    light("AREA", (0.0, -0.5, -0.4), 8, 0.6)

    cam_d = bpy.data.cameras.new("cam")
    cam_d.lens = 55
    cam = bpy.data.objects.new("cam", cam_d)
    scene.collection.objects.link(cam)
    scene.camera = cam

    for shot in looks:
        for name, o in objs.items():
            o.hide_render = not name.startswith(shot)
            o.location = (0, 0, 0.12)
        target = Vector((0, 0.08, 0.12))
        cam.location = target + Vector((0.9, -0.3, 0.14))
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, f"tip_{shot}.png")
        bpy.ops.render.render(write_still=True)
        # And from straight behind, to see into the bore.
        cam.location = target + Vector((0.12, -0.9, 0.12))
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, f"tip_{shot}_behind.png")
        bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------------------
# Writer half (system python3): MeshData modules through meshkit's encoder.
# ---------------------------------------------------------------------------


def write_obj(path, piece, cols):
    """The piece in tip space (the mouth at the origin, as generated), with
    its per-vertex colour on each `v` line (x y z r g b, 0..1), which
    Studio's importer reads as vertex colour where it supports it."""
    with open(path, "w") as fh:
        fh.write(f"# GENERATED by tools/cosmetics/exhaust_tips.py: {piece.name}, metres, tip space\n")
        fh.write(f"o {piece.name}\n")
        for v, c in zip(piece.positions + piece.offset, cols):
            fh.write(f"v {v[0]:.5f} {v[1]:.5f} {v[2]:.5f} {c[0] / 255:.3f} {c[1] / 255:.3f} {c[2] / 255:.3f}\n")
        for n in piece.normals:
            fh.write(f"vn {n[0]:.4f} {n[1]:.4f} {n[2]:.4f}\n")
        for t in piece.tris:
            fh.write("f " + " ".join(f"{c[0] + 1}//{c[1] + 1}" for c in t) + "\n")


def write_main(path):
    import base64
    import struct

    import numpy as np

    sys.path.insert(0, os.path.join(ROOT, "tools", "carbody"))
    import meshkit  # the car bodies' encoder: same buffers, same decoder (MeshData)

    with open(path) as fh:
        dump = json.load(fh)
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(OBJ_OUT, exist_ok=True)
    for old in os.listdir(OUT):
        if old.endswith(".luau"):
            os.remove(os.path.join(OUT, old))
    gen = "-- GENERATED by tools/cosmetics/exhaust_tips.py. Do not edit by hand."
    lines = [
        "--!strict",
        gen,
        "-- Change the generator and run it again (tools/cosmetics/README.md).",
        "-- Exhaust tips, modelled in Blender (garage round 3 §1). Tip space, metres",
        "-- before the car's scale: the mouth centre at the origin, +Z out of the",
        "-- mouth, +Y up. Each piece is centred on its bounding box; offsetM is that",
        "-- centre in tip space (so a tip goes at its mouth frame * offsetM). inletM",
        "-- is where its pipe goes in (inletRadiusM wide; none on a quad tip, which",
        "-- sits on its pair's Y), radiusM a tip's outer half size across (x, y),",
        "-- tips how many tips the mesh holds. QuadPair is in pair space: the pair's",
        "-- centre on its mouth plane, tips at x = +-pairGapM/2. bores: each tip's",
        "-- open bore, closed in the game by a dark disc Part: its centre (xM, zM),",
        "-- radii and tilt about X (the slash cut).",
        "--",
        "-- Buffers as src/shared/CarMeshes (tools/carbody/meshkit.py): base64",
        "-- little-endian, positions int16 of the half size, normals int8, uvs",
        "-- uint16, triangles uint16 (position, normal, uv) per corner; plus colors,",
        "-- uint8 RGB per position (sRGB), which MeshData multiplies into the part",
        "-- colour.",
        "return {",
        f"\tpairGapM = {QUAD_GAP},",
        "\tpieces = {",
    ]
    report = []
    for name, d in dump.items():
        P = np.array(d["positions"], dtype=float)
        nrm_map, normals, tris = {}, [], []
        for tri in d["corners"]:
            corner = []
            for vi, n in tri:
                key = tuple(int(round(x * 127)) for x in n)
                if key not in nrm_map:
                    nrm_map[key] = len(normals)
                    normals.append(n)
                corner.append((vi, nrm_map[key], 0))
            tris.append(corner)
        lo, hi = P.min(0), P.max(0)
        centre = (lo + hi) / 2
        piece = meshkit.Piece(name, P - centre, np.array(normals), np.zeros((1, 2)), np.array(tris, dtype=np.int64), hi - lo, centre)
        e = meshkit.encode_piece(piece)
        cols = np.clip(np.round(np.array(d["colours"]) * 255), 0, 255).astype(int)
        e["colors"] = base64.b64encode(struct.pack("<" + "B" * cols.size, *cols.flatten().tolist())).decode("ascii")
        for key, text in e.items():
            assert len(text) < meshkit.CHUNK, f"{name} {key}: split it"
            with open(os.path.join(OUT, f"{name}_{key}.luau"), "w") as fh:
                fh.write("--!strict\n" + gen + "\n" + f'return "{text}"\n')
        s, o, i = piece.size, piece.offset, d["inlet"]
        lines += [
            f"\t\t{name} = {{",
            f"\t\t\ttriangleCount = {piece.triangles},",
            f"\t\t\tsizeM = {{ {s[0]:.4f}, {s[1]:.4f}, {s[2]:.4f} }},",
            f"\t\t\toffsetM = {{ {o[0]:.4f}, {o[1]:.4f}, {o[2]:.4f} }},",
            f"\t\t\tcounts = {{ {len(piece.positions)}, {len(piece.normals)}, 1 }},",
            f"\t\t\tinletM = {{ {i[0]:.4f}, {i[1]:.4f}, {i[2]:.4f} }},",
            f"\t\t\tinletRadiusM = {d['inletR'] if d['inletR'] else 0},",
            f"\t\t\tradiusM = {{ {d['radius'][0]:.4f}, {d['radius'][1]:.4f} }},",
            f"\t\t\ttips = {d['tips']},",
            "\t\t\tbores = {",
        ]
        for b in d["bores"]:
            lines.append(f"\t\t\t\t{{ xM = {b['x']:.4f}, zM = {b['z']:.4f}, radiusM = {{ {b['rx']:.4f}, {b['ry']:.4f} }}, tiltDeg = {b.get('tilt', 0.0):.3f} }},")
        lines.append("\t\t\t},")
        for key in ("positions", "normals", "uvs", "triangles", "colors"):
            lines.append(f"\t\t\t{key} = require(script.{name}_{key}) :: string,")
        lines.append("\t\t},")
        write_obj(os.path.join(OBJ_OUT, name + ".obj"), piece, cols)
        report.append(f"{name}: {piece.triangles} tris, {len(piece.positions)} positions, {len(piece.normals)} normals, size {s.round(4).tolist()}")
    lines += ["\t},", "}"]
    with open(os.path.join(OUT, "init.luau"), "w") as fh:
        fh.write("\n".join(lines) + "\n")
    print("\n".join(report))


if __name__ == "__main__":
    if "--write" in sys.argv:
        write_main(sys.argv[sys.argv.index("--write") + 1])
    else:
        blender_main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
