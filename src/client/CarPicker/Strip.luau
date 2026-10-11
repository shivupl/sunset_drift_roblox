--!strict
-- STRIP: a car-select band across the bottom of the screen, the world left
-- open above it. The picked car's name large on the left with its drive
-- and IN USE, SPAWN and the header buttons on the right; the tabs; then the
-- boxes in one row scrolling sideways.
local Kit = require(script.Parent:WaitForChild("Kit"))
local Types = require(script.Parent:WaitForChild("Types"))
local Common = require(script.Parent:WaitForChild("Common"))
local Art = require(script.Parent:WaitForChild("Art"))

local Strip = {}

function Strip.build(gui: ScreenGui, ctx: Types.Ctx): Types.View
	local touch = ctx.touch
	local root = Kit.frame(gui, "Strip")
	local scale, room = Common.fit(ctx, root)
	local bandH = if touch then 226 else 334
	-- The band spans the screen whatever the scale.
	root.AnchorPoint = Vector2.new(0, 1)
	root.Position = UDim2.fromScale(0, 1)
	root.Size = UDim2.fromOffset(room.X, bandH)
	local _ = scale

	local shade = Kit.frame(root, "Shade", Color3.fromHex("#0A0A0C"), 0)
	shade.Size = UDim2.fromScale(1, 1)
	shade.ZIndex = 0
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.18),
		NumberSequenceKeypoint.new(1, 0.06),
	})
	fade.Parent = shade
	local dots = Kit.image(root, "Dots", Art.dots)
	dots.ScaleType = Enum.ScaleType.Tile
	dots.TileSize = UDim2.fromOffset(9, 9)
	dots.AnchorPoint = Vector2.new(0, 1)
	dots.Position = UDim2.fromScale(0, 1)
	dots.Size = UDim2.fromScale(0.45, 0.7)
	dots.ZIndex = 0
	local dotFade = Instance.new("UIGradient")
	dotFade.Transparency = NumberSequence.new(0.94, 1)
	dotFade.Parent = dots

	local body = Kit.frame(root, "Body")
	body.Size = UDim2.fromScale(1, 1)
	if touch then
		Kit.pad(body, 18, 12, 10, 12)
	else
		Kit.pad(body, 34, 40, 22, 40)
	end
	Kit.list(body, true, if touch then 7 else 12)

	-- The picked car, SPAWN, the buttons.
	local top = Kit.frame(body, "Top")
	top.LayoutOrder = 1
	top.Size = UDim2.new(1, 0, 0, if touch then 48 else 70)
	Kit.list(top, false, if touch then 10 else 16, Enum.VerticalAlignment.Bottom)
	local info = Kit.frame(top, "Info")
	info.LayoutOrder = 1
	info.AutomaticSize = Enum.AutomaticSize.X
	info.Size = UDim2.fromScale(0, 1)
	Kit.list(info, true, if touch then 2 else 6, Enum.VerticalAlignment.Bottom)
	local caption = Kit.frame(info, "Caption")
	caption.LayoutOrder = 1
	caption.AutomaticSize = Enum.AutomaticSize.X
	caption.Size = UDim2.fromOffset(0, if touch then 12 else 15)
	Kit.list(caption, false, 10, Enum.VerticalAlignment.Center)
	local cap = Kit.text(caption, "English", "CHOOSE YOUR CAR", if touch then 9 else 11, Enum.FontWeight.ExtraBold, false, Kit.C.sub)
	cap.AutomaticSize = Enum.AutomaticSize.X
	cap.Size = UDim2.fromScale(0, 1)
	cap.TextTruncate = Enum.TextTruncate.None
	local capAr = Kit.text(caption, "Arabic", "اختر سيارتك", if touch then 11 else 13, Enum.FontWeight.Bold, false, Kit.C.sub)
	capAr.LayoutOrder = 1
	capAr.AutomaticSize = Enum.AutomaticSize.X
	capAr.Size = UDim2.fromScale(0, 1)
	capAr.TextTruncate = Enum.TextTruncate.None
	local nameRow = Kit.frame(info, "NameRow")
	nameRow.LayoutOrder = 2
	nameRow.AutomaticSize = Enum.AutomaticSize.X
	nameRow.Size = UDim2.fromOffset(0, if touch then 30 else 46)
	Kit.list(nameRow, false, if touch then 9 else 14, Enum.VerticalAlignment.Center)
	local name = Kit.text(nameRow, "Name", "", if touch then 26 else 44, Enum.FontWeight.Heavy, true)
	name.LayoutOrder = 1
	name.AutomaticSize = Enum.AutomaticSize.X
	name.Size = UDim2.fromScale(0, 1)
	name.TextTruncate = Enum.TextTruncate.None
	local chipHolder = Kit.frame(nameRow, "Drive")
	chipHolder.LayoutOrder = 2
	chipHolder.AutomaticSize = Enum.AutomaticSize.X
	chipHolder.Size = UDim2.fromOffset(0, if touch then 18 else 24)
	local chip: Frame? = nil
	local inUse = Kit.inUse(nameRow, if touch then 16 else 22, if touch then 8 else 10)
	inUse.LayoutOrder = 3
	Common.spacer(top, 2)
	local spawn = Kit.spawnButton(top, UDim.new(0, if touch then 180 else 300), if touch then 44 else 58, if touch then 15 else 21, ctx.act.spawn)
	spawn.root.LayoutOrder = 3
	local buttons = Common.headerButtons(top, ctx, if touch then 40 else 46, if touch then 4 else 6)
	buttons.LayoutOrder = 4

	-- The tabs and the count.
	local filter = Kit.frame(body, "Filter")
	filter.LayoutOrder = 2
	filter.Size = UDim2.new(1, 0, 0, if touch then 28 else 34)
	Kit.list(filter, false, 12, Enum.VerticalAlignment.Center)
	local tabHolder = Kit.frame(filter, "TabHolder")
	tabHolder.LayoutOrder = 1
	tabHolder.AutomaticSize = Enum.AutomaticSize.X
	tabHolder.Size = UDim2.fromScale(0, 1)
	Kit.pad(tabHolder, 0, 0, 0, 5)
	local tabs = Common.tabs(tabHolder, ctx, if touch then 28 else 32, if touch then 11 else 13, if touch then 4 else 6, if touch then 46 else 58)
	Common.spacer(filter, 2)
	local count = Kit.text(filter, "Count", "", if touch then 10 else 12, Enum.FontWeight.SemiBold, false, Kit.C.sub)
	count.LayoutOrder = 3
	count.AutomaticSize = Enum.AutomaticSize.X
	count.Size = UDim2.fromScale(0, 1)

	-- The boxes, one row.
	local grid = Common.grid(body, ctx, 1, 0, if touch then 8 else 12, if touch then 168 else 208)
	grid.root.LayoutOrder = 3
	grid.root.Size = UDim2.fromScale(1, 0)
	Kit.fill(grid.root)

	local function refresh()
		local st = ctx.state
		local car = Common.find(ctx, st.selected)
		local now = car.id == st.current
		name.Text = car.name
		local old = chip
		if old then
			old:Destroy()
		end
		chip = Kit.chip(chipHolder, car.drive, if touch then 18 else 24, if touch then 9 else 11)
		inUse.Visible = now
		local shown = 0
		for _, c in ctx.cars do
			if Common.visible(ctx, c) then
				shown += 1
			end
		end
		count.Text = shown .. (if shown == 1 then " car" else " cars")
		spawn.set(if st.busy then "…" elseif now then "RESPAWN" else "SPAWN THIS CAR", not st.busy)
		tabs.set(st.filter)
		grid.refresh()
	end
	return {
		refresh = refresh,
		destroy = function()
			root:Destroy()
		end,
	}
end

return Strip
