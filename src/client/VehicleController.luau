--!strict
-- Runs VehicleSim on the car this client owns, every PreSimulation.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local ConfigLoader = require(Shared.ConfigLoader)
local VehicleSim = require(Shared.VehicleSim)
local VehicleRig = require(Shared.VehicleRig)
local Input = require(script.Parent.Input)
local Keyboard = require(script.Parent.Input.Keyboard)
local Gamepad = require(script.Parent.Input.Gamepad)
local Touch = require(script.Parent.Input.Touch)
local CameraRig = require(script.Parent.CameraRig)
local DriftEffects = require(script.Parent.DriftEffects)
local EngineAudio = require(script.Parent.EngineAudio)
local CarControls = require(script.Parent.CarControls)

type VehicleState = Types.VehicleState

local VehicleController = {}
VehicleController.lastState = nil :: VehicleState?
VehicleController.onState = nil :: ((VehicleState, number) -> ())?
VehicleController.onReload = nil :: (() -> ())?

local sim: VehicleSim.Sim? = nil
local car: Model? = nil
local conn: RBXScriptConnection? = nil
local exitRemote: RemoteEvent? = nil
local carId: string? = nil

local function setJumpEnabled(enabled: boolean)
	local character = Players.LocalPlayer.Character
	local hum = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if hum then
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled)
	end
end

-- Re-park upright at the nearest point on the road, zero velocity. The
-- client owns the assembly while driving, so it can move it directly.
local function resetCar(model: Model)
	local cfg = ConfigLoader.forCar(carId)
	local mps = cfg.units.metersPerStud
	local road = workspace:FindFirstChild("Road")
	local chassis = model.PrimaryPart :: BasePart
	local pos = chassis.Position
	local halfWidth = if road then (road:GetAttribute("HalfWidthStuds") :: number) else 100
	local length = if road then (road:GetAttribute("LengthStuds") :: number) else 7000
	local surfaceY = if road then (road:GetAttribute("SurfaceY") :: number) else 0
	local x = math.clamp(pos.X, -halfWidth + 5 / mps, halfWidth - 5 / mps)
	local z = math.clamp(pos.Z, -length, 30 / mps)
	-- The road is a dual carriageway now, so the corridor's centre is the
	-- median. Snap to the centre of whichever carriageway the car is nearer,
	-- read off the median strip if the world built one.
	local medianHalf = 0
	local median = if road then road:FindFirstChild("Median") else nil
	local strip = if median then median:FindFirstChildWhichIsA("BasePart") else nil
	if strip then
		medianHalf = strip.Size.X / 2
	end
	local laneCentre = medianHalf + (halfWidth - medianHalf) / 2
	local side = if pos.X < 0 then -1 else 1
	if medianHalf > 0 then
		x = side * laneCentre
	end
	-- Past the end of the straight (the curve or beyond) or well off the
	-- side: go back to the start line instead of the edge of the world.
	if pos.Z < -length or math.abs(pos.X) > halfWidth * 2 then
		x, z = side * laneCentre, 0
	end
	local y = surfaceY + (cfg.body.bodySize[2] / 2 + 0.4) / mps
	model:PivotTo(CFrame.new(x, y, z)) -- identity rotation faces -Z, down the road
	chassis.AssemblyLinearVelocity = Vector3.zero
	chassis.AssemblyAngularVelocity = Vector3.zero
end

-- The server seats a player in a car it built a moment ago, so the whole
-- rig may still be replicating when DriveStart arrives. Wait for it.
local function waitForRig(model: Model, timeout: number): boolean
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		if model and model.Parent and pcall(VehicleRig.handles, model) then
			return true
		end
		task.wait(0.05)
	end
	return false
end

local starting = 0 -- bumped on every start and stop, so a stale wait gives up

function VehicleController.start(model: Model, remotes: Folder)
	VehicleController.stop()
	starting += 1
	local token = starting
	if not waitForRig(model, 10) then
		warn(`[Hajwala] {model:GetFullName()} never finished arriving; not driving it`)
		return
	end
	if token ~= starting then
		return -- stopped, or another car started, while this one was arriving
	end
	car = model
	local id = model:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
	carId = if type(id) == "string" then id else nil
	exitRemote = remotes:FindFirstChild("ExitCar") :: RemoteEvent
	local s = VehicleSim.new(model, ConfigLoader.forCar(carId))
	s:setCharacter(Players.LocalPlayer.Character)
	sim = s
	setJumpEnabled(false)
	-- Roblox's own thumbstick and jump button would sit under our pad.
	UserInputService.ModalEnabled = true
	Keyboard.bind()
	Gamepad.bind()
	Touch.bind()
	CameraRig.start(model)
	DriftEffects.attach(model)
	EngineAudio.attach(model)
	CarControls.start(model, remotes)
	conn = RunService.PreSimulation:Connect(function(dt: number)
		local cfg = ConfigLoader.current()
		local input = Input.get(dt, cfg)
		if input.exit and exitRemote then
			exitRemote:FireServer()
		end
		if input.reset then
			resetCar(model)
		end
		if input.reload and VehicleController.onReload then
			VehicleController.onReload()
		end
		local state = s:step(input, dt)
		VehicleController.lastState = state
		Touch.observe(state.twoWheelMode)
		Touch.setLeanVisible(input.twoWheel)
		DriftEffects.update(state)
		EngineAudio.update(state, dt)
		CarControls.update(state)
		CameraRig.setState(state)
		Players.LocalPlayer:SetAttribute("DbgCamera", CameraRig.currentProfile())
		if VehicleController.onState then
			VehicleController.onState(state, dt)
		end
	end)
end

-- Called after a reload. The sim drives on this car's merged config, not
-- the shared one, so it is rebuilt here from the reloaded modules.
function VehicleController.setConfig(_config: ConfigLoader.Config)
	if sim then
		sim:setConfig(ConfigLoader.forCar(carId))
	end
	Touch.relayout()
end

function VehicleController.stop()
	starting += 1
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if car and car.Parent then
		local ok, rig = pcall(VehicleRig.handles, car)
		if ok then
			rig.force.Force = Vector3.zero
			rig.torque.Torque = Vector3.zero
		end
	end
	Keyboard.unbind()
	Gamepad.unbind()
	Touch.unbind()
	CameraRig.stop()
	DriftEffects.detach()
	EngineAudio.detach()
	CarControls.stop()
	setJumpEnabled(true)
	UserInputService.ModalEnabled = false
	sim = nil
	car = nil
	carId = nil
	VehicleController.lastState = nil
end

function VehicleController.isDriving(): boolean
	return sim ~= nil
end

-- The car the local sim is driving, if any.
function VehicleController.currentCar(): Model?
	return if sim then car else nil
end

return VehicleController
