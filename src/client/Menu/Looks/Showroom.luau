--!strict
-- SHOWROOM: the car picker's two panels (the owner's favourite of its
-- looks), the menu's CARS (2026-10-12; of PICKER, SHOWROOM and FRAME
-- tried, "lets go with showroom for the cars menu"). On the left the
-- picked car: its name, drive chip and star over it, on a lit stage with
-- IN USE when you are in it, its weight and length under it, and SPAWN.
-- On the right CARS with the header's buttons (the plates, the settings,
-- close), the drive tabs with a search beside them, and the wide cards
-- two across.
local Client = script.Parent.Parent.Parent
local Kit = require(Client:WaitForChild("CarPicker"):WaitForChild("Kit"))
local CarArt = require(Client:WaitForChild("CarPicker"):WaitForChild("Art"))
local Looks = Client:WaitForChild("Garage"):WaitForChild("Looks")
local Types = require(Looks:WaitForChild("Types"))
local Parts = require(Looks:WaitForChild("Parts"))

local Showroom = {}

local function titleOf(ctx: Types.Ctx): { en: string, ar: string }
	for _, t in ctx.tabs do
		if t.id == ctx.tab() then
			return { en = t.label, ar = t.arabic }
		end
	end
	return ctx.title
end

function Showroom.build(gui: ScreenGui, ctx: Types.Ctx): Types.View
	local touch = ctx.touch
	local root, room = Parts.root(gui, ctx, "Showroom")
	local scale = Parts.scaleFor(touch, ctx.screen)
	local w = if touch then math.min(748, room.X - 16) else math.min(1060, room.X - 40)
	local h = if touch then room.Y - 16 else math.min(604, room.Y - 24)
	local gap = if touch then 8 else 10
	local leftW = if touch then 262 else 360
	local x0 = math.floor((room.X - w) / 2)
	local y0 = if touch then 8 else 12

	------------------------------------------------------------------
	-- The picked car.
	local leftFrame, left = Kit.panel(root, "Picked", if touch then 14 else 16)
	leftFrame.Position = UDim2.fromOffset(x0, y0)
	leftFrame.Size = UDim2.fromOffset(leftW, h)
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
	local chipText = ""
	local star = Kit.iconButton(head, "Fav", CarArt.starLine, if touch then 32 else 36)
	star.LayoutOrder = 3
	star.Activated:Connect(function()
		local fn = ctx.act.star
		if fn and not ctx.busy() then
			fn()
		end
	end)
	local starIcon = star:FindFirstChild("Icon") :: ImageLabel

	-- The stage: the page draws the car and its stats in it (Cars.stage);
	-- the IN USE tag sits over its top left.
	local actionH = if touch then 44 else 52
	local stage = Kit.frame(left, "Stage")
	stage.LayoutOrder = 2
	stage.Size = UDim2.fromScale(1, 0)
	Kit.fill(stage)
	local inUse = Kit.inUse(stage, if touch then 18 else 22, if touch then 9 else 11)
	inUse.Position = UDim2.fromOffset(6, 6)
	inUse.ZIndex = 5
	inUse.Visible = false

	local action = Parts.action(left, ctx, leftW - (if touch then 20 else 32), actionH, if touch then 15 else 19)
	action.root.LayoutOrder = 3

	------------------------------------------------------------------
	-- The cars.
	local rightFrame, right = Kit.panel(root, "Cars", if touch then 14 else 16)
	rightFrame.Position = UDim2.fromOffset(x0 + leftW + gap, y0)
	rightFrame.Size = UDim2.fromOffset(w - leftW - gap, h)
	if touch then
		Kit.pad(right, 10, 12, 10, 12)
	else
		Kit.pad(right, 16, 16, 16, 16)
	end
	Kit.list(right, true, if touch then 8 else 12)

	local header = Kit.frame(right, "Header")
	header.LayoutOrder = 1
	header.Size = UDim2.new(1, 0, 0, if touch then 36 else 44)
	Kit.list(header, false, 10, Enum.VerticalAlignment.Center)
	Parts.title(header, if touch then 24 else 30, titleOf(ctx))
	local spacer = Kit.frame(header, "Spacer")
	spacer.LayoutOrder = 2
	spacer.Size = UDim2.fromOffset(0, 1)
	Kit.fill(spacer)
	local buttons = Parts.headerButtons(header, ctx, if touch then 32 else 36, if touch then 4 else 6)
	buttons.LayoutOrder = 4

	local subH = if touch then 30 else 34
	local filter = Kit.frame(right, "Filter")
	filter.LayoutOrder = 2
	filter.Size = UDim2.new(1, 0, 0, subH)
	Kit.list(filter, false, 8, Enum.VerticalAlignment.Center)
	local subHolder = Kit.frame(filter, "Subs")
	subHolder.LayoutOrder = 1
	subHolder.AutomaticSize = Enum.AutomaticSize.X
	subHolder.Size = UDim2.fromOffset(0, subH)
	Kit.pad(subHolder, 0, 0, 0, 5)
	local gapF = Kit.frame(filter, "Gap")
	gapF.LayoutOrder = 2
	gapF.Size = UDim2.fromOffset(0, 1)
	Kit.fill(gapF)
	local searchHolder = Kit.frame(filter, "SearchHolder")
	searchHolder.LayoutOrder = 3
	searchHolder.Size = UDim2.new(0, if touch then 120 else 180, 1, 0)
	Parts.searchBox(searchHolder, ctx, subH, if touch then 11 else 13)

	local note = Parts.note(right, if touch then 10 else 12)
	note.LayoutOrder = 3

	local cards = Parts.cards(right, ctx, 2, if touch then 104 else 138, if touch then 8 else 10)
	cards.root.LayoutOrder = 4
	cards.root.Size = UDim2.fromScale(1, 0)
	Kit.fill(cards.root)

	local subs: Parts.Picker? = nil
	local function fill()
		local s = subs
		if s then
			s.root:Destroy()
		end
		subs = Parts.slants(subHolder, ctx, ctx.views(), subH, if touch then 10 else 13, if touch then 4 else 6)
		cards.fill(ctx.entries())
	end

	local function refresh()
		local s = subs
		if s then
			s.set(ctx.view())
		end
		local n = ctx.note()
		note.Visible = n ~= nil
		note.Text = n or ""
		cards.refresh()
		local f = ctx.foot()
		action.set(f)
		name.Text = f.name
		inUse.Visible = f.label == "RESPAWN"
		local drive = ctx.carDrive()
		if drive ~= chipText then
			chipText = drive
			local old = chip
			if old then
				old:Destroy()
			end
			chip = if drive ~= "" then Kit.chip(chipHolder, drive, if touch then 19 else 22, if touch then 9 else 11) else nil
		end
		local st = ctx.starred
		local v = if st then st() else nil
		star.Visible = v ~= nil
		local fav = v == true
		starIcon.Image = if fav then CarArt.star else CarArt.starLine
		starIcon.ImageColor3 = if fav then Kit.C.green else Color3.new(1, 1, 1)
		starIcon.ImageTransparency = if fav then 0 else 0.4
	end

	local pieces: Parts.Pieces = {
		room = room,
		scale = scale,
		left = { leftFrame },
		right = { rightFrame },
		top = {},
		bottom = {},
		content = { leftFrame, rightFrame },
	}
	return {
		root = root,
		stage = stage,
		fill = fill,
		refresh = refresh,
		pop = cards.pop,
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

return Showroom
