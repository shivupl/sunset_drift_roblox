--!strict
-- HUD variants to try (hud-variants, 2026-10-07). The owner, on the first
-- round of theme mockups: "these really arent that good... for the phone it
-- should be actual gas/break pedals and whatnot. i need a way more alive UI",
-- then "just take refference from any of those games, make some better
-- variants for me to try".
--
-- Three variants, each a driving HUD and a set of phone controls, after
-- games the owner named:
--   PRO       CarX Drift Racing 2: a steering wheel, metal pedals, a pull
--             handbrake, a needle tacho, a drift-angle scale.
--   MIDNIGHT  Midnight Racing: Tokyo: a thin white analog tacho with a red
--             needle, a timing bar across the top, chevrons for the slide's
--             side, glass pedals and a slider.
--   ARCADE    Driving Empire: chunky outlined type, an LED speed arc, a
--             bouncing multiplier badge, big coloured pedals and a thumb pad.
-- CLASSIC is the HUD and controls from before (Hud.luau, Touch.luau).
--
-- Round two (2026-10-07), the owner: "all are really good but i like arcade
-- layout. make a few more varients arcade layout but with the actual
-- odometer and stuff, take refference from other games. as it it - feels
-- really ai, need deep UI." So ARCADE's control layout with a real
-- instrument cluster and rendered parts (Instruments.luau, ArcadeControls):
--   KRUZER    Tokyo Xtreme Racer 2025's orange tacho and small gauges, the
--             100-series Land Cruiser's amber cluster: an LCD, an
--             inclinometer for the natl, a dot-matrix drift display, OEM
--             rubber pedals, a leather pad and lever.
--   STREET    Initial D Arcade Stage's white-face tacho with the gear and
--             speed in big italic digits, CarX Street's rolling odometer: a
--             peak needle, a shift light, a tyre-temperature gauge, a red
--             LED drift board, drilled pedals, a missile switch.
--   KABRIS    the box Caprice's cluster (the hajwala classic): a sweep
--             speedometer, a C-to-H tyre gauge, text lamps, a sliding gear
--             pointer, a walnut band; the score on a vacuum-fluorescent
--             display; chrome-trimmed pedals, a spinner knob, a pull knob.
--
-- Switching: the STYLE button on screen, U on a keyboard, or the LocalPlayer
-- attribute HudVariant ("kruzer" | "street" | "kabris" | "arcade" |
-- "pro" | "midnight" | "classic"). Hud.luau and Touch.luau hand over to this module while a
-- variant is on.
--
-- The variants share the motion (Motion) and the controls' behaviour
-- (Widgets): pedals give part throttle low on the plate, the lever and the
-- wheel spring back, the needle overshoots, numbers roll, the edge of the
-- screen glows with the chain. Events (a 360, a natl, a big chain, banked,
-- dropped) are shouted, the Arabic as the scene says it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local Input = require(script.Parent:WaitForChild("Input"))
local Widgets = require(script:WaitForChild("Widgets"))

local HudLab = {}

export type View = {
	speed: number, -- km/h
	gear: number, -- -1 reverse
	rpm: number,
	redline: number,
	angle: number, -- degrees, signed: + velocity right of heading
	sliding: boolean,
	points: number,
	mult: number,
	multMax: number,
	chain: number, -- 1 full .. 0 banking (time left before it banks)
	natl: boolean,
	roll: number, -- degrees, signed
	margin: number, -- degrees left before it tips
	spins: number,
	cash: number,
	best: number,
	serverBest: number,
	holder: string,
	-- For the instrument clusters:
	throttle: number, -- 0..1
	handbrake: boolean,
	odo: number, -- km: the car's mileage when it spawned plus what it has driven
	trip: number, -- km this drive
	heat: number, -- 0..1 tyre heat: a slide warms them, grip cools them
}

-- What a variant's HUD and controls hand back.
export type Hud = {
	update: (view: View, dt: number) -> (),
	event: (kind: string, a: number, b: number) -> (),
	destroy: () -> (),
}

export type Controls = {
	update: (dt: number) -> (),
	setLean: (visible: boolean) -> (),
	setNatl: (on: boolean) -> (),
	destroy: () -> (),
}

-- What controls write through: the same Input.raw the old controls write.
export type Api = {
	throttle: (number) -> (),
	brake: (number) -> (),
	steer: (number) -> (), -- -1..1, already past the deadzone and curve
	steerRaw: (number) -> (), -- -1..1 thumb offset, deadzone and curve applied here
	handbrake: (boolean) -> (),
	lean: (number) -> (), -- -1..1
	natl: () -> (), -- the toggle
	exit: () -> (),
	reset: () -> (),
	cycle: () -> (), -- the next style
	styleName: () -> string,
}

export type Variant = {
	id: string,
	name: string,
	buildHud: (gui: ScreenGui, touch: boolean, api: Api) -> Hud,
	buildControls: (gui: ScreenGui, api: Api) -> Controls,
}

local ORDER = { "kruzer", "street", "kabris", "arcade", "pro", "midnight", "classic" }
-- The trial starts on the newest style, so the owner sees it at once.
local DEFAULT = "kruzer"
local NAMES: { [string]: string } = {
	kruzer = "KRUZER",
	street = "STREET",
	kabris = "KABRIS",
	arcade = "ARCADE",
	pro = "PRO",
	midnight = "MIDNIGHT",
	classic = "CLASSIC",
}

local player = Players.LocalPlayer
local variants: { [string]: Variant } = {}
local switched: { () -> () } = {}

local hudGui: ScreenGui? = nil
local hud: Hud? = nil
local hudFor = "" -- variant id .. touch flag the HUD was built for
local ctlGui: ScreenGui? = nil
local controls: Controls? = nil
local view: View? = nil
local shown = false
local lastClock = os.clock()

-- Two-wheel toggle, as Touch.luau keeps it: on until the car lands.
local natlOn = false
local wasUp = false
-- Events worked out between updates.
local lastMult = 1
local shoutedChain = false
-- The odometer and tyres, kept across style switches.
local odoCar: Model? = nil
local odoKm = 0
local tripKm = 0
local heat = 0
local lastState = os.clock()

local function currentId(): string
	local v = player:GetAttribute("HudVariant")
	if type(v) == "string" and (v == "classic" or variants[v] ~= nil) then
		return v
	end
	return DEFAULT
end

-- Whether a variant (not CLASSIC) is on.
function HudLab.active(): boolean
	return currentId() ~= "classic"
end

local function isTouch(): boolean
	return UserInputService.TouchEnabled or player:GetAttribute("ForceTouch") == true
end

local function setNatl(on: boolean)
	natlOn = on
	Input.raw.twoWheelButton = on
	local c = controls
	if c then
		c.setNatl(on)
	end
end

local function steerCurve(frac: number): number
	local cfg = ConfigLoader.current().input
	local mag = math.abs(frac) / math.max(cfg.touchPadFullAt, 1e-3)
	if mag <= cfg.touchPadDeadzone then
		return 0
	end
	return math.sign(frac) * math.min((mag - cfg.touchPadDeadzone) / (1 - cfg.touchPadDeadzone), 1) ^ cfg.touchPadCurve
end

local api: Api
api = {
	throttle = function(v: number)
		Input.raw.throttle = v
		Input.raw.source = "touch"
	end,
	brake = function(v: number)
		Input.raw.brake = v
		Input.raw.source = "touch"
	end,
	steer = function(v: number)
		Input.raw.steerAnalog = math.clamp(v, -1, 1)
		Input.raw.steerDigital = 0
		Input.raw.source = "touch"
	end,
	steerRaw = function(frac: number)
		Input.raw.steerAnalog = steerCurve(frac)
		Input.raw.steerDigital = 0
		Input.raw.source = "touch"
	end,
	handbrake = function(on: boolean)
		Input.raw.handbrake = on
	end,
	lean = function(frac: number)
		local dead = ConfigLoader.current().input.touchLeanDeadzone
		Input.raw.leanLeft = frac < -dead
		Input.raw.leanRight = frac > dead
	end,
	natl = function()
		setNatl(not natlOn)
	end,
	exit = function()
		Input.pulse("exit")
	end,
	reset = function()
		Input.pulse("reset")
	end,
	cycle = function()
		HudLab.cycle()
	end,
	styleName = function(): string
		return NAMES[currentId()] or "STYLE"
	end,
}

local function newGui(name: string, order: number): ScreenGui
	local g = Instance.new("ScreenGui")
	g.Name = name
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = order
	g.Parent = player:WaitForChild("PlayerGui")
	return g
end

local function dropHud()
	local h = hud
	hud = nil
	hudFor = ""
	if h then
		h.destroy()
	end
	local g = hudGui
	hudGui = nil
	if g then
		g:Destroy()
	end
end

local function dropControls()
	local c = controls
	controls = nil
	if c then
		c.destroy()
	end
	local g = ctlGui
	ctlGui = nil
	if g then
		g:Destroy()
	end
	Input.raw.leanLeft, Input.raw.leanRight = false, false
	Input.raw.twoWheelButton = false
	Input.raw.handbrake = false
	Input.raw.throttle, Input.raw.brake = 0, 0
	if Input.raw.source == "touch" then
		Input.raw.steerAnalog = nil
		Input.raw.steerDigital = 0
	end
	natlOn, wasUp = false, false
end

-- The next style, from the STYLE button or U (skipping any not loaded).
function HudLab.cycle()
	local cur = currentId()
	local i = table.find(ORDER, cur) or 0
	for step = 1, #ORDER do
		local nextId = ORDER[(i + step - 1) % #ORDER + 1]
		if nextId == "classic" or variants[nextId] then
			player:SetAttribute("HudVariant", nextId)
			return
		end
	end
end

-- The car being driven, from the seat (the car is SeatPart.Parent.Parent).
local function drivenCar(): Model?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local car = seat and seat.Parent and seat.Parent.Parent
	return if car and car:IsA("Model") then car else nil
end

-- A used car's mileage, the same for every car of a kind: the odometer's
-- starting point (flavour; what it adds on is the real distance driven).
local function mileage(car: Model): number
	local id = tostring(car:GetAttribute("CarId") or car.Name)
	local h = 7
	for i = 1, #id do
		h = (h * 31 + string.byte(id, i)) % 1000003
	end
	return 60000 + h % 320000 + (h % 10) / 10
end

local function onSwitch()
	dropHud()
	for _, f in switched do
		task.spawn(f)
	end
end

-- Touch.luau listens here to rebuild its controls when the style changes
-- mid-drive.
function HudLab.onSwitched(f: () -> ())
	table.insert(switched, f)
end

------------------------------------------------------------------------
-- The HUD side (Hud.luau delegates while a variant is on).
------------------------------------------------------------------------

function HudLab.update(state: any, score: any)
	local cfg = ConfigLoader.current()
	local records = ReplicatedStorage:FindFirstChild("Records")
	local up = state.twoWheelMode == "lifting" or state.twoWheelMode == "balanced"
	local grace = cfg.scoring.graceSeconds
	local now = os.clock()
	local sdt = math.clamp(now - lastState, 0, 0.1)
	lastState = now
	local car = drivenCar()
	if car ~= odoCar then
		odoCar = car
		tripKm = 0
		if car then
			odoKm = mileage(car)
		end
	end
	local km = state.speedKmh / 3600 * sdt
	odoKm += km
	tripKm += km
	-- Tyre heat: a slide warms them (faster at a bigger angle), they cool
	-- back over half a minute of grip.
	if score.active then
		heat = math.min(1, heat + sdt * (0.05 + 0.12 * math.clamp(math.abs(state.driftAngleDeg) / 60, 0, 1)))
	else
		heat = math.max(0, heat - sdt * 0.035)
	end
	local v: View = {
		speed = state.speedKmh,
		gear = state.gear,
		rpm = state.rpm,
		redline = cfg.drivetrain.redlineRpm,
		angle = state.driftAngleDeg,
		sliding = score.active,
		points = score.points,
		mult = score.multiplier,
		multMax = cfg.scoring.chainMax,
		chain = if score.active then math.clamp(1 - score.graceTime / math.max(grace, 1e-3), 0, 1) else 0,
		natl = up,
		roll = state.rollDeg,
		margin = state.rollMarginDeg,
		spins = state.spinCount,
		cash = tonumber(player:GetAttribute("Cash")) or 0,
		best = tonumber(player:GetAttribute("SessionBest")) or 0,
		serverBest = if records then tonumber(records:GetAttribute("BestScore")) or 0 else 0,
		holder = if records then tostring(records:GetAttribute("BestHolder") or "") else "",
		throttle = state.throttle,
		handbrake = state.handbrake,
		odo = odoKm,
		trip = tripKm,
		heat = heat,
	}
	local prev = view
	view = v
	shown = true
	local h = hud
	if not h then
		return
	end
	-- Events from what changed.
	if v.natl and not (prev and prev.natl) then
		h.event("natl", 0, 0)
	end
	if v.sliding then
		if v.mult > lastMult + 1e-3 then
			h.event("mult", v.mult, 0)
			if v.mult >= 3 and not shoutedChain then
				shoutedChain = true
				h.event("chain", v.mult, 0)
			end
		end
		lastMult = v.mult
	else
		lastMult = 1
		shoutedChain = false
	end
end

function HudLab.flashResult(points: number, cash: number)
	local h = hud
	if h then
		if points > 0 then
			h.event("banked", points, cash)
		else
			h.event("dropped", 0, 0)
		end
	end
end

function HudLab.flashSpin(bonus: number, spins: number)
	local h = hud
	if h then
		h.event("spin", bonus, spins)
	end
end

function HudLab.hide()
	shown = false
	view = nil
	dropHud()
end

------------------------------------------------------------------------
-- The controls side (Touch.luau delegates while a variant is on).
------------------------------------------------------------------------

function HudLab.bindTouch()
	dropControls()
	local variant = variants[currentId()]
	if not variant then
		return
	end
	local g = newGui("HajwalaHudLabControls", 5)
	ctlGui = g
	controls = variant.buildControls(g, api)
	setNatl(false)
	local c = controls
	if c then
		c.setLean(false)
	end
end

function HudLab.unbindTouch()
	dropControls()
end

function HudLab.observe(twoWheelMode: string)
	local up = twoWheelMode == "lifting" or twoWheelMode == "balanced"
	if natlOn and wasUp and not up then
		setNatl(false)
	end
	wasUp = up
end

function HudLab.setLeanVisible(visible: boolean)
	local c = controls
	if c then
		c.setLean(visible)
	end
end

------------------------------------------------------------------------

local function frame()
	local now = os.clock()
	local dt = math.min(now - lastClock, 0.1)
	lastClock = now
	local id = currentId()
	local variant = variants[id]
	if shown and variant then
		local key = id .. (if isTouch() then ":touch" else ":desk")
		if hudFor ~= key then
			dropHud()
			local g = newGui("HajwalaHudLab", 6)
			hudGui = g
			hud = variant.buildHud(g, isTouch(), api)
			hudFor = key
			if not isTouch() then
				-- The trial's one instruction on a keyboard: which style this
				-- is and the key for the next (a phone has its STYLE button).
				local hint = Widgets.text(g, "StyleHint", `STYLE  {NAMES[id]}   ·   U  NEXT`, Widgets.font("BuilderSans", Enum.FontWeight.Bold), Color3.fromRGB(240, 240, 236))
				hint.AnchorPoint = Vector2.new(0.5, 1)
				hint.Position = UDim2.new(0.5, 0, 1, -4)
				Widgets.box(hint, 0.5, 0.026)
				hint.TextTransparency = 0.35
				Widgets.stroke(hint, Color3.new(0, 0, 0), 1, 0.5)
			end
		end
		local h = hud
		local v = view
		if h and v then
			h.update(v, dt)
		end
	end
	local c = controls
	if c then
		c.update(dt)
	end
end

function HudLab.start()
	local folder = script:WaitForChild("Variants")
	for _, m in folder:GetChildren() do
		if m:IsA("ModuleScript") then
			local v = (require :: any)(m) :: Variant
			variants[v.id] = v
		end
	end
	player:GetAttributeChangedSignal("HudVariant"):Connect(onSwitch)
	UserInputService.InputBegan:Connect(function(io: InputObject, processed: boolean)
		if not processed and io.KeyCode == Enum.KeyCode.U then
			HudLab.cycle()
		end
	end)
	RunService.RenderStepped:Connect(frame)
end

-- Shared with the variants so they need not require the parent.
HudLab.Widgets = Widgets

return HudLab
