--!strict
-- The maths of the auto-flip (client AutoFlip): when the car the player is
-- driving has capsized (on its side or roof) and come to rest, it rolls back
-- onto its wheels on its own. Asked by the owner on 2026-10-04: "an autoflip
-- feature that seamlessly/naturally flips the car back over if it capsizes".
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
