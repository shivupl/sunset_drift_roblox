--!strict
-- The garage panel's sounds (garage-polish, 2026-10-05; GarageConfig.sounds):
-- a category or sub-tab, an unbought item previewed, an owned item fitted,
-- a purchase, an error. For this player only: each is one Sound under
-- SoundService, so playing it again restarts it rather than piling up.
-- They are preloaded as Sounds (BEHAVIOURS: a bare id string preloads as
-- an image), and one that fails to load is skipped quietly.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GarageConfig = require(Shared:WaitForChild("GarageConfig"))

local GarageSounds = {}

local FOLDER_NAME = "GarageSounds"

local sounds: { [string]: Sound } = {}
local failed: { [string]: boolean } = {}

-- Builds the Sounds and preloads them; once per client.
function GarageSounds.start()
	if next(sounds) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	local list: { Sound } = {}
	for kind, def in GarageConfig.sounds do
		local s = Instance.new("Sound")
		s.Name = kind
		s.SoundId = def.id
		s.Volume = def.volume
		s.Parent = folder
		sounds[kind] = s
		table.insert(list, s)
	end
	folder.Parent = SoundService
	task.spawn(function()
		ContentProvider:PreloadAsync(list, function(id: string, status: Enum.AssetFetchStatus)
			if status ~= Enum.AssetFetchStatus.Success then
				failed[id] = true
				warn(`[GarageSounds] {id} did not load ({status.Name}); it stays silent`)
			end
		end)
	end)
end

-- Plays one of GarageConfig.sounds from its start.
function GarageSounds.play(kind: string)
	local s = sounds[kind]
	if not s or failed[s.SoundId] or s.Volume <= 0 then
		return
	end
	s.TimePosition = 0
	s:Play()
end

return GarageSounds
