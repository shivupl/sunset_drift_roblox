--!strict
-- Where each car's garage cosmetics sit (garage spec §4, "Decals" and
-- "Exhaust"), keyed by car id. Same frame as CarPlateMounts: car space in
-- metres before the car's scale, +X right, +Y up, forward is -Z, the origin
-- on the ground under the wheelbase centre, measured from the body mount.
--
-- windscreen: the sun strip across the top of the windscreen. posM is the
-- strip's centre, just inside the glass; widthM the glass's width there;
-- heightM the strip's height; tiltDeg leans its top back toward +Z with the
-- screen's rake.
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
-- The windscreen strip was lined up with CarCosmetics.apply and front 3/4
-- captures instead. Each entry says what it was lined up against.
export type Windscreen = { posM: { number }, widthM: number, heightM: number, tiltDeg: number }
export type Outlet = { posM: { number }, dir: { number }?, factory: boolean?, pipeLengthM: number? }
export type Tips = { posM: { number }, spreadM: number, pipeLengthM: number }
export type Exhaust = { stock: { Outlet }, tips: Tips, bumperZ: number, quadOuterBumperZ: number? }
export type Windows = { side: { string }, screen: { string }, whole: { string }? }
export type Mounts = { windscreen: Windscreen?, exhaust: Exhaust?, windows: Windows? }

local CarCosmeticMounts = {}

-- All by eye in Studio Edit, 2026-09-28 (garage plan, task 3). "Inside"
-- strips sit about 1 cm behind see-through glass; where the glass is opaque
-- (a black glass mesh, or glass painted into a textured shell) nothing shows
-- behind it, so the strip sits just outside it like a vinyl sticker.
CarCosmeticMounts.cars = {
	-- Strip: outside the generated glass (it renders near-black), 6 cm under
	-- the screen's top at the roof, which is far back (z 0.17, the screen rakes
	-- about 27°); crowned glass, so 2 cm proud of the edge line.
	kamri = {
		-- Windows: one generated glass piece all round.
		windows = { side = {}, screen = {}, whole = { "Glass" } },
		windscreen = { posM = { 0, 1.446, 0.081 }, widthM = 1.2, heightM = 0.12, tiltDeg = 63 },
		-- Exhaust: the generated body has no pipe, so a factory one on the left
		-- under the bumper's lower edge (face 2.45 m at 0.38 m up, from the
		-- side and below), 2 cm past it. Tips 3 cm past that face, their tops
		-- tucked into the rising underside.
		exhaust = {
			stock = { { posM = { -0.55, 0.33, 2.47 }, factory = true, pipeLengthM = 0.35 } },
			tips = { posM = { 0, 0.30, 2.48 }, spreadM = 1.1, pipeLengthM = 0.35 },
			bumperZ = 2.45,
		},
	},
	-- Strip: outside the opaque black glass mesh, under the roof's front edge
	-- (side view: the screen rakes about 17°).
	hatch = {
		windscreen = { posM = { 0, 1.045, -0.496 }, widthM = 1.0, heightM = 0.12, tiltDeg = 73 },
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
		},
	},
	-- Strip: outside the textured shell, top edge on the glass's top edge (side
	-- view: an upright screen, about 54° from level).
	pickup = {
		windscreen = { posM = { 0, 1.605, -0.71 }, widthM = 1.35, heightM = 0.12, tiltDeg = 36 },
		-- Exhaust: the shell has no pipe and an open underside (the bed floor at
		-- 0.45 m, the bumper 0.365-0.57 m up, face 2.81 m). A factory pipe on the
		-- left through the bumper's lower half, its top on the bed floor, 2 cm
		-- past the face; tips the same way, 3 cm past it. Their pipes run under
		-- the bed to behind the rear tyre.
		exhaust = {
			stock = { { posM = { -0.6, 0.415, 2.83 }, factory = true, pipeLengthM = 0.8 } },
			tips = { posM = { 0, 0.415, 2.84 }, spreadM = 1.2, pipeLengthM = 0.8 },
			bumperZ = 2.81,
		},
	},
	-- Strip: outside the textured shell, its top on the glass's top edge (side
	-- view: the screen rakes about 34°).
	cruiser = {
		windscreen = { posM = { 0, 1.38, -0.535 }, widthM = 1.3, heightM = 0.12, tiltDeg = 56 },
		-- Exhaust: the shell has no pipe. A factory one on the left, its top
		-- under the bumper's lower rear edge (0.41 m up at 2.81 m, face 2.82-2.84
		-- m from below), 2 cm past it; tips 3 cm past, tops in the bumper's
		-- chamfer.
		exhaust = {
			stock = { { posM = { -0.6, 0.37, 2.84 }, factory = true, pipeLengthM = 0.4 } },
			tips = { posM = { 0, 0.32, 2.85 }, spreadM = 1.2, pipeLengthM = 0.4 },
			bumperZ = 2.82,
		},
	},
	-- Strip: inside the glass, from the fleet car's windscreen piece (Glass_3:
	-- top 1.375 m at z -0.235, rake 31°), checked from the front.
	krownvik = {
		-- Windows: six door and quarter lights; Glass_7 is the windscreen, roof
		-- line and rear window in one piece.
		windows = { side = { "Glass", "Glass_2", "Glass_3", "Glass_4", "Glass_5", "Glass_6" }, screen = {}, whole = { "Glass_7" } },
		windscreen = { posM = { 0, 1.336, -0.296 }, widthM = 1.2, heightM = 0.12, tiltDeg = 59 },
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
			quadOuterBumperZ = 2.715,
		},
	},
	-- Same body as the krownvik: same spots.
	krownvikfleet = {
		-- Windows: Glass_3 the windscreen, Glass_4 the rear window, the rest the
		-- doors (Glass_6 and _7 are the textured grey upper door bands).
		windows = { side = { "Glass", "Glass_2", "Glass_4", "Glass_5", "Glass_6", "Glass_7", "Glass_8" }, screen = { "Glass_3" } },
		windscreen = { posM = { 0, 1.336, -0.296 }, widthM = 1.2, heightM = 0.12, tiltDeg = 59 },
		-- Exhaust: as the krownvik, its pipes (in Underbody_6) and bumper about
		-- 1 cm further back (from below: 2.76 m at x ±0.715, 2.725 m at ±0.815).
		exhaust = {
			stock = {
				{ posM = { -0.715, 0.265, 2.665 }, dir = { 0, -0.14, 0.99 } },
				{ posM = { 0.715, 0.265, 2.665 }, dir = { 0, -0.14, 0.99 } },
			},
			tips = { posM = { 0, 0.265, 2.79 }, spreadM = 1.43, pipeLengthM = 0.35 },
			bumperZ = 2.76,
			quadOuterBumperZ = 2.725,
		},
	},
	-- Strip: inside the glass, just under the glass's top edge, checked from
	-- the front.
	lekzas = {
		-- Windows: Glass is every window in one piece; Glass_2, the shade band
		-- at the windscreen's top, is left as it is.
		windows = { side = {}, screen = {}, whole = { "Glass" } },
		windscreen = { posM = { 0, 1.33, -0.40 }, widthM = 1.2, heightM = 0.12, tiltDeg = 62 },
		-- Exhaust: its own twin chrome tips (Chrome_2), turned slightly down,
		-- in cut-outs of the lower valance (side view, Chrome_2 alone; ends at
		-- 2.53 m from below). Tips over them, 3 cm past the valance above them
		-- (2.59 m).
		exhaust = {
			stock = {
				{ posM = { -0.553, 0.325, 2.52 }, dir = { 0, -0.15, 0.99 } },
				{ posM = { 0.553, 0.325, 2.52 }, dir = { 0, -0.15, 0.99 } },
			},
			tips = { posM = { 0, 0.30, 2.62 }, spreadM = 1.106, pipeLengthM = 0.35 },
			bumperZ = 2.59,
		},
	},
	-- Strip: inside the windscreen piece (P37: top 1.375 m at z -0.31, rake
	-- 25.5°), under the black band at its top.
	kamri07 = {
		-- Windows: P37 the windscreen; P72 / P153 the front doors, P34 / P155
		-- the rear doors, P172 the rear window.
		windows = { side = { "P34", "P72", "P153", "P155", "P172" }, screen = { "P37" } },
		windscreen = { posM = { 0, 1.312, -0.413 }, widthM = 1.25, heightM = 0.12, tiltDeg = 64.5 },
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
		},
	},
	-- Strip: inside the dark glass, between the A-pillars (an upright screen,
	-- about 50° from level).
	batrol = {
		-- Windows: Glass is every window in one piece.
		windows = { side = {}, screen = {}, whole = { "Glass" } },
		windscreen = { posM = { 0, 1.71, -0.47 }, widthM = 1.24, heightM = 0.12, tiltDeg = 40 },
		-- Exhaust: its own single pipe (in Trim) runs back and out to the left
		-- rear corner, about 29° outward (from below), ending under the bumper
		-- (bottom 0.52 m, face 2.49 m, side view). Tips over it and its mirror,
		-- tops at the bumper's lower edge, 3 cm past the face.
		exhaust = {
			stock = { { posM = { -0.666, 0.485, 2.395 }, dir = { -0.48, 0, 0.88 } } },
			tips = { posM = { 0, 0.44, 2.52 }, spreadM = 1.332, pipeLengthM = 0.3 },
			bumperZ = 2.49,
		},
	},
	-- Strip: at the top of the windscreen piece (Glass_7: top 1.99 m at
	-- z -0.295, rake 43°).
	kruzer80 = {
		-- Windows: Glass_7 the windscreen; Glass to Glass_4 the doors, Glass_6
		-- the rear quarters, Glass_5 the tailgate.
		windows = { side = { "Glass", "Glass_2", "Glass_3", "Glass_4", "Glass_5", "Glass_6" }, screen = { "Glass_7" } },
		windscreen = { posM = { 0, 1.95, -0.34 }, widthM = 1.28, heightM = 0.12, tiltDeg = 47 },
		-- Exhaust: its own single pipe (in Chrome_13) on the right under the
		-- black bumper, turned a little out and about 8° down (side view,
		-- Chrome_13 alone; from below). Tips over it and its mirror, tops at the
		-- bumper's lower edge (0.70 m, 2.44 m), 3 cm past it.
		exhaust = {
			stock = { { posM = { 0.60, 0.643, 2.41 }, dir = { 0.19, -0.14, 0.97 } } },
			tips = { posM = { 0, 0.62, 2.47 }, spreadM = 1.2, pipeLengthM = 0.3 },
			bumperZ = 2.44,
		},
	},
} :: { [string]: Mounts }

-- The spot's frame relative to the car's body mount, in studs.
function CarCosmeticMounts.cframe(posM: { number }, tiltDeg: number?, k: number, mps: number): CFrame
	return CFrame.new(Vector3.new(posM[1], posM[2], posM[3]) * (k / mps)) * CFrame.Angles(math.rad(tiltDeg or 0), 0, 0)
end

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
		return { c - half - g, c - half + g, c + half - g, c + half + g }
	end
	return {}
end

-- Each aftermarket tip's mouth centre, metres, for n tips: at tips.posM's
-- height and z, at tipXs; a quad's outer two moved with the bumper there
-- (quadOuterBumperZ), same clearance past it.
function CarCosmeticMounts.tipMouths(e: Exhaust, n: number, quadPairGapM: number): { Vector3 }
	local out: { Vector3 } = {}
	local y, z = e.tips.posM[2], e.tips.posM[3]
	local xs = CarCosmeticMounts.tipXs(e, n, quadPairGapM)
	for i, x in xs do
		local outer = #xs >= 4 and (i == 1 or i == #xs)
		local shift = if outer and e.quadOuterBumperZ then e.quadOuterBumperZ - e.bumperZ else 0
		table.insert(out, Vector3.new(x, y, z + shift))
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
-- mouth with its LookVector pointing out of the pipe (straight back for tips;
-- the stock pipe's dir), UpVector as near car-up as that allows.
-- CarCosmetics puts an ExhaustOutlet Attachment at each one.
function CarCosmeticMounts.outletFrames(e: Exhaust, n: number, quadPairGapM: number): { CFrame }
	local out: { CFrame } = {}
	if n > 0 then
		for _, p in CarCosmeticMounts.tipMouths(e, n, quadPairGapM) do
			table.insert(out, CFrame.lookAt(p, p + Vector3.zAxis))
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

-- A frame in car metres to one relative to the body mount in studs.
function CarCosmeticMounts.toStuds(cf: CFrame, k: number, mps: number): CFrame
	return CFrame.new(cf.Position * (k / mps)) * cf.Rotation
end

return CarCosmeticMounts
