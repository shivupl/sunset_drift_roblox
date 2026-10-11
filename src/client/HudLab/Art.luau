--!strict
-- The HUD's image art, rendered by art/hud/streetd/make.py (the gear digits
-- by art/hud/street/make.py) and uploaded from Studio; each id here is the
-- upload of art/hud/out/<file>.png. Re-render and re-upload to change one.
--
-- Every round button is its finish's `base` with an icon from `icons` over
-- it, tinted, and `halo` over that when it is lit; so a finish is seven
-- images however many buttons there are.
export type FinishArt = {
	base: string, -- 256, a knurled round button without its icon
	tachoFace: string, -- 512, -135..135 deg for 0..9000 r/min
	tachoNeedle: string, -- 512
	pill: string, -- 300x120, 9-slice
	board: string, -- 660x170
	pedalGas: string, -- 400x1000
	pedalBrake: string, -- 640x404
}

local streetd: FinishArt = {
	base = "rbxassetid://80035479601810",
	tachoFace = "rbxassetid://128320814498203",
	tachoNeedle = "rbxassetid://75483086251441",
	pill = "rbxassetid://90720575878768",
	board = "rbxassetid://100418208380715",
	pedalGas = "rbxassetid://119885551343539",
	pedalBrake = "rbxassetid://130654904731448",
}

local sodium: FinishArt = {
	base = "rbxassetid://99547039974202",
	tachoFace = "rbxassetid://73546261811211",
	tachoNeedle = "rbxassetid://134510158620859",
	pill = "rbxassetid://76187293381969",
	board = "rbxassetid://93402628633203",
	pedalGas = "rbxassetid://132853684292592",
	pedalBrake = "rbxassetid://132064613665489",
}

local carbon: FinishArt = {
	base = "rbxassetid://133364572314158",
	tachoFace = "rbxassetid://93253278361713",
	tachoNeedle = "rbxassetid://82325847849838",
	pill = "rbxassetid://125364488949987",
	board = "rbxassetid://89007961639261",
	pedalGas = "rbxassetid://130628417135485",
	pedalBrake = "rbxassetid://115895894533881",
}

return {
	icons = "rbxassetid://124965200075331", -- hud_icons, 768x384: 192 px cells, 4 across: left, right, natl_l, natl_r, hand, exit, reset, style
	halo = "rbxassetid://133638095976591", -- hud_halo, 256, white: the lit ring
	tachoGlass = "rbxassetid://128679846706849", -- streetd_tacho_glass, 512: the glass and cap, every finish
	num = "rbxassetid://121313293704646", -- num, 640x300, cells of 80x150, 8 across: 0123456789,.x+-°
	gear = "rbxassetid://79074122323209", -- street_gear, 896x160, cells of 112x160, 123456RN
	streetd = streetd,
	sodium = sodium,
	carbon = carbon,
}
