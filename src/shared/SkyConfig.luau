--!strict
-- The times of day a player can pick in the menu's Settings tab. The choice
-- is only how the world looks on that player's screen: the client sets these
-- Lighting fields over what the world build set, and the server keeps the
-- choice in the player's profile.
--
-- Asked by the owner on 2026-09-28, after trying values live in Play: "i
-- like 2 times/settings ... is there a way i can let users choose". Both
-- are the golden-hour preset (WorldConfig.timesOfDay.goldenHour: the painted
-- sunset skybox, the same haze and ambient) with the hour, the sun's
-- brightness and the exposure changed, at the values the owner picked live
-- (hour and exposure first; brightness added and all three retuned the same
-- day with the SkyFree switch).
--
-- To add an option, add a row: it shows up as a button in the menu.
export type Option = {
	id: string, -- stored in the profile; never rename one players may have saved
	label: string, -- the button text
	clockTime: number, -- Lighting.ClockTime. Lower is more daytime; 0.05 is a visible step
	brightness: number, -- Lighting.Brightness: the sun's strength
	exposureCompensation: number, -- Lighting.ExposureCompensation; +-0.1 is a small step
}

local SkyConfig = {
	-- What a new player sees, and what an unknown stored id falls back to.
	-- Keep WorldConfig's goldenHour clockTime, brightness and exposure equal to this
	-- option, so the world does not change as a player's client starts.
	default = "sunset",
	options = {
		-- Sun about 3.5 degrees up: the sunset band in the windscreen, long
		-- shadows across the road.
		-- Retuned 2026-09-28 from brightness 2.2, exposure -0.12.
		{ id = "sunset", label = "Sunset", clockTime = 17.68, brightness = 1.36, exposureCompensation = -0.3 },
		-- Sun just below the horizon, the sun's light turned well down, the
		-- exposure raised so the road still reads between the lamps.
		-- Retuned 2026-09-28 from 19.2, brightness 2.2, exposure 0.14.
		{ id = "night", label = "Night", clockTime = 18.9, brightness = 0.5, exposureCompensation = 0.1 },
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
