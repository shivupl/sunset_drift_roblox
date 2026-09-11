--!strict
local ContextActionService = game:GetService("ContextActionService")
local Input = require(script.Parent)

local Keyboard = {}

local PRIORITY = Enum.ContextActionPriority.High.Value
local ACTIONS = {
	"HJ_KThrottle", "HJ_KBrake", "HJ_KLeft", "HJ_KRight", "HJ_KHandbrake",
	"HJ_KKick", "HJ_KTwoWheel", "HJ_KExit", "HJ_KReset", "HJ_KReload",
}
local left, right = false, false

local function updateSteer()
	Input.raw.steerAnalog = nil
	Input.raw.steerDigital = (if right then 1 else 0) - (if left then 1 else 0)
	Input.raw.source = "keyboard"
end

local function bind(name: string, handler: (boolean) -> (), ...: Enum.KeyCode)
	ContextActionService:BindActionAtPriority(name, function(_, state: Enum.UserInputState)
		handler(state == Enum.UserInputState.Begin)
		-- Sink so Space does not also jump the character out of the seat.
		return Enum.ContextActionResult.Sink
	end, false, PRIORITY, ...)
end

function Keyboard.bind()
	bind("HJ_KThrottle", function(down)
		Input.raw.throttle = if down then 1 else 0
		Input.raw.source = "keyboard"
	end, Enum.KeyCode.W, Enum.KeyCode.Up)
	bind("HJ_KBrake", function(down)
		Input.raw.brake = if down then 1 else 0
		Input.raw.source = "keyboard"
	end, Enum.KeyCode.S, Enum.KeyCode.Down)
	bind("HJ_KLeft", function(down)
		left = down
		updateSteer()
	end, Enum.KeyCode.A, Enum.KeyCode.Left)
	bind("HJ_KRight", function(down)
		right = down
		updateSteer()
	end, Enum.KeyCode.D, Enum.KeyCode.Right)
	bind("HJ_KHandbrake", function(down)
		Input.raw.handbrake = down
	end, Enum.KeyCode.Space)
	bind("HJ_KKick", function(down)
		if down then
			Input.pulse("clutchKick")
		end
	end, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
	bind("HJ_KTwoWheel", function(down)
		Input.raw.twoWheel = down
	end, Enum.KeyCode.F)
	bind("HJ_KExit", function(down)
		if down then
			Input.pulse("exit")
		end
	end, Enum.KeyCode.E)
	bind("HJ_KReset", function(down)
		if down then
			Input.pulse("reset")
		end
	end, Enum.KeyCode.R)
	bind("HJ_KReload", function(down)
		if down then
			Input.pulse("reload")
		end
	end, Enum.KeyCode.L)
end

function Keyboard.unbind()
	for _, name in ACTIONS do
		ContextActionService:UnbindAction(name)
	end
	left, right = false, false
	Input.raw.throttle, Input.raw.brake = 0, 0
	Input.raw.handbrake, Input.raw.twoWheel = false, false
	Input.raw.steerDigital = 0
end

return Keyboard
