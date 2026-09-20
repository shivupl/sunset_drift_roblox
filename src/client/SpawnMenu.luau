--!strict
-- The spawn menu: pick a car from the catalog and the server builds it in
-- your bay slot with you in the driver's seat.
--
-- It opens by itself when you join (you start on foot), and M or the CARS
-- button at the bottom centre opens it again at any time, driving or not.
-- Spawning while driving replaces the car you are in. Every card is built
-- from CarCatalog, so a new catalog entry shows up here with no code change.
--
-- The request is only a wish: the server checks the id, the cooldown and
-- whether a spawn is already building, and does the seating itself.
--
-- PHONE FIRST. The first version was a desktop panel shrunk onto a phone and
-- the owner found it unusable: cards were tapped and nothing happened, and the
-- button under the thumb stayed dark, as though it were disabled.
--
-- Three things caused that, and each is handled here:
-- 1. **A tap inside a ScrollingFrame is a gesture, not a click.** The frame
--    claims a touch that moves even slightly, so `Activated` never fires and
--    the button is left in its pressed colour. Every card now tracks the touch
--    itself, through UserInputService, and counts it as a tap only if the
--    finger stays within TAP_SLOP_PX and lifts over the card. `AutoButtonColor`
--    is off everywhere: a pressed or busy look is set here, so it can always be
--    cleared.
-- 2. **Roblox's own touch controls sit on top of any PlayerGui.** The
--    thumbstick and the jump button are CoreGui, so they took taps meant for
--    the cards. `UserInputService.ModalEnabled` hides them while the menu is
--    open.
-- 3. **Everything was sized in desktop pixels.** Sizes now come from the
--    viewport, with phone minimums for tap targets (44 points is the floor).
-- 4. **The panel was taller than the phone.** It grew with AutomaticSize and
--    was centred, so the header and the footer were cut off the top and the
--    bottom, and a half-clipped card reads as a greyed-out one. The panel is
--    sized to the screen now: the list takes what is left after the header,
--    the footer and the margins, and scrolls when it has to.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared.ConfigLoader)
local VehicleRig = require(Shared.VehicleRig)

local SpawnMenu = {}

local INK = Color3.fromRGB(15, 15, 18)
local CARD = Color3.fromRGB(28, 28, 33)
local CARD_DOWN = Color3.fromRGB(46, 46, 54)
local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 175)
local HOT = Color3.fromRGB(255, 165, 40)
local HOT_DIM = Color3.fromRGB(120, 84, 34)

local ACTION = "HJ_SpawnMenu"
-- How far a finger may travel and still count as a tap rather than a scroll.
local TAP_SLOP_PX = 14

type Card = {
	id: string,
	frame: Frame,
	button: TextButton,
	name: TextLabel,
	blurb: TextLabel,
	specs: TextLabel,
	chip: TextLabel,
	stroke: UIStroke,
	paint: Frame,
}

-- The touch or click being followed across the list: which card it started
-- on, where, and whether it has turned into a scroll.
type Press = {
	card: Card,
	input: InputObject,
	origin: Vector2,
	canvas: number,
	cancelled: boolean,
}

local gui: ScreenGui? = nil
local openButton: TextButton? = nil
local panel: Frame? = nil
local header: Frame? = nil
local closeButton: TextButton? = nil
local title: TextLabel? = nil
local subtitle: TextLabel? = nil
local list: ScrollingFrame? = nil
local status: TextLabel? = nil
local cards: { Card } = {}
local press: Press? = nil
local remote: RemoteEvent? = nil
local currentCarId: string? = nil
local waitingUntil = 0
-- ModalEnabled hides Roblox's own touch controls. VehicleController holds it
-- on for the whole drive (its thumbstick would sit under our steer pad), so
-- the menu remembers what it found and puts that back: closing the menu in a
-- car must not hand the thumbstick back mid-drive.
local modalBefore = false

local function isTouch(): boolean
	return UserInputService.TouchEnabled or Players.LocalPlayer:GetAttribute("ForceTouch") == true
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, text: string, font: Enum.Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Parent = parent
	return l
end

-- Every size in the menu, worked out from the viewport. On a phone the
-- numbers grow with the screen and never fall under a thumb-sized target;
-- on a desktop they stay near the original panel.
type Metrics = {
	touch: boolean,
	cardH: number,
	gap: number,
	pad: number,
	buttonW: number,
	buttonH: number,
	nameSize: number,
	blurbSize: number,
	specSize: number,
	titleSize: number,
	subSize: number,
	headerH: number,
	closeSize: number,
	footerH: number,
	footerSize: number,
	panelWidth: number,
	panelMax: number,
}

local function metrics(): Metrics
	local vp = if gui then (gui :: ScreenGui).AbsoluteSize else Vector2.new(1280, 720)
	-- A ScreenGui that has never been enabled reports nothing; fall back to
	-- the camera, which is always there.
	if vp.X < 1 or vp.Y < 1 then
		local cam = workspace.CurrentCamera
		vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	end
	local touch = isTouch()
	local short = math.min(vp.X, vp.Y)
	if not touch then
		return {
			touch = false,
			cardH = 92,
			gap = 10,
			pad = 18,
			buttonW = 118,
			buttonH = 48,
			nameSize = 22,
			blurbSize = 14,
			specSize = 12,
			titleSize = 24,
			subSize = 15,
			headerH = 44,
			closeSize = 40,
			footerH = 18,
			footerSize = 13,
			panelWidth = 0.92,
			panelMax = 560,
		}
	end
	-- Phone: a card is about a fifth of the short side, a tap target never
	-- under 44 points, and text scales with it.
	local unit = math.clamp(short, 320, 900)
	local cardH = math.clamp(unit * 0.21, 78, 132)
	local buttonH = math.clamp(cardH * 0.58, 46, 72)
	return {
		touch = true,
		cardH = cardH,
		gap = math.clamp(unit * 0.022, 8, 16),
		pad = math.clamp(unit * 0.035, 12, 24),
		buttonW = math.clamp(cardH * 1.5, 104, 190),
		buttonH = buttonH,
		nameSize = math.clamp(cardH * 0.25, 19, 32),
		blurbSize = math.clamp(cardH * 0.17, 13, 21),
		specSize = math.clamp(cardH * 0.145, 11, 18),
		titleSize = math.clamp(unit * 0.055, 20, 34),
		subSize = math.clamp(unit * 0.035, 13, 22),
		headerH = math.clamp(unit * 0.12, 44, 72),
		closeSize = math.clamp(unit * 0.095, 44, 60),
		footerH = math.clamp(unit * 0.05, 18, 30),
		footerSize = math.clamp(unit * 0.032, 12, 19),
		panelWidth = 0.96,
		panelMax = 720,
	}
end

local function busy(): boolean
	return os.clock() < waitingUntil
end

local function paintCard(card: Card, down: boolean)
	local m = metrics()
	local current = card.id == currentCarId
	local isBusy = busy()
	card.frame.BackgroundColor3 = if down then CARD_DOWN else CARD
	card.button.Text = if isBusy then "…" elseif current then "RESPAWN" else "SPAWN"
	card.button.BackgroundColor3 = if isBusy then HOT_DIM elseif down then Color3.fromRGB(255, 196, 110) else HOT
	card.button.TextSize = math.floor(m.buttonH * 0.36)
	card.stroke.Transparency = if current then 0.1 else 1
	card.chip.Visible = current
end

local function refreshButtons()
	local p = press
	for _, card in cards do
		paintCard(card, p ~= nil and p.card == card and not p.cancelled)
	end
end

local function requestSpawn(id: string)
	if busy() or not remote then
		return
	end
	local cooldown = ConfigLoader.current().spawn.spawnCooldownSeconds
	waitingUntil = os.clock() + cooldown
	refreshButtons()
	;(remote :: RemoteEvent):FireServer(id)
	SpawnMenu.close()
	task.delay(cooldown + 0.05, refreshButtons)
end

local function specLine(entry: VehicleRig.CarEntry): string
	local k = VehicleRig.scaleOf(entry)
	local r = entry.rig
	local mass = tostring(math.floor(r.massKg + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return string.format("%.1f m long   ·   %s kg   ·   rear-wheel drive", r.collisionSizeM[3] * k, mass)
end

local function sortedCars(): { { id: string, entry: VehicleRig.CarEntry } }
	local out = {}
	for id, entry in ConfigLoader.catalog().cars do
		table.insert(out, { id = id, entry = entry })
	end
	table.sort(out, function(a, b)
		local oa, ob = a.entry.order or math.huge, b.entry.order or math.huge
		if oa ~= ob then
			return oa < ob
		end
		return a.entry.displayName < b.entry.displayName
	end)
	return out
end

-- What is under a press, by the engine's own hit-test. It respects clipping,
-- so a card scrolled half out of the list is only hit where it shows, and it
-- avoids the inset question entirely: measured in Studio, an InputObject's
-- position is already in the same space as AbsolutePosition under a gui with
-- IgnoreGuiInset (GetMouseLocation is the one that carries the inset). Adding
-- the inset here is what made taps miss the lower cards.
local function hits(position: Vector3): { GuiObject }
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return {}
	end
	local ok, found = pcall(function()
		return pg:GetGuiObjectsAtPosition(position.X, position.Y)
	end)
	return if ok and found then found else {}
end

local function overCard(card: Card, position: Vector3): boolean
	for _, o in hits(position) do
		if o == card.frame then
			return true
		end
	end
	return false
end

local function buildCard(parent: Instance, id: string, entry: VehicleRig.CarEntry, order: number)
	-- A Frame, not a button: a GuiButton inside a ScrollingFrame blocks the
	-- drag that scrolls it, which left the lower cars unreachable on a phone.
	-- The list handles taps for every card instead (see bindTapTracking).
	local frame = Instance.new("Frame")
	frame.Name = "Car_" .. id
	frame.BackgroundColor3 = CARD
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(1, 0, 0, 92)
	frame.LayoutOrder = order
	corner(frame, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = HOT
	stroke.Thickness = 2
	stroke.Transparency = 1
	stroke.Parent = frame
	frame.Parent = parent

	-- The car's paint, as a stripe down the left edge.
	local swatch = Instance.new("Frame")
	swatch.Name = "Paint"
	swatch.BackgroundColor3 = entry.body.paint
	swatch.BorderSizePixel = 0
	corner(swatch, 4)
	swatch.Parent = frame

	local name = label(frame, entry.displayName, Enum.Font.GothamBlack, 22, WHITE)
	local chip = label(frame, "IN USE", Enum.Font.GothamBold, 11, HOT)
	chip.Name = "Current"
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Visible = false
	local chipPad = Instance.new("UIPadding")
	chipPad.PaddingLeft = UDim.new(0, name.TextBounds.X + 10)
	chipPad.Parent = chip
	name:GetPropertyChangedSignal("TextBounds"):Connect(function()
		chipPad.PaddingLeft = UDim.new(0, name.TextBounds.X + 10)
	end)

	local blurb = label(frame, entry.blurb or "", Enum.Font.Gotham, 14, MUTED)
	blurb.TextTruncate = Enum.TextTruncate.AtEnd

	local specs = label(frame, specLine(entry), Enum.Font.GothamMedium, 12, MUTED)
	specs.TextTransparency = 0.25
	specs.TextTruncate = Enum.TextTruncate.AtEnd

	-- The SPAWN pill reads as the action; tapping anywhere on the card does it.
	local btn = Instance.new("TextButton")
	btn.Name = "Spawn"
	btn.AutoButtonColor = false
	btn.Active = false -- the card handles the touch, so this never eats one
	btn.Selectable = false
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.BackgroundColor3 = HOT
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBlack
	btn.TextSize = 17
	btn.TextColor3 = INK
	btn.Text = "SPAWN"
	corner(btn, 10)
	btn.Parent = frame

	local card: Card = {
		id = id,
		frame = frame,
		button = btn,
		name = name,
		blurb = blurb,
		specs = specs,
		chip = chip,
		stroke = stroke,
		paint = swatch,
	}
	table.insert(cards, card)
end

-- Taps for the whole list, tracked here rather than on each card, so the
-- ScrollingFrame keeps its drag-to-scroll: a press picks the card under it, a
-- drag past the slop (or any scrolling) turns into a scroll and cancels, and
-- a lift still over that card spawns.
local function cardAt(position: Vector3): Card?
	for _, o in hits(position) do
		for _, card in cards do
			if o == card.frame then
				return card
			end
		end
	end
	return nil
end

local function cancelPress()
	local p = press
	if p and not p.cancelled then
		p.cancelled = true
		paintCard(p.card, false)
	end
end

local function bindTapTracking()
	local scroll = list
	if not scroll then
		return
	end
	-- Every press is picked up from UserInputService rather than from the list:
	-- a ScrollingFrame claims a touch for its gesture, and what it passes on to
	-- its own handlers on a phone is not something to depend on. The hit test
	-- below decides whether the press was on a card.
	UserInputService.InputBegan:Connect(function(io: InputObject)
		if io.UserInputType ~= Enum.UserInputType.Touch and io.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if press or busy() or not SpawnMenu.isOpen() then
			return
		end
		local card = cardAt(io.Position)
		if not card then
			return
		end
		press = { card = card, input = io, origin = Vector2.new(io.Position.X, io.Position.Y), canvas = (scroll :: ScrollingFrame).CanvasPosition.Y, cancelled = false }
		paintCard(card, true)
	end)
	UserInputService.InputChanged:Connect(function(io: InputObject)
		local p = press
		if not p or p.cancelled then
			return
		end
		local moved = io == p.input or io.UserInputType == Enum.UserInputType.MouseMovement
		if not moved then
			return
		end
		local travel = (Vector2.new(io.Position.X, io.Position.Y) - p.origin).Magnitude
		local scrolled = math.abs((scroll :: ScrollingFrame).CanvasPosition.Y - p.canvas)
		if travel > TAP_SLOP_PX or scrolled > 2 then
			cancelPress()
		end
	end)
	UserInputService.InputEnded:Connect(function(io: InputObject)
		local p = press
		if not p or p.input ~= io then
			return
		end
		local tapped = not p.cancelled and overCard(p.card, io.Position)
		press = nil
		paintCard(p.card, false)
		if tapped then
			requestSpawn(p.card.id)
		end
	end)
end

-- Lay the whole menu out for the viewport it is in. Called on open and
-- whenever the screen changes, so a phone rotating is handled.
local function fit()
	local g = gui
	local p = panel
	local scroll = list
	if not g or not p or not scroll or not header or not closeButton or not title or not subtitle or not status then
		return
	end
	local m = metrics()
	local vp = g.AbsoluteSize
	if vp.Y < 1 then
		local cam = workspace.CurrentCamera
		vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	end

	p.Size = UDim2.new(m.panelWidth, 0, 0, 0)
	local constraint = p:FindFirstChildOfClass("UISizeConstraint")
	if constraint then
		constraint.MaxSize = Vector2.new(m.panelMax, math.huge)
	end
	local padding = p:FindFirstChildOfClass("UIPadding")
	if padding then
		padding.PaddingTop = UDim.new(0, m.pad)
		padding.PaddingBottom = UDim.new(0, m.pad - 2)
		padding.PaddingLeft = UDim.new(0, m.pad)
		padding.PaddingRight = UDim.new(0, m.pad)
	end
	local layout = p:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.Padding = UDim.new(0, m.gap)
	end

	header.Size = UDim2.new(1, 0, 0, m.headerH);
	(title :: TextLabel).TextSize = m.titleSize;
	(title :: TextLabel).Size = UDim2.new(1, -(m.closeSize + 16), 0, math.floor(m.headerH * 0.6));
	(subtitle :: TextLabel).TextSize = m.subSize;
	(subtitle :: TextLabel).Position = UDim2.fromOffset(0, math.floor(m.headerH * 0.6));
	(subtitle :: TextLabel).Size = UDim2.new(1, -(m.closeSize + 16), 0, math.floor(m.headerH * 0.4));
	(closeButton :: TextButton).Size = UDim2.fromOffset(m.closeSize, m.closeSize);
	(closeButton :: TextButton).TextSize = math.floor(m.closeSize * 0.62)

	local cardList = scroll:FindFirstChildOfClass("UIListLayout")
	if cardList then
		cardList.Padding = UDim.new(0, m.gap)
	end
	scroll.ScrollBarThickness = if m.touch then 6 else 4
	for _, card in cards do
		card.frame.Size = UDim2.new(1, 0, 0, m.cardH)
		card.paint.Position = UDim2.fromOffset(12, math.floor(m.cardH * 0.15))
		card.paint.Size = UDim2.new(0, 8, 1, -math.floor(m.cardH * 0.3))
		local textW = -(m.buttonW + 46)
		card.name.TextSize = m.nameSize
		card.name.Position = UDim2.fromOffset(34, math.floor(m.cardH * 0.13))
		card.name.Size = UDim2.new(1, textW, 0, math.floor(m.nameSize * 1.2))
		card.chip.TextSize = math.floor(m.specSize * 0.95)
		card.chip.Position = card.name.Position
		local chipPad = card.chip:FindFirstChildOfClass("UIPadding")
		if chipPad then
			chipPad.PaddingLeft = UDim.new(0, card.name.TextBounds.X + 10)
		end
		card.chip.Size = UDim2.fromOffset(0, math.floor(m.nameSize * 1.2))
		card.blurb.TextSize = m.blurbSize
		card.blurb.Position = UDim2.fromOffset(34, math.floor(m.cardH * 0.43))
		card.blurb.Size = UDim2.new(1, textW, 0, math.floor(m.blurbSize * 1.3))
		card.specs.TextSize = m.specSize
		card.specs.Position = UDim2.fromOffset(34, math.floor(m.cardH * 0.67))
		card.specs.Size = UDim2.new(1, textW, 0, math.floor(m.specSize * 1.3))
		-- On a narrow phone the spec line is noise; the name and blurb carry it.
		card.specs.Visible = vp.X > 520 or not m.touch
		card.button.Size = UDim2.fromOffset(m.buttonW, m.buttonH)
		card.button.Position = UDim2.new(1, -14, 0.5, 0)
	end

	status.TextSize = m.footerSize
	status.Size = UDim2.new(1, 0, 0, m.footerH)

	-- The panel is sized, not grown: everything but the list is fixed, so the
	-- list takes whatever the screen has left and the header and footer are
	-- always on it. Margins keep it off the top bar and off a phone's home
	-- indicator.
	local topMargin = if m.touch then 10 else 8
	local bottomMargin = if m.touch then 18 else 8
	local chrome = m.pad * 2 + m.headerH + m.gap * 2 + m.footerH
	local room = math.max(vp.Y - topMargin - bottomMargin - chrome, math.floor(m.cardH * 0.6))
	local want = #cards * (m.cardH + m.gap) - m.gap
	local listH = math.min(want, room)
	scroll.Size = UDim2.new(1, 0, 0, listH)
	p.Size = UDim2.new(m.panelWidth, 0, 0, chrome + listH)

	local ob = openButton
	if ob then
		local w = if m.touch then math.clamp(vp.X * 0.2, 120, 220) else 92
		local h = if m.touch then math.clamp(vp.Y * 0.09, 44, 64) else 38
		ob.Size = UDim2.fromOffset(w, h)
		ob.TextSize = if m.touch then math.floor(h * 0.42) else 15
		ob.Position = UDim2.new(0.5, 0, 1, -math.floor(h * 0.35) - (if m.touch then 10 else 0))
	end
	refreshButtons()
end

local function build()
	local player = Players.LocalPlayer
	local g = Instance.new("ScreenGui")
	g.Name = "HajwalaSpawnMenu"
	g.ResetOnSpawn = false
	-- Not IgnoreGuiInset: the gui is then exactly the area under Roblox's top
	-- bar, so a centred panel cannot end up beneath it. On a phone the panel
	-- was taller than the screen and the header and footer were cut off.
	g.IgnoreGuiInset = false
	g.DisplayOrder = 20
	-- Sibling, not the Global default: under Global every ZIndex 1 object in
	-- the gui draws before every ZIndex 2 one, so the panel (2) was drawn over
	-- its own cards and text (1) and its near-opaque background dimmed them.
	-- That is the "dark overlay" the owner saw on a phone. With Sibling a
	-- child always draws above its parent, and ZIndex only orders siblings.
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Enabled = false

	-- The dim backdrop is a button so a tap outside the panel closes the
	-- menu. A button behind the panel still hears taps on the panel (Active
	-- does not stop it), so it checks where the tap landed.
	local back = Instance.new("TextButton")
	back.Name = "Backdrop"
	back.Text = ""
	back.AutoButtonColor = false
	back.BackgroundColor3 = Color3.new(0, 0, 0)
	back.BackgroundTransparency = 0.45
	back.BorderSizePixel = 0
	back.Size = UDim2.fromScale(1, 1)
	back.Parent = g

	local p = Instance.new("Frame")
	p.Name = "Panel"
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.fromScale(0.5, 0.5)
	p.Size = UDim2.new(0.92, 0, 0, 0)
	p.BackgroundColor3 = INK
	p.BackgroundTransparency = 0.08
	p.BorderSizePixel = 0
	p.Active = true -- taps on the panel do not reach the backdrop
	p.ZIndex = 2
	corner(p, 14)
	local maxSize = Instance.new("UISizeConstraint")
	maxSize.MaxSize = Vector2.new(560, math.huge)
	maxSize.Parent = p
	local pad = Instance.new("UIPadding")
	pad.Parent = p
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = p
	p.Parent = g
	panel = p
	back.Activated:Connect(function(io: InputObject)
		-- A button behind the panel still hears clicks on the panel, so ask
		-- what is actually under this one.
		for _, o in hits(io.Position) do
			if o == p then
				return
			end
		end
		SpawnMenu.close()
	end)

	local head = Instance.new("Frame")
	head.Name = "Header"
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 44)
	head.LayoutOrder = 1
	head.Parent = p
	header = head
	title = label(head, "CHOOSE YOUR CAR", Enum.Font.GothamBlack, 24, WHITE)
	subtitle = label(head, "اختر سيارتك", Enum.Font.GothamMedium, 15, HOT)
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AutoButtonColor = false
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.fromOffset(40, 40)
	close.BackgroundColor3 = CARD
	close.BorderSizePixel = 0
	close.Text = "×"
	close.Font = Enum.Font.GothamBold
	close.TextSize = 26
	close.TextColor3 = MUTED
	corner(close, 10)
	close.Parent = head
	closeButton = close
	close.Activated:Connect(function()
		SpawnMenu.close()
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Cars"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = 2
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = MUTED
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Active = true
	local cardList = Instance.new("UIListLayout")
	cardList.FillDirection = Enum.FillDirection.Vertical
	cardList.SortOrder = Enum.SortOrder.LayoutOrder
	cardList.Parent = scroll
	scroll.Parent = p
	list = scroll

	for i, car in sortedCars() do
		buildCard(scroll, car.id, car.entry, i)
	end
	bindTapTracking()

	local footer = label(p, "", Enum.Font.GothamMedium, 13, MUTED)
	footer.Name = "Footer"
	footer.LayoutOrder = 3
	footer.Size = UDim2.new(1, 0, 0, 18)
	footer.TextXAlignment = Enum.TextXAlignment.Center
	status = footer

	-- The CARS button, on every platform: the only way back in on a phone.
	-- Bottom centre: the top left is the debug panel, the top centre the HUD,
	-- the top right Roblox's own menus, and on a phone the steer pad and the
	-- pedals leave the bottom centre free.
	local open = Instance.new("TextButton")
	open.Name = "OpenSpawnMenu"
	open.AutoButtonColor = false
	open.AnchorPoint = Vector2.new(0.5, 1)
	open.Position = UDim2.new(0.5, 0, 1, -14)
	open.Size = UDim2.fromOffset(92, 38)
	open.BackgroundColor3 = INK
	open.BackgroundTransparency = 0.35
	open.BorderSizePixel = 0
	open.Font = Enum.Font.GothamBlack
	open.TextSize = 15
	open.TextColor3 = WHITE
	corner(open, 10)
	local openStroke = Instance.new("UIStroke")
	openStroke.Color = HOT
	openStroke.Thickness = 2
	openStroke.Transparency = 0.45
	openStroke.Parent = open
	local openGui = Instance.new("ScreenGui")
	openGui.Name = "HajwalaSpawnButton"
	openGui.ResetOnSpawn = false
	openGui.DisplayOrder = 7
	open.Parent = openGui
	openButton = open
	open.Activated:Connect(function()
		SpawnMenu.toggle()
	end)
	openGui.Parent = player:WaitForChild("PlayerGui")

	g.Parent = player:WaitForChild("PlayerGui")
	gui = g
	g:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
end

function SpawnMenu.isOpen(): boolean
	return gui ~= nil and (gui :: ScreenGui).Enabled
end

function SpawnMenu.open()
	if not gui then
		return
	end
	local g = gui :: ScreenGui
	if not g.Enabled then
		modalBefore = UserInputService.ModalEnabled
	end
	g.Enabled = true
	-- Roblox's own touch controls are CoreGui and draw over any PlayerGui;
	-- modal hides them so they cannot take taps meant for the cards.
	UserInputService.ModalEnabled = true
	fit()
	if list then
		(list :: ScrollingFrame).CanvasPosition = Vector2.zero
	end
	if status then
		(status :: TextLabel).Text = if isTouch() then "Tap a car to spawn it   ·   CARS reopens this" else "Click a car to spawn it   ·   M reopens this"
	end
	local ob = openButton
	if ob then
		ob.Text = if isTouch() then "CARS" else "CARS  (M)"
		ob.Visible = false -- it sits under the backdrop; hide it while open
	end
	refreshButtons()
end

function SpawnMenu.close()
	if gui then
		(gui :: ScreenGui).Enabled = false
	end
	UserInputService.ModalEnabled = modalBefore
	press = nil
	for _, card in cards do
		paintCard(card, false)
	end
	local ob = openButton
	if ob then
		ob.Text = if isTouch() then "CARS" else "CARS  (M)"
		ob.Visible = true
	end
end

function SpawnMenu.toggle()
	if SpawnMenu.isOpen() then
		SpawnMenu.close()
	else
		SpawnMenu.open()
	end
end

-- The car the player is in now, so its card reads RESPAWN. nil when on foot
-- is fine: the last car stays marked.
function SpawnMenu.setCurrent(carId: string?)
	if carId then
		currentCarId = carId
	end
	refreshButtons()
end

function SpawnMenu.start(remotes: Folder)
	remote = remotes:WaitForChild("SpawnCar") :: RemoteEvent
	build()
	ContextActionService:BindAction(ACTION, function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			SpawnMenu.toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M)
	-- You start on foot: open straight away.
	SpawnMenu.open()
end

return SpawnMenu
