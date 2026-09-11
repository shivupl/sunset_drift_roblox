--!strict
-- Chase camera: sits behind the car, lags, and swings toward the velocity
-- direction in a slide so the drift angle is visible from behind.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared.ConfigLoader)

local CameraRig = {}

local conn: RBXScriptConnection? = nil
local smoothedDir = Vector3.new(0, 0, -1)
local smoothedPos = Vector3.zero

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-4 then f.Unit else Vector3.new(0, 0, -1)
end

function CameraRig.start(model: Model)
	CameraRig.stop()
	local chassis = model.PrimaryPart :: BasePart
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	local cfg = ConfigLoader.current()
	local mps = cfg.units.metersPerStud
	smoothedDir = flat(chassis.CFrame.LookVector)
	smoothedPos = chassis.Position - smoothedDir * (cfg.camera.distance / mps) + Vector3.yAxis * (cfg.camera.height / mps)

	conn = RunService.RenderStepped:Connect(function(dt: number)
		local c = ConfigLoader.current()
		local camCfg = c.camera
		local metersPerStud = c.units.metersPerStud
		local pos = chassis.Position
		local heading = flat(chassis.CFrame.LookVector)
		local vel = chassis.AssemblyLinearVelocity * metersPerStud
		local speedMps = vel.Magnitude

		-- Blend heading toward the direction of travel while sliding forward.
		local desired = heading
		if speedMps > camCfg.minSpeedForSwingMps and vel:Dot(chassis.CFrame.LookVector) > 0 then
			local blended = heading:Lerp(flat(vel), camCfg.driftSwing)
			if blended.Magnitude > 0.1 then
				desired = blended.Unit
			end
		end
		local dirAlpha = 1 - math.exp(-camCfg.directionLag * dt)
		local nextDir = smoothedDir:Lerp(desired, dirAlpha)
		if nextDir.Magnitude > 0.1 then
			smoothedDir = nextDir.Unit
		end

		local target = pos - smoothedDir * (camCfg.distance / metersPerStud) + Vector3.yAxis * (camCfg.height / metersPerStud)
		local posAlpha = 1 - math.exp(-camCfg.positionLag * dt)
		smoothedPos = smoothedPos:Lerp(target, posAlpha)

		local look = pos + Vector3.yAxis * (camCfg.lookHeight / metersPerStud)
		cam.CFrame = CFrame.lookAt(smoothedPos, look)
		cam.FieldOfView = math.min(camCfg.baseFov + camCfg.fovPerKmh * speedMps * 3.6, camCfg.maxFov)
	end)
end

function CameraRig.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
	end
end

return CameraRig
