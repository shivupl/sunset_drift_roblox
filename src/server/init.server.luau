--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared.ConfigLoader)
local VehicleSim = require(Shared.VehicleSim)
local World = require(script.World)
local Remotes = require(script.Remotes)
local CarSpawner = require(script.CarSpawner)
local ScoreService = require(script.ScoreService)
local CarControls = require(script.CarControls)
local PlateService = require(script.PlateService)
local SkyService = require(script.SkyService)
local CosmeticsService = require(script.CosmeticsService)

print("[Hajwala] server boot")
local config = ConfigLoader.current()
-- Remotes before the world: the build takes tens of seconds and the player who
-- started this server is already in it, with a client that boots nothing (no
-- HUD, no menu) until the Remotes folder exists. WorldReady tells that client
-- when the build is done and a car can actually be spawned.
ReplicatedStorage:SetAttribute("WorldReady", false)
local remotes = Remotes.create()
local world = World.build()
local road = world.road
CarSpawner.setSimFactory(function(model: Model, cfg: ConfigLoader.Config): CarSpawner.Sim
	-- VehicleSim.Sim is a metatable type; cast to the spawner's structural Sim interface.
	return (VehicleSim.new(model, cfg) :: any) :: CarSpawner.Sim
end)
CarSpawner.driverChanged = ScoreService.setDriving
CarSpawner.configChanged = ScoreService.setConfig
-- Before ScoreService.start, which starts Economy: plates hook its profile loads.
PlateService.start(remotes)
-- After PlateService (it chains onto the onLoaded hook PlateService sets),
-- and like it before ScoreService.start so no profile load is missed.
CosmeticsService.start(remotes)
ScoreService.start(config, remotes)
CarSpawner.start(config, road, remotes)
CarControls.start(remotes)
SkyService.start(remotes)
ReplicatedStorage:SetAttribute("WorldReady", true)
print("[Hajwala] ready")
