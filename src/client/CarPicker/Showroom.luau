--!strict
-- SHOWROOM: two panels, after the store garage the owner showed. On the
-- left the picked car on a lit stage, its name, drive and favourite star,
-- what it is like, its weight and length, and SPAWN; on the right CARS,
-- the tabs, a search, and the boxes (three across on a PC, two on a phone).
local Kit = require(script.Parent:WaitForChild("Kit"))
local Types = require(script.Parent:WaitForChild("Types"))
local Common = require(script.Parent:WaitForChild("Common"))
local Art = require(script.Parent:WaitForChild("Art"))

local Showroom = {}

function Showroom.build(gui: ScreenGui, ctx: Types.Ctx): Types.View
	local touch = ctx.touch
	local root = Kit.frame(gui, "Showroom")
	local _, room = Common.fit(ctx, root)
	local w = if touch then math.min(748, room.X - 16) else math.min(1060, room.X - 40)
	local h = if touch then room.Y - 16 else math.min(604, room.Y - 24)
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, if touch then 8 else 12)
	root.Size = UDim2.fromOffset(w, h)
	Kit.list(root, false, if touch then 8 else 10)

	------------------------------------------------------------------
	-- The picked car.
	local leftFrame, left = Kit.panel(root, "Picked", if touch then 14 else 16)
	leftFrame.LayoutOrder = 1
	leftFrame.Size = UDim2.new(0, if touch then 262 else 360, 1, 0)
	if touch then
		Kit.pad(left, 10, 10, 10, 10)
	else
		Kit.pad(left, 16, 16, 16, 16)
	end
	Kit.list(left, true, if touch then 8 else 12)

	local head = Kit.frame(left, "Head")
	head.LayoutOrder = 1
	head.Size = UDim2.new(1, 0, 0, if touch then 32 else 36)
	Kit.list(head, false, 8, Enum.VerticalAlignment.Center)
	local name = Kit.text(head, "Name", "", if touch then 17 else 22, Enum.FontWeight.Heavy, true)
	name.LayoutOrder = 1
	name.Size = UDim2.fromScale(0, 1)
	Kit.fill(name)
	local chipHolder = Kit.frame(head, "Drive")
	chipHolder.LayoutOrder = 2
	chipHolder.AutomaticSize = Enum.AutomaticSize.X
	chipHolder.Size = UDim2.fromOffset(0, if touch then 19 else 22)
	local chip: Frame? = nil
	local star = Kit.iconButton(head, "Fav", Art.starLine, if touch then 32 else 36)
	star.LayoutOrder = 3
	star.Activated:Connect(function()
		ctx.act.fav(ctx.state.selected)
	end)
	local starIcon = star:FindFirstChild("Icon") :: ImageLabel

	local stageH = if touch then 118 else 214
	local stage = Kit.frame(left, "Stage", Color3.new(1, 1, 1), 0)
	stage.LayoutOrder = 2
	stage.Size = UDim2.new(1, 0, 0, stageH)
	stage.ClipsDescendants = true
	Kit.corner(stage, if touch then 10 else 12)
	Kit.gradient(stage, Color3.fromHex("#2E3035"), Color3.fromHex("#141517"))
	Kit.stroke(stage, Color3.new(1, 1, 1), 1, 0.93)
	local spot = Kit.image(stage, "Spot", Art.spot, Kit.C.spot, 0.15)
	spot.AnchorPoint = Vector2.new(0.5, 0.5)
	spot.Position = UDim2.fromScale(0.5, 0.36)
	spot.Size = UDim2.fromScale(1.1, 1.4)
	local ring = Kit.image(stage, "Ring", Art.ring, Color3.new(1, 1, 1), 0.965)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.44)
	ring.Size = UDim2.fromOffset(math.floor(stageH * 1.2), math.floor(stageH * 1.2))
	local mark = Kit.text(stage, "Watermark", "", math.floor(stageH * 0.45), Enum.FontWeight.Heavy, true)
	mark.TextTransparency = 0.95
	mark.AnchorPoint = Vector2.new(1, 1)
	mark.Position = UDim2.new(1, -8, 1, math.floor(stageH * 0.09))
	mark.Size = UDim2.new(1, 0, 0, math.floor(stageH * 0.45))
	mark.TextXAlignment = Enum.TextXAlignment.Right
	mark.TextTruncate = Enum.TextTruncate.None
	local floor = Kit.image(stage, "Floor", Art.spot, Color3.new(0, 0, 0), 0.45)
	floor.AnchorPoint = Vector2.new(0.5, 1)
	floor.Position = UDim2.new(0.5, 0, 1, -math.floor(stageH * 0.06))
	floor.Size = UDim2.new(0.8, 0, 0, math.floor(stageH * 0.16))
	local photo = Kit.image(stage, "Photo", "")
	photo.ScaleType = Enum.ScaleType.Fit
	photo.Position = UDim2.new(0.04, 0, 0, math.floor(stageH * 0.05))
	photo.Size = UDim2.new(0.92, 0, 0.9, 0)
	local inUse = Kit.inUse(stage, if touch then 16 else 20, if touch then 8 else 10)
	inUse.Position = UDim2.fromOffset(if touch then 8 else 12, if touch then 7 else 10)

	local blurb = Kit.text(left, "Blurb", "", 13, Enum.FontWeight.Medium, false, Color3.fromHex("#A7ABB2"))
	blurb.LayoutOrder = 3
	blurb.TextWrapped = true
	blurb.TextYAlignment = Enum.TextYAlignment.Top
	blurb.TextTruncate = Enum.TextTruncate.None
	blurb.AutomaticSize = Enum.AutomaticSize.Y
	blurb.Size = UDim2.fromScale(1, 0)
	blurb.LineHeight = 1.15
	blurb.Visible = not touch -- a phone has the height for the bars only

	local stats = Common.stats(left, if touch then 11 else 12, if touch then 14 else 16, if touch then 9 else 12, if touch then 7 else 12)
	stats.root.LayoutOrder = 4
	Common.spacer(left, 5).Size = UDim2.fromScale(1, 0)
	local spawn = Kit.spawnButton(left, UDim.new(1, 0), if touch then 46 else 54, if touch then 16 else 20, ctx.act.spawn)
	spawn.root.LayoutOrder = 6

	------------------------------------------------------------------
	-- The cars.
	local rightFrame, right = Kit.panel(root, "Cars", if touch then 14 else 16)
	rightFrame.LayoutOrder = 2
	rightFrame.Size = UDim2.fromScale(0, 1)
	Kit.fill(rightFrame)
	if touch then
		Kit.pad(right, 10, 10, 10, 10)
	else
		Kit.pad(right, 18, 18, 16, 18)
	end
	Kit.list(right, true, if touch then 8 else 14)

	local top = Kit.frame(right, "Header")
	top.LayoutOrder = 1
	top.Size = UDim2.new(1, 0, 0, if touch then 32 else 40)
	Kit.list(top, false, 10, Enum.VerticalAlignment.Center)
	Common.title(top, if touch then 22 else 32)
	Common.spacer(top, 2)
	Common.headerButtons(top, ctx, if touch then 32 else 38, if touch then 4 else 6).LayoutOrder = 3

	local filter = Kit.frame(right, "Filter")
	filter.LayoutOrder = 2
	filter.Size = UDim2.new(1, 0, 0, if touch then 32 else 38)
	Kit.list(filter, false, if touch then 8 else 12, Enum.VerticalAlignment.Center)
	local tabHolder = Kit.frame(filter, "TabHolder")
	tabHolder.LayoutOrder = 1
	tabHolder.AutomaticSize = Enum.AutomaticSize.X
	tabHolder.Size = UDim2.fromScale(0, 1)
	Kit.pad(tabHolder, 0, 0, 0, 5)
	local tabs = Common.tabs(tabHolder, ctx, if touch then 30 else 36, if touch then 11 else 13, if touch then 4 else 6, if touch then 44 else 58)
	tabs.root.Position = UDim2.fromScale(0, 0)
	Common.spacer(filter, 2)
	local search = Kit.frame(filter, "Search", Color3.new(1, 1, 1), 0.94)
	search.LayoutOrder = 3
	search.Size = UDim2.new(0, if touch then 112 else 230, 1, 0)
	Kit.corner(search, 8)
	Kit.stroke(search, Color3.new(1, 1, 1), 1, 0.93)
	local glass = Kit.image(search, "Icon", Art.search, Kit.C.green)
	glass.AnchorPoint = Vector2.new(0, 0.5)
	glass.Position = UDim2.new(0, if touch then 8 else 12, 0.5, 0)
	glass.Size = UDim2.fromOffset(if touch then 13 else 16, if touch then 13 else 16)
	local box = Instance.new("TextBox")
	box.Name = "Query"
	box.BackgroundTransparency = 1
	box.ClearTextOnFocus = false
	box.Text = ctx.state.query
	box.PlaceholderText = if touch then "Search" else "Search cars"
	box.PlaceholderColor3 = Color3.fromHex("#7C818A")
	box.TextColor3 = Kit.C.text
	box.TextSize = if touch then 11 else 13
	box.FontFace = Kit.font(Enum.FontWeight.SemiBold)
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Position = UDim2.new(0, if touch then 27 else 37, 0, 0)
	box.Size = UDim2.new(1, -(if touch then 33 else 45), 1, 0)
	box.Parent = search
	box:GetPropertyChangedSignal("Text"):Connect(function()
		ctx.act.query(box.Text)
	end)

	local grid = Common.grid(right, ctx, if touch then 2 else 3, if touch then 104 else 136, if touch then 8 else 12)
	grid.root.LayoutOrder = 3
	grid.root.Size = UDim2.fromScale(1, 0)
	Kit.fill(grid.root)

	local function refresh()
		local st = ctx.state
		local car = Common.find(ctx, st.selected)
		local now = car.id == st.current
		local fav = st.favs[car.id] == true
		name.Text = car.name
		local old = chip
		if old then
			old:Destroy()
		end
		chip = Kit.chip(chipHolder, car.drive, if touch then 19 else 22, if touch then 9 else 11)
		starIcon.Image = if fav then Art.star else Art.starLine
		starIcon.ImageColor3 = if fav then Kit.C.green else Color3.new(1, 1, 1)
		starIcon.ImageTransparency = if fav then 0 else 0.4
		photo.Image = car.image or ""
		mark.Text = car.drive
		inUse.Visible = now
		blurb.Text = car.blurb
		stats.set(car)
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

return Showroom
