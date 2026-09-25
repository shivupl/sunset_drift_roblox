--!strict
-- Lamps on every car this client sees: built once the car's body is
-- mounted (CarBodies), updated whenever the car's lamp attributes change.
-- The attributes come from the driver (CarControls) through the server, so
-- everyone sees the same headlights and brake lights.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleRig = require(Shared:WaitForChild("VehicleRig"))
local CarLamps = require(Shared:WaitForChild("CarLamps"))

local CarLights = {}

local WAIT_SECONDS = 15

local function watch(model: Model)
	-- The body arrives a moment after the car (CarBodies builds it).
	local deadline = os.clock() + WAIT_SECONDS
	while model.Parent and not model:FindFirstChild(VehicleRig.BODY) do
		if os.clock() > deadline then
			return
		end
		task.wait(0.2)
	end
	if not model.Parent then
		return
	end
	task.wait(0.1) -- the pieces go in with the folder; let them settle in place
	if not CarLamps.build(model) then
		return
	end
	for _, name in { CarLamps.HEAD, CarLamps.BRAKE, CarLamps.REVERSE } do
		model:GetAttributeChangedSignal(name):Connect(function()
			CarLamps.apply(model)
		end)
	end
end

function CarLights.start()
	task.spawn(function()
		local cars = Workspace:WaitForChild("Cars", math.huge)
		cars.ChildAdded:Connect(function(child)
			if child:IsA("Model") then
				task.spawn(watch, child)
			end
		end)
		for _, child in cars:GetChildren() do
			if child:IsA("Model") then
				task.spawn(watch, child)
			end
		end
	end)
end

return CarLights
