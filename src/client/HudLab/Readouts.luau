--!strict
-- What the HUD's score and cash readouts share (StreetHud, ScoreBoard,
-- ScoreLive): the italic digits from the num atlas, small labels, placing
-- by fractions, the multiplier as text.
local HudLab = script.Parent
local W = require(HudLab:WaitForChild("Widgets"))
local I = require(HudLab:WaitForChild("Instruments"))
local Art = require(HudLab:WaitForChild("Art"))

local R = {}

R.INK = Color3.fromRGB(12, 12, 13)
R.LABEL = W.font("BuilderSans", Enum.FontWeight.Bold)
R.SHOUT = W.font("BuilderSans", Enum.FontWeight.Heavy, true)

local NUM_ORDER = "0123456789,.x+-°"
local NUM_CELL = Vector2.new(80, 150)

-- Places o by its top left corner, all fractions of its parent.
function R.rect(o: GuiObject, x: number, y: number, w: number, h: number)
	o.AnchorPoint = Vector2.new(0, 0)
	o.Position = UDim2.fromScale(x, y)
	o.Size = UDim2.fromScale(w, h)
end

-- A row of `count` italic digits (Art.num), white for tint().
function R.nums(parent: Instance, name: string, count: number, align: string?): I.Chars
	local c = I.chars(parent, name, { atlas = Art.num, order = NUM_ORDER, cell = NUM_CELL, cols = 8, count = count, align = align })
	c.root.ZIndex = 3
	return c
end

function R.label(parent: Instance, name: string, text: string, color: Color3): TextLabel
	local t = W.text(parent, name, text, R.LABEL, color)
	t.ZIndex = 3
	return t
end

-- x2, x2.5.
function R.mult(m: number): string
	return if m % 1 == 0 then string.format("x%d", m) else string.format("x%.1f", m)
end

return R
