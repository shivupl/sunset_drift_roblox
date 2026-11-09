--!strict
-- CarDashes names real cars with cabins, and its dials sit on the driver's
-- side of the dash in front of the steering wheel: a stale car id or a dial
-- placed off in the cabin would draw nothing anyone sees, with nothing to
-- say so. The needle readings must stay on their dials.
local CarDashes = require(script.Parent.Parent.CarDashes)
local CarCockpits = require(script.Parent.Parent.CarCockpits)
local ConfigLoader = require(script.Parent.Parent.ConfigLoader)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local cars = ConfigLoader.catalog().cars
	for id, dash in CarDashes.cars do
		t.ok(cars[id] ~= nil, `{id} is a catalog car`)
		local cockpit = CarCockpits.of(id)
		local wheel = cockpit and cockpit.wheel
		t.ok(wheel ~= nil, `{id} has a first-person cockpit to see its gauges from`)
		local reads = {}
		for _, d in dash.dials do
			reads[d.reads] = true
			t.eq(#d.posM, 3, `{id} {d.name}: posM is x, y, z`)
			t.ok(d.sizeM[1] > 0 and d.sizeM[2] > 0 and d.sizeM[3] > 0, `{id} {d.name}: a real size`)
			t.ok(d.degPerUnit > 0 and d.maxDeg > d.zeroDeg, `{id} {d.name}: the needle sweeps up the dial`)
			t.ok(d.maxDeg - d.zeroDeg <= 300, `{id} {d.name}: the sweep fits on a dial ({d.maxDeg - d.zeroDeg} deg)`)
			t.ok((d.needle.startPx or 0) < d.needle.lengthPx, `{id} {d.name}: the needle has length`)
			t.eq(CarDashes.needleDeg(d, 0), d.zeroDeg, `{id} {d.name}: at rest it reads zero`)
			t.eq(CarDashes.needleDeg(d, 1e6), d.maxDeg, `{id} {d.name}: it stops at the end of the dial`)
			t.eq(CarDashes.needleDeg(d, -5), d.zeroDeg, `{id} {d.name}: no reading below zero`)
			if wheel then
				local p = wheel.pivotM
				local ahead = p[3] - d.posM[3]
				t.ok(ahead > 0.05 and ahead < 0.5, `{id} {d.name}: the dial is ahead of the wheel ({ahead} m)`)
				t.ok(math.abs(d.posM[1] - p[1]) < 0.2, `{id} {d.name}: the dial is in front of the driver`)
				t.ok(math.abs(d.posM[2] - p[2]) < 0.15, `{id} {d.name}: the dial is at the wheel's height`)
			end
		end
		t.ok(reads.speedMph and reads.rpm, `{id}: a speedometer and a tachometer`)
	end
end
