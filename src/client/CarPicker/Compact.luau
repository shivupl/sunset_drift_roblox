--!strict
-- COMPACT: a panel down the left, the road left open beside it. CARS and
-- the header buttons, the tabs, the boxes two across scrolling down, and
-- the picked car's name over SPAWN at the foot.
local Kit = require(script.Parent:WaitForChild("Kit"))
local Types = require(script.Parent:WaitForChild("Types"))
local Common = require(script.Parent:WaitForChild("Common"))

local Compact = {}

function Compact.build(gui: ScreenGui, ctx: Types.Ctx): Types.View
	local touch = ctx.touch
	local root = Kit.frame(gui, "Compact")
	local _, room = Common.fit(ctx, root)
	local w = if touch then 360 else 468
	local h = if touch then room.Y - 16 else math.min(630, room.Y - 24)
	root.Position = UDim2.fromOffset(if touch then 8 else 16, if touch then 8 else 12)
	root.Size = UDim2.fromOffset(w, h)

	local frame, panel = Kit.panel(root, "Panel", if touch then 14 else 16)
	frame.Size = UDim2.fromScale(1, 1)
	if touch then
		Kit.pad(panel, 10, 12, 10, 12)
	else
		Kit.pad(panel, 16, 16, 16, 16)
	end
	Kit.list(panel, true, if touch then 8 else 12)

	local head = Kit.frame(panel, "Header")
	head.LayoutOrder = 1
	head.Size = UDim2.new(1, 0, 0, if touch then 36 else 44)
	Kit.list(head, false, 10, Enum.VerticalAlignment.Center)
	Common.title(head, if touch then 24 else 30)
	Common.spacer(head, 2)
	local count = Kit.text(head, "Count", "", 12, Enum.FontWeight.SemiBold, false, Kit.C.faint)
	count.LayoutOrder = 3
	count.AutomaticSize = Enum.AutomaticSize.X
	count.Size = UDim2.fromScale(0, 1)
	count.Visible = not touch
	local buttons = Common.headerButtons(head, ctx, if touch then 32 else 36, if touch then 4 else 6)
	buttons.LayoutOrder = 4

	local tabRow = Kit.frame(panel, "Filter")
	tabRow.LayoutOrder = 2
	tabRow.Size = UDim2.new(1, 0, 0, if touch then 30 else 34)
	Kit.pad(tabRow, 0, 0, 0, 5)
	local tabs = Common.tabs(tabRow, ctx, if touch then 30 else 34, if touch then 11 else 13, if touch then 4 else 6, if touch then 48 else 58)

	local grid = Common.grid(panel, ctx, 2, if touch then 104 else 138, if touch then 8 else 10)
	grid.root.LayoutOrder = 3
	grid.root.Size = UDim2.fromScale(1, 0)
	Kit.fill(grid.root)

	local foot = Kit.frame(panel, "Foot")
	foot.LayoutOrder = 4
	foot.Size = UDim2.new(1, 0, 0, if touch then 46 else 58)
	Kit.list(foot, false, 10, Enum.VerticalAlignment.Center)
	local info = Kit.frame(foot, "Info")
	info.LayoutOrder = 1
	info.Size = UDim2.fromScale(0, 1)
	Kit.fill(info)
	local name = Kit.text(info, "Name", "", if touch then 15 else 17, Enum.FontWeight.ExtraBold, true)
	name.Position = UDim2.fromScale(0, 0.12)
	name.Size = UDim2.new(1, 0, 0.45, 0)
	local note = Kit.text(info, "Note", "", if touch then 10 else 11, Enum.FontWeight.SemiBold, false, Kit.C.sub)
	note.Position = UDim2.fromScale(0, 0.58)
	note.Size = UDim2.new(1, 0, 0.3, 0)
	local spawn = Kit.spawnButton(foot, UDim.new(0, if touch then 176 else 230), if touch then 44 else 52, if touch then 15 else 19, ctx.act.spawn)
	spawn.root.LayoutOrder = 2

	local function refresh()
		local st = ctx.state
		tabs.set(st.filter)
		grid.refresh()
		local car = Common.find(ctx, st.selected)
		local now = car.id == st.current
		name.Text = car.name
		note.Text = (if now then "IN USE   ·   " else "") .. car.drive
		local shown = 0
		for _, c in ctx.cars do
			if Common.visible(ctx, c) then
				shown += 1
			end
		end
		count.Text = shown .. (if shown == 1 then " car" else " cars")
		spawn.set(if st.busy then "…" elseif now then "RESPAWN" else "SPAWN THIS CAR", not st.busy)
	end
	return {
		refresh = refresh,
		destroy = function()
			root:Destroy()
		end,
	}
end

return Compact
