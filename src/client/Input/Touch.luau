--!strict
-- Phone controls: the client's door to them. The controls themselves are
-- HudLab's (LayoutD: round steer buttons, NATL, the lean slider, the
-- pedals, HAND, EXIT and RESET). The steer pad, buttons and LOAD / DBG row
-- this module used to draw (CLASSIC) went on 2026-10-10 with the other
-- trial styles (the owner: "remove all the other HUD layouts we have and
-- keep this").
--
-- NATL is a toggle (tap on, tap off) because a held button would pin the
-- thumb that has to keep steering. It clears itself when the car lands.
--
-- Harness: setting the LocalPlayer attribute ForceTouch = true builds the
-- controls on a desktop so they can be inspected without the device
-- emulator.
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local HudLab = require(script.Parent.Parent:WaitForChild("HudLab"))

local Touch = {}

function Touch.bind()
	local forced = Players.LocalPlayer:GetAttribute("ForceTouch") == true
	if not (UserInputService.TouchEnabled or forced) then
		return
	end
	HudLab.bindTouch()
end

-- Called every step with the sim's two-wheel mode: the NATL toggle turns
-- itself off once a lift has ended, so the lean slider goes away with it.
function Touch.observe(twoWheelMode: string)
	HudLab.observe(twoWheelMode)
end

-- The lean slider is only on screen while the car is in two-wheel mode.
function Touch.setLeanVisible(visible: boolean)
	HudLab.setLeanVisible(visible)
end

function Touch.unbind()
	HudLab.unbindTouch()
end

return Touch
