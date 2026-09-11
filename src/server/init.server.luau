--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared.ConfigLoader)
local VehicleSim = require(Shared.VehicleSim)
local World = require(script.World)
local Remotes = require(script.Remotes)
local CarSpawner = require(script.CarSpawner)
local ScoreService = require(script.ScoreService)

print("[Hajwala] server boot")
local config = ConfigLoader.current()
local world = World.build()
local road = world.road
local remotes = Remotes.create()
CarSpawner.setSimFactory(function(model: Model, cfg: ConfigLoader.Config): CarSpawner.Sim
	-- VehicleSim.Sim is a metatable type; cast to the spawner's structural Sim interface.
	return (VehicleSim.new(model, cfg) :: any) :: CarSpawner.Sim
end)
CarSpawner.driverChanged = ScoreService.setDriving
CarSpawner.configChanged = ScoreService.setConfig
ScoreService.start(config, remotes)
CarSpawner.start(config, road, remotes)
print("[Hajwala] ready")
