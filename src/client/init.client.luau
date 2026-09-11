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

print("[Hajwala] client boot")
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
end)
driveStop.OnClientEvent:Connect(function()
	VehicleController.stop()
	ScoreController.clear()
	Hud.hide()
	DebugPanel.hide()
end)
