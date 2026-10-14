--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local driveStart = remotes:WaitForChild("DriveStart") :: RemoteEvent
local driveStop = remotes:WaitForChild("DriveStop") :: RemoteEvent
local reloadRemote = remotes:WaitForChild("ReloadConfig") :: RemoteEvent
local submitSlide = remotes:WaitForChild("SubmitSlide") :: RemoteEvent
local slideResult = remotes:WaitForChild("SlideResult") :: RemoteEvent
local ConfigLoader = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ConfigLoader"))
local ExitSpot = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ExitSpot"))
local VehicleController = require(script.VehicleController)
local Input = require(script.Input)
local DebugPanel = require(script.DebugPanel)
local Hud = require(script.Hud)
-- The driving HUD and the phone controls (layout D; STYLE or U cycles its finish).
local HudLab = require(script.HudLab)
HudLab.start()
local ScoreController = require(script.ScoreController)
local WorldLights = require(script.WorldLights)
local SpawnMenu = require(script.SpawnMenu)
local TopBar = require(script.TopBar)
local CameraViews = require(script.CameraViews)
local CarBodies = require(script.CarBodies)
local CarLights = require(script.CarLights)
local CarPlates = require(script.CarPlates)
local WheelVisuals = require(script.WheelVisuals)
local LoadCover = require(script.LoadCover)
local Sky = require(script.Sky)
local EngineAudio = require(script.EngineAudio)
local ExhaustPops = require(script.ExhaustPops)
local DriftStyle = require(script.DriftStyle)
local TireSmoke = require(script.TireSmoke)
local GarageView = require(script.Garage.GarageView)
local GaragePanel = require(script.Garage.GaragePanel)

print("[Hajwala] client boot")
-- A phone plays in landscape only (the owner, 2026-10-14: "when i startup
-- the game it should automatically lock the screen to landscape").
-- StarterGui's ScreenOrientation (default.project.json) is the default for
-- every PlayerGui; it is set here as well, for one made before that
-- property reached it. LandscapeSensor: either way up, never portrait.
Players.LocalPlayer:WaitForChild("PlayerGui").ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
-- Up first: the server may still be building the world this client joined.
LoadCover.start()
-- Lamp lights follow the camera whether or not the player is driving. They
-- read WorldSettings once, and that folder only exists after the build.
LoadCover.whenReady(WorldLights.start)
-- Every car's body is built here, and every car not driven by this client
-- gets its wheel travel here.
CarBodies.start()
CarLights.start()
CarPlates.start()
-- Exhaust pops: EngineAudio decides when (a fast lift, the throttle back on,
-- an upshift or limiter pop); ExhaustPops plays the burst in the exhaust
-- style with its sounds and flames and sends it on, so every player sees
-- the same burst; everyone else's come as the server relays them.
EngineAudio.onLift = function(model: Model, rev: number)
	ExhaustPops.lift(model, rev)
end
EngineAudio.onCut = function(model: Model)
	ExhaustPops.cut(model)
end
EngineAudio.onSingle = function(model: Model)
	ExhaustPops.single(model)
end
-- A lift mid-drift: the style's flutter (feathering flutters the flames).
EngineAudio.onFlutter = function(model: Model)
	ExhaustPops.flutter(model)
end
ExhaustPops.start(remotes)
-- Drift styles: the Settings tab picks one per drivetrain; in Studio O and
-- Shift+O cycle them.
DriftStyle.start()
WheelVisuals.localCar = VehicleController.currentCar
WheelVisuals.start()
-- Tyre smoke: the car this client drives sends its levels through this
-- remote; every other car's smoke comes from the levels its driver sent.
TireSmoke.setRemotes(remotes)
TireSmoke.start(VehicleController.currentCar)
ScoreController.onSpin = function(bonus: number, spins: number)
	Hud.flashSpin(bonus, spins)
end
ScoreController.submit = function(points: number)
	submitSlide:FireServer(points)
end
slideResult.OnClientEvent:Connect(function(points: number, cash: number)
	Hud.flashResult(points, cash)
end)
VehicleController.onState = function(state, dt)
	ScoreController.step(state, dt)
	Hud.update(state, ScoreController.state)
	DebugPanel.update(state)
end
VehicleController.onReload = function()
	local cfg, err = ConfigLoader.reload()
	if err then
		warn("[Hajwala] config reload failed:", err)
	else
		print("[Hajwala] config reloaded")
	end
	VehicleController.setConfig(cfg)
	reloadRemote:FireServer()
end
driveStart.OnClientEvent:Connect(function(carArg: Model?, carName: string?)
	-- A car the server built a moment ago can arrive after this event, in
	-- which case the instance comes through as nil: wait for it by name.
	local car = carArg
	if not car and type(carName) == "string" then
		local folder = workspace:WaitForChild("Cars", 10)
		local found = folder and folder:WaitForChild(carName, 10)
		car = if found and found:IsA("Model") then found else nil
	end
	if not car then
		warn("[Hajwala] DriveStart for a car that never arrived")
		return
	end
	VehicleController.start(car, remotes)
	local id = car:GetAttribute("CarId")
	SpawnMenu.setCurrent(if type(id) == "string" then id else nil)
	-- The top row's driving tabs (EXIT; CAMERA and STYLE on a desktop).
	TopBar.setDriving(true)
end)
-- Stepping out: our own character is ours to move (the server's move alone
-- lost to it, and the owner landed under the car, 2026-09-27), so once the
-- seat has let go, stand beside the driver's door (ExitSpot).
local function standBeside(car: Model)
	local character = game:GetService("Players").LocalPlayer.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not hum then
		return
	end
	local deadline = os.clock() + 1
	while hum.SeatPart and os.clock() < deadline do
		task.wait()
	end
	if hum.SeatPart or not car.Parent then
		return
	end
	local cfg = ConfigLoader.current()
	local spot = ExitSpot.cframe(car, cfg.spawn.exitGapM, cfg.spawn.exitLiftM, cfg.units.metersPerStud)
	if spot then
		character:PivotTo(spot)
	end
end

driveStop.OnClientEvent:Connect(function()
	local car = VehicleController.currentCar()
	VehicleController.stop()
	ScoreController.clear()
	Hud.hide()
	DebugPanel.hide()
	TopBar.setDriving(false)
	if car then
		task.spawn(standBeside, car)
	end
end)

-- The time of day this player picked (Settings tab), before the menu that
-- shows it.
Sky.start(remotes)
-- Players start on foot; the spawn menu opens and puts them in a car.
SpawnMenu.start(remotes)
-- The top bar, right of Roblox's buttons: STORE (the plates page, until a
-- store exists), GARAGE (the car menu) and SETTINGS always, EXIT while
-- driving (CAMERA and STYLE too on a desktop; off the phone's row for
-- now); a page's button closes it when it is the one up. RESET left the
-- row (2026-10-13). A desktop's tabs wear their keys (M, F, V, U) and the
-- CARS button went (desktop-ui, 2026-10-14).
TopBar.start({
	store = function()
		SpawnMenu.toggleTab("plates")
	end,
	garage = function()
		SpawnMenu.toggleTab("cars")
	end,
	-- The same pulse as E: the car controller sends ExitCar on its next step.
	exit = function()
		Input.pulse("exit")
	end,
	view = CameraViews.cycle,
	style = HudLab.cycle,
	settings = function()
		SpawnMenu.toggleTab("settings")
	end,
})
-- Walking into the garage opens the customisation view; the lift bay's
-- raised car is built once the garage is here.
GarageView.start()
-- The panel down the view's left side: preview, buy with a confirm, equip.
GaragePanel.start(remotes)
