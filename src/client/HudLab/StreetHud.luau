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
--           the cap, the speed below it in big italic digits. On a
--           desktop the readouts are the desk layout's (Desk, desktop-ui
--           2026-10-14; the owner: "the odometer and stuff should go on
--           the right"): the same dial in the bottom right corner (DASH),
--           a strip with no dial (STRIP) or a cluster on a glass tray
--           (CLUSTER), and the key guide bottom left (KeyGuide).
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
local Desk = require(HudLab:WaitForChild("Desk"))
local KeyGuide = require(HudLab:WaitForChild("KeyGuide"))
local PickerArt = require(HudLab.Parent:WaitForChild("CarPicker"):WaitForChild("Art"))

local FROM, TO, MAX = -135, 135, 9000
-- The dial: a phone's, bottom middle; a desktop's, in the corner (the
-- canvas: 300 on 1080, was 0.3 in the middle).
local DIAL_TOUCH = 0.237
local DIAL_DESK = 0.28
-- STRIP, fractions of the screen's height (the canvas: 440 wide on 1080;
-- the gear box 76x96, the bar 14, 10 and 6 between, a 12 px label row):
-- the box's own parts as fractions of the box.
local STRIP_W, STRIP_H = 0.407, 0.15
local STRIP_GEAR = { 0, 0, 0.173, 0.593 }
local STRIP_SPEED = { 0.214, 0, 0.35, 0.593 }
local STRIP_KMH = { 0.584, 0.4, 0.12, 0.13 }
local STRIP_BAR = { 0, 0.654, 1, 0.086 }
-- The label row and the gear box's word: bigger shares than the canvas's
-- 12 px, which came out 7 px in Studio's 683 px viewport.
local STRIP_LABELS = { 0, 0.76, 1, 0.1 }
local STRIP_GEAR_WORD = { 0.15, 0.08, 0.7, 0.2 }
local STRIP_GEAR_DIGIT = { 0.3, 0.32, 0.4, 0.58 }
-- Where the bar goes red: 7 of 9.
local RED_FROM = 7000 / MAX
-- CLUSTER (the canvas: a 560x230 tray 44 in from the right, 28 up; the
-- dial 200): the tray's parts as fractions of the tray.
local TRAY_W, TRAY_H = 0.519, 0.213
local TRAY_EDGE_R = 0.041
-- (The words a size up on the canvas's, for Studio's small viewport.)
local TRAY_GEAR_LABEL = { 0.12, 0.19, 0.1, 0.08 }
local TRAY_GEAR = { 0.225, 0.1, 0.08, 0.26 }
local TRAY_SPEED = { 0.12, 0.38, 0.286, 0.43 }
local TRAY_KMH = { 0.42, 0.66, 0.12, 0.09 }
local TRAY_DIAL = 0.87
local TRAY_DIAL_X = 0.77
local GLASS_ALPHA = 0.5
local RIM_ALPHA = 0.88
-- The callout: the stamp it always was, a little left of the car rather
-- than on it, tilted, and never quite in the same place twice (the owner,
-- 2026-10-10: "similar to before just off to the side a bit to make it look
-- more scrappy"; it was centred at 0.5, tilted -6). Fractions of the screen.
local SHOUT_X, SHOUT_Y = 0.43, 0.44
local SHOUT_TILT = -8
local SHOUT_JITTER = 0.012
local SHOUT_JITTER_DEG = 3

local StreetHud = {}

type Readouts = { update: (v: any, dt: number) -> () }

local function rect(o: GuiObject, r: { number })
	R.rect(o, r[1], r[2], r[3], r[4])
end

local function dialOf(parent: Instance, f: Finishes.Finish): I.Dial
	return I.dial(parent, "Tacho", {
		face = f.art.tachoFace,
		needle = f.art.tachoNeedle,
		glass = Art.tachoGlass,
		fromDeg = FROM,
		toDeg = TO,
		max = MAX,
		jitterAbove = 6650,
	})
end

-- The tabs' slanted shape as dark glass with a faint rim (TopBar's tabs
-- and KeyGuide's strip are the same art): the slice follows the height.
local function glass(parent: Instance, name: string): Frame
	local box = W.frame(parent, name)
	local function slice(o: ImageLabel)
		o.Image = PickerArt.tab
		o.ScaleType = Enum.ScaleType.Slice
		o.SliceCenter = PickerArt.tabSlice
		o:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			o.SliceScale = math.max(o.AbsoluteSize.Y, 1) / PickerArt.tabH
		end)
	end
	local rim = W.image(box, "Rim", PickerArt.tab)
	rim.ImageTransparency = RIM_ALPHA
	slice(rim)
	local fill = W.image(box, "Fill", PickerArt.tab)
	fill.ImageColor3 = Color3.fromRGB(6, 6, 7)
	fill.ImageTransparency = GLASS_ALPHA
	fill.Position = UDim2.fromOffset(1, 1)
	fill.Size = UDim2.new(1, -2, 1, -2)
	slice(fill)
	return box
end

-- The speed, the gear and the revs. A phone, and a desktop's DASH: the
-- dial, the gear above its cap and the speed under it; STRIP and CLUSTER
-- as Desk says. `right` is the screen's top-right corner square
-- (LayoutD.corner): a desktop's readouts are placed in it, in fractions
-- of the screen's height from its right edge.
local function readouts(root: Frame, right: Frame, touch: boolean, f: Finishes.Finish, form: string): Readouts
	local gear: I.Chars
	local speed: I.Chars
	local kmh: TextLabel
	local tacho: I.Dial? = nil
	local barFill: Frame? = nil
	local barSpring = Motion.spring(0, 4.2, 0.55)
	if form == "strip" then
		local box = W.frame(right, "Strip")
		W.box(box, STRIP_W, STRIP_H)
		box.AnchorPoint = Vector2.new(1, 1)
		box.Position = UDim2.fromScale(1 - LayoutD.EDGE_R - 0.006, 1 - LayoutD.EDGE_B)
		local gearBox = W.frame(box, "GearBox", R.INK, 0.4)
		rect(gearBox, STRIP_GEAR)
		W.corner(gearBox, UDim.new(0, 10))
		W.stroke(gearBox, Color3.new(1, 1, 1), 1, 0.88)
		local gl = R.label(gearBox, "Label", "GEAR", f.label)
		rect(gl, STRIP_GEAR_WORD)
		gear = I.chars(gearBox, "Gear", { atlas = Art.gear, order = "123456RN", cell = Vector2.new(112, 160), cols = 8, count = 1 })
		rect(gear.root, STRIP_GEAR_DIGIT)
		speed = R.nums(box, "Speed", 3)
		speed.tint(f.print)
		rect(speed.root, STRIP_SPEED)
		kmh = R.label(box, "Kmh", "km/h", f.label)
		rect(kmh, STRIP_KMH)
		kmh.TextXAlignment = Enum.TextXAlignment.Left
		local bar = W.frame(box, "Bar", R.INK, 0.4)
		rect(bar, STRIP_BAR)
		bar.ClipsDescendants = true
		W.corner(bar)
		W.stroke(bar, Color3.new(1, 1, 1), 1, 0.88)
		local red = W.frame(bar, "Red", f.accent, 0.65)
		red.Position = UDim2.fromScale(RED_FROM, 0)
		red.Size = UDim2.fromScale(1 - RED_FROM, 1)
		local fill = W.frame(bar, "Fill", f.label, 0)
		fill.Size = UDim2.fromScale(0, 1)
		fill.ZIndex = 2
		W.corner(fill)
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(f.label, f.accent)
		g.Parent = fill
		barFill = fill
		local lo = R.label(box, "Lo", "0", f.label)
		rect(lo, STRIP_LABELS)
		lo.TextXAlignment = Enum.TextXAlignment.Left
		local mid = R.label(box, "Rpm", "RPM", f.label)
		rect(mid, STRIP_LABELS)
		local hi = R.label(box, "Hi", "9", f.accent)
		rect(hi, STRIP_LABELS)
		hi.TextXAlignment = Enum.TextXAlignment.Right
	elseif form == "cluster" then
		local tray = glass(right, "Tray")
		W.box(tray, TRAY_W, TRAY_H)
		tray.AnchorPoint = Vector2.new(1, 1)
		tray.Position = UDim2.fromScale(1 - TRAY_EDGE_R, 1 - LayoutD.EDGE_B)
		local gl = R.label(tray, "GearLabel", "GEAR", f.label)
		rect(gl, TRAY_GEAR_LABEL)
		gl.TextXAlignment = Enum.TextXAlignment.Left
		gear = I.chars(tray, "Gear", { atlas = Art.gear, order = "123456RN", cell = Vector2.new(112, 160), cols = 8, count = 1 })
		rect(gear.root, TRAY_GEAR)
		speed = R.nums(tray, "Speed", 3)
		speed.tint(f.print)
		rect(speed.root, TRAY_SPEED)
		kmh = R.label(tray, "Kmh", "km/h", f.label)
		rect(kmh, TRAY_KMH)
		kmh.TextXAlignment = Enum.TextXAlignment.Left
		local d = dialOf(tray, f)
		W.square(d.root, TRAY_DIAL)
		W.at(d.root, TRAY_DIAL_X, 0.5)
		tacho = d
	else
		local d = dialOf(if touch then root else right, f)
		if touch then
			W.square(d.root, DIAL_TOUCH)
			d.root.AnchorPoint = Vector2.new(0.5, 1)
			d.root.Position = UDim2.new(0.5, 0, 1 - LayoutD.EDGE_B, 0)
		else
			W.square(d.root, DIAL_DESK)
			d.root.AnchorPoint = Vector2.new(1, 1)
			d.root.Position = UDim2.fromScale(1 - LayoutD.EDGE_R - 0.006, 1 - LayoutD.EDGE_B)
		end
		gear = I.chars(d.under, "Gear", { atlas = Art.gear, order = "123456RN", cell = Vector2.new(112, 160), cols = 8, count = 1 })
		R.rect(gear.root, 0.43, 0.2, 0.14, 0.2)
		speed = R.nums(d.under, "Speed", 3)
		speed.tint(f.print)
		R.rect(speed.root, 0.29, 0.56, 0.42, 0.24)
		kmh = R.label(d.under, "Kmh", "km/h", f.label)
		R.rect(kmh, 0.38, 0.79, 0.24, 0.08)
		tacho = d
	end
	local gearScale = Instance.new("UIScale")
	gearScale.Parent = gear.root
	local gearPop = Motion.spring(1, 6, 0.4)
	local lastGear = 0
	return {
		update = function(v: any, dt: number)
			local t = tacho
			if t then
				t.set(v.rpm)
				t.update(dt)
			end
			local bf = barFill
			if bf then
				bf.Size = UDim2.fromScale(Motion.step(barSpring, math.clamp(v.rpm / MAX, 0, 1), dt), 1)
			end
			gear.set(if v.gear == -1 then "R" elseif v.gear == 0 then "N" else tostring(v.gear))
			if v.gear ~= lastGear then
				lastGear = v.gear
				Motion.kick(gearPop, 7)
			end
			gearScale.Scale = Motion.step(gearPop, 1, dt)
			speed.set(tostring(math.clamp(math.floor(v.speed + 0.5), 0, 999)))
		end,
	}
end

function StreetHud.build(gui: ScreenGui, touch: boolean, finish: Finishes.Finish, version: Versions.Version): any
	local f = finish
	local desk: Desk.Desk? = if touch then nil else Desk.current()
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

	-- The readouts: the tacho bottom middle on a phone; a desktop's where
	-- its layout puts them. The key guide, a desktop's, bottom left.
	local ro = readouts(root, right, touch, f, if desk then desk.readouts else "dial")
	local guide: KeyGuide.Guide? = if desk then KeyGuide.build(root, desk.guide) else nil

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
		ro.update(v, dt)
		local kg = guide
		if kg then
			kg.update(dt)
		end

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
