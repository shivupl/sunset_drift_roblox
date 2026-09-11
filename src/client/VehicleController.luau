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
local Input = require(script.Parent.Input)
local Keyboard = require(script.Parent.Input.Keyboard)
local Gamepad = require(script.Parent.Input.Gamepad)
local Touch = require(script.Parent.Input.Touch)
local CameraRig = require(script.Parent.CameraRig)
local DriftEffects = require(script.Parent.DriftEffects)

type VehicleState = Types.VehicleState

local VehicleController = {}
VehicleController.lastState = nil :: VehicleState?
VehicleController.onState = nil :: ((VehicleState) -> ())?
VehicleController.onReload = nil :: (() -> ())?

local sim: VehicleSim.Sim? = nil
local car: Model? = nil
local conn: RBXScriptConnection? = nil
local exitRemote: RemoteEvent? = nil

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
	local cfg = ConfigLoader.current()
	local mps = cfg.units.metersPerStud
	local road = workspace:FindFirstChild("Road")
	local chassis = model.PrimaryPart :: BasePart
	local pos = chassis.Position
	local halfWidth = if road then (road:GetAttribute("HalfWidthStuds") :: number) else 100
	local length = if road then (road:GetAttribute("LengthStuds") :: number) else 7000
	local surfaceY = if road then (road:GetAttribute("SurfaceY") :: number) else 0
	local x = math.clamp(pos.X, -halfWidth + 5 / mps, halfWidth - 5 / mps)
	local z = math.clamp(pos.Z, -length, 30 / mps)
	-- Past the end of the straight (the curve or beyond) or well off the
	-- side: go back to the start line instead of the edge of the world.
	if pos.Z < -length or math.abs(pos.X) > halfWidth * 2 then
		x, z = 0, 0
	end
	local y = surfaceY + (cfg.body.bodySize[2] / 2 + 0.4) / mps
	model:PivotTo(CFrame.new(x, y, z)) -- identity rotation faces -Z, down the road
	chassis.AssemblyLinearVelocity = Vector3.zero
	chassis.AssemblyAngularVelocity = Vector3.zero
end

function VehicleController.start(model: Model, remotes: Folder)
	VehicleController.stop()
	car = model
	exitRemote = remotes:FindFirstChild("ExitCar") :: RemoteEvent
	local s = VehicleSim.new(model, ConfigLoader.current())
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
		CameraRig.setState(state)
		Players.LocalPlayer:SetAttribute("DbgCamera", CameraRig.currentProfile())
		if VehicleController.onState then
			VehicleController.onState(state)
		end
	end)
end

function VehicleController.setConfig(config: ConfigLoader.Config)
	if sim then
		sim:setConfig(config)
	end
	Touch.relayout()
end

function VehicleController.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if car then
		local chassis = car.PrimaryPart
		if chassis then
			local vf = chassis:FindFirstChild("SimForce") :: VectorForce?
			local tq = chassis:FindFirstChild("SimTorque") :: Torque?
			if vf then
				vf.Force = Vector3.zero
			end
			if tq then
				tq.Torque = Vector3.zero
			end
		end
	end
	Keyboard.unbind()
	Gamepad.unbind()
	Touch.unbind()
	CameraRig.stop()
	DriftEffects.detach()
	setJumpEnabled(true)
	UserInputService.ModalEnabled = false
	sim = nil
	car = nil
	VehicleController.lastState = nil
end

function VehicleController.isDriving(): boolean
	return sim ~= nil
end

return VehicleController
