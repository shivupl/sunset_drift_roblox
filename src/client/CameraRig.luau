--!strict
-- Chase camera with three profiles (normal, drift, two-wheel) from
-- CarConfig.camera. Sits behind the car, lags, swings toward the velocity
-- direction in a slide so the angle is visible, and on two wheels moves to
-- the lifted side and tilts with the lean. Profile parameters cross-fade.
-- The view (CameraViews: CHASE, CLOSE, FAR) moves all three
-- closer or farther, higher or lower, narrower or wider; free look
-- (FreeLook) swings the camera round the car on top of it all.
-- With speed the view widens and a faint shake comes in, and the follow
-- carries part of the car's velocity so a fast car does not shrink to a
-- speck (speed-feel, 2026-10-05). The speed it reads is SpeedFeel.kmh, so
-- Studio's SpeedFeelKmh previews it on a parked car.
--
-- The DRIVER view is first person instead (camera.firstPerson): the eye at
-- the car's CarCockpits spot, fixed to the cabin, turning a little into a
-- slide and with free look as the head. The chase camera keeps following
-- underneath, so switching back is seamless. The local character is hidden
-- from this client while in it (others still see it).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared.ConfigLoader)
local Types = require(Shared.Types)
local SpeedFeel = require(script.Parent.SpeedFeel)
local CameraViews = require(script.Parent.CameraViews)
local FreeLook = require(script.Parent.FreeLook)
local VehicleRig = require(Shared.VehicleRig)
local CarCockpits = require(Shared.CarCockpits)

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
local slideLook = 0 -- degrees the first-person view has turned into a slide
local hidden = false -- the local character is hidden for first person
local cleared: Model? = nil -- the car whose glass first person cleared

-- Clears (or restores) a car's glass on this client only.
local function clearGlass(model: Model, amount: number)
	local body = model:FindFirstChild(VehicleRig.BODY)
	if body then
		for _, part in body:GetChildren() do
			if part:IsA("BasePart") and string.sub(part.Name, 1, 5) == "Glass" then
				part.LocalTransparencyModifier = amount
			end
		end
	end
	cleared = if amount > 0 then model else nil
end

-- Hides (or shows) the local character on this client only.
local function hideCharacter(hide: boolean)
	local character = game:GetService("Players").LocalPlayer.Character
	if character then
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = if hide then 1 else 0
			end
		end
	end
	hidden = hide
end

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

-- A profile as the view on now has it: the view says where the normal
-- profile sits and how wide it sees; the others keep their difference from
-- normal, scaled (CarConfig.camera.views). Written into `out`.
local function viewed(camCfg: typeof(ConfigLoader.current().camera), name: string, out: Params): Params
	local p = (camCfg.profiles :: any)[name] :: Params
	local n = camCfg.profiles.normal
	local v = CameraViews.chase()
	local far = v.distance / n.distance
	local up = v.height / n.height
	out.distance = p.distance * far
	out.height = p.height * up
	out.lookHeight = p.lookHeight + (v.lookHeight - n.lookHeight)
	out.lateralOffset = p.lateralOffset * far
	out.driftSwing = p.driftSwing
	out.baseFov = p.baseFov + (v.baseFov - n.baseFov)
	out.maxFov = p.maxFov + (v.maxFov - n.maxFov)
	out.fovPerKmh = p.fovPerKmh * (v.maxFov - v.baseFov) / math.max(n.maxFov - n.baseFov, 1e-3)
	out.rollFollow = p.rollFollow
	return out
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
	local carId = model:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
	local cockpit = CarCockpits.of(if type(carId) == "string" then carId else nil)
	local okHandles, handles = pcall(VehicleRig.handles, model)
	local bodyMount: Attachment? = if okHandles then handles.bodyMount else nil
	local scale = if cockpit and type(carId) == "string" then VehicleRig.scaleOf(ConfigLoader.entry(carId)) else 1
	slideLook = 0
	current = viewed(cfg.camera, "normal", copy(cfg.camera.profiles.normal))
	local target = copy(cfg.camera.profiles.normal)
	profileName = "normal"
	lateralSign = 0
	smoothedDir = flat(chassis.CFrame.LookVector)
	smoothedPos = chassis.Position - smoothedDir * ((current :: Params).distance / mps)
		+ Vector3.yAxis * ((current :: Params).height / mps)
	FreeLook.start()

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
		lerpParams(params, viewed(camCfg, profileName, target), 1 - math.exp(-camCfg.profileBlendRate * dt))

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
		-- Free look: the camera swings round the car from where the follow
		-- put it, yaw about the vertical through the look point, pitch up or
		-- down from its height there. The follow itself carries on, so letting
		-- go eases back to a camera that kept up.
		local eye = smoothedPos
		local yaw, pitch = FreeLook.step(dt)

		local fp = camCfg.firstPerson
		if cockpit and bodyMount and CameraViews.current().firstPerson then
			-- First person: the eye rides the cabin; the head turns into the
			-- slide and by free look.
			local e = cockpit.eyeM
			local f = scale / metersPerStud
			local eyePos = bodyMount.WorldCFrame * Vector3.new(e[1] * f, e[2] * f, e[3] * f)
			local localVel = cf:VectorToObjectSpace(chassis.AssemblyLinearVelocity)
			local wantLook = 0
			if speedMps > camCfg.minSpeedForSwingMps and localVel.Z < 0 then
				local slideDeg = math.deg(math.atan2(localVel.X, -localVel.Z)) -- + = travelling right of the nose
				wantLook = math.clamp(slideDeg * fp.lookIntoSlide, -fp.lookIntoSlideMaxDeg, fp.lookIntoSlideMaxDeg)
			end
			slideLook += (wantLook - slideLook) * (1 - math.exp(-fp.lookIntoSlideRate * dt))
			local headYaw = math.clamp(slideLook + yaw, -fp.maxLookYawDeg, fp.maxLookYawDeg)
			-- Free look's pitch raises the chase camera (looking down at the
			-- car); here the same drag looks down.
			local headPitch = math.clamp(-pitch, -fp.maxLookPitchDeg, fp.maxLookPitchDeg)
			local camCf = CFrame.new(eyePos) * cf.Rotation
				* CFrame.Angles(0, -math.rad(headYaw), 0)
				* CFrame.Angles(math.rad(headPitch), 0, 0)
			local kmh = SpeedFeel.kmh(speedMps * 3.6)
			local sh = camCfg.shake
			local amp = sh.maxDeg * fp.shakeScale * SpeedFeel.ramp(kmh, sh.fromKmh, sh.fullKmh)
			if amp > 0 then
				shakeTime += dt
				local t = shakeTime * sh.hz
				camCf *= CFrame.Angles(math.rad(amp * math.noise(t, 0.31)), math.rad(amp * math.noise(t, 7.7)), 0)
			end
			cam.CFrame = camCf
			local vp = cam.ViewportSize
			local aspect = if vp.Y > 0 then vp.X / vp.Y else 16 / 9
			local across = math.deg(2 * math.atan(math.tan(math.rad(camCfg.maxHorizontalFov) / 2) / aspect))
			cam.FieldOfView = math.min(fp.baseFov + fp.fovPerKmh * kmh, fp.maxFov, across)
			-- Every frame: a respawned or re-dressed character, and the
			-- default camera scripts, can set it back.
			hideCharacter(true)
			clearGlass(model, fp.glassClear)
			return
		end
		if hidden then
			hideCharacter(false)
		end
		if cleared then
			clearGlass(cleared, 0)
		end
		slideLook = 0
		if yaw ~= 0 or pitch ~= 0 then
			local off = CFrame.Angles(0, -math.rad(yaw), 0) * (smoothedPos - look)
			local across = Vector3.new(off.X, 0, off.Z)
			local r = off.Magnitude
			if across.Magnitude > 1e-3 then
				local elev = math.clamp(math.atan2(off.Y, across.Magnitude) + math.rad(pitch), math.rad(-80), math.rad(80))
				off = across.Unit * (r * math.cos(elev)) + Vector3.yAxis * (r * math.sin(elev))
			end
			eye = look + off
		end
		-- Horizon tilt: follow a fraction of the car's roll (two-wheel profile).
		local upVec = Vector3.yAxis
		if st and params.rollFollow > 0.001 then
			local viewDir = (look - eye)
			if viewDir.Magnitude > 1e-3 then
				local tilt = math.rad(st.rollDeg * params.rollFollow)
				upVec = CFrame.fromAxisAngle(viewDir.Unit, -tilt) * Vector3.yAxis
			end
		end
		local kmh = SpeedFeel.kmh(speedMps * 3.6)
		local camCf = CFrame.lookAt(eye, look, upVec)
		-- The shake: low noise in pitch and yaw, faded in with speed.
		local sh = camCfg.shake
		local amp = sh.maxDeg * SpeedFeel.ramp(kmh, sh.fromKmh, sh.fullKmh)
		if amp > 0 then
			shakeTime += dt
			local t = shakeTime * sh.hz
			camCf *= CFrame.Angles(math.rad(amp * math.noise(t, 0.31)), math.rad(amp * math.noise(t, 7.7)), 0)
		end
		cam.CFrame = camCf
		-- Capped at maxHorizontalFov across, whatever the screen's shape: the
		-- field of view is vertical, so a 19.5:9 phone at 96 saw 135 degrees
		-- across against 126 on a 16:9 screen (speed-feel review).
		local vp = cam.ViewportSize
		local aspect = if vp.Y > 0 then vp.X / vp.Y else 16 / 9
		local across = math.deg(2 * math.atan(math.tan(math.rad(camCfg.maxHorizontalFov) / 2) / aspect))
		cam.FieldOfView = math.min(params.baseFov + params.fovPerKmh * kmh, params.maxFov, across)
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
	FreeLook.stop()
	if hidden then
		hideCharacter(false)
	end
	if cleared then
		clearGlass(cleared, 0)
	end
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
	end
end

return CameraRig
