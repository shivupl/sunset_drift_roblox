--!strict
-- How plates look (spec §2): frames and text labels, no images. Every
-- glyph is its own label, so Arabic letters are never joined and nothing
-- needs right-to-left shaping. layout() is the pure part (tested);
-- draw() turns it into instances inside any GUI container, a car's
-- SurfaceGui or the menu's preview alike.
--
-- Saudi private plate (checked in build Task 1, the spec's "Checked"
-- section): white, a digits block on the left and a letters block on the
-- right, each with Arabic above Latin. Each Arabic letter sits directly
-- above its Latin letter, so the Arabic row reads (right to left) in the
-- reverse order of the Latin. The KSA strip is a column on the right of
-- the short plate and between the two blocks on the long one.
local PlateText = require(script.Parent.PlateText)

export type Format = "short" | "long"
export type Rect = { x: number, y: number, w: number, h: number }
export type Role = "arabicLetter" | "arabicDigit" | "latinLetter" | "latinDigit" | "strip"
export type Cell = { text: string, role: Role, rect: Rect, font: Enum.Font, color: Color3 }
export type Block = { rect: Rect, color: Color3 }
export type Art = { blocks: { Block }, cells: { Cell } }

local PlateStyles = {}

-- Real plate sizes in metres (spec §2; build Task 1).
PlateStyles.SIZE_M = {
	short = Vector2.new(0.335, 0.155), -- the "US size", the one most used in Saudi Arabia
	long = Vector2.new(0.55, 0.11), -- the "EU size"
} :: { [Format]: Vector2 }

-- SurfaceGui canvas pixels per metre of plate: a long plate is 550 px wide.
PlateStyles.PIXELS_PER_M = 1000

local COLORS = {
	plate = Color3.fromRGB(246, 246, 242),
	ink = Color3.fromRGB(18, 18, 20),
	strip = Color3.fromRGB(246, 246, 242), -- white on private plates (yellow taxi, blue commercial)
	stripInk = Color3.fromRGB(18, 18, 20),
}
PlateStyles.COLORS = COLORS

-- Roblox draws Arabic in one fallback face whatever the font (build Task
-- 1), so only the Latin choice matters; GothamBold matches the HUD.
local FONTS = {
	latin = Enum.Font.GothamBold,
	arabic = Enum.Font.GothamBold,
}

type Layout = {
	strip: Rect,
	arabicDigits: Rect,
	arabicLetters: Rect,
	latinDigits: Rect,
	latinLetters: Rect,
	lines: { Rect }, -- the thin rules between the four fields
	border: number, -- border thickness, fraction of the plate's height
	arabicMirrored: boolean, -- arabic[1] drawn rightmost (false on Saudi plates: each Arabic letter above its Latin one)
}

local LAYOUT: { [Format]: Layout } = {
	-- Digits | letters | strip. Fractions measured off plate_ref_short.png
	-- (520x288): plate spans x=[3,510], the digit/letter rule sits at
	-- x≈262 (0.511 of plate width) and the letter/strip rule at x≈445
	-- (0.872); block widths and the strip's ~0.13 tuned to match.
	short = {
		strip = { x = 0.87, y = 0, w = 0.13, h = 1 },
		arabicDigits = { x = 0.03, y = 0.07, w = 0.47, h = 0.40 },
		arabicLetters = { x = 0.515, y = 0.07, w = 0.345, h = 0.40 },
		latinDigits = { x = 0.03, y = 0.53, w = 0.47, h = 0.40 },
		latinLetters = { x = 0.515, y = 0.53, w = 0.345, h = 0.40 },
		lines = {
			{ x = 0.503, y = 0.06, w = 0.008, h = 0.88 },
			{ x = 0.862, y = 0, w = 0.008, h = 1 },
			{ x = 0.03, y = 0.495, w = 0.83, h = 0.01 },
		},
		border = 0.03,
		arabicMirrored = false,
	},
	-- Digits | strip | letters. Fractions measured off plate_ref_long.png
	-- (1000x221): plate spans x=[13,986], the digit/strip rule at x≈455
	-- (0.454) and the strip/letter rule at x≈603 (0.606) give a strip
	-- ~0.15 wide, centred rather than the earlier guess at 0.43.
	long = {
		strip = { x = 0.454, y = 0, w = 0.15, h = 1 },
		arabicDigits = { x = 0.03, y = 0.08, w = 0.41, h = 0.39 },
		arabicLetters = { x = 0.615, y = 0.08, w = 0.365, h = 0.39 },
		latinDigits = { x = 0.03, y = 0.53, w = 0.41, h = 0.39 },
		latinLetters = { x = 0.615, y = 0.53, w = 0.365, h = 0.39 },
		lines = {
			{ x = 0.450, y = 0, w = 0.004, h = 1 },
			{ x = 0.604, y = 0, w = 0.004, h = 1 },
			{ x = 0.02, y = 0.495, w = 0.42, h = 0.01 },
			{ x = 0.615, y = 0.495, w = 0.365, h = 0.01 },
		},
		border = 0.035,
		arabicMirrored = false,
	},
}

-- Glyphs spread evenly across a rect, first on the left (or the right).
local function spread(out: { Cell }, glyphs: { string }, rect: Rect, role: Role, font: Enum.Font, color: Color3, rightToLeft: boolean)
	local n = #glyphs
	for i, g in glyphs do
		local slot = if rightToLeft then n - i else i - 1
		table.insert(out, {
			text = g,
			role = role,
			font = font,
			color = color,
			rect = { x = rect.x + slot * rect.w / n, y = rect.y, w = rect.w / n, h = rect.h },
		})
	end
end

-- The plate for a key as plain data; nil for anything not a valid key.
function PlateStyles.layout(key: string, format: Format): Art?
	local p = PlateText.parts(key)
	local l = LAYOUT[format]
	if not p or not l then
		return nil
	end
	local size = PlateStyles.SIZE_M[format]
	local bx = l.border * size.Y / size.X -- the same thickness on the sides
	local blocks: { Block } = {
		{ rect = l.strip, color = COLORS.strip },
		{ rect = { x = 0, y = 0, w = 1, h = l.border }, color = COLORS.ink },
		{ rect = { x = 0, y = 1 - l.border, w = 1, h = l.border }, color = COLORS.ink },
		{ rect = { x = 0, y = 0, w = bx, h = 1 }, color = COLORS.ink },
		{ rect = { x = 1 - bx, y = 0, w = bx, h = 1 }, color = COLORS.ink },
	}
	for _, line in l.lines do
		table.insert(blocks, { rect = line, color = COLORS.ink })
	end
	local cells: { Cell } = {}
	local latinDigits: { string } = {}
	for i = 1, #p.digits do
		table.insert(latinDigits, string.sub(p.digits, i, i))
	end
	spread(cells, p.arabicDigits, l.arabicDigits, "arabicDigit", FONTS.arabic, COLORS.ink, false)
	spread(cells, p.arabic, l.arabicLetters, "arabicLetter", FONTS.arabic, COLORS.ink, l.arabicMirrored)
	spread(cells, latinDigits, l.latinDigits, "latinDigit", FONTS.latin, COLORS.ink, false)
	spread(cells, p.latin, l.latinLetters, "latinLetter", FONTS.latin, COLORS.ink, false)
	-- The strip: the country in Arabic on top, K S A stacked below.
	local s = l.strip
	table.insert(cells, { text = "السعودية", role = "strip", font = FONTS.arabic, color = COLORS.stripInk, rect = { x = s.x + s.w * 0.1, y = 0.08, w = s.w * 0.8, h = 0.2 } })
	for i, ch in { "K", "S", "A" } do
		table.insert(cells, { text = ch, role = "strip", font = FONTS.latin, color = COLORS.stripInk, rect = { x = s.x + s.w * 0.2, y = 0.34 + (i - 1) * 0.2, w = s.w * 0.6, h = 0.18 } })
	end
	return { blocks = blocks, cells = cells }
end

local function place(o: GuiObject, r: Rect)
	o.Position = UDim2.fromScale(r.x, r.y)
	o.Size = UDim2.fromScale(r.w, r.h)
end

-- Draws a plate into a GUI container, replacing what was drawn before
-- (the child "PlateArt"). Draws nothing and returns nil for no key.
function PlateStyles.draw(parent: Instance, key: string?, format: Format): Frame?
	local old = parent:FindFirstChild("PlateArt")
	if old then
		old:Destroy()
	end
	local art = if key then PlateStyles.layout(key, format) else nil
	if not art then
		return nil
	end
	local size = PlateStyles.SIZE_M[format]
	local f = Instance.new("Frame")
	f.Name = "PlateArt"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = COLORS.plate
	f.BorderSizePixel = 0
	f.ClipsDescendants = true
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = size.X / size.Y
	aspect.Parent = f
	for _, b in art.blocks do
		local fill = Instance.new("Frame")
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = b.color
		place(fill, b.rect)
		fill.Parent = f
	end
	for _, c in art.cells do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Text = c.text
		l.Font = c.font
		l.TextColor3 = c.color
		l.TextScaled = true
		place(l, c.rect)
		l.Parent = f
	end
	f.Parent = parent
	return f
end

return PlateStyles
