--!strict
local AutoFlip = require(script.Parent.Parent.AutoFlip)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local up = CFrame.new(0, 2, 0)
	local side = up * CFrame.Angles(0, 0, math.rad(90)) -- rolled onto its side
	local roof = up * CFrame.Angles(0, 0, math.rad(180)) -- on its roof
	t.near(AutoFlip.tiltDeg(up), 0, 1e-3, "upright tilts 0")
	t.near(AutoFlip.tiltDeg(side), 90, 1e-3, "on its side tilts 90")
	t.near(AutoFlip.tiltDeg(roof), 180, 1e-3, "on its roof tilts 180")

	-- The heading survives: a car yawed 30 degrees and rolled onto its side
	-- comes upright still facing 30 degrees.
	local yawed = CFrame.Angles(0, math.rad(30), 0)
	local lying = yawed * CFrame.Angles(0, 0, math.rad(95))
	local target = AutoFlip.upright(lying, Vector3.new(5, 1, 5))
	t.near(target.UpVector.Y, 1, 1e-6, "the target is upright")
	t.near(target.LookVector:Dot(yawed.LookVector), 1, 1e-6, "the target keeps the heading")
	t.near((target.Position - Vector3.new(5, 1, 5)).Magnitude, 0, 1e-6, "the target is where it was asked")
	-- From its side that is a roll about the long axis: a quarter turn.
	t.near(AutoFlip.turnDeg(lying, target), 95, 1e-3, "off its side it rolls 95 degrees")

	-- Off its roof it rolls half round, about its long axis (the nose stays
	-- pointing the same way).
	local roofTarget = AutoFlip.upright(roof, Vector3.new(0, 1, 0))
	t.near(AutoFlip.turnDeg(roof, roofTarget), 180, 1e-3, "off its roof it rolls 180 degrees")
	t.near(roofTarget.LookVector:Dot(roof.LookVector), 1, 1e-6, "off its roof the nose keeps its direction")

	-- Standing on its nose: no flat nose direction, so it still gets an
	-- upright frame (heading from its roof).
	local nose = CFrame.Angles(math.rad(-90), 0, 0)
	local noseTarget = AutoFlip.upright(nose, Vector3.zero)
	t.near(noseTarget.UpVector.Y, 1, 1e-6, "a car on its nose still gets an upright frame")

	-- Roll about the long axis, as seen from behind (CFrames are single
	-- precision: angles to 1e-4 degrees) --------------------------------------
	t.near(AutoFlip.rollDeg(up), 0, 1e-4, "upright: no roll")
	-- CFrame.Angles(0, 0, +90) turns the roof to the car's left (-X): lying
	-- on its left side.
	local leftSide = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90))
	local rightSide = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(-90))
	t.near(AutoFlip.rollDeg(leftSide), -90, 1e-4, "on its left side: -90")
	t.near(AutoFlip.rollDeg(rightSide), 90, 1e-4, "on its right side: +90")
	t.near(math.abs(AutoFlip.rollDeg(roof)), 180, 1e-4, "on its roof: 180")
	t.near(AutoFlip.rollDeg(yawed * CFrame.Angles(0, 0, math.rad(90))), -90, 1e-4, "the heading doesn't change it")
	t.eq(AutoFlip.rollDeg(nose), 0, "on its nose: no roll")
	t.eq(AutoFlip.rightingDir(leftSide), 1, "left side down: roll it clockwise (steer right)")
	t.eq(AutoFlip.rightingDir(rightSide), -1, "right side down: the other way (steer left)")
	-- Steering right (a turn along +LookVector) takes the left-side car toward
	-- upright, and the right-side one away from it.
	local nudge = CFrame.fromAxisAngle(leftSide.LookVector, math.rad(10))
	t.ok(math.abs(AutoFlip.rollDeg(nudge * leftSide)) < 90, "steer right lifts a car off its left side")
	t.ok(math.abs(AutoFlip.rollDeg(nudge * rightSide)) > 90, "and pushes one on its right side into the ground")
	-- The driver's steer: on its side either way rolls it up the short way;
	-- on its roof the steer picks the side.
	t.eq(AutoFlip.steerDir(leftSide, 1, 135), 1, "left side, steer right: clockwise, up")
	t.eq(AutoFlip.steerDir(leftSide, -1, 135), 1, "left side, steer left: still up the short way")
	t.eq(AutoFlip.steerDir(rightSide, 1, 135), -1, "right side, steer right: up the short way")
	t.near(AutoFlip.steerDir(rightSide, -0.5, 135), -0.5, 1e-9, "half a steer, half the push")
	t.eq(AutoFlip.steerDir(roof, 1, 135), 1, "on its roof, steer right goes over clockwise")
	t.eq(AutoFlip.steerDir(roof, -1, 135), -1, "and steer left the other way")

	-- The roll torque: full while it is stopped, easing off near the target
	-- rate, braking past it, never over the cap.
	t.eq(AutoFlip.rollTorque(700, 0, 2.4, 20, 25000), 25000, "from rest it pushes as hard as it may")
	t.ok(AutoFlip.rollTorque(700, 2.3, 2.4, 20, 25000) < 2000, "near the roll rate it eases off")
	t.ok(AutoFlip.rollTorque(700, 3, 2.4, 20, 25000) < 0, "past it, it brakes")
	t.eq(AutoFlip.rollTorque(700, 0, -2.4, 20, 25000), -25000, "the other way the same")

	-- The ease starts and ends at rest.
	t.near(AutoFlip.ease(0), 0, 1e-9, "ease 0")
	t.near(AutoFlip.ease(1), 1, 1e-9, "ease 1")
	t.near(AutoFlip.ease(0.5), 0.5, 1e-9, "ease is symmetric")

	-- A flip off its side: a car 2 wide, 1.4 tall to its roof and 0.6 from
	-- its centre down to its wheels (studs), lying on its side on ground at
	-- y = 0. It must never dig into the ground on the way, and must land with
	-- its wheels on the ground, upright, where it was.
	local points = AutoFlip.boxPoints(Vector3.new(-1, -0.6, -2.5), Vector3.new(1, 0.8, 2.5))
	local start = CFrame.new(3, 1, 4) * CFrame.Angles(0, 0, math.rad(90)) -- resting on its right side
	local fl: AutoFlip.Flip = {
		start = start,
		target = AutoFlip.upright(start, Vector3.new(3, 0.6, 4)),
		seconds = 0.75,
		points = points,
		groundY = 0,
		clearance = 0.1,
	}
	local deepest = math.huge
	local rose = false
	for i = 0, 50 do
		local cf = AutoFlip.frameAt(fl, i / 50)
		deepest = math.min(deepest, cf.Position.Y + AutoFlip.lowestY(cf.Rotation, points))
		if cf.Position.Y > 1.05 then
			rose = true -- it lifts over its edge rather than sliding round its centre
		end
	end
	t.ok(deepest >= -1e-6, `never below the ground (lowest corner {deepest})`)
	t.ok(rose, "it pivots up over its edge on the way")
	-- A real car's widest point (the mirrors, up high) and lowest (the
	-- tyres, set in) are not one corner: rolling over its real outline lifts
	-- it less than rolling over the box round it.
	local shape = {
		Vector3.new(-1.2, 0.3, -1), Vector3.new(1.2, 0.3, -1), -- mirrors
		Vector3.new(-0.9, -0.6, -2), Vector3.new(0.9, -0.6, -2), -- tyre bottoms
		Vector3.new(-0.9, -0.6, 2), Vector3.new(0.9, -0.6, 2),
		Vector3.new(-0.8, 0.8, 0), Vector3.new(0.8, 0.8, 0), -- roof
	}
	local function peak(pts: { Vector3 }): number
		local f2: AutoFlip.Flip = {
			start = start,
			target = AutoFlip.upright(start, Vector3.new(3, 0.6, 4)),
			seconds = 0.75,
			points = pts,
			groundY = start.Y + AutoFlip.lowestY(start.Rotation, pts),
			clearance = 0,
		}
		local top = -math.huge
		for i = 0, 50 do
			top = math.max(top, AutoFlip.frameAt(f2, i / 50).Y)
		end
		return top - f2.groundY
	end
	t.ok(peak(shape) < peak(AutoFlip.boxPoints(Vector3.new(-1.2, -0.6, -2), Vector3.new(1.2, 0.8, 2))), "it pivots on its real edge, lower than its box")

	local landed = AutoFlip.frameAt(fl, 1)
	t.near(landed.UpVector.Y, 1, 1e-6, "lands upright")
	t.near(landed.Position.Y, 0.6, 1e-6, "lands with its wheels on the ground")
	t.near(landed.Position.X, 3, 1e-6, "lands where it lay (x)")
	t.near(landed.Position.Z, 4, 1e-6, "lands where it lay (z)")
	local begun = AutoFlip.frameAt(fl, 0)
	t.near((begun.Position - start.Position).Magnitude, 0, 1e-6, "starts where it lies")
end
