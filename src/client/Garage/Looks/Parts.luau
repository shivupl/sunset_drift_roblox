--!strict
-- The garage layouts' shared pieces, in the car picker's look
-- (CarPicker/Kit, UI_SYSTEM.md "The car picker"), so the garage matches the
-- CARS menu (the owner, 2026-10-11: "make every single menu UI coherent"):
-- graphite panels, heavy italic Montserrat, slanted tabs, items in the
-- picker's cut-corner box with the chosen one edged green. Money is the
-- sodium of the HUD's coin: prices, BUY and the confirm sheet's BUY; green
-- is go and yours (DRIVE THIS, ON CAR, OWNED, what shows on the car).
-- The category icons are art/garage.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UITheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local Client = script.Parent.Parent.Parent
local CarPicker = Client:WaitForChild("CarPicker")
local Kit = require(CarPicker:WaitForChild("Kit"))
local Art = require(CarPicker:WaitForChild("Art"))
local UIKit = require(Client:WaitForChild("UIKit"))
local Types = require(script.Parent:WaitForChild("Types"))

local Parts = {}

-- art/garage/out/garage_icons.png, 128 px cells.
Parts.ICONS = "rbxassetid://71924428072059"
Parts.ICON_CELL = 128
Parts.ICON = { cars = 0, paint = 1, rims = 2, plates = 3, lights = 4, decal = 5, exhaust = 6, layout = 7 }
-- The HUD's cash coin (HudLab/Art).
Parts.COIN = "rbxassetid://117391161025187"

Parts.C = {
	sodium = Color3.fromHex("#FFBA5C"),
	sodiumTop = Color3.fromHex("#FFD592"),
	buyInk = Color3.fromHex("#2B1903"),
	sand = Color3.fromHex("#C6AC84"),
	beacon = Color3.fromHex("#FF7A68"),
	beaconGround = Color3.fromHex("#4A1A14"),
	dusk = Color3.fromHex("#C99BDB"),
	grey = Color3.fromHex("#5A5D64"),
}

-- Numbers in Oswald, like the HUD's and the old garage's prices.
local NUMBERS = "rbxasset://fonts/families/Oswald.json"
function Parts.num(weight: Enum.FontWeight?): Font
	return Font.new(NUMBERS, weight or Enum.FontWeight.SemiBold)
end

-- 1850 -> "1,850".
function Parts.money(n: number): string
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

------------------------------------------------------------------------
-- Scale: each layout is drawn for one phone and one PC screen and scaled
-- to the one it is on (CarPicker/Common.fit's sizes and bounds).
------------------------------------------------------------------------

Parts.REF_PC = Vector2.new(1280, 664)
Parts.REF_PHONE = Vector2.new(844, 346)

function Parts.scaleFor(touch: boolean, screen: Vector2): number
	local ref = if touch then Parts.REF_PHONE else Parts.REF_PC
	return math.clamp(math.min(screen.X / ref.X, screen.Y / ref.Y), 0.7, 1.35)
end

-- A full-screen root scaled for this screen, and the room it has in
-- drawing pixels.
function Parts.root(gui: ScreenGui, ctx: Types.Ctx, name: string): (Frame, Vector2)
	local root = Kit.frame(gui, name)
	local s = Parts.scaleFor(ctx.touch, ctx.screen)
	local room = ctx.screen / s
	root.Size = UDim2.fromOffset(room.X, room.Y)
	local scale = Instance.new("UIScale")
	scale.Scale = s
	scale.Parent = root
	return root, room
end

------------------------------------------------------------------------
-- Small pieces.
------------------------------------------------------------------------

-- An icon from the garage sheet.
function Parts.icon(parent: Instance, index: number, size: number, color: Color3?): ImageLabel
	local i = Kit.image(parent, "Icon", Parts.ICONS, color or Kit.C.text)
	i.ImageRectSize = Vector2.new(Parts.ICON_CELL, Parts.ICON_CELL)
	i.ImageRectOffset = Vector2.new(index * Parts.ICON_CELL, 0)
	i.Size = UDim2.fromOffset(size, size)
	return i
end

-- A title's Arabic beside it: UITheme.arabicScale the English's size
-- (UI_SYSTEM.md "Arabic with English"). Roblox's Arabic face draws small,
-- so this reads as the same size; at 0.6 it was a smudge on a phone (the
-- owner's screenshots, 2026-10-12).
function Parts.arabicSize(size: number): number
	return math.floor(size * UITheme.arabicScale + 0.5)
end

-- GARAGE and its Arabic, side by side.
function Parts.title(parent: Instance, size: number): Frame
	local f = Kit.frame(parent, "Title")
	f.AutomaticSize = Enum.AutomaticSize.X
	f.Size = UDim2.fromOffset(0, size + 4)
	Kit.list(f, false, math.floor(size * 0.4), Enum.VerticalAlignment.Center)
	local en = Kit.text(f, "English", "GARAGE", size, Enum.FontWeight.Heavy, true)
	en.AutomaticSize = Enum.AutomaticSize.X
	en.Size = UDim2.fromScale(0, 1)
	en.TextTruncate = Enum.TextTruncate.None
	local ar = Kit.text(f, "Arabic", "كراج", Parts.arabicSize(size), Enum.FontWeight.Bold, false, Parts.C.sand)
	ar.LayoutOrder = 1
	ar.AutomaticSize = Enum.AutomaticSize.X
	ar.Size = UDim2.fromScale(0, 1)
	ar.TextTruncate = Enum.TextTruncate.None
	return f
end

-- A heading in a category's words, its Arabic after it.
function Parts.heading(parent: Instance, def: Types.TabDef, size: number): Frame
	local f = Kit.frame(parent, "Heading")
	f.AutomaticSize = Enum.AutomaticSize.X
	f.Size = UDim2.fromOffset(0, size + 4)
	Kit.list(f, false, math.floor(size * 0.4), Enum.VerticalAlignment.Center)
	local en = Kit.text(f, "English", def.label, size, Enum.FontWeight.Heavy, true)
	en.AutomaticSize = Enum.AutomaticSize.X
	en.Size = UDim2.fromScale(0, 1)
	en.TextTruncate = Enum.TextTruncate.None
	local ar = Kit.text(f, "Arabic", def.arabic, Parts.arabicSize(size), Enum.FontWeight.Bold, false, Parts.C.sand)
	ar.LayoutOrder = 1
	ar.AutomaticSize = Enum.AutomaticSize.X
	ar.Size = UDim2.fromScale(0, 1)
	ar.TextTruncate = Enum.TextTruncate.None
	return f
end

-- Your balance: the coin and the amount on a dark pill.
export type Cash = { root: Frame, set: (text: string) -> () }
function Parts.cash(parent: Instance, h: number, size: number): Cash
	local p = Kit.frame(parent, "Cash", Kit.C.chip, 0.15)
	p.AutomaticSize = Enum.AutomaticSize.X
	p.Size = UDim2.fromOffset(0, h)
	Kit.corner(p, math.floor(h / 2))
	Kit.stroke(p, Parts.C.sodium, 1, 0.65)
	Kit.pad(p, 0, math.floor(h * 0.4), 0, 3)
	Kit.list(p, false, math.floor(h * 0.22), Enum.VerticalAlignment.Center)
	local coin = Kit.image(p, "Coin", Parts.COIN)
	coin.Size = UDim2.fromOffset(h - 6, h - 6)
	local t = Kit.text(p, "Amount", "", size, Enum.FontWeight.SemiBold, false)
	t.FontFace = Parts.num()
	t.LayoutOrder = 1
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.fromScale(0, 1)
	t.TextTruncate = Enum.TextTruncate.None
	return {
		root = p,
		set = function(text: string)
			t.Text = text
		end,
	}
end

-- A square dark button: an icon from the sheet, or a glyph, and maybe a
-- word under it.
function Parts.square(parent: Instance, name: string, w: number, h: number, icon: number?, glyph: string?, label: string?): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BackgroundTransparency = 0.92
	b.Size = UDim2.fromOffset(w, h)
	b.Text = ""
	Kit.corner(b, math.floor(math.min(w, h) * 0.24))
	Kit.stroke(b, Color3.new(1, 1, 1), 1, 0.92)
	local mid = if label then 0.4 else 0.5
	if icon then
		-- The sheet's drawings fill three fifths of their cell.
		local i = Parts.icon(b, icon, math.floor(h * (if label then 0.52 else 0.66)))
		i.AnchorPoint = Vector2.new(0.5, 0.5)
		i.Position = UDim2.fromScale(0.5, mid)
	elseif glyph then
		local g = Kit.text(b, "Glyph", glyph, math.floor(h * 0.42), Enum.FontWeight.Bold, false)
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.fromScale(0.5, mid)
		g.Size = UDim2.fromScale(1, 0.5)
		g.TextXAlignment = Enum.TextXAlignment.Center
	end
	if label then
		local l = Kit.text(b, "Label", label, math.max(8, math.floor(h * 0.17)), Enum.FontWeight.ExtraBold, true, Kit.C.tabInk)
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.78)
		l.Size = UDim2.new(1, -4, 0, math.floor(h * 0.22))
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.TextTruncate = Enum.TextTruncate.None
	end
	b.Parent = parent
	return b
end

-- EXIT: a cross and the word, side by side.
function Parts.exit(parent: Instance, w: number, h: number, size: number): TextButton
	local b = Parts.square(parent, "Exit", w, h)
	local row = Kit.frame(b, "Row")
	row.Size = UDim2.fromScale(1, 1)
	local l = Kit.list(row, false, math.floor(size * 0.6), Enum.VerticalAlignment.Center)
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local x = Kit.text(row, "Cross", "×", math.floor(size * 1.5), Enum.FontWeight.Bold, false)
	x.AutomaticSize = Enum.AutomaticSize.X
	x.Size = UDim2.fromScale(0, 1)
	x.TextTruncate = Enum.TextTruncate.None
	local t = Kit.text(row, "Label", "EXIT", size, Enum.FontWeight.ExtraBold, true)
	t.LayoutOrder = 1
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.fromScale(0, 1)
	t.TextTruncate = Enum.TextTruncate.None
	return b
end

-- A shade from one edge of the screen (left, right or bottom) for words or
-- items to sit on: dark at the edge, clear `tail` past `reach` into the
-- gui. It starts half a screen out and the gui stops clipping to the safe
-- area, so it meets the screen's edge beside any notch (UIKit.edgeToEdge;
-- the owner, 2026-10-12: "no wierd gap for any device"). Its fade is
-- SHOWCASE's first shade's: solid to 60 px outside the gui, 0.45 a little
-- past `reach`, clear at the end. Drags pass through it (PassThrough).
export type Edge = "left" | "right" | "bottom"
function Parts.edgeShade(gui: ScreenGui, root: Frame, room: Vector2, side: Edge, reach: number, tail: number): Frame
	gui.ClipToDeviceSafeArea = false
	local bleed = math.floor((if side == "bottom" then room.Y else room.X) * 0.5)
	local total = bleed + reach + tail
	local fadeW = reach + 60 + tail
	local shade = Kit.frame(root, "Shade_" .. side, Color3.new(0, 0, 0), 0)
	if side == "left" then
		shade.Position = UDim2.fromOffset(-bleed, -math.floor(room.Y * 0.5))
		shade.Size = UDim2.fromOffset(total, room.Y * 2)
	elseif side == "right" then
		shade.Position = UDim2.fromOffset(room.X - reach - tail, -math.floor(room.Y * 0.5))
		shade.Size = UDim2.fromOffset(total, room.Y * 2)
	else
		shade.Position = UDim2.fromOffset(-math.floor(room.X * 0.5), room.Y - reach - tail)
		shade.Size = UDim2.fromOffset(room.X * 2, total)
	end
	shade:SetAttribute("PassThrough", true)
	local solid = (bleed - 60) / total
	local g = Instance.new("UIGradient")
	-- Keypoint 0 at the screen's edge: left, right, or the bottom.
	g.Rotation = if side == "left" then 0 elseif side == "right" then 180 else 270
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(solid, 0.15),
		NumberSequenceKeypoint.new(solid + 0.55 * fadeW / total, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = shade
	return shade
end

-- A line under the sub-tabs: how the tyres drive, or why a set can't go on.
function Parts.note(parent: Instance, size: number): TextLabel
	local n = Kit.text(parent, "Note", "", size, Enum.FontWeight.SemiBold, false, Kit.C.tabInk)
	n.TextWrapped = true
	n.TextTruncate = Enum.TextTruncate.None
	n.TextYAlignment = Enum.TextYAlignment.Top
	n.AutomaticSize = Enum.AutomaticSize.Y
	n.Size = UDim2.fromScale(1, 0)
	return n
end

------------------------------------------------------------------------
-- Items: the picker's cut-corner box. A tile (a swatch over the name and
-- its word), a row (the swatch at the left) or a square block (a big
-- picture over the name and its word).
------------------------------------------------------------------------

export type BoxMetrics = {
	name: number, -- text sizes
	word: number,
	swatch: number, -- a tile's round swatch; a row's swatch height
	rows: boolean, -- draw a palette's swatches as rows too
	inline: boolean, -- a row's word at its right end, not under the name
	-- Every item a square block this big, its picture over its name and
	-- word, whatever its shape (DOCK, the SHOWCASE variants).
	block: number?,
	-- The blocks in one row scrolling sideways (SHELF).
	sideways: boolean?,
	-- What is under the list, for the fades at its ends: a panel (the
	-- default) or a shade (the SHOWCASE variants without a panel).
	backdrop: ("panel" | "shade")?,
}

export type Box = {
	root: Frame,
	paint: (state: Types.EntryState) -> (),
	press: (down: boolean) -> (),
	pop: () -> (),
}

local ASPECT: { [string]: number } = { row = 1.6, wide = 2.2, car = 1.8 }

-- A round swatch's children drawn edge to edge get its corners too.
local function roundChildren(tile: Frame, radius: number)
	for _, c in tile:GetChildren() do
		if c:IsA("Frame") and c.Size == UDim2.fromScale(1, 1) and not c:FindFirstChildOfClass("UICorner") then
			Kit.corner(c, radius)
		end
	end
end

function Parts.box(parent: Instance, e: Types.Entry, m: BoxMetrics): Box
	local root = Kit.frame(parent, "Item_" .. (if e.key == "" then "account" else e.key))
	root.Active = true
	local fill = Kit.image(root, "Fill", Art.tile)
	fill.ScaleType = Enum.ScaleType.Slice
	fill.SliceCenter = Art.tileSlice
	fill.SliceScale = 0.45
	fill.Size = UDim2.fromScale(1, 1)
	Kit.gradient(fill, Kit.C.tileTop, Kit.C.tileBottom)
	local scale = Instance.new("UIScale")
	scale.Parent = root

	local block = m.block
	local asRow = block == nil and (e.shape ~= "swatch" or m.rows)
	local round = e.shape == "swatch"
	local tile = Kit.frame(root, "Swatch", Color3.new(1, 1, 1), 0)
	tile.ClipsDescendants = true
	local nameLabel = Kit.text(root, "Name", "", m.name, Enum.FontWeight.ExtraBold, true)
	nameLabel.RichText = true
	nameLabel.Text = if e.rare then `<font color="#{Parts.C.dusk:ToHex()}">◆</font> {e.name}` else e.name
	local word = Kit.text(root, "Word", "", m.word, Enum.FontWeight.ExtraBold, true, Parts.C.sodium)
	if block then
		-- The picture fills the room over the words: a palette's colour
		-- as a disc up to `swatch` across, anything else at its own aspect
		-- as wide as the block lets it.
		local textH = m.name + m.word + 16
		local artTop = 8
		local artRoom = block - textH - artTop - 4
		local w, h = 0, 0
		if round then
			local d = math.min(m.swatch, artRoom)
			w, h = d, d
		else
			local aspect = ASPECT[e.shape] or 1.6
			w = block - 16
			h = math.floor(w / aspect + 0.5)
			if h > artRoom then
				h = artRoom
				w = math.floor(h * aspect + 0.5)
			end
		end
		tile.AnchorPoint = Vector2.new(0.5, 0.5)
		tile.Position = UDim2.new(0.5, 0, 0, artTop + math.floor(artRoom / 2))
		tile.Size = UDim2.fromOffset(w, h)
		Kit.corner(tile, if round then math.floor(h / 2) else 8)
		nameLabel.AnchorPoint = Vector2.new(0.5, 1)
		nameLabel.Position = UDim2.new(0.5, 0, 1, -(m.word + 12))
		nameLabel.Size = UDim2.new(1, -12, 0, m.name + 3)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Center
		nameLabel.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = math.floor(m.name)
		limit.MinTextSize = math.floor(m.name * 0.72)
		limit.Parent = nameLabel
		word.AnchorPoint = Vector2.new(0.5, 1)
		word.Position = UDim2.new(0.5, 0, 1, -8)
		word.Size = UDim2.new(1, -16, 0, m.word + 4)
		word.TextXAlignment = Enum.TextXAlignment.Center
	elseif asRow then
		local h = m.swatch
		local w = if round then h else math.floor(h * (ASPECT[e.shape] or 1.6) + 0.5)
		tile.AnchorPoint = Vector2.new(0, 0.5)
		tile.Position = UDim2.new(0, 7, 0.5, 0)
		tile.Size = UDim2.fromOffset(w, h)
		Kit.corner(tile, if round then math.floor(h / 2) else 6)
		local x = 7 + w + 10
		if m.inline then
			nameLabel.AnchorPoint = Vector2.new(0, 0.5)
			nameLabel.Position = UDim2.new(0, x, 0.5, 0)
			nameLabel.Size = UDim2.new(0.68, -x, 0, m.name + 4)
			word.AnchorPoint = Vector2.new(1, 0.5)
			word.Position = UDim2.new(1, -14, 0.5, 0)
			word.Size = UDim2.new(0.32, -8, 0, m.word + 4)
			word.TextXAlignment = Enum.TextXAlignment.Right
		else
			nameLabel.AnchorPoint = Vector2.new(0, 1)
			nameLabel.Position = UDim2.new(0, x, 0.5, 1)
			nameLabel.Size = UDim2.new(1, -(x + 10), 0, m.name + 4)
			word.AnchorPoint = Vector2.new(0, 0)
			word.Position = UDim2.new(0, x, 0.5, 2)
			word.Size = UDim2.new(1, -(x + 14), 0, m.word + 4)
		end
	else
		local s = m.swatch
		tile.AnchorPoint = Vector2.new(0.5, 0)
		tile.Position = UDim2.new(0.5, 0, 0, math.floor(s * 0.22))
		tile.Size = UDim2.fromOffset(s, s)
		Kit.corner(tile, math.floor(s / 2))
		local y = math.floor(s * 0.22) + s + 4
		nameLabel.Position = UDim2.fromOffset(5, y)
		nameLabel.Size = UDim2.new(1, -10, 0, m.name + 3)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Center
		-- A long name (Sodium Orange) shrinks to fit rather than being cut.
		nameLabel.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = math.floor(m.name)
		limit.MinTextSize = math.floor(m.name * 0.72)
		limit.Parent = nameLabel
		word.Position = UDim2.fromOffset(5, y + m.name + 3)
		word.Size = UDim2.new(1, -14, 0, m.word + 4)
		word.TextXAlignment = Enum.TextXAlignment.Center
	end
	tile.ZIndex = 2
	nameLabel.ZIndex = 2
	word.ZIndex = 2
	local ring = Kit.stroke(tile, Color3.new(1, 1, 1), 1, 0.82)
	e.draw(tile)
	if round then
		roundChildren(tile, math.floor(tile.Size.Y.Offset / 2))
	end

	-- The outline on top: faint, or thick and green on what shows on the car.
	local edge = Kit.image(root, "Edge", Art.tileEdge)
	edge.ScaleType = Enum.ScaleType.Slice
	edge.SliceCenter = Art.tileSlice
	edge.SliceScale = 0.45
	edge.Size = UDim2.fromScale(1, 1)
	edge.ZIndex = 3
	local edgeFade = Instance.new("UIGradient")
	edgeFade.Rotation = 90
	edgeFade.Parent = edge
	root.Parent = parent

	local quick = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	return {
		root = root,
		paint = function(st: Types.EntryState)
			local chosen = st.chosen and not st.disabled
			edge.Image = if chosen then Art.tileEdgeThick else Art.tileEdge
			if chosen then
				edgeFade.Color = ColorSequence.new(Kit.C.greenTop, Kit.C.greenBottom)
				edgeFade.Transparency = NumberSequence.new(0)
			else
				edgeFade.Color = ColorSequence.new(Color3.new(1, 1, 1))
				edgeFade.Transparency = NumberSequence.new(0.78, 0.94)
			end
			if e.fades then
				tile.BackgroundTransparency = if st.disabled then 0.6 else 0
			end
			ring.Transparency = if st.disabled then 0.95 else 0.82
			nameLabel.TextColor3 = if st.disabled then Kit.C.faint else Kit.C.text
			local k = st.kind
			word.Visible = k ~= "none" and not st.disabled
			word.Text = st.word
			if k == "price" then
				word.FontFace = Parts.num()
				word.TextSize = m.word + 2
				word.TextColor3 = Parts.C.sodium
			else
				word.FontFace = Kit.font(Enum.FontWeight.ExtraBold, true)
				word.TextSize = m.word
				word.TextColor3 = if k == "note" then Kit.C.sub else Kit.C.green
			end
		end,
		press = function(down: boolean)
			TweenService:Create(scale, quick, { Scale = if down then 0.95 else 1 }):Play()
		end,
		pop = function()
			local up = TweenService:Create(scale, quick, { Scale = 1.06 })
			up.Completed:Once(function()
				TweenService:Create(scale, quick, { Scale = 1 }):Play()
			end)
			up:Play()
		end,
	}
end

-- The items in a scrolling grid (`cols` across) or list (cols 1), built
-- again on every fill. Returns the boxes by key, for refresh and pop.
-- `root` holds the scroll and goes in the layout's list.
--
-- Where more items are past an edge, that edge fades into the panel, so a
-- row cut by the edge reads as "more this way" rather than a broken box
-- (the owner's phone, 2026-10-12: MY CARS showed a sliver of a fifth car).
export type Items = {
	root: Frame,
	scroll: ScrollingFrame,
	fill: (entries: { Types.Entry }) -> (),
	refresh: () -> (),
	pop: (key: string) -> (),
}
function Parts.items(parent: Instance, ctx: Types.Ctx, swatchCols: number, rowCols: number, tileH: number, rowH: number, gap: number, m: BoxMetrics): Items
	local sideways = m.sideways == true
	local holder = Kit.frame(parent, "Items")
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Color3.new(1, 1, 1)
	scroll.ScrollBarImageTransparency = 0.8
	scroll.ScrollingDirection = if sideways then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y
	scroll.AutomaticCanvasSize = if sideways then Enum.AutomaticSize.X else Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Active = true
	scroll.Parent = holder
	if sideways then
		Kit.pad(scroll, 3, 6, 8, 3)
	else
		Kit.pad(scroll, 3, 8, 6, 3)
	end
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellPadding = UDim2.fromOffset(gap, gap)
	if sideways then
		-- Down one cell, then the next column: one row going right.
		grid.FillDirection = Enum.FillDirection.Vertical
		grid.FillDirectionMaxCells = 1
	end
	grid.Parent = scroll

	-- At an end with more past it, the list fades into what is under it:
	-- the panel's own colour (Kit.panel's gradient, near its top and its
	-- foot), or a shade's black, never quite solid as the shade is not.
	local fadeH = if ctx.touch then 18 else 24
	local onShade = m.backdrop == "shade"
	local function fade(name: string, atStart: boolean): Frame
		local color = if onShade
			then Color3.new(0, 0, 0)
			elseif atStart then Kit.C.panelTop:Lerp(Kit.C.panelBottom, 0.2)
			else Kit.C.panelTop:Lerp(Kit.C.panelBottom, 0.85)
		local solid = if onShade then 0.25 else 0
		local f = Kit.frame(holder, name, color, 0)
		if sideways then
			f.AnchorPoint = Vector2.new(if atStart then 0 else 1, 0)
			f.Position = UDim2.fromScale(if atStart then 0 else 1, 0)
			f.Size = UDim2.new(0, fadeH, 1, 0)
		else
			f.AnchorPoint = Vector2.new(0, if atStart then 0 else 1)
			f.Position = UDim2.fromScale(0, if atStart then 0 else 1)
			f.Size = UDim2.new(1, 0, 0, fadeH)
		end
		f.ZIndex = 5
		f.Visible = false
		local g = Instance.new("UIGradient")
		g.Rotation = if sideways then 0 else 90
		g.Transparency = if atStart then NumberSequence.new(solid, 1) else NumberSequence.new(1, solid)
		g.Parent = f
		return f
	end
	local topFade = fade("FadeStart", true)
	local bottomFade = fade("FadeEnd", false)

	local boxes: { { e: Types.Entry, box: Box } } = {}
	-- Measured on the boxes themselves, in screen pixels (CanvasPosition
	-- and AbsoluteCanvasSize disagree under the layout's UIScale).
	local function edges()
		local first, last = boxes[1], boxes[#boxes]
		if not first or not last then
			topFade.Visible = false
			bottomFade.Visible = false
			return
		end
		local a = if sideways then 1 else 2 -- the axis it scrolls along
		local p0 = if a == 1 then scroll.AbsolutePosition.X else scroll.AbsolutePosition.Y
		local p1 = p0 + (if a == 1 then scroll.AbsoluteSize.X else scroll.AbsoluteSize.Y)
		local f, l = first.box.root, last.box.root
		local fStart = if a == 1 then f.AbsolutePosition.X else f.AbsolutePosition.Y
		local lEnd = if a == 1 then l.AbsolutePosition.X + l.AbsoluteSize.X else l.AbsolutePosition.Y + l.AbsoluteSize.Y
		topFade.Visible = fStart < p0 - 1
		bottomFade.Visible = lEnd > p1 + 1
	end
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(edges)
	scroll:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(edges)
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(edges)

	return {
		root = holder,
		scroll = scroll,
		fill = function(entries: { Types.Entry })
			for _, b in boxes do
				b.box.root:Destroy()
			end
			table.clear(boxes)
			local block = m.block
			if block then
				grid.CellSize = UDim2.fromOffset(block, block)
			else
				local tiles = #entries > 0 and entries[1].shape == "swatch" and not m.rows
				local cols = if tiles then swatchCols else rowCols
				grid.CellSize = UDim2.new(1 / cols, -math.ceil(gap * (cols - 1) / cols), 0, if tiles then tileH else rowH)
			end
			for i, e in entries do
				local box = Parts.box(scroll, e, m)
				box.root.LayoutOrder = i
				ctx.tap(box.root, scroll, function()
					ctx.act.entry(e)
				end, box.press)
				table.insert(boxes, { e = e, box = box })
			end
			scroll.CanvasPosition = Vector2.zero
			-- The grid places the new boxes on the next layout pass.
			task.defer(edges)
		end,
		refresh = function()
			for _, b in boxes do
				b.box.paint(ctx.stateOf(b.e))
			end
		end,
		pop = function(key: string)
			for _, b in boxes do
				if b.e.key == key then
					b.box.pop()
				end
			end
		end,
	}
end

-- The line naming what the action is for: the item picked and how it
-- stands (Previewing, On your Kamri), over or beside the action. Not on
-- MY CARS: the car's name is over the car already (the owner's phone,
-- 2026-10-12: Kamri three times on one screen).
export type FootLine = { root: Frame, set: (foot: Types.Foot) -> () }
function Parts.footLine(parent: Instance, h: number, size: number, noteSize: number): FootLine
	local foot = Kit.frame(parent, "Foot")
	foot.Size = UDim2.new(1, 0, 0, h)
	Kit.list(foot, false, 8, Enum.VerticalAlignment.Center)
	local name = Kit.text(foot, "Name", "", size, Enum.FontWeight.Heavy, true)
	name.RichText = true
	name.AutomaticSize = Enum.AutomaticSize.X
	name.Size = UDim2.fromScale(0, 1)
	name.TextTruncate = Enum.TextTruncate.None
	local note = Kit.text(foot, "Note", "", noteSize, Enum.FontWeight.SemiBold, false, Kit.C.sub)
	note.LayoutOrder = 1
	note.Size = UDim2.fromScale(0, 1)
	Kit.fill(note)
	return {
		root = foot,
		set = function(f: Types.Foot)
			foot.Visible = f.name ~= "" and f.action ~= "drive"
			name.Text = if f.rare then `<font color="#{Parts.C.dusk:ToHex()}">◆</font> {f.name}` else f.name
			note.Text = f.note
		end,
	}
end

------------------------------------------------------------------------
-- Sub-tabs: the picker's slanted tabs, or words with a green underline.
------------------------------------------------------------------------

export type Picker = { root: Frame, set: (id: string) -> () }

-- Slanted tabs sharing `width` (or each as wide as its word).
function Parts.slants(parent: Instance, ctx: Types.Ctx, defs: { Types.ViewDef }, h: number, size: number, gap: number, width: number?): Picker
	local tabDefs: { Kit.TabDef } = {}
	for _, d in defs do
		local w = if width then math.floor((width - gap * (#defs - 1)) / #defs) else math.floor(#d.label * size * 0.8 + size * 2)
		table.insert(tabDefs, { id = d.id, label = d.label, width = w })
	end
	local t = Kit.tabs(parent, tabDefs, h, size, gap, function(id: string)
		if not ctx.busy() then
			ctx.act.view(id)
		end
	end)
	return t
end

-- Words, the chosen one bigger and white with a slanted green underline.
function Parts.words(parent: Instance, ctx: Types.Ctx, defs: { Types.ViewDef }, h: number, size: number, sizeOn: number, gap: number): Picker
	local row = Kit.frame(parent, "Words")
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Size = UDim2.fromOffset(0, h)
	Kit.list(row, false, gap, Enum.VerticalAlignment.Center)
	local items: { [string]: { label: TextButton, bar: Frame } } = {}
	for i, d in defs do
		local b = Instance.new("TextButton")
		b.Name = "Word_" .. d.id
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.AutomaticSize = Enum.AutomaticSize.X
		b.Size = UDim2.fromOffset(0, h)
		b.Text = d.label
		b.TextSize = size
		b.LayoutOrder = i
		local bar = Kit.frame(b, "Bar", Kit.C.green, 0)
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.new(0, 0, 1, -math.floor(h * 0.16))
		bar.Size = UDim2.new(1, 0, 0, 3)
		bar.Rotation = 0
		Kit.corner(bar, 2)
		b.Activated:Connect(function()
			if not ctx.busy() then
				ctx.act.view(d.id)
			end
		end)
		b.Parent = row
		items[d.id] = { label = b, bar = bar }
	end
	return {
		root = row,
		set = function(id: string)
			for key, it in items do
				local on = key == id
				it.label.FontFace = Kit.font(if on then Enum.FontWeight.Heavy else Enum.FontWeight.ExtraBold, true)
				it.label.TextSize = if on then sizeOn else size
				it.label.TextColor3 = if on then Kit.C.text else Kit.C.sub
				it.bar.Visible = on
			end
		end,
	}
end

------------------------------------------------------------------------
-- Categories: a rail of words (Showcase, Shade) or the dock's tabs.
------------------------------------------------------------------------

-- A column of words, the chosen one white and bigger with a green bar
-- beside it, its Arabic after it when `arabic`.
function Parts.wordRail(parent: Instance, ctx: Types.Ctx, rowH: number, size: number, sizeOn: number, arabic: boolean): Picker
	local col = Kit.frame(parent, "Rail")
	col.AutomaticSize = Enum.AutomaticSize.Y
	col.Size = UDim2.fromScale(1, 0)
	Kit.list(col, true, 0)
	local items: { [string]: { b: TextButton, word: TextLabel, ar: TextLabel?, bar: Frame } } = {}
	for i, d in ctx.tabs do
		local b = Instance.new("TextButton")
		b.Name = "Tab_" .. d.id
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.Text = ""
		b.Size = UDim2.new(1, 0, 0, rowH)
		b.LayoutOrder = i
		local bar = Kit.frame(b, "Bar", Kit.C.green, 0)
		bar.AnchorPoint = Vector2.new(0, 0.5)
		bar.Position = UDim2.fromScale(0, 0.5)
		bar.Size = UDim2.new(0, 4, 0.5, 0)
		Kit.corner(bar, 2)
		local line = Kit.frame(b, "Line")
		line.Position = UDim2.fromOffset(math.floor(size * 1.1), 0)
		line.Size = UDim2.new(1, -math.floor(size * 1.1), 1, 0)
		Kit.list(line, false, math.floor(size * 0.5), Enum.VerticalAlignment.Center)
		local w = Kit.text(line, "Word", d.label, size, Enum.FontWeight.ExtraBold, true, Kit.C.sub)
		w.AutomaticSize = Enum.AutomaticSize.X
		w.Size = UDim2.fromScale(0, 1)
		w.TextTruncate = Enum.TextTruncate.None
		local ar: TextLabel? = nil
		if arabic then
			-- As big as the word, like the dock's chosen tab (a title's
			-- 1.15 runs SUN STRIPS out of the rail).
			local a = Kit.text(line, "Arabic", d.arabic, sizeOn, Enum.FontWeight.Bold, false, Parts.C.sand)
			a.LayoutOrder = 1
			a.AutomaticSize = Enum.AutomaticSize.X
			a.Size = UDim2.fromScale(0, 1)
			a.TextTruncate = Enum.TextTruncate.None
			ar = a
		end
		b.Activated:Connect(function()
			if not ctx.busy() then
				ctx.act.tab(d.id)
			end
		end)
		b.Parent = col
		items[d.id] = { b = b, word = w, ar = ar, bar = bar }
	end
	return {
		root = col,
		set = function(id: string)
			for key, it in items do
				local on = key == id
				it.word.FontFace = Kit.font(if on then Enum.FontWeight.Heavy else Enum.FontWeight.ExtraBold, true)
				it.word.TextSize = if on then sizeOn else size
				it.word.TextColor3 = if on then Kit.C.text else Kit.C.sub
				it.bar.Visible = on
				local a = it.ar
				if a then
					a.Visible = on
				end
			end
		end,
	}
end

-- The dock's tabs (Dock): slanted, the chosen one green and wide with its
-- word and Arabic beside the icon, the rest the icon over a small word.
-- They share `width` between them, the chosen one `wOn` of it, so the dock
-- has no hole between them and its buttons on a wide phone (the owner,
-- 2026-10-12: "the bottom dock needs some centering work").
function Parts.dockTabs(parent: Instance, ctx: Types.Ctx, h: number, wOn: number, width: number, size: number, gap: number): Picker
	local row = Kit.frame(parent, "Tabs")
	row.Size = UDim2.fromOffset(width, h)
	Kit.list(row, false, gap, Enum.VerticalAlignment.Center)
	type Item = { b: ImageButton, g: UIGradient, icon: ImageLabel, word: TextLabel, ar: TextLabel }
	local items: { [string]: Item } = {}
	local n = #ctx.tabs
	local wOff = math.floor((width - wOn - gap * (n - 1)) / (n - 1))
	-- The rounding's few pixels go to the chosen tab, so the row ends flush.
	local wChosen = width - gap * (n - 1) - wOff * (n - 1)
	local iconS = math.floor(h * 0.56)
	-- The tab leans (Art.tab, 16 degrees): a thing at height fraction `f`
	-- sits this far right of the box's middle to sit in the middle of the
	-- slanted shape (an icon centred on the box read as left of it).
	local lean = math.tan(math.rad(16)) * h
	local function along(f: number): number
		return math.floor((0.5 - f) * lean + 0.5)
	end
	for i, d in ctx.tabs do
		local b = Instance.new("ImageButton")
		b.Name = "Tab_" .. d.id
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.Image = Art.tab
		b.ScaleType = Enum.ScaleType.Slice
		b.SliceCenter = Art.tabSlice
		b.SliceScale = h / Art.tabH
		b.Size = UDim2.fromOffset(wOff, h)
		b.LayoutOrder = i
		local g = Kit.gradient(b, Kit.C.greenTop, Kit.C.greenBottom)
		local icon = Parts.icon(b, d.icon, iconS)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		local word = Kit.text(b, "Word", d.label, size, Enum.FontWeight.ExtraBold, true, Kit.C.tabInk)
		word.TextTruncate = Enum.TextTruncate.None
		local ar = Kit.text(b, "Arabic", d.arabic, math.floor(size * 1.4), Enum.FontWeight.Bold, false)
		ar.TextTruncate = Enum.TextTruncate.None
		b.Activated:Connect(function()
			if not ctx.busy() then
				ctx.act.tab(d.id)
			end
		end)
		b.Parent = row
		items[d.id] = { b = b, g = g, icon = icon, word = word, ar = ar }
	end
	return {
		root = row,
		set = function(id: string)
			for key, it in items do
				local on = key == id
				it.g.Enabled = on
				it.b.ImageTransparency = if on then 0 else 0.93
				it.b.Size = UDim2.fromOffset(if on then wChosen else wOff, h)
				it.ar.Visible = on
				if on then
					local x = math.floor(h * 0.5) + math.floor(iconS * 0.6)
					it.icon.Position = UDim2.new(0, math.floor(h * 0.5), 0.5, 0)
					it.icon.ImageColor3 = Kit.C.text
					it.word.AnchorPoint = Vector2.new(0, 1)
					it.word.Position = UDim2.new(0, x + along(0.36), 0.5, 2)
					it.word.Size = UDim2.new(1, -(x + 6), 0, size + 6)
					it.word.TextXAlignment = Enum.TextXAlignment.Left
					it.word.TextSize = math.floor(size * 1.45)
					it.word.FontFace = Kit.font(Enum.FontWeight.Heavy, true)
					it.word.TextColor3 = Kit.C.text
					it.ar.Position = UDim2.new(0, x + along(0.68), 0.5, 2)
					it.ar.Size = UDim2.new(1, -(x + 6), 0, size + 8)
					it.ar.TextColor3 = Kit.C.text
				else
					it.icon.Position = UDim2.new(0.5, along(0.4), 0.4, 0)
					it.icon.ImageColor3 = Kit.C.tabInk
					it.word.AnchorPoint = Vector2.new(0.5, 0.5)
					it.word.Position = UDim2.new(0.5, along(0.78), 0.78, 0)
					it.word.Size = UDim2.new(1, -4, 0, size + 2)
					it.word.TextXAlignment = Enum.TextXAlignment.Center
					it.word.TextSize = size
					it.word.FontFace = Kit.font(Enum.FontWeight.ExtraBold, true)
					it.word.TextColor3 = Kit.C.tabInk
				end
			end
		end,
	}
end

------------------------------------------------------------------------
-- The action button: BUY (sodium) with the price, DRIVE THIS (green), or
-- ON YOUR CAR (grey, nothing to do).
------------------------------------------------------------------------

export type ActionButton = { root: ImageButton, set: (foot: Types.Foot) -> () }

function Parts.action(parent: Instance, ctx: Types.Ctx, w: number, h: number, size: number): ActionButton
	local b = Instance.new("ImageButton")
	b.Name = "Action"
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Image = Art.button
	b.ScaleType = Enum.ScaleType.Slice
	b.SliceCenter = Art.buttonSlice
	b.SliceScale = h / Art.buttonH
	b.Size = UDim2.fromOffset(w, h)
	local t = Kit.text(b, "Label", "", size, Enum.FontWeight.Heavy, true)
	t.Size = UDim2.fromScale(1, 1)
	t.TextXAlignment = Enum.TextXAlignment.Center
	t.RichText = true
	local live = false
	b.Activated:Connect(function()
		if live and not ctx.busy() then
			ctx.act.action()
		end
	end)
	b.Parent = parent
	return {
		root = b,
		set = function(foot: Types.Foot)
			local a = foot.action
			b.Visible = a ~= "none"
			live = a == "buy" or a == "drive"
			b.ImageTransparency = 0
			if a == "buy" then
				b.ImageColor3 = Parts.C.sodium
				t.TextColor3 = Parts.C.buyInk
				t.TextStrokeTransparency = 1
				t.Text = `BUY  <font face="Oswald" weight="bold">{Parts.money(foot.price)}</font>`
			elseif a == "drive" then
				b.ImageColor3 = Kit.C.greenTop
				t.TextColor3 = Kit.C.text
				t.TextStrokeColor3 = Color3.fromRGB(0, 60, 30)
				t.TextStrokeTransparency = 0.75
				t.Text = "DRIVE THIS"
			else
				b.ImageColor3 = Parts.C.grey
				b.ImageTransparency = 0.55
				t.TextColor3 = Kit.C.tabInk
				t.TextStrokeTransparency = 1
				t.Text = "ON YOUR CAR"
			end
		end,
	}
end

------------------------------------------------------------------------
-- The confirm sheet: what you are buying, the price, your cash and what is
-- left, CANCEL and BUY. Nothing is charged from one tap (UI_SYSTEM.md).
------------------------------------------------------------------------

export type SheetInfo = { title: string, name: string, rare: boolean, what: string, price: number, entry: Types.Entry? }
export type Sheet = { holder: Frame, update: (cash: number, working: boolean) -> () }

function Parts.sheet(gui: ScreenGui, ctx: Types.Ctx, info: SheetInfo, onCancel: () -> (), onBuy: () -> ()): Sheet
	local holder = Kit.frame(gui, "ConfirmSheet")
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 20
	-- The dim covers the whole screen, under Roblox's top bar and into a
	-- notch's strip.
	local scrim = Kit.frame(holder, "Scrim", Color3.new(0, 0, 0), 0.45)
	UIKit.edgeToEdge(scrim, gui)
	scrim.Active = true
	scrim.ZIndex = 20
	local s = Parts.scaleFor(ctx.touch, ctx.screen)
	local body = Kit.frame(holder, "Body")
	body.AnchorPoint = Vector2.new(1, 1)
	body.Position = UDim2.new(1, -math.floor(12 * s), 1, -math.floor(12 * s))
	body.ZIndex = 21
	local scale = Instance.new("UIScale")
	scale.Scale = s
	scale.Parent = body
	local w = if ctx.touch then 330 else 400
	local p, inner = Kit.panel(body, "Panel", 16)
	p.Size = UDim2.fromOffset(w, 0)
	p.AutomaticSize = Enum.AutomaticSize.Y
	p.BackgroundTransparency = 0
	inner.Size = UDim2.fromOffset(w, 0)
	inner.AutomaticSize = Enum.AutomaticSize.Y
	Kit.pad(inner, 14, 14, 14, 14)
	Kit.list(inner, true, 10)
	body.Size = UDim2.fromOffset(w, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	local size = if ctx.touch then 1 else 1.15

	local head = Kit.frame(inner, "Head")
	head.LayoutOrder = 1
	head.Size = UDim2.new(1, 0, 0, math.floor(22 * size))
	Kit.list(head, false, 8, Enum.VerticalAlignment.Center)
	local t = Kit.text(head, "Title", info.title, math.floor(17 * size), Enum.FontWeight.Heavy, true)
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.fromScale(0, 1)
	t.TextTruncate = Enum.TextTruncate.None
	local ar = Kit.text(head, "Arabic", "شراء", Parts.arabicSize(math.floor(17 * size)), Enum.FontWeight.Bold, false, Parts.C.sand)
	ar.LayoutOrder = 1
	ar.AutomaticSize = Enum.AutomaticSize.X
	ar.Size = UDim2.fromScale(0, 1)

	local mid = Kit.frame(inner, "Item")
	mid.LayoutOrder = 2
	mid.Size = UDim2.new(1, 0, 0, math.floor(64 * size))
	local swatchS = math.floor(54 * size)
	local e = info.entry
	if e then
		local sw = Kit.frame(mid, "Swatch", Color3.new(1, 1, 1), 0)
		sw.AnchorPoint = Vector2.new(0, 0.5)
		sw.Position = UDim2.fromScale(0, 0.5)
		sw.ClipsDescendants = true
		if e.shape == "swatch" then
			sw.Size = UDim2.fromOffset(swatchS, swatchS)
			Kit.corner(sw, math.floor(swatchS / 2))
		else
			sw.Size = UDim2.fromOffset(math.floor(swatchS * 1.6), math.floor(swatchS * 0.8))
			Kit.corner(sw, 6)
		end
		Kit.stroke(sw, Color3.new(1, 1, 1), 1, 0.8)
		e.draw(sw)
		if e.shape == "swatch" then
			roundChildren(sw, math.floor(swatchS / 2))
		end
	end
	local swW = if e then (if e.shape == "swatch" then swatchS else math.floor(swatchS * 1.6)) + 14 else 0
	local rows = Kit.frame(mid, "Rows")
	rows.Position = UDim2.fromOffset(swW, 0)
	rows.Size = UDim2.new(1, -swW, 1, 0)
	Kit.list(rows, true, 2, Enum.VerticalAlignment.Center)
	local function row(order: number, label: string): TextLabel
		local r = Kit.frame(rows, "Row" .. order)
		r.LayoutOrder = order
		r.Size = UDim2.new(1, 0, 0, math.floor(18 * size))
		local l = Kit.text(r, "Label", label, math.floor(11 * size), Enum.FontWeight.SemiBold, false, Kit.C.tabInk)
		l.RichText = true
		l.Size = UDim2.new(0.6, 0, 1, 0)
		local v = Kit.text(r, "Value", "", math.floor(15 * size), Enum.FontWeight.SemiBold, false)
		v.FontFace = Parts.num()
		v.AnchorPoint = Vector2.new(1, 0)
		v.Position = UDim2.fromScale(1, 0)
		v.Size = UDim2.new(0.4, 0, 1, 0)
		v.TextXAlignment = Enum.TextXAlignment.Right
		return v
	end
	local nameRow = Kit.text(rows, "Name", "", math.floor(13 * size), Enum.FontWeight.ExtraBold, true)
	nameRow.LayoutOrder = 0
	nameRow.RichText = true
	nameRow.Size = UDim2.new(1, 0, 0, math.floor(18 * size))
	nameRow.Text = if info.rare then `<font color="#{Parts.C.dusk:ToHex()}">◆</font> {info.name}` else info.name
	local priceV = row(1, "Price")
	local cashV = row(2, "Your cash")
	local afterV = row(3, "After")
	priceV.TextColor3 = Parts.C.sodium

	local what = Kit.text(inner, "What", info.what, math.floor(11 * size), Enum.FontWeight.SemiBold, false, Kit.C.sub)
	what.LayoutOrder = 3
	what.Size = UDim2.new(1, 0, 0, math.floor(15 * size))

	local buttons = Kit.frame(inner, "Buttons")
	buttons.LayoutOrder = 4
	local bh = math.floor(46 * size)
	buttons.Size = UDim2.new(1, 0, 0, bh)
	Kit.list(buttons, false, 8, Enum.VerticalAlignment.Center)
	local cancel = Instance.new("TextButton")
	cancel.Name = "Cancel"
	cancel.AutoButtonColor = false
	cancel.BorderSizePixel = 0
	cancel.BackgroundColor3 = Color3.new(1, 1, 1)
	cancel.BackgroundTransparency = 0.92
	cancel.Size = UDim2.new(0.5, -4, 1, 0)
	cancel.Text = "CANCEL"
	cancel.TextSize = math.floor(13 * size)
	cancel.TextColor3 = Kit.C.text
	cancel.FontFace = Kit.font(Enum.FontWeight.ExtraBold, true)
	Kit.corner(cancel, 10)
	Kit.stroke(cancel, Color3.new(1, 1, 1), 1, 0.85)
	cancel.Parent = buttons
	local buy = Instance.new("ImageButton")
	buy.Name = "Buy"
	buy.LayoutOrder = 1
	buy.AutoButtonColor = false
	buy.BackgroundTransparency = 1
	buy.Image = Art.button
	buy.ScaleType = Enum.ScaleType.Slice
	buy.SliceCenter = Art.buttonSlice
	buy.SliceScale = bh / Art.buttonH
	buy.ImageColor3 = Parts.C.sodium
	buy.Size = UDim2.new(0.5, -4, 1, 0)
	local buyLabel = Kit.text(buy, "Label", "BUY", math.floor(15 * size), Enum.FontWeight.Heavy, true, Parts.C.buyInk)
	buyLabel.Size = UDim2.fromScale(1, 1)
	buyLabel.TextXAlignment = Enum.TextXAlignment.Center
	buy.Parent = buttons

	local working, lacking = false, false
	cancel.Activated:Connect(function()
		if not working then
			onCancel()
		end
	end)
	buy.Activated:Connect(function()
		if not working and not lacking then
			onBuy()
		end
	end)
	return {
		holder = holder,
		update = function(cash: number, busy: boolean)
			working = busy
			local short = info.price - cash
			lacking = short > 0
			priceV.Text = Parts.money(info.price)
			cashV.Text = Parts.money(cash)
			afterV.Text = if lacking then `Short {Parts.money(short)}` else Parts.money(cash - info.price)
			afterV.TextColor3 = if lacking then Parts.C.beacon else Kit.C.text
			buy.ImageTransparency = if lacking or busy then 0.55 else 0
			buyLabel.Text = if busy then "…" else "BUY"
			cancel.TextTransparency = if busy then 0.5 else 0
		end,
	}
end

------------------------------------------------------------------------
-- The toast: a result, for a moment, at the top middle.
------------------------------------------------------------------------

export type Toast = (text: string, kind: string) -> ()

function Parts.toast(gui: ScreenGui, ctx: Types.Ctx): Toast
	local s = Parts.scaleFor(ctx.touch, ctx.screen)
	local holder = Kit.frame(gui, "Toast")
	holder.AnchorPoint = Vector2.new(0.5, 0)
	-- Under the layouts' top rows (GARAGE, the cash).
	holder.Position = UDim2.new(0.5, 0, 0, math.floor(66 * s))
	holder.AutomaticSize = Enum.AutomaticSize.XY
	holder.ZIndex = 30
	holder.Visible = false
	local scale = Instance.new("UIScale")
	scale.Scale = s
	scale.Parent = holder
	local pill = Kit.frame(holder, "Pill", Kit.C.panelTop, 0.05)
	pill.AutomaticSize = Enum.AutomaticSize.XY
	pill.ZIndex = 30
	Kit.corner(pill, 10)
	Kit.stroke(pill, Color3.new(1, 1, 1), 1, 0.88)
	Kit.pad(pill, 8, 14, 8, 14)
	local label = Kit.text(pill, "Label", "", if ctx.touch then 13 else 15, Enum.FontWeight.ExtraBold, true)
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.new()
	label.TextTruncate = Enum.TextTruncate.None
	label.ZIndex = 30
	local serial = 0
	return function(text: string, kind: string)
		serial += 1
		local mine = serial
		if kind == "done" then
			pill.BackgroundColor3 = Kit.C.panelTop
			label.TextColor3 = Kit.C.green
			label.Text = "✓ " .. text
		elseif kind == "error" then
			pill.BackgroundColor3 = Parts.C.beaconGround
			label.TextColor3 = Kit.C.text
			label.Text = text
		else
			pill.BackgroundColor3 = Kit.C.panelTop
			label.TextColor3 = Parts.C.sand
			label.Text = text
		end
		holder.Visible = true
		task.delay(3, function()
			if serial == mine then
				holder.Visible = false
			end
		end)
	end
end

return Parts
