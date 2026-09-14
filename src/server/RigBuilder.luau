--!strict
-- Builds a car's Rig: every physics part and nothing you are meant to see.
-- Numbers only, from the car's config (VehicleRig.configFor), so every car
-- gets the same construction and the sim finds the same names on each.
--
-- One rigid assembly: Chassis (the collidable box, PrimaryPart), Ballast
-- (a hidden dense box that places the centre of mass), four massless hubs on
-- Welds the sim moves every frame, a VehicleSeat, the ray origin and mount
-- Attachments, one VectorForce and one Torque. Roblox mass units are kg:
-- densities are set so the assembly mass equals massKg.
--
-- Everything is invisible unless spawn.showRig is on, when the box, the
-- hubs and the seat show translucent over the body.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared.CarConfig)
local VehicleRig = require(Shared.VehicleRig)

type Config = CarConfig.Config

local RigBuilder = {}

local HUB_STUDS = 0.4

local function inert(p: BasePart)
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

-- The entry for the seat and the name, cfg (already merged and scaled) for everything else.
function RigBuilder.build(cfg: Config, entry: VehicleRig.CarEntry, name: string): Model
	local mps = cfg.units.metersPerStud
	local function s(m: number): number
		return m / mps
	end
	local body = cfg.body
	local L, H, W = s(body.bodySize[1]), s(body.bodySize[2]), s(body.bodySize[3])
	local show = cfg.spawn.showRig == true
	local ghost = if show then 0.6 else 1

	local model = Instance.new("Model")
	model.Name = name
	-- A car streams to every client whole and always: a freshly spawned car
	-- is driven the moment its player is seated, and a client handed a car
	-- whose chassis has not arrived yet cannot drive it.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local rig = Instance.new("Model")
	rig.Name = VehicleRig.RIG
	rig.Parent = model

	local chassis = Instance.new("Part")
	chassis.Name = VehicleRig.CHASSIS
	chassis.Size = Vector3.new(W, H, L)
	chassis.Color = Color3.fromRGB(80, 200, 255)
	chassis.Material = Enum.Material.SmoothPlastic
	chassis.Transparency = ghost
	chassis.CastShadow = false
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	local shellMass = body.massKg * body.shellMassFraction
	chassis.CustomPhysicalProperties = PhysicalProperties.new(shellMass / (W * H * L), 0.3, 0.05)
	chassis.Anchored = true
	chassis.Parent = rig
	model.PrimaryPart = chassis

	-- Ballast: places the assembly centre of mass at body.centerOfMassOffset.
	-- CoM = (shell*0 + ballast*p) / total  =>  p = offset * total / ballast
	local ballastMass = body.massKg - shellMass
	local off = body.centerOfMassOffset
	local ballastPosM = Vector3.new(off[1], off[2], -off[3]) * (body.massKg / ballastMass)
	local side = 3 -- studs; Roblox density max is 100
	while ballastMass / (side * side * side) > 100 do
		side += 1
	end
	local ballast = Instance.new("Part")
	ballast.Name = VehicleRig.BALLAST
	ballast.Size = Vector3.new(side, side, side)
	ballast.Transparency = 1
	ballast.CanCollide = false
	ballast.CanQuery = false
	ballast.CanTouch = false
	ballast.CastShadow = false
	ballast.CustomPhysicalProperties = PhysicalProperties.new(ballastMass / (side * side * side), 0, 0)
	ballast.CFrame = chassis.CFrame * CFrame.new(ballastPosM / mps)
	ballast.Parent = rig
	local ballastWeld = Instance.new("WeldConstraint")
	ballastWeld.Part0 = chassis
	ballastWeld.Part1 = ballast
	ballastWeld.Parent = ballast

	-- Where the body is mounted: the car-space origin, on the ground under
	-- the box centre with the car at rest.
	local bodyMount = Instance.new("Attachment")
	bodyMount.Name = VehicleRig.BODY_MOUNT
	bodyMount.Position = VehicleRig.bodyMountM(cfg) / mps
	bodyMount.Parent = chassis

	-- Plate mounts: where the plate system (and for now BodyBuilder's
	-- placeholder plates) puts a car's number plates.
	for _, pair in { { "front", VehicleRig.PLATE_FRONT }, { "rear", VehicleRig.PLATE_REAR } } do
		local which, name = pair[1], pair[2]
		local cf = VehicleRig.plateCFrame(cfg, entry, which :: any)
		if cf then
			local plate = Instance.new("Attachment")
			plate.Name = name
			plate.CFrame = cf
			plate.Parent = chassis
		end
	end

	-- Ray origins and hubs. A hub starts at full droop; the sim moves it to
	-- the ground, steers it and spins it through WheelWeld.C0 every frame.
	for _, w in VehicleRig.WHEELS do
		local rayOrigin = Instance.new("Attachment")
		rayOrigin.Name = VehicleRig.rayOriginName(w.name)
		rayOrigin.Position = VehicleRig.rayOriginM(cfg, w) / mps
		rayOrigin.Parent = chassis

		local hubOffset = VehicleRig.hubM(cfg, w, cfg.suspension.restLength) / mps
		local hub = Instance.new("Part")
		hub.Name = VehicleRig.hubName(w.name)
		hub.Size = Vector3.new(HUB_STUDS, HUB_STUDS, HUB_STUDS)
		hub.Color = Color3.fromRGB(255, 170, 40)
		hub.Material = Enum.Material.Neon
		hub.Transparency = ghost
		inert(hub)
		hub.CFrame = chassis.CFrame * CFrame.new(hubOffset)
		hub.Parent = rig

		local mount = Instance.new("Attachment")
		mount.Name = VehicleRig.WHEEL_MOUNT
		mount.Parent = hub

		local weld = Instance.new("Weld")
		weld.Name = VehicleRig.WHEEL_WELD
		weld.Part0 = chassis
		weld.Part1 = hub
		weld.C0 = CFrame.new(hubOffset)
		weld.C1 = CFrame.new()
		weld.Parent = hub
	end

	-- Seat (inside the body; entered via ProximityPrompt, not by touching)
	local seatM = VehicleRig.seatM(entry)
	local seat = Instance.new("VehicleSeat")
	seat.Name = VehicleRig.SEAT
	seat.Size = Vector3.new(2, 1, 2)
	seat.Transparency = ghost
	seat.Color = Color3.fromRGB(60, 60, 60)
	seat.CanCollide = false
	seat.CanQuery = false
	seat.CanTouch = false
	seat.Massless = true
	seat.CastShadow = false
	seat.MaxSpeed = 0 -- disable the built-in VehicleSeat motor
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.HeadsUpDisplay = false
	seat.CFrame = chassis.CFrame * CFrame.new(seatM / mps)
	seat.Parent = rig
	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0 = chassis
	seatWeld.Part1 = seat
	seatWeld.Parent = seat

	-- Force actuators the sim writes to
	local center = Instance.new("Attachment")
	center.Name = VehicleRig.CENTER
	center.Parent = chassis

	local vf = Instance.new("VectorForce")
	vf.Name = VehicleRig.FORCE
	vf.Attachment0 = center
	vf.ApplyAtCenterOfMass = true
	vf.RelativeTo = Enum.ActuatorRelativeTo.World
	vf.Force = Vector3.zero
	vf.Parent = chassis

	local tq = Instance.new("Torque")
	tq.Name = VehicleRig.TORQUE
	tq.Attachment0 = center
	tq.RelativeTo = Enum.ActuatorRelativeTo.World
	tq.Torque = Vector3.zero
	tq.Parent = chassis

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = VehicleRig.PROMPT
	prompt.ActionText = "Enter car"
	prompt.ObjectText = entry.displayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = chassis

	return model
end

return RigBuilder
