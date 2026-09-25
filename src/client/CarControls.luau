--!strict
-- The driver's horn and lamps. H holds the horn and G toggles the
-- headlights (L3 and D-pad up on a pad); the brake and reverse lights
-- follow the sim. Changes go to the server, which plays the horn and copies
-- the lamps onto the car for every player; the driver's own lamps are set
-- here at once so they never lag the pedal.
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local ConfigLoader = require(Shared.ConfigLoader)
local CarLamps = require(Shared.CarLamps)

type VehicleState = Types.VehicleState

local CarControls = {}

local HORN = "HJ_Horn"
local LIGHTS = "HJ_Headlights"
local PRIORITY = Enum.ContextActionPriority.High.Value

local car: Model? = nil
local lampsRemote: RemoteEvent? = nil
local hornRemote: RemoteEvent? = nil
local head = false
local brake = false
local reverse = false
local horn = false
local sent = { head = false, brake = false, reverse = false }
local dirty = false
local bound = false

local function push()
	local model = car
	if not model then
		return
	end
	model:SetAttribute(CarLamps.HEAD, head)
	model:SetAttribute(CarLamps.BRAKE, brake)
	model:SetAttribute(CarLamps.REVERSE, reverse)
	CarLamps.apply(model)
	if lampsRemote and (sent.head ~= head or sent.brake ~= brake or sent.reverse ~= reverse or dirty) then
		lampsRemote:FireServer(head, brake, reverse)
		sent.head, sent.brake, sent.reverse = head, brake, reverse
		dirty = false
	end
end

local function setHorn(on: boolean)
	if on ~= horn then
		horn = on
		if hornRemote then
			hornRemote:FireServer(on)
		end
	end
end

function CarControls.start(model: Model, remotes: Folder)
	CarControls.stop()
	car = model
	lampsRemote = remotes:FindFirstChild("CarLamps") :: RemoteEvent?
	hornRemote = remotes:FindFirstChild("Horn") :: RemoteEvent?
	local id = model:GetAttribute("CarId")
	head = ConfigLoader.forCar(if type(id) == "string" then id else nil).effects.lamps.headlightsOnAtStart
	brake, reverse = false, false
	dirty = true
	push()
	bound = true
	ContextActionService:BindActionAtPriority(HORN, function(_, state: Enum.UserInputState)
		setHorn(state == Enum.UserInputState.Begin)
		return Enum.ContextActionResult.Sink
	end, false, PRIORITY, Enum.KeyCode.H, Enum.KeyCode.ButtonL3)
	ContextActionService:BindActionAtPriority(LIGHTS, function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			head = not head
			push()
		end
		return Enum.ContextActionResult.Sink
	end, false, PRIORITY, Enum.KeyCode.G, Enum.KeyCode.DPadUp)
end

-- Every frame from the sim. The pedals swap meaning in reverse (Drivetrain):
-- there the throttle pedal is what slows the car.
function CarControls.update(state: VehicleState)
	if not car then
		return
	end
	local inReverse = state.gear == -1
	local braking = if inReverse then state.throttle > 0.05 else state.brake > 0.05
	if braking ~= brake or inReverse ~= reverse then
		brake, reverse = braking, inReverse
		push()
	end
end

function CarControls.stop()
	if bound then
		ContextActionService:UnbindAction(HORN)
		ContextActionService:UnbindAction(LIGHTS)
		bound = false
	end
	setHorn(false)
	local model = car
	if model and model.Parent then
		-- Parked: brake and reverse lights off; the headlights stay as they were.
		brake, reverse = false, false
		push()
	end
	car = nil
	lampsRemote, hornRemote = nil, nil
end

return CarControls
