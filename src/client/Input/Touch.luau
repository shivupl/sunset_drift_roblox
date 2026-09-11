--!strict
-- Phone controls. Draws its own ScreenGui rather than the ContextActionService
-- stock buttons: those are small grey discs with no room for a steering pad.
--
-- Layout, landscape, positions as fractions of the viewport and sizes from
-- its height so a 375-point phone and a 430-point phone feel the same:
--   left thumb   steer pad along the bottom, NATL above it
--   right thumb  GAS in the corner, BRAKE inboard, HAND above GAS, KICK above
--                BRAKE, and the LEAN pair inboard of BRAKE while two-wheel is live
--   top          EXIT RESET LOAD DBG, small, right of the HUD card (the top-left
--                belongs to Roblox's menu and chat window)
--
-- The steer pad is positional: where the thumb sits across the pad is the
-- steer angle, so sliding from one side to the other is a counter-steer
-- without lifting. Input smooths that with input.touchSteerRatePerSec.
--
-- NATL is a toggle here (tap on, tap off) because a held button would pin
-- the thumb that has to keep steering. It clears itself when the car lands.
--
-- Multi-touch: a touch is tracked by its InputObject from the control it
-- began on until UserInputService says it ended, so a thumb that slides off
-- a button still releases it and two thumbs never confuse each other.
--
-- Harness: setting the LocalPlayer attribute ForceTouch = true builds this
-- HUD on a desktop so it can be inspected without the device emulator.
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared.ConfigLoader)
local Input = require(script.Parent)

local Touch = {}
Touch.onDebugToggle = nil :: (() -> ())?

type Spec = {
	name: string,
	title: string,
	x: number, -- centre, fraction of viewport width
	y: number, -- centre, fraction of viewport height (ignored when top is set)
	size: number, -- diameter, fraction of viewport height
	color: Color3,
	top: boolean?, -- sit just under the Roblox top bar instead of at y
}

local GREY = Color3.fromRGB(210, 210, 215)
local LEAN = Color3.fromRGB(150, 145, 255)
local BUTTONS: { Spec } = {
	{ name = "Gas", title = "GAS", x = 0.91, y = 0.78, size = 0.26, color = Color3.fromRGB(80, 225, 120) },
	{ name = "Brake", title = "BRAKE", x = 0.78, y = 0.89, size = 0.18, color = Color3.fromRGB(245, 85, 85) },
	{ name = "Hand", title = "HAND", x = 0.90, y = 0.50, size = 0.21, color = Color3.fromRGB(255, 165, 40) },
	{ name = "Kick", title = "KICK", x = 0.77, y = 0.66, size = 0.16, color = Color3.fromRGB(250, 230, 60) },
	{ name = "Natl", title = "NATL", x = 0.09, y = 0.58, size = 0.17, color = Color3.fromRGB(110, 205, 255) },
	{ name = "LeanLeft", title = "LEAN\n<", x = 0.55, y = 0.87, size = 0.18, color = LEAN },
	{ name = "LeanRight", title = "LEAN\n>", x = 0.66, y = 0.87, size = 0.18, color = LEAN },
	{ name = "Exit", title = "EXIT", x = 0.60, y = 0, size = 0.11, color = GREY, top = true },
	{ name = "Reset", title = "RESET", x = 0.66, y = 0, size = 0.11, color = GREY, top = true },
	{ name = "Reload", title = "LOAD", x = 0.72, y = 0, size = 0.11, color = GREY, top = true },
	{ name = "Debug", title = "DBG", x = 0.78, y = 0, size = 0.11, color = GREY, top = true },
}
local PAD = { x = 0.20, y = 0.84, w = 0.36, h = 0.19 } -- w of viewport width, h of height
local PAD_COLOR = Color3.fromRGB(235, 235, 240)
local LEAN_BUTTONS = { "LeanLeft", "LeanRight" }

local gui: ScreenGui? = nil
local buttons: { [string]: TextButton } = {}
local specs: { [string]: Spec } = {}
local touches: { [InputObject]: string } = {}
local connections: { RBXScriptConnection } = {}
local pad: TextButton? = nil
local knob: Frame? = nil
local padTouch: InputObject? = nil
local natlOn = false
local wasUp = false
local leanVisible = true

local function isPress(io: InputObject): boolean
	return io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1
end

local function style(btn: TextButton, color: Color3, down: boolean)
	btn.BackgroundColor3 = if down then color else Color3.fromRGB(18, 18, 22)
	btn.BackgroundTransparency = if down then 0.1 else 0.45
	btn.TextColor3 = if down then Color3.fromRGB(10, 10, 12) else Color3.new(1, 1, 1)
	local stroke = btn:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
		stroke.Transparency = if down then 0 else 0.3
	end
end

local function setNatl(on: boolean)
	natlOn = on
	Input.raw.twoWheelButton = on
	local b = buttons.Natl
	if b then
		style(b, specs.Natl.color, on)
	end
end

local handlers: { [string]: (boolean) -> () } = {
	Gas = function(down)
		Input.raw.throttle = if down then 1 else 0
		Input.raw.source = "touch"
	end,
	Brake = function(down)
		Input.raw.brake = if down then 1 else 0
		Input.raw.source = "touch"
	end,
	Hand = function(down)
		Input.raw.handbrake = down
	end,
	Kick = function(down)
		if down then
			Input.pulse("clutchKick")
		end
	end,
	Natl = function(down)
		if down then
			setNatl(not natlOn)
		end
	end,
	LeanLeft = function(down)
		Input.raw.leanLeft = down
	end,
	LeanRight = function(down)
		Input.raw.leanRight = down
	end,
	Exit = function(down)
		if down then
			Input.pulse("exit")
		end
	end,
	Reset = function(down)
		if down then
			Input.pulse("reset")
		end
	end,
	Reload = function(down)
		if down then
			Input.pulse("reload")
		end
	end,
	Debug = function(down)
		if down and Touch.onDebugToggle then
			Touch.onDebugToggle()
		end
	end,
}

local function press(name: string, down: boolean)
	local spec = specs[name]
	local btn = buttons[name]
	-- NATL keeps its lit state from the toggle, not the finger.
	if btn and spec and name ~= "Natl" then
		style(btn, spec.color, down)
	end
	local h = handlers[name]
	if h then
		h(down)
	end
end

-- Steer from the thumb's x across the pad. Beyond the pad the value clamps,
-- so a thumb that wanders off the end is still full lock, not nothing.
local function padSteer(px: number)
	local p, k = pad, knob
	if not p or not k then
		return
	end
	local cfg = ConfigLoader.current().input
	local halfW = p.AbsoluteSize.X / 2
	local cx = p.AbsolutePosition.X + halfW
	local dx = (px - cx) / math.max(halfW * cfg.touchPadFullAt, 1)
	local mag = math.abs(dx)
	local steer = 0
	if mag > cfg.touchPadDeadzone then
		steer = math.sign(dx) * math.min((mag - cfg.touchPadDeadzone) / (1 - cfg.touchPadDeadzone), 1) ^ cfg.touchPadCurve
	end
	Input.raw.steerAnalog = steer
	Input.raw.steerDigital = 0
	Input.raw.source = "touch"
	local frac = math.clamp((px - p.AbsolutePosition.X) / math.max(p.AbsoluteSize.X, 1), 0.1, 0.9)
	k.Position = UDim2.fromScale(frac, 0.5)
	k.BackgroundTransparency = 0.05
end

local function padRelease()
	padTouch = nil
	Input.raw.steerAnalog = 0
	Input.raw.steerDigital = 0
	Input.raw.source = "touch"
	if knob then
		knob.Position = UDim2.fromScale(0.5, 0.5)
		knob.BackgroundTransparency = 0.35
	end
end

local function makeButton(parent: ScreenGui, spec: Spec): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = spec.name
	btn.Text = spec.title
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.Position = UDim2.fromScale(spec.x, spec.y)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = btn
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = btn
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.2, 0)
	padding.PaddingRight = UDim.new(0.2, 0)
	padding.PaddingTop = UDim.new(0.26, 0)
	padding.PaddingBottom = UDim.new(0.26, 0)
	padding.Parent = btn
	style(btn, spec.color, false)
	btn.Parent = parent
	table.insert(
		connections,
		btn.InputBegan:Connect(function(io: InputObject)
			if isPress(io) and touches[io] == nil then
				touches[io] = spec.name
				press(spec.name, true)
			end
		end)
	)
	return btn
end

local function makePad(parent: ScreenGui)
	local p = Instance.new("TextButton")
	p.Name = "SteerPad"
	p.Text = ""
	p.AutoButtonColor = false
	p.BorderSizePixel = 0
	p.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	p.BackgroundTransparency = 0.45
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.fromScale(PAD.x, PAD.y)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = p
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = PAD_COLOR
	stroke.Transparency = 0.3
	stroke.Parent = p
	local function arrow(glyph: string, xFrac: number)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Text = glyph
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextColor3 = PAD_COLOR
		l.TextTransparency = 0.35
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(xFrac, 0.5)
		l.Size = UDim2.fromScale(0.12, 0.6)
		l.Parent = p
	end
	arrow("<", 0.08)
	arrow(">", 0.92)
	local tick = Instance.new("Frame")
	tick.Name = "Centre"
	tick.BorderSizePixel = 0
	tick.BackgroundColor3 = PAD_COLOR
	tick.BackgroundTransparency = 0.6
	tick.AnchorPoint = Vector2.new(0.5, 0.5)
	tick.Position = UDim2.fromScale(0.5, 0.5)
	tick.Size = UDim2.new(0, 2, 0.5, 0)
	tick.Parent = p
	local k = Instance.new("Frame")
	k.Name = "Knob"
	k.BorderSizePixel = 0
	k.BackgroundColor3 = PAD_COLOR
	k.BackgroundTransparency = 0.35
	k.AnchorPoint = Vector2.new(0.5, 0.5)
	k.Position = UDim2.fromScale(0.5, 0.5)
	local kc = Instance.new("UICorner")
	kc.CornerRadius = UDim.new(0.5, 0)
	kc.Parent = k
	k.Parent = p
	p.Parent = parent
	pad, knob = p, k
	table.insert(
		connections,
		p.InputBegan:Connect(function(io: InputObject)
			if isPress(io) and padTouch == nil and touches[io] == nil then
				padTouch = io
				padSteer(io.Position.X)
			end
		end)
	)
end

local function layout()
	local g = gui
	if not g then
		return
	end
	local vp = g.AbsoluteSize
	local scale = ConfigLoader.current().input.touchScale
	-- The gui ignores the inset so the pad can hug the bottom edge; the top
	-- row then has to step over Roblox's top bar by hand.
	local inset = GuiService:GetGuiInset()
	for _, spec in BUTTONS do
		local b = buttons[spec.name]
		if b then
			local d = math.floor(vp.Y * spec.size * scale)
			b.Size = UDim2.fromOffset(d, d)
			if spec.top then
				b.Position = UDim2.new(spec.x, 0, 0, inset.Y + d / 2 + 6)
			end
		end
	end
	local p, k = pad, knob
	if p and k then
		local h = math.floor(vp.Y * PAD.h * scale)
		p.Size = UDim2.fromOffset(math.floor(vp.X * PAD.w * scale), h)
		local kd = math.floor(h * 0.78)
		k.Size = UDim2.fromOffset(kd, kd)
	end
end

function Touch.bind()
	local forced = Players.LocalPlayer:GetAttribute("ForceTouch") == true
	if not (UserInputService.TouchEnabled or forced) then
		return
	end
	Touch.unbind()
	local g = Instance.new("ScreenGui")
	g.Name = "HajwalaTouch"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 5
	gui = g
	for _, spec in BUTTONS do
		specs[spec.name] = spec
		buttons[spec.name] = makeButton(g, spec)
	end
	makePad(g)
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	layout()
	table.insert(connections, g:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout))

	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(io: InputObject)
			local pt = padTouch
			if not pt then
				return
			end
			-- A touch keeps its InputObject for its whole life; a mouse drag
			-- (Studio without the emulator) arrives as MouseMovement instead.
			if io == pt or (pt.UserInputType == Enum.UserInputType.MouseButton1 and io.UserInputType == Enum.UserInputType.MouseMovement) then
				padSteer(io.Position.X)
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(io: InputObject)
			local name = touches[io]
			if name then
				touches[io] = nil
				press(name, false)
			end
			if io == padTouch then
				padRelease()
			end
		end)
	)

	natlOn, wasUp = false, false
	leanVisible = true
	Touch.setLeanVisible(false)
end

-- Sizes depend on input.touchScale; VehicleController calls this on reload.
function Touch.relayout()
	layout()
end

-- Called every step with the sim's two-wheel mode: the NATL toggle turns
-- itself off once a lift has ended, so the lean pair goes away with it.
function Touch.observe(twoWheelMode: string)
	local up = twoWheelMode == "lifting" or twoWheelMode == "balanced"
	if natlOn and wasUp and not up then
		setNatl(false)
	end
	wasUp = up
end

-- The lean pair is only on screen while the car is in two-wheel mode.
function Touch.setLeanVisible(visible: boolean)
	if visible == leanVisible then
		return
	end
	leanVisible = visible
	for _, name in LEAN_BUTTONS do
		local btn = buttons[name]
		if btn then
			btn.Visible = visible
		end
	end
	if not visible then
		-- A button that vanishes under a finger never fires its Up event.
		Input.raw.leanLeft, Input.raw.leanRight = false, false
		for io, name in touches do
			if name == "LeanLeft" or name == "LeanRight" then
				touches[io] = nil
			end
		end
	end
end

function Touch.unbind()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	table.clear(touches)
	table.clear(buttons)
	table.clear(specs)
	pad, knob, padTouch = nil, nil, nil
	if gui then
		gui:Destroy()
		gui = nil
	end
	natlOn, wasUp = false, false
	leanVisible = true
	Input.raw.leanLeft, Input.raw.leanRight = false, false
	Input.raw.twoWheelButton = false
	Input.raw.handbrake = false
	Input.raw.throttle, Input.raw.brake = 0, 0
	if Input.raw.source == "touch" then
		Input.raw.steerAnalog = nil
		Input.raw.steerDigital = 0
	end
end

return Touch
