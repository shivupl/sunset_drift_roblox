--!strict
local UITheme = require(script.Parent.Parent.UITheme)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local c = UITheme.color
	-- Every text-on-surface pairing UI_SYSTEM.md allows, held to WCAG AA:
	-- 4.5:1 for text. Disabled text is exempt (WCAG), so it is not here.
	local checks: { { name: string, fg: Color3, bg: Color3 } } = {
		{ name = "paint on asphalt900", fg = c.paint, bg = c.asphalt900 },
		{ name = "paint on asphalt800", fg = c.paint, bg = c.asphalt800 },
		{ name = "paint on asphalt700", fg = c.paint, bg = c.asphalt700 },
		{ name = "sand on asphalt900", fg = c.sand, bg = c.asphalt900 },
		{ name = "sand on asphalt800", fg = c.sand, bg = c.asphalt800 },
		{ name = "sand on asphalt700", fg = c.sand, bg = c.asphalt700 },
		{ name = "sandDim on asphalt900", fg = c.sandDim, bg = c.asphalt900 },
		{ name = "sandDim on asphalt800", fg = c.sandDim, bg = c.asphalt800 },
		{ name = "asphalt900 on sodium", fg = c.asphalt900, bg = c.sodium },
		{ name = "asphalt900 on sodiumDeep", fg = c.asphalt900, bg = c.sodiumDeep },
		{ name = "paint on sodiumDim", fg = c.paint, bg = c.sodiumDim },
		{ name = "sodium on sodiumDim", fg = c.sodium, bg = c.sodiumDim },
		{ name = "sodium on asphalt900", fg = c.sodium, bg = c.asphalt900 },
		{ name = "sodium on asphalt800", fg = c.sodium, bg = c.asphalt800 },
		{ name = "gantryBright on asphalt900", fg = c.gantryBright, bg = c.asphalt900 },
		{ name = "gantryBright on asphalt800", fg = c.gantryBright, bg = c.asphalt800 },
		{ name = "paint on gantry", fg = c.paint, bg = c.gantry },
		{ name = "asphalt900 on beacon", fg = c.asphalt900, bg = c.beacon },
		{ name = "beacon on asphalt900", fg = c.beacon, bg = c.asphalt900 },
		{ name = "paint on beaconDim", fg = c.paint, bg = c.beaconDim },
		{ name = "dusk on asphalt900", fg = c.dusk, bg = c.asphalt900 },
		{ name = "dusk on duskDim", fg = c.dusk, bg = c.duskDim },
	}
	for _, p in checks do
		t.ok(UITheme.contrast(p.fg, p.bg) >= 4.5, `{p.name} is at least 4.5:1`)
	end
	-- Every button state except disabled reads.
	for name, s in UITheme.button do
		if name ~= "disabled" then
			t.ok(UITheme.contrast(s.text, s.bg) >= 4.5, `button {name} text reads`)
		end
	end
	t.near(UITheme.contrast(Color3.new(1, 1, 1), Color3.new(0, 0, 0)), 21, 1e-6, "white on black is 21:1")
	t.eq(UITheme.px(16, false), 16, "desktop sizes are unscaled")
	t.eq(UITheme.px(16, true), 20, "touch sizes scale by 1.25")
	t.ok(UITheme.target(true) >= 44, "a thumb target is at least 44 px")
	for role, spec in UITheme.type do
		t.ok(spec.size >= 12, `{role} is at least 12 px`)
	end
end
