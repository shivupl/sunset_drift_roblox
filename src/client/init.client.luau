--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local driveStart = remotes:WaitForChild("DriveStart") :: RemoteEvent
local driveStop = remotes:WaitForChild("DriveStop") :: RemoteEvent

print("[Hajwala] client boot")
driveStart.OnClientEvent:Connect(function(car: Model)
	print("[Hajwala] DriveStart", car:GetFullName())
end)
driveStop.OnClientEvent:Connect(function()
	print("[Hajwala] DriveStop")
end)
