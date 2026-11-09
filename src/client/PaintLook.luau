--!strict
-- Studio's B: the next paint look (PaintLooks: the clear coat and the sunset
-- sun's hour), named on screen like the drift switches. The LocalPlayer
-- attribute PaintLook holds the choice; CarCosmetics repaints and Sky moves
-- the sun when it changes. Studio only: players get the main look.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PaintLooks = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PaintLooks"))
local DriftStyle = require(script.Parent:WaitForChild("DriftStyle"))

local PaintLook = {}

function PaintLook.cycle()
	local player = Players.LocalPlayer
	local current = PaintLooks.resolve(player:GetAttribute(PaintLooks.ATTRIBUTE))
	local i = table.find(PaintLooks.order, current) or 0
	local nextId = PaintLooks.order[i % #PaintLooks.order + 1]
	player:SetAttribute(PaintLooks.ATTRIBUTE, nextId)
	local look = PaintLooks.looks[nextId]
	DriftStyle.say(`PAINT: {string.upper(look.name)} ({look.blurb})`)
end

function PaintLook.start()
	if not RunService:IsStudio() then
		return
	end
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.B then
			PaintLook.cycle()
		end
	end)
end

return PaintLook
