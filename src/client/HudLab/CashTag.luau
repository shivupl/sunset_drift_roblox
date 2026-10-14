--!strict
-- The cash as a price tag (the owner, 2026-10-14, of the canvas's J7
-- "Price tag: a sodium plate with the cut corner, dark ink": "uniformly
-- implement this one throughout the ui"): a sodium plate with the kit's
-- cut corner, the amount in dark ink on it, the coin over its left end.
-- One drawing for everywhere the cash shows (ScoreLive and ScoreBoard: the
-- HUD in every version and finish; Coins: the menu and the garage), so
-- the coins neither move nor change their look between driving, the car
-- menu and the garage.
--
-- Sized in fractions of the HUD's top-right corner square (its side the
-- screen's height; LayoutD.corner): the plate LayoutD.CASH_H tall at
-- LayoutD.CASH_Y, its right edge at EDGE_R, as wide as the amount needs
-- (the mock's: 34 of 32 left of the digits for the coin, 12 right), the
-- coin 1.25 the plate's height centred 4/32 in from its left end, the
-- digits half the plate's height.
local HudLab = script.Parent
local W = require(HudLab:WaitForChild("Widgets"))
local LayoutD = require(HudLab:WaitForChild("LayoutD"))
local Art = require(HudLab:WaitForChild("Art"))
local R = require(HudLab:WaitForChild("Readouts"))

local CashTag = {}

-- The mock (a 32 px plate), in fractions of the plate's height.
local PAD_L = 34 / 32
local PAD_R = 12 / 32
local COIN = 40 / 32
local COIN_X = 4 / 32
local DIGIT_H = 0.5
-- The digits' atlas cells are 80x150: a character's width as a share of
-- its height.
local CHAR = 80 / 150
local COUNT = 9 -- "1,000,000"
-- The plate: sodium, lighter at the top (#FFD592 over #FFBA5C), the ink
-- #2B1903.
local TOP = Color3.fromRGB(255, 213, 146)
local BOTTOM = Color3.fromRGB(255, 186, 92)
local INK = Color3.fromRGB(43, 25, 3)
-- The art (hud_tag, 300x120): three corners rounded (30), the
-- bottom-right cut (34), white for the gradient to tint.
local SLICE = Rect.new(36, 36, 264, 84)
local ART_H = 120

export type Tag = {
	root: Frame, -- the plate's box ("Cash"); the coin hangs off its left end
	coin: ImageLabel, -- the coin's face (a banked slide's cash flies into it)
	set: (text: string) -> (), -- the amount as text ("25,000")
}

-- `right`: the HUD's top-right corner square (LayoutD.corner).
function CashTag.build(right: Frame): Tag
	local h = LayoutD.CASH_H
	local box = W.frame(right, "Cash")
	box.AnchorPoint = Vector2.new(1, 0)
	box.Position = UDim2.fromScale(1 - LayoutD.EDGE_R, LayoutD.CASH_Y)
	local plate = W.image(box, "Plate", Art.tag)
	plate.ScaleType = Enum.ScaleType.Slice
	plate.SliceCenter = SLICE
	plate:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		plate.SliceScale = math.max(plate.AbsoluteSize.Y, 1) / ART_H
	end)
	local tint = Instance.new("UIGradient")
	tint.Rotation = 90
	tint.Color = ColorSequence.new(TOP, BOTTOM)
	tint.Parent = plate
	local holder = W.frame(box, "Coin")
	holder.SizeConstraint = Enum.SizeConstraint.RelativeYY
	holder.Size = UDim2.fromScale(COIN, COIN)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.ZIndex = 4
	local coin = W.image(holder, "Face", Art.coin)
	coin.ZIndex = 4
	local digits = R.nums(box, "Value", COUNT, "left")
	digits.tint(INK)
	local shown = ""
	-- The plate as wide as the amount: its padding and one cell a character.
	local function set(text: string)
		if text == shown then
			return
		end
		shown = text
		local n = math.max(utf8.len(text) or #text, 1)
		local w = PAD_L + PAD_R + n * DIGIT_H * CHAR -- plate heights
		box.Size = UDim2.fromScale(w * h, h)
		holder.Position = UDim2.fromScale(COIN_X / w, 0.5)
		R.rect(digits.root, PAD_L / w, (1 - DIGIT_H) / 2, COUNT * DIGIT_H * CHAR / w, DIGIT_H)
		digits.set(text)
	end
	set("0")
	return { root = box, coin = coin, set = set }
end

return CashTag
