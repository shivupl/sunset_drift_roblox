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
local Suspension = require(script.Suspension)
local Tire = require(script.Tire)
local Drivetrain = require(script.Drivetrain)
local TwoWheel = require(script.TwoWheel)

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
		lean = 0,
		driftAngleDeg = 0,
		yawRateDegPerSec = 0,
		twoWheelMode = "idle",
		rollDeg = 0,
		rollMarginDeg = 0,
		handbrake = false,
		clutchKick = false,
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
	local steerTarget = input.steer * cfg.steering.maxSteerDeg
	local returning = math.abs(steerTarget) < math.abs(self.steerDeg) or steerTarget * self.steerDeg < 0
	local rate = if returning then cfg.steering.steerReturnDegPerSec else cfg.steering.steerSpeedDegPerSec
	self.steerDeg += math.clamp(steerTarget - self.steerDeg, -rate * dt, rate * dt)
	-- Drift angle + means velocity is right of heading (tail out left), so
	-- counter-steer is to the right: add a fraction of it.
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

	-- 4. Drivetrain from rear wheel speed and last step's spin state.
	local rearWheelSpeed = (contacts[3].vLong + contacts[4].vLong) / 2
	local rearSpinning = self.wheels[3].state.saturated or self.wheels[4].state.saturated
	local drive = Drivetrain.step(
		self.drivetrain,
		cfg.drivetrain,
		cfg.clutchKick,
		cfg.body.wheelRadius,
		dt,
		input.throttle,
		input.brake,
		input.clutchKick,
		rearWheelSpeed,
		rearSpinning
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
			fxDemand = drive.drivePerRearWheel
				+ brakeDir * (drive.brakePerRearWheel + drive.engineBrakePerRearWheel) * brakeFade
			if input.handbrake then
				-- Handbrake cuts rear grip and drags the rear wheels; it must not stop the car.
				gripMult *= cfg.handbrake.rearGripMultiplier
				fxDemand += brakeDir * cfg.handbrake.brakeForce / 2 * brakeFade
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
		ws.steerDeg = c.steerDeg
		ws.fx = out.fx
		ws.fy = out.fy

		-- Visual wheel: sit at the ray hit (or full droop), steer, and roll.
		-- Forward rolling is a negative rotation about the lateral (+X) axis.
		w.spinAngle -= c.vLong / cfg.body.wheelRadius * dt
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
		input.lean,
		rollDeg,
		rollRate,
		groundedLeft,
		groundedRight,
		dt
	)
	totalTorque += forward * rollTorque

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
	st.lean = input.lean
	st.driftAngleDeg = driftAngleDeg
	st.yawRateDegPerSec = -math.deg(angVel:Dot(up)) -- + = turning right
	st.twoWheelMode = self.twoWheel.mode
	st.rollDeg = rollDeg
	st.rollMarginDeg = self.twoWheel.marginDeg
	st.handbrake = input.handbrake
	st.clutchKick = self.drivetrain.kickTimer > 0
	st.driftAssist = cfg.steering.driftAssist
	return st
end

return VehicleSim
