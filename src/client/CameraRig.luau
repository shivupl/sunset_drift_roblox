--!strict
-- Chase camera with three profiles (normal, drift, two-wheel) from
-- CarConfig.camera. Sits behind the car, lags, swings toward the velocity
-- direction in a slide so the angle is visible, and on two wheels moves to
-- the lifted side and tilts with the lean. Profile parameters cross-fade.
-- With speed the view widens and a faint shake comes in, and the follow
-- carries part of the car's velocity so a fast car does not shrink to a
-- speck (speed-feel, 2026-10-05). The speed it reads is SpeedFeel.kmh, so
-- Studio's SpeedFeelKmh previews it on a parked car.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared.ConfigLoader)
local Types = require(Shared.Types)
local SpeedFeel = require(script.Parent.SpeedFeel)

type VehicleState = Types.VehicleState

local CameraRig = {}

type Params = {
	distance: number,
	height: number,
	lookHeight: number,
	lateralOffset: number,
	driftSwing: number,
	baseFov: number,
	fovPerKmh: number,
	maxFov: number,
	rollFollow: number,
}

local conn: RBXScriptConnection? = nil
-- Simulated time since the camera last updated. The camera smooths by this,
-- not by the frame's render time: the car moves by whole physics steps (a
-- fixed 1/60 s each, one per frame at 60 fps) while render dt jitters 9 to
-- 25 ms, so smoothing by render time moved the camera 0.65 to 1.74 studs a
-- frame behind a car moving a steady 1.25, and the world juddered. A frame
-- with no physics step, where the car did not move, moves the camera nothing.
local stepConn: RBXScriptConnection? = nil
local simDt = 0
local smoothedDir = Vector3.new(0, 0, -1)
local smoothedPos = Vector3.zero
local current: Params? = nil
local profileName = "normal"
local lastState: VehicleState? = nil
local lateralSign = 0 -- which side the lateral offset goes to, smoothed
local shakeTime = 0 -- seconds of simulated time, for the shake's noise

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-4 then f.Unit else Vector3.new(0, 0, -1)
end

local function copy(p: Params): Params
	return table.clone(p)
end

local function lerpParams(a: Params, b: Params, t: number)
	for k, v in b do
		a[k] = a[k] + (v - a[k]) * t
	end
end

-- Called by VehicleController every physics step.
function CameraRig.setState(state: VehicleState)
	lastState = state
end

local function pickProfile(camCfg: typeof(ConfigLoader.current().camera)): string
	local st = lastState
	if not st then
		return "normal"
	end
	if st.twoWheelMode == "lifting" or st.twoWheelMode == "balanced" then
		return "twoWheel"
	end
	local a = math.abs(st.driftAngleDeg)
	if profileName == "drift" then
		return if a > camCfg.driftProfileExitDeg then "drift" else "normal"
	end
	return if a > camCfg.driftProfileEnterDeg then "drift" else "normal"
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
	current = copy(cfg.camera.profiles.normal)
	profileName = "normal"
	lateralSign = 0
	smoothedDir = flat(chassis.CFrame.LookVector)
	smoothedPos = chassis.Position - smoothedDir * (cfg.camera.profiles.normal.distance / mps)
		+ Vector3.yAxis * (cfg.camera.profiles.normal.height / mps)

	simDt = 0
	stepConn = RunService.PreSimulation:Connect(function(dt: number)
		simDt += dt
	end)
	conn = RunService.RenderStepped:Connect(function(_renderDt: number)
		local dt = simDt
		simDt = 0
		local c = ConfigLoader.current()
		local camCfg = c.camera
		local metersPerStud = c.units.metersPerStud
		local params = current :: Params

		-- Profile selection and cross-fade.
		profileName = pickProfile(camCfg)
		local target = (camCfg.profiles :: any)[profileName] :: Params
		lerpParams(params, target, 1 - math.exp(-camCfg.profileBlendRate * dt))

		local pos = chassis.Position
		local cf = chassis.CFrame
		local heading = flat(cf.LookVector)
		local vel = chassis.AssemblyLinearVelocity * metersPerStud
		local speedMps = vel.Magnitude

		-- Blend heading toward the direction of travel while sliding forward.
		local desired = heading
		if speedMps > camCfg.minSpeedForSwingMps and vel:Dot(cf.LookVector) > 0 then
			local blended = heading:Lerp(flat(vel), params.driftSwing)
			if blended.Magnitude > 0.1 then
				desired = blended.Unit
			end
		end
		local dirAlpha = 1 - math.exp(-camCfg.directionLag * dt)
		local nextDir = smoothedDir:Lerp(desired, dirAlpha)
		if nextDir.Magnitude > 0.1 then
			smoothedDir = nextDir.Unit
		end

		-- Lateral offset: toward the lifted side on two wheels, toward the
		-- outside of the slide otherwise (drift + means tail out left).
		local st = lastState
		local wantSign = 0
		if st then
			if profileName == "twoWheel" then
				wantSign = if st.rollDeg > 0 then -1 else 1 -- rolled right -> left wheels lifted -> camera left
			elseif profileName == "drift" then
				wantSign = if st.driftAngleDeg > 0 then 1 else -1
			end
		end
		lateralSign += (wantSign - lateralSign) * (1 - math.exp(-camCfg.profileBlendRate * dt))
		local sideDir = Vector3.new(-smoothedDir.Z, 0, smoothedDir.X) -- right of the look direction
		local lateral = sideDir * (params.lateralOffset * lateralSign / metersPerStud)

		local targetPos = pos - smoothedDir * (params.distance / metersPerStud)
			+ Vector3.yAxis * (params.height / metersPerStud)
			+ lateral
		-- Carry followAhead of the car's own velocity, so a steady speed
		-- trails only the rest of v / positionLag.
		smoothedPos += chassis.AssemblyLinearVelocity * (camCfg.followAhead * dt)
		local posAlpha = 1 - math.exp(-camCfg.positionLag * dt)
		smoothedPos = smoothedPos:Lerp(targetPos, posAlpha)

		local look = pos + Vector3.yAxis * (params.lookHeight / metersPerStud)
		-- Horizon tilt: follow a fraction of the car's roll (two-wheel profile).
		local upVec = Vector3.yAxis
		if st and params.rollFollow > 0.001 then
			local viewDir = (look - smoothedPos)
			if viewDir.Magnitude > 1e-3 then
				local tilt = math.rad(st.rollDeg * params.rollFollow)
				upVec = CFrame.fromAxisAngle(viewDir.Unit, -tilt) * Vector3.yAxis
			end
		end
		local kmh = SpeedFeel.kmh(speedMps * 3.6)
		local camCf = CFrame.lookAt(smoothedPos, look, upVec)
		-- The shake: low noise in pitch and yaw, faded in with speed.
		local sh = camCfg.shake
		local amp = sh.maxDeg * SpeedFeel.ramp(kmh, sh.fromKmh, sh.fullKmh)
		if amp > 0 then
			shakeTime += dt
			local t = shakeTime * sh.hz
			camCf *= CFrame.Angles(math.rad(amp * math.noise(t, 0.31)), math.rad(amp * math.noise(t, 7.7)), 0)
		end
		cam.CFrame = camCf
		cam.FieldOfView = math.min(params.baseFov + params.fovPerKmh * kmh, params.maxFov)
	end)
end

function CameraRig.currentProfile(): string
	return profileName
end

function CameraRig.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if stepConn then
		stepConn:Disconnect()
		stepConn = nil
	end
	lastState = nil
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
	end
end

return CameraRig
