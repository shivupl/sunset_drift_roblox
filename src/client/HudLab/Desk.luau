--!strict
-- The desktop HUD's layouts (desktop-ui, 2026-10-14; the owner, of the PC
-- screen: "the odometer and stuff should go on the right", "put a small
-- guide on which keys are for what", "the buttons and everything needs to
-- be redone and spaced for pc", "make a couple different full UI options
-- ... implement them in game for me to switch between"). A layout says
-- where the readouts go and what shape they take (StreetHud), the key
-- guide's form (KeyGuide) and the top row's tabs (TopBar). The phone has
-- none of this: its controls are layout D, its readouts the dial in the
-- bottom middle.
--
-- Cycled with K, picked in Settings' PC LAYOUT row, or set as the
-- LocalPlayer attribute HudDesk (a layout's id). The canvas "Hajwala
-- desktop HUD" has the three drawn.
--
--   DASH     the dial as it was, moved from the bottom middle to the
--            bottom right corner; the keys in one line on a soft blot,
--            bottom left; the tabs 44 tall, each with its word and key.
--   STRIP    no dial: the gear in a box, the speed big, the revs as a bar
--            with a red end, bottom right; the keys in two columns; the
--            tabs 36 tall, an icon and a key each, GARAGE's word alone.
--   CLUSTER  a glass tray in the tabs' slant, bottom right: the speed and
--            the gear on its left, a smaller dial on its right; the keys
--            on a glass strip of the same slant; the tabs 48 tall.
local Players = game:GetService("Players")

export type Desk = {
	id: string,
	name: string,
	blurb: string, -- the word beside its name in Settings' PC LAYOUT row
	readouts: string, -- "dial", "strip" or "cluster": the speed, gear and revs
	guide: string, -- "line", "stack" or "glass": the key guide's form
	tabH: number, -- the top row's tabs, px
	words: boolean, -- every tab but SETTINGS carries its word; false: GARAGE's alone, the rest their icons and keys
}

local Desk = {}

Desk.ATTRIBUTE = "HudDesk"

local list: { Desk } = {
	{ id = "dash", name = "DASH", blurb = "The dial in the corner", readouts = "dial", guide = "line", tabH = 44, words = true },
	{ id = "strip", name = "STRIP", blurb = "No dial, a strip", readouts = "strip", guide = "stack", tabH = 36, words = false },
	{ id = "cluster", name = "CLUSTER", blurb = "A cluster on a tray", readouts = "cluster", guide = "glass", tabH = 48, words = true },
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
