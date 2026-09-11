--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared.ConfigLoader)
local RoadBuilder = require(script.RoadBuilder)

print("[Hajwala] server boot")
local road = RoadBuilder.build(ConfigLoader.current())
print("[Hajwala] road built:", road:GetAttribute("LengthStuds"), "studs")
