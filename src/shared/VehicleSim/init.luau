--!strict
-- Glue between Roblox and the pure physics modules. One instance per car.
-- step() raycasts each corner, computes every force in SI about the centre
-- of mass, writes one VectorForce and one Torque on the chassis, moves the
-- wheel hubs (which carry the body's wheel meshes), and returns a
-- VehicleState for the debug panel.
--
-- It only ever touches the Rig, found through VehicleRig.handles(); the
-- Body is visual and rides along on the hubs and the chassis.
--
-- Runs on whoever owns the assembly: the driving client, or the server for a
-- parked car (zero input) so it keeps sitting on its springs.
local Shared = script.Parent
local Types = require(Shared.Types)
local Units = require(Shared.Units)
local Curve = require(Shared.Curve)
local CarConfig = require(Shared.CarConfig)
local VehicleRig = require(Shared.VehicleRig)
local Steering = require(script.Steering)
local Suspension = require(script.Suspension)
local Tire = require(script.Tire)
local Wheel = require(script.Wheel)
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
	attachment: Attachment, -- the ray origin
	part: BasePart, -- the hub
	weld: Weld,
	compression: number,
	spinAngle: number,
	omega: number, -- rad/s, integrated by the slip model (Wheel.luau); unused by the legacy tyre
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
		slideHold: number, -- seconds the gearbox still treats the car as sliding
		throwTail: number,
		flickSign: number, -- sign of the last strong steer input, 0 none
		flickAge: number, -- seconds since that input
		flickTimer: number, -- seconds of rear grip cut left after a flick
		lastFlatVel: Vector3, -- last step's horizontal velocity, for the path's turn rate
		lastPosition: Vector3?, -- chassis position last step, studs, to spot a reset
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

local WHEEL_DEFS = VehicleRig.WHEELS

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
	local rig = VehicleRig.handles(model)
	local chassis = rig.chassis
	local wheels: { Wheel } = {}
	for _, def in WHEEL_DEFS do
		local hub = rig.hubs[def.name]
		table.insert(wheels, {
			name = def.name,
			front = def.front,
			left = def.left,
			attachment = rig.rayOrigins[def.name],
			part = hub.part,
			weld = hub.weld,
			compression = 0,
			spinAngle = 0,
			omega = 0,
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
		vectorForce = rig.force,
		torque = rig.torque,
		rayParams = rayParams,
		wheels = wheels,
		drivetrain = Drivetrain.new(config.drivetrain),
		twoWheel = TwoWheel.new(),
		steerDeg = 0,
		comHeightM = 0.5,
		handbrakeLevel = 0,
		slideHold = 0,
		throwTail = 0,
		flickSign = 0,
		flickAge = 0,
		flickTimer = 0,
		lastFlatVel = Vector3.zero,
		lastPosition = nil,
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

	-- A reset (the R key, the bay respawn, a fall catch) moves the car and
	-- zeroes its velocity, but the slip model's wheels would keep spinning
	-- at their old speed and drive the car off the spot. A jump far bigger
	-- than the car could have travelled this step is a reset: stop them.
	local position = chassis.Position
	local lastPosition = self.lastPosition
	self.lastPosition = position
	if lastPosition and dt > 0 then
		local moved = (position - lastPosition).Magnitude
		local couldMove = (chassis.AssemblyLinearVelocity.Magnitude + 60) * dt * 3 + 5
		if moved > couldMove then
			for _, w in self.wheels do
				w.omega = 0
			end
		end
	end

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
	-- The lever arms it too, so handing a slide from the lever to the gas
	-- never falls through the angle gate: a tap that settled at 19
	-- degrees straightened the moment the lever came out. Once on it
	-- keeps down to throwThrottleHoldKeepDeg, a lower bar than starting.
	local gasOn = not twoWheelActive and input.throttle >= cfg.steering.throwThrottleHold
	local sidewaysNow = math.abs(driftAngleDeg) >= cfg.steering.throwThrottleHoldFromDeg
	local keepNow = math.abs(driftAngleDeg) >= cfg.steering.throwThrottleHoldKeepDeg
	if keepNow or math.abs(input.steer) > 0.05 then
		self.throttleHoldStraight = 0
	else
		self.throttleHoldStraight += dt
	end
	if not gasOn then
		self.throttleHoldOn = false
	elseif sidewaysNow or self.handbrakeLevel > 0 then
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
		-- The age counts from the last moment the wheel was hard over in
		-- that direction, not from when it first went there. It used to
		-- reset only on a change of direction, so after any hard right (a
		-- lane change, a 360) a later right-left flick found a stale age and
		-- never tripped: measured as a flick that rotated 4 degrees instead
		-- of 76 whenever the previous hard steer had been the same way.
		self.flickSign = sign
		self.flickAge = 0
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
		-- Just after a two-wheel landing the dampers run soft, so the drop
		-- rocks the car on its springs (measured with full damping: 1 degree
		-- past level and dead in 0.3 s).
		local dampingMult = if self.twoWheel.touchdown > 0 then cfg.twoWheel.touchdownDampingScale else 1
		local susp = Suspension.step(wheel.compression, hitDistM, cfg.suspension, cfg.body.wheelRadius, stiffnessMult, dt, dampingMult)
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

	-- 4. Drivetrain from rear wheel speed and last step's spin state. With
	-- the slip model the engine turns with the rear wheels' own spin.
	local slipCfg = cfg.tires.slipModel
	local slipModel = slipCfg ~= nil and slipCfg.enabled
	local rearWheelSpeed = (contacts[3].vLong + contacts[4].vLong) / 2
	local rearSpinning = self.wheels[3].state.saturated or self.wheels[4].state.saturated
	local rearSpinSpeed: number? = if slipModel then (self.wheels[3].omega + self.wheels[4].omega) / 2 * cfg.body.wheelRadius else nil
	-- Traction control only while the car is pointing where it is going,
	-- and never on two wheels: the airborne rear reads as spinning, and
	-- cutting the throttle there takes away the yaw that holds a natl up.
	local tractionAllowed = math.abs(driftAngleDeg) < cfg.drivetrain.tractionControlMaxDriftDeg
		and self.handbrakeLevel <= 0
		and not twoWheelActive
	-- Launch control, slip model only. The wheels are real now, so rather
	-- than wait for a spin and cut the throttle back (the loop never goes
	-- under its 0.7 floor, and full launch torque is about twice what the
	-- rears can take), the throttle is capped at the torque the rear tyres
	-- can put down right now: their load, grip, load sensitivity and drive
	-- grip at the peak slip, through this gear. The wheels sit just under
	-- the peak instead of spinning past it onto the sliding floor.
	local throttle = input.throttle
	if slipModel and tractionAllowed and self.drivetrain.gear >= 1 and Units.mpsToKmh(speed) < cfg.drivetrain.tractionControlBelowKmh then
		local sc = slipCfg :: Wheel.SlipConfig
		local rearAxle = cfg.tires.rear
		local staticLoad = mass * g / 4
		local wheelCap = math.huge
		for i = 3, 4 do
			local load = contacts[i].susp.force
			wheelCap = math.min(wheelCap, load * rearAxle.grip * Wheel.loadFactor(sc, load, staticLoad) * (rearAxle.longitudinalGrip or 1))
		end
		local overall = cfg.drivetrain.gearRatios[self.drivetrain.gear] * cfg.drivetrain.finalDrive
		local r = cfg.body.wheelRadius
		-- The drive also has to spin the wheels and the engine up with the
		-- car. In first gear the crank's inertia through the gearing is ten
		-- times a wheel's, and leaving it out capped the launch 18% short:
		-- no wheelspin, and 0-100 slower than the spin-and-cut loop.
		local tyreForce = wheelCap * sc.launchGripUse
		local wheelInertia = sc.wheelInertia + 0.5 * sc.engineInertia * overall * overall
		local carAccel = 2 * tyreForce / mass
		local wheelTorque = tyreForce * r + wheelInertia * carAccel / r
		local crankCap = wheelTorque * 2 / (overall * cfg.drivetrain.drivelineEfficiency)
		local curveTorque = Curve.lookup(cfg.drivetrain.torqueCurve, self.drivetrain.rpm)
		if curveTorque > 0 then
			throttle = math.min(throttle, crankCap / curveTorque)
		end
	end
	-- The gearbox's idea of a slide. It holds for slideShiftHoldSeconds after
	-- the angle drops, because a transition swings the angle through zero
	-- and the box hunted 3>4>3>2 in a chain.
	if math.abs(driftAngleDeg) >= cfg.drivetrain.slideShiftFromDeg and Units.mpsToKmh(speed) >= cfg.drivetrain.slideShiftMinKmh then
		self.slideHold = cfg.drivetrain.slideShiftHoldSeconds
	else
		self.slideHold = math.max(0, self.slideHold - dt)
	end
	local drive = Drivetrain.step(
		self.drivetrain,
		cfg.drivetrain,
		cfg.body.wheelRadius,
		dt,
		throttle,
		input.brake,
		rearWheelSpeed,
		rearSpinning,
		tractionAllowed,
		rearSpinSpeed,
		self.slideHold > 0
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
	-- Along the way, how hard the tyres' lateral forces drag against the
	-- velocity (scrub) and what all tyre forces do along it (net), for the
	-- slide momentum relief after the loop.
	local vHat = if speed > 1 then vel.Unit else Vector3.zero
	local scrubAlong, tireAlong = 0, 0
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
		local out: Tire.Output
		if slipModel then
			-- The wheel spins. Drive, brakes, engine braking and the lever are
			-- torques on it; the tyre force follows from how its spin and the
			-- patch's sideways motion compare with the road. The legacy
			-- handbrake grip cut is replaced by locking the wheel, and any
			-- that is left is handbrakeGripCut.
			local sc = slipCfg :: Wheel.SlipConfig
			local r = cfg.body.wheelRadius
			local driveTorque, brakeTorque = 0, 0
			local inertia = sc.wheelInertia
			local wheelGrip = rimGrip
			if w.front then
				brakeTorque = drive.brakePerFrontWheel * r
			else
				local other = if w.left then contacts[4] else contacts[3]
				local ratio = if c.susp.force > 1e-3 then math.clamp(other.susp.force / c.susp.force, 0, 1) else 1
				local diffShare = cfg.drivetrain.diffLock + (1 - cfg.drivetrain.diffLock) * ratio
				driveTorque = drive.drivePerRearWheel * diffShare * r
				brakeTorque = (drive.brakePerRearWheel + drive.engineBrakePerRearWheel) * r + sc.handbrakeTorque * hbLevel
				local gearRatio = if drive.gear == -1 then cfg.drivetrain.reverseRatio else cfg.drivetrain.gearRatios[drive.gear]
				local overall = gearRatio * cfg.drivetrain.finalDrive
				inertia += 0.5 * sc.engineInertia * overall * overall
				if self.flickTimer > 0 then
					wheelGrip *= sc.flickRearGripMultiplier
				end
				if hbLevel > 0 then
					wheelGrip *= 1 + (sc.handbrakeGripCut - 1) * hbLevel
				end
			end
			local staticLoad = mass * g / 4
			local fMax = c.susp.force * axle.grip * wheelGrip * Wheel.loadFactor(sc, c.susp.force, staticLoad)
			local res = Wheel.step(sc, axle, w.omega, c.vLong, c.vLat, r, fMax, inertia, driveTorque, brakeTorque, dt)
			w.omega = res.omega
			local fade = math.clamp(math.sqrt(c.vLong * c.vLong + c.vLat * c.vLat) / cfg.tires.speedFadeMps, 0, 1)
			out = {
				fx = res.fx,
				fy = res.fy * fade,
				slipAngleDeg = res.slipAngleDeg,
				-- Spinning or locked: past half again the peak slip ratio.
				saturated = math.abs(res.slipRatio) > sc.peakSlipRatio * 1.5,
			}
			fxDemand = if res.slipRatio < 0 then -1 else 1 -- only its sign is read below, for "locked"
		else
			out = Tire.compute(c.vLong, c.vLat, c.susp.force, axle, gripMult, fxDemand, cfg.tires.speedFadeMps)
		end

		-- Tire force acts at ground level: lateral force x CoM height is the
		-- roll moment that loads the outside springs in a slide.
		local tireForce = c.heading * out.fx + c.right * out.fy
		applyAt(tireForce, c.contactM)
		scrubAlong += math.min(0, (c.right * out.fy):Dot(vHat))
		tireAlong += tireForce:Dot(vHat)
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

		-- Hub: sit at the ray hit (or full droop), steer, and roll. The body's
		-- wheel meshes are welded to it.
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
		if slipModel then
			-- The wheel's own spin is the real thing to show.
			ws.visualOmega = w.omega
		end
		w.spinAngle -= ws.visualOmega * dt
		-- Travel is the suspension's own compression, so the wheel moves in
		-- the arch exactly as the spring does: full droop in the air, never
		-- past full bump (the bump stop takes the rest, and the arches are
		-- cut for travel). WheelVisuals does the same for cars this client
		-- does not simulate.
		local dropM = cfg.suspension.restLength - c.susp.compression
		w.weld.C0 = CFrame.new(w.attachment.Position - Vector3.new(0, dropM / mps, 0))
			* CFrame.Angles(0, -math.rad(c.steerDeg), 0)
			* CFrame.Angles(w.spinAngle, 0, 0)
	end

	-- 5b. Slide momentum: hand back part of the scrub while sideways, at the
	-- centre of mass so no yaw moment changes. Capped so the tyres alone
	-- never push the car along faster: a slide can hold its speed on the
	-- gas, it cannot gain it. See Tire.scrubRelief.
	if speed > 1 and scrubAlong < 0 and not twoWheelActive then
		local momentum = cfg.tires.slideMomentum
		if slipModel then
			local sc = slipCfg :: Wheel.SlipConfig
			momentum = table.clone(momentum)
			momentum.slideRelief = sc.slideRelief
			momentum.leverRelief = sc.leverRelief
		end
		local relief = Tire.scrubRelief(momentum, driftAngleDeg, Units.mpsToKmh(speed), hbLevel)
		local give = math.min(-scrubAlong * relief, math.max(0, -tireAlong))
		if give > 0 then
			totalForce += vHat * give
		end
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
