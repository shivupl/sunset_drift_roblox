--!strict
-- KABRIS (hud-variants, 2026-10-07): ARCADE's layout as the box Caprice
-- ("kabris"), the hajwala classic. After the 1977-90 cluster:
--
--   Housing    a wide chrome-trimmed cluster, a walnut band across the top.
--   Sweep      the speedometer: an orange needle that runs sideways along
--              a km/h scale (the MPH scale under it in blue), the
--              odometer's drums under it.
--   TYRE       the left pod, a fuel gauge's arc from C to H: a slide warms
--              the tyres, grip cools them.
--   Lamps      text lamps in the right pod: BRAKE with the handbrake, NATL
--              on two wheels, TEMP when the tyres are hot, SHIFT near the
--              limiter (flashing on it).
--   Gears      the PRND strip, here R N 1..6, its pointer sliding along.
--   Display    the drift score on a vacuum-fluorescent display (14
--              segments, a grid mesh over them), as the dash's clock and
--              radio were; the cash on a small one.
-- Phone: ARCADE's controls as Brougham trim (ArcadeControls): chrome-
-- trimmed pedals, a walnut and chrome pad with a red pearl spinner knob, a
-- PARK T-handle, a chrome pull knob for the natl that lights green.
-- The art is art/hud/kabris/make.py; its layout numbers are mirrored here.
-- The odometer's drums are STREET's.
local GuiService = game:GetService("GuiService")

local HudLab = script.Parent.Parent
local W = require(HudLab:WaitForChild("Widgets"))
local I = require(HudLab:WaitForChild("Instruments"))
local Motion = require(HudLab:WaitForChild("Motion"))
local Controls = require(HudLab:WaitForChild("ArcadeControls"))
local Display = require(HudLab:WaitForChild("DotDisplay"))
local ArtAll = require(HudLab:WaitForChild("Art"))
local Art = ArtAll.kabris

local VFD = Color3.fromRGB(93, 255, 210)
local VFD_DIM = Color3.fromRGB(10, 38, 32)
local VFD_HOT = Color3.fromRGB(220, 255, 120)
local CHROME = Color3.fromRGB(236, 238, 241)
local INK = Color3.fromRGB(10, 10, 12)
local GREEN = Color3.fromRGB(92, 255, 122)
local RED = Color3.fromRGB(255, 58, 36)

-- The housing's art (1000x320) and what sits on it.
local HW, HH = 1000, 320
local SPEED_X = { 310, 690 } -- 0 and SPEED_MAX km/h
local SPEED_MAX = 220
local NEEDLE_Y = 102
local DRUMS = { 420, 180, 160, 34 }
local POD_PIVOT = { 140, 236 }
local POD_FROM, POD_TO = -52, 52
local GEAR_X = { 330, 670 } -- R .. 6, eight even steps
local POINTER_Y = 242
local LAMPS = { { 812, 112 }, { 908, 112 }, { 812, 190 }, { 908, 190 } } -- brake, natl, temp, shift

local Kabris = {}
Kabris.id = "kabris"
Kabris.name = "KABRIS"

local ARABIC = W.font("BuilderSans", Enum.FontWeight.Heavy)
local WIDE = W.font("Michroma", Enum.FontWeight.Regular)

local function rectIn(o: GuiObject, x: number, y: number, w: number, h: number)
	o.AnchorPoint = Vector2.new(0.5, 0.5)
	o.Position = UDim2.fromScale(x / HW, y / HH)
	o.Size = UDim2.fromScale(w / HW, h / HH)
end

function Kabris.buildHud(gui: ScreenGui, touch: boolean, _api: any): any
	local root = W.frame(gui, "Kabris")
	root.Size = UDim2.fromScale(1, 1)
	local glow = W.edgeGlow(root)
	local top = GuiService:GetGuiInset().Y

	-- The cluster: top right under the cash on a phone (left of the
	-- handbrake), bottom right on a monitor.
	local housing = W.frame(root, "Cluster")
	if touch then
		W.box(housing, 0.72, 0.72 * HH / HW)
		housing.AnchorPoint = Vector2.new(1, 0)
		housing.Position = UDim2.new(0.885, 0, 0.12, top)
	else
		W.box(housing, 0.95, 0.95 * HH / HW)
		housing.AnchorPoint = Vector2.new(1, 1)
		housing.Position = UDim2.new(1, -24, 1, -18)
	end
	I.layer(housing, "Housing", Art.housing, 1)
	local odo = I.drums(housing, "Odo", {
		strip = ArtAll.street.drum,
		lastStrip = ArtAll.street.drumTenths,
		shade = ArtAll.street.drumShade,
		count = 7,
		gap = 0.1,
	})
	odo.root.AnchorPoint = Vector2.new(0, 0)
	odo.root.Position = UDim2.fromScale(DRUMS[1] / HW, DRUMS[2] / HH)
	odo.root.Size = UDim2.fromScale(DRUMS[3] / HW, DRUMS[4] / HH)
	odo.root.ZIndex = 2

	local sweepImg = I.layer(housing, "Sweep", Art.sweep, 3)
	rectIn(sweepImg, SPEED_X[1], NEEDLE_Y, 40, 120)
	local sweep = I.slide(sweepImg, SPEED_X[1] / HW, SPEED_X[2] / HW, 3.2, 0.6)

	local podNeedle = I.layer(housing, "TyreNeedle", Art.podNeedle, 3)
	rectIn(podNeedle, POD_PIVOT[1], POD_PIVOT[2], 320, 320)
	local podSpring = Motion.spring(0, 1.5, 0.9)

	local pointerImg = I.layer(housing, "Pointer", Art.pointer, 3)
	rectIn(pointerImg, GEAR_X[1], POINTER_Y, 40, 32)
	local pointer = I.slide(pointerImg, GEAR_X[1] / HW, GEAR_X[2] / HW, 5, 0.45)

	local lamps: { I.Lamp } = {}
	for i, art in { Art.lampBrake, Art.lampNatl, Art.lampTemp, Art.lampShift } do
		local l = I.lamp(housing, "Lamp" .. i, art)
		rectIn(l.root, LAMPS[i][1], LAMPS[i][2], 112, 70)
		table.insert(lamps, l)
	end
	I.layer(housing, "Glass", Art.glass, 4)

	local displays = Display.build(root, touch, {
		panel = Art.vfd,
		mini = Art.vfdMini,
		dots = Art.seg,
		lit = VFD,
		dim = VFD_DIM,
		hot = VFD_HOT,
		angleBar = false,
		overlay = Art.vfdOver,
		miniOverlay = Art.vfdMiniOver,
		flyFont = ARABIC,
		flyColor = VFD,
		flyStroke = INK,
	})

	local shout = W.shout(root, "Shout", {
		font = ARABIC,
		color = CHROME,
		stroke = INK,
		strokeThickness = 5,
		subFont = WIDE,
		subColor = VFD,
		tilt = -4,
	})
	W.box(shout.root, 0.56, 0.22)
	W.at(shout.root, if touch then 0.42 else 0.36, 0.46)

	local glowAmt = Motion.spring(0, 2, 1)
	local flash = VFD
	local flashUntil = 0
	local clock = 0

	local function update(v: any, dt: number)
		clock += dt
		local now = os.clock()
		-- Pegs at the end of the scale, as the real one does past 85 mph.
		sweep.set(math.clamp(v.speed / SPEED_MAX, 0, 1))
		sweep.update(dt)
		odo.set(v.odo * 10)
		odo.update(dt)
		podNeedle.Rotation = POD_FROM + (POD_TO - POD_FROM) * Motion.step(podSpring, v.heat, dt)
		-- R, N, then 1..6.
		local step = if v.gear == -1 then 0 elseif v.gear <= 0 then 1 else math.min(v.gear, 6) + 1
		pointer.set(step / 7)
		pointer.update(dt)

		local nearLimit = v.rpm >= v.redline - 600
		local onLimit = v.rpm >= v.redline - 150
		lamps[1].set(if v.handbrake then "on" else "off")
		lamps[2].set(if v.natl then "on" else "off")
		lamps[3].set(if v.heat > 0.8 then "on" else "off")
		lamps[4].set(if onLimit then "blink" elseif nearLimit then "on" else "off")
		for _, l in lamps do
			l.update(dt)
		end

		displays.update(v, dt)
		local heat = math.clamp((v.mult - 1) / math.max(v.multMax - 1, 1), 0, 1)
		local want = if v.sliding then 0.05 + 0.18 * heat else 0
		local g = Motion.step(glowAmt, want, dt)
		glow.set(if now < flashUntil then flash else VFD, if now < flashUntil then 0.35 else g)
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

function Kabris.buildControls(gui: ScreenGui, api: any): any
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
		font = WIDE,
		text = Color3.fromRGB(233, 230, 223),
		litText = VFD,
	})
end

return Kabris
