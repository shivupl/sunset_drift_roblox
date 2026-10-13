--!strict
-- PICKER: the car picker's COMPACT, the menu's simplest CARS look and the
-- one it starts on (the owner, 2026-10-12: "the old layouts were internally
-- a bit better ... on start, it should be simple"). One panel down the
-- left with the road open beside it: CARS and the header's buttons (the
-- plates, the settings, the next look, close), the drive tabs, the wide
-- cards two across, and the picked car's name over SPAWN at the foot.
local Client = script.Parent.Parent.Parent
local Kit = require(Client:WaitForChild("CarPicker"):WaitForChild("Kit"))
local Looks = Client:WaitForChild("Garage"):WaitForChild("Looks")
local Types = require(Looks:WaitForChild("Types"))
local Parts = require(Looks:WaitForChild("Parts"))

local Picker = {}

-- The page's title: its tab's words (CARS سيارات).
local function titleOf(ctx: Types.Ctx): { en: string, ar: string }
	for _, t in ctx.tabs do
		if t.id == ctx.tab() then
			return { en = t.label, ar = t.arabic }
		end
	end
	return ctx.title
end

function Picker.build(gui: ScreenGui, ctx: Types.Ctx): Types.View
	local touch = ctx.touch
	local root, room = Parts.root(gui, ctx, "Picker")
	local scale = Parts.scaleFor(touch, ctx.screen)
	local w = if touch then 360 else 468
	local h = if touch then room.Y - 16 else math.min(630, room.Y - 24)
	local frame, panel = Kit.panel(root, "Panel", if touch then 14 else 16)
	frame.Position = UDim2.fromOffset(if touch then 8 else 16, if touch then 8 else 12)
	frame.Size = UDim2.fromOffset(w, h)
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
	Parts.title(head, if touch then 24 else 30, titleOf(ctx))
	local spacer = Kit.frame(head, "Spacer")
	spacer.LayoutOrder = 2
	spacer.Size = UDim2.fromOffset(0, 1)
	Kit.fill(spacer)
	local buttons = Parts.headerButtons(head, ctx, if touch then 32 else 36, if touch then 4 else 6)
	buttons.LayoutOrder = 4

	local subH = if touch then 30 else 34
	local tabRow = Kit.frame(panel, "Filter")
	tabRow.LayoutOrder = 2
	tabRow.Size = UDim2.new(1, 0, 0, subH)
	Kit.pad(tabRow, 0, 0, 0, 5)

	local note = Parts.note(panel, if touch then 10 else 12)
	note.LayoutOrder = 3

	local cards = Parts.cards(panel, ctx, 2, if touch then 104 else 138, if touch then 8 else 10)
	cards.root.LayoutOrder = 4
	cards.root.Size = UDim2.fromScale(1, 0)
	Kit.fill(cards.root)

	local actionH = if touch then 44 else 52
	local foot = Kit.frame(panel, "Foot")
	foot.LayoutOrder = 5
	foot.Size = UDim2.new(1, 0, 0, if touch then 46 else 58)
	Kit.list(foot, false, 10, Enum.VerticalAlignment.Center)
	local info = Kit.frame(foot, "Info")
	info.LayoutOrder = 1
	info.Size = UDim2.fromScale(0, 1)
	Kit.fill(info)
	local name = Kit.text(info, "Name", "", if touch then 15 else 17, Enum.FontWeight.ExtraBold, true)
	name.Position = UDim2.fromScale(0, 0.12)
	name.Size = UDim2.new(1, 0, 0.45, 0)
	local line = Kit.text(info, "Note", "", if touch then 10 else 11, Enum.FontWeight.SemiBold, false, Kit.C.sub)
	line.Position = UDim2.fromScale(0, 0.58)
	line.Size = UDim2.new(1, 0, 0.3, 0)
	local action = Parts.action(foot, ctx, if touch then 176 else 230, actionH, if touch then 15 else 19)
	action.root.LayoutOrder = 2

	-- No subject of its own: the picked car is its card.
	local stage = Kit.frame(root, "Stage")
	stage.Visible = false

	local subs: Parts.Picker? = nil
	local function fill()
		local s = subs
		if s then
			s.root:Destroy()
		end
		subs = Parts.slants(tabRow, ctx, ctx.views(), subH, if touch then 11 else 13, if touch then 4 else 6)
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
		local drive = ctx.carDrive()
		line.Text = (if f.label == "RESPAWN" then "IN USE   ·   " else "") .. drive
	end

	local pieces: Parts.Pieces = {
		room = room,
		scale = scale,
		left = { frame },
		right = {},
		top = {},
		bottom = {},
		content = { frame },
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

return Picker
