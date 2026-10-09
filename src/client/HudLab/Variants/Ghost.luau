--!strict
-- GHOST (hud-variants, 2026-10-08): layout D (LayoutD.luau, StreetHud.luau)
-- in smoked glass: see-through round buttons with a thin white rim, black
-- anodised drilled pedals, a glass tacho.
local HudLab = script.Parent.Parent
local StreetHud = require(HudLab:WaitForChild("StreetHud"))
local ArtAll = require(HudLab:WaitForChild("Art"))
local A = ArtAll.ghost

return StreetHud.variant("ghost", "GHOST", {
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
		pedalGas = A.pedalGas,
		pedalBrake = A.pedalBrake,
		leanTrack = ArtAll.street.leanTrack,
		leanKnob = ArtAll.street.leanKnob,
	},
})
