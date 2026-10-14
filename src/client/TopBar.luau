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
-- are also proportionate"). The places carry their words, the tools their
-- icons alone (the canvas's L1; of the four takes tried, the owner,
-- 2026-10-13: "just implement this version but fix the spacing").
--
-- SETTINGS is the gear alone (the owner, 2026-10-13, of four takes, full
-- or compact and the word or the gear: "go with this one"), and CAMERA and
-- STYLE are off the row for now ("forget the style and camera buttons for
-- now"; TOOLS, the code kept). The icons were then made bigger and the
-- pair leaned left to read centred ("make sure the icons are big enough
-- and the text is centered well ... a little less room on the right").
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
-- The row fits the room it has, between Roblox's buttons and the cash
-- (the owner's phone, 2026-10-13: the row ran into the coin; "make sure
-- you are making all these changes so that they adjust dynamically"): it
-- measures what it would need, and if that is more than the room, scales
-- down to fit, never past 0.7, keeping every word. Nothing is sized to a
-- particular screen: the row takes its height from Roblox's top bar
-- inset and its room from where the cash is drawn (any "Cash" frame on
-- screen, the HUD's or a menu's, and its hanging "Coin").
--
-- The icons are art/topbar (one sheet, 128 px cells); STORE's is the
-- garage's plates cell.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent:WaitForChild("CarPicker"):WaitForChild("Kit"))
local Art = require(script.Parent:WaitForChild("CarPicker"):WaitForChild("Art"))
local ClearUi = require(script.Parent:WaitForChild("ClearUi"))

local TopBar = {}

export type Actions = {
	store: () -> (),
	garage: () -> (),
	exit: () -> (),
	view: () -> (),
	style: () -> (),
	settings: () -> (),
}

-- art/topbar/out/topbar_icons.png: GARAGE, RESET, VIEW, STYLE, SETTINGS, EXIT.
local ICONS = "rbxassetid://112507017361383"
-- The garage's sheet (Parts.ICONS): STORE is its plates cell, 3.
local GARAGE_ICONS = "rbxassetid://71924428072059"
local ICON_CELL = 128

-- `page`: the menu page this button opens (lit while it shows); `driving`:
-- only while the phone controls are up; `tool`: CAMERA and STYLE, the
-- icon alone, off the row for now (TOOLS).
type Spec = { id: string, label: string, icon: number, sheet: string, page: string?, driving: boolean, tool: boolean }
local SPECS: { Spec } = {
	{ id = "store", label = "STORE", icon = 3, sheet = GARAGE_ICONS, page = "plates", driving = false, tool = false },
	{ id = "garage", label = "GARAGE", icon = 0, sheet = ICONS, page = "cars", driving = false, tool = false },
	{ id = "settings", label = "SETTINGS", icon = 4, sheet = ICONS, page = "settings", driving = false, tool = false },
	-- Out of the car (the owner, 2026-10-14: "on mobile - need an exit car
	-- button"; a desktop has E): the first driving tab, a group apart.
	{ id = "exit", label = "EXIT", icon = 5, sheet = ICONS, driving = true, tool = false },
	{ id = "view", label = "CAMERA", icon = 2, sheet = ICONS, driving = true, tool = true },
	{ id = "style", label = "STYLE", icon = 3, sheet = ICONS, driving = true, tool = true },
}
local SETTINGS_SPEC = SPECS[3]

-- CAMERA and STYLE on the row while driving; off for now (the owner,
-- 2026-10-13: "forget the style and camera buttons for now").
local TOOLS = false

-- The row sits level with Roblox's own pill (the owner, 2026-10-13: "line
-- the buttons up well with this horizontally"): the pill is not centred
-- in the top bar inset but 12 px down it and 44 tall where the inset is
-- 58 (measured in Studio and on the owner's phone), so the row takes the
-- same fractions of the inset's height, within these bounds.
local PILL_TOP = 12 / 58
local PILL_H = 44 / 58
local MIN_H, MAX_H = 36, 48
-- The tab's own height as a share of the pill's: the icon, the word and
-- the padding keep the pill's measure (`ch`), the tab is this much
-- shorter round them (the owner, 2026-10-14: "buttons should be slightly
-- vertically narrower (text and icon remain the same)"): 40 on 44.
local TAB_SHARE = 40 / 44
-- Between tabs; between the places and the tools (the mock's 5 and 20).
local GAP = 5
local GROUP_GAP = 20
-- How far a press sinks.
local PRESS = 0.92
-- The glass: the tab's white shape nearly clear over a second, fainter
-- copy of it (a tint: white, or green for GARAGE), so the tab reads a
-- shade lighter than the world through it.
local GLASS = 0.9
local RIM = 0.86
-- The icon and the word, as shares of the tab's height (the canvas's row
-- L, measured in the browser: an 18 px icon and an 11 px word on a 44
-- tab, 16 of padding, 8 between them; the tools 42 wide with the icon
-- alone). Roblox draws the word narrower than the browser (no letter
-- spacing), so it is a size up.
-- The icon was 18 on 44 (0.41), the mock's; the owner wanted it bigger.
local ICON_SHARE = 0.5
local WORD_SHARE = 0.27
local PAD_SHARE = 0.36
local TOOL_PAD_SHARE = 0.27
local WORD_GAP_SHARE = 0.18
-- SETTINGS as the gear alone (the mock: a 20 px gear, 13 of padding; the
-- gear bigger with the icons).
local GEAR_ICON_SHARE = 0.55
local GEAR_PAD_SHARE = 0.3
-- An icon's drawing sits inside its box (the sheet's margin and the
-- glyph's own) and the italic word's ink leans past its box's right, so
-- a centred pair reads right of centre (the owner's phone: 10 px clear
-- on the left of STORE, 8 on the right). The padding leans the other way
-- by this share of the height: 2 px on 40 or 44 (3 overshot, measured off
-- a Studio capture: 10 clear on the left, 12 on the right).
local LEAN_SHARE = 0.045
-- The sheet's drawings sit inside a margin of their cell; the icon shows
-- the cell cropped to the drawing, so an 18 px icon draws 18 px.
local ICON_CROP = 22

local player = Players.LocalPlayer

local gui: ScreenGui? = nil
local row: Frame? = nil
local actions: Actions? = nil
type Button = { spec: Spec, b: ImageButton, fill: ImageLabel, gradient: UIGradient, icon: ImageLabel, label: TextLabel?, space: Frame? }
local buttons: { Button } = {}
local gear: TextButton? = nil
local shown = true -- no garage view up
local driving = false
local openPage: string? = nil -- the menu page showing, or nil
local busy = false -- a confirm sheet is up over the menu
local ch = MAX_H -- the content's height: the pill's
local h = MAX_H -- the tab's

-- Where the row rests (fit), so it can come back down to it.
local rest = UDim2.new()
local SLIDE = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- Fitting the room: the row's scale, and a label that measures words.
local rowScale: UIScale? = nil
local scratch: TextLabel? = nil
local MIN_SCALE = 0.7
-- Room kept before the cash and past Roblox's inset.
local MARGIN = 8
-- Whether a tab belongs on the row now: a driving tab only while the
-- phone controls are up, a tool only with TOOLS.
local function up(spec: Spec): boolean
	return (not spec.driving or driving) and (not spec.tool or TOOLS)
end

-- Any driving tab up: the group gap before them is drawn.
local function drivingUp(): boolean
	for _, spec in SPECS do
		if spec.driving and up(spec) then
			return true
		end
	end
	return false
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
		it.b.Visible = not clear and up(spec)
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
	icon.ImageRectSize = Vector2.new(ICON_CELL - 2 * ICON_CROP, ICON_CELL - 2 * ICON_CROP)
	icon.ImageRectOffset = Vector2.new(spec.icon * ICON_CELL + ICON_CROP, ICON_CROP)
	icon.Size = UDim2.fromOffset(size, size)
	return icon
end

local function slice(o: any)
	o.Image = Art.tab
	o.ScaleType = Enum.ScaleType.Slice
	o.SliceCenter = Art.tabSlice
	o.SliceScale = h / Art.tabH
end

-- STORE, GARAGE and EXIT carry their words; SETTINGS is the gear alone, a
-- tool its icon alone.
local function wordsFor(spec: Spec): boolean
	return spec ~= SETTINGS_SPEC and not spec.tool
end

-- A tab's sizes at this height.
local function sizes(): (number, number, number, number, number)
	local iconSize = math.floor(ch * ICON_SHARE + 0.5)
	local wordSize = math.max(8, math.floor(ch * WORD_SHARE + 0.5))
	local pad = math.floor(ch * PAD_SHARE + 0.5)
	local toolPad = math.floor(ch * TOOL_PAD_SHARE + 0.5)
	local gap = math.floor(ch * WORD_GAP_SHARE + 0.5)
	return iconSize, wordSize, pad, toolPad, gap
end

-- The icon and the padding of a tab with the icon alone: a tool's, or
-- SETTINGS as the gear, a touch bigger.
local function aloneSizes(spec: Spec): (number, number)
	if spec == SETTINGS_SPEC then
		return math.floor(ch * GEAR_ICON_SHARE + 0.5), math.floor(ch * GEAR_PAD_SHARE + 0.5)
	end
	local iconSize, _, _, toolPad = sizes()
	return iconSize, toolPad
end

-- A word's width as the tabs draw it.
local function wordWidth(text: string, size: number): number
	local t = scratch
	if not t then
		return #text * size * 0.7
	end
	t.TextSize = size
	t.Text = text
	return t.TextBounds.X
end

-- What a tab would measure, built now.
local function tabWidth(spec: Spec): number
	local iconSize, wordSize, pad, _, gap = sizes()
	if not wordsFor(spec) then
		local alone, aPad = aloneSizes(spec)
		return 2 * aPad + alone
	end
	return 2 * pad + iconSize + gap + wordWidth(spec.label, wordSize)
end

-- What the row would measure, built now, with the driving tabs in or out.
local function naturalWidth(): number
	local total = 0
	local n = 0
	for _, spec in SPECS do
		if up(spec) then
			total += tabWidth(spec)
			n += 1
		end
	end
	if drivingUp() then
		total += GROUP_GAP - 2 * GAP
	end
	return total + GAP * (n - 1)
end

-- The left edge of the cash on screen, from any "Cash" frame showing
-- (the HUD's, a menu's) and the coin hanging off it; nil with none.
local function cashLeft(): number?
	local pg = player:FindFirstChildOfClass("PlayerGui")
	local g = gui
	if not pg then
		return nil
	end
	local left: number? = nil
	for _, screen in pg:GetChildren() do
		if screen:IsA("ScreenGui") and screen.Enabled and screen ~= g then
			for _, d in screen:GetDescendants() do
				if d:IsA("GuiObject") and (d.Name == "Cash" or d.Name == "Coin") and d.Visible and d.AbsoluteSize.X > 0 then
					local x = d.AbsolutePosition.X
					if not left or x < left then
						left = x
					end
				end
			end
		end
	end
	return left
end

-- The room the row has, in its pixels: from where it rests to the cash
-- (or Roblox's inset's end), less a margin. In Studio the LocalPlayer
-- attribute TopRowRoom (a number) stands in for the cash, to try a
-- narrow phone.
local function room(): number
	local forced = player:GetAttribute("TopRowRoom")
	if RunService:IsStudio() and type(forced) == "number" then
		return forced
	end
	local bar = GuiService.TopbarInset
	local limit = bar.Max.X
	local c = cashLeft()
	if c then
		limit = math.min(limit, c)
	end
	return limit - MARGIN - rest.X.Offset
end

-- A slanted glass tab: the rim (the button's own shape), the fill inset a
-- pixel over it (green when lit), the icon and the word in it, the tab as
-- wide as they need. `words`: the word drawn (a place's; a tool has its
-- icon alone).
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
	local iconSize, wordSize, pad, _, gap = sizes()
	-- The pair leaned left to read centred (less padding on the left,
	-- more on the right); an icon alone is centred as it is.
	local lean = if words then math.floor(ch * LEAN_SHARE + 0.5) else 0
	if not words then
		iconSize, pad = aloneSizes(spec)
	end
	Kit.pad(inner, 0, pad + lean, 0, pad - lean) -- top, right, bottom, left
	local l = Kit.list(inner, false, gap, Enum.VerticalAlignment.Center)
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

-- A small round graphite button: the gear (CLEAR UI's way back).
local function smallDisc(parent: Frame, name: string, order: number, fn: () -> ()): TextButton
	local d = math.floor(ch * 0.84)
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

-- The row built again for the height (fit).
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
		exit = a.exit,
		view = a.view,
		style = a.style,
	}
	for i, spec in SPECS do
		local it = slantTab(r, spec, i, fns[spec.id], wordsFor(spec))
		if spec.id == "exit" then
			-- The driving tabs a little apart from the places; the spacer
			-- goes with the first of them (paint hides them on foot).
			it.space = spacer(r, i - 1, GROUP_GAP - 2 * GAP)
		end
		table.insert(buttons, it)
	end
	-- The gear: the SETTINGS icon alone, shown with CLEAR UI on.
	local ge = smallDisc(r, "Gear", 90, a.settings)
	local gi = iconOf(ge, SETTINGS_SPEC, math.floor(ge.Size.X.Offset * 0.56))
	gi.AnchorPoint = Vector2.new(0.5, 0.5)
	gi.Position = UDim2.fromScale(0.5, 0.5)
	gear = ge
	paint()
end

-- The row fitted to its room: scaled down when it needs more, every word
-- kept.
local function refit()
	if not row or ClearUi.on() then
		return
	end
	local have = room()
	local n = naturalWidth()
	local sc = rowScale
	if sc then
		sc.Scale = if n > have and have > 0 then math.max(MIN_SCALE, have / n) else 1
	end
end

-- A refit a moment on, once what moved has laid out.
local pendingFit = false
local function scheduleRefit()
	if pendingFit then
		return
	end
	pendingFit = true
	task.delay(0.1, function()
		pendingFit = false
		refit()
	end)
end

local function fit()
	local r = row
	if not r then
		return
	end
	local bar = GuiService.TopbarInset
	ch = math.clamp(math.floor(bar.Height * PILL_H + 0.5), MIN_H, MAX_H)
	h = math.floor(ch * TAB_SHARE + 0.5)
	-- The row's middle on the pill's, whatever the tab's height.
	rest = UDim2.fromOffset(bar.Min.X + 8, bar.Min.Y + math.floor(bar.Height * PILL_TOP + 0.5) + ch / 2)
	r.Position = rest
	r.Size = UDim2.fromOffset(0, h)
	rebuild()
	refit()
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
	scheduleRefit()
end

-- The menu page showing (Menu.watchPage), or nil: its button is lit.
function TopBar.setOpen(page: string?)
	openPage = page
	paint()
	scheduleRefit()
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
	return g.AbsolutePosition.Y + rest.Y.Offset + ch / 2
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
	local sc = Instance.new("UIScale")
	sc.Parent = r
	rowScale = sc
	-- Measures words as the tabs draw them.
	local t = Kit.text(g, "Scratch", "", 12, Enum.FontWeight.ExtraBold, true)
	t.AutomaticSize = Enum.AutomaticSize.XY
	t.Visible = false
	scratch = t
	row = r
	gui = g
	local pg = player:WaitForChild("PlayerGui")
	g.Parent = pg
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(fit)
	player:GetAttributeChangedSignal("ForceTouch"):Connect(function()
		paint()
		scheduleRefit()
	end)
	player:GetAttributeChangedSignal("TopRowRoom"):Connect(scheduleRefit)
	ClearUi.changed(function()
		paint()
		scheduleRefit()
	end)
	-- The cash comes and goes with the HUD and the menus.
	pg.ChildAdded:Connect(scheduleRefit)
	pg.ChildRemoved:Connect(scheduleRefit)
	fit()
end

return TopBar
