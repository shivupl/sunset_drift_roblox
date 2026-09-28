--!strict
-- Every car carries a windscreen strip spot and an exhaust spot, so the
-- garage's DECALS and EXHAUST show on every car (final review fix 5,
-- 2026-09-28). The garage greys those items out on a car without one
-- (CarCosmetics.hasSpot); this keeps a new car from shipping that way.
--
-- And every car's exhaust keeps the one standard (garage round 2 §1,
-- 2026-09-28), so flames work and look right on any car: at least one stock
-- outlet, tips 2-5 cm past the bumper face on a pipe that runs forward, every
-- outlet behind the rear axle, low and pointing back, and one outlet frame per
-- pipe mouth for every exhaust item.
local CarCosmeticMounts = require(script.Parent.Parent.CarCosmeticMounts)
local ConfigLoader = require(script.Parent.Parent.ConfigLoader)
local CosmeticsConfig = require(script.Parent.Parent.CosmeticsConfig)
local Tests = require(script.Parent)
type T = Tests.T

local R = CosmeticsConfig.render

-- Tip mouth past the bumper face: 2-5 cm (the spec), with 1 mm for rounding.
local PAST_MIN, PAST_MAX = 0.019, 0.051

return function(t: T)
	t.ok(R.quadPairGapM >= 2 * R.tipRadiusM, "quad tips of a pair do not overlap")
	t.ok(R.pipeRadiusM < R.boreRadiusM, "a tip's pipe hides inside its bore")
	t.ok(R.quadPairGapM / 2 <= 2 * R.tipRadiusM, "a quad pair sits over the pipe between its tips")

	for id in ConfigLoader.catalog().cars do
		local m = CarCosmeticMounts.cars[id]
		t.ok(m ~= nil, `{id}: has cosmetic spots`)
		local w = if m then m.windscreen else nil
		local e = if m then m.exhaust else nil
		t.ok(w ~= nil, `{id}: has a windscreen strip spot`)
		t.ok(e ~= nil, `{id}: has an exhaust spot`)
		if w then
			t.eq(#w.posM, 3, `{id} windscreen: x, y, z`)
			t.ok(w.posM[3] < 0.5, `{id} windscreen: toward the front`)
			t.ok(w.widthM > 0 and w.heightM > 0, `{id} windscreen: has a size`)
		end
		if not e then
			continue
		end
		local rig = ConfigLoader.entry(id).rig
		local axleZ = rig.wheelbaseM / 2
		-- "Below the boot line": under the top of the rear tyres.
		local lowY = 2 * rig.wheelRadiusM

		t.ok(#e.stock >= 1, `{id} exhaust: at least one stock outlet`)
		for i, o in e.stock do
			t.eq(#o.posM, 3, `{id} stock {i}: x, y, z`)
			t.ok(o.posM[3] >= axleZ, `{id} stock {i}: behind the rear axle`)
			t.ok(o.posM[2] > 0.1 and o.posM[2] < lowY, `{id} stock {i}: low at the rear`)
			if o.dir then
				t.eq(#o.dir, 3, `{id} stock {i}: dir x, y, z`)
			end
		end
		if #e.stock >= 2 then
			t.ok(e.stock[1].posM[1] <= e.stock[2].posM[1], `{id} stock: listed left first`)
		end

		local tips = e.tips
		t.eq(#tips.posM, 3, `{id} tips: x, y, z`)
		t.ok(tips.spreadM > 0, `{id} tips: a spread`)
		t.ok(tips.pipeLengthM > 0, `{id} tips: a pipe running forward`)
		local past = tips.posM[3] - e.bumperZ
		t.ok(past >= PAST_MIN and past <= PAST_MAX, `{id} tips: 2-5 cm past the bumper (got {math.round(past * 1000)} mm)`)
		t.ok(tips.posM[3] >= axleZ, `{id} tips: behind the rear axle`)
		t.ok(tips.posM[2] < lowY, `{id} tips: below the boot line`)
		t.ok(tips.posM[2] - R.tipRadiusM > 0.08, `{id} tips: clear of the ground`)
		t.ok(tips.posM[3] - R.tipLengthM - tips.pipeLengthM > axleZ, `{id} tips: the pipe stops short of the rear axle`)

		-- One outlet per pipe mouth that shows, for every exhaust item, all
		-- pointing back: the tips, plus any of the car's own pipes no tip covers.
		for _, n in { 0, 1, 2, 4 } do
			local frames = CarCosmeticMounts.outletFrames(e, n, R.quadPairGapM, R.tipRadiusM)
			local shown = 0
			for _, o in e.stock do
				if CarCosmeticMounts.stockShows(e, o, n, R.quadPairGapM, R.tipRadiusM) then
					shown += 1
				end
				if n > 0 then
					t.ok(not o.factory or not CarCosmeticMounts.stockShows(e, o, n, R.quadPairGapM, R.tipRadiusM), `{id}: a factory pipe goes when tips go on`)
				end
			end
			t.eq(#frames, n + shown, `{id}: {n} tips give an outlet per showing mouth`)
			for i, f in frames do
				t.ok(f.LookVector.Z > 0.5, `{id} outlet {i} of {n} tips: points out the back`)
				t.ok(f.UpVector.Y > 0.5, `{id} outlet {i} of {n} tips: upright`)
				t.ok(f.Position.Z >= axleZ, `{id} outlet {i} of {n} tips: behind the rear axle`)
				t.ok(f.Position.Y < lowY, `{id} outlet {i} of {n} tips: below the boot line`)
			end
		end
		-- A one-pipe car's own pipe is under a tip for every tip count, so
		-- flames never come out of a pipe hidden inside a tip.
		if #e.stock == 1 and not e.stock[1].factory then
			for _, n in { 1, 2, 4 } do
				t.ok(not CarCosmeticMounts.stockShows(e, e.stock[1], n, R.quadPairGapM, R.tipRadiusM), `{id}: {n} tips sit over its own pipe`)
			end
		end
		-- A single tip goes on stock[1]'s side (over a one-pipe car's own pipe).
		local single = CarCosmeticMounts.tipXs(e, 1, R.quadPairGapM)[1]
		local side = if e.stock[1].posM[1] > 0 then 1 else -1
		t.ok((single - tips.posM[1]) * side > 0, `{id}: a single tip on stock[1]'s side`)
	end
end
