--!strict
local ContextActionService = game:GetService("ContextActionService")
local Input = require(script.Parent)

local Keyboard = {}

local PRIORITY = Enum.ContextActionPriority.High.Value
-- Only what we actually bound, so unbinding before the first bind is a no-op
-- instead of a row of "could not find the function passed in" warnings.
local bound: { string } = {}
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
	table.insert(bound, name)
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
	-- Q/E lift the car onto two wheels (a tap picks the side and the mode
	-- latches) and then lean it: taps toward the lifted side keep it up,
	-- the other key catches it, and held it lands the car.
	bind("HJ_KLeanLeft", function(down)
		Input.raw.leanLeft = down
	end, Enum.KeyCode.Q)
	bind("HJ_KLeanRight", function(down)
		Input.raw.leanRight = down
	end, Enum.KeyCode.E)
	bind("HJ_KExit", function(down)
		if down then
			Input.pulse("exit")
		end
	end, Enum.KeyCode.F)
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
	for _, name in bound do
		ContextActionService:UnbindAction(name)
	end
	table.clear(bound)
	left, right = false, false
	Input.raw.throttle, Input.raw.brake = 0, 0
	Input.raw.handbrake = false
	Input.raw.leanLeft, Input.raw.leanRight = false, false
	Input.raw.steerDigital = 0
end

return Keyboard
