--!strict
-- The garage's customisation view. Asked by the owner on 2026-09-28:
-- "Crossing the threshold switches to the customisation view: camera moves
-- onto the car on a turntable, panel comes up, character control drops
-- away. Leaving returns them to their character outside." The design is
-- docs/superpowers/specs/2026-09-28-garage-design.md sections 1 to 3; the
-- numbers are GarageConfig.
--
-- On foot, walking in through the open door (the character's root crossing
-- DoorZone from outside to inside) fades to asphalt950, drops the controls,
-- hides the character, suspends the world lamp pool and lights the display
-- bay with the view's own four lights, builds the preview car on the
-- turntable and puts the camera on one fixed framing. The turntable turns
-- slowly; a drag outside any UI spins it. LEAVE (button, Esc, gamepad B)
-- reverses all of it and stands the character at ExitSpot, facing out.
--
-- The cars shown here (the preview and the raised car in the lift bay) are
-- client-only models with no physics: a minimal rig that satisfies
-- VehicleRig.handles, with BodyBuilder's body mounted on it (staticCar
-- below). Why not clone the player's spawned car: there may be none (a
-- player can walk in before spawning), the panel's MY CARS swaps to cars
-- the player is not driving, and the lift car is never anyone's; one path
-- serves all three. The rig costs a handful of invisible instances.
--
-- Driving in (garage round 2 §3, the owner on 2026-09-28: "also add the
-- ability to not only walk in but drive a car in as well"): seated as the
-- driver of your own car, the chassis's centre crossing DoorZone inward
-- below GarageConfig.driveIn.maxKmh fades out and asks the server
-- (GarageAction "driveIn", server/GarageService), which unseats the player
-- and parks the car on the drive-out spot facing out; the view then opens
-- with that car. Leaving after a drive-in asks for "driveOut", which seats
-- the player back in the car there, ready to drive away; if that fails (the
-- car was replaced or taken) they stand at ExitSpot as after a walk-in.
-- Closing the view any other way (died, respawned, seated elsewhere) sends
-- "release", so the parked car's prompt comes back.
--
-- The panel is the GaragePanel's (Task 7); this module only offers the
-- hooks below and a fallback LEAVE button the panel can hide.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GarageConfig = require(Shared:WaitForChild("GarageConfig"))
local VehicleRig = require(Shared:WaitForChild("VehicleRig"))
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local BodyBuilder = require(Shared:WaitForChild("BodyBuilder"))
local CarLook = require(Shared:WaitForChild("CarLook"))
local CarLamps = require(Shared:WaitForChild("CarLamps"))
local CarPlateMounts = require(Shared:WaitForChild("CarPlateMounts"))
local UITheme = require(Shared:WaitForChild("UITheme"))
local SkyConfig = require(Shared:WaitForChild("SkyConfig"))
local Client = script.Parent.Parent
local CarCosmetics = require(Client:WaitForChild("CarCosmetics"))
local CarPlates = require(Client:WaitForChild("CarPlates"))
local UIKit = require(Client:WaitForChild("UIKit"))
local WorldLights = require(Client:WaitForChild("WorldLights"))
local Sky = require(Client:WaitForChild("Sky"))
local VehicleController = require(Client:WaitForChild("VehicleController"))

local GarageView = {}

-- Hooks for the panel. onEnter fires once the preview is on the turntable,
-- before the fade lifts; onLeave once the player stands outside again.
GarageView.onEnter = nil :: ((carId: string, preview: Model) -> ())?
GarageView.onLeave = nil :: (() -> ())?

local player = Players.LocalPlayer

local RENDER_STEP = "GarageView"
local LEAVE_ACTION = "GarageLeave"
local PREVIEW_NAME = "GaragePreview"
local LIFT_CAR_NAME = "GarageLiftCar"
local LIGHTS_NAME = "GarageViewLights"
local NO_PREVIEW_TEXT = "The garage couldn't show this car. Try again in a moment."
local FIND_INTERVAL = 1 -- seconds between looks for the garage while it is not here

type Garage = {
	folder: Folder,
	turntable: BasePart,
	viewFrame: CFrame, -- the turntable's top centre, -Z into the garage
	door: BasePart,
	exit: BasePart,
}

type Preview = {
	model: Model,
	carId: string,
	pivot: CFrame, -- the chassis relative to the turntable frame, before the spin
	centreY: number, -- studs above the turntable top of the car's middle
	radius: number, -- studs, half the body's bounding diagonal
}

local state: "outside" | "entering" | "inside" | "leaving" = "outside"
local garage: Garage? = nil
local preview: Preview? = nil
local lightsFolder: Folder? = nil
local plateHome: CFrame? = nil -- the turntable plate's CFrame before any spin
local savedFov: number? = nil
-- The view was opened by driving in: leaving asks to be seated again.
local drivenIn = false
local connections: { RBXScriptConnection } = {}

-- The spin, radians about the turntable's axis.
local angle = 0
local dragging: InputObject? = nil
local dragX = 0
local dragVel = 0 -- rad/s, smoothed, while dragging
local lastMove = 0
local releaseVel = 0
local releaseAt = -math.huge
local lastDrag = -math.huge
-- A presentation (present(), the garage's REV): the turntable eases to a
-- set angle, calls onArrive, holds, then the auto-spin resumes. A drag,
-- a car switch or leaving cancels it without calling onArrive.
type Presenting = { target: number, arrived: boolean, holdUntil: number, onArrive: () -> () }
local presenting: Presenting? = nil

-- The framing's sideways offset (fraction of the screen width), eased.
local panelOpen = true
local offsetFrom, offsetTo, offsetAt = 0, 0, -math.huge

local gui: ScreenGui? = nil
local fadeFrame: Frame? = nil
local leaveButton: TextButton? = nil
local leaveButtonWanted = true

local function mps(): number
	return ConfigLoader.current().units.metersPerStud
end

------------------------------------------------------------------------
-- The garage's parts.
------------------------------------------------------------------------

local function findGarage(): Garage?
	local g = garage
	if g and g.folder.Parent and g.turntable.Parent and g.door.Parent and g.exit.Parent then
		return g
	end
	garage = nil
	local world = Workspace:FindFirstChild("World")
	local folder = world and world:FindFirstChild("Garage")
	if not folder or not folder:IsA("Folder") or folder:GetAttribute("GarageRoot") ~= true then
		return nil
	end
	local turntable = folder:FindFirstChild("Turntable")
	local door = folder:FindFirstChild("DoorZone")
	local exit = folder:FindFirstChild("ExitSpot")
	local frame = if turntable then turntable:GetAttribute("ViewFrame") else nil
	if not (turntable and turntable:IsA("BasePart") and door and door:IsA("BasePart") and exit and exit:IsA("BasePart")) then
		return nil
	end
	if typeof(frame) ~= "CFrame" then
		return nil
	end
	garage = { folder = folder, turntable = turntable, viewFrame = frame, door = door, exit = exit }
	return garage
end

------------------------------------------------------------------------
-- A car with no physics: a minimal rig for BodyBuilder.mount.
------------------------------------------------------------------------

local function inert(p: BasePart)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
end

-- A client-only car standing with its car-space origin (the ground under
-- the middle, RIG_SPEC) at `at`, nose along at's LookVector. The rig holds
-- only what VehicleRig.handles asks for, all inert: an anchored chassis the
-- body is welded to, the hubs where the wheels rest, and a disabled seat,
-- prompt and actuators. Nothing here simulates.
local function staticCar(carId: string, name: string, at: CFrame, parent: Instance): Model
	local cfg = ConfigLoader.forCar(carId)
	local entry = ConfigLoader.entry(carId)
	local s = cfg.units.metersPerStud
	local size = cfg.body.bodySize
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute(VehicleRig.CAR_ID_ATTRIBUTE, carId)
	local rig = Instance.new("Model")
	rig.Name = VehicleRig.RIG
	rig.Parent = model

	local mountM = VehicleRig.bodyMountM(cfg)
	local chassis = Instance.new("Part")
	chassis.Name = VehicleRig.CHASSIS
	chassis.Size = Vector3.new(size[3], size[2], size[1]) / s
	inert(chassis)
	chassis.Anchored = true
	chassis.CFrame = at * CFrame.new(-mountM / s)
	chassis.Parent = rig
	model.PrimaryPart = chassis

	local bodyMount = Instance.new("Attachment")
	bodyMount.Name = VehicleRig.BODY_MOUNT
	bodyMount.Position = mountM / s
	bodyMount.Parent = chassis

	for _, w in VehicleRig.WHEELS do
		local ray = Instance.new("Attachment")
		ray.Name = VehicleRig.rayOriginName(w.name)
		ray.Position = VehicleRig.rayOriginM(cfg, w) / s
		ray.Parent = chassis
		-- The wheel at rest on the ground: the car-space wheel centre.
		local hubOffset = CFrame.new((mountM + VehicleRig.wheelCentreCarM(cfg, w)) / s)
		local hub = Instance.new("Part")
		hub.Name = VehicleRig.hubName(w.name)
		hub.Size = Vector3.one * 0.4
		inert(hub)
		hub.CFrame = chassis.CFrame * hubOffset
		hub.Parent = rig
		local wheelMount = Instance.new("Attachment")
		wheelMount.Name = VehicleRig.WHEEL_MOUNT
		wheelMount.Parent = hub
		local weld = Instance.new("Weld")
		weld.Name = VehicleRig.WHEEL_WELD
		weld.Part0 = chassis
		weld.Part1 = hub
		weld.C0 = hubOffset
		weld.Parent = hub
	end

	local seat = Instance.new("VehicleSeat")
	seat.Name = VehicleRig.SEAT
	seat.Size = Vector3.one
	inert(seat)
	seat.Disabled = true
	seat.CFrame = chassis.CFrame
	seat.Parent = rig
	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0 = chassis
	seatWeld.Part1 = seat
	seatWeld.Parent = seat

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = VehicleRig.PROMPT
	prompt.Enabled = false
	prompt.Parent = chassis
	local force = Instance.new("VectorForce")
	force.Name = VehicleRig.FORCE
	force.Enabled = false
	force.Parent = chassis
	local torque = Instance.new("Torque")
	torque.Name = VehicleRig.TORQUE
	torque.Enabled = false
	torque.Parent = chassis

	model.Parent = parent
	BodyBuilder.mount(model, cfg, entry)
	return model
end

-- The body's bounding box in car space (studs, origin at the body mount):
-- its centre and half its diagonal. The body only: the rig's invisible
-- boxes would widen it.
local function bodyBox(model: Model): (Vector3, number)
	local handles = VehicleRig.handles(model)
	local frame = handles.bodyMount.WorldCFrame
	local lo = Vector3.one * math.huge
	local hi = -lo
	local body = handles.body
	if body then
		for _, part in body:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 1 then
				local rel = frame:ToObjectSpace(part.CFrame)
				local h = part.Size / 2
				local r = rel.Rotation
				-- The part's box turned into car space: |R| * half size.
				local ext = Vector3.new(
					math.abs(r.XVector.X) * h.X + math.abs(r.YVector.X) * h.Y + math.abs(r.ZVector.X) * h.Z,
					math.abs(r.XVector.Y) * h.X + math.abs(r.YVector.Y) * h.Y + math.abs(r.ZVector.Y) * h.Z,
					math.abs(r.XVector.Z) * h.X + math.abs(r.YVector.Z) * h.Y + math.abs(r.ZVector.Z) * h.Z
				)
				lo = lo:Min(rel.Position - ext)
				hi = hi:Max(rel.Position + ext)
			end
		end
	end
	if lo.X > hi.X then
		-- No visible piece: a box the size of the rig's chassis.
		return Vector3.zero, handles.chassis.Size.Magnitude / 2
	end
	return (lo + hi) / 2, (hi - lo).Magnitude / 2
end

------------------------------------------------------------------------
-- Which car, with which look and plate.
------------------------------------------------------------------------

local function myCar(): Model?
	local cars = Workspace:FindFirstChild("Cars")
	if not cars then
		return nil
	end
	for _, m in cars:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("OwnerUserId") == player.UserId then
			return m
		end
	end
	return nil
end

local function currentCarId(): string
	local car = myCar()
	local id = car and car:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
	return ConfigLoader.resolveCarId(if type(id) == "string" then id else nil)
end

-- The saved look for this car as the server last sent it: the spawned car's
-- own Look when it is this car, else the profile's Looks.
local function savedLook(carId: string): CarLook.Look
	local car = myCar()
	if car and car:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE) == carId then
		return CarLook.decode(car:GetAttribute(CarLook.ATTRIBUTE))
	end
	local raw = player:GetAttribute("Looks")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, looks = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(looks) ~= "table" then
		return {}
	end
	-- The server already dropped anything not owned.
	return CarLook.clean(looks[carId], function(_: string): boolean
		return true
	end)
end

-- The plate this car would carry (PlateService.plateFor, read from the
-- replicated attributes).
local function plateFor(carId: string): string?
	local car = myCar()
	if car and car:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE) == carId then
		local p = car:GetAttribute("Plate")
		return if type(p) == "string" then p else nil
	end
	local chosen = savedLook(carId).plate
	local owned = player:GetAttribute("Plates")
	if type(chosen) == "string" and type(owned) == "string" and table.find(string.split(owned, ","), chosen) then
		return chosen
	end
	local equipped = player:GetAttribute("PlateEquipped")
	if type(equipped) == "string" and equipped ~= "" then
		return equipped
	end
	local default = player:GetAttribute("PlateDefault")
	return if type(default) == "string" then default else nil
end

------------------------------------------------------------------------
-- The preview on the turntable.
------------------------------------------------------------------------

local function destroyPreview()
	local p = preview
	preview = nil
	presenting = nil
	if p then
		p.model:Destroy()
	end
end

local function buildPreview(g: Garage, carId: string): Preview?
	destroyPreview()
	local model: Model? = nil
	local ok, err = pcall(function()
		local m = staticCar(carId, PREVIEW_NAME, g.viewFrame, g.folder)
		model = m
		if GarageConfig.previewLampsOn then
			m:SetAttribute(CarLamps.HEAD, true)
		end
		CarLamps.build(m)
		CarCosmetics.apply(m, savedLook(carId), carId)
		local mounts = CarPlateMounts.cars[carId]
		if mounts then
			m:SetAttribute("Plate", plateFor(carId))
			CarPlates.place(m, mounts)
		end
	end)
	local m = model
	if not ok or not m then
		warn(`[GarageView] preview for {carId} failed: {err}`)
		if m then
			m:Destroy()
		end
		return nil
	end
	local centre, radius = bodyBox(m)
	-- The chassis relative to the turntable frame: turned so the nose faces
	-- the door (car -Z along the frame's +Z), the body's middle on the axis.
	local mountM = VehicleRig.bodyMountM(ConfigLoader.forCar(carId))
	local pivot = CFrame.Angles(0, math.pi, 0) * CFrame.new(-centre.X, 0, -centre.Z) * CFrame.new(-mountM / mps())
	local p: Preview = { model = m, carId = carId, pivot = pivot, centreY = centre.Y, radius = radius }
	preview = p
	return p
end

------------------------------------------------------------------------
-- The view's four lights.
------------------------------------------------------------------------

-- The view lights' brightness factor under the player's sky option (see
-- GarageConfig.lights): the same exposure on the car whichever sky.
local function exposureScale(): number
	local base = SkyConfig.resolve(nil).exposureCompensation
	local chosen = SkyConfig.resolve(Sky.current()).exposureCompensation
	return 2 ^ (base - chosen)
end

local function scaleLights()
	local folder = lightsFolder
	if not folder then
		return
	end
	local k = exposureScale()
	for _, light in folder:GetDescendants() do
		local base = light:GetAttribute("BaseBrightness")
		if light:IsA("Light") and type(base) == "number" then
			light.Brightness = base * k
		end
	end
end

local function makeLights(g: Garage)
	local old = lightsFolder
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = LIGHTS_NAME
	local s = mps()
	local aim = g.viewFrame * Vector3.new(0, GarageConfig.aimHeightM / s, 0)
	local lights = GarageConfig.lights
	for _, def in { lights.key, lights.fill, lights.rim, lights.under } do
		local anchor = Instance.new("Part")
		anchor.Name = def.type
		local face = (def.sizeM or 0.2) / s
		anchor.Size = Vector3.new(face, face, 0.2)
		inert(anchor)
		anchor.Anchored = true
		local at = g.viewFrame * (def.positionM / s)
		anchor.CFrame = CFrame.lookAt(at, aim)
		local light: Light
		if def.type == "SpotLight" then
			local l = Instance.new("SpotLight")
			l.Face = Enum.NormalId.Front
			l.Angle = def.angleDeg
			light = l
		elseif def.type == "SurfaceLight" then
			local l = Instance.new("SurfaceLight")
			l.Face = Enum.NormalId.Front
			l.Angle = def.angleDeg
			light = l
		else
			light = Instance.new("PointLight")
		end
		light:SetAttribute("BaseBrightness", def.brightness)
		light.Brightness = def.brightness
		light.Color = def.color
		light.Shadows = def.shadows == true
		-- Range is capped at 60 studs by the engine.
		;(light :: any).Range = math.min(def.rangeM / s, 60)
		light.Parent = anchor
		anchor.Parent = folder
	end
	folder.Parent = g.folder
	lightsFolder = folder
	scaleLights()
end

------------------------------------------------------------------------
-- The interior's painted-on light per sky option.
------------------------------------------------------------------------

-- Strong tables, not weak-keyed: an Instance held only as a weak key can
-- lose its entry while the Instance lives on (measured 2026-09-28: the
-- night glow never applied). Entries go when their Instance leaves.
local bakedBuilt: { [SurfaceGui]: number } = {}

local function bakedGlow(): number
	return GarageConfig.bakedGlow[Sky.current()] or 1
end

local function applyBaked(g: SurfaceGui, glow: number)
	local built = bakedBuilt[g]
	if built == nil then
		local host = g.Adornee or g.Parent
		if g.LightInfluence >= 1 or (host and GarageConfig.bakedGlowSkip[host.Name]) then
			return
		end
		built = g.LightInfluence
		bakedBuilt[g] = built
		g.Destroying:Once(function()
			bakedBuilt[g] = nil
		end)
	end
	assert(built)
	g.LightInfluence = 1 - (1 - built) * glow
end

local watchedBaked: Folder? = nil
local function watchBaked(folder: Folder)
	if watchedBaked == folder then
		return
	end
	watchedBaked = folder
	local glow = bakedGlow()
	for _, d in folder:GetDescendants() do
		if d:IsA("SurfaceGui") then
			applyBaked(d, glow)
		end
	end
	-- Parts streaming in later.
	folder.DescendantAdded:Connect(function(d)
		if d:IsA("SurfaceGui") then
			applyBaked(d, bakedGlow())
		end
	end)
end

local function reapplyBaked()
	local glow = bakedGlow()
	for g in bakedBuilt do
		if g.Parent then
			applyBaked(g, glow)
		end
	end
end

------------------------------------------------------------------------
-- The character.
------------------------------------------------------------------------

local function characterParts(): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, hum, if root and root:IsA("BasePart") then root else nil
end

-- The character's visible pieces, collected once on entering; each frame
-- only re-hides a piece something else has shown again.
local hiddenParts: { any } = {} -- BaseParts and Decals

local function setHidden(hidden: boolean)
	if hidden then
		local character = player.Character
		if not character then
			return
		end
		table.clear(hiddenParts)
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				table.insert(hiddenParts, d)
				d.LocalTransparencyModifier = 1
			end
		end
	else
		for _, d in hiddenParts do
			d.LocalTransparencyModifier = 0
		end
		table.clear(hiddenParts)
	end
end

local function keepHidden()
	for _, d in hiddenParts do
		if d.LocalTransparencyModifier ~= 1 then
			d.LocalTransparencyModifier = 1
		end
	end
end

-- The PlayerModule's controls, by the documented route
-- (PlayerScripts.PlayerModule:GetControls()), looked up without waiting:
-- in the Studio session of 2026-09-28 PlayerScripts held no PlayerModule,
-- and a WaitForChild there hung the fade on black. Requiring the copy under
-- StarterPlayer instead would make a second, separate ControlModule (and
-- its Enable could build a second set of touch controls), so it is not
-- used. The character's root is anchored on this client as well, which
-- drops control whether or not the module was found.
local function controlModule(): any
	local ok, module = pcall(function(): any
		local scripts = player:FindFirstChild("PlayerScripts")
		local classic = scripts and scripts:FindFirstChild("PlayerModule")
		if classic and classic:IsA("ModuleScript") then
			return ((require :: any)(classic)):GetControls()
		end
		return nil
	end)
	return if ok then module else nil
end

local anchoredRoot: BasePart? = nil

local function setControls(enabled: boolean)
	local ctl = controlModule()
	if ctl then
		pcall(function()
			if enabled then
				ctl:Enable()
			else
				ctl:Disable()
			end
		end)
	end
	if enabled then
		local root = anchoredRoot
		anchoredRoot = nil
		if root then
			root.Anchored = false
		end
	else
		local _, _, root = characterParts()
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
			root.Anchored = true
			anchoredRoot = root
		end
	end
end

------------------------------------------------------------------------
-- The screen: fade and the fallback LEAVE button.
------------------------------------------------------------------------

local function ensureGui(): (ScreenGui, Frame)
	local g, f = gui, fadeFrame
	if g and f and g.Parent then
		return g, f
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "GarageView"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.DisplayOrder = 50 -- over the panel, so the fade covers it too
	local fade = Instance.new("Frame")
	fade.Name = "Fade"
	fade.Size = UDim2.fromScale(1, 1)
	fade.BorderSizePixel = 0
	fade.BackgroundColor3 = UITheme.color.asphalt950
	fade.BackgroundTransparency = 1
	fade.Visible = false
	fade.ZIndex = 10
	fade.Parent = screen
	local touch = UIKit.isTouch()
	local button = UIKit.button(screen, "LEAVE", "secondary", touch)
	-- Bottom right: the top corners belong to the Roblox top bar, and the
	-- panel docks on the left.
	button.AnchorPoint = Vector2.new(1, 1)
	local inset = UITheme.px(UITheme.space.xl, touch)
	button.Position = UDim2.new(1, -inset, 1, -inset)
	button.Visible = false
	button.Activated:Connect(function()
		GarageView.leave()
	end)
	screen.Parent = player:WaitForChild("PlayerGui")
	gui, fadeFrame, leaveButton = screen, fade, button
	return screen, fade
end

-- A short line of text at the foot of the screen, gone after a moment.
local function notice(text: string)
	local screen = ensureGui()
	local touch = UIKit.isTouch()
	local box = Instance.new("Frame")
	box.Name = "Notice"
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -UITheme.px(UITheme.space.xxxl, touch) * 2)
	box.AutomaticSize = Enum.AutomaticSize.XY
	box.BackgroundColor3 = UITheme.color.asphalt900
	box.BackgroundTransparency = UITheme.alpha.panel
	box.BorderSizePixel = 0
	box.ZIndex = 20 -- over the fade
	UIKit.corner(box, "md")
	UIKit.pad(box, "md")
	local label = UIKit.text(box, text, "body", "paint", touch, false)
	label.ZIndex = 21
	box.Parent = screen
	task.delay(GarageConfig.noticeSeconds, function()
		box:Destroy()
	end)
end

local function fade(to: number)
	local _, f = ensureGui()
	f.Visible = true
	local t = TweenService:Create(f, TweenInfo.new(GarageConfig.fadeSeconds, Enum.EasingStyle.Quad), { BackgroundTransparency = to })
	t:Play()
	t.Completed:Wait()
	f.Visible = to < 1
end

------------------------------------------------------------------------
-- Framing and the spin, every frame while in the view.
------------------------------------------------------------------------

local function currentOffset(now: number): number
	local info = UITheme.motion.panel
	local a = math.clamp((now - offsetAt) / info.Time, 0, 1)
	return offsetFrom + (offsetTo - offsetFrom) * TweenService:GetValue(a, info.EasingStyle, info.EasingDirection)
end

local function cameraCFrame(g: Garage, p: Preview?, now: number): CFrame
	local cam = Workspace.CurrentCamera
	local s = mps()
	local tanV = math.tan(math.rad(GarageConfig.fovDeg / 2))
	local radius = if p then p.radius else 2.5 / s
	local centreY = if p then p.centreY else GarageConfig.aimHeightM / s
	-- Far enough that the body's bounding sphere, with the margin, fits
	-- the vertical field of view; every car fits whatever its size.
	local d = radius * GarageConfig.framingMargin / tanV
	local eyeY = GarageConfig.eyeHeightM / s
	local dy = eyeY - centreY
	local flat = math.sqrt(math.max(d * d - dy * dy, 0))
	-- Round from the nose (toward the door, +Z) to the car's right, which
	-- faces -X of the frame while the nose faces the door.
	local yaw = math.rad(GarageConfig.yawDeg)
	local eye = g.viewFrame * Vector3.new(-math.sin(yaw) * flat, eyeY, math.cos(yaw) * flat)
	local centre = g.viewFrame * Vector3.new(0, centreY, 0)
	local cf = CFrame.lookAt(eye, centre)
	-- Turn the camera left (not slide it: the bay is 13 m wide and a slide
	-- put the eye through the side wall, measured 2026-09-28) so the car's
	-- middle sits `offset` of the screen width right of centre, where the
	-- panel on the left does not cover it.
	local vp = if cam then cam.ViewportSize else Vector2.new(16, 9)
	local tanH = tanV * vp.X / math.max(vp.Y, 1)
	return cf * CFrame.Angles(0, math.atan(currentOffset(now) * 2 * tanH), 0)
end

local function step(dt: number)
	local g = garage
	if state ~= "inside" or not g or not g.folder.Parent then
		return
	end
	local now = os.clock()
	local pr = presenting
	if pr and not dragging then
		local R = GarageConfig.revPresent
		if not pr.arrived then
			-- The shortest way round, eased (exponential approach).
			local delta = (pr.target - angle + math.pi) % (2 * math.pi) - math.pi
			angle += delta * (1 - math.exp(-dt / R.easeSeconds))
			if math.abs(delta) < math.rad(R.arriveDeg) then
				pr.arrived = true
				pr.holdUntil = now + R.holdSeconds
				task.spawn(pr.onArrive)
			end
		elseif now >= pr.holdUntil then
			presenting = nil
			-- Spin again straight away, not after the drag pause.
			lastDrag = now - GarageConfig.resumeAfterSeconds
			releaseVel = 0
		end
	elseif not dragging then
		local left = 1 - (now - releaseAt) / GarageConfig.inertiaSeconds
		if left > 0 then
			angle += releaseVel * left * dt
		end
		if now - lastDrag >= GarageConfig.resumeAfterSeconds then
			angle += math.rad(GarageConfig.spinDegPerSec) * dt
		end
	end
	angle %= 2 * math.pi
	local spin = CFrame.Angles(0, angle, 0)
	local home = plateHome
	if home then
		g.turntable.CFrame = g.viewFrame * spin * g.viewFrame:Inverse() * home
	end
	local p = preview
	if p and p.model.Parent then
		p.model:PivotTo(g.viewFrame * spin * p.pivot)
	end
	local cam = Workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = GarageConfig.fovDeg
		cam.CFrame = cameraCFrame(g, p, now)
	end
	-- The default camera scripts may set it back while the character is
	-- close to the camera; keep it hidden.
	keepHidden()
end

------------------------------------------------------------------------
-- Dragging the turntable.
------------------------------------------------------------------------

-- True if a visible piece of UI (the panel, a button) is under the point.
local function overUi(pos: Vector3): boolean
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return false
	end
	for _, o in playerGui:GetGuiObjectsAtPosition(pos.X, pos.Y) do
		local screen = o:FindFirstAncestorOfClass("ScreenGui")
		if o ~= fadeFrame and o.Visible and (screen == nil or screen.Enabled) and (o:IsA("GuiButton") or o.BackgroundTransparency < 1) then
			return true
		end
	end
	return false
end

local function onInputBegan(input: InputObject, processed: boolean)
	if state ~= "inside" or processed or dragging then
		return
	end
	local t = input.UserInputType
	if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
		return
	end
	if overUi(input.Position) then
		return
	end
	dragging = input
	presenting = nil
	dragX = input.Position.X
	dragVel = 0
	lastMove = os.clock()
	releaseVel = 0
	lastDrag = os.clock()
end

local function onInputChanged(input: InputObject)
	local d = dragging
	if not d then
		return
	end
	local mouse = d.UserInputType == Enum.UserInputType.MouseButton1
	if (mouse and input.UserInputType ~= Enum.UserInputType.MouseMovement) or (not mouse and input ~= d) then
		return
	end
	local now = os.clock()
	local dx = input.Position.X - dragX
	dragX = input.Position.X
	local da = math.rad(dx * GarageConfig.dragDegPerPixel)
	angle += da
	local sample = da / math.max(now - lastMove, 1 / 240)
	dragVel = dragVel * 0.5 + sample * 0.5
	lastMove = now
	lastDrag = now
end

local function onInputEnded(input: InputObject)
	local d = dragging
	if not d or (input ~= d and input.UserInputType ~= d.UserInputType) then
		return
	end
	dragging = nil
	local now = os.clock()
	-- Held still before letting go: no flick.
	local cap = math.rad(GarageConfig.maxFlickDegPerSec)
	releaseVel = if now - lastMove > 0.1 then 0 else math.clamp(dragVel, -cap, cap)
	releaseAt = now
	lastDrag = now
end

------------------------------------------------------------------------
-- In and out.
------------------------------------------------------------------------

local function disconnectAll()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	pcall(function()
		RunService:UnbindFromRenderStep(RENDER_STEP)
	end)
	ContextActionService:UnbindAction(LEAVE_ACTION)
end

local function seatedNow(): boolean
	local _, hum = characterParts()
	return hum ~= nil and hum.SeatPart ~= nil
end

-- The camera back to the default one, unless the character is seated: then
-- the car camera (CameraRig) owns it and setting Custom would fight it.
-- Idempotent: restore() and restoreEssentials() both call it, so savedFov
-- is only forgotten once the whole leave is over (forgetFov).
local function restoreCamera()
	local cam = Workspace.CurrentCamera
	if cam and not seatedNow() then
		local _, hum = characterParts()
		cam.FieldOfView = savedFov or 70
		cam.CameraType = Enum.CameraType.Custom
		if hum then
			cam.CameraSubject = hum
		end
	end
end

local function forgetFov()
	savedFov = nil
end

-- GarageAction (server/GarageService) -> its status, or "unavailable".
local function garageAction(what: string): string
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild("GarageAction")
	if not remote or not remote:IsA("RemoteFunction") then
		return "unavailable"
	end
	local ok, reply = pcall(function(): any
		return remote:InvokeServer(what)
	end)
	if ok and type(reply) == "table" and type(reply.status) == "string" then
		return reply.status
	end
	return "unavailable"
end

-- Stand the character at ExitSpot, facing out, with the camera behind it
-- (not when it is seated, dead or gone).
local function standAtExit()
	local g = garage
	local character, hum, root = characterParts()
	if g and g.exit.Parent and character and root and hum and not hum.SeatPart and hum.Health > 0 then
		character:PivotTo(g.exit.CFrame)
		local c = GarageConfig.exitCamera
		local s = mps()
		local cam = Workspace.CurrentCamera
		if cam then
			local eye = g.exit.CFrame * Vector3.new(0, c.upM / s, c.backM / s)
			cam.CFrame = CFrame.lookAt(eye, g.exit.Position)
		end
	end
end

-- After a drive-in: back in the parked car ("driveOut"), and true once the
-- car controller has it; false (nothing changed) when the server could not.
local function driveBackOut(): boolean
	-- The server holds the car anchored through the seating until "go": let
	-- go before this client's sim runs, it fell and could land on its side
	-- (GarageConfig.driveIn.holdSeconds). "go" goes as soon as the car
	-- controller runs, not after "driveOut" returns (the server's seating
	-- checks the seat held for 0.3 s first): VehicleSim warns every step it
	-- drives an anchored chassis (BEHAVIOURS.md), so the hold is kept short.
	task.spawn(function()
		local deadline = os.clock() + 3
		while os.clock() < deadline do
			-- "waiting": the seat has not reached the server yet; ask again.
			if VehicleController.isDriving() and garageAction("go") ~= "waiting" then
				return
			end
			task.wait(0.03)
		end
	end)
	if garageAction("driveOut") ~= "ok" then
		return false
	end
	-- DriveStart follows the seat; wait for the car camera before the fade
	-- lifts, so the default camera does not show for a frame.
	local deadline = os.clock() + 3
	while not VehicleController.isDriving() and os.clock() < deadline do
		task.wait()
	end
	return true
end

-- Everything the view changed, put back. `outside`: stand the character at
-- ExitSpot (not when it is seated, dead or gone).
local function restore(outside: boolean)
	disconnectAll()
	dragging = nil
	destroyPreview()
	local lf = lightsFolder
	lightsFolder = nil
	if lf then
		lf:Destroy()
	end
	local g = garage
	local home = plateHome
	plateHome = nil
	if g and home and g.turntable.Parent then
		g.turntable.CFrame = home
	end
	WorldLights.resume()
	if outside then
		standAtExit()
	end
	restoreCamera()
	setHidden(false)
	setControls(true)
	local b = leaveButton
	if b then
		b.Visible = false
	end
end

-- The parts of restore that must happen whatever failed, each on its own,
-- so one error cannot leave the player anchored, hidden or blind.
local function restoreEssentials()
	local function dropScene()
		destroyPreview()
		local lf = lightsFolder
		lightsFolder = nil
		if lf then
			lf:Destroy()
		end
		local g, home = garage, plateHome
		plateHome = nil
		if g and home and g.turntable.Parent then
			g.turntable.CFrame = home
		end
	end
	for _, fn in { disconnectAll, dropScene, WorldLights.resume, restoreCamera } :: { () -> () } do
		local ok, err = pcall(fn :: () -> any)
		if not ok then
			warn("[GarageView]", err)
		end
	end
	for _, step in { { setHidden, false }, { setControls, true } } :: { { any } } do
		local ok, err = pcall(step[1], step[2])
		if not ok then
			warn("[GarageView]", err)
		end
	end
	local b = leaveButton
	if b then
		b.Visible = false
	end
end

local function leaveNow(outside: boolean)
	if state ~= "inside" then
		return
	end
	state = "leaving"
	local driven = drivenIn
	drivenIn = false
	if seatedNow() then
		-- The car camera and the seat weld take over now, not after the fade.
		pcall(function()
			RunService:UnbindFromRenderStep(RENDER_STEP)
		end)
		pcall(setControls, true)
	end
	local ok, err = xpcall(function(): any
		fade(0)
		-- After a drive-in the player goes back into the car, so not to
		-- ExitSpot first; only if the car is not there to go back to.
		restore(outside and not driven)
		if driven then
			if outside and not seatedNow() then
				if not driveBackOut() then
					standAtExit()
				end
			else
				task.spawn(garageAction, "release")
			end
		end
		return nil
	end, debug.traceback)
	if not ok then
		warn("[GarageView] leaving failed:", err)
		if driven then
			task.spawn(garageAction, "release")
		end
	end
	-- Always, even after an error: the player walks away free.
	restoreEssentials()
	forgetFov()
	pcall(fade, 1)
	state = "outside"
	local cb = GarageView.onLeave
	if cb then
		task.spawn(cb)
	end
end

local function enter(g: Garage, carIdArg: string?)
	if state ~= "outside" then
		return
	end
	state = "entering"
	local _, hum = characterParts()
	if hum then
		-- Hooked before anything else, so a death or a seat during the fade in
		-- is not missed (the checks after entering catch those).
		table.insert(connections, hum.Died:Connect(function()
			task.spawn(leaveNow, false)
		end))
		table.insert(connections, hum:GetPropertyChangedSignal("SeatPart"):Connect(function()
			if hum.SeatPart then
				-- Seated (the spawn menu put them in a car): stop driving the
				-- camera and let go of the root at once, so the car camera and
				-- the seat weld take over; then close the view without moving
				-- the character.
				pcall(function()
					RunService:UnbindFromRenderStep(RENDER_STEP)
				end)
				pcall(setControls, true)
				task.spawn(leaveNow, false)
			end
		end))
	end
	local carId = carIdArg or currentCarId()
	local p: Preview? = nil
	local ok, err = xpcall(function(): any
		fade(0)
		setControls(false)
		setHidden(true)
		local cam = Workspace.CurrentCamera
		if cam then
			savedFov = cam.FieldOfView
			cam.CameraType = Enum.CameraType.Scriptable
		end
		WorldLights.suspend()
		makeLights(g)
		plateHome = g.turntable.CFrame
		angle = 0
		releaseVel, releaseAt, lastDrag = 0, -math.huge, -math.huge
		panelOpen = true
		offsetFrom, offsetTo, offsetAt = GarageConfig.screenOffset, GarageConfig.screenOffset, -math.huge
		p = buildPreview(g, carId)
		state = "inside"
		RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, step)
		step(0)
		return nil
	end, debug.traceback)
	if not ok then
		warn("[GarageView] entering failed:", err)
		local rok, rerr = pcall(restore :: (boolean) -> any, false)
		if not rok then
			warn("[GarageView]", rerr)
		end
		restoreEssentials()
		forgetFov()
		if drivenIn then
			drivenIn = false
			if not driveBackOut() then
				standAtExit()
			end
		end
		pcall(fade, 1)
		state = "outside"
		return
	end
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		-- Esc leaves; the Roblox menu may take it first, so it is read here
		-- whether or not the game "processed" it. Not while typing in a box.
		if input.KeyCode == Enum.KeyCode.Escape and (state :: string) == "inside" and not UserInputService:GetFocusedTextBox() then
			task.spawn(leaveNow, true)
			return
		end
		onInputBegan(input, processed)
	end))
	table.insert(connections, UserInputService.InputChanged:Connect(onInputChanged))
	table.insert(connections, UserInputService.InputEnded:Connect(onInputEnded))
	ContextActionService:BindActionAtPriority(LEAVE_ACTION, function(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			task.spawn(leaveNow, true)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)
	-- Died or seated while the fade ran: out at once.
	if hum and (hum.Health <= 0 or hum.SeatPart) then
		leaveNow(false)
		return
	end
	local built = p
	if not built then
		-- No car to show: say so and step back out, rather than open an
		-- empty turntable. onLeave still fires, for the panel.
		notice(NO_PREVIEW_TEXT)
		leaveNow(true)
		return
	end
	local b = leaveButton
	if b then
		b.Visible = leaveButtonWanted
	end
	local cb = GarageView.onEnter
	if cb then
		task.spawn(cb, carId, built.model)
	end
	fade(1)
end

------------------------------------------------------------------------
-- The threshold and the lift car, watched from start().
------------------------------------------------------------------------

local lastSide: number? = nil

local function watchThreshold()
	if state ~= "outside" then
		lastSide = nil
		return
	end
	local g = garage
	local _, hum, root = characterParts()
	if not g or not g.door.Parent or not hum or not root or hum.SeatPart or hum.Health <= 0 then
		lastSide = nil
		return
	end
	local rel = g.door.CFrame:PointToObjectSpace(root.Position)
	if rel.Magnitude > GarageConfig.thresholdRangeM / mps() then
		lastSide = nil
		return
	end
	-- Along the zone's LookVector (its -Z), which points into the garage.
	local side = -rel.Z
	local half = g.door.Size / 2
	local inDoorway = math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y
	local was = lastSide
	lastSide = side
	if was and was <= 0 and side > 0 and inDoorway then
		lastSide = nil
		task.spawn(enter, g)
	end
end

-- Driving in: the car's chassis, while this player drives their own car.
local lastCarSide: number? = nil

local function driveIn(g: Garage, carId: string)
	if state ~= "outside" then
		return
	end
	state = "entering"
	-- Black first, while the server parks the car, so the jump to the apron
	-- and the step out of the seat are not seen.
	local fading = true
	task.spawn(function()
		pcall(fade, 0)
		fading = false
	end)
	local status = garageAction("driveIn")
	while fading do
		task.wait()
	end
	if status ~= "ok" then
		if status == "blocked" then
			notice(GarageConfig.driveIn.blockedText)
		end
		pcall(fade, 1)
		state = "outside"
		return
	end
	drivenIn = true
	-- Out of the seat and the car controller stopped (DriveStop) before the
	-- view takes the camera and the character.
	local _, hum = characterParts()
	local deadline = os.clock() + 2
	while os.clock() < deadline and ((hum and hum.SeatPart) or VehicleController.isDriving()) do
		task.wait()
	end
	state = "outside"
	enter(g, carId)
end

local function watchDriveIn()
	local car = VehicleController.currentCar()
	if not car then
		lastCarSide = nil
		return
	end
	local g = garage
	local _, hum = characterParts()
	if state ~= "outside" or not g or not g.door.Parent or not hum or not hum.SeatPart or hum.Health <= 0 then
		lastCarSide = nil
		return
	end
	-- Only your own car: the view and the parking are for the owner.
	if car:GetAttribute("OwnerUserId") ~= player.UserId or not hum.SeatPart:IsDescendantOf(car) then
		lastCarSide = nil
		return
	end
	local chassis = car.PrimaryPart
	if not chassis then
		lastCarSide = nil
		return
	end
	local rel = g.door.CFrame:PointToObjectSpace(chassis.Position)
	if rel.Magnitude > GarageConfig.thresholdRangeM / mps() then
		lastCarSide = nil
		return
	end
	local side = -rel.Z
	local half = g.door.Size / 2
	local inDoorway = math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y
	local was = lastCarSide
	lastCarSide = side
	if was and was <= 0 and side > 0 and inDoorway then
		local kmh = chassis.AssemblyLinearVelocity.Magnitude * mps() * 3.6
		if kmh <= GarageConfig.driveIn.maxKmh then
			lastCarSide = nil
			local id = car:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
			task.spawn(driveIn, g, ConfigLoader.resolveCarId(if type(id) == "string" then id else nil))
		end
	end
end

local liftBuilt: { [Folder]: boolean } = {} -- strong: see bakedBuilt

local function buildLiftCar(g: Garage)
	if liftBuilt[g.folder] then
		return
	end
	local spot = g.folder:FindFirstChild("LiftCarSpot")
	if not spot or not spot:IsA("BasePart") then
		return -- not streamed in yet; the next look tries again
	end
	liftBuilt[g.folder] = true
	g.folder.Destroying:Once(function()
		liftBuilt[g.folder] = nil
	end)
	local id = spot:GetAttribute("CarId")
	local carId = ConfigLoader.resolveCarId(if type(id) == "string" then id else nil)
	local ok, err = pcall(function()
		local m = staticCar(carId, LIFT_CAR_NAME, spot.CFrame, g.folder)
		CarLamps.build(m) -- stock, lamps off
	end)
	if not ok then
		warn(`[GarageView] lift car {carId} failed: {err}`)
	end
end

------------------------------------------------------------------------
-- The panel's handles.
------------------------------------------------------------------------

-- Rebuilds the preview for another car, keeping the spin.
function GarageView.setCar(carId: string)
	local g = garage
	if state ~= "inside" or not g then
		return
	end
	buildPreview(g, ConfigLoader.resolveCarId(carId))
end

-- Turns the car's rear toward the camera (GarageConfig.revPresent: a rear
-- 3/4 with the exhaust in the open right-hand part of the screen), calls
-- onArrive once it is there, holds, then lets the turntable spin on. False
-- (and onArrive never called) when the view is not open or a presentation
-- is already running; a drag, car switch or leaving cancels it.
function GarageView.present(onArrive: () -> ()): boolean
	if state ~= "inside" or not preview or presenting then
		return false
	end
	-- angle 0 is the nose toward the door (+Z); the camera sits yawDeg
	-- round from the nose, so 180 - yawDeg puts the rear square to it.
	local target = math.rad(180 - GarageConfig.yawDeg + GarageConfig.revPresent.turnDeg)
	presenting = { target = target, arrived = false, holdUntil = 0, onArrive = onArrive }
	return true
end

-- The car on the turntable, for CarCosmetics.apply.
function GarageView.preview(): Model?
	local p = preview
	return if p then p.model else nil
end

-- The car's middle sits right of centre with the panel open, centred with
-- it closed; the framing eases between the two with the panel's motion.
function GarageView.setPanelOpen(open: boolean)
	if open == panelOpen then
		return
	end
	panelOpen = open
	local now = os.clock()
	offsetFrom = currentOffset(now)
	offsetTo = if open then GarageConfig.screenOffset else 0
	offsetAt = now
end

-- The fallback LEAVE button; the panel hides it when it has its own.
function GarageView.setLeaveButton(visible: boolean)
	leaveButtonWanted = visible
	local b = leaveButton
	if b then
		b.Visible = visible and state == "inside"
	end
end

function GarageView.isOpen(): boolean
	return state == "inside"
end

function GarageView.leave()
	task.spawn(leaveNow, true)
end

function GarageView.start()
	ensureGui()
	-- A respawn while in the view: the old character is gone, put the rest
	-- back.
	player.CharacterAdded:Connect(function()
		if state == "inside" then
			task.spawn(leaveNow, false)
		end
	end)
	-- The sky option changes the hour; the painted-on light and the view's
	-- lights follow.
	Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
		reapplyBaked()
		scaleLights()
	end)
	RunService.Heartbeat:Connect(function()
		if garage then
			watchThreshold()
			watchDriveIn()
		end
	end)
	task.spawn(function()
		-- Looks for the garage until it is here, and again after a rebuild,
		-- for as long as this player is in the game.
		while player.Parent do
			local g = findGarage()
			if g then
				buildLiftCar(g)
				watchBaked(g.folder)
			end
			task.wait(FIND_INTERVAL)
		end
	end)
end

return GarageView
