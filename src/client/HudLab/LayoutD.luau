--!strict
-- Layout D (hud-variants, 2026-10-08): the phone layout the owner put
-- together from the mockups (claude.ai canvas "Hajwala mobile HUD layouts",
-- board D): "make the handbreak a button not a slide", the tacho small and
-- see-through at the bottom middle, cash top right, "the buttons should go
-- out a bit more".
--
--   bottom left    two round steer buttons, NATL over the right one (the
--                  lean slider over them while on two wheels)
--   bottom right   the tall gas in the corner, the brake left of it, a round
--                  HAND button over the brake
--   top right      EXIT / RESET / STYLE as round icon buttons, left of the
--                  cash (the HUD's); clear of Roblox's top bar and chat
--                  window, which are top left
--
-- Positions are fractions of the screen's height, measured in from the
-- corner each group sits in, so they keep their spacing on any phone; the
-- gui keeps out of a notch and the home bar (ScreenInsets).
local HudLab = script.Parent
local W = require(HudLab:WaitForChild("Widgets"))
local Motion = require(HudLab:WaitForChild("Motion"))

local LayoutD = {}

-- In from the screen's sides and bottom, fractions of its height.
LayoutD.EDGE_X = 0.05
LayoutD.EDGE_B = 0.03
-- Where the round menu buttons sit, so the HUD can put the cash beside them:
-- the cash's right edge is EDGE_X in, CASH_W wide, its top CASH_Y.
LayoutD.CASH_W = 0.463
LayoutD.CASH_H = 0.096
LayoutD.CASH_Y = 0.026

-- Steering from the buttons, as a keyboard steers: out at STEER_OUT a
-- second, back at STEER_BACK (Input's keyboard ramp is 4 and 8).
local STEER_OUT = 4.5
local STEER_BACK = 8

export type Skin = {
	left: string,
	right: string,
	natlOff: string,
	natlOn: string,
	handOff: string,
	handOn: string,
	exit: string,
	reset: string,
	style: string,
	pedalGas: string, -- 400x1000
	pedalBrake: string, -- 560x520
	leanTrack: string, -- 900x200
	leanKnob: string,
}

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

type Hold = { root: Frame, down: () -> boolean, update: (dt: number) -> () }

-- A round button held down (steer, HAND): it sinks and darkens while held;
-- `lit`, if given, is its art while held.
local function hold(parent: Instance, name: string, image: string, lit: string?, t: W.Tracker, onChange: (boolean) -> ()): Hold
	local root = W.frame(parent, name)
	local img = W.image(root, "Art", image)
	local scale = Instance.new("UIScale")
	scale.Parent = img
	local isDown = false
	local press = Motion.spring(0, 10, 0.6)
	W.claim(t, root, function()
		isDown = true
		Motion.kick(press, 6)
		onChange(true)
	end, nil, function()
		isDown = false
		onChange(false)
	end)
	local function update(dt: number)
		local d = Motion.step(press, if isDown then 1 else 0, dt)
		scale.Scale = 1 - 0.07 * d
		img.ImageColor3 = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(170, 170, 176), 0.6 * d)
		img.Image = if isDown and lit then lit else image
	end
	return {
		root = root,
		down = function()
			return isDown
		end,
		update = update,
	}
end

function LayoutD.build(gui: ScreenGui, api: any, skin: Skin): any
	-- Keep out of a notch and the home bar.
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	local t = W.tracker()
	local root = W.frame(gui, "LayoutD")
	root.Size = UDim2.fromScale(1, 1)
	local left = LayoutD.corner(root, "Left", false)
	local right = LayoutD.corner(root, "Right", true)
	local ex, eb = LayoutD.EDGE_X, LayoutD.EDGE_B

	-- Steering.
	local steer = 0
	local steerL = hold(left, "SteerLeft", skin.left, nil, t, function() end)
	local steerR = hold(left, "SteerRight", skin.right, nil, t, function() end)
	local sb = 0.215
	place(steerL.root, ex + sb / 2, 1 - eb - sb / 2, sb, sb)
	place(steerR.root, ex + 0.356, 1 - eb - sb / 2, sb, sb)

	local natlSkin: W.ButtonSkin = {
		fill = Color3.new(0, 0, 0),
		fillTransparency = 1,
		lit = Color3.new(1, 1, 1),
		edge = Color3.new(1, 1, 1),
		edgeThickness = 0,
		radius = UDim.new(0.5, 0),
		font = W.font("BuilderSans", Enum.FontWeight.Bold),
		text = Color3.new(1, 1, 1),
		litText = Color3.new(1, 1, 1),
		textStroke = nil,
		image = skin.natlOff,
		litImage = skin.natlOn,
		slice = nil,
		sliceHeight = nil,
	}
	local natl = W.button(left, "Natl", "", natlSkin, t, function()
		api.natl()
	end)
	-- Higher than the mockup had it, clear of the right steer button (the
	-- owner, 2026-10-08: "this needs to be a bit higher").
	place(natl.root, ex + 0.356, 0.55, 0.178, 0.178)

	local lean = W.slider(left, "Lean", {
		track = Color3.new(0, 0, 0),
		trackTransparency = 1,
		edge = Color3.new(1, 1, 1),
		edgeThickness = 0,
		knob = Color3.new(1, 1, 1),
		knobEdge = Color3.new(1, 1, 1),
		radius = UDim.new(0.5, 0),
		marks = nil,
		markFont = nil,
		left = nil,
		right = nil,
		trackImage = skin.leanTrack,
		knobImage = skin.leanKnob,
	}, t, function(frac)
		api.lean(frac)
	end)
	place(lean.root, ex + 0.24, 0.47, 0.44, 0.098)
	lean.root.Visible = false

	-- Pedals and HAND.
	local function pedalSkin(image: string, minValue: number): W.PedalSkin
		local white = Color3.new(1, 1, 1)
		return {
			plate = white,
			plateLow = white,
			edge = white,
			edgeThickness = 0,
			radius = UDim.new(0.2, 0),
			slots = 0,
			slot = white,
			slotTransparency = 1,
			label = "",
			labelFont = natlSkin.font,
			labelColor = white,
			labelStroke = nil,
			shadow = white,
			shadowTransparency = 1,
			depth = 0.05,
			fill = nil,
			minValue = minValue,
			image = image,
		}
	end
	local gas = W.pedal(right, "Gas", pedalSkin(skin.pedalGas, 0.45), t, function(v)
		api.throttle(v)
	end)
	place(gas.root, 1 - ex - 0.1185, 1 - eb - 0.25, 0.237, 0.5)
	local brake = W.pedal(right, "Brake", pedalSkin(skin.pedalBrake, 0.5), t, function(v)
		api.brake(v)
	end)
	place(brake.root, 1 - ex - 0.459, 1 - eb - 0.1167, 0.37, 0.233)
	local hand = hold(right, "Hand", skin.handOff, skin.handOn, t, function(on)
		api.handbrake(on)
	end)
	place(hand.root, 1 - ex - 0.376, 0.598, 0.204, 0.204)

	-- EXIT / RESET / STYLE, left of the cash.
	local menuSkin = table.clone(natlSkin)
	menuSkin.litImage = nil
	local buttons: { W.Button } = {}
	local menu: { { name: string, image: string, fn: () -> () } } = {
		{ name = "Exit", image = skin.exit, fn = api.exit },
		{ name = "Reset", image = skin.reset, fn = api.reset },
		{ name = "Style", image = skin.style, fn = api.cycle },
	}
	for i, spec in menu do
		local s = table.clone(menuSkin)
		s.image = spec.image
		local fn = spec.fn
		local b = W.button(right, spec.name, "", s, t, function()
			fn()
		end)
		local fromRight = ex + LayoutD.CASH_W + 0.03 + (3 - i) * 0.115 + 0.052
		place(b.root, 1 - fromRight, LayoutD.CASH_Y + LayoutD.CASH_H / 2, 0.104, 0.104)
		table.insert(buttons, b)
	end

	return {
		update = function(dt: number)
			local want = (if steerR.down() then 1 else 0) - (if steerL.down() then 1 else 0)
			-- Back toward centre (or across it) at the faster rate.
			local back = want == 0 or (steer ~= 0 and math.sign(want) ~= math.sign(steer))
			local rate = if back then STEER_BACK else STEER_OUT
			steer = if steer < want then math.min(want, steer + rate * dt) else math.max(want, steer - rate * dt)
			api.steer(steer)
			steerL.update(dt)
			steerR.update(dt)
			hand.update(dt)
			gas.update(dt)
			brake.update(dt)
			natl.update(dt)
			lean.update(dt)
			for _, b in buttons do
				b.update(dt)
			end
		end,
		setLean = function(visible: boolean)
			lean.root.Visible = visible
			if not visible then
				api.lean(0)
			end
		end,
		setNatl = function(on: boolean)
			natl.setLit(on)
		end,
		destroy = function()
			W.release(t)
			root:Destroy()
		end,
	}
end

return LayoutD
