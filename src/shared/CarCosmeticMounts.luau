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
-- exhaust: where the aftermarket tips come out. posM is the centre between
-- a twin pair, at the tips' own centre (they protrude a few cm past the
-- bumper); spreadM the distance between the two tips of a twin.
--
-- A car with no entry (or no spot) shows no strip or no tips.
--
-- How each spot was measured: by eye in Studio Edit, like the plates
-- (tools/carbody/README.md, "Plates"): build the car (RigBuilder.build +
-- BodyBuilder.mount, anchored), CarCosmetics.apply a strip and twin tips
-- with trial numbers in this table, screen_capture front 3/4 and rear 3/4,
-- adjust, repeat. The strip sits about 1 cm inside the glass at its top, as
-- wide as the glass there; the tips just under the rear bumper's edge,
-- sticking out 3-5 cm. Each entry says what it was lined up against.
export type Windscreen = { posM: { number }, widthM: number, heightM: number, tiltDeg: number }
export type Exhaust = { posM: { number }, spreadM: number }
export type Mounts = { windscreen: Windscreen?, exhaust: Exhaust? }

local CarCosmeticMounts = {}

-- All by eye in Studio Edit, 2026-09-28 (garage plan, task 3). "Inside"
-- strips sit about 1 cm behind see-through glass; where the glass is opaque
-- (a black glass mesh, or glass painted into a textured shell) nothing shows
-- behind it, so the strip sits just outside it like a vinyl sticker.
CarCosmeticMounts.cars = {
	-- Strip: outside the generated glass (it renders near-black), 6 cm under
	-- the screen's top at the roof, which is far back (z 0.17, the screen rakes
	-- about 27°); crowned glass, so 2 cm proud of the edge line. Tips: under
	-- the bumper's black lower edge.
	kamri = {
		windscreen = { posM = { 0, 1.446, 0.081 }, widthM = 1.2, heightM = 0.12, tiltDeg = 63 },
		exhaust = { posM = { 0, 0.28, 2.40 }, spreadM = 1.1 },
	},
	-- Strip: outside the opaque black glass mesh, under the roof's front edge
	-- (side view: the screen rakes about 17°). Tips: 3 cm past the rear panel's
	-- lower edge, inboard of the wheels either side of the car's own pipes.
	hatch = {
		windscreen = { posM = { 0, 1.045, -0.496 }, widthM = 1.0, heightM = 0.12, tiltDeg = 73 },
		exhaust = { posM = { 0, 0.30, 1.95 }, spreadM = 0.8 },
	},
	-- Strip: outside the textured shell, top edge on the glass's top edge (side
	-- view: an upright screen, about 54° from level). Tips: under the rear
	-- bumper, 4 cm past it.
	pickup = {
		windscreen = { posM = { 0, 1.605, -0.71 }, widthM = 1.35, heightM = 0.12, tiltDeg = 36 },
		exhaust = { posM = { 0, 0.38, 2.77 }, spreadM = 1.2 },
	},
	-- Strip: outside the textured shell, its top on the glass's top edge (side
	-- view: the screen rakes about 34°). Tips: under the rear bumper.
	cruiser = {
		windscreen = { posM = { 0, 1.38, -0.535 }, widthM = 1.3, heightM = 0.12, tiltDeg = 56 },
		exhaust = { posM = { 0, 0.30, 2.80 }, spreadM = 1.2 },
	},
	-- Strip: inside the glass, from the fleet car's windscreen piece (Glass_3:
	-- top 1.375 m at z -0.235, rake 31°), checked from the front. Tips: under
	-- the rear bumper (bottom 0.23 m, face 2.82 m), 4 cm past it.
	krownvik = {
		windscreen = { posM = { 0, 1.336, -0.296 }, widthM = 1.2, heightM = 0.12, tiltDeg = 59 },
		exhaust = { posM = { 0, 0.30, 2.78 }, spreadM = 1.1 },
	},
	-- Same body as the krownvik: same spots.
	krownvikfleet = {
		windscreen = { posM = { 0, 1.336, -0.296 }, widthM = 1.2, heightM = 0.12, tiltDeg = 59 },
		exhaust = { posM = { 0, 0.30, 2.79 }, spreadM = 1.1 },
	},
	-- Strip: inside the glass, just under the glass's top edge, checked from
	-- the front. Tips: under the rear bumper's chrome lip.
	lekzas = {
		windscreen = { posM = { 0, 1.33, -0.40 }, widthM = 1.2, heightM = 0.12, tiltDeg = 62 },
		exhaust = { posM = { 0, 0.30, 2.52 }, spreadM = 1.1 },
	},
	-- Strip: inside the windscreen piece (P37: top 1.375 m at z -0.31, rake
	-- 25.5°), under the black band at its top. Tips: side view, tucked under
	-- the bumper, 4 cm past its lower edge.
	kamri07 = {
		windscreen = { posM = { 0, 1.312, -0.413 }, widthM = 1.25, heightM = 0.12, tiltDeg = 64.5 },
		exhaust = { posM = { 0, 0.30, 2.40 }, spreadM = 1.0 },
	},
	-- Strip: inside the dark glass, between the A-pillars (an upright screen,
	-- about 50° from level). Tips: under the rear bumper.
	batrol = {
		windscreen = { posM = { 0, 1.71, -0.47 }, widthM = 1.24, heightM = 0.12, tiltDeg = 40 },
		exhaust = { posM = { 0, 0.36, 2.44 }, spreadM = 1.1 },
	},
	-- Strip: at the top of the windscreen piece (Glass_7: top 1.99 m at
	-- z -0.295, rake 43°). Tips: under the black rear bumper (Trim_16, bottom
	-- 0.64 m, face 2.50 m).
	kruzer80 = {
		windscreen = { posM = { 0, 1.95, -0.34 }, widthM = 1.28, heightM = 0.12, tiltDeg = 47 },
		exhaust = { posM = { 0, 0.58, 2.46 }, spreadM = 1.1 },
	},
} :: { [string]: Mounts }

-- The spot's frame relative to the car's body mount, in studs.
function CarCosmeticMounts.cframe(posM: { number }, tiltDeg: number?, k: number, mps: number): CFrame
	return CFrame.new(Vector3.new(posM[1], posM[2], posM[3]) * (k / mps)) * CFrame.Angles(math.rad(tiltDeg or 0), 0, 0)
end

return CarCosmeticMounts
