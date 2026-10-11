--!strict
-- The pieces the HUD is made of (hud-variants, 2026-10-07): pedals that
-- sink and give part throttle by where the thumb sits, the touch tracking
-- every control shares, an edge glow and shouted callouts. The round
-- buttons are LayoutD's.
--
-- Everything is sized from the screen's height (SizeConstraint RelativeYY)
-- and its text is TextScaled, so one layout fits a phone and a monitor.
-- Each control takes a skin: its art, colours and shape.
--
-- Touch: a Tracker claims an InputObject when it begins on a control and
-- routes its moves and its end to that control until it lifts, so two thumbs
-- never confuse each other and a thumb that slides off a pedal still lets it
-- go (Touch.luau's rule). A mouse press counts too, with MouseMovement as its
-- moves, so Studio without the device emulator can drive them.
local UserInputService = game:GetService("UserInputService")

local Motion = require(script.Parent:WaitForChild("Motion"))

local W = {}

------------------------------------------------------------------------
-- Building blocks.
------------------------------------------------------------------------

function W.font(family: string, weight: Enum.FontWeight?, italic: boolean?): Font
	return Font.new(
		`rbxasset://fonts/families/{family}.json`,
		weight or Enum.FontWeight.Regular,
		if italic then Enum.FontStyle.Italic else Enum.FontStyle.Normal
	)
end

function W.frame(parent: Instance, name: string, color: Color3?, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	if color then
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transparency or 0
	else
		f.BackgroundTransparency = 1
	end
	f.Parent = parent
	return f
end

-- A square sized from the parent's height: size is a fraction of it.
function W.square(f: GuiObject, size: number)
	f.SizeConstraint = Enum.SizeConstraint.RelativeYY
	f.Size = UDim2.fromScale(size, size)
end

-- A box sized from the parent's height: w and h are fractions of it.
function W.box(f: GuiObject, w: number, h: number)
	f.SizeConstraint = Enum.SizeConstraint.RelativeYY
	f.Size = UDim2.fromScale(w, h)
end

function W.corner(o: GuiObject, radius: UDim?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0.5, 0)
	c.Parent = o
	return c
end

function W.stroke(o: GuiObject, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = if o:IsA("TextLabel") or o:IsA("TextButton") then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = o
	return s
end

-- A text box filling its frame, its text scaled to fit.
function W.text(parent: Instance, name: string, text: string, font: Font, color: Color3): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.BorderSizePixel = 0
	t.FontFace = font
	t.Text = text
	t.TextColor3 = color
	t.TextScaled = true
	t.Size = UDim2.fromScale(1, 1)
	t.Parent = parent
	return t
end

-- An image filling its parent, transparent around it.
function W.image(parent: Instance, name: string, image: string): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.BackgroundTransparency = 1
	i.BorderSizePixel = 0
	i.Image = image
	i.ScaleType = Enum.ScaleType.Fit
	i.Size = UDim2.fromScale(1, 1)
	i.Parent = parent
	return i
end

-- Places a child at a point given as fractions of its parent, centred.
function W.at(o: GuiObject, x: number, y: number)
	o.AnchorPoint = Vector2.new(0.5, 0.5)
	o.Position = UDim2.fromScale(x, y)
end

------------------------------------------------------------------------
-- Touch tracking.
------------------------------------------------------------------------

type Claim = { gui: GuiObject, move: ((Vector2) -> ())?, ended: () -> () }

export type Tracker = {
	connections: { RBXScriptConnection },
	claims: { [InputObject]: Claim },
}

local function isPress(io: InputObject): boolean
	return io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1
end

function W.tracker(): Tracker
	local t: Tracker = { connections = {}, claims = {} }
	table.insert(
		t.connections,
		UserInputService.InputChanged:Connect(function(io: InputObject)
			for held, claim in t.claims do
				local mine = io == held
					or (held.UserInputType == Enum.UserInputType.MouseButton1 and io.UserInputType == Enum.UserInputType.MouseMovement)
				local move = claim.move
				if mine and move then
					move(Vector2.new(io.Position.X, io.Position.Y))
				end
			end
		end)
	)
	table.insert(
		t.connections,
		UserInputService.InputEnded:Connect(function(io: InputObject)
			local claim = t.claims[io]
			if claim then
				t.claims[io] = nil
				claim.ended()
			end
		end)
	)
	return t
end

-- Makes gui a control: began on a press over it, move with the press's
-- position while it is held, ended when it lifts (wherever it is).
function W.claim(t: Tracker, gui: GuiObject, began: (Vector2) -> (), move: ((Vector2) -> ())?, ended: () -> ())
	gui.Active = true
	table.insert(
		t.connections,
		gui.InputBegan:Connect(function(io: InputObject)
			if not isPress(io) or t.claims[io] ~= nil then
				return
			end
			for _, other in t.claims do
				if other.gui == gui then
					return -- one thumb per control
				end
			end
			t.claims[io] = { gui = gui, move = move, ended = ended }
			began(Vector2.new(io.Position.X, io.Position.Y))
		end)
	)
end

-- Lets go of every held control (each one's ended runs) and disconnects.
function W.release(t: Tracker)
	for io, claim in t.claims do
		t.claims[io] = nil
		claim.ended()
	end
	for _, c in t.connections do
		c:Disconnect()
	end
	table.clear(t.connections)
end

------------------------------------------------------------------------
-- Pedal: rendered art (Art.luau) at the pedal's own shape, so its hit box
-- is the plate you see. It sinks and darkens under the thumb. Where the
-- thumb sits sets how much: the top two thirds is all of it, the bottom down
-- to `minValue`, so a thumb sliding down the pedal feathers it (drifting
-- wants part throttle).
------------------------------------------------------------------------

export type PedalSkin = {
	image: string,
	minValue: number,
	depth: number, -- how far it sinks, fraction of its height
	rest: number, -- its transparency with no thumb on it; solid under one
}

export type Pedal = {
	root: Frame,
	plate: GuiObject,
	update: (dt: number) -> (),
	value: () -> number,
}

function W.pedal(parent: Instance, name: string, skin: PedalSkin, t: Tracker, onValue: (number) -> ()): Pedal
	local root = W.frame(parent, name)
	local plate = W.image(root, "Plate", skin.image)
	local scale = Instance.new("UIScale")
	scale.Parent = plate

	local target = 0
	local press = Motion.spring(0, 9, 0.6)
	local function fromY(y: number)
		local top = root.AbsolutePosition.Y
		local h = math.max(root.AbsoluteSize.Y, 1)
		local up = 1 - math.clamp((y - top) / h, 0, 1)
		target = math.clamp(skin.minValue + (1 - skin.minValue) * up * 1.5, skin.minValue, 1)
		onValue(target)
	end
	W.claim(t, root, function(p)
		Motion.kick(press, 6)
		fromY(p.Y)
	end, function(p)
		fromY(p.Y)
	end, function()
		target = 0
		onValue(0)
	end)

	local function update(dt: number)
		local d = Motion.step(press, if target > 0 then 0.6 + 0.4 * target else 0, dt)
		plate.Position = UDim2.fromScale(0, skin.depth * d)
		scale.Scale = 1 - 0.05 * d
		-- Pressed down out of the light, and solid.
		plate.ImageColor3 = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(150, 150, 156), d)
		plate.ImageTransparency = skin.rest * (1 - math.clamp(d / 0.6, 0, 1))
	end
	return { root = root, plate = plate, update = update, value = function()
		return target
	end }
end

------------------------------------------------------------------------
-- Edge glow: the screen's four edges tinted, strongest at the edge, for
-- a slide in progress (its colour and strength) or a flash.
------------------------------------------------------------------------

export type EdgeGlow = { root: Frame, set: (color: Color3, alpha: number) -> () }

function W.edgeGlow(parent: Instance): EdgeGlow
	local root = W.frame(parent, "EdgeGlow")
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 0
	local edges: { Frame } = {}
	local grads: { UIGradient } = {}
	local specs: { { pos: UDim2, size: UDim2, rot: number } } = {
		{ pos = UDim2.fromScale(0, 0), size = UDim2.fromScale(1, 0.22), rot = 90 },
		{ pos = UDim2.fromScale(0, 0.78), size = UDim2.fromScale(1, 0.22), rot = -90 },
		{ pos = UDim2.fromScale(0, 0), size = UDim2.fromScale(0.16, 1), rot = 0 },
		{ pos = UDim2.fromScale(0.84, 0), size = UDim2.fromScale(0.16, 1), rot = 180 },
	}
	for i, s in specs do
		local f = W.frame(root, "Edge" .. i, Color3.new(1, 1, 1), 0)
		f.Position = s.pos
		f.Size = s.size
		local g = Instance.new("UIGradient")
		g.Rotation = s.rot
		g.Parent = f
		table.insert(edges, f)
		table.insert(grads, g)
	end
	local function set(color: Color3, alpha: number)
		local a = math.clamp(alpha, 0, 1)
		root.Visible = a > 0.005
		for i, f in edges do
			f.BackgroundColor3 = color
			grads[i].Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1 - a),
				NumberSequenceKeypoint.new(1, 1),
			})
		end
	end
	set(Color3.new(1, 1, 1), 0)
	return { root = root, set = set }
end

------------------------------------------------------------------------
-- Shout: a big word that slams in, holds and fades (a 360, a natl, a big
-- chain), with a smaller line under it.
------------------------------------------------------------------------

export type ShoutSkin = {
	font: Font,
	color: Color3,
	stroke: Color3,
	strokeThickness: number,
	subFont: Font,
	subColor: Color3,
	tilt: number, -- degrees
}

export type Shout = { root: Frame, fire: (word: string, sub: string) -> (), update: (dt: number) -> () }

function W.shout(parent: Instance, name: string, skin: ShoutSkin): Shout
	local root = W.frame(parent, name)
	root.Visible = false
	root.Rotation = skin.tilt
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local word = W.text(root, "Word", "", skin.font, skin.color)
	word.Size = UDim2.fromScale(1, 0.7)
	local wordStroke = W.stroke(word, skin.stroke, skin.strokeThickness)
	local sub = W.text(root, "Sub", "", skin.subFont, skin.subColor)
	sub.Position = UDim2.fromScale(0, 0.7)
	sub.Size = UDim2.fromScale(1, 0.3)
	local subStroke = W.stroke(sub, skin.stroke, math.max(1, skin.strokeThickness - 1))
	local age = math.huge
	local pop = Motion.spring(1, 5, 0.45)
	local function fire(w: string, s: string)
		word.Text = w
		sub.Text = s
		age = 0
		pop.x, pop.v = 1.7, 0
		root.Visible = true
	end
	local function update(dt: number)
		if age == math.huge then
			return
		end
		age += dt
		scale.Scale = Motion.step(pop, 1, dt)
		local fade = math.clamp((age - 0.9) / 0.35, 0, 1)
		word.TextTransparency = fade
		sub.TextTransparency = fade
		wordStroke.Transparency = fade
		subStroke.Transparency = fade
		if fade >= 1 then
			root.Visible = false
			age = math.huge
		end
	end
	return { root = root, fire = fire, update = update }
end

return W
