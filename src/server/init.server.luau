--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared.ConfigLoader)
local RoadBuilder = require(script.RoadBuilder)
local Remotes = require(script.Remotes)
local CarSpawner = require(script.CarSpawner)

print("[Hajwala] server boot")
local config = ConfigLoader.current()
local road = RoadBuilder.build(config)
local remotes = Remotes.create()
CarSpawner.start(config, road, remotes)
print("[Hajwala] ready")
