--!strict
-- The driving HUD and the phone controls: layout D (StreetHud.luau draws
-- the HUD, LayoutD.luau the controls) in one of its finishes (Finishes.luau:
-- STREET D, SODIUM, CARBON). It began as a trial of HUD styles
-- (hud-variants, 2026-10-07: PRO, MIDNIGHT, ARCADE, then KRUZER, STREET,
-- KABRIS, then STREET D and GHOST on the owner's own mobile layout); on
-- 2026-10-10 the owner kept STREET D and had the rest removed, the old
-- CLASSIC HUD and controls with them ("remove all the other HUD layouts we
-- have and keep this"), then asked for "a couple variants of the same
-- deisgn i can cycle through".
--
-- Switching finish: the STYLE button on screen, U on a keyboard, the HUD
-- STYLE row in the menu's Settings tab (SettingsPanel), or the LocalPlayer
-- attribute HudVariant (a finish's id). Hud.luau and Input/Touch.luau hand
-- each update, flash and binding here.
--
-- The motion (Motion) and the controls' behaviour (Widgets) are shared:
-- pedals give part throttle low on the plate, the needle overshoots, numbers
-- roll, the edge of the screen glows with the chain. Events (a 360, a natl,
-- a big chain, banked, dropped) are shouted, the Arabic as the scene says it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local Input = require(script.Parent:WaitForChild("Input"))
local Widgets = require(script:WaitForChild("Widgets"))
local Finishes = require(script:WaitForChild("Finishes"))
local StreetHud = require(script:WaitForChild("StreetHud"))
local LayoutD = require(script:WaitForChild("LayoutD"))

local HudLab = {}

export type View = {
	speed: number, -- km/h
	gear: number, -- -1 reverse
	rpm: number,
	angle: number, -- degrees, signed: + velocity right of heading
	sliding: boolean,
	points: number,
	mult: number,
	multMax: number,
	natl: boolean,
	cash: number,
	best: number,
	serverBest: number,
}

-- What the HUD and the controls hand back.
export type Hud = {
	update: (view: View, dt: number) -> (),
	event: (kind: string, a: number, b: number) -> (),
	destroy: () -> (),
}

export type Controls = {
	update: (dt: number) -> (),
	setNatl: (ready: boolean, side: number) -> (),
	destroy: () -> (),
}

-- What the controls write through: Input.raw, as the keyboard does. The
-- NATL buttons are the lean keys, Q and E.
export type Api = {
	throttle: (number) -> (),
	brake: (number) -> (),
	steer: (number) -> (), -- -1..1
	handbrake: (boolean) -> (),
	leanLeft: (boolean) -> (),
	leanRight: (boolean) -> (),
	exit: () -> (),
	reset: () -> (),
	cycle: () -> (), -- the next finish
}

export type Style = { id: string, name: string }

local player = Players.LocalPlayer

local hudGui: ScreenGui? = nil
local hud: Hud? = nil
local hudFor = "" -- finish id and "touch" or "desk", what the HUD was built for
local ctlGui: ScreenGui? = nil
local controls: Controls? = nil
local bound = false -- between bindTouch and unbindTouch: the car is being driven on a phone
local view: View? = nil
local shown = false
local lastClock = os.clock()
-- Events worked out between updates.
local lastMult = 1
local shoutedChain = false

local function finish(): Finishes.Finish
	local id = player:GetAttribute("HudVariant")
	return (if type(id) == "string" then Finishes.byId[id] else nil) or Finishes.list[1]
end

local function isTouch(): boolean
	return UserInputService.TouchEnabled or player:GetAttribute("ForceTouch") == true
end

local api: Api = {
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
	handbrake = function(on: boolean)
		Input.raw.handbrake = on
	end,
	leanLeft = function(on: boolean)
		Input.raw.leanLeft = on
	end,
	leanRight = function(on: boolean)
		Input.raw.leanRight = on
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
	Input.raw.handbrake = false
	Input.raw.throttle, Input.raw.brake = 0, 0
	if Input.raw.source == "touch" then
		Input.raw.steerAnalog = nil
		Input.raw.steerDigital = 0
	end
end

local function buildControls()
	dropControls()
	local g = newGui("HajwalaHudLabControls", 5)
	ctlGui = g
	controls = LayoutD.build(g, api, finish())
end

------------------------------------------------------------------------
-- Finishes.
------------------------------------------------------------------------

-- The new finish's name, shown for a moment whatever switched it.
local toastGui: ScreenGui? = nil
local toastToken = 0
local function toast(text: string)
	local g: ScreenGui = toastGui or newGui("HajwalaHudLabToast", 7)
	toastGui = g
	g:ClearAllChildren()
	toastToken += 1
	local mine = toastToken
	local t = Widgets.text(g, "Toast", text, Widgets.font("BuilderSans", Enum.FontWeight.Heavy), Color3.fromRGB(245, 243, 238))
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.3)
	Widgets.box(t, 0.9, 0.07)
	local stroke = Widgets.stroke(t, Color3.new(0, 0, 0), 2, 0.25)
	task.delay(1.1, function()
		local start = os.clock()
		while toastToken == mine and t.Parent do
			local k = math.clamp((os.clock() - start) / 0.4, 0, 1)
			t.TextTransparency = k
			stroke.Transparency = 0.25 + 0.75 * k
			if k >= 1 then
				t:Destroy()
				break
			end
			task.wait()
		end
	end)
end

local function onSwitch()
	dropHud()
	if bound then
		buildControls()
	end
	toast(`STYLE: {finish().name}`)
end

-- The next finish, from the STYLE button or U.
function HudLab.cycle()
	local cur = finish()
	local i = table.find(Finishes.list, cur) or 0
	player:SetAttribute("HudVariant", Finishes.list[i % #Finishes.list + 1].id)
end

-- The finishes in cycle order, for the Settings row.
function HudLab.styles(): { Style }
	local out: { Style } = {}
	for _, f in Finishes.list do
		table.insert(out, { id = f.id, name = f.name })
	end
	return out
end

function HudLab.current(): string
	return finish().id
end

function HudLab.set(id: string)
	player:SetAttribute("HudVariant", id)
end

------------------------------------------------------------------------
-- The HUD side (Hud.luau delegates).
------------------------------------------------------------------------

function HudLab.update(state: any, score: any)
	local cfg = ConfigLoader.current()
	local records = ReplicatedStorage:FindFirstChild("Records")
	local up = state.twoWheelMode == "lifting" or state.twoWheelMode == "balanced"
	local v: View = {
		speed = state.speedKmh,
		gear = state.gear,
		rpm = state.rpm,
		angle = state.driftAngleDeg,
		sliding = score.active,
		points = score.points,
		mult = score.multiplier,
		multMax = cfg.scoring.chainMax,
		natl = up,
		cash = tonumber(player:GetAttribute("Cash")) or 0,
		best = tonumber(player:GetAttribute("SessionBest")) or 0,
		serverBest = if records then tonumber(records:GetAttribute("BestScore")) or 0 else 0,
	}
	-- The NATL buttons show up once the car can lift and stay while it is
	-- up; the side it is up on lights (rollDeg: + is the right side lower).
	local c = controls
	if c then
		local ready = up or state.speedKmh >= cfg.twoWheel.minLiftSpeedKmh
		c.setNatl(ready, if up then (if state.rollDeg < 0 then -1 else 1) else 0)
	end
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
-- The controls side (Input/Touch.luau delegates).
------------------------------------------------------------------------

function HudLab.bindTouch()
	bound = true
	buildControls()
end

function HudLab.unbindTouch()
	bound = false
	dropControls()
end

------------------------------------------------------------------------

local function frame()
	local now = os.clock()
	local dt = math.min(now - lastClock, 0.1)
	lastClock = now
	if shown then
		local f = finish()
		local key = f.id .. (if isTouch() then ":touch" else ":desk")
		if hudFor ~= key then
			dropHud()
			local g = newGui("HajwalaHudLab", 6)
			hudGui = g
			hud = StreetHud.build(g, isTouch(), f)
			hudFor = key
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
	player:GetAttributeChangedSignal("HudVariant"):Connect(onSwitch)
	UserInputService.InputBegan:Connect(function(io: InputObject, processed: boolean)
		if not processed and io.KeyCode == Enum.KeyCode.U then
			HudLab.cycle()
		end
	end)
	RunService.RenderStepped:Connect(frame)
end

return HudLab
