--!strict
-- Versions of the whole HUD, cycled with the UI button (Y on a keyboard),
-- apart from the finish STYLE cycles (the owner, 2026-10-10: "make a couple
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
--          Live controls.
--   SIDE   the score off the middle altogether: a combo meter down the
--          right under the cash (badge, points, angle line), the middle
--          left to the car and the road; the cash a coin with no plate.
--          Live controls.
--
-- Live controls (LayoutD): a ripple on every press, a glint across a button
-- now and then, the steer buttons glowing with the steer they are giving,
-- NATL popping in and breathing while it can lift, a light strip on each
-- pedal filling with how hard it is pressed (the gas's blinking near the
-- redline).
export type Version = {
	id: string,
	name: string,
	live: boolean, -- the live controls
	cashW: number, -- how wide the cash is, fractions of the screen's height (the menu buttons sit left of it)
}

local list: { Version } = {
	-- The trial opens on the newest, so the owner sees it at once.
	{ id = "flow", name = "FLOW", live = true, cashW = 0.37 },
	{ id = "side", name = "SIDE", live = true, cashW = 0.37 },
	{ id = "board", name = "BOARD", live = false, cashW = 0.463 },
}

local byId: { [string]: Version } = {}
for _, v in list do
	byId[v.id] = v
end

return {
	list = list,
	byId = byId,
}
