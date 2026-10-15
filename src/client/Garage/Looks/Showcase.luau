--!strict
-- SHOWCASE (C. Garage on the "Hajwala Menus" canvas) and its variants, the
-- phone's garage (the owner, 2026-10-12: "lets finalize on the shade mode
-- FOR mobile, make the options in there also squares/blocks"; after
-- several rounds, "remove the shades from glass ... for frame and showcase
-- move them more to the ight and lightly higher just to align more with
-- other elements . remove other modes"). In all of them the subject is the
-- big thing in the middle under its name; the categories are words down
-- the left on a shade, EXIT under them on the action's line; the cash is
-- where the HUD has it (the controller's, Parts.hudCash). The right side
-- lines up under the cash (its right edge and just below its foot) and
-- holds the sub-tabs (REV or SHOP PLATES beside them), a note, a form
-- (the plate search, the settings), the items as square blocks two
-- across, a hairline, the item picked, and the action under them:
--   SHOWCASE  ("column") on a graphite panel.
--   GLASS     ("glass") on the panel see-through.
--   FRAME     ("frame") on a shade, the blocks in a thin outlined tray.
-- SHADES, EDGE, SHELF, CARD and WIDE were tried and went.
--
-- The menu draws through this too (ui-flow, 2026-10-12): its CARS, PLATES
-- and SETTINGS are the words, HAJWALA the title, the picked car or plate
-- the subject (drawn by the menu in `stage`), so the car menu and the
-- garage are one frame and a player never sees the screen rearrange.
local Kit = require(script.Parent.Parent.Parent:WaitForChild("CarPicker"):WaitForChild("Kit"))
local CarArt = require(script.Parent.Parent.Parent:WaitForChild("CarPicker"):WaitForChild("Art"))
local Types = require(script.Parent:WaitForChild("Types"))
local Parts = require(script.Parent:WaitForChild("Parts"))

local Showcase = {}

-- How near the screen's right edge a column reaching past the coins may go,
-- in drawing pixels: about a notch's depth.
local CLEAR_EDGE = 40

export type Variant = "column" | "glass" | "frame"

-- How a variant is fitted out beyond its look: how far past the coins'
-- right edge the column reaches, and the list's up/down control in place
-- of its fades (Parts.scroller).
export type Options = { reach: number?, scroller: Parts.ScrollKind? }

function Showcase.build(gui: ScreenGui, ctx: Types.Ctx, variant: Variant, options: Options?): Types.View
	local opts: Options = options or {}
	local scrollKind: Parts.ScrollKind? = opts.scroller
	local touch = ctx.touch
	local root, room = Parts.root(gui, ctx, "Showcase")
	-- The margin from the screen's edges: a phone's 8; a PC's 22 (the
	-- owner, 2026-10-14, of the garage on a PC: "the spacing is off all
	-- around ... the exit and buy buttons can be raised slightly"; they
	-- sat 8 from the bottom, the words 7 from the left).
	local M = if touch then 8 else 22
	-- Between the column's foot and the action.
	local actGap = if touch then M else 12
	local navW = if touch then 132 else 190
	local actionH = if touch then 52 else 60
	-- The action's height, so the bottom row lines up (the owner's phone,
	-- 2026-10-12: 44 beside 52 read as two rows).
	local btnH = actionH
	local exitW = if touch then 112 else 136
	-- A PC's column a little tighter all through (the owner, 2026-10-14:
	-- "the right side menu needs to be compacted a bit"): 8 between
	-- blocks, the sub-tabs 32, the blocks 92 (were 10, 36, 98).
	local gap = 8
	local subH = if touch then 30 else 32

	-- The words' shade, reaching the screen's edge on any phone (the owner,
	-- 2026-10-12: on a panel instead it looked "way worse").
	local shadeL = Parts.edgeShade(gui, root, room, "left", navW, if touch then 90 else 140)
	local shadesR: { GuiObject } = {}

	-- The categories down the left, EXIT under them on the action's line.
	-- The LAYOUT button beside EXIT went (the owner's phone, 2026-10-12:
	-- "remove the layout button"); Settings' SCREEN LAYOUT picks one. The
	-- words share the height down to EXIT, a row no shorter than `rowMin`
	-- nor taller than `rowMax`, so seven and three both sit at ease, and the
	-- first word is level with the title (its line on the title's middle;
	-- they had sat a few pixels apart).
	local titleSize = if touch then 15 else 19
	local exitTop = room.Y - M - btnH
	-- A PC's rows 50 (were up to 54: the owner, 2026-10-14, "the left side
	-- menu options need to be adjusted better").
	local rowMin, rowMax = if touch then 38 else 46, if touch then 44 else 50
	local rowH = math.clamp(math.floor((exitTop - 12 - M) / math.max(#ctx.tabs, 1)), rowMin, rowMax)
	-- The words two points bigger on a phone (the owner, 2026-10-12:
	-- "slightly increase the font size of the left options").
	local railSize = if touch then 15 else 16
	local rail = Parts.wordRail(root, ctx, rowH, railSize, if touch then 19 else 21, true)
	rail.root.Position = UDim2.fromOffset(M, M + math.floor((titleSize + 4) / 2) - math.floor(rowH / 2))
	rail.root.Size = UDim2.fromOffset(navW, 0)
	-- On a PC EXIT's cross starts where the words do (Parts.wordRail's
	-- indent), one left edge down the side; a phone's EXIT stays centred.
	local exit = Parts.exit(root, exitW, btnH, if touch then 13 else 15, if touch then nil else math.floor(railSize * 1.1))
	exit.Position = UDim2.fromOffset(M, exitTop)
	exit.Activated:Connect(function()
		if not ctx.busy() then
			ctx.act.leave()
		end
	end)

	-- The place and the subject's name over it.
	local cx = M + navW + (if touch then 14 else 24)
	local head = Kit.frame(root, "Head")
	head.Position = UDim2.fromOffset(cx, M)
	head.AutomaticSize = Enum.AutomaticSize.XY
	Kit.list(head, true, if touch then 2 else 4)
	local title = Parts.title(head, titleSize, ctx.title)
	title.LayoutOrder = 1
	local nameH = if touch then 34 else 46
	local nameRow = Kit.frame(head, "NameRow")
	nameRow.LayoutOrder = 2
	nameRow.AutomaticSize = Enum.AutomaticSize.X
	nameRow.Size = UDim2.fromOffset(0, nameH)
	Kit.list(nameRow, false, 10, Enum.VerticalAlignment.Center)
	local carName = Kit.text(nameRow, "Name", "", if touch then 28 else 40, Enum.FontWeight.Heavy, true)
	carName.AutomaticSize = Enum.AutomaticSize.X
	carName.Size = UDim2.fromScale(0, 1)
	carName.TextTruncate = Enum.TextTruncate.None
	carName.TextStrokeTransparency = 0.8
	local chipHolder = Kit.frame(nameRow, "Drive")
	chipHolder.LayoutOrder = 1
	chipHolder.AutomaticSize = Enum.AutomaticSize.X
	chipHolder.Size = UDim2.fromOffset(0, if touch then 20 else 24)
	local chip: Frame? = nil
	local chipText = ""
	-- The favourite star, where a screen has one (the menu's cars).
	local starIcon: ImageLabel? = nil
	if ctx.starred then
		local star = Kit.iconButton(nameRow, "Fav", CarArt.starLine, if touch then 30 else 36)
		star.LayoutOrder = 2
		star.BackgroundTransparency = 1
		star.Activated:Connect(function()
			local fn = ctx.act.star
			if fn and not ctx.busy() then
				fn()
			end
		end)
		starIcon = star:FindFirstChild("Icon") :: ImageLabel
	end

	-- The right side, its right edge under the cash's and its top just
	-- below it (Parts.coinAnchor; kept near the gui's corner should the
	-- measure come out odd), down to the action.
	local scale = Parts.scaleFor(touch, ctx.screen)
	local right, sideTop = room.X - M, M
	local coins = ctx.coins
	if coins then
		right = math.clamp(coins.X / scale, room.X - 80, room.X + 160)
		sideTop = math.clamp(coins.Y / scale + (if touch then 6 else 8), -50, 80)
	end
	-- GLASS on a phone reaches a little past the coins (the owner,
	-- 2026-10-12: "extend this slightly more to the right"); its left edge
	-- stays, so it is that much wider. Only into room there is: never
	-- nearer the screen's edge than CLEAR_EDGE (a notch's depth), so on a
	-- screen with no margin past the coins (Studio, a PC) it stays put.
	local reach = 0
	if coins and opts.reach then
		local cam = workspace.CurrentCamera
		local screenRight = ((if cam then cam.ViewportSize.X else gui.AbsoluteSize.X) - gui.AbsolutePosition.X) / scale
		local to = math.min(right + opts.reach, math.max(right, screenRight - CLEAR_EDGE))
		reach = math.floor(to - right)
		right = to
	end
	local sideH = room.Y - M - actionH - actGap - sideTop
	local cols = if touch then 2 else 3
	local tray = variant == "frame"
	local column: Frame -- what slides in from the right
	local body: Frame
	local inner: number -- the width its pieces have
	local block: number
	local sideLeft: number
	if tray then
		-- FRAME: on a shade like the words', the blocks in a tray that
		-- adds its own padding round them.
		block = if touch then 104 else 110
		inner = cols * block + gap * (cols - 1) + Parts.LIST_PAD_X + Parts.railRoom(scrollKind) + 12
		sideLeft = right - inner
		table.insert(shadesR, Parts.edgeShade(gui, root, room, "right", room.X - sideLeft, if touch then 70 else 110))
		local side = Kit.frame(root, "Side")
		side.Position = UDim2.fromOffset(sideLeft, sideTop)
		side.Size = UDim2.fromOffset(inner, sideH)
		body = side
		column = side
	else
		local colW = (if touch then 252 else 332) + reach
		local pad = if touch then 8 else 10
		local col, panelBody = Kit.panel(root, "Column", if touch then 14 else 16)
		sideLeft = right - colW
		col.Position = UDim2.fromOffset(sideLeft, sideTop)
		col.Size = UDim2.fromOffset(colW, sideH)
		if variant == "glass" then
			-- See-through, no dots: the garage shows through it.
			col.BackgroundTransparency = 0.42
			local dots = col:FindFirstChild("Dots")
			if dots and dots:IsA("GuiObject") then
				dots.Visible = false
			end
		end
		Kit.pad(panelBody, pad, pad, pad, pad)
		body = panelBody
		column = col
		inner = colW - 2 * pad
		block = math.floor((inner - Parts.LIST_PAD_X - Parts.railRoom(scrollKind) - gap * (cols - 1)) / cols)
	end
	Kit.list(body, true, if touch then 7 else 8)
	local sideW = if tray then inner else inner + 2 * (if touch then 8 else 10)

	-- The room between the words and the items, under the name: the
	-- subject's (the garage's car is the 3D one behind it).
	local stageTop = M + titleSize + 4 + nameH + (if touch then 6 else 10)
	local stage = Kit.frame(root, "Stage")
	stage.Position = UDim2.fromOffset(cx, stageTop)
	stage.Size = UDim2.fromOffset(math.max(sideLeft - (if touch then 14 else 24) - cx, 0), room.Y - M - stageTop)

	-- The sub-tabs (or the category's name), REV or SHOP PLATES at the
	-- end of their row.
	local top = Kit.frame(body, "Top")
	top.LayoutOrder = 1
	top.Size = UDim2.new(1, 0, 0, subH)
	Kit.list(top, false, 6, Enum.VerticalAlignment.Center)
	local subHolder = Kit.frame(top, "Subs")
	subHolder.Size = UDim2.fromScale(0, 1)
	Kit.fill(subHolder)
	Kit.pad(subHolder, 0, 0, 0, 5)
	local extra = Instance.new("TextButton")
	extra.Name = "Extra"
	extra.LayoutOrder = 2
	extra.AutoButtonColor = false
	extra.BorderSizePixel = 0
	extra.BackgroundColor3 = Color3.new(1, 1, 1)
	extra.BackgroundTransparency = 0.92
	extra.TextSize = if touch then 11 else 13
	extra.TextColor3 = Kit.C.text
	extra.FontFace = Kit.font(Enum.FontWeight.ExtraBold, true)
	Kit.corner(extra, 8)
	Kit.stroke(extra, Color3.new(1, 1, 1), 1, 0.88)
	extra.Parent = top
	extra.Activated:Connect(function()
		if not ctx.busy() then
			ctx.act.extra()
		end
	end)
	local revW = if touch then 58 else 70
	local shopW = if touch then 112 else 132

	local note = Parts.note(body, if touch then 10 else 12)
	note.LayoutOrder = 2

	local m: Parts.BoxMetrics = if touch
		then { name = 11, word = 10, swatch = 54, rows = false, inline = false, block = block }
		else { name = 13, word = 11, swatch = 56, rows = false, inline = false, block = block }
	if variant ~= "column" then
		m.backdrop = "shade"
	end
	m.scroller = scrollKind
	-- With no fades, a row cut by the list's foot read as broken: the
	-- blocks fit whole rows (Parts.items).
	m.fitRows = scrollKind ~= nil
	local listParent: Frame = body
	local itemsBox: Frame -- what holds the items in the column
	if tray then
		-- FRAME: the blocks in a tray, a hairline round them and the
		-- faintest fill, on the shade.
		local t = Kit.frame(body, "Tray", Color3.new(1, 1, 1), 0.96)
		t.LayoutOrder = 4
		t.Size = UDim2.fromScale(1, 0)
		Kit.fill(t)
		Kit.corner(t, if touch then 12 else 14)
		Kit.stroke(t, Color3.new(1, 1, 1), 1, 0.82)
		Kit.pad(t, 6, 6, 6, 6)
		listParent = t
		itemsBox = t
	end
	local items = Parts.items(listParent, ctx, cols, cols, block, block, gap, m)
	if tray then
		items.root.Size = UDim2.fromScale(1, 1)
	else
		items.root.LayoutOrder = 4
		items.root.Size = UDim2.fromScale(1, 0)
		Kit.fill(items.root)
		itemsBox = items.root
	end

	-- A hairline over the item picked, parting it from the blocks.
	local rule = Kit.frame(body, "Rule", Color3.new(1, 1, 1), 0.9)
	rule.LayoutOrder = 5
	rule.Size = UDim2.new(1, 0, 0, 1)
	local foot = Parts.footLine(body, if touch then 22 else 26, if touch then 13 else 16, if touch then 10 else 12)
	foot.root.LayoutOrder = 6

	local action = Parts.action(root, ctx, sideW, actionH, if touch then 17 else 21)
	action.root.AnchorPoint = Vector2.new(1, 1)
	action.root.Position = UDim2.fromOffset(right, room.Y - M)

	local subs: Parts.Picker? = nil
	local heading: Frame? = nil
	local form: Types.Form? = nil

	local function fill()
		local s, hd, f = subs, heading, form
		if s then
			s.root:Destroy()
		end
		if hd then
			hd:Destroy()
		end
		if f then
			f.root:Destroy()
		end
		subs, heading, form = nil, nil, nil
		local x = ctx.extra()
		extra.Visible = x ~= nil
		extra.Text = if x == "rev" then "REV" elseif x == "shop" then "SHOP PLATES" else ""
		local extraW = if x == "rev" then revW elseif x == "shop" then shopW else 0
		extra.Size = UDim2.fromOffset(extraW, subH)
		local defs = ctx.views()
		if #defs > 1 then
			local slantW = inner - 9 - (if extraW > 0 then extraW + 6 else 0)
			subs = Parts.slants(subHolder, ctx, defs, subH, if touch then 10 else 12, 4, slantW)
		else
			for _, d in ctx.tabs do
				if d.id == ctx.tab() then
					heading = Parts.heading(subHolder, d, if touch then 17 else 21)
				end
			end
		end
		-- The screen's form (the plate search, the settings), over the items
		-- or in their place.
		local fills = false
		local builder = if ctx.form then ctx.form() else nil
		if builder then
			local made = builder(body, inner, m.backdrop == "shade", scrollKind)
			made.root.LayoutOrder = 3
			if made.fills then
				Kit.fill(made.root)
			end
			fills = made.fills
			form = made
		end
		itemsBox.Visible = not fills
		items.fill(if fills then {} else ctx.entries())
	end

	local function refresh()
		rail.set(ctx.tab())
		local s = subs
		if s then
			s.set(ctx.view())
		end
		local n = ctx.note()
		note.Visible = n ~= nil
		note.Text = n or ""
		items.refresh()
		local f = ctx.foot()
		action.set(f)
		foot.set(f)
		rule.Visible = foot.root.Visible
		local name = ctx.carName()
		carName.Text = name
		nameRow.Visible = name ~= ""
		local drive = ctx.carDrive()
		if drive ~= chipText then
			chipText = drive
			local old = chip
			if old then
				old:Destroy()
			end
			chip = if drive ~= "" then Kit.chip(chipHolder, drive, if touch then 20 else 24, if touch then 9 else 11) else nil
		end
		local si, st = starIcon, ctx.starred
		if si and st then
			-- nil: no star on this screen (the menu's PLATES, SETTINGS).
			local v = st()
			local holder = si.Parent :: GuiObject
			holder.Visible = v ~= nil
			local fav = v == true
			si.Image = if fav then CarArt.star else CarArt.starLine
			si.ImageColor3 = if fav then Kit.C.green else Color3.new(1, 1, 1)
			si.ImageTransparency = if fav then 0 else 0.4
		end
	end

	-- Coming in: the words and their shade from the left, the column and
	-- the action from the right, the title from above, the subject up from
	-- below (Parts.intro).
	local left: { GuiObject } = { shadeL, rail.root, exit }
	local rightSide: { GuiObject } = {}
	for _, sh in shadesR do
		table.insert(rightSide, sh)
	end
	table.insert(rightSide, column)
	table.insert(rightSide, action.root)
	local pieces: Parts.Pieces = {
		room = room,
		scale = scale,
		left = left,
		right = rightSide,
		top = { head },
		bottom = { stage },
		content = { column, stage, head },
	}
	return {
		root = root,
		stage = stage,
		fill = fill,
		refresh = refresh,
		pop = items.pop,
		destroy = function()
			root:Destroy()
		end,
		intro = function(switch: boolean)
			Parts.intro(pieces, switch)
		end,
		outro = function(): number
			return Parts.outro(pieces)
		end,
	}
end

return Showcase
