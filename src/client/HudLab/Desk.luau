--!strict
-- The desktop HUD's layouts (desktop-ui, 2026-10-14; the owner, of the PC
-- screen: "the odometer and stuff should go on the right", "put a small
-- guide on which keys are for what", "the buttons and everything needs to
-- be redone and spaced for pc", "make a couple different full UI options
-- ... implement them in game for me to switch between"). Of the three
-- drawn (DASH, STRIP, CLUSTER: the canvas "Hajwala desktop HUD", boards
-- A–C; the code at a669f1a) the owner picked DASH, "but still needs some
-- polishing and work, make a couple variants". So every layout is DASH:
-- the dial in the bottom right corner (StreetHud), the top row's tabs 44
-- tall with their keys (TopBar); they differ in the key guide's form
-- (KeyGuide, the canvas's A1–A3 boards). The phone has none of this: its
-- controls are layout D, its readouts the dial in the bottom middle.
--
-- Cycled with K, picked in Settings' PC LAYOUT row, or set as the
-- LocalPlayer attribute HudDesk (a layout's id).
--
--   DASH       outlined keys, nothing behind them
--   DASH THIN  the letters alone, no keycaps
--   DASH FADE  the outlined keys on a fade along the screen's bottom edge
local Players = game:GetService("Players")

export type Desk = {
	id: string,
	name: string,
	blurb: string, -- the words beside its name in Settings' PC LAYOUT row
	guide: string, -- "ghost", "thin" or "fade": the key guide's form
}

local Desk = {}

Desk.ATTRIBUTE = "HudDesk"

local list: { Desk } = {
	{ id = "dash", name = "DASH", blurb = "Outlined keys, nothing behind", guide = "ghost" },
	{ id = "thin", name = "DASH THIN", blurb = "The letters alone", guide = "thin" },
	{ id = "fade", name = "DASH FADE", blurb = "Keys on a fade along the bottom", guide = "fade" },
}

local byId: { [string]: Desk } = {}
for _, d in list do
	byId[d.id] = d
end

Desk.list = list
Desk.byId = byId

function Desk.current(): Desk
	local id = Players.LocalPlayer:GetAttribute(Desk.ATTRIBUTE)
	return (if type(id) == "string" then byId[id] else nil) or list[1]
end

function Desk.set(id: string)
	Players.LocalPlayer:SetAttribute(Desk.ATTRIBUTE, id)
end

-- The next layout round, from K.
function Desk.cycle()
	local i = table.find(list, Desk.current()) or 0
	Desk.set(list[i % #list + 1].id)
end

return Desk
