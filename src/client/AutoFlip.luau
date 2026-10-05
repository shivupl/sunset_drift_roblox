--!strict
-- Gets the car this client is driving back onto its wheels when it has
-- capsized (CarConfig.autoFlip; the maths in shared AutoFlip).
-- VehicleController calls step() every PreSimulation before the sim.
--
-- A capsized car lying on something is rolled by a real torque about its
-- long axis (a Torque on the chassis, apart from the sim's): steering rolls it
-- back the short way (on its roof, over the side you steer to) and letting go
-- lets it fall back; untouched, after a moment at rest it rolls itself the
-- short way. Physics does the rest: it pivots on its edge and drops onto its
-- springs, and the sim keeps running throughout. Only if that fails (wedged
-- against a wall) does the scripted roll take over: then step() returns true
-- and the sim waits, as each step sets the car's frame along the roll and
-- zeroes its velocities and the sim's force and torque.
--
-- The driver's client owns the car, so all of it replicates to everyone like
-- any other driving.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AutoFlipMath = require(Shared.AutoFlip)
local VehicleRig = require(Shared.VehicleRig)
local CarConfig = require(Shared.CarConfig)

type Config = CarConfig.Config

local AutoFlip = {}

local restFor = 0 -- seconds the car has lain capsized and still
local cooldown = 0
local flip: AutoFlipMath.Flip? = nil
local elapsed = 0
-- Rolling it physically: "manual" while the driver steers, "auto" when it
-- rolls itself the short way (autoDir), for tryFor seconds so far.
local mode: "idle" | "manual" | "auto" = "idle"
local autoDir = 1
local tryFor = 0
local effort = 0 -- 0..1: the push builds up over rollRampSeconds each roll
local righting: Torque? = nil -- the rolling torque on the car's chassis

local TORQUE_NAME = "RightingTorque"

local function stopRolling()
	mode = "idle"
	tryFor = 0
	effort = 0
	if righting then
		righting.Torque = Vector3.zero
	end
end

function AutoFlip.reset()
	restFor = 0
	cooldown = 0
	flip = nil
	elapsed = 0
	stopRolling()
	righting = nil
end

function AutoFlip.isFlipping(): boolean
	return flip ~= nil
end

-- The car's outline in the chassis's own frame, studs: every visible part's
-- corners (shared AutoFlip.lowestY), body pieces included, so a tall cabin
-- or a mirror can't dig in, but the car still pivots on its real edge.
--
-- The wheels are the exception. Capsized, they hang at full droop; landing
-- those on the ground would set the car down on unloaded springs and it
-- would drop onto them (0.18 m at 1.6 m/s, Studio 2026-10-04). So the wheel
-- parts are left out and each tyre is put in where it sits with the car at
-- rest on its springs: the car lands at its rest height, already settled.
local function outline(model: Model, rig: VehicleRig.Handles, cfg: Config): { Vector3 }
	local chassis = rig.chassis
	local mps = cfg.units.metersPerStud
	local inv = chassis.CFrame:Inverse()
	local radius = cfg.body.wheelRadius / mps
	local hubs: { Vector3 } = {}
	for _, hub in rig.hubs do
		table.insert(hubs, hub.part.Position)
	end
	local function isWheel(part: BasePart): boolean
		for _, h in hubs do
			if (part.Position - h).Magnitude < radius * 1.3 then
				return true
			end
		end
		return false
	end
	local out: { Vector3 } = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 and not isWheel(part) then
			local h = part.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						table.insert(out, inv * (part.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)))
					end
				end
			end
		end
	end
	-- Each tyre at rest: its centre sits (restLength - static sag) below the
	-- hardpoint; its outline is the tyre's cylinder (12 points round it at
	-- both sidewalls).
	local drop = (cfg.suspension.restLength - VehicleRig.staticSagM(cfg)) / mps
	local halfW = cfg.body.wheelWidth / 2 / mps
	for _, origin in rig.rayOrigins do
		local c = origin.Position - Vector3.new(0, drop, 0)
		for k = 0, 11 do
			local a = k * math.pi / 6
			for _, sx in { -halfW, halfW } do
				table.insert(out, c + Vector3.new(sx, math.cos(a) * radius, math.sin(a) * radius))
			end
		end
	end
	return out
end

-- World Y of the ground under the car, ignoring the car and every character.
local function groundUnder(model: Model, at: Vector3): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { model }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(at + Vector3.new(0, 20, 0), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position.Y else nil
end

-- Whether a box (frame, size in studs) overlaps anything solid besides the
-- car and the players.
local function blocked(model: Model, cf: CFrame, size: Vector3): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { model }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	for _, part in workspace:GetPartBoundsInBox(cf, size, params) do
		if not part:IsA("Terrain") then
			return true
		end
	end
	return false
end

local function begin(model: Model, rig: VehicleRig.Handles, cfg: Config)
	local chassis = rig.chassis
	local mps = cfg.units.metersPerStud
	local ac = cfg.autoFlip
	local ground = groundUnder(model, chassis.Position)
	if not ground then
		return -- nothing under it (off the edge of the world): leave it to R
	end
	local points = outline(model, rig, cfg)
	local start = chassis.CFrame
	-- Upright at its rest height: its tyres (in their rest place) on the
	-- ground and its springs already carrying it, so it lands settled.
	local up = AutoFlipMath.upright(start, Vector3.new(start.X, 0, start.Z))
	local landY = math.max(ground + VehicleRig.restHeightM(cfg) / mps, ground - AutoFlipMath.lowestY(up.Rotation, points))
	local target = up + Vector3.new(0, landY, 0)
	-- Where it would stand must be clear (it may lie against a wall, a pillar
	-- or another car): try sliding the spot sideways, away from whatever is
	-- there, before giving up (R still resets it).
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in points do
		lo = lo:Min(p)
		hi = hi:Max(p)
	end
	local size = (hi - lo) - Vector3.new(0.1, 0.1, 0.1) / mps -- a touch inside, so the road itself never counts
	local centre = (lo + hi) / 2 + Vector3.new(0, 0.05 / mps, 0)
	local side = target.RightVector
	local found: CFrame? = nil
	for _, shift in ac.clearShiftsM do
		local tryCf = target + side * (shift / mps)
		-- The spot must be clear, and so must the way there: a wall between
		-- where it lies and a clear spot beyond it would have it rolled
		-- through the wall (Studio, 2026-10-04). Boxes every half metre
		-- along the slide, upright, a little lower (it is still rolling up).
		local clear = not blocked(model, tryCf * CFrame.new(centre), size)
		local steps = math.ceil(math.abs(shift) / 0.5)
		for k = 1, steps - 1 do
			if not clear then
				break
			end
			local mid = target + side * (shift * k / steps / mps)
			clear = not blocked(model, mid * CFrame.new(centre - Vector3.new(0, size.Y * 0.25, 0)), size * Vector3.new(1, 0.5, 1))
		end
		if clear then
			found = tryCf
			break
		end
	end
	if not found then
		return
	end
	target = found
	local turn = AutoFlipMath.turnDeg(start, target)
	-- The collision box is what rests on the ground; a mirror or a bumper
	-- lip can sit a little below it. The flip's floor starts from wherever
	-- the car's lowest point really is, so the first frame doesn't jump.
	local lowest = start.Y + AutoFlipMath.lowestY(start.Rotation, points)
	flip = {
		start = start,
		target = target,
		seconds = math.max(0.2, ac.flipSecondsPer90 * turn / 90),
		points = points,
		groundY = math.min(ground, lowest),
		clearance = ac.clearanceM / mps,
	}
	elapsed = 0
end

-- The rolling torque on this car's chassis, made the first time it's needed:
-- relative to the world, so it is set straight along the car's long axis.
local function torqueOn(rig: VehicleRig.Handles): Torque
	local t = righting
	if t and t.Parent == rig.chassis then
		return t
	end
	local found = rig.chassis:FindFirstChild(TORQUE_NAME)
	if found and found:IsA("Torque") then
		righting = found
		return found
	end
	local a = Instance.new("Attachment")
	a.Name = TORQUE_NAME
	a.Parent = rig.chassis
	local made = Instance.new("Torque")
	made.Name = TORQUE_NAME
	made.Attachment0 = a
	made.RelativeTo = Enum.ActuatorRelativeTo.World
	made.Torque = Vector3.zero
	made.Parent = rig.chassis
	righting = made
	return made
end

-- The car's size (studs, in its own frame), body and all, cached per car.
local extents: { [Model]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any
local function sizeOf(model: Model): Vector3
	local e = extents[model]
	if not e then
		e = model:GetExtentsSize()
		extents[model] = e
	end
	return e
end

-- Whether a capsized car is lying on something (not tumbling through the air
-- or sliding along on its roof): its centre near the ground, and slow. With
-- `settled`, also not still falling: a roll only starts once it has landed,
-- since a torque on a car dropping onto its side spun it in the air and it
-- landed past upright and went over (Studio, 2026-10-04). A roll under way
-- moves its centre up and down, so it isn't held to that.
local function resting(model: Model, rig: VehicleRig.Handles, cfg: Config, settled: boolean?): boolean
	local chassis = rig.chassis
	local mps = cfg.units.metersPerStud
	local ac = cfg.autoFlip
	local v = chassis.AssemblyLinearVelocity * mps
	if v.Magnitude > ac.rollMaxSpeedMps or (settled and math.abs(v.Y) > ac.rollMaxFallMps) then
		return false
	end
	local ground = groundUnder(model, chassis.Position)
	if not ground then
		return false
	end
	local size = sizeOf(model)
	local reach = math.sqrt(size.X * size.X + size.Y * size.Y) / 2 + ac.groundGapM / mps
	return chassis.Position.Y - ground <= reach
end

-- One step of rolling it: drives its roll rate about its long axis toward
-- `dir` (-1..1, +1 clockwise as seen from behind) times rollRateDegPerSec,
-- with a torque capped at rollTorqueG times what holds its weight at half
-- its height off its edge, building up over rollRampSeconds.
local function roll(model: Model, rig: VehicleRig.Handles, cfg: Config, dir: number, dt: number)
	local chassis = rig.chassis
	local mps = cfg.units.metersPerStud
	local ac = cfg.autoFlip
	effort = math.min(1, effort + dt / math.max(ac.rollRampSeconds, 1e-3))
	local look = chassis.CFrame.LookVector
	local mass = chassis.AssemblyMass -- kg: the rig's densities make Roblox mass units kilograms
	local size = sizeOf(model) * mps
	local inertia = mass * (size.X * size.X + size.Y * size.Y) / 12
	local cap = ac.rollTorqueG * mass * workspace.Gravity * mps * size.Y / 2 * effort
	local omega = chassis.AssemblyAngularVelocity:Dot(look)
	local tau = AutoFlipMath.rollTorque(inertia, omega, dir * math.rad(ac.rollRateDegPerSec), ac.rollGain, cap)
	-- N m to Roblox's units (Units.torqueNmToSim).
	torqueOn(rig).Torque = look * (tau / (mps * mps))
end

local function hold(model: Model, rig: VehicleRig.Handles, cf: CFrame)
	local chassis = rig.chassis
	model:PivotTo(cf * chassis.CFrame:ToObjectSpace(model:GetPivot()))
	chassis.AssemblyLinearVelocity = Vector3.zero
	chassis.AssemblyAngularVelocity = Vector3.zero
	rig.force.Force = Vector3.zero
	rig.torque.Torque = Vector3.zero
end

-- One PreSimulation step, with the driver's steer (-1..1) and how many wheels
-- the sim last had on the ground. True only while the scripted roll runs
-- (skip the sim).
function AutoFlip.step(model: Model, rig: VehicleRig.Handles, cfg: Config, dt: number, steer: number, wheelsDown: number): boolean
	local f = flip
	if f then
		elapsed += dt
		local p = math.min(1, elapsed / f.seconds)
		hold(model, rig, AutoFlipMath.frameAt(f, p))
		if p >= 1 then
			flip = nil
			restFor = 0
			cooldown = cfg.autoFlip.cooldownSeconds
		end
		return true
	end
	local ac = cfg.autoFlip
	if not ac.enabled then
		stopRolling()
		return false
	end
	if cooldown > 0 then
		cooldown -= dt
	end
	local chassis = rig.chassis
	local cf = chassis.CFrame
	local tilt = AutoFlipMath.tiltDeg(cf)
	local steering = math.abs(steer) > ac.steerDeadzone

	-- Rolling: carry on until it is upright enough to fall onto its wheels.
	if mode ~= "idle" then
		if tilt < ac.releaseTiltDeg or not resting(model, rig, cfg) then
			stopRolling()
			restFor = 0
		elseif steering then
			mode = "manual"
			roll(model, rig, cfg, AutoFlipMath.steerDir(cf, steer, ac.roofChoiceDeg), dt)
		elseif mode == "manual" then
			stopRolling() -- let go: it falls back, or rocks
		else
			tryFor += dt
			if tryFor > ac.giveUpSeconds then
				-- It can't roll where it lies: the scripted roll, if there is
				-- room for it (else it stays down and R resets it).
				stopRolling()
				restFor = 0
				if cooldown <= 0 then
					begin(model, rig, cfg)
					return flip ~= nil
				end
			else
				roll(model, rig, cfg, autoDir, dt)
			end
		end
		return false
	end

	-- Watching: capsized means well over, no wheel down, lying on something.
	if tilt <= ac.tiltDeg or wheelsDown > 0 or not resting(model, rig, cfg, true) then
		restFor = 0
		return false
	end
	if steering then
		mode = "manual"
		roll(model, rig, cfg, AutoFlipMath.steerDir(cf, steer, ac.roofChoiceDeg), dt)
		return false
	end
	local mps = cfg.units.metersPerStud
	local still = chassis.AssemblyLinearVelocity.Magnitude * mps < ac.restSpeedMps
		and math.deg(chassis.AssemblyAngularVelocity.Magnitude) < ac.restSpinDegPerSec
	if still and cooldown <= 0 then
		restFor += dt
		if restFor >= ac.settleSeconds then
			restFor = 0
			mode = "auto"
			tryFor = 0
			autoDir = AutoFlipMath.rightingDir(cf)
			roll(model, rig, cfg, autoDir, dt)
		end
	else
		restFor = 0
	end
	return false
end

return AutoFlip
