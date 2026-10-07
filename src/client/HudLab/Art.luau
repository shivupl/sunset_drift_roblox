--!strict
-- The HUD variants' image art (hud-variants, 2026-10-07; the owner: "the
-- 'art' looks pretty bad... would benefit from some sort of image generation
-- or higher detail"). Drawn as SVG in art/hud/<variant>/, rendered by
-- art/hud/render.py, uploaded from Studio; each id here is the upload of
-- art/hud/out/<variant>_<name>.png. Re-render and re-upload to change one.
local Art = {}

Art.pro = {
	pedalGas = "rbxassetid://135274787038915", -- 400x1000
	pedalBrake = "rbxassetid://79262254764559", -- 560x520
	wheel = "rbxassetid://102449432767242", -- 800x800
	leverTrack = "rbxassetid://78580710859585", -- 220x640
	leverHandle = "rbxassetid://120524520893805", -- 300x340
	natlOff = "rbxassetid://102396238986805", -- 320x320
	natlOn = "rbxassetid://136280960014442",
	pill = "rbxassetid://134413685288700", -- 300x120, 9-slice
	tachoFace = "rbxassetid://117938827503151", -- 800x800, -135..100 deg for 0..8000 rpm
	needle = "rbxassetid://73792139926842", -- 800x800, pointing up from the centre
}

return Art
