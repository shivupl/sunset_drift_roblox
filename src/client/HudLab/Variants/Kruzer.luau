--!strict
-- KRUZER (hud-variants, 2026-10-07): ARCADE's layout with a real instrument
-- cluster, after Tokyo Xtreme Racer 2025 (an orange-lit analog tacho with
-- small gauges round it, the speed and odometer in digits) and the
-- 100-series Land Cruiser's cluster at night (amber numerals lit through a
-- black face, a red needle that glows, an LCD).
--
--   Tacho      needle on a spring; the LCD under it shows the speed and the
--              odometer, a window over the cap the gear; telltales light:
--              SHIFT near the limiter, (P) with the handbrake, the skid car
--              while sliding, NATL on two wheels.
--   ROLL       an inclinometer: the car tilts with the roll, red marks show
--              where it tips (roll plus the margin left).
--   ANGLE      the drift angle, the 30..60 sweet spot marked.
--   Display    an amber dot-matrix: the slide's points, the multiplier, a
--              line of what is happening, the chain as a row of LEDs.
--   Cash       a small dot-matrix display; banked cash flies into it.
-- Phone: ARCADE's controls in OEM parts (ArcadeControls): ribbed rubber
-- pedals on steel, a leather pad, a leather handbrake grip, a NATL switch.
-- The art is art/hud/kruzer/make.py; its layout numbers are mirrored here.
local GuiService = game:GetService("GuiService")

local HudLab = script.Parent.Parent
local W = require(HudLab:WaitForChild("Widgets"))
local I = require(HudLab:WaitForChild("Instruments"))
local Motion = require(HudLab:WaitForChild("Motion"))
local Controls = require(HudLab:WaitForChild("ArcadeControls"))
local Display = require(HudLab:WaitForChild("DotDisplay"))
local Art = require(HudLab:WaitForChild("Art")).kruzer

local AMBER = Color3.fromRGB(255, 173, 66)
local AMBER_DIM = Color3.fromRGB(58, 34, 10)
local RED = Color3.fromRGB(255, 58, 36)
local GREEN = Color3.fromRGB(92, 255, 122)
local INK = Color3.fromRGB(20, 10, 2)

-- The tacho's art (768 px): its scale and where its windows are.
local T = 768
local FROM, TO, MAX = -125, 125, 8000
local GEAR = { 354, 214, 60, 96 } -- x, y, w, h
local TELLS = { { 276, 262 }, { 318, 262 }, { 450, 262 }, { 492, 262 } } -- shift, brake, slip, natl
local TELL = 38 * 96 / 66 -- a lamp image's size for its icon to cover the print
local SPEED = { 262, 500, 192, 104 }
local ODO = { 300, 614, 168, 40 }
local LCD_ORDER = "0123456789 -rnP#"
local LCD_CELL = Vector2.new(60, 96)

local Kruzer = {}
Kruzer.id = "kruzer"
Kruzer.name = "KRUZER"

local ARABIC = W.font("BuilderSans", Enum.FontWeight.Heavy)
local LABEL = W.font("BuilderSans", Enum.FontWeight.Bold)

local function lcd(parent: Instance, name: string, count: number, box: { number }): I.Chars
	local c = I.chars(parent, name, { atlas = Art.lcd, order = LCD_ORDER, cell = LCD_CELL, cols = 16, count = count })
	I.placeTL(c.root, T, box[1], box[2], box[3], box[4])
	return c
end

function Kruzer.buildHud(gui: ScreenGui, touch: boolean, _api: any): any
	local root = W.frame(gui, "Kruzer")
	root.Size = UDim2.fromScale(1, 1)
	local glow = W.edgeGlow(root)
	local top = GuiService:GetGuiInset().Y

	-- The cluster: the tacho, the two small gauges against its rim.
	local cluster = W.frame(root, "Cluster")
	W.square(cluster, if touch then 0.38 else 0.36)
	if touch then
		-- Top right, left of the handbrake.
		cluster.AnchorPoint = Vector2.new(1, 0)
		cluster.Position = UDim2.new(0.885, 0, 0, top + 2)
	else
		cluster.AnchorPoint = Vector2.new(1, 1)
		cluster.Position = UDim2.new(1, -24, 1, -18)
	end
	local tacho = I.dial(cluster, "Tacho", {
		face = Art.tachoFace,
		needle = Art.tachoNeedle,
		glass = Art.tachoGlass,
		fromDeg = FROM,
		toDeg = TO,
		max = MAX,
		jitterAbove = 6650,
	})
	tacho.root.Size = UDim2.fromScale(1, 1)
	local speed = lcd(tacho.under, "Speed", 3, SPEED)
	local odo = lcd(tacho.under, "Odo", 6, ODO)
	local gear = lcd(tacho.under, "Gear", 1, GEAR)
	local lamps: { I.Lamp } = {}
	for i, art in { Art.lampShift, Art.lampBrake, Art.lampSlip, Art.lampNatl } do
		local l = I.lamp(tacho.under, "Lamp" .. i, art)
		I.place(l.root, T, TELLS[i][1], TELLS[i][2], TELL, TELL)
		table.insert(lamps, l)
	end

	-- The small gauges sit on the tacho's rim: below and left on a phone
	-- (the cluster is at the top), above and left on a monitor.
	local podSize = 0.395
	local function podAt(o: GuiObject, x: number, y: number)
		o.AnchorPoint = Vector2.new(0.5, 0.5)
		o.Position = UDim2.fromScale(x, y)
		o.Size = UDim2.fromScale(podSize, podSize)
		o.ZIndex = 2
	end
	local roll = I.dial(cluster, "Roll", {
		face = Art.rollFace,
		needle = Art.rollCar,
		glass = Art.podGlass,
		fromDeg = -60,
		toDeg = 60,
		min = -60,
		max = 60,
		freq = 2.6,
		damp = 0.7,
	})
	local tips: { ImageLabel } = {}
	for i = 1, 2 do
		local tip = I.layer(roll.under, "Tip" .. i, Art.rollTip, 2)
		tip.Visible = false
		table.insert(tips, tip)
	end
	local angle = I.dial(cluster, "Angle", {
		face = Art.angleFace,
		needle = Art.podNeedle,
		glass = Art.podGlass,
		fromDeg = -90,
		toDeg = 90,
		min = -90,
		max = 90,
		freq = 3.2,
		damp = 0.6,
	})
	if touch then
		podAt(roll.root, -0.04, 0.763)
		podAt(angle.root, 0.158, 1.04)
	else
		podAt(roll.root, -0.04, 0.237)
		podAt(angle.root, 0.158, -0.04)
	end

	local displays = Display.build(root, touch, {
		panel = Art.mid,
		mini = Art.mini,
		dots = Art.dots,
		lit = AMBER,
		dim = AMBER_DIM,
		hot = RED,
		angleBar = false,
		flyFont = ARABIC,
		flyColor = AMBER,
		flyStroke = INK,
	})

	local shout = W.shout(root, "Shout", {
		font = ARABIC,
		color = AMBER,
		stroke = INK,
		strokeThickness = 5,
		subFont = LABEL,
		subColor = Color3.fromRGB(255, 236, 205),
		tilt = -4,
	})
	W.box(shout.root, 0.56, 0.22)
	W.at(shout.root, if touch then 0.42 else 0.36, 0.46)

	local glowAmt = Motion.spring(0, 2, 1)
	local flash = AMBER
	local flashUntil = 0

	local function update(v: any, dt: number)

		local now = os.clock()
		-- Tacho and its LCD.
		tacho.set(v.rpm)
		tacho.update(dt)
		speed.set(tostring(math.floor(v.speed + 0.5)))
		odo.set(string.format("%06d", math.floor(v.odo) % 1000000))
		gear.set(if v.gear == -1 then "r" elseif v.gear == 0 then "n" else tostring(v.gear))
		local limiter = v.rpm >= v.redline - 300
		lamps[1].set(if limiter then "blink" else "off")
		lamps[2].set(if v.handbrake then "on" else "off")
		lamps[3].set(if v.sliding and math.abs(v.angle) > 8 then "blink" else "off")
		lamps[4].set(if v.natl then "on" else "off")
		for _, l in lamps do
			l.update(dt)
		end

		-- Inclinometer: the car tilts with the roll; on two wheels the red
		-- marks show where it goes over.
		roll.set(v.roll)
		roll.update(dt)
		local tipAt = math.clamp(math.abs(v.roll) + v.margin, 5, 60)
		for i, tip in tips do
			tip.Visible = v.natl
			tip.Rotation = if i == 1 then -tipAt else tipAt
		end
		angle.set(if v.speed > 5 then math.clamp(v.angle, -90, 90) else 0)
		angle.update(dt)

		displays.update(v, dt)
		local live = v.sliding
		local heat = math.clamp((v.mult - 1) / math.max(v.multMax - 1, 1), 0, 1)
		local want = if live then 0.06 + 0.2 * heat else 0
		local g = Motion.step(glowAmt, want, dt)
		glow.set(if now < flashUntil then flash else AMBER, if now < flashUntil then 0.35 else g)
		shout.update(dt)
	end

	local function event(kind: string, a: number, b: number)
		local now = os.clock()
		displays.event(kind, a, b)
		if kind == "spin" then
			shout.fire("طارت!", `{if b > 1 then b * 360 else 360}  +{Motion.comma(a)}`)
		elseif kind == "natl" then
			shout.fire("نطل!", "TWO WHEELS")
		elseif kind == "chain" then
			shout.fire("هجولة!", string.format("x%.1f CHAIN", a))
		elseif kind == "banked" then
			flash, flashUntil = GREEN, now + 0.3
		elseif kind == "dropped" then
			flash, flashUntil = RED, now + 0.4
		end
	end

	return {
		update = update,
		event = event,
		destroy = function()
			root:Destroy()
		end,
	}
end

function Kruzer.buildControls(gui: ScreenGui, api: any): any
	return Controls.build(gui, api, {
		pedalGas = Art.pedalGas,
		pedalBrake = Art.pedalBrake,
		padBase = Art.padBase,
		padKnob = Art.padKnob,
		leverTrack = Art.leverTrack,
		leverHandle = Art.leverHandle,
		natlOff = Art.natlOff,
		natlOn = Art.natlOn,
		pill = Art.pill,
		pillSlice = Rect.new(40, 40, 260, 72),
		leanTrack = Art.leanTrack,
		leanKnob = Art.leanKnob,
		font = LABEL,
		text = Color3.fromRGB(222, 216, 206),
		litText = AMBER,
	})
end

return Kruzer
