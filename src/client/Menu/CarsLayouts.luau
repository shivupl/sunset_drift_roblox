--!strict
-- The showroom's versions to try (2026-10-12, the owner, from the "Hajwala
-- Menus" canvas's row E: "implement one version with a side panel like
-- this and one like this. for the customize button, something like this,
-- make a couple options and add a temporary layout switch button"). Two
-- ways to PLATES, two places for CUSTOMIZE, every pairing, cycled by the
-- LAYOUT button in the showroom's header (temporary):
--   nav       rail     a narrow panel left of the showroom: CARS, PLATES,
--                      SETTINGS as icons over words, CLOSE at its foot.
--             segment  CARS | PLATES as one switch in the right panel's
--                      header, the count and close beside it.
--   customize stage    a dark pill with a green ring on the car's stage,
--                      bottom right.
--             button   a graphite slanted button beside RESPAWN.
-- CARS and PLATES both draw in the showroom; SETTINGS keeps the screen's
-- layout (Layouts). The choice is the LocalPlayer attribute CarsLayout.
local Players = game:GetService("Players")

local Looks = script.Parent.Parent:WaitForChild("Garage"):WaitForChild("Looks")
local Types = require(Looks:WaitForChild("Types"))
local Showroom = require(script.Parent:WaitForChild("Looks"):WaitForChild("Showroom"))

local CarsLayouts = {}

CarsLayouts.ATTRIBUTE = "CarsLayout"

local function look(id: string, name: string, opts: Showroom.Options): Types.Layout
	return {
		id = id,
		name = name,
		build = function(g: ScreenGui, c: Types.Ctx): Types.View
			return Showroom.build(g, c, opts)
		end,
	}
end

CarsLayouts.all = {
	look("railstage", "RAIL · STAGE", { nav = "rail", customize = "stage" }),
	look("railbutton", "RAIL · BUTTON", { nav = "rail", customize = "button" }),
	look("segmentstage", "SEGMENT · STAGE", { nav = "segment", customize = "stage" }),
	look("segmentbutton", "SEGMENT · BUTTON", { nav = "segment", customize = "button" }),
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
