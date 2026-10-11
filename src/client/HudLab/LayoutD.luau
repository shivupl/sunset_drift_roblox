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
--   top right      EXIT / RESET / STYLE, left of the cash (the HUD's); clear
--                  of Roblox's top bar and chat window, which are top left
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
-- The cash, top right; the menu buttons line up left of it.
LayoutD.CASH_W = 0.463
LayoutD.CASH_H = 0.096
LayoutD.CASH_Y = 0.026
-- How see-through a control is with no thumb on it.
local REST = 0.15

-- Steering from the buttons, as a keyboard steers: out at STEER_OUT a
-- second, back at STEER_BACK (Input's keyboard ramp is 4 and 8).
local STEER_OUT = 4.5
local STEER_BACK = 8

-- Cells in Art.icons, 4 across.
local ICON_CELL = 192
local ICON = { left = 0, right = 1, natlL = 2, natlR = 3, hand = 4, exit = 5, reset = 6, style = 7 }

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
	update: (dt: number) -> (),
}

-- A round button: the finish's base, the icon over it in the finish's
-- print, the halo in its accent when lit. onPress(true) as a thumb lands,
-- onPress(false) as it lifts. Held it sinks and goes solid with a faint
-- halo; lit (HAND held, the side the car is up on) the halo is full and
-- the icon takes the accent.
local function round(parent: Instance, name: string, finish: Finishes.Finish, icon: number, t: W.Tracker, onPress: (boolean) -> ()): Round
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
	ico.ZIndex = 2
	local halo = W.image(body, "Halo", Art.halo)
	halo.ImageColor3 = finish.accent
	halo.ImageTransparency = 1
	halo.ZIndex = 3

	local isDown, lit, shown = false, false, true
	local press = Motion.spring(0, 10, 0.6)
	local glow = Motion.spring(0, 8, 1)
	local vis = Motion.spring(1, 7, 1)
	W.claim(t, root, function()
		if not shown or isDown then
			return
		end
		isDown = true
		Motion.kick(press, 6)
		onPress(true)
	end, nil, function()
		if isDown then
			isDown = false
			onPress(false)
		end
	end)

	local function update(dt: number)
		local d = Motion.step(press, if isDown then 1 else 0, dt)
		local g = Motion.step(glow, if lit then 1 elseif isDown then 0.45 else 0, dt)
		local v = Motion.step(vis, if shown then 1 else 0, dt)
		root.Visible = v > 0.02
		scale.Scale = (1 - 0.07 * d) * (0.85 + 0.15 * v)
		local rest = REST * (1 - math.max(d, g))
		local alpha = rest + (1 - rest) * (1 - v)
		base.ImageTransparency = alpha
		base.ImageColor3 = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(170, 170, 176), 0.5 * d)
		ico.ImageTransparency = alpha
		ico.ImageColor3 = finish.print:Lerp(finish.accent, if lit then g else 0)
		halo.ImageTransparency = 1 - g * v
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
		update = update,
	}
end

function LayoutD.build(gui: ScreenGui, api: any, finish: Finishes.Finish): any
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
	local steerL = add(round(left, "SteerLeft", finish, ICON.left, t, function() end))
	local steerR = add(round(left, "SteerRight", finish, ICON.right, t, function() end))
	local xL = STEER_X + BIG / 2
	local xR = xL + BIG + GAP
	local steerY = 1 - STEER_B - BIG / 2
	place(steerL.root, xL, steerY, BIG, BIG)
	place(steerR.root, xR, steerY, BIG, BIG)
	local rowY = steerY - BIG / 2 - GAP - NATL / 2
	local natlL = add(round(left, "NatlLeft", finish, ICON.natlL, t, function(down)
		api.leanLeft(down)
	end))
	local natlR = add(round(left, "NatlRight", finish, ICON.natlR, t, function(down)
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
	hand = add(round(right, "Hand", finish, ICON.hand, t, function(down)
		api.handbrake(down)
		hand.setLit(down)
	end))
	place(hand.root, brakeX, rowY, BIG, BIG)

	-- EXIT / RESET / STYLE, left of the cash.
	local menu: { { name: string, icon: number, fn: () -> () } } = {
		{ name = "Exit", icon = ICON.exit, fn = api.exit },
		{ name = "Reset", icon = ICON.reset, fn = api.reset },
		{ name = "Style", icon = ICON.style, fn = api.cycle },
	}
	for i, spec in menu do
		local fn = spec.fn
		local b = add(round(right, spec.name, finish, spec.icon, t, function(down)
			if down then
				fn()
			end
		end))
		local fromRight = er + LayoutD.CASH_W + 0.02 + SMALL / 2 + (#menu - i) * (SMALL + 0.012)
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
			gas.update(dt)
			brake.update(dt)
			for _, r in rounds do
				r.update(dt)
			end
		end,
		-- ready: fast enough to lift, or up already; side: -1 up on the
		-- left wheels, 1 the right, 0 down.
		setNatl = function(ready: boolean, side: number)
			natlL.setShown(ready)
			natlR.setShown(ready)
			natlL.setLit(side < 0)
			natlR.setLit(side > 0)
		end,
		destroy = function()
			W.release(t)
			root:Destroy()
		end,
	}
end

return LayoutD
