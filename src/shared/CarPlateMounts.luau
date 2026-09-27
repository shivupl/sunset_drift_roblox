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
