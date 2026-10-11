--!strict
-- Pieces every car picker layout uses: which cars show, the boxes in a
-- scrolling grid or row, the header buttons, the tabs, the stat bars, and
-- the scale for this screen.
local Kit = require(script.Parent:WaitForChild("Kit"))
local Types = require(script.Parent:WaitForChild("Types"))
local Art = require(script.Parent:WaitForChild("Art"))

local Common = {}

-- The screens the mockups were drawn for, less Roblox's top bar.
Common.REF_PC = Vector2.new(1280, 664)
Common.REF_PHONE = Vector2.new(844, 346)

-- The scale that fits a layout drawn for `ref` on this screen, and the room
-- it then has in drawing pixels.
function Common.fit(ctx: Types.Ctx, root: GuiObject): (number, Vector2)
	local ref = if ctx.touch then Common.REF_PHONE else Common.REF_PC
	local s = math.clamp(math.min(ctx.screen.X / ref.X, ctx.screen.Y / ref.Y), 0.7, 1.35)
	local scale = Instance.new("UIScale")
	scale.Scale = s
	scale.Parent = root
	return s, ctx.screen / s
end

function Common.visible(ctx: Types.Ctx, car: Kit.Car): boolean
	local st = ctx.state
	local f = st.filter
	if f == "fav" then
		if not st.favs[car.id] then
			return false
		end
	elseif f ~= "all" and string.lower(car.drive) ~= f then
		return false
	end
	local q = string.lower(st.query)
	return q == "" or string.find(string.lower(car.name), q, 1, true) ~= nil
end

function Common.find(ctx: Types.Ctx, id: string): Kit.Car
	for _, c in ctx.cars do
		if c.id == id then
			return c
		end
	end
	return ctx.cars[1]
end

-- The box sizes, PC and phone (the mockups': 138 and 104 tall).
function Common.tileMetrics(touch: boolean): Kit.TileMetrics
	if touch then
		return { name = 12, chipH = 17, chipText = 9, starBox = 30, star = 16, imageTop = 16, imageBottom = 14, ring = 112, ringInset = 26 }
	end
	return { name = 14, chipH = 20, chipText = 10, starBox = 34, star = 19, imageTop = 20, imageBottom = 18, ring = 150, ringInset = 30 }
end

------------------------------------------------------------------------

export type Grid = { root: Frame, refresh: () -> () }

-- The boxes in a scrolling grid (cols across, scrolling down) or, with
-- `rowWidth`, in one row scrolling sideways.
function Common.grid(parent: Instance, ctx: Types.Ctx, cols: number, cellH: number, gap: number, rowWidth: number?): Grid
	local holder = Kit.frame(parent, "Cars")
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.ScrollBarThickness = if ctx.touch then 5 else 4
	scroll.ScrollBarImageColor3 = Color3.new(1, 1, 1)
	scroll.ScrollBarImageTransparency = 0.8
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = holder
	local m = Common.tileMetrics(ctx.touch)
	if rowWidth then
		scroll.ScrollingDirection = Enum.ScrollingDirection.X
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.X
		scroll.ElasticBehavior = Enum.ElasticBehavior.Always
		Kit.pad(scroll, 2, 2, 8, 2)
		Kit.list(scroll, false, gap)
	else
		scroll.ScrollingDirection = Enum.ScrollingDirection.Y
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		Kit.pad(scroll, 2, 7, 4, 2)
		local g = Instance.new("UIGridLayout")
		g.SortOrder = Enum.SortOrder.LayoutOrder
		g.CellPadding = UDim2.fromOffset(gap, gap)
		g.CellSize = UDim2.new(1 / cols, -math.ceil(gap * (cols - 1) / cols), 0, cellH)
		g.Parent = scroll
	end
	local empty = Kit.text(holder, "Empty", "", if ctx.touch then 12 else 13, Enum.FontWeight.SemiBold, false, Kit.C.sub)
	empty.Size = UDim2.fromScale(1, 1)
	empty.TextXAlignment = Enum.TextXAlignment.Center
	empty.TextWrapped = true
	local tiles: { { car: Kit.Car, tile: Kit.Tile } } = {}
	for i, car in ctx.cars do
		local tile = Kit.tile(scroll, car, m)
		tile.root.LayoutOrder = i
		if rowWidth then
			tile.root.Size = UDim2.new(0, rowWidth, 1, 0)
		end
		ctx.taps.add(tile.star, scroll, function()
			ctx.act.fav(car.id)
		end)
		ctx.taps.add(tile.root, scroll, function()
			ctx.act.pick(car.id)
		end)
		table.insert(tiles, { car = car, tile = tile })
	end
	return {
		root = holder,
		refresh = function()
			local any = false
			for _, t in tiles do
				local show = Common.visible(ctx, t.car)
				any = any or show
				t.tile.root.Visible = show
				t.tile.setPicked(t.car.id == ctx.state.selected)
				t.tile.setFav(ctx.state.favs[t.car.id] == true)
			end
			empty.Visible = not any
			empty.Text = if ctx.state.filter == "fav" and ctx.state.query == "" then "Star a car to keep it here." else "No car matches that."
		end,
	}
end

------------------------------------------------------------------------

-- ALL / RWD / FWD / AWD / favourites.
function Common.tabs(parent: Instance, ctx: Types.Ctx, h: number, size: number, gap: number, w: number): Kit.Tabs
	local defs: { Kit.TabDef } = {
		{ id = "all", label = "ALL", width = w },
		{ id = "rwd", label = "RWD", width = w + 4 },
		{ id = "fwd", label = "FWD", width = w + 4 },
		{ id = "awd", label = "AWD", width = w + 4 },
		{ id = "fav", label = "", star = true, width = math.floor(w * 0.78) },
	}
	return Kit.tabs(parent, defs, h, size, gap, ctx.act.filter)
end

-- The header's buttons: the next layout, the plates, the settings, close.
function Common.headerButtons(parent: Instance, ctx: Types.Ctx, size: number, gap: number): Frame
	local row = Kit.frame(parent, "Buttons")
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Size = UDim2.fromOffset(0, size)
	Kit.list(row, false, gap, Enum.VerticalAlignment.Center)
	local defs: { { name: string, icon: string, fn: () -> () } } = {
		{ name = "Layout", icon = Art.layout, fn = ctx.act.nextLayout },
		{ name = "Plates", icon = Art.plates, fn = ctx.act.plates },
		{ name = "Settings", icon = Art.settings, fn = ctx.act.settings },
	}
	for i, d in defs do
		local b = Kit.iconButton(row, d.name, d.icon, size)
		b.LayoutOrder = i
		b.Activated:Connect(d.fn)
	end
	local close = Kit.iconButton(row, "Close", nil, size, "×")
	close.LayoutOrder = 9
	close.Activated:Connect(ctx.act.close)
	return row
end

-- "CARS" and its Arabic, side by side.
function Common.title(parent: Instance, size: number): Frame
	local f = Kit.frame(parent, "Title")
	f.AutomaticSize = Enum.AutomaticSize.X
	f.Size = UDim2.fromOffset(0, size + 4)
	Kit.list(f, false, math.floor(size * 0.4), Enum.VerticalAlignment.Center)
	local en = Kit.text(f, "English", "CARS", size, Enum.FontWeight.Heavy, true)
	en.AutomaticSize = Enum.AutomaticSize.X
	en.Size = UDim2.fromScale(0, 1)
	en.TextTruncate = Enum.TextTruncate.None
	local ar = Kit.text(f, "Arabic", "سياراتي", math.floor(size * 0.58), Enum.FontWeight.Bold, false, Kit.C.sub)
	ar.AutomaticSize = Enum.AutomaticSize.X
	ar.Size = UDim2.fromScale(0, 1)
	ar.TextTruncate = Enum.TextTruncate.None
	ar.LayoutOrder = 1
	return f
end

-- A spacer that takes the rest of a row.
function Common.spacer(parent: Instance, order: number): Frame
	local s = Kit.frame(parent, "Spacer")
	s.LayoutOrder = order
	s.Size = UDim2.fromOffset(0, 1)
	Kit.fill(s)
	return s
end

------------------------------------------------------------------------

-- 1850 -> "1,850".
function Common.commas(n: number): string
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

export type Stats = { root: Frame, set: (car: Kit.Car) -> () }

-- Weight and length as striped bars (Showroom), over the lightest and
-- heaviest, shortest and longest the game has.
function Common.stats(parent: Instance, labelSize: number, valueSize: number, barH: number, gap: number): Stats
	local f = Kit.frame(parent, "Stats")
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.Size = UDim2.fromScale(1, 0)
	Kit.list(f, true, gap)
	local rows = {}
	for i, label in { "Weight", "Length" } do
		local row = Kit.frame(f, label)
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, valueSize + 4 + barH)
		local l = Kit.text(row, "Label", label, labelSize, Enum.FontWeight.Bold, false)
		l.Size = UDim2.new(0.6, 0, 0, valueSize)
		local v = Kit.text(row, "Value", "", valueSize, Enum.FontWeight.ExtraBold, true)
		v.AnchorPoint = Vector2.new(1, 0)
		v.Position = UDim2.fromScale(1, 0)
		v.Size = UDim2.new(0.4, 0, 0, valueSize)
		v.TextXAlignment = Enum.TextXAlignment.Right
		local track = Kit.frame(row, "Track", Color3.new(0, 0, 0), 0.5)
		track.AnchorPoint = Vector2.new(0, 1)
		track.Position = UDim2.fromScale(0, 1)
		track.Size = UDim2.new(1, 0, 0, barH)
		track.ClipsDescendants = true
		Kit.corner(track, math.floor(barH / 2))
		Kit.stroke(track, Color3.new(1, 1, 1), 1, 0.78)
		local bar = Kit.image(track, "Bar", Art.stripes)
		bar.ScaleType = Enum.ScaleType.Tile
		bar.TileSize = UDim2.fromOffset(8, 8)
		bar.Size = UDim2.fromScale(0.5, 1)
		Kit.corner(bar, math.floor(barH / 2))
		rows[label] = { v = v, bar = bar }
	end
	return {
		root = f,
		set = function(car: Kit.Car)
			local w, l = rows.Weight, rows.Length
			w.v.Text = Common.commas(car.kg) .. " kg"
			w.bar.Size = UDim2.fromScale(math.clamp((car.kg - 1000) / 1400, 0.06, 1), 1)
			l.v.Text = string.format("%.1f m", car.lengthM)
			l.bar.Size = UDim2.fromScale(math.clamp((car.lengthM - 4.5) / 2, 0.06, 1), 1)
		end,
	}
end

return Common
