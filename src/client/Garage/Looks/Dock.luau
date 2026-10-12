--!strict
-- DOCK (B. Garage on the "Hajwala Menus" canvas): the categories as tabs
-- in a dock along the bottom with the action and EXIT, where the thumbs
-- are; above it on the left a panel with the sub-tabs, the items and a
-- line naming the one picked; the car on the right under GARAGE and the
-- cash.
local Kit = require(script.Parent.Parent.Parent:WaitForChild("CarPicker"):WaitForChild("Kit"))
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

	-- The panel: the sub-tabs (or the category's name), a note, the items,
	-- the item picked.
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

	local m: Parts.BoxMetrics = if touch
		then { name = 10, word = 9, swatch = 30, rows = false, inline = false }
		else { name = 12, word = 11, swatch = 42, rows = false, inline = false }
	local items = Parts.items(body, ctx, if touch then 4 else 5, if touch then 1 else 2, if touch then 80 else 104, if touch then 46 else 56, if touch then 7 else 9, m)
	items.scroll.LayoutOrder = 3
	items.scroll.Size = UDim2.fromScale(1, 0)
	Kit.fill(items.scroll)

	local foot = Kit.frame(body, "Foot")
	foot.LayoutOrder = 4
	foot.Size = UDim2.new(1, 0, 0, if touch then 22 else 28)
	Kit.list(foot, false, 8, Enum.VerticalAlignment.Center)
	local footName = Kit.text(foot, "Name", "", if touch then 13 else 16, Enum.FontWeight.Heavy, true)
	footName.RichText = true
	footName.AutomaticSize = Enum.AutomaticSize.X
	footName.Size = UDim2.fromScale(0, 1)
	footName.TextTruncate = Enum.TextTruncate.None
	local footNote = Kit.text(foot, "Note", "", if touch then 10 else 12, Enum.FontWeight.SemiBold, false, Kit.C.sub)
	footNote.LayoutOrder = 1
	footNote.Size = UDim2.fromScale(0, 1)
	Kit.fill(footNote)

	-- GARAGE and the car over the car, the cash in the corner.
	local head = Kit.frame(root, "Head")
	head.Position = UDim2.fromOffset(M + panelW + (if touch then 24 else 40), M)
	head.AutomaticSize = Enum.AutomaticSize.XY
	Kit.list(head, true, 2)
	local title = Parts.title(head, if touch then 22 else 30)
	title.LayoutOrder = 1
	local carLine = Kit.text(head, "Car", "", if touch then 11 else 14, Enum.FontWeight.ExtraBold, true, Kit.C.tabInk)
	carLine.LayoutOrder = 2
	carLine.AutomaticSize = Enum.AutomaticSize.X
	carLine.Size = UDim2.fromOffset(0, if touch then 14 else 18)
	carLine.TextTruncate = Enum.TextTruncate.None
	local cash = Parts.cash(root, if touch then 30 else 36, if touch then 16 else 20)
	cash.root.AnchorPoint = Vector2.new(1, 0)
	cash.root.Position = UDim2.new(0, room.X - M, 0, M)

	-- The dock: the categories, the layout switch, the action, EXIT.
	local dock, dockBody = Kit.panel(root, "Dock", if touch then 14 else 16)
	dock.Position = UDim2.fromOffset(M, room.Y - M - dockH)
	dock.Size = UDim2.fromOffset(room.X - 2 * M, dockH)
	Kit.pad(dockBody, 4, 4, 4, 4)
	Kit.list(dockBody, false, 6, Enum.VerticalAlignment.Center)
	local h = dockH - 8
	local tabs = Parts.dockTabs(dockBody, ctx, h, if touch then 100 else 150, if touch then 58 else 82, if touch then 8 else 10, if touch then 4 else 6)
	tabs.root.LayoutOrder = 1
	local gap = Kit.frame(dockBody, "Spacer")
	gap.LayoutOrder = 2
	gap.Size = UDim2.fromOffset(0, 1)
	Kit.fill(gap)
	local layoutButton = Parts.square(dockBody, "Layout", h, h, Parts.ICON.layout, nil, "LAYOUT")
	layoutButton.LayoutOrder = 3
	layoutButton.Activated:Connect(function()
		if not ctx.busy() then
			ctx.act.nextLayout()
		end
	end)
	local action = Parts.action(dockBody, ctx, if touch then 170 else 240, h, if touch then 15 else 19)
	action.root.LayoutOrder = 4
	local exit = Parts.square(dockBody, "Exit", if touch then 54 else 66, h, nil, "×", "EXIT")
	exit.LayoutOrder = 5
	exit.Activated:Connect(function()
		if not ctx.busy() then
			ctx.act.leave()
		end
	end)

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
		items.fill(ctx.entries())
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
		foot.Visible = f.name ~= ""
		footName.Text = if f.rare then `<font color="#{Parts.C.dusk:ToHex()}">◆</font> {f.name}` else f.name
		footNote.Text = f.note
		carLine.Text = `{ctx.carName()}, {ctx.carDrive()}`
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

return Dock
