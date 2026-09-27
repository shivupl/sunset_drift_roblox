--!strict
-- Number plates on every car this client sees (spec §2). Like CarLights:
-- built once the rig is readable, redrawn whenever the car's "Plate"
-- attribute changes (PlateService sets it). A plate is a thin part welded
-- at each spot in CarPlateMounts, with a SurfaceGui drawing the style
-- (PlateStyles). No attribute: no plate shows.
--
-- place() also serves measuring: call it from the Client datamodel with
-- trial mounts to see a spot at once (tools/carbody/README.md, "Plates").
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleRig = require(Shared:WaitForChild("VehicleRig"))
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local CarPlateMounts = require(Shared:WaitForChild("CarPlateMounts"))
local PlateStyles = require(Shared:WaitForChild("PlateStyles"))
local PlateConfig = require(Shared:WaitForChild("PlateConfig"))

local CarPlates = {}

local FOLDER = "Plates"
local WAIT_SECONDS = 10

local watching: { [Model]: RBXScriptConnection } = {}

local function carIdOf(model: Model): string?
	local id = model:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
	return if type(id) == "string" then id else nil
end

-- (Re)builds the plates on a car from these mounts and draws its Plate.
function CarPlates.place(model: Model, mounts: CarPlateMounts.Mounts)
	local old = model:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	local previous = watching[model]
	if previous then
		previous:Disconnect()
		watching[model] = nil
	end
	local handles = VehicleRig.handles(model)
	local carId = carIdOf(model)
	local k = VehicleRig.scaleOf(ConfigLoader.entry(carId))
	local mps = ConfigLoader.forCar(carId).units.metersPerStud
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	local drawn: { { gui: SurfaceGui, part: Part, format: PlateStyles.Format } } = {}
	for _, side in { { name = "PlateFront", spot = mounts.front, rear = false }, { name = "PlateRear", spot = mounts.rear, rear = true } } do
		local spot = side.spot
		if not spot then
			continue
		end
		local found = handles.chassis:FindFirstChild(side.name)
		local at: Attachment
		if found and found:IsA("Attachment") then
			at = found
		else
			at = Instance.new("Attachment")
			at.Name = side.name
			at.Parent = handles.chassis
		end
		at.CFrame = handles.bodyMount.CFrame
			* CarPlateMounts.cframe(spot, side.rear, k, mps)
			* CFrame.new(0, 0, -PlateConfig.standoffM * k / mps)
		local sizeM = PlateStyles.SIZE_M[spot.format]
		local part = Instance.new("Part")
		part.Name = side.name
		part.Size = Vector3.new(sizeM.X, sizeM.Y, PlateConfig.thicknessM) * (k / mps)
		part.Color = PlateStyles.COLORS.plate
		part.Material = Enum.Material.SmoothPlastic
		part.CastShadow = false
		part.Anchored = false
		part.Massless = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CFrame = at.WorldCFrame
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handles.chassis
		weld.Part1 = part
		weld.Parent = part
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = sizeM * PlateStyles.PIXELS_PER_M
		gui.LightInfluence = 1 -- lit like the car, not glowing at night
		gui.MaxDistance = PlateConfig.drawDistanceStuds
		gui.Parent = part
		part.Parent = folder
		table.insert(drawn, { gui = gui, part = part, format = spot.format })
	end
	folder.Parent = model
	local function draw()
		local key = model:GetAttribute("Plate")
		for _, d in drawn do
			local art = PlateStyles.draw(d.gui, if type(key) == "string" then key else nil, d.format)
			d.part.Transparency = if art then 0 else 1
		end
	end
	draw()
	watching[model] = model:GetAttributeChangedSignal("Plate"):Connect(draw)
end

local function build(model: Model)
	local deadline = os.clock() + WAIT_SECONDS
	while model.Parent do
		if carIdOf(model) ~= nil and pcall(VehicleRig.handles, model) then
			break
		end
		if os.clock() > deadline then
			return
		end
		task.wait(0.1)
	end
	if not model.Parent then
		return
	end
	local mounts = CarPlateMounts.cars[carIdOf(model) :: string]
	if not mounts then
		return
	end
	local ok, err = pcall(function()
		CarPlates.place(model, mounts)
	end)
	if not ok then
		warn(`[CarPlates] {model.Name}: {err}`)
	end
	model.Destroying:Connect(function()
		local c = watching[model]
		if c then
			c:Disconnect()
			watching[model] = nil
		end
	end)
end

function CarPlates.start()
	task.spawn(function()
		local cars = Workspace:WaitForChild("Cars", math.huge)
		cars.ChildAdded:Connect(function(child)
			if child:IsA("Model") then
				task.spawn(build, child)
			end
		end)
		for _, child in cars:GetChildren() do
			if child:IsA("Model") then
				task.spawn(build, child)
			end
		end
	end)
end

return CarPlates
