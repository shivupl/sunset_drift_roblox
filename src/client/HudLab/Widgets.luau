--!strict
-- The pieces the HUD variants are made of (hud-variants, 2026-10-07):
-- touch controls that feel like the real thing (pedals that sink and give
-- part throttle by where the thumb sits, a handbrake lever you pull, a
-- steering wheel you turn, a slider and a thumb pad) and gauges that move
-- (a needle tacho with LED or tick arcs, a drift-angle scale, a chain bar,
-- an edge glow, shouted callouts).
--
-- Everything is sized from the screen's height (SizeConstraint RelativeYY)
-- and its text is TextScaled, so one layout fits a phone and a monitor.
-- Each variant passes a skin: colours, fonts and shapes; the behaviour is
-- shared, so all three drive the car the same way.
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

function W.gradient(o: GuiObject, from: Color3, to: Color3, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(from, to)
	g.Rotation = rotation or 90
	g.Parent = o
	return g
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
-- Pedal: a plate that sinks under the thumb. Where the thumb sits sets how
-- much: the top two thirds is all of it, the bottom down to `minValue`, so a
-- thumb sliding down the pedal feathers it (drifting wants part throttle).
------------------------------------------------------------------------

export type PedalSkin = {
	plate: Color3, -- top of the plate's gradient
	plateLow: Color3, -- bottom of it
	edge: Color3,
	edgeThickness: number,
	radius: UDim,
	slots: number, -- grip slots across the plate (0: none)
	slot: Color3,
	slotTransparency: number,
	label: string,
	labelFont: Font,
	labelColor: Color3,
	labelStroke: Color3?,
	shadow: Color3,
	shadowTransparency: number,
	depth: number, -- how far it sinks, fraction of its height
	fill: Color3?, -- the amount bar along its side, nil for none
	minValue: number,
	-- Rendered art instead of the drawn plate (Art.luau): its shading,
	-- slots and label are in the image; pressing darkens and sinks it.
	image: string?,
}

export type Pedal = {
	root: Frame,
	plate: GuiObject,
	update: (dt: number) -> (),
	value: () -> number,
}

function W.pedal(parent: Instance, name: string, skin: PedalSkin, t: Tracker, onValue: (number) -> ()): Pedal
	local root = W.frame(parent, name)
	local art = skin.image
	local plate: GuiObject
	local grad: UIGradient? = nil
	local artImage: ImageLabel? = nil
	if art then
		local img = W.image(root, "Plate", art)
		plate = img
		artImage = img
	else
		local shadow = W.frame(root, "Shadow", skin.shadow, skin.shadowTransparency)
		shadow.Size = UDim2.fromScale(1, 1)
		shadow.Position = UDim2.fromScale(0.04, skin.depth)
		W.corner(shadow, skin.radius)
		local f = W.frame(root, "Plate", Color3.new(1, 1, 1), 0)
		f.Size = UDim2.fromScale(1, 1)
		W.corner(f, skin.radius)
		grad = W.gradient(f, skin.plate, skin.plateLow, 90)
		W.stroke(f, skin.edge, skin.edgeThickness)
		plate = f
	end
	local scale = Instance.new("UIScale")
	scale.Parent = plate
	-- Grip slots: rounded bars across the plate, label in the middle gap.
	local n = if art then 0 else skin.slots
	for i = 1, n do
		local y = 0.12 + (i - 1) * (0.76 / math.max(n - 1, 1))
		if math.abs(y - 0.5) < 0.07 then
			continue -- the label sits here
		end
		local s = W.frame(plate, "Slot" .. i, skin.slot, skin.slotTransparency)
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Position = UDim2.fromScale(0.5, y)
		s.Size = UDim2.fromScale(0.62, 0.045)
		W.corner(s)
	end
	if not art and skin.label ~= "" then
		local label = W.text(plate, "Label", skin.label, skin.labelFont, skin.labelColor)
		W.at(label, 0.5, 0.5)
		label.Size = UDim2.fromScale(0.78, 0.13)
		if skin.labelStroke then
			W.stroke(label, skin.labelStroke, 2)
		end
	end
	local fillBar: Frame? = nil
	if skin.fill then
		local track = W.frame(root, "Amount", Color3.new(0, 0, 0), 0.6)
		track.AnchorPoint = Vector2.new(1, 1)
		track.Position = UDim2.new(0, -6, 1, 0)
		track.Size = UDim2.new(0, 5, 1, 0)
		W.corner(track)
		local f = W.frame(track, "Fill", skin.fill, 0)
		f.AnchorPoint = Vector2.new(0, 1)
		f.Position = UDim2.fromScale(0, 1)
		f.Size = UDim2.fromScale(1, 0)
		W.corner(f)
		fillBar = f
	end

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
		local g = grad
		if g then
			g.Offset = Vector2.new(0, -0.25 * d)
		end
		local img = artImage
		if img then
			-- Pressed down out of the light.
			img.ImageColor3 = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(150, 150, 156), d)
		end
		local fb = fillBar
		if fb then
			fb.Size = UDim2.fromScale(1, target)
		end
	end
	return { root = root, plate = plate, update = update, value = function()
		return target
	end }
end

------------------------------------------------------------------------
-- Lever: a handle in a slot. Pull it down: past `engageAt` of the travel the
-- handbrake is on. A tap puts it straight on; letting go springs it back.
------------------------------------------------------------------------

export type LeverSkin = {
	track: Color3,
	trackTransparency: number,
	trackEdge: Color3,
	handle: Color3,
	handleLow: Color3,
	handleEdge: Color3,
	grip: Color3,
	label: string,
	labelFont: Font,
	labelColor: Color3,
	engageAt: number,
	active: Color3, -- the slot's glow while it is on
	trackImage: string?, -- rendered art (Art.luau) for the slot plate...
	handleImage: string?, -- ...and the grip
}

export type Lever = { root: Frame, update: (dt: number) -> () }

function W.lever(parent: Instance, name: string, skin: LeverSkin, t: Tracker, onEngaged: (boolean) -> ()): Lever
	local root = W.frame(parent, name)
	local trackStroke: UIStroke? = nil
	local handle: GuiObject
	local handleImage: ImageLabel? = nil
	local trackArt, handleArt = skin.trackImage, skin.handleImage
	if trackArt and handleArt then
		W.image(root, "Track", trackArt)
		local h = W.image(root, "Handle", handleArt)
		h.AnchorPoint = Vector2.new(0.5, 0.5)
		h.Size = UDim2.fromScale(1.45, 0.4)
		h.ZIndex = 2
		handle = h
		handleImage = h
	else
		local track = W.frame(root, "Track", skin.track, skin.trackTransparency)
		W.at(track, 0.5, 0.5)
		track.Size = UDim2.fromScale(0.36, 1)
		W.corner(track)
		trackStroke = W.stroke(track, skin.trackEdge, 2)
		local f = W.frame(root, "Handle", Color3.new(1, 1, 1), 0)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.fromScale(1, 0.3)
		W.corner(f, UDim.new(0.3, 0))
		W.gradient(f, skin.handle, skin.handleLow, 90)
		W.stroke(f, skin.handleEdge, 2)
		for i = 1, 3 do
			local g = W.frame(f, "Grip" .. i, skin.grip, 0.2)
			g.AnchorPoint = Vector2.new(0.5, 0.5)
			g.Position = UDim2.fromScale(0.5, 0.22 + (i - 1) * 0.12)
			g.Size = UDim2.fromScale(0.6, 0.06)
			W.corner(g)
		end
		local label = W.text(f, "Label", skin.label, skin.labelFont, skin.labelColor)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.74)
		label.Size = UDim2.fromScale(0.86, 0.3)
		handle = f
	end

	local held = false
	local want = 0
	local pos = Motion.spring(0, 7, 0.5)
	local on = false
	local function set(frac: number)
		want = frac
		local now = frac >= skin.engageAt
		if now ~= on then
			on = now
			onEngaged(now)
		end
	end
	local grabY = 0
	local grabFrac = 0
	W.claim(t, root, function(p)
		held = true
		grabY = p.Y
		grabFrac = math.max(pos.x, skin.engageAt + 0.15)
		set(grabFrac)
	end, function(p)
		local travel = math.max(root.AbsoluteSize.Y * 0.7, 1)
		set(math.clamp(grabFrac + (p.Y - grabY) / travel, 0, 1))
	end, function()
		held = false
		set(0)
	end)

	local function update(dt: number)
		local x = Motion.step(pos, if held then want else 0, dt)
		handle.Position = UDim2.fromScale(0.5, 0.17 + 0.64 * math.clamp(x, 0, 1))
		local ts = trackStroke
		if ts then
			ts.Color = if on then skin.active else skin.trackEdge
			ts.Thickness = if on then 3 else 2
		end
		local hi = handleImage
		if hi then
			hi.ImageColor3 = if on then Color3.fromRGB(255, 226, 186) else Color3.new(1, 1, 1)
		end
	end
	return { root = root, update = update }
end

------------------------------------------------------------------------
-- Steering wheel: turn it with the thumb round its centre. The angle you
-- have turned it, over maxDeg, is the steer, through the same deadzone and
-- curve as the steer pad. Let go and it springs back to straight.
------------------------------------------------------------------------

export type WheelSkin = {
	rim: Color3,
	rimThickness: number, -- fraction of the wheel's size
	rimTransparency: number,
	spoke: Color3,
	hub: Color3,
	hubEdge: Color3,
	marker: Color3, -- the stripe at 12 o'clock
	maxDeg: number,
	image: string?, -- rendered art (Art.luau) instead of the drawn wheel
}

export type Wheel = { root: Frame, update: (dt: number) -> () }

function W.wheel(parent: Instance, name: string, skin: WheelSkin, t: Tracker, onSteer: (number) -> ()): Wheel
	local root = W.frame(parent, name)
	local spin = W.frame(root, "Spin")
	spin.Size = UDim2.fromScale(1, 1)
	local rimStroke: UIStroke? = nil
	local art = skin.image
	if art then
		W.image(spin, "Art", art)
	else
		local rim = W.frame(spin, "Rim")
		rim.Size = UDim2.fromScale(1, 1)
		W.corner(rim)
		rimStroke = W.stroke(rim, skin.rim, 8, skin.rimTransparency)
		local function spoke(rot: number, len: number)
			local holder = W.frame(spin, "Spoke")
			holder.Size = UDim2.fromScale(1, 1)
			holder.Rotation = rot
			local s = W.frame(holder, "Bar", skin.spoke, 0)
			s.AnchorPoint = Vector2.new(0.5, 1)
			s.Position = UDim2.fromScale(0.5, 0.5)
			s.Size = UDim2.fromScale(0.09, len)
			W.corner(s, UDim.new(0.4, 0))
		end
		spoke(90, 0.47)
		spoke(270, 0.47)
		spoke(180, 0.47)
		local hub = W.frame(spin, "Hub", skin.hub, 0)
		W.at(hub, 0.5, 0.5)
		hub.Size = UDim2.fromScale(0.3, 0.3)
		W.corner(hub)
		W.stroke(hub, skin.hubEdge, 2)
		local marker = W.frame(spin, "Marker", skin.marker, 0)
		marker.AnchorPoint = Vector2.new(0.5, 0)
		marker.Position = UDim2.fromScale(0.5, -0.02)
		marker.Size = UDim2.fromScale(0.06, 0.1)
		W.corner(marker, UDim.new(0.3, 0))
	end

	local turned = 0 -- degrees, + right
	local held = false
	local lastAngle = 0
	local back = Motion.spring(0, 5, 0.65)
	local function angleOf(p: Vector2): number
		local c = root.AbsolutePosition + root.AbsoluteSize / 2
		return math.deg(math.atan2(p.X - c.X, -(p.Y - c.Y)))
	end
	local function report()
		onSteer(math.clamp(turned / skin.maxDeg, -1, 1))
	end
	W.claim(t, root, function(p)
		held = true
		lastAngle = angleOf(p)
		turned = back.x
	end, function(p)
		local a = angleOf(p)
		local d = a - lastAngle
		if d > 180 then
			d -= 360
		elseif d < -180 then
			d += 360
		end
		lastAngle = a
		turned = math.clamp(turned + d, -skin.maxDeg, skin.maxDeg)
		report()
	end, function()
		held = false
		onSteer(0)
	end)

	local function update(dt: number)
		if held then
			back.x, back.v = turned, 0
		else
			turned = Motion.step(back, 0, dt)
		end
		spin.Rotation = turned
		local rs = rimStroke
		if rs then
			rs.Thickness = math.max(2, root.AbsoluteSize.X * skin.rimThickness)
		end
	end
	return { root = root, update = update }
end

------------------------------------------------------------------------
-- Slider: a track with a knob; the knob's offset from centre is -1..1.
-- Springs back to centre when let go.
------------------------------------------------------------------------

export type SliderSkin = {
	track: Color3,
	trackTransparency: number,
	edge: Color3,
	edgeThickness: number,
	knob: Color3,
	knobEdge: Color3,
	radius: UDim,
	marks: Color3?, -- the chevrons at each end
	markFont: Font?,
	left: string?,
	right: string?,
}

export type Slider = { root: Frame, update: (dt: number) -> () }

function W.slider(parent: Instance, name: string, skin: SliderSkin, t: Tracker, onMove: (number) -> ()): Slider
	local root = W.frame(parent, name, skin.track, skin.trackTransparency)
	W.corner(root, skin.radius)
	W.stroke(root, skin.edge, skin.edgeThickness)
	local marks = skin.marks
	if marks then
		local font = skin.markFont or W.font("BuilderSans", Enum.FontWeight.Bold)
		for i, ch in { skin.left or "‹", skin.right or "›" } do
			local m = W.text(root, "Mark" .. i, ch, font, marks)
			W.at(m, if i == 1 then 0.08 else 0.92, 0.5)
			m.Size = UDim2.fromScale(0.12, 0.6)
		end
	end
	local knob = W.frame(root, "Knob", skin.knob, 0)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.SizeConstraint = Enum.SizeConstraint.RelativeYY
	knob.Size = UDim2.fromScale(0.82, 0.82)
	W.corner(knob, skin.radius)
	W.stroke(knob, skin.knobEdge, 2)
	local frac = 0
	local held = false
	local pos = Motion.spring(0, 8, 0.7)
	local function fromX(x: number)
		local half = root.AbsoluteSize.X / 2
		local c = root.AbsolutePosition.X + half
		frac = math.clamp((x - c) / math.max(half * 0.84, 1), -1, 1)
		onMove(frac)
	end
	W.claim(t, root, function(p)
		held = true
		fromX(p.X)
	end, function(p)
		fromX(p.X)
	end, function()
		held = false
		frac = 0
		onMove(0)
	end)
	local function update(dt: number)
		local x = Motion.step(pos, if held then frac else 0, dt)
		knob.Position = UDim2.fromScale(0.5 + 0.42 * x, 0.5)
	end
	return { root = root, update = update }
end

------------------------------------------------------------------------
-- Thumb pad: a disc whose knob follows the thumb across it, sideways only.
------------------------------------------------------------------------

export type PadSkin = {
	base: Color3,
	baseTransparency: number,
	edge: Color3,
	edgeThickness: number,
	knob: Color3,
	knobLow: Color3,
	knobEdge: Color3,
	arrows: Color3,
	arrowFont: Font,
}

function W.pad(parent: Instance, name: string, skin: PadSkin, t: Tracker, onMove: (number) -> ()): Slider
	local root = W.frame(parent, name, skin.base, skin.baseTransparency)
	W.corner(root)
	W.stroke(root, skin.edge, skin.edgeThickness)
	for i, ch in { "◀", "▶" } do
		local a = W.text(root, "Arrow" .. i, ch, skin.arrowFont, skin.arrows)
		W.at(a, if i == 1 then 0.14 else 0.86, 0.5)
		a.Size = UDim2.fromScale(0.16, 0.2)
	end
	local knob = W.frame(root, "Knob", Color3.new(1, 1, 1), 0)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromScale(0.46, 0.46)
	W.corner(knob)
	W.gradient(knob, skin.knob, skin.knobLow, 90)
	W.stroke(knob, skin.knobEdge, 3)
	local frac = 0
	local held = false
	local pos = Motion.spring(0, 9, 0.6)
	local function fromX(x: number)
		local half = root.AbsoluteSize.X / 2
		local c = root.AbsolutePosition.X + half
		frac = math.clamp((x - c) / math.max(half * 0.7, 1), -1, 1)
		onMove(frac)
	end
	W.claim(t, root, function(p)
		held = true
		fromX(p.X)
	end, function(p)
		fromX(p.X)
	end, function()
		held = false
		frac = 0
		onMove(0)
	end)
	local function update(dt: number)
		local x = Motion.step(pos, if held then frac else 0, dt)
		knob.Position = UDim2.fromScale(0.5 + 0.3 * x, 0.5)
	end
	return { root = root, update = update }
end

------------------------------------------------------------------------
-- A tappable button (NATL, RESET, EXIT, STYLE): pops when pressed; `lit`
-- shows a toggle's state.
------------------------------------------------------------------------

export type ButtonSkin = {
	fill: Color3,
	fillTransparency: number,
	lit: Color3,
	edge: Color3,
	edgeThickness: number,
	radius: UDim,
	font: Font,
	text: Color3,
	litText: Color3,
	textStroke: Color3?,
	image: string?, -- rendered art (Art.luau) behind the label...
	litImage: string?, -- ...swapped in while lit
	slice: Rect?, -- 9-slice centre of the image, for a pill that stretches
	sliceHeight: number?, -- the image's height in px, so its corners scale with the button
}

export type Button = { root: Frame, setLit: (boolean) -> (), update: (dt: number) -> () }

function W.button(parent: Instance, name: string, label: string, skin: ButtonSkin, t: Tracker, onTap: () -> ()): Button
	local art = skin.image
	local root = if art then W.frame(parent, name) else W.frame(parent, name, skin.fill, skin.fillTransparency)
	local bg: ImageLabel? = nil
	if art then
		local img = W.image(root, "Art", art)
		local slice = skin.slice
		if slice then
			img.ScaleType = Enum.ScaleType.Slice
			img.SliceCenter = slice
			img.SliceScale = 0.5
		end
		bg = img
	else
		W.corner(root, skin.radius)
		W.stroke(root, skin.edge, skin.edgeThickness)
	end
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local txt = W.text(root, "Label", label, skin.font, skin.text)
	W.at(txt, 0.5, 0.5)
	txt.Size = UDim2.fromScale(0.72, 0.4)
	txt.Visible = label ~= ""
	txt.ZIndex = 2
	if skin.textStroke then
		W.stroke(txt, skin.textStroke, 2)
	end
	local pop = Motion.spring(1, 6, 0.4)
	W.claim(t, root, function()
		Motion.kick(pop, -5)
		onTap()
	end, nil, function() end)
	local function setLit(on: boolean)
		local img = bg
		if img then
			img.Image = if on and skin.litImage then skin.litImage else art or ""
		else
			root.BackgroundColor3 = if on then skin.lit else skin.fill
			root.BackgroundTransparency = if on then 0 else skin.fillTransparency
		end
		txt.TextColor3 = if on then skin.litText else skin.text
	end
	local function update(dt: number)
		scale.Scale = Motion.step(pop, 1, dt)
		local img = bg
		local h = skin.sliceHeight
		if img and h then
			img.SliceScale = math.max(root.AbsoluteSize.Y, 1) / h
		end
	end
	return { root = root, setLit = setLit, update = update }
end

------------------------------------------------------------------------
-- Tacho: ticks round an arc (or LED segments), numerals, a redline, and a
-- needle on a spring that swings past and settles like a real one.
------------------------------------------------------------------------

export type TachoSkin = {
	fromDeg: number, -- the arc's start, 0 = straight up, negative = left
	toDeg: number,
	majors: number, -- numbered ticks, 0..majors (x1000 rpm)
	minors: number, -- ticks between two majors
	tick: Color3,
	red: Color3,
	tickWidth: number, -- px
	majorLen: number, -- fraction of the gauge's size
	minorLen: number,
	radius: number, -- the ticks' outer radius, fraction of the size
	numerals: Font?,
	numeralColor: Color3,
	needle: Color3,
	needleWidth: number, -- px
	needleLen: number,
	hub: Color3,
	leds: number?, -- LED segments instead of the needle (Arcade)
	ledOn: Color3?,
	ledOff: Color3?,
	ledRed: Color3?,
}

export type Tacho = { root: Frame, set: (rpm: number, redline: number) -> (), update: (dt: number) -> () }

function W.tacho(parent: Instance, name: string, skin: TachoSkin): Tacho
	local root = W.frame(parent, name)
	local span = skin.toDeg - skin.fromDeg
	local function polar(deg: number, r: number): UDim2
		local a = math.rad(deg)
		return UDim2.fromScale(0.5 + r * math.sin(a), 0.5 - r * math.cos(a))
	end
	local ticks: { { f: Frame, rpm: number } } = {}
	local leds: { { f: Frame, frac: number } } = {}
	local ledCount = skin.leds
	if ledCount then
		for i = 1, ledCount do
			local frac = (i - 0.5) / ledCount
			local deg = skin.fromDeg + span * frac
			local holder = W.frame(root, "Led" .. i)
			holder.Size = UDim2.fromScale(1, 1)
			holder.Rotation = deg
			local seg = W.frame(holder, "Seg", skin.ledOff, 0)
			seg.AnchorPoint = Vector2.new(0.5, 0)
			seg.Position = UDim2.fromScale(0.5, 0.5 - skin.radius)
			seg.Size = UDim2.fromScale(math.max(0.012, 2.6 / ledCount * skin.radius), skin.majorLen)
			W.corner(seg, UDim.new(0.3, 0))
			table.insert(leds, { f = seg, frac = frac })
		end
	else
		local n = skin.majors * skin.minors
		for i = 0, n do
			local major = i % skin.minors == 0
			local frac = i / n
			local deg = skin.fromDeg + span * frac
			local holder = W.frame(root, "Tick" .. i)
			holder.Size = UDim2.fromScale(1, 1)
			holder.Rotation = deg
			local len = if major then skin.majorLen else skin.minorLen
			local tk = W.frame(holder, "T", skin.tick, 0)
			tk.AnchorPoint = Vector2.new(0.5, 0)
			tk.Position = UDim2.fromScale(0.5, 0.5 - skin.radius)
			tk.Size = UDim2.new(0, if major then skin.tickWidth + 1 else skin.tickWidth, len, 0)
			table.insert(ticks, { f = tk, rpm = frac * skin.majors * 1000 })
			local font = skin.numerals
			if major and font then
				local num = W.text(root, "N" .. i, tostring(i // skin.minors), font, skin.numeralColor)
				num.AnchorPoint = Vector2.new(0.5, 0.5)
				num.Position = polar(deg, skin.radius - skin.majorLen - 0.07)
				num.Size = UDim2.fromScale(0.11, 0.11)
			end
		end
	end
	local needle: Frame? = nil
	if not ledCount then
		local holder = W.frame(root, "Needle")
		holder.Size = UDim2.fromScale(1, 1)
		local bar = W.frame(holder, "Bar", skin.needle, 0)
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.new(0, skin.needleWidth, skin.needleLen, 0)
		W.corner(bar)
		local hub = W.frame(root, "Hub", skin.hub, 0)
		W.at(hub, 0.5, 0.5)
		hub.Size = UDim2.fromScale(0.07, 0.07)
		W.corner(hub)
		needle = holder
	end

	local rpm = 0
	local red = 7000
	local spring = Motion.spring(0, 4.2, 0.55)
	local function set(r: number, redline: number)
		rpm = r
		if redline ~= red then
			red = redline
			for _, tk in ticks do
				tk.f.BackgroundColor3 = if tk.rpm >= redline then skin.red else skin.tick
			end
		end
	end
	local function update(dt: number)
		local maxRpm = skin.majors * 1000
		local frac = Motion.step(spring, math.clamp(rpm / maxRpm, 0, 1.03), dt)
		-- On the limiter the needle trembles.
		local jitter = if rpm >= red - 150 then (math.random() - 0.5) * 2.5 else 0
		local n = needle
		if n then
			n.Rotation = skin.fromDeg + span * frac + jitter
		end
		for _, led in leds do
			local lit = led.frac <= frac
			local isRed = led.frac * maxRpm >= red
			led.f.BackgroundColor3 = if not lit
				then skin.ledOff or skin.tick
				elseif isRed then skin.ledRed or skin.red
				else skin.ledOn or skin.tick
		end
	end
	return { root = root, set = set, update = update }
end

-- A tacho drawn as art: the dial face and a needle image, both squares
-- with the needle's pivot at the centre, turned from fromDeg (0 rpm) to
-- toDeg (maxRpm) as the face was drawn (art/hud/pro/make_tacho.py).
function W.tachoImage(parent: Instance, name: string, face: string, needleArt: string, fromDeg: number, toDeg: number, maxRpm: number): Tacho
	local root = W.frame(parent, name)
	W.image(root, "Face", face)
	local needle = W.image(root, "Needle", needleArt)
	needle.ZIndex = 3
	local rpm = 0
	local red = maxRpm
	local spring = Motion.spring(0, 4.2, 0.55)
	local function set(r: number, redline: number)
		rpm = r
		red = redline
	end
	local function update(dt: number)
		local frac = Motion.step(spring, math.clamp(rpm / maxRpm, 0, 1.03), dt)
		local jitter = if rpm >= red - 150 then (math.random() - 0.5) * 2.5 else 0
		needle.Rotation = fromDeg + (toDeg - fromDeg) * frac + jitter
	end
	return { root = root, set = set, update = update }
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
