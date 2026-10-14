--!strict
-- BOARD's score and cash (Versions.luau): layout D's drift board and cash
-- plate as they were (StreetHud until 2026-10-10).
--
--   Cash    top right on a long plate (EXIT / RESET / STYLE / UI are left
--           of it, LayoutD), the best or the server best beside it.
--   Board   the drift score, top middle, only while sliding (and a moment
--           after): points, the multiplier, the angle as a bar; on two
--           wheels the roll instead, the bar filling toward the tip and
--           warning as it gets close. Under it the chain's grace drains
--           while the slide is between swings.
local HudLab = script.Parent
local W = require(HudLab:WaitForChild("Widgets"))
local Motion = require(HudLab:WaitForChild("Motion"))
local LayoutD = require(HudLab:WaitForChild("LayoutD"))
local Finishes = require(HudLab:WaitForChild("Finishes"))
local R = require(HudLab:WaitForChild("Readouts"))
local CashTag = require(HudLab:WaitForChild("CashTag"))

local BAR = 18 -- angle bar segments, 5 degrees each

export type Score = {
	update: (v: any, dt: number) -> (),
	event: (kind: string, a: number, b: number) -> (),
	destroy: () -> (),
}

local ScoreBoard = {}

function ScoreBoard.build(root: Frame, right: Frame, f: Finishes.Finish): Score
	local er = LayoutD.EDGE_R

	-- Cash, top right: the price tag every screen shows (CashTag), BEST
	-- under it as FLOW has it (the long plate with CASH, the amount and
	-- BEST went with it).
	local cash = CashTag.build(right)
	local best = R.label(right, "Best", "", f.label)
	best.AnchorPoint = Vector2.new(1, 0)
	best.Position = UDim2.fromScale(1 - er - 0.012, LayoutD.CASH_Y + LayoutD.CASH_H + 0.004)
	best.Size = UDim2.fromScale(0.32, 0.03)
	best.TextXAlignment = Enum.TextXAlignment.Right
	W.stroke(best, R.INK, 1, 0.45)
	local cashScale = Instance.new("UIScale")
	cashScale.Parent = cash.root

	-- The drift board, top middle (660x170 art).
	local board = W.image(root, "Board", f.art.board)
	W.box(board, 0.611, 0.157)
	board.AnchorPoint = Vector2.new(0.5, 0)
	board.Position = UDim2.new(0.5, 0, 0.18, 0)
	local points = R.nums(board, "Points", 7)
	points.tint(f.points)
	R.rect(points.root, 0.05, 0.08, 0.5, 0.6)
	local mult = R.nums(board, "Mult", 4)
	mult.tint(f.mult)
	R.rect(mult.root, 0.62, 0.14, 0.33, 0.46)
	local info = R.label(board, "Info", "", f.info)
	R.rect(info, 0.06, 0.66, 0.36, 0.2)
	info.TextXAlignment = Enum.TextXAlignment.Left
	local bar: { Frame } = {}
	for i = 1, BAR do
		local seg = W.frame(board, "Bar" .. i, f.barOff, 0)
		R.rect(seg, 0.44 + (i - 1) * 0.5 / BAR, 0.68, 0.5 / BAR - 0.006, 0.15)
		seg.ZIndex = 3
		W.corner(seg, UDim.new(0.25, 0))
		table.insert(bar, seg)
	end
	local boardScale = Instance.new("UIScale")
	boardScale.Parent = board
	-- Under the board, the chain's grace: full while sliding, draining to
	-- the middle once the slide lets go; link the next one before it is gone
	-- or the slide banks.
	local graceBar = W.frame(root, "Grace", f.mult, 0.15)
	graceBar.AnchorPoint = Vector2.new(0.5, 0)
	graceBar.SizeConstraint = Enum.SizeConstraint.RelativeYY
	graceBar.Position = UDim2.new(0.5, 0, 0.18 + 0.157 + 0.006, 0)
	W.corner(graceBar)
	local graceShown = Motion.spring(0, 6, 1)

	local roller = Motion.roller()
	local cashRoller = Motion.roller()
	cashRoller.shown = -1
	local cashPop = Motion.spring(1, 5, 0.35)
	local boardPop = Motion.spring(1, 4, 0.45)
	local held, heldUntil = 0, 0
	local message, messageUntil, messageColor = "", 0, f.dropped
	local pointsTint = f.points
	local clock = 0

	local function update(v: any, dt: number)
		clock += dt
		local now = os.clock()
		if cashRoller.shown < 0 then
			cashRoller.shown = v.cash
		end
		cash.set(Motion.comma(Motion.roll(cashRoller, v.cash, dt, 4)))
		cashScale.Scale = Motion.step(cashPop, 1, dt)
		best.Text = if v.serverBest > 0 and (clock % 6) > 3 then `SERVER {Motion.comma(v.serverBest)}` else `BEST {Motion.comma(v.best)}`

		local live = v.sliding
		if live then
			held, heldUntil = v.points, now + 1.4
			pointsTint = f.points
		end
		local showing = live or now < heldUntil or now < messageUntil
		board.Visible = showing
		if showing then
			local p = Motion.roll(roller, if live then v.points else held, dt, 9)
			points.set(if p > 0 then Motion.comma(p) else "0")
			points.tint(pointsTint)
			mult.set(if live and v.mult > 1 then R.mult(v.mult) else "")
			local deg = math.floor(math.abs(v.angle) + 0.5)
			-- On two wheels: how far over, and how close to the tip (the
			-- warning steps are the old HUD's: under 16 degrees left, under 8).
			local roll = math.floor(math.abs(v.roll) + 0.5)
			local tip = if v.margin < 8 then f.dropped elseif v.margin < 16 then f.mult else f.info
			if now < messageUntil then
				info.Text = message
				info.TextColor3 = messageColor
			elseif live and v.natl then
				info.Text = `ترفيع {roll}°`
				info.TextColor3 = tip
			else
				info.Text = `ANGLE {math.min(deg, 999)}°`
				info.TextColor3 = f.info
			end
			local heat = math.clamp((v.mult - 1) / math.max(v.multMax - 1, 1), 0, 1)
			local on = f.points:Lerp(f.mult, heat)
			local lit = if v.natl then math.floor(BAR * math.abs(v.roll) / math.max(math.abs(v.roll) + v.margin, 1) + 0.5) else 0
			for i, seg in bar do
				if live and v.natl then
					seg.BackgroundColor3 = if i <= lit then tip else f.barOff
				else
					seg.BackgroundColor3 = if live and deg >= i * 5 - 2.5 then on else f.barOff
				end
			end
		end
		boardScale.Scale = Motion.step(boardPop, 1, dt)
		local gs = Motion.step(graceShown, if live then 1 else 0, dt)
		graceBar.Visible = showing and gs > 0.02
		graceBar.Size = UDim2.fromScale(0.5 * v.chain, 0.007)
		graceBar.BackgroundTransparency = 1 - 0.85 * gs
	end

	local function event(kind: string, a: number, b: number)
		local now = os.clock()
		if kind == "mult" then
			Motion.kick(boardPop, 3)
		elseif kind == "spin" then
			Motion.kick(boardPop, 5)
		elseif kind == "banked" then
			held, heldUntil = a, now + 1.6
			pointsTint = f.banked
			message, messageUntil, messageColor = `BANKED +{Motion.comma(b)}`, now + 1.6, f.banked
			Motion.kick(boardPop, 5)
			if b > 0 then
				Motion.kick(cashPop, 8)
			end
		elseif kind == "dropped" then
			held, heldUntil = 0, 0
			message, messageUntil, messageColor = "DROPPED", now + 1.2, f.dropped
		end
	end

	return {
		update = update,
		event = event,
		destroy = function()
			cash.root:Destroy()
			best:Destroy()
			board:Destroy()
			graceBar:Destroy()
		end,
	}
end

return ScoreBoard
