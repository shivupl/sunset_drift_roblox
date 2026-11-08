--!strict
-- Turns the steering wheel in every car with one (CarCockpits) as its
-- front wheels turn: this client's own car, whose hubs the sim steers, and
-- everyone else's, whose hubs WheelVisuals steers, so a wheel seen through
-- another car's window turns too. The owner, 2026-11-07: "the steering
-- wheel moving also in first person".
--
-- The front hubs' angle over steering.maxSteerDeg, times the wheel turn
-- picked in SETTINGS (camera.firstPerson.wheelTurns, the LocalPlayer
-- attribute WheelTurn), about the steering column. Following the tyres
-- rather than the stick means the wheel counter-steers in a slide exactly
-- as they do, which is what a driver's hands do.
--
-- A body's pieces are held by WeldConstraints (BodyBuilder); a wheel piece's
-- is swapped once for a Weld whose C0 can turn. Bodies are built on each
-- client and do not replicate, so neither does this.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleRig = require(Shared:WaitForChild("VehicleRig"))
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local CarCockpits = require(Shared:WaitForChild("CarCockpits"))

local SteeringWheels = {}

local ATTRIBUTE = "WheelTurn"
SteeringWheels.ATTRIBUTE = ATTRIBUTE

export type Turn = { id: string, name: string, deg: number }

type Rigged = {
	body: Instance,
	handles: VehicleRig.Handles,
	maxSteerDeg: number,
	pivot: Vector3, -- in the space of the part the pieces weld to, studs
	axis: Vector3, -- in that space
	welds: { { weld: Weld, base: CFrame } },
	lastDeg: number,
}

local rigged: { [Model]: Rigged } = {}
-- Cars looked at that have no turnable wheel, by the body looked at.
local without: { [Model]: Instance } = {}
local watched: { [Model]: boolean } = {}

function SteeringWheels.turns(): { Turn }
	return ConfigLoader.current().camera.firstPerson.wheelTurns
end

function SteeringWheels.current(): Turn
	local turns = SteeringWheels.turns()
	local id = Players.LocalPlayer:GetAttribute(ATTRIBUTE)
	for _, t in turns do
		if t.id == id then
			return t
		end
	end
	return turns[1]
end

function SteeringWheels.set(id: string)
	Players.LocalPlayer:SetAttribute(ATTRIBUTE, id)
end

-- The front hubs' steer angle in degrees, + = right: a hub's C0 is
-- Angles(0, -steer, 0) * Angles(spin, 0, 0) (VehicleSim, WheelVisuals), and
-- the spin about X leaves its X axis alone.
local function steerDeg(handles: VehicleRig.Handles): number
	local sum, n = 0, 0
	for _, w in VehicleRig.WHEELS do
		if w.front then
			local r = handles.hubs[w.name].weld.C0.RightVector
			sum += math.deg(math.atan2(r.Z, r.X))
			n += 1
		end
	end
	return if n > 0 then sum / n else 0
end

-- Swaps the car's wheel pieces onto turnable Welds, or nil if it has none.
local function rig(model: Model, body: Instance): Rigged?
	local carId = model:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
	local cockpit = CarCockpits.of(if type(carId) == "string" then carId else nil)
	local wheel = cockpit and cockpit.wheel
	if not wheel or type(carId) ~= "string" then
		return nil
	end
	local ok, handles = pcall(VehicleRig.handles, model)
	if not ok then
		return nil
	end
	local cfg = ConfigLoader.forCar(carId)
	local f = VehicleRig.scaleOf(ConfigLoader.entry(carId)) / cfg.units.metersPerStud
	local mountCf = handles.bodyMount.WorldCFrame
	local p, a = wheel.pivotM, wheel.axis
	local pivotWorld = mountCf * Vector3.new(p[1] * f, p[2] * f, p[3] * f)
	local axisWorld = mountCf:VectorToWorldSpace(Vector3.new(a[1], a[2], a[3]).Unit)
	local welds = {}
	local holder: BasePart? = nil
	for _, name in wheel.pieces do
		local part = body:FindFirstChild(name)
		if not part or not part:IsA("BasePart") then
			continue
		end
		local constraint = part:FindFirstChildOfClass("WeldConstraint")
		local part0 = if constraint then constraint.Part0 else nil
		if not constraint or not part0 or (holder and part0 ~= holder) then
			continue
		end
		holder = part0
		local base = part0.CFrame:ToObjectSpace(part.CFrame)
		local weld = Instance.new("Weld")
		weld.Name = "SteeringWeld"
		weld.Part0 = part0
		weld.Part1 = part
		weld.C0 = base
		weld.Parent = part
		constraint:Destroy()
		table.insert(welds, { weld = weld, base = base })
	end
	if #welds == 0 or not holder then
		return nil
	end
	return {
		body = body,
		handles = handles,
		maxSteerDeg = cfg.steering.maxSteerDeg,
		pivot = holder.CFrame:PointToObjectSpace(pivotWorld),
		axis = holder.CFrame:VectorToObjectSpace(axisWorld),
		welds = welds,
		lastDeg = 0,
	}
end

-- How far a car's steering wheel is turned now, degrees, + = right: what
-- the first-person arms hold on to.
function SteeringWheels.angleDeg(model: Model): number
	local r = rigged[model]
	return if r then r.lastDeg else 0
end

function SteeringWheels.start()
	RunService.RenderStepped:Connect(function()
		local cars = Workspace:FindFirstChild("Cars")
		local camera = Workspace.CurrentCamera
		if not cars or not camera then
			return
		end
		local fp = ConfigLoader.current().camera.firstPerson
		local turnDeg = SteeringWheels.current().deg
		local camPos = camera.CFrame.Position
		for _, model in cars:GetChildren() do
			if not model:IsA("Model") then
				continue
			end
			local body = model:FindFirstChild(VehicleRig.BODY)
			if not body then
				continue
			end
			if not watched[model] then
				watched[model] = true
				model.AncestryChanged:Connect(function()
					if not model:IsDescendantOf(Workspace) then
						rigged[model], without[model], watched[model] = nil, nil, nil
					end
				end)
			end
			if without[model] == body then
				continue
			end
			local existing: Rigged? = rigged[model]
			if not existing or existing.body ~= body then
				existing = rig(model, body)
				if existing then
					rigged[model] = existing
				else
					rigged[model] = nil
				end
			end
			if not existing then
				without[model] = body
				continue
			end
			local r: Rigged = existing
			local chassis = r.handles.chassis
			local mps = ConfigLoader.current().units.metersPerStud
			if (chassis.Position - camPos).Magnitude * mps > fp.wheelDrawDistanceM then
				continue
			end
			local ratio = math.clamp(steerDeg(r.handles) / r.maxSteerDeg, -1, 1)
			local deg = ratio * turnDeg
			if math.abs(deg - r.lastDeg) < 0.2 then
				continue
			end
			r.lastDeg = deg
			-- Turning right turns the rim clockwise as the driver sees it:
			-- negative about an axis pointing back at the driver.
			local turn = CFrame.new(r.pivot) * CFrame.fromAxisAngle(r.axis, -math.rad(deg)) * CFrame.new(-r.pivot)
			for _, w in r.welds do
				w.weld.C0 = turn * w.base
			end
		end
	end)
end

return SteeringWheels
