--!strict
-- DOCK (B. Garage on the "Hajwala Menus" canvas): the categories as tabs
-- in a dock along the bottom with the action and EXIT, where the thumbs
-- are; above it on the left a panel with the sub-tabs, a form (the plate
-- search, the settings), the items and a line naming the one picked; the
-- subject on the right under its title and the cash.
--
-- The menu draws through this too (ui-flow, 2026-10-12): the dock's tabs
-- are CARS, PLATES and SETTINGS there and the subject (the picked car, a
-- plate) is drawn by the menu in `stage`, so a phone that picks DOCK has
-- it on every screen, the garage's and the menu's alike.
local Kit = require(script.Parent.Parent.Parent:WaitForChild("CarPicker"):WaitForChild("Kit"))
local CarArt = require(script.Parent.Parent.Parent:WaitForChild("CarPicker"):WaitForChild("Art"))
local Types = require(script.Parent:WaitForChild("Types"))
local Parts = require(script.Parent:WaitForChild("Parts"))

local Dock = {}

function Dock.build(gui: ScreenGui, ctx: Types.Ctx): Types.View
	local touch = ctx.touch
	local root, room = Parts.root(gui, ctx, "Dock")
	local M = 8
	local dockH = if touch then 56 else 66
	local panelW = if touch then 356 else 520
	local pad = if touch then 10 else 14

	-- The panel: the sub-tabs (or the category's name), a note, a form, the
	-- items, the item picked.
	local panel, body = Kit.panel(root, "Panel", if touch then 14 else 16)
	panel.Position = UDim2.fromOffset(M, M)
	panel.Size = UDim2.fromOffset(panelW, room.Y - dockH - 3 * M)
	Kit.pad(body, pad, pad, pad, pad)
	Kit.list(body, true, if touch then 7 else 10)

	local subH = if touch then 30 else 36
	local top = Kit.frame(body, "Top")
	top.LayoutOrder = 1
	top.Size = UDim2.new(1, 0, 0, subH)
	Kit.list(top, false, 8, Enum.VerticalAlignment.Center)
	local subHolder = Kit.frame(top, "Subs")
	subHolder.AutomaticSize = Enum.AutomaticSize.X
	subHolder.Size = UDim2.fromOffset(0, subH)
	Kit.pad(subHolder, 0, 0, 0, 5)
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
	extra.Size = UDim2.fromOffset(0, subH)
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

	local note = Parts.note(body, if touch then 11 else 13)
	note.LayoutOrder = 2

	-- Every item a square block, three across on a phone (the owner,
	-- 2026-10-12: "the options need to be bigger and make them
	-- blocks/squares"; they were 80-tall tiles four across and full-width
	-- rows). A block is what the panel's width leaves after its padding,
	-- the list's (Parts.LIST_PAD_X) and the gaps.
	local cols = if touch then 3 else 4
	local gapB = if touch then 8 else 10
	local inner = panelW - 2 * pad
	local block = math.floor((inner - Parts.LIST_PAD_X - gapB * (cols - 1)) / cols)
	local m: Parts.BoxMetrics = if touch
		then { name = 11, word = 10, swatch = 56, rows = false, inline = false, block = block }
		else { name = 13, word = 11, swatch = 64, rows = false, inline = false, block = block }
	local items = Parts.items(body, ctx, cols, cols, block, block, gapB, m)
	items.root.LayoutOrder = 4
	items.root.Size = UDim2.fromScale(1, 0)
	Kit.fill(items.root)

	local foot = Parts.footLine(body, if touch then 22 else 28, if touch then 13 else 16, if touch then 10 else 12)
	foot.root.LayoutOrder = 5

	-- The place and the subject over it (the cash is the controller's,
	-- where the HUD has it: Parts.hudCash).
	local headX = M + panelW + (if touch then 24 else 40)
	local head = Kit.frame(root, "Head")
	head.Position = UDim2.fromOffset(headX, M)
	head.AutomaticSize = Enum.AutomaticSize.XY
	Kit.list(head, true, 2)
	local title = Parts.title(head, if touch then 22 else 30, ctx.title)
	title.LayoutOrder = 1
	local lineH = if touch then 18 else 22
	local carRow = Kit.frame(head, "CarRow")
	carRow.LayoutOrder = 2
	carRow.AutomaticSize = Enum.AutomaticSize.X
	carRow.Size = UDim2.fromOffset(0, lineH)
	Kit.list(carRow, false, 4, Enum.VerticalAlignment.Center)
	local carLine = Kit.text(carRow, "Car", "", if touch then 11 else 14, Enum.FontWeight.ExtraBold, true, Kit.C.tabInk)
	carLine.AutomaticSize = Enum.AutomaticSize.X
	carLine.Size = UDim2.fromScale(0, 1)
	carLine.TextTruncate = Enum.TextTruncate.None
	local starIcon: ImageLabel? = nil
	if ctx.starred then
		local star = Kit.iconButton(carRow, "Fav", CarArt.starLine, lineH + 6)
		star.LayoutOrder = 1
		star.BackgroundTransparency = 1
		star.Activated:Connect(function()
			local fn = ctx.act.star
			if fn and not ctx.busy() then
				fn()
			end
		end)
		starIcon = star:FindFirstChild("Icon") :: ImageLabel
	end

	-- The subject's room: right of the panel, under the title, over the
	-- dock.
	local stageTop = M + (if touch then 22 else 30) + 4 + lineH + (if touch then 6 else 10)
	local stage = Kit.frame(root, "Stage")
	stage.Position = UDim2.fromOffset(M + panelW + M, stageTop)
	stage.Size = UDim2.fromOffset(math.max(room.X - 2 * M - panelW - M, 0), room.Y - dockH - 2 * M - stageTop)

	-- The dock: the categories, the layout switch, the action, EXIT.
	local dock, dockBody = Kit.panel(root, "Dock", if touch then 14 else 16)
	dock.Position = UDim2.fromOffset(M, room.Y - M - dockH)
	dock.Size = UDim2.fromOffset(room.X - 2 * M, dockH)
	Kit.pad(dockBody, 4, 4, 4, 4)
	Kit.list(dockBody, false, 6, Enum.VerticalAlignment.Center)
	-- The tabs take what the buttons leave, so the dock has no hole on a
	-- wide phone (the owner, 2026-10-12: "the bottom dock needs some
	-- centering work").
	local h = dockH - 8
	local actionW = if touch then 170 else 240
	local exitW = if touch then 54 else 66
	local tabsW = (room.X - 2 * M) - 8 - h - actionW - exitW - 3 * 6
	-- A few tabs (the menu's three) share less of the row, so the chosen
	-- one is not stretched across half the dock.
	local wOn = if #ctx.tabs <= 3 then math.floor(tabsW * 0.42) else (if touch then 100 else 150)
	local tabs = Parts.dockTabs(dockBody, ctx, h, wOn, tabsW, if touch then 8 else 10, if touch then 4 else 6)
	tabs.root.LayoutOrder = 1
	local layoutButton = Parts.square(dockBody, "Layout", h, h, Parts.ICON.layout, nil, "LAYOUT")
	layoutButton.LayoutOrder = 3
	layoutButton.Activated:Connect(function()
		if not ctx.busy() then
			ctx.act.nextLayout()
		end
	end)
	local action = Parts.action(dockBody, ctx, actionW, h, if touch then 15 else 19)
	action.root.LayoutOrder = 4
	local exit = Parts.square(dockBody, "Exit", exitW, h, nil, "×", "EXIT")
	exit.LayoutOrder = 5
	exit.Activated:Connect(function()
		if not ctx.busy() then
			ctx.act.leave()
		end
	end)

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
		local defs = ctx.views()
		if #defs > 1 then
			subs = Parts.slants(subHolder, ctx, defs, subH, if touch then 11 else 13, 5, nil)
		else
			for _, d in ctx.tabs do
				if d.id == ctx.tab() then
					heading = Parts.heading(subHolder, d, if touch then 18 else 22)
				end
			end
		end
		local x = ctx.extra()
		extra.Visible = x ~= nil
		extra.Text = if x == "rev" then "REV" elseif x == "shop" then "SHOP PLATES" else ""
		local fills = false
		local builder = if ctx.form then ctx.form() else nil
		if builder then
			local made = builder(body, inner, false, nil)
			made.root.LayoutOrder = 3
			if made.fills then
				Kit.fill(made.root)
			end
			fills = made.fills
			form = made
		end
		items.root.Visible = not fills
		items.fill(if fills then {} else ctx.entries())
	end

	local function refresh()
		tabs.set(ctx.tab())
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
		local name, drive = ctx.carName(), ctx.carDrive()
		carLine.Text = if drive ~= "" then `{name}, {drive}` else name
		carRow.Visible = name ~= ""
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

	-- Coming in: the panel from the left, the subject from the right, the
	-- title from above, the dock up from below (Parts.intro).
	local pieces: Parts.Pieces = {
		room = room,
		scale = Parts.scaleFor(touch, ctx.screen),
		left = { panel },
		right = { stage },
		top = { head },
		bottom = { dock },
		content = { panel, stage, head },
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

return Dock
