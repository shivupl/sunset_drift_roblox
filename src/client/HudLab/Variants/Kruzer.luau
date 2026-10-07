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
local TweenService = game:GetService("TweenService")

local HudLab = script.Parent.Parent
local W = require(HudLab:WaitForChild("Widgets"))
local I = require(HudLab:WaitForChild("Instruments"))
local Motion = require(HudLab:WaitForChild("Motion"))
local Controls = require(HudLab:WaitForChild("ArcadeControls"))
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
local DOT_ORDER = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZx.,+-!:/° #"
local DOT_CELL = Vector2.new(96, 128)

local Kruzer = {}
Kruzer.id = "kruzer"
Kruzer.name = "KRUZER"

local ARABIC = W.font("BuilderSans", Enum.FontWeight.Heavy)
local LABEL = W.font("BuilderSans", Enum.FontWeight.Bold)

-- A child placed by its top left in a w x h piece of art's pixels.
local function rectIn(o: GuiObject, bw: number, bh: number, x: number, y: number, w: number, h: number)
	o.AnchorPoint = Vector2.new(0, 0)
	o.Position = UDim2.fromScale(x / bw, y / bh)
	o.Size = UDim2.fromScale(w / bw, h / bh)
end

local function lcd(parent: Instance, name: string, count: number, box: { number }): I.Chars
	local c = I.chars(parent, name, { atlas = Art.lcd, order = LCD_ORDER, cell = LCD_CELL, cols = 16, count = count })
	I.placeTL(c.root, T, box[1], box[2], box[3], box[4])
	return c
end

local function dots(parent: Instance, name: string, count: number, align: string?): I.Chars
	return I.chars(parent, name, { atlas = Art.dots, order = DOT_ORDER, cell = DOT_CELL, cols = 10, count = count, align = align })
end

local function pad(s: string, n: number): string
	return s .. string.rep(" ", math.max(n - utf8.len(s) :: number, 0))
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

	-- On a phone the displays line up by the buttons (EXIT / RESET / STYLE
	-- run 0.62 of the screen's height along the top left): the cash beside
	-- them, the drift display under them, clear of the cluster on any
	-- screen down to 16:10. A square the screen's height tall lets them be
	-- placed in fractions of it.
	local byHeight = W.frame(root, "ByHeight")
	byHeight.SizeConstraint = Enum.SizeConstraint.RelativeYY
	byHeight.Size = UDim2.fromScale(1, 1)
	byHeight.Position = UDim2.fromOffset(0, top)

	-- The drift display (960x300 art).
	local mid = W.frame(if touch then byHeight else root, "Display")
	if touch then
		mid.Size = UDim2.fromScale(0.56, 0.56 * 300 / 960)
		mid.Position = UDim2.new(0, 10, 0.115, 6)
	else
		W.box(mid, 0.6, 0.6 * 300 / 960)
		mid.AnchorPoint = Vector2.new(0.5, 0)
		mid.Position = UDim2.new(0.5, 0, 0, top + 4)
	end
	I.layer(mid, "Glass", Art.mid, 1)
	local points = dots(mid, "Points", 8)
	rectIn(points.root, 960, 300, 40, 24, 632, 105)
	local mult = dots(mid, "Mult", 4)
	rectIn(mult.root, 960, 300, 700, 50, 208, 70)
	local info = dots(mid, "Info", 16, "left")
	rectIn(info.root, 960, 300, 40, 150, 832, 70)
	for _, c in { points, mult, info } do
		c.root.ZIndex = 2
	end
	local leds: { Frame } = {}
	local LEDS = 24
	for i = 1, LEDS do
		local f = W.frame(mid, "Led" .. i, AMBER_DIM, 0)
		rectIn(f, 960, 300, 40 + (i - 1) * 880 / LEDS, 236, 880 / LEDS - 8, 16)
		f.ZIndex = 2
		W.corner(f, UDim.new(0.3, 0))
		table.insert(leds, f)
	end
	local midScale = Instance.new("UIScale")
	midScale.Parent = mid

	-- The cash display (600x200 art).
	local mini = W.frame(if touch then byHeight else root, "Cash")
	if touch then
		mini.Size = UDim2.fromScale(0.3, 0.1)
		mini.Position = UDim2.new(0.62, 34, 0, 4)
	else
		W.box(mini, 0.34, 0.34 * 200 / 600)
		mini.AnchorPoint = Vector2.new(0, 1)
		mini.Position = UDim2.new(0, 22, 1, -22)
	end
	I.layer(mini, "Glass", Art.mini, 1)
	local cashLabel = dots(mini, "Label", 4, "left")
	rectIn(cashLabel.root, 600, 200, 36, 42, 136, 44)
	cashLabel.set("CASH")
	local cash = dots(mini, "Value", 9)
	rectIn(cash.root, 600, 200, 178, 28, 396, 59)
	local best = dots(mini, "Best", 16, "left")
	rectIn(best.root, 600, 200, 36, 112, 528, 44)
	for _, c in { cashLabel, cash, best } do
		c.root.ZIndex = 2
	end
	local cashScale = Instance.new("UIScale")
	cashScale.Parent = mini

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

	local roller = Motion.roller()
	local cashRoller = Motion.roller()
	cashRoller.shown = -1
	local cashPop = Motion.spring(1, 5, 0.35)
	local midPop = Motion.spring(1, 4, 0.45)
	local glowAmt = Motion.spring(0, 2, 1)
	local message = ""
	local messageUntil = 0
	local messageBlink = false
	local held = 0 -- the points shown after a slide ends
	local heldUntil = 0
	local flash = AMBER
	local flashUntil = 0
	local clock = 0

	local function fly(amount: number)
		local t = W.text(root, "Fly", `+{Motion.comma(amount)}`, ARABIC, AMBER)
		W.stroke(t, INK, 3)
		W.box(t, 0.3, 0.07)
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		local from = mid.AbsolutePosition + mid.AbsoluteSize / 2
		local to = mini.AbsolutePosition + mini.AbsoluteSize / 2
		t.Position = UDim2.fromOffset(from.X, from.Y)
		local tw = TweenService:Create(t, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromOffset(to.X, to.Y),
		})
		tw.Completed:Once(function()
			t:Destroy()
			Motion.kick(cashPop, 8)
		end)
		tw:Play()
	end

	local function update(v: any, dt: number)
		clock += dt
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

		-- The display.
		local live = v.sliding
		if live then
			held, heldUntil = v.points, now + 1.4
		end
		local shownPoints = if live then v.points elseif now < heldUntil then held else 0
		local p = Motion.roll(roller, shownPoints, dt, 9)
		points.set(if p > 0 then Motion.comma(p) else "")
		mult.set(if live and v.mult > 1 then (if v.mult % 1 == 0 then string.format("x%d", v.mult) else string.format("x%.1f", v.mult)) else "")
		local line: string
		if now < messageUntil then
			line = if messageBlink and (clock * 3) % 1 > 0.6 then "" else message
		elseif v.natl then
			local m = v.margin
			line = pad(`NATL {math.floor(math.abs(v.roll) + 0.5)}°`, 11) .. (if m < 8 then "TIP!" elseif m < 16 then "CATCH" else "HOLD")
		elseif live then
			line = pad("DRIFT", 12) .. string.format("%3d°", math.floor(math.abs(v.angle) + 0.5))
		else
			line = string.format("TRIP %6.1f KM", v.trip)
		end
		info.set(line)
		local heat = math.clamp((v.mult - 1) / math.max(v.multMax - 1, 1), 0, 1)
		local lit = if live then math.floor(v.chain * LEDS + 0.5) else 0
		local ledOn = AMBER:Lerp(RED, heat)
		for i, f in leds do
			f.BackgroundColor3 = if i <= lit then ledOn else AMBER_DIM
		end
		midScale.Scale = Motion.step(midPop, 1, dt)

		-- Cash.
		if cashRoller.shown < 0 then
			cashRoller.shown = v.cash
		end
		cash.set(Motion.comma(Motion.roll(cashRoller, v.cash, dt, 4)))
		cashScale.Scale = Motion.step(cashPop, 1, dt)
		local showServer = v.serverBest > 0 and (clock % 6) > 3
		best.set(if showServer then `SERVER {Motion.comma(v.serverBest)}` else `BEST {Motion.comma(v.best)}`)

		local want = if live then 0.06 + 0.2 * heat else 0
		local g = Motion.step(glowAmt, want, dt)
		glow.set(if now < flashUntil then flash else AMBER, if now < flashUntil then 0.35 else g)
		shout.update(dt)
	end

	local function event(kind: string, a: number, b: number)
		local now = os.clock()
		if kind == "mult" then
			Motion.kick(midPop, 3)
		elseif kind == "spin" then
			shout.fire("طارت!", `{if b > 1 then b * 360 else 360}  +{Motion.comma(a)}`)
			Motion.kick(midPop, 5)
		elseif kind == "natl" then
			shout.fire("نطل!", "TWO WHEELS")
		elseif kind == "chain" then
			shout.fire("هجولة!", string.format("x%.1f CHAIN", a))
		elseif kind == "banked" then
			held, heldUntil = a, now + 1.6
			message, messageUntil, messageBlink = `BANKED +{Motion.comma(b)}`, now + 1.6, false
			flash, flashUntil = GREEN, now + 0.3
			Motion.kick(midPop, 5)
			if b > 0 then
				fly(b)
			end
		elseif kind == "dropped" then
			held, heldUntil = 0, 0
			message, messageUntil, messageBlink = "DROPPED", now + 1.2, true
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
