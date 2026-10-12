--!strict
-- SHOWCASE (C. Garage on the "Hajwala Menus" canvas): the car is the big
-- thing in the middle under its name; the categories are words down the
-- left on a shade, EXIT and the layout switch under them; on the right a
-- slim panel with the cash, the sub-tabs, the items as a list and the one
-- picked, the action under it where the right thumb is. EXIT, the layout
-- switch and the action share one bottom line.
local Kit = require(script.Parent.Parent.Parent:WaitForChild("CarPicker"):WaitForChild("Kit"))
local Types = require(script.Parent:WaitForChild("Types"))
local Parts = require(script.Parent:WaitForChild("Parts"))

local Showcase = {}

function Showcase.build(gui: ScreenGui, ctx: Types.Ctx): Types.View
	local touch = ctx.touch
	local root, room = Parts.root(gui, ctx, "Showcase")
	local M = 8
	local navW = if touch then 132 else 190
	local colW = if touch then 252 else 352
	local actionH = if touch then 52 else 60

	-- A shade behind the words, so they read over the garage: dark at the
	-- screen's edge, clear past the words. It starts half a screen left of
	-- the gui and the gui does not clip to the safe area, so it reaches the
	-- edge beside any notch (it started 60 px left and left a strip on the
	-- owner's phone, 2026-10-12: "there is a gap still ... i want it fixed
	-- so that there is no wierd gap for any device"; on a panel instead it
	-- looked "way worse"). Its fade is where it was: solid to 60 px left of
	-- the gui, 0.45 a little past the words, clear `tail` past them.
	gui.ClipToDeviceSafeArea = false
	local bleed = math.floor(room.X * 0.5)
	local tail = if touch then 90 else 140
	local fadeW = navW + 60 + tail -- the old shade's width, from 60 px left
	local total = bleed + navW + tail
	local shade = Kit.frame(root, "Shade", Color3.new(0, 0, 0), 0)
	shade.Position = UDim2.fromOffset(-bleed, -math.floor(room.Y * 0.5))
	shade.Size = UDim2.fromOffset(total, room.Y * 2)
	shade:SetAttribute("PassThrough", true)
	local solid = (bleed - 60) / total
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(solid, 0.15),
		NumberSequenceKeypoint.new(solid + 0.55 * fadeW / total, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = shade

	-- The categories, EXIT and the layout switch under them.
	local rail = Parts.wordRail(root, ctx, if touch then 38 else 46, if touch then 13 else 16, if touch then 17 else 21, true)
	rail.root.Position = UDim2.fromOffset(M, M)
	rail.root.Size = UDim2.fromOffset(navW, 0)
	-- The action's height, so the bottom row lines up (the owner's phone,
	-- 2026-10-12: 44 beside 52 read as two rows).
	local btnH = actionH
	local exitW = if touch then 84 else 104
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

	-- The column: the cash and REV / SHOP PLATES, the sub-tabs, a note, the
	-- items as a list, and the item picked at its foot, right over the
	-- action that buys it (it was a chip across the screen from BUY).
	local col, body = Kit.panel(root, "Column", if touch then 14 else 16)
	col.Position = UDim2.fromOffset(room.X - M - colW, M)
	col.Size = UDim2.fromOffset(colW, room.Y - 3 * M - actionH)
	local pad = if touch then 8 else 12
	Kit.pad(body, pad, pad, pad, pad)
	Kit.list(body, true, if touch then 7 else 10)
	local rowH = if touch then 28 else 34
	local top = Kit.frame(body, "Top")
	top.LayoutOrder = 1
	top.Size = UDim2.new(1, 0, 0, rowH)
	Kit.list(top, false, 6, Enum.VerticalAlignment.Center)
	local cash = Parts.cash(top, rowH, if touch then 15 else 18)
	cash.root.LayoutOrder = 1
	local spacer = Kit.frame(top, "Spacer")
	spacer.LayoutOrder = 2
	spacer.Size = UDim2.fromOffset(0, 1)
	Kit.fill(spacer)
	local extra = Instance.new("TextButton")
	extra.Name = "Extra"
	extra.LayoutOrder = 3
	extra.AutoButtonColor = false
	extra.BorderSizePixel = 0
	extra.BackgroundColor3 = Color3.new(1, 1, 1)
	extra.BackgroundTransparency = 0.92
	extra.AutomaticSize = Enum.AutomaticSize.X
	extra.Size = UDim2.fromOffset(0, rowH)
	extra.TextSize = if touch then 11 else 13
	extra.TextColor3 = Kit.C.text
	extra.FontFace = Kit.font(Enum.FontWeight.ExtraBold, true)
	Kit.corner(extra, 8)
	Kit.stroke(extra, Color3.new(1, 1, 1), 1, 0.88)
	Kit.pad(extra, 0, 12, 0, 12)
	extra.Parent = top
	extra.Activated:Connect(function()
		if not ctx.busy() then
			ctx.act.extra()
		end
	end)

	local subH = if touch then 30 else 36
	local subHolder = Kit.frame(body, "Subs")
	subHolder.LayoutOrder = 2
	subHolder.Size = UDim2.new(1, 0, 0, subH)
	Kit.pad(subHolder, 0, 0, 0, 5)
	local note = Parts.note(body, if touch then 10 else 12)
	note.LayoutOrder = 3
	local m: Parts.BoxMetrics = if touch
		then { name = 11, word = 9, swatch = 28, rows = true, inline = true }
		else { name = 13, word = 11, swatch = 34, rows = true, inline = true }
	local items = Parts.items(body, ctx, 1, 1, if touch then 44 else 54, if touch then 44 else 54, if touch then 5 else 7, m)
	items.root.LayoutOrder = 4
	items.root.Size = UDim2.fromScale(1, 0)
	Kit.fill(items.root)
	local foot = Parts.footLine(body, if touch then 22 else 28, if touch then 13 else 16, if touch then 10 else 12)
	foot.root.LayoutOrder = 5

	local action = Parts.action(root, ctx, colW, actionH, if touch then 17 else 21)
	action.root.Position = UDim2.fromOffset(room.X - M - colW, room.Y - M - actionH)

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
			subs = Parts.slants(subHolder, ctx, defs, subH, if touch then 10 else 12, 4, colW - 2 * pad - 9)
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
