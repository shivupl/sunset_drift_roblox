--!strict
-- The time of day this player sees (SkyConfig; the Settings tab picks it).
--
-- The world build sets Lighting on the server and it replicates; this sets
-- ClockTime and ExposureCompensation over it on this client only, so each
-- player can drive at their own hour. The server writes those fields again
-- only when it builds the world, and a client can join before the build is
-- done, so whenever they change to anything but the choice, the choice is put
-- back. That also undoes edits in Studio's Properties panel during Play, so
-- in Studio the player carries a SkyFree checkbox: tick it (Players > you >
-- Attributes) and the choice stops being put back, so ClockTime and exposure
-- can be tried live; untick it and the choice returns. The owner found the
-- snapping "so irritating" (2026-09-28). Never on a live server.
--
-- The choice is saved in the player's profile (SkyService) and comes back as
-- the Sky attribute when the profile loads.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SkyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SkyConfig"))

local Sky = {}

-- Called after the choice changes, so the menu can repaint its buttons.
Sky.changed = nil :: ((id: string) -> ())?

local chosen: SkyConfig.Option = SkyConfig.resolve(nil)
-- Once the player picks here, the profile's stored value (which may land
-- after the pick, when a slow load finishes) no longer overrides it.
local pickedHere = false
local remote: RemoteEvent? = nil

-- The Studio-only testing switch (see the top of this file).
local FREE_ATTRIBUTE = "SkyFree"

local function free(): boolean
	return RunService:IsStudio() and Players.LocalPlayer:GetAttribute(FREE_ATTRIBUTE) == true
end

local function apply()
	if free() then
		return
	end
	if math.abs(Lighting.ClockTime - chosen.clockTime) > 1e-3 then
		Lighting.ClockTime = chosen.clockTime
	end
	if math.abs(Lighting.ExposureCompensation - chosen.exposureCompensation) > 1e-3 then
		Lighting.ExposureCompensation = chosen.exposureCompensation
	end
end

local function choose(option: SkyConfig.Option)
	chosen = option
	apply()
	local cb = Sky.changed
	if cb then
		cb(option.id)
	end
end

function Sky.current(): string
	return chosen.id
end

-- The player picked this option in the menu.
function Sky.set(id: string)
	local option = SkyConfig.find(id)
	if not option then
		return
	end
	pickedHere = true
	choose(option)
	local r = remote
	if r then
		r:FireServer(id)
	end
end

function Sky.start(remotes: Folder)
	remote = remotes:WaitForChild("SetSky") :: RemoteEvent
	local player = Players.LocalPlayer
	if RunService:IsStudio() then
		-- Present but unticked, so it shows up as a checkbox to tick.
		if player:GetAttribute(FREE_ATTRIBUTE) == nil then
			player:SetAttribute(FREE_ATTRIBUTE, false)
		end
		player:GetAttributeChangedSignal(FREE_ATTRIBUTE):Connect(apply)
	end
	chosen = SkyConfig.resolve(player:GetAttribute("Sky") :: string?)
	apply()
	for _, prop in { "ClockTime", "ExposureCompensation" } do
		Lighting:GetPropertyChangedSignal(prop):Connect(apply)
	end
	player:GetAttributeChangedSignal("Sky"):Connect(function()
		if not pickedHere then
			choose(SkyConfig.resolve(player:GetAttribute("Sky") :: string?))
		end
	end)
end

return Sky
