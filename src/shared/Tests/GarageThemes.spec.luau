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
local KINDS = { cozy = true, studio = true, gallery = true, workshop = true }
local TYPES = { SpotLight = true, SurfaceLight = true, PointLight = true }

return function(t: T)
	t.eq(GarageThemes.order[1], "tungsten", "Tungsten is the main look, first in the cycle")
	-- The owner found the first Tungsten too dark (2026-11-09): the main one
	-- is brighter than the kept first cut, and lights the car's flank.
	local main, low = GarageThemes.themes.tungsten, GarageThemes.themes.tungstenLow
	local function sum(c: Color3): number
		return c.R + c.G + c.B
	end
	t.ok(sum(main.env.ambient) > sum(low.env.ambient), "Tungsten's room is brighter than Tungsten Low's")
	t.ok(main.shopLights ~= nil and #main.shopLights >= 1, "Tungsten has a shop light on the car")
	local listed: { [string]: boolean } = {}
	for _, id in GarageThemes.order do
		listed[id] = true
		t.ok(GarageThemes.themes[id] ~= nil, `{id} in order is a look`)
	end
	for id in GarageThemes.themes do
		t.ok(listed[id] == true, `{id} is in the cycle order`)
	end
	t.eq(GarageThemes.resolve(nil), "tungsten", "no choice: Tungsten")
	t.eq(GarageThemes.resolve("nope"), "tungsten", "unknown choice: Tungsten")
	t.eq(GarageThemes.resolve("gallery"), "gallery", "a known choice stays")

	local r = GarageThemes.room
	t.ok(r.backZ < 0 and r.frontZ > 0 and r.leftX < 0 and r.splitX > 0, "the room surrounds the turntable")
	t.ok(r.ceilingY > 4 and r.ceilingY < 6.5, "the dropped ceiling is under the roof (6.5 m eaves)")

	for id, th in GarageThemes.themes do
		t.ok(KINDS[th.kind] == true, `{id}: a known builder ({th.kind})`)
		-- A lit pendant adds its SpotLight (GarageInterior.lights).
		local lit = 0
		for i, pd in th.pendants or ({} :: { GarageThemes.Pendant }) do
			local p = pd.positionM
			if pd.brightness > 0 then
				lit += 1
			end
			t.ok(p.Y > 2.4 and p.Y < r.ceilingY, `{id} pendant {i}: hung above head height, under the roof`)
			t.ok(math.abs(p.X) < 3 and math.abs(p.Z) < 3, `{id} pendant {i}: over the turntable`)
			t.ok(pd.brightness >= 0 and pd.brightness <= 2, `{id} pendant {i}: brightness in 0..2`)
		end
		for i, sl in th.shopLights or ({} :: { GarageThemes.ShopLight }) do
			local p = sl.positionM
			if sl.brightness > 0 then
				lit += 1
			end
			t.ok(p.Y > 2.4 and p.Y < r.ceilingY, `{id} shop light {i}: hung above head height, under the roof`)
			t.ok(p.X - sl.lengthM / 2 > r.leftX and p.X + sl.lengthM / 2 < r.splitX and p.Z > r.backZ and p.Z < r.frontZ, `{id} shop light {i}: inside the display bay`)
			t.ok(sl.brightness >= 0 and sl.brightness <= 2, `{id} shop light {i}: brightness in 0..2`)
			t.ok(sl.aimM.Y < p.Y, `{id} shop light {i}: shines down`)
		end
		local wl = th.wallLamp
		if wl and wl.brightness > 0 then
			lit += 1
		end
		local total = #th.lights + lit
		t.ok(total >= 3 and total <= MAX_LIGHTS, `{id}: 3..{MAX_LIGHTS} view lights ({total})`)
		for i, sg in th.signs or ({} :: { GarageThemes.Sign }) do
			t.ok(sg.positionM.Z < r.backZ + 0.2, `{id} sign {i}: on the back wall`)
			t.ok(sg.neon or sg.background ~= nil, `{id} sign {i}: a tin sign has a background`)
		end
		if th.bakedGlowView then
			t.ok(th.bakedGlowView >= 0 and th.bakedGlowView <= 1, `{id}: bakedGlowView in 0..1`)
		end
		for i, l in th.lights do
			local p = l.positionM
			t.ok(TYPES[l.type] == true, `{id} light {i}: a known type`)
			-- In the building: the display bay, or the lift bay beyond the
			-- columns (its far wall is 19.16 m over).
			t.ok(p.X > r.leftX - 0.01 and p.X < 19.1 and p.Z > r.backZ - 0.01 and p.Z < r.frontZ + 0.01, `{id} light {i}: inside the building`)
			t.ok(p.Y > 0 and p.Y < r.ceilingY, `{id} light {i}: between the floor and the ceiling`)
			t.ok(l.brightness > 0 and l.brightness <= 3, `{id} light {i}: brightness in 0..3`)
			t.ok(l.rangeM > 0 and l.rangeM / 0.28 <= 60 + 1e-6, `{id} light {i}: range within the engine's 60 studs`)
		end
		local env = th.env
		t.ok(GarageThemes.skies[env.sky] ~= nil, `{id}: its studio sky ({env.sky}) exists`)
		t.ok(env.bloom.threshold >= 0.8, `{id}: bloom threshold keeps lit paint from glowing`)
		if th.kind == "cozy" then
			-- The owner found the first garage look "so bright/glowy": in the
			-- cozy looks only the bulbs and neon may bloom.
			t.ok(env.bloom.threshold >= 1.3, `{id}: cozy, so only bulbs and neon bloom ({env.bloom.threshold})`)
			-- 1.2: the owner found Tungsten Low (0.64) "too dark"; Tungsten
			-- is 0.87, Tungsten Bright 1.08. Past this the unlit faces flatten the lamps' pools.
			t.ok(env.ambient.R + env.ambient.G + env.ambient.B < 1.2, `{id}: cozy, a dim room`)
			local ring: Color3? = th.colors.ring
			t.ok(ring == nil, `{id}: cozy, no glowing ring round the turntable`)
		end
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
