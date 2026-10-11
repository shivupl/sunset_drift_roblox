--!strict
-- FLOW's and SIDE's score and cash (Versions.luau), the owner's notes on
-- BOARD (2026-10-10): "the middle score-counting part is too big for no
-- raeson, why does it have to be there taking up so much space", "coins/
-- cash - same issue", "very plain and boring right now and blocky".
--
-- No plates. The score is the points in the italic digits, a round badge
-- with the multiplier, and the chain's grace as the badge's ring running
-- down (full while sliding, draining once the slide lets go); under them a
-- thin line for the angle (on two wheels: how close to the tip, warning as
-- it closes) and a line of text. A soft shadow keeps it readable over a
-- bright sky. It pops in when a slide starts and goes a moment after.
--
--   FLOW   the score small and centred at the top
--   SIDE   the score down the right under the cash, right-aligned
--
-- The cash is a coin and the amount: FLOW on a short chip with the coin
-- over its end, SIDE on nothing. A banked slide's cash flies from the score
-- into the coin and the amount counts up. (The coin spun and the cash
-- popped as it landed; the owner, 2026-10-10: "it makes a strange animation
-- on the top right like popping in and out that i dont like".)
local HudLab = script.Parent
local W = require(HudLab:WaitForChild("Widgets"))
local Motion = require(HudLab:WaitForChild("Motion"))
local LayoutD = require(HudLab:WaitForChild("LayoutD"))
local Art = require(HudLab:WaitForChild("Art"))
local Finishes = require(HudLab:WaitForChild("Finishes"))
local R = require(HudLab:WaitForChild("Readouts"))

-- The cash's box, fractions of the screen's height (Versions.cashW leaves
-- room left of it for the coin's overhang).
local CASH_W = 0.32
-- How long a banked slide's cash takes to fly into the coin.
local FLY_SECONDS = 0.6

export type Score = {
	update: (v: any, dt: number) -> (),
	event: (kind: string, a: number, b: number) -> (),
	destroy: () -> (),
}

type Flyer = { frame: Frame, scale: UIScale, from: Vector2, to: Vector2, lift: number, t: number }

local ScoreLive = {}

function ScoreLive.build(root: Frame, right: Frame, f: Finishes.Finish, side: boolean): Score
	local er = LayoutD.EDGE_R
	local made: { Instance } = {}
	local function keep<T>(o: T): T
		table.insert(made, o :: any)
		return o
	end

	------------------------------------------------------------------
	-- Cash: a coin and the amount.
	------------------------------------------------------------------
	local cashBox = keep(W.frame(right, "Cash"))
	cashBox.AnchorPoint = Vector2.new(1, 0)
	cashBox.Position = UDim2.fromScale(1 - er, LayoutD.CASH_Y)
	cashBox.Size = UDim2.fromScale(CASH_W, LayoutD.CASH_H)
	local chip: ImageLabel? = nil
	if side then
		local shade = W.image(cashBox, "Shade", Art.soft)
		shade.ImageTransparency = 0.4
		shade.Size = UDim2.fromScale(1.3, 2)
		W.at(shade, 0.55, 0.5)
		shade.ZIndex = 0
	else
		local c = W.image(cashBox, "Chip", f.art.pill)
		c.ScaleType = Enum.ScaleType.Slice
		c.SliceCenter = Rect.new(40, 30, 260, 82)
		chip = c
	end
	local coinHolder = W.frame(cashBox, "Coin")
	coinHolder.SizeConstraint = Enum.SizeConstraint.RelativeYY
	coinHolder.Size = UDim2.fromScale(1.25, 1.25)
	coinHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	coinHolder.Position = UDim2.fromScale(if side then 0.1 else 0.05, 0.5)
	coinHolder.ZIndex = 4
	local coin = W.image(coinHolder, "Face", Art.coin)
	coin.ZIndex = 4
	local cash = R.nums(cashBox, "Value", 9, "left")
	cash.tint(f.print)
	R.rect(cash.root, if side then 0.3 else 0.26, 0.255, 0.7, 0.49)
	local best = keep(R.label(right, "Best", "", f.label))
	best.AnchorPoint = Vector2.new(1, 0)
	best.Position = UDim2.fromScale(1 - er - 0.012, LayoutD.CASH_Y + LayoutD.CASH_H + 0.004)
	best.Size = UDim2.fromScale(CASH_W, 0.03)
	best.TextXAlignment = Enum.TextXAlignment.Right
	W.stroke(best, R.INK, 1, 0.45)

	------------------------------------------------------------------
	-- The score.
	------------------------------------------------------------------
	local cl = keep(W.frame(if side then right else root, "Score"))
	if side then
		cl.AnchorPoint = Vector2.new(1, 0)
		cl.Position = UDim2.fromScale(1 - er, 0.17)
		cl.Size = UDim2.fromScale(0.42, 0.24)
	else
		W.box(cl, 0.6, 0.16)
		cl.AnchorPoint = Vector2.new(0.5, 0)
		cl.Position = UDim2.new(0.5, 0, 0.15, 0) -- clear of the menu row (to 0.13) on a wide phone
	end
	cl.Visible = false
	local clScale = Instance.new("UIScale")
	clScale.Parent = cl
	local shade = W.image(cl, "Shade", Art.soft)
	shade.ImageTransparency = 0.3
	shade.Size = UDim2.fromScale(1.3, 1.6)
	W.at(shade, 0.5, 0.45)
	shade.ZIndex = 0

	-- Points: 7 digits at their own shape (80x150 cells).
	local points = R.nums(cl, "Points", 7)
	if side then
		R.rect(points.root, 0.036, 0.08, 0.62, 0.29)
	else
		R.rect(points.root, 0.083, 0, 0.557, 0.56)
	end

	-- The badge: the multiplier, its ring the chain's grace.
	local badge = W.frame(cl, "Badge")
	badge.SizeConstraint = Enum.SizeConstraint.RelativeYY
	if side then
		badge.Size = UDim2.fromScale(0.56, 0.56)
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.fromScale(1, 0)
	else
		badge.Size = UDim2.fromScale(0.66, 0.66)
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.fromScale(0.81, 0.3)
	end
	local badgeScale = Instance.new("UIScale")
	badgeScale.Parent = badge
	local disc = W.image(badge, "Disc", Art.disc)
	disc.ImageColor3 = R.INK
	disc.ImageTransparency = 0.3
	disc.Size = UDim2.fromScale(0.86, 0.86)
	W.at(disc, 0.5, 0.5)
	local track = W.image(badge, "Track", Art.ring)
	track.ImageColor3 = f.barOff
	track.ImageTransparency = 0.1
	track.ZIndex = 2
	local arc = W.arc(badge, "Grace", Art.ring)
	arc.root.Size = UDim2.fromScale(1, 1)
	arc.paint(f.mult, 0)
	for _, d in arc.root:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 3
		end
	end
	local mult = R.nums(badge, "Mult", 4, "center")
	mult.tint(f.mult)
	R.rect(mult.root, 0.16, 0.335, 0.68, 0.33)

	-- The angle line (on two wheels, the tip line) and the text under it.
	local meter = W.frame(cl, "Meter", f.barOff, 0.25)
	W.corner(meter)
	local fill = W.frame(meter, "Fill", f.points, 0)
	W.corner(fill)
	if side then
		meter.AnchorPoint = Vector2.new(1, 0.5)
		meter.Position = UDim2.fromScale(1, 0.66)
		meter.Size = UDim2.fromScale(0.95, 0.03)
		fill.AnchorPoint = Vector2.new(1, 0.5)
		fill.Position = UDim2.fromScale(1, 0.5)
	else
		meter.AnchorPoint = Vector2.new(0.5, 0.5)
		meter.Position = UDim2.fromScale(0.5, 0.68)
		meter.Size = UDim2.fromScale(0.8, 0.035)
		fill.AnchorPoint = Vector2.new(0.5, 0.5)
		fill.Position = UDim2.fromScale(0.5, 0.5)
	end
	local info = R.label(cl, "Info", "", f.info)
	if side then
		R.rect(info, 0, 0.72, 1, 0.17)
		info.TextXAlignment = Enum.TextXAlignment.Right
	else
		R.rect(info, 0.1, 0.75, 0.8, 0.2)
	end
	W.stroke(info, R.INK, 1, 0.45)

	------------------------------------------------------------------

	local roller = Motion.roller()
	local cashRoller = Motion.roller()
	cashRoller.shown = -1
	local clPop = Motion.spring(1, 6, 0.5)
	local badgePop = Motion.spring(1, 5, 0.4)
	local meterAmt = Motion.spring(0, 8, 1)
	local held, heldUntil = 0, 0
	local message, messageUntil, messageColor = "", 0, f.dropped
	local pointsTint = f.points
	local wasShowing = false
	local clock = 0
	local flyers: { Flyer } = {}

	-- A banked slide's cash, from the score into the coin.
	local function fly(amount: number)
		local from = points.root.AbsolutePosition + points.root.AbsoluteSize / 2
		local to = coin.AbsolutePosition + coin.AbsoluteSize / 2
		local h = math.max(points.root.AbsoluteSize.Y * 0.7, 8)
		local fr = keep(W.frame(root, "Fly"))
		fr.AnchorPoint = Vector2.new(0.5, 0.5)
		fr.Size = UDim2.fromOffset(h * 0.533 * 6, h)
		fr.ZIndex = 6
		local digits = R.nums(fr, "Digits", 6, "center")
		digits.root.Size = UDim2.fromScale(1, 1)
		digits.tint(f.banked)
		digits.set("+" .. Motion.comma(amount))
		for _, d in digits.root:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex = 6
			end
		end
		local sc = Instance.new("UIScale")
		sc.Parent = fr
		table.insert(flyers, {
			frame = fr,
			scale = sc,
			from = from - root.AbsolutePosition,
			to = to - root.AbsolutePosition,
			lift = root.AbsoluteSize.Y * 0.06,
			t = 0,
		})
	end

	local function update(v: any, dt: number)
		clock += dt
		local now = os.clock()

		-- Cash.
		local c = chip
		if c then
			c.SliceScale = math.max(c.AbsoluteSize.Y, 1) / 120
		end
		if cashRoller.shown < 0 then
			cashRoller.shown = v.cash
		end
		cash.set(Motion.comma(Motion.roll(cashRoller, v.cash, dt, 4)))
		best.Text = if v.serverBest > 0 and (clock % 6) > 3 then `SERVER {Motion.comma(v.serverBest)}` else `BEST {Motion.comma(v.best)}`

		-- Score.
		local live = v.sliding
		if live then
			held, heldUntil = v.points, now + 1.4
			pointsTint = f.points
		end
		local showing = live or now < heldUntil or now < messageUntil
		if showing and not wasShowing then
			clPop.x, clPop.v = 0.8, 0
		end
		wasShowing = showing
		cl.Visible = showing
		if showing then
			local p = Motion.roll(roller, if live then v.points else held, dt, 9)
			points.set(if p > 0 then Motion.comma(p) else "0")
			points.tint(pointsTint)
			mult.set(R.mult(math.max(v.mult, 1)))
			arc.set(if live then v.chain else 0)
			local deg = math.abs(v.angle)
			local roll = math.abs(v.roll)
			local tip = if v.margin < 8 then f.dropped elseif v.margin < 16 then f.mult else f.info
			local heat = math.clamp((v.mult - 1) / math.max(v.multMax - 1, 1), 0, 1)
			local amount, colour
			if live and v.natl then
				amount, colour = roll / math.max(roll + v.margin, 1), tip
			else
				amount, colour = if live then math.clamp(deg / 90, 0, 1) else 0, f.points:Lerp(f.mult, heat)
			end
			fill.Size = UDim2.fromScale(Motion.step(meterAmt, amount, dt), 1)
			fill.BackgroundColor3 = colour
			if now < messageUntil then
				info.Text = message
				info.TextColor3 = messageColor
			elseif live and v.natl then
				info.Text = `ترفيع {math.floor(roll + 0.5)}°`
				info.TextColor3 = tip
			else
				info.Text = `ANGLE {math.min(math.floor(deg + 0.5), 999)}°`
				info.TextColor3 = f.info
			end
		end
		clScale.Scale = Motion.step(clPop, 1, dt)
		badgeScale.Scale = Motion.step(badgePop, 1, dt)

		-- Cash on its way to the coin: an arc up and over, shrinking.
		for i = #flyers, 1, -1 do
			local fl = flyers[i]
			fl.t += dt
			local k = math.clamp(fl.t / FLY_SECONDS, 0, 1)
			local e = k * k * (3 - 2 * k)
			local pos = fl.from:Lerp(fl.to, e) - Vector2.new(0, math.sin(math.pi * k) * fl.lift)
			fl.frame.Position = UDim2.fromOffset(pos.X, pos.Y)
			fl.scale.Scale = 1 - 0.5 * e
			if k >= 1 then
				fl.frame:Destroy()
				table.remove(flyers, i)
			end
		end
	end

	local function event(kind: string, a: number, b: number)
		local now = os.clock()
		if kind == "mult" then
			Motion.kick(badgePop, 6)
		elseif kind == "spin" then
			Motion.kick(clPop, 4)
		elseif kind == "banked" then
			held, heldUntil = a, now + 1.6
			pointsTint = f.banked
			message, messageUntil, messageColor = `BANKED +{Motion.comma(b)}`, now + 1.6, f.banked
			Motion.kick(clPop, 4)
			if b > 0 then
				fly(b)
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
			for _, o in made do
				o:Destroy()
			end
		end,
	}
end

return ScoreLive
