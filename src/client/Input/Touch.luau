--!strict
-- Phone controls: the client's door to them. The controls themselves are
-- HudLab's (LayoutD: round steer buttons, a NATL button over each, the
-- pedals, HAND, EXIT, RESET and STYLE). The steer pad, buttons and LOAD /
-- DBG row this module used to draw (CLASSIC) went on 2026-10-10 with the
-- other trial styles (the owner: "remove all the other HUD layouts we have
-- and keep this"), and the NATL toggle and lean slider with them: the two
-- NATL buttons are the lean keys, Q and E.
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

function Touch.unbind()
	HudLab.unbindTouch()
end

return Touch
