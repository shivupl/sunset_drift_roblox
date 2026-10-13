--!strict
-- The menu: CARS, PLATES and SETTINGS (ui-flow, 2026-10-12, the owner:
-- "string together the entire UI ... make a couple different complete
-- layouts but just stop it from being so choppy and disconnected").
--
-- It is drawn by the garage's layouts (Garage/Looks, the one the player
-- picked: Layouts), so the menu and the garage are one frame: the words
-- (here CARS, PLATES, SETTINGS), EXIT and LAYOUT, the coins exactly as the
-- driving HUD has them, the column under the coins, the action at the
-- bottom right, the subject in the middle. Before this the car list was the
-- car picker's own panels and PLATES and SETTINGS were the old spawn
-- menu's, each in its own look and place.
--
-- One motion for all of it (Parts.intro): opening, the world behind blurs
-- and dims and the pieces come in from the edges they live on; a page
-- swaps its column and subject in place, which ease up; closing, they go
-- back out the way they came. Opened over the garage (its SHOP PLATES) the
-- frame is already there, so only the content changes, and EXIT hands the
-- garage back the same way (Menu.watch: the garage hides under the menu).
--
-- SpawnMenu owns opening and closing (M, the CARS button, the top bar),
-- spawning and its cooldown, and the touch controls' modal; this owns the
-- screen.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Client = script.Parent
local Kit = require(Client:WaitForChild("CarPicker"):WaitForChild("Kit"))
local UIKit = require(Client:WaitForChild("UIKit"))
local HudLab = require(Client:WaitForChild("HudLab"))
local Looks = Client:WaitForChild("Garage"):WaitForChild("Looks")
local Types = require(Looks:WaitForChild("Types"))
local Parts = require(Looks:WaitForChild("Parts"))
local Layouts = require(Looks:WaitForChild("Layouts"))
local Showroom = require(script:WaitForChild("Looks"):WaitForChild("Showroom"))
local GarageSounds = require(Client:WaitForChild("Garage"):WaitForChild("GarageSounds"))
local Page = require(script:WaitForChild("Page"))
local Cars = require(script:WaitForChild("Cars"))
local Plates = require(script:WaitForChild("Plates"))
local Settings = require(script:WaitForChild("Settings"))

local Menu = {}

-- Over the garage panel (15) and its coins (16), under the load cover.
local DISPLAY_ORDER = 20
-- How far a finger may travel and still count as a tap (the spawn menu's).
local TAP_SLOP_PX = 14
-- How the world goes behind the menu: the dim and the blur ease in over
-- this, and out a little quicker.
local SCENE_IN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SCENE_OUT = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

export type OpenOptions = {
	-- Opened from a screen in the same frame (the garage's SHOP PLATES): no
	-- slide in, and closing hands that screen back at once, no slide out.
	switch: boolean?,
}

type Tap = { gui: GuiObject, scroll: ScrollingFrame?, onTap: () -> (), onDown: ((boolean) -> ())? }
type Press = { tap: Tap, input: InputObject, origin: Vector2, canvas: Vector2, cancelled: boolean }
type Sheet = { ui: Parts.Sheet, update: () -> () }

local player = Players.LocalPlayer
local hooks: Page.Hooks? = nil
local gui: ScreenGui? = nil
local dim: Frame? = nil
local blur: BlurEffect? = nil
local cashGui: ScreenGui? = nil
local cashPill: Parts.Cash? = nil
local view: Types.View? = nil
local ctxNow: Types.Ctx? = nil
local stageView: Page.Stage? = nil
local toastFn: Parts.Toast? = nil
local pages: { [string]: Page.Page } = {}
local ORDER = { "cars", "plates", "settings" }
local tabs: { Types.TabDef } = {}
local pageId = "cars"
local isOpen = false
-- Closed but still going out (its pieces sliding off): the screen is not
-- given back yet.
local leaving = false
-- Bumped on every open and close: a close's delayed teardown checks it.
local serial = 0
-- Opened with `switch`: closing hands the screen under back at once.
local switched = false
-- Told when the menu takes the screen and when it gives it back (the
-- garage panel hides under it).
local watchers: { (open: boolean) -> () } = {}
local taps: { Tap } = {}
local press: Press? = nil
local sheet: Sheet? = nil

local function tell(open: boolean)
	for _, fn in watchers do
		task.spawn(fn, open)
	end
end

local function page(): Page.Page
	return pages[pageId]
end

local function touch(): boolean
	return Kit.isTouch()
end

local function cashNow(): number
	return tonumber(player:GetAttribute("Cash")) or 0
end

------------------------------------------------------------------------
-- The world behind: dimmed and blurred to the page's measure.
------------------------------------------------------------------------

-- The tweens running on them, so a newer one (or the close's reset) can
-- stop them: a page's blur still easing in after the menu had gone left
-- the world blurred while driving (review, ui-flow).
local sceneTweens: { Tween } = {}

local function stopScene()
	for _, t in sceneTweens do
		t:Cancel()
	end
	table.clear(sceneTweens)
end

local function scene(on: boolean, info: TweenInfo)
	stopScene()
	local p = page()
	local d, b = dim, blur
	if d then
		local t = TweenService:Create(d, info, { BackgroundTransparency = if on then p.dim else 1 })
		table.insert(sceneTweens, t)
		t:Play()
	end
	if b then
		local t = TweenService:Create(b, info, { Size = if on then p.blur else 0 })
		table.insert(sceneTweens, t)
		t:Play()
	end
end

------------------------------------------------------------------------
-- Painting.
------------------------------------------------------------------------

local function refresh()
	local v = view
	if not v or not isOpen then
		return
	end
	v.refresh()
	page().paint()
	local st = stageView
	if st then
		st.refresh()
	end
	local pill = cashPill
	if pill then
		pill.set(Parts.money(cashNow()))
	end
	local s = sheet
	if s then
		s.update()
	end
end

local function closeSheet(which: Sheet?)
	local s = which or sheet
	if s and sheet == s then
		sheet = nil
	end
	if s then
		s.ui.holder:Destroy()
	end
end

-- A fill asked for while the confirm sheet was up (a plate bought lands
-- in the Plates attribute before the buy returns): done once it closes,
-- so the sheet is not torn down mid-purchase.
local fillPending = false

-- The column built again for the page showing.
local function fill()
	local v = view
	if not v or not isOpen then
		return
	end
	if sheet then
		fillPending = true
		return
	end
	fillPending = false
	press = nil
	table.clear(taps)
	v.fill()
end

-- The subject drawn again in the layout's stage.
local function drawStage()
	local old = stageView
	stageView = nil
	if old then
		old.destroy()
	end
	local v = view
	if v then
		stageView = page().stage(v.stage, touch())
	end
end

local function toast(text: string, kind: string)
	if kind == "error" then
		GarageSounds.play("error")
	end
	local t = toastFn
	if t then
		t(text, kind)
	end
end

local function openSheet(info: Parts.SheetInfo, buy: () -> ())
	local g, ctx = gui, ctxNow
	if sheet or not isOpen or not g or not ctx then
		return
	end
	local working = false
	local mine: Sheet
	local function done()
		closeSheet(mine)
		if fillPending then
			fill()
		end
		refresh()
	end
	local ui = Parts.sheet(g, ctx, info, done, function()
		if working or cashNow() < info.price then
			return
		end
		working = true
		mine.update()
		buy()
		working = false
		done()
	end)
	mine = {
		ui = ui,
		update = function()
			ui.update(cashNow(), working)
		end,
	}
	sheet = mine
	mine.update()
end

------------------------------------------------------------------------
-- The screen: the layout, built for the page showing.
------------------------------------------------------------------------

local build: (switch: boolean) -> ()
-- The gui's size the screen was last built for, and when the menu last
-- opened: a size that settles just after opening (a gui enabled for the
-- first time) builds again with the opening's slide, not a settle.
local builtFor = Vector2.zero
local openedAt = 0

-- The layout a page is drawn in: CARS and PLATES the car picker's
-- SHOWROOM (the owner, 2026-10-12, of PICKER, SHOWROOM and FRAME tried:
-- "lets go with showroom for the cars menu"), SETTINGS the screen's
-- (kept apart).
local SHOWROOM: Types.Layout = { id = "showroom", name = "SHOWROOM", build = Showroom.build }
local function layoutFor(id: string): Types.Layout
	return if id == "settings" then Layouts.current() else SHOWROOM
end

local function choosePage(id: string)
	if sheet or not isOpen or not pages[id] then
		return
	end
	if id == pageId then
		return
	end
	GarageSounds.play("tab")
	local was = pageId
	pageId = id
	page().shown()
	if layoutFor(was) ~= layoutFor(id) then
		-- Another look: the screen built again, coming in from its edges.
		build(false)
		scene(true, SCENE_IN)
		return
	end
	fill()
	drawStage()
	refresh()
	scene(true, SCENE_IN)
	local v = view
	if v then
		v.intro(true)
	end
end

-- Said by the next build's toast (the build the layout's change starts
-- would drop a toast shown now).
local pendingToast: string? = nil

local function nextLayout()
	if sheet or not isOpen then
		return
	end
	GarageSounds.play("tab")
	local nxt = Layouts.after()
	pendingToast = `LAYOUT: {nxt.name}`
	Layouts.set(nxt.id)
end

local function makeCtx(g: ScreenGui, cash: ScreenGui): Types.Ctx
	return {
		touch = touch(),
		screen = Parts.screen(g),
		title = { en = "HAJWALA", ar = "هجولة" },
		tabs = tabs,
		tab = function()
			return pageId
		end,
		views = function()
			return page().views()
		end,
		view = function()
			return page().view()
		end,
		extra = function()
			return nil
		end,
		note = function()
			return page().note()
		end,
		entries = function()
			return page().entries()
		end,
		stateOf = function(e: Types.Entry)
			return page().stateOf(e)
		end,
		foot = function()
			return page().foot()
		end,
		carName = function()
			local name = page().subject()
			return name
		end,
		carDrive = function()
			local _, chip = page().subject()
			return chip
		end,
		starred = function()
			return page().starred()
		end,
		form = function()
			return page().form()
		end,
		act = {
			tab = choosePage,
			view = function(id: string)
				if not sheet then
					GarageSounds.play("tab")
					page().setView(id)
				end
			end,
			entry = function(e: Types.Entry)
				if not sheet then
					GarageSounds.play("tap")
					page().tap(e)
				end
			end,
			action = function()
				if not sheet then
					GarageSounds.play("tap")
					page().action()
				end
			end,
			extra = function() end,
			leave = function()
				local h = hooks
				if h and not sheet then
					h.close()
				end
			end,
			nextLayout = nextLayout,
			collapse = function() end,
			star = function()
				GarageSounds.play("tap")
				page().star()
			end,
			starEntry = function(e: Types.Entry)
				local fn = page().starEntry
				if fn and not sheet then
					GarageSounds.play("tap")
					fn(e.key)
				end
			end,
			-- CUSTOMIZE: the garage, once the menu can take you there; a
			-- toast for now (the showroom's versions, 2026-10-12).
			customize = function()
				if not sheet then
					GarageSounds.play("tap")
					toast("CUSTOMIZE: the garage, soon", "info")
				end
			end,
		},
		search = {
			get = function()
				local s = page().search
				return if s then s.get() else ""
			end,
			set = function(q: string)
				local s = page().search
				if s then
					s.set(q)
				end
			end,
			has = function()
				return page().search ~= nil
			end,
		},
		tap = function(target: GuiObject, scroll: ScrollingFrame?, onTap: () -> (), onDown: ((boolean) -> ())?)
			table.insert(taps, { gui = target, scroll = scroll, onTap = onTap, onDown = onDown })
		end,
		-- A sheet is up, or the menu is going out: its buttons are dead.
		busy = function()
			return sheet ~= nil or not isOpen
		end,
		-- Under a simulated screen the coins are not where the layout is.
		coins = if Parts.screen(g) == g.AbsoluteSize then Parts.coinAnchor(g, cash) else nil,
	}
end

local function dropView()
	closeSheet()
	local g = gui
	local oldToast = g and g:FindFirstChild("Toast")
	if oldToast then
		oldToast:Destroy()
	end
	local st = stageView
	stageView = nil
	if st then
		st.destroy()
	end
	local v = view
	view = nil
	if v then
		v.destroy()
	end
	table.clear(taps)
	press = nil
end

local function dropCash()
	local cg = cashGui
	cashGui, cashPill = nil, nil
	if cg then
		cg:Destroy()
	end
end

-- The coins, as the HUD has them now (its finish and version).
local function makeCash(): ScreenGui
	dropCash()
	local cg, cp = Parts.hudCash("MenuCash", DISPLAY_ORDER + 1, player:WaitForChild("PlayerGui"))
	cashGui, cashPill = cg, cp
	cp.set(Parts.money(cashNow()))
	return cg
end

build = function(switch: boolean)
	local g = gui
	if not g then
		return
	end
	dropView()
	local cg = makeCash()
	local ctx = makeCtx(g, cg)
	ctxNow = ctx
	local t = Parts.toast(g, ctx)
	toastFn = t
	local v = layoutFor(pageId).build(g, ctx)
	view = v
	builtFor = g.AbsoluteSize
	v.fill()
	drawStage()
	refresh()
	v.intro(switch)
	local said = pendingToast
	pendingToast = nil
	if said then
		t(said, "info")
	end
end

------------------------------------------------------------------------
-- Taps on blocks, through UserInputService: a button in a phone's
-- ScrollingFrame never sees Activated (SpawnMenu's header has the story).
------------------------------------------------------------------------

local function tapAt(position: Vector3): Tap?
	local ok, found = pcall(function()
		return player:WaitForChild("PlayerGui"):GetGuiObjectsAtPosition(position.X, position.Y)
	end)
	if not ok or not found then
		return nil
	end
	for _, o in found do
		for _, t in taps do
			if o == t.gui then
				return t
			end
		end
	end
	return nil
end

local function cancelPress()
	local p = press
	if p and not p.cancelled then
		p.cancelled = true
		local down = p.tap.onDown
		if down then
			down(false)
		end
	end
end

local function bindInput()
	UserInputService.InputBegan:Connect(function(io: InputObject)
		if io.UserInputType ~= Enum.UserInputType.Touch and io.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if not isOpen or press or sheet then
			return
		end
		local t = tapAt(io.Position)
		if not t then
			return
		end
		local scroll = t.scroll
		press = {
			tap = t,
			input = io,
			origin = Vector2.new(io.Position.X, io.Position.Y),
			canvas = if scroll then scroll.CanvasPosition else Vector2.zero,
			cancelled = false,
		}
		local down = t.onDown
		if down then
			down(true)
		end
	end)
	UserInputService.InputChanged:Connect(function(io: InputObject)
		local p = press
		if not p or p.cancelled then
			return
		end
		if io ~= p.input and io.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		local travel = (Vector2.new(io.Position.X, io.Position.Y) - p.origin).Magnitude
		local scroll = p.tap.scroll
		local scrolled = if scroll then (scroll.CanvasPosition - p.canvas).Magnitude else 0
		if travel > TAP_SLOP_PX or scrolled > 2 then
			cancelPress()
		end
	end)
	UserInputService.InputEnded:Connect(function(io: InputObject)
		local p = press
		if not p or p.input ~= io then
			return
		end
		press = nil
		local tapped = not p.cancelled and tapAt(io.Position) == p.tap
		local down = p.tap.onDown
		if down then
			down(false)
		end
		if tapped and isOpen then
			p.tap.onTap()
		end
	end)
end

------------------------------------------------------------------------

function Menu.isOpen(): boolean
	return isOpen
end

-- Open, or still going out: what is under it should not come back yet
-- (the top bar, the CARS button).
function Menu.covering(): boolean
	return isOpen or leaving
end

function Menu.page(): string
	return pageId
end

-- Opens on `id` (or switches to it if open already).
function Menu.open(id: string?, opts: OpenOptions?)
	local g = gui
	if not g then
		return
	end
	local o: OpenOptions = opts or {}
	if id and pages[id] then
		if isOpen then
			choosePage(id)
			return
		end
		pageId = id
	end
	if isOpen then
		return
	end
	serial += 1
	isOpen = true
	leaving = false
	switched = o.switch == true
	openedAt = os.clock()
	g.Enabled = true
	HudLab.setCovered(true)
	page().shown()
	build(switched)
	tell(true)
	if o.switch then
		-- The frame was on screen already: the world behind goes straight
		-- to this page's measure.
		stopScene()
		local p = page()
		local d, b = dim, blur
		if d then
			d.BackgroundTransparency = p.dim
		end
		if b then
			b.Size = p.blur
		end
	else
		scene(true, SCENE_IN)
	end
end

-- Closes: the pieces go back out and the world comes back, or, opened
-- over the garage, the garage takes the screen back at once.
function Menu.close()
	if not isOpen then
		return
	end
	isOpen = false
	leaving = true
	serial += 1
	local mine = serial
	closeSheet()
	local handBack = switched
	switched = false
	local function finish()
		if serial ~= mine then
			return -- opened again meanwhile
		end
		leaving = false
		dropView()
		dropCash()
		local g = gui
		if g then
			g.Enabled = false
		end
		stopScene()
		local d, b = dim, blur
		if d then
			d.BackgroundTransparency = 1
		end
		if b then
			b.Size = 0
		end
		HudLab.setCovered(false)
		tell(false)
	end
	if handBack then
		finish()
		return
	end
	local v = view
	local t = if v then v.outro() else 0
	scene(false, SCENE_OUT)
	task.delay(math.max(t, SCENE_OUT.Time), finish)
end

-- fn(true) as the menu takes the screen, fn(false) once it has given it
-- back.
function Menu.watch(fn: (open: boolean) -> ())
	table.insert(watchers, fn)
end

-- The car you are in changed, or a spawn's cooldown ended.
function Menu.refresh()
	refresh()
end

function Menu.start(h: Page.Hooks, remotes: Folder)
	hooks = h
	GarageSounds.start()
	local g = Instance.new("ScreenGui")
	g.Name = "HajwalaMenu"
	g.ResetOnSpawn = false
	-- Under Roblox's top bar, as the garage panel's gui: the layouts are
	-- drawn for that room, and their shades bleed past it.
	g.IgnoreGuiInset = false
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = DISPLAY_ORDER
	g.Enabled = false
	-- The world behind, dimmed edge to edge (under Roblox's top bar and
	-- into a notch's strip: UIKit.edgeToEdge).
	local d = Kit.frame(g, "Dim", Color3.new(0, 0, 0), 1)
	UIKit.edgeToEdge(d, g)
	d.ZIndex = 0
	d:SetAttribute("PassThrough", true)
	dim = d
	g.Parent = player:WaitForChild("PlayerGui")
	gui = g
	local b = Instance.new("BlurEffect")
	b.Name = "HajwalaMenuBlur"
	b.Size = 0
	b.Parent = Lighting
	blur = b

	local shell: Page.Shell = {
		hooks = h,
		touch = touch,
		refresh = refresh,
		fill = fill,
		toast = toast,
		sound = GarageSounds.play,
		tap = function(target: GuiObject, scroll: ScrollingFrame?, onTap: () -> (), onDown: ((boolean) -> ())?)
			table.insert(taps, { gui = target, scroll = scroll, onTap = onTap, onDown = onDown })
		end,
		sheet = openSheet,
		busy = function()
			return sheet ~= nil or not isOpen
		end,
		showing = function()
			return if isOpen then pageId else nil
		end,
		relayout = function()
			if isOpen then
				build(false)
			end
		end,
	}
	pages.cars = Cars.new(shell)
	pages.plates = Plates.new(shell, remotes)
	pages.settings = Settings.new(shell)
	for _, id in ORDER do
		table.insert(tabs, pages[id].tab)
	end
	bindInput()

	-- A new screen size, Studio's phone mode or a new layout lays it out
	-- again; a new HUD finish or version redraws the coins to match it.
	g:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if isOpen and g.AbsoluteSize ~= builtFor then
			build(not (os.clock() - openedAt < 0.3 and not switched))
		end
	end)
	for _, name in { "ForceTouch", "ScreenSim" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if isOpen then
				build(true)
			end
		end)
	end
	for _, name in { Layouts.ATTRIBUTE, Showroom.PICKED } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if isOpen then
				build(false)
			end
		end)
	end
	for _, name in { "HudVariant", "HudLayout" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if isOpen then
				makeCash()
			end
		end)
	end
	player:GetAttributeChangedSignal("Cash"):Connect(refresh)
end

return Menu
