--!strict
-- The garage panel: the side panel of the customisation view (garage spec
-- docs/superpowers/specs/2026-09-28-garage-design.md §4 and §5). The owner's
-- rules, 2026-09-28: "Down one side, car fills the rest. Categories: my cars,
-- paint, wheels, plates, lights, sun strips, exhaust. Every change previews live
-- on the car. No confirm step until money is involved. Owned versus unowned
-- is unmistakable. Unowned previews with a price. Nothing is bought without
-- an explicit confirm. The panel collapses so the player can just look at the
-- car. Thumb-reachable and readable at phone size."
--
-- GarageView owns the view (camera, turntable, the preview car, LEAVE by Esc
-- or gamepad B); this module is built on its onEnter and torn down on its
-- onLeave. Every element comes from UIKit on the UITheme tokens, and the item
-- states are UI_SYSTEM.md "Shop items":
--   * on this car: button.selected ground and stroke, an ON CAR badge;
--   * owned: a secondary card with the gantry OWNED badge;
--   * for sale: a secondary card with the price chip (padlock, sodium);
--   * previewing: for sale plus the sodium stroke, and the foot bar
--     PREVIEWING · price · BUY;
--   * rare: a dusk diamond before the name.
--
-- Behaviour:
--   * A tap applies the item to the turntable car at once
--     (CarCosmetics.apply on the draft look). An owned (or stock) item is also
--     equipped at once through CosmeticsAction ("equip" / "plate"); taps are
--     coalesced per slot, so a burst of taps sends the last one, never one
--     per tap (the server allows 4 actions a second).
--   * An unowned item only previews. There is at most one unbought preview:
--     choosing any other card drops it; switching category keeps it; leaving
--     the view or switching car drops it (the preview car is rebuilt with the
--     saved look).
--   * BUY opens a confirm sheet (item, price, cash after, BUY / CANCEL); only
--     the sheet's BUY charges ("buy", then "equip").
--   * MY CARS swaps the turntable car (GarageView.setCar); DRIVE THIS asks
--     for that car the way the spawn menu does and leaves the view.
--   * PLATES equips one of your plates on this car; SHOP PLATES opens the
--     spawn menu's plates tab, which stays the one place plates are bought.
--   * The pill on the panel's edge, H or gamepad Y collapse the panel; the
--     car re-centres (GarageView.setPanelOpen).
--
-- Taps on cards and chips are tracked here through UserInputService, not
-- with Activated, for the reason SpawnMenu's header gives: on a phone a
-- GuiButton inside a ScrollingFrame blocks the drag that scrolls it, and a
-- touch that moves a little never fires Activated. A press counts as a tap
-- if it lifts over the same card within TAP_SLOP_PX and the list did not
-- scroll.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UITheme = require(Shared:WaitForChild("UITheme"))
local CosmeticsConfig = require(Shared:WaitForChild("CosmeticsConfig"))
local CarLook = require(Shared:WaitForChild("CarLook"))
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local VehicleRig = require(Shared:WaitForChild("VehicleRig"))
local CarPlateMounts = require(Shared:WaitForChild("CarPlateMounts"))
local PlateText = require(Shared:WaitForChild("PlateText"))
local PlateStyles = require(Shared:WaitForChild("PlateStyles"))
local Client = script.Parent.Parent
local UIKit = require(Client:WaitForChild("UIKit"))
local CarCosmetics = require(Client:WaitForChild("CarCosmetics"))
local ExhaustPops = require(Client:WaitForChild("ExhaustPops"))
local SpawnMenu = require(Client:WaitForChild("SpawnMenu"))
local GarageView = require(script.Parent:WaitForChild("GarageView"))

local GaragePanel = {}

type Category = CosmeticsConfig.Category
type Look = CarLook.Look
type Tab = "cars" | "paint" | "rims" | "plates" | "lights" | "decal" | "exhaust"
-- A cosmetic slot or the per-car plate.
type Slot = string

local player = Players.LocalPlayer
local C = UITheme.color

-- How far a finger may travel and still count as a tap rather than a
-- scroll (the spawn menu's value; an input threshold, not a drawn size).
local TAP_SLOP_PX = 14
-- How many times an equip or buy refused as "busy" (the server's rate limit) is
-- resent, one action's slot (1 / actionsPerSecond) apart, before the player
-- is told: 4 retries span the server's whole 1 s window.
local BUSY_RETRIES = 4
-- How long a result message stays up, seconds.
local TOAST_SECONDS = 3
-- Draw order: the gui sits under the spawn menu (DisplayOrder 20) so SHOP
-- PLATES can open that menu over the panel, and under GarageView's fade (50).
local DISPLAY_ORDER = 15
-- The confirm sheet's base ZIndex, above the panel's (UIKit.panel's 2).
local SHEET_Z = 20
-- A card's name gets two lines; a line is the text size times this (Builder
-- Sans' line box at LineHeight 1, with room for Arabic marks).
local LINE_BOX = 1.3

local TABS: { { id: Tab, label: string } } = {
	{ id = "cars", label = "MY CARS" },
	{ id = "paint", label = "PAINT" },
	{ id = "rims", label = "WHEELS" },
	{ id = "plates", label = "PLATES" },
	{ id = "lights", label = "LIGHTS" },
	-- "decal" stays the slot key (stored on profiles); the player reads SUN
	-- STRIPS, the banner across a windscreen's top (garage round 3 §4).
	{ id = "decal", label = "SUN STRIPS" },
	{ id = "exhaust", label = "EXHAUST" },
}

-- What each category is called on the confirm sheet.
local CATEGORY_NAMES: { [string]: string } = {
	paint = "Paint colour",
	finish = "Paint finish",
	rims = "Wheel finish",
	head = "Headlight colour",
	tail = "Tail light colour",
	decal = "Sun strip",
	exhaust = "Exhaust",
	tint = "Window tint",
}

-- CosmeticsAction statuses, as the player reads them.
local MESSAGES: { [string]: string } = {
	cash = "Not enough cash. Nothing was charged",
	unavailable = "The garage shop is unavailable right now. Nothing was charged",
	busy = "One moment, then try again",
	unknown = "That item isn't available",
	notowned = "You don't own that yet",
}

type Card = {
	key: string, -- item id, car id, or plate key ("" = the account's plate)
	slot: Slot?, -- nil for a car
	name: string,
	price: number,
	rare: boolean,
	frame: Frame,
	stroke: UIStroke,
	tile: Frame?,
	nameLabel: TextLabel,
	badges: Frame,
	badgeSig: string?,
}

type Tap = {
	gui: GuiObject,
	scroll: ScrollingFrame?,
	onTap: () -> (),
	onDown: ((down: boolean) -> ())?,
}

type Press = {
	tap: Tap,
	input: InputObject,
	origin: Vector2,
	canvas: Vector2,
	cancelled: boolean,
}

type UI = {
	gui: ScreenGui,
	dock: Frame,
	panel: Frame,
	panelPad: UIPadding,
	handle: TextButton,
	header: Frame,
	titleHolder: Frame,
	titleRow: Frame,
	cash: TextLabel,
	leave: TextButton,
	chips: Frame,
	chipButtons: { [Tab]: TextButton },
	sub: Frame,
	subList: UIListLayout,
	grid: ScrollingFrame,
	gridLayouts: { UIGridLayout },
	foot: Frame,
	footText: TextLabel,
	footPrice: TextLabel,
	footButton: TextButton,
	toast: Frame,
	toastLabel: TextLabel,
}

local remote: RemoteFunction? = nil
local ui: UI? = nil
local touch = false
local inside = false
local collapsed = false
local tab: Tab = "paint"
local carId = ""
local previewModel: Model? = nil
-- The one unbought item showing on the car.
local previewing: { slot: Slot, id: string }? = nil
-- Owned choices sent (or being sent) to the server, shown until the saved
-- look agrees. "" in the plate slot is the account's plate.
local want: { [Slot]: string } = {}
local sending: { [Slot]: boolean } = {}
-- Values the server said "done" to, waiting for the saved look to show them.
local confirmed: { [Slot]: string } = {}
-- Bumped on every enter, leave and car switch: replies from an earlier one
-- are ignored.
local epoch = 0
local cards: { Card } = {}
-- PAINT's finish row and its pills, flowed by relayout.
local finishRow: Frame? = nil
local finishPills: { GuiObject } = {}
-- The owned plates changed while the PLATES list could not be rebuilt.
local platesDirty = false
local taps: { Tap } = {}
local press: Press? = nil
type Sheet = { frame: Frame, scrim: Frame, update: () -> () }
local sheet: Sheet? = nil
local toastSerial = 0
local lastApplied: string? = nil
local modalBefore = false
local relaying = false
-- REV's last burst runs until this os.clock(); taps before then do nothing.
local revUntil = 0

------------------------------------------------------------------------
-- What the player owns and has saved (Player attributes from Economy).
------------------------------------------------------------------------

local function money(n: number): string
	return (tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function cashNow(): number
	return tonumber(player:GetAttribute("Cash")) or 0
end

local function ownedIds(): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local raw = player:GetAttribute("Cosmetics")
	if type(raw) == "string" then
		for id in string.gmatch(raw, "[^,]+") do
			out[id] = true
		end
	end
	return out
end

local function owns(id: string): boolean
	return CosmeticsConfig.isStock(id) or ownedIds()[id] == true
end

local function ownedPlates(): { string }
	local out: { string } = {}
	local raw = player:GetAttribute("Plates")
	if type(raw) == "string" then
		for k in string.gmatch(raw, "[^,]+") do
			table.insert(out, k)
		end
	end
	return out
end

-- The profile's looks. Empty encodes as "[]" (an empty Lua table is a JSON
-- array), so both "[]" and "{}" mean none.
local function looks(): { [string]: any }
	local raw = player:GetAttribute("Looks")
	if type(raw) ~= "string" or raw == "" then
		return {}
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok and type(decoded) == "table" then decoded else {}
end

-- This car's saved look; its plate only if the player still owns it.
local function savedLook(): Look
	local look = CarLook.clean(looks()[carId], owns)
	if look.plate and not table.find(ownedPlates(), look.plate) then
		look.plate = nil
	end
	return look
end

-- The effective id in a slot: the item's id, or for the plate the key
-- ("" for the account's plate).
local function slotValue(look: Look, slot: Slot): string
	if slot == "plate" then
		return look.plate or ""
	end
	return CarLook.item(look, slot :: Category).id
end

local function setSlot(look: Look, slot: Slot, value: string)
	if slot == "plate" then
		look.plate = if value == "" then nil else value
	else
		(look :: any)[slot] = value
	end
end

-- What the turntable car shows: the saved look, then choices on their way to
-- the server, then the unbought preview.
local function draftLook(saved: Look?): Look
	local look = table.clone(saved or savedLook())
	for slot, value in want do
		setSlot(look, slot, value)
	end
	local p = previewing
	if p then
		setSlot(look, p.slot, p.id)
	end
	return look
end

-- The plate a car carries for a per-car choice (PlateService.plateFor).
local function plateKeyFor(choice: string?): string?
	if choice and choice ~= "" then
		return choice
	end
	local equipped = player:GetAttribute("PlateEquipped")
	if type(equipped) == "string" and equipped ~= "" then
		return equipped
	end
	local default = player:GetAttribute("PlateDefault")
	return if type(default) == "string" then default else nil
end

-- A plate as a player reads it: "KSA ABJ 7" (PlatesPanel's wording).
local function shownPlate(key: string): string
	local typed = PlateText.typed(key)
	if not typed then
		return key
	end
	local code = PlateText.styleOf(key)
	for _, st in PlateText.STYLES do
		if st.code == code then
			return `{st.name} {typed}`
		end
	end
	return typed
end

local function plateFormat(): PlateStyles.Format
	local mounts = CarPlateMounts.cars[carId]
	local rear = if mounts then mounts.rear else nil
	return if rear and rear.format == "long" then "long" else "short"
end

-- The car this player has spawned, if any.
local function drivingId(): string?
	local folder = Workspace:FindFirstChild("Cars")
	if not folder then
		return nil
	end
	for _, m in folder:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("OwnerUserId") == player.UserId then
			local id = m:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
			return if type(id) == "string" then id else nil
		end
	end
	return nil
end

local function paintable(): boolean
	return CarCosmetics.paintable(carId)
end

-- Whether this car shows a slot's items at all: paint and finish need a
-- painted piece, the strip, tips and tint a spot (CarCosmetics.hasSpot).
-- Items the car can't show are greyed out and can't be chosen (final review
-- fix 5).
local function showsSlot(slot: string, canPaint: boolean, hasStrip: boolean, hasTips: boolean, hasWindows: boolean): boolean
	if slot == "paint" or slot == "finish" then
		return canPaint
	elseif slot == "decal" then
		return hasStrip
	elseif slot == "exhaust" then
		return hasTips
	elseif slot == "tint" then
		return hasWindows
	end
	return true
end

local function shows(slot: string): boolean
	return showsSlot(slot, paintable(), CarCosmetics.hasSpot(carId, "windscreen"), CarCosmetics.hasSpot(carId, "exhaust"), CarCosmetics.hasSpot(carId, "windows"))
end

------------------------------------------------------------------------
-- Sizes, all from the tokens.
------------------------------------------------------------------------

local function px(n: number): number
	return UITheme.px(n, touch)
end

local function space(name: string): number
	return px((UITheme.space :: any)[name])
end

local function target(): number
	return UITheme.target(touch)
end

local function lineBox(role: UITheme.Role): number
	return math.ceil(UITheme.textSize(role, touch) * LINE_BOX)
end

-- A badge's height: the tallest badge text (a price) and its xs padding.
local function badgeHeight(): number
	return UITheme.textSize("price", touch) + 2 * space("xs")
end

local function cardHeight(): number
	return 2 * space("sm") + target() + space("sm") + 2 * lineBox("heading") + space("xs") + badgeHeight()
end

local function panelWidth(u: UI): number
	local sp = UITheme.sidePanel
	if not touch then
		return sp.width
	end
	local vp = u.gui.AbsoluteSize.X
	if vp < 1 then
		local cam = Workspace.CurrentCamera
		vp = if cam then cam.ViewportSize.X else sp.width / sp.touchFraction
	end
	return math.min(math.floor(vp * sp.touchFraction), sp.touchMax)
end

local function columns(u: UI): number
	return if panelWidth(u) < UITheme.sidePanel.oneColumnBelow then 1 else 2
end

------------------------------------------------------------------------
-- Talking to the server.
------------------------------------------------------------------------

local function invoke(...: any): string
	local r = remote
	if not r then
		return "unavailable"
	end
	local args = table.pack(...)
	local ok, reply = pcall(function()
		return r:InvokeServer(table.unpack(args, 1, args.n))
	end)
	if ok and type(reply) == "table" and type(reply.status) == "string" then
		return reply.status
	end
	return "unavailable"
end

------------------------------------------------------------------------
-- Small pieces.
------------------------------------------------------------------------

local function padAll(obj: GuiObject, amount: number): UIPadding
	local p = Instance.new("UIPadding")
	local u = UDim.new(0, amount)
	p.PaddingTop, p.PaddingBottom, p.PaddingLeft, p.PaddingRight = u, u, u, u
	p.Parent = obj
	return p
end

local function list(obj: GuiObject, horizontal: boolean, gap: number): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, gap)
	if horizontal then
		l.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	l.Parent = obj
	return l
end

local function scroller(name: string, horizontal: boolean): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.Name = name
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.CanvasSize = UDim2.fromOffset(0, 0)
	s.AutomaticCanvasSize = if horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y
	s.ScrollingDirection = if horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y
	-- The chip rows scroll with a finger or the wheel; no bar under them.
	s.ScrollBarThickness = if horizontal then 0 else space("xs")
	s.ScrollBarImageColor3 = C.asphalt500
	s.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	s.Active = true
	return s
end

-- A rare item's name: the dusk diamond before it (UI_SYSTEM.md "Rare").
local function nameText(name: string, rare: boolean): string
	if not rare then
		return name
	end
	return `<font color="#{C.dusk:ToHex()}">◆</font> {name}`
end

local function registerTap(t: Tap)
	table.insert(taps, t)
end

------------------------------------------------------------------------
-- Swatches: what an item looks like, drawn in the card's tile.
------------------------------------------------------------------------

local function tileBlank(tile: Frame)
	tile.BackgroundColor3 = C.asphalt700
	UIKit.stroke(tile, "asphalt600", UITheme.stroke.hairline)
end

local function tileCircles(tile: Frame, n: number, color: Color3, aspect: number?)
	tileBlank(tile)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	local l = list(row, true, space("xs"))
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.Parent = tile
	local d = math.floor(target() * 0.5)
	for i = 1, n do
		local dot = Instance.new("Frame")
		dot.BackgroundColor3 = color
		dot.BorderSizePixel = 0
		-- aspect: a dot this many times wider than tall (the Big Oval Tip).
		dot.Size = UDim2.fromOffset(math.floor(d * (aspect or 1)), d)
		dot.LayoutOrder = i
		UIKit.corner(dot, "pill")
		-- A dark tip (Quad Tips) would vanish on the tile without an edge.
		UIKit.stroke(dot, "asphalt500", UITheme.stroke.hairline)
		dot.Parent = row
	end
end

local function drawItemTile(tile: Frame, item: CosmeticsConfig.Item)
	local c = item.category
	if c == "paint" then
		if item.color then
			tile.BackgroundColor3 = item.color
		else
			-- Factory: the car's own catalog paint.
			tile.BackgroundColor3 = ConfigLoader.entry(carId).body.paint
		end
	elseif c == "rims" or c == "head" or c == "tail" then
		if item.color then
			tileCircles(tile, 1, item.color)
		else
			tileBlank(tile)
		end
	elseif c == "decal" then
		if item.stripColor then
			tile.BackgroundColor3 = item.stripColor
			if item.stripColor2 then
				local g = Instance.new("UIGradient")
				g.Color = ColorSequence.new(item.stripColor, item.stripColor2)
				g.Parent = tile
			end
			if item.text and item.text ~= "" then
				local t = UIKit.text(tile, item.text, "label", "paint", touch, false)
				t.TextColor3 = item.textColor or C.paint
				t.AnchorPoint = Vector2.new(0.5, 0.5)
				t.Position = UDim2.fromScale(0.5, 0.5)
			end
		else
			tileBlank(tile)
		end
	elseif c == "exhaust" then
		local n = item.tips or 0
		if n > 0 and item.tipColor then
			local style = if item.tipStyle then CosmeticsConfig.render.tipStyles[item.tipStyle] else nil
			tileCircles(tile, n, item.tipColor, style and style.tileAspect)
		else
			tileBlank(tile)
		end
	elseif c == "tint" then
		-- The film over sand, as the desert looks through a side window.
		if item.glassColor and item.glassTransparency then
			tile.BackgroundColor3 = C.sand
			local film = Instance.new("Frame")
			film.Name = "Film"
			film.BorderSizePixel = 0
			film.Size = UDim2.fromScale(1, 1)
			film.BackgroundColor3 = item.glassColor
			film.BackgroundTransparency = item.glassTransparency
			film.Parent = tile
			-- Limo's film is nearly the card's own colour: an edge keeps the
			-- swatch from vanishing, as the dark exhaust tips have.
			UIKit.stroke(tile, "asphalt500", UITheme.stroke.hairline)
		else
			tileBlank(tile)
		end
	else
		tileBlank(tile)
	end
end

------------------------------------------------------------------------
-- Cards and their states.
------------------------------------------------------------------------

type CardState = {
	disabled: boolean,
	onCar: boolean, -- saved on this car
	showing: boolean, -- on the turntable car now
	owned: boolean,
	driving: boolean, -- MY CARS: the car you have out
}

-- What every card's state is read from, worked out once per repaint (the
-- looks decode JSON and the owned set splits a string).
type Context = {
	saved: Look,
	draft: Look,
	driving: string?,
	paintable: boolean,
	hasStrip: boolean,
	hasTips: boolean,
	hasWindows: boolean,
	owned: { [string]: boolean },
}

local function context(): Context
	local saved = savedLook()
	return {
		saved = saved,
		draft = draftLook(saved),
		driving = drivingId(),
		paintable = paintable(),
		hasStrip = CarCosmetics.hasSpot(carId, "windscreen"),
		hasTips = CarCosmetics.hasSpot(carId, "exhaust"),
		hasWindows = CarCosmetics.hasSpot(carId, "windows"),
		owned = ownedIds(),
	}
end

local function stateOf(card: Card, ctx: Context): CardState
	local slot = card.slot
	if slot == nil then
		return {
			disabled = false,
			onCar = false,
			showing = card.key == carId,
			owned = true,
			driving = ctx.driving == card.key,
		}
	end
	local disabled = not showsSlot(slot, ctx.paintable, ctx.hasStrip, ctx.hasTips, ctx.hasWindows)
	return {
		disabled = disabled,
		onCar = slotValue(ctx.saved, slot) == card.key,
		showing = slotValue(ctx.draft, slot) == card.key,
		owned = slot == "plate" or CosmeticsConfig.isStock(card.key) or ctx.owned[card.key] == true,
		driving = false,
	}
end

local function setBadge(card: Card, kind: string?, text: string)
	local sig = if kind then `{kind}:{text}` else ""
	if card.badgeSig == sig then
		return
	end
	card.badgeSig = sig
	for _, child in card.badges:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if kind then
		UIKit.badge(card.badges, kind :: any, text, touch)
	end
end

local function paintCard(card: Card, down: boolean?, ctx: Context?)
	local st = stateOf(card, ctx or context())
	local look: UITheme.State
	local sodiumStroke = false
	if st.disabled then
		look = UITheme.button.disabled
	elseif card.slot == nil then
		look = if st.showing then UITheme.button.selected elseif down then UITheme.button.secondaryPressed else UITheme.button.secondary
		sodiumStroke = st.showing
	elseif st.onCar and st.showing then
		look = UITheme.button.selected
		sodiumStroke = true
	else
		look = if down then UITheme.button.secondaryPressed else UITheme.button.secondary
		-- Previewing: the sodium stroke on a secondary card.
		sodiumStroke = st.showing
	end
	card.frame.BackgroundColor3 = look.bg
	card.nameLabel.TextColor3 = look.text
	card.stroke.Color = if sodiumStroke then C.sodium else C.asphalt600
	card.stroke.Thickness = if sodiumStroke then UITheme.stroke.selected else UITheme.stroke.hairline
	local tile = card.tile
	if tile then
		tile.BackgroundTransparency = if st.disabled then UITheme.alpha.disabled else 0
	end
	if st.disabled then
		setBadge(card, nil, "")
	elseif card.slot == nil then
		if st.driving then
			setBadge(card, "owned", "✓ DRIVING")
		else
			setBadge(card, nil, "")
		end
	elseif st.onCar then
		setBadge(card, "oncar", "ON CAR")
	elseif st.owned then
		setBadge(card, "owned", "✓ OWNED")
	else
		setBadge(card, "price", money(card.price))
	end
end

local function paintCards()
	local ctx = context()
	for _, card in cards do
		paintCard(card, nil, ctx)
	end
end

-- A grid card: tile, name (up to two lines), badge.
local function buildCard(parent: Instance, order: number, key: string, slot: Slot?, name: string, price: number, rare: boolean, drawTile: (Frame) -> ()): Card
	local f = Instance.new("Frame")
	f.Name = "Card_" .. (if key == "" then "account" else key)
	f.BackgroundColor3 = UITheme.button.secondary.bg
	f.BorderSizePixel = 0
	f.LayoutOrder = order
	f.Active = true
	UIKit.corner(f, "md")
	local stroke = UIKit.stroke(f, "asphalt600", UITheme.stroke.hairline)
	padAll(f, space("sm"))

	local tile = Instance.new("Frame")
	tile.Name = "Tile"
	tile.BorderSizePixel = 0
	tile.Size = UDim2.new(1, 0, 0, target())
	tile.ClipsDescendants = true
	UIKit.corner(tile, "sm")
	tile.Parent = f
	drawTile(tile)

	local label = UIKit.text(f, "", "heading", "paint", touch, true)
	label.Name = "ItemName"
	label.AutomaticSize = Enum.AutomaticSize.None
	label.RichText = true
	label.Text = nameText(name, rare)
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Position = UDim2.fromOffset(0, target() + space("sm"))
	label.Size = UDim2.new(1, 0, 0, 2 * lineBox("heading"))

	local badges = Instance.new("Frame")
	badges.Name = "Badges"
	badges.BackgroundTransparency = 1
	badges.AnchorPoint = Vector2.new(0, 1)
	badges.Position = UDim2.fromScale(0, 1)
	badges.Size = UDim2.new(1, 0, 0, badgeHeight())
	list(badges, true, space("xs"))
	badges.Parent = f

	f.Parent = parent
	local card: Card = {
		key = key,
		slot = slot,
		name = name,
		price = price,
		rare = rare,
		frame = f,
		stroke = stroke,
		tile = tile,
		nameLabel = label,
		badges = badges,
	}
	table.insert(cards, card)
	return card
end

-- A finish pill: name and badge in one row, for the row above the colours.
local function buildPill(parent: Instance, order: number, item: CosmeticsConfig.Item): Card
	local f = Instance.new("Frame")
	f.Name = "Pill_" .. item.id
	f.BackgroundColor3 = UITheme.button.secondary.bg
	f.BorderSizePixel = 0
	f.LayoutOrder = order
	f.AutomaticSize = Enum.AutomaticSize.X
	f.Size = UDim2.fromOffset(0, target())
	f.Active = true
	UIKit.corner(f, "sm")
	local stroke = UIKit.stroke(f, "asphalt600", UITheme.stroke.hairline)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, space("sm"))
	pad.PaddingRight = UDim.new(0, space("sm"))
	pad.Parent = f
	list(f, true, space("sm"))
	local label = UIKit.text(f, "", "label", "paint", touch, false)
	label.Name = "ItemName"
	label.RichText = true
	label.Text = nameText(string.upper(item.name), item.rare == true)
	label.LayoutOrder = 1
	local badges = Instance.new("Frame")
	badges.Name = "Badges"
	badges.BackgroundTransparency = 1
	badges.AutomaticSize = Enum.AutomaticSize.X
	badges.Size = UDim2.fromOffset(0, badgeHeight())
	badges.LayoutOrder = 2
	list(badges, true, space("xs"))
	badges.Parent = f
	f.Parent = parent
	local card: Card = {
		key = item.id,
		slot = item.category,
		name = item.name,
		price = item.price,
		rare = item.rare == true,
		frame = f,
		stroke = stroke,
		tile = nil,
		nameLabel = label,
		badges = badges,
	}
	table.insert(cards, card)
	return card
end

------------------------------------------------------------------------
-- Toast.
------------------------------------------------------------------------

local relayout: (u: UI) -> ()

local function toast(text: string, kind: "done" | "error" | "info")
	local u = ui
	if not u then
		return
	end
	toastSerial += 1
	local mine = toastSerial
	if kind == "done" then
		u.toast.BackgroundColor3 = C.asphalt800
		u.toastLabel.TextColor3 = C.gantryBright
		u.toastLabel.Text = "✓ " .. text
	elseif kind == "error" then
		u.toast.BackgroundColor3 = C.beaconDim
		u.toastLabel.TextColor3 = C.paint
		u.toastLabel.Text = text
	else
		u.toast.BackgroundColor3 = C.asphalt800
		u.toastLabel.TextColor3 = C.sand
		u.toastLabel.Text = text
	end
	u.toast.Visible = true
	relayout(u)
	task.delay(TOAST_SECONDS, function()
		if toastSerial == mine and ui == u then
			u.toast.Visible = false
			relayout(u)
		end
	end)
end

------------------------------------------------------------------------
-- The car on the turntable, and the whole panel's state.
------------------------------------------------------------------------

local function applyPreview()
	local m = previewModel
	if not m or not m.Parent then
		return
	end
	local look = draftLook()
	local sig = `{carId}|{CarLook.encode(look)}|{look.plate or ""}|{plateKeyFor(look.plate) or ""}`
	if sig == lastApplied then
		return
	end
	lastApplied = sig
	local ok, err = pcall(function()
		CarCosmetics.apply(m, look, carId)
	end)
	if not ok then
		warn(`[GaragePanel] apply on {carId}: {err}`)
	end
	m:SetAttribute("Plate", plateKeyFor(look.plate))
end

local function paintFoot(u: UI)
	local p = previewing
	local was = u.foot.Visible
	if p and tab ~= "cars" then
		local item = CosmeticsConfig.find(p.id)
		u.footText.Text = "PREVIEWING"
		u.footText.TextColor3 = C.sand
		u.footText.FontFace = UITheme.font("label")
		u.footText.TextSize = UITheme.textSize("label", touch)
		u.footPrice.Visible = true
		u.footPrice.Text = money(if item then item.price else 0)
		u.footButton.Text = "BUY"
		u.foot.Visible = true
	elseif tab == "cars" then
		u.footText.Text = ConfigLoader.entry(carId).displayName
		u.footText.TextColor3 = C.paint
		u.footText.FontFace = UITheme.font("heading")
		u.footText.TextSize = UITheme.textSize("heading", touch)
		u.footPrice.Visible = false
		u.footButton.Text = "DRIVE THIS"
		u.foot.Visible = true
	else
		u.foot.Visible = false
	end
	if was ~= u.foot.Visible then
		relayout(u)
	end
end

-- A new session of choices (enter, leave, car switch): what was wanted or
-- sent for the last one is dropped, and its replies are ignored.
local function newEpoch()
	epoch += 1
	table.clear(want)
	table.clear(sending)
	table.clear(confirmed)
end

local buildTab: (u: UI) -> ()

local function refresh()
	local u = ui
	if not u or not inside then
		return
	end
	if platesDirty and not sheet then
		platesDirty = false
		if tab == "plates" then
			buildTab(u)
		end
	end
	-- Choices the saved look now agrees with are settled.
	local saved = savedLook()
	for slot, value in want do
		if not sending[slot] and slotValue(saved, slot) == value then
			want[slot] = nil
			confirmed[slot] = nil
		end
	end
	applyPreview()
	paintCards()
	paintFoot(u)
	u.cash.Text = money(cashNow())
	local s = sheet
	if s then
		s.update()
	end
end

------------------------------------------------------------------------
-- Choosing things.
------------------------------------------------------------------------

-- Sends the latest wanted value for a slot, then again if a newer tap came
-- while it was on its way: never more than one action in flight per slot.
local function sendEquip(slot: Slot)
	if sending[slot] then
		return
	end
	sending[slot] = true
	local myEpoch = epoch
	task.spawn(function()
		local forCar = carId
		local busyTries = 0
		while inside and epoch == myEpoch do
			local value = want[slot]
			if value == nil or confirmed[slot] == value then
				break
			end
			-- Whatever was confirmed before is superseded by this send: left
			-- set, it could later block a tap back to that value (review fix
			-- round 2).
			confirmed[slot] = nil
			local status
			if slot == "plate" then
				status = invoke("plate", forCar, if value == "" then nil else value)
			else
				status = invoke("equip", forCar, slot, value)
			end
			-- A reply for another car or an earlier visit changes nothing here:
			-- that session's state is gone, and its own loop runs for it.
			if epoch ~= myEpoch then
				return
			end
			if want[slot] ~= value then
				busyTries = 0
				continue -- a newer tap; send that
			end
			if status == "busy" and busyTries < BUSY_RETRIES then
				-- The server's rate limit: wait one action's slot and resend
				-- the latest choice before saying anything.
				busyTries += 1
				task.wait(1 / CosmeticsConfig.actionsPerSecond)
				continue
			end
			if status ~= "done" then
				want[slot] = nil
				confirmed[slot] = nil
				toast(MESSAGES[status] or MESSAGES.unavailable, if status == "busy" then "info" else "error")
			elseif slotValue(savedLook(), slot) == value then
				want[slot] = nil
				confirmed[slot] = nil
			else
				confirmed[slot] = value -- shown until the saved look arrives
			end
			break
		end
		if epoch ~= myEpoch then
			return
		end
		sending[slot] = false
		refresh()
		-- A tap that came while the last reply was on its way.
		local latest = want[slot]
		if inside and latest ~= nil and confirmed[slot] ~= latest then
			sendEquip(slot)
		end
	end)
end

local function chooseItem(slot: Category, id: string)
	if not shows(slot) then
		return
	end
	local p = previewing
	if p and p.slot == slot and p.id == id then
		return
	end
	-- Choosing any other card drops an unbought preview.
	previewing = nil
	if owns(id) then
		if slotValue(draftLook(), slot) ~= id or want[slot] ~= nil then
			want[slot] = id
			sendEquip(slot)
		end
	else
		previewing = { slot = slot :: string, id = id }
	end
	refresh()
end

local function choosePlate(key: string)
	previewing = nil
	want.plate = key
	sendEquip("plate")
	refresh()
end

local function chooseCar(id: string)
	if id == carId then
		return
	end
	previewing = nil
	newEpoch()
	GarageView.setCar(id)
	previewModel = GarageView.preview()
	carId = id
	lastApplied = nil
	local u = ui
	if u then
		-- The cards read the car (the Factory swatch, paint, plate art); MY
		-- CARS itself only repaints, so its list keeps its scroll.
		if tab == "cars" then
			paintFoot(u)
		else
			buildTab(u)
		end
	end
	refresh()
end

------------------------------------------------------------------------
-- The confirm sheet.
------------------------------------------------------------------------

-- Closes the open sheet, or only `which` if given: a buy reply that comes
-- back after the player left and re-entered must not close the new sheet.
local function closeSheet(which: Sheet?)
	local s = which or sheet
	if s and sheet == s then
		sheet = nil
	end
	if s then
		s.frame:Destroy()
		s.scrim:Destroy()
	end
end

local function openSheet(u: UI)
	local p = previewing
	if sheet or not p then
		return
	end
	local item = CosmeticsConfig.find(p.id)
	if not item then
		return
	end
	local frame, scrim = UIKit.sheet(u.gui, touch, SHEET_Z)
	frame.Name = "ConfirmSheet"
	scrim.Name = "ConfirmScrim"
	-- Active does not stop a button under the scrim from hearing a click
	-- (SpawnMenu's header notes the same; measured again 2026-09-28: LEAVE
	-- fired through it). The panel's own buttons check `sheet` instead;
	-- Active still keeps the turntable drag from starting on the scrim.
	scrim.Active = true
	-- Opaque, not alpha.panel: at 0.06 the cards under the sheet showed
	-- through its rows (measured in Play, 2026-09-28).
	frame.BackgroundTransparency = 0
	local pad = space("lg")
	local width = panelWidth(u) - 2 * pad
	frame.Position = UDim2.new(0, math.floor(panelWidth(u) / 2), 0.5, 0)
	frame.Size = UDim2.fromOffset(width, 0)
	local layout = list(frame, false, space("md"))

	local title = UIKit.title(frame, "BUY", "شراء", "title", touch)
	title.LayoutOrder = 1

	local name = UIKit.text(frame, "", "heading", "paint", touch, true)
	name.RichText = true
	name.Text = nameText(item.name, item.rare == true)
	name.LayoutOrder = 2
	local what = UIKit.text(frame, `{CATEGORY_NAMES[item.category] or item.category} · yours on every car`, "caption", "sandDim", touch, true)
	what.LayoutOrder = 3

	local function row(order: number, labelText: string, valueColor: UIKit.ColorName): TextLabel
		local r = Instance.new("Frame")
		r.BackgroundTransparency = 1
		r.Size = UDim2.new(1, 0, 0, lineBox("price"))
		r.LayoutOrder = order
		local l = UIKit.text(r, labelText, "body", "sand", touch, false)
		l.AnchorPoint = Vector2.new(0, 0.5)
		l.Position = UDim2.fromScale(0, 0.5)
		local v = UIKit.text(r, "", "price", valueColor, touch, false)
		v.AnchorPoint = Vector2.new(1, 0.5)
		v.Position = UDim2.fromScale(1, 0.5)
		v.TextXAlignment = Enum.TextXAlignment.Right
		r.Parent = frame
		return v
	end
	local priceValue = row(4, "Price", "sodium")
	local cashValue = row(5, "Your cash", "paint")
	local afterValue = row(6, "Cash after", "paint")

	local short = UIKit.text(frame, "", "body", "beacon", touch, true)
	short.Name = "Short"
	short.LayoutOrder = 7

	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.BackgroundTransparency = 1
	buttons.Size = UDim2.new(1, 0, 0, target())
	buttons.LayoutOrder = 8
	local bl = list(buttons, true, space("sm"))
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	buttons.Parent = frame
	local cancel = UIKit.button(buttons, "CANCEL", "secondary", touch)
	cancel.Name = "Cancel"
	cancel.AutomaticSize = Enum.AutomaticSize.None
	cancel.Size = UDim2.new(0.5, -math.floor(space("sm") / 2), 1, 0)
	cancel.LayoutOrder = 1
	local buy = UIKit.button(buttons, "BUY", "primary", touch)
	buy.Name = "Buy"
	buy.AutomaticSize = Enum.AutomaticSize.None
	buy.Size = UDim2.new(0.5, -math.floor(space("sm") / 2), 1, 0)
	buy.LayoutOrder = 2

	local working = false
	local mine: Sheet
	local function update()
		local cash = cashNow()
		priceValue.Text = money(item.price)
		cashValue.Text = money(cash)
		local lacking = item.price - cash
		-- Short: the shortfall in beacon rather than a cash-after of 0.
		afterValue.Text = if lacking > 0 then `Short {money(lacking)}` else money(cash - item.price)
		afterValue.TextColor3 = if lacking > 0 then C.beacon else C.paint
		short.Visible = lacking > 0
		short.Text = if lacking > 0 then "Not enough cash to buy this" else ""
		UIKit.setDisabled(buy, working or lacking > 0)
		UIKit.setDisabled(cancel, working)
	end

	local function fitHeight()
		frame.Size = UDim2.fromOffset(width, layout.AbsoluteContentSize.Y + 2 * pad)
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitHeight)
	fitHeight()

	cancel.Activated:Connect(function()
		if not working then
			closeSheet()
			refresh()
		end
	end)
	buy.Activated:Connect(function()
		if working or cashNow() < item.price then
			return
		end
		working = true
		update()
		local slot, id = p.slot, p.id
		local forCar = carId
		local myEpoch = epoch
		local status = invoke("buy", id)
		-- "busy" is the server's rate limit (an equip may be in flight):
		-- resend the buy one action's slot later, like sendEquip. Only this
		-- sheet's BUY gets here (final review fix 4).
		local buyTries = 0
		while status == "busy" and buyTries < BUSY_RETRIES and inside and epoch == myEpoch do
			buyTries += 1
			task.wait(1 / CosmeticsConfig.actionsPerSecond)
			status = invoke("buy", id)
		end
		if status == "done" or status == "owned" then
			-- The buy used one of the server's actions: a "busy" here is the
			-- rate limit, retried like sendEquip's.
			local fitted = invoke("equip", forCar, slot, id)
			local tries = 0
			while fitted == "busy" and tries < BUSY_RETRIES and inside and epoch == myEpoch do
				tries += 1
				task.wait(1 / CosmeticsConfig.actionsPerSecond)
				fitted = invoke("equip", forCar, slot, id)
			end
			if inside and epoch == myEpoch then
				local cur = previewing
				if cur and cur.id == id then
					previewing = nil
				end
				if fitted == "done" then
					if slotValue(savedLook(), slot) ~= id then
						-- Shown until the saved look arrives; already sent.
						want[slot] = id
						confirmed[slot] = id
					end
					toast(`Bought and fitted: {item.name}`, "done")
				else
					toast(`Bought {item.name}. Tap it to fit it`, "info")
				end
			end
		elseif inside and epoch == myEpoch then
			toast(MESSAGES[status] or MESSAGES.unavailable, if status == "busy" then "info" else "error")
		end
		working = false
		closeSheet(mine)
		refresh()
	end)

	mine = { frame = frame, scrim = scrim, update = update }
	sheet = mine
	update()
end

------------------------------------------------------------------------
-- The category's content.
------------------------------------------------------------------------

local function newGrid(u: UI, parent: Instance, order: number): Frame
	local g = Instance.new("Frame")
	g.Name = "Grid"
	g.BackgroundTransparency = 1
	g.AutomaticSize = Enum.AutomaticSize.Y
	g.Size = UDim2.new(1, 0, 0, 0)
	g.LayoutOrder = order
	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.CellPadding = UDim2.fromOffset(space("sm"), space("sm"))
	layout.Parent = g
	table.insert(u.gridLayouts, layout)
	g.Parent = parent
	return g
end

local function sizeGrids(u: UI)
	local cols = columns(u)
	local gap = space("sm")
	for _, layout in u.gridLayouts do
		layout.CellSize = UDim2.new(1 / cols, -math.ceil(gap * (cols - 1) / cols), 0, cardHeight())
	end
end

local function itemCards(u: UI, parent: Instance, category: Category, orderBase: number)
	for i, item in CosmeticsConfig.inCategory(category) do
		local card = buildCard(parent, orderBase + i, item.id, category, item.name, item.price, item.rare == true, function(tile)
			drawItemTile(tile, item)
		end)
		registerTap({
			gui = card.frame,
			scroll = u.grid,
			onTap = function()
				chooseItem(category, item.id)
			end,
			onDown = function(down)
				paintCard(card, down)
			end,
		})
	end
end

local function clearContent(u: UI)
	closeSheet()
	press = nil
	finishRow = nil
	table.clear(finishPills)
	table.clear(cards)
	table.clear(taps)
	table.clear(u.gridLayouts)
	for _, child in u.grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for _, child in u.sub:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- The chips go through the tracker too, like every card.
local function registerChips(u: UI)
	for _, entry in TABS do
		local b = u.chipButtons[entry.id]
		registerTap({
			gui = b,
			scroll = nil,
			onTap = function()
				if tab ~= entry.id then
					tab = entry.id
					buildTab(u)
					refresh()
				end
			end,
		})
	end
end

local function paintChips(u: UI)
	for id, b in u.chipButtons do
		UIKit.setSelected(b, id == tab)
		-- UIKit makes a pressable Active; the tracker handles these taps.
		b.Active = false
	end
end

buildTab = function(u: UI)
	clearContent(u)
	registerChips(u)
	paintChips(u)
	u.grid.CanvasPosition = Vector2.zero

	if tab == "cars" then
		local g = newGrid(u, u.grid, 1)
		for i, car in SpawnMenu.cars() do
			local entry = car.entry
			local card = buildCard(g, i, car.id, nil, entry.displayName, 0, false, function(tile)
				tile.BackgroundColor3 = entry.body.paint
			end)
			registerTap({
				gui = card.frame,
				scroll = u.grid,
				onTap = function()
					chooseCar(car.id)
				end,
				onDown = function(down)
					paintCard(card, down)
				end,
			})
		end
	elseif tab == "paint" then
		-- The finish row above the colours: it wraps (relayout flows it), so
		-- every finish shows at any width.
		local row = Instance.new("Frame")
		row.Name = "Finishes"
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, target())
		row.LayoutOrder = 1
		row.Parent = u.sub
		finishRow = row
		for i, item in CosmeticsConfig.inCategory("finish") do
			local card = buildPill(row, i, item)
			table.insert(finishPills, card.frame)
			card.frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				if ui == u then
					relayout(u)
				end
			end)
			registerTap({
				gui = card.frame,
				scroll = nil,
				onTap = function()
					chooseItem("finish", item.id)
				end,
				onDown = function(down)
					paintCard(card, down)
				end,
			})
		end
		if not paintable() then
			local note = UIKit.text(u.sub, "This car's paint can't be changed yet", "caption", "sand", touch, true)
			note.Name = "NotPaintable"
			note.LayoutOrder = 2
		end
		itemCards(u, newGrid(u, u.grid, 1), "paint", 0)
		-- Window tint, the third row under PAINT (garage round 2 §4).
		local tint = UIKit.title(u.grid, "WINDOW TINT", "تظليل", "title", touch)
		tint.LayoutOrder = 2
		if not shows("tint") then
			local note = UIKit.text(u.grid, "This car's windows can't be tinted yet", "caption", "sand", touch, true)
			note.Name = "NoWindows"
			note.LayoutOrder = 3
		end
		itemCards(u, newGrid(u, u.grid, 4), "tint", 0)
	elseif tab == "rims" then
		itemCards(u, newGrid(u, u.grid, 1), "rims", 0)
	elseif tab == "lights" then
		local head = UIKit.title(u.grid, "HEADLIGHTS", "الأنوار الأمامية", "title", touch)
		head.LayoutOrder = 1
		itemCards(u, newGrid(u, u.grid, 2), "head", 0)
		local tail = UIKit.title(u.grid, "TAIL LIGHTS", "الأنوار الخلفية", "title", touch)
		tail.LayoutOrder = 3
		itemCards(u, newGrid(u, u.grid, 4), "tail", 0)
	elseif tab == "decal" then
		local title = UIKit.title(u.grid, "SUN STRIPS", "شريط", "title", touch)
		title.LayoutOrder = 1
		if not shows("decal") then
			local note = UIKit.text(u.sub, "This car has no spot for a sun strip yet", "caption", "sand", touch, true)
			note.Name = "NoSpot"
			note.LayoutOrder = 1
		end
		itemCards(u, newGrid(u, u.grid, 2), "decal", 0)
	elseif tab == "exhaust" then
		if not shows("exhaust") then
			local note = UIKit.text(u.sub, "This car has no spot for exhaust tips yet", "caption", "sand", touch, true)
			note.Name = "NoSpot"
			note.LayoutOrder = 1
		end
		-- REV: a burst of pops and flames on the turntable car, with the
		-- exhaust on it now (bought or only previewing), so the flame is
		-- part of what a player is choosing (garage round 2 §2).
		local rev = UIKit.button(u.sub, "REV", "secondary", touch)
		rev.Name = "Rev"
		rev.LayoutOrder = 2
		rev.Activated:Connect(function()
			local m = previewModel
			if sheet or not m or not m.Parent or os.clock() < revUntil then
				return -- under the confirm sheet, or the last burst is still going
			end
			-- The rear comes round first (GarageView.present), then the burst,
			-- with the exhaust on the car at that moment.
			GarageView.present(function()
				local now = previewModel
				if not now or now ~= m or not m.Parent then
					return
				end
				local item = CarLook.item(draftLook(), "exhaust")
				-- A burst in this client's exhaust style (ExhaustPops), waited out.
				revUntil = os.clock() + ExhaustPops.rev(m, item)
			end)
		end)
		itemCards(u, newGrid(u, u.grid, 1), "exhaust", 0)
	elseif tab == "plates" then
		local shop = UIKit.button(u.sub, "SHOP PLATES", "secondary", touch)
		shop.Name = "ShopPlates"
		shop.LayoutOrder = 1
		shop.Activated:Connect(function()
			if sheet then
				return -- under the confirm sheet
			end
			SpawnMenu.openTab("plates")
		end)
		local g = newGrid(u, u.grid, 1)
		local format: PlateStyles.Format = plateFormat()
		local keys = ownedPlates()
		local options: { { key: string, name: string } } = { { key = "", name = "My plate · every car" } }
		for _, k in keys do
			table.insert(options, { key = k, name = shownPlate(k) })
		end
		for i, o in options do
			local card = buildCard(g, i, o.key, "plate", o.name, 0, false, function(tile)
				tile.BackgroundTransparency = 1
				PlateStyles.draw(tile, plateKeyFor(o.key), format)
			end)
			card.tile = nil -- the plate art is the tile; it never fades
			registerTap({
				gui = card.frame,
				scroll = u.grid,
				onTap = function()
					choosePlate(o.key)
				end,
				onDown = function(down)
					paintCard(card, down)
				end,
			})
		end
		if #keys == 0 then
			local hint = UIKit.text(u.grid, "Plates you buy show here", "caption", "sandDim", touch, true)
			hint.LayoutOrder = 9
		end
	end
	sizeGrids(u)
	relayout(u)
end

------------------------------------------------------------------------
-- Layout.
------------------------------------------------------------------------

-- Lays `items` out left to right, wrapping at `width`; returns the height.
local function flow(items: { GuiObject }, width: number, gap: number): number
	local x, y, lineH = 0, 0, 0
	for _, o in items do
		local w, h = o.AbsoluteSize.X, o.AbsoluteSize.Y
		if x > 0 and x + w > width then
			x = 0
			y += lineH + gap
			lineH = 0
		end
		o.Position = UDim2.fromOffset(x, y)
		x += w + gap
		lineH = math.max(lineH, h)
	end
	return y + lineH
end

relayout = function(u: UI)
	if relaying then
		return
	end
	relaying = true
	local w = panelWidth(u)
	local r = UITheme.radius.lg
	local pad = space("lg")
	local gap = space("md")
	local handleW = target()
	-- The panel docks on the left: its left corners sit off-screen, so only
	-- the right edge is rounded.
	u.dock.Size = UDim2.new(0, w + space("sm") + handleW, 1, 0)
	u.dock.Position = UDim2.fromOffset(if collapsed then -w else 0, 0)
	u.panel.Position = UDim2.fromOffset(-r, 0)
	u.panel.Size = UDim2.new(0, w + r, 1, 0)
	u.panelPad.PaddingLeft = UDim.new(0, pad + r)
	u.handle.Size = UDim2.fromOffset(handleW, 2 * target())
	u.handle.Position = UDim2.new(0, w + space("sm"), 0.5, 0)

	-- Header: the title and cash, LEAVE at the right.
	local leaveW = u.leave.AbsoluteSize.X
	u.titleHolder.Size = UDim2.new(1, -(leaveW + gap), 0, 0)
	local titleH = u.titleRow.AbsoluteSize.Y
	u.cash.Position = UDim2.fromOffset(0, titleH + space("xxs"))
	local headerH = math.max(titleH + space("xxs") + UITheme.textSize("price", touch), target())
	u.header.Size = UDim2.new(1, 0, 0, headerH)
	local y = headerH + gap

	-- The categories wrap onto as many rows as the width needs (review fix
	-- round 1: a scrolling row hid DECALS, now SUN STRIPS, and EXHAUST off the
	-- edge).
	local chipList: { GuiObject } = {}
	for _, entry in TABS do
		table.insert(chipList, u.chipButtons[entry.id])
	end
	local contentW = u.chips.AbsoluteSize.X
	local chipsH = flow(chipList, contentW, space("sm"))
	u.chips.Position = UDim2.fromOffset(0, y)
	u.chips.Size = UDim2.new(1, 0, 0, chipsH)
	y += chipsH + gap

	local fr = finishRow
	if fr and fr.Parent then
		fr.Size = UDim2.new(1, 0, 0, flow(finishPills, contentW, space("sm")))
	end

	local subH = u.subList.AbsoluteContentSize.Y
	u.sub.Visible = subH > 0
	if subH > 0 then
		u.sub.Position = UDim2.fromOffset(0, y)
		u.sub.Size = UDim2.new(1, 0, 0, subH)
		y += subH + gap
	end

	local bottom = 0
	if u.foot.Visible then
		local footH = target() + 2 * space("sm")
		u.foot.Size = UDim2.new(1, 0, 0, footH)
		u.foot.Position = UDim2.new(0, 0, 1, -footH)
		bottom += footH + gap
	end
	if u.toast.Visible then
		local th = u.toast.AbsoluteSize.Y
		u.toast.Position = UDim2.new(0, 0, 1, -(bottom + th))
		bottom += th + space("sm")
	end
	u.grid.Position = UDim2.fromOffset(0, y)
	u.grid.Size = UDim2.new(1, 0, 1, -(y + bottom))
	sizeGrids(u)
	relaying = false
end

------------------------------------------------------------------------
-- Collapse.
------------------------------------------------------------------------

local function setCollapsed(c: boolean)
	local u = ui
	if not u or not inside or sheet or c == collapsed then
		return
	end
	collapsed = c
	local w = panelWidth(u)
	TweenService:Create(u.dock, UITheme.motion.panel, { Position = UDim2.fromOffset(if c then -w else 0, 0) }):Play()
	u.handle.Text = if c then "›" else "‹"
	GarageView.setPanelOpen(not c)
end

------------------------------------------------------------------------
-- Build and tear down.
------------------------------------------------------------------------

local function build(): UI
	touch = UIKit.isTouch()
	local g = Instance.new("ScreenGui")
	g.Name = "GaragePanel"
	g.ResetOnSpawn = false
	-- Not IgnoreGuiInset: the panel runs under Roblox's top bar, never
	-- beneath its buttons.
	g.IgnoreGuiInset = false
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = DISPLAY_ORDER

	local dock = Instance.new("Frame")
	dock.Name = "Dock"
	dock.BackgroundTransparency = 1
	dock.Size = UDim2.fromScale(0, 1)
	dock.Parent = g

	local panel = UIKit.panel(dock, touch)
	panel.Name = "Panel"
	panel.Active = true
	local panelPad = panel:FindFirstChildOfClass("UIPadding") :: UIPadding

	-- The collapse handle: a pill on the panel's right edge at mid-height,
	-- where a left thumb reaches.
	local handle = Instance.new("TextButton")
	handle.Name = "Handle"
	handle.AutoButtonColor = false
	handle.AnchorPoint = Vector2.new(0, 0.5)
	handle.BackgroundColor3 = C.asphalt900
	handle.BackgroundTransparency = UITheme.alpha.panel
	handle.BorderSizePixel = 0
	handle.FontFace = UITheme.font("title")
	handle.TextSize = UITheme.textSize("title", touch)
	handle.TextColor3 = C.paint
	handle.Text = "‹"
	UIKit.corner(handle, "pill")
	UIKit.stroke(handle, "asphalt600", UITheme.stroke.hairline)
	handle.Parent = dock

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Parent = panel
	local titleHolder = Instance.new("Frame")
	titleHolder.Name = "TitleHolder"
	titleHolder.BackgroundTransparency = 1
	titleHolder.Size = UDim2.new(1, 0, 1, 0)
	titleHolder.Parent = header
	local titleRow = UIKit.title(titleHolder, "GARAGE", "كراج", "display", touch)
	-- Your balance is not something to press or pay: paint, not sodium.
	local cash = UIKit.text(titleHolder, "0", "price", "paint", touch, false)
	cash.Name = "Cash"
	local leave = UIKit.button(header, "LEAVE", "secondary", touch)
	leave.Name = "Leave"
	leave.AnchorPoint = Vector2.new(1, 0)
	leave.Position = UDim2.fromScale(1, 0)

	local chips = Instance.new("Frame")
	chips.Name = "Categories"
	chips.BackgroundTransparency = 1
	chips.Size = UDim2.new(1, 0, 0, UITheme.target(touch))
	chips.Parent = panel
	local chipButtons: { [Tab]: TextButton } = {}
	for i, entry in TABS do
		-- A tab is a chip in the title role (UI_SYSTEM.md "title: section
		-- title, tab names"), as the spawn menu's tabs are.
		local b = UIKit.chip(chips, entry.label, touch)
		b.Name = entry.label
		b.FontFace = UITheme.font("title")
		b.TextSize = UITheme.textSize("title", touch)
		b.LayoutOrder = i
		b.Active = false
		chipButtons[entry.id] = b
		-- The row wraps by measured chip widths: lay out again once known.
		b:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			local cur = ui
			if cur and cur.chipButtons == chipButtons then
				relayout(cur)
			end
		end)
	end

	local sub = Instance.new("Frame")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	local subList = list(sub, false, space("sm"))
	sub.Parent = panel

	local grid = scroller("Items", false)
	list(grid, false, space("md"))
	grid.Parent = panel

	local foot = Instance.new("Frame")
	foot.Name = "Foot"
	foot.BackgroundColor3 = C.asphalt800
	foot.BorderSizePixel = 0
	foot.Visible = false
	UIKit.corner(foot, "md")
	UIKit.stroke(foot, "asphalt600", UITheme.stroke.hairline)
	local footPad = Instance.new("UIPadding")
	footPad.PaddingLeft = UDim.new(0, space("md"))
	footPad.PaddingRight = UDim.new(0, space("sm"))
	footPad.Parent = foot
	foot.Parent = panel
	local footRow = Instance.new("Frame")
	footRow.BackgroundTransparency = 1
	footRow.Size = UDim2.fromScale(1, 1)
	list(footRow, true, space("sm"))
	footRow.Parent = foot
	local footText = UIKit.text(footRow, "", "label", "sand", touch, false)
	footText.Name = "Status"
	footText.LayoutOrder = 1
	footText.TextTruncate = Enum.TextTruncate.AtEnd
	local footPrice = UIKit.text(footRow, "", "price", "sodium", touch, false)
	footPrice.Name = "Price"
	footPrice.LayoutOrder = 2
	local footButton = UIKit.button(foot, "BUY", "primary", touch)
	footButton.Name = "Action"
	footButton.AnchorPoint = Vector2.new(1, 0.5)
	footButton.Position = UDim2.fromScale(1, 0.5)

	local toastFrame = Instance.new("Frame")
	toastFrame.Name = "Toast"
	toastFrame.BorderSizePixel = 0
	toastFrame.AutomaticSize = Enum.AutomaticSize.Y
	toastFrame.Size = UDim2.new(1, 0, 0, 0)
	toastFrame.Visible = false
	UIKit.corner(toastFrame, "sm")
	padAll(toastFrame, space("sm"))
	toastFrame.Parent = panel
	local toastLabel = UIKit.text(toastFrame, "", "body", "paint", touch, true)

	local u: UI = {
		gui = g,
		dock = dock,
		panel = panel,
		panelPad = panelPad,
		handle = handle,
		header = header,
		titleHolder = titleHolder,
		titleRow = titleRow,
		cash = cash,
		leave = leave,
		chips = chips,
		chipButtons = chipButtons,
		sub = sub,
		subList = subList,
		grid = grid,
		gridLayouts = {},
		foot = foot,
		footText = footText,
		footPrice = footPrice,
		footButton = footButton,
		toast = toastFrame,
		toastLabel = toastLabel,
	}

	-- The status text stops short of the action button.
	local function fitFoot()
		footRow.Size = UDim2.new(1, -(footButton.AbsoluteSize.X + space("sm")), 1, 0)
		footText.Size = UDim2.fromOffset(0, 0)
	end
	footButton:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitFoot)
	fitFoot()

	-- Buttons under the confirm sheet hear clicks through its scrim, so each
	-- one ignores them while a sheet is open (Esc and gamepad B still leave).
	leave.Activated:Connect(function()
		if sheet then
			return
		end
		GarageView.leave()
	end)
	handle.Activated:Connect(function()
		setCollapsed(not collapsed)
	end)
	footButton.Activated:Connect(function()
		if sheet then
			return
		end
		if tab == "cars" then
			local id = carId
			if SpawnMenu.requestCar(id) then
				GarageView.leave()
			else
				toast(MESSAGES.busy, "info")
			end
		elseif previewing then
			openSheet(u)
		end
	end)

	-- chips: its width (the panel's content width) sets where the row wraps.
	local watchedList: { Instance } = { titleRow, leave, subList, g, chips }
	for _, watched in watchedList do
		local prop = if watched:IsA("UIListLayout") then "AbsoluteContentSize" else "AbsoluteSize"
		watched:GetPropertyChangedSignal(prop):Connect(function()
			if ui == u then
				relayout(u)
			end
		end)
	end
	toastFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if ui == u and toastFrame.Visible then
			relayout(u)
		end
	end)

	g.Parent = player:WaitForChild("PlayerGui")
	return u
end

local function teardown()
	closeSheet()
	local u = ui
	ui = nil
	if u then
		u.gui:Destroy()
	end
	table.clear(cards)
	table.clear(taps)
	press = nil
end

local function onEnter(id: string, preview: Model)
	teardown()
	inside = true
	collapsed = false
	tab = "paint"
	carId = id
	previewModel = preview
	previewing = nil
	newEpoch()
	lastApplied = nil
	-- The spawn menu can be open over the view (it reopens on stepping out
	-- of a car); the panel takes the screen.
	SpawnMenu.close()
	SpawnMenu.setOpenButtonHidden(true)
	modalBefore = UserInputService.ModalEnabled
	if UIKit.isTouch() then
		-- Roblox's own touch controls draw over any PlayerGui.
		UserInputService.ModalEnabled = true
	end
	local u = build()
	ui = u
	GarageView.setPanelOpen(true)
	buildTab(u)
	refresh()
end

local function onLeave()
	inside = false
	teardown()
	previewModel = nil
	previewing = nil
	newEpoch()
	SpawnMenu.setOpenButtonHidden(false)
	UserInputService.ModalEnabled = modalBefore
end

------------------------------------------------------------------------
-- Tap tracking for cards and chips.
------------------------------------------------------------------------

local function tapAt(position: Vector3): Tap?
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return nil
	end
	local ok, found = pcall(function()
		return pg:GetGuiObjectsAtPosition(position.X, position.Y)
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
	UserInputService.InputBegan:Connect(function(io: InputObject, processed: boolean)
		if not inside or not ui then
			return
		end
		-- H / gamepad Y fold the panel away and back (not while typing).
		if (io.KeyCode == Enum.KeyCode.H and not processed) or io.KeyCode == Enum.KeyCode.ButtonY then
			setCollapsed(not collapsed)
			return
		end
		if io.UserInputType ~= Enum.UserInputType.Touch and io.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if press or sheet or collapsed or SpawnMenu.isOpen() then
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
		local hit = tapAt(io.Position)
		local tapped = not p.cancelled and hit == p.tap
		local down = p.tap.onDown
		if down then
			down(false)
		end
		if tapped and inside then
			p.tap.onTap()
		end
	end)
end

------------------------------------------------------------------------

function GaragePanel.start(remotes: Folder)
	remote = remotes:WaitForChild("CosmeticsAction") :: RemoteFunction
	-- This panel has its own LEAVE in the header.
	GarageView.setLeaveButton(false)
	GarageView.onEnter = onEnter
	GarageView.onLeave = onLeave
	bindInput()
	for _, name in { "Cash", "Cosmetics", "Looks", "PlateEquipped", "PlateDefault" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	-- A plate bought in the spawn menu joins the PLATES list.
	player:GetAttributeChangedSignal("Plates"):Connect(function()
		-- Rebuilt by refresh(), and not while a confirm sheet is open (a
		-- rebuild clears the content, sheet included).
		platesDirty = true
		refresh()
	end)
end

return GaragePanel
