--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type RemoteTable = {
	DriveStart: RemoteEvent, -- server -> client (carModel)
	DriveStop: RemoteEvent, -- server -> client
	ExitCar: RemoteEvent, -- client -> server
	ReloadConfig: RemoteEvent, -- client -> server
}

local Remotes = {}

function Remotes.create(): RemoteTable
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	local function ev(name: string): RemoteEvent
		local e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = folder
		return e
	end
	local t: RemoteTable = {
		DriveStart = ev("DriveStart"),
		DriveStop = ev("DriveStop"),
		ExitCar = ev("ExitCar"),
		ReloadConfig = ev("ReloadConfig"),
	}
	folder.Parent = ReplicatedStorage
	return t
end

return Remotes
