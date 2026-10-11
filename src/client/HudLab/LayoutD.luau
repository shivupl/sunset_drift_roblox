--!strict
-- Layout D (hud-variants, 2026-10-08): the phone controls the owner put
-- together from the mockups (claude.ai canvas "Hajwala mobile HUD layouts",
-- board D): "make the handbreak a button not a slide", the tacho small and
-- see-through at the bottom middle, cash top right, "the buttons should go
-- out a bit more". Reworked on 2026-10-10 (the owner: "very much is
-- unasthetic in terms of button placement and non functional"; "make it 2
-- natl buttons that show up one left one right"; "button / overlay opacity
-- find a way to reduce it subtly"):
--
--   bottom left    ◀ ▶, a NATL button over each: NATL◀ is Q and NATL▶ is
--                  E (a tap lifts the car onto that side's wheels, taps
--                  keep it up, the other one catches), placed as Q and E sit
--                  over A and D. The right thumb stays on the gas. They
--                  show up once the car is fast enough to lift
--                  (twoWheel.minLiftSpeedKmh) and stay while it is up; the
--                  side it is up on is lit.
--   bottom right   the gas in the corner, the brake left of it, HAND over
--                  the brake, level with the NATL row and the gas's top
--   top right      EXIT / RESET / STYLE / UI, left of the cash (the HUD's);
--                  clear of Roblox's top bar and chat window, which are top
--                  left. STYLE cycles the finish, UI the version (Versions).
--
-- Live controls (FLOW and SIDE; the owner, 2026-10-10: "the buttons - dead
-- and lfieless"): a ripple on every press; a glint across each button now
-- and then, never two at once; the steer buttons glowing with the steer
-- they are giving as it ramps; NATL popping in when it shows and breathing
-- while it can lift; a light strip by each pedal filling with how hard it
-- is pressed, the gas's blinking near the redline like a shift light.
--
-- Every control's hit box is the shape you see: the pedals are laid out at
-- their art's own shape (they used to sit letterboxed in boxes of another
-- shape, the brake's half as wide again as its plate). Two round sizes, one
-- gap. At rest the controls let a little of the road through (REST, and the
-- art's see-through faces and drilled slots); under a thumb they are solid.
--
-- Positions are fractions of the screen's height, measured in from the
-- corner each group sits in, so they keep their spacing on any phone; the
-- gui keeps out of a notch and the home bar (ScreenInsets).
local HudLab = script.Parent
local W = require(HudLab:WaitForChild("Widgets"))
local Motion = require(HudLab:WaitForChild("Motion"))
local Art = require(HudLab:WaitForChild("Art"))
local Finishes = require(HudLab:WaitForChild("Finishes"))
local Versions = require(HudLab:WaitForChild("Versions"))

local LayoutD = {}

-- In from the safe area's bottom and right edges, fractions of its height.
LayoutD.EDGE_B = 0.03
LayoutD.EDGE_R = 0.02
-- The steer buttons sit higher and nearer the left edge (the owner,
-- 2026-10-10: "move the leftright up and a bit left, move the pedals a bit
-- to the right").
local STEER_X = 0.025
local STEER_B = 0.1
-- Two round sizes, so the buttons read as one set: BIG for what a thumb
-- lives on (steer, HAND), SMALL for the menu; NATL between them.
local BIG = 0.21
local NATL = 0.16
local SMALL = 0.11
local GAP = 0.035
-- The pedals at their art's shape: the gas 400x1000, the brake 640x404.
local GAS_W, GAS_H = 0.2, 0.5
local BRAKE_W, BRAKE_H = 0.37, 0.2336
-- The cash, top right (its width is the version's, Versions.cashW); the
-- menu buttons line up left of it.
LayoutD.CASH_H = 0.096
LayoutD.CASH_Y = 0.026
-- How see-through a control is with no thumb on it.
local REST = 0.15
-- Live controls: a ripple's life, how often a button glints and how long
-- the glint takes to cross it, how fast NATL breathes while it can lift.
local RIPPLE_SECONDS = 0.4
local SHEEN_EVERY = 7
local SHEEN_SECONDS = 0.6
local BREATHE_HZ = 0.55
-- The gas strip blinks from here, a fraction of the redline.
local SHIFT_AT = 0.93
local INK = Color3.fromRGB(12, 12, 13)

-- Steering from the buttons, as a keyboard steers: out at STEER_OUT a
-- second, back at STEER_BACK (Input's keyboard ramp is 4 and 8).
local STEER_OUT = 4.5
local STEER_BACK = 8

-- Cells in Art.icons, 4 across.
local ICON_CELL = 192
local ICON = { left = 0, right = 1, natlL = 2, natlR = 3, hand = 4, exit = 5, reset = 6, style = 7, layout = 8 }
local SHEEN = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.4, 1),
	NumberSequenceKeypoint.new(0.5, 0.72),
	NumberSequenceKeypoint.new(0.6, 1),
	NumberSequenceKeypoint.new(1, 1),
})

-- A square the screen's height tall in a corner: children are placed in
-- fractions of the height from that side.
function LayoutD.corner(parent: Instance, name: string, right: boolean): Frame
	local f = W.frame(parent, name)
	f.SizeConstraint = Enum.SizeConstraint.RelativeYY
	f.Size = UDim2.fromScale(1, 1)
	f.AnchorPoint = Vector2.new(if right then 1 else 0, 0)
	f.Position = UDim2.fromScale(if right then 1 else 0, 0)
	return f
end

local function place(o: GuiObject, x: number, y: number, w: number, h: number)
	o.AnchorPoint = Vector2.new(0.5, 0.5)
	o.Position = UDim2.fromScale(x, y)
	o.Size = UDim2.fromScale(w, h)
end

type Round = {
	root: Frame,
	down: () -> boolean,
	setLit: (on: boolean) -> (),
	setShown: (on: boolean) -> (),
	setGlow: (amount: number) -> (), -- live: a glow short of lit (the steer given)
	setBreathe: (on: boolean) -> (), -- live: a slow pulse (NATL can lift)
	update: (dt: number) -> (),
}

-- A round button: the finish's base, the icon over it in the finish's
-- print, the halo in its accent when lit. onPress(true) as a thumb lands,
-- onPress(false) as it lifts. Held it sinks and goes solid with a faint
-- halo; lit (HAND held, the side the car is up on) the halo is full and
-- the icon takes the accent. live: the ripple, the glint, setGlow and
-- setBreathe, and a pop with an overshoot when it shows.
local function round(parent: Instance, name: string, finish: Finishes.Finish, icon: number, t: W.Tracker, live: boolean, onPress: (boolean) -> ()): Round
	local root = W.frame(parent, name)
	local body = W.frame(root, "Body")
	body.Size = UDim2.fromScale(1, 1)
	local scale = Instance.new("UIScale")
	scale.Parent = body
	local base = W.image(body, "Base", finish.art.base)
	local ico = W.image(body, "Icon", Art.icons)
	ico.ImageRectSize = Vector2.new(ICON_CELL, ICON_CELL)
	ico.ImageRectOffset = Vector2.new((icon % 4) * ICON_CELL, (icon // 4) * ICON_CELL)
	ico.ImageColor3 = finish.print
	ico.Size = UDim2.fromScale(0.62, 0.62)
	W.at(ico, 0.5, 0.5)
	ico.ZIndex = 3
	local halo = W.image(body, "Halo", Art.halo)
	halo.ImageColor3 = finish.accent
	halo.ImageTransparency = 1
	halo.ZIndex = 4
	local ripple: ImageLabel? = nil
	local sheen: ImageLabel? = nil
	local sheenGrad: UIGradient? = nil
	if live then
		local r = W.image(root, "Ripple", Art.ring)
		r.ImageColor3 = finish.accent
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.Position = UDim2.fromScale(0.5, 0.5)
		r.Visible = false
		r.ZIndex = 5
		ripple = r
		local sh = W.image(body, "Sheen", Art.disc)
		sh.ZIndex = 2
		sh.Visible = false
		local g = Instance.new("UIGradient")
		g.Transparency = SHEEN
		g.Rotation = 30
		g.Parent = sh
		sheen, sheenGrad = sh, g
	end

	local isDown, lit, shown = false, false, true
	local glowExtra, breathe = 0, false
	local clock = math.random() * SHEEN_EVERY -- so no two buttons glint together
	local rippleT = math.huge
	local press = Motion.spring(0, 10, 0.6)
	local glow = Motion.spring(0, 8, 1)
	local vis = Motion.spring(1, 7, if live then 0.5 else 1)
	W.claim(t, root, function()
		if not shown or isDown then
			return
		end
		isDown = true
		rippleT = 0
		Motion.kick(press, 6)
		onPress(true)
	end, nil, function()
		if isDown then
			isDown = false
			onPress(false)
		end
	end)

	local function update(dt: number)
		clock += dt
		local d = Motion.step(press, if isDown then 1 else 0, dt)
		local want = if lit then 1 elseif isDown then 0.45 else 0
		if live then
			want = math.max(want, glowExtra * 0.8)
			if breathe and not lit then
				want = math.max(want, 0.2 + 0.14 * math.sin(clock * 2 * math.pi * BREATHE_HZ))
			end
		end
		local g = Motion.step(glow, want, dt)
		local v = Motion.step(vis, if shown then 1 else 0, dt)
		root.Visible = v > 0.02
		scale.Scale = (1 - 0.07 * d) * (0.85 + 0.15 * v)
		local rest = REST * (1 - math.max(d, g))
		local alpha = rest + (1 - rest) * (1 - math.clamp(v, 0, 1))
		base.ImageTransparency = alpha
		base.ImageColor3 = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(170, 170, 176), 0.5 * d)
		ico.ImageTransparency = alpha
		ico.ImageColor3 = finish.print:Lerp(finish.accent, if lit or glowExtra > 0.05 then g else 0)
		halo.ImageTransparency = 1 - g * math.clamp(v, 0, 1)
		local r = ripple
		if r then
			rippleT += dt
			local k = rippleT / RIPPLE_SECONDS
			r.Visible = k < 1
			if k < 1 then
				local e = 1 - (1 - k) ^ 2
				r.Size = UDim2.fromScale(0.95 + 0.55 * e, 0.95 + 0.55 * e)
				r.ImageTransparency = 0.25 + 0.75 * e
			end
		end
		local sh, sg = sheen, sheenGrad
		if sh and sg then
			local k = (clock % SHEEN_EVERY) / SHEEN_SECONDS
			sh.Visible = k < 1 and v > 0.5
			if k < 1 then
				sg.Offset = Vector2.new(-0.8 + 1.6 * k, 0)
			end
		end
	end
	return {
		root = root,
		down = function()
			return isDown
		end,
		setLit = function(on: boolean)
			lit = on
		end,
		setShown = function(on: boolean)
			shown = on
			if not on and isDown then
				-- A control that goes away under a thumb lets go.
				isDown = false
				onPress(false)
			end
		end,
		setGlow = function(amount: number)
			glowExtra = amount
		end,
		setBreathe = function(on: boolean)
			breathe = on
		end,
		update = update,
	}
end

-- Live: a light strip by a pedal, filling with how hard it is pressed. The
-- gas's runs up its left side, the brake's along its top.
type Strip = { fill: Frame, update: (amount: number, blink: boolean, clock: number, dt: number) -> () }

local function strip(pedal: Frame, colour: Color3, flash: Color3, vertical: boolean): Strip
	local track = W.frame(pedal, "StripTrack", INK, 0.55)
	local fill = W.frame(track, "Strip", colour, 0.05)
	W.corner(track)
	W.corner(fill)
	if vertical then
		track.AnchorPoint = Vector2.new(1, 1)
		track.Position = UDim2.fromScale(0.085, 0.955)
		track.Size = UDim2.fromScale(0.035, 0.91)
		fill.AnchorPoint = Vector2.new(0, 1)
		fill.Position = UDim2.fromScale(0, 1)
	else
		track.AnchorPoint = Vector2.new(0, 1)
		track.Position = UDim2.fromScale(0.04, 0.05)
		track.Size = UDim2.fromScale(0.92, 0.03)
	end
	local amt = Motion.spring(0, 12, 1)
	return {
		fill = fill,
		update = function(amount: number, blink: boolean, clock: number, dt: number)
			local a = Motion.step(amt, amount, dt)
			fill.Size = if vertical then UDim2.fromScale(1, a) else UDim2.fromScale(a, 1)
			fill.BackgroundColor3 = if blink and (clock * 10) % 2 < 1 then flash else colour
		end,
	}
end

function LayoutD.build(gui: ScreenGui, api: any, finish: Finishes.Finish, version: Versions.Version): any
	local live = version.live
	-- Keep out of a notch and the home bar.
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	local t = W.tracker()
	local root = W.frame(gui, "LayoutD")
	root.Size = UDim2.fromScale(1, 1)
	local left = LayoutD.corner(root, "Left", false)
	local right = LayoutD.corner(root, "Right", true)
	local eb, er = LayoutD.EDGE_B, LayoutD.EDGE_R
	local rounds: { Round } = {}
	local function add(r: Round): Round
		table.insert(rounds, r)
		return r
	end

	-- Steering, and a NATL over each steer button.
	local steer = 0
	local steerL = add(round(left, "SteerLeft", finish, ICON.left, t, live, function() end))
	local steerR = add(round(left, "SteerRight", finish, ICON.right, t, live, function() end))
	local xL = STEER_X + BIG / 2
	local xR = xL + BIG + GAP
	local steerY = 1 - STEER_B - BIG / 2
	place(steerL.root, xL, steerY, BIG, BIG)
	place(steerR.root, xR, steerY, BIG, BIG)
	local rowY = steerY - BIG / 2 - GAP - NATL / 2
	local natlL = add(round(left, "NatlLeft", finish, ICON.natlL, t, live, function(down)
		api.leanLeft(down)
	end))
	local natlR = add(round(left, "NatlRight", finish, ICON.natlR, t, live, function(down)
		api.leanRight(down)
	end))
	place(natlL.root, xL, rowY, NATL, NATL)
	place(natlR.root, xR, rowY, NATL, NATL)
	natlL.setShown(false)
	natlR.setShown(false)

	-- Pedals and HAND.
	local gas = W.pedal(right, "Gas", { image = finish.art.pedalGas, minValue = 0.45, depth = 0.05, rest = REST }, t, function(v)
		api.throttle(v)
	end)
	place(gas.root, 1 - er - GAS_W / 2, 1 - eb - GAS_H / 2, GAS_W, GAS_H)
	local brakeX = 1 - er - GAS_W - GAP - BRAKE_W / 2
	local brake = W.pedal(right, "Brake", { image = finish.art.pedalBrake, minValue = 0.5, depth = 0.05, rest = REST }, t, function(v)
		api.brake(v)
	end)
	place(brake.root, brakeX, 1 - eb - BRAKE_H / 2, BRAKE_W, BRAKE_H)
	local hand: Round
	hand = add(round(right, "Hand", finish, ICON.hand, t, live, function(down)
		api.handbrake(down)
		hand.setLit(down)
	end))
	place(hand.root, brakeX, rowY, BIG, BIG)
	local gasStrip: Strip? = nil
	local brakeStrip: Strip? = nil
	if live then
		gasStrip = strip(gas.root, finish.accent, finish.print, true)
		brakeStrip = strip(brake.root, finish.dropped, finish.dropped, false)
	end
	local rpmFrac = 0
	local clock = 0

	-- EXIT / RESET / STYLE, left of the cash.
	local menu: { { name: string, icon: number, fn: () -> () } } = {
		{ name = "Exit", icon = ICON.exit, fn = api.exit },
		{ name = "Reset", icon = ICON.reset, fn = api.reset },
		{ name = "Style", icon = ICON.style, fn = api.cycle },
		{ name = "Layout", icon = ICON.layout, fn = api.layout },
	}
	for i, spec in menu do
		local fn = spec.fn
		local b = add(round(right, spec.name, finish, spec.icon, t, live, function(down)
			if down then
				fn()
			end
		end))
		local fromRight = er + version.cashW + 0.02 + SMALL / 2 + (#menu - i) * (SMALL + 0.012)
		place(b.root, 1 - fromRight, LayoutD.CASH_Y + LayoutD.CASH_H / 2, SMALL, SMALL)
	end

	return {
		update = function(dt: number)
			local want = (if steerR.down() then 1 else 0) - (if steerL.down() then 1 else 0)
			-- Back toward centre (or across it) at the faster rate.
			local back = want == 0 or (steer ~= 0 and math.sign(want) ~= math.sign(steer))
			local rate = if back then STEER_BACK else STEER_OUT
			steer = if steer < want then math.min(want, steer + rate * dt) else math.max(want, steer - rate * dt)
			api.steer(steer)
			clock += dt
			steerL.setGlow(math.max(-steer, 0))
			steerR.setGlow(math.max(steer, 0))
			gas.update(dt)
			brake.update(dt)
			local gs, bs = gasStrip, brakeStrip
			if gs then
				gs.update(gas.value(), rpmFrac >= SHIFT_AT, clock, dt)
			end
			if bs then
				bs.update(brake.value(), false, clock, dt)
			end
			for _, r in rounds do
				r.update(dt)
			end
		end,
		-- The engine's speed as a fraction of the redline (the shift light).
		setRpm = function(frac: number)
			rpmFrac = frac
		end,
		-- ready: fast enough to lift, or up already; side: -1 up on the
		-- left wheels, 1 the right, 0 down.
		setNatl = function(ready: boolean, side: number)
			natlL.setShown(ready)
			natlR.setShown(ready)
			natlL.setLit(side < 0)
			natlR.setLit(side > 0)
			natlL.setBreathe(ready and side == 0)
			natlR.setBreathe(ready and side == 0)
		end,
		destroy = function()
			W.release(t)
			root:Destroy()
		end,
	}
end

return LayoutD
