--!strict
-- Puts a body on every car this client sees. The server builds rigs only;
-- a body is visual, and a generated one is an EditableMesh that cannot
-- replicate, so each client mounts its own (RIG_SPEC.md section 7).
--
-- Cars stream whole (ModelStreamingMode Persistent), so the rig is complete
-- when the model arrives; the wait below only covers the frame or two
-- before the CarId attribute and the hubs are readable. A car swap is a new
-- model, so nothing needs rebuilding in place.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleRig = require(Shared:WaitForChild("VehicleRig"))
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local BodyBuilder = require(Shared:WaitForChild("BodyBuilder"))

local CarBodies = {}

local WAIT_SECONDS = 10

local function carIdOf(model: Model): string?
	local id = model:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
	return if type(id) == "string" then id else nil
end

local function mount(model: Model)
	local deadline = os.clock() + WAIT_SECONDS
	while model.Parent do
		local ok = carIdOf(model) ~= nil and pcall(VehicleRig.handles, model)
		if ok then
			break
		end
		if os.clock() > deadline then
			warn(`[CarBodies] {model:GetFullName()} never became a complete rig; no body`)
			return
		end
		task.wait(0.1)
	end
	if not model.Parent or model:FindFirstChild(VehicleRig.BODY) then
		return
	end
	local carId = carIdOf(model)
	local ok, err = pcall(function()
		BodyBuilder.mount(model, ConfigLoader.forCar(carId), ConfigLoader.entry(carId))
	end)
	if not ok then
		warn(`[CarBodies] body for {model.Name} ({carId}) failed: {err}`)
	end
end

function CarBodies.start()
	task.spawn(function()
		-- The server makes the folder with the first car; no timeout warning.
		local cars = Workspace:WaitForChild("Cars", math.huge)
		cars.ChildAdded:Connect(function(child)
			if child:IsA("Model") then
				task.spawn(mount, child)
			end
		end)
		for _, child in cars:GetChildren() do
			if child:IsA("Model") then
				task.spawn(mount, child)
			end
		end
	end)
end

return CarBodies
