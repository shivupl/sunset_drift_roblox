--!strict
-- One parked car per player. Owns seating, network ownership handoff,
-- driverless simulation (plugged in by VehicleSim), anchoring of settled
-- cars, exit, and config reload.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared.CarConfig)
local ConfigLoader = require(Shared.ConfigLoader)
local Types = require(Shared.Types)
local CarBuilder = require(script.Parent.CarBuilder)
local Remotes = require(script.Parent.Remotes)

type Config = CarConfig.Config

-- Minimal interface the spawner needs from a sim (VehicleSim satisfies it).
export type Sim = {
	step: (self: Sim, input: Types.InputState, dt: number) -> Types.VehicleState,
	setConfig: (self: Sim, config: Config) -> (),
}
export type SimFactory = (model: Model, config: Config) -> Sim

type Entry = {
	model: Model,
	chassis: BasePart,
	seat: VehicleSeat,
	prompt: ProximityPrompt,
	owner: Player,
	driver: Player?,
	sim: Sim?,
	stillTime: number,
	slotX: number,
}

local CarSpawner = {}

-- Set by whoever needs to follow the driver (ScoreService). model is nil
-- when the player gets out.
CarSpawner.driverChanged = nil :: ((player: Player, model: Model?) -> ())?
-- Fired after a live CarConfig reload, so other services pick up the new
-- tunables without each of them listening to the remote.
CarSpawner.configChanged = nil :: ((config: Config) -> ())?

local cars: { [Player]: Entry } = {}
local config: Config = ConfigLoader.current()
local simFactory: SimFactory? = nil
local remotes: Remotes.RemoteTable
local road: Model
local slotCounter = 0
local zeroInput = Types.newInput()

local FALL_CHECK_SECONDS = 1

local function s(m: number): number
	return m / config.units.metersPerStud
end

local function unseat(entry: Entry)
	local hum = entry.seat.Occupant
	if hum then
		hum.Sit = false
	end
	local weld = entry.seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
end

local function onOccupantChanged(entry: Entry)
	local hum = entry.seat.Occupant
	if hum then
		local character = hum.Parent
		local player = if character then Players:GetPlayerFromCharacter(character) else nil
		if not player then
			unseat(entry)
			return
		end
		entry.driver = player
		entry.prompt.Enabled = false
		entry.chassis.Anchored = false
		entry.chassis:SetNetworkOwner(player)
		remotes.DriveStart:FireClient(player, entry.model)
		if CarSpawner.driverChanged then
			CarSpawner.driverChanged(player, entry.model)
		end
	else
		local prev = entry.driver
		entry.driver = nil
		entry.prompt.Enabled = true
		entry.stillTime = 0
		if not entry.chassis.Anchored then
			entry.chassis:SetNetworkOwner(nil)
		end
		if prev then
			if CarSpawner.driverChanged then
				CarSpawner.driverChanged(prev, nil)
			end
			remotes.DriveStop:FireClient(prev)
			local character = prev.Character
			if character then
				task.defer(function()
					character:PivotTo(entry.model:GetPivot() * CFrame.new(-s(3), s(1.5), 0))
				end)
			end
		end
	end
end

local function bayPose(slotX: number): CFrame
	local bay = road:GetAttribute("BayCFrame") :: CFrame
	local restHeight = s(config.body.bodySize[2] / 2 + config.spawn.spawnHeightM) -- a little high, let it settle
	return bay * CFrame.new(slotX, restHeight, 0)
end

-- Put the car back in its bay slot, upright, still. Keeps the driver seated;
-- the server briefly takes the assembly back so the move is authoritative.
local function repark(entry: Entry)
	local driver = entry.driver
	if not entry.chassis.Anchored then
		entry.chassis:SetNetworkOwner(nil)
	end
	entry.model:PivotTo(bayPose(entry.slotX))
	entry.chassis.AssemblyLinearVelocity = Vector3.zero
	entry.chassis.AssemblyAngularVelocity = Vector3.zero
	entry.stillTime = 0
	if driver and not entry.chassis.Anchored then
		entry.chassis:SetNetworkOwner(driver)
	end
end

local function carsFolder(): Folder
	local f = workspace:FindFirstChild("Cars")
	if f and f:IsA("Folder") then
		return f
	end
	local folder = Instance.new("Folder")
	folder.Name = "Cars"
	folder.Parent = workspace
	return folder
end

local spawnFor: (Player) -> ()
spawnFor = function(player: Player)
	if cars[player] then
		return
	end
	local model = CarBuilder.build(config, "Car_" .. player.Name)
	model:SetAttribute("OwnerUserId", player.UserId)
	local chassis = model.PrimaryPart :: BasePart
	local seat = model:FindFirstChild("DriverSeat") :: VehicleSeat
	local prompt = chassis:FindFirstChild("EnterPrompt") :: ProximityPrompt

	local slotX = s(config.spawn.slotStartM) + (slotCounter % 10) * s(config.spawn.slotSpacingM)
	slotCounter += 1
	model:PivotTo(bayPose(slotX))
	model.Parent = carsFolder()

	local entry: Entry = {
		model = model,
		chassis = chassis,
		seat = seat,
		prompt = prompt,
		owner = player,
		driver = nil,
		sim = if simFactory then simFactory(model, config) else nil,
		stillTime = 0,
		slotX = slotX,
	}
	cars[player] = entry

	-- If the chassis ever gets destroyed (fell past FallenPartsDestroyHeight,
	-- deleted in Studio), give the player a fresh car.
	chassis:GetPropertyChangedSignal("Parent"):Connect(function()
		if chassis.Parent == nil and cars[player] == entry then
			cars[player] = nil
			entry.model:Destroy()
			if player.Parent then
				task.delay(0.5, spawnFor, player)
			end
		end
	end)

	-- With no sim the car stays anchored where it spawned.
	chassis.Anchored = entry.sim == nil

	prompt.Triggered:Connect(function(who: Player)
		if entry.driver ~= nil then
			return
		end
		local character = who.Character
		local hum = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not hum or hum.Health <= 0 then
			return
		end
		chassis.Anchored = false
		seat:Sit(hum)
	end)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		onOccupantChanged(entry)
	end)
end

local function despawn(player: Player)
	local entry = cars[player]
	if not entry then
		return
	end
	cars[player] = nil
	entry.model:Destroy()
end

local fallCheckTimer = 0
local function checkFallen(dt: number)
	fallCheckTimer += dt
	if fallCheckTimer < FALL_CHECK_SECONDS then
		return
	end
	fallCheckTimer = 0
	local surfaceY = (road:GetAttribute("SurfaceY") :: number) or 0
	for _, entry in cars do
		if entry.chassis.Position.Y < surfaceY - s(config.spawn.fallBelowM) then
			warn("[Hajwala] car fell off the world, re-parking:", entry.model.Name)
			repark(entry)
		end
	end
end

local function stepDriverless(dt: number)
	checkFallen(dt)
	for _, entry in cars do
		if entry.driver ~= nil or entry.sim == nil or entry.chassis.Anchored then
			continue
		end
		entry.sim:step(zeroInput, dt)
		if entry.chassis.AssemblyLinearVelocity.Magnitude < s(config.spawn.settleSpeedMps) then
			entry.stillTime += dt
			if entry.stillTime >= config.spawn.settleSeconds then
				entry.chassis.Anchored = true
			end
		else
			entry.stillTime = 0
		end
	end
end

function CarSpawner.setSimFactory(factory: SimFactory)
	simFactory = factory
end

function CarSpawner.setConfig(newConfig: Config)
	config = newConfig
	for _, entry in cars do
		if entry.sim then
			entry.sim:setConfig(newConfig)
		end
	end
	if CarSpawner.configChanged then
		CarSpawner.configChanged(newConfig)
	end
end

function CarSpawner.start(startConfig: Config, startRoad: Model, startRemotes: Remotes.RemoteTable)
	config = startConfig
	road = startRoad
	remotes = startRemotes

	Players.PlayerAdded:Connect(spawnFor)
	Players.PlayerRemoving:Connect(despawn)
	for _, p in Players:GetPlayers() do
		spawnFor(p)
	end

	RunService.PreSimulation:Connect(stepDriverless)

	remotes.ExitCar.OnServerEvent:Connect(function(player: Player)
		for _, entry in cars do
			if entry.driver == player then
				unseat(entry)
			end
		end
	end)

	remotes.ReloadConfig.OnServerEvent:Connect(function()
		local newConfig, err = ConfigLoader.reload()
		if err then
			warn("[Hajwala] config reload failed:", err)
		end
		CarSpawner.setConfig(newConfig)
	end)
end

return CarSpawner
