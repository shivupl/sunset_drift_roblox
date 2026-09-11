--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local driveStart = remotes:WaitForChild("DriveStart") :: RemoteEvent
local driveStop = remotes:WaitForChild("DriveStop") :: RemoteEvent
local reloadRemote = remotes:WaitForChild("ReloadConfig") :: RemoteEvent
local ConfigLoader = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ConfigLoader"))
local VehicleController = require(script.VehicleController)
local DebugPanel = require(script.DebugPanel)

print("[Hajwala] client boot")
VehicleController.onState = function(state)
	DebugPanel.update(state)
end
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
	DebugPanel.hide()
end)
