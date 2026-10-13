--!strict
-- Versions of the whole HUD, picked in Settings' HUD LAYOUT row (Y on a
-- keyboard; the UI button went with the phone top bar, 2026-10-11), apart
-- from the finish STYLE cycles (the owner, 2026-10-10: "make a couple
-- versions of the whole UI that are improvements and let me chose... make a
-- seppearate hud style button"). What was wrong with BOARD, in the owner's
-- words: "the middle score-counting part is too big for no raeson", "the
-- buttons - dead and lfieless", "coins/cash - same issue", "blocky".
--
--   BOARD  layout D as it was: the drift score on a plate across the top
--          middle, the cash on a long plate, buttons that only answer a
--          press.
--   FLOW   no plates: the score floats small at the top middle over a soft
--          shadow, the multiplier in a round badge whose ring is the
--          chain's grace running out, a thin angle line under it; the cash
--          a coin on a short chip, a banked slide's cash flying into it.
--          The owner, 2026-10-10: "flow looks good".
--   SIDE   the score off the middle altogether: a combo meter down the
--          right under the cash (badge, points, angle line), the middle
--          left to the car and the road; the cash a coin with no plate.
--
-- FLOW and SIDE had live controls too (ripples, glints, a steer glow, NATL
-- breathing, pedal light strips); they went the same day ("remove all the
-- wierd effects from all the buttons").
export type Version = {
	id: string,
	name: string,
	blurb: string, -- the word beside its name in Settings' HUD LAYOUT row
}

local list: { Version } = {
	-- The trial opens on the newest, so the owner sees it at once.
	{ id = "flow", name = "FLOW", blurb = "Score floats at the top" },
	{ id = "side", name = "SIDE", blurb = "Meter down the right" },
	{ id = "board", name = "BOARD", blurb = "Score on a plate" },
}

local byId: { [string]: Version } = {}
for _, v in list do
	byId[v.id] = v
end

return {
	list = list,
	byId = byId,
}
