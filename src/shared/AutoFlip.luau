--!strict
-- The maths of getting a capsized car back onto its wheels (client
-- AutoFlip). Asked by the owner on 2026-10-04: "an autoflip feature that
-- seamlessly/naturally flips the car back over if it capsizes", then: it was
-- "to robotic", "if i get into a flipped (upside down or flat state) i can
-- like turn my wheels to reflip back to normal ... make it look more natural".
--
-- So the car is rolled by a real torque about its long axis (rollDeg,
-- rightingDir, rollTorque below): the player steers it over, or after a
-- moment at rest it rolls itself the short way, and physics does the rest:
-- it pivots on its edge, tips past the balance point and drops onto its
-- springs. The scripted roll (frameAt and the rest) is only the last resort,
-- for a car wedged where it can't roll.
--
-- Natural means it rolls over its own edge rather than teleporting: the
-- rotation is the shortest turn from how it lies to upright with the same
-- heading (a roll about its long axis for a car on its side or roof), eased in
-- and out, and the car's centre is kept just high enough that its lowest
-- corner never goes into the ground, so it visibly pivots up over the edge it
-- lies on and settles onto its wheels. Pure functions, so the spec can check
-- them without a car.
local AutoFlip = {}

-- Degrees between the car's up and world up: 0 upright, 90 on its side, 180
-- on its roof.
function AutoFlip.tiltDeg(cf: CFrame): number
	return math.deg(math.acos(math.clamp(cf.UpVector.Y, -1, 1)))
end

-- How far the car is rolled about its own long axis from upright, degrees,
-- -180..180: the angle a right-hand turn about its LookVector (clockwise as
-- seen from behind) would take an upright car of the same heading to it.
-- Positive lying on its right side, negative on its left, about 180 on its
-- roof. 0 for a car standing on its nose or tail (no roll to speak of).
function AutoFlip.rollDeg(cf: CFrame): number
	local look = cf.LookVector
	local w = Vector3.yAxis - look * look.Y -- world up, square to the long axis
	if w.Magnitude < 1e-3 then
		return 0
	end
	w = w.Unit
	local up = cf.UpVector
	return math.deg(math.atan2(look:Dot(w:Cross(up)), w:Dot(up)))
end

-- Which way to roll it back the short way, as a steer: +1 clockwise as seen
-- from behind (steer right, torque along +LookVector), -1 the other way. A
-- car on its left side goes clockwise, on its right the other way; on its
-- roof whichever side it leans to.
function AutoFlip.rightingDir(cf: CFrame): number
	return if AutoFlip.rollDeg(cf) > 0 then -1 else 1
end

-- Which way, and how hard (-1..1), the driver's steer rolls it. On its side
-- either way of steering rolls it back the short way: steering "into the
-- ground" rolled it on over its roof and round, 270 degrees and 4 m across
-- the road (Studio, 2026-10-04). Past `roofDeg` of roll (on or near its
-- roof) both ways are as short, so the steer picks the side it goes over.
function AutoFlip.steerDir(cf: CFrame, steer: number, roofDeg: number): number
	if math.abs(AutoFlip.rollDeg(cf)) > roofDeg then
		return math.clamp(steer, -1, 1)
	end
	return AutoFlip.rightingDir(cf) * math.min(1, math.abs(steer))
end

-- The torque (N m) about the long axis that drives its roll rate `omega`
-- (rad/s) toward `target`: proportional to the shortfall through the car's
-- inertia (kg m^2) at `gain` per second, never past `cap` either way. Past
-- the balance point gravity takes over and the same law brakes it, so it
-- rolls at about `target` and doesn't slam down.
function AutoFlip.rollTorque(inertia: number, omega: number, target: number, gain: number, cap: number): number
	return math.clamp(inertia * (target - omega) * gain, -cap, cap)
end

-- The upright frame at `position` with the heading the car had: its nose
-- direction flattened onto the ground. A car standing on its nose or tail has
-- no such direction, so its roof direction (flattened) stands in for the nose.
function AutoFlip.upright(cf: CFrame, position: Vector3): CFrame
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if look.Magnitude < 0.2 then
		local up = cf.UpVector
		look = Vector3.new(up.X, 0, up.Z) * (if cf.LookVector.Y > 0 then 1 else -1)
	end
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(position, position + look.Unit, Vector3.yAxis)
end

-- Smoothstep: starts and ends at rest, so the roll gathers and settles.
function AutoFlip.ease(p: number): number
	p = math.clamp(p, 0, 1)
	return p * p * (3 - 2 * p)
end

-- The angle, degrees, of the shortest turn from `a` to `b`.
function AutoFlip.turnDeg(a: CFrame, b: CFrame): number
	local _, angle = (a.Rotation:Inverse() * b.Rotation):ToAxisAngle()
	return math.deg(math.abs(angle))
end

-- How low the car reaches below its centre with its rotation `rot`: the
-- lowest of its outline points (studs, in its own frame) in world Y, as a
-- (negative) offset. The points are each part's corners, not one box round
-- the whole car: a box's corner (mirror width at wheel depth) is nowhere on
-- the car, and rolling over it lifted the car twice as high as its real edge
-- (the tyre and sill) needs (Studio, 2026-10-04).
function AutoFlip.lowestY(rot: CFrame, points: { Vector3 }): number
	local low = math.huge
	for _, p in points do
		local y = (rot * p).Y
		if y < low then
			low = y
		end
	end
	return low
end

-- The 8 corners of a box from `lo` to `hi`, as outline points.
function AutoFlip.boxPoints(lo: Vector3, hi: Vector3): { Vector3 }
	local out = {}
	for _, x in { lo.X, hi.X } do
		for _, y in { lo.Y, hi.Y } do
			for _, z in { lo.Z, hi.Z } do
				table.insert(out, Vector3.new(x, y, z))
			end
		end
	end
	return out
end

export type Flip = {
	start: CFrame,
	target: CFrame,
	seconds: number,
	points: { Vector3 }, -- the car's outline in its own frame, studs (lowestY)
	groundY: number, -- world Y of the ground under it
	clearance: number, -- studs kept between its lowest corner and the ground
}

-- The car's frame `p` (0..1) of the way through a flip: rotation eased from
-- start to target, centre height eased between them but never lower than
-- keeps the lowest corner above the ground, so the car pivots over its edge
-- instead of sinking through it.
function AutoFlip.frameAt(f: Flip, p: number): CFrame
	local e = AutoFlip.ease(p)
	local rot = f.start.Rotation:Lerp(f.target.Rotation, e)
	local pos = f.start.Position:Lerp(f.target.Position, e)
	-- The clearance grows from nothing and fades out again, so the car
	-- starts exactly where it lies and finishes with its wheels on the ground
	-- rather than a hair above them.
	local floor = f.groundY + f.clearance * 4 * e * (1 - e) - AutoFlip.lowestY(rot, f.points)
	return rot + Vector3.new(pos.X, math.max(pos.Y, floor), pos.Z)
end

return AutoFlip
