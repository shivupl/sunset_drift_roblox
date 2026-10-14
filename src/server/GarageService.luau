--!strict
-- Driving into the garage (garage round 2 §3). Asked by the owner on
-- 2026-09-28: "also add the ability to not only walk in but drive a car in
-- as well (either one)." The numbers are GarageConfig.driveIn.
--
-- GarageAction (RemoteFunction), from the client's GarageView:
--   "driveIn"  the sender is driving their own car through the open door.
--              Checked here (seated driver of their own car, the chassis
--              at the doorway, the drive-out spot free); then
--              the player is unseated and the car parks on the drive-out
--              spot, facing away from the door, still and anchored, its
--              prompt off so nobody else takes it. -> { status = "ok" }
--   "bringIn"  the same from anywhere (CUSTOMIZE in the car menu; the
--              owner, 2026-10-14: "clicking customize should take me to
--              the actual garage"): the doorway and speed checks are
--              skipped, and the player is stood beside the parked car so
--              "driveOut" finds them in range.
--   "driveOut" leaving the view after a drive-in: the parked car is
--              unanchored and the player seated in it (CarSpawner's own
--              seating, which hands them network ownership as any seat
--              does), ready to drive away. Anything else ("gone" when the
--              car was replaced or removed, "failed" when the seat did not
--              hold) and the client stands them at ExitSpot as a walk-in.
--   "go"       after a drive-out, once the client's car controller runs:
--              the car, held anchored through the seating, is let go and
--              handed to the driver (CarSpawner.letGo). "waiting" while the
--              player is not its driver yet (the client asks again). Without
--              it the car is let go after driveIn.holdSeconds anyway.
--   "release"  the view closed without a drive-out (died, respawned,
--              seated elsewhere): forget the parked car, prompt back on.
-- One request at a time per player; a second while one runs is "busy".
-- The parked car stays anchored when released: a settled driverless car is
-- anchored anyway (CarSpawner), and its prompt un-anchors it.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GarageConfig = require(Shared.GarageConfig)
local ConfigLoader = require(Shared.ConfigLoader)
local VehicleRig = require(Shared.VehicleRig)
local Remotes = require(script.Parent.Remotes)
local CarSpawner = require(script.Parent.CarSpawner)

type Parked = { model: Model, prompt: ProximityPrompt }

local GarageService = {}

local parked: { [Player]: Parked } = {}
local busy: { [Player]: boolean } = {}

local function s(m: number): number
	return m / ConfigLoader.current().units.metersPerStud
end

local function door(): BasePart?
	local world = Workspace:FindFirstChild("World")
	local folder = world and world:FindFirstChild("Garage")
	if not folder or folder:GetAttribute("GarageRoot") ~= true then
		return nil
	end
	local zone = folder:FindFirstChild("DoorZone")
	return if zone and zone:IsA("BasePart") then zone else nil
end

-- Straight down from `from`, ignoring cars and characters: the ground.
local function groundY(from: Vector3, depth: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	local cars = Workspace:FindFirstChild("Cars")
	if cars then
		table.insert(ignore, cars)
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(from, Vector3.new(0, -depth, 0), params)
	return if hit then hit.Position.Y else nil
end

-- The drive-out spot on the ground: outM straight out of the door from
-- DoorZone's centre, looking away from the door.
local function spotFrame(zone: BasePart): CFrame
	local inward = zone.CFrame.LookVector
	local out = Vector3.new(-inward.X, 0, -inward.Z).Unit
	local bottom = zone.Position - Vector3.new(0, zone.Size.Y / 2, 0)
	local at = bottom + out * s(GarageConfig.driveIn.outM)
	return CFrame.lookAt(at, at + out)
end

-- True when a part of any other car, or any other player's character,
-- sits in the spot's footprint: an anchored car pivoted onto someone
-- standing there would fling them (review, 2026-09-28).
local function spotTaken(spot: CFrame, mine: Model, me: Player): boolean
	local include: { Instance } = {}
	local cars = Workspace:FindFirstChild("Cars")
	if cars then
		table.insert(include, cars)
	end
	for _, p in Players:GetPlayers() do
		if p ~= me and p.Character then
			table.insert(include, p.Character)
		end
	end
	if #include == 0 then
		return false
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	local c = GarageConfig.driveIn.clearM
	local size = Vector3.new(s(c.X), s(3), s(c.Y))
	for _, part in Workspace:GetPartBoundsInBox(spot * CFrame.new(0, s(1.5), 0), size, params) do
		if not part:IsDescendantOf(mine) then
			return true
		end
	end
	return false
end

-- Forget a parked car without seating anyone; its prompt comes back.
local function release(player: Player)
	local p = parked[player]
	parked[player] = nil
	if p and p.model.Parent then
		p.prompt.Enabled = true
	end
end

-- `afar`: "bringIn", from anywhere on the map.
local function driveIn(player: Player, afar: boolean): string
	if parked[player] then
		-- A stale park (the car was replaced since) is dropped; a live one
		-- means the view is already open for it.
		if CarSpawner.carOf(player) == parked[player].model then
			return "busy"
		end
		release(player)
	end
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if not hum or hum.Health <= 0 or not seat or not seat:IsA("VehicleSeat") then
		return "refused"
	end
	local model = CarSpawner.carOf(player)
	if not model or not seat:IsDescendantOf(model) or seat.Occupant ~= hum then
		return "refused" -- not driving their own car
	end
	local ok, handles = pcall(VehicleRig.handles, model)
	if not ok or handles.seat ~= seat then
		return "refused"
	end
	local zone = door()
	if not zone then
		return "refused"
	end
	local chassis = handles.chassis
	local half = zone.Size / 2
	if not afar then
		-- At the doorway: within the zone's box plus the margin. At any
		-- speed (2026-10-14): the car parks at once, before the walls.
		local rel = zone.CFrame:PointToObjectSpace(chassis.Position)
		local margin = s(GarageConfig.driveIn.zoneMarginM)
		if math.abs(rel.X) > half.X + margin or math.abs(rel.Y) > half.Y + margin or math.abs(rel.Z) > half.Z + margin then
			return "refused"
		end
	end
	local spot = spotFrame(zone)
	if spotTaken(spot, model, player) then
		return "blocked"
	end
	-- The car's ride height: the chassis's height over the floor it is on,
	-- kept on the apron so the anchored car neither floats nor sinks. One
	-- sample can catch the suspension mid-bounce, so it is clamped between
	-- half the body's height and CarSpawner.bayPose's spawn height (half
	-- the body plus spawn.spawnHeightM, the most a fresh car is ever
	-- dropped from).
	local below = groundY(chassis.Position, s(6)) or (zone.Position.Y - half.Y)
	local carId = model:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
	local carConfig = ConfigLoader.forCar(if type(carId) == "string" then carId else nil)
	local halfBody = carConfig.body.bodySize[2] / 2
	local ride = math.clamp(chassis.Position.Y - below, s(halfBody), s(halfBody + carConfig.spawn.spawnHeightM))
	local spotGround = groundY(spot.Position + Vector3.new(0, s(4), 0), s(10)) or spot.Position.Y
	local target = CFrame.new(spot.Position.X, spotGround + ride, spot.Position.Z) * spot.Rotation

	-- Out of the seat (CarSpawner.unseat's way), then anchor and move: an
	-- anchored assembly is the server's, so the move is not undone by the
	-- client that owned it a moment ago. CarSpawner sees the seat empty and
	-- tells the client the drive is over (DriveStop).
	hum.Sit = false
	local weld = seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	local from = model:GetPivot()
	chassis.Anchored = true
	chassis.AssemblyLinearVelocity = Vector3.zero
	chassis.AssemblyAngularVelocity = Vector3.zero
	model:PivotTo(target * chassis.CFrame:ToObjectSpace(from))
	parked[player] = { model = model, prompt = handles.prompt }
	-- CarSpawner turns the prompt back on as the seat empties; off after it.
	local deadline = os.clock() + 1
	while seat.Occupant and os.clock() < deadline do
		task.wait()
	end
	if seat.Occupant then
		-- The seat never let go: undo the park where the car was, so the
		-- player is not left driving an anchored car on the apron.
		parked[player] = nil
		if model.Parent then
			model:PivotTo(from)
			chassis.Anchored = false
			handles.prompt.Enabled = not seat.Occupant
		end
		return "failed"
	end
	task.wait()
	local p = parked[player]
	if p and p.model == model and model.Parent then
		p.prompt.Enabled = false
	end
	if afar then
		-- The player came with the car: stood beside it on the apron (the
		-- view hides them; "driveOut" wants them within leaveRangeM).
		local c = player.Character
		if c and hum.Health > 0 and not hum.SeatPart then
			c:PivotTo(target * CFrame.new(s(GarageConfig.visit.standBesideM), s(2), 0))
		end
	end
	return "ok"
end

local function driveOut(player: Player): string
	local p = parked[player]
	if not p then
		return "gone"
	end
	parked[player] = nil
	local model = p.model
	local ok, handles = pcall(VehicleRig.handles, model)
	if not model.Parent or CarSpawner.carOf(player) ~= model or not ok then
		return "gone"
	end
	if handles.seat.Occupant then
		p.prompt.Enabled = true
		return "gone"
	end
	-- Only from the garage: the player (hidden in the view) stands by the
	-- door; a request from anywhere else would pull them across the map.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local zone = door()
	if
		not root
		or not root:IsA("BasePart")
		or not zone
		or (root.Position - zone.Position).Magnitude > s(GarageConfig.driveIn.leaveRangeM)
	then
		p.prompt.Enabled = true
		return "refused"
	end
	-- CarSpawner's seating: un-anchors, sits them, and the seat hands them
	-- the car (network ownership, DriveStart) as any seat does.
	if CarSpawner.seatOwner(player, true) then
		-- The client says "go" once its sim runs; if it never does, the
		-- car must not stay anchored under a seated driver.
		local token = CarSpawner.holdToken(player)
		task.delay(GarageConfig.driveIn.holdSeconds, function()
			if player.Parent and token then
				CarSpawner.letGo(player, token, true)
			end
		end)
		return "ok"
	end
	if model.Parent then
		p.prompt.Enabled = true
	end
	return "failed"
end

local function action(player: Player, what: any): string
	if what == "release" then
		release(player)
		return "ok"
	end
	if what == "go" then
		local r = CarSpawner.letGo(player)
		-- A "go" ahead of the seat (a late DriveStop left the client's
		-- controller running): tell the client to ask again.
		if r == "waiting" or (r == "none" and busy[player]) then
			return "waiting"
		end
		return "ok"
	end
	if what ~= "driveIn" and what ~= "bringIn" and what ~= "driveOut" then
		return "refused"
	end
	if busy[player] then
		return "busy"
	end
	busy[player] = true
	local ok, result = pcall(function(): string
		if what == "driveOut" then
			return driveOut(player)
		end
		return driveIn(player, what == "bringIn")
	end)
	busy[player] = nil
	if not ok then
		warn("[GarageService]", what, player.Name, result)
		return "failed"
	end
	return result
end

function GarageService.start(remotes: Remotes.RemoteTable)
	remotes.GarageAction.OnServerInvoke = function(player: Player, what: any): any
		return { status = action(player, what) }
	end
	local function watch(player: Player)
		-- A new character (death, reset) closes the view without a drive-out.
		player.CharacterRemoving:Connect(function()
			release(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		parked[player] = nil
		busy[player] = nil
	end)
end

return GarageService
