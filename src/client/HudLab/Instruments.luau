--!strict
-- Instruments made of rendered art (hud-variants, 2026-10-07; the owner:
-- "need deep UI"). The HUD's tacho and readouts:
--
--   dial    a face, a needle on a spring that overshoots and settles, glass
--           over it; an optional peak needle that holds the highest reading
--   chars   a readout of characters cut from an atlas image, each over its
--           unlit ghost
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

return I
