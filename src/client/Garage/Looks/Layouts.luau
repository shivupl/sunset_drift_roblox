--!strict
-- The complete layouts (ui-flow, 2026-10-12, the owner: "make a couple
-- different complete layouts but just stop it from being so choppy and
-- disconnected"). One choice for every screen: the car menu, its plates and
-- settings, and the garage are drawn in the same layout, so the words, EXIT,
-- the coins, the column and the action never move between them.
--
--   SHOWCASE  the words down the left on a shade, the items in a graphite
--             column under the coins, the action under it. On a PC in
--             three sizes: SHOWCASE, BIGGER, WIDE (Showcase.Sizing).
--   GLASS     the same, the column see-through. A phone's only layout
--             (2026-10-12), in three versions of its up/down control.
--   FRAME     the same, the column on a shade, the items in a tray.
--   DOCK      the words as tabs in a dock along the bottom with the action
--             and EXIT, where the thumbs are; the items in a panel above.
--
-- The choice is the LocalPlayer attribute UiLayout (it lasts the session),
-- picked in Settings' SCREEN LAYOUT row (DOCK's LAYOUT button cycles it on
-- a PC; the one beside EXIT went, the owner's phone, 2026-10-12). The
-- garage's own GarageLayout went into it.
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
-- Mobile view garage"), its column a little past the coins, its fades
-- gone and a rail down the list's right edge in their place: of the three
-- up/down controls tried (ARROWS, RAIL, MORE) they picked RAIL from their
-- phone. SHOWCASE, FRAME and DOCK stay on a PC.
local REACH = 24
Layouts.phone = {
	variant("glass", "GLASS", "glass", { reach = REACH, scroller = "rail" }),
} :: { Types.Layout }

-- A PC has SHOWCASE in three sizes (the owner, 2026-10-14: "make a couple
-- variants of the customization UI, i feel like the text buttons on the
-- left side need to be a bit bigger and also the boxes in the right side
-- menu also could be bigger"; Showcase.Sizing) and DOCK. GLASS and FRAME
-- are off a PC's list (Showcase still draws them; GLASS is the phone's).
Layouts.pc = {
	variant("showcase", "SHOWCASE", "column"),
	variant("bigger", "BIGGER", "column", { pc = Showcase.BIGGER }),
	variant("wide", "WIDE", "column", { pc = Showcase.WIDE }),
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
