--!strict
-- Instruments made of rendered art (hud-variants, 2026-10-07; the owner, on
-- picking the ARCADE layout: "make a few more varients arcade layout but with
-- the actual odometer and stuff... need deep UI"). The cluster variants
-- (KRUZER, STREET, KABRIS) build their gauges from these:
--
--   dial    a face, a needle on a spring that overshoots and settles, glass
--           over it; an optional peak needle that holds the highest reading
--   chars   a readout of characters cut from an atlas image (an LCD's seven
--           segments, a dot matrix), each over its unlit ghost
--   drums   an odometer's drums: each digit a strip of 0..9,0 that rolls,
--           the next drum turning only as the one below passes 9
--   lamp    a telltale over the face's dim print: off, on or blinking
--   slide   an image that slides along a line on a spring (a sweep
--           speedometer's needle, a gear pointer)
--
-- Positions inside a dial are given in the art's own pixels (`base`, the
-- image's size), so the HUD and art/hud/<variant>/make.py share numbers.
local Motion = require(script.Parent:WaitForChild("Motion"))

local I = {}

local function layer(parent: Instance, name: string, image: string, z: number): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.BackgroundTransparency = 1
	i.BorderSizePixel = 0
	i.Image = image
	i.ScaleType = Enum.ScaleType.Stretch
	i.Size = UDim2.fromScale(1, 1)
	i.ZIndex = z
	i.Parent = parent
	return i
end
I.layer = layer

-- Places o by its centre at (x, y), w x h, all in the parent art's pixels.
function I.place(o: GuiObject, base: number, x: number, y: number, w: number, h: number)
	o.AnchorPoint = Vector2.new(0.5, 0.5)
	o.Position = UDim2.fromScale(x / base, y / base)
	o.Size = UDim2.fromScale(w / base, h / base)
end

-- The same by the top left corner.
function I.placeTL(o: GuiObject, base: number, x: number, y: number, w: number, h: number)
	o.AnchorPoint = Vector2.new(0, 0)
	o.Position = UDim2.fromScale(x / base, y / base)
	o.Size = UDim2.fromScale(w / base, h / base)
end

------------------------------------------------------------------------
-- Dial
------------------------------------------------------------------------

export type DialSpec = {
	face: string,
	needle: string,
	glass: string?,
	fromDeg: number, -- the needle's angle at `min` (0 up, clockwise)
	toDeg: number, -- at `max`
	min: number?,
	max: number,
	freq: number?, -- the needle's spring, Hz
	damp: number?,
	jitterAbove: number?, -- trembles at and above this value (a limiter)
	peak: string?, -- a second needle that holds the highest reading
	peakHold: number?, -- seconds it holds before it falls back
	shadow: string?, -- the needle's shadow: turns with it, offset down-right
	shadowOffset: Vector2?, -- fraction of the dial's size
}

export type Dial = {
	root: Frame,
	face: ImageLabel,
	needle: ImageLabel,
	-- Where to put readouts and lamps: between the face and the needle.
	under: Frame,
	set: (value: number) -> (),
	update: (dt: number) -> (),
}

function I.dial(parent: Instance, name: string, spec: DialSpec): Dial
	local root = Instance.new("Frame")
	root.Name = name
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Parent = parent
	local face = layer(root, "Face", spec.face, 1)
	local under = Instance.new("Frame")
	under.Name = "Under"
	under.BackgroundTransparency = 1
	under.Size = UDim2.fromScale(1, 1)
	under.ZIndex = 2
	under.Parent = root
	local shadowImg: ImageLabel? = nil
	local shadowArt = spec.shadow
	if shadowArt then
		local sh = layer(root, "Shadow", shadowArt, 3)
		local off = spec.shadowOffset or Vector2.new(0.008, 0.014)
		sh.Position = UDim2.fromScale(off.X, off.Y)
		shadowImg = sh
	end
	local peakImg: ImageLabel? = nil
	local peakArt = spec.peak
	if peakArt then
		peakImg = layer(root, "Peak", peakArt, 3)
	end
	local needle = layer(root, "Needle", spec.needle, 4)
	local glassArt = spec.glass
	if glassArt then
		layer(root, "Glass", glassArt, 5)
	end
	local lo = spec.min or 0
	local span = spec.max - lo
	local value = lo
	local spring = Motion.spring(0, spec.freq or 4.2, spec.damp or 0.55)
	local peak = 0
	local peakAge = 0
	local function angleOf(frac: number): number
		return spec.fromDeg + (spec.toDeg - spec.fromDeg) * frac
	end
	local function set(v: number)
		value = v
	end
	local function update(dt: number)
		local want = math.clamp((value - lo) / span, -0.02, 1.03)
		local frac = Motion.step(spring, want, dt)
		local jit = spec.jitterAbove
		local jitter = if jit and value >= jit then (math.random() - 0.5) * 2.5 else 0
		needle.Rotation = angleOf(frac) + jitter
		local sh = shadowImg
		if sh then
			sh.Rotation = needle.Rotation
		end
		local p = peakImg
		if p then
			if frac >= peak then
				peak, peakAge = frac, 0
			else
				peakAge += dt
				if peakAge > (spec.peakHold or 1.6) then
					-- Falls back like a released tell-tale needle.
					peak = math.max(frac, peak - dt * 0.6)
				end
			end
			p.Rotation = angleOf(peak)
		end
	end
	return { root = root, face = face, needle = needle, under = under, set = set, update = update }
end

------------------------------------------------------------------------
-- Character readouts
------------------------------------------------------------------------

export type CharsSpec = {
	atlas: string,
	order: string, -- the characters in the atlas's cell order; "#" is the ghost
	cell: Vector2, -- one cell, px
	cols: number,
	count: number,
	align: string?, -- "right" (default) or "left"
	tint: Color3?,
}

export type Chars = { root: Frame, set: (text: string) -> (), tint: (c: Color3) -> () }

local function codes(s: string): { string }
	local out = {}
	for _, cp in utf8.codes(s) do
		table.insert(out, utf8.char(cp))
	end
	return out
end

function I.chars(parent: Instance, name: string, spec: CharsSpec): Chars
	local root = Instance.new("Frame")
	root.Name = name
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Parent = parent
	local index: { [string]: number } = {}
	for i, ch in codes(spec.order) do
		index[ch] = i - 1
	end
	local function rect(img: ImageLabel, i: number)
		img.ImageRectOffset = Vector2.new((i % spec.cols) * spec.cell.X, (i // spec.cols) * spec.cell.Y)
		img.ImageRectSize = spec.cell
	end
	local slots: { ImageLabel } = {}
	local ghost = index["#"]
	for i = 1, spec.count do
		local x = (i - 1) / spec.count
		if ghost then
			local g = layer(root, "Ghost" .. i, spec.atlas, 1)
			g.Position = UDim2.fromScale(x, 0)
			g.Size = UDim2.fromScale(1 / spec.count, 1)
			rect(g, ghost)
		end
		local img = layer(root, "C" .. i, spec.atlas, 2)
		img.Position = UDim2.fromScale(x, 0)
		img.Size = UDim2.fromScale(1 / spec.count, 1)
		img.Visible = false
		if spec.tint then
			img.ImageColor3 = spec.tint
		end
		table.insert(slots, img)
	end
	local shown = ""
	local function set(text: string)
		if text == shown then
			return
		end
		shown = text
		local cs = codes(text)
		local pad = if spec.align == "left" then 0 else math.max(spec.count - #cs, 0)
		for i, img in slots do
			local ch = cs[i - pad]
			local idx = if ch then index[ch] else nil
			if idx and ch ~= " " then
				rect(img, idx)
				img.Visible = true
			else
				img.Visible = false
			end
		end
	end
	local function tint(c: Color3)
		for _, img in slots do
			img.ImageColor3 = c
		end
	end
	return { root = root, set = set, tint = tint }
end

------------------------------------------------------------------------
-- Odometer drums
------------------------------------------------------------------------

export type DrumsSpec = {
	strip: string, -- digits 0..9,0 down one image, one drum window each
	shade: string?, -- the drums' curve, over each window
	count: number,
	gap: number?, -- between drums, fraction of a drum's width
	lastStrip: string?, -- a different strip for the last drum (tenths)
}

export type Drums = { root: Frame, set: (value: number) -> (), update: (dt: number) -> () }

function I.drums(parent: Instance, name: string, spec: DrumsSpec): Drums
	local root = Instance.new("Frame")
	root.Name = name
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Parent = parent
	local gap = spec.gap or 0.08
	local w = 1 / (spec.count + gap * (spec.count - 1))
	local strips: { ImageLabel } = {}
	for i = 1, spec.count do
		local win = Instance.new("Frame")
		win.Name = "Drum" .. i
		win.BackgroundColor3 = Color3.new(0, 0, 0)
		win.BorderSizePixel = 0
		win.ClipsDescendants = true
		win.Position = UDim2.fromScale((i - 1) * w * (1 + gap), 0)
		win.Size = UDim2.fromScale(w, 1)
		win.Parent = root
		local art = if i == spec.count and spec.lastStrip then spec.lastStrip else spec.strip
		local strip = layer(win, "Strip", art, 1)
		strip.Size = UDim2.fromScale(1, 11)
		table.insert(strips, strip)
		local shade = spec.shade
		if shade then
			layer(win, "Shade", shade, 2)
		end
	end
	local target = 0
	local shown = 0
	local function set(v: number)
		target = math.max(v, 0)
	end
	local function update(dt: number)
		-- The drums never jump: they chase the reading (a new car's mileage
		-- winds on in a moment).
		shown += (target - shown) * (1 - math.exp(-12 * dt))
		if math.abs(target - shown) > 1e5 then
			shown = target
		end
		local x = shown % (10 ^ spec.count)
		for i, strip in strips do
			local p = spec.count - i -- 0 for the last drum
			local unit = 10 ^ p
			local pos: number
			if p == 0 then
				pos = x % 10
			else
				local digit = math.floor(x / unit) % 10
				-- Turns only while every drum below passes from 9 to 0.
				local below = x % unit
				local carry = math.clamp(below - (unit - 1), 0, 1)
				pos = digit + carry
			end
			strip.Position = UDim2.fromScale(0, -pos)
		end
	end
	return { root = root, set = set, update = update }
end

------------------------------------------------------------------------
-- Telltale lamp
------------------------------------------------------------------------

export type Lamp = { root: ImageLabel, set: (state: string) -> (), update: (dt: number) -> () }

-- state: "off", "on", or "blink" (2.5 Hz, as a hazard flasher).
function I.lamp(parent: Instance, name: string, image: string): Lamp
	local img = layer(parent, name, image, 2)
	img.Visible = false
	local state = "off"
	local t = 0
	local function set(s: string)
		if s ~= state then
			state = s
			t = 0
		end
	end
	local function update(dt: number)
		t += dt
		if state == "on" then
			img.Visible = true
		elseif state == "blink" then
			img.Visible = (t * 2.5) % 1 < 0.55
		else
			img.Visible = false
		end
	end
	return { root = img, set = set, update = update }
end

------------------------------------------------------------------------
-- Slide: an image along a line (a sweep speedometer's needle, a pointer)
------------------------------------------------------------------------

export type Slide = { root: GuiObject, set: (frac: number) -> (), update: (dt: number) -> () }

-- o moves from x0 to x1 (fractions of its parent's width) at frac 0..1.
function I.slide(o: GuiObject, x0: number, x1: number, freq: number?, damp: number?): Slide
	local spring = Motion.spring(0, freq or 4, damp or 0.6)
	local want = 0
	local y = o.Position.Y
	local function set(f: number)
		want = f
	end
	local function update(dt: number)
		local f = Motion.step(spring, want, dt)
		o.Position = UDim2.new(x0 + (x1 - x0) * f, 0, y.Scale, y.Offset)
	end
	return { root = o, set = set, update = update }
end

return I
