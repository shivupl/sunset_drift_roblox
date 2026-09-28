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
--     default plate.
-- What you own comes from Player attributes set by the server (Plates,
-- PlateEquipped, PlateDefault); nothing here is trusted by the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlateText = require(Shared:WaitForChild("PlateText"))
local PlateStyles = require(Shared:WaitForChild("PlateStyles"))
local CarPlateMounts = require(Shared:WaitForChild("CarPlateMounts"))

export type Theme = { card: Color3, white: Color3, muted: Color3, hot: Color3, hotDim: Color3 }

local PlatesPanel = {}

-- Seconds typing must pause before the server is asked.
local QUERY_DELAY = 0.35

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

local theme: Theme? = nil
local root: Frame? = nil
local search: TextBox? = nil
local previewBox: Frame? = nil
local info: TextLabel? = nil
local buyButton: TextButton? = nil
local list: ScrollingFrame? = nil
local heading: TextLabel? = nil
local topRow: Frame? = nil
local queryRemote: RemoteFunction? = nil
local actionRemote: RemoteFunction? = nil
local carId: string? = nil
local current: { key: string?, price: number?, free: boolean } = { key = nil, price = nil, free = false }
local asked = 0
local touch = false
local style = "SA" -- the style being searched (PlateText.STYLES)
local styleButtons: { [string]: TextButton } = {}

-- What each style's search box expects, as a hint.
local HINTS: { [string]: { placeholder: string, empty: string } } = {
	SA = { placeholder = "ABJ 7   ·   حبأ ٧", empty = "Type 3 letters and a number, in Arabic or English" },
	DU = { placeholder = "A 12345", empty = "Type the code (A to Z, or AA to EE) and a number of up to 5 digits" },
}

local function t(): Theme
	return theme :: Theme
end

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

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function button(parent: Instance, text: string): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBlack
	b.Text = text
	b.TextSize = 16
	b.TextColor3 = Color3.fromRGB(15, 15, 18)
	b.BackgroundColor3 = t().hot
	corner(b, 8)
	b.Parent = parent
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
	b.BackgroundColor3 = if can then t().hot else t().hotDim
	b.Text = if price then `BUY  {money(price)}` else "BUY"
end

local function drawPreview(key: string?)
	local box = previewBox
	if box then
		PlateStyles.draw(box, key or (Players.LocalPlayer:GetAttribute("PlateDefault") :: string?), format())
	end
end

local refreshOwned: () -> ()

local function doAction(what: string, key: string)
	local remote = actionRemote
	if not remote then
		return
	end
	setInfo(MESSAGES.busy, t().muted)
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
		setInfo(reply.reason or "Not a plate", t().hot)
	else
		setInfo(MESSAGES[status] or MESSAGES.unavailable, if status == "done" then t().white else t().hot)
	end
	if status == "done" or status == "taken" then
		current.free = false
	end
	refreshOwned()
	refreshBuy()
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
		setInfo(HINTS[style].empty, t().muted)
		return
	end
	local searching = style
	local key, reason = PlateText.normalise(searching, text)
	if not key then
		drawPreview(nil)
		setInfo(reason or "Not a plate", t().hot)
		return
	end
	drawPreview(key)
	if owns(key) then
		setInfo(`{shown(key)} is yours`, t().white)
		return
	end
	local price = PlateText.price(key) :: number
	current = { key = key, price = price, free = false }
	refreshBuy()
	setInfo(`{money(price)} cash · checking…`, t().muted)
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
			setInfo(MESSAGES.unavailable, t().hot)
		elseif reply.status == "ok" then
			current = { key = reply.key, price = reply.price, free = reply.available == true }
			if current.free then
				setInfo(`{money(reply.price)} cash · available`, t().white)
			else
				setInfo(MESSAGES.taken, t().hot)
			end
		elseif reply.status == "invalid" then
			setInfo(reply.reason or "Not a plate", t().hot)
		else
			setInfo(MESSAGES[reply.status] or MESSAGES.unavailable, t().hot)
		end
		refreshBuy()
	end)
end

local function rowHeight(): number
	return if touch then 72 else 56
end

local function row(parent: Instance, order: number, key: string, caption: string, fitted: boolean, onPress: () -> ())
	local h = rowHeight()
	local f = Instance.new("Frame")
	f.BackgroundColor3 = t().card
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, 0, 0, h)
	f.LayoutOrder = order
	corner(f, 10)
	local mini = Instance.new("Frame")
	mini.BackgroundTransparency = 1
	mini.Position = UDim2.fromOffset(10, math.floor(h * 0.12))
	mini.Size = UDim2.fromOffset(math.floor(h * 1.9), math.floor(h * 0.76))
	mini.Parent = f
	PlateStyles.draw(mini, key, format())
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = if touch then 18 else 15
	l.TextColor3 = t().white
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = caption
	l.Position = UDim2.fromOffset(math.floor(h * 1.9) + 22, 0)
	l.Size = UDim2.new(1, -(math.floor(h * 1.9) + 22 + 130), 1, 0)
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = f
	local b = button(f, if fitted then "FITTED" else "EQUIP")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -10, 0.5, 0)
	b.Size = UDim2.fromOffset(110, math.floor(h * 0.64))
	if fitted then
		b.BackgroundColor3 = t().hotDim
	end
	b.Activated:Connect(function()
		if not fitted then
			onPress()
		end
	end)
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
		row(l, 0, default, `{shown(default)} · default this session`, equipped == nil, function()
			doAction("unequip", "")
		end)
	end
	local keys = ownedKeys()
	for i, key in keys do
		row(l, i, key, shown(key), equipped == key, function()
			doAction("equip", key)
		end)
	end
	if #keys == 0 then
		local hint = Instance.new("TextLabel")
		hint.BackgroundTransparency = 1
		hint.Font = Enum.Font.GothamMedium
		hint.TextSize = 14
		hint.TextColor3 = t().muted
		hint.Text = "Plates you buy show here"
		hint.Size = UDim2.new(1, 0, 0, 28)
		hint.LayoutOrder = 999
		hint.Parent = l
	end
end

local function paintStyles()
	for code, b in styleButtons do
		local on = code == style
		b.BackgroundColor3 = if on then t().hot else t().card
		b.TextColor3 = if on then Color3.fromRGB(15, 15, 18) else t().muted
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

-- Width of the style switch at the left of the search row.
local SWITCH_W = 150

function PlatesPanel.build(parent: Instance, th: Theme, layoutOrder: number): Frame
	theme = th
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
	top.LayoutOrder = 1
	top.Size = UDim2.new(1, 0, 0, 44)
	top.Parent = f
	topRow = top
	local box = Instance.new("TextBox")
	box.BackgroundColor3 = th.card
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.GothamBold
	box.TextSize = 20
	box.TextColor3 = th.white
	box.PlaceholderText = "ABJ 7   ·   حبأ ٧"
	box.PlaceholderColor3 = th.muted
	box.Text = ""
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Position = UDim2.fromOffset(SWITCH_W + 8, 0)
	box.Size = UDim2.new(1, -(SWITCH_W + 8 + 170), 1, 0)
	corner(box, 8)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.Parent = box
	box.Parent = top
	box:GetPropertyChangedSignal("Text"):Connect(onSearch)
	search = box
	for i, st in PlateText.STYLES do
		local sb = button(top, st.name)
		sb.Name = "Style" .. st.code
		sb.TextSize = 13
		sb.Position = UDim2.fromOffset((i - 1) * (SWITCH_W / #PlateText.STYLES), 0)
		sb.Size = UDim2.new(0, SWITCH_W / #PlateText.STYLES - 4, 1, 0)
		sb.Activated:Connect(function()
			setStyle(st.code)
		end)
		styleButtons[st.code] = sb
	end
	paintStyles()
	local buy = button(top, "BUY")
	buy.AnchorPoint = Vector2.new(1, 0)
	buy.Position = UDim2.fromScale(1, 0)
	buy.Size = UDim2.new(0, 160, 1, 0)
	buy.Activated:Connect(function()
		local key = current.key
		if key and current.free then
			doAction("buy", key)
		end
	end)
	buyButton = buy

	local preview = Instance.new("Frame")
	preview.BackgroundTransparency = 1
	preview.LayoutOrder = 2
	preview.Size = UDim2.new(1, 0, 0, 84)
	preview.Parent = f
	previewBox = preview

	local line = Instance.new("TextLabel")
	line.BackgroundTransparency = 1
	line.Font = Enum.Font.GothamMedium
	line.TextSize = 14
	line.TextColor3 = th.muted
	line.LayoutOrder = 3
	line.Size = UDim2.new(1, 0, 0, 20)
	line.Parent = f
	info = line

	local head = Instance.new("TextLabel")
	head.BackgroundTransparency = 1
	head.Font = Enum.Font.GothamBlack
	head.TextSize = 14
	head.TextColor3 = th.muted
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
	scroll.ScrollBarImageColor3 = th.muted
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
	f.Size = UDim2.new(1, 0, 0, height)
	top.Size = UDim2.new(1, 0, 0, topH)
	preview.Size = UDim2.new(1, 0, 0, previewH)
	local fixed = topH + previewH + 20 + 18 + 8 * 4
	scroll.Size = UDim2.new(1, 0, 0, math.max(height - fixed, rowHeight()))
	scroll.ScrollBarThickness = if isTouch then 6 else 4
end

function PlatesPanel.setVisible(visible: boolean)
	local f = root
	if not f then
		return
	end
	f.Visible = visible
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
		end)
	end
end

return PlatesPanel
