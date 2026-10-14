--!strict
-- The phone's top row (the owner, 2026-10-11: "format the top button bar
-- with the new setup ... garage, view, style, settings buttons keep 'view'
-- icon as a regular camera"; asked, they kept RESET and let EXIT and UI go):
-- one row right of Roblox's own buttons. Phones only (the owner: "still
-- only working on mobile"); a desktop keeps the CARS button and the keys.
--
-- The row is the kit's slanted tabs as glass (the owner, 2026-10-13, of
-- the TABS row on their phone: "i am a big fan of this one but i think it
-- needs some work"; the canvas's row L): STORE (the plates page, until a
-- store exists), GARAGE (the car menu, ringed green) and SETTINGS, then
-- CAMERA and STYLE while you drive (RESET left the row: "store, garage,
-- settings then camera, style buttons"). Sized to Roblox's pill: the tab
-- 44 tall, the icon 18, the word 11 ("make sure the text and icon sizes
-- are also proportionate"). Two takes to try, each with SETTINGS as a word
-- or as the gear alone, the LocalPlayer attribute TopRow, cycled by the
-- small ROW button at the row's end (temporary):
--   TABS      (L1) the icon beside the word; the tools slanted squares
--             with the icon alone.
--   STACKED   (L3) the icon over a smaller word, the tools with their
--             words too, so the row reads as one set.
--   ...GEAR   the same with SETTINGS as the gear alone.
--
-- The row stays up while the menu is open, which hangs under it, and the
-- button of the page showing is lit; tapping it again closes the menu
-- ("when clicking settings or garage the options should stay there and
-- the tabs/menu should just show below"). The row draws over the menu's
-- dim, so the lit button stays crisp, and shades its other buttons itself
-- while the menu is open ("it should darken the other buttons on top"),
-- all of them while a confirm sheet is up. With CLEAR UI on (ClearUi) the
-- row goes and one small round gear stands in its place, on a phone or a
-- desktop, the way to SETTINGS and the switch that brings everything back.
--
-- The icons are art/topbar (one sheet, 128 px cells); STORE's is the
-- garage's plates cell.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent:WaitForChild("CarPicker"):WaitForChild("Kit"))
local Art = require(script.Parent:WaitForChild("CarPicker"):WaitForChild("Art"))
local ClearUi = require(script.Parent:WaitForChild("ClearUi"))

local TopBar = {}

export type Actions = {
	store: () -> (),
	garage: () -> (),
	view: () -> (),
	style: () -> (),
	settings: () -> (),
}

export type Variant = "tabs" | "tabsgear" | "stacked" | "stackedgear"
local VARIANTS: { Variant } = { "tabs", "tabsgear", "stacked", "stackedgear" }
TopBar.ATTRIBUTE = "TopRow"

-- art/topbar/out/topbar_icons.png: GARAGE, RESET, VIEW, STYLE, SETTINGS.
local ICONS = "rbxassetid://115983636701904"
-- The garage's sheet (Parts.ICONS): STORE is its plates cell, 3.
local GARAGE_ICONS = "rbxassetid://71924428072059"
local ICON_CELL = 128

-- `page`: the menu page this button opens (lit while it shows); `driving`:
-- only while the phone controls are up.
type Spec = { id: string, label: string, icon: number, sheet: string, page: string?, driving: boolean }
local SPECS: { Spec } = {
	{ id = "store", label = "STORE", icon = 3, sheet = GARAGE_ICONS, page = "plates", driving = false },
	{ id = "garage", label = "GARAGE", icon = 0, sheet = ICONS, page = "cars", driving = false },
	{ id = "settings", label = "SETTINGS", icon = 4, sheet = ICONS, page = "settings", driving = false },
	{ id = "view", label = "CAMERA", icon = 2, sheet = ICONS, driving = true },
	{ id = "style", label = "STYLE", icon = 3, sheet = ICONS, driving = true },
}
local SETTINGS_SPEC = SPECS[3]

-- The row sits level with Roblox's own pill (the owner, 2026-10-13: "line
-- the buttons up well with this horizontally"): the pill is not centred
-- in the top bar inset but 12 px down it and 44 tall where the inset is
-- 58 (measured in Studio and on the owner's phone), so the row takes the
-- same fractions of the inset's height, within these bounds.
local PILL_TOP = 12 / 58
local PILL_H = 44 / 58
local MIN_H, MAX_H = 36, 48
-- Between tabs; between the places and the tools.
local GAP = 5
local GROUP_GAP = 10
-- How far a press sinks.
local PRESS = 0.92
-- The glass: the tab's white shape nearly clear over a second, fainter
-- copy of it (a tint: white, or green for GARAGE), so the tab reads a
-- shade lighter than the world through it.
local GLASS = 0.9
local RIM = 0.86
-- The icon and the word, as shares of the tab's height (the canvas's row
-- L: an 18 px drawing and an 11 px word on 44; the stacked word smaller).
-- The sheet's drawings fill about three fifths of their cell, so the
-- icon's cell is drawn bigger than the drawing wanted.
local ICON_SHARE = 0.64
local WORD_SHARE = 0.25
local STACK_ICON_SHARE = 0.58
local STACK_WORD_SHARE = 0.2

local player = Players.LocalPlayer

local gui: ScreenGui? = nil
local row: Frame? = nil
local actions: Actions? = nil
type Button = { spec: Spec, b: ImageButton, fill: ImageLabel, gradient: UIGradient, icon: ImageLabel, label: TextLabel?, space: Frame? }
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
	local i = if type(v) == "string" then table.find(VARIANTS, (v :: any) :: Variant) else nil
	return if i then VARIANTS[i] else "tabs"
end

local function stacked(): boolean
	local v = variant()
	return v == "stacked" or v == "stackedgear"
end

local function gearOnly(): boolean
	local v = variant()
	return v == "tabsgear" or v == "stackedgear"
end

-- The menu page a button stands for is lit.
local function litBy(spec: Spec): boolean
	return spec.page ~= nil and spec.page == openPage
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
		local accent = spec.id == "garage"
		-- The rim (the button's own image) and the fill over it.
		it.b.ImageColor3 = if accent and not on then Kit.C.green else Color3.new(1, 1, 1)
		it.b.ImageTransparency = if on then 1 elseif accent then (if off then 0.88 else 0.72) elseif off then 0.94 else RIM
		it.gradient.Enabled = on
		it.fill.ImageTransparency = if on then (if off then 0.5 else 0) elseif off then 0.96 else GLASS
		local ink = if on then Kit.C.inUseInk elseif accent then Kit.C.green else Kit.C.text
		it.icon.ImageColor3 = ink
		it.icon.ImageTransparency = if off then 0.45 else 0
		local lb = it.label
		if lb then
			lb.TextColor3 = if on then Kit.C.inUseInk elseif accent then Kit.C.green elseif spec.driving then Kit.C.tabInk else Kit.C.text
			lb.TextTransparency = if off then 0.45 else 0
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

local function slice(o: any)
	o.Image = Art.tab
	o.ScaleType = Enum.ScaleType.Slice
	o.SliceCenter = Art.tabSlice
	o.SliceScale = h / Art.tabH
end

-- A slanted glass tab: the rim (the button's own shape), the fill inset a
-- pixel over it (green when lit), the icon and the word in it, the tab as
-- wide as they need. `words`: the word drawn (a tool's only when stacked;
-- SETTINGS' not when the gear stands alone).
local function slantTab(parent: Frame, spec: Spec, order: number, fn: () -> (), words: boolean): Button
	local b = Instance.new("ImageButton")
	b.Name = spec.label
	b.LayoutOrder = order
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.AutomaticSize = Enum.AutomaticSize.X
	b.Size = UDim2.fromOffset(0, h)
	slice(b)
	local fill = Kit.image(b, "Fill", Art.tab, Color3.new(1, 1, 1), GLASS)
	slice(fill)
	fill.Position = UDim2.fromOffset(1, 1)
	fill.Size = UDim2.new(1, -2, 1, -2)
	local gradient = Kit.gradient(fill, Kit.C.greenTop, Kit.C.greenBottom)
	gradient.Enabled = false
	local inner = Kit.frame(b, "Inner")
	inner.AutomaticSize = Enum.AutomaticSize.X
	inner.Size = UDim2.fromOffset(0, h)
	inner.ZIndex = 2
	local up = stacked()
	local iconSize = math.floor(h * (if up then STACK_ICON_SHARE else ICON_SHARE) + 0.5)
	local wordSize = math.max(8, math.floor(h * (if up then STACK_WORD_SHARE else WORD_SHARE) + 0.5))
	if not words then
		-- The icon alone, a little bigger.
		iconSize += 3
	end
	local pad = if words then math.floor(h * 0.36) else math.floor(h * 0.3)
	Kit.pad(inner, 0, pad, 0, pad)
	local l = Kit.list(inner, up and words, if up then 3 else math.floor(h * 0.18), Enum.VerticalAlignment.Center)
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local icon = iconOf(inner, spec, iconSize)
	icon.ZIndex = 2
	local label: TextLabel? = nil
	if words then
		local t = Kit.text(inner, "Label", spec.label, wordSize, Enum.FontWeight.ExtraBold, true)
		t.LayoutOrder = 1
		t.AutomaticSize = Enum.AutomaticSize.X
		t.Size = UDim2.fromOffset(0, wordSize + 2)
		t.TextTruncate = Enum.TextTruncate.None
		t.ZIndex = 2
		label = t
	end
	pressable(b)
	b.Activated:Connect(fn)
	b.Parent = parent
	return { spec = spec, b = b, fill = fill, gradient = gradient, icon = icon, label = label }
end

-- A small round graphite button: the gear (CLEAR UI's way back) and the
-- temporary ROW switch.
local function smallDisc(parent: Frame, name: string, order: number, fn: () -> ()): TextButton
	local d = math.floor(h * 0.84)
	local b = Instance.new("TextButton")
	b.Name = name
	b.LayoutOrder = order
	b.AutoButtonColor = false
	b.Text = ""
	b.BorderSizePixel = 0
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BackgroundTransparency = 0.1
	b.Visible = false
	b.Size = UDim2.fromOffset(d, d)
	Kit.gradient(b, Kit.C.panelTop, Kit.C.panelBottom)
	Kit.corner(b, math.floor(d / 2))
	Kit.stroke(b, Color3.new(1, 1, 1), 1, 0.85)
	local shade = Kit.frame(b, "Shade", Color3.new(0, 0, 0), 0.5)
	shade.Size = UDim2.fromScale(1, 1)
	shade.ZIndex = 5
	shade.Visible = false
	Kit.corner(shade, math.floor(d / 2))
	pressable(b)
	b.Activated:Connect(fn)
	b.Parent = parent
	return b
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
		store = a.store,
		garage = a.garage,
		settings = a.settings,
		view = a.view,
		style = a.style,
	}
	local up, bare = stacked(), gearOnly()
	for i, spec in SPECS do
		local words = if spec.id == "settings" then not bare elseif spec.driving then up else true
		local it = slantTab(r, spec, i, fns[spec.id], words)
		if spec.id == "view" then
			-- The tools a little apart from the places; the spacer goes
			-- with them (paint hides the tools on foot).
			it.space = spacer(r, i - 1, GROUP_GAP - GAP)
		end
		table.insert(buttons, it)
	end
	-- The gear: the SETTINGS icon alone, shown with CLEAR UI on.
	local ge = smallDisc(r, "Gear", 90, a.settings)
	local gi = iconOf(ge, SETTINGS_SPEC, math.floor(ge.Size.X.Offset * 0.56))
	gi.AnchorPoint = Vector2.new(0.5, 0.5)
	gi.Position = UDim2.fromScale(0.5, 0.5)
	gear = ge
	-- Temporary: the ROW switch, cycling the rows to try.
	local sw = smallDisc(r, "Row", 99, function()
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
