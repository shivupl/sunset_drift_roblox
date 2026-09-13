--!strict
-- The spawn menu: pick a car from the catalog and the server builds it in
-- your bay slot with you in the driver's seat.
--
-- It opens by itself when you join (you start on foot), and M or the CARS
-- button at the bottom centre opens it again at any time, driving or not.
-- Spawning while driving replaces the car you are in. Every card is built
-- from CarCatalog, so a new catalog entry shows up here with no code change.
--
-- The request is only a wish: the server checks the id, the cooldown and
-- whether a spawn is already building, and does the seating itself.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared.ConfigLoader)
local VehicleRig = require(Shared.VehicleRig)

local SpawnMenu = {}

local INK = Color3.fromRGB(15, 15, 18)
local CARD = Color3.fromRGB(28, 28, 33)
local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 175)
local HOT = Color3.fromRGB(255, 165, 40)
local HOT_DIM = Color3.fromRGB(120, 84, 34)

local ACTION = "HJ_SpawnMenu"

local gui: ScreenGui? = nil
local backdrop: TextButton? = nil
local list: ScrollingFrame? = nil
local status: TextLabel? = nil
local spawnButtons: { [string]: TextButton } = {}
local remote: RemoteEvent? = nil
local currentCarId: string? = nil
local waitingUntil = 0

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, text: string, font: Enum.Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Parent = parent
	return l
end

local function isTouch(): boolean
	return UserInputService.TouchEnabled or Players.LocalPlayer:GetAttribute("ForceTouch") == true
end

local function specLine(entry: VehicleRig.CarEntry): string
	local k = VehicleRig.scaleOf(entry)
	local r = entry.rig
	local mass = tostring(math.floor(r.massKg + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return string.format("%.1f m long   ·   %s kg   ·   rear-wheel drive", r.collisionSizeM[3] * k, mass)
end

local function refreshButtons()
	local busy = os.clock() < waitingUntil
	for id, btn in spawnButtons do
		local current = id == currentCarId
		btn.Text = if busy then "…" elseif current then "RESPAWN" else "SPAWN"
		btn.BackgroundColor3 = if busy then HOT_DIM else HOT
		btn.AutoButtonColor = not busy
		local card = btn.Parent
		if card then
			local stroke = card:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = if current then 0.1 else 1
			end
			local chip = card:FindFirstChild("Current")
			if chip and chip:IsA("TextLabel") then
				chip.Visible = current
			end
		end
	end
end

local function sortedCars(): { { id: string, entry: VehicleRig.CarEntry } }
	local out = {}
	for id, entry in ConfigLoader.catalog().cars do
		table.insert(out, { id = id, entry = entry })
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

local function buildCard(parent: Instance, id: string, entry: VehicleRig.CarEntry, order: number)
	local card = Instance.new("Frame")
	card.Name = "Car_" .. id
	card.BackgroundColor3 = CARD
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1, 0, 0, 92)
	card.LayoutOrder = order
	corner(card, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = HOT
	stroke.Thickness = 2
	stroke.Transparency = 1
	stroke.Parent = card
	card.Parent = parent

	-- The car's paint, as a stripe down the left edge.
	local swatch = Instance.new("Frame")
	swatch.Name = "Paint"
	swatch.BackgroundColor3 = entry.body.paint
	swatch.BorderSizePixel = 0
	swatch.Position = UDim2.fromOffset(12, 14)
	swatch.Size = UDim2.new(0, 8, 1, -28)
	corner(swatch, 4)
	swatch.Parent = card

	local name = label(card, entry.displayName, Enum.Font.GothamBlack, 22, WHITE)
	name.Position = UDim2.fromOffset(34, 12)
	name.Size = UDim2.new(1, -170, 0, 26)

	local chip = label(card, "IN USE", Enum.Font.GothamBold, 11, HOT)
	chip.Name = "Current"
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Position = UDim2.fromOffset(34, 12)
	chip.Size = UDim2.fromOffset(0, 26)
	chip.Visible = false
	-- Sits after the name: pad it past the name's text.
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, name.TextBounds.X + 10)
	pad.Parent = chip
	name:GetPropertyChangedSignal("TextBounds"):Connect(function()
		pad.PaddingLeft = UDim.new(0, name.TextBounds.X + 10)
	end)

	local blurb = label(card, entry.blurb or "", Enum.Font.Gotham, 14, MUTED)
	blurb.Position = UDim2.fromOffset(34, 40)
	blurb.Size = UDim2.new(1, -170, 0, 18)
	blurb.TextTruncate = Enum.TextTruncate.AtEnd

	local specs = label(card, specLine(entry), Enum.Font.GothamMedium, 12, MUTED)
	specs.Position = UDim2.fromOffset(34, 62)
	specs.Size = UDim2.new(1, -170, 0, 16)
	specs.TextTransparency = 0.25

	local btn = Instance.new("TextButton")
	btn.Name = "Spawn"
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, -14, 0.5, 0)
	btn.Size = UDim2.fromOffset(118, 48)
	btn.BackgroundColor3 = HOT
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBlack
	btn.TextSize = 17
	btn.TextColor3 = INK
	btn.Text = "SPAWN"
	corner(btn, 10)
	btn.Parent = card
	btn.Activated:Connect(function()
		if os.clock() < waitingUntil or not remote then
			return
		end
		waitingUntil = os.clock() + ConfigLoader.current().spawn.spawnCooldownSeconds
		refreshButtons()
		remote:FireServer(id)
		SpawnMenu.close()
		task.delay(ConfigLoader.current().spawn.spawnCooldownSeconds + 0.05, refreshButtons)
	end)
	spawnButtons[id] = btn
end

local function build()
	local player = Players.LocalPlayer
	local g = Instance.new("ScreenGui")
	g.Name = "HajwalaSpawnMenu"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 20
	g.Enabled = false

	-- The dim backdrop is a button so a click outside the panel closes the
	-- menu, and Modal so the mouse is free while it is open. A button behind
	-- the panel still hears clicks on the panel (Active does not stop it),
	-- so it checks where the click landed.
	local back = Instance.new("TextButton")
	back.Name = "Backdrop"
	back.Text = ""
	back.AutoButtonColor = false
	back.BackgroundColor3 = Color3.new(0, 0, 0)
	back.BackgroundTransparency = 0.45
	back.BorderSizePixel = 0
	back.Size = UDim2.fromScale(1, 1)
	back.Modal = true
	back.Parent = g
	backdrop = back

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.92, 0, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = INK
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Active = true -- clicks on the panel do not reach the backdrop
	panel.ZIndex = 2
	corner(panel, 14)
	local maxSize = Instance.new("UISizeConstraint")
	maxSize.MaxSize = Vector2.new(560, math.huge)
	maxSize.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 18)
	pad.PaddingBottom = UDim.new(0, 16)
	pad.PaddingLeft = UDim.new(0, 18)
	pad.PaddingRight = UDim.new(0, 18)
	pad.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 12)
	layout.Parent = panel
	panel.Parent = g
	back.Activated:Connect(function(io: InputObject)
		-- Input positions leave out the top bar; this gui ignores the inset,
		-- so its absolute positions include it.
		local p = Vector2.new(io.Position.X, io.Position.Y) + GuiService:GetGuiInset()
		local a, size = panel.AbsolutePosition, panel.AbsoluteSize
		local inside = p.X >= a.X and p.X <= a.X + size.X and p.Y >= a.Y and p.Y <= a.Y + size.Y
		if not inside then
			SpawnMenu.close()
		end
	end)

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 44)
	header.LayoutOrder = 1
	header.Parent = panel
	local title = label(header, "CHOOSE YOUR CAR", Enum.Font.GothamBlack, 24, WHITE)
	title.Size = UDim2.new(1, -60, 0, 26)
	local sub = label(header, "اختر سيارتك", Enum.Font.GothamMedium, 15, HOT)
	sub.Position = UDim2.fromOffset(0, 26)
	sub.Size = UDim2.new(1, -60, 0, 18)
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.fromOffset(40, 40)
	close.BackgroundColor3 = CARD
	close.BorderSizePixel = 0
	close.Text = "×"
	close.Font = Enum.Font.GothamBold
	close.TextSize = 26
	close.TextColor3 = MUTED
	corner(close, 10)
	close.Parent = header
	close.Activated:Connect(function()
		SpawnMenu.close()
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Cars"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = 2
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = MUTED
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	local cardList = Instance.new("UIListLayout")
	cardList.FillDirection = Enum.FillDirection.Vertical
	cardList.SortOrder = Enum.SortOrder.LayoutOrder
	cardList.Padding = UDim.new(0, 10)
	cardList.Parent = scroll
	scroll.Parent = panel
	list = scroll

	local cars = sortedCars()
	for i, car in cars do
		buildCard(scroll, car.id, car.entry, i)
	end
	-- Tall enough for every card up to four, then it scrolls. Capped by the
	-- screen so a phone in landscape still shows the header and footer.
	local want = math.min(#cars, 4) * 102 - 10
	local function fit()
		local screenH = g.AbsoluteSize.Y
		scroll.Size = UDim2.new(1, 0, 0, math.max(92, math.min(want, screenH - 190)))
	end
	g:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

	local footer = label(panel, "", Enum.Font.GothamMedium, 13, MUTED)
	footer.Name = "Footer"
	footer.LayoutOrder = 3
	footer.Size = UDim2.new(1, 0, 0, 18)
	footer.TextXAlignment = Enum.TextXAlignment.Center
	footer.Text = if isTouch() then "Tap CARS to come back here" else "Press M to come back here"
	status = footer

	-- The CARS button, on every platform: the only way back in on a phone.
	-- Bottom centre: the top left is the debug panel, the top centre the HUD,
	-- the top right Roblox's own menus (a click there hits CoreGui), and on a
	-- phone the steer pad and the pedals leave the bottom centre free.
	local open = Instance.new("TextButton")
	open.Name = "OpenSpawnMenu"
	open.AnchorPoint = Vector2.new(0.5, 1)
	open.Position = UDim2.new(0.5, 0, 1, -14)
	open.Size = UDim2.fromOffset(92, 38)
	open.BackgroundColor3 = INK
	open.BackgroundTransparency = 0.35
	open.BorderSizePixel = 0
	open.Font = Enum.Font.GothamBlack
	open.TextSize = 15
	open.TextColor3 = WHITE
	open.Text = if isTouch() then "CARS" else "CARS  (M)"
	corner(open, 10)
	local openGui = Instance.new("ScreenGui")
	openGui.Name = "HajwalaSpawnButton"
	openGui.ResetOnSpawn = false
	openGui.DisplayOrder = 7
	open.Parent = openGui
	open.Activated:Connect(function()
		SpawnMenu.toggle()
	end)
	openGui.Parent = player:WaitForChild("PlayerGui")

	g.Parent = player:WaitForChild("PlayerGui")
	fit()
	gui = g
end

function SpawnMenu.isOpen(): boolean
	return gui ~= nil and (gui :: ScreenGui).Enabled
end

function SpawnMenu.open()
	if not gui then
		return
	end
	refreshButtons()
	local g = gui :: ScreenGui
	g.Enabled = true
	if list then
		list.CanvasPosition = Vector2.zero
	end
	if status then
		status.Text = if isTouch() then "Tap CARS to come back here" else "Press M to come back here"
	end
	if backdrop then
		backdrop.Modal = true
	end
end

function SpawnMenu.close()
	if gui then
		(gui :: ScreenGui).Enabled = false
	end
	if backdrop then
		backdrop.Modal = false
	end
end

function SpawnMenu.toggle()
	if SpawnMenu.isOpen() then
		SpawnMenu.close()
	else
		SpawnMenu.open()
	end
end

-- The car the player is in now, so its card reads RESPAWN. nil when on foot
-- is fine: the last car stays marked.
function SpawnMenu.setCurrent(carId: string?)
	if carId then
		currentCarId = carId
	end
	refreshButtons()
end

function SpawnMenu.start(remotes: Folder)
	remote = remotes:WaitForChild("SpawnCar") :: RemoteEvent
	build()
	ContextActionService:BindAction(ACTION, function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			SpawnMenu.toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M)
	-- You start on foot: open straight away.
	SpawnMenu.open()
end

return SpawnMenu
