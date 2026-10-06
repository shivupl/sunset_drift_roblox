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
local DriftStyles = require(Shared:WaitForChild("DriftStyles"))
local UITheme = require(Shared:WaitForChild("UITheme"))
local UIKit = require(script.Parent.UIKit)
local PlatesPanel = require(script.Parent.PlatesPanel)
local SettingsPanel = require(script.Parent.SettingsPanel)

local SpawnMenu = {}

-- Colours, type, radii and button states come from UITheme (UI_SYSTEM.md).
-- Re-skinned onto the tokens on 2026-09-28; the layout below is unchanged.
local C = UITheme.color

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
-- The bilingual title row (UIKit.title) and the holder that keeps it clear
-- of the close button.
local titleHolder: Frame? = nil
local titleEnglish: TextLabel? = nil
local titleArabic: TextLabel? = nil
local list: ScrollingFrame? = nil
local status: TextLabel? = nil
local cards: { Card } = {}
local press: Press? = nil
local remote: RemoteEvent? = nil
local currentCarId: string? = nil
local waitingUntil = 0
local tabs: Frame? = nil
local tabButtons: { [string]: TextButton } = {}
type Tab = "cars" | "plates" | "settings"
local showing: Tab = "cars"
-- ModalEnabled hides Roblox's own touch controls. VehicleController holds it
-- on for the whole drive (its thumbstick would sit under our steer pad), so
-- the menu remembers what it found and puts that back: closing the menu in a
-- car must not hand the thumbstick back mid-drive.
local modalBefore = false
-- The garage view hides the CARS button (SpawnMenu.setOpenButtonHidden).
local openButtonHidden = false

local isTouch = UIKit.isTouch

-- A fixed-size label in a type role. Not UIKit.text: these labels are sized
-- and truncated by fit(), which AutomaticSize would fight.
local function label(parent: Instance, text: string, role: UITheme.Role, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = if UITheme.type[role].caps then string.upper(text) else text
	l.FontFace = UITheme.font(role)
	l.TextSize = UITheme.textSize(role, isTouch())
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
	headerH: number,
	tabH: number,
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
			-- Text sizes are the type roles (UI_SYSTEM.md): name heading,
			-- blurb body, spec line caption, footer caption.
			nameSize = UITheme.textSize("heading", false),
			blurbSize = UITheme.textSize("body", false),
			specSize = UITheme.textSize("caption", false),
			headerH = 44,
			-- Every pressable is at least UITheme.target (36 here, 48 on a
			-- phone): fix round 1, 2026-09-28, the owner wants the UI thumb-
			-- reachable. The tabs were 34.
			tabH = math.max(34, UITheme.target(false)),
			closeSize = 40,
			footerH = 18,
			footerSize = UITheme.textSize("caption", false),
			panelWidth = 0.92,
			panelMax = 560,
		}
	end
	-- Phone: a card is about a fifth of the short side, a tap target never
	-- under 44 points, and text scales with it, never under its type role's
	-- touch size.
	local unit = math.clamp(short, 320, 900)
	local cardH = math.clamp(unit * 0.21, 78, 132)
	-- Tap targets never under UITheme.target(true) (48): the SPAWN pill, the
	-- tabs and the close button were floored at 46, 40 and 44 before.
	local thumb = UITheme.target(true)
	local buttonH = math.max(thumb, math.clamp(cardH * 0.58, 46, 72))
	local closeSize = math.max(thumb, math.clamp(unit * 0.095, 44, 60))
	return {
		touch = true,
		cardH = cardH,
		gap = math.clamp(unit * 0.022, 8, 16),
		pad = math.clamp(unit * 0.035, 12, 24),
		buttonW = math.clamp(cardH * 1.5, 104, 190),
		buttonH = buttonH,
		nameSize = math.max(UITheme.textSize("heading", true), math.clamp(cardH * 0.25, 19, 32)),
		blurbSize = math.max(UITheme.textSize("body", true), math.clamp(cardH * 0.17, 13, 21)),
		specSize = math.max(UITheme.textSize("caption", true), math.clamp(cardH * 0.145, 11, 18)),
		-- The header always holds the close button.
		headerH = math.max(closeSize, math.clamp(unit * 0.12, 44, 72)),
		tabH = math.max(thumb, math.clamp(unit * 0.08, 40, 56)),
		closeSize = closeSize,
		footerH = math.clamp(unit * 0.05, 18, 30),
		footerSize = math.max(UITheme.textSize("caption", true), math.clamp(unit * 0.032, 12, 19)),
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
	-- A card is a secondary surface, pressed while a finger is on it; the car
	-- you are in carries the selected stroke. SPAWN is the primary button,
	-- and waiting out the cooldown reads as disabled.
	local surface = if down then UITheme.button.secondaryPressed else UITheme.button.secondary
	card.frame.BackgroundColor3 = surface.bg
	card.stroke.Color = if current then C.sodium else C.asphalt600
	card.stroke.Thickness = if current then UITheme.stroke.selected else UITheme.stroke.hairline
	card.stroke.Transparency = 0
	local look = if isBusy then UITheme.button.disabled elseif down then UITheme.button.primaryPressed else UITheme.button.primary
	card.button.Text = if isBusy then "…" elseif current then "RESPAWN" else "SPAWN"
	card.button.BackgroundColor3 = look.bg
	card.button.TextColor3 = look.text
	-- The label role; on a phone it grows with the button, as it did before.
	card.button.TextSize = if m.touch
		then math.max(UITheme.textSize("label", true), math.floor(m.buttonH * 0.36))
		else UITheme.textSize("label", false)
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
	-- Which wheels drive: the catalog's drivetrain.layout (DriftStyles).
	local tuning = entry.tuning
	local layout = DriftStyles.layoutOf({ drivetrain = (tuning and tuning.drivetrain) or {} })
	local drive = string.lower(DriftStyles.layoutName[layout])
	return string.format("%.1f m long   ·   %s kg   ·   %s", r.collisionSizeM[3] * k, mass, drive)
end

local function sortedCars(): { { id: string, entry: VehicleRig.CarEntry } }
	local out = {}
	for id, entry in ConfigLoader.catalog().cars do
		-- A hidden entry stays spawnable by id but is off the menu (the
		-- generated-body Kamri, since the store-body one replaced it).
		if not (entry :: any).hidden then
			table.insert(out, { id = id, entry = entry })
		end
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
	frame.BackgroundColor3 = UITheme.button.secondary.bg
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(1, 0, 0, 92)
	frame.LayoutOrder = order
	UIKit.corner(frame, "md")
	-- Hairline asphalt600 at rest; paintCard makes it the selected sodium
	-- stroke on the car you are in.
	local stroke = UIKit.stroke(frame, "asphalt600", UITheme.stroke.hairline)
	frame.Parent = parent

	-- The car's paint, as a stripe down the left edge.
	local swatch = Instance.new("Frame")
	swatch.Name = "Paint"
	swatch.BackgroundColor3 = entry.body.paint
	swatch.BorderSizePixel = 0
	UIKit.corner(swatch, "sm")
	swatch.Parent = frame

	local name = label(frame, entry.displayName, "heading", C.paint)
	-- Marks the chosen car, so it is the accent.
	local chip = label(frame, "IN USE", "label", C.sodium)
	chip.Name = "Current"
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Visible = false
	local chipPad = Instance.new("UIPadding")
	chipPad.PaddingLeft = UDim.new(0, name.TextBounds.X + 10)
	chipPad.Parent = chip
	name:GetPropertyChangedSignal("TextBounds"):Connect(function()
		chipPad.PaddingLeft = UDim.new(0, name.TextBounds.X + 10)
	end)

	local blurb = label(frame, entry.blurb or "", "body", C.sand)
	blurb.TextTruncate = Enum.TextTruncate.AtEnd

	local specs = label(frame, specLine(entry), "caption", C.sandDim)
	specs.TextTruncate = Enum.TextTruncate.AtEnd

	-- The SPAWN pill reads as the action; tapping anywhere on the card does it.
	local btn = Instance.new("TextButton")
	btn.Name = "Spawn"
	btn.AutoButtonColor = false
	btn.Active = false -- the card handles the touch, so this never eats one
	btn.Selectable = false
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.BackgroundColor3 = UITheme.button.primary.bg
	btn.BorderSizePixel = 0
	btn.FontFace = UITheme.font("label")
	btn.TextSize = UITheme.textSize("label", isTouch())
	btn.TextColor3 = UITheme.button.primary.text
	btn.Text = "SPAWN"
	UIKit.corner(btn, "md")
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
	if not g or not p or not scroll or not header or not closeButton or not titleHolder or not status then
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
	-- The title row sizes its own text from the type roles (UIKit.title); the
	-- holder keeps it clear of the close button, as the old labels were.
	(titleHolder :: Frame).Size = UDim2.new(1, -(m.closeSize + 16), 1, 0);
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
		card.chip.TextSize = UITheme.textSize("label", m.touch)
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
	local chrome = m.pad * 2 + m.headerH + m.tabH + m.gap * 3 + m.footerH
	local room = math.max(vp.Y - topMargin - bottomMargin - chrome, math.floor(m.cardH * 0.6))
	local want = #cards * (m.cardH + m.gap) - m.gap
	-- The plates tab takes all the room; the car list and settings only what
	-- they need.
	local listH = if showing == "plates"
		then room
		elseif showing == "settings" then math.min(SettingsPanel.height(m.touch), room)
		else math.min(want, room)
	scroll.Size = UDim2.new(1, 0, 0, listH)
	PlatesPanel.fit(listH, m.touch)
	SettingsPanel.fit(listH, m.touch)
	if tabs then
		(tabs :: Frame).Size = UDim2.new(1, 0, 0, m.tabH)
		for _, b in tabButtons do
			b.TextSize = UITheme.textSize("title", m.touch)
		end
	end
	p.Size = UDim2.new(m.panelWidth, 0, 0, chrome + listH)

	local ob = openButton
	if ob then
		local w = if m.touch then math.clamp(vp.X * 0.2, 120, 220) else 92
		local h = math.max(UITheme.target(m.touch), if m.touch then math.clamp(vp.Y * 0.09, 44, 64) else 38)
		ob.Size = UDim2.fromOffset(w, h)
		ob.TextSize = if m.touch then math.max(UITheme.textSize("label", true), math.floor(h * 0.42)) else UITheme.textSize("label", false)
		ob.Position = UDim2.new(0.5, 0, 1, -math.floor(h * 0.35) - (if m.touch then 10 else 0))
	end
	refreshButtons()
end

local function paintTabs()
	-- The open tab takes the selected state (sodiumDim, sodium stroke).
	for name, b in tabButtons do
		UIKit.setSelected(b, name == showing)
	end
end

local function show(which: Tab)
	showing = which
	if list then
		(list :: ScrollingFrame).Visible = which == "cars"
	end
	PlatesPanel.setVisible(which == "plates")
	SettingsPanel.setVisible(which == "settings")
	if titleEnglish then
		(titleEnglish :: TextLabel).Text = if which == "cars"
			then "CHOOSE YOUR CAR"
			elseif which == "plates" then "NUMBER PLATES"
			else "SETTINGS"
	end
	if titleArabic then
		(titleArabic :: TextLabel).Text = if which == "cars" then "اختر سيارتك" elseif which == "plates" then "لوحات" else "الإعدادات"
	end
	if status then
		(status :: TextLabel).Text = if which == "plates"
			then "Plates are yours alone: nobody else can own the same one"
			-- The drift mode moved to the garage's tyres (garage-tyres-flames,
			-- 2026-10-05), so the sky is all this tab holds.
			elseif which == "settings" then "Time of day is saved with your progress"
			elseif isTouch() then "Tap a car to spawn it   ·   CARS reopens this"
			else "Click a car to spawn it   ·   M reopens this"
	end
	paintTabs()
	fit()
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
	back.BackgroundColor3 = C.asphalt950
	back.BackgroundTransparency = UITheme.alpha.scrim
	back.BorderSizePixel = 0
	back.Size = UDim2.fromScale(1, 1)
	back.Parent = g

	local p = Instance.new("Frame")
	p.Name = "Panel"
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.fromScale(0.5, 0.5)
	p.Size = UDim2.new(0.92, 0, 0, 0)
	p.BackgroundColor3 = C.asphalt900
	p.BackgroundTransparency = UITheme.alpha.panel
	p.BorderSizePixel = 0
	p.Active = true -- taps on the panel do not reach the backdrop
	p.ZIndex = 2
	UIKit.corner(p, "lg")
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
		-- The plates confirm sheet's scrim covers the backdrop, and a click
		-- still comes through it: the sheet's CANCEL is the way out.
		if PlatesPanel.sheetOpen() then
			return
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
	-- The screen title: English at the left in display, the Arabic at the
	-- right edge in sand (UI_SYSTEM.md "Arabic with English"). The holder
	-- stops short of the close button; the row sits centred in the header.
	local holder = Instance.new("Frame")
	holder.Name = "TitleHolder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, -56, 1, 0)
	holder.Parent = head
	titleHolder = holder
	local titleRow = UIKit.title(holder, "CHOOSE YOUR CAR", "اختر سيارتك", "display", isTouch())
	titleRow.AnchorPoint = Vector2.new(0, 0.5)
	titleRow.Position = UDim2.fromScale(0, 0.5)
	titleEnglish = titleRow:FindFirstChild("English") :: TextLabel
	titleArabic = titleRow:FindFirstChild("Arabic") :: TextLabel
	local close = UIKit.button(head, "×", "secondary", isTouch())
	close.Name = "Close"
	close.AutomaticSize = Enum.AutomaticSize.None
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.fromOffset(40, 40)
	-- A glyph, sized by fit() to the button: no interior padding to squeeze it.
	local closePad = close:FindFirstChildOfClass("UIPadding")
	if closePad then
		closePad:Destroy()
	end
	closeButton = close
	close.Activated:Connect(function()
		if PlatesPanel.sheetOpen() then
			return -- under the plates confirm sheet
		end
		SpawnMenu.close()
	end)

	local tabRow = Instance.new("Frame")
	tabRow.Name = "Tabs"
	tabRow.BackgroundTransparency = 1
	tabRow.LayoutOrder = 2
	tabRow.Size = UDim2.new(1, 0, 0, 34)
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabRow
	local tabList = { { "cars", "CARS" }, { "plates", "PLATES" }, { "settings", "SETTINGS" } }
	for i, pair in tabList do
		-- A tab is a chip in the title role (UI_SYSTEM.md: "title: section
		-- title, tab names"); paintTabs marks the open one selected.
		local b = UIKit.chip(tabRow, pair[2], isTouch())
		b.Name = pair[2]
		b.FontFace = UITheme.font("title")
		b.TextSize = UITheme.textSize("title", isTouch())
		b.LayoutOrder = i
		b.AutomaticSize = Enum.AutomaticSize.None
		b.Size = UDim2.new(1 / #tabList, -8 * (#tabList - 1) / #tabList, 1, 0)
		tabButtons[pair[1]] = b
		b.Activated:Connect(function()
			if PlatesPanel.sheetOpen() then
				return -- under the plates confirm sheet
			end
			show(pair[1] :: any)
		end)
	end
	tabRow.Parent = p
	tabs = tabRow

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Cars"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = 3
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = C.asphalt500
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
	PlatesPanel.build(p, 3)
	SettingsPanel.build(p, 3)

	for i, car in sortedCars() do
		buildCard(scroll, car.id, car.entry, i)
	end
	bindTapTracking()

	-- A hint: caption role in sandDim.
	local footer = label(p, "", "caption", C.sandDim)
	footer.Name = "Footer"
	footer.LayoutOrder = 4
	footer.Size = UDim2.new(1, 0, 0, 18)
	footer.TextXAlignment = Enum.TextXAlignment.Center
	status = footer

	-- The CARS button, on every platform: the only way back in on a phone.
	-- Bottom centre: the top left is the debug panel, the top centre the HUD,
	-- the top right Roblox's own menus, and on a phone the steer pad and the
	-- pedals leave the bottom centre free.
	-- A secondary button (UIKit), see-through over the road.
	local openGui = Instance.new("ScreenGui")
	openGui.Name = "HajwalaSpawnButton"
	openGui.ResetOnSpawn = false
	openGui.DisplayOrder = 7
	local open = UIKit.button(openGui, "CARS", "secondary", isTouch())
	open.Name = "OpenSpawnMenu"
	open.AnchorPoint = Vector2.new(0.5, 1)
	open.Position = UDim2.new(0.5, 0, 1, -14)
	open.Size = UDim2.fromOffset(92, 38)
	-- It floats over the road like the HUD card: alpha.hud, not a panel's.
	open.BackgroundTransparency = UITheme.alpha.hud
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
	show(showing)
	local ob = openButton
	if ob then
		ob.Text = if isTouch() then "CARS" else "CARS  (M)"
		ob.Visible = false -- it sits under the backdrop; hide it while open
	end
	refreshButtons()
end

function SpawnMenu.close()
	-- M closes the menu even over the plates confirm sheet: that cancels it.
	PlatesPanel.closeSheet()
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
		ob.Visible = not openButtonHidden
	end
end

-- Handles for the garage panel (garage plan, task 7, 2026-09-28).

-- Opens the menu straight on one tab: the panel's SHOP PLATES opens it on
-- the plates tab, which stays the one place plates are bought.
function SpawnMenu.openTab(which: string)
	if which == "cars" or which == "plates" or which == "settings" then
		showing = which
	end
	SpawnMenu.open()
end

-- Asks for a car exactly as tapping its card here does (same cooldown).
-- False if a spawn is still cooling down.
function SpawnMenu.requestCar(id: string): boolean
	if busy() or not remote then
		return false
	end
	requestSpawn(id)
	return true
end

-- The catalog cars in menu order (the panel's MY CARS uses the same order).
function SpawnMenu.cars(): { { id: string, entry: VehicleRig.CarEntry } }
	return sortedCars()
end

-- Hides the floating CARS button while the garage view fills the screen
-- (it sat over the car); M still opens the menu.
function SpawnMenu.setOpenButtonHidden(hidden: boolean)
	openButtonHidden = hidden
	local ob = openButton
	if ob and not SpawnMenu.isOpen() then
		ob.Visible = not hidden
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
	PlatesPanel.setCar(carId)
	refreshButtons()
end

function SpawnMenu.start(remotes: Folder)
	remote = remotes:WaitForChild("SpawnCar") :: RemoteEvent
	PlatesPanel.start(remotes)
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
