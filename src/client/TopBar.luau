--!strict
-- The phone's top bar (the owner, 2026-10-11: "format the top button bar
-- with the new setup ... garage, view, style, settings buttons keep 'view'
-- icon as a regular camera"; asked, they kept RESET and let EXIT and UI go):
-- one row right of Roblox's own buttons, from the Driving board on the
-- "Hajwala Menus" canvas. GARAGE opens the car menu and SETTINGS its
-- Settings tab, on foot or driving; RESET, VIEW and STYLE sit between them
-- while you drive. It takes the place of the CARS button and of layout D's
-- round buttons by the cash. Phones only for now (the owner: "still only
-- working on mobile"); a desktop keeps the CARS button and the keys.
--
-- The look is the car picker's (CarPicker/Kit): graphite squares with a
-- hairline edge, the icon over a heavy italic word, GARAGE edged in the
-- picker's green. The icons are art/topbar (one sheet, 128 px cells).
--
-- With CLEAR UI on (ClearUi; the owner, 2026-10-13) the row goes and one
-- small round gear stands in its place, on a phone or a desktop, the way
-- to SETTINGS and the switch that brings everything back.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent:WaitForChild("CarPicker"):WaitForChild("Kit"))
local ClearUi = require(script.Parent:WaitForChild("ClearUi"))

local TopBar = {}

export type Actions = {
	garage: () -> (),
	reset: () -> (),
	view: () -> (),
	style: () -> (),
	settings: () -> (),
}

-- art/topbar/out/topbar_icons.png: GARAGE, RESET, VIEW, STYLE, SETTINGS.
local ICONS = "rbxassetid://115983636701904"
local ICON_CELL = 128

type Spec = { id: string, label: string, icon: number, driving: boolean, accent: boolean }
local SPECS: { Spec } = {
	{ id = "garage", label = "GARAGE", icon = 0, driving = false, accent = true },
	{ id = "reset", label = "RESET", icon = 1, driving = true, accent = false },
	{ id = "view", label = "VIEW", icon = 2, driving = true, accent = false },
	{ id = "style", label = "STYLE", icon = 3, driving = true, accent = false },
	{ id = "settings", label = "SETTINGS", icon = 4, driving = false, accent = false },
}

-- A button's height is Roblox's top bar less this, within these bounds
-- (the CARS button's measure: as tall as Roblox's own buttons); its width
-- is its height times WIDTH, room for SETTINGS.
local INSET = 12
local MIN_H, MAX_H = 36, 48
local WIDTH = 1.22
local GAP = 6
-- How far a press sinks.
local PRESS = 0.92

local player = Players.LocalPlayer
local gui: ScreenGui? = nil
local row: Frame? = nil
local buttons: { [string]: TextButton } = {}
local gear: TextButton? = nil
local shown = true -- no menu open and no garage view
local driving = false

-- Where the row rests (fit), so it can come back down to it.
local rest = UDim2.new()
local SLIDE = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function paint()
	local g = gui
	if not g then
		return
	end
	local was = g.Enabled
	local clear = ClearUi.on()
	g.Enabled = (Kit.isTouch() or clear) and shown
	local r = row
	if r and g.Enabled and not was then
		-- Back after a menu or the garage: down from above the screen, as
		-- the menu's pieces come in from their edges (ui-flow).
		r.Position = rest - UDim2.fromOffset(0, r.AbsoluteSize.Y + 24)
		TweenService:Create(r, SLIDE, { Position = rest }):Play()
	end
	for _, spec in SPECS do
		local b = buttons[spec.id]
		if b then
			b.Visible = not clear and (driving or not spec.driving)
		end
	end
	local ge = gear
	if ge then
		ge.Visible = clear
	end
end

local function fit()
	local r = row
	if not r then
		return
	end
	local bar = GuiService.TopbarInset
	local h = math.clamp(bar.Height - INSET, MIN_H, MAX_H)
	rest = UDim2.fromOffset(bar.Min.X + 8, bar.Min.Y + math.max(bar.Height, h) / 2)
	r.Position = rest
	r.Size = UDim2.fromOffset(0, h)
	for _, b in buttons do
		b.Size = UDim2.fromOffset(math.floor(h * WIDTH), h)
		local corner = b:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0, math.floor(h * 0.26))
		end
		local icon = b:FindFirstChild("Icon") :: ImageLabel?
		if icon then
			local s = math.floor(h * 0.44)
			icon.Size = UDim2.fromOffset(s, s)
		end
		local label = b:FindFirstChild("Label") :: TextLabel?
		if label then
			label.TextSize = math.max(9, math.floor(h * 0.2))
			label.Size = UDim2.new(1, -4, 0, label.TextSize + 2)
		end
	end
	local ge = gear
	if ge then
		-- A little under the squares' height: small.
		local d = math.floor(h * 0.84)
		ge.Size = UDim2.fromOffset(d, d)
		local corner = ge:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0, math.floor(d / 2))
		end
		local icon = ge:FindFirstChild("Icon") :: ImageLabel?
		if icon then
			local s = math.floor(d * 0.56)
			icon.Size = UDim2.fromOffset(s, s)
		end
	end
end

local function button(parent: Frame, spec: Spec, order: number, fn: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = spec.label
	b.LayoutOrder = order
	b.AutoButtonColor = false
	b.Text = ""
	b.BorderSizePixel = 0
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BackgroundTransparency = 0.1
	Kit.gradient(b, Kit.C.panelTop, Kit.C.panelBottom)
	Kit.corner(b, 12)
	if spec.accent then
		Kit.stroke(b, Kit.C.green, 1, 0.45)
	else
		Kit.stroke(b, Color3.new(1, 1, 1), 1, 0.9)
	end
	local scale = Instance.new("UIScale")
	scale.Parent = b
	local icon = Kit.image(b, "Icon", ICONS)
	icon.ImageRectSize = Vector2.new(ICON_CELL, ICON_CELL)
	icon.ImageRectOffset = Vector2.new(spec.icon * ICON_CELL, 0)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.38)
	local label = Kit.text(b, "Label", spec.label, 9, Enum.FontWeight.Heavy, true, if spec.accent then Kit.C.text else Kit.C.tabInk)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.78)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextTruncate = Enum.TextTruncate.None
	local quick = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	b.InputBegan:Connect(function(io: InputObject)
		if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then
			TweenService:Create(scale, quick, { Scale = PRESS }):Play()
		end
	end)
	b.InputEnded:Connect(function(io: InputObject)
		if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then
			TweenService:Create(scale, quick, { Scale = 1 }):Play()
		end
	end)
	b.Activated:Connect(fn)
	b.Parent = parent
	return b
end

-- The gear: round, graphite, the SETTINGS icon alone, shown in the row's
-- place with CLEAR UI on.
local function gearButton(parent: Frame, fn: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = "Gear"
	b.LayoutOrder = 0
	b.AutoButtonColor = false
	b.Text = ""
	b.BorderSizePixel = 0
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BackgroundTransparency = 0.1
	b.Visible = false
	Kit.gradient(b, Kit.C.panelTop, Kit.C.panelBottom)
	Kit.corner(b, 18)
	Kit.stroke(b, Color3.new(1, 1, 1), 1, 0.85)
	local scale = Instance.new("UIScale")
	scale.Parent = b
	local icon = Kit.image(b, "Icon", ICONS)
	icon.ImageRectSize = Vector2.new(ICON_CELL, ICON_CELL)
	icon.ImageRectOffset = Vector2.new(4 * ICON_CELL, 0)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	local quick = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	b.InputBegan:Connect(function(io: InputObject)
		if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then
			TweenService:Create(scale, quick, { Scale = PRESS }):Play()
		end
	end)
	b.InputEnded:Connect(function(io: InputObject)
		if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then
			TweenService:Create(scale, quick, { Scale = 1 }):Play()
		end
	end)
	b.Activated:Connect(fn)
	b.Parent = parent
	return b
end

-- False while a menu is open or the garage view fills the screen
-- (SpawnMenu, which used to show and hide the CARS button the same way).
function TopBar.setShown(on: boolean)
	shown = on
	paint()
end

-- True while the phone controls are up (HudLab.bindTouch / unbindTouch).
function TopBar.setDriving(on: boolean)
	driving = on
	paint()
end

function TopBar.start(actions: Actions)
	local g = Instance.new("ScreenGui")
	g.Name = "HajwalaTopBar"
	g.ResetOnSpawn = false
	-- Placed by GuiService.TopbarInset, in the top bar itself.
	g.IgnoreGuiInset = true
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = 7
	local r = Kit.frame(g, "Row")
	r.AnchorPoint = Vector2.new(0, 0.5)
	r.AutomaticSize = Enum.AutomaticSize.X
	Kit.list(r, false, GAP, Enum.VerticalAlignment.Center)
	local fns: { [string]: () -> () } = {
		garage = actions.garage,
		reset = actions.reset,
		view = actions.view,
		style = actions.style,
		settings = actions.settings,
	}
	for i, spec in SPECS do
		buttons[spec.id] = button(r, spec, i, fns[spec.id])
	end
	gear = gearButton(r, actions.settings)
	row = r
	gui = g
	g.Parent = player:WaitForChild("PlayerGui")
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(fit)
	player:GetAttributeChangedSignal("ForceTouch"):Connect(paint)
	ClearUi.changed(paint)
	fit()
	paint()
end

return TopBar
