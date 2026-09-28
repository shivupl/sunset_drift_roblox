--!strict
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
local DebugPanel = require(script.DebugPanel)
local Hud = require(script.Hud)
local ScoreController = require(script.ScoreController)
local Touch = require(script.Input.Touch)
local WorldLights = require(script.WorldLights)
local SpawnMenu = require(script.SpawnMenu)
local CarBodies = require(script.CarBodies)
local CarLights = require(script.CarLights)
local CarPlates = require(script.CarPlates)
local WheelVisuals = require(script.WheelVisuals)
local LoadCover = require(script.LoadCover)
local Sky = require(script.Sky)
local EngineAudio = require(script.EngineAudio)
local ExhaustFlames = require(script.ExhaustFlames)
local GarageView = require(script.Garage.GarageView)
local GaragePanel = require(script.Garage.GaragePanel)

print("[Hajwala] client boot")
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
-- Exhaust flames: the driver's own at each pop EngineAudio plays, and each
-- pop sent on to the server as it plays (so a burst the throttle cuts short
-- is cut short for everyone); everyone else's as the server relays them.
EngineAudio.onPop = function(model: Model)
	ExhaustFlames.pop(model)
	ExhaustFlames.send(1)
end
ExhaustFlames.start(remotes)
WheelVisuals.localCar = VehicleController.currentCar
WheelVisuals.start()
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
Touch.onDebugToggle = DebugPanel.toggle
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
	if car then
		task.spawn(standBeside, car)
	end
end)

-- The time of day this player picked (Settings tab), before the menu that
-- shows it.
Sky.start(remotes)
-- Players start on foot; the spawn menu opens and puts them in a car.
SpawnMenu.start(remotes)
-- Walking into the garage opens the customisation view; the lift bay's
-- raised car is built once the garage is here.
GarageView.start()
-- The panel down the view's left side: preview, buy with a confirm, equip.
GaragePanel.start(remotes)
