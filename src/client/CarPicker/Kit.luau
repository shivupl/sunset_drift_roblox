--!strict
-- The car picker's look and its building blocks: the garage style the owner
-- chose on 2026-10-11 (after a store car game's garage: "make it good and
-- polished, like a real car game ... with the theme of the seccond uploaded
-- image"): graphite panels with a faint dot texture, heavy italic Montserrat,
-- slanted tabs, a green SPAWN, boxes with a lit stage, a faint ring and the
-- drive type behind the car and the bottom-right corner cut.
--
-- Sizes are pixels at the reference screens (PC 1280x720, phone 844x390,
-- the mockups'); each layout picks its numbers and scales to the screen.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Art = require(script.Parent:WaitForChild("Art"))

local Kit = {}

local function rgb(hex: string): Color3
	return Color3.fromHex(hex)
end

Kit.C = {
	panelTop = rgb("#18191C"),
	panelBottom = rgb("#0C0D0F"),
	text = rgb("#FFFFFF"),
	sub = rgb("#8C9199"),
	faint = rgb("#6E737B"),
	tabInk = rgb("#B9BDC4"),
	green = rgb("#1ED07F"),
	greenTop = rgb("#3BE59C"),
	greenBottom = rgb("#12A866"),
	inUseInk = rgb("#06291A"),
	tileTop = rgb("#2C2E33"),
	tileBottom = rgb("#141517"),
	spot = rgb("#5A5D64"),
	chip = rgb("#060607"),
	teal = rgb("#2FD3C0"),
}

local FAMILY = "rbxasset://fonts/families/Montserrat.json"

function Kit.font(weight: Enum.FontWeight, italic: boolean?): Font
	return Font.new(FAMILY, weight, if italic then Enum.FontStyle.Italic else Enum.FontStyle.Normal)
end

function Kit.isTouch(): boolean
	return UserInputService.TouchEnabled or Players.LocalPlayer:GetAttribute("ForceTouch") == true
end

function Kit.frame(parent: Instance, name: string, color: Color3?, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	if color then
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transparency or 0
	else
		f.BackgroundTransparency = 1
	end
	f.Parent = parent
	return f
end

function Kit.image(parent: Instance, name: string, image: string, color: Color3?, transparency: number?): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.BackgroundTransparency = 1
	i.BorderSizePixel = 0
	i.Image = image
	i.ImageColor3 = color or Color3.new(1, 1, 1)
	i.ImageTransparency = transparency or 0
	i.Parent = parent
	return i
end

function Kit.text(parent: Instance, name: string, text: string, size: number, weight: Enum.FontWeight, italic: boolean?, color: Color3?): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.BorderSizePixel = 0
	t.Text = text
	t.TextSize = size
	t.FontFace = Kit.font(weight, italic)
	t.TextColor3 = color or Kit.C.text
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.TextTruncate = Enum.TextTruncate.AtEnd
	t.Parent = parent
	return t
end

function Kit.corner(o: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = o
end

function Kit.stroke(o: GuiObject, color: Color3, thickness: number, transparency: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = o
	return s
end

function Kit.pad(o: GuiObject, top: number, right: number, bottom: number, left: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, top)
	p.PaddingRight = UDim.new(0, right)
	p.PaddingBottom = UDim.new(0, bottom)
	p.PaddingLeft = UDim.new(0, left)
	p.Parent = o
end

-- Children in a row or a column, `gap` apart, in LayoutOrder.
function Kit.list(o: GuiObject, vertical: boolean, gap: number, align: Enum.VerticalAlignment?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = if vertical then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, gap)
	l.VerticalAlignment = align or Enum.VerticalAlignment.Top
	l.Parent = o
	return l
end

-- Takes whatever its list has left over (a CSS flex-grow: 1).
function Kit.fill(o: GuiObject)
	local f = Instance.new("UIFlexItem")
	f.FlexMode = Enum.UIFlexMode.Fill
	f.Parent = o
end

function Kit.gradient(o: GuiObject, top: Color3, bottom: Color3): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = o
	return g
end

-- A graphite panel: dark, lighter at the top, a hairline edge, the dot
-- texture fading in from the bottom-left corner. Returns the panel and its
-- Body, where the content and its layout go (the texture stays out of it).
function Kit.panel(parent: Instance, name: string, radius: number): (Frame, Frame)
	local p = Kit.frame(parent, name, Color3.new(1, 1, 1), 0.05)
	Kit.gradient(p, Kit.C.panelTop, Kit.C.panelBottom)
	Kit.corner(p, radius)
	Kit.stroke(p, Color3.new(1, 1, 1), 1, 0.92)
	local dots = Kit.image(p, "Dots", Art.dots, Color3.new(1, 1, 1), 0)
	dots.ScaleType = Enum.ScaleType.Tile
	dots.TileSize = UDim2.fromOffset(9, 9)
	dots.AnchorPoint = Vector2.new(0, 1)
	dots.Position = UDim2.fromScale(0, 1)
	dots.Size = UDim2.fromScale(0.65, 0.6)
	dots.ZIndex = 0
	local fade = Instance.new("UIGradient")
	fade.Rotation = -40
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.93),
		NumberSequenceKeypoint.new(0.55, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = dots
	local body = Kit.frame(p, "Body")
	body.Size = UDim2.fromScale(1, 1)
	return p, body
end

-- A square dark button with an icon (close, layout, plates, settings).
function Kit.iconButton(parent: Instance, name: string, icon: string?, size: number, glyph: string?): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BackgroundTransparency = 0.93
	b.Size = UDim2.fromOffset(size + 4, size)
	b.Text = glyph or ""
	b.TextColor3 = Kit.C.text
	b.TextSize = math.floor(size * 0.62)
	b.FontFace = Kit.font(Enum.FontWeight.Bold)
	Kit.corner(b, math.floor(size * 0.26))
	if icon then
		local i = Kit.image(b, "Icon", icon, Kit.C.text, 0.05)
		i.AnchorPoint = Vector2.new(0.5, 0.5)
		i.Position = UDim2.fromScale(0.5, 0.5)
		i.Size = UDim2.fromOffset(math.floor(size * 0.5), math.floor(size * 0.5))
	end
	b.Parent = parent
	return b
end

-- The small black drive chip (RWD) with a white hairline, like a tier tag.
function Kit.chip(parent: Instance, text: string, h: number, size: number): Frame
	local c = Kit.frame(parent, "Chip", Kit.C.chip, 0.1)
	c.AutomaticSize = Enum.AutomaticSize.X
	c.Size = UDim2.fromOffset(0, h)
	Kit.corner(c, math.floor(h / 2))
	Kit.stroke(c, Color3.new(1, 1, 1), 1, 0.45)
	Kit.pad(c, 0, math.floor(h * 0.5), 0, math.floor(h * 0.5))
	local t = Kit.text(c, "Label", text, size, Enum.FontWeight.ExtraBold, true)
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.fromScale(0, 1)
	t.TextTruncate = Enum.TextTruncate.None
	return c
end

-- The green IN USE tag.
function Kit.inUse(parent: Instance, h: number, size: number): Frame
	local c = Kit.frame(parent, "InUse", Kit.C.green, 0)
	c.AutomaticSize = Enum.AutomaticSize.X
	c.Size = UDim2.fromOffset(0, h)
	Kit.corner(c, 4)
	Kit.pad(c, 0, 7, 0, 7)
	local t = Kit.text(c, "Label", "IN USE", size, Enum.FontWeight.ExtraBold, true, Kit.C.inUseInk)
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.fromScale(0, 1)
	t.TextTruncate = Enum.TextTruncate.None
	return c
end

------------------------------------------------------------------------
-- Tabs: ALL / RWD / FWD / AWD / favourites, slanted, the open one green.
------------------------------------------------------------------------

export type TabDef = { id: string, label: string, star: boolean?, width: number }
export type Tabs = { root: Frame, set: (id: string) -> () }

function Kit.tabs(parent: Instance, defs: { TabDef }, h: number, size: number, gap: number, onPick: (string) -> ()): Tabs
	local row = Kit.frame(parent, "Tabs")
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Size = UDim2.fromOffset(0, h)
	Kit.list(row, false, gap, Enum.VerticalAlignment.Center)
	local items: { [string]: { b: ImageButton, g: UIGradient, label: TextLabel?, icon: ImageLabel? } } = {}
	for i, d in defs do
		local b = Instance.new("ImageButton")
		b.Name = "Tab_" .. d.id
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.Image = Art.tab
		b.ScaleType = Enum.ScaleType.Slice
		b.SliceCenter = Art.tabSlice
		b.SliceScale = h / Art.tabH
		b.Size = UDim2.fromOffset(d.width, h)
		b.LayoutOrder = i
		local g = Kit.gradient(b, Kit.C.greenTop, Kit.C.greenBottom)
		local item: { b: ImageButton, g: UIGradient, label: TextLabel?, icon: ImageLabel? } = { b = b, g = g }
		if d.star then
			local s = Kit.image(b, "Star", Art.star, Kit.C.tabInk)
			s.AnchorPoint = Vector2.new(0.5, 0.5)
			s.Position = UDim2.fromScale(0.5, 0.5)
			s.Size = UDim2.fromOffset(math.floor(h * 0.42), math.floor(h * 0.42))
			item.icon = s
		else
			local t = Kit.text(b, "Label", d.label, size, Enum.FontWeight.ExtraBold, true, Kit.C.tabInk)
			t.Size = UDim2.fromScale(1, 1)
			t.TextXAlignment = Enum.TextXAlignment.Center
			item.label = t
		end
		b.Activated:Connect(function()
			onPick(d.id)
		end)
		b.Parent = row
		items[d.id] = item
	end
	return {
		root = row,
		set = function(id: string)
			for key, it in items do
				local on = key == id
				it.g.Enabled = on
				it.b.ImageColor3 = Color3.new(1, 1, 1)
				it.b.ImageTransparency = if on then 0 else 0.92
				local ink = if on then Kit.C.text else Kit.C.tabInk
				local lbl, ico = it.label, it.icon
				if lbl then
					lbl.TextColor3 = ink
				end
				if ico then
					ico.ImageColor3 = ink
				end
			end
		end,
	}
end

------------------------------------------------------------------------
-- The green SPAWN button, slanted and shaded.
------------------------------------------------------------------------

export type Spawn = { root: ImageButton, set: (text: string, enabled: boolean) -> () }

function Kit.spawnButton(parent: Instance, w: UDim, h: number, size: number, onClick: () -> ()): Spawn
	local b = Instance.new("ImageButton")
	b.Name = "Spawn"
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Image = Art.button
	b.ScaleType = Enum.ScaleType.Slice
	b.SliceCenter = Art.buttonSlice
	b.SliceScale = h / Art.buttonH
	b.ImageColor3 = Kit.C.greenTop
	b.Size = UDim2.new(w.Scale, w.Offset, 0, h)
	local t = Kit.text(b, "Label", "SPAWN THIS CAR", size, Enum.FontWeight.Heavy, true)
	t.Size = UDim2.fromScale(1, 1)
	t.TextXAlignment = Enum.TextXAlignment.Center
	t.TextStrokeColor3 = Color3.fromRGB(0, 60, 30)
	t.TextStrokeTransparency = 0.75
	local enabled = true
	b.Activated:Connect(function()
		if enabled then
			onClick()
		end
	end)
	b.Parent = parent
	return {
		root = b,
		set = function(text: string, on: boolean)
			enabled = on
			t.Text = text
			b.ImageTransparency = if on then 0 else 0.45
		end,
	}
end

------------------------------------------------------------------------
-- A car's box: the photo on a lit stage, its name top left, the
-- favourite star top right, the drive type bottom right.
------------------------------------------------------------------------

export type Car = {
	id: string,
	name: string,
	drive: string,
	blurb: string,
	kg: number,
	lengthM: number,
	image: string?,
}

export type TileMetrics = {
	name: number, -- text size
	chipH: number,
	chipText: number,
	starBox: number,
	star: number,
	imageTop: number,
	imageBottom: number,
	ring: number,
	ringInset: number, -- how far the ring hangs off the top-right corner
}

export type Tile = {
	root: Frame,
	star: Frame, -- the star's hit area
	setPicked: (boolean) -> (),
	setFav: (boolean) -> (),
}

function Kit.tile(parent: Instance, car: Car, m: TileMetrics): Tile
	local root = Kit.frame(parent, "Car_" .. car.id)
	-- The box: a cut-corner shape, lighter at the top.
	local fill = Kit.image(root, "Fill", Art.tile)
	fill.ScaleType = Enum.ScaleType.Slice
	fill.SliceCenter = Art.tileSlice
	fill.SliceScale = 0.5
	fill.Size = UDim2.fromScale(1, 1)
	Kit.gradient(fill, Kit.C.tileTop, Kit.C.tileBottom)
	-- The stage: a soft light above centre, a faint ring hanging off the
	-- top right, the drive type huge and faint behind the car.
	local stage = Kit.frame(root, "Stage")
	stage.Size = UDim2.new(1, -4, 1, -4)
	stage.Position = UDim2.fromOffset(2, 2)
	stage.ClipsDescendants = true
	local spot = Kit.image(stage, "Spot", Art.spot, Kit.C.spot, 0.25)
	spot.AnchorPoint = Vector2.new(0.5, 0.5)
	spot.Position = UDim2.fromScale(0.5, 0.4)
	spot.Size = UDim2.fromScale(1.15, 1.3)
	local ring = Kit.image(stage, "Ring", Art.ring, Color3.new(1, 1, 1), 0.965)
	ring.AnchorPoint = Vector2.new(1, 0)
	ring.Position = UDim2.new(1, m.ringInset, 0, -m.ringInset)
	ring.Size = UDim2.fromOffset(m.ring, m.ring)
	local mark = Kit.text(stage, "Watermark", car.drive, math.floor(m.ring * 0.42), Enum.FontWeight.Heavy, true, Color3.new(1, 1, 1))
	mark.TextTransparency = 0.95
	mark.AnchorPoint = Vector2.new(1, 1)
	mark.Position = UDim2.new(1, -6, 1, math.floor(m.ring * 0.1))
	mark.Size = UDim2.new(1, 0, 0, math.floor(m.ring * 0.42))
	mark.TextXAlignment = Enum.TextXAlignment.Right
	mark.TextTruncate = Enum.TextTruncate.None
	if car.image then
		local photo = Kit.image(stage, "Photo", car.image :: string)
		photo.ScaleType = Enum.ScaleType.Fit
		photo.Position = UDim2.new(0.06, 0, 0, m.imageTop)
		photo.Size = UDim2.new(0.88, 0, 1, -(m.imageTop + m.imageBottom))
	end
	local name = Kit.text(root, "Name", car.name, m.name, Enum.FontWeight.ExtraBold, true)
	name.Position = UDim2.fromOffset(math.floor(m.name * 0.75), math.floor(m.name * 0.55))
	name.Size = UDim2.new(1, -(m.starBox + 10), 0, math.floor(m.name * 1.3))
	name.TextStrokeTransparency = 0.8
	local chip = Kit.chip(root, car.drive, m.chipH, m.chipText)
	chip.AnchorPoint = Vector2.new(1, 1)
	chip.Position = UDim2.new(1, -math.floor(m.chipH * 0.9), 1, -math.floor(m.chipH * 0.45))
	-- The favourite star: its own hit area, so a tap on it does not pick.
	local star = Kit.frame(root, "Fav")
	star.AnchorPoint = Vector2.new(1, 0)
	star.Position = UDim2.new(1, -2, 0, 0)
	star.Size = UDim2.fromOffset(m.starBox, m.starBox)
	star.ZIndex = 3
	local starImg = Kit.image(star, "Icon", Art.starLine, Color3.new(1, 1, 1), 0.5)
	starImg.AnchorPoint = Vector2.new(0.5, 0.5)
	starImg.Position = UDim2.fromScale(0.5, 0.5)
	starImg.Size = UDim2.fromOffset(m.star, m.star)
	starImg.ZIndex = 3
	-- The outline on top: faint, or thick and green when picked.
	local edge = Kit.image(root, "Edge", Art.tileEdge)
	edge.ScaleType = Enum.ScaleType.Slice
	edge.SliceCenter = Art.tileSlice
	edge.SliceScale = 0.5
	edge.Size = UDim2.fromScale(1, 1)
	edge.ZIndex = 2
	local edgeFade = Instance.new("UIGradient")
	edgeFade.Rotation = 90
	edgeFade.Parent = edge
	local function paintEdge(picked: boolean)
		edge.Image = if picked then Art.tileEdgeThick else Art.tileEdge
		if picked then
			edgeFade.Color = ColorSequence.new(Kit.C.greenTop, Kit.C.greenBottom)
			edgeFade.Transparency = NumberSequence.new(0)
		else
			edgeFade.Color = ColorSequence.new(Color3.new(1, 1, 1))
			edgeFade.Transparency = NumberSequence.new(0.76, 0.93)
		end
	end
	paintEdge(false)
	root.Parent = parent
	return {
		root = root,
		star = star,
		setPicked = paintEdge,
		setFav = function(fav: boolean)
			starImg.Image = if fav then Art.star else Art.starLine
			starImg.ImageColor3 = if fav then Kit.C.green else Color3.new(1, 1, 1)
			starImg.ImageTransparency = if fav then 0 else 0.5
		end,
	}
end

------------------------------------------------------------------------
-- Taps. A ScrollingFrame on a phone claims a touch that moves even a
-- little for its own scrolling, so buttons inside one never see Activated
-- (SpawnMenu's header has the story). Presses on the boxes and stars are
-- followed through UserInputService instead: a press counts as a tap when
-- the finger stays within SLOP and the list did not scroll.
------------------------------------------------------------------------

local SLOP = 14

export type Taps = {
	add: (target: GuiObject, scroller: ScrollingFrame?, fn: () -> ()) -> (),
	destroy: () -> (),
}

function Kit.taps(isLive: () -> boolean): Taps
	local targets: { [GuiObject]: { scroller: ScrollingFrame?, fn: () -> () } } = {}
	local press: { target: GuiObject, input: InputObject, origin: Vector2, canvas: Vector2, cancelled: boolean }? = nil
	local conns: { RBXScriptConnection } = {}
	local function under(pos: Vector3): GuiObject?
		local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if not pg then
			return nil
		end
		for _, o in pg:GetGuiObjectsAtPosition(pos.X, pos.Y) do
			if targets[o] then
				return o
			end
		end
		return nil
	end
	local function canvasOf(t: GuiObject): Vector2
		local s = targets[t] and targets[t].scroller
		return if s then s.CanvasPosition else Vector2.zero
	end
	table.insert(
		conns,
		UserInputService.InputBegan:Connect(function(io: InputObject)
			if io.UserInputType ~= Enum.UserInputType.Touch and io.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			if press or not isLive() then
				return
			end
			local t = under(io.Position)
			if t then
				press = { target = t, input = io, origin = Vector2.new(io.Position.X, io.Position.Y), canvas = canvasOf(t), cancelled = false }
			end
		end)
	)
	table.insert(
		conns,
		UserInputService.InputChanged:Connect(function(io: InputObject)
			local p = press
			if not p or p.cancelled then
				return
			end
			if io ~= p.input and io.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end
			local travel = (Vector2.new(io.Position.X, io.Position.Y) - p.origin).Magnitude
			if travel > SLOP or (canvasOf(p.target) - p.canvas).Magnitude > 2 then
				p.cancelled = true
			end
		end)
	)
	table.insert(
		conns,
		UserInputService.InputEnded:Connect(function(io: InputObject)
			local p = press
			if not p or p.input ~= io then
				return
			end
			press = nil
			if not p.cancelled and under(io.Position) == p.target and targets[p.target] then
				targets[p.target].fn()
			end
		end)
	)
	return {
		add = function(target: GuiObject, scroller: ScrollingFrame?, fn: () -> ())
			targets[target] = { scroller = scroller, fn = fn }
		end,
		destroy = function()
			for _, c in conns do
				c:Disconnect()
			end
			table.clear(targets)
			press = nil
		end,
	}
end

return Kit
