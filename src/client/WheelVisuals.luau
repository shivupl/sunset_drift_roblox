--!strict
-- Wheel travel, steer and spin for every car this client is not driving.
--
-- The driver's own sim places its hubs every step from the suspension
-- (VehicleSim). A hub Weld's C0 set on one client never reaches another, so
-- without this every other player's car would roll past with its wheels
-- frozen at whatever the server last wrote. Here each such car casts the
-- same four rays and runs the same Suspension.step the sim does, so its
-- wheels ride the road in their arches; steer follows the direction the
-- front axle is travelling (which is what a driver's hands do in a slide as
-- well as a corner) and spin follows the ground speed.
--
-- Cheap: nothing past DRAW_DISTANCE_M, and a parked (anchored) car settles
-- its wheels once and is then left alone.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleRig = require(Shared:WaitForChild("VehicleRig"))
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local Suspension = require(Shared:WaitForChild("VehicleSim"):WaitForChild("Suspension"))

local WheelVisuals = {}

local DRAW_DISTANCE_M = 90

type WheelState = { compression: number, spin: number, steerDeg: number }
type Tracked = {
	handles: VehicleRig.Handles,
	carId: string?,
	wheels: { [string]: WheelState },
	params: RaycastParams,
	settled: boolean,
}

local tracked: { [Model]: Tracked } = {}

-- The car the local sim drives; its hubs are the sim's.
WheelVisuals.localCar = nil :: (() -> Model?)?

local function track(model: Model): Tracked?
	local t = tracked[model]
	if t then
		return t
	end
	local ok, handles = pcall(VehicleRig.handles, model)
	if not ok then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	params.IgnoreWater = true
	local wheels = {}
	for _, w in VehicleRig.WHEELS do
		wheels[w.name] = { compression = 0, spin = 0, steerDeg = 0 }
	end
	t = { handles = handles, carId = handles.carId, wheels = wheels, params = params, settled = false }
	tracked[model] = t
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			tracked[model] = nil
		end
	end)
	return t
end

local function step(t: Tracked, dt: number)
	local cfg = ConfigLoader.forCar(t.carId)
	local mps = cfg.units.metersPerStud
	local chassis = t.handles.chassis
	local cf = chassis.CFrame
	local up = cf.UpVector
	local rayLenM = Suspension.rayLengthM(cfg.suspension, cfg.body.wheelRadius)
	local vel = chassis.AssemblyLinearVelocity
	local angVel = chassis.AssemblyAngularVelocity
	for _, w in VehicleRig.WHEELS do
		local state = t.wheels[w.name]
		local origin = t.handles.rayOrigins[w.name]
		local hit = Workspace:Raycast(origin.WorldPosition, -up * (rayLenM / mps), t.params)
		local susp = Suspension.step(state.compression, if hit then hit.Distance * mps else nil, cfg.suspension, cfg.body.wheelRadius, 1, dt)
		state.compression = susp.compression

		local at = origin.WorldPosition
		local v = vel + angVel:Cross(at - chassis.AssemblyCenterOfMass)
		local forward = v:Dot(cf.LookVector) * mps
		local lateral = v:Dot(cf.RightVector) * mps
		if w.front and math.abs(forward) > 1 then
			local target = math.deg(math.atan2(lateral, math.abs(forward)))
			target = math.clamp(target, -cfg.steering.maxSteerDeg, cfg.steering.maxSteerDeg)
			state.steerDeg += (target - state.steerDeg) * math.min(1, dt * 10)
		elseif w.front then
			state.steerDeg *= 1 - math.min(1, dt * 2)
		end
		if hit then
			state.spin -= forward / cfg.body.wheelRadius * dt
		end

		local dropM = cfg.suspension.restLength - state.compression
		t.handles.hubs[w.name].weld.C0 = CFrame.new(origin.Position - Vector3.new(0, dropM / mps, 0))
			* CFrame.Angles(0, -math.rad(state.steerDeg), 0)
			* CFrame.Angles(state.spin % (2 * math.pi), 0, 0)
	end
end

function WheelVisuals.start()
	RunService.RenderStepped:Connect(function(dt)
		local cars = Workspace:FindFirstChild("Cars")
		local camera = Workspace.CurrentCamera
		if not cars or not camera then
			return
		end
		local mine = if WheelVisuals.localCar then WheelVisuals.localCar() else nil
		local camPos = camera.CFrame.Position
		for _, model in cars:GetChildren() do
			if not model:IsA("Model") or model == mine then
				continue
			end
			local t = track(model)
			if not t then
				continue
			end
			local chassis = t.handles.chassis
			local mps = ConfigLoader.forCar(t.carId).units.metersPerStud
			if (chassis.Position - camPos).Magnitude * mps > DRAW_DISTANCE_M then
				continue
			end
			if chassis.Anchored then
				if t.settled then
					continue
				end
				-- Several steps from rest so the springs reach the road.
				for _ = 1, 3 do
					step(t, 1 / 60)
				end
				t.settled = true
				continue
			end
			t.settled = false
			step(t, dt)
		end
	end)
end

return WheelVisuals
