--!strict
-- Every car carries a windscreen strip spot and an exhaust spot, so the
-- garage's DECALS and EXHAUST show on every car (final review fix 5,
-- 2026-09-28). The garage greys those items out on a car without one
-- (CarCosmetics.hasSpot); this keeps a new car from shipping that way.
local CarCosmeticMounts = require(script.Parent.Parent.CarCosmeticMounts)
local ConfigLoader = require(script.Parent.Parent.ConfigLoader)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
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
		if e then
			t.eq(#e.posM, 3, `{id} exhaust: x, y, z`)
			t.ok(e.posM[3] > 0, `{id} exhaust: at the rear`)
			t.ok(e.spreadM > 0, `{id} exhaust: a spread`)
		end
	end
end
