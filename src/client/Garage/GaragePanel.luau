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
-- onLeave. Every element comes from UIKit on the UITheme tokens.
--
-- How it looks (garage-ui-overhaul, 2026-10-06, the owner: "a complete
-- overhaul to make the UI look better and more organized + appealing";
-- docs/superpowers/specs/2026-10-06-garage-ui-overhaul-design.md):
--   * no panel box: a shade (UITheme.shade) darkens the screen under the
--     panel and fades to clear past it, so the panel melts into the garage;
--     the fading tail lets drags through to the turntable (PassThrough);
--   * one header row: GARAGE and the Arabic, the cash, the close button
--     (LEAVE);
--   * the categories as a rail of words down the left (the nav role), the
--     chosen one paint with a sodium bar that slides to it;
--   * right of the rail: the sub-tabs as words with a sliding sodium
--     underline and the category's action (REV, SHOP PLATES) at the row's
--     end, a note where needed, the items, and the foot;
--   * a set of colours is a palette (a grid of swatches: paint, tint, rims,
--     head and tail lights); everything else is a list (a row per item);
--   * each item's status is a word under its name (UI_SYSTEM.md "Shop
--     items"): ON CAR in sodium for what is saved on this car, ✓ OWNED in
--     gantryBright, or the price in sodium; what shows on the car now is
--     drawn chosen (a palette swatch's sodium ring, a list row's selected
--     ground and stroke); rare items get the dusk diamond before the name;
--   * the foot names what you are about to buy: the item, its price, BUY;
--     on MY CARS the car and DRIVE THIS.
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
--   * WHEELS has the rims and the tyres, EXHAUST the tips and the flames
--     (garage-tyres-flames, 2026-10-05). A tyre is a drift mode: the list
--     has only the tyres for this car's drivetrain, and the line over it
--     says how the tyre showing drives. REV fires the flame showing, so a
--     flame is heard and seen before it is bought.
--   * Garage polish (2026-10-05, GarageConfig.views): a category with more
--     than one set of items has sub-tabs (PAINT: COLOUR, FINISH, TINT;
--     WHEELS: RIMS, TYRES; LIGHTS: HEADLIGHTS, TAIL LIGHTS; EXHAUST: TIPS,
--     FLAMES, with REV on the row), one set each, remembered per category
--     for the visit. Each view has a camera shot (GarageView.focus): the
--     camera goes to the part; tapping the sub-tab again goes back in
--     after a drag took it out. Tapping tips or a flame plays a burst once
--     the camera is there; a headlight colour blinks the lamps. Sounds
--     (GarageSounds) on a tab, a preview, a fit, a purchase and an error;
--     an item shrinks while pressed and pops when it is fitted or bought;
--     the cash counts down after a purchase; a new set slides up into
--     place.
--   * The pill on the panel's edge, H or gamepad Y collapse the panel; the
--     car re-centres (GarageView.setPanelOpen).
--
-- Taps on items, rail rows and sub-tabs are tracked here through
-- UserInputService, not with Activated, for the reason SpawnMenu's header
-- gives: on a phone a GuiButton inside a ScrollingFrame blocks the drag that
-- scrolls it, and a touch that moves a little never fires Activated. A press
-- counts as a tap if it lifts over the same item within TAP_SLOP_PX and the
-- list did not scroll.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UITheme = require(Shared:WaitForChild("UITheme"))
local CosmeticsConfig = require(Shared:WaitForChild("CosmeticsConfig"))
local CarLook = require(Shared:WaitForChild("CarLook"))
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local VehicleRig = require(Shared:WaitForChild("VehicleRig"))
local CarPlateMounts = require(Shared:WaitForChild("CarPlateMounts"))
local GarageConfig = require(Shared:WaitForChild("GarageConfig"))
local PlateText = require(Shared:WaitForChild("PlateText"))
local PlateStyles = require(Shared:WaitForChild("PlateStyles"))
local Client = script.Parent.Parent
local UIKit = require(Client:WaitForChild("UIKit"))
local CarCosmetics = require(Client:WaitForChild("CarCosmetics"))
local ExhaustPops = require(Client:WaitForChild("ExhaustPops"))
local SpawnMenu = require(Client:WaitForChild("SpawnMenu"))
local GarageView = require(script.Parent:WaitForChild("GarageView"))
local GarageSounds = require(script.Parent:WaitForChild("GarageSounds"))

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
-- A line of text is the text size times this (Builder Sans' line box at
-- LineHeight 1, with room for Arabic marks).
local LINE_BOX = 1.3
-- A palette swatch is this many targets tall (50 px on desktop, 67 on
-- touch): big enough to judge a colour, small enough for four rows of
-- three in view (garage-ui-overhaul).
local SWATCH_TALL = 1.4
-- A list row's swatch is this many times as wide as it is tall; a banner
-- (sun strips, plates: their art is wide) WIDE_SWATCH.
local ROW_SWATCH = 1.6
local WIDE_SWATCH = 2.2
-- A finish swatch's highlight: the car's paint is lifted toward white by
-- this much at the swatch's top corner for a shiny (Glass) finish, plus
-- FINISH_SHINE_PER_REFLECTANCE for each unit of reflectance, so Gloss,
-- Metallic and Chrome read as a ladder (0.35, 0.5, 0.8).
local FINISH_SHINE = 0.35
local FINISH_SHINE_PER_REFLECTANCE = 3
-- The close button's cross: each stroke is this share of the button.
local CLOSE_MARK = 0.4

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

-- The sets shown as a palette, a grid of swatches: the ones that are
-- colours. Everything else is a list, a row per item (garage-ui-overhaul).
local PALETTES: { [string]: boolean } = { paint = true, tint = true, rims = true, head = true, tail = true }
-- List rows whose swatch is a banner.
local WIDE: { [string]: boolean } = { decal = true, plate = true }

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
	tyre = "Tyres",
	flame = "Exhaust flame",
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
	row: boolean, -- a list row; else a palette tile
	frame: Frame,
	-- The chosen mark: a row's stroke, or the ring round a tile's swatch.
	stroke: UIStroke,
	tile: Frame?, -- the swatch, faded when the car can't show the slot
	nameLabel: TextLabel,
	status: TextLabel,
	statusSig: string?,
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

type Grid = { layout: UIGridLayout, palette: boolean }

type UI = {
	gui: ScreenGui,
	dock: Frame,
	shade: Frame,
	tail: Frame,
	handle: TextButton,
	header: Frame,
	title: TextLabel,
	arabic: TextLabel,
	cash: TextLabel,
	leave: TextButton,
	rail: ScrollingFrame,
	railRows: { [Tab]: Frame },
	railLabels: { [Tab]: TextLabel },
	railBar: Frame,
	content: Frame,
	sub: Frame,
	subList: UIListLayout,
	grid: ScrollingFrame,
	grids: { Grid },
	foot: Frame,
	footName: TextLabel,
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
-- WHEELS: the line over the tyres, how the tyre showing drives.
local tyreNote: TextLabel? = nil
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
-- Each category's sub-tab (GarageConfig.views), for this visit.
local subTab: { [string]: string } = {}
-- Where the sub-tab underline last sat, so a new choice in the same
-- category slides it there from the old one.
local underlineWas: { tab: Tab, x: number, w: number }? = nil
-- The rail's row height, as last laid out (the bar's slide needs it), the
-- bar's slide while it runs, and the rail's widest word this visit: the
-- rail only grows, so the items don't shift when a wider word turns bold.
local railRowH = 0
local railTween: Tween? = nil
local railLabelW = 0
-- The cash as shown, and where it is heading: it counts down after a
-- purchase (GarageConfig.feel.cashCountSeconds).
local cashShown: number? = nil
local cashTarget: number? = nil
local cashToken = 0

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

-- The drivetrain of the car on the turntable: its tyres are the ones that
-- fit it (CosmeticsConfig.fits).
local function carLayout(): string
	return ConfigLoader.driftStyles().layoutOf(ConfigLoader.forCar(carId))
end

-- The effective id in a slot: the item's id, or for the plate the key
-- ("" for the account's plate).
local function slotValue(look: Look, slot: Slot): string
	if slot == "plate" then
		return look.plate or ""
	end
	local item = CarLook.item(look, slot :: Category)
	-- A tyre that no longer fits the car (the catalog changed its
	-- drivetrain) drives as Classic (DriftStyle), so it shows as Classic.
	if item.layout ~= nil and item.layout ~= carLayout() then
		return CosmeticsConfig.stockId(slot :: Category)
	end
	return item.id
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
	elseif slot == "exhaust" or slot == "flame" then
		-- The flames come out of the tips' outlets (CarCosmetics.outlets).
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

-- A palette swatch's height.
local function swatchHeight(): number
	return math.floor(target() * SWATCH_TALL + 0.5)
end

-- A palette tile: the swatch, a line of name and the status line.
local function tileHeight(): number
	return swatchHeight() + space("xs") + lineBox("body") + lineBox("price")
end

-- A list row: the name over the status line, padded.
local function rowHeight(): number
	return 2 * space("sm") + lineBox("body") + lineBox("price")
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

-- How far the shade (and the confirm sheet's dim) runs past the gui's
-- edges: under Roblox's top bar and any notch, so it has no edge of its
-- own but the fade.
local function shadeBleed(): number
	return GuiService:GetGuiInset().Y + space("xxxl")
end

-- How far past the panel its shade fades to clear.
local function fadeTail(): number
	local sp = UITheme.sidePanel
	return if touch then sp.touchFadeTail else sp.fadeTail
end

-- A palette's columns: as many as fit tiles paletteMinTile wide (3 in the
-- desktop panel, 2 on a phone).
local function paletteColumns(width: number): number
	local sp = UITheme.sidePanel
	local minTile = if touch then sp.touchPaletteMinTile else sp.paletteMinTile
	local gap = space("sm")
	return math.max(1, math.floor((width + gap) / (minTile + gap)))
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
	-- Nothing to draw: a dark swatch, outlined by its ring or edge.
	tile.BackgroundColor3 = C.asphalt700
end

-- n dots in a row across the swatch's middle (rims, lights, tips, tyres).
-- aspect: a dot this many times wider than tall (the Big Oval Tip).
local function tileCircles(tile: Frame, n: number, color: Color3, aspect: number?)
	tileBlank(tile)
	local row = Instance.new("Frame")
	row.Name = "Dots"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	local l = list(row, true, space("xs"))
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.Parent = tile
	local dots: { Frame } = {}
	for i = 1, n do
		local dot = Instance.new("Frame")
		dot.BackgroundColor3 = color
		dot.BorderSizePixel = 0
		dot.LayoutOrder = i
		UIKit.corner(dot, "pill")
		-- A dark tip (Quad Tips) would vanish on the swatch without an edge.
		UIKit.stroke(dot, "asphalt500", UITheme.stroke.hairline)
		dot.Parent = row
		table.insert(dots, dot)
	end
	-- As big as fits: every dot across the swatch with a margin, and no
	-- taller than three fifths of it. aspect: a dot this many times wider
	-- than tall.
	local wide = aspect or 1
	local function fit()
		local size = tile.AbsoluteSize
		if size.X < 1 or size.Y < 1 then
			return
		end
		local room = size.X - 2 * space("sm") - (n - 1) * space("xs")
		local d = math.floor(math.min(room / (n * wide), size.Y * 0.6))
		d = math.max(d, 4)
		for _, dot in dots do
			dot.Size = UDim2.fromOffset(math.floor(d * wide), d)
		end
	end
	fit()
	tile:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
end

-- The paint the turntable car shows now: a finish is drawn on it.
local function shownPaint(): Color3
	local item = CarLook.item(draftLook(), "paint")
	return item.color or ConfigLoader.entry(carId).body.paint
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
	elseif c == "finish" then
		-- The car's paint in this finish: darkened and greyed as the finish
		-- does (CarCosmetics), with a highlight across a shiny one, so the
		-- finishes read as a ladder at a glance (garage-ui-overhaul).
		local h, s, v = shownPaint():ToHSV()
		local base = Color3.fromHSV(h, s * (1 - (item.desaturate or 0)), v * (1 - (item.darken or 0)))
		local shine = if item.material == Enum.Material.Glass then FINISH_SHINE + FINISH_SHINE_PER_REFLECTANCE * (item.reflectance or 0) else 0
		tile.BackgroundColor3 = Color3.new(1, 1, 1)
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, base:Lerp(C.lens, shine)),
			ColorSequenceKeypoint.new(0.5, base),
			ColorSequenceKeypoint.new(1, base:Lerp(C.asphalt950, shine * 0.3)),
		})
		g.Rotation = 35
		g.Parent = tile
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
		-- Limo's film is nearly the shade's own colour: the swatch's ring
		-- keeps it from vanishing.
		if item.glassColor and item.glassTransparency then
			tile.BackgroundColor3 = C.sand
			local film = Instance.new("Frame")
			film.Name = "Film"
			film.BorderSizePixel = 0
			film.Size = UDim2.fromScale(1, 1)
			film.BackgroundColor3 = item.glassColor
			film.BackgroundTransparency = item.glassTransparency
			film.Parent = tile
		else
			tileBlank(tile)
		end
	elseif c == "tyre" then
		-- Every tyre looks alike: it is how it drives that differs (the note
		-- over the list).
		tileCircles(tile, 1, C.asphalt900)
	elseif c == "flame" then
		-- The style's colours, from the hot core at the mouth to its body.
		if item.flameCore and item.flameColor then
			tile.BackgroundColor3 = Color3.new(1, 1, 1)
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new(item.flameCore, item.flameColor)
			g.Parent = tile
		else
			tileBlank(tile)
		end
	else
		tileBlank(tile)
	end
end

------------------------------------------------------------------------
-- Items and their states.
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

-- A car's line under its name: its drivetrain, which is what decides the
-- tyres it takes.
local function carNote(id: string): string
	local styles = ConfigLoader.driftStyles()
	return styles.layoutName[styles.layoutOf(ConfigLoader.forCar(id))] or ""
end

-- The word under an item's name (UI_SYSTEM.md "Shop items"): ON CAR, a
-- green tick, the price, a note, or nothing.
type StatusKind = "oncar" | "owned" | "price" | "note" | "none"

local function setStatus(card: Card, kind: StatusKind, text: string)
	local sig = `{kind}:{text}`
	if card.statusSig == sig then
		return
	end
	card.statusSig = sig
	local s = card.status
	local role: UITheme.Role = if kind == "price" then "price" elseif kind == "note" then "caption" else "label"
	s.FontFace = UITheme.font(role)
	s.TextSize = UITheme.textSize(role, touch)
	s.TextColor3 = if kind == "owned" then C.gantryBright elseif kind == "note" then C.sandDim else C.sodium
	s.Text = if UITheme.type[role].caps then string.upper(text) else text
end

local function paintCard(card: Card, down: boolean?, ctx: Context?)
	local st = stateOf(card, ctx or context())
	-- What shows on the car now is drawn chosen (garage-ui-overhaul): a
	-- palette swatch's sodium ring, a list row's selected ground and stroke.
	-- One item per set shows, so there is one per set.
	local chosen = st.showing and not st.disabled
	if card.row then
		local look = if chosen then UITheme.button.selected elseif down and not st.disabled then UITheme.button.secondaryPressed else nil
		card.frame.BackgroundTransparency = if look then 0 else 1
		if look then
			card.frame.BackgroundColor3 = look.bg
		end
		card.stroke.Transparency = if chosen then 0 else 1
	else
		card.stroke.Color = if chosen then C.sodium else C.asphalt600
		card.stroke.Thickness = if chosen then UITheme.stroke.selected else UITheme.stroke.hairline
	end
	card.nameLabel.TextColor3 = if st.disabled then C.asphalt500 else C.paint
	local tile = card.tile
	if tile then
		tile.BackgroundTransparency = if st.disabled then UITheme.alpha.disabled else 0
	end
	if st.disabled then
		setStatus(card, "none", "")
	elseif card.slot == nil then
		if st.driving then
			setStatus(card, "owned", "✓ DRIVING")
		else
			setStatus(card, "note", carNote(card.key))
		end
	elseif st.onCar then
		setStatus(card, "oncar", "ON CAR")
	elseif st.owned then
		setStatus(card, "owned", "✓ OWNED")
	else
		setStatus(card, "price", money(card.price))
	end
end

local function paintCards()
	local ctx = context()
	for _, card in cards do
		paintCard(card, nil, ctx)
	end
	local note = tyreNote
	if note then
		local styles = ConfigLoader.driftStyles()
		local layout = carLayout()
		local mode = styles.resolve(layout, CarLook.item(ctx.draft, "tyre").driftStyle)
		note.Text = `{styles.layoutName[layout]} · {styles.styles[mode].blurb}`
	end
end

-- A card's scale, made on first use.
local function scaleOf(frame: GuiObject): UIScale
	local found = frame:FindFirstChild("Press")
	if found and found:IsA("UIScale") then
		return found
	end
	local sc = Instance.new("UIScale")
	sc.Name = "Press"
	sc.Parent = frame
	return sc
end

-- Pressed: the item shrinks a little (GarageConfig.feel.pressScale).
local function pressCard(card: Card, down: boolean)
	paintCard(card, down)
	local to = if down then GarageConfig.feel.pressScale else 1
	TweenService:Create(scaleOf(card.frame), UITheme.motion.quick, { Scale = to }):Play()
end

-- Fitted or bought: the item pops (feel.popScale) and settles.
local function popCard(key: string)
	for _, card in cards do
		if card.key == key and card.frame.Parent then
			local sc = scaleOf(card.frame)
			local up = TweenService:Create(sc, UITheme.motion.quick, { Scale = GarageConfig.feel.popScale })
			up.Completed:Once(function()
				TweenService:Create(sc, UITheme.motion.quick, { Scale = 1 }):Play()
			end)
			up:Play()
		end
	end
end

-- The name and status lines of an item, from x across. shrink: the name
-- shrinks to fit, from body down to caption size, instead of being cut
-- (a palette tile: Sodium Orange is 104 px at touch size, a phone's tile
-- 99).
local function itemText(f: Frame, x: number, y: number, name: string, rare: boolean, shrink: boolean): (TextLabel, TextLabel)
	local label = UIKit.text(f, "", "body", "paint", touch, false)
	label.Name = "ItemName"
	label.AutomaticSize = Enum.AutomaticSize.None
	label.RichText = true
	label.Text = nameText(name, rare)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Position = UDim2.fromOffset(x, y)
	label.Size = UDim2.new(1, -x, 0, lineBox("body"))
	if shrink then
		label.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = UITheme.textSize("body", touch)
		limit.MinTextSize = UITheme.textSize("caption", touch)
		limit.Parent = label
	end
	local status = UIKit.text(f, "", "label", "sodium", touch, false)
	status.Name = "Status"
	status.AutomaticSize = Enum.AutomaticSize.None
	status.TextTruncate = Enum.TextTruncate.AtEnd
	status.Position = UDim2.fromOffset(x, y + lineBox("body"))
	status.Size = UDim2.new(1, -x, 0, lineBox("price"))
	return label, status
end

local function newCard(f: Frame, key: string, slot: Slot?, name: string, price: number, rare: boolean, row: boolean, stroke: UIStroke, tile: Frame, label: TextLabel, status: TextLabel): Card
	local card: Card = {
		key = key,
		slot = slot,
		name = name,
		price = price,
		rare = rare,
		row = row,
		frame = f,
		stroke = stroke,
		tile = tile,
		nameLabel = label,
		status = status,
	}
	table.insert(cards, card)
	return card
end

local function itemFrame(parent: Instance, order: number, key: string): Frame
	local f = Instance.new("Frame")
	f.Name = "Card_" .. (if key == "" then "account" else key)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.LayoutOrder = order
	f.Active = true
	f.Parent = parent
	return f
end

-- A palette tile: the swatch with its ring, the name under it, the status
-- word under that.
local function buildTile(parent: Instance, order: number, key: string, slot: Slot?, name: string, price: number, rare: boolean, drawTile: (Frame) -> ()): Card
	local f = itemFrame(parent, order, key)
	local tile = Instance.new("Frame")
	tile.Name = "Tile"
	tile.BorderSizePixel = 0
	tile.Size = UDim2.new(1, 0, 0, swatchHeight())
	tile.ClipsDescendants = true
	UIKit.corner(tile, "md")
	local ring = UIKit.stroke(tile, "asphalt600", UITheme.stroke.hairline)
	tile.Parent = f
	drawTile(tile)
	local label, status = itemText(f, 0, swatchHeight() + space("xs"), name, rare, true)
	return newCard(f, key, slot, name, price, rare, false, ring, tile, label, status)
end

-- A list row: the swatch at the left, the name over the status word; the
-- row's ground and stroke show when it is chosen or pressed. wide: a
-- banner's swatch (sun strips, plates).
local function buildRow(parent: Instance, order: number, key: string, slot: Slot?, name: string, price: number, rare: boolean, drawTile: (Frame) -> (), wide: boolean?): Card
	local f = itemFrame(parent, order, key)
	f.BackgroundColor3 = UITheme.button.secondaryPressed.bg
	UIKit.corner(f, "md")
	local stroke = UIKit.stroke(f, "sodium", UITheme.stroke.selected)
	stroke.Transparency = 1
	padAll(f, space("sm"))
	local h = rowHeight() - 2 * space("sm")
	local w = math.floor(h * (if wide then WIDE_SWATCH else ROW_SWATCH) + 0.5)
	local tile = Instance.new("Frame")
	tile.Name = "Tile"
	tile.BorderSizePixel = 0
	tile.Size = UDim2.fromOffset(w, h)
	tile.ClipsDescendants = true
	UIKit.corner(tile, "sm")
	UIKit.stroke(tile, "asphalt600", UITheme.stroke.hairline)
	tile.Parent = f
	drawTile(tile)
	local label, status = itemText(f, w + space("md"), 0, name, rare, false)
	return newCard(f, key, slot, name, price, rare, true, stroke, tile, label, status)
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
		GarageSounds.play("error")
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

-- The foot names what its button acts on (garage-ui-overhaul): the item
-- previewing, its price and BUY; on MY CARS the car and DRIVE THIS.
local function paintFoot(u: UI)
	local p = previewing
	local was = u.foot.Visible
	if p and tab ~= "cars" then
		local item = CosmeticsConfig.find(p.id)
		u.footName.Text = if item then nameText(item.name, item.rare == true) else ""
		u.footPrice.Visible = true
		u.footPrice.Text = money(if item then item.price else 0)
		u.footButton.Text = "BUY"
		u.foot.Visible = true
	elseif tab == "cars" then
		u.footName.Text = ConfigLoader.entry(carId).displayName
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

-- The cash readout: straight to a rise, counting down to a fall (a
-- purchase) over GarageConfig.feel.cashCountSeconds.
local function showCash(u: UI)
	local target = cashNow()
	if cashTarget == target then
		return
	end
	local from = cashShown
	cashTarget = target
	cashToken += 1
	local mine = cashToken
	if from == nil or target >= from then
		cashShown = target
		u.cash.Text = money(target)
		return
	end
	local info = UITheme.motion.panel
	local seconds = GarageConfig.feel.cashCountSeconds
	local t0 = os.clock()
	task.spawn(function()
		while cashToken == mine and ui == u do
			local a = math.clamp((os.clock() - t0) / seconds, 0, 1)
			local shown = from + (target - from) * TweenService:GetValue(a, info.EasingStyle, info.EasingDirection)
			cashShown = shown
			u.cash.Text = money(shown)
			if a >= 1 then
				break
			end
			task.wait()
		end
	end)
end

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
	showCash(u)
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

-- The category's views (GarageConfig.views): its sub-tabs, or one.
local function views(): { GarageConfig.View }
	return GarageConfig.views[tab] or { { id = tab, label = "", shot = GarageConfig.FULL } }
end

-- The sub-tab showing: the one chosen this visit, else the first.
local function currentView(): GarageConfig.View
	local list = views()
	local chosen = subTab[tab]
	for _, v in list do
		if v.id == chosen then
			return v
		end
	end
	return list[1]
end

-- The camera to the view's part (GarageView.focus); arrived runs once it
-- is there.
local function focusView(arrived: (() -> ())?)
	GarageView.focus(currentView().shot, arrived)
end

-- What a tap shows besides the look: tips or a flame play a burst once
-- the camera is on the exhaust (a new tap starts a new one: ExhaustPops'
-- newest burst wins); a headlight colour blinks the lamps.
local function autoPreview(slot: Category)
	if slot == "exhaust" or slot == "flame" then
		local m = previewModel
		if not m then
			return
		end
		focusView(function()
			if previewModel ~= m or not m.Parent then
				return
			end
			revUntil = os.clock() + ExhaustPops.rev(m, draftLook())
		end)
	elseif slot == "head" then
		GarageView.flashHeadlights()
	end
end

local function chooseItem(slot: Category, id: string)
	if not shows(slot) then
		return
	end
	local p = previewing
	if p and p.slot == slot and p.id == id then
		-- The preview tapped again: show it again.
		GarageSounds.play("tap")
		autoPreview(slot)
		return
	end
	-- Choosing any other card drops an unbought preview.
	previewing = nil
	if owns(id) then
		if slotValue(draftLook(), slot) ~= id or want[slot] ~= nil then
			GarageSounds.play("fit")
			popCard(id)
			want[slot] = id
			sendEquip(slot)
		else
			GarageSounds.play("tap")
		end
	else
		GarageSounds.play("tap")
		previewing = { slot = slot :: string, id = id }
	end
	refresh()
	autoPreview(slot)
end

local function choosePlate(key: string)
	previewing = nil
	if slotValue(draftLook(), "plate") ~= key then
		GarageSounds.play("fit")
		popCard(key)
	else
		GarageSounds.play("tap")
	end
	want.plate = key
	sendEquip("plate")
	refresh()
end

local function chooseCar(id: string)
	if id == carId then
		return
	end
	GarageSounds.play("tap")
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
	-- The dim runs under the top bar too, like the panel's shade.
	local bleed = shadeBleed()
	scrim.Position = UDim2.fromOffset(-bleed, -bleed)
	scrim.Size = UDim2.new(1, 2 * bleed, 1, 2 * bleed)
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
			if status == "done" and inside and epoch == myEpoch then
				GarageSounds.play("buy")
				popCard(id)
			end
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

-- A set's grid: a palette's columns, or a list's single column (sizeGrids).
local function newGrid(u: UI, order: number, palette: boolean): Frame
	local g = Instance.new("Frame")
	g.Name = if palette then "Palette" else "List"
	g.BackgroundTransparency = 1
	g.AutomaticSize = Enum.AutomaticSize.Y
	g.Size = UDim2.new(1, 0, 0, 0)
	g.LayoutOrder = order
	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.CellPadding = if palette then UDim2.fromOffset(space("sm"), space("md")) else UDim2.fromOffset(0, space("xs"))
	layout.Parent = g
	table.insert(u.grids, { layout = layout, palette = palette })
	g.Parent = u.grid
	return g
end

local function sizeGrids(u: UI)
	-- The items' width: the list's, less the room either side kept for a
	-- chosen item's ring (the Slide padding).
	local width = u.grid.AbsoluteWindowSize.X - 2 * UITheme.stroke.selected
	for _, g in u.grids do
		if g.palette then
			local cols = paletteColumns(width)
			local gap = space("sm")
			g.layout.CellSize = UDim2.new(1 / cols, -math.ceil(gap * (cols - 1) / cols), 0, tileHeight())
		else
			g.layout.CellSize = UDim2.new(1, 0, 0, rowHeight())
		end
	end
end

local function tapCard(u: UI, card: Card, onTap: () -> ())
	registerTap({
		gui = card.frame,
		scroll = u.grid,
		onTap = onTap,
		onDown = function(down)
			pressCard(card, down)
		end,
	})
end

-- A category's items: a palette for colours, else a list.
local function itemCards(u: UI, category: Category, order: number)
	local palette = PALETTES[category] == true
	local parent = newGrid(u, order, palette)
	local layout = carLayout()
	for i, item in CosmeticsConfig.inCategory(category) do
		-- Tyres: only the ones for this car's drivetrain.
		if not CosmeticsConfig.fits(item, layout) then
			continue
		end
		local function draw(tile: Frame)
			drawItemTile(tile, item)
		end
		local card = if palette
			then buildTile(parent, i, item.id, category, item.name, item.price, item.rare == true, draw)
			else buildRow(parent, i, item.id, category, item.name, item.price, item.rare == true, draw, WIDE[category])
		tapCard(u, card, function()
			chooseItem(category, item.id)
		end)
	end
end

-- A line under the sub-tabs: why a set can't be fitted, or how the tyres
-- drive.
local function note(u: UI, text: string, name: string): TextLabel
	local l = UIKit.text(u.sub, text, "caption", "sand", touch, true)
	l.Name = name
	l.LayoutOrder = 1
	return l
end

local function clearContent(u: UI)
	closeSheet()
	press = nil
	tyreNote = nil
	table.clear(cards)
	table.clear(taps)
	table.clear(u.grids)
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

-- Where the rail's sodium bar sits across: centred in the rail's left
-- padding, beside the words.
local function railBarX(): number
	return math.floor((space("lg") - UITheme.stroke.marker) / 2)
end

-- The rail's chosen row: its word paint and bold, the sodium bar beside it,
-- sliding there over motion.panel when `slide`.
local function paintRail(u: UI, slide: boolean)
	local index = 1
	for i, entry in TABS do
		local chosen = entry.id == tab
		local label = u.railLabels[entry.id]
		local face = UITheme.font("nav")
		label.FontFace = if chosen then Font.new(face.Family, Enum.FontWeight.Bold) else face
		label.TextColor3 = if chosen then C.paint else C.sand
		if chosen then
			index = i
		end
	end
	local h = railRowH
	if h <= 0 then
		return
	end
	local barH = math.floor(h / 2)
	local to = UDim2.fromOffset(railBarX(), (index - 1) * h + math.floor((h - barH) / 2))
	u.railBar.Size = UDim2.fromOffset(UITheme.stroke.marker, barH)
	-- A slide still running would carry the bar to a row's old place.
	local running = railTween
	if running then
		running:Cancel()
		railTween = nil
	end
	if slide then
		local tw = TweenService:Create(u.railBar, UITheme.motion.panel, { Position = to })
		railTween = tw
		tw:Play()
	else
		u.railBar.Position = to
	end
end

-- The rail's rows go through the tap tracker too, like every item: the
-- rail scrolls on a short phone.
local function registerRail(u: UI)
	for _, entry in TABS do
		local label = u.railLabels[entry.id]
		registerTap({
			gui = u.railRows[entry.id],
			scroll = u.rail,
			onTap = function()
				GarageSounds.play("tab")
				if tab ~= entry.id then
					tab = entry.id
					buildTab(u)
					refresh()
				end
				-- The camera to the category's part (again, after a drag
				-- took it out).
				focusView()
			end,
			onDown = function(down)
				if entry.id ~= tab then
					label.TextColor3 = if down then C.paint else C.sand
				end
			end,
		})
	end
end

-- A sub-tab tapped: its set and its shot; the one showing tapped again
-- brings the camera back in after a drag took it out.
local function chooseView(id: string)
	local u = ui
	if not u then
		return
	end
	GarageSounds.play("tab")
	if subTab[tab] ~= id and currentView().id ~= id then
		subTab[tab] = id
		buildTab(u)
		refresh()
	end
	focusView()
end

-- The sub row (GarageConfig.views): the sub-tabs as words, the chosen one
-- with a sodium underline that slides to it from the last choice in this
-- category; the category's action at the row's end (REV, SHOP PLATES).
local function buildSubRow(u: UI)
	local subs = views()
	if #subs < 2 and tab ~= "exhaust" and tab ~= "plates" then
		return
	end
	local row = Instance.new("Frame")
	row.Name = "SubTabs"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, target())
	row.LayoutOrder = 0
	row.Parent = u.sub
	if #subs >= 2 then
		local view = currentView()
		-- Each word is padded into a wider target; the row starts that far
		-- left so the first word's letters line up with the items.
		local padX = space("sm")
		local words = Instance.new("Frame")
		words.Name = "Words"
		words.BackgroundTransparency = 1
		words.AutomaticSize = Enum.AutomaticSize.X
		words.Size = UDim2.new(0, 0, 1, 0)
		words.Position = UDim2.fromOffset(-padX, 0)
		list(words, true, 0)
		words.Parent = row
		local line = Instance.new("Frame")
		line.Name = "Underline"
		line.BackgroundColor3 = C.sodium
		line.BorderSizePixel = 0
		line.AnchorPoint = Vector2.new(0, 1)
		line.Size = UDim2.fromOffset(0, UITheme.stroke.selected)
		line.Parent = row
		local chosenWord: TextLabel? = nil
		for i, v in subs do
			local chosen = v.id == view.id
			local w = UIKit.text(words, v.label, "label", if chosen then "paint" else "sandDim", touch, false)
			w.Name = "Sub_" .. v.id
			w.LayoutOrder = i
			w.Size = UDim2.new(0, 0, 1, 0)
			w.AutomaticSize = Enum.AutomaticSize.X
			local p = Instance.new("UIPadding")
			p.PaddingLeft = UDim.new(0, padX)
			p.PaddingRight = UDim.new(0, padX)
			p.Parent = w
			if chosen then
				chosenWord = w
			end
			registerTap({
				gui = w,
				scroll = nil,
				onTap = function()
					chooseView(v.id)
				end,
				onDown = function(down)
					if not chosen then
						w.TextColor3 = if down then C.paint else C.sandDim
					end
				end,
			})
		end
		local cw = chosenWord
		if cw then
			local slid = false
			local function place()
				if not line.Parent then
					return
				end
				local x = cw.AbsolutePosition.X - row.AbsolutePosition.X + padX
				local width = cw.AbsoluteSize.X - 2 * padX
				if width <= 0 then
					return
				end
				local to = { Position = UDim2.new(0, x, 1, 0), Size = UDim2.fromOffset(width, UITheme.stroke.selected) }
				local was = underlineWas
				underlineWas = { tab = tab, x = x, w = width }
				if not slid and was and was.tab == tab and was.x ~= x then
					line.Position = UDim2.new(0, was.x, 1, 0)
					line.Size = UDim2.fromOffset(was.w, UITheme.stroke.selected)
					TweenService:Create(line, UITheme.motion.panel, to):Play()
				else
					line.Position = to.Position
					line.Size = to.Size
				end
				slid = true
			end
			cw:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
			words:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
			place()
		end
	end
	if tab == "exhaust" then
		-- REV: a burst of pops and flames on the turntable car, with the
		-- exhaust and flame on it now (bought or only previewing), so the flame is
		-- part of what a player is choosing (garage round 2 §2).
		local rev = UIKit.button(row, "REV", "secondary", touch)
		rev.Name = "Rev"
		rev.AnchorPoint = Vector2.new(1, 0.5)
		rev.Position = UDim2.fromScale(1, 0.5)
		rev.Activated:Connect(function()
			local m = previewModel
			if sheet or not m or not m.Parent or os.clock() < revUntil then
				return -- under the confirm sheet, or the last burst is still going
			end
			-- The camera on the exhaust first (GarageView.focus), then the
			-- burst, with the exhaust on the car at that moment.
			GarageSounds.play("tap")
			focusView(function()
				local now = previewModel
				if not now or now ~= m or not m.Parent then
					return
				end
				-- A burst with the exhaust and flame showing (ExhaustPops),
				-- waited out.
				revUntil = os.clock() + ExhaustPops.rev(m, draftLook())
			end)
		end)
	elseif tab == "plates" then
		local shop = UIKit.button(row, "SHOP PLATES", "secondary", touch)
		shop.Name = "ShopPlates"
		shop.AnchorPoint = Vector2.new(1, 0.5)
		shop.Position = UDim2.fromScale(1, 0.5)
		shop.Activated:Connect(function()
			if sheet then
				return -- under the confirm sheet
			end
			SpawnMenu.openTab("plates")
		end)
	end
end

-- The new set slides up into place (UITheme.motion.panel); its padding
-- rests at the room kept for a chosen item's ring.
local function slideIn(u: UI)
	local pad = u.grid:FindFirstChild("Slide")
	if pad and pad:IsA("UIPadding") then
		local rest = UITheme.stroke.selected
		pad.PaddingTop = UDim.new(0, rest + space("md"))
		TweenService:Create(pad, UITheme.motion.panel, { PaddingTop = UDim.new(0, rest) }):Play()
	end
end

buildTab = function(u: UI)
	clearContent(u)
	registerRail(u)
	paintRail(u, true)
	u.grid.CanvasPosition = Vector2.zero
	buildSubRow(u)
	local view = currentView()

	if tab == "cars" then
		local g = newGrid(u, 1, false)
		for i, car in SpawnMenu.cars() do
			local entry = car.entry
			local card = buildRow(g, i, car.id, nil, entry.displayName, 0, false, function(tile)
				tile.BackgroundColor3 = entry.body.paint
			end)
			tapCard(u, card, function()
				chooseCar(car.id)
			end)
		end
	elseif tab == "paint" then
		if view.id == "tint" then
			if not shows("tint") then
				note(u, "This car's windows can't be tinted yet", "NoWindows")
			end
			itemCards(u, "tint", 1)
		else
			if not paintable() then
				note(u, "This car's paint can't be changed yet", "NotPaintable")
			end
			itemCards(u, if view.id == "finish" then "finish" else "paint", 1)
		end
	elseif tab == "rims" then
		if view.id == "tyres" then
			-- The drift mode, for this car's drivetrain (garage-tyres-flames):
			-- the drivetrain and how the tyre showing drives.
			tyreNote = note(u, "", "TyreNote")
			itemCards(u, "tyre", 1)
		else
			itemCards(u, "rims", 1)
		end
	elseif tab == "lights" then
		itemCards(u, if view.id == "tail" then "tail" else "head", 1)
	elseif tab == "decal" then
		if not shows("decal") then
			note(u, "This car has no spot for a sun strip yet", "NoSpot")
		end
		itemCards(u, "decal", 1)
	elseif tab == "exhaust" then
		if not shows("exhaust") then
			note(u, "This car has no spot for exhaust tips yet", "NoSpot")
		end
		itemCards(u, if view.id == "flames" then "flame" else "exhaust", 1)
	elseif tab == "plates" then
		local g = newGrid(u, 1, false)
		local format: PlateStyles.Format = plateFormat()
		local keys = ownedPlates()
		local options: { { key: string, name: string } } = { { key = "", name = "My plate · every car" } }
		for _, k in keys do
			table.insert(options, { key = k, name = shownPlate(k) })
		end
		for i, o in options do
			local card = buildRow(g, i, o.key, "plate", o.name, 0, false, function(tile)
				-- The plate art is the swatch, edges and all.
				tile.BackgroundTransparency = 1
				local edge = tile:FindFirstChildOfClass("UIStroke")
				if edge then
					edge:Destroy()
				end
				PlateStyles.draw(tile, plateKeyFor(o.key), format)
			end, true)
			card.tile = nil -- the plate art is the tile; it never fades
			tapCard(u, card, function()
				choosePlate(o.key)
			end)
		end
		if #keys == 0 then
			local hint = UIKit.text(u.grid, "Plates you buy show here", "caption", "sandDim", touch, true)
			hint.LayoutOrder = 9
		end
	end
	sizeGrids(u)
	relayout(u)
	slideIn(u)
end

------------------------------------------------------------------------
-- Layout.
------------------------------------------------------------------------

relayout = function(u: UI)
	if relaying then
		return
	end
	relaying = true
	local w = panelWidth(u)
	local pad = space("lg")
	local tail = fadeTail()
	u.dock.Size = UDim2.new(0, w + tail, 1, 0)
	u.dock.Position = UDim2.fromOffset(if collapsed then -w else 0, 0)
	local bleed = shadeBleed()
	u.shade.Position = UDim2.fromOffset(-bleed, -bleed)
	u.shade.Size = UDim2.new(0, w + bleed, 1, 2 * bleed)
	u.tail.Position = UDim2.fromOffset(w, -bleed)
	u.tail.Size = UDim2.new(0, tail, 1, 2 * bleed)
	u.handle.Size = UDim2.fromOffset(target(), 2 * target())
	u.handle.Position = UDim2.new(0, w + space("sm"), 0.5, 0)

	-- Header: GARAGE and the Arabic after it; the cash and the close button
	-- at the right.
	local top = space("md")
	local headerH = math.max(target(), u.title.AbsoluteSize.Y)
	u.header.Position = UDim2.fromOffset(pad, top)
	u.header.Size = UDim2.fromOffset(w - 2 * pad, headerH)
	u.arabic.Position = UDim2.new(0, u.title.AbsoluteSize.X + space("md"), 0.5, 0)
	u.cash.Position = UDim2.new(1, -(u.leave.AbsoluteSize.X + space("md")), 0.5, 0)
	local y = top + headerH + space("lg")
	local height = math.max(u.gui.AbsoluteSize.Y - y - pad, 0)

	-- The rail: as wide as its longest word. On touch the rows share its
	-- height, between railMinTouchRow and a target, so all seven show.
	for _, entry in TABS do
		railLabelW = math.max(railLabelW, u.railLabels[entry.id].AbsoluteSize.X)
	end
	local railW = pad + railLabelW + space("sm")
	local rowH = target() + space("xs")
	if touch then
		rowH = math.clamp(math.floor(height / #TABS), UITheme.sidePanel.railMinTouchRow, target())
	end
	u.rail.Position = UDim2.fromOffset(0, y)
	u.rail.Size = UDim2.fromOffset(railW, height)
	u.rail.CanvasSize = UDim2.fromOffset(0, rowH * #TABS)
	for i, entry in TABS do
		local row = u.railRows[entry.id]
		row.Position = UDim2.fromOffset(0, (i - 1) * rowH)
		row.Size = UDim2.new(1, 0, 0, rowH)
	end
	if rowH ~= railRowH then
		railRowH = rowH
		paintRail(u, false)
	end

	-- The content column, top-aligned with the rail.
	local cx = railW + space("md")
	u.content.Position = UDim2.fromOffset(cx, y)
	u.content.Size = UDim2.fromOffset(math.max(w - cx - pad, 0), height)
	local cy = 0
	local subH = u.subList.AbsoluteContentSize.Y
	u.sub.Visible = subH > 0
	if subH > 0 then
		u.sub.Size = UDim2.new(1, 0, 0, subH)
		cy = subH + space("sm")
	end
	local bottom = 0
	if u.foot.Visible then
		local footH = math.max(target(), lineBox("heading") + lineBox("price")) + 2 * space("sm")
		u.foot.Size = UDim2.new(1, 0, 0, footH)
		u.foot.Position = UDim2.new(0, 0, 1, -footH)
		bottom += footH + space("sm")
	end
	if u.toast.Visible then
		local th = u.toast.AbsoluteSize.Y
		u.toast.Position = UDim2.new(0, 0, 1, -(bottom + th))
		bottom += th + space("sm")
	end
	u.grid.Position = UDim2.fromOffset(0, cy)
	u.grid.Size = UDim2.new(1, 0, 1, -(cy + bottom))
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
	-- The shade's tail would stay on the screen's edge: it fades instead.
	TweenService:Create(u.tail, UITheme.motion.panel, { BackgroundTransparency = if c then 1 else 0 }):Play()
	u.handle.Text = if c then "›" else "‹"
	GarageView.setPanelOpen(not c)
end

------------------------------------------------------------------------
-- Build and tear down.
------------------------------------------------------------------------

-- A shade layer: asphalt950, see-through from `from` at its left to `to`
-- at its right.
local function shadeFrame(parent: Instance, name: string, from: number, to: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = C.asphalt950
	f.BorderSizePixel = 0
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new(from, to)
	g.Parent = f
	f.Parent = parent
	return f
end

local function build(): UI
	touch = UIKit.isTouch()
	railLabelW = 0
	railRowH = 0
	local g = Instance.new("ScreenGui")
	g.Name = "GaragePanel"
	g.ResetOnSpawn = false
	-- Not IgnoreGuiInset: the panel runs under Roblox's top bar, never
	-- beneath its buttons (the shade alone bleeds up under it).
	g.IgnoreGuiInset = false
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = DISPLAY_ORDER

	local dock = Instance.new("Frame")
	dock.Name = "Dock"
	dock.BackgroundTransparency = 1
	dock.Size = UDim2.fromScale(0, 1)
	dock.Parent = g

	-- The shade (UITheme.shade): under the panel it counts as the panel (a
	-- drag there is not the turntable's); its tail past the panel fades to
	-- clear and lets drags through (GarageView.overUi skips PassThrough).
	local shade = shadeFrame(dock, "Shade", UITheme.shade.near, UITheme.shade.far)
	shade.Active = true
	local tail = shadeFrame(dock, "ShadeTail", UITheme.shade.far, 1)
	tail:SetAttribute("PassThrough", true)

	-- The collapse handle: a pill just past the panel's edge at mid-height,
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
	header.Parent = dock
	local title = UIKit.text(header, "GARAGE", "display", "paint", touch, false)
	title.Name = "Title"
	title.AnchorPoint = Vector2.new(0, 0.5)
	title.Position = UDim2.fromScale(0, 0.5)
	-- The Arabic follows the English: the right edge holds the cash and the
	-- close button (UI_SYSTEM.md "Arabic with English").
	local arabic = Instance.new("TextLabel")
	arabic.Name = "Arabic"
	arabic.BackgroundTransparency = 1
	arabic.AutomaticSize = Enum.AutomaticSize.XY
	arabic.Size = UDim2.fromOffset(0, 0)
	arabic.AnchorPoint = Vector2.new(0, 0.5)
	arabic.FontFace = UITheme.font("title")
	arabic.TextSize = math.floor(UITheme.textSize("title", touch) * UITheme.arabicScale + 0.5)
	arabic.TextColor3 = C.sand
	arabic.Text = "كراج"
	arabic.Parent = header
	-- Your balance is not something to press or pay: paint, not sodium.
	local cash = UIKit.text(header, "0", "title", "paint", touch, false)
	cash.Name = "Cash"
	cash.AnchorPoint = Vector2.new(1, 0.5)
	-- LEAVE: a square close button, its mark two crossed strokes (no emoji).
	local leave = UIKit.button(header, "", "secondary", touch)
	leave.Name = "Leave"
	leave.AutomaticSize = Enum.AutomaticSize.None
	leave.Size = UDim2.fromOffset(target(), target())
	leave.AnchorPoint = Vector2.new(1, 0.5)
	leave.Position = UDim2.fromScale(1, 0.5)
	for _, angle in { 45, -45 } do
		local stroke = Instance.new("Frame")
		stroke.Name = "Mark"
		stroke.BackgroundColor3 = C.paint
		stroke.BorderSizePixel = 0
		stroke.AnchorPoint = Vector2.new(0.5, 0.5)
		stroke.Position = UDim2.fromScale(0.5, 0.5)
		stroke.Size = UDim2.fromOffset(math.floor(target() * CLOSE_MARK + 0.5), UITheme.stroke.selected)
		stroke.Rotation = angle
		stroke.Parent = leave
	end

	-- The rail: the categories as words.
	local rail = scroller("Rail", false)
	rail.ScrollBarThickness = 0
	rail.AutomaticCanvasSize = Enum.AutomaticSize.None
	rail.Parent = dock
	local railRows: { [Tab]: Frame } = {}
	local railLabels: { [Tab]: TextLabel } = {}
	for _, entry in TABS do
		local row = Instance.new("Frame")
		row.Name = entry.label
		row.BackgroundTransparency = 1
		row.Parent = rail
		local label = UIKit.text(row, entry.label, "nav", "sand", touch, false)
		label.Name = "Label"
		label.AnchorPoint = Vector2.new(0, 0.5)
		label.Position = UDim2.new(0, space("lg"), 0.5, 0)
		railRows[entry.id] = row
		railLabels[entry.id] = label
	end
	local railBar = Instance.new("Frame")
	railBar.Name = "Marker"
	railBar.BackgroundColor3 = C.sodium
	railBar.BorderSizePixel = 0
	UIKit.corner(railBar, "pill")
	railBar.Parent = rail

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Parent = dock

	local sub = Instance.new("Frame")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	local subList = list(sub, false, space("xs"))
	sub.Parent = content

	local grid = scroller("Items", false)
	list(grid, false, space("md"))
	-- Room either side for a chosen item's ring; the top eases from more
	-- as a new set comes in (slideIn).
	local slide = Instance.new("UIPadding")
	slide.Name = "Slide"
	local ring = UDim.new(0, UITheme.stroke.selected)
	slide.PaddingTop, slide.PaddingBottom, slide.PaddingLeft, slide.PaddingRight = ring, ring, ring, ring
	slide.Parent = grid
	grid.Parent = content

	-- The foot: a hairline over the item's name and price, and the action.
	local foot = Instance.new("Frame")
	foot.Name = "Foot"
	foot.BackgroundTransparency = 1
	foot.Visible = false
	foot.Parent = content
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.BackgroundColor3 = C.asphalt600
	rule.BorderSizePixel = 0
	rule.Size = UDim2.new(1, 0, 0, UITheme.stroke.hairline)
	rule.Parent = foot
	local footItem = Instance.new("Frame")
	footItem.Name = "Item"
	footItem.BackgroundTransparency = 1
	footItem.AutomaticSize = Enum.AutomaticSize.Y
	footItem.AnchorPoint = Vector2.new(0, 0.5)
	footItem.Position = UDim2.fromScale(0, 0.5)
	list(footItem, false, 0)
	footItem.Parent = foot
	local footName = UIKit.text(footItem, "", "heading", "paint", touch, false)
	footName.Name = "Name"
	footName.AutomaticSize = Enum.AutomaticSize.None
	footName.Size = UDim2.new(1, 0, 0, lineBox("heading"))
	footName.RichText = true
	footName.TextTruncate = Enum.TextTruncate.AtEnd
	footName.LayoutOrder = 1
	local footPrice = UIKit.text(footItem, "", "price", "sodium", touch, false)
	footPrice.Name = "Price"
	footPrice.AutomaticSize = Enum.AutomaticSize.None
	footPrice.Size = UDim2.new(1, 0, 0, lineBox("price"))
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
	toastFrame.Parent = content
	local toastLabel = UIKit.text(toastFrame, "", "body", "paint", touch, true)

	local u: UI = {
		gui = g,
		dock = dock,
		shade = shade,
		tail = tail,
		handle = handle,
		header = header,
		title = title,
		arabic = arabic,
		cash = cash,
		leave = leave,
		rail = rail,
		railRows = railRows,
		railLabels = railLabels,
		railBar = railBar,
		content = content,
		sub = sub,
		subList = subList,
		grid = grid,
		grids = {},
		foot = foot,
		footName = footName,
		footPrice = footPrice,
		footButton = footButton,
		toast = toastFrame,
		toastLabel = toastLabel,
	}

	-- The item's words stop short of the action button.
	local function fitFoot()
		footItem.Size = UDim2.new(1, -(footButton.AbsoluteSize.X + space("md")), 0, 0)
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

	-- Measured sizes the layout reads: lay out again when one changes.
	local watched: { Instance } = { title, leave, subList, g }
	for _, label in railLabels do
		table.insert(watched, label)
	end
	for _, w in watched do
		local prop = if w:IsA("UIListLayout") then "AbsoluteContentSize" else "AbsoluteSize"
		w:GetPropertyChangedSignal(prop):Connect(function()
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
	-- The palette's columns follow the list's width (a scroll bar coming
	-- or going changes it).
	grid:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
		if ui == u then
			sizeGrids(u)
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
	table.clear(subTab)
	cashShown, cashTarget = nil, nil
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
	focusView()
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
	GarageSounds.start()
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
