--!strict
-- SHOWROOM: the car picker's two panels (the owner's favourite of its
-- looks), the menu's CARS and PLATES (2026-10-12; of PICKER, SHOWROOM and
-- FRAME tried, "lets go with showroom for the cars menu"). On the left the
-- subject: its name, chip and star over it, on a lit stage (the page draws
-- the car with its stats, or the plate), IN USE when you are in the car,
-- and the action (SPAWN, BUY). On the right the page: its title or the
-- CARS | PLATES switch, the sub-tabs with a search beside them, its form
-- (the plates' field) and its items: the picker's wide cards for cars, the
-- blocks for plates.
--
-- Its versions (CarsLayouts, cycled by the header's temporary LAYOUT
-- button): the way to PLATES and SETTINGS is a rail of icons left of the
-- panels or a CARS | PLATES switch in the header (`nav`); CUSTOMIZE is a
-- pill on the stage or a button beside the action (`customize`).
local Client = script.Parent.Parent.Parent
local Kit = require(Client:WaitForChild("CarPicker"):WaitForChild("Kit"))
local CarArt = require(Client:WaitForChild("CarPicker"):WaitForChild("Art"))
local Looks = Client:WaitForChild("Garage"):WaitForChild("Looks")
local Types = require(Looks:WaitForChild("Types"))
local Parts = require(Looks:WaitForChild("Parts"))

local Showroom = {}

export type Nav = "rail" | "segment"
export type Customize = "stage" | "button"
export type Options = { nav: Nav, customize: Customize }

local function tabOf(ctx: Types.Ctx, id: string): Types.TabDef?
	for _, t in ctx.tabs do
		if t.id == id then
			return t
		end
	end
	return nil
end

-- A CUSTOMIZE: the garage's icon in green and the word.
local function customizeInner(parent: GuiObject, size: number, iconSize: number)
	local row = Kit.frame(parent, "Row")
	row.Size = UDim2.fromScale(1, 1)
	row.ZIndex = parent.ZIndex + 1
	local l = Kit.list(row, false, 6, Enum.VerticalAlignment.Center)
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local icon = Parts.icon(row, Parts.TOPBAR_ICON.garage, iconSize, Kit.C.green, Parts.TOPBAR_ICONS)
	icon.ZIndex = row.ZIndex
	local t = Kit.text(row, "Label", "CUSTOMIZE", size, Enum.FontWeight.ExtraBold, true)
	t.LayoutOrder = 1
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.fromScale(0, 1)
	t.TextTruncate = Enum.TextTruncate.None
	t.ZIndex = row.ZIndex
end

function Showroom.build(gui: ScreenGui, ctx: Types.Ctx, options: Options?): Types.View
	local opts: Options = options or { nav = "segment", customize = "stage" }
	local touch = ctx.touch
	local root, room = Parts.root(gui, ctx, "Showroom")
	local scale = Parts.scaleFor(touch, ctx.screen)
	local w = if touch then math.min(748, room.X - 16) else math.min(1060, room.X - 40)
	local h = if touch then room.Y - 16 else math.min(604, room.Y - 24)
	local gap = if touch then 8 else 10
	local rail = opts.nav == "rail"
	local railW = if rail then (if touch then 58 else 72) else 0
	local leftW = if touch then (if rail then 232 else 262) else (if rail then 330 else 360)
	local x0 = math.floor((room.X - w) / 2)
	local y0 = if touch then 8 else 12
	local pad = if touch then 10 else 16
	local actionH = if touch then 44 else 52

	------------------------------------------------------------------
	-- The rail: the pages as icons over words, CLOSE at its foot.
	local railFrame: Frame? = nil
	type RailItem = { b: TextButton, bar: Frame, icon: ImageLabel, word: TextLabel }
	local railItems: { [string]: RailItem } = {}
	if rail then
		local rf, rb = Kit.panel(root, "Rail", if touch then 14 else 16)
		rf.Position = UDim2.fromOffset(x0, y0)
		rf.Size = UDim2.fromOffset(railW, h)
		Kit.pad(rb, 8, 0, 8, 0)
		Kit.list(rb, true, 2)
		local itemH = if touch then 54 else 64
		for i, d in ctx.tabs do
			local b = Instance.new("TextButton")
			b.Name = "Tab_" .. d.id
			b.LayoutOrder = i
			b.AutoButtonColor = false
			b.BackgroundColor3 = Kit.C.green
			b.BackgroundTransparency = 1
			b.BorderSizePixel = 0
			b.Text = ""
			b.Size = UDim2.new(1, 0, 0, itemH)
			local bar = Kit.frame(b, "Bar", Kit.C.green, 0)
			bar.Position = UDim2.fromOffset(0, 10)
			bar.Size = UDim2.new(0, 3, 1, -20)
			bar.Visible = false
			Kit.corner(bar, 2)
			-- The sheets' drawings fill three fifths of a cell, so a cell
			-- this big reads as a 20 px icon.
			local icon = Parts.icon(b, d.icon, if touch then 34 else 40, Kit.C.tabInk, d.sheet)
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Position = UDim2.fromScale(0.5, 0.38)
			local word = Kit.text(b, "Word", d.label, if touch then 8 else 9, Enum.FontWeight.ExtraBold, true, Kit.C.tabInk)
			word.AnchorPoint = Vector2.new(0.5, 0.5)
			word.Position = UDim2.fromScale(0.5, 0.74)
			word.Size = UDim2.new(1, -2, 0, 12)
			word.TextXAlignment = Enum.TextXAlignment.Center
			word.TextTruncate = Enum.TextTruncate.None
			b.Activated:Connect(function()
				if not ctx.busy() then
					ctx.act.tab(d.id)
				end
			end)
			b.Parent = rb
			railItems[d.id] = { b = b, bar = bar, icon = icon, word = word }
		end
		local spacer = Kit.frame(rb, "Spacer")
		spacer.LayoutOrder = 8
		spacer.Size = UDim2.fromOffset(0, 1)
		Kit.fill(spacer)
		local line = Kit.frame(rb, "Line", Color3.new(1, 1, 1), 0.92)
		line.LayoutOrder = 9
		line.Size = UDim2.new(1, -24, 0, 1)
		line.Position = UDim2.fromOffset(12, 0)
		local close = Instance.new("TextButton")
		close.Name = "Close"
		close.LayoutOrder = 10
		close.AutoButtonColor = false
		close.BackgroundTransparency = 1
		close.Text = ""
		close.Size = UDim2.new(1, 0, 0, if touch then 50 else 58)
		local x = Kit.text(close, "Cross", "×", if touch then 22 else 26, Enum.FontWeight.Bold, false)
		x.AnchorPoint = Vector2.new(0.5, 0.5)
		x.Position = UDim2.fromScale(0.5, 0.36)
		x.Size = UDim2.new(1, 0, 0, 24)
		x.TextXAlignment = Enum.TextXAlignment.Center
		local cw = Kit.text(close, "Word", "CLOSE", if touch then 8 else 9, Enum.FontWeight.ExtraBold, true, Kit.C.tabInk)
		cw.AnchorPoint = Vector2.new(0.5, 0.5)
		cw.Position = UDim2.fromScale(0.5, 0.74)
		cw.Size = UDim2.new(1, -2, 0, 12)
		cw.TextXAlignment = Enum.TextXAlignment.Center
		close.Activated:Connect(function()
			if not ctx.busy() then
				ctx.act.leave()
			end
		end)
		close.Parent = rb
		railFrame = rf
	end
	local px = x0 + (if rail then railW + gap else 0)

	------------------------------------------------------------------
	-- The subject.
	local leftFrame, left = Kit.panel(root, "Picked", if touch then 14 else 16)
	leftFrame.Position = UDim2.fromOffset(px, y0)
	leftFrame.Size = UDim2.fromOffset(leftW, h)
	Kit.pad(left, pad, pad, pad, pad)
	Kit.list(left, true, if touch then 8 else 12)

	local head = Kit.frame(left, "Head")
	head.LayoutOrder = 1
	head.Size = UDim2.new(1, 0, 0, if touch then 32 else 36)
	Kit.list(head, false, 8, Enum.VerticalAlignment.Center)
	local name = Kit.text(head, "Name", "", if touch then 17 else 22, Enum.FontWeight.Heavy, true)
	name.LayoutOrder = 1
	name.Size = UDim2.fromScale(0, 1)
	Kit.fill(name)
	local chipHolder = Kit.frame(head, "Drive")
	chipHolder.LayoutOrder = 2
	chipHolder.AutomaticSize = Enum.AutomaticSize.X
	chipHolder.Size = UDim2.fromOffset(0, if touch then 19 else 22)
	local chip: Frame? = nil
	local chipText = ""
	local star = Kit.iconButton(head, "Fav", CarArt.starLine, if touch then 32 else 36)
	star.LayoutOrder = 3
	star.Activated:Connect(function()
		local fn = ctx.act.star
		if fn and not ctx.busy() then
			fn()
		end
	end)
	local starIcon = star:FindFirstChild("Icon") :: ImageLabel

	-- The stage: the page draws the subject in it (Cars.stage, Plates.stage);
	-- the IN USE tag over its top left, CUSTOMIZE over its bottom right.
	local stage = Kit.frame(left, "Stage")
	stage.LayoutOrder = 2
	stage.Size = UDim2.fromScale(1, 0)
	Kit.fill(stage)
	local inUse = Kit.inUse(stage, if touch then 18 else 22, if touch then 9 else 11)
	inUse.Position = UDim2.fromOffset(6, 6)
	inUse.ZIndex = 5
	inUse.Visible = false
	local customize: GuiButton? = nil
	if opts.customize == "stage" then
		local pill = Instance.new("TextButton")
		pill.Name = "Customize"
		pill.AutoButtonColor = false
		pill.Text = ""
		pill.BorderSizePixel = 0
		pill.BackgroundColor3 = Kit.C.chip
		pill.BackgroundTransparency = 0.14
		pill.AnchorPoint = Vector2.new(1, 1)
		pill.Position = UDim2.new(1, -6, 1, -(if touch then 58 else 68))
		pill.Size = UDim2.fromOffset(if touch then 108 else 128, if touch then 26 else 30)
		pill.ZIndex = 5
		Kit.corner(pill, if touch then 13 else 15)
		Kit.stroke(pill, Kit.C.green, 1, 0.3)
		customizeInner(pill, if touch then 9 else 11, if touch then 22 else 26)
		pill.Parent = stage
		customize = pill
	end

	-- The action, and beside it CUSTOMIZE as a button.
	local foot = Kit.frame(left, "Foot")
	foot.LayoutOrder = 3
	foot.Size = UDim2.new(1, 0, 0, actionH)
	Kit.list(foot, false, 6, Enum.VerticalAlignment.Center)
	local innerW = leftW - 2 * pad
	local actionW = innerW
	if opts.customize == "button" then
		local bw = if touch then 92 else 112
		actionW = innerW - bw - 6
		local b = Instance.new("ImageButton")
		b.Name = "Customize"
		b.LayoutOrder = 1
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.Image = CarArt.button
		b.ScaleType = Enum.ScaleType.Slice
		b.SliceCenter = CarArt.buttonSlice
		b.SliceScale = actionH / CarArt.buttonH
		b.ImageColor3 = Parts.C.graphite
		b.Size = UDim2.fromOffset(bw, actionH)
		customizeInner(b, if touch then 9 else 11, if touch then 22 else 26)
		b.Parent = foot
		customize = b
	end
	local beside = opts.customize == "button"
	local action = Parts.action(foot, ctx, actionW, actionH, if touch then (if beside then 12 else 15) else (if beside then 16 else 19))
	action.root.LayoutOrder = 2
	local c = customize
	if c then
		c.Visible = ctx.act.customize ~= nil
		c.Activated:Connect(function()
			local fn = ctx.act.customize
			if fn and not ctx.busy() then
				fn()
			end
		end)
	end

	------------------------------------------------------------------
	-- The page.
	local rightX = px + leftW + gap
	local rightW = x0 + w - rightX
	local rightFrame, right = Kit.panel(root, "Cars", if touch then 14 else 16)
	rightFrame.Position = UDim2.fromOffset(rightX, y0)
	rightFrame.Size = UDim2.fromOffset(rightW, h)
	if touch then
		Kit.pad(right, 10, 12, 10, 12)
	else
		Kit.pad(right, 16, 16, 16, 16)
	end
	Kit.list(right, true, if touch then 8 else 12)
	local inner = rightW - (if touch then 24 else 32)

	local headH = if touch then 36 else 44
	local header = Kit.frame(right, "Header")
	header.LayoutOrder = 1
	header.Size = UDim2.new(1, 0, 0, headH)
	Kit.list(header, false, 8, Enum.VerticalAlignment.Center)
	-- The title (the rail says where you are) or the CARS | PLATES switch.
	local titleHolder = Kit.frame(header, "TitleHolder")
	titleHolder.LayoutOrder = 1
	titleHolder.AutomaticSize = Enum.AutomaticSize.X
	titleHolder.Size = UDim2.fromOffset(0, headH)
	local title: Frame? = nil
	type Half = { b: TextButton, word: TextLabel, ar: TextLabel }
	local halves: { [string]: Half } = {}
	if not rail then
		local track = Kit.frame(titleHolder, "Switch", Color3.new(0, 0, 0), 0.55)
		track.AutomaticSize = Enum.AutomaticSize.X
		track.Size = UDim2.fromOffset(0, if touch then 34 else 40)
		track.AnchorPoint = Vector2.new(0, 0.5)
		track.Position = UDim2.fromScale(0, 0.5)
		Kit.corner(track, 10)
		Kit.stroke(track, Color3.new(1, 1, 1), 1, 0.92)
		Kit.pad(track, 3, 3, 3, 3)
		Kit.list(track, false, 2, Enum.VerticalAlignment.Center)
		for i, id in { "cars", "plates" } do
			local d = tabOf(ctx, id)
			if d then
				local b = Instance.new("TextButton")
				b.Name = "Half_" .. id
				b.LayoutOrder = i
				b.AutoButtonColor = false
				b.BorderSizePixel = 0
				b.Text = ""
				b.BackgroundColor3 = Color3.new(1, 1, 1)
				b.BackgroundTransparency = 1
				b.AutomaticSize = Enum.AutomaticSize.X
				b.Size = UDim2.fromScale(0, 1)
				Kit.corner(b, 8)
				Kit.pad(b, 0, if touch then 12 else 14, 0, if touch then 12 else 14)
				Kit.list(b, false, 6, Enum.VerticalAlignment.Center)
				local word = Kit.text(b, "Word", d.label, if touch then 14 else 17, Enum.FontWeight.Heavy, true)
				word.AutomaticSize = Enum.AutomaticSize.X
				word.Size = UDim2.fromScale(0, 1)
				word.TextTruncate = Enum.TextTruncate.None
				local ar = Kit.text(b, "Arabic", d.arabic, Parts.arabicSize(if touch then 11 else 13), Enum.FontWeight.Bold, false, Parts.C.sand)
				ar.LayoutOrder = 1
				ar.AutomaticSize = Enum.AutomaticSize.X
				ar.Size = UDim2.fromScale(0, 1)
				ar.TextTruncate = Enum.TextTruncate.None
				b.Activated:Connect(function()
					if not ctx.busy() then
						ctx.act.tab(id)
					end
				end)
				b.Parent = track
				halves[id] = { b = b, word = word, ar = ar }
			end
		end
	end
	local spacer = Kit.frame(header, "Spacer")
	spacer.LayoutOrder = 2
	spacer.Size = UDim2.fromOffset(0, 1)
	Kit.fill(spacer)
	local count = Kit.text(header, "Count", "", if touch then 11 else 13, Enum.FontWeight.SemiBold, false, Kit.C.sub)
	count.LayoutOrder = 3
	count.AutomaticSize = Enum.AutomaticSize.X
	count.Size = UDim2.fromScale(0, 1)
	count.TextTruncate = Enum.TextTruncate.None
	-- Temporary: the next version (CarsLayouts).
	local switch = Kit.iconButton(header, "Layout", CarArt.layout, if touch then 32 else 36)
	switch.LayoutOrder = 4
	switch.Activated:Connect(function()
		if not ctx.busy() then
			ctx.act.nextLayout()
		end
	end)
	if not rail then
		local close = Kit.iconButton(header, "Close", nil, if touch then 32 else 36, "×")
		close.LayoutOrder = 5
		close.Activated:Connect(function()
			if not ctx.busy() then
				ctx.act.leave()
			end
		end)
	end

	local subH = if touch then 30 else 34
	local filter = Kit.frame(right, "Filter")
	filter.LayoutOrder = 2
	filter.Size = UDim2.new(1, 0, 0, subH)
	Kit.list(filter, false, 8, Enum.VerticalAlignment.Center)
	local subHolder = Kit.frame(filter, "Subs")
	subHolder.LayoutOrder = 1
	subHolder.AutomaticSize = Enum.AutomaticSize.X
	subHolder.Size = UDim2.fromOffset(0, subH)
	Kit.pad(subHolder, 0, 0, 0, 5)
	local gapF = Kit.frame(filter, "Gap")
	gapF.LayoutOrder = 2
	gapF.Size = UDim2.fromOffset(0, 1)
	Kit.fill(gapF)
	local searchHolder = Kit.frame(filter, "SearchHolder")
	searchHolder.LayoutOrder = 3
	searchHolder.Size = UDim2.new(0, if touch then 120 else 180, 1, 0)
	searchHolder.Visible = false

	local note = Parts.note(right, if touch then 10 else 12)
	note.LayoutOrder = 3

	-- The lists: the cars' cards, or the page's blocks (the plates).
	local cards = Parts.cards(right, ctx, 2, if touch then 104 else 138, if touch then 8 else 10)
	cards.root.LayoutOrder = 5
	cards.root.Size = UDim2.fromScale(1, 0)
	Kit.fill(cards.root)
	local block = math.floor((inner - Parts.LIST_PAD_X - Parts.railRoom("rail") - gap) / 2)
	local m: Parts.BoxMetrics = if touch
		then { name = 11, word = 10, swatch = 54, rows = false, inline = false, block = block, scroller = "rail", fitRows = true }
		else { name = 13, word = 11, swatch = 60, rows = false, inline = false, block = block, scroller = "rail", fitRows = true }
	local items = Parts.items(right, ctx, 2, 2, block, block, gap, m)
	items.root.LayoutOrder = 5
	items.root.Size = UDim2.fromScale(1, 0)
	Kit.fill(items.root)

	local subs: Parts.Picker? = nil
	local form: Types.Form? = nil
	local searchBox: Frame? = nil

	local function paintNav()
		local id = ctx.tab()
		for key, it in railItems do
			local on = key == id
			it.bar.Visible = on
			it.b.BackgroundTransparency = if on then 0.9 else 1
			it.icon.ImageColor3 = if on then Kit.C.text else Kit.C.tabInk
			it.word.TextColor3 = if on then Kit.C.text else Kit.C.tabInk
		end
		for key, hf in halves do
			local on = key == id
			hf.b.BackgroundTransparency = if on then 0 else 1
			local g = hf.b:FindFirstChildOfClass("UIGradient")
			if g then
				g:Destroy()
			end
			if on then
				Kit.gradient(hf.b, Kit.C.greenTop, Kit.C.greenBottom)
			end
			hf.word.TextColor3 = if on then Kit.C.inUseInk else Kit.C.tabInk
			hf.ar.TextColor3 = if on then Kit.C.inUseInk else Parts.C.sand
		end
		if rail then
			local t = title
			if t then
				t:Destroy()
			end
			local d = tabOf(ctx, id)
			title = Parts.title(titleHolder, if touch then 24 else 30, if d then { en = d.label, ar = d.arabic } else ctx.title)
		end
	end

	local function fill()
		local s, f, sb = subs, form, searchBox
		if s then
			s.root:Destroy()
		end
		if f then
			f.root:Destroy()
		end
		if sb then
			sb:Destroy()
		end
		subs, form, searchBox = nil, nil, nil
		paintNav()
		local defs = ctx.views()
		if #defs > 1 then
			subs = Parts.slants(subHolder, ctx, defs, subH, if touch then 10 else 13, if touch then 4 else 6)
		end
		local sr = ctx.search
		local hasSearch = sr ~= nil and sr.has()
		searchHolder.Visible = hasSearch
		if hasSearch then
			searchBox = Parts.searchBox(searchHolder, ctx, subH, if touch then 11 else 13)
		end
		local fills = false
		local builder = if ctx.form then ctx.form() else nil
		if builder then
			local made = builder(right, inner, false, "rail")
			made.root.LayoutOrder = 4
			if made.fills then
				Kit.fill(made.root)
			end
			fills = made.fills
			form = made
		end
		local useCards = ctx.tab() == "cars"
		cards.root.Visible = useCards and not fills
		items.root.Visible = not useCards and not fills
		local entries = if fills then {} else ctx.entries()
		cards.fill(if useCards then entries else {})
		items.fill(if useCards then {} else entries)
	end

	local function refresh()
		local s = subs
		if s then
			s.set(ctx.view())
		end
		local n = ctx.note()
		note.Visible = n ~= nil
		note.Text = n or ""
		cards.refresh()
		items.refresh()
		local f = ctx.foot()
		action.set(f)
		local shown = #ctx.entries()
		local what = if ctx.tab() == "cars" then "car" else "plate"
		count.Text = shown .. " " .. what .. (if shown == 1 then "" else "s")
		name.Text = ctx.carName()
		inUse.Visible = f.label == "RESPAWN"
		local drive = ctx.carDrive()
		if drive ~= chipText then
			chipText = drive
			local old = chip
			if old then
				old:Destroy()
			end
			chip = if drive ~= "" then Kit.chip(chipHolder, drive, if touch then 19 else 22, if touch then 9 else 11) else nil
		end
		local st = ctx.starred
		local v = if st then st() else nil
		star.Visible = v ~= nil
		local fav = v == true
		starIcon.Image = if fav then CarArt.star else CarArt.starLine
		starIcon.ImageColor3 = if fav then Kit.C.green else Color3.new(1, 1, 1)
		starIcon.ImageTransparency = if fav then 0 else 0.4
		local cb = customize
		if cb then
			cb.Visible = ctx.act.customize ~= nil and ctx.tab() == "cars"
		end
	end

	local leftPieces: { GuiObject } = {}
	local rf = railFrame
	if rf then
		table.insert(leftPieces, rf)
	end
	table.insert(leftPieces, leftFrame)
	local pieces: Parts.Pieces = {
		room = room,
		scale = scale,
		left = leftPieces,
		right = { rightFrame },
		top = {},
		bottom = {},
		content = { leftFrame, rightFrame },
	}
	return {
		root = root,
		stage = stage,
		fill = fill,
		refresh = refresh,
		pop = function(key: string)
			cards.pop(key)
			items.pop(key)
		end,
		destroy = function()
			root:Destroy()
		end,
		intro = function(switch_: boolean)
			Parts.intro(pieces, switch_)
		end,
		outro = function(): number
			return Parts.outro(pieces)
		end,
	}
end

return Showroom
