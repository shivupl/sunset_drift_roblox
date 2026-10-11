--!strict
-- The driving HUD for layout D (hud-variants, 2026-10-08), in STREET's look,
-- in whichever finish is on (Finishes.luau; on 2026-10-10 the owner kept
-- STREET D, had the other styles removed, then asked for finishes of it)
-- and whichever version (Versions.luau: where the score and cash go and how
-- they look). From the owner's notes on the STREET trial: the tacho "bottom
-- middle, remove the white and change the opacity... remove the tyre
-- monitor", "remove the 'trip' thing and move the cash to the top right",
-- then on the mockups "make odometer smaller".
--
--   Tacho   small, bottom middle, a smoked see-through face; the gear above
--           the cap, the speed below it in big italic digits.
--   Score   and cash: the version's (ScoreBoard for BOARD, ScoreLive for
--           FLOW and SIDE).
--   Glow    the screen's edges, with the chain; a flash on banked or dropped.
--   Shout   a 360, two wheels, a big chain, stamped just left of the car as
--           each move ends, in tafheet's own words, a line under it:
--           تخميسة! (takhmisa, the car spun round), ترفيع! (tarfi', the car
--           up on two tyres), هجولة! (hajwala, drifting itself, at a x3
--           chain). Researched on 2026-10-10 (forum glossaries, news, Saudi
--           videos and games); it was طارت! ("it flew"), which no source used
--           for a 360.
-- The art is Art.luau.
local HudLab = script.Parent
local W = require(HudLab:WaitForChild("Widgets"))
local I = require(HudLab:WaitForChild("Instruments"))
local Motion = require(HudLab:WaitForChild("Motion"))
local LayoutD = require(HudLab:WaitForChild("LayoutD"))
local Art = require(HudLab:WaitForChild("Art"))
local Finishes = require(HudLab:WaitForChild("Finishes"))
local Versions = require(HudLab:WaitForChild("Versions"))
local R = require(HudLab:WaitForChild("Readouts"))
local ScoreBoard = require(HudLab:WaitForChild("ScoreBoard"))
local ScoreLive = require(HudLab:WaitForChild("ScoreLive"))

local FROM, TO, MAX = -135, 135, 9000
-- The callout: the stamp it always was, a little left of the car rather
-- than on it, tilted, and never quite in the same place twice (the owner,
-- 2026-10-10: "similar to before just off to the side a bit to make it look
-- more scrappy"; it was centred at 0.5, tilted -6). Fractions of the screen.
local SHOUT_X, SHOUT_Y = 0.43, 0.44
local SHOUT_TILT = -8
local SHOUT_JITTER = 0.012
local SHOUT_JITTER_DEG = 3

local StreetHud = {}

function StreetHud.build(gui: ScreenGui, touch: boolean, finish: Finishes.Finish, version: Versions.Version): any
	local f = finish
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	local root = W.frame(gui, "StreetHud")
	root.Size = UDim2.fromScale(1, 1)
	-- The edge glow fills the whole screen, notch and all: inside the
	-- safe area it stopped in hard lines short of the sides (the owner,
	-- 2026-10-08: "again with the boundries, whats going on? its cut off").
	local glowGui = Instance.new("ScreenGui")
	glowGui.Name = "HajwalaHudLabGlow"
	glowGui.ResetOnSpawn = false
	glowGui.IgnoreGuiInset = true
	glowGui.ScreenInsets = Enum.ScreenInsets.None
	glowGui.DisplayOrder = gui.DisplayOrder - 1
	glowGui.Parent = gui.Parent
	local glow = W.edgeGlow(glowGui)
	local right = LayoutD.corner(root, "Right", true)

	-- The tacho, bottom middle.
	local size = if touch then 0.237 else 0.3
	local tacho = I.dial(root, "Tacho", {
		face = f.art.tachoFace,
		needle = f.art.tachoNeedle,
		glass = Art.tachoGlass,
		fromDeg = FROM,
		toDeg = TO,
		max = MAX,
		jitterAbove = 6650,
	})
	W.square(tacho.root, size)
	tacho.root.AnchorPoint = Vector2.new(0.5, 1)
	tacho.root.Position = UDim2.new(0.5, 0, 1 - LayoutD.EDGE_B, 0)
	local gear = I.chars(tacho.under, "Gear", { atlas = Art.gear, order = "123456RN", cell = Vector2.new(112, 160), cols = 8, count = 1 })
	R.rect(gear.root, 0.43, 0.2, 0.14, 0.2)
	local speed = R.nums(tacho.under, "Speed", 3)
	speed.tint(f.print)
	R.rect(speed.root, 0.29, 0.56, 0.42, 0.24)
	local kmh = R.label(tacho.under, "Kmh", "km/h", f.label)
	R.rect(kmh, 0.38, 0.79, 0.24, 0.08)
	local gearScale = Instance.new("UIScale")
	gearScale.Parent = gear.root
	local gearPop = Motion.spring(1, 6, 0.4)
	local lastGear = 0

	-- Score and cash.
	local score: ScoreBoard.Score
	if version.id == "board" then
		score = ScoreBoard.build(root, right, f)
	else
		score = ScoreLive.build(root, right, f, version.id == "side")
	end

	local shout = W.shout(root, "Shout", {
		font = R.SHOUT,
		color = f.print,
		stroke = R.INK,
		strokeThickness = 5,
		subFont = R.LABEL,
		subColor = f.accent,
		tilt = SHOUT_TILT,
	})
	W.box(shout.root, 0.56, 0.2)
	W.at(shout.root, SHOUT_X, SHOUT_Y)
	-- Each one lands a little differently, slapped on rather than placed.
	local function stamp(word: string, sub: string)
		shout.root.Rotation = SHOUT_TILT + (math.random() - 0.5) * 2 * SHOUT_JITTER_DEG
		shout.root.Position = UDim2.fromScale(SHOUT_X + (math.random() - 0.5) * 2 * SHOUT_JITTER, SHOUT_Y + (math.random() - 0.5) * 2 * SHOUT_JITTER)
		shout.fire(word, sub)
	end

	local glowAmt = Motion.spring(0, 2, 1)
	local flash, flashUntil = f.accent, 0

	local function update(v: any, dt: number)
		local now = os.clock()
		tacho.set(v.rpm)
		tacho.update(dt)
		gear.set(if v.gear == -1 then "R" elseif v.gear == 0 then "N" else tostring(v.gear))
		if v.gear ~= lastGear then
			lastGear = v.gear
			Motion.kick(gearPop, 7)
		end
		gearScale.Scale = Motion.step(gearPop, 1, dt)
		speed.set(tostring(math.clamp(math.floor(v.speed + 0.5), 0, 999)))

		score.update(v, dt)

		local heat = math.clamp((v.mult - 1) / math.max(v.multMax - 1, 1), 0, 1)
		local want = if v.sliding then 0.05 + 0.18 * heat else 0
		local g = Motion.step(glowAmt, want, dt)
		glow.set(if now < flashUntil then flash else f.accent, if now < flashUntil then 0.3 else g)
		shout.update(dt)
	end

	local function event(kind: string, a: number, b: number)
		local now = os.clock()
		if kind == "spin" then
			stamp("تخميسة!", `{if b > 1 then b * 360 else 360}  +{Motion.comma(a)}`)
		elseif kind == "natl" then
			stamp("ترفيع!", string.format("%.1fs", a))
		elseif kind == "chain" then
			stamp("هجولة!", R.mult(a) .. " CHAIN")
		elseif kind == "banked" then
			flash, flashUntil = f.banked, now + 0.3
		elseif kind == "dropped" then
			flash, flashUntil = f.dropped, now + 0.4
		end
		score.event(kind, a, b)
	end

	return {
		update = update,
		event = event,
		destroy = function()
			score.destroy()
			root:Destroy()
			glowGui:Destroy()
		end,
	}
end

return StreetHud
