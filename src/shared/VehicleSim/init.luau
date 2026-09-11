--!strict
-- Glue between Roblox and the pure physics modules. One instance per car.
-- step() raycasts each corner, computes every force in SI about the centre
-- of mass, writes one VectorForce and one Torque on the chassis, repositions
-- the visual wheels, and returns a VehicleState for the debug panel.
--
-- Runs on whoever owns the assembly: the driving client, or the server for a
-- parked car (zero input) so it keeps sitting on its springs.
local Shared = script.Parent
local Types = require(Shared.Types)
local Units = require(Shared.Units)
local CarConfig = require(Shared.CarConfig)
local Steering = require(script.Steering)
local Suspension = require(script.Suspension)
local Tire = require(script.Tire)
local Drivetrain = require(script.Drivetrain)
local TwoWheel = require(script.TwoWheel)
local Throw = require(script.Throw)

type Config = CarConfig.Config
type InputState = Types.InputState
type VehicleState = Types.VehicleState
type WheelState = Types.WheelState

type Wheel = {
	name: string,
	front: boolean,
	left: boolean,
	attachment: Attachment,
	part: BasePart,
	weld: Weld,
	compression: number,
	spinAngle: number,
	state: WheelState,
}

type Contact = {
	wheel: Wheel,
	hitDistM: number?,
	susp: Suspension.Result,
	hpM: Vector3,
	contactM: Vector3,
	normal: Vector3,
	heading: Vector3,
	right: Vector3,
	vLong: number,
	vLat: number,
	steerDeg: number,
}

local VehicleSim = {}
VehicleSim.__index = VehicleSim

export type Sim = typeof(setmetatable(
	{} :: {
		config: Config,
		model: Model,
		chassis: BasePart,
		vectorForce: VectorForce,
		torque: Torque,
		rayParams: RaycastParams,
		wheels: { Wheel },
		drivetrain: Drivetrain.State,
		twoWheel: TwoWheel.State,
		steerDeg: number,
		comHeightM: number,
		handbrakeLevel: number,
		throwTail: number,
		flickSign: number, -- sign of the last strong steer input, 0 none
		flickAge: number, -- seconds since that input
		flickTimer: number, -- seconds of rear grip cut left after a flick
		lastFlatVel: Vector3, -- last step's horizontal velocity, for the path's turn rate
		pathRateDeg: number, -- filtered rate the velocity direction is turning, deg/s, + = right
		throw: Throw.State,
		throttleHoldStraight: number, -- seconds the drift has been under the throttle-hold gate
		throttleHoldOn: boolean, -- throttle is currently a throw permission
		spinAccumDeg: number, -- signed, unwrapped drift-angle travel of the current spin
		spinCount: number,
		lastDriftDeg: number,
		spinStraight: number, -- seconds the car has been under spinSlipDeg
		lastState: VehicleState,
	},
	VehicleSim
))

local WHEEL_DEFS = {
	{ name = "FL", front = true, left = true },
	{ name = "FR", front = true, left = false },
	{ name = "RL", front = false, left = true },
	{ name = "RR", front = false, left = false },
}

local function newWheelState(name: string): WheelState
	return {
		name = name,
		grounded = false,
		compression = 0,
		load = 0,
		slipAngleDeg = 0,
		saturated = false,
		locked = false,
		visualOmega = 0,
		steerDeg = 0,
		fx = 0,
		fy = 0,
	}
end

local function emptyState(wheels: { Wheel }): VehicleState
	local ws = {}
	for _, w in wheels do
		table.insert(ws, w.state)
	end
	return {
		speedMps = 0,
		speedKmh = 0,
		gear = 1,
		rpm = 0,
		throttle = 0,
		brake = 0,
		steer = 0,
		steerDeg = 0,
		steerLock = 1,
		lean = 0,
		driftAngleDeg = 0,
		yawRateDegPerSec = 0,
		spinCount = 0,
		spinProgressDeg = 0,
		twoWheelMode = "idle",
		rollDeg = 0,
		rollMarginDeg = 0,
		handbrake = false,
		driftAssist = 0,
		wheels = ws,
	}
end

local function isFinite(v: Vector3): boolean
	local m = v.Magnitude
	return m == m and m ~= math.huge
end

function VehicleSim.new(model: Model, config: Config): Sim
	local chassis = model.PrimaryPart :: BasePart
	local wheels: { Wheel } = {}
	for _, def in WHEEL_DEFS do
		local part = model:FindFirstChild("Wheel_" .. def.name) :: BasePart
		local weld = part:FindFirstChild("WheelWeld") :: Weld
		local attachment = chassis:FindFirstChild("Hardpoint_" .. def.name) :: Attachment
		table.insert(wheels, {
			name = def.name,
			front = def.front,
			left = def.left,
			attachment = attachment,
			part = part,
			weld = weld,
			compression = 0,
			spinAngle = 0,
			state = newWheelState(def.name),
		})
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { model }
	rayParams.IgnoreWater = true

	local self = setmetatable({
		config = config,
		model = model,
		chassis = chassis,
		vectorForce = chassis:FindFirstChild("SimForce") :: VectorForce,
		torque = chassis:FindFirstChild("SimTorque") :: Torque,
		rayParams = rayParams,
		wheels = wheels,
		drivetrain = Drivetrain.new(config.drivetrain),
		twoWheel = TwoWheel.new(),
		steerDeg = 0,
		comHeightM = 0.5,
		handbrakeLevel = 0,
		throwTail = 0,
		flickSign = 0,
		flickAge = 0,
		flickTimer = 0,
		lastFlatVel = Vector3.zero,
		pathRateDeg = 0,
		throw = Throw.new(),
		throttleHoldStraight = 0,
		throttleHoldOn = false,
		spinAccumDeg = 0,
		spinCount = 0,
		lastDriftDeg = 0,
		spinStraight = 0,
		lastState = emptyState(wheels),
	}, VehicleSim)
	return self
end

function VehicleSim.setConfig(self: Sim, config: Config)
	self.config = config
end

-- The seated character is welded into the assembly; keep it out of the rays.
function VehicleSim.setCharacter(self: Sim, character: Model?)
	self.rayParams.FilterDescendantsInstances = if character then { self.model, character } else { self.model }
end

function VehicleSim.step(self: Sim, input: InputState, dt: number): VehicleState
	local cfg = self.config
	local mps = cfg.units.metersPerStud
	local chassis = self.chassis
	local cf = chassis.CFrame
	local up, forward, right = cf.UpVector, cf.LookVector, cf.RightVector
	local comM = chassis.AssemblyCenterOfMass * mps
	local vel = chassis.AssemblyLinearVelocity * mps -- m/s
	local angVel = chassis.AssemblyAngularVelocity -- rad/s
	local mass = chassis.AssemblyMass -- kg by convention (plus the seated character)
	local g = cfg.units.gravity
	local speed = vel.Magnitude

	local totalForce = Vector3.zero -- N, world
	local totalTorque = Vector3.zero -- Nm, world, about the centre of mass

	local function applyAt(force: Vector3, pointM: Vector3)
		totalForce += force
		totalTorque += (pointM - comM):Cross(force)
	end

	-- 1. Gravity correction. workspace.Gravity is 196.2 studs/s²; the car
	--    should fall at cfg.units.gravity. Push up by the difference so every
	--    load, roll and tip number downstream is honest. See DESIGN.md.
	totalForce += Vector3.new(0, mass * (workspace.Gravity * mps - g), 0)

	-- 2. Steering with rate limits and drift assist.
	-- Assist is off while on two wheels: it would read the sideways creep as
	-- a slide and steer into it, which turns the car toward the grounded side
	-- and brings it down on its own. Balance is the lean axis; the steer the
	-- player holds up there is theirs, for correcting yaw.
	local twoWheelActive = TwoWheel.isActive(self.twoWheel)
	local assistGain = if twoWheelActive then 0 else cfg.steering.driftAssist
	local vLongBody = vel:Dot(forward)
	local vLatBody = vel:Dot(right)
	local driftAngleDeg = if speed > 1 then math.deg(math.atan2(vLatBody, vLongBody)) else 0
	-- Assist uses |vLong| so reversing does not read as a 180° drift.
	local assistAngleDeg = if speed > 1 then math.deg(math.atan2(vLatBody, math.abs(vLongBody))) else 0
	-- Past the fade the assist lets a spin be a spin instead of steering
	-- against it: a driver holding the lever through a Ta'geed wants to come
	-- round. Hands off, with no lever, is the opposite request, so the
	-- hands-off assist does not fade: lift and straighten always means
	-- "bring it back", whatever the angle.
	-- Throttle is the second permission for the throw, once the car is
	-- already sideways: gas past throwThrottleHold with the drift past
	-- throwThrottleHoldFromDeg keeps the controller alive with the lever
	-- out, so a slide started on the lever is held on the gas, with full
	-- rear grip and no lever drag. Throttle alone never starts one. Once
	-- on, it stays on through the straight moment of a transition: it
	-- only drops when the car has been under the gate for
	-- throwThrottleHoldGraceSeconds with the wheel centred, or the gas is
	-- lifted. Without that a flick on the gas died at zero.
	local gasOn = not twoWheelActive and input.throttle >= cfg.steering.throwThrottleHold
	local sidewaysNow = math.abs(driftAngleDeg) >= cfg.steering.throwThrottleHoldFromDeg
	if sidewaysNow or math.abs(input.steer) > 0.05 then
		self.throttleHoldStraight = 0
	else
		self.throttleHoldStraight += dt
	end
	if not gasOn then
		self.throttleHoldOn = false
	elseif sidewaysNow then
		self.throttleHoldOn = true
	elseif self.throttleHoldStraight >= cfg.steering.throwThrottleHoldGraceSeconds then
		self.throttleHoldOn = false
	end
	local throttleHold = self.throttleHoldOn
	-- Hands off the wheel, whatever the lever and the gas are doing, and
	-- the assist aligns the fronts with the velocity. Under a hold that is
	-- not a request to straighten (the controller holds the angle); it is
	-- what stops the fronts scrubbing 27 degrees off the path, which was
	-- most of the speed a held slide bled.
	local handsOff = not twoWheelActive and math.abs(input.steer) < cfg.steering.driftAssistHandsOffBelow
	if handsOff then
		assistGain = math.max(assistGain, cfg.steering.driftAssistHandsOff)
	else
		local a = math.abs(assistAngleDeg)
		local fade = 1 - math.clamp(
			(a - cfg.steering.driftAssistFadeStartDeg)
				/ math.max(cfg.steering.driftAssistFadeEndDeg - cfg.steering.driftAssistFadeStartDeg, 1),
			0,
			1
		)
		assistGain *= fade
	end
	-- Speed-sensitive lock, lifted again when the input is a correction or a
	-- deliberate throw (the handbrake). A throw keeps its relief for a tail
	-- after the lever is let go, so a 360 started with the handbrake does not
	-- lose its lock halfway round.
	-- A flick is the other deliberate throw: a hard steer one way followed
	-- quickly by a hard steer the other, the pendulum turn. A held turn never
	-- trips it, however fast the key was pressed, so the taper that keeps the
	-- car planted on a steady bend stays in force; only the reversal is read
	-- as "I want the tail out".
	local throwNow = math.max(self.handbrakeLevel, if throttleHold then 1 else 0)
	local fl = cfg.steering
	self.flickAge += dt
	local steerMag = math.abs(input.steer)
	if steerMag >= fl.flickFromLock then
		local sign = if input.steer > 0 then 1 else -1
		if self.flickSign ~= 0 and sign ~= self.flickSign and self.flickAge <= fl.flickWindowSeconds and fl.flickRelief > 0 then
			throwNow = math.max(throwNow, fl.flickRelief)
			-- The reversal also unloads the rear for a moment. The steering
			-- relief alone does not break a rear that out-grips the front;
			-- this is the weight transfer a real pendulum turn gets for free.
			self.flickTimer = fl.flickGripSeconds
		end
		if sign ~= self.flickSign then
			self.flickSign = sign
			self.flickAge = 0
		end
	end
	if throwNow > 0 then
		self.throwTail = 1
	elseif self.throwTail > 0 then
		self.throwTail = math.max(0, self.throwTail - dt / math.max(cfg.steering.throwReliefTailSeconds, 1e-3))
	end
	local throwing = math.max(throwNow, self.throwTail)
	self.flickTimer = math.max(0, self.flickTimer - dt)
	local flickCut = if self.flickTimer > 0 then cfg.steering.flickRearGripMultiplier else 1
	local lockFactor = Steering.lockFactor(cfg.steering, Units.mpsToKmh(speed), input.steer, assistAngleDeg, throwing)
	-- On two wheels the lock is scaled, and scaled again for a turn away
	-- from the low side, which is the one that flips the car.
	local steerScale = 1
	if twoWheelActive then
		steerScale = cfg.twoWheel.steerScale
		if input.steer * self.twoWheel.side < 0 then
			steerScale *= cfg.twoWheel.steerAwayScale
		end
	end
	local steerTarget = input.steer * cfg.steering.maxSteerDeg * lockFactor * steerScale
	local returning = math.abs(steerTarget) < math.abs(self.steerDeg) or steerTarget * self.steerDeg < 0
	local rate = if returning then cfg.steering.steerReturnDegPerSec else cfg.steering.steerSpeedDegPerSec
	self.steerDeg += math.clamp(steerTarget - self.steerDeg, -rate * dt, rate * dt)
	-- Drift angle + means velocity is right of heading (tail out left), so
	-- counter-steer is to the right: add a fraction of it. The assist is
	-- clamped to the full lock, not the tapered one, for the same reason the
	-- taper lifts for a correction.
	local effectiveSteerDeg = math.clamp(
		self.steerDeg + assistGain * assistAngleDeg,
		-cfg.steering.maxSteerDeg,
		cfg.steering.maxSteerDeg
	)

	-- 3. Raycasts and suspension.
	local rayLenM = Suspension.rayLengthM(cfg.suspension, cfg.body.wheelRadius)
	local contacts: { Contact } = {}
	local groundedLeft, groundedRight = 0, 0
	local groundLocalYSum, groundCount = 0, 0
	for _, wheel in self.wheels do
		local hpStuds = wheel.attachment.WorldPosition
		local hit = workspace:Raycast(hpStuds, -up * (rayLenM / mps), self.rayParams)
		local hitDistM = if hit then hit.Distance * mps else nil
		-- Two-wheel: the loaded side carries double weight; stiffen it.
		local stiffnessMult = 1
		if twoWheelActive and ((self.twoWheel.side > 0) == (not wheel.left)) then
			stiffnessMult = cfg.twoWheel.suspensionBias
		end
		local susp = Suspension.step(wheel.compression, hitDistM, cfg.suspension, cfg.body.wheelRadius, stiffnessMult, dt)
		wheel.compression = susp.compression
		local hpM = hpStuds * mps
		local contactM = if hit then hit.Position * mps else hpM - up * rayLenM
		local normal = if hit then hit.Normal else up
		if susp.grounded and susp.force > 0 then
			if wheel.left then
				groundedLeft += 1
			else
				groundedRight += 1
			end
			-- Body-frame contact height, for the two-wheel pendulum geometry.
			groundLocalYSum += cf:PointToObjectSpace(hit.Position).Y * mps
			groundCount += 1
		end
		local steerDeg = if wheel.front then effectiveSteerDeg else 0
		-- Positive steer = right = clockwise from above = negative rotation about up.
		local headingRaw = CFrame.fromAxisAngle(up, -math.rad(steerDeg)) * forward
		local heading = (headingRaw - normal * headingRaw:Dot(normal)).Unit
		local wRight = heading:Cross(normal) -- forward x up = right
		local vContact = vel + angVel:Cross(contactM - comM)
		table.insert(contacts, {
			wheel = wheel,
			hitDistM = hitDistM,
			susp = susp,
			hpM = hpM,
			contactM = contactM,
			normal = normal,
			heading = heading,
			right = wRight,
			vLong = vContact:Dot(heading),
			vLat = vContact:Dot(wRight),
			steerDeg = steerDeg,
		})
	end

	-- Anti-roll bars: only act when both wheels of an axle carry load.
	local function antiRoll(leftIdx: number, rightIdx: number, k: number)
		local l, r = contacts[leftIdx], contacts[rightIdx]
		if l.susp.force > 0 and r.susp.force > 0 then
			local d = Suspension.antiRoll(k, l.susp.compression, r.susp.compression)
			l.susp.force = math.max(l.susp.force + d, 0)
			r.susp.force = math.max(r.susp.force - d, 0)
		end
	end
	antiRoll(1, 2, cfg.suspension.antiRollFront)
	antiRoll(3, 4, cfg.suspension.antiRollRear)

	-- Handbrake level: on instantly, off over releaseSeconds so the rear's
	-- grip returns progressively rather than snapping the car straight.
	if input.handbrake then
		self.handbrakeLevel = 1
	elseif self.handbrakeLevel > 0 then
		self.handbrakeLevel = math.max(0, self.handbrakeLevel - dt / math.max(cfg.handbrake.releaseSeconds, 1e-3))
	end
	local hbLevel = self.handbrakeLevel

	-- 4. Drivetrain from rear wheel speed and last step's spin state.
	local rearWheelSpeed = (contacts[3].vLong + contacts[4].vLong) / 2
	local rearSpinning = self.wheels[3].state.saturated or self.wheels[4].state.saturated
	local drive = Drivetrain.step(
		self.drivetrain,
		cfg.drivetrain,
		cfg.body.wheelRadius,
		dt,
		input.throttle,
		input.brake,
		rearWheelSpeed,
		rearSpinning,
		-- Traction control only while the car is pointing where it is going,
		-- and never on two wheels: the airborne rear reads as spinning, and
		-- cutting the throttle there takes away the yaw that holds a natl up.
		math.abs(driftAngleDeg) < cfg.drivetrain.tractionControlMaxDriftDeg
			and self.handbrakeLevel <= 0
			and not twoWheelActive
	)

	-- Rim dig-in: on two wheels past rimGripStartDeg the tires are on their
	-- sidewalls and rims, which bite harder than tread. Without this the base
	-- slides out at atan(grip) and the car can never reach the static tip
	-- angle, so "ignore it and it falls" would be impossible on flat asphalt.
	local rollNow = math.deg(math.asin(math.clamp(-right.Y, -1, 1)))
	local rimGrip = 1
	if twoWheelActive or self.twoWheel.mode == "tipped" then
		local t = math.clamp((math.abs(rollNow) - cfg.twoWheel.rimGripStartDeg) / 10, 0, 1)
		rimGrip = 1 + cfg.twoWheel.rimGripBoost * t
	end

	-- 5. Tire forces at the contact patches, suspension forces at the hardpoints.
	for _, c in contacts do
		local w = c.wheel
		local brakeFade = math.clamp(math.abs(c.vLong) / cfg.drivetrain.brakeFadeMps, 0, 1)
		local brakeDir = -math.sign(c.vLong)
		local fxDemand = 0
		local gripMult = rimGrip
		if w.front then
			fxDemand = brakeDir * drive.brakePerFrontWheel * brakeFade
		else
			-- Differential: an open diff can only push this wheel as hard as
			-- the other rear can react, so drive here scales with the other
			-- wheel's load. diffLock blends toward a welded split.
			local other = if w.left then contacts[4] else contacts[3]
			local ratio = if c.susp.force > 1e-3 then math.clamp(other.susp.force / c.susp.force, 0, 1) else 1
			local diffShare = cfg.drivetrain.diffLock + (1 - cfg.drivetrain.diffLock) * ratio
			fxDemand = drive.drivePerRearWheel * diffShare
				+ brakeDir * (drive.brakePerRearWheel + drive.engineBrakePerRearWheel) * brakeFade
			gripMult *= flickCut
			if hbLevel > 0 then
				-- Handbrake cuts rear grip and drags the rear wheels; it must not stop the car.
				gripMult *= 1 + (cfg.handbrake.rearGripMultiplier - 1) * hbLevel
				fxDemand += brakeDir * cfg.handbrake.brakeForce / 2 * brakeFade * hbLevel
			end
		end
		local axle = if w.front then cfg.tires.front else cfg.tires.rear
		local out = Tire.compute(c.vLong, c.vLat, c.susp.force, axle, gripMult, fxDemand, cfg.tires.speedFadeMps)

		-- Tire force acts at ground level: lateral force x CoM height is the
		-- roll moment that loads the outside springs in a slide.
		applyAt(c.heading * out.fx + c.right * out.fy, c.contactM)
		-- Spring force acts along body up at the hardpoint.
		applyAt(up * c.susp.force, c.hpM)

		local ws = w.state
		ws.grounded = c.susp.grounded
		ws.compression = c.susp.compression
		ws.load = c.susp.force
		ws.slipAngleDeg = out.slipAngleDeg
		ws.saturated = out.saturated
		ws.locked = out.saturated and fxDemand * c.vLong < 0
		ws.steerDeg = c.steerDeg
		ws.fx = out.fx
		ws.fy = out.fy

		-- Visual wheel: sit at the ray hit (or full droop), steer, and roll.
		-- Forward rolling is a negative rotation about the lateral (+X) axis.
		-- A driven wheel that has broken loose winds up toward the speed the
		-- engine is turning it; a locked wheel stops. The physics does not
		-- integrate wheel spin, so this is the one place it is shown.
		local groundOmega = c.vLong / cfg.body.wheelRadius
		local targetOmega = groundOmega
		if ws.locked then
			targetOmega = 0
		elseif out.saturated and not w.front then
			local ratio = if drive.gear == -1 then -cfg.drivetrain.reverseRatio else cfg.drivetrain.gearRatios[drive.gear]
			local engineOmega = drive.rpm / (60 / (2 * math.pi)) / (ratio * cfg.drivetrain.finalDrive)
			targetOmega = if math.abs(engineOmega) > math.abs(groundOmega) then engineOmega else groundOmega
		end
		local spinUp = 1 - math.exp(-cfg.effects.wheelSpinUpRate * dt)
		ws.visualOmega += (targetOmega - ws.visualOmega) * spinUp
		w.spinAngle -= ws.visualOmega * dt
		local dropM = if c.hitDistM
			then math.min(c.hitDistM - cfg.body.wheelRadius, cfg.suspension.restLength)
			else cfg.suspension.restLength
		w.weld.C0 = CFrame.new(w.attachment.Position - Vector3.new(0, dropM / mps, 0))
			* CFrame.Angles(0, -math.rad(c.steerDeg), 0)
			* CFrame.Angles(w.spinAngle, 0, 0)
	end

	-- 6. Aero drag and rolling resistance at the centre of mass.
	if speed > 0.1 then
		local body = cfg.body
		local dragN = 0.5 * body.airDensity * body.dragCoefficient * body.frontalArea * speed * speed
		local rollN = body.rollingResistance * mass * g * math.clamp(speed, 0, 1) * (groundCount / 4)
		totalForce -= vel.Unit * (dragN + rollN)
	end

	-- 7. Two-wheel roll torque about the forward axis.
	local rollDeg = rollNow -- + = right side lower
	local rollRate = math.deg(angVel:Dot(forward)) -- same sign convention
	-- Pendulum geometry in the body frame: the centre of mass sits comHeightM
	-- above the contact line along body up and halfTrackM to the side of it.
	-- Measured in the body frame so the numbers stay constant as the car rolls.
	local comLocal = cf:PointToObjectSpace(chassis.AssemblyCenterOfMass) * mps
	if groundCount > 0 then
		self.comHeightM = comLocal.Y - groundLocalYSum / groundCount
	end
	local body = {
		massKg = mass,
		gravity = g,
		comHeightM = self.comHeightM,
		halfTrackM = cfg.body.trackWidth / 2 - self.twoWheel.side * comLocal.X,
	}
	local rollTorque = TwoWheel.step(
		self.twoWheel,
		cfg.twoWheel,
		body,
		input.twoWheel,
		input.leanLeft,
		input.leanRight,
		rollDeg,
		rollRate,
		groundedLeft,
		groundedRight,
		dt,
		Units.mpsToKmh(speed)
	)
	totalTorque += forward * rollTorque
	-- Yaw. + = turning right (clockwise from above), which is a negative
	-- rotation about body up.
	local yawRateDeg = -math.deg(angVel:Dot(up))
	-- The rate the path itself is turning, same sign, filtered. The drift
	-- angle only changes when the car yaws faster or slower than its
	-- velocity turns, so this is what the throw controller holds against.
	local flatVel = Vector3.new(vel.X, 0, vel.Z)
	local lastFlat = self.lastFlatVel
	self.lastFlatVel = flatVel
	if speed > 1 and lastFlat.Magnitude > 1e-3 and dt > 0 then
		local turned = -math.deg(math.atan2(lastFlat:Cross(flatVel).Y, lastFlat:Dot(flatVel)))
		local k = 1 - math.exp(-dt / math.max(cfg.steering.throwPathFilterSeconds, 1e-3))
		self.pathRateDeg += (turned / dt - self.pathRateDeg) * k
	else
		self.pathRateDeg = 0
	end
	-- The throw controller: see Throw.luau. Everything sideways that the
	-- tyres cannot do on their own (the 360, the held slide, the catch) is in
	-- there, and it is pure so it has its own spec.
	if not twoWheelActive then
		totalTorque -= up * Throw.step(self.throw, cfg.steering, {
			steer = input.steer,
			permission = throwNow,
			flick = self.flickTimer > 0,
			driftAngleDeg = driftAngleDeg,
			yawRateDeg = yawRateDeg,
			pathRateDeg = self.pathRateDeg,
			speedKmh = Units.mpsToKmh(speed),
		})
	end
	if twoWheelActive then
		-- Steady yaw damping while lifted, the driver's micro-corrections.
		totalTorque -= up * (cfg.twoWheel.yawDamping * math.deg(angVel:Dot(up)))
	end

	-- Spin counter (Ta'geed). A 360 is one full turn of the car relative to
	-- where it is going, so it is measured on the drift angle, unwrapped,
	-- not on yaw: yaw over-counts on a curving path and under-counts the
	-- angle built before the car was properly sideways. Counting starts
	-- when the drift passes spinSlipDeg, seeded with that angle so the
	-- travel is exact from straight, and keeps going through the brief
	-- straight moment at the end of one rotation so a 720 reads as two.
	-- Straight for spinResetSeconds clears it. Display only.
	local dDrift = driftAngleDeg - self.lastDriftDeg
	if dDrift > 180 then
		dDrift -= 360
	elseif dDrift < -180 then
		dDrift += 360
	end
	self.lastDriftDeg = driftAngleDeg
	local sideways = math.abs(driftAngleDeg) >= cfg.debug.spinSlipDeg
	if speed <= 1 then
		self.spinStraight = math.huge
	elseif sideways then
		if self.spinStraight >= cfg.debug.spinResetSeconds then
			self.spinAccumDeg = driftAngleDeg -- fresh spin: what it built so far
			self.spinCount = 0
		end
		self.spinStraight = 0
	else
		self.spinStraight += dt
	end
	if self.spinStraight < cfg.debug.spinResetSeconds then
		if sideways or self.spinStraight > 0 then
			self.spinAccumDeg += dDrift
		end
		if math.abs(self.spinAccumDeg) >= 360 then
			self.spinAccumDeg -= math.sign(self.spinAccumDeg) * 360
			self.spinCount += 1
		end
	else
		self.spinAccumDeg = 0
		self.spinCount = 0
	end

	-- 8. Write the actuators. Never let a NaN into the physics engine.
	if not isFinite(totalForce) or not isFinite(totalTorque) then
		warn("[VehicleSim] non-finite force, zeroing this step")
		totalForce = Vector3.zero
		totalTorque = Vector3.zero
	end
	self.vectorForce.Force = Units.forceNToSim(totalForce, mps)
	self.torque.Torque = Units.torqueNmToSim(totalTorque, mps)

	-- 9. State for the debug panel and camera.
	local st = self.lastState
	st.speedMps = speed
	st.speedKmh = Units.mpsToKmh(speed)
	st.gear = drive.gear
	st.rpm = drive.rpm
	st.throttle = input.throttle
	st.brake = input.brake
	st.steer = input.steer
	st.steerDeg = effectiveSteerDeg
	st.steerLock = lockFactor
	st.lean = input.lean
	st.driftAngleDeg = driftAngleDeg
	st.yawRateDegPerSec = yawRateDeg -- + = turning right
	st.spinCount = self.spinCount
	st.spinProgressDeg = math.abs(self.spinAccumDeg)
	st.twoWheelMode = self.twoWheel.mode
	st.rollDeg = rollDeg
	st.rollMarginDeg = self.twoWheel.marginDeg
	st.handbrake = input.handbrake
	st.driftAssist = cfg.steering.driftAssist
	return st
end

return VehicleSim
