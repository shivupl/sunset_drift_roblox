--!strict
-- The garage panel: the side panel of the customisation view (garage spec
-- docs/superpowers/specs/2026-09-28-garage-design.md §4 and §5). The owner's
-- rules, 2026-09-28: "Down one side, car fills the rest. Categories: my cars,
-- paint, wheels, plates, lights, sun strips, exhaust. Every change previews live
-- on the car. No confirm step until money is involved. Owned versus unowned
-- is unmistakable. Unowned previews with a price. Nothing is bought without
-- an explicit confirm. Thumb-reachable and readable at phone size."
--
-- GarageView owns the view (camera, turntable, the preview car, LEAVE by Esc
-- or gamepad B); this module is built on its onEnter and torn down on its
-- onLeave.
--
-- How it looks (2026-10-12, the owner: "now moving onto garage, implement
-- these 3 to let me chose from ... this time for both pc and phone"): in
-- the car picker's look (Looks/Parts), in the layout every screen follows
-- (Looks/Layouts, ui-flow: the menu's CARS, PLATES and SETTINGS draw
-- through the same layouts, so the garage and the menu are one frame):
--   SHOWCASE  (Looks/Showcase) the car big in the middle; the categories as
--             words down the left on a shade; the items as square blocks
--             down the right, lined up under the cash: SHOWCASE (on a
--             panel), GLASS (the panel see-through), FRAME (on a shade, the
--             blocks in an outlined tray). SHADES, EDGE, SHELF, CARD and
--             WIDE were tried and went (2026-10-12: "remove other modes").
--   DOCK      (Looks/Dock) the categories as tabs in a dock along the bottom
--             with the action and EXIT; the items in a panel on the left.
--   SHADE     (Looks/Shade) the garage-ui-overhaul's shade and rail of words,
--             the sub-tabs as words along the bottom. Parked (2026-10-12,
--             the owner on the phone: "i liked those 2 mobile layouts the
--             most so lets narrow it down to that for now"): out of the
--             lists, kept to come back to.
-- The cash is drawn here, where the HUD has it and as the HUD draws it
-- (Parts.hudCash), whatever the layout. The LAYOUT button in each cycles
-- the layouts for every screen; the choice is the LocalPlayer attribute
-- UiLayout and lasts the session. Each puts the car where its panels leave
-- room (GarageConfig.layoutOffset). The pieces slide in from their edges on
-- entering (Parts.intro); SHOP PLATES opens the menu's PLATES over the
-- panel in the same frame, and the panel hides under it (SpawnMenu.watch).
--
-- Behaviour:
--   * A tap applies the item to the turntable car at once
--     (CarCosmetics.apply on the draft look). An owned (or stock) item is also
--     equipped at once through CosmeticsAction ("equip" / "plate"); taps are
--     coalesced per slot, so a burst of taps sends the last one, never one
--     per tap (the server allows 4 actions a second).
--   * An unowned item only previews. There is at most one unbought preview:
--     choosing any other item drops it; switching category keeps it; leaving
--     the view or switching car drops it (the preview car is rebuilt with the
--     saved look).
--   * Each item's word (UI_SYSTEM.md "Shop items"): ON CAR for what is saved
--     on this car, ✓ OWNED, or the price; what shows on the car now is edged
--     green; rare items get the dusk diamond before the name.
--   * The action button: BUY with the preview's price opens a confirm sheet
--     (item, price, cash after, BUY / CANCEL); only the sheet's BUY charges
--     ("buy", then "equip"). On MY CARS it is DRIVE THIS; otherwise it reads
--     ON YOUR CAR and does nothing (an owned item goes on with a tap).
--   * MY CARS swaps the turntable car (GarageView.setCar); DRIVE THIS asks
--     for that car the way the spawn menu does and leaves the view.
--   * PLATES equips one of your plates on this car; SHOP PLATES opens the
--     menu's PLATES, which stays the one place plates are bought.
--   * WHEELS has the rims and the tyres, EXHAUST the tips and the flames
--     (garage-tyres-flames, 2026-10-05). A tyre is a drift mode: the list
--     has only the tyres for this car's drivetrain, and the note over it
--     says how the tyre showing drives. REV fires the flame showing, so a
--     flame is heard and seen before it is bought.
--   * Garage polish (2026-10-05, GarageConfig.views): a category with more
--     than one set of items has sub-tabs (PAINT: COLOUR, FINISH, TINT;
--     WHEELS: RIMS, TYRES; LIGHTS: HEADLIGHTS, TAIL LIGHTS; EXHAUST: TIPS,
--     FLAMES), one set each, remembered per category for the visit. Each
--     view has a camera shot (GarageView.focus): the camera goes to the
--     part; tapping the sub-tab again goes back in after a drag took it out.
--     Tapping tips or a flame plays a burst once the camera is there; a
--     headlight colour blinks the lamps. Sounds (GarageSounds) on a tab, a
--     preview, a fit, a purchase and an error; an item shrinks while pressed
--     and pops when it is fitted or bought; the cash counts down after a
--     purchase.
--   * H or gamepad Y fold the panel away (SHADE's pill too); the car
--     re-centres (GarageView.setPanelOpen) and a pill brings it back.
--
-- Taps on items are tracked here through UserInputService, not with
-- Activated, for the reason SpawnMenu's header gives: on a phone a GuiButton
-- inside a ScrollingFrame blocks the drag that scrolls it, and a touch that
-- moves a little never fires Activated. A press counts as a tap if it lifts
-- over the same item within TAP_SLOP_PX and the list did not scroll.
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
local GarageConfig = require(Shared:WaitForChild("GarageConfig"))
local PlateText = require(Shared:WaitForChild("PlateText"))
local PlateStyles = require(Shared:WaitForChild("PlateStyles"))
local Client = script.Parent.Parent
local UIKit = require(Client:WaitForChild("UIKit"))
local CarCosmetics = require(Client:WaitForChild("CarCosmetics"))
local ExhaustPops = require(Client:WaitForChild("ExhaustPops"))
local SpawnMenu = require(Client:WaitForChild("SpawnMenu"))
local CarArt = require(Client:WaitForChild("CarPicker"):WaitForChild("Art"))
local GarageView = require(script.Parent:WaitForChild("GarageView"))
local GarageSounds = require(script.Parent:WaitForChild("GarageSounds"))
local Looks = script.Parent:WaitForChild("Looks")
local Types = require(Looks:WaitForChild("Types"))
local Parts = require(Looks:WaitForChild("Parts"))

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
-- Draw order: the gui sits under the spawn menu (DisplayOrder 20) so SHOP
-- PLATES can open that menu over the panel, and under GarageView's fade (50).
local DISPLAY_ORDER = 15
-- A finish swatch's highlight: the car's paint is lifted toward white by
-- this much at the swatch's top corner for a shiny (Glass) finish, plus
-- FINISH_SHINE_PER_REFLECTANCE for each unit of reflectance, so Gloss,
-- Metallic and Chrome read as a ladder (0.35, 0.5, 0.8).
local FINISH_SHINE = 0.35
local FINISH_SHINE_PER_REFLECTANCE = 3

-- The layout is the one every screen follows (Looks/Layouts, ui-flow).
local Layouts = require(Looks:WaitForChild("Layouts"))

-- The categories, with their Arabic for the titles (UI_SYSTEM.md "Arabic
-- with English": section titles are bilingual) and their icon (art/garage).
local TABS: { Types.TabDef } = {
	{ id = "cars", label = "MY CARS", arabic = "سياراتي", icon = Parts.ICON.cars },
	{ id = "paint", label = "PAINT", arabic = "صبغ", icon = Parts.ICON.paint },
	{ id = "rims", label = "WHEELS", arabic = "جنوط", icon = Parts.ICON.rims },
	{ id = "plates", label = "PLATES", arabic = "لوحات", icon = Parts.ICON.plates },
	{ id = "lights", label = "LIGHTS", arabic = "أنوار", icon = Parts.ICON.lights },
	-- "decal" stays the slot key (stored on profiles); the player reads SUN
	-- STRIPS, the banner across a windscreen's top (garage round 3 §4).
	{ id = "decal", label = "SUN STRIPS", arabic = "شريط", icon = Parts.ICON.decal },
	{ id = "exhaust", label = "EXHAUST", arabic = "اكزوز", icon = Parts.ICON.exhaust },
}

-- The sets shown as a palette, a grid of swatches: the ones that are
-- colours. Everything else is a list, a row per item (garage-ui-overhaul).
local PALETTES: { [string]: boolean } = { paint = true, tint = true, rims = true, head = true, tail = true }
-- List rows whose swatch is a banner.
local WIDE: { [string]: boolean } = { decal = true }

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
-- The confirm sheet's title: BUY THIS <word>.
local SHEET_WORDS: { [string]: string } = {
	paint = "PAINT",
	finish = "FINISH",
	rims = "RIM",
	head = "HEADLIGHT",
	tail = "TAIL LIGHT",
	decal = "SUN STRIP",
	exhaust = "EXHAUST",
	tint = "TINT",
	tyre = "TYRE",
	flame = "FLAME",
}

-- CosmeticsAction statuses, as the player reads them.
local MESSAGES: { [string]: string } = {
	cash = "Not enough cash. Nothing was charged",
	unavailable = "The garage shop is unavailable right now. Nothing was charged",
	busy = "One moment, then try again",
	unknown = "That item isn't available",
	notowned = "You don't own that yet",
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

type Sheet = { ui: Parts.Sheet, update: () -> () }

local remote: RemoteFunction? = nil
local gui: ScreenGui? = nil
local view: Types.View? = nil
local viewRoot: GuiObject? = nil
-- The cash, where the driving HUD has it whatever the layout (Parts.hudCash).
local cashGui: ScreenGui? = nil
local cashPill: Parts.Cash? = nil
local restore: TextButton? = nil
local toastFn: Parts.Toast? = nil
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
-- The owned plates changed while the PLATES list could not be rebuilt.
local platesDirty = false
local taps: { Tap } = {}
local press: Press? = nil
local sheet: Sheet? = nil
local lastApplied: string? = nil
local modalBefore = false
-- REV's last burst runs until this os.clock(); taps before then do nothing.
local revUntil = 0
-- Each category's sub-tab (GarageConfig.views), for this visit.
local subTab: { [string]: string } = {}
-- The cash as shown, and where it is heading: it counts down after a
-- purchase (GarageConfig.feel.cashCountSeconds).
local cashShown: number? = nil
local cashTarget: number? = nil
local cashToken = 0

------------------------------------------------------------------------
-- What the player owns and has saved (Player attributes from Economy).
------------------------------------------------------------------------

local function money(n: number): string
	return Parts.money(n)
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

-- The drivetrain of a car ("RWD", "FWD", "AWD"): its tyres are the ones
-- that fit it (CosmeticsConfig.fits).
local function layoutOf(id: string): string
	return ConfigLoader.driftStyles().layoutOf(ConfigLoader.forCar(id))
end

local function carLayout(): string
	return layoutOf(carId)
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

local function carName(id: string): string
	return ConfigLoader.entry(id).displayName
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
-- Swatches: what an item looks like, drawn in its box's swatch.
------------------------------------------------------------------------

local function space(name: string): number
	return UITheme.px((UITheme.space :: any)[name], touch)
end

local function tileBlank(tile: Frame)
	-- Nothing to draw: a dark swatch, outlined by its ring.
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
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, space("xs"))
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.Parent = row
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
	-- taller than three fifths of it.
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
		-- A soft light across the top, so a colour reads as paint.
		local g = Instance.new("UIGradient")
		g.Rotation = 120
		g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.55, 0.55, 0.55))
		g.Parent = tile
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
-- The category showing: its sub-tabs, its set, its items.
------------------------------------------------------------------------

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

-- The cosmetic slot whose items show, or nil (MY CARS, PLATES).
local function category(): Category?
	local v = currentView().id
	local c: string? = nil
	if tab == "paint" then
		c = if v == "tint" then "tint" elseif v == "finish" then "finish" else "paint"
	elseif tab == "rims" then
		c = if v == "tyres" then "tyre" else "rims"
	elseif tab == "lights" then
		c = if v == "tail" then "tail" else "head"
	elseif tab == "decal" then
		c = "decal"
	elseif tab == "exhaust" then
		c = if v == "flames" then "flame" else "exhaust"
	end
	return (c :: any) :: Category?
end

local function entryOf(item: CosmeticsConfig.Item): Types.Entry
	local cat = item.category
	return {
		key = item.id,
		slot = cat,
		name = item.name,
		price = item.price,
		rare = item.rare == true,
		shape = if PALETTES[cat] then "swatch" elseif WIDE[cat] then "wide" else "row",
		fades = true,
		draw = function(tile: Frame)
			drawItemTile(tile, item)
		end,
	}
end

local function entries(): { Types.Entry }
	local out: { Types.Entry } = {}
	if tab == "cars" then
		for _, car in SpawnMenu.cars() do
			local entry = car.entry
			local photo = CarArt.cars[car.id]
			table.insert(out, {
				key = car.id,
				slot = nil,
				name = entry.displayName,
				price = 0,
				rare = false,
				shape = "car",
				fades = false,
				draw = function(tile: Frame)
					if photo then
						-- The car picker's photo on a dark stage.
						tile.BackgroundColor3 = Color3.fromHex("#2C2E33")
						local img = Instance.new("ImageLabel")
						img.Name = "Photo"
						img.BackgroundTransparency = 1
						img.Image = photo
						img.ScaleType = Enum.ScaleType.Fit
						img.Size = UDim2.fromScale(1, 1)
						img.Parent = tile
					else
						tile.BackgroundColor3 = entry.body.paint
					end
				end,
			})
		end
	elseif tab == "plates" then
		local format: PlateStyles.Format = plateFormat()
		local options: { { key: string, name: string } } = { { key = "", name = "My plate" } }
		for _, k in ownedPlates() do
			table.insert(options, { key = k, name = shownPlate(k) })
		end
		for _, o in options do
			table.insert(out, {
				key = o.key,
				slot = "plate",
				name = o.name,
				price = 0,
				rare = false,
				shape = "wide",
				fades = false,
				draw = function(tile: Frame)
					-- The plate art is the swatch, edges and all.
					tile.BackgroundTransparency = 1
					local edge = tile:FindFirstChildOfClass("UIStroke")
					if edge then
						edge:Destroy()
					end
					PlateStyles.draw(tile, plateKeyFor(o.key), format)
				end,
			})
		end
	else
		local cat = category()
		if cat then
			local layout = carLayout()
			for _, item in CosmeticsConfig.inCategory(cat :: Category) do
				-- Tyres: only the ones for this car's drivetrain.
				if CosmeticsConfig.fits(item, layout) then
					table.insert(out, entryOf(item))
				end
			end
		end
	end
	return out
end

-- The line under the sub-tabs: why a set can't be fitted, or how the tyres
-- drive.
local function noteText(): string?
	local v = currentView().id
	if tab == "paint" then
		if v == "tint" then
			return if shows("tint") then nil else "This car's windows can't be tinted yet"
		end
		return if paintable() then nil else "This car's paint can't be changed yet"
	elseif tab == "rims" and v == "tyres" then
		local styles = ConfigLoader.driftStyles()
		local layout = carLayout()
		local mode = styles.resolve(layout, CarLook.item(draftLook(), "tyre").driftStyle)
		return `{styles.layoutName[layout]}: {styles.styles[mode].blurb}`
	elseif tab == "decal" then
		return if shows("decal") then nil else "This car has no spot for a sun strip yet"
	elseif tab == "exhaust" then
		return if shows("exhaust") then nil else "This car has no spot for exhaust tips yet"
	elseif tab == "plates" then
		return if #ownedPlates() == 0 then "Plates you buy show here" else nil
	end
	return nil
end

------------------------------------------------------------------------
-- Items' states.
------------------------------------------------------------------------

-- What every item's state is read from, worked out once per repaint (the
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
local paintCtx: Context? = nil

local function stateOf(e: Types.Entry): Types.EntryState
	local ctx = paintCtx or context()
	paintCtx = ctx
	local slot = e.slot
	if slot == nil then
		-- A car: its word is its drivetrain, which decides its tyres, or
		-- that it is the one you have out.
		local driving = ctx.driving == e.key
		return {
			chosen = e.key == carId,
			disabled = false,
			word = if driving then "✓ DRIVING" else layoutOf(e.key),
			kind = if driving then "owned" else "note",
		}
	end
	local disabled = not showsSlot(slot, ctx.paintable, ctx.hasStrip, ctx.hasTips, ctx.hasWindows)
	local onCar = slotValue(ctx.saved, slot) == e.key
	local owned = slot == "plate" or CosmeticsConfig.isStock(e.key) or ctx.owned[e.key] == true
	local word, kind: Types.WordKind
	if disabled then
		word, kind = "", "none"
	elseif onCar then
		word, kind = "ON CAR", "oncar"
	elseif owned then
		word, kind = "✓ OWNED", "owned"
	else
		word, kind = money(e.price), "price"
	end
	return {
		chosen = slotValue(ctx.draft, slot) == e.key,
		disabled = disabled,
		word = word,
		kind = kind,
	}
end

-- What the action button does and the line that names it.
local function foot(): Types.Foot
	if tab == "cars" then
		return { name = carName(carId), rare = false, note = layoutOf(carId), action = "drive", price = 0, entry = nil }
	end
	local p = previewing
	if p then
		local item = CosmeticsConfig.find(p.id)
		if item then
			return { name = item.name, rare = item.rare == true, note = "Previewing", action = "buy", price = item.price, entry = entryOf(item) }
		end
	end
	local draft = draftLook()
	local onYour = `On your {carName(carId)}`
	if tab == "plates" then
		local key = slotValue(draft, "plate")
		return { name = if key == "" then "My plate" else shownPlate(key), rare = false, note = onYour, action = "oncar", price = 0, entry = nil }
	end
	local cat = category()
	if cat then
		local item = CosmeticsConfig.find(slotValue(draft, cat))
		if item then
			return { name = item.name, rare = item.rare == true, note = onYour, action = "oncar", price = 0, entry = entryOf(item) }
		end
	end
	return { name = "", rare = false, note = "", action = "none", price = 0, entry = nil }
end

------------------------------------------------------------------------
-- The car on the turntable, and repainting.
------------------------------------------------------------------------

local function toast(text: string, kind: "done" | "error" | "info")
	if kind == "error" then
		GarageSounds.play("error")
	end
	local t = toastFn
	if t then
		t(text, kind)
	end
end

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

-- A new session of choices (enter, leave, car switch): what was wanted or
-- sent for the last one is dropped, and its replies are ignored.
local function newEpoch()
	epoch += 1
	table.clear(want)
	table.clear(sending)
	table.clear(confirmed)
end

-- The cash readout: straight to a rise, counting down to a fall (a
-- purchase) over GarageConfig.feel.cashCountSeconds.
local function showCash()
	local v = view
	if not v then
		return
	end
	local target = cashNow()
	if cashTarget == target then
		return
	end
	local from = cashShown
	cashTarget = target
	cashToken += 1
	local mine = cashToken
	local pill = cashPill
	if not pill then
		return
	end
	if from == nil or target >= from then
		cashShown = target
		pill.set(money(target))
		return
	end
	local info = UITheme.motion.panel
	local seconds = GarageConfig.feel.cashCountSeconds
	local t0 = os.clock()
	task.spawn(function()
		while cashToken == mine and view == v do
			local a = math.clamp((os.clock() - t0) / seconds, 0, 1)
			local shown = from + (target - from) * TweenService:GetValue(a, info.EasingStyle, info.EasingDirection)
			cashShown = shown
			pill.set(money(shown))
			if a >= 1 then
				break
			end
			task.wait()
		end
	end)
end

local fillTab: () -> ()

local function refresh()
	local v = view
	if not v or not inside then
		return
	end
	if platesDirty and not sheet then
		platesDirty = false
		if tab == "plates" then
			fillTab()
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
	paintCtx = nil
	v.refresh()
	paintCtx = nil
	showCash()
	local s = sheet
	if s then
		s.update()
	end
end

-- Fitted or bought: the item pops and settles.
local function popCard(key: string)
	local v = view
	if v then
		v.pop(key)
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
	-- Choosing any other item drops an unbought preview.
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
	-- The items read the car (the Factory swatch, paint, plate art); MY CARS
	-- itself only repaints, so its list keeps its scroll.
	if tab ~= "cars" then
		fillTab()
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
		s.ui.holder:Destroy()
	end
end

local ctxNow: Types.Ctx? = nil

local function openSheet()
	local p = previewing
	local g, ctx = gui, ctxNow
	if sheet or not p or not g or not ctx then
		return
	end
	local item = CosmeticsConfig.find(p.id)
	if not item then
		return
	end
	local working = false
	local mine: Sheet
	local function cancel()
		closeSheet(mine)
		refresh()
	end
	local function buy()
		if working or cashNow() < item.price then
			return
		end
		working = true
		mine.update()
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
	end
	local cat = item.category
	local ui = Parts.sheet(g, ctx, {
		title = `BUY THIS {SHEET_WORDS[cat] or "ITEM"}`,
		name = item.name,
		rare = item.rare == true,
		what = `{CATEGORY_NAMES[cat] or cat}, yours on every car`,
		price = item.price,
		entry = entryOf(item),
	}, cancel, buy)
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
-- Tabs, sub-tabs and the layout.
------------------------------------------------------------------------

fillTab = function()
	local v = view
	if not v then
		return
	end
	closeSheet()
	press = nil
	table.clear(taps)
	paintCtx = nil
	v.fill()
end

local function chooseTab(id: string)
	if sheet then
		return
	end
	GarageSounds.play("tab")
	if tab ~= id then
		tab = id :: Tab
		fillTab()
		refresh()
	end
	-- The camera to the category's part (again, after a drag took it out).
	focusView()
end

-- A sub-tab tapped: its set and its shot; the one showing tapped again
-- brings the camera back in after a drag took it out.
local function chooseView(id: string)
	if sheet then
		return
	end
	GarageSounds.play("tab")
	if subTab[tab] ~= id and currentView().id ~= id then
		subTab[tab] = id
		fillTab()
		refresh()
	end
	focusView()
end

local function tapEntry(e: Types.Entry)
	local slot = e.slot
	if slot == nil then
		chooseCar(e.key)
	elseif slot == "plate" then
		choosePlate(e.key)
	else
		chooseItem(slot :: Category, e.key)
	end
end

local function doAction()
	if sheet then
		return
	end
	if tab == "cars" then
		if SpawnMenu.requestCar(carId) then
			GarageView.leave()
		else
			toast(MESSAGES.busy, "info")
		end
	elseif previewing then
		openSheet()
	end
end

local function doExtra()
	if sheet then
		return
	end
	if tab == "exhaust" then
		-- REV: a burst of pops and flames on the turntable car, with the
		-- exhaust and flame on it now (bought or only previewing), so the
		-- flame is part of what a player is choosing (garage round 2 §2).
		local m = previewModel
		if not m or not m.Parent or os.clock() < revUntil then
			return -- the last burst is still going
		end
		GarageSounds.play("tap")
		focusView(function()
			local now = previewModel
			if not now or now ~= m or not m.Parent then
				return
			end
			revUntil = os.clock() + ExhaustPops.rev(m, draftLook())
		end)
	elseif tab == "plates" then
		-- The menu's PLATES in the same frame: the garage hides under it
		-- (SpawnMenu.watch) and EXIT brings it straight back.
		SpawnMenu.openTab("plates", { switch = true })
	end
end

local function layout(): Types.Layout
	return Layouts.current()
end

local function setCollapsed(c: boolean)
	local root, r = viewRoot, restore
	if not inside or sheet or c == collapsed or not root or not r then
		return
	end
	collapsed = c
	root.Visible = not c
	r.Visible = c
	GarageView.setPanelOpen(not c)
end

local buildView: (snap: boolean, still: boolean?) -> ()

-- The next layout, for every screen (the menu follows it too); the view is
-- built again by the attribute's change (GaragePanel.start).
local function nextLayout()
	if sheet then
		return
	end
	local nxt = Layouts.advance()
	GarageSounds.play("tab")
	toast(`LAYOUT: {nxt.name}`, "info")
end

local function makeCtx(g: ScreenGui): Types.Ctx
	return {
		touch = touch,
		screen = Parts.screen(g),
		title = { en = "GARAGE", ar = "كراج" },
		tabs = TABS,
		tab = function()
			return tab
		end,
		views = function()
			local out: { Types.ViewDef } = {}
			local list = views()
			if #list > 1 then
				for _, v in list do
					table.insert(out, { id = v.id, label = v.label })
				end
			end
			return out
		end,
		view = function()
			return currentView().id
		end,
		extra = function()
			return if tab == "exhaust" then "rev" elseif tab == "plates" then "shop" else nil
		end,
		note = noteText,
		entries = entries,
		stateOf = stateOf,
		foot = foot,
		carName = function()
			return carName(carId)
		end,
		carDrive = function()
			return carLayout()
		end,
		act = {
			tab = chooseTab,
			view = chooseView,
			entry = tapEntry,
			action = doAction,
			extra = doExtra,
			leave = function()
				if not sheet then
					GarageView.leave()
				end
			end,
			nextLayout = nextLayout,
			collapse = function()
				setCollapsed(not collapsed)
			end,
		},
		tap = function(target: GuiObject, scroll: ScrollingFrame?, onTap: () -> (), onDown: ((boolean) -> ())?)
			table.insert(taps, { gui = target, scroll = scroll, onTap = onTap, onDown = onDown })
		end,
		busy = function()
			return sheet ~= nil
		end,
	}
end

-- The chosen layout, built again (entering, a layout switch, a new screen
-- size, Studio's phone mode). Its pieces slide in, unless `still` (a new
-- screen size: the frame was up already).
buildView = function(snap: boolean, still: boolean?)
	local g = gui
	if not g or not inside then
		return
	end
	closeSheet()
	local old = view
	view = nil
	if old then
		old.destroy()
	end
	table.clear(taps)
	press = nil
	touch = UIKit.isTouch()
	-- The cash first: a layout lines its right side up under it.
	local oldCash = cashGui
	if oldCash then
		oldCash:Destroy()
	end
	-- Over the panel's gui: FRAME's right-hand shade runs up through the
	-- corner and would dim it.
	local cg, cp = Parts.hudCash("GarageCash", DISPLAY_ORDER + 1, player:WaitForChild("PlayerGui"))
	cashGui, cashPill = cg, cp
	local ctx = makeCtx(g)
	-- Under a simulated screen (Parts.screen) the coins are not where the
	-- layout is.
	ctx.coins = if Parts.screen(g) == g.AbsoluteSize then Parts.coinAnchor(g, cg) else nil
	ctxNow = ctx
	local l = layout()
	local v = l.build(g, ctx)
	view = v
	viewRoot = v.root
	collapsed = false
	local r = restore
	if r then
		r.Visible = false
	end
	GarageView.setPanelOpen(true)
	GarageView.setPanelOffset(GarageConfig.layoutOffset[l.id] or GarageConfig.screenOffset, snap)
	cashShown, cashTarget = nil, nil
	fillTab()
	refresh()
	if SpawnMenu.isOpen() then
		-- Built again under the menu (a layout picked in its SETTINGS): it
		-- stays hidden until the menu hands the screen back.
		v.root.Visible = false
		cg.Enabled = false
	else
		v.intro(still == true)
	end
end

------------------------------------------------------------------------
-- Build and tear down.
------------------------------------------------------------------------

local function buildGui(): ScreenGui
	local g = Instance.new("ScreenGui")
	g.Name = "GaragePanel"
	g.ResetOnSpawn = false
	-- Not IgnoreGuiInset: the panel runs under Roblox's top bar, never
	-- beneath its buttons (a layout's shade alone bleeds up under it).
	g.IgnoreGuiInset = false
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = DISPLAY_ORDER
	g.Parent = player:WaitForChild("PlayerGui")
	-- The fold's way back: a pill at the left edge, mid height.
	local r = Parts.square(g, "Restore", 36, 64, nil, "›", nil)
	r.AnchorPoint = Vector2.new(0, 0.5)
	r.Position = UDim2.new(0, 8, 0.5, 0)
	r.BackgroundColor3 = Color3.fromHex("#18191C")
	r.BackgroundTransparency = 0.1
	r.Visible = false
	r.ZIndex = 5
	r.Activated:Connect(function()
		setCollapsed(false)
	end)
	restore = r
	toastFn = nil
	return g
end

local function teardown()
	closeSheet()
	local v = view
	view = nil
	if v then
		v.destroy()
	end
	local g = gui
	gui = nil
	if g then
		g:Destroy()
	end
	local cg = cashGui
	cashGui, cashPill = nil, nil
	if cg then
		cg:Destroy()
	end
	viewRoot, restore, toastFn, ctxNow = nil, nil, nil, nil
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
	-- The spawn menu can be open over the view (it reopens on stepping out
	-- of a car); the panel takes the screen.
	SpawnMenu.close()
	SpawnMenu.setOpenButtonHidden(true)
	modalBefore = UserInputService.ModalEnabled
	if UIKit.isTouch() then
		-- Roblox's own touch controls draw over any PlayerGui.
		UserInputService.ModalEnabled = true
	end
	local g = buildGui()
	gui = g
	buildView(true)
	local ctx = ctxNow
	if ctx then
		toastFn = Parts.toast(g, ctx)
	end
	-- A new screen size or Studio's phone mode lays it out again.
	g:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if gui == g then
			buildView(false, true)
		end
	end)
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
-- Tap tracking for items.
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
		if not inside or not view then
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
	-- This panel has its own EXIT.
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
	-- Studio's phone mode (and its simulated screen) lays the panel out
	-- again.
	for _, name in { "ForceTouch", "ScreenSim" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if inside then
				buildView(false, true)
			end
		end)
	end
	-- A layout picked here, in the menu or in Settings: every screen
	-- follows it.
	player:GetAttributeChangedSignal(Layouts.ATTRIBUTE):Connect(function()
		if inside then
			buildView(false)
		end
	end)
	-- The menu over the garage (SHOP PLATES, M): the panel and its coins
	-- hide under it, so the two frames never show at once, and come back
	-- in place as it goes.
	SpawnMenu.watch(function(open: boolean)
		if not inside then
			return
		end
		local root, cg = viewRoot, cashGui
		if root then
			root.Visible = not open and not collapsed
		end
		if cg then
			cg.Enabled = not open
		end
		local v = view
		if not open and v and not collapsed then
			v.intro(true)
		end
	end)
end

return GaragePanel
