--!strict
-- STREET (hud-variants, 2026-10-07): ARCADE's layout as a street drift car.
-- After Initial D Arcade Stage (a white-face tacho with a red needle, the
-- gear and the speed in big italic digits beside it) and CarX Street (a real
-- tacho with a rolling odometer).
--
--   Tacho      an aftermarket white face in a knurled black bezel; the red
--              needle casts a shadow; an orange peak needle holds the top
--              reading and falls back; mechanical drums count the
--              kilometres (the last, red, tenths); the shift light on the
--              bezel lights near the limiter and flashes on it.
--   TYRE       tyre temperature, 40..140 C: a slide warms them, grip cools.
--   Readout    the gear (yellow to red) and the speed in big italic digits:
--              under the tacho on a phone, left of it on a monitor.
--   Board      the red LED drift board: points, multiplier, the drift angle
--              as a bar while sliding, the chain as a row of LEDs; the cash
--              board the banked cash flies into.
-- Phone: ARCADE's controls as drift-car hardware (ArcadeControls): drilled
-- aluminium pedals with rubber strips, a machined thumb pad, a hydraulic
-- handbrake grip, a missile switch for the natl.
-- The art is art/hud/street/make.py; its layout numbers are mirrored here.
local GuiService = game:GetService("GuiService")

local HudLab = script.Parent.Parent
local W = require(HudLab:WaitForChild("Widgets"))
local I = require(HudLab:WaitForChild("Instruments"))
local Motion = require(HudLab:WaitForChild("Motion"))
local Controls = require(HudLab:WaitForChild("ArcadeControls"))
local Display = require(HudLab:WaitForChild("DotDisplay"))
local Art = require(HudLab:WaitForChild("Art")).street

local LED = Color3.fromRGB(255, 50, 32)
local LED_DIM = Color3.fromRGB(42, 10, 6)
local HOT = Color3.fromRGB(255, 196, 64)
local WHITE = Color3.fromRGB(251, 250, 246)
local INK = Color3.fromRGB(12, 12, 13)
local GREEN = Color3.fromRGB(90, 230, 120)

-- The tacho's art (768 px).
local T = 768
local FROM, TO, MAX = -135, 135, 9000
local DRUMS = { 264, 520, 240, 54 } -- x, y, w, h: seven drums, the last tenths
local SHIFT = { 600, 128, 150 } -- the shift light's centre and size

local Street = {}
Street.id = "street"
Street.name = "STREET"

local SHOUT = W.font("BuilderSans", Enum.FontWeight.Heavy, true)
local LABEL = W.font("BuilderSans", Enum.FontWeight.Bold)

-- Places o in the cluster by its top left and size, as fractions of the
-- tacho's size (the readout sits outside it).
local function inCluster(o: GuiObject, x: number, y: number, w: number, h: number)
	o.AnchorPoint = Vector2.new(0, 0)
	o.Position = UDim2.fromScale(x, y)
	o.Size = UDim2.fromScale(w, h)
end

function Street.buildHud(gui: ScreenGui, touch: boolean, _api: any): any
	local root = W.frame(gui, "Street")
	root.Size = UDim2.fromScale(1, 1)
	local glow = W.edgeGlow(root)
	local top = GuiService:GetGuiInset().Y

	local cluster = W.frame(root, "Cluster")
	W.square(cluster, if touch then 0.38 else 0.36)
	if touch then
		cluster.AnchorPoint = Vector2.new(1, 0)
		cluster.Position = UDim2.new(0.885, 0, 0, top + 2)
	else
		cluster.AnchorPoint = Vector2.new(1, 1)
		cluster.Position = UDim2.new(1, -24, 1, -18)
	end
	local tacho = I.dial(cluster, "Tacho", {
		face = Art.tachoFace,
		needle = Art.needle,
		shadow = Art.needleShadow,
		peak = Art.peak,
		glass = Art.tachoGlass,
		fromDeg = FROM,
		toDeg = TO,
		max = MAX,
		jitterAbove = 6650,
	})
	tacho.root.Size = UDim2.fromScale(1, 1)
	local odo = I.drums(tacho.under, "Odo", {
		strip = Art.drum,
		lastStrip = Art.drumTenths,
		shade = Art.drumShade,
		count = 7,
		gap = 0.1,
	})
	I.placeTL(odo.root, T, DRUMS[1], DRUMS[2], DRUMS[3], DRUMS[4])
	local shift = I.layer(cluster, "Shift", Art.shiftOff, 6)
	I.place(shift, T, SHIFT[1], SHIFT[2], SHIFT[3], SHIFT[3])

	local tyre = I.dial(cluster, "Tyre", {
		face = Art.tyreFace,
		needle = Art.podNeedle,
		shadow = Art.podNeedleShadow,
		glass = Art.podGlass,
		fromDeg = -120,
		toDeg = 120,
		max = 100,
		freq = 1.5,
		damp = 0.9,
	})
	tyre.root.AnchorPoint = Vector2.new(0.5, 0.5)
	tyre.root.Size = UDim2.fromScale(0.395, 0.395)
	tyre.root.Position = if touch then UDim2.fromScale(-0.04, 0.658) else UDim2.fromScale(-0.04, 0.34)
	tyre.root.ZIndex = 2

	-- The gear and the speed, big and italic.
	local gear = I.chars(cluster, "Gear", { atlas = Art.gear, order = "123456RN", cell = Vector2.new(112, 160), cols = 8, count = 1 })
	local speed = I.chars(cluster, "Speed", { atlas = Art.speed, order = "0123456789", cell = Vector2.new(80, 150), cols = 10, count = 3 })
	local kmh = I.layer(cluster, "Kmh", Art.kmh, 1)
	if touch then
		inCluster(gear.root, -0.1, 1.0, 0.24, 0.343)
		inCluster(speed.root, 0.16, 1.02, 0.5, 0.31)
		inCluster(kmh, 0.42, 1.32, 0.3, 0.11)
	else
		inCluster(gear.root, -0.94, 0.5, 0.24, 0.343)
		inCluster(speed.root, -0.68, 0.52, 0.5, 0.31)
		inCluster(kmh, -0.44, 0.83, 0.3, 0.11)
	end
	local gearScale = Instance.new("UIScale")
	gearScale.Parent = gear.root
	local gearPop = Motion.spring(1, 6, 0.4)
	local lastGear = 0

	local displays = Display.build(root, touch, {
		panel = Art.board,
		mini = Art.mini,
		dots = Art.dots,
		lit = LED,
		dim = LED_DIM,
		hot = HOT,
		angleBar = true,
		flyFont = SHOUT,
		flyColor = WHITE,
		flyStroke = INK,
	})

	local shout = W.shout(root, "Shout", {
		font = SHOUT,
		color = WHITE,
		stroke = INK,
		strokeThickness = 5,
		subFont = LABEL,
		subColor = LED,
		tilt = -6,
	})
	W.box(shout.root, 0.56, 0.22)
	W.at(shout.root, if touch then 0.42 else 0.36, 0.46)

	local glowAmt = Motion.spring(0, 2, 1)
	local flash = LED
	local flashUntil = 0
	local clock = 0

	local function update(v: any, dt: number)
		clock += dt
		local now = os.clock()
		tacho.set(v.rpm)
		tacho.update(dt)
		odo.set(v.odo * 10)
		odo.update(dt)
		-- Shift light: on near the limiter, flashing on it.
		local onAt = v.redline - 600
		local lit = v.rpm >= onAt and (v.rpm < v.redline - 150 or (clock * 8) % 1 < 0.5)
		shift.Image = if lit then Art.shiftOn else Art.shiftOff
		tyre.set(v.heat * 100)
		tyre.update(dt)

		local g = if v.gear == -1 then "R" elseif v.gear == 0 then "N" else tostring(v.gear)
		gear.set(g)
		if v.gear ~= lastGear then
			lastGear = v.gear
			Motion.kick(gearPop, 7)
		end
		gearScale.Scale = Motion.step(gearPop, 1, dt)
		speed.set(tostring(math.clamp(math.floor(v.speed + 0.5), 0, 999)))

		displays.update(v, dt)
		local heat = math.clamp((v.mult - 1) / math.max(v.multMax - 1, 1), 0, 1)
		local want = if v.sliding then 0.06 + 0.2 * heat else 0
		local gl = Motion.step(glowAmt, want, dt)
		glow.set(if now < flashUntil then flash else LED, if now < flashUntil then 0.35 else gl)
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
			flash, flashUntil = LED, now + 0.4
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

function Street.buildControls(gui: ScreenGui, api: any): any
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
		pillSlice = Rect.new(40, 30, 260, 82),
		leanTrack = Art.leanTrack,
		leanKnob = Art.leanKnob,
		font = LABEL,
		text = Color3.fromRGB(233, 230, 223),
		litText = LED,
	})
end

return Street
