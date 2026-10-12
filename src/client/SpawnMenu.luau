--!strict
-- The spawn menu: pick a car from the catalog and the server builds it in
-- your bay slot with you in the driver's seat.
--
-- It opens by itself once the world is built (you start on foot), and M,
-- the CARS button (a desktop) or the top bar's GARAGE and SETTINGS (a
-- phone, TopBar) open it again at any time, driving or not. Spawning while
-- driving replaces the car you are in. Every car comes from CarCatalog, so
-- a new catalog entry shows up with no code change.
--
-- The screen is the Menu's (ui-flow, 2026-10-12): CARS, PLATES and
-- SETTINGS in the frame the garage shares, in the layout the player picked.
-- Before, the car list was the car picker's panels (CarPicker, 2026-10-11)
-- and PLATES and SETTINGS this module's own panel on the UITheme tokens, a
-- different look the owner kept landing in ("tapping plates/settings jumps
-- to the old menu whose style is different"). This keeps what is not the
-- screen: the spawn request and its cooldown, the car you are in, the way
-- back in, and Roblox's touch controls.
--
-- The request is only a wish: the server checks the id, the cooldown and
-- whether a spawn is already building, and does the seating itself.
--
-- PHONE FIRST. Roblox's own touch controls (the thumbstick, the jump button)
-- are CoreGui and draw over any PlayerGui, so they took taps meant for the
-- menu: `UserInputService.ModalEnabled` hides them while it is open.
-- VehicleController holds it on for the whole drive (its thumbstick would
-- sit under our steer pad), so the menu remembers what it found and puts
-- that back: closing the menu in a car must not hand the thumbstick back
-- mid-drive.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared.ConfigLoader)
local VehicleRig = require(Shared.VehicleRig)
local UITheme = require(Shared:WaitForChild("UITheme"))
local UIKit = require(script.Parent.UIKit)
local LoadCover = require(script.Parent.LoadCover)
local Menu = require(script.Parent:WaitForChild("Menu"))
local TopBar = require(script.Parent:WaitForChild("TopBar"))

local SpawnMenu = {}

local ACTION = "HJ_SpawnMenu"

local remote: RemoteEvent? = nil
local openButton: TextButton? = nil
local currentCarId: string? = nil
local waitingUntil = 0
local modalBefore = false
-- The garage view hides the way back in (SpawnMenu.setOpenButtonHidden).
local openButtonHidden = false

local isTouch = UIKit.isTouch

-- The way back into the menu shows while no menu is open and no garage view
-- fills the screen: on a desktop the CARS button, on a phone the top bar
-- (TopBar, whose GARAGE took the CARS button's place, 2026-10-11).
local function paintOpen()
	-- Not while the menu is still going out: the top bar came back over its
	-- title as it slid away.
	local free = not openButtonHidden and not Menu.covering()
	local ob = openButton
	if ob then
		ob.Visible = free and not isTouch()
	end
	TopBar.setShown(free)
end

local function busy(): boolean
	return os.clock() < waitingUntil
end

local function requestSpawn(id: string)
	if busy() or not remote then
		return
	end
	local cooldown = ConfigLoader.current().spawn.spawnCooldownSeconds
	waitingUntil = os.clock() + cooldown
	;(remote :: RemoteEvent):FireServer(id)
	SpawnMenu.close()
	task.delay(cooldown + 0.05, function()
		Menu.refresh()
	end)
end

local function sortedCars(): { { id: string, entry: VehicleRig.CarEntry } }
	local out = {}
	for id, entry in ConfigLoader.catalog().cars do
		-- A hidden entry stays spawnable by id but is off the menu (the
		-- generated-body Kamri, since the store-body one replaced it).
		if not (entry :: any).hidden then
			table.insert(out, { id = id, entry = entry })
		end
	end
	table.sort(out, function(a, b)
		local oa, ob = a.entry.order or math.huge, b.entry.order or math.huge
		if oa ~= ob then
			return oa < ob
		end
		return a.entry.displayName < b.entry.displayName
	end)
	return out
end

-- The CARS button, on a desktop: as tall as Roblox's own top bar buttons,
-- just right of them (the owner, 2026-10-08: "put the cars menu at the top").
local function fitButton()
	local ob = openButton
	if not ob then
		return
	end
	local bar = GuiService.TopbarInset
	local barH = math.max(bar.Height, 36)
	local h = math.max(barH - 12, 32)
	ob.Size = UDim2.fromOffset(92, h)
	ob.TextSize = UITheme.textSize("label", false)
	ob.Position = UDim2.fromOffset(bar.Min.X + 8, bar.Min.Y + barH / 2)
end

local function buildButton()
	local openGui = Instance.new("ScreenGui")
	openGui.Name = "HajwalaSpawnButton"
	openGui.ResetOnSpawn = false
	openGui.IgnoreGuiInset = true
	openGui.DisplayOrder = 7
	local open = UIKit.button(openGui, "CARS  (M)", "secondary", false)
	open.Name = "OpenSpawnMenu"
	open.AnchorPoint = Vector2.new(0, 0.5)
	open.AutomaticSize = Enum.AutomaticSize.None
	-- It floats over the road like the HUD card: alpha.hud, not a panel's.
	open.BackgroundTransparency = UITheme.alpha.hud
	open.Activated:Connect(function()
		SpawnMenu.toggle()
	end)
	openButton = open
	openGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(fitButton)
	fitButton()
end

function SpawnMenu.isOpen(): boolean
	return Menu.isOpen()
end

-- fn(true) as the menu takes the screen, fn(false) once it gives it back.
function SpawnMenu.watch(fn: (open: boolean) -> ())
	Menu.watch(fn)
end

export type OpenOptions = Menu.OpenOptions

-- Opens the menu on a page ("cars", "plates", "settings"), or switches to
-- it if the menu is open. The garage's SHOP PLATES opens PLATES with
-- `switch`: the frame stays, and EXIT hands the garage back at once.
function SpawnMenu.openTab(which: string, opts: OpenOptions?)
	if not Menu.isOpen() then
		modalBefore = UserInputService.ModalEnabled
	end
	-- Roblox's own touch controls are CoreGui and draw over any PlayerGui;
	-- modal hides them so they cannot take taps meant for the menu.
	UserInputService.ModalEnabled = true
	Menu.open(which, opts)
	paintOpen()
end

function SpawnMenu.open()
	SpawnMenu.openTab(Menu.page())
end

function SpawnMenu.close()
	if not Menu.isOpen() then
		return
	end
	Menu.close()
	UserInputService.ModalEnabled = modalBefore
	paintOpen()
end

-- Asks for a car exactly as SPAWN does (same cooldown). False if a spawn
-- is still cooling down.
function SpawnMenu.requestCar(id: string): boolean
	if busy() or not remote then
		return false
	end
	requestSpawn(id)
	return true
end

-- The catalog cars in menu order (the garage's MY CARS uses the same order).
function SpawnMenu.cars(): { { id: string, entry: VehicleRig.CarEntry } }
	return sortedCars()
end

-- Hides the way back in (the CARS button, the top bar on a phone) while the
-- garage view fills the screen; M still opens the menu.
function SpawnMenu.setOpenButtonHidden(hidden: boolean)
	openButtonHidden = hidden
	paintOpen()
end

function SpawnMenu.toggle()
	if SpawnMenu.isOpen() then
		SpawnMenu.close()
	else
		SpawnMenu.open()
	end
end

-- The car the player is in now, so CARS opens on it and reads RESPAWN. nil
-- when on foot is fine: the last car stays marked.
function SpawnMenu.setCurrent(carId: string?)
	if carId then
		currentCarId = carId
	end
	Menu.refresh()
end

function SpawnMenu.start(remotes: Folder)
	remote = remotes:WaitForChild("SpawnCar") :: RemoteEvent
	Menu.start({
		cars = sortedCars,
		spawn = SpawnMenu.requestCar,
		current = function()
			return currentCarId
		end,
		busy = busy,
		close = SpawnMenu.close,
	}, remotes)
	buildButton()
	ContextActionService:BindAction(ACTION, function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			SpawnMenu.toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M)
	-- Studio's phone mode (ForceTouch) swaps the CARS button for the top bar.
	Players.LocalPlayer:GetAttributeChangedSignal("ForceTouch"):Connect(paintOpen)
	-- The way back in returns once the menu has gone.
	Menu.watch(function()
		paintOpen()
	end)
	paintOpen()
	-- You start on foot: the menu comes in as the load cover goes (at once
	-- if the world is built already).
	LoadCover.whenReady(function()
		SpawnMenu.openTab("cars")
	end)
end

return SpawnMenu
