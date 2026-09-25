--!strict
-- The server half of the horn and the lamps (client CarControls). A driver
-- sends their lamp state and horn; the server checks they are sitting in
-- that car's driver seat, copies the lamps onto the car Model as attributes
-- (every client shows them, CarLights) and plays the horn on the chassis,
-- so every player hears it.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleRig = require(Shared.VehicleRig)
local ConfigLoader = require(Shared.ConfigLoader)
local CarLamps = require(Shared.CarLamps)
local Remotes = require(script.Parent.Remotes)

local CarControls = {}

-- Lamp and horn events a player may send per second; more are dropped. A
-- driver sends one per pedal change, so this is far above normal play.
local MAX_PER_SECOND = 30

local budget: { [Player]: { at: number, n: number } } = {}
local sounding: { [Player]: Sound } = {} -- the horn each player is holding

local function allowed(player: Player): boolean
	local now = os.clock()
	local b = budget[player]
	if not b or now - b.at >= 1 then
		budget[player] = { at = now, n = 1 }
		return true
	end
	b.n += 1
	return b.n <= MAX_PER_SECOND
end

-- The car this player is driving, if they are in its driver seat.
local function drivenBy(player: Player): Model?
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if not seat then
		return nil
	end
	local cars = Workspace:FindFirstChild("Cars")
	local node: Instance? = seat
	while node and node.Parent ~= cars do
		node = node.Parent
	end
	if not node or not node:IsA("Model") then
		return nil
	end
	local ok, handles = pcall(VehicleRig.handles, node)
	if not ok or (handles.seat :: Instance) ~= (seat :: Instance) then
		return nil
	end
	return node
end

local function hornSound(model: Model): Sound?
	local ok, handles = pcall(VehicleRig.handles, model)
	if not ok then
		return nil
	end
	local existing = handles.chassis:FindFirstChild("Horn")
	if existing and existing:IsA("Sound") then
		return existing
	end
	local id = model:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
	local cfg = ConfigLoader.forCar(if type(id) == "string" then id else nil).effects.horn
	local s = Instance.new("Sound")
	s.Name = "Horn"
	s.SoundId = cfg.soundId
	s.Volume = cfg.volume
	s.Looped = true
	s.RollOffMaxDistance = cfg.rollOffMaxDistance
	s.Parent = handles.chassis
	return s
end

function CarControls.start(remotes: Remotes.RemoteTable)
	remotes.CarLamps.OnServerEvent:Connect(function(player: Player, head: any, brake: any, reverse: any)
		if not allowed(player) or type(head) ~= "boolean" or type(brake) ~= "boolean" or type(reverse) ~= "boolean" then
			return
		end
		local model = drivenBy(player)
		if model then
			model:SetAttribute(CarLamps.HEAD, head)
			model:SetAttribute(CarLamps.BRAKE, brake)
			model:SetAttribute(CarLamps.REVERSE, reverse)
		end
	end)
	remotes.Horn.OnServerEvent:Connect(function(player: Player, on: any)
		-- A release is never rate limited: dropping one would leave it blaring.
		if type(on) ~= "boolean" or (on and not allowed(player)) then
			return
		end
		-- Letting go stops the horn this player started, even once they
		-- have left the seat.
		local held = sounding[player]
		if not on then
			if held then
				held:Stop()
				sounding[player] = nil
			end
			return
		end
		local model = drivenBy(player)
		local s = model and hornSound(model)
		if s then
			s:Play()
			sounding[player] = s
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		budget[player] = nil
		local held = sounding[player]
		if held then
			held:Stop()
			sounding[player] = nil
		end
	end)
end

return CarControls
