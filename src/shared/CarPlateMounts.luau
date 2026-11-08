--!strict
-- Where each car's number plates go (spec §1), keyed by car id.
--
-- Positions are car space in metres before the car's scale, the same frame
-- as the catalog's body pieces (offsetM): +X right, +Y up, forward is -Z,
-- the origin on the ground under the wheelbase centre, measured from the
-- body mount. A front plate faces -Z and a rear plate +Z. tiltDeg leans the
-- plate's top in toward the car, for a recess on a sloping boot lid or
-- bumper. A car with no front spot has no front entry and shows no front
-- plate. format is the Saudi plate that fits the recess (PlateStyles).
--
-- How each spot was measured: tools/carbody/README.md, "Plates".
local PlateStyles = require(script.Parent.PlateStyles)

export type Spot = { posM: { number }, format: PlateStyles.Format, tiltDeg: number? }
export type Mounts = { front: Spot?, rear: Spot? }

local CarPlateMounts = {}

CarPlateMounts.cars = {
	-- The store model has no plate parts. Rear: the tailgate recess, 0.85
	-- to 1.07 m up, its face 2.51 m back (carprobe.py); front: the bumper
	-- face under the grille, 2.37 m forward. Checked by eye in Studio.
	kruzer300 = {
		front = { posM = { 0, 0.56, -2.375 }, format = "short" },
		rear = { posM = { 0, 0.96, 2.515 }, format = "short" },
	},
	-- Store plate parts 130 (front) and 177 (rear, the boot recess leans
	-- 15°), storecar.py --spots.
	kamri12 = {
		front = { posM = { 0.015, 0.472, -2.38 }, format = "short", tiltDeg = 10.8 },
		rear = { posM = { -0.009, 0.784, 2.426 }, format = "short", tiltDeg = 14.7 },
	},
	-- Store plate parts 111 (front) and 116 (rear, the boot recess leans
	-- 16°), storecar.py --spots.
	akord = {
		front = { posM = { 0.004, 0.476, -2.43 }, format = "short" },
		rear = { posM = { -0.008, 0.862, 2.428 }, format = "short", tiltDeg = 16 },
	},
	-- Store plate parts Front and Rear (the boot recess leans 23.5°),
	-- storecar.py --spots.
	sonatta = {
		front = { posM = { 0.001, 0.455, -2.243 }, format = "short" },
		rear = { posM = { 0, 0.85, 2.292 }, format = "short", tiltDeg = 23.5 },
	},
	-- Store plate parts 120 (front, on the bumper below the grille) and 54
	-- (rear, the tailgate recess), storecar.py --spots.
	tahu = {
		front = { posM = { 0, 0.39, -2.319 }, format = "short", tiltDeg = -13.8 },
		rear = { posM = { 0, 0.931, 2.485 }, format = "short" },
	},
	-- Store plate parts 16 (front) and 82 (rear), storecar.py --spots.
	krownvik = {
		front = { posM = { -0.007, 0.421, -2.549 }, format = "short" },
		rear = { posM = { -0.001, 0.743, 2.629 }, format = "short", tiltDeg = 8.5 },
	},
	-- Store plate parts 126 (front) and 17 (rear): the empty brackets.
	krownvikfleet = {
		front = { posM = { -0.001, 0.429, -2.570 }, format = "short" },
		rear = { posM = { -0.001, 0.754, 2.643 }, format = "short" },
	},
	-- Rear: the store plate mount, part 36 (painted body colour, 2026-09-25).
	-- Front: by eye in Play (the store model has no front plate), centred on
	-- the bumper's front strip (part 90: y 0.914, face at z -2.248).
	kruzer80 = {
		front = { posM = { 0.006, 0.9, -2.26 }, format = "short" },
		rear = { posM = { -0.331, 1.111, 2.452 }, format = "short" },
	},
	-- By eye in Studio (2026-09-27): rear, the wide painted recess on the boot
	-- panel between the tail lamps, which slopes about 17°; front, the flat
	-- bumper band between the indicators and the lower grille (no recess).
	cruiser = {
		front = { posM = { 0, 0.52, -2.549 }, format = "long" },
		rear = { posM = { 0, 0.74, 2.665 }, format = "long", tiltDeg = 17 },
	},
	-- By eye in Studio (2026-09-27): rear, the notch in the rear bumper
	-- (about 36 x 15 cm); front, the bumper face behind the bull bar (no recess).
	pickup = {
		front = { posM = { 0, 0.52, -2.426 }, format = "short" },
		rear = { posM = { 0, 0.44, 2.753 }, format = "short" },
	},
	-- By eye in Studio (2026-09-27): rear, the panel between the tail lamps
	-- under the black strip, which slopes about 30°; front, the nose between
	-- the two intakes, whose chin leans out about 24°.
	hatch = {
		front = { posM = { 0, 0.32, -2.203 }, format = "long", tiltDeg = -24 },
		rear = { posM = { 0, 0.57, 2.007 }, format = "long", tiltDeg = 30 },
	},
	-- By eye in Studio (2026-09-27): rear, the tall recess in the boot lid
	-- between the tail lamps, which slopes about 9°; front, the bumper band
	-- between the chrome strip and the lower intake, too shallow for a short
	-- plate.
	lekzas = {
		-- Front moved 7.5 cm back and leaned 8 degrees onto the bumper: it stood
		-- off the bumper, seen from the side (owner, 2026-09-27; the last 1.5 cm
		-- after the owner's check in Play).
		front = { posM = { 0, 0.52, -2.285 }, format = "long", tiltDeg = 8 },
		rear = { posM = { 0, 0.76, 2.555 }, format = "short", tiltDeg = 9 },
	},
	-- By eye in Studio (2026-09-27): rear, the tailgate recess left of the
	-- spare wheel (about 40 x 21 cm); front, over the bumper's intake slot.
	batrol = {
		front = { posM = { 0, 0.73, -2.40 }, format = "long" },
		rear = { posM = { -0.37, 0.966, 2.46 }, format = "short" },
	},
	-- By eye in Studio (2026-09-27): rear, the boot-lid recess under the
	-- garnish (about 54 x 19 cm), which slopes about 12°; front, the bumper
	-- between the grille and the lower intake.
	kamri07 = {
		-- Front moved 2.5 cm back and leaned 12 degrees with the bumper: it
		-- stood upright off the curved bumper (owner, 2026-09-27).
		front = { posM = { 0, 0.46, -2.355 }, format = "short", tiltDeg = 12 },
		rear = { posM = { 0, 0.85, 2.37 }, format = "short", tiltDeg = 12 },
	},
} :: { [string]: Mounts }

-- The plate's frame relative to the car's body mount, in studs. Its -Z (a
-- Part's Front face, where the plate is drawn) points out of the car.
function CarPlateMounts.cframe(spot: Spot, rear: boolean, k: number, mps: number): CFrame
	local p = spot.posM
	return CFrame.new(Vector3.new(p[1], p[2], p[3]) * (k / mps))
		* CFrame.Angles(0, if rear then math.pi else 0, 0)
		* CFrame.Angles(math.rad(spot.tiltDeg or 0), 0, 0)
end

return CarPlateMounts
