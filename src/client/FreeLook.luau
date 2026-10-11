--!strict
-- Looking around while driving (the owner, 2026-10-10: "allow me to
-- freelook while driving, resets after i a) on phone let go or b) on pc
-- resets after a seccond or 2 in the same mouse position"). CameraRig swings
-- the chase camera round the car by yaw and pitch from here.
--
--   Mouse  any movement turns the view; once the mouse has sat still for
--          holdSeconds it eases back behind the car.
--   Touch  a thumb dragging on the screen turns it, one that began away from
--          the controls (each control is Active, so a press on one arrives
--          already processed and is left to it); lifting it eases the view
--          back.
--
-- Yaw: + turns the view right, all the way round. Pitch: + raises the camera
-- to look down on the car. Settings: CarConfig.camera.freeLook.
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))

local FreeLook = {}

-- A mouse "moving" farther than this between two events jumped (it left the
-- window and came back in somewhere else); that turns nothing. In Studio a
-- cursor arriving from outside swung the view 160 degrees in one go. A real
-- flick is well under it: 3,000 px/s is 50 a frame at 60 fps.
local JUMP_PIXELS = 250

local connections: { RBXScriptConnection } = {}
local yaw, pitch = 0, 0
local lastMove = -math.huge -- os.clock() of the mouse's last movement
local lastMouse: Vector2? = nil
local thumb: InputObject? = nil -- the touch doing the looking
local thumbAt = Vector2.zero

local function turn(dx: number, dy: number)
	local fl = ConfigLoader.current().camera.freeLook
	yaw = (yaw + dx + 180) % 360 - 180
	pitch = math.clamp(pitch + dy, fl.minPitchDeg, fl.maxPitchDeg)
end

local function screen(): Vector2
	local cam = workspace.CurrentCamera
	return if cam then cam.ViewportSize else Vector2.new(1280, 720)
end

function FreeLook.start()
	FreeLook.stop()
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(io: InputObject, processed: boolean)
			if io.UserInputType == Enum.UserInputType.Touch and not processed and not thumb then
				thumb = io
				thumbAt = Vector2.new(io.Position.X, io.Position.Y)
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(io: InputObject, processed: boolean)
			local at = Vector2.new(io.Position.X, io.Position.Y)
			if io.UserInputType == Enum.UserInputType.MouseMovement then
				-- Moved since last time; a locked mouse only reports Delta.
				local last = lastMouse
				lastMouse = at
				if processed then
					return -- over a menu
				end
				local d = if last and at ~= last then at - last else Vector2.new(io.Delta.X, io.Delta.Y)
				if d.Magnitude > 0 and d.Magnitude < JUMP_PIXELS then
					local k = ConfigLoader.current().camera.freeLook.degPerPixel
					turn(d.X * k, d.Y * k)
					lastMove = os.clock()
				end
			elseif io == thumb then
				local d = at - thumbAt
				thumbAt = at
				local size = screen()
				local k = ConfigLoader.current().camera.freeLook.degPerScreen
				turn(d.X / math.max(size.X, 1) * k, d.Y / math.max(size.X, 1) * k)
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(io: InputObject)
			if io == thumb then
				thumb = nil
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.WindowFocused:Connect(function()
			lastMouse = nil
		end)
	)
end

function FreeLook.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	yaw, pitch = 0, 0
	lastMove = -math.huge
	lastMouse = nil
	thumb = nil
end

-- The look this frame, degrees: held while a thumb is down or the mouse has
-- moved within holdSeconds, easing home otherwise.
function FreeLook.step(dt: number): (number, number)
	local fl = ConfigLoader.current().camera.freeLook
	if not thumb and os.clock() - lastMove > fl.holdSeconds then
		local k = math.exp(-fl.returnRate * dt)
		yaw *= k
		pitch *= k
		if math.abs(yaw) < 0.01 and math.abs(pitch) < 0.01 then
			yaw, pitch = 0, 0
		end
	end
	return yaw, pitch
end

return FreeLook
