--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type RemoteTable = {
	DriveStart: RemoteEvent, -- server -> client (carModel)
	DriveStop: RemoteEvent, -- server -> client
	ExitCar: RemoteEvent, -- client -> server
	SpawnCar: RemoteEvent, -- client -> server (catalog car id): spawn it and seat me in it
	ReloadConfig: RemoteEvent, -- client -> server
	SubmitSlide: RemoteEvent, -- client -> server (points claimed for a finished slide)
	SlideResult: RemoteEvent, -- server -> client (points banked, cash earned; 0,0 = dropped)
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
		SpawnCar = ev("SpawnCar"),
		ReloadConfig = ev("ReloadConfig"),
		SubmitSlide = ev("SubmitSlide"),
		SlideResult = ev("SlideResult"),
	}
	folder.Parent = ReplicatedStorage
	return t
end

return Remotes
