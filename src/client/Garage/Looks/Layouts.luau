--!strict
-- The complete layouts (ui-flow, 2026-10-12, the owner: "make a couple
-- different complete layouts but just stop it from being so choppy and
-- disconnected"). One choice for every screen: the car menu, its plates and
-- settings, and the garage are drawn in the same layout, so the words, EXIT,
-- the coins, the column and the action never move between them.
--
--   SHOWCASE  the words down the left on a shade, the items in a graphite
--             column under the coins, the action under it.
--   GLASS     the same, the column see-through. A phone's only layout
--             (2026-10-12), in three versions of its up/down control.
--   FRAME     the same, the column on a shade, the items in a tray.
--   DOCK      the words as tabs in a dock along the bottom with the action
--             and EXIT, where the thumbs are; the items in a panel above.
--
-- The choice is the LocalPlayer attribute UiLayout (it lasts the session),
-- cycled by the LAYOUT button on any screen or picked in Settings' MENU
-- LAYOUT row. The garage's own GarageLayout went into it.
local Players = game:GetService("Players")

local Kit = require(script.Parent.Parent.Parent:WaitForChild("CarPicker"):WaitForChild("Kit"))
local Types = require(script.Parent:WaitForChild("Types"))
local Showcase = require(script.Parent:WaitForChild("Showcase"))
local Dock = require(script.Parent:WaitForChild("Dock"))

local Layouts = {}

Layouts.ATTRIBUTE = "UiLayout"

local function variant(id: string, name: string, v: Showcase.Variant, opts: Showcase.Options?): Types.Layout
	return {
		id = id,
		name = name,
		build = function(g: ScreenGui, c: Types.Ctx): Types.View
			return Showcase.build(g, c, v, opts)
		end,
	}
end

-- A phone has GLASS (the owner, 2026-10-12: "lets go with 'glass' for
-- Mobile view garage"), its column a little past the coins and its fades
-- gone, in three versions of the up/down control to choose between
-- ("add an obvious scroll/updown for the options (make a couple
-- versions)"). SHOWCASE, FRAME and DOCK stay on a PC.
local REACH = 24
Layouts.phone = {
	variant("glass", "GLASS ARROWS", "glass", { reach = REACH, scroller = "arrows" }),
	variant("glassrail", "GLASS RAIL", "glass", { reach = REACH, scroller = "rail" }),
	variant("glassmore", "GLASS MORE", "glass", { reach = REACH, scroller = "more" }),
} :: { Types.Layout }

Layouts.pc = {
	variant("showcase", "SHOWCASE", "column"),
	variant("glass", "GLASS", "glass"),
	variant("frame", "FRAME", "frame"),
	{ id = "dock", name = "DOCK", build = Dock.build },
} :: { Types.Layout }

-- The layouts this screen cycles: a phone's or a PC's.
function Layouts.all(): { Types.Layout }
	return if Kit.isTouch() then Layouts.phone else Layouts.pc
end

function Layouts.current(): Types.Layout
	local id = Players.LocalPlayer:GetAttribute(Layouts.ATTRIBUTE)
	local list = Layouts.all()
	for _, l in list do
		if l.id == id then
			return l
		end
	end
	return list[1]
end

function Layouts.set(id: string)
	Players.LocalPlayer:SetAttribute(Layouts.ATTRIBUTE, id)
end

-- The one after the current.
function Layouts.after(): Types.Layout
	local list = Layouts.all()
	return list[(table.find(list, Layouts.current()) or 0) % #list + 1]
end

-- The one after the current, chosen.
function Layouts.advance(): Types.Layout
	local nxt = Layouts.after()
	Layouts.set(nxt.id)
	return nxt
end

return Layouts
