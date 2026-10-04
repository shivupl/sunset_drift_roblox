--!strict
-- Rolls the car this client is driving back onto its wheels when it has
-- capsized and come to rest (CarConfig.autoFlip; the maths in shared
-- AutoFlip). VehicleController calls step() every PreSimulation before the
-- sim; while a flip is running it returns true and the sim does not step.
--
-- The driver's client owns the car, so moving it here replicates to everyone
-- like any other driving. Each step sets the car's frame along the flip and
-- zeroes its velocities and the sim's force and torque, so nothing fights the
-- roll; when it lands the sim takes over from rest.
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

function AutoFlip.reset()
	restFor = 0
	cooldown = 0
	flip = nil
	elapsed = 0
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

local function hold(model: Model, rig: VehicleRig.Handles, cf: CFrame)
	local chassis = rig.chassis
	model:PivotTo(cf * chassis.CFrame:ToObjectSpace(model:GetPivot()))
	chassis.AssemblyLinearVelocity = Vector3.zero
	chassis.AssemblyAngularVelocity = Vector3.zero
	rig.force.Force = Vector3.zero
	rig.torque.Torque = Vector3.zero
end

-- One PreSimulation step. True while a flip is running (skip the sim).
function AutoFlip.step(model: Model, rig: VehicleRig.Handles, cfg: Config, dt: number): boolean
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
		return false
	end
	if cooldown > 0 then
		cooldown -= dt
		return false
	end
	local chassis = rig.chassis
	local mps = cfg.units.metersPerStud
	local still = chassis.AssemblyLinearVelocity.Magnitude * mps < ac.restSpeedMps
		and math.deg(chassis.AssemblyAngularVelocity.Magnitude) < ac.restSpinDegPerSec
	if AutoFlipMath.tiltDeg(chassis.CFrame) > ac.tiltDeg and still then
		restFor += dt
		if restFor >= ac.settleSeconds then
			restFor = 0
			begin(model, rig, cfg)
			return flip ~= nil
		end
	else
		restFor = 0
	end
	return false
end

return AutoFlip
