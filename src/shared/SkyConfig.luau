--!strict
-- The times of day a player can pick in the menu's Settings tab. The choice
-- is only how the world looks on that player's screen: the client sets these
-- Lighting fields over what the world build set, and the server keeps the
-- choice in the player's profile.
--
-- Asked by the owner on 2026-09-28, after trying values live in Play: "i
-- like 2 times/settings ... is there a way i can let users choose". Both
-- are the golden-hour preset (WorldConfig.timesOfDay.goldenHour: brightness
-- 2.2, the painted sunset skybox, the same haze and ambient) with only the
-- hour and the exposure changed, at the values the owner picked.
--
-- To add an option, add a row: it shows up as a button in the menu.
export type Option = {
	id: string, -- stored in the profile; never rename one players may have saved
	label: string, -- the button text
	clockTime: number, -- Lighting.ClockTime. Lower is more daytime; 0.05 is a visible step
	exposureCompensation: number, -- Lighting.ExposureCompensation; +-0.1 is a small step
}

local SkyConfig = {
	-- What a new player sees, and what an unknown stored id falls back to.
	-- Keep WorldConfig's goldenHour clockTime and exposure equal to this
	-- option, so the world does not change as a player's client starts.
	default = "sunset",
	options = {
		-- Sun about 3.5 degrees up: the sunset band in the windscreen, long
		-- shadows across the road.
		{ id = "sunset", label = "Sunset", clockTime = 17.68, exposureCompensation = -0.12 },
		-- Sun below the horizon. The exposure is raised so the road still
		-- reads between the lamps; headlights carry the rest.
		{ id = "night", label = "Night", clockTime = 19.2, exposureCompensation = 0.14 },
	} :: { Option },
}

-- The option with this id, or nil.
function SkyConfig.find(id: string?): Option?
	for _, o in SkyConfig.options do
		if o.id == id then
			return o
		end
	end
	return nil
end

-- The option with this id, or the default one.
function SkyConfig.resolve(id: string?): Option
	return SkyConfig.find(id) or SkyConfig.find(SkyConfig.default) or SkyConfig.options[1]
end

return SkyConfig
