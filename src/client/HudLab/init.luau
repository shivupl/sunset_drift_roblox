--!strict
-- The driving HUD and the phone controls: STREET D, layout D (StreetHud.luau
-- draws the HUD, LayoutD.luau the controls). It began as a trial of HUD
-- styles (hud-variants, 2026-10-07: PRO, MIDNIGHT, ARCADE, then KRUZER,
-- STREET, KABRIS, then STREET D and GHOST on the owner's own mobile layout);
-- on 2026-10-10 the owner kept STREET D and had the rest removed, the old
-- CLASSIC HUD and controls with them ("remove all the other HUD layouts we
-- have and keep this").
--
-- Hud.luau and Input/Touch.luau hand each update, flash and binding here.
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
	setLean: (visible: boolean) -> (),
	setNatl: (on: boolean) -> (),
	destroy: () -> (),
}

-- What the controls write through: Input.raw, as the keyboard does.
export type Api = {
	throttle: (number) -> (),
	brake: (number) -> (),
	steer: (number) -> (), -- -1..1
	handbrake: (boolean) -> (),
	lean: (number) -> (), -- -1..1
	natl: () -> (), -- the toggle
	exit: () -> (),
	reset: () -> (),
}

local player = Players.LocalPlayer

local hudGui: ScreenGui? = nil
local hud: Hud? = nil
local hudFor = "" -- "touch" or "desk", what the HUD was built for
local ctlGui: ScreenGui? = nil
local controls: Controls? = nil
local view: View? = nil
local shown = false
local lastClock = os.clock()

-- The two-wheel toggle: on until the car lands.
local natlOn = false
local wasUp = false
-- Events worked out between updates.
local lastMult = 1
local shoutedChain = false

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
	dropControls()
	local g = newGui("HajwalaHudLabControls", 5)
	ctlGui = g
	controls = LayoutD.build(g, api)
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
	if shown then
		local key = if isTouch() then "touch" else "desk"
		if hudFor ~= key then
			dropHud()
			local g = newGui("HajwalaHudLab", 6)
			hudGui = g
			hud = StreetHud.build(g, isTouch())
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
	RunService.RenderStepped:Connect(frame)
end

return HudLab
