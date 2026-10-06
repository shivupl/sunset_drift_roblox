--!strict
-- The garage view's shots, views and sounds (garage-polish, 2026-10-05).
local GarageConfig = require(script.Parent.Parent.GarageConfig)
local VehicleRig = require(script.Parent.Parent.VehicleRig)
local Tests = require(script.Parent)
type T = Tests.T

-- The panel's categories (GaragePanel TABS).
local TABS = { "cars", "paint", "rims", "plates", "lights", "decal", "exhaust" }

return function(t: T)
	local wheels: { [string]: boolean } = {}
	for _, w in VehicleRig.WHEELS do
		wheels[w.name] = true
	end

	-- Every shot's numbers are sane, and its aim can be found.
	t.ok(GarageConfig.shots[GarageConfig.FULL] == nil, "full is not a close shot")
	for key, sh in GarageConfig.shots do
		t.ok(sh.faceDeg >= 0 and sh.faceDeg < 360, `{key}: faceDeg in 0..360`)
		t.ok(sh.distanceM > 0.5 and sh.distanceM < 8, `{key}: distanceM in 0.5..8 (closer than the full framing)`)
		t.ok(sh.eyeHeightM > 0 and sh.eyeHeightM < 4, `{key}: eyeHeightM in 0..4 (under the garage roof)`)
		t.ok(sh.aim == "box" or sh.aim == "hub" or sh.aim == "outlets", `{key}: aim is box, hub or outlets`)
		if sh.aim == "hub" then
			t.ok(sh.hub ~= nil and wheels[sh.hub :: string] == true, `{key}: hub names a wheel`)
		end
		-- Every shot has a box point: the aim, or the fallback for a missing
		-- hub or exhaust.
		local b = sh.box
		t.ok(math.abs(b.x) <= 1 and b.y >= 0 and b.y <= 1 and math.abs(b.z) <= 1, `{key}: box point inside the body's box`)
		if sh.fovDeg then
			t.ok(sh.fovDeg > 10 and sh.fovDeg < 90, `{key}: fovDeg in 10..90`)
		end
	end

	-- Every category has views, each naming a shot, ids unique per category.
	for _, tab in TABS do
		local views: { GarageConfig.View } = GarageConfig.views[tab] or {}
		t.ok(#views >= 1, `{tab} has views`)
		local seen: { [string]: boolean } = {}
		for _, v in views do
			t.ok(v.shot == GarageConfig.FULL or GarageConfig.shots[v.shot] ~= nil, `{tab}/{v.id}: shot {v.shot} exists`)
			t.ok(not seen[v.id], `{tab}/{v.id}: id unique`)
			seen[v.id] = true
			if #views > 1 then
				t.ok(#v.label > 0, `{tab}/{v.id}: a sub-tab has a label`)
			end
		end
	end
	-- The exhaust views share the exhaust shot, so a flame's burst plays
	-- where the tips are framed.
	for _, v in GarageConfig.views.exhaust do
		t.eq(v.shot, "exhaust", `exhaust/{v.id} frames the exhaust`)
	end

	-- Sounds: an asset id and a volume in 0..1 each.
	for _, kind in { "tab", "tap", "fit", "buy", "error" } do
		local def = GarageConfig.sounds[kind]
		t.ok(def ~= nil, `sound {kind} exists`)
		if def then
			t.ok(string.match(def.id, "^rbxassetid://%d+$") ~= nil, `sound {kind} is an asset id`)
			t.ok(def.volume >= 0 and def.volume <= 1, `sound {kind} volume in 0..1`)
		end
	end

	-- Motion: a press shrinks, a pop grows, the cash counts in under a second.
	local feel = GarageConfig.feel
	t.ok(feel.pressScale > 0.8 and feel.pressScale < 1, "pressScale shrinks a little")
	t.ok(feel.popScale > 1 and feel.popScale < 1.2, "popScale grows a little")
	t.ok(feel.cashCountSeconds > 0 and feel.cashCountSeconds <= 1, "cash counts in under a second")
	t.ok(GarageConfig.headFlash.blinks >= 1, "the headlights blink at least once")
end
