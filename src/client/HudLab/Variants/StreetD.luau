--!strict
-- STREET D (hud-variants, 2026-10-08): layout D (LayoutD.luau, StreetHud.luau)
-- in STREET's machined finish: black anodised round buttons with knurled
-- rims, STREET's drilled aluminium pedals, a smoked tacho in a black bezel.
local HudLab = script.Parent.Parent
local StreetHud = require(HudLab:WaitForChild("StreetHud"))
local ArtAll = require(HudLab:WaitForChild("Art"))
local A = ArtAll.streetd

return StreetHud.variant("streetd", "STREET D", {
	tachoFace = A.tachoFace,
	tachoNeedle = A.tachoNeedle,
	tachoGlass = A.tachoGlass,
	pill = A.pill,
	board = A.board,
	controls = {
		left = A.btnLeft,
		right = A.btnRight,
		natlOff = A.natlOff,
		natlOn = A.natlOn,
		handOff = A.handOff,
		handOn = A.handOn,
		exit = A.exit,
		reset = A.reset,
		style = A.style,
		pedalGas = ArtAll.street.pedalGas,
		pedalBrake = ArtAll.street.pedalBrake,
		leanTrack = ArtAll.street.leanTrack,
		leanKnob = ArtAll.street.leanKnob,
	},
})
