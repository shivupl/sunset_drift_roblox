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
-- Switching finish: the phone top bar's STYLE (TopBar), U on a keyboard,
-- the HUD STYLE row in the menu's SETTINGS (Menu/Settings), or the
-- LocalPlayer attribute HudVariant (a finish's id). Switching version
-- (Versions.luau: FLOW, SIDE, BOARD): the HUD LAYOUT row in Settings, Y on a
-- keyboard, or the attribute HudLayout (the UI button went with the top bar,
-- 2026-10-11). Switching a desktop's layout (Desk.luau: DASH, STRIP,
-- CLUSTER: where the readouts, the key guide and the top row's tabs go):
-- the PC LAYOUT row in Settings, K, or the attribute HudDesk (desktop-ui,
-- 2026-10-14). Hud.luau and Input/Touch.luau hand each update, flash and
-- binding here. The top bar's VIEW cycles the driving view (CameraViews; V
-- on a keyboard) and the new view's name shows here too.
--
-- The motion (Motion) and the controls' behaviour (Widgets) are shared:
-- pedals give part throttle low on the plate, the needle overshoots, numbers
-- roll, the edge of the screen glows with the chain. Events (a 360, a natl,
-- a big chain, banked, dropped) are shouted, the Arabic as the scene says it.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local Input = require(script.Parent:WaitForChild("Input"))
local CameraViews = require(script.Parent:WaitForChild("CameraViews"))
local Finishes = require(script:WaitForChild("Finishes"))
local Versions = require(script:WaitForChild("Versions"))
local Desk = require(script:WaitForChild("Desk"))
local StreetHud = require(script:WaitForChild("StreetHud"))
local LayoutD = require(script:WaitForChild("LayoutD"))
local Coins = require(script:WaitForChild("Coins"))
local TopBar = require(script.Parent:WaitForChild("TopBar"))
local ClearUi = require(script.Parent:WaitForChild("ClearUi"))
local Kit = require(script.Parent:WaitForChild("CarPicker"):WaitForChild("Kit"))

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
	roll: number, -- degrees, + right side lower
	margin: number, -- degrees left before it tips
	chain: number, -- 1 while sliding, draining to 0 over the grace before it banks; 0 off
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
}

-- `blurb`: a version's word, for Settings' HUD LAYOUT row.
export type Style = { id: string, name: string, blurb: string? }

local player = Players.LocalPlayer

local hudGui: ScreenGui? = nil
local hud: Hud? = nil
local hudFor = "" -- finish, version and "touch" or "desk": what the HUD was built for
local ctlGui: ScreenGui? = nil
local controls: Controls? = nil
local bound = false -- between bindTouch and unbindTouch: the car is being driven on a phone
local view: View? = nil
local shown = false
local lastClock = os.clock()
-- Events worked out between updates. A callout fires at the end of its
-- move (the owner, 2026-10-10: "make sure it pops up at the right time - at
-- the end of the move made"): a 360 as it comes round (Scoring pays it
-- then), two wheels as the car lands, a big chain as the slide banks.
local lastMult = 1
local peakMult = 1
local natlFrom: number? = nil
-- Two wheels for less than this is a wobble, not a ترفيع.
local NATL_STAMP_MIN = 1
-- The chain that earns its callout when it banks.
local CHAIN_STAMP_MIN = 3

local function finish(): Finishes.Finish
	local id = player:GetAttribute("HudVariant")
	return (if type(id) == "string" then Finishes.byId[id] else nil) or Finishes.list[1]
end

local function version(): Versions.Version
	local id = player:GetAttribute("HudLayout")
	return (if type(id) == "string" then Versions.byId[id] else nil) or Versions.list[1]
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
}

-- True while a menu or the garage covers the screen (HudLab.setCovered):
-- the HUD and the phone controls hide under it.
local covered = false

local function newGui(name: string, order: number): ScreenGui
	local g = Instance.new("ScreenGui")
	g.Name = name
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = order
	g.Enabled = not covered and not ClearUi.on()
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

-- The new finish's name, shown for a moment whatever switched it: the
-- menu's and the garage's toast (Parts.toast), a graphite pill with the
-- word in heavy italic, under the top bar (ui-flow, 2026-10-12: it was
-- outlined Builder Sans across the middle, a fourth look).
local toastGui: ScreenGui? = nil
local toastToken = 0
local function toast(text: string)
	local g: ScreenGui = toastGui or newGui("HajwalaHudLabToast", 7)
	toastGui = g
	g:ClearAllChildren()
	toastToken += 1
	local mine = toastToken
	local touch = isTouch()
	local pill = Kit.frame(g, "Toast", Kit.C.panelTop, 0.05)
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, GuiService.TopbarInset.Max.Y + (if touch then 10 else 14))
	pill.AutomaticSize = Enum.AutomaticSize.XY
	Kit.corner(pill, 10)
	local edge = Kit.stroke(pill, Color3.new(1, 1, 1), 1, 0.88)
	Kit.pad(pill, 8, 14, 8, 14)
	local label = Kit.text(pill, "Label", text, if touch then 15 else 17, Enum.FontWeight.ExtraBold, true, Color3.fromHex("#C6AC84"))
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.new()
	label.TextTruncate = Enum.TextTruncate.None
	task.delay(1.1, function()
		if toastToken ~= mine or not pill.Parent then
			return
		end
		local info = TweenInfo.new(0.4)
		TweenService:Create(pill, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, info, { TextTransparency = 1 }):Play()
		TweenService:Create(edge, info, { Transparency = 1 }):Play()
		task.delay(0.4, function()
			if toastToken == mine then
				pill:Destroy()
			end
		end)
	end)
end

local function onSwitch(what: string)
	dropHud()
	if bound then
		buildControls()
	end
	toast(if what == "layout" then `UI: {version().name}` elseif what == "desk" then `PC: {Desk.current().name}` else `STYLE: {finish().name}`)
end

-- The next finish, from the top bar's STYLE or U.
function HudLab.cycle()
	local cur = finish()
	local i = table.find(Finishes.list, cur) or 0
	player:SetAttribute("HudVariant", Finishes.list[i % #Finishes.list + 1].id)
end

-- The next version, from Y.
function HudLab.cycleLayout()
	local cur = version()
	local i = table.find(Versions.list, cur) or 0
	player:SetAttribute("HudLayout", Versions.list[i % #Versions.list + 1].id)
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

-- The versions in cycle order, for the Settings row.
function HudLab.versions(): { Style }
	local out: { Style } = {}
	for _, v in Versions.list do
		table.insert(out, { id = v.id, name = v.name, blurb = v.blurb })
	end
	return out
end

function HudLab.currentVersion(): string
	return version().id
end

function HudLab.setVersion(id: string)
	player:SetAttribute("HudLayout", id)
end

-- A desktop's layouts in cycle order, for Settings' PC LAYOUT row.
function HudLab.desks(): { Style }
	local out: { Style } = {}
	for _, d in Desk.list do
		table.insert(out, { id = d.id, name = d.name, blurb = d.blurb })
	end
	return out
end

function HudLab.currentDesk(): string
	return Desk.current().id
end

function HudLab.setDesk(id: string)
	Desk.set(id)
end

------------------------------------------------------------------------
-- The HUD side (Hud.luau delegates).
------------------------------------------------------------------------

function HudLab.update(state: any, score: any)
	local cfg = ConfigLoader.current()
	local records = ReplicatedStorage:FindFirstChild("Records")
	local up = state.twoWheelMode == "lifting" or state.twoWheelMode == "balanced"
	local grace = math.max(cfg.scoring.graceSeconds, 1e-3)
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
		roll = state.rollDeg,
		margin = state.rollMarginDeg,
		chain = if score.active then math.clamp(1 - score.graceTime / grace, 0, 1) else 0,
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
	view = v
	shown = true
	local h = hud
	-- Events from what changed, worked out whether or not the HUD is up.
	local now = os.clock()
	if up and not natlFrom then
		natlFrom = now
	elseif not up and natlFrom then
		local seconds = now - natlFrom
		natlFrom = nil
		if h and seconds >= NATL_STAMP_MIN and state.twoWheelMode ~= "tipped" then
			h.event("natl", seconds, 0)
		end
	end
	if v.sliding then
		peakMult = math.max(peakMult, v.mult)
		if v.mult > lastMult + 1e-3 and h then
			h.event("mult", v.mult, 0)
		end
		lastMult = v.mult
	else
		lastMult = 1
	end
	if score.banked > 0 then
		if h and peakMult >= CHAIN_STAMP_MIN then
			h.event("chain", peakMult, score.banked)
		end
		peakMult = 1
	elseif score.dropped then
		peakMult = 1
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

-- The cash as this HUD draws it, in `gui` (set up as the HUD's): the menu
-- and the garage show it at the HUD's spot (Coins).
function HudLab.coins(gui: ScreenGui): Coins.Coins
	return Coins.build(gui)
end

-- A menu or the garage covers the screen: the HUD, its edge glow and the
-- phone controls hide under it (the pedals showed through the menu's
-- middle), and come back as it goes. With CLEAR UI on they stay hidden.
function HudLab.setCovered(on: boolean)
	covered = on
	local pg = player:FindFirstChildOfClass("PlayerGui")
	for _, g in { hudGui, ctlGui, toastGui, pg and pg:FindFirstChild("HajwalaHudLabGlow") } do
		if g and g:IsA("ScreenGui") then
			g.Enabled = not on and not ClearUi.on()
		end
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
	TopBar.setDriving(true)
end

function HudLab.unbindTouch()
	bound = false
	dropControls()
	TopBar.setDriving(false)
end

------------------------------------------------------------------------

local function frame()
	local now = os.clock()
	local dt = math.min(now - lastClock, 0.1)
	lastClock = now
	if shown then
		local f = finish()
		local ver = version()
		local key = f.id .. ":" .. ver.id .. (if isTouch() then ":touch" else ":desk:" .. Desk.current().id)
		if hudFor ~= key then
			dropHud()
			local g = newGui("HajwalaHudLab", 6)
			hudGui = g
			hud = StreetHud.build(g, isTouch(), f, ver)
			hudFor = key
			if covered then
				-- Its edge glow is a gui of its own, made enabled.
				HudLab.setCovered(true)
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
	player:GetAttributeChangedSignal("HudVariant"):Connect(function()
		onSwitch("style")
	end)
	player:GetAttributeChangedSignal("HudLayout"):Connect(function()
		onSwitch("layout")
	end)
	player:GetAttributeChangedSignal(Desk.ATTRIBUTE):Connect(function()
		onSwitch("desk")
	end)
	player:GetAttributeChangedSignal(CameraViews.ATTRIBUTE):Connect(function()
		toast(`VIEW: {CameraViews.current().name}`)
	end)
	ClearUi.changed(function()
		HudLab.setCovered(covered)
	end)
	UserInputService.InputBegan:Connect(function(io: InputObject, processed: boolean)
		if processed then
			return
		end
		if io.KeyCode == Enum.KeyCode.U then
			HudLab.cycle()
		elseif io.KeyCode == Enum.KeyCode.Y then
			HudLab.cycleLayout()
		elseif io.KeyCode == Enum.KeyCode.K and not isTouch() and player:GetAttribute("GarageOpen") ~= true then
			-- Not while the garage is up (GaragePanel's GarageOpen): the
			-- HUD would change unseen behind it.
			Desk.cycle()
		end
	end)
	RunService.RenderStepped:Connect(frame)
end

return HudLab
