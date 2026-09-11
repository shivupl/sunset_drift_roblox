--!strict
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared.ConfigLoader)
local Input = require(script.Parent)

local Gamepad = {}

local PRIORITY = Enum.ContextActionPriority.High.Value
local ACTIONS = {
	"HJ_GThrottle", "HJ_GBrake", "HJ_GSteer", "HJ_GHandbrake", "HJ_GKick",
	"HJ_GTwoWheel", "HJ_GExit", "HJ_GReset",
}

local function applyDeadzone(v: number, dz: number): number
	local a = math.abs(v)
	if a < dz then
		return 0
	end
	return math.sign(v) * (a - dz) / (1 - dz)
end

local function bindAnalog(name: string, handler: (InputObject) -> (), key: Enum.KeyCode)
	ContextActionService:BindActionAtPriority(name, function(_, _state: Enum.UserInputState, obj: InputObject)
		handler(obj)
		return Enum.ContextActionResult.Sink
	end, false, PRIORITY, key)
end

local function bindButton(name: string, handler: (boolean) -> (), key: Enum.KeyCode)
	ContextActionService:BindActionAtPriority(name, function(_, state: Enum.UserInputState)
		handler(state == Enum.UserInputState.Begin)
		return Enum.ContextActionResult.Sink
	end, false, PRIORITY, key)
end

function Gamepad.bind()
	bindAnalog("HJ_GThrottle", function(obj)
		local cfg = ConfigLoader.current().input
		Input.raw.throttle = applyDeadzone(obj.Position.Z, cfg.triggerDeadzone)
		Input.raw.source = "gamepad"
	end, Enum.KeyCode.ButtonR2)
	bindAnalog("HJ_GBrake", function(obj)
		local cfg = ConfigLoader.current().input
		Input.raw.brake = applyDeadzone(obj.Position.Z, cfg.triggerDeadzone)
		Input.raw.source = "gamepad"
	end, Enum.KeyCode.ButtonL2)
	bindAnalog("HJ_GSteer", function(obj)
		local cfg = ConfigLoader.current().input
		local x = applyDeadzone(obj.Position.X, cfg.gamepadDeadzone)
		-- Centred stick hands steering back to digital sources.
		Input.raw.steerAnalog = if x == 0 then nil else x
		Input.raw.source = "gamepad"
	end, Enum.KeyCode.Thumbstick1)
	bindButton("HJ_GHandbrake", function(down)
		Input.raw.handbrake = down
	end, Enum.KeyCode.ButtonB)
	bindButton("HJ_GKick", function(down)
		if down then
			Input.pulse("clutchKick")
		end
	end, Enum.KeyCode.ButtonX)
	bindButton("HJ_GTwoWheel", function(down)
		Input.raw.twoWheel = down
	end, Enum.KeyCode.ButtonY)
	bindButton("HJ_GExit", function(down)
		if down then
			Input.pulse("exit")
		end
	end, Enum.KeyCode.ButtonL1)
	bindButton("HJ_GReset", function(down)
		if down then
			Input.pulse("reset")
		end
	end, Enum.KeyCode.ButtonSelect)
end

function Gamepad.unbind()
	for _, name in ACTIONS do
		ContextActionService:UnbindAction(name)
	end
	Input.raw.steerAnalog = nil
end

return Gamepad
