--!strict
-- The HUD's cash on its own: the price tag exactly as the driving HUD
-- draws it (CashTag, every version and finish), at the HUD's spot. The
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
local CashTag = require(HudLab:WaitForChild("CashTag"))

local Coins = {}

export type Coins = {
	root: Frame,
	-- The amount as text ("25,000"); the caller counts it.
	set: (text: string) -> (),
}

function Coins.build(gui: ScreenGui): Coins
	local root = W.frame(gui, "Coins")
	root.Size = UDim2.fromScale(1, 1)
	local right = LayoutD.corner(root, "Right", true)
	local tag = CashTag.build(right)
	return {
		root = root,
		set = tag.set,
	}
end

return Coins
