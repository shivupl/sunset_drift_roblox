--!strict
-- The dot-matrix displays the cluster variants share (hud-variants,
-- 2026-10-07): the drift display (the slide's points, the multiplier, a line
-- of what is happening or the drift angle as a bar, the chain as a row of
-- LEDs) and the cash display (cash and your best), each a rendered panel
-- with characters cut from an atlas in parts.DOT_ORDER, cells of 96x128:
-- dot-matrix (parts.dot_atlas) for KRUZER (amber) and STREET (red LEDs),
-- 14-segment (parts.seg_atlas, DSEG14) for KABRIS's vacuum-fluorescent
-- display, which also lays its grid mesh and glass over the characters.
--
-- On a phone they line up by the buttons (EXIT / RESET / STYLE run 0.62 of
-- the screen's height along the top left): the cash beside them, the drift
-- display under them, clear of a top-right cluster on screens down to
-- 16:10. On a monitor the drift display is top centre, the cash bottom left.
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local HudLab = script.Parent
local W = require(HudLab:WaitForChild("Widgets"))
local I = require(HudLab:WaitForChild("Instruments"))
local Motion = require(HudLab:WaitForChild("Motion"))

local DOT_ORDER = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZx.,+-!:/° #"
local DOT_CELL = Vector2.new(96, 128)
local LEDS = 24
local BAR = 18 -- angle bar segments, 5 degrees each

export type Style = {
	panel: string, -- 960x300
	mini: string, -- 600x200
	dots: string,
	lit: Color3, -- an LED on
	dim: Color3, -- an LED off
	hot: Color3, -- the chain LEDs at the top multiplier
	angleBar: boolean, -- the second line is the drift angle as a bar
	overlay: string?, -- over the drift display's characters (a VFD's mesh)
	miniOverlay: string?,
	flyFont: Font,
	flyColor: Color3,
	flyStroke: Color3,
}

export type Displays = {
	update: (v: any, dt: number) -> (),
	event: (kind: string, a: number, b: number) -> (),
}

local DotDisplay = {}

local function rectIn(o: GuiObject, bw: number, bh: number, x: number, y: number, w: number, h: number)
	o.AnchorPoint = Vector2.new(0, 0)
	o.Position = UDim2.fromScale(x / bw, y / bh)
	o.Size = UDim2.fromScale(w / bw, h / bh)
end

local function pad(s: string, n: number): string
	return s .. string.rep(" ", math.max(n - (utf8.len(s) or #s), 0))
end

function DotDisplay.build(root: Frame, touch: boolean, style: Style): Displays
	local top = GuiService:GetGuiInset().Y
	local function dots(parent: Instance, name: string, count: number, align: string?): I.Chars
		local c = I.chars(parent, name, { atlas = style.dots, order = DOT_ORDER, cell = DOT_CELL, cols = 10, count = count, align = align })
		c.root.ZIndex = 2
		return c
	end
	local function led(parent: Instance, name: string): Frame
		local f = W.frame(parent, name, style.dim, 0)
		f.ZIndex = 2
		W.corner(f, UDim.new(0.3, 0))
		return f
	end

	-- A square the screen's height tall, so a phone's displays are placed in
	-- fractions of the height (as the buttons are).
	local byHeight = W.frame(root, "ByHeight")
	byHeight.SizeConstraint = Enum.SizeConstraint.RelativeYY
	byHeight.Size = UDim2.fromScale(1, 1)
	byHeight.Position = UDim2.fromOffset(0, top)

	-- The drift display (960x300 art).
	local mid = W.frame(if touch then byHeight else root, "Display")
	if touch then
		mid.Size = UDim2.fromScale(0.56, 0.56 * 300 / 960)
		mid.Position = UDim2.new(0, 10, 0.115, 6)
	else
		W.box(mid, 0.6, 0.6 * 300 / 960)
		mid.AnchorPoint = Vector2.new(0.5, 0)
		mid.Position = UDim2.new(0.5, 0, 0, top + 4)
	end
	I.layer(mid, "Panel", style.panel, 1)
	local over = style.overlay
	if over then
		I.layer(mid, "Over", over, 3)
	end
	local points = dots(mid, "Points", 8)
	rectIn(points.root, 960, 300, 40, 24, 632, 105)
	local mult = dots(mid, "Mult", 4)
	rectIn(mult.root, 960, 300, 700, 50, 208, 70)
	local info = dots(mid, "Info", 16, "left")
	rectIn(info.root, 960, 300, 40, 150, 832, 70)
	-- The angle bar sits after "ANGLE" (5 characters) and before the
	-- degrees (4 characters at the right of the line).
	local bar: { Frame } = {}
	if style.angleBar then
		for i = 1, BAR do
			local f = led(mid, "Bar" .. i)
			rectIn(f, 960, 300, 316 + (i - 1) * 344 / BAR, 160, 344 / BAR - 5, 50)
			table.insert(bar, f)
		end
	end
	local leds: { Frame } = {}
	for i = 1, LEDS do
		local f = led(mid, "Led" .. i)
		rectIn(f, 960, 300, 40 + (i - 1) * 880 / LEDS, 236, 880 / LEDS - 8, 16)
		table.insert(leds, f)
	end
	local midScale = Instance.new("UIScale")
	midScale.Parent = mid

	-- The cash display (600x200 art).
	local mini = W.frame(if touch then byHeight else root, "Cash")
	if touch then
		mini.Size = UDim2.fromScale(0.3, 0.1)
		mini.Position = UDim2.new(0.62, 34, 0, 4)
	else
		W.box(mini, 0.34, 0.34 * 200 / 600)
		mini.AnchorPoint = Vector2.new(0, 1)
		mini.Position = UDim2.new(0, 22, 1, -22)
	end
	I.layer(mini, "Panel", style.mini, 1)
	local miniOver = style.miniOverlay
	if miniOver then
		I.layer(mini, "Over", miniOver, 3)
	end
	local cashLabel = dots(mini, "Label", 4, "left")
	rectIn(cashLabel.root, 600, 200, 36, 42, 136, 44)
	cashLabel.set("CASH")
	local cash = dots(mini, "Value", 9)
	rectIn(cash.root, 600, 200, 178, 28, 396, 59)
	local best = dots(mini, "Best", 16, "left")
	rectIn(best.root, 600, 200, 36, 112, 528, 44)
	local cashScale = Instance.new("UIScale")
	cashScale.Parent = mini

	local roller = Motion.roller()
	local cashRoller = Motion.roller()
	cashRoller.shown = -1
	local cashPop = Motion.spring(1, 5, 0.35)
	local midPop = Motion.spring(1, 4, 0.45)
	local message = ""
	local messageUntil = 0
	local messageBlink = false
	local held = 0 -- the points left on the display after a slide
	local heldUntil = 0
	local clock = 0

	-- Banked cash flies from the drift display into the cash display.
	local function fly(amount: number)
		local t = W.text(root, "Fly", `+{Motion.comma(amount)}`, style.flyFont, style.flyColor)
		W.stroke(t, style.flyStroke, 3)
		W.box(t, 0.3, 0.07)
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.ZIndex = 5
		local from = mid.AbsolutePosition + mid.AbsoluteSize / 2 - root.AbsolutePosition
		local to = mini.AbsolutePosition + mini.AbsoluteSize / 2 - root.AbsolutePosition
		t.Position = UDim2.fromOffset(from.X, from.Y)
		local tw = TweenService:Create(t, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromOffset(to.X, to.Y),
		})
		tw.Completed:Once(function()
			t:Destroy()
			Motion.kick(cashPop, 8)
		end)
		tw:Play()
	end

	local function update(v: any, dt: number)
		clock += dt
		local now = os.clock()
		local live = v.sliding
		if live then
			held, heldUntil = v.points, now + 1.4
		end
		local shownPoints = if live then v.points elseif now < heldUntil then held else 0
		local p = Motion.roll(roller, shownPoints, dt, 9)
		points.set(if p > 0 then Motion.comma(p) else "")
		mult.set(if live and v.mult > 1 then (if v.mult % 1 == 0 then string.format("x%d", v.mult) else string.format("x%.1f", v.mult)) else "")

		local deg = math.floor(math.abs(v.angle) + 0.5)
		local line: string
		local showBar = false
		if now < messageUntil then
			line = if messageBlink and (clock * 3) % 1 > 0.6 then "" else message
		elseif v.natl then
			local m = v.margin
			line = pad(`NATL {math.floor(math.abs(v.roll) + 0.5)}°`, 11) .. (if m < 8 then "TIP!" elseif m < 16 then "CATCH" else "HOLD")
		elseif live then
			if style.angleBar then
				showBar = true
				line = "ANGLE" .. string.rep(" ", 7) .. string.format("%3d°", math.min(deg, 999))
			else
				line = pad("DRIFT", 12) .. string.format("%3d°", math.min(deg, 999))
			end
		else
			line = string.format("TRIP %6.1f KM", v.trip)
		end
		info.set(line)
		for i, f in bar do
			f.Visible = showBar
			f.BackgroundColor3 = if showBar and deg >= i * 5 - 2.5 then style.lit else style.dim
		end

		local heat = math.clamp((v.mult - 1) / math.max(v.multMax - 1, 1), 0, 1)
		local lit = if live then math.floor(v.chain * LEDS + 0.5) else 0
		local on = style.lit:Lerp(style.hot, heat)
		for i, f in leds do
			f.BackgroundColor3 = if i <= lit then on else style.dim
		end
		midScale.Scale = Motion.step(midPop, 1, dt)

		if cashRoller.shown < 0 then
			cashRoller.shown = v.cash
		end
		cash.set(Motion.comma(Motion.roll(cashRoller, v.cash, dt, 4)))
		cashScale.Scale = Motion.step(cashPop, 1, dt)
		local showServer = v.serverBest > 0 and (clock % 6) > 3
		best.set(if showServer then `SERVER {Motion.comma(v.serverBest)}` else `BEST {Motion.comma(v.best)}`)
	end

	local function event(kind: string, a: number, b: number)
		local now = os.clock()
		if kind == "mult" then
			Motion.kick(midPop, 3)
		elseif kind == "spin" then
			Motion.kick(midPop, 5)
		elseif kind == "banked" then
			held, heldUntil = a, now + 1.6
			message, messageUntil, messageBlink = `BANKED +{Motion.comma(b)}`, now + 1.6, false
			Motion.kick(midPop, 5)
			if b > 0 then
				fly(b)
			end
		elseif kind == "dropped" then
			held, heldUntil = 0, 0
			message, messageUntil, messageBlink = "DROPPED", now + 1.2, true
		end
	end

	return { update = update, event = event }
end

return DotDisplay
