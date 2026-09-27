--!strict
local CarPlateMounts = require(script.Parent.Parent.CarPlateMounts)
local PlateStyles = require(script.Parent.Parent.PlateStyles)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local function near(v: Vector3, w: Vector3, label: string)
		t.near((v - w).Magnitude, 0, 1e-6, label)
	end
	-- Front plates face forward (-Z), rear plates backward (+Z); a Part's
	-- Front face is its -Z, which is the LookVector.
	local spot: CarPlateMounts.Spot = { posM = { 0.1, 0.5, -2 }, format = "short" }
	local front = CarPlateMounts.cframe(spot, false, 1.2, 0.28)
	near(front.LookVector, Vector3.new(0, 0, -1), "front plate faces forward")
	near(front.Position, Vector3.new(0.1, 0.5, -2) * (1.2 / 0.28), "position is metres times scale over metres per stud")
	local rear = CarPlateMounts.cframe({ posM = { 0, 0.8, 2.5 }, format = "short" }, true, 1, 0.28)
	near(rear.LookVector, Vector3.new(0, 0, 1), "rear plate faces backward")
	-- tiltDeg leans the top in toward the car
	local tiltedRear = CarPlateMounts.cframe({ posM = { 0, 0.8, 2.5 }, format = "short", tiltDeg = 10 }, true, 1, 0.28)
	t.ok(tiltedRear.UpVector.Z < 0, "tilted rear plate's top leans forward, into the car")
	local tiltedFront = CarPlateMounts.cframe({ posM = { 0, 0.5, -2 }, format = "short", tiltDeg = 10 }, false, 1, 0.28)
	t.ok(tiltedFront.UpVector.Z > 0, "tilted front plate's top leans back, into the car")

	-- Every listed spot is sane
	for id, m in CarPlateMounts.cars do
		for _, side in { "front", "rear" } do
			local s = (m :: any)[side] :: CarPlateMounts.Spot?
			if s then
				t.ok((PlateStyles.SIZE_M[s.format] :: Vector2?) ~= nil, `{id} {side}: known format`)
				t.eq(#s.posM, 3, `{id} {side}: x, y, z`)
				t.ok(if side == "front" then s.posM[3] < 0 else s.posM[3] > 0, `{id} {side}: on the right end of the car`)
				t.ok(s.posM[2] > 0.1 and s.posM[2] < 1.6, `{id} {side}: a plausible height`)
			end
		end
		t.ok(m.rear ~= nil, `{id}: has a rear plate`)
	end
end
