--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local driveStart = remotes:WaitForChild("DriveStart") :: RemoteEvent
local driveStop = remotes:WaitForChild("DriveStop") :: RemoteEvent
local reloadRemote = remotes:WaitForChild("ReloadConfig") :: RemoteEvent
local submitSlide = remotes:WaitForChild("SubmitSlide") :: RemoteEvent
local slideResult = remotes:WaitForChild("SlideResult") :: RemoteEvent
local ConfigLoader = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ConfigLoader"))
local VehicleController = require(script.VehicleController)
local DebugPanel = require(script.DebugPanel)
local Hud = require(script.Hud)
local ScoreController = require(script.ScoreController)
local Touch = require(script.Input.Touch)
local WorldLights = require(script.WorldLights)
local SpawnMenu = require(script.SpawnMenu)

print("[Hajwala] client boot")
-- Lamp lights follow the camera whether or not the player is driving.
WorldLights.start()
ScoreController.onSpin = function(bonus: number, spins: number)
	Hud.flashSpin(bonus, spins)
end
ScoreController.submit = function(points: number)
	submitSlide:FireServer(points)
end
slideResult.OnClientEvent:Connect(function(points: number, cash: number)
	Hud.flashResult(points, cash)
end)
VehicleController.onState = function(state, dt)
	ScoreController.step(state, dt)
	Hud.update(state, ScoreController.state)
	DebugPanel.update(state)
end
Touch.onDebugToggle = DebugPanel.toggle
VehicleController.onReload = function()
	local cfg, err = ConfigLoader.reload()
	if err then
		warn("[Hajwala] config reload failed:", err)
	else
		print("[Hajwala] config reloaded")
	end
	VehicleController.setConfig(cfg)
	reloadRemote:FireServer()
end
driveStart.OnClientEvent:Connect(function(car: Model)
	VehicleController.start(car, remotes)
	local id = car:GetAttribute("CarId")
	SpawnMenu.setCurrent(if type(id) == "string" then id else nil)
end)
driveStop.OnClientEvent:Connect(function()
	VehicleController.stop()
	ScoreController.clear()
	Hud.hide()
	DebugPanel.hide()
end)

-- Players start on foot; the spawn menu opens and puts them in a car.
SpawnMenu.start(remotes)
