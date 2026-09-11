--!strict
-- On-screen buttons for phones, created through ContextActionService
-- (createTouchButton = true) and laid out by viewport fraction so both
-- thumbs have a cluster: steer + NATL on the left, throttle/brake/handbrake/
-- kick on the right, small utility buttons along the top.
--
-- Touch is the one platform where two-wheel is not entered by leaning:
-- the LEAN buttons are hidden until the mode is live, so NATL opens it and
-- the pair then appears inboard of the throttle cluster, under the right
-- thumb's sweep.
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Input = require(script.Parent)

local Touch = {}

local PRIORITY = Enum.ContextActionPriority.High.Value
local connections: { RBXScriptConnection } = {}
local bound: { string } = {}
local left, right = false, false
local LEAN_BUTTONS = { "HJ_TLeanLeft", "HJ_TLeanRight" }
local leanVisible = true

local function updateSteer()
	Input.raw.steerAnalog = nil
	Input.raw.steerDigital = (if right then 1 else 0) - (if left then 1 else 0)
	Input.raw.source = "touch"
end

-- xFrac/yFrac: centre of the button as a fraction of the viewport.
local function place(name: string, title: string, xFrac: number, yFrac: number, sizePx: number)
	local btn = ContextActionService:GetButton(name)
	if not btn then
		return
	end
	ContextActionService:SetTitle(name, title)
	btn.Size = UDim2.fromOffset(sizePx, sizePx)
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	local function layout()
		local parent = btn.Parent
		local cam = workspace.CurrentCamera
		if not parent or not parent:IsA("GuiObject") or not cam then
			return
		end
		local vp = cam.ViewportSize
		local target = Vector2.new(vp.X * xFrac, vp.Y * yFrac)
		local localPos = target - parent.AbsolutePosition
		btn.Position = UDim2.fromOffset(localPos.X, localPos.Y)
	end
	layout()
	local parent = btn.Parent
	if parent and parent:IsA("GuiObject") then
		table.insert(connections, parent:GetPropertyChangedSignal("AbsolutePosition"):Connect(layout))
		table.insert(connections, parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout))
	end
	local cam = workspace.CurrentCamera
	if cam then
		table.insert(connections, cam:GetPropertyChangedSignal("ViewportSize"):Connect(layout))
	end
end

local function bind(name: string, handler: (boolean) -> ())
	ContextActionService:BindActionAtPriority(name, function(_, state: Enum.UserInputState)
		handler(state == Enum.UserInputState.Begin)
		return Enum.ContextActionResult.Sink
	end, true, PRIORITY)
	table.insert(bound, name)
end

function Touch.bind()
	if not UserInputService.TouchEnabled then
		return
	end
	bind("HJ_TThrottle", function(down)
		Input.raw.throttle = if down then 1 else 0
		Input.raw.source = "touch"
	end)
	bind("HJ_TBrake", function(down)
		Input.raw.brake = if down then 1 else 0
		Input.raw.source = "touch"
	end)
	bind("HJ_TLeft", function(down)
		left = down
		updateSteer()
	end)
	bind("HJ_TRight", function(down)
		right = down
		updateSteer()
	end)
	bind("HJ_THandbrake", function(down)
		Input.raw.handbrake = down
	end)
	bind("HJ_TKick", function(down)
		if down then
			Input.pulse("clutchKick")
		end
	end)
	bind("HJ_TTwoWheel", function(down)
		Input.raw.twoWheelButton = down
	end)
	bind("HJ_TLeanLeft", function(down)
		Input.raw.leanLeft = down
	end)
	bind("HJ_TLeanRight", function(down)
		Input.raw.leanRight = down
	end)
	bind("HJ_TExit", function(down)
		if down then
			Input.pulse("exit")
		end
	end)
	bind("HJ_TReset", function(down)
		if down then
			Input.pulse("reset")
		end
	end)
	bind("HJ_TReload", function(down)
		if down then
			Input.pulse("reload")
		end
	end)

	-- Right thumb
	place("HJ_TThrottle", "GAS", 0.92, 0.80, 96)
	place("HJ_TBrake", "BRAKE", 0.80, 0.88, 72)
	place("HJ_THandbrake", "HAND", 0.92, 0.58, 72)
	place("HJ_TKick", "KICK", 0.80, 0.66, 60)
	-- Left thumb
	place("HJ_TLeft", "<", 0.08, 0.84, 96)
	place("HJ_TRight", ">", 0.22, 0.84, 96)
	place("HJ_TTwoWheel", "NATL", 0.15, 0.62, 72)
	-- Lean pair: horizontal so left/right read at a glance, inboard of BRAKE
	-- and GAS so nothing overlaps. Hidden until two-wheel is live.
	place("HJ_TLeanLeft", "LEAN<", 0.58, 0.84, 72)
	place("HJ_TLeanRight", "LEAN>", 0.70, 0.84, 72)
	-- Utility
	place("HJ_TExit", "EXIT", 0.56, 0.08, 44)
	place("HJ_TReset", "RESET", 0.64, 0.08, 44)
	place("HJ_TReload", "RELOAD", 0.72, 0.08, 44)

	leanVisible = true
	Touch.setLeanVisible(false)
end

-- Called every step by VehicleController: the lean pair is only on screen
-- while the car is in two-wheel mode.
function Touch.setLeanVisible(visible: boolean)
	if visible == leanVisible then
		return
	end
	leanVisible = visible
	for _, name in LEAN_BUTTONS do
		local btn = ContextActionService:GetButton(name)
		if btn then
			btn.Visible = visible
		end
	end
	if not visible then
		-- A button that vanishes under a finger never fires its Up event.
		Input.raw.leanLeft, Input.raw.leanRight = false, false
	end
end

function Touch.unbind()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for _, name in bound do
		ContextActionService:UnbindAction(name)
	end
	table.clear(bound)
	left, right = false, false
	leanVisible = true
	Input.raw.leanLeft, Input.raw.leanRight = false, false
	Input.raw.twoWheelButton = false
end

return Touch
