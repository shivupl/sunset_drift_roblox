--!strict
-- SHADE (D. Garage on the "Hajwala Menus" canvas): the garage as it was
-- (garage-ui-overhaul: no panel box, a shade that melts into the garage, a
-- rail of category words) in the car picker's look. The rail down the
-- left, the category's name and the items right of it; along the
-- bottom EXIT and the sub-tabs as words with a green underline; the car on
-- the right under GARAGE, the item picked and the action under it, REV or
-- SHOP PLATES in the corner. The pill on the shade's edge folds it away.
local Kit = require(script.Parent.Parent.Parent:WaitForChild("CarPicker"):WaitForChild("Kit"))
local Types = require(script.Parent:WaitForChild("Types"))
local Parts = require(script.Parent:WaitForChild("Parts"))

local Shade = {}

function Shade.build(gui: ScreenGui, ctx: Types.Ctx): Types.View
	local touch = ctx.touch
	local root, room = Parts.root(gui, ctx, "Shade")
	local M = 8
	local railW = if touch then 116 else 156
	local contentW = if touch then 318 else 470
	local bottomH = if touch then 52 else 60
	local contentX = M + railW + 8
	local edge = contentX + contentW + 12

	-- The shade: dark under the panel (it counts as the panel: a drag there
	-- is not the turntable's), then a tail fading to clear that lets drags
	-- through (GarageView.overUi skips PassThrough). Both run half a screen
	-- past the gui's edges, into a notch's strip on any phone (UIKit.edgeToEdge).
	gui.ClipToDeviceSafeArea = false
	local tail = if touch then 110 else 200
	local shade = Kit.frame(root, "Shade", Color3.fromHex("#0A0A0C"), 0)
	shade.Position = UDim2.fromScale(-0.5, -0.5)
	shade.Size = UDim2.new(0.5, edge, 2, 0)
	shade.Active = true
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new(0.06, 0.14)
	g.Parent = shade
	local fadeOut = Kit.frame(root, "ShadeTail", Color3.fromHex("#0A0A0C"), 0)
	fadeOut.Position = UDim2.new(0, edge, -0.5, 0)
	fadeOut.Size = UDim2.new(0, tail, 2, 0)
	fadeOut:SetAttribute("PassThrough", true)
	local g2 = Instance.new("UIGradient")
	g2.Transparency = NumberSequence.new(0.14, 1)
	g2.Parent = fadeOut

	-- The rail.
	local rail = Parts.wordRail(root, ctx, if touch then 36 else 44, if touch then 12 else 15, if touch then 16 else 20, false)
	rail.root.Position = UDim2.fromOffset(M, M)
	rail.root.Size = UDim2.fromOffset(railW, 0)

	-- The category's name, the note, the items (the cash is the
	-- controller's, where the HUD has it: Parts.hudCash).
	local content = Kit.frame(root, "Content")
	content.Position = UDim2.fromOffset(contentX, M)
	content.Size = UDim2.fromOffset(contentW, room.Y - 3 * M - bottomH)
	Kit.list(content, true, if touch then 7 else 10)
	local headH = if touch then 28 else 34
	local top = Kit.frame(content, "Top")
	top.LayoutOrder = 1
	top.Size = UDim2.new(1, 0, 0, headH)
	Kit.list(top, false, 8, Enum.VerticalAlignment.Center)
	local headHolder = Kit.frame(top, "Heading")
	headHolder.AutomaticSize = Enum.AutomaticSize.X
	headHolder.Size = UDim2.fromOffset(0, headH)
	local spacer = Kit.frame(top, "Spacer")
	spacer.LayoutOrder = 2
	spacer.Size = UDim2.fromOffset(0, 1)
	Kit.fill(spacer)
	local note = Parts.note(content, if touch then 11 else 13)
	note.LayoutOrder = 2
	local m: Parts.BoxMetrics = if touch
		then { name = 9.5, word = 8.5, swatch = 34, rows = false, inline = false }
		else { name = 12, word = 11, swatch = 46, rows = false, inline = false }
	local items = Parts.items(content, ctx, if touch then 3 else 4, if touch then 1 else 2, if touch then 84 else 110, if touch then 46 else 56, if touch then 7 else 9, m)
	items.root.LayoutOrder = 3
	items.root.Size = UDim2.fromScale(1, 0)
	Kit.fill(items.root)

	-- Along the bottom: EXIT and the layout switch under the rail, the
	-- sub-tabs as words.
	local by = room.Y - M - bottomH
	local exitW = if touch then 84 else 104
	local exit = Parts.exit(root, exitW, bottomH - 8, if touch then 12 else 14)
	exit.Position = UDim2.fromOffset(M, by + 4)
	exit.Activated:Connect(function()
		if not ctx.busy() then
			ctx.act.leave()
		end
	end)
	local layoutButton = Parts.square(root, "Layout", bottomH - 8, bottomH - 8, Parts.ICON.layout)
	layoutButton.Position = UDim2.fromOffset(M + exitW + 6, by + 4)
	layoutButton.Activated:Connect(function()
		if not ctx.busy() then
			ctx.act.nextLayout()
		end
	end)
	local subHolder = Kit.frame(root, "Subs")
	subHolder.Position = UDim2.fromOffset(M + exitW + 6 + (bottomH - 8) + (if touch then 18 else 26), by)
	subHolder.Size = UDim2.fromOffset(0, bottomH)
	subHolder.AutomaticSize = Enum.AutomaticSize.X

	-- The fold: a pill on the shade's edge, at mid height.
	local handle = Instance.new("TextButton")
	handle.Name = "Handle"
	handle.AutoButtonColor = false
	handle.BorderSizePixel = 0
	handle.BackgroundColor3 = Kit.C.panelTop
	handle.BackgroundTransparency = 0.1
	handle.AnchorPoint = Vector2.new(0, 0.5)
	handle.Position = UDim2.new(0, edge + 6, 0.5, 0)
	handle.Size = UDim2.fromOffset(if touch then 26 else 28, if touch then 60 else 72)
	handle.Text = "‹"
	handle.TextSize = if touch then 20 else 22
	handle.TextColor3 = Kit.C.text
	handle.FontFace = Kit.font(Enum.FontWeight.Bold)
	Kit.corner(handle, 13)
	Kit.stroke(handle, Color3.new(1, 1, 1), 1, 0.88)
	handle.Parent = root
	handle.Activated:Connect(function()
		if not ctx.busy() then
			ctx.act.collapse()
		end
	end)

	-- Over the car: GARAGE and the car, top right; the item picked over the
	-- action, bottom right, REV or SHOP PLATES beside it.
	local head = Kit.frame(root, "Head")
	head.AnchorPoint = Vector2.new(1, 0)
	head.Position = UDim2.fromOffset(room.X - M, M)
	head.AutomaticSize = Enum.AutomaticSize.XY
	local hl = Kit.list(head, true, 2)
	hl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	local title = Parts.title(head, if touch then 22 else 30)
	title.LayoutOrder = 1
	local carLine = Kit.text(head, "Car", "", if touch then 11 else 14, Enum.FontWeight.ExtraBold, true, Kit.C.tabInk)
	carLine.LayoutOrder = 2
	carLine.AutomaticSize = Enum.AutomaticSize.X
	carLine.Size = UDim2.fromOffset(0, if touch then 14 else 18)
	carLine.TextXAlignment = Enum.TextXAlignment.Right
	carLine.TextTruncate = Enum.TextTruncate.None

	local actionW = if touch then 230 else 280
	local extraW = bottomH - 4
	local action = Parts.action(root, ctx, actionW, bottomH, if touch then 17 else 21)
	action.root.AnchorPoint = Vector2.new(1, 1)
	local extra = Parts.square(root, "Extra", extraW, bottomH - 4, nil, nil, nil)
	extra.AnchorPoint = Vector2.new(1, 1)
	extra.Position = UDim2.fromOffset(room.X - M, room.Y - M - 2)
	local extraLabel = Kit.text(extra, "Label", "", if touch then 10 else 12, Enum.FontWeight.Heavy, true)
	extraLabel.Size = UDim2.fromScale(1, 1)
	extraLabel.TextXAlignment = Enum.TextXAlignment.Center
	extraLabel.TextWrapped = true
	extra.Activated:Connect(function()
		if not ctx.busy() then
			ctx.act.extra()
		end
	end)

	local pick = Kit.frame(root, "Picked", Kit.C.chip, 0.2)
	pick.AnchorPoint = Vector2.new(1, 1)
	pick.AutomaticSize = Enum.AutomaticSize.X
	pick.Size = UDim2.fromOffset(0, if touch then 26 else 30)
	Kit.corner(pick, 8)
	Kit.stroke(pick, Color3.new(1, 1, 1), 1, 0.9)
	Kit.pad(pick, 0, 10, 0, 10)
	Kit.list(pick, false, 8, Enum.VerticalAlignment.Center)
	local pickName = Kit.text(pick, "Name", "", if touch then 11 else 14, Enum.FontWeight.Heavy, true)
	pickName.RichText = true
	pickName.AutomaticSize = Enum.AutomaticSize.X
	pickName.Size = UDim2.fromScale(0, 1)
	pickName.TextTruncate = Enum.TextTruncate.None
	local pickNote = Kit.text(pick, "Note", "", if touch then 10 else 12, Enum.FontWeight.SemiBold, false, Kit.C.sub)
	pickNote.LayoutOrder = 1
	pickNote.AutomaticSize = Enum.AutomaticSize.X
	pickNote.Size = UDim2.fromScale(0, 1)
	pickNote.TextTruncate = Enum.TextTruncate.None

	local subs: Parts.Picker? = nil
	local heading: Frame? = nil

	local function placeRight(hasExtra: boolean)
		local right = room.X - M - (if hasExtra then extraW + 6 else 0)
		action.root.Position = UDim2.fromOffset(right, room.Y - M)
		pick.Position = UDim2.fromOffset(right, room.Y - M - bottomH - 6)
	end

	local function fill()
		local s, hd = subs, heading
		if s then
			s.root:Destroy()
		end
		if hd then
			hd:Destroy()
		end
		subs, heading = nil, nil
		for _, d in ctx.tabs do
			if d.id == ctx.tab() then
				heading = Parts.heading(headHolder, d, if touch then 20 else 26)
			end
		end
		local defs = ctx.views()
		if #defs > 1 then
			subs = Parts.words(subHolder, ctx, defs, bottomH, if touch then 13 else 15, if touch then 17 else 20, if touch then 20 else 28)
		end
		local x = ctx.extra()
		extra.Visible = x ~= nil
		extraLabel.Text = if x == "rev" then "REV" elseif x == "shop" then "SHOP" else ""
		placeRight(x ~= nil)
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
		pick.Visible = f.name ~= ""
		pickName.Text = if f.rare then `<font color="#{Parts.C.dusk:ToHex()}">◆</font> {f.name}` else f.name
		pickNote.Text = f.note
		carLine.Text = `{ctx.carName()}, {ctx.carDrive()}`
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

return Shade
