--!strict
-- The CARS page's own looks (2026-10-12, the owner: "the old layouts were
-- internally a bit better the rhs boxes, the overall styling. on start, it
-- should be simple. make a couple more variations ... maybe ones that
-- combine all options for the cars menu"), cycled by the LAYOUT button in
-- the cars header; PLATES and SETTINGS keep the screen's layout (Layouts).
--
--   PICKER    the picker's one panel down the left: the tabs, the wide
--             cards two across, the picked car's name over SPAWN. The
--             start.
--   SHOWROOM  the picker's two panels: the picked car with its stats and
--             SPAWN on the left, the tabs, a search and the cards on the
--             right.
--   FRAME     the screen's one frame (the words, the coins, EXIT) with the
--             wide cards one to a row, a search over them, the picked car
--             on the stage in the middle.
--
-- The choice is the LocalPlayer attribute CarsLayout (it lasts the
-- session).
local Players = game:GetService("Players")

local Looks = script.Parent.Parent:WaitForChild("Garage"):WaitForChild("Looks")
local Types = require(Looks:WaitForChild("Types"))
local Showcase = require(Looks:WaitForChild("Showcase"))
local Picker = require(script.Parent:WaitForChild("Looks"):WaitForChild("Picker"))
local Showroom = require(script.Parent:WaitForChild("Looks"):WaitForChild("Showroom"))

local CarsLayouts = {}

CarsLayouts.ATTRIBUTE = "CarsLayout"

CarsLayouts.all = {
	{ id = "picker", name = "PICKER", build = Picker.build },
	{ id = "showroom", name = "SHOWROOM", build = Showroom.build },
	{
		id = "frame",
		name = "FRAME",
		build = function(g: ScreenGui, c: Types.Ctx): Types.View
			return Showcase.build(g, c, "glass", { reach = 24, scroller = "rail", cards = true })
		end,
	},
} :: { Types.Layout }

function CarsLayouts.current(): Types.Layout
	local id = Players.LocalPlayer:GetAttribute(CarsLayouts.ATTRIBUTE)
	for _, l in CarsLayouts.all do
		if l.id == id then
			return l
		end
	end
	return CarsLayouts.all[1]
end

function CarsLayouts.set(id: string)
	Players.LocalPlayer:SetAttribute(CarsLayouts.ATTRIBUTE, id)
end

-- The one after the current.
function CarsLayouts.after(): Types.Layout
	local list = CarsLayouts.all
	return list[(table.find(list, CarsLayouts.current()) or 0) % #list + 1]
end

return CarsLayouts
