--!strict
-- Phone controls. Draws its own ScreenGui rather than the ContextActionService
-- stock buttons: those are small grey discs with no room for a steering pad.
--
-- Landscape layout, positions as fractions of the viewport and sizes from its
-- height so a 375-point phone and a 430-point phone feel the same.
--
--   left half, bottom    steer pad, thumb position across it is the angle
--   directly above it    lean slider, only while the car is on two wheels
--   left, higher         NATL, the two-wheel toggle
--   bottom right         GAS, with BRAKE inboard of it
--   directly above GAS   HAND, close enough that the thumb slides between
--                        the two without lifting
--   inboard of HAND      KICK, the clutch kick
--   top                  EXIT RESET LOAD DBG, small, right of the HUD card
--
-- Both sliders are positional and spring back to centre when released. The
-- steer pad is analog: sliding from one side to the other is a counter-steer
-- without lifting, smoothed by input.touchSteerRatePerSec. The lean slider is
-- digital past input.touchLeanDeadzone, because the two-wheel balance model
-- wants taps rather than a held axis, so a flick out and back is one tap.
--
-- NATL is a toggle here (tap on, tap off) because a held button would pin the
-- thumb that has to keep steering. It clears itself when the car lands.
--
-- Multi-touch: a touch is tracked by its InputObject from the control it began
-- on until UserInputService says it ended, so a thumb that slides off a button
-- still releases it and two thumbs never confuse each other.
--
-- Harness: setting the LocalPlayer attribute ForceTouch = true builds this HUD
-- on a desktop so it can be inspected without the device emulator.
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

type SliderSpec = {
	name: string,
	x: number,
	y: number,
	w: number, -- fraction of viewport width
	h: number, -- fraction of viewport height
	color: Color3,
	left: string, -- glyph at each end
	right: string,
}

type Slider = {
	frame: TextButton,
	knob: Frame,
	spec: SliderSpec,
	touch: InputObject?,
	move: (frac: number) -> (), -- frac is -1..1 from the centre
	release: () -> (),
}

local GREY = Color3.fromRGB(210, 210, 215)
local PAD_COLOR = Color3.fromRGB(235, 235, 240)
local LEAN_COLOR = Color3.fromRGB(150, 145, 255)

local BUTTONS: { Spec } = {
	{ name = "Gas", title = "GAS", x = 0.91, y = 0.80, size = 0.26, color = Color3.fromRGB(80, 225, 120) },
	{ name = "Brake", title = "BRAKE", x = 0.755, y = 0.86, size = 0.18, color = Color3.fromRGB(245, 85, 85) },
	{ name = "Hand", title = "HAND", x = 0.91, y = 0.545, size = 0.20, color = Color3.fromRGB(255, 165, 40) },
	{ name = "Kick", title = "KICK", x = 0.755, y = 0.62, size = 0.15, color = Color3.fromRGB(255, 90, 200) },
	{ name = "Natl", title = "NATL", x = 0.06, y = 0.45, size = 0.15, color = Color3.fromRGB(110, 205, 255) },
	{ name = "Exit", title = "EXIT", x = 0.60, y = 0, size = 0.11, color = GREY, top = true },
	{ name = "Reset", title = "RESET", x = 0.66, y = 0, size = 0.11, color = GREY, top = true },
	{ name = "Reload", title = "LOAD", x = 0.72, y = 0, size = 0.11, color = GREY, top = true },
	{ name = "Debug", title = "DBG", x = 0.78, y = 0, size = 0.11, color = GREY, top = true },
}
local STEER_SPEC: SliderSpec =
	{ name = "SteerPad", x = 0.20, y = 0.86, w = 0.36, h = 0.17, color = PAD_COLOR, left = "<", right = ">" }
local LEAN_SPEC: SliderSpec =
	{ name = "LeanSlider", x = 0.20, y = 0.655, w = 0.30, h = 0.115, color = LEAN_COLOR, left = "◀", right = "▶" }

local gui: ScreenGui? = nil
local buttons: { [string]: TextButton } = {}
local specs: { [string]: Spec } = {}
local sliders: { [string]: Slider } = {}
local touches: { [InputObject]: string } = {}
local connections: { RBXScriptConnection } = {}
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
		Input.raw.kick = down
	end,
	Natl = function(down)
		if down then
			setNatl(not natlOn)
		end
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
	-- NATL keeps its lit state from the toggle, not from the finger.
	if btn and spec and name ~= "Natl" then
		style(btn, spec.color, down)
	end
	local h = handlers[name]
	if h then
		h(down)
	end
end

-- Steering: the thumb's position across the pad is the angle. Past the end of
-- the pad it clamps, so a thumb that wanders off is still full lock.
local function steerMove(frac: number)
	local cfg = ConfigLoader.current().input
	local mag = math.abs(frac) / math.max(cfg.touchPadFullAt, 1e-3)
	local steer = 0
	if mag > cfg.touchPadDeadzone then
		steer = math.sign(frac) * math.min((mag - cfg.touchPadDeadzone) / (1 - cfg.touchPadDeadzone), 1) ^ cfg.touchPadCurve
	end
	Input.raw.steerAnalog = steer
	Input.raw.steerDigital = 0
	Input.raw.source = "touch"
end

local function steerRelease()
	Input.raw.steerAnalog = 0
	Input.raw.steerDigital = 0
	Input.raw.source = "touch"
end

-- Leaning is digital: past the deadzone in either direction is the same as
-- holding Q or E, and the slider springing back is the release.
local function leanMove(frac: number)
	local dead = ConfigLoader.current().input.touchLeanDeadzone
	Input.raw.leanLeft = frac < -dead
	Input.raw.leanRight = frac > dead
end

local function leanRelease()
	Input.raw.leanLeft = false
	Input.raw.leanRight = false
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

local function makeSlider(parent: ScreenGui, spec: SliderSpec, move: (number) -> (), release: () -> ()): Slider
	local f = Instance.new("TextButton")
	f.Name = spec.name
	f.Text = ""
	f.AutoButtonColor = false
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	f.BackgroundTransparency = 0.45
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(spec.x, spec.y)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = spec.color
	stroke.Transparency = 0.3
	stroke.Parent = f
	local function glyph(ch: string, xFrac: number)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Text = ch
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextColor3 = spec.color
		l.TextTransparency = 0.35
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(xFrac, 0.5)
		l.Size = UDim2.fromScale(0.1, 0.5)
		l.Parent = f
	end
	glyph(spec.left, 0.07)
	glyph(spec.right, 0.93)
	local tick = Instance.new("Frame")
	tick.Name = "Centre"
	tick.BorderSizePixel = 0
	tick.BackgroundColor3 = spec.color
	tick.BackgroundTransparency = 0.6
	tick.AnchorPoint = Vector2.new(0.5, 0.5)
	tick.Position = UDim2.fromScale(0.5, 0.5)
	tick.Size = UDim2.new(0, 2, 0.5, 0)
	tick.Parent = f
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.BorderSizePixel = 0
	knob.BackgroundColor3 = spec.color
	knob.BackgroundTransparency = 0.35
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	local kc = Instance.new("UICorner")
	kc.CornerRadius = UDim.new(0.5, 0)
	kc.Parent = knob
	knob.Parent = f
	f.Parent = parent

	local slider: Slider = { frame = f, knob = knob, spec = spec, touch = nil, move = move, release = release }
	table.insert(
		connections,
		f.InputBegan:Connect(function(io: InputObject)
			if isPress(io) and slider.touch == nil and touches[io] == nil then
				slider.touch = io
				Touch.trackSlider(slider, io.Position.X)
			end
		end)
	)
	sliders[spec.name] = slider
	return slider
end

-- Drive a slider from a screen x: move the knob, report the offset from
-- centre as -1..1.
function Touch.trackSlider(slider: Slider, px: number)
	local f, knob = slider.frame, slider.knob
	local halfW = f.AbsoluteSize.X / 2
	local centre = f.AbsolutePosition.X + halfW
	local frac = math.clamp((px - centre) / math.max(halfW, 1), -1, 1)
	knob.Position = UDim2.fromScale(0.5 + frac * 0.42, 0.5)
	knob.BackgroundTransparency = 0.05
	slider.move(frac)
end

local function releaseSlider(slider: Slider)
	slider.touch = nil
	slider.knob.Position = UDim2.fromScale(0.5, 0.5)
	slider.knob.BackgroundTransparency = 0.35
	slider.release()
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
	for _, slider in sliders do
		local h = math.floor(vp.Y * slider.spec.h * scale)
		slider.frame.Size = UDim2.fromOffset(math.floor(vp.X * slider.spec.w * scale), h)
		local kd = math.floor(h * 0.78)
		slider.knob.Size = UDim2.fromOffset(kd, kd)
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
	makeSlider(g, STEER_SPEC, steerMove, steerRelease)
	makeSlider(g, LEAN_SPEC, leanMove, leanRelease)
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	layout()
	table.insert(connections, g:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout))

	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(io: InputObject)
			for _, slider in sliders do
				local held = slider.touch
				-- A touch keeps its InputObject for its whole life; a mouse
				-- drag (Studio without the emulator) arrives as MouseMovement.
				if
					held
					and (
						io == held
						or (held.UserInputType == Enum.UserInputType.MouseButton1 and io.UserInputType == Enum.UserInputType.MouseMovement)
					)
				then
					Touch.trackSlider(slider, io.Position.X)
				end
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
			for _, slider in sliders do
				if slider.touch == io then
					releaseSlider(slider)
				end
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
-- itself off once a lift has ended, so the lean slider goes away with it.
function Touch.observe(twoWheelMode: string)
	local up = twoWheelMode == "lifting" or twoWheelMode == "balanced"
	if natlOn and wasUp and not up then
		setNatl(false)
	end
	wasUp = up
end

-- The lean slider is only on screen while the car is in two-wheel mode.
function Touch.setLeanVisible(visible: boolean)
	if visible == leanVisible then
		return
	end
	leanVisible = visible
	local slider = sliders[LEAN_SPEC.name]
	if slider then
		slider.frame.Visible = visible
		if not visible then
			-- A control that vanishes under a finger never fires its Up event.
			releaseSlider(slider)
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
	table.clear(sliders)
	if gui then
		gui:Destroy()
		gui = nil
	end
	natlOn, wasUp = false, false
	leanVisible = true
	Input.raw.leanLeft, Input.raw.leanRight = false, false
	Input.raw.twoWheelButton = false
	Input.raw.handbrake = false
	Input.raw.kick = false
	Input.raw.throttle, Input.raw.brake = 0, 0
	if Input.raw.source == "touch" then
		Input.raw.steerAnalog = nil
		Input.raw.steerDigital = 0
	end
end

return Touch
