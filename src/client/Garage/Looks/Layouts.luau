--!strict
-- The complete layouts (ui-flow, 2026-10-12, the owner: "make a couple
-- different complete layouts but just stop it from being so choppy and
-- disconnected"). One choice for every screen: the car menu, its plates and
-- settings, and the garage are drawn in the same layout, so the words, EXIT,
-- the coins, the column and the action never move between them.
--
--   SHOWCASE  the words down the left on a shade, the items in a graphite
--             column under the coins, the action under it.
--   GLASS     the same, the column see-through.
--   FRAME     the same, the column on a shade, the items in a tray.
--   DOCK      the words as tabs in a dock along the bottom with the action
--             and EXIT, where the thumbs are; the items in a panel above.
--
-- The choice is the LocalPlayer attribute UiLayout (it lasts the session),
-- cycled by the LAYOUT button on any screen or picked in Settings' MENU
-- LAYOUT row. The garage's own GarageLayout went into it.
local Players = game:GetService("Players")

local Types = require(script.Parent:WaitForChild("Types"))
local Showcase = require(script.Parent:WaitForChild("Showcase"))
local Dock = require(script.Parent:WaitForChild("Dock"))

local Layouts = {}

Layouts.ATTRIBUTE = "UiLayout"

local function variant(id: string, name: string, v: Showcase.Variant): Types.Layout
	return {
		id = id,
		name = name,
		build = function(g: ScreenGui, c: Types.Ctx): Types.View
			return Showcase.build(g, c, v)
		end,
	}
end

Layouts.list = {
	variant("showcase", "SHOWCASE", "column"),
	variant("glass", "GLASS", "glass"),
	variant("frame", "FRAME", "frame"),
	{ id = "dock", name = "DOCK", build = Dock.build },
} :: { Types.Layout }

function Layouts.current(): Types.Layout
	local id = Players.LocalPlayer:GetAttribute(Layouts.ATTRIBUTE)
	for _, l in Layouts.list do
		if l.id == id then
			return l
		end
	end
	return Layouts.list[1]
end

function Layouts.set(id: string)
	Players.LocalPlayer:SetAttribute(Layouts.ATTRIBUTE, id)
end

-- The one after the current, chosen.
function Layouts.advance(): Types.Layout
	local cur = Layouts.current()
	local i = table.find(Layouts.list, cur) or 0
	local nxt = Layouts.list[i % #Layouts.list + 1]
	Layouts.set(nxt.id)
	return nxt
end

return Layouts
