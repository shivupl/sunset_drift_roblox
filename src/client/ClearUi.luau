--!strict
-- CLEAR UI (the owner, 2026-10-13: "add a 'clear UI' option that literally
-- removes every element from the UI except a small settings gear button"):
-- a switch on the menu's SETTINGS board. On, the driving HUD (its score,
-- speed, coins, callouts and edge glow), the phone's controls, the top bar
-- and a desktop's CARS button all go; what stays is the gear, small and
-- round where the top bar was (TopBar draws it), which opens SETTINGS,
-- where the switch turns it off. A screen you open yourself (the menu,
-- the garage) still shows while it is up. The choice is the LocalPlayer
-- attribute ClearUi, the session's; each owner of a gui reads it as it
-- shows and listens here for the change.
local Players = game:GetService("Players")

local ClearUi = {}

ClearUi.ATTRIBUTE = "ClearUi"

local player = Players.LocalPlayer

function ClearUi.on(): boolean
	return player:GetAttribute(ClearUi.ATTRIBUTE) == true
end

function ClearUi.set(on: boolean)
	player:SetAttribute(ClearUi.ATTRIBUTE, on)
end

-- fn runs as the switch changes.
function ClearUi.changed(fn: () -> ()): RBXScriptConnection
	return player:GetAttributeChangedSignal(ClearUi.ATTRIBUTE):Connect(fn)
end

return ClearUi
