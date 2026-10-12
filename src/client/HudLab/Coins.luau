--!strict
-- The HUD's cash on its own: the coin and the amount exactly as the
-- driving HUD draws them (ScoreLive's FLOW chip or SIDE's bare coin,
-- ScoreBoard's long plate), in the HUD's finish, at the HUD's spot. The
-- menu and the garage show this, so the coins neither move nor change
-- their look between driving, the car menu and the garage (ui-flow,
-- 2026-10-12: the garage had its own Oswald pill, the menu none).
--
-- `gui` must be set up as the HUD's (IgnoreGuiInset, so DeviceSafeInsets):
-- the cash is placed in a square the screen's height tall in its top right
-- corner (LayoutD.corner), in fractions of that height.
local HudLab = script.Parent
local W = require(HudLab:WaitForChild("Widgets"))
local LayoutD = require(HudLab:WaitForChild("LayoutD"))
local Art = require(HudLab:WaitForChild("Art"))
local Finishes = require(HudLab:WaitForChild("Finishes"))
local R = require(HudLab:WaitForChild("Readouts"))

local Coins = {}

-- ScoreLive's cash box and ScoreBoard's plate, fractions of the height.
local CHIP_W = 0.32
local PLATE_W = 0.463

export type Coins = {
	root: Frame,
	-- The amount as text ("25,000"); the caller counts it.
	set: (text: string) -> (),
}

function Coins.build(gui: ScreenGui, finish: Finishes.Finish, version: string): Coins
	local f = finish
	local er = LayoutD.EDGE_R
	local root = W.frame(gui, "Coins")
	root.Size = UDim2.fromScale(1, 1)
	local right = LayoutD.corner(root, "Right", true)
	local value: { set: (text: string) -> () }
	if version == "board" then
		local pill = W.image(right, "Cash", f.art.pill)
		pill.ScaleType = Enum.ScaleType.Slice
		pill.SliceCenter = Rect.new(40, 30, 260, 82)
		pill.AnchorPoint = Vector2.new(1, 0)
		pill.Position = UDim2.fromScale(1 - er, LayoutD.CASH_Y)
		pill.Size = UDim2.fromScale(PLATE_W, LayoutD.CASH_H)
		local label = R.label(pill, "Label", "CASH", f.label)
		R.rect(label, 0.04, 0.3, 0.13, 0.36)
		local cash = R.nums(pill, "Value", 9, "left")
		cash.tint(f.print)
		R.rect(cash.root, 0.17, 0.14, 0.52, 0.68)
		value = cash
	else
		local side = version == "side"
		local box = W.frame(right, "Cash")
		box.AnchorPoint = Vector2.new(1, 0)
		box.Position = UDim2.fromScale(1 - er, LayoutD.CASH_Y)
		box.Size = UDim2.fromScale(CHIP_W, LayoutD.CASH_H)
		if side then
			local shade = W.image(box, "Shade", Art.soft)
			shade.ImageTransparency = 0.4
			shade.Size = UDim2.fromScale(1.3, 2)
			W.at(shade, 0.55, 0.5)
			shade.ZIndex = 0
		else
			local chip = W.image(box, "Chip", f.art.pill)
			chip.ScaleType = Enum.ScaleType.Slice
			chip.SliceCenter = Rect.new(40, 30, 260, 82)
		end
		local holder = W.frame(box, "Coin")
		holder.SizeConstraint = Enum.SizeConstraint.RelativeYY
		holder.Size = UDim2.fromScale(1.25, 1.25)
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(if side then 0.1 else 0.05, 0.5)
		holder.ZIndex = 4
		local coin = W.image(holder, "Face", Art.coin)
		coin.ZIndex = 4
		local cash = R.nums(box, "Value", 9, "left")
		cash.tint(f.print)
		R.rect(cash.root, if side then 0.3 else 0.26, 0.255, 0.7, 0.49)
		value = cash
	end
	return {
		root = root,
		set = function(text: string)
			value.set(text)
		end,
	}
end

return Coins
