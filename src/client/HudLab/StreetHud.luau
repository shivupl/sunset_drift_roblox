--!strict
-- The driving HUD for layout D (hud-variants, 2026-10-08), in STREET's look,
-- in whichever finish is on (Finishes.luau; on 2026-10-10 the owner kept
-- STREET D, had the other styles removed, then asked for finishes of it).
-- From the owner's notes on the STREET trial: the tacho "bottom middle, remove the white and change the
-- opacity... remove the tyre monitor", "remove the 'trip' thing and move the
-- cash to the top right", then on the mockups "make odometer smaller".
--
--   Tacho   small, bottom middle, a smoked see-through face; the gear above
--           the cap, the speed below it in big italic digits.
--   Cash    top right (EXIT / RESET / STYLE are left of it, LayoutD).
--   Board   the drift score, top middle, only while sliding (and a moment
--           after): points, the multiplier, the angle as a bar; on two
--           wheels the roll instead, the bar filling toward the tip and
--           warning as it gets close. Under it the chain's grace drains
--           while the slide is between swings.
--   Shout   a 360, two wheels, a big chain, stamped just left of the car in
--           tafheet's own words, the English under it: تخميسة! (takhmisa,
--           the car spun round), ترفيع! (tarfi', the car up on two tyres),
--           هجولة! (hajwala, drifting itself, at a x3 chain). Researched on
--           2026-10-10 (forum glossaries, news, Saudi videos and games); it
--           was طارت! ("it flew"), which no source used for a 360.
-- The art is Art.luau.
local HudLab = script.Parent
local W = require(HudLab:WaitForChild("Widgets"))
local I = require(HudLab:WaitForChild("Instruments"))
local Motion = require(HudLab:WaitForChild("Motion"))
local LayoutD = require(HudLab:WaitForChild("LayoutD"))
local Art = require(HudLab:WaitForChild("Art"))
local Finishes = require(HudLab:WaitForChild("Finishes"))

local INK = Color3.fromRGB(12, 12, 13)

local NUM_ORDER = "0123456789,.x+-°"
local NUM_CELL = Vector2.new(80, 150)
local FROM, TO, MAX = -135, 135, 9000
local BAR = 18 -- angle bar segments, 5 degrees each
-- The callout: the stamp it always was, a little left of the car rather
-- than on it, tilted, and never quite in the same place twice (the owner,
-- 2026-10-10: "similar to before just off to the side a bit to make it look
-- more scrappy"; it was centred at 0.5, tilted -6). Fractions of the screen.
local SHOUT_X, SHOUT_Y = 0.43, 0.44
local SHOUT_TILT = -8
local SHOUT_JITTER = 0.012
local SHOUT_JITTER_DEG = 3

local SHOUT = W.font("BuilderSans", Enum.FontWeight.Heavy, true)
local LABEL = W.font("BuilderSans", Enum.FontWeight.Bold)

local StreetHud = {}

local function rect(o: GuiObject, x: number, y: number, w: number, h: number)
	o.AnchorPoint = Vector2.new(0, 0)
	o.Position = UDim2.fromScale(x, y)
	o.Size = UDim2.fromScale(w, h)
end

local function nums(parent: Instance, name: string, count: number, align: string?): I.Chars
	local c = I.chars(parent, name, { atlas = Art.num, order = NUM_ORDER, cell = NUM_CELL, cols = 8, count = count, align = align })
	c.root.ZIndex = 3
	return c
end

local function label(parent: Instance, name: string, text: string, color: Color3): TextLabel
	local t = W.text(parent, name, text, LABEL, color)
	t.ZIndex = 3
	return t
end

function StreetHud.build(gui: ScreenGui, touch: boolean, finish: Finishes.Finish): any
	local f = finish
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	local root = W.frame(gui, "StreetHud")
	root.Size = UDim2.fromScale(1, 1)
	-- The edge glow fills the whole screen, notch and all: inside the
	-- safe area it stopped in hard lines short of the sides (the owner,
	-- 2026-10-08: "again with the boundries, whats going on? its cut off").
	local glowGui = Instance.new("ScreenGui")
	glowGui.Name = "HajwalaHudLabGlow"
	glowGui.ResetOnSpawn = false
	glowGui.IgnoreGuiInset = true
	glowGui.ScreenInsets = Enum.ScreenInsets.None
	glowGui.DisplayOrder = gui.DisplayOrder - 1
	glowGui.Parent = gui.Parent
	local glow = W.edgeGlow(glowGui)
	local right = LayoutD.corner(root, "Right", true)
	local er = LayoutD.EDGE_R

	-- The tacho, bottom middle.
	local size = if touch then 0.237 else 0.3
	local tacho = I.dial(root, "Tacho", {
		face = f.art.tachoFace,
		needle = f.art.tachoNeedle,
		glass = Art.tachoGlass,
		fromDeg = FROM,
		toDeg = TO,
		max = MAX,
		jitterAbove = 6650,
	})
	W.square(tacho.root, size)
	tacho.root.AnchorPoint = Vector2.new(0.5, 1)
	tacho.root.Position = UDim2.new(0.5, 0, 1 - LayoutD.EDGE_B, 0)
	local gear = I.chars(tacho.under, "Gear", { atlas = Art.gear, order = "123456RN", cell = Vector2.new(112, 160), cols = 8, count = 1 })
	rect(gear.root, 0.43, 0.2, 0.14, 0.2)
	local speed = nums(tacho.under, "Speed", 3)
	speed.tint(f.print)
	rect(speed.root, 0.29, 0.56, 0.42, 0.24)
	local kmh = label(tacho.under, "Kmh", "km/h", f.label)
	rect(kmh, 0.38, 0.79, 0.24, 0.08)
	local gearScale = Instance.new("UIScale")
	gearScale.Parent = gear.root
	local gearPop = Motion.spring(1, 6, 0.4)
	local lastGear = 0

	-- Cash, top right.
	local pill = W.image(right, "Cash", f.art.pill)
	pill.ScaleType = Enum.ScaleType.Slice
	pill.SliceCenter = Rect.new(40, 30, 260, 82)
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Position = UDim2.fromScale(1 - er, LayoutD.CASH_Y)
	pill.Size = UDim2.fromScale(LayoutD.CASH_W, LayoutD.CASH_H)
	local cashLabel = label(pill, "Label", "CASH", f.label)
	rect(cashLabel, 0.04, 0.3, 0.13, 0.36)
	local cash = nums(pill, "Value", 9, "left")
	cash.tint(f.print)
	rect(cash.root, 0.17, 0.14, 0.52, 0.68)
	local best = label(pill, "Best", "", f.label)
	rect(best, 0.68, 0.32, 0.28, 0.34)
	best.TextXAlignment = Enum.TextXAlignment.Right
	local cashScale = Instance.new("UIScale")
	cashScale.Parent = pill

	-- The drift board, top middle (660x170 art).
	local board = W.image(root, "Board", f.art.board)
	W.box(board, 0.611, 0.157)
	board.AnchorPoint = Vector2.new(0.5, 0)
	board.Position = UDim2.new(0.5, 0, 0.18, 0)
	local points = nums(board, "Points", 7)
	points.tint(f.points)
	rect(points.root, 0.05, 0.08, 0.5, 0.6)
	local mult = nums(board, "Mult", 4)
	mult.tint(f.mult)
	rect(mult.root, 0.62, 0.14, 0.33, 0.46)
	local info = label(board, "Info", "", f.info)
	rect(info, 0.06, 0.66, 0.36, 0.2)
	info.TextXAlignment = Enum.TextXAlignment.Left
	local bar: { Frame } = {}
	for i = 1, BAR do
		local seg = W.frame(board, "Bar" .. i, f.barOff, 0)
		rect(seg, 0.44 + (i - 1) * 0.5 / BAR, 0.68, 0.5 / BAR - 0.006, 0.15)
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

	local shout = W.shout(root, "Shout", {
		font = SHOUT,
		color = f.print,
		stroke = INK,
		strokeThickness = 5,
		subFont = LABEL,
		subColor = f.accent,
		tilt = SHOUT_TILT,
	})
	W.box(shout.root, 0.56, 0.2)
	W.at(shout.root, SHOUT_X, SHOUT_Y)
	-- Each one lands a little differently, slapped on rather than placed.
	local function stamp(word: string, sub: string)
		shout.root.Rotation = SHOUT_TILT + (math.random() - 0.5) * 2 * SHOUT_JITTER_DEG
		shout.root.Position = UDim2.fromScale(SHOUT_X + (math.random() - 0.5) * 2 * SHOUT_JITTER, SHOUT_Y + (math.random() - 0.5) * 2 * SHOUT_JITTER)
		shout.fire(word, sub)
	end

	local roller = Motion.roller()
	local cashRoller = Motion.roller()
	cashRoller.shown = -1
	local cashPop = Motion.spring(1, 5, 0.35)
	local boardPop = Motion.spring(1, 4, 0.45)
	local glowAmt = Motion.spring(0, 2, 1)
	local held, heldUntil = 0, 0
	local message, messageUntil, messageColor = "", 0, f.dropped
	local pointsTint = f.points
	local flash, flashUntil = f.accent, 0
	local clock = 0

	local function update(v: any, dt: number)
		clock += dt
		local now = os.clock()
		tacho.set(v.rpm)
		tacho.update(dt)
		gear.set(if v.gear == -1 then "R" elseif v.gear == 0 then "N" else tostring(v.gear))
		if v.gear ~= lastGear then
			lastGear = v.gear
			Motion.kick(gearPop, 7)
		end
		gearScale.Scale = Motion.step(gearPop, 1, dt)
		speed.set(tostring(math.clamp(math.floor(v.speed + 0.5), 0, 999)))

		pill.SliceScale = math.max(pill.AbsoluteSize.Y, 1) / 120
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
			mult.set(if live and v.mult > 1 then (if v.mult % 1 == 0 then string.format("x%d", v.mult) else string.format("x%.1f", v.mult)) else "")
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

		local heat = math.clamp((v.mult - 1) / math.max(v.multMax - 1, 1), 0, 1)
		local want = if live then 0.05 + 0.18 * heat else 0
		local g = Motion.step(glowAmt, want, dt)
		glow.set(if now < flashUntil then flash else f.accent, if now < flashUntil then 0.3 else g)
		shout.update(dt)
	end

	local function event(kind: string, a: number, b: number)
		local now = os.clock()
		if kind == "mult" then
			Motion.kick(boardPop, 3)
		elseif kind == "spin" then
			stamp("تخميسة!", `{if b > 1 then b * 360 else 360}  +{Motion.comma(a)}`)
			Motion.kick(boardPop, 5)
		elseif kind == "natl" then
			stamp("ترفيع!", string.format("%.1fs", a))
		elseif kind == "chain" then
			stamp("هجولة!", (if a % 1 == 0 then string.format("x%d", a) else string.format("x%.1f", a)) .. " CHAIN")
		elseif kind == "banked" then
			held, heldUntil = a, now + 1.6
			pointsTint = f.banked
			message, messageUntil, messageColor = `BANKED +{Motion.comma(b)}`, now + 1.6, f.banked
			flash, flashUntil = f.banked, now + 0.3
			Motion.kick(boardPop, 5)
			if b > 0 then
				Motion.kick(cashPop, 8)
			end
		elseif kind == "dropped" then
			held, heldUntil = 0, 0
			message, messageUntil, messageColor = "DROPPED", now + 1.2, f.dropped
			flash, flashUntil = f.dropped, now + 0.4
		end
	end

	return {
		update = update,
		event = event,
		destroy = function()
			root:Destroy()
			glowGui:Destroy()
		end,
	}
end

return StreetHud
