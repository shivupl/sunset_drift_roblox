--!strict
-- The menu's SETTINGS: three columns on the board (Looks/Board; the
-- canvas's "B. Settings", the owner, 2026-10-12: "implement this version
-- that we had planned but remove the buttons at the bottom"). Before, the
-- settings were rows of slanted words in the frame every screen shares.
--   TIME OF DAY    down the left, Sunset and Night as art tiles (SkyConfig);
--                  the world changes at once, on this screen only, and the
--                  world behind is left unblurred so it shows.
--   HUD STYLE      the middle: the driving HUD's finishes as cards, each a
--                  mock readout in its own colours (HudLab; STYLE or U
--                  cycle it).
--   PC LAYOUT      under the cards, a PC only: the desktop HUD's layouts
--                  as rows (HudLab/Desk; K cycles it).
--   CAMERA         the right, first: the driving views as slanted choices
--                  (CameraViews; VIEW or V cycle it).
--   HUD LAYOUT     under it: the HUD's versions as rows, a word on each
--                  (HudLab; Y cycles it).
--   CLEAR UI       under them, one row that switches (ClearUi; the owner,
--                  2026-10-13): everything on the screen goes but a gear.
--   SCREEN LAYOUT  last, only where there is more than one (a PC): the
--                  garage's layout (Layouts), slanted choices.
-- The chosen tile or card is edged green with a tick; a chosen choice is
-- the green slant.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SkyConfig"))

local Client = script.Parent.Parent
local Kit = require(Client:WaitForChild("CarPicker"):WaitForChild("Kit"))
local Art = require(Client:WaitForChild("CarPicker"):WaitForChild("Art"))
local Sky = require(Client:WaitForChild("Sky"))
local HudLab = require(Client:WaitForChild("HudLab"))
local Finishes = require(Client:WaitForChild("HudLab"):WaitForChild("Finishes"))
local CameraViews = require(Client:WaitForChild("CameraViews"))
local ClearUi = require(Client:WaitForChild("ClearUi"))
local Looks = Client:WaitForChild("Garage"):WaitForChild("Looks")
local Types = require(Looks:WaitForChild("Types"))
local Parts = require(Looks:WaitForChild("Parts"))
local Layouts = require(Looks:WaitForChild("Layouts"))
local Page = require(script.Parent:WaitForChild("Page"))

local Settings = {}

type Option = { id: string, label: string, hint: string? }
type Row = {
	title: string,
	options: () -> { Option },
	current: () -> string,
	pick: (id: string) -> (),
}

local SKY: Row = {
	title = "TIME OF DAY",
	options = function()
		local out: { Option } = {}
		for _, o in SkyConfig.options do
			table.insert(out, { id = o.id, label = o.label })
		end
		return out
	end,
	current = Sky.current,
	pick = Sky.set,
}

local STYLE: Row = {
	title = "HUD STYLE",
	options = function()
		local out: { Option } = {}
		for _, s in HudLab.styles() do
			table.insert(out, { id = s.id, label = s.name })
		end
		return out
	end,
	current = HudLab.current,
	pick = HudLab.set,
}

local CAMERA: Row = {
	title = "CAMERA",
	options = function()
		local out: { Option } = {}
		for _, v in CameraViews.list() do
			table.insert(out, { id = v.id, label = v.name })
		end
		return out
	end,
	current = function()
		return CameraViews.current().id
	end,
	pick = CameraViews.set,
}

local VERSION: Row = {
	title = "HUD LAYOUT",
	options = function()
		local out: { Option } = {}
		for _, v in HudLab.versions() do
			table.insert(out, { id = v.id, label = v.name, hint = v.blurb })
		end
		return out
	end,
	current = HudLab.currentVersion,
	pick = HudLab.setVersion,
}

local DESK: Row = {
	title = "PC LAYOUT",
	options = function()
		local out: { Option } = {}
		for _, d in HudLab.desks() do
			table.insert(out, { id = d.id, label = d.name, hint = d.blurb })
		end
		return out
	end,
	current = HudLab.currentDesk,
	pick = HudLab.setDesk,
}

local SCREEN: Row = {
	title = "SCREEN LAYOUT",
	options = function()
		local out: { Option } = {}
		for _, l in Layouts.all() do
			table.insert(out, { id = l.id, label = l.name })
		end
		return out
	end,
	current = function()
		return Layouts.current().id
	end,
	pick = Layouts.set,
}

-- The sky in each tile: the band of colour the time of day has, the
-- ground dark under it (the canvas's tiles).
local function skyColours(id: string): ColorSequence
	if id == "night" then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("#04050B")),
			ColorSequenceKeypoint.new(0.5, Color3.fromHex("#101830")),
			ColorSequenceKeypoint.new(0.6, Color3.fromHex("#1E2440")),
			ColorSequenceKeypoint.new(0.62, Color3.fromHex("#121214")),
			ColorSequenceKeypoint.new(1, Color3.fromHex("#0B0B0C")),
		})
	end
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("#2B2238")),
		ColorSequenceKeypoint.new(0.4, Color3.fromHex("#8A4A3A")),
		ColorSequenceKeypoint.new(0.6, Color3.fromHex("#E89A50")),
		ColorSequenceKeypoint.new(0.62, Color3.fromHex("#2C2724")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("#1C1A19")),
	})
end

-- A cut-corner box (the blocks' shape): its fill, the room inside, and the
-- outline painted faint or thick and green.
type Box = { root: TextButton, fill: ImageLabel, content: Frame, press: UIScale, set: (on: boolean) -> () }
local function cutBox(parent: Instance, name: string): Box
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundTransparency = 1
	b.BorderSizePixel = 0
	local fill = Kit.image(b, "Fill", Art.tile)
	fill.ScaleType = Enum.ScaleType.Slice
	fill.SliceCenter = Art.tileSlice
	fill.SliceScale = 0.45
	fill.Size = UDim2.fromScale(1, 1)
	local content = Kit.frame(b, "Content")
	content.Position = UDim2.fromOffset(2, 2)
	content.Size = UDim2.new(1, -4, 1, -4)
	content.ClipsDescendants = true
	content.ZIndex = 2
	local edge = Kit.image(b, "Edge", Art.tileEdge)
	edge.ScaleType = Enum.ScaleType.Slice
	edge.SliceCenter = Art.tileSlice
	edge.SliceScale = 0.45
	edge.Size = UDim2.fromScale(1, 1)
	edge.ZIndex = 3
	local edgeFade = Instance.new("UIGradient")
	edgeFade.Rotation = 90
	edgeFade.Parent = edge
	local press = Instance.new("UIScale")
	press.Parent = b
	b.Parent = parent
	return {
		root = b,
		fill = fill,
		content = content,
		press = press,
		set = function(on: boolean)
			edge.Image = if on then Art.tileEdgeThick else Art.tileEdge
			if on then
				edgeFade.Color = ColorSequence.new(Kit.C.greenTop, Kit.C.greenBottom)
				edgeFade.Transparency = NumberSequence.new(0)
			else
				edgeFade.Color = ColorSequence.new(Color3.new(1, 1, 1))
				edgeFade.Transparency = NumberSequence.new(0.78, 0.94)
			end
		end,
	}
end

-- The green tick on a chosen tile.
local function tick(parent: Instance, size: number): Frame
	local c = Kit.frame(parent, "Tick", Kit.C.green, 0)
	c.AnchorPoint = Vector2.new(1, 0)
	c.Position = UDim2.new(1, -8, 0, 8)
	c.Size = UDim2.fromOffset(size, size)
	c.ZIndex = 4
	Kit.corner(c, math.floor(size / 2))
	local t = Kit.text(c, "Mark", "✓", math.floor(size * 0.68), Enum.FontWeight.Heavy, false, Kit.C.inUseInk)
	t.Size = UDim2.fromScale(1, 1)
	t.TextXAlignment = Enum.TextXAlignment.Center
	t.ZIndex = 4
	return c
end

-- A column's small title.
local function heading(parent: Instance, text: string, touch: boolean): TextLabel
	local t = Kit.text(parent, "Title", text, if touch then 10 else 12, Enum.FontWeight.ExtraBold, true, Kit.C.sub)
	t.Size = UDim2.new(1, 0, 0, if touch then 14 else 16)
	t.TextTruncate = Enum.TextTruncate.None
	return t
end

-- A small dot (a star, a lamp) in a night tile.
local function dot(parent: Instance, x: number, y: number, d: number, color: Color3, transparency: number)
	local f = Kit.frame(parent, "Dot", color, transparency)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromOffset(d, d)
	f.ZIndex = 2
	Kit.corner(f, math.ceil(d / 2))
end

function Settings.new(shell: Page.Shell): Page.Page
	-- What the last fill drew, each painting its row's state.
	local painters: { () -> () } = {}

	local function paint()
		for _, p in painters do
			p()
		end
	end

	local function choose(row: Row, id: string)
		if not shell.busy() and row.current() ~= id then
			shell.sound("tab")
			row.pick(id)
			paint()
		end
	end

	-- A box the finger presses: the menu follows the press (shell.tap).
	local function pressable(box: Box, row: Row, id: string)
		shell.tap(box.root, nil, function()
			choose(row, id)
		end, function(down: boolean)
			box.press.Scale = if down then 0.96 else 1
		end)
	end

	-- A time of day as a tile: its sky over dark ground, its name in the
	-- corner, a tick when it is the one.
	local function skyTile(parent: Instance, o: Option, order: number, touch: boolean)
		local box = cutBox(parent, "Sky_" .. o.id)
		box.root.LayoutOrder = order
		box.root.Size = UDim2.new(1, 0, 0, 0)
		Kit.fill(box.root)
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = skyColours(o.id)
		g.Parent = box.fill
		if o.id == "night" then
			dot(box.content, 0.3, 0.22, 2, Color3.new(1, 1, 1), 0.3)
			dot(box.content, 0.75, 0.16, 2, Color3.new(1, 1, 1), 0.4)
			dot(box.content, 0.52, 0.38, 2, Color3.new(1, 1, 1), 0.5)
			dot(box.content, 0.72, 0.56, 5, Parts.C.sodium, 0.45)
		end
		local label = Kit.text(box.content, "Label", o.label, if touch then 15 else 18, Enum.FontWeight.Heavy, true)
		label.AnchorPoint = Vector2.new(0, 1)
		label.Position = UDim2.new(0, 10, 1, -8)
		label.Size = UDim2.new(1, -20, 0, if touch then 20 else 24)
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextStrokeTransparency = 0.7
		label.ZIndex = 2
		local mark = tick(box.content, if touch then 18 else 22)
		pressable(box, SKY, o.id)
		table.insert(painters, function()
			local on = SKY.current() == o.id
			box.set(on)
			mark.Visible = on
		end)
	end

	-- A HUD finish as a card: a mock readout (the slide score and its
	-- multiplier, a speed dial with its needle) in the finish's colours,
	-- its name under them.
	local function styleCard(parent: Instance, o: Option, order: number, touch: boolean)
		local f = Finishes.byId[o.id] or Finishes.list[1]
		local box = cutBox(parent, "Style_" .. o.id)
		box.root.LayoutOrder = order
		box.root.Size = UDim2.new(0, 0, 1, 0)
		Kit.fill(box.root)
		Kit.gradient(box.fill, Kit.C.tileTop, Kit.C.tileBottom)
		local c = box.content
		-- The score.
		local score = Kit.frame(c, "Score")
		score.Position = UDim2.new(0, 0, 0, if touch then 16 else 22)
		score.Size = UDim2.new(1, 0, 0, if touch then 20 else 24)
		score.ZIndex = 2
		local sl = Kit.list(score, false, 3, Enum.VerticalAlignment.Bottom)
		sl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local points = Kit.text(score, "Points", "4,860", if touch then 16 else 20, Enum.FontWeight.Bold, false, f.points)
		points.FontFace = Parts.num(Enum.FontWeight.Bold)
		points.AutomaticSize = Enum.AutomaticSize.X
		points.Size = UDim2.fromScale(0, 1)
		points.TextTruncate = Enum.TextTruncate.None
		points.ZIndex = 2
		local mult = Kit.text(score, "Mult", "x1.5", if touch then 10 else 12, Enum.FontWeight.Bold, false, f.mult)
		mult.FontFace = Parts.num(Enum.FontWeight.Bold)
		mult.LayoutOrder = 1
		mult.AutomaticSize = Enum.AutomaticSize.X
		mult.Size = UDim2.new(0, 0, 1, -3)
		mult.TextTruncate = Enum.TextTruncate.None
		mult.ZIndex = 2
		-- The dial: a dark face, a ring in the print's colour, the needle
		-- low on the left in the accent, the speed over it.
		local d = if touch then 58 else 70
		local dial = Kit.frame(c, "Dial", Kit.C.panelBottom, 0)
		dial.AnchorPoint = Vector2.new(0.5, 0.5)
		dial.Position = UDim2.fromScale(0.5, 0.47)
		dial.Size = UDim2.fromOffset(d, d)
		dial.ZIndex = 2
		Kit.corner(dial, math.floor(d / 2))
		Kit.stroke(dial, f.print, 2, 0.15)
		local len = math.floor(d * 0.38)
		local ang = math.rad(240)
		local needle = Kit.frame(dial, "Needle", f.accent, 0)
		needle.AnchorPoint = Vector2.new(0.5, 0.5)
		needle.Position = UDim2.fromOffset(math.floor(d / 2 + len / 2 * math.sin(ang) + 0.5), math.floor(d / 2 - len / 2 * math.cos(ang) + 0.5))
		needle.Size = UDim2.fromOffset(2, len)
		needle.Rotation = 240
		needle.ZIndex = 3
		local speed = Kit.text(dial, "Speed", "96", if touch then 13 else 16, Enum.FontWeight.Bold, false, f.print)
		speed.FontFace = Parts.num(Enum.FontWeight.Bold)
		speed.Size = UDim2.fromScale(1, 1)
		speed.TextXAlignment = Enum.TextXAlignment.Center
		speed.ZIndex = 4
		local name = Kit.text(c, "Name", o.label, if touch then 10 else 12, Enum.FontWeight.ExtraBold, true)
		name.AnchorPoint = Vector2.new(0.5, 1)
		name.Position = UDim2.new(0.5, 0, 1, -9)
		name.Size = UDim2.new(1, -8, 0, if touch then 14 else 16)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.ZIndex = 2
		pressable(box, STYLE, o.id)
		table.insert(painters, function()
			box.set(STYLE.current() == o.id)
		end)
	end

	-- A row's choices as slanted tabs sharing the width (CAMERA, SCREEN
	-- LAYOUT).
	local function segment(parent: Instance, row: Row, order: number, width: number, touch: boolean)
		local section = Kit.frame(parent, "Segment_" .. row.title)
		section.LayoutOrder = order
		section.AutomaticSize = Enum.AutomaticSize.Y
		section.Size = UDim2.new(1, 0, 0, 0)
		Kit.list(section, true, if touch then 7 else 9)
		heading(section, row.title, touch)
		local holder = Kit.frame(section, "Choices")
		holder.LayoutOrder = 1
		holder.AutomaticSize = Enum.AutomaticSize.Y
		holder.Size = UDim2.new(1, 0, 0, 0)
		Kit.pad(holder, 0, 0, 0, 5)
		local options = row.options()
		local gap = 5
		local h = if touch then 40 else 44
		local w = math.floor((width - 5 - gap * (#options - 1)) / #options)
		local defs: { Kit.TabDef } = {}
		for _, o in options do
			table.insert(defs, { id = o.id, label = o.label, width = w })
		end
		local tabs = Kit.tabs(holder, defs, h, if touch then 11 else 13, gap, function(id: string)
			choose(row, id)
		end)
		table.insert(painters, function()
			tabs.set(row.current())
		end)
	end

	-- A row's choices as rows, each its name and a word on it (HUD
	-- LAYOUT).
	local function rows(parent: Instance, row: Row, order: number, touch: boolean)
		local section = Kit.frame(parent, "Rows_" .. row.title)
		section.LayoutOrder = order
		section.AutomaticSize = Enum.AutomaticSize.Y
		section.Size = UDim2.new(1, 0, 0, 0)
		Kit.list(section, true, if touch then 7 else 9)
		heading(section, row.title, touch)
		local holder = Kit.frame(section, "Choices")
		holder.LayoutOrder = 1
		holder.AutomaticSize = Enum.AutomaticSize.Y
		holder.Size = UDim2.new(1, 0, 0, 0)
		Kit.pad(holder, 0, 0, 0, 5)
		Kit.list(holder, true, 6)
		local h = if touch then 40 else 44
		for i, o in row.options() do
			local b = Instance.new("ImageButton")
			b.Name = "Choice_" .. o.id
			b.LayoutOrder = i
			b.AutoButtonColor = false
			b.BackgroundTransparency = 1
			b.Image = Art.tab
			b.ScaleType = Enum.ScaleType.Slice
			b.SliceCenter = Art.tabSlice
			b.SliceScale = h / Art.tabH
			b.Size = UDim2.new(1, 0, 0, h)
			local g = Kit.gradient(b, Kit.C.greenTop, Kit.C.greenBottom)
			local label = Kit.text(b, "Label", o.label, if touch then 11 else 13, Enum.FontWeight.ExtraBold, true, Kit.C.tabInk)
			label.Position = UDim2.fromOffset(14, 0)
			label.Size = UDim2.new(0.5, -14, 1, 0)
			local hint = Kit.text(b, "Hint", o.hint or "", if touch then 10 else 12, Enum.FontWeight.SemiBold, false, Kit.C.sub)
			hint.AnchorPoint = Vector2.new(1, 0)
			hint.Position = UDim2.new(1, -14, 0, 0)
			hint.Size = UDim2.new(0.5, -14, 1, 0)
			hint.TextXAlignment = Enum.TextXAlignment.Right
			local press = Instance.new("UIScale")
			press.Parent = b
			b.Parent = holder
			shell.tap(b, nil, function()
				choose(row, o.id)
			end, function(down: boolean)
				press.Scale = if down then 0.97 else 1
			end)
			table.insert(painters, function()
				local on = row.current() == o.id
				g.Enabled = on
				b.ImageColor3 = Color3.new(1, 1, 1)
				b.ImageTransparency = if on then 0 else 0.92
				label.TextColor3 = if on then Kit.C.inUseInk else Kit.C.tabInk
				hint.TextColor3 = if on then Kit.C.inUseInk else Kit.C.sub
				hint.TextTransparency = if on then 0.25 else 0
			end)
		end
	end

	-- One row that switches: green and its word when on (CLEAR UI).
	local function switchRow(parent: Instance, order: number, label: string, onWord: string, offWord: string, get: () -> boolean, set: (boolean) -> (), touch: boolean)
		local holder = Kit.frame(parent, "Switch_" .. label)
		holder.LayoutOrder = order
		holder.AutomaticSize = Enum.AutomaticSize.Y
		holder.Size = UDim2.new(1, 0, 0, 0)
		Kit.pad(holder, 0, 0, 0, 5)
		local h = if touch then 40 else 44
		local b = Instance.new("ImageButton")
		b.Name = "Choice"
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.Image = Art.tab
		b.ScaleType = Enum.ScaleType.Slice
		b.SliceCenter = Art.tabSlice
		b.SliceScale = h / Art.tabH
		b.Size = UDim2.new(1, 0, 0, h)
		local g = Kit.gradient(b, Kit.C.greenTop, Kit.C.greenBottom)
		local name = Kit.text(b, "Label", label, if touch then 11 else 13, Enum.FontWeight.ExtraBold, true, Kit.C.tabInk)
		name.Position = UDim2.fromOffset(14, 0)
		name.Size = UDim2.new(0.4, -14, 1, 0)
		local hint = Kit.text(b, "Hint", "", if touch then 10 else 12, Enum.FontWeight.SemiBold, false, Kit.C.sub)
		hint.AnchorPoint = Vector2.new(1, 0)
		hint.Position = UDim2.new(1, -14, 0, 0)
		hint.Size = UDim2.new(0.6, -14, 1, 0)
		hint.TextXAlignment = Enum.TextXAlignment.Right
		local press = Instance.new("UIScale")
		press.Parent = b
		b.Parent = holder
		shell.tap(b, nil, function()
			if not shell.busy() then
				shell.sound("tab")
				set(not get())
				paint()
			end
		end, function(down: boolean)
			press.Scale = if down then 0.97 else 1
		end)
		table.insert(painters, function()
			local on = get()
			g.Enabled = on
			b.ImageColor3 = Color3.new(1, 1, 1)
			b.ImageTransparency = if on then 0 else 0.92
			name.TextColor3 = if on then Kit.C.inUseInk else Kit.C.tabInk
			hint.Text = if on then onWord else offWord
			hint.TextColor3 = if on then Kit.C.inUseInk else Kit.C.sub
			hint.TextTransparency = if on then 0.25 else 0
		end)
	end

	local page: Page.Page
	page = {
		tab = { id = "settings", label = "SETTINGS", arabic = "إعدادات", icon = Parts.TOPBAR_ICON.settings, sheet = Parts.TOPBAR_ICONS },
		blur = 0,
		dim = 0.8,
		views = function()
			return {}
		end,
		view = function()
			return "settings"
		end,
		setView = function(_id: string) end,
		note = function()
			return nil
		end,
		entries = function()
			return {}
		end,
		stateOf = function(_e: Types.Entry): Types.EntryState
			return { chosen = false, disabled = false, word = "", kind = "none" }
		end,
		tap = function(_e: Types.Entry) end,
		-- DONE: what is picked is in force already; this is the way out
		-- where a layout with an action slot would show one (the board
		-- has none: its close is in the header).
		foot = function(): Types.Foot
			return { name = "", rare = false, note = "", action = "drive", price = 0, label = "DONE" }
		end,
		action = function()
			shell.hooks.close()
		end,
		subject = function()
			return "", ""
		end,
		starred = function()
			return nil
		end,
		star = function() end,
		form = function()
			return function(parent: Frame, width: number, _shade: boolean, _scroller: string?): Types.Form
				local touch = shell.touch()
				table.clear(painters)
				local holder = Kit.frame(parent, "Settings")
				holder.Size = UDim2.fromOffset(width, 0)
				local colGap = if touch then 14 else 18
				Kit.list(holder, false, colGap)
				local leftW = if touch then 186 else 260
				local midW = if touch then 272 else 380
				local rightW = width - leftW - midW - 2 * colGap
				local titleGap = if touch then 7 else 9

				-- TIME OF DAY: the tiles down the left.
				local left = Kit.frame(holder, "Sky")
				left.LayoutOrder = 1
				left.Size = UDim2.new(0, leftW, 1, 0)
				Kit.list(left, true, titleGap)
				heading(left, SKY.title, touch)
				local tiles = Kit.frame(left, "Tiles")
				tiles.LayoutOrder = 1
				tiles.Size = UDim2.new(1, 0, 0, 0)
				Kit.fill(tiles)
				Kit.list(tiles, true, titleGap)
				for i, o in SKY.options() do
					skyTile(tiles, o, i, touch)
				end

				-- HUD STYLE: the cards across the middle.
				local mid = Kit.frame(holder, "Style")
				mid.LayoutOrder = 2
				mid.Size = UDim2.new(0, midW, 1, 0)
				Kit.list(mid, true, titleGap)
				heading(mid, STYLE.title, touch)
				local cards = Kit.frame(mid, "Cards")
				cards.LayoutOrder = 1
				cards.Size = UDim2.new(1, 0, 0, 0)
				Kit.fill(cards)
				Kit.list(cards, false, 8)
				for i, o in STYLE.options() do
					styleCard(cards, o, i, touch)
				end
				-- PC LAYOUT under the cards, a desktop only (the cards give up
				-- the room: the right column had no more, 2026-10-14).
				if not touch then
					local gap = Kit.frame(mid, "Gap")
					gap.LayoutOrder = 2
					gap.Size = UDim2.new(1, 0, 0, colGap - titleGap)
					rows(mid, DESK, 3, touch)
				end

				-- CAMERA, HUD LAYOUT and (a PC) SCREEN LAYOUT down the right.
				local right = Kit.frame(holder, "Choices")
				right.LayoutOrder = 3
				right.Size = UDim2.new(0, rightW, 1, 0)
				Kit.list(right, true, colGap)
				segment(right, CAMERA, 1, rightW, touch)
				rows(right, VERSION, 2, touch)
				switchRow(right, 3, "CLEAR UI", "On: only the gear stays", "Everything goes but a gear", ClearUi.on, ClearUi.set, touch)
				if #SCREEN.options() > 1 then
					segment(right, SCREEN, 4, rightW, touch)
				end

				paint()
				return { root = holder, fills = true }
			end
		end,
		stage = function(frame: Frame, _touch: boolean): Page.Stage
			-- Nothing: the world itself is what these change.
			local holder = Kit.frame(frame, "Clear")
			holder.Size = UDim2.fromScale(1, 1)
			return {
				refresh = function() end,
				destroy = function()
					holder:Destroy()
				end,
			}
		end,
		paint = paint,
		shown = function() end,
	}

	-- A choice made elsewhere (U, Y, V, STYLE, VIEW, DOCK's LAYOUT button)
	-- shows here.
	Sky.changed = function()
		paint()
	end
	local player = Players.LocalPlayer
	for _, name in { "HudVariant", "HudLayout", "HudDesk", Layouts.ATTRIBUTE, CameraViews.ATTRIBUTE, ClearUi.ATTRIBUTE } do
		player:GetAttributeChangedSignal(name):Connect(paint)
	end
	return page
end

return Settings
