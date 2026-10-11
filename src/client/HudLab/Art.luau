--!strict
-- The HUD's image art. Rendered by art/hud/streetd/make.py (layout D's
-- buttons, tacho, panels and digits) and art/hud/street/make.py (the gear
-- digits, the drilled pedals and the lean slider, from the STREET cluster
-- trial), uploaded from Studio; each id here is the upload of
-- art/hud/out/<file>.png. Re-render and re-upload to change one.
local Art = {
	btnLeft = "rbxassetid://133082246836189", -- streetd_btn_left, 256
	btnRight = "rbxassetid://73905289624720",
	natlOff = "rbxassetid://118567959882542",
	natlOn = "rbxassetid://83705259355697",
	handOff = "rbxassetid://106206029263233",
	handOn = "rbxassetid://70471969886521",
	exit = "rbxassetid://116049898008258", -- 160
	reset = "rbxassetid://76953069037084",
	tachoFace = "rbxassetid://136476820905479", -- 512, -135..135 deg for 0..9000 r/min
	tachoNeedle = "rbxassetid://75483086251441",
	tachoGlass = "rbxassetid://128679846706849",
	pill = "rbxassetid://78874374331613", -- 300x120, 9-slice
	board = "rbxassetid://74386076589633", -- 660x170
	num = "rbxassetid://121313293704646", -- num, 640x300, cells of 80x150, 8 across: 0123456789,.x+-°
	gear = "rbxassetid://79074122323209", -- street_gear, 896x160, cells of 112x160, 123456RN
	pedalGas = "rbxassetid://119885551343539", -- street_pedal_gas, 400x1000
	pedalBrake = "rbxassetid://84226814032224", -- street_pedal_brake, 560x520
	leanTrack = "rbxassetid://121856851965042", -- street_lean_track, 900x200
	leanKnob = "rbxassetid://96228336250197", -- street_lean_knob, 200
}

return Art
