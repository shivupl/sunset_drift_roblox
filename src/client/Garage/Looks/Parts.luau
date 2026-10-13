--!strict
-- The garage layouts' shared pieces, in the car picker's look
-- (CarPicker/Kit, UI_SYSTEM.md "The car picker"), so the garage matches the
-- CARS menu (the owner, 2026-10-11: "make every single menu UI coherent"):
-- graphite panels, heavy italic Montserrat, slanted tabs, items in the
-- picker's cut-corner box with the chosen one edged green. Money is the
-- sodium of the HUD's coin: prices, BUY and the confirm sheet's BUY; green
-- is go and yours (DRIVE THIS, ON CAR, OWNED, what shows on the car).
-- The category icons are art/garage.
--
-- The menu (CARS, PLATES, SETTINGS) draws through these layouts too
-- (ui-flow, 2026-10-12), so this is every phone screen's kit: the same
-- words, buttons, coins, action and motion wherever a player is.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UITheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local Client = script.Parent.Parent.Parent
local CarPicker = Client:WaitForChild("CarPicker")
local Kit = require(CarPicker:WaitForChild("Kit"))
local Art = require(CarPicker:WaitForChild("Art"))
local UIKit = require(Client:WaitForChild("UIKit"))
local LayoutD = require(Client:WaitForChild("HudLab"):WaitForChild("LayoutD"))
local HudLab = require(Client:WaitForChild("HudLab"))
local Types = require(script.Parent:WaitForChild("Types"))

local Parts = {}

-- art/garage/out/garage_icons.png, 128 px cells.
Parts.ICONS = "rbxassetid://71924428072059"
Parts.ICON_CELL = 128
Parts.ICON = { cars = 0, paint = 1, rims = 2, plates = 3, lights = 4, decal = 5, exhaust = 6, layout = 7 }
-- The top bar's sheet (art/topbar, 128 px cells): GARAGE, RESET, VIEW,
-- STYLE, SETTINGS; the menu's SETTINGS word wears its gear.
Parts.TOPBAR_ICONS = "rbxassetid://115983636701904"
Parts.TOPBAR_ICON = { garage = 0, reset = 1, view = 2, style = 3, settings = 4 }
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
	-- EXIT's tint of the action's shape: the tiles' graphite, a step up so
	-- it holds on the words' shade.
	graphite = Color3.fromHex("#3A3D44"),
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

-- The screen a controller lays its layout out for: the gui's size, or in
-- Studio the LocalPlayer attribute ScreenSim (a Vector2, a phone's pixels:
-- 844x346 is the reference phone under Roblox's top bar), so a phone's
-- proportions can be checked in Studio's wider, taller viewport. The
-- layout is then drawn at the gui's top left at that size.
function Parts.screen(gui: ScreenGui): Vector2
	local sim = Players.LocalPlayer:GetAttribute("ScreenSim")
	if typeof(sim) == "Vector2" and RunService:IsStudio() then
		return sim
	end
	return gui.AbsoluteSize
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

-- An icon from the garage sheet (or another sheet of 128 px cells).
function Parts.icon(parent: Instance, index: number, size: number, color: Color3?, sheet: string?): ImageLabel
	local i = Kit.image(parent, "Icon", sheet or Parts.ICONS, color or Kit.C.text)
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

-- The place (GARAGE, HAJWALA) and its Arabic, side by side.
function Parts.title(parent: Instance, size: number, title: { en: string, ar: string }?): Frame
	local words = title or { en = "GARAGE", ar = "كراج" }
	local f = Kit.frame(parent, "Title")
	f.AutomaticSize = Enum.AutomaticSize.X
	f.Size = UDim2.fromOffset(0, size + 4)
	Kit.list(f, false, math.floor(size * 0.4), Enum.VerticalAlignment.Center)
	local en = Kit.text(f, "English", words.en, size, Enum.FontWeight.Heavy, true)
	en.AutomaticSize = Enum.AutomaticSize.X
	en.Size = UDim2.fromScale(0, 1)
	en.TextTruncate = Enum.TextTruncate.None
	local ar = Kit.text(f, "Arabic", words.ar, Parts.arabicSize(size), Enum.FontWeight.Bold, false, Parts.C.sand)
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

-- The cash where the driving HUD has it, drawn as the HUD draws it
-- (HudLab.coins: its coin, its chip, its digits, in its finish), in a gui
-- set up as the HUD's, so the coins neither move nor change between
-- driving, the menu and the garage (the owner, 2026-10-12: "make sure the
-- coins thing stays in the same position as usuall"; ui-flow: the garage
-- had its own Oswald pill and the menu none).
function Parts.hudCash(name: string, displayOrder: number, parent: Instance): (ScreenGui, Cash)
	local g = Instance.new("ScreenGui")
	g.Name = name
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = displayOrder
	local coins = HudLab.coins(g)
	g.Parent = parent
	return g, { root = coins.root, set = coins.set }
end

-- Where the cash pill's right edge and foot fall in `panel`'s pixels, for
-- the right side to line up under it (the owner, 2026-10-12: "move them
-- more to the right and slightly higher just to align more with other
-- elements"). The HUD's gui keeps out of the device's notch only, the
-- panel's out of Roblox's own margins too, so on a phone the coins sit
-- right of the panel's edge. X: the guis' AbsolutePositions share one
-- space. Y: the cash's gui starts at the screen's top, the panel's under
-- the top bar (GetGuiInset), so the foot can be above the panel's top.
function Parts.coinAnchor(panel: ScreenGui, cash: ScreenGui): Vector2
	local h = cash.AbsoluteSize.Y
	local right = cash.AbsolutePosition.X + cash.AbsoluteSize.X - LayoutD.EDGE_R * h - panel.AbsolutePosition.X
	local inset = GuiService:GetGuiInset()
	return Vector2.new(right, (LayoutD.CASH_Y + LayoutD.CASH_H) * h - inset.Y)
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

-- EXIT: a cross and the word, side by side, on the action's slanted
-- shape in graphite (the owner's phone, 2026-10-12: "ensure the exit
-- button is aligned properly and stylized appropriately"; a rounded box
-- beside the slanted BUY read as two kits). It is the action's height on
-- the action's line, so the bottom row reads as one.
function Parts.exit(parent: Instance, w: number, h: number, size: number): ImageButton
	local b = Instance.new("ImageButton")
	b.Name = "Exit"
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Image = Art.button
	b.ScaleType = Enum.ScaleType.Slice
	b.SliceCenter = Art.buttonSlice
	b.SliceScale = h / Art.buttonH
	b.ImageColor3 = Parts.C.graphite
	b.ImageTransparency = 0.06
	b.Size = UDim2.fromOffset(w, h)
	b.Parent = parent
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

-- A shade from one side of the screen (left or right) for words or items
-- to sit on: dark at the edge, clear `tail` past `reach` into the
-- gui. It starts half a screen out and the gui stops clipping to the safe
-- area, so it meets the screen's edge beside any notch (UIKit.edgeToEdge;
-- the owner, 2026-10-12: "no wierd gap for any device"). Its fade is
-- SHOWCASE's first shade's: solid to 60 px outside the gui, 0.45 a little
-- past `reach`, clear at the end. Drags pass through it (PassThrough).
export type Edge = "left" | "right"
function Parts.edgeShade(gui: ScreenGui, root: Frame, room: Vector2, side: Edge, reach: number, tail: number): Frame
	gui.ClipToDeviceSafeArea = false
	local bleed = math.floor(room.X * 0.5)
	local total = bleed + reach + tail
	local fadeW = reach + 60 + tail
	local shade = Kit.frame(root, "Shade_" .. side, Color3.new(0, 0, 0), 0)
	if side == "left" then
		shade.Position = UDim2.fromOffset(-bleed, -math.floor(room.Y * 0.5))
		shade.Size = UDim2.fromOffset(total, room.Y * 2)
	else
		shade.Position = UDim2.fromOffset(room.X - reach - tail, -math.floor(room.Y * 0.5))
		shade.Size = UDim2.fromOffset(total, room.Y * 2)
	end
	shade:SetAttribute("PassThrough", true)
	local solid = (bleed - 60) / total
	local g = Instance.new("UIGradient")
	-- Keypoint 0 at the screen's edge.
	g.Rotation = if side == "left" then 0 else 180
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
	-- What is under the list, for the fades at its ends: a panel (the
	-- default) or a shade (the SHOWCASE variants without a panel).
	backdrop: ("panel" | "shade")?,
	-- The rail in place of the fades (GLASS on a phone; the owner,
	-- 2026-10-12: "remove the scroll shaddow ... add an obvious
	-- scroll/updown for the options"): Parts.scroller.
	scroller: ScrollKind?,
	-- Blocks sized so the list shows whole rows, never a sliver of the next
	-- (the owner's phone, 2026-10-12: with the fades gone a cut row read as
	-- broken): as many rows as fit at `block`, each a little smaller if
	-- that is what makes them fit, the grid centred in the width it frees.
	fitRows: boolean?,
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
	-- A car's photo is cut out: it stands on the box's own stage, with no
	-- box of its own round it (ui-flow: a box in a box). A car with no
	-- photo keeps its paint swatch.
	e.draw(tile)
	local bare = e.shape == "car" and tile:FindFirstChild("Photo") ~= nil
	if bare then
		tile.BackgroundTransparency = 1
		ring.Enabled = false
	end
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

-- A block list's sideways padding (half each side): what the panel's width
-- loses before its blocks.
Parts.LIST_PAD_X = 12

-- At an end of a scrolling list with more past it, the list fades into
-- what is under it: the panel's own colour (Kit.panel's gradient, near its
-- top and its foot), or a shade's black, never quite solid as the shade is
-- not. The caller shows them (`top`, `bottom`); `watch` does it from a
-- scroll's own canvas (the settings, which have no boxes to measure).
export type Fades = { top: Frame, bottom: Frame, watch: (scroll: ScrollingFrame) -> () }
function Parts.fades(holder: GuiObject, touch: boolean, onShade: boolean): Fades
	local fadeH = if touch then 18 else 24
	local function fade(name: string, atStart: boolean): Frame
		local color = if onShade
			then Color3.new(0, 0, 0)
			elseif atStart then Kit.C.panelTop:Lerp(Kit.C.panelBottom, 0.2)
			else Kit.C.panelTop:Lerp(Kit.C.panelBottom, 0.85)
		local solid = if onShade then 0.25 else 0
		local f = Kit.frame(holder, name, color, 0)
		f.AnchorPoint = Vector2.new(0, if atStart then 0 else 1)
		f.Position = UDim2.fromScale(0, if atStart then 0 else 1)
		f.Size = UDim2.new(1, 0, 0, fadeH)
		f.ZIndex = 5
		f.Visible = false
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = if atStart then NumberSequence.new(solid, 1) else NumberSequence.new(1, solid)
		g.Parent = f
		return f
	end
	local top, bottom = fade("FadeTop", true), fade("FadeBottom", false)
	return {
		top = top,
		bottom = bottom,
		watch = function(scroll: ScrollingFrame)
			local function edges()
				local over = scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y
				top.Visible = scroll.CanvasPosition.Y > 1
				bottom.Visible = over > 1 and scroll.CanvasPosition.Y < over - 1
			end
			scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(edges)
			scroll:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(edges)
			scroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(edges)
			task.defer(edges)
		end,
	}
end

-- An obvious way up and down a list (the owner, 2026-10-12: "add an
-- obvious scroll/updown for the options (make a couple versions)"; of
-- ARROWS, RAIL and MORE tried, they picked RAIL from their phone), in
-- place of the fades; the list still scrolls under a thumb as well: a
-- track down the list's right edge with a green thumb as tall as the share
-- showing, dragged to scroll; chevrons at its ends step a row.
-- `step` is a row in screen pixels (CanvasPosition's units under the
-- layout's UIScale).
export type ScrollKind = "rail"
export type Scroller = { update: () -> (), shown: () -> () }

-- The margin right of the blocks a control takes: the rail's, so its
-- track and chevrons stand clear of them. A layout takes it off the
-- blocks' width (else the grid would wrap to one across).
function Parts.railRoom(kind: ScrollKind?): number
	return if kind == "rail" then 18 else 0
end

local CHEVRON = "›"
local SCROLL_TWEEN = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- A chevron glyph pointing up (-90) or down (90).
local function chevron(parent: Instance, size: number, up: boolean, color: Color3): TextLabel
	local c = Kit.text(parent, "Chevron", CHEVRON, size, Enum.FontWeight.Bold, false, color)
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	c.Position = UDim2.fromScale(0.5, 0.5)
	c.Size = UDim2.fromOffset(size, size)
	c.TextXAlignment = Enum.TextXAlignment.Center
	c.Rotation = if up then -90 else 90
	c.TextTruncate = Enum.TextTruncate.None
	return c
end

function Parts.scroller(holder: GuiObject, scroll: ScrollingFrame, kind: ScrollKind, step: () -> number, touch: boolean): Scroller
	-- The list's own bar would be a second one. Thickness 0 alone still
	-- left a hairline thumb by the blocks (Studio's phone view, 2026-10-12).
	scroll.ScrollBarThickness = 0
	scroll.ScrollBarImageTransparency = 1
	local tween: Tween? = nil
	local function limit(): number
		return math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y)
	end
	local function go(by: number)
		local to = math.clamp(scroll.CanvasPosition.Y + by, 0, limit())
		local t = tween
		if t then
			t:Cancel()
		end
		local nt = TweenService:Create(scroll, SCROLL_TWEEN, { CanvasPosition = Vector2.new(scroll.CanvasPosition.X, to) })
		tween = nt
		nt:Play()
	end
	local update: () -> ()
	do
		local w = if touch then 8 else 9
		local cap = if touch then 24 else 26
		local rail = Kit.frame(holder, "Rail")
		-- In the margin the layout leaves right of the blocks for it
		-- (Parts.railRoom), centred on it.
		rail.AnchorPoint = Vector2.new(0.5, 0)
		rail.Position = UDim2.new(1, -math.floor(Parts.railRoom(kind) / 2) + 2, 0, 0)
		rail.Size = UDim2.new(0, cap, 1, 0)
		rail.ZIndex = 6
		local function capButton(up: boolean): (TextButton, TextLabel)
			local b = Instance.new("TextButton")
			b.Name = if up then "Up" else "Down"
			b.AutoButtonColor = false
			b.Text = ""
			b.BackgroundTransparency = 1
			b.AnchorPoint = Vector2.new(0.5, if up then 0 else 1)
			b.Position = UDim2.fromScale(0.5, if up then 0 else 1)
			b.Size = UDim2.fromOffset(cap, cap)
			b.ZIndex = 7
			local c = chevron(b, cap, up, Kit.C.text)
			c.ZIndex = 7
			b.Activated:Connect(function()
				go(if up then -step() else step())
			end)
			b.Parent = rail
			return b, c
		end
		local _, upC = capButton(true)
		local _, downC = capButton(false)
		local track = Kit.frame(rail, "Track", Color3.new(1, 1, 1), 0.8)
		track.AnchorPoint = Vector2.new(0.5, 0)
		track.Position = UDim2.new(0.5, 0, 0, cap)
		track.Size = UDim2.new(0, w, 1, -2 * cap)
		track.ZIndex = 6
		Kit.corner(track, math.floor(w / 2))
		local thumb = Instance.new("TextButton")
		thumb.Name = "Thumb"
		thumb.AutoButtonColor = false
		thumb.Text = ""
		thumb.BorderSizePixel = 0
		thumb.BackgroundColor3 = Color3.new(1, 1, 1)
		thumb.AnchorPoint = Vector2.new(0.5, 0)
		thumb.ZIndex = 7
		Kit.corner(thumb, math.floor((w + 4) / 2))
		Kit.gradient(thumb, Kit.C.greenTop, Kit.C.greenBottom)
		thumb.Parent = track
		-- A wider hit than it looks, for a thumb.
		local grab = Instance.new("TextButton")
		grab.Name = "Grab"
		grab.AutoButtonColor = false
		grab.Text = ""
		grab.BackgroundTransparency = 1
		grab.AnchorPoint = Vector2.new(0.5, 0)
		grab.Position = UDim2.fromScale(0.5, 0)
		grab.Size = UDim2.new(0, cap + 10, 1, 0)
		grab.ZIndex = 8
		grab.Parent = thumb
		update = function()
			local window, lim = scroll.AbsoluteWindowSize.Y, limit()
			local share = if scroll.AbsoluteCanvasSize.Y > 0 then math.clamp(window / scroll.AbsoluteCanvasSize.Y, 0.15, 1) else 1
			rail.Visible = lim > 1
			local at = if lim > 0 then scroll.CanvasPosition.Y / lim else 0
			thumb.Size = UDim2.new(0, w + 4, share, 0)
			thumb.Position = UDim2.new(0.5, 0, (1 - share) * at, 0)
			upC.TextTransparency = if scroll.CanvasPosition.Y > 1 then 0 else 0.7
			downC.TextTransparency = if scroll.CanvasPosition.Y < lim - 1 then 0 else 0.7
		end
		-- Dragging the thumb: the list follows it along the track.
		local drag: { input: InputObject, y: number, canvas: number }? = nil
		grab.InputBegan:Connect(function(io: InputObject)
			if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then
				drag = { input = io, y = io.Position.Y, canvas = scroll.CanvasPosition.Y }
			end
		end)
		UserInputService.InputChanged:Connect(function(io: InputObject)
			local dr = drag
			if not dr or not holder.Parent then
				return
			end
			if io ~= dr.input and io.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end
			local free = track.AbsoluteSize.Y - thumb.AbsoluteSize.Y
			if free <= 0 then
				return
			end
			local lim = limit()
			local to = dr.canvas + (io.Position.Y - dr.y) * lim / free
			scroll.CanvasPosition = Vector2.new(scroll.CanvasPosition.X, math.clamp(to, 0, lim))
		end)
		UserInputService.InputEnded:Connect(function(io: InputObject)
			local dr = drag
			if dr and (io == dr.input or io.UserInputType == Enum.UserInputType.MouseButton1) then
				drag = nil
			end
		end)
	end
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(update)
	scroll:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(update)
	scroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(update)
	task.defer(update)
	return {
		update = update,
		shown = update,
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
	local holder = Kit.frame(parent, "Items")
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Color3.new(1, 1, 1)
	scroll.ScrollBarImageTransparency = 0.8
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Active = true
	scroll.Parent = holder
	-- Blocks sit centred, the scroll bar in their right margin; a list
	-- keeps its bar clear of the rows.
	local padTop, padBottom = 3, 6
	if m.block then
		Kit.pad(scroll, padTop, Parts.LIST_PAD_X / 2 + Parts.railRoom(m.scroller), padBottom, Parts.LIST_PAD_X / 2)
	else
		Kit.pad(scroll, padTop, 8, padBottom, 3)
	end
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellPadding = UDim2.fromOffset(gap, gap)
	if m.fitRows then
		-- Smaller blocks stay `swatchCols` across, centred.
		grid.FillDirectionMaxCells = swatchCols
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	grid.Parent = scroll

	local fades = Parts.fades(holder, ctx.touch, m.backdrop == "shade")
	local topFade, bottomFade = fades.top, fades.bottom
	local kind: ScrollKind? = m.scroller

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
		local y0 = scroll.AbsolutePosition.Y
		local y1 = y0 + scroll.AbsoluteSize.Y
		local l = last.box.root
		topFade.Visible = kind == nil and first.box.root.AbsolutePosition.Y < y0 - 1
		bottomFade.Visible = kind == nil and l.AbsolutePosition.Y + l.AbsoluteSize.Y > y1 + 1
	end
	-- The up/down control: a row (a cell and the gap) a step.
	local control: Scroller? = nil
	if kind then
		control = Parts.scroller(holder, scroll, kind, function(): number
			-- The padding is drawing pixels; the cell's absolute size says
			-- the scale.
			local cell = grid.AbsoluteCellSize.Y
			local drawn = grid.CellSize.Y.Offset
			return cell + gap * (if drawn > 0 then cell / drawn else 1)
		end, ctx.touch)
	end
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(edges)
	scroll:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(edges)
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(edges)

	-- The block a set is drawn at: `m.block`, or with `fitRows` the size
	-- that shows whole rows in the list's height (in drawing pixels, under
	-- the layout's UIScale). Rows of `block` that fit with a remainder
	-- become one more row, each smaller, if that keeps them to three
	-- quarters of `block`; else the rows stay at `block` and the list ends
	-- under them, the remainder left empty below (`spare`, a padding on
	-- the holder).
	local scale = Parts.scaleFor(ctx.touch, ctx.screen)
	local spare = Instance.new("UIPadding")
	spare.Parent = holder
	local function blockFor(): (number?, number)
		local want = m.block
		if not want or not m.fitRows then
			return want, 0
		end
		local total = holder.AbsoluteSize.Y / scale
		if total < want then
			return want, 0
		end
		-- The rows and the padding round them fill the window, so a set
		-- that fits does not scroll; with more, the next row starts a gap
		-- after the last, past the bottom padding, out of sight.
		local h = total - padTop - padBottom
		local r = math.max(1, math.ceil((h + gap) / (want + gap) - 0.001))
		local b = math.floor((h - (r - 1) * gap) / r)
		if r > 1 and b < want * 0.75 then
			r -= 1
			b = want
		end
		b = math.min(b, want)
		return b, math.max(0, math.floor(total - (padTop + r * b + (r - 1) * gap + padBottom)))
	end

	local shown: { Types.Entry } = {}
	local drawnAt: number? = nil
	local function build(entries: { Types.Entry }, settle: boolean)
		for _, b in boxes do
			b.box.root:Destroy()
		end
		table.clear(boxes)
		shown = entries
		local block, left = blockFor()
		drawnAt = block
		spare.PaddingBottom = UDim.new(0, left)
		local bm = m
		if block then
			grid.CellSize = UDim2.fromOffset(block, block)
			if block ~= m.block then
				bm = table.clone(m)
				bm.block = block
			end
		else
			local tiles = #entries > 0 and entries[1].shape == "swatch" and not m.rows
			local cols = if tiles then swatchCols else rowCols
			grid.CellSize = UDim2.new(1 / cols, -math.ceil(gap * (cols - 1) / cols), 0, if tiles then tileH else rowH)
		end
		for i, e in entries do
			local box = Parts.box(scroll, e, bm)
			box.root.LayoutOrder = i
			ctx.tap(box.root, scroll, function()
				ctx.act.entry(e)
			end, box.press)
			table.insert(boxes, { e = e, box = box })
		end
		scroll.CanvasPosition = Vector2.zero
		-- A new set eases up into place (ui-flow: it had swapped in a
		-- frame, and a tab tap read as a flicker).
		if settle and #entries > 0 then
			Parts.settle(scroll, Parts.LIFT)
		end
		-- The grid places the new boxes on the next layout pass.
		task.defer(edges)
		local c = control
		if c then
			task.defer(c.shown)
		end
	end
	if m.fitRows then
		-- The list's height is known only once it is laid out (and changes
		-- with a note over it): the set is drawn again at its new size.
		holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			local block, left = blockFor()
			spare.PaddingBottom = UDim.new(0, left)
			if #shown > 0 and block ~= drawnAt then
				build(shown, false)
				for _, b in boxes do
					b.box.paint(ctx.stateOf(b.e))
				end
			end
		end)
	end

	return {
		root = holder,
		scroll = scroll,
		fill = function(entries: { Types.Entry })
			build(entries, true)
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
			foot.Visible = f.name ~= "" and f.action ~= "drive" and f.action ~= "wait"
			name.Text = if f.rare then `<font color="#{Parts.C.dusk:ToHex()}">◆</font> {f.name}` else f.name
			note.Text = f.note
		end,
	}
end

------------------------------------------------------------------------
-- Sub-tabs: the picker's slanted tabs, or words with a green underline.
------------------------------------------------------------------------

export type Picker = { root: Frame, set: (id: string) -> () }

-- Slanted tabs sharing `width` (or each as wide as its word). Words of
-- very different lengths share it by length (the menu's KSA beside ABU
-- DHABI, its ALL beside the star), alike ones evenly (the garage's).
function Parts.slants(parent: Instance, ctx: Types.Ctx, defs: { Types.ViewDef }, h: number, size: number, gap: number, width: number?): Picker
	local tabDefs: { Kit.TabDef } = {}
	local total, least, most = 0, math.huge, 0
	for _, d in defs do
		local wt = #d.label + 3
		total += wt
		least = math.min(least, wt)
		most = math.max(most, wt)
	end
	local weighted = most >= least * 1.6
	for _, d in defs do
		local share = if weighted then (#d.label + 3) / total else 1 / #defs
		local w = if width then math.floor((width - gap * (#defs - 1)) * share) else math.floor(#d.label * size * 0.8 + size * 2)
		table.insert(tabDefs, { id = d.id, label = d.label, width = w, star = d.star })
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
-- beside it, its Arabic after it when `arabic`. The bar is one marker that
-- slides to the word chosen (UI_SYSTEM.md: "the sodium marker beside it,
-- which slides to a new choice"; it had jumped).
function Parts.wordRail(parent: Instance, ctx: Types.Ctx, rowH: number, size: number, sizeOn: number, arabic: boolean): Picker
	local col = Kit.frame(parent, "Rail")
	col.AutomaticSize = Enum.AutomaticSize.Y
	col.Size = UDim2.fromScale(1, 0)
	local list = Kit.frame(col, "Words")
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.Size = UDim2.fromScale(1, 0)
	Kit.list(list, true, 0)
	local barH = math.floor(rowH * 0.5)
	local marker = Kit.frame(col, "Marker", Kit.C.green, 0)
	marker.Size = UDim2.fromOffset(4, barH)
	marker.Visible = false
	Kit.corner(marker, 2)
	local items: { [string]: { word: TextLabel, ar: TextLabel?, row: number } } = {}
	for i, d in ctx.tabs do
		local b = Instance.new("TextButton")
		b.Name = "Tab_" .. d.id
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.Text = ""
		b.Size = UDim2.new(1, 0, 0, rowH)
		b.LayoutOrder = i
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
		b.Parent = list
		items[d.id] = { word = w, ar = ar, row = i - 1 }
	end
	local current: string? = nil
	return {
		root = col,
		set = function(id: string)
			for key, it in items do
				local on = key == id
				it.word.FontFace = Kit.font(if on then Enum.FontWeight.Heavy else Enum.FontWeight.ExtraBold, true)
				it.word.TextSize = if on then sizeOn else size
				it.word.TextColor3 = if on then Kit.C.text else Kit.C.sub
				local a = it.ar
				if a then
					a.Visible = on
				end
			end
			local it = items[id]
			marker.Visible = it ~= nil
			if it and id ~= current then
				local to = UDim2.fromOffset(0, it.row * rowH + math.floor((rowH - barH) / 2))
				if current == nil then
					marker.Position = to
				else
					TweenService:Create(marker, Parts.SETTLE, { Position = to }):Play()
				end
			end
			current = id
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
		local icon = Parts.icon(b, d.icon, iconS, nil, d.sheet)
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
	local first = true
	return {
		root = row,
		set = function(id: string)
			for key, it in items do
				local on = key == id
				it.g.Enabled = on
				it.b.ImageTransparency = if on then 0 else 0.93
				-- The chosen tab widens and the one it left narrows, eased,
				-- so the row reads as one piece moving (ui-flow).
				local want = UDim2.fromOffset(if on then wChosen else wOff, h)
				if first then
					it.b.Size = want
				elseif it.b.Size ~= want then
					TweenService:Create(it.b, Parts.SETTLE, { Size = want }):Play()
				end
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
			first = false
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
			t.TextTransparency = 0
			if a == "buy" then
				b.ImageColor3 = Parts.C.sodium
				t.TextColor3 = Parts.C.buyInk
				t.TextStrokeTransparency = 1
				t.Text = `BUY  <font face="Oswald" weight="bold">{Parts.money(foot.price)}</font>`
			elseif a == "drive" or a == "wait" then
				-- Green: go (DRIVE THIS, SPAWN THIS CAR); faded while a
				-- spawn cools down.
				b.ImageColor3 = Kit.C.greenTop
				b.ImageTransparency = if a == "wait" then 0.45 else 0
				t.TextColor3 = Kit.C.text
				t.TextTransparency = if a == "wait" then 0.3 else 0
				t.TextStrokeColor3 = Color3.fromRGB(0, 60, 30)
				t.TextStrokeTransparency = 0.75
				t.Text = foot.label or "DRIVE THIS"
			else
				b.ImageColor3 = Parts.C.grey
				b.ImageTransparency = 0.55
				t.TextColor3 = Kit.C.tabInk
				t.TextStrokeTransparency = 1
				t.Text = foot.label or "ON YOUR CAR"
			end
		end,
	}
end

------------------------------------------------------------------------
-- Motion: one language for every screen (ui-flow, 2026-10-12, the owner:
-- "stop it from being so choppy"). A piece comes in from the edge it lives
-- on and settles (IN); content that changes in place eases up a few pixels
-- (SETTLE); what goes leaves the way it came, quicker (OUT). Positions
-- only: a fade would need a CanvasGroup, which redraws its children soft.
------------------------------------------------------------------------

Parts.IN = TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
Parts.OUT = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
Parts.SETTLE = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- How far content that changed in place eases up.
Parts.LIFT = 14
-- Past the edge a piece comes from: with no fade, it must start out of
-- sight, or it would appear and then move.
local CLEAR = 24

-- A piece's resting place, taken the first time it moves.
local HOME = "MotionHome"
local function home(o: GuiObject): UDim2
	local h = o:GetAttribute(HOME)
	if typeof(h) == "UDim2" then
		return h
	end
	o:SetAttribute(HOME, o.Position)
	return o.Position
end

-- In from (dx, dy) away, after `delay`.
function Parts.slideIn(o: GuiObject, dx: number, dy: number, delay: number?)
	local h = home(o)
	o.Position = h + UDim2.fromOffset(dx, dy)
	local d = delay or 0
	local info = if d > 0 then TweenInfo.new(Parts.IN.Time, Parts.IN.EasingStyle, Parts.IN.EasingDirection, 0, false, d) else Parts.IN
	TweenService:Create(o, info, { Position = h }):Play()
end

-- Out toward (dx, dy).
function Parts.slideOut(o: GuiObject, dx: number, dy: number)
	local h = home(o)
	TweenService:Create(o, Parts.OUT, { Position = h + UDim2.fromOffset(dx, dy) }):Play()
end

-- Eases up into place from `dy` below (new content in a place that stays).
function Parts.settle(o: GuiObject, dy: number)
	local h = home(o)
	o.Position = h + UDim2.fromOffset(0, dy)
	TweenService:Create(o, Parts.SETTLE, { Position = h }):Play()
end

-- A screen's pieces: `left` and `right` come from their sides, `top` from
-- above, `bottom` from below, each from just out of sight; `content` is
-- what a switch from a screen in the same frame settles. `room` and
-- `scale` are the layout's (Parts.root).
export type Pieces = {
	room: Vector2,
	scale: number,
	left: { GuiObject },
	right: { GuiObject },
	top: { GuiObject },
	bottom: { GuiObject },
	content: { GuiObject },
}

-- A piece's box at rest, in the layout's drawing pixels.
local function rest(o: GuiObject, scale: number): (number, number, number, number)
	local h = home(o)
	local w, ht = o.Size.X.Offset, o.Size.Y.Offset
	if w <= 0 or ht <= 0 then
		-- Sized by its content (AutomaticSize): what it measures now.
		w = math.max(w, o.AbsoluteSize.X / scale)
		ht = math.max(ht, o.AbsoluteSize.Y / scale)
	end
	return h.X.Offset - o.AnchorPoint.X * w, h.Y.Offset - o.AnchorPoint.Y * ht, w, ht
end

-- How far each piece goes to be out of sight past its edge.
local function travels(p: Pieces): { { o: GuiObject, dx: number, dy: number } }
	local out = {}
	for _, o in p.left do
		local x, _, w = rest(o, p.scale)
		table.insert(out, { o = o, dx = -(x + w + CLEAR), dy = 0 })
	end
	for _, o in p.right do
		local x = rest(o, p.scale)
		table.insert(out, { o = o, dx = p.room.X - x + CLEAR, dy = 0 })
	end
	for _, o in p.top do
		local _, y, _, ht = rest(o, p.scale)
		table.insert(out, { o = o, dx = 0, dy = -(y + ht + CLEAR) })
	end
	for _, o in p.bottom do
		local _, y = rest(o, p.scale)
		table.insert(out, { o = o, dx = 0, dy = p.room.Y - y + CLEAR })
	end
	return out
end

-- In: every piece from out of sight past its edge, a little apart (the
-- shades first, then the words, the title, the column, the action).
function Parts.intro(p: Pieces, switch: boolean)
	if switch then
		-- The chrome is where it was on the screen before; only what
		-- changed settles.
		for _, o in p.content do
			Parts.settle(o, Parts.LIFT)
		end
		return
	end
	for i, t in travels(p) do
		Parts.slideIn(t.o, t.dx, t.dy, math.min(i - 1, 6) * 0.025)
	end
end

-- Out: every piece back past its edge; returns how long that takes.
function Parts.outro(p: Pieces): number
	for _, t in travels(p) do
		Parts.slideOut(t.o, t.dx, t.dy)
	end
	return Parts.OUT.Time
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
