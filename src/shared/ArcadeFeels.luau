--!strict
-- Side variants of the arcade drive (CarConfig.arcade), for comparing feel by
-- driving: the owner decides by driving, not from a description, so the main
-- tune ships with a few others beside it (keep-design-variations). Studio's I
-- cycles them (client DriftStyle); the LocalPlayer attribute ArcadeFeel names
-- one. Each is a partial config merged over the car's styled config. Once the
-- owner picks, the rest go.
local ArcadeFeels = {}

export type Feel = {
	name: string,
	blurb: string,
	over: { [string]: any },
}

ArcadeFeels.feels = {
	main = {
		name = "Main",
		blurb = "The tune in CarConfig.arcade",
		over = {},
	},
	-- Bigger angles that settle slower and run straighter: the long
	-- one-sided hajwala slide.
	wide = {
		name = "Wide",
		blurb = "Bigger, floatier slides",
		over = { arcade = { driftAngleDeg = 70, angleResponseSeconds = 0.55, driftG = 0.22, handbrakeSpinDegPerSec = 170 } },
	},
	-- Smaller angles that come quicker and let go sooner: twitchy and
	-- precise.
	snappy = {
		name = "Snappy",
		blurb = "Quick, tight slides",
		over = { arcade = { driftAngleDeg = 45, angleResponseSeconds = 0.25, driftYawResponseSeconds = 0.14, gripReturnSeconds = 0.25 } },
	},
	-- The tyre model with its assists, as it was before the arcade drive.
	classic = {
		name = "Old tyres",
		blurb = "The drive before the arcade one",
		over = { arcade = { enabled = false } },
	},
} :: { [string]: Feel }

ArcadeFeels.order = { "main", "wide", "snappy", "classic" }

function ArcadeFeels.resolve(id: any): string
	if type(id) == "string" and ArcadeFeels.feels[id] then
		return id
	end
	return "main"
end

return ArcadeFeels
