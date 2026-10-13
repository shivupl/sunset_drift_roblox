--!strict
-- The phone's top row (the owner, 2026-10-11: "format the top button bar
-- with the new setup ... garage, view, style, settings buttons keep 'view'
-- icon as a regular camera"; asked, they kept RESET and let EXIT and UI go):
-- one row right of Roblox's own buttons. GARAGE opens the car menu and
-- SETTINGS its settings, on foot or driving; RESET, VIEW and STYLE sit
-- between them while you drive. Phones only (the owner: "still only
-- working on mobile"); a desktop keeps the CARS button and the keys.
--
-- The row stays up while the menu is open, which hangs under it, and the
-- button of the page showing is lit; tapping it again closes the menu
-- (the owner, 2026-10-13: "when clicking settings or garage the options
-- should stay there and the tabs/menu should just show below"). The row
-- draws over the menu's dim, so the lit button stays crisp, and shades its
-- other buttons itself while the menu is open ("it should darken the
-- other buttons on top"), all of them while a confirm sheet is up. Two rows
-- to try from the canvas's row H, the LocalPlayer attribute TopRow, cycled
-- by the small ROW button at the row's end (temporary):
--   DISCS  (H3) round graphite icons with no words, GARAGE ringed green;
--          the one open widens into a green capsule with its word.
--   TABS   (H4) GARAGE, PLATES and SETTINGS as the kit's slanted tabs,
--          the open one green; the driving tools as squares after them.
--
-- With CLEAR UI on (ClearUi; the owner, 2026-10-13) the row goes and one
-- small round gear stands in its place, on a phone or a desktop, the way
-- to SETTINGS and the switch that brings everything back.
--
-- The look is the car picker's (CarPicker/Kit): graphite with a hairline
-- edge, heavy italic words. The icons are art/topbar (one sheet, 128 px
-- cells); PLATES' is the garage's plates cell.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent:WaitForChild("CarPicker"):WaitForChild("Kit"))
local Art = require(script.Parent:WaitForChild("CarPicker"):WaitForChild("Art"))
local ClearUi = require(script.Parent:WaitForChild("ClearUi"))

local TopBar = {}

export type Actions = {
	garage: () -> (),
	plates: () -> (),
	reset: () -> (),
	view: () -> (),
	style: () -> (),
	settings: () -> (),
}

export type Variant = "discs" | "tabs"
local VARIANTS: { Variant } = { "discs", "tabs" }
TopBar.ATTRIBUTE = "TopRow"

-- art/topbar/out/topbar_icons.png: GARAGE, RESET, VIEW, STYLE, SETTINGS.
local ICONS = "rbxassetid://115983636701904"
-- The garage's sheet (Parts.ICONS): PLATES is its cell 3.
local GARAGE_ICONS = "rbxassetid://71924428072059"
local ICON_CELL = 128

-- `page`: the menu page this button opens (lit while it shows); `driving`:
-- only while the phone controls are up; `tabs`: only in the TABS row.
type Spec = { id: string, label: string, icon: number, sheet: string, page: string?, driving: boolean, tabs: boolean? }
local SPECS: { Spec } = {
	{ id = "garage", label = "GARAGE", icon = 0, sheet = ICONS, page = "cars", driving = false },
	{ id = "plates", label = "PLATES", icon = 3, sheet = GARAGE_ICONS, page = "plates", driving = false, tabs = true },
	{ id = "reset", label = "RESET", icon = 1, sheet = ICONS, driving = true },
	{ id = "view", label = "VIEW", icon = 2, sheet = ICONS, driving = true },
	{ id = "style", label = "STYLE", icon = 3, sheet = ICONS, driving = true },
	{ id = "settings", label = "SETTINGS", icon = 4, sheet = ICONS, page = "settings", driving = false },
}
local SETTINGS_SPEC = SPECS[6]

-- The row sits level with Roblox's own pill (the owner, 2026-10-13: "line
-- the buttons up well with this horizontally"): the pill is not centred
-- in the top bar inset but 12 px down it and 44 tall where the inset is
-- 58 (measured in Studio and on the owner's phone), so the row takes the
-- same fractions of the inset's height, within these bounds.
local PILL_TOP = 12 / 58
local PILL_H = 44 / 58
local MIN_H, MAX_H = 36, 48
local GAP = 6
-- How far a press sinks.
local PRESS = 0.92

local player = Players.LocalPlayer

local gui: ScreenGui? = nil
local row: Frame? = nil
local actions: Actions? = nil
type Button = { spec: Spec, b: GuiButton, icon: ImageLabel, label: TextLabel?, gradient: UIGradient?, stroke: UIStroke?, space: Frame?, shade: Frame? }
local buttons: { Button } = {}
local gear: TextButton? = nil
local switch: TextButton? = nil
local shown = true -- no garage view up
local driving = false
local openPage: string? = nil -- the menu page showing, or nil
local busy = false -- a confirm sheet is up over the menu
local h = MAX_H

-- Where the row rests (fit), so it can come back down to it.
local rest = UDim2.new()
local SLIDE = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function variant(): Variant
	local v = player:GetAttribute(TopBar.ATTRIBUTE)
	return if v == "tabs" then "tabs" else "discs"
end

-- The menu page a button stands for is lit. In DISCS the showroom's two
-- pages are both GARAGE's.
local function litBy(spec: Spec): boolean
	local p = spec.page
	if not p or not openPage then
		return false
	end
	if p == openPage then
		return true
	end
	return variant() == "discs" and p == "cars" and openPage == "plates"
end

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
		-- Back after the garage: down from above the screen, as the menu's
		-- pieces come in from their edges (ui-flow).
		r.Position = rest - UDim2.fromOffset(0, r.AbsoluteSize.Y + 24)
		TweenService:Create(r, SLIDE, { Position = rest }):Play()
	end
	local discs = variant() == "discs"
	for _, it in buttons do
		local spec = it.spec
		it.b.Visible = not clear and (driving or not spec.driving)
		local sp = it.space
		if sp then
			sp.Visible = it.b.Visible
		end
		local on = litBy(spec)
		-- Behind the menu: every button but the lit one, all under a sheet.
		local off = busy or (openPage ~= nil and not on)
		local sh = it.shade
		if sh then
			sh.Visible = off
		end
		it.icon.ImageTransparency = if off then 0.45 else 0
		local lb = it.label
		if lb then
			lb.TextTransparency = if off then 0.45 else 0
		end
		local accent = spec.id == "garage"
		if discs then
			-- A disc, or the open one a capsule with its word.
			it.b.Size = UDim2.fromOffset(if on then math.floor(h * 2.5) else h, h)
			it.b.BackgroundTransparency = if on then 0 else 0.1
			local gr = it.gradient
			if gr then
				gr.Color = if on then ColorSequence.new(Kit.C.greenTop, Kit.C.greenBottom) else ColorSequence.new(Kit.C.panelTop, Kit.C.panelBottom)
			end
			local st = it.stroke
			if st then
				st.Color = if accent and not on then Kit.C.green else Color3.new(1, 1, 1)
				st.Transparency = if on then 1 elseif accent then 0.3 else 0.85
			end
			it.icon.ImageColor3 = if on then Kit.C.inUseInk else Kit.C.text
			local l = it.label
			if l then
				l.Visible = on
			end
		elseif spec.page then
			local ib = it.b :: ImageButton
			local gr = it.gradient
			if gr then
				gr.Enabled = on
			end
			ib.ImageColor3 = Color3.new(1, 1, 1)
			ib.ImageTransparency = if on and not off then 0 elseif on then 0.5 elseif off then 0.97 else 0.92
			it.icon.ImageColor3 = if on then Kit.C.inUseInk else Kit.C.text
			local l = it.label
			if l then
				l.TextColor3 = if on then Kit.C.inUseInk else Kit.C.tabInk
			end
		end
	end
	local ge = gear
	if ge then
		ge.Visible = clear
	end
	local sw = switch
	if sw then
		sw.Visible = not clear
		local sh = sw:FindFirstChild("Shade")
		if sh and sh:IsA("Frame") then
			sh.Visible = openPage ~= nil
		end
	end
end

-- A dark shade over a round or square button while it is behind the menu.
local function shadeOf(b: GuiButton, radius: number): Frame
	local f = Kit.frame(b, "Shade", Color3.new(0, 0, 0), 0.5)
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 5
	f.Visible = false
	Kit.corner(f, radius)
	return f
end

local function pressable(b: GuiButton)
	local scale = Instance.new("UIScale")
	scale.Parent = b
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
end

local function iconOf(parent: GuiObject, spec: Spec, size: number): ImageLabel
	local icon = Kit.image(parent, "Icon", spec.sheet)
	icon.ImageRectSize = Vector2.new(ICON_CELL, ICON_CELL)
	icon.ImageRectOffset = Vector2.new(spec.icon * ICON_CELL, 0)
	icon.Size = UDim2.fromOffset(size, size)
	return icon
end

-- A round graphite button, the icon alone (DISCS; the gear; the ROW
-- switch). A place's word sits beside the icon, shown while it is open
-- (paint widens the disc into a capsule).
local function disc(parent: Frame, spec: Spec?, name: string, order: number, d: number, fn: () -> ()): (TextButton, Button?)
	local b = Instance.new("TextButton")
	b.Name = name
	b.LayoutOrder = order
	b.AutoButtonColor = false
	b.Text = ""
	b.BorderSizePixel = 0
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BackgroundTransparency = 0.1
	b.Size = UDim2.fromOffset(d, d)
	local gradient = Kit.gradient(b, Kit.C.panelTop, Kit.C.panelBottom)
	Kit.corner(b, math.floor(d / 2))
	local stroke = Kit.stroke(b, Color3.new(1, 1, 1), 1, 0.85)
	local shade = shadeOf(b, math.floor(d / 2))
	pressable(b)
	b.Activated:Connect(fn)
	b.Parent = parent
	if not spec then
		return b, nil
	end
	local inner = Kit.frame(b, "Inner")
	inner.Size = UDim2.fromScale(1, 1)
	local l = Kit.list(inner, false, math.floor(d * 0.16), Enum.VerticalAlignment.Center)
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local icon = iconOf(inner, spec, math.floor(d * 0.44))
	local label: TextLabel? = nil
	if spec.page then
		local t = Kit.text(inner, "Label", spec.label, math.max(9, math.floor(d * 0.26)), Enum.FontWeight.Heavy, true, Kit.C.inUseInk)
		t.LayoutOrder = 1
		t.AutomaticSize = Enum.AutomaticSize.X
		t.Size = UDim2.fromScale(0, 1)
		t.TextTruncate = Enum.TextTruncate.None
		t.Visible = false
		label = t
	end
	local it: Button = { spec = spec, b = b, icon = icon, label = label, gradient = gradient, stroke = stroke, shade = shade }
	return b, it
end

-- TABS: a place as the kit's slanted tab, icon and word.
local function slantTab(parent: Frame, spec: Spec, order: number, fn: () -> ()): Button
	local b = Instance.new("ImageButton")
	b.Name = spec.label
	b.LayoutOrder = order
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Image = Art.tab
	b.ScaleType = Enum.ScaleType.Slice
	b.SliceCenter = Art.tabSlice
	b.SliceScale = h / Art.tabH
	b.Size = UDim2.fromOffset(math.floor(h * (if spec.id == "settings" then 2.4 elseif spec.id == "garage" then 2.2 else 2.05)), h)
	local gradient = Kit.gradient(b, Kit.C.greenTop, Kit.C.greenBottom)
	local inner = Kit.frame(b, "Inner")
	inner.Size = UDim2.fromScale(1, 1)
	local l = Kit.list(inner, false, math.floor(h * 0.14), Enum.VerticalAlignment.Center)
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local icon = iconOf(inner, spec, math.floor(h * 0.38))
	local t = Kit.text(inner, "Label", spec.label, math.max(9, math.floor(h * 0.24)), Enum.FontWeight.Heavy, true, Kit.C.tabInk)
	t.LayoutOrder = 1
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.fromScale(0, 1)
	t.TextTruncate = Enum.TextTruncate.None
	pressable(b)
	b.Activated:Connect(fn)
	b.Parent = parent
	return { spec = spec, b = b, icon = icon, label = t, gradient = gradient }
end

-- TABS: a tool as a graphite square with the icon alone.
local function square(parent: Frame, spec: Spec, order: number, fn: () -> ()): Button
	local b = Instance.new("TextButton")
	b.Name = spec.label
	b.LayoutOrder = order
	b.AutoButtonColor = false
	b.Text = ""
	b.BorderSizePixel = 0
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BackgroundTransparency = 0.1
	local d = math.floor(h * 0.86)
	b.Size = UDim2.fromOffset(d, d)
	Kit.gradient(b, Kit.C.panelTop, Kit.C.panelBottom)
	Kit.corner(b, math.floor(d * 0.26))
	Kit.stroke(b, Color3.new(1, 1, 1), 1, 0.9)
	local icon = iconOf(b, spec, math.floor(d * 0.5))
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	local shade = shadeOf(b, math.floor(d * 0.26))
	pressable(b)
	b.Activated:Connect(fn)
	b.Parent = parent
	return { spec = spec, b = b, icon = icon, shade = shade }
end

local function spacer(parent: Frame, order: number, w: number): Frame
	local f = Kit.frame(parent, "Space")
	f.LayoutOrder = order
	f.Size = UDim2.fromOffset(w, 1)
	return f
end

-- The row built again for the variant and the height.
local function rebuild()
	local r, a = row, actions
	if not r or not a then
		return
	end
	for _, c in r:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	table.clear(buttons)
	local fns: { [string]: () -> () } = {
		garage = a.garage,
		plates = a.plates,
		reset = a.reset,
		view = a.view,
		style = a.style,
		settings = a.settings,
	}
	local tabsRow = variant() == "tabs"
	local l = r:FindFirstChildOfClass("UIListLayout")
	if l then
		-- The tabs touch; the discs and the squares sit GAP apart (spacers).
		l.Padding = UDim.new(0, if tabsRow then 1 else GAP)
	end
	for i, spec in SPECS do
		if spec.tabs and not tabsRow then
			continue
		end
		local fn = fns[spec.id]
		if not tabsRow then
			local _, it = disc(r, spec, spec.label, i, h, fn)
			if it then
				table.insert(buttons, it)
			end
		elseif spec.page then
			-- The places first, the tools after them a little apart.
			table.insert(buttons, slantTab(r, spec, i, fn))
		else
			-- Its spacer goes with it (paint hides the tools on foot).
			local sp = spacer(r, 20 + 2 * i - 1, if spec.id == "reset" then 8 else GAP - 1)
			local it = square(r, spec, 20 + 2 * i, fn)
			it.space = sp
			table.insert(buttons, it)
		end
	end
	local small = math.floor(h * 0.84)
	if tabsRow then
		spacer(r, 89, GAP - 1)
	end
	-- The gear: the SETTINGS icon alone, shown with CLEAR UI on.
	local ge = disc(r, nil, "Gear", 90, small, a.settings)
	local gi = iconOf(ge, SETTINGS_SPEC, math.floor(small * 0.56))
	gi.AnchorPoint = Vector2.new(0.5, 0.5)
	gi.Position = UDim2.fromScale(0.5, 0.5)
	gear = ge
	-- Temporary: the ROW switch, cycling the rows to try.
	if tabsRow then
		spacer(r, 98, GAP - 1)
	end
	local sw = disc(r, nil, "Row", 99, small, function()
		local i = table.find(VARIANTS, variant()) or 0
		player:SetAttribute(TopBar.ATTRIBUTE, VARIANTS[i % #VARIANTS + 1])
	end)
	local st = Kit.text(sw, "Label", "ROW", math.max(8, math.floor(h * 0.2)), Enum.FontWeight.Heavy, true, Kit.C.tabInk)
	st.Size = UDim2.fromScale(1, 1)
	st.TextXAlignment = Enum.TextXAlignment.Center
	switch = sw
	paint()
end

local function fit()
	local r = row
	if not r then
		return
	end
	local bar = GuiService.TopbarInset
	h = math.clamp(math.floor(bar.Height * PILL_H + 0.5), MIN_H, MAX_H)
	rest = UDim2.fromOffset(bar.Min.X + 8, bar.Min.Y + math.floor(bar.Height * PILL_TOP + 0.5) + h / 2)
	r.Position = rest
	r.Size = UDim2.fromOffset(0, h)
	rebuild()
end

-- False while the garage view fills the screen (SpawnMenu). The menu
-- leaves the row up: it hangs under it.
function TopBar.setShown(on: boolean)
	shown = on
	paint()
end

-- True while the phone controls are up (HudLab.bindTouch / unbindTouch).
function TopBar.setDriving(on: boolean)
	driving = on
	paint()
end

-- The menu page showing (Menu.watchPage), or nil: its button is lit.
function TopBar.setOpen(page: string?)
	openPage = page
	paint()
end

-- A confirm sheet is up over the menu: the whole row shades.
function TopBar.setBusy(on: boolean)
	busy = on
	paint()
end

-- The row's foot at rest, in AbsolutePosition's pixels (from Roblox's
-- inset, as every gui reports them; this gui ignores the inset, so its
-- own AbsolutePosition is minus the inset), while the row is up; nil when
-- it is not (a desktop, the garage, CLEAR UI). The menu's panels start
-- under it. At rest, not where the row is now: it may be sliding in as
-- the menu opens. Sized to the inset, the row ends just above the menu's
-- gui, so this is mostly 0; it guards a short inset.
function TopBar.foot(): number?
	local g, r = gui, row
	if not g or not r or not g.Enabled or ClearUi.on() then
		return nil
	end
	return g.AbsolutePosition.Y + rest.Y.Offset + h / 2
end

function TopBar.start(a: Actions)
	actions = a
	local g = Instance.new("ScreenGui")
	g.Name = "HajwalaTopBar"
	g.ResetOnSpawn = false
	-- Placed by GuiService.TopbarInset, in the top bar itself.
	g.IgnoreGuiInset = true
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- Over the menu (Menu's DISPLAY_ORDER 20 and its cash at 21): its dim
	-- would cover the row.
	g.DisplayOrder = 22
	local r = Kit.frame(g, "Row")
	r.AnchorPoint = Vector2.new(0, 0.5)
	r.AutomaticSize = Enum.AutomaticSize.X
	Kit.list(r, false, GAP, Enum.VerticalAlignment.Center)
	row = r
	gui = g
	g.Parent = player:WaitForChild("PlayerGui")
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(fit)
	player:GetAttributeChangedSignal("ForceTouch"):Connect(paint)
	player:GetAttributeChangedSignal(TopBar.ATTRIBUTE):Connect(rebuild)
	ClearUi.changed(paint)
	fit()
end

return TopBar
