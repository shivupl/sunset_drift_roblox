--!strict
-- SHOWCASE (C. Garage on the "Hajwala Menus" canvas) and its variants, the
-- phone's garage (the owner, 2026-10-12: "lets finalize on the shade mode
-- FOR mobile, make the options in there also squares/blocks"; of four right
-- sides, "showcades and shade are the best delete the others. make some
-- mroe variants of showcase that are more lined up with shades"). In all
-- of them the car is the big thing in the middle under its name; the
-- categories are words down the left on a shade, EXIT and the layout
-- switch under them; the cash is where the HUD has it (the controller's,
-- Parts.hudCash). The right side holds the sub-tabs (REV or SHOP PLATES
-- beside them), a note, the items as square blocks two across, a hairline,
-- the item picked, and the action under them:
--   SHOWCASE  ("column") on a graphite panel.
--   SHADES    ("shades") straight on a shade like the words', no panel.
-- And SHOWCASE leaning toward SHADES:
--   GLASS     ("glass") the panel see-through, over SHADES' shade.
--   EDGE      ("edge") a panel run off the screen's right edge like a
--             drawer, its inner edge fading into the garage, the action
--             inside at its foot.
--   FRAME     ("frame") SHADES with the blocks in a thin outlined tray.
-- EXIT, the layout switch and the action share one bottom line.
local Kit = require(script.Parent.Parent.Parent:WaitForChild("CarPicker"):WaitForChild("Kit"))
local Types = require(script.Parent:WaitForChild("Types"))
local Parts = require(script.Parent:WaitForChild("Parts"))

local Showcase = {}

export type Variant = "column" | "shades" | "glass" | "edge" | "frame"

-- The right side's width: a panel's (its blocks fill it), or on a bare
-- shade its blocks' (two across at `block`).
local function sideWidth(variant: Variant, touch: boolean): (number?, number?)
	if variant == "shades" or variant == "frame" then
		return nil, if touch then 104 else 110
	elseif variant == "edge" then
		return if touch then 264 else 368, nil
	end
	return if touch then 252 else 352, nil
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
	local subH = if touch then 30 else 36

	-- The words' shade, reaching the screen's edge on any phone (the owner,
	-- 2026-10-12: on a panel instead it looked "way worse").
	Parts.edgeShade(gui, root, room, "left", navW, if touch then 90 else 140)

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

	-- The right side.
	local cols = if touch then 2 else 3
	local colW, shadeBlock = sideWidth(variant, touch)
	local edge = variant == "edge"
	local tray = variant == "frame"
	local onShade = variant ~= "column"
	-- Over the action, or (EDGE) down to the bottom line with it inside.
	local sideH = if edge then room.Y - 2 * M else room.Y - 3 * M - actionH
	local body: Frame
	local inner: number -- the width its pieces have
	local block: number
	if colW then
		local pad = if touch then 8 else 12
		if variant == "glass" then
			-- SHADES' shade behind, the panel over it see-through: the
			-- garage shows through both, the blocks still sit on a card.
			Parts.edgeShade(gui, root, room, "right", colW, if touch then 70 else 110)
		end
		if edge then
			-- A drawer: graphite from half a screen past the right edge to
			-- colW in from it (no gap beside a notch: UIKit.edgeToEdge), its
			-- inner edge fading out over `soft` like a shade's.
			gui.ClipToDeviceSafeArea = false
			local bleed = math.floor(room.X * 0.5)
			local soft = if touch then 28 else 40
			-- One graphite, the panel's middle: a UIGradient's colour can't
			-- run top to bottom while its fade runs across.
			local drawer = Kit.frame(root, "Drawer", Kit.C.panelTop:Lerp(Kit.C.panelBottom, 0.5), 0)
			drawer.Position = UDim2.fromOffset(room.X - colW - soft, -math.floor(room.Y * 0.5))
			drawer.Size = UDim2.fromOffset(colW + soft + bleed, room.Y * 2)
			local fade = Instance.new("UIGradient")
			fade.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(soft / (colW + soft + bleed), 0.04),
				NumberSequenceKeypoint.new(1, 0.04),
			})
			fade.Parent = drawer
			drawer.Active = true
			local holder = Kit.frame(root, "Side")
			holder.Position = UDim2.fromOffset(room.X - colW, M)
			holder.Size = UDim2.fromOffset(colW - M, sideH)
			Kit.pad(holder, 0, 0, 0, pad)
			body = holder
			inner = colW - M - pad
		else
			local col, panelBody = Kit.panel(root, "Column", if touch then 14 else 16)
			col.Position = UDim2.fromOffset(room.X - M - colW, M)
			col.Size = UDim2.fromOffset(colW, sideH)
			if variant == "glass" then
				col.BackgroundTransparency = 0.42
				local dots = col:FindFirstChild("Dots")
				if dots and dots:IsA("GuiObject") then
					dots.Visible = false
				end
			end
			Kit.pad(panelBody, pad, pad, pad, pad)
			body = panelBody
			inner = colW - 2 * pad
		end
		block = math.floor((inner - Parts.LIST_PAD_X - gap * (cols - 1)) / cols)
	else
		block = shadeBlock or 104
		-- FRAME's tray adds its own padding round the blocks.
		local trayPad = if tray then 6 else 0
		inner = cols * block + gap * (cols - 1) + Parts.LIST_PAD_X + 2 * trayPad
		Parts.edgeShade(gui, root, room, "right", inner, if touch then 70 else 110)
		local side = Kit.frame(root, "Side")
		side.Position = UDim2.fromOffset(room.X - M - inner, M)
		side.Size = UDim2.fromOffset(inner, sideH)
		body = side
	end
	Kit.list(body, true, if touch then 7 else 10)
	local sideW = colW or inner

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
		else { name = 13, word = 11, swatch = 60, rows = false, inline = false, block = block }
	if onShade and variant ~= "edge" then
		m.backdrop = "shade"
	end
	local listParent: Frame = body
	if tray then
		-- FRAME: the blocks in a tray, a hairline round them and the
		-- faintest fill, on the shade.
		local t = Kit.frame(body, "Tray", Color3.new(1, 1, 1), 0.96)
		t.LayoutOrder = 3
		t.Size = UDim2.fromScale(1, 0)
		Kit.fill(t)
		Kit.corner(t, if touch then 12 else 14)
		Kit.stroke(t, Color3.new(1, 1, 1), 1, 0.82)
		Kit.pad(t, 6, 6, 6, 6)
		listParent = t
	end
	local items = Parts.items(listParent, ctx, cols, cols, block, block, gap, m)
	if tray then
		items.root.Size = UDim2.fromScale(1, 1)
	else
		items.root.LayoutOrder = 3
		items.root.Size = UDim2.fromScale(1, 0)
		Kit.fill(items.root)
	end

	-- A hairline over the item picked, parting it from the blocks.
	local rule = Kit.frame(body, "Rule", Color3.new(1, 1, 1), 0.9)
	rule.LayoutOrder = 4
	rule.Size = UDim2.new(1, 0, 0, 1)
	local foot = Parts.footLine(body, if touch then 22 else 28, if touch then 13 else 16, if touch then 10 else 12)
	foot.root.LayoutOrder = 5

	local action: Parts.ActionButton
	if edge then
		action = Parts.action(body, ctx, inner, actionH, if touch then 17 else 21)
		action.root.LayoutOrder = 6
	else
		action = Parts.action(root, ctx, sideW, actionH, if touch then 17 else 21)
		action.root.AnchorPoint = Vector2.new(1, 1)
		action.root.Position = UDim2.fromOffset(room.X - M, room.Y - M)
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
		rule.Visible = foot.root.Visible
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
		pop = items.pop,
		destroy = function()
			root:Destroy()
		end,
	}
end

return Showcase
