--!strict
-- One car per player. Owns choosing the car, building it (RigBuilder then
-- BodyBuilder), seating, network ownership handoff, driverless simulation
-- (plugged in by VehicleSim), anchoring of settled cars, exit, and config
-- reload.
--
-- Players start on foot. The spawn menu (client) fires SpawnCar with a
-- catalog id; the server replaces the player's car with that one in their
-- bay slot and seats them in it. spawn.autoSpawnOnJoin brings back the old
-- parked-car-at-join behaviour.
--
-- Which car a respawn builds: the player's "CarId" attribute if the catalog
-- has it, else CarConfig.spawn.carId, else the catalog default. Changing the
-- attribute swaps an existing car (at once if parked, on getting out if
-- driving).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared.CarConfig)
local ConfigLoader = require(Shared.ConfigLoader)
local Types = require(Shared.Types)
local VehicleRig = require(Shared.VehicleRig)
local RigBuilder = require(script.Parent.RigBuilder)
local BodyBuilder = require(script.Parent.BodyBuilder)
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
	carId: string,
	config: Config, -- this car's handling: shared CarConfig + its rig + its tuning
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
local slotOf: { [Player]: number } = {} -- each player keeps one bay slot for the session
local lastSpawnRequest: { [Player]: number } = {}
local spawning: { [Player]: boolean } = {}
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

-- Forward declared: getting out can swap the car, which respawns it.
local spawnFor: (Player) -> ()
local despawn: (Player) -> ()

local function carIdFor(player: Player): string
	local wanted = player:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
	local fromConfig = config.spawn.carId
	local id = if type(wanted) == "string" and ConfigLoader.catalog().cars[wanted] then wanted else fromConfig
	return ConfigLoader.resolveCarId(id)
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
	-- A replaced or removed car can still report its driver leaving, after
	-- the model is gone. Nothing to hand back then.
	if cars[entry.owner] ~= entry then
		return
	end
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
		-- The name too: a car spawned a moment ago may not have reached the
		-- client yet, and an instance that has not arrives as nil.
		remotes.DriveStart:FireClient(player, entry.model, entry.model.Name)
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
			-- A car change asked for while driving happens now.
			if carIdFor(entry.owner) ~= entry.carId then
				task.delay(0.5, function()
					if cars[entry.owner] == entry and entry.driver == nil then
						despawn(entry.owner)
						spawnFor(entry.owner)
					end
				end)
			end
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

local function bayPose(slotX: number, carConfig: Config): CFrame
	local bay = road:GetAttribute("BayCFrame") :: CFrame
	local restHeight = s(carConfig.body.bodySize[2] / 2 + config.spawn.spawnHeightM) -- a little high, let it settle
	return bay * CFrame.new(slotX, restHeight, 0)
end

-- Put the car back in its bay slot, upright, still. Keeps the driver seated;
-- the server briefly takes the assembly back so the move is authoritative.
local function repark(entry: Entry)
	local driver = entry.driver
	if not entry.chassis.Anchored then
		entry.chassis:SetNetworkOwner(nil)
	end
	entry.model:PivotTo(bayPose(entry.slotX, entry.config))
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

spawnFor = function(player: Player)
	if cars[player] then
		return
	end
	local carId = carIdFor(player)
	local catalogEntry = ConfigLoader.entry(carId)
	local problems = VehicleRig.validate(carId, catalogEntry)
	if #problems > 0 then
		warn(`[Hajwala] car "{carId}" breaks the rig contract:\n  {table.concat(problems, "\n  ")}`)
		local fallback = ConfigLoader.resolveCarId(nil)
		if fallback == carId then
			return
		end
		carId = fallback
		catalogEntry = ConfigLoader.entry(carId)
	end
	local carConfig = ConfigLoader.forCar(carId)
	BodyBuilder.preload(catalogEntry)
	if cars[player] or not player.Parent then
		return -- the preload yielded and something else got there first
	end
	local model = RigBuilder.build(carConfig, catalogEntry, "Car_" .. player.Name)
	BodyBuilder.mount(model, carConfig, catalogEntry)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute(VehicleRig.CAR_ID_ATTRIBUTE, carId)
	local handles = VehicleRig.handles(model)
	local chassis = handles.chassis
	local seat = handles.seat
	local prompt = handles.prompt

	local slot = slotOf[player]
	if not slot then
		slot = slotCounter % 10
		slotCounter += 1
		slotOf[player] = slot
	end
	local slotX = s(config.spawn.slotStartM) + slot * s(config.spawn.slotSpacingM)
	model:PivotTo(bayPose(slotX, carConfig))
	model.Parent = carsFolder()

	local entry: Entry = {
		model = model,
		carId = carId,
		config = carConfig,
		chassis = chassis,
		seat = seat,
		prompt = prompt,
		owner = player,
		driver = nil,
		sim = if simFactory then simFactory(model, carConfig) else nil,
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

despawn = function(player: Player)
	local entry = cars[player]
	if not entry then
		return
	end
	cars[player] = nil
	-- Taking a car away from under its driver: tell the scoring and the
	-- client the drive is over, the way getting out would.
	local driver = entry.driver
	entry.driver = nil
	if driver then
		if CarSpawner.driverChanged then
			CarSpawner.driverChanged(driver, nil)
		end
		remotes.DriveStop:FireClient(driver)
		local hum = entry.seat.Occupant
		if hum then
			hum.Sit = false
		end
	end
	entry.model:Destroy()
end

-- Seats a player in their car, waiting briefly for a character that is still
-- loading. Returns whether they ended up in the seat.
local function seatIn(entry: Entry, player: Player): boolean
	local character = player.Character
	local deadline = os.clock() + 10
	while not character and os.clock() < deadline and player.Parent do
		task.wait(0.1)
		character = player.Character
	end
	if not character then
		return false
	end
	local hum = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not hum or not hum:IsA("Humanoid") or hum.Health <= 0 or cars[player] ~= entry then
		return false
	end
	if hum.SeatPart then
		hum.Sit = false
		task.wait()
	end
	entry.chassis.Anchored = false
	character:PivotTo(entry.seat.CFrame * CFrame.new(0, s(1.5), 0))
	entry.seat:Sit(hum)
	return true
end

-- The spawn menu's request: replace this player's car with catalog car
-- carId and put them in it. Everything from the client is checked: an id
-- the catalog does not have, a request while one is still building, or one
-- inside the cooldown is ignored.
function CarSpawner.requestSpawn(player: Player, carId: any)
	if type(carId) ~= "string" or #carId > 64 or not ConfigLoader.catalog().cars[carId] then
		return
	end
	local now = os.clock()
	local last = lastSpawnRequest[player]
	if spawning[player] or (last and now - last < config.spawn.spawnCooldownSeconds) then
		return
	end
	lastSpawnRequest[player] = now
	spawning[player] = true
	-- Remove the old car before setting the attribute, so the attribute
	-- watcher finds no car to swap and leaves this to us.
	despawn(player)
	player:SetAttribute(VehicleRig.CAR_ID_ATTRIBUTE, carId)
	local ok, err = pcall(function()
		spawnFor(player)
	end)
	if not ok then
		warn(`[Hajwala] spawning "{carId}" for {player.Name} failed: {err}`)
	end
	local entry = cars[player]
	if entry then
		seatIn(entry, player)
	end
	spawning[player] = nil
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

-- newConfig is the shared CarConfig; each car gets its own merged copy.
-- Handling changes apply live. A change to a car's rig geometry or body
-- only shows on a fresh car, because those are built into the model.
function CarSpawner.setConfig(newConfig: Config)
	config = newConfig
	for _, entry in cars do
		entry.config = ConfigLoader.forCar(entry.carId)
		if entry.sim then
			entry.sim:setConfig(entry.config)
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

	-- Every catalog entry is checked once at start, so a broken new car is
	-- reported in the output before anyone tries to drive it.
	for id, carEntry in ConfigLoader.catalog().cars do
		local problems = VehicleRig.validate(id, carEntry)
		if #problems > 0 then
			warn(`[Hajwala] car "{id}" breaks the rig contract:\n  {table.concat(problems, "\n  ")}`)
		end
	end

	local function watch(player: Player)
		player:GetAttributeChangedSignal(VehicleRig.CAR_ID_ATTRIBUTE):Connect(function()
			local entry = cars[player]
			if entry and entry.driver == nil and carIdFor(player) ~= entry.carId then
				despawn(player)
				spawnFor(player)
			end
		end)
		if config.spawn.autoSpawnOnJoin then
			spawnFor(player)
		end
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player: Player)
		despawn(player)
		slotOf[player] = nil
		lastSpawnRequest[player] = nil
		spawning[player] = nil
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(watch, p)
	end

	RunService.PreSimulation:Connect(stepDriverless)

	remotes.SpawnCar.OnServerEvent:Connect(function(player: Player, carId: any)
		CarSpawner.requestSpawn(player, carId)
	end)

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
