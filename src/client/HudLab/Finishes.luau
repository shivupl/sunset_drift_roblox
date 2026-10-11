--!strict
-- The HUD's finishes: one design (layout D, STREET's machined parts) in
-- three materials, cycled with the STYLE button, U, or the HUD STYLE row
-- in Settings (the owner, 2026-10-10: "make a couple variants of the same
-- deisgn i can cycle through"). The art is art/hud/streetd/make.py.
--
--   STREET D  black anodised, a polished ring, brushed aluminium pedals;
--             red, the HUD as the owner picked it.
--   SODIUM    the game's own look (UI_SYSTEM.md: "the highway at golden
--             hour, seen from a dark cabin"): warm asphalt anodised, a
--             sand-gold ring, champagne pedals, lane-paint print, and its
--             one accent, the sodium lamp's amber, for what is lit.
--   CARBON    clear-coated carbon fibre, red anodised knurls, carbon pedals
--             with red rubber.
local Art = require(script.Parent:WaitForChild("Art"))

export type Finish = {
	id: string,
	name: string,
	art: Art.FinishArt,
	print: Color3, -- the icons, the speed and the cash
	accent: Color3, -- what is lit: a held button, the side you are up on, the edge glow
	label: Color3, -- CASH, BEST, km/h
	points: Color3, -- the live slide score
	mult: Color3, -- its multiplier
	info: Color3, -- ANGLE under the score
	barOff: Color3, -- an unlit angle segment
	banked: Color3,
	dropped: Color3,
}

local list: { Finish } = {
	{
		id = "streetd",
		name = "STREET D",
		art = Art.streetd,
		print = Color3.fromRGB(251, 250, 246),
		accent = Color3.fromRGB(255, 50, 32),
		label = Color3.fromRGB(170, 170, 176),
		points = Color3.fromRGB(255, 50, 32),
		mult = Color3.fromRGB(255, 176, 0),
		info = Color3.fromRGB(255, 50, 32),
		barOff = Color3.fromRGB(70, 20, 16),
		banked = Color3.fromRGB(80, 230, 120),
		dropped = Color3.fromRGB(255, 50, 32),
	},
	{
		-- UITheme's tokens: paint, sodium, sand, sodiumDim, gantryBright, beacon.
		id = "sodium",
		name = "SODIUM",
		art = Art.sodium,
		print = Color3.fromRGB(232, 226, 205),
		accent = Color3.fromRGB(255, 186, 92),
		label = Color3.fromRGB(198, 172, 132),
		points = Color3.fromRGB(232, 226, 205),
		mult = Color3.fromRGB(255, 186, 92),
		info = Color3.fromRGB(198, 172, 132),
		barOff = Color3.fromRGB(74, 52, 24),
		banked = Color3.fromRGB(92, 203, 138),
		dropped = Color3.fromRGB(240, 83, 63),
	},
	{
		id = "carbon",
		name = "CARBON",
		art = Art.carbon,
		print = Color3.fromRGB(244, 242, 236),
		accent = Color3.fromRGB(255, 42, 31),
		label = Color3.fromRGB(170, 170, 176),
		points = Color3.fromRGB(251, 250, 246),
		mult = Color3.fromRGB(255, 42, 31),
		info = Color3.fromRGB(170, 170, 176),
		barOff = Color3.fromRGB(70, 20, 16),
		banked = Color3.fromRGB(80, 230, 120),
		dropped = Color3.fromRGB(255, 42, 31),
	},
}

local byId: { [string]: Finish } = {}
for _, f in list do
	byId[f.id] = f
end

return {
	list = list,
	byId = byId,
}
