--!strict
-- Looking around while driving (the owner, 2026-10-10: "allow me to
-- freelook while driving, resets after i a) on phone let go or b) on pc
-- resets after a seccond or 2 in the same mouse position"). CameraRig swings
-- the chase camera round the car by yaw and pitch from here.
--
--   Mouse  hold the right button and move the mouse; the cursor stays put
--          while it looks, so the view turns as far as you like and the
--          cursor is where you left it. Let go and the view holds for
--          mouseHoldSeconds, then eases back behind the car. Any movement
--          used to look (the first cut), but then the cursor could not reach
--          a button without swinging the view (the owner, 2026-10-10: "having
--          the regular mouse cursor be freelook will make it hard to click
--          buttons").
--   Touch  a thumb dragging on the screen turns it, one that began away from
--          the controls (each control is Active, so a press on one arrives
--          already processed and is left to it). Lifted, the view holds for
--          touchHoldSeconds, then eases back. It sprang straight back at
--          first (the owner: "a bit less 'eslastic'").
--
-- The ease home starts and ends slowly (smoothstep over returnSeconds), so
-- the camera glides back rather than snapping. Yaw: + turns the view right,
-- all the way round. Pitch: + raises the camera to look down on the car.
-- Settings: CarConfig.camera.freeLook.
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))

local FreeLook = {}

local connections: { RBXScriptConnection } = {}
local yaw, pitch = 0, 0
local mouseDown = false -- the right button is held, looking
local thumb: InputObject? = nil -- the touch doing the looking
local thumbAt = Vector2.zero
local released = -math.huge -- os.clock() when the button or thumb let go
local byTouch = false -- the last look was a thumb's (its hold and return apply)
-- The ease home: from where the look was when it began, over `returnFor`.
local returning = false
local fromYaw, fromPitch, returnT, returnFor = 0, 0, 0, 1

local function turn(dx: number, dy: number)
	local fl = ConfigLoader.current().camera.freeLook
	returning = false
	yaw = (yaw + dx + 180) % 360 - 180
	pitch = math.clamp(pitch + dy, fl.minPitchDeg, fl.maxPitchDeg)
end

local function screen(): Vector2
	local cam = workspace.CurrentCamera
	return if cam then cam.ViewportSize else Vector2.new(1280, 720)
end

local function letGoMouse()
	if mouseDown then
		mouseDown = false
		released = os.clock()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

function FreeLook.start()
	FreeLook.stop()
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(io: InputObject, processed: boolean)
			if processed then
				return -- on a control or a menu
			end
			if io.UserInputType == Enum.UserInputType.MouseButton2 then
				mouseDown, byTouch, returning = true, false, false
				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
			elseif io.UserInputType == Enum.UserInputType.Touch and not thumb then
				thumb, byTouch, returning = io, true, false
				thumbAt = Vector2.new(io.Position.X, io.Position.Y)
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(io: InputObject)
			if io.UserInputType == Enum.UserInputType.MouseMovement then
				if mouseDown then
					local k = ConfigLoader.current().camera.freeLook.degPerPixel
					turn(io.Delta.X * k, io.Delta.Y * k)
				end
			elseif io == thumb then
				local at = Vector2.new(io.Position.X, io.Position.Y)
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
			if io.UserInputType == Enum.UserInputType.MouseButton2 then
				letGoMouse()
			elseif io == thumb then
				thumb = nil
				released = os.clock()
			end
		end)
	)
	-- Alt-tabbed away mid-look: the button's release never arrives here.
	table.insert(connections, UserInputService.WindowFocusReleased:Connect(letGoMouse))
end

function FreeLook.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	letGoMouse()
	yaw, pitch = 0, 0
	thumb = nil
	returning = false
	released = -math.huge
end

-- The look this frame, degrees: held while the button or a thumb is down
-- and for a moment after, then easing home.
function FreeLook.step(dt: number): (number, number)
	if mouseDown or thumb or (yaw == 0 and pitch == 0) then
		return yaw, pitch
	end
	local fl = ConfigLoader.current().camera.freeLook
	if not returning then
		if os.clock() - released < (if byTouch then fl.touchHoldSeconds else fl.mouseHoldSeconds) then
			return yaw, pitch
		end
		returning = true
		fromYaw, fromPitch, returnT = yaw, pitch, 0
		returnFor = math.max(if byTouch then fl.touchReturnSeconds else fl.mouseReturnSeconds, 1e-3)
	end
	returnT += dt
	local x = math.min(returnT / returnFor, 1)
	local k = 1 - x * x * (3 - 2 * x)
	yaw, pitch = fromYaw * k, fromPitch * k
	if x >= 1 then
		yaw, pitch, returning = 0, 0, false
	end
	return yaw, pitch
end

return FreeLook
