--!strict
-- The garage's interior looks (GarageThemes): every look in the cycle and
-- the main one first; an unknown choice falls back to it; each look's
-- lights stay inside the room and inside the light budget (the view
-- suspends the lamp pool, and a client holds at most
-- WorldConfig.lamps.maxLiveLights = 12 live lights, one of them a dune
-- campfire); each names a studio sky that exists; and its grading is sane.
local GarageThemes = require(script.Parent.Parent.GarageThemes)
local Tests = require(script.Parent)
type T = Tests.T

local MAX_LIGHTS = 10 -- 12, less the campfire, less one spare
local KINDS = { studio = true, gallery = true, workshop = true }
local TYPES = { SpotLight = true, SurfaceLight = true, PointLight = true }

return function(t: T)
	t.eq(GarageThemes.order[1], "studio", "Studio is the main look, first in the cycle")
	local listed: { [string]: boolean } = {}
	for _, id in GarageThemes.order do
		listed[id] = true
		t.ok(GarageThemes.themes[id] ~= nil, `{id} in order is a look`)
	end
	for id in GarageThemes.themes do
		t.ok(listed[id] == true, `{id} is in the cycle order`)
	end
	t.eq(GarageThemes.resolve(nil), "studio", "no choice: Studio")
	t.eq(GarageThemes.resolve("nope"), "studio", "unknown choice: Studio")
	t.eq(GarageThemes.resolve("gallery"), "gallery", "a known choice stays")

	local r = GarageThemes.room
	t.ok(r.backZ < 0 and r.frontZ > 0 and r.leftX < 0 and r.splitX > 0, "the room surrounds the turntable")
	t.ok(r.ceilingY > 4 and r.ceilingY < 6.5, "the dropped ceiling is under the roof (6.5 m eaves)")

	for id, th in GarageThemes.themes do
		t.ok(KINDS[th.kind] == true, `{id}: a known builder ({th.kind})`)
		t.ok(#th.lights >= 3 and #th.lights <= MAX_LIGHTS, `{id}: 3..{MAX_LIGHTS} view lights ({#th.lights})`)
		for i, l in th.lights do
			local p = l.positionM
			t.ok(TYPES[l.type] == true, `{id} light {i}: a known type`)
			t.ok(p.X > r.leftX - 0.01 and p.X < r.splitX + 0.01 and p.Z > r.backZ - 0.01 and p.Z < r.frontZ + 0.01, `{id} light {i}: inside the display bay`)
			t.ok(p.Y > 0 and p.Y < r.ceilingY, `{id} light {i}: between the floor and the ceiling`)
			t.ok(l.brightness > 0 and l.brightness <= 3, `{id} light {i}: brightness in 0..3`)
			t.ok(l.rangeM > 0 and l.rangeM / 0.28 <= 60 + 1e-6, `{id} light {i}: range within the engine's 60 studs`)
		end
		local env = th.env
		t.ok(GarageThemes.skies[env.sky] ~= nil, `{id}: its studio sky ({env.sky}) exists`)
		t.ok(env.bloom.threshold >= 0.8, `{id}: bloom threshold keeps lit paint from glowing`)
		t.ok(math.abs(env.grade.contrast) <= 0.3 and math.abs(env.grade.saturation) <= 0.3, `{id}: a gentle grade`)
		if env.dof then
			t.ok(env.dof.farIntensity >= 0 and env.dof.farIntensity <= 0.4, `{id}: background softened, not smeared`)
			t.ok(env.dof.inFocusRadiusM >= 3, `{id}: the whole car stays in focus`)
		end
		t.ok(th.floorReflect <= th.floorReflectView, `{id}: the floor shines more in the view than to passers-by`)
		t.ok(th.floorReflect <= 0.05, `{id}: outside the view the floor barely mirrors the sunset`)
	end

	for name, box in GarageThemes.skies do
		for _, face in { "side", "up", "down" } do
			local id = (box :: any)[face]
			t.ok(type(id) == "number" and id > 0, `sky {name}: {face} is an asset id`)
		end
		t.ok(string.find(GarageThemes.skyImage(box.side), tostring(box.side), 1, true) ~= nil, `sky {name}: the image link carries the id`)
	end
end
