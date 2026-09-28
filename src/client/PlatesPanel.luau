--!strict
-- The Plates tab of the car menu (docs/superpowers/specs/2026-09-26-number-plates-design.md §5;
-- Dubai: 2026-09-27-dubai-plates-design.md).
-- SpawnMenu owns the panel and shows this in place of the car list.
--   * A KSA / DUBAI switch picks the plate style being searched.
--   * Search: letters and digits in either script. PlateText answers at
--     once here; the server is asked (PlateQuery) for the price and whether
--     the plate is free once typing pauses.
--   * A preview in the current car's rear plate format.
--   * Buy, then your plates, each with an Equip button, and the session's
--     default plate. BUY opens a confirm sheet (the plate, its price, your
--     cash, cash after, BUY / CANCEL) like the garage's; only the sheet's BUY
--     charges (UI_SYSTEM.md: nothing is ever charged from a single tap).
-- What you own comes from Player attributes set by the server (Plates,
-- PlateEquipped, PlateDefault); nothing here is trusted by the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlateText = require(Shared:WaitForChild("PlateText"))
local PlateStyles = require(Shared:WaitForChild("PlateStyles"))
local CarPlateMounts = require(Shared:WaitForChild("CarPlateMounts"))
local UITheme = require(Shared:WaitForChild("UITheme"))
local UIKit = require(script.Parent.UIKit)

-- The panel's chrome reads UITheme (UI_SYSTEM.md); re-skinned onto the
-- tokens on 2026-09-28, replacing the Theme table SpawnMenu used to pass
-- in. The plate artwork itself is PlateStyles and is not UI chrome.
local C = UITheme.color

local PlatesPanel = {}

-- Seconds typing must pause before the server is asked.
local QUERY_DELAY = 0.35
-- The confirm sheet's base ZIndex (UIKit.sheet: scrim here, the sheet at +2),
-- above SpawnMenu's panel (ZIndex 2) and everything in it.
local SHEET_Z = 10
-- A price row's height is the price text size times this (the garage
-- panel's LINE_BOX: Builder Sans' line box with room for Arabic marks).
local LINE_BOX = 1.3

local MESSAGES: { [string]: string } = {
	done = "Done",
	taken = "Someone else owns this plate",
	cash = "Not enough cash",
	unavailable = "The plate shop is unavailable right now. Nothing was charged",
	pending = "Your purchase is finishing. It will show in a moment",
	owned = "You already own this plate",
	notowned = "You don't own this plate",
	busy = "One moment…",
}

local root: Frame? = nil
local search: TextBox? = nil
local previewBox: Frame? = nil
local info: TextLabel? = nil
local buyButton: TextButton? = nil
local list: ScrollingFrame? = nil
local heading: TextLabel? = nil
local topRow: Frame? = nil
local styleRow: Frame? = nil
local queryRemote: RemoteFunction? = nil
local actionRemote: RemoteFunction? = nil
local carId: string? = nil
local current: { key: string?, price: number?, free: boolean } = { key = nil, price = nil, free = false }
local asked = 0
-- Whether the panel is laid out for touch. TRAP: it is false until the first
-- PlatesPanel.fit(), and SpawnMenu calls build() before that, so anything
-- build() sizes from it (UIKit padding, chip heights, starting text sizes)
-- gets the desktop value. fit() re-applies the text sizes; rows are rebuilt
-- by refreshOwned() after fit, so they are right. Anything new that build()
-- sizes from `touch` must be re-applied in fit() too.
local touch = false
local style = "SA" -- the style being searched (PlateText.STYLES)
local styleButtons: { [string]: TextButton } = {}
-- The open confirm sheet. Buttons under its scrim still hear clicks through
-- it (GaragePanel measured LEAVE firing through, 2026-09-28), so every button
-- here, and SpawnMenu's own, checks PlatesPanel.sheetOpen() first.
type Sheet = { frame: Frame, scrim: Frame, update: () -> () }
local sheet: Sheet? = nil

-- What each style's search box expects, as a hint, and the plate the
-- preview shows until a valid plate is typed, so picking a style shows its
-- design at once (owner, 2026-09-27).
local HINTS: { [string]: { placeholder: string, empty: string, sample: string } } = {
	SA = { placeholder = "ABJ 7   ·   حبأ ٧", empty = "Type 3 letters and a number, in Arabic or English", sample = "SA:ABJ-1234" },
	DU = { placeholder = "A 12345", empty = "Type the code (A to Z, or AA to EE) and a number of up to 5 digits", sample = "DU:A-12345" },
	AD = { placeholder = "20 10234", empty = "Type the code (1, 4 to 22, or 50), a space, then a number of up to 5 digits", sample = "AD:20-10234" },
	KW = { placeholder = "10 23456", empty = "Type the code (1 to 89), a space, then a number of up to 5 digits", sample = "KW:10-23456" },
}

local function money(n: number): string
	return (tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- A plate as a player reads it, with its country: "KSA ABJ 7", "DUBAI A 12345".
local function shown(key: string): string
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

local function format(): PlateStyles.Format
	local mounts = if carId then CarPlateMounts.cars[carId] else nil
	local rear = if mounts then mounts.rear else nil
	return if rear then rear.format else "short"
end

local function ownedKeys(): { string }
	local raw = Players.LocalPlayer:GetAttribute("Plates")
	local out: { string } = {}
	if type(raw) == "string" then
		for k in string.gmatch(raw, "[^,]+") do
			table.insert(out, k)
		end
	end
	return out
end

local function owns(key: string): boolean
	return table.find(ownedKeys(), key) ~= nil
end

local function setInfo(text: string, color: Color3)
	if info then
		(info :: TextLabel).Text = text;
		(info :: TextLabel).TextColor3 = color
	end
end

-- A token button (UIKit) sized by the caller: the panel's layout sets every
-- button's size itself, so it does not grow with its text.
local function button(parent: Instance, text: string, kind: UIKit.ButtonKind): TextButton
	local b = UIKit.button(parent, text, kind, touch)
	b.AutomaticSize = Enum.AutomaticSize.None
	return b
end

local function refreshBuy()
	local b = buyButton
	if not b then
		return
	end
	local cash = tonumber(Players.LocalPlayer:GetAttribute("Cash")) or 0
	local key, price = current.key, current.price
	local can = key ~= nil and price ~= nil and current.free and not owns(key) and cash >= price
	-- Primary when there is something to buy, disabled when not.
	UIKit.setDisabled(b, not can)
	b.Text = if price then `BUY  {money(price)}` else "BUY"
end

-- The preview: the typed plate, or with nothing valid typed, a sample of
-- the selected style (the samples match the search box's placeholder).
local function drawPreview(key: string?)
	local box = previewBox
	if box then
		PlateStyles.draw(box, key or HINTS[style].sample, format())
	end
end

local refreshOwned: () -> ()

local function doAction(what: string, key: string)
	local remote = actionRemote
	if not remote then
		return
	end
	setInfo(MESSAGES.busy, C.sand)
	-- The server normalises what it is sent as typed text, and a canonical
	-- key ("SA:ABJ-7") is not typed text (its colon is refused), so send the
	-- plate as a player would type it, with its style: "ABJ 7" in "SA"
	-- normalises back to the same key.
	local typed = if key == "" then "" else (PlateText.typed(key) or "")
	local keyStyle = if key == "" then nil else PlateText.styleOf(key)
	local ok, reply = pcall(function()
		return remote:InvokeServer(what, typed, keyStyle)
	end)
	local status = if ok and type(reply) == "table" then reply.status else "unavailable"
	if status == "invalid" then
		setInfo(reply.reason or "Not a plate", C.beacon)
	else
		setInfo(MESSAGES[status] or MESSAGES.unavailable, if status == "done" then C.paint else C.beacon)
	end
	if status == "done" or status == "taken" then
		current.free = false
	end
	refreshOwned()
	refreshBuy()
end

------------------------------------------------------------------------
-- The confirm sheet (the garage panel's, GaragePanel openSheet).
------------------------------------------------------------------------

local function sp(name: string): number
	return UITheme.px((UITheme.space :: any)[name], touch)
end

-- Closes the open sheet, or only `which` if given: a reply that comes back
-- after that sheet was closed must not close a newer one.
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

local function openSheet()
	local f = root
	local key, price = current.key, current.price
	if sheet or not f or not key or not price or not current.free or owns(key) then
		return
	end
	local g = f:FindFirstAncestorOfClass("ScreenGui")
	if not g then
		return
	end
	local frame, scrim = UIKit.sheet(g, touch, SHEET_Z)
	frame.Name = "ConfirmSheet"
	scrim.Name = "ConfirmScrim"
	scrim.Active = true
	-- Opaque, as the garage's: at alpha.panel the tab under it shows through.
	frame.BackgroundTransparency = 0
	local width = f.AbsoluteSize.X
	frame.Size = UDim2.fromOffset(width, 0)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, sp("md"))
	layout.Parent = frame

	local title = UIKit.title(frame, "BUY", "شراء", "title", touch)
	title.LayoutOrder = 1

	-- The plate itself, in the current car's rear format, the preview's size.
	local art = Instance.new("Frame")
	art.Name = "Plate"
	art.BackgroundTransparency = 1
	art.Size = UDim2.new(1, 0, 0, if previewBox then (previewBox :: Frame).AbsoluteSize.Y else UITheme.target(touch) * 2)
	art.LayoutOrder = 2
	art.Parent = frame
	PlateStyles.draw(art, key, format())

	local name = UIKit.text(frame, shown(key), "heading", "paint", touch, true)
	name.Name = "PlateName"
	name.LayoutOrder = 3
	local what = UIKit.text(frame, "Yours alone: nobody else can own it", "caption", "sandDim", touch, true)
	what.LayoutOrder = 4

	local function row(order: number, labelText: string, valueColor: UIKit.ColorName): TextLabel
		local r = Instance.new("Frame")
		r.BackgroundTransparency = 1
		r.Size = UDim2.new(1, 0, 0, math.ceil(UITheme.textSize("price", touch) * LINE_BOX))
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
	local priceValue = row(5, "Price", "sodium")
	local cashValue = row(6, "Your cash", "paint")
	local afterValue = row(7, "Cash after", "paint")
	afterValue.Name = "CashAfter"

	local short = UIKit.text(frame, "", "body", "beacon", touch, true)
	short.Name = "Short"
	short.LayoutOrder = 8

	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.BackgroundTransparency = 1
	buttons.Size = UDim2.new(1, 0, 0, UITheme.target(touch))
	buttons.LayoutOrder = 9
	local bl = Instance.new("UIListLayout")
	bl.FillDirection = Enum.FillDirection.Horizontal
	bl.SortOrder = Enum.SortOrder.LayoutOrder
	bl.Padding = UDim.new(0, sp("sm"))
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	bl.VerticalAlignment = Enum.VerticalAlignment.Center
	bl.Parent = buttons
	buttons.Parent = frame
	local cancel = button(buttons, "CANCEL", "secondary")
	cancel.Name = "Cancel"
	cancel.Size = UDim2.new(0.5, -math.floor(sp("sm") / 2), 1, 0)
	cancel.LayoutOrder = 1
	local buy = button(buttons, "BUY", "primary")
	buy.Name = "Buy"
	buy.Size = UDim2.new(0.5, -math.floor(sp("sm") / 2), 1, 0)
	buy.LayoutOrder = 2

	local working = false
	local mine: Sheet
	local function cash(): number
		return tonumber(Players.LocalPlayer:GetAttribute("Cash")) or 0
	end
	local function update()
		local have = cash()
		priceValue.Text = money(price)
		cashValue.Text = money(have)
		local lacking = price - have
		-- Short: the shortfall in beacon rather than a cash-after of 0.
		afterValue.Text = if lacking > 0 then `Short {money(lacking)}` else money(have - price)
		afterValue.TextColor3 = if lacking > 0 then C.beacon else C.paint
		short.Visible = lacking > 0
		short.Text = if lacking > 0 then "Not enough cash to buy this plate" else ""
		UIKit.setDisabled(buy, working or lacking > 0)
		UIKit.setDisabled(cancel, working)
	end

	local pad = sp("lg")
	local function fitHeight()
		frame.Size = UDim2.fromOffset(width, layout.AbsoluteContentSize.Y + 2 * pad)
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitHeight)
	fitHeight()

	cancel.Activated:Connect(function()
		if not working then
			closeSheet(mine)
		end
	end)
	buy.Activated:Connect(function()
		if working or cash() < price then
			return
		end
		working = true
		update()
		-- The one place a plate is charged; its statuses show on the tab.
		doAction("buy", key)
		working = false
		closeSheet(mine)
		refreshBuy()
	end)

	mine = { frame = frame, scrim = scrim, update = update }
	sheet = mine
	update()
end

local function onSearch()
	local box = search
	if not box then
		return
	end
	local text = box.Text
	asked += 1
	local mine = asked
	current = { key = nil, price = nil, free = false }
	refreshBuy()
	if text == "" then
		drawPreview(nil)
		setInfo(HINTS[style].empty, C.sand)
		return
	end
	local searching = style
	local key, reason = PlateText.normalise(searching, text)
	if not key then
		drawPreview(nil)
		setInfo(reason or "Not a plate", C.beacon)
		return
	end
	drawPreview(key)
	if owns(key) then
		setInfo(`{shown(key)} is yours`, C.paint)
		return
	end
	local price = PlateText.price(key) :: number
	current = { key = key, price = price, free = false }
	refreshBuy()
	setInfo(`{money(price)} cash · checking…`, C.sand)
	task.delay(QUERY_DELAY, function()
		local remote = queryRemote
		if mine ~= asked or not remote then
			return
		end
		local ok, reply = pcall(function()
			return remote:InvokeServer(text, searching)
		end)
		if mine ~= asked then
			return
		end
		if not ok or type(reply) ~= "table" then
			setInfo(MESSAGES.unavailable, C.beacon)
		elseif reply.status == "ok" then
			current = { key = reply.key, price = reply.price, free = reply.available == true }
			if current.free then
				-- A price you are about to pay: sodium (UI_SYSTEM.md "Colour").
				setInfo(`{money(reply.price)} cash · available`, C.sodium)
			else
				setInfo(MESSAGES.taken, C.beacon)
			end
		elseif reply.status == "invalid" then
			setInfo(reply.reason or "Not a plate", C.beacon)
		else
			setInfo(MESSAGES[reply.status] or MESSAGES.unavailable, C.beacon)
		end
		refreshBuy()
	end)
end

local function rowHeight(): number
	return if touch then 72 else 56
end

-- One of your plates, in the "Shop items" states of UI_SYSTEM.md: the one on
-- the car is the selected state (sodiumDim ground, sodium stroke) with an
-- ON CAR chip where its button was; a bought plate is a secondary card with a
-- gantry OWNED badge beside its EQUIP button. The session's default plate is
-- not bought, so it carries no OWNED badge.
local function row(parent: Instance, order: number, key: string, caption: string, fitted: boolean, bought: boolean, onPress: () -> ())
	local h = rowHeight()
	-- EQUIP is at least a tap target (h * 0.64 was 36 / 46).
	local pressH = math.max(math.floor(h * 0.64), UITheme.target(touch))
	local look = if fitted then UITheme.button.selected else UITheme.button.secondary
	local f = Instance.new("Frame")
	f.BackgroundColor3 = look.bg
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, 0, 0, h)
	f.LayoutOrder = order
	UIKit.corner(f, "md")
	UIKit.stroke(f, if fitted then "sodium" else "asphalt600", look.strokeThickness or UITheme.stroke.hairline)
	local mini = Instance.new("Frame")
	mini.BackgroundTransparency = 1
	mini.Position = UDim2.fromOffset(10, math.floor(h * 0.12))
	mini.Size = UDim2.fromOffset(math.floor(h * 1.9), math.floor(h * 0.76))
	mini.Parent = f
	PlateStyles.draw(mini, key, format())
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = UITheme.font("heading")
	l.TextSize = UITheme.textSize("heading", touch)
	l.TextColor3 = look.text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = caption
	l.Position = UDim2.fromOffset(math.floor(h * 1.9) + 22, 0)
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = f
	-- The right-hand end: the ON CAR chip, or EQUIP with the OWNED badge
	-- before it. The caption stops short of whichever is there.
	local tail = Instance.new("Frame")
	tail.Name = "Tail"
	tail.BackgroundTransparency = 1
	tail.AnchorPoint = Vector2.new(1, 0.5)
	tail.Position = UDim2.new(1, -10, 0.5, 0)
	tail.AutomaticSize = Enum.AutomaticSize.X
	tail.Size = UDim2.fromOffset(0, pressH)
	local tailLayout = Instance.new("UIListLayout")
	tailLayout.FillDirection = Enum.FillDirection.Horizontal
	tailLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	tailLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tailLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tailLayout.Padding = UDim.new(0, UITheme.px(UITheme.space.sm, touch))
	tailLayout.Parent = tail
	tail.Parent = f
	if fitted then
		UIKit.badge(tail, "oncar", "ON CAR", touch).LayoutOrder = 2
	else
		if bought then
			UIKit.badge(tail, "owned", "✓ OWNED", touch).LayoutOrder = 1
		end
		local b = button(tail, "EQUIP", "secondary")
		b.LayoutOrder = 2
		b.Size = UDim2.fromOffset(110, pressH)
		b.Activated:Connect(function()
			if not sheet then
				onPress()
			end
		end)
	end
	local function fitCaption()
		l.Size = UDim2.new(1, -(math.floor(h * 1.9) + 22 + 20 + tail.AbsoluteSize.X), 1, 0)
	end
	tail:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCaption)
	fitCaption()
	f.Parent = parent
end

refreshOwned = function()
	local l = list
	if not l then
		return
	end
	for _, child in l:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local player = Players.LocalPlayer
	local equipped = player:GetAttribute("PlateEquipped")
	local default = player:GetAttribute("PlateDefault")
	if type(default) == "string" then
		row(l, 0, default, `{shown(default)} · default this session`, equipped == nil, false, function()
			doAction("unequip", "")
		end)
	end
	local keys = ownedKeys()
	for i, key in keys do
		row(l, i, key, shown(key), equipped == key, true, function()
			doAction("equip", key)
		end)
	end
	if #keys == 0 then
		local hint = Instance.new("TextLabel")
		hint.BackgroundTransparency = 1
		hint.FontFace = UITheme.font("caption")
		hint.TextSize = UITheme.textSize("caption", touch)
		hint.TextColor3 = C.sandDim
		hint.Text = "Plates you buy show here"
		hint.Size = UDim2.new(1, 0, 0, 28)
		hint.LayoutOrder = 999
		hint.Parent = l
	end
end

local function paintStyles()
	-- The style being searched takes the selected state.
	for code, b in styleButtons do
		UIKit.setSelected(b, code == style)
	end
	if search then
		(search :: TextBox).PlaceholderText = HINTS[style].placeholder
	end
end

local function setStyle(code: string)
	if code == style then
		return
	end
	style = code
	paintStyles()
	onSearch()
end

function PlatesPanel.build(parent: Instance, layoutOrder: number): Frame
	local f = Instance.new("Frame")
	f.Name = "Plates"
	f.BackgroundTransparency = 1
	f.LayoutOrder = layoutOrder
	f.Visible = false
	f.Size = UDim2.new(1, 0, 0, 300)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = f

	local top = Instance.new("Frame")
	top.BackgroundTransparency = 1
	top.Name = "Search"
	top.LayoutOrder = 1
	top.Size = UDim2.new(1, 0, 0, 44)
	top.Parent = f
	topRow = top
	local box = Instance.new("TextBox")
	-- An input: asphalt800 with a hairline stroke, typed text in heading.
	box.BackgroundColor3 = C.asphalt800
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.FontFace = UITheme.font("heading")
	box.TextSize = UITheme.textSize("heading", touch)
	box.TextColor3 = C.paint
	box.PlaceholderText = "ABJ 7   ·   حبأ ٧"
	box.PlaceholderColor3 = C.sandDim
	box.Text = ""
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Size = UDim2.new(1, -170, 1, 0)
	UIKit.corner(box, "md")
	UIKit.stroke(box, "asphalt600", UITheme.stroke.hairline)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.Parent = box
	box.Parent = top
	box:GetPropertyChangedSignal("Text"):Connect(onSearch)
	-- Under the confirm sheet the box can still take a click: give it back,
	-- so the plate being bought cannot change under the sheet.
	box.Focused:Connect(function()
		if sheet then
			box:ReleaseFocus()
		end
	end)
	search = box
	-- The style switch: one button per plate style, its own row above the
	-- search (four names do not fit beside it).
	local switch = Instance.new("Frame")
	switch.Name = "Styles"
	switch.BackgroundTransparency = 1
	switch.LayoutOrder = 0
	switch.Size = UDim2.new(1, 0, 0, 30)
	local switchLayout = Instance.new("UIListLayout")
	switchLayout.FillDirection = Enum.FillDirection.Horizontal
	switchLayout.SortOrder = Enum.SortOrder.LayoutOrder
	switchLayout.Padding = UDim.new(0, 6)
	switchLayout.Parent = switch
	local count = #PlateText.STYLES
	for i, st in PlateText.STYLES do
		local sb = UIKit.chip(switch, st.name, touch)
		sb.Name = "Style" .. st.code
		sb.AutomaticSize = Enum.AutomaticSize.None
		sb.LayoutOrder = i
		sb.Size = UDim2.new(1 / count, -6 * (count - 1) / count, 1, 0)
		sb.Activated:Connect(function()
			if not sheet then
				setStyle(st.code)
			end
		end)
		styleButtons[st.code] = sb
	end
	switch.Parent = f
	styleRow = switch
	paintStyles()
	local buy = button(top, "BUY", "primary")
	buy.Name = "Buy"
	buy.AnchorPoint = Vector2.new(1, 0)
	buy.Position = UDim2.fromScale(1, 0)
	buy.Size = UDim2.new(0, 160, 1, 0)
	buy.Activated:Connect(function()
		if sheet then
			return
		end
		-- Opens the confirm sheet; nothing is charged until its BUY.
		openSheet()
	end)
	buyButton = buy

	local preview = Instance.new("Frame")
	preview.Name = "Preview"
	preview.BackgroundTransparency = 1
	preview.LayoutOrder = 2
	preview.Size = UDim2.new(1, 0, 0, 84)
	preview.Parent = f
	previewBox = preview

	local line = Instance.new("TextLabel")
	line.BackgroundTransparency = 1
	line.FontFace = UITheme.font("body")
	line.TextSize = UITheme.textSize("body", touch)
	line.TextColor3 = C.sand
	line.LayoutOrder = 3
	line.Size = UDim2.new(1, 0, 0, 20)
	line.Parent = f
	info = line

	local head = Instance.new("TextLabel")
	head.BackgroundTransparency = 1
	-- A small section label: label role in sand.
	head.FontFace = UITheme.font("label")
	head.TextSize = UITheme.textSize("label", touch)
	head.TextColor3 = C.sand
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.Text = "YOUR PLATES"
	head.LayoutOrder = 4
	head.Size = UDim2.new(1, 0, 0, 18)
	head.Parent = f
	heading = head

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = 5
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = C.asphalt500
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Size = UDim2.new(1, 0, 0, 120)
	local rows = Instance.new("UIListLayout")
	rows.SortOrder = Enum.SortOrder.LayoutOrder
	rows.Padding = UDim.new(0, 6)
	rows.Parent = scroll
	scroll.Parent = f
	list = scroll

	f.Parent = parent
	root = f
	return f
end

-- Sizes the tab to the height the menu gives it.
function PlatesPanel.fit(height: number, isTouch: boolean)
	touch = isTouch
	local f, top, preview, scroll = root, topRow, previewBox, list
	if not f or not top or not preview or not scroll or not info or not heading then
		return
	end
	local topH = if isTouch then 56 else 44
	local previewH = if isTouch then 96 else 84
	-- The style chips are tap targets: UITheme.target (they were 30 / 44).
	local switchH = UITheme.target(isTouch)
	f.Size = UDim2.new(1, 0, 0, height)
	top.Size = UDim2.new(1, 0, 0, topH)
	preview.Size = UDim2.new(1, 0, 0, previewH)
	if styleRow then
		(styleRow :: Frame).Size = UDim2.new(1, 0, 0, switchH)
	end
	local fixed = switchH + topH + previewH + 20 + 18 + 8 * 5
	scroll.Size = UDim2.new(1, 0, 0, math.max(height - fixed, rowHeight()))
	scroll.ScrollBarThickness = if isTouch then 6 else 4
	-- Text follows the type roles for this screen.
	local box = search
	if box then
		box.TextSize = UITheme.textSize("heading", isTouch)
	end
	for _, sb in styleButtons do
		sb.TextSize = UITheme.textSize("label", isTouch)
	end
	if buyButton then
		(buyButton :: TextButton).TextSize = UITheme.textSize("label", isTouch)
	end
	(info :: TextLabel).TextSize = UITheme.textSize("body", isTouch);
	(heading :: TextLabel).TextSize = UITheme.textSize("label", isTouch)
end

function PlatesPanel.setVisible(visible: boolean)
	local f = root
	if not f then
		return
	end
	f.Visible = visible
	if not visible then
		closeSheet() -- leaving the tab cancels a buy not yet confirmed
	end
	if visible then
		refreshOwned()
		onSearch()
	end
end

function PlatesPanel.setCar(id: string?)
	if id then
		carId = id
	end
	if root and (root :: Frame).Visible then
		refreshOwned()
		onSearch()
	end
end

function PlatesPanel.start(remotes: Folder)
	queryRemote = remotes:WaitForChild("PlateQuery") :: RemoteFunction
	actionRemote = remotes:WaitForChild("PlateAction") :: RemoteFunction
	local player = Players.LocalPlayer
	for _, name in { "Plates", "PlateEquipped", "PlateDefault", "Cash" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if root and (root :: Frame).Visible then
				refreshOwned()
				refreshBuy()
			end
			local s = sheet
			if s and name == "Cash" then
				s.update()
			end
		end)
	end
end

-- Whether the confirm sheet is up: SpawnMenu's own buttons ignore clicks
-- that come through its scrim.
function PlatesPanel.sheetOpen(): boolean
	return sheet ~= nil
end

-- Cancels an open confirm sheet (the menu closing).
function PlatesPanel.closeSheet()
	closeSheet()
end

return PlatesPanel
