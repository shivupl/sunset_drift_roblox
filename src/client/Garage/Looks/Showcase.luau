--!strict
-- SHOWCASE (C. Garage on the "Hajwala Menus" canvas) and its variants, the
-- phone's garage (the owner, 2026-10-12: "lets finalize on the shade mode
-- FOR mobile, make the options in there also squares/blocks. make 3
-- variants again for me to shift though"). In all three the car is the big
-- thing in the middle under its name; the categories are words down the
-- left on a shade, EXIT and the layout switch under them; the items are
-- square blocks (they were a list):
--   SHOWCASE  ("column") in a panel down the right, with the cash, the
--             sub-tabs and the item picked; the action under it.
--   SHADES    ("shades") the same down the right on a shade like the
--             words', no panel.
--   SHELF     ("shelf") in one row along the bottom on a shade, scrolling
--             sideways, the action at its right end; the cash and the
--             sub-tabs top right. The car is lifted clear of the row
--             (GarageConfig.layoutLift).
-- EXIT, the layout switch and the action share one bottom line.
local Kit = require(script.Parent.Parent.Parent:WaitForChild("CarPicker"):WaitForChild("Kit"))
local Types = require(script.Parent:WaitForChild("Types"))
local Parts = require(script.Parent:WaitForChild("Parts"))

local Showcase = {}

export type Variant = "column" | "shades" | "shelf"

-- REV or SHOP PLATES: a small dark button with its word.
local function extraButton(parent: Instance, ctx: Types.Ctx, h: number, size: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = "Extra"
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BackgroundTransparency = 0.92
	b.AutomaticSize = Enum.AutomaticSize.X
	b.Size = UDim2.fromOffset(0, h)
	b.TextSize = size
	b.TextColor3 = Kit.C.text
	b.FontFace = Kit.font(Enum.FontWeight.ExtraBold, true)
	Kit.corner(b, 8)
	Kit.stroke(b, Color3.new(1, 1, 1), 1, 0.88)
	Kit.pad(b, 0, 12, 0, 12)
	b.Parent = parent
	b.Activated:Connect(function()
		if not ctx.busy() then
			ctx.act.extra()
		end
	end)
	return b
end

function Showcase.build(gui: ScreenGui, ctx: Types.Ctx, variant: Variant): Types.View
	local touch = ctx.touch
	local root, room = Parts.root(gui, ctx, "Showcase")
	local M = 8
	local navW = if touch then 132 else 190
	local actionH = if touch then 52 else 60
	-- The action's height, so the bottom row lines up (the owner's phone,
	-- 2026-10-12: 44 beside 52 read as two rows).
	local btnH = actionH
	local exitW = if touch then 84 else 104
	local gap = if touch then 8 else 10
	local rowH = if touch then 28 else 34
	local subH = if touch then 30 else 36

	-- The words' shade, reaching the screen's edge on any phone (the owner,
	-- 2026-10-12: on a panel instead it looked "way worse").
	Parts.edgeShade(gui, root, room, "left", navW, if touch then 90 else 140)

	-- SHELF's row along the bottom, on its own shade; its blocks set how
	-- tall that is.
	local shelfBlock = if touch then 88 else 108
	local shelfH = shelfBlock + 11 -- the list's padding (3 over, 8 under)
	if variant == "shelf" then
		Parts.edgeShade(gui, root, room, "bottom", shelfH, if touch then 50 else 80)
	end

	-- The categories, EXIT and the layout switch under them.
	local rail = Parts.wordRail(root, ctx, if touch then 38 else 46, if touch then 13 else 16, if touch then 17 else 21, true)
	rail.root.Position = UDim2.fromOffset(M, M)
	rail.root.Size = UDim2.fromOffset(navW, 0)
	local exit = Parts.exit(root, exitW, btnH, if touch then 12 else 14)
	exit.Position = UDim2.fromOffset(M, room.Y - M - btnH)
	exit.Activated:Connect(function()
		if not ctx.busy() then
			ctx.act.leave()
		end
	end)
	local layoutButton = Parts.square(root, "Layout", btnH, btnH, Parts.ICON.layout)
	layoutButton.Position = UDim2.fromOffset(M + exitW + 6, room.Y - M - btnH)
	layoutButton.Activated:Connect(function()
		if not ctx.busy() then
			ctx.act.nextLayout()
		end
	end)

	-- The car's name over it.
	local cx = M + navW + (if touch then 14 else 24)
	local head = Kit.frame(root, "Head")
	head.Position = UDim2.fromOffset(cx, M)
	head.AutomaticSize = Enum.AutomaticSize.XY
	Kit.list(head, true, if touch then 2 else 4)
	local title = Parts.title(head, if touch then 15 else 19)
	title.LayoutOrder = 1
	local nameRow = Kit.frame(head, "NameRow")
	nameRow.LayoutOrder = 2
	nameRow.AutomaticSize = Enum.AutomaticSize.X
	nameRow.Size = UDim2.fromOffset(0, if touch then 34 else 46)
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

	-- The items' side: the cash and REV / SHOP PLATES, the sub-tabs (or
	-- the category's name), a note, the blocks, the item picked, the
	-- action. Where they go is the variant's.
	local m: Parts.BoxMetrics = if touch
		then { name = 11, word = 10, swatch = 54, rows = false, inline = false }
		else { name = 13, word = 11, swatch = 60, rows = false, inline = false }
	local body: Frame
	local top: Frame
	local subHolder: Frame
	local subW: number? -- the slants share this width; nil: each its word's
	local actionW: number

	if variant == "shelf" then
		-- Top right: the cash in the corner, REV / SHOP PLATES left of it,
		-- the sub-tabs and the note under them.
		actionW = if touch then 190 else 240
		local side = Kit.frame(root, "Side")
		side.AnchorPoint = Vector2.new(1, 0)
		side.Position = UDim2.fromOffset(room.X - M, M)
		side.Size = UDim2.fromOffset(if touch then 300 else 420, 0)
		side.AutomaticSize = Enum.AutomaticSize.Y
		local sl = Kit.list(side, true, if touch then 6 else 8)
		sl.HorizontalAlignment = Enum.HorizontalAlignment.Right
		body = side
		top = Kit.frame(side, "Top")
		top.LayoutOrder = 1
		top.Size = UDim2.new(1, 0, 0, rowH)
		local tl = Kit.list(top, false, 6, Enum.VerticalAlignment.Center)
		tl.HorizontalAlignment = Enum.HorizontalAlignment.Right
		subHolder = Kit.frame(side, "Subs")
		subHolder.LayoutOrder = 2
		subHolder.AutomaticSize = Enum.AutomaticSize.X
		subHolder.Size = UDim2.fromOffset(0, subH)
		subW = nil
		m.block = shelfBlock
		m.sideways = true
		m.backdrop = "shade"
	else
		-- Down the right: a panel (SHOWCASE) or straight on a shade (SHADES).
		local cols = if touch then 2 else 3
		local sideW: number
		if variant == "column" then
			local colW = if touch then 252 else 352
			local pad = if touch then 8 else 12
			local col, panelBody = Kit.panel(root, "Column", if touch then 14 else 16)
			col.Position = UDim2.fromOffset(room.X - M - colW, M)
			col.Size = UDim2.fromOffset(colW, room.Y - 3 * M - actionH)
			Kit.pad(panelBody, pad, pad, pad, pad)
			body = panelBody
			sideW = colW - 2 * pad
			m.block = math.floor((sideW - 11 - gap * (cols - 1)) / cols)
			actionW = colW
		else
			local block = if touch then 104 else 110
			sideW = cols * block + gap * (cols - 1) + 11
			Parts.edgeShade(gui, root, room, "right", sideW, if touch then 70 else 110)
			local side = Kit.frame(root, "Side")
			side.Position = UDim2.fromOffset(room.X - M - sideW, M)
			side.Size = UDim2.fromOffset(sideW, room.Y - 3 * M - actionH)
			body = side
			m.block = block
			m.backdrop = "shade"
			actionW = sideW
		end
		Kit.list(body, true, if touch then 7 else 10)
		top = Kit.frame(body, "Top")
		top.LayoutOrder = 1
		top.Size = UDim2.new(1, 0, 0, rowH)
		Kit.list(top, false, 6, Enum.VerticalAlignment.Center)
		subHolder = Kit.frame(body, "Subs")
		subHolder.LayoutOrder = 2
		subHolder.Size = UDim2.new(1, 0, 0, subH)
		Kit.pad(subHolder, 0, 0, 0, 5)
		subW = sideW - 9
	end

	-- The cash and REV / SHOP PLATES: the cash first down the right, in
	-- the corner along the top (SHELF).
	local cash = Parts.cash(top, rowH, if touch then 15 else 18)
	local extra = extraButton(top, ctx, rowH, if touch then 11 else 13)
	if variant == "shelf" then
		cash.root.LayoutOrder = 3
		extra.LayoutOrder = 1
	else
		cash.root.LayoutOrder = 1
		local spacer = Kit.frame(top, "Spacer")
		spacer.LayoutOrder = 2
		spacer.Size = UDim2.fromOffset(0, 1)
		Kit.fill(spacer)
		extra.LayoutOrder = 3
	end

	local note = Parts.note(body, if touch then 10 else 12)
	note.LayoutOrder = 3

	local blocks = m.block or 0
	local items = Parts.items(if variant == "shelf" then root else body, ctx, 1, 1, blocks, blocks, gap, m)
	local action = Parts.action(root, ctx, actionW, actionH, if touch then 17 else 21)
	action.root.AnchorPoint = Vector2.new(1, 1)
	action.root.Position = UDim2.fromOffset(room.X - M, room.Y - M)
	local footH = if touch then 22 else 28
	local foot: Parts.FootLine
	if variant == "shelf" then
		-- The row runs between the layout switch and the action, its
		-- blocks' feet on the bottom line (the scroll bar under them); the
		-- item picked sits over the action.
		local x0 = M + exitW + 6 + btnH + (if touch then 10 else 14)
		local x1 = room.X - M - actionW - (if touch then 10 else 14)
		items.root.Position = UDim2.fromOffset(x0, room.Y - M - shelfH + 8)
		items.root.Size = UDim2.fromOffset(x1 - x0, shelfH)
		foot = Parts.footLine(root, footH, if touch then 13 else 16, if touch then 10 else 12)
		foot.root.AnchorPoint = Vector2.new(1, 1)
		foot.root.Position = UDim2.fromOffset(room.X - M, room.Y - M - actionH - 6)
		foot.root.Size = UDim2.fromOffset(actionW, footH)
		note.TextXAlignment = Enum.TextXAlignment.Right
	else
		items.root.LayoutOrder = 4
		items.root.Size = UDim2.fromScale(1, 0)
		Kit.fill(items.root)
		foot = Parts.footLine(body, footH, if touch then 13 else 16, if touch then 10 else 12)
		foot.root.LayoutOrder = 5
	end

	local subs: Parts.Picker? = nil
	local heading: Frame? = nil

	local function fill()
		local s, hd = subs, heading
		if s then
			s.root:Destroy()
		end
		if hd then
			hd:Destroy()
		end
		subs, heading = nil, nil
		local defs = ctx.views()
		if #defs > 1 then
			subs = Parts.slants(subHolder, ctx, defs, subH, if touch then 10 else 12, 4, subW)
		else
			for _, d in ctx.tabs do
				if d.id == ctx.tab() then
					heading = Parts.heading(subHolder, d, if touch then 17 else 21)
				end
			end
		end
		local x = ctx.extra()
		extra.Visible = x ~= nil
		extra.Text = if x == "rev" then "REV" elseif x == "shop" then "SHOP PLATES" else ""
		items.fill(ctx.entries())
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
		carName.Text = ctx.carName()
		local old = chip
		if old then
			old:Destroy()
		end
		chip = Kit.chip(chipHolder, ctx.carDrive(), if touch then 20 else 24, if touch then 9 else 11)
	end

	return {
		root = root,
		fill = fill,
		refresh = refresh,
		setCash = cash.set,
		pop = items.pop,
		destroy = function()
			root:Destroy()
		end,
	}
end

return Showcase
