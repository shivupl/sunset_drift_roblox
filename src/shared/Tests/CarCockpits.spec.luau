--!strict
-- CarCockpits names real cars and real body pieces, and its numbers sit
-- where a steering wheel and a driver's eyes can be: a typo or a stale piece
-- name would leave a wheel that never turns, with nothing to say so.
local CarCockpits = require(script.Parent.Parent.CarCockpits)
local ConfigLoader = require(script.Parent.Parent.ConfigLoader)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local cars = ConfigLoader.catalog().cars
	for id, c in CarCockpits.cars do
		t.ok(cars[id] ~= nil, `{id} is a catalog car`)
		if not cars[id] then
			continue
		end
		local entry = ConfigLoader.entry(id)
		t.eq(#c.eyeM, 3, `{id}: eyeM is x, y, z`)
		t.ok(c.eyeM[2] > 0.8 and c.eyeM[2] < 2.2, `{id}: eye height {c.eyeM[2]} m is a seated driver's`)
		t.ok(c.eyeM[1] < 0, `{id}: the driver sits on the left`)
		local wheel = c.wheel
		if not wheel then
			continue
		end
		local a = Vector3.new(wheel.axis[1], wheel.axis[2], wheel.axis[3])
		t.near(a.Magnitude, 1, 0.01, `{id}: the column axis is a unit vector`)
		local tilt = math.deg(math.asin(a.Y))
		t.ok(a.Z > 0 and tilt > 10 and tilt < 40, `{id}: the column leans back toward the driver ({tilt} deg)`)
		t.ok(c.eyeM[3] > wheel.pivotM[3], `{id}: the eye is behind the wheel`)
		t.ok(wheel.radiusM > 0.1 and wheel.radiusM < 0.25, `{id}: the rim radius {wheel.radiusM} m is a steering wheel's`)
		local byName = {}
		for _, piece in entry.body.pieces do
			byName[piece.name] = piece
		end
		local lo = Vector3.one * math.huge
		local hi = -lo
		for _, name in wheel.pieces do
			local piece = byName[name]
			t.ok(piece ~= nil, `{id}: wheel piece {name} is a body piece`)
			if piece then
				local o = Vector3.new(piece.offsetM[1], piece.offsetM[2], piece.offsetM[3])
				local h = Vector3.new(piece.sizeM[1], piece.sizeM[2], piece.sizeM[3]) / 2
				lo, hi = lo:Min(o - h), hi:Max(o + h)
			end
		end
		local p = Vector3.new(wheel.pivotM[1], wheel.pivotM[2], wheel.pivotM[3])
		local inside = p.X >= lo.X - 0.01 and p.X <= hi.X + 0.01 and p.Y >= lo.Y - 0.01 and p.Y <= hi.Y + 0.01 and p.Z >= lo.Z - 0.01 and p.Z <= hi.Z + 0.01
		t.ok(inside, `{id}: the pivot is inside the wheel pieces' box`)
	end
	-- The view and the wheel turns the client reads.
	local camera = ConfigLoader.current().camera
	local fp = 0
	for _, v in camera.views do
		if v.firstPerson then
			fp += 1
		end
	end
	t.eq(fp, 1, "one first-person view")
	t.ok(not camera.views[1].firstPerson, "the first view, the fallback for cars with no cabin, is a chase view")
	t.ok(#camera.firstPerson.wheelTurns >= 1, "at least one wheel turn")
	for _, turn in camera.firstPerson.wheelTurns do
		t.ok(turn.deg > 0, `wheel turn {turn.id} turns`)
	end
end
