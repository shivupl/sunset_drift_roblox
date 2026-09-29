--!strict
-- Where each car's garage cosmetics sit (garage spec §4, "Decals" and
-- "Exhaust"), keyed by car id. Same frame as CarPlateMounts: car space in
-- metres before the car's scale, +X right, +Y up, forward is -Z, the origin
-- on the ground under the wheelbase centre, measured from the body mount.
--
-- windscreen: the sun strip across the top of the windscreen, moulded to
-- the glass as slats (garage round 3 §3). These are the inputs of
-- tools/cosmetics/strip_shapes.py, which reads the glass mesh and writes the
-- slats to CarStripShapes (run it again after changing any of them):
--   piece: the body piece whose mesh is the windscreen (CarCatalog), a
--     glass piece or, on a shell car, the shell.
--   side: "inside" sits behind see-through glass; "outside" sits on opaque
--     glass (a black glass mesh, or glass painted into a textured shell),
--     where nothing behind it shows, like a vinyl sticker.
--   heightM: the strip's height, down the glass.
--   topGapM (optional, default 0): how far under the glass's top edge the
--     strip's top sits, down the glass.
--   ends: "mesh" runs the strip to where the glass ends at the pillars (the
--     mesh's outline), less endInsetM (optional) at each end. "spot" is for a
--     shell whose glass is painted into its texture, so the mesh has no
--     outline there: posM is a point on the screen (it picks the shell's
--     screen faces) and widthM the strip's width, both by eye.
-- exhaust: one shape on every car (garage round 2, §1, 2026-09-28: the
-- owner asked for exhausts "formatted uniformly throughout cars ... attached
-- in some sense to the car - not floating", so flames work on any of them).
--   stock: the car's own pipe mouth(s). posM is the centre of the mouth;
--     dir (optional, default straight back, {0, 0, 1}) the way the pipe points
--     out of it, as the pipe runs on the mesh; factory = true where the body
--     mesh has no pipe, so CarCosmetics builds a plain one there, pipeLengthM
--     long (optional; default tips.pipeLengthM), running forward from the
--     mouth. Listed left (-X) first: a single aftermarket tip goes on
--     stock[1]'s side.
--   tips: where aftermarket tips go. posM is the centre between a twin pair
--     at the tips' mouth (their open end); spreadM the distance between the
--     two tips of a twin; pipeLengthM the pipe that runs forward from each
--     tip's front end under the car, ending hidden in the body or muffler.
--     A single tip sits at spreadM/2 on stock[1]'s side, quad tips are two
--     pairs round the twin spots (CosmeticsConfig.render.quadPairGapM).
--   bumperZ: the rear face of the body just above the tips (the bumper's
--     lower edge, or a diffuser there). Tip mouths sit 2-5 cm past it, so
--     nothing overhangs them from behind (CarCosmeticMounts.spec).
--   riseM: how far above the tips' pipe centre the body sits where the pipe
--     ends (tips.pipeLengthM forward of the round-2 tip length): the pipe
--     bends up that far, and CosmeticsConfig.render.pipeEndBuryM more, so its
--     end is hidden inside (pipeRoute; garage round 3 §2). The body there is
--     the underbody, or the car's own muffler or pipe where the run ends in
--     one (each car says which). Where the run already ends inside the body
--     (its underside at or below the pipe's centre there), riseM is a
--     nominal 0.04, so the end still turns up and stays inside. A factory
--     outlet (factory = true) has its own riseM, from its own pipe centre at
--     the end of its own run. Measured 2026-09-28 by raycasts straight up
--     through copies of the body pieces made with precise collision (a
--     store MeshPart's own collision is a box), then checked by eye from under
--     the car, rear 3/4 and the side (garage round 3 task 2 report).
--   quadSpreadM (optional): the quad's pair centres at ±quadSpreadM/2
--     instead of ±spreadM/2, where a car's single own pipe would otherwise sit
--     in the gap between a pair's tips (the outer tip then covers it).
--   quadOuterBumperZ (optional): the same face above the quad's two outer
--     tips, where a bumper curves forward at its corners. Those two tips move
--     with it, keeping the same clearance past it as the others.
-- Where a car has its own pipes, the tips sit over them (same x, the stock
-- mouth inside the tip), like a slip-on tip. Fitted tips replace the whole
-- exhaust: only the tips are outlets. Where tips can't cover the car's own
-- pipes (the hatch's, too close together at the centre), those stay visible
-- but are not outlets.
--
-- windows: the glass pieces window tint recolours (garage round 2 §4), by
-- body piece name. side: the side and rear windows, which take a film's
-- glassTransparency. screen: the windscreen alone, which takes the film's
-- lighter screenTransparency so it stays legal-looking. whole (optional): a
-- piece that is the windscreen and other windows in one, which takes
-- halfway between the two. A car whose glass is opaque or painted into a
-- textured shell (hatch, pickup, cruiser) has no windows entry, and the
-- garage greys TINT out on it.
--
-- A car with no entry (or no spot) shows no strip or no tips.
--
-- How each spot was measured: by eye in Studio Edit, like the plates
-- (tools/carbody/README.md, "Plates"): build the car (RigBuilder.build +
-- BodyBuilder.mount, anchored), then near-orthographic captures (FieldOfView
-- 3, camera 30 m out, calibrated with marker balls at known car-space points:
-- about 700 px per metre) from straight behind, the side and below, with
-- every body piece but the pipe's hidden where the pipe is inside the body.
-- The windscreen strip comes from the glass mesh instead (above), checked
-- with CarCosmetics.apply and front 3/4, head-on and close captures.
export type Windscreen = {
	piece: string,
	side: "inside" | "outside",
	heightM: number,
	topGapM: number?,
	ends: "mesh" | "spot",
	endInsetM: number?,
	posM: { number }?,
	widthM: number?,
}
export type Outlet = { posM: { number }, dir: { number }?, factory: boolean?, pipeLengthM: number?, riseM: number? }
export type Tips = { posM: { number }, spreadM: number, pipeLengthM: number }
export type Exhaust = { stock: { Outlet }, tips: Tips, bumperZ: number, riseM: number, quadOuterBumperZ: number?, quadSpreadM: number? }
export type Windows = { side: { string }, screen: { string }, whole: { string }? }
export type Mounts = { windscreen: Windscreen?, exhaust: Exhaust?, windows: Windows? }

local CarCosmeticMounts = {}

-- Exhausts and windows by eye in Studio Edit, 2026-09-28 (garage plan, task
-- 3). Strips (garage round 3 §3): "inside" behind see-through glass;
-- where the glass is opaque (a black glass mesh, or glass painted into a
-- textured shell) nothing shows behind it, so the strip sits outside it like
-- a vinyl sticker. Each was checked front 3/4, head-on and close.
CarCosmeticMounts.cars = {
	-- Strip: outside the generated glass (it renders near-black), from its top
	-- edge at the roof down.
	kamri = {
		-- Windows: one generated glass piece all round.
		windows = { side = {}, screen = {}, whole = { "Glass" } },
		windscreen = { piece = "Glass", side = "outside", heightM = 0.12, ends = "mesh" },
		-- Exhaust: the generated body has no pipe, so a factory one on the left
		-- under the bumper's lower edge (face 2.45 m at 0.38 m up, from the
		-- side and below), 2 cm past it. Tips 3 cm past that face, their tops
		-- tucked into the rising underside.
		exhaust = {
			stock = { { posM = { -0.55, 0.33, 2.47 }, factory = true, pipeLengthM = 0.35, riseM = 0.04 } }, -- underside 0.257 m at z 2.12: inside
			tips = { posM = { 0, 0.30, 2.48 }, spreadM = 1.1, pipeLengthM = 0.35 },
			bumperZ = 2.45,
			-- riseM (garage round 3 §2): the generated body's underside is 0.217 m up
			-- at the run's end (z 1.97, x ±0.55), below the pipe's centre: the
			-- straight is already inside the body from z 2.2 on, so a nominal 4 cm.
			riseM = 0.04,
		},
	},
	-- Strip: outside the opaque black glass mesh, from its top edge down.
	hatch = {
		windscreen = { piece = "Glass", side = "outside", heightM = 0.12, ends = "mesh" },
		-- Exhaust: the car's own twin pipes (ExhaustL / ExhaustR) come out at the
		-- centre under the rear panel, pointing about 23° up (side view, the pipe
		-- pieces alone). Tips either side of them (too close together to sit
		-- over), 3 cm past the panel's lower edge (2.035 m at x ±0.4, from below),
		-- their tops in the sloping underside.
		exhaust = {
			stock = {
				{ posM = { -0.048, 0.444, 2.079 }, dir = { 0, 0.4, 0.92 } },
				{ posM = { 0.078, 0.444, 2.079 }, dir = { 0, 0.4, 0.92 } },
			},
			tips = { posM = { 0, 0.30, 2.065 }, spreadM = 0.8, pipeLengthM = 0.3 },
			bumperZ = 2.035,
			-- riseM: the shell's underside is 0.248 m at the run's end (z 1.605,
			-- x ±0.4), below the pipe's centre: already inside, a nominal 4 cm.
			riseM = 0.04,
		},
	},
	-- Strip: outside the textured shell, from the painted screen's top edge (the
	-- shell's glass faces start there, under the roof lip); ends by eye inside
	-- the painted pillars' rounded corners (1.35 m poked past them).
	pickup = {
		windscreen = { piece = "Shell", side = "outside", heightM = 0.12, ends = "spot", posM = { 0, 1.605, -0.71 }, widthM = 1.25 },
		-- Exhaust: the shell has no pipe and an open underside (the bed floor at
		-- 0.45 m, the bumper 0.365-0.57 m up, face 2.81 m). A factory pipe on the
		-- left through the bumper's lower half, its top on the bed floor, 2 cm
		-- past the face; tips the same way, 3 cm past it. Their pipes run under
		-- the bed to behind the rear tyre.
		exhaust = {
			stock = { { posM = { -0.6, 0.415, 2.83 }, factory = true, pipeLengthM = 0.8, riseM = 0.02 } }, -- bed floor 0.435 m at z 2.03
			tips = { posM = { 0, 0.415, 2.84 }, spreadM = 1.2, pipeLengthM = 0.8 },
			bumperZ = 2.81,
			-- riseM: the bed floor's underside is 0.427 m at the run's end (z 1.88,
			-- x ±0.6), 1.2 cm over the pipe's centre (0.415); the pipe hugs the
			-- floor and turns up into it. Its end's top is 0.499 m (factory 0.494),
			-- under the bed floor's top (0.54 m at z 1.79-1.94, the same raycasts
			-- from above: a floor about 11 cm thick there); nothing shows in the
			-- bed from above (checked, fix round 1).
			riseM = 0.015,
		},
	},
	-- Strip: outside the textured shell. Its forward-facing faces run up onto
	-- the roof, so the strip starts 21.5 cm under their top, at the painted
	-- screen's top edge; ends by eye inside the painted pillars.
	cruiser = {
		windscreen = { piece = "Shell", side = "outside", heightM = 0.12, ends = "spot", posM = { 0, 1.38, -0.535 }, widthM = 1.26, topGapM = 0.215 },
		-- Exhaust: the shell has no pipe. A factory one on the left, its top
		-- under the bumper's lower rear edge (0.41 m up at 2.81 m, face 2.82-2.84
		-- m from below), 2 cm past it; tips 3 cm past, tops in the bumper's
		-- chamfer.
		exhaust = {
			stock = { { posM = { -0.6, 0.37, 2.84 }, factory = true, pipeLengthM = 0.4, riseM = 0.04 } }, -- underside 0.331 m at z 2.44: inside
			tips = { posM = { 0, 0.32, 2.85 }, spreadM = 1.2, pipeLengthM = 0.4 },
			bumperZ = 2.82,
			-- riseM: the shell's underside is 0.318 m at the run's end (z 2.29,
			-- x ±0.6), level with the pipe's centre: a nominal 4 cm.
			riseM = 0.04,
		},
	},
	-- Strip: outside the windscreen, roof line and rear window piece (Glass_7),
	-- from its top edge down. Its glass is Glass material, and nothing drawn by
	-- a SurfaceGui behind Glass material shows (BEHAVIOURS.md), so the strip
	-- is a sticker on it; 1.5 cm in from each end, where the glass runs on
	-- under the pillar trim.
	krownvik = {
		-- Windows: six door and quarter lights; Glass_7 is the windscreen, roof
		-- line and rear window in one piece.
		windows = { side = { "Glass", "Glass_2", "Glass_3", "Glass_4", "Glass_5", "Glass_6" }, screen = {}, whole = { "Glass_7" } },
		windscreen = { piece = "Glass_7", side = "outside", heightM = 0.12, ends = "mesh", endInsetM = 0.015 },
		-- Exhaust: its own twin pipes (in Underbody) end under the bumper
		-- corners, tilted about 8° down (side view, Underbody alone; ends at
		-- 2.67 m from below). Tips over them, 3 cm past the bumper there (2.75 m
		-- at x ±0.715, from below, zoomed on the corner), pipes back into the
		-- mufflers. The bumper curves forward at its corners: 2.715 m over the
		-- quad's outer tips (x ±0.815).
		exhaust = {
			stock = {
				{ posM = { -0.715, 0.265, 2.655 }, dir = { 0, -0.14, 0.99 } },
				{ posM = { 0.715, 0.265, 2.655 }, dir = { 0, -0.14, 0.99 } },
			},
			tips = { posM = { 0, 0.265, 2.78 }, spreadM = 1.43, pipeLengthM = 0.35 },
			bumperZ = 2.75,
			-- riseM: the run ends in the car's own pipes and mufflers (in
			-- Underbody, its underside 0.23 m at z 2.27, x ±0.715, below the pipe's
			-- centre): a nominal 4 cm.
			riseM = 0.04,
			quadOuterBumperZ = 2.715,
		},
	},
	-- Same body as the krownvik; its windscreen is its own piece (Glass_3).
	krownvikfleet = {
		-- Windows: Glass_3 the windscreen, Glass_4 the rear window, the rest the
		-- doors (Glass_6 and _7 are the textured grey upper door bands).
		windows = { side = { "Glass", "Glass_2", "Glass_4", "Glass_5", "Glass_6", "Glass_7", "Glass_8" }, screen = { "Glass_3" } },
		windscreen = { piece = "Glass_3", side = "inside", heightM = 0.12, ends = "mesh" },
		-- Exhaust: as the krownvik, its pipes (in Underbody_6) and bumper about
		-- 1 cm further back (from below: 2.76 m at x ±0.715, 2.725 m at ±0.815).
		exhaust = {
			stock = {
				{ posM = { -0.715, 0.265, 2.665 }, dir = { 0, -0.14, 0.99 } },
				{ posM = { 0.715, 0.265, 2.665 }, dir = { 0, -0.14, 0.99 } },
			},
			tips = { posM = { 0, 0.265, 2.79 }, spreadM = 1.43, pipeLengthM = 0.35 },
			bumperZ = 2.76,
			-- riseM: as the krownvik, into its own pipes (Underbody_6, 0.249 m at
			-- z 2.28): a nominal 4 cm.
			riseM = 0.04,
			quadOuterBumperZ = 2.725,
		},
	},
	-- Strip: inside the all-round glass, from its top edge down (under the
	-- Glass_2 shade band).
	lekzas = {
		-- Windows: Glass is every window in one piece; Glass_2, the shade band
		-- at the windscreen's top, is left as it is.
		windows = { side = {}, screen = {}, whole = { "Glass" } },
		windscreen = { piece = "Glass", side = "inside", heightM = 0.12, ends = "mesh" },
		-- Exhaust: its own twin chrome tips (Chrome_2), turned slightly down,
		-- in cut-outs of the lower valance (side view, Chrome_2 alone; ends at
		-- 2.53 m from below). Tips over them, 3 cm past the valance above them
		-- (2.59 m).
		exhaust = {
			stock = {
				{ posM = { -0.553, 0.325, 2.52 }, dir = { 0, -0.15, 0.99 } },
				{ posM = { 0.553, 0.325, 2.52 }, dir = { 0, -0.15, 0.99 } },
			},
			-- Fix round 1 (garage round 3, 2026-09-28): 6 cm lower and 1.5 cm
			-- further back (was y 0.30, z 2.62). The bumper's underside sweeps
			-- down from 0.39 m at the mouth to 0.35 m 10 cm in and 0.32 m 15 cm
			-- in (side view, calibrated at 1,480 px/m), so the modelled tips'
			-- tops were inside it; now the top (0.33 m) clears it back to the
			-- band. 4.5 cm past the valance, inside the 2-5 cm standard.
			tips = { posM = { 0, 0.24, 2.635 }, spreadM = 1.106, pipeLengthM = 0.35 },
			bumperZ = 2.59,
			-- riseM: the Underbody's underside is 0.267 m at the run's end (z 2.125,
			-- x ±0.553), 2.7 cm over the pipe's centre; the run passes under the
			-- car's own chrome pipes (Chrome_2, from 0.252 m) and turns up into it.
			riseM = 0.03,
		},
	},
	-- Strip: inside the windscreen piece (P37), 10 cm under its top edge: the
	-- glass runs on under the roof, and the strip's top shows just under the
	-- dark band there (0 hid the whole strip; 8 cm still hid 2 cm).
	kamri07 = {
		-- Windows: P37 the windscreen; P72 / P153 the front doors, P34 / P155
		-- the rear doors, P172 the rear window.
		windows = { side = { "P34", "P72", "P153", "P155", "P172" }, screen = { "P37" } },
		windscreen = { piece = "P37", side = "inside", heightM = 0.12, topGapM = 0.1, ends = "mesh" },
		-- Exhaust: its own twin slash-cut tips (P50) off the mufflers (P31), under
		-- the bumper (side view, those two alone: 2.28-2.34 m; from below).
		-- Tips over them, 3 cm past the black diffuser strip above them (P60,
		-- 2.40 m at x ±0.57 from below), pipes back into the mufflers.
		exhaust = {
			stock = {
				{ posM = { -0.565, 0.337, 2.31 } },
				{ posM = { 0.565, 0.337, 2.31 } },
			},
			tips = { posM = { 0, 0.31, 2.43 }, spreadM = 1.13, pipeLengthM = 0.3 },
			bumperZ = 2.40,
			-- riseM: the run ends in the car's own mufflers (P31, 0.289-0.372 m from
			-- z 1.9 to 2.2 at x ±0.565) and the floor behind them (P41, 0.30 m at
			-- z 1.92), both at the pipe's centre: a nominal 4 cm.
			riseM = 0.04,
		},
	},
	-- Strip: outside the dark all-round glass (Glass material: a SurfaceGui
	-- behind it does not show, BEHAVIOURS.md), from its windscreen's top edge.
	batrol = {
		-- Windows: Glass is every window in one piece.
		windows = { side = {}, screen = {}, whole = { "Glass" } },
		windscreen = { piece = "Glass", side = "outside", heightM = 0.12, ends = "mesh" },
		-- Exhaust: its own single pipe (in Trim) runs back and out to the left
		-- rear corner, about 29° outward (from below), ending under the bumper
		-- (bottom 0.52 m, face 2.49 m, side view). Tips over it and its mirror,
		-- tops at the bumper's lower edge, 3 cm past the face.
		exhaust = {
			stock = { { posM = { -0.666, 0.485, 2.395 }, dir = { -0.48, 0, 0.88 } } },
			tips = { posM = { 0, 0.44, 2.52 }, spreadM = 1.332, pipeLengthM = 0.3 },
			-- Quad pairs 0.2 m further in, so the outer left tip, not the gap
			-- between a pair's tips, sits over its own pipe (fix round 1).
			quadSpreadM = 1.132,
			bumperZ = 2.49,
			-- riseM: the Underbody's underside is 0.532 m over the run's end (z 2.01
			-- to 2.21, x ±0.566 and ±0.666), 9.2 cm over the pipe's centre (0.44).
			riseM = 0.09,
		},
	},
	-- Strip: inside the windscreen piece (Glass_7), from its top edge down.
	kruzer80 = {
		-- Windows: Glass_7 the windscreen; Glass to Glass_4 the doors, Glass_6
		-- the rear quarters, Glass_5 the tailgate.
		windows = { side = { "Glass", "Glass_2", "Glass_3", "Glass_4", "Glass_5", "Glass_6" }, screen = { "Glass_7" } },
		windscreen = { piece = "Glass_7", side = "inside", heightM = 0.12, ends = "mesh" },
		-- Exhaust: its own single pipe (in Chrome_13) on the right under the
		-- black bumper, turned a little out and about 8° down (side view,
		-- Chrome_13 alone; from below). Tips over it and its mirror, tops at the
		-- bumper's lower edge (0.70 m, 2.44 m), 3 cm past it.
		exhaust = {
			stock = { { posM = { 0.60, 0.643, 2.41 }, dir = { 0.19, -0.14, 0.97 } } },
			tips = { posM = { 0, 0.62, 2.47 }, spreadM = 1.2, pipeLengthM = 0.3 },
			-- Quad pairs 0.2 m further in, so the outer right tip sits over its
			-- own pipe: in the gap between a pair's tips the pipe, turned in as it
			-- runs forward, showed beside the right pair (fix round 1).
			quadSpreadM = 1.0,
			bumperZ = 2.44,
			-- riseM: an open underside; the floor (Chrome_13 and Interior_10's
			-- undersides) is 0.925 m over the run's end (z 1.85-2.26, x ±0.5 and
			-- ±0.6), 30.5 cm over the pipe's centre (0.62), so the pipe bends a full
			-- 90° and runs 22 cm straight up, behind the tyre and mud flap; its level
			-- end (top 0.94 m) stops under Interior_10's underside (0.953 m), so it
			-- is not in the cabin. No hanger (taller than hangerMaxM). On the right
			-- it rises beside the car's own pipe and muffler. The spec's boot line
			-- here is 0.948 m: a centimetre more riseM fails it.
			riseM = 0.3,
		},
	},
} :: { [string]: Mounts }

-- The aftermarket tips' centre x, metres, for n tips (0, 1, 2 or 4): a twin
-- at ±spreadM/2 round tips.posM, a single on stock[1]'s side (over a one-pipe
-- car's own pipe, the left of a symmetric car), quad as two pairs round the
-- twin spots, each pair's tips quadPairGapM apart.
function CarCosmeticMounts.tipXs(e: Exhaust, n: number, quadPairGapM: number): { number }
	local c, half = e.tips.posM[1], e.tips.spreadM / 2
	if n == 1 then
		local first = e.stock[1]
		local side = if first and first.posM[1] > 0 then 1 else -1
		return { c + side * half }
	elseif n == 2 then
		return { c - half, c + half }
	elseif n >= 4 then
		local g = quadPairGapM / 2
		local q = (e.quadSpreadM or e.tips.spreadM) / 2
		return { c - q - g, c - q + g, c + q - g, c + q + g }
	end
	return {}
end

-- A quad's two pairs as frames in car metres (garage round 3 §1: one mesh per
-- pair on one Y inlet): origin at the pair's centre on its mouth plane, +Z
-- out of the mouths, tips at x = +-quadPairGapM/2 in the frame. Where the
-- bumper curves forward over the outer tip (quadOuterBumperZ) the pair turns
-- about Y so its outer mouth moves forward with it and its inner one stays
-- put (on the krownvik and fleet, 3.5 cm over a 0.2 m gap: about 10°,
-- the pair pointing slightly outward, as the bumper there does).
function CarCosmeticMounts.quadPairFrames(e: Exhaust, quadPairGapM: number): { CFrame }
	local c, half = e.tips.posM[1], (e.quadSpreadM or e.tips.spreadM) / 2
	local y, z = e.tips.posM[2], e.tips.posM[3]
	local shift = if e.quadOuterBumperZ then e.quadOuterBumperZ - e.bumperZ else 0
	local out: { CFrame } = {}
	for _, side in { -1, 1 } do
		-- side * sin(yaw) * gap = -shift puts the outer mouth `shift` along z.
		local sinYaw = math.clamp(-side * shift / quadPairGapM, -1, 1)
		local yaw = math.asin(sinYaw)
		local centre = Vector3.new(c + side * half, y, z + shift / 2)
		table.insert(out, CFrame.new(centre) * CFrame.Angles(0, yaw, 0))
	end
	return out
end

-- Each aftermarket tip's frame, car metres: at its mouth centre, +Z out of
-- the mouth (tip space, tools/cosmetics). Straight back at tipXs, tips.posM's
-- height and z, except a quad's, which come from its pair frames (the outer
-- two moved with the bumper, quadOuterBumperZ, same clearance past it).
function CarCosmeticMounts.tipFrames(e: Exhaust, n: number, quadPairGapM: number): { CFrame }
	local out: { CFrame } = {}
	if n >= 4 then
		local g = quadPairGapM / 2
		for _, pair in CarCosmeticMounts.quadPairFrames(e, quadPairGapM) do
			table.insert(out, pair * CFrame.new(-g, 0, 0))
			table.insert(out, pair * CFrame.new(g, 0, 0))
		end
		return out
	end
	local y, z = e.tips.posM[2], e.tips.posM[3]
	for _, x in CarCosmeticMounts.tipXs(e, n, quadPairGapM) do
		table.insert(out, CFrame.new(x, y, z))
	end
	return out
end

-- Each aftermarket tip's mouth centre, metres, for n tips (tipFrames).
function CarCosmeticMounts.tipMouths(e: Exhaust, n: number, quadPairGapM: number): { Vector3 }
	local out: { Vector3 } = {}
	for _, f in CarCosmeticMounts.tipFrames(e, n, quadPairGapM) do
		table.insert(out, f.Position)
	end
	return out
end

-- The bumper face above tip i of n (tipMouths order): quadOuterBumperZ for
-- a quad's outer two where set, bumperZ otherwise.
function CarCosmeticMounts.bumperAt(e: Exhaust, i: number, n: number): number
	if n >= 4 and (i == 1 or i == n) and e.quadOuterBumperZ then
		return e.quadOuterBumperZ
	end
	return e.bumperZ
end

-- Whether n aftermarket tips hide one of the car's own pipes: a tip's centre
-- within a tip's diameter of the pipe's, across. That takes in a quad pair,
-- whose two tips sit either side of the twin spot (0.1 m off it). Visual
-- only (the spec keeps a one-pipe car's pipe from peeking out beside its
-- tips); outlets never come from stock pipes once tips are on.
function CarCosmeticMounts.tipCovers(e: Exhaust, o: Outlet, n: number, quadPairGapM: number, tipRadiusM: number): boolean
	for _, x in CarCosmeticMounts.tipXs(e, n, quadPairGapM) do
		if math.abs(x - o.posM[1]) <= 2 * tipRadiusM then
			return true
		end
	end
	return false
end

-- The outlet frames for the exhaust fitted, metres in car space: with n > 0
-- aftermarket tips, one per tip mouth and nothing else (the tips replace the
-- whole exhaust; any own pipe left showing, like the hatch's, is not an
-- outlet); with none, one per stock outlet. Each sits at the centre of the
-- mouth with its LookVector pointing out of the pipe (out of the tip for tips;
-- the stock pipe's dir; a turned quad pair's own axis), UpVector as near
-- car-up as that allows.
-- CarCosmetics puts an ExhaustOutlet Attachment at each one.
function CarCosmeticMounts.outletFrames(e: Exhaust, n: number, quadPairGapM: number): { CFrame }
	local out: { CFrame } = {}
	if n > 0 then
		for _, f in CarCosmeticMounts.tipFrames(e, n, quadPairGapM) do
			table.insert(out, CFrame.lookAt(f.Position, f.Position + f.ZVector))
		end
		return out
	end
	for _, o in e.stock do
		local p = Vector3.new(o.posM[1], o.posM[2], o.posM[3])
		local d = if o.dir then Vector3.new(o.dir[1], o.dir[2], o.dir[3]).Unit else Vector3.zAxis
		table.insert(out, CFrame.lookAt(p, p + d))
	end
	return out
end

-- How a pipe bends up into the body (CosmeticsConfig.render's pipe knobs;
-- CarCosmetics passes them in, so this stays a lookup with no config of its
-- own and the spec can walk every route).
export type PipeBend = {
	radiusM: number, -- centreline bend radius
	maxDeg: number, -- the most the pipe turns up
	segments: number, -- cylinders over maxDeg
	buryM: number, -- the end's rim this far inside the body
	axisRunM: number, -- a turned tip's pipe runs this far along its axis first
	hangerBackM: number, -- the hanger this far behind the bend
	hangerMaxM: number, -- no hanger where the strap would be taller than this
}

-- The render knobs the pipes read (CosmeticsConfig.render's fields; passed
-- in so this module stays free of config, and so CarCosmetics and the spec
-- build the same routes from one place).
export type PipeKnobs = {
	pipeBendRadiusM: number,
	pipeBendMaxDeg: number,
	pipeBendSegments: number,
	pipeEndBuryM: number,
	pipeAxisRunM: number,
	hangerBackM: number,
	hangerMaxM: number,
	pipeRunFromM: number,
	quadPairGapM: number,
}

function CarCosmeticMounts.pipeBend(k: PipeKnobs): PipeBend
	return {
		radiusM = k.pipeBendRadiusM,
		maxDeg = k.pipeBendMaxDeg,
		segments = k.pipeBendSegments,
		buryM = k.pipeEndBuryM,
		axisRunM = k.pipeAxisRunM,
		hangerBackM = k.hangerBackM,
		hangerMaxM = k.hangerMaxM,
	}
end

-- Where every tip pipe's straight run ends: tips.pipeLengthM forward of
-- round 2's tip length (pipeRunFromM) in from the mouth.
function CarCosmeticMounts.pipeFrontZ(e: Exhaust, k: PipeKnobs): number
	return e.tips.posM[3] - k.pipeRunFromM - e.tips.pipeLengthM
end

-- Each tip pipe's inlet frame, car metres, +Z out of the tip, for n tips:
-- one per tip at `inletM` in its tip frame, except a quad (n >= 4), which
-- has one pipe per pair at `pairInletM` in its pair frame (quadPairFrames).
-- The mesh quad's inlet is its Y; the cylinder fallback's pair pipe starts
-- between the pair's two cylinders, overlapping both (fix round 1: four
-- pipes at the tips' own x ran the pickup's outer two through its tyres).
function CarCosmeticMounts.pipeInlets(e: Exhaust, n: number, k: PipeKnobs, inletM: Vector3, pairInletM: Vector3): { CFrame }
	local out: { CFrame } = {}
	if n >= 4 then
		for _, f in CarCosmeticMounts.quadPairFrames(e, k.quadPairGapM) do
			table.insert(out, f * CFrame.new(pairInletM))
		end
		return out
	end
	for _, f in CarCosmeticMounts.tipFrames(e, n, k.quadPairGapM) do
		table.insert(out, f * CFrame.new(inletM))
	end
	return out
end
-- A routed pipe in car metres: straight cylinders from a to b, a ball at
-- each joint (where two cylinders meet at an angle), the hanger's foot (on
-- the pipe's centre) and top (inside the body), and where the pipe ends:
-- the centre of its last end face and the direction it points there.
export type PipeSegment = { a: Vector3, b: Vector3 }
export type PipeRoute = {
	segments: { PipeSegment },
	joints: { Vector3 },
	hanger: PipeSegment?,
	finish: Vector3,
	finishDir: Vector3,
}

-- The route of one pipe (garage round 3 §2): from `overlapM` behind the
-- inlet (inside the tip's collar, or 0 at a factory pipe's mouth), along the
-- tip's axis `out` (pointing out of the mouth) where the tip is turned, then
-- straight forward (-Z) to frontZ, then a bend up in the car's Y-Z plane
-- until its end's whole rim is riseM + buryM above the start's centre (the
-- body sits riseM up there), and straight on up if the bend's maxDeg is not
-- enough. Chords of the arc stand in for the bend, the last one lengthened
-- so its flat end, which leans back by half a chord's angle, still clears.
function CarCosmeticMounts.pipeRoute(inlet: Vector3, out: Vector3, overlapM: number, frontZ: number, riseM: number, radiusM: number, b: PipeBend): PipeRoute
	local segments: { PipeSegment } = {}
	local joints: { Vector3 } = {}
	local start = inlet + out * overlapM
	local head = start
	-- Along a turned tip's own axis first (more than about 1° off straight).
	if out.Z < 0.9998 then
		local j = inlet - out * b.axisRunM
		table.insert(segments, { a = start, b = j })
		head = j
	end
	local bendAt = Vector3.new(head.X, head.Y, math.min(head.Z, frontZ))
	local hanger: PipeSegment? = nil
	local target = riseM + b.buryM
	if head.Z - bendAt.Z > 1e-4 then
		if #segments > 0 then
			table.insert(joints, head)
		end
		table.insert(segments, { a = head, b = bendAt })
		local hz = bendAt.Z + b.hangerBackM
		if hz < head.Z - 0.02 and target <= b.hangerMaxM then
			local foot = Vector3.new(bendAt.X, bendAt.Y, hz)
			hanger = { a = foot, b = foot + Vector3.yAxis * target }
		end
	end
	-- The bend's angle: its end's lowest rim point (centre height less
	-- r cos(theta)) reaches target, or the most it may turn plus a riser.
	local rb, r = b.radiusM, radiusM
	local maxT = math.rad(b.maxDeg)
	local function short(t: number): number
		return target - (rb * (1 - math.cos(t)) - r * math.cos(t))
	end
	local theta, riser = maxT, 0
	if short(maxT) <= 0 then
		local lo, hi = 0, maxT
		for _ = 1, 30 do
			local mid = (lo + hi) / 2
			if short(mid) > 0 then
				lo = mid
			else
				hi = mid
			end
		end
		theta = hi
	else
		-- A riser only when it is longer than about a chord; a shorter one is
		-- folded into the last chord below (fix round 1: the batrol's 1 cm
		-- riser came and went with float rounding).
		local need = short(maxT) / math.sin(maxT)
		if need > rb * maxT / b.segments then
			riser = need
		end
	end
	local n = math.max(1, math.ceil(theta / maxT * b.segments - 1e-6))
	local fwd, up = -Vector3.zAxis, Vector3.yAxis
	local function at(t: number): Vector3
		return bendAt + fwd * (rb * math.sin(t)) + up * (rb * (1 - math.cos(t)))
	end
	local prev = bendAt
	for k = 1, n do
		if #segments > 0 then
			table.insert(joints, prev)
		end
		local p = at(theta * k / n)
		table.insert(segments, { a = prev, b = p })
		prev = p
	end
	local dir = fwd * math.cos(theta) + up * math.sin(theta)
	if riser > 0 then
		table.insert(joints, prev)
		local e = prev + dir * riser
		table.insert(segments, { a = prev, b = e })
		prev = e
	else
		-- The last chord leans back half a chord's angle from the bend's end
		-- direction, so its rim hangs a little lower: lengthen it to clear.
		local last = segments[#segments]
		dir = (last.b - last.a).Unit
		local cosA = math.sqrt(math.max(0, 1 - dir.Y * dir.Y))
		local lack = target - ((prev.Y - start.Y) - r * cosA)
		if lack > 0 and dir.Y > 0.05 then
			prev += dir * (lack / dir.Y)
			last.b = prev
		end
	end
	return { segments = segments, joints = joints, hanger = hanger, finish = prev, finishDir = dir }
end

-- A frame in car metres to one relative to the body mount in studs.
function CarCosmeticMounts.toStuds(cf: CFrame, k: number, mps: number): CFrame
	return CFrame.new(cf.Position * (k / mps)) * cf.Rotation
end

return CarCosmeticMounts
