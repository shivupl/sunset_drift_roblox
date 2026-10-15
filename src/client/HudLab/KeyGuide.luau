--!strict
-- The desktop's key guide (desktop-ui, 2026-10-14; the owner: "put a small
-- guide on which keys are for what"): the driving keys with a word each,
-- bottom left, in the form the desk layout asks for (Desk.guide). A key
-- lights sodium while it is held, so the guide also shows what the car is
-- being told. The keys that sit on the top row's tabs (M, F, V, U) are not
-- repeated here.
--
-- The owner, of the first cut (a line of dark keycaps on a blot): "the
-- controls on the bottom should be faint and lighter opacity and more
-- simple". So the guide is faint: no blot, white a quarter to a half
-- there, in one of three forms (the canvas "Hajwala desktop HUD", the
-- A1–A3 boards):
--
--   ghost   outlined keycaps, nothing behind them (DASH)
--   thin    the letters alone, no keycaps (DASH THIN)
--   fade    the outlined keycaps on a fade up from the screen's bottom
--           edge, under the dial too (DASH FADE)
--
-- Pixel sizes, a desktop's: the keycap 22 tall, its letter 11, the word
-- 12; 4 between keycaps, 6 before the word, 24 between pairs. The keycap
-- is also the top row's (TopBar draws a tab's key with KeyGuide.cap, in
-- the `tab` tones), so one keycap means one thing everywhere. The letter
-- is centred in a cap sized to it (the owner, of the tabs' keys: "off
-- center and too dark"; the letter was drawn in a box of its own width
-- set at the cap's left, so F sat 3 px left of centre).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Client = script.Parent.Parent
local Kit = require(Client:WaitForChild("CarPicker"):WaitForChild("Kit"))

local KeyGuide = {}

-- The keycap: never narrower than it is tall.
local CAP_H = 22
local CAP_PAD = 5
local CAP_FONT = 11
local CAP_RADIUS = 4
-- THIN's letters, a size up: a bare cap this tall carries a 12 px letter.
local THIN_H = 24

local WHITE = Color3.new(1, 1, 1)
local SODIUM = Color3.fromHex("#FFBA5C")

-- A keycap's colours: the face (its fill), the edge (a 1 px stroke) and
-- the ink (the letter), each with how see-through it is.
export type Tone = { face: Color3, faceAlpha: number, edge: Color3, edgeAlpha: number, ink: Color3, inkAlpha: number }

KeyGuide.TONES = {
	-- A tab's key: a light face on the dark glass, the letter white.
	tab = { face = WHITE, faceAlpha = 0.84, edge = WHITE, edgeAlpha = 0.66, ink = WHITE, inkAlpha = 0 } :: Tone,
	-- GARAGE's key while its word is green: the key in the green too.
	tabGreen = { face = Kit.C.green, faceAlpha = 0.86, edge = Kit.C.green, edgeAlpha = 0.45, ink = Kit.C.green, inkAlpha = 0 } :: Tone,
	-- A tab's key on the lit (solid green) tab: the dark ink its word takes.
	tabOn = { face = Kit.C.inUseInk, faceAlpha = 0.84, edge = Kit.C.inUseInk, edgeAlpha = 0.6, ink = Kit.C.inUseInk, inkAlpha = 0 } :: Tone,
	-- The guide's: an outline, a whisper of a face, the letter three
	-- quarters there.
	ghost = { face = WHITE, faceAlpha = 0.94, edge = WHITE, edgeAlpha = 0.66, ink = WHITE, inkAlpha = 0.28 } :: Tone,
	-- No cap at all, the letter alone.
	bare = { face = WHITE, faceAlpha = 1, edge = WHITE, edgeAlpha = 1, ink = WHITE, inkAlpha = 0.28 } :: Tone,
	-- Held: sodium, the lamp's lens for an edge, the ink dark.
	lit = { face = SODIUM, faceAlpha = 0, edge = Color3.fromHex("#FFD592"), edgeAlpha = 0, ink = Color3.fromHex("#2B1903"), inkAlpha = 0 } :: Tone,
	-- Held with no cap: the letter itself goes sodium.
	litBare = { face = SODIUM, faceAlpha = 1, edge = SODIUM, edgeAlpha = 1, ink = SODIUM, inkAlpha = 0 } :: Tone,
}

-- The word after the keys: white, half there.
local WORD_FONT = 12
local WORD_ALPHA = 0.5
local THIN_WORD_ALPHA = 0.55
local KEY_GAP = 4
local THIN_KEY_GAP = 3
local WORD_GAP = 6
local THIN_WORD_GAP = 8
local PAIR_GAP = 24
local THIN_PAIR_GAP = 28
-- In from the screen's bottom left corner.
local EDGE_X, EDGE_Y = 24, 28
-- FADE: black fading up from the screen's bottom edge, 130 tall, 0.58
-- there at the edge.
local FADE_H = 130
local FADE_ALPHA = 0.42

type Pair = { keys: { Enum.KeyCode }, caps: { string }, word: string }
local PAIRS: { Pair } = {
	{ keys = { Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D }, caps = { "W", "A", "S", "D" }, word = "DRIVE" },
	{ keys = { Enum.KeyCode.Space }, caps = { "SPACE" }, word = "HAND" },
	{ keys = { Enum.KeyCode.Q, Enum.KeyCode.E }, caps = { "Q", "E" }, word = "NATL" },
	{ keys = { Enum.KeyCode.R }, caps = { "R" }, word = "RESET" },
	{ keys = { Enum.KeyCode.H }, caps = { "H" }, word = "HORN" },
	{ keys = { Enum.KeyCode.G }, caps = { "G" }, word = "LIGHTS" },
}

local function fontFor(size: number): number
	return math.max(8, math.floor(size * CAP_FONT / CAP_H + 0.5))
end

-- Measures a letter as the caps draw it: a hidden label in the PlayerGui
-- (TextBounds needs the label in a screen).
local scratch: TextLabel? = nil
local function scratchLabel(): TextLabel
	local t = scratch
	if t then
		return t
	end
	local g = Instance.new("ScreenGui")
	g.Name = "HajwalaKeyScratch"
	g.ResetOnSpawn = false
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local l = Kit.text(g, "Scratch", "", CAP_FONT, Enum.FontWeight.ExtraBold, false)
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Visible = false
	scratch = l
	return l
end
local function measure(letter: string, font: number): number
	local t = scratchLabel()
	t.TextSize = font
	t.Text = letter
	local w = t.TextBounds.X
	return if w > 0 then w else #letter * font * 0.75
end

-- What a keycap measures: its letter and padding, never narrower than it
-- is tall; a bare one the letter alone.
function KeyGuide.width(letter: string, h: number?, bare: boolean?): number
	local size = h or CAP_H
	local w = measure(letter, fontFor(size))
	if bare then
		return math.ceil(w)
	end
	local pad = math.floor(size * CAP_PAD / CAP_H + 0.5)
	return math.max(size, math.ceil(w + 2 * pad))
end

export type Cap = {
	root: Frame,
	setTone: (tone: Tone, fade: number?) -> (), -- the cap's own colours; `fade` washes them out that much more (a shaded tab)
	setLit: (on: boolean) -> (),
}

export type CapOpts = {
	h: number?, -- the guide's 22; a tab's is sized to the tab
	tone: Tone?, -- ghost unless said
	lit: Tone?, -- lit (litBare if bare) unless said
	bare: boolean?, -- no face, no edge, no padding: the letter alone
}

-- A keycap with `letter` on it, centred.
function KeyGuide.cap(parent: Instance, letter: string, opts: CapOpts?): Cap
	local o: CapOpts = opts or {}
	local size = o.h or CAP_H
	local bare = o.bare == true
	local base: Tone = o.tone or (if bare then KeyGuide.TONES.bare else KeyGuide.TONES.ghost)
	local litTone: Tone = o.lit or (if bare then KeyGuide.TONES.litBare else KeyGuide.TONES.lit)
	local baseFade = 0
	local root = Kit.frame(parent, "Key_" .. letter, base.face, base.faceAlpha)
	root.Size = UDim2.fromOffset(KeyGuide.width(letter, size, bare), size)
	local edge: UIStroke? = nil
	if not bare then
		Kit.corner(root, CAP_RADIUS)
		edge = Kit.stroke(root, base.edge, 1, base.edgeAlpha)
	end
	local t = Kit.text(root, "Letter", letter, fontFor(size), Enum.FontWeight.ExtraBold, false, base.ink)
	t.Size = UDim2.fromScale(1, 1)
	t.TextXAlignment = Enum.TextXAlignment.Center
	t.TextTruncate = Enum.TextTruncate.None
	t.TextTransparency = base.inkAlpha
	t.ZIndex = root.ZIndex + 1
	local function apply(tone: Tone, fade: number)
		local function washed(alpha: number): number
			return 1 - (1 - alpha) * (1 - fade)
		end
		root.BackgroundColor3 = tone.face
		root.BackgroundTransparency = washed(tone.faceAlpha)
		local e = edge
		if e then
			e.Color = tone.edge
			e.Transparency = washed(tone.edgeAlpha)
		end
		t.TextColor3 = tone.ink
		t.TextTransparency = washed(tone.inkAlpha)
	end
	local lit = false
	return {
		root = root,
		setTone = function(tone: Tone, fade: number?)
			base = tone
			baseFade = fade or 0
			if not lit then
				apply(base, baseFade)
			end
		end,
		setLit = function(on: boolean)
			if on == lit then
				return
			end
			lit = on
			if on then
				apply(litTone, 0)
			else
				apply(base, baseFade)
			end
		end,
	}
end

export type Guide = {
	root: Frame,
	update: (dt: number) -> (),
	destroy: () -> (),
}

type Lit = { keys: { Enum.KeyCode }, caps: { Cap } }

-- One pair: its keys in a row and the word after them.
local function pair(parent: Instance, p: Pair, order: number, thin: boolean, out: { Lit })
	local row = Kit.frame(parent, "Pair_" .. p.word)
	row.LayoutOrder = order
	row.AutomaticSize = Enum.AutomaticSize.XY
	Kit.list(row, false, if thin then THIN_KEY_GAP else KEY_GAP, Enum.VerticalAlignment.Center)
	local caps: { Cap } = {}
	for i, letter in p.caps do
		local c = KeyGuide.cap(row, letter, if thin then { h = THIN_H, bare = true } else nil)
		c.root.LayoutOrder = i
		table.insert(caps, c)
	end
	local w = Kit.text(row, "Word", p.word, WORD_FONT, Enum.FontWeight.SemiBold, false, WHITE)
	w.LayoutOrder = 10
	w.AutomaticSize = Enum.AutomaticSize.X
	w.Size = UDim2.fromOffset(0, CAP_H)
	w.TextTruncate = Enum.TextTruncate.None
	w.TextTransparency = if thin then THIN_WORD_ALPHA else WORD_ALPHA
	Kit.pad(w, 0, 0, 0, if thin then THIN_WORD_GAP else WORD_GAP)
	table.insert(out, { keys = p.keys, caps = caps })
end

-- The guide in `form` ("ghost", "thin" or "fade"), in the HUD's root (the
-- screen), bottom left.
function KeyGuide.build(parent: Instance, form: string): Guide
	local lit: { Lit } = {}
	local thin = form == "thin"
	local fade: Frame? = nil
	if form == "fade" then
		local f = Kit.frame(parent, "KeyFade", Color3.new(0, 0, 0), 0)
		f.AnchorPoint = Vector2.new(0, 1)
		f.Position = UDim2.fromScale(0, 1)
		f.Size = UDim2.new(1, 0, 0, FADE_H)
		f.ZIndex = 0 -- under the dial and everything else in the HUD
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, FADE_ALPHA) })
		g.Parent = f
		fade = f
	end
	local root = Kit.frame(parent, "KeyGuide")
	root.AnchorPoint = Vector2.new(0, 1)
	root.AutomaticSize = Enum.AutomaticSize.XY
	root.Position = UDim2.new(0, EDGE_X, 1, -EDGE_Y)
	root.ZIndex = 3
	Kit.list(root, false, if thin then THIN_PAIR_GAP else PAIR_GAP, Enum.VerticalAlignment.Center)
	for i, p in PAIRS do
		pair(root, p, i, thin, lit)
	end
	-- Every zindex above the HUD's glow and shade.
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = math.max(d.ZIndex, 3)
		end
	end
	return {
		root = root,
		update = function(_dt: number)
			for _, l in lit do
				for i, key in l.keys do
					local c = l.caps[if #l.caps == 1 then 1 else i]
					if c then
						c.setLit(UserInputService:IsKeyDown(key))
					end
				end
			end
		end,
		destroy = function()
			root:Destroy()
			local f = fade
			if f then
				f:Destroy()
			end
		end,
	}
end

return KeyGuide
