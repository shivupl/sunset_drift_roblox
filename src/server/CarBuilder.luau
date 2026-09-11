--!strict
-- Builds the placeholder sedan from CarConfig dimensions.
-- One rigid assembly: Chassis (collidable box, the PrimaryPart), Ballast
-- (hidden dense box that places the centre of mass), four massless
-- non-colliding wheel cylinders on Welds that the sim repositions every frame,
-- a VehicleSeat, hardpoint Attachments, one VectorForce and one Torque.
-- Roblox mass units == kg: densities are chosen so the assembly mass equals massKg.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared.CarConfig)

type Config = CarConfig.Config

local CarBuilder = {}

local WHEELS = {
	{ name = "FL", x = -1, z = -1 },
	{ name = "FR", x = 1, z = -1 },
	{ name = "RL", x = -1, z = 1 },
	{ name = "RR", x = 1, z = 1 },
}

-- Hardpoint position in chassis-local metres for a wheel.
function CarBuilder.hardpointLocalM(config: Config, xSign: number, zSign: number): Vector3
	local body = config.body
	return Vector3.new(
		xSign * body.trackWidth / 2,
		-body.bodySize[2] / 2 + config.suspension.restLength,
		zSign * body.wheelbase / 2 -- front is -Z
	)
end

function CarBuilder.build(config: Config, name: string): Model
	local mps = config.units.metersPerStud
	local function s(m: number): number
		return m / mps
	end
	local body = config.body
	local L, H, W = s(body.bodySize[1]), s(body.bodySize[2]), s(body.bodySize[3])

	local model = Instance.new("Model")
	model.Name = name

	-- Chassis shell
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(W, H, L)
	chassis.Color = Color3.fromRGB(230, 230, 235)
	chassis.Material = Enum.Material.SmoothPlastic
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	local shellMass = body.massKg * body.shellMassFraction
	chassis.CustomPhysicalProperties = PhysicalProperties.new(shellMass / (W * H * L), 0.3, 0.05)
	chassis.Anchored = true
	chassis.Parent = model
	model.PrimaryPart = chassis

	-- A stripe so heading is obvious in tests
	local hood = Instance.new("Part")
	hood.Name = "HoodStripe"
	hood.Size = Vector3.new(W * 0.3, 0.2, L * 0.3)
	hood.Color = Color3.fromRGB(200, 40, 40)
	hood.Material = Enum.Material.SmoothPlastic
	hood.Massless = true
	hood.CanCollide = false
	hood.CanQuery = false
	hood.CanTouch = false
	hood.CFrame = chassis.CFrame * CFrame.new(0, H / 2 + 0.1, -L * 0.3)
	hood.Parent = model
	local hoodWeld = Instance.new("WeldConstraint")
	hoodWeld.Part0 = chassis
	hoodWeld.Part1 = hood
	hoodWeld.Parent = hood

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
	ballast.Name = "Ballast"
	ballast.Size = Vector3.new(side, side, side)
	ballast.Transparency = 1
	ballast.CanCollide = false
	ballast.CanQuery = false
	ballast.CanTouch = false
	ballast.CustomPhysicalProperties = PhysicalProperties.new(ballastMass / (side * side * side), 0, 0)
	ballast.CFrame = chassis.CFrame * CFrame.new(ballastPosM / mps)
	ballast.Parent = model
	local ballastWeld = Instance.new("WeldConstraint")
	ballastWeld.Part0 = chassis
	ballastWeld.Part1 = ballast
	ballastWeld.Parent = ballast

	-- Wheels and hardpoints
	local r = s(body.wheelRadius)
	for _, w in WHEELS do
		local hpM = CarBuilder.hardpointLocalM(config, w.x, w.z)
		local hp = hpM / mps

		local att = Instance.new("Attachment")
		att.Name = "Hardpoint_" .. w.name
		att.Position = hp
		att.Parent = chassis

		local wheel = Instance.new("Part")
		wheel.Name = "Wheel_" .. w.name
		wheel.Shape = Enum.PartType.Cylinder -- axis along X == car lateral axis
		wheel.Size = Vector3.new(s(body.wheelWidth), r * 2, r * 2)
		wheel.Color = Color3.fromRGB(30, 30, 30)
		wheel.Material = Enum.Material.Rubber
		wheel.Massless = true
		wheel.CanCollide = false
		wheel.CanQuery = false
		wheel.CanTouch = false
		wheel.CFrame = chassis.CFrame * CFrame.new(hp - Vector3.new(0, s(config.suspension.restLength), 0))
		wheel.Parent = model

		local weld = Instance.new("Weld")
		weld.Name = "WheelWeld"
		weld.Part0 = chassis
		weld.Part1 = wheel
		weld.C0 = CFrame.new(hp - Vector3.new(0, s(config.suspension.restLength), 0))
		weld.C1 = CFrame.new()
		weld.Parent = wheel
	end

	-- Seat (inside the body; entered via ProximityPrompt, not by touching)
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.Transparency = 0.6
	seat.Color = Color3.fromRGB(60, 60, 60)
	seat.CanCollide = false
	seat.CanQuery = false
	seat.Massless = true
	seat.MaxSpeed = 0 -- disable the built-in VehicleSeat motor
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.HeadsUpDisplay = false
	seat.CFrame = chassis.CFrame * CFrame.new(-s(0.4), 0, -s(0.2))
	seat.Parent = model
	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0 = chassis
	seatWeld.Part1 = seat
	seatWeld.Parent = seat

	-- Force actuators the sim writes to
	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Parent = chassis

	local vf = Instance.new("VectorForce")
	vf.Name = "SimForce"
	vf.Attachment0 = center
	vf.ApplyAtCenterOfMass = true
	vf.RelativeTo = Enum.ActuatorRelativeTo.World
	vf.Force = Vector3.zero
	vf.Parent = chassis

	local tq = Instance.new("Torque")
	tq.Name = "SimTorque"
	tq.Attachment0 = center
	tq.RelativeTo = Enum.ActuatorRelativeTo.World
	tq.Torque = Vector3.zero
	tq.Parent = chassis

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterPrompt"
	prompt.ActionText = "Enter car"
	prompt.ObjectText = "Sedan"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = chassis

	return model
end

return CarBuilder
