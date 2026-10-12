--!strict
-- The cover shown while the server is still building the world.
--
-- A server builds the whole world when it starts, and a player testing alone
-- starts a new server with every join, so they arrive tens of seconds before
-- the road, the dunes and the car spawner exist. Without this they stand in a
-- half-built desert with a menu whose SPAWN buttons do nothing. The server
-- sets ReplicatedStorage's WorldReady attribute when the build is done.
--
-- It wears the menu's look (CarPicker/Kit: graphite, heavy italic
-- Montserrat, the green), since the menu is what comes up as it fades
-- (ui-flow, 2026-10-12: it was the old UITheme look, a third style between
-- joining and the first menu).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIKit = require(script.Parent.UIKit)
local Kit = require(script.Parent:WaitForChild("CarPicker"):WaitForChild("Kit"))

local LoadCover = {}

local FADE_SECONDS = 0.6

local function ready(): boolean
	-- nil means a server that never sets the flag (an older build): no cover.
	return ReplicatedStorage:GetAttribute("WorldReady") ~= false
end

-- Runs fn once the world is built; at once if it already is. For anything
-- that reads what the build leaves behind (WorldSettings, tagged lamps).
function LoadCover.whenReady(fn: () -> ())
	task.spawn(function()
		while not ready() do
			ReplicatedStorage:GetAttributeChangedSignal("WorldReady"):Wait()
		end
		fn()
	end)
end

function LoadCover.start()
	if ready() then
		return
	end
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local touch = UIKit.isTouch()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HajwalaLoadCover"
	gui.IgnoreGuiInset = true
	-- The whole screen, notch and home bar too: inside the safe area the
	-- world showed in a strip down the side (UIKit.edgeToEdge). Its words
	-- are in the middle.
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ClipToDeviceSafeArea = false
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100 -- over the HUD and the cars menu
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	back.BorderSizePixel = 0
	back.Active = true -- swallow taps meant for what is underneath
	Kit.gradient(back, Kit.C.panelTop, Kit.C.panelBottom)
	back.Parent = gui

	-- The name and its Arabic side by side, as the menu's title has them.
	local size = if touch then 46 else 56
	local title = Kit.frame(back, "Title")
	title.AnchorPoint = Vector2.new(0.5, 1)
	title.Position = UDim2.new(0.5, 0, 0.5, -2)
	title.AutomaticSize = Enum.AutomaticSize.X
	title.Size = UDim2.fromOffset(0, size + 6)
	local row = Kit.list(title, false, math.floor(size * 0.35), Enum.VerticalAlignment.Center)
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local en = Kit.text(title, "English", "HAJWALA", size, Enum.FontWeight.Heavy, true)
	en.AutomaticSize = Enum.AutomaticSize.X
	en.Size = UDim2.fromScale(0, 1)
	en.TextTruncate = Enum.TextTruncate.None
	local ar = Kit.text(title, "Arabic", "هجولة", math.floor(size * 0.8), Enum.FontWeight.Bold, false, Color3.fromHex("#C6AC84"))
	ar.LayoutOrder = 1
	ar.AutomaticSize = Enum.AutomaticSize.X
	ar.Size = UDim2.fromScale(0, 1)
	ar.TextTruncate = Enum.TextTruncate.None

	local note = Kit.text(back, "Note", "Laying out the desert", if touch then 14 else 16, Enum.FontWeight.SemiBold, false, Kit.C.sub)
	note.AnchorPoint = Vector2.new(0.5, 0)
	note.Position = UDim2.new(0.5, 0, 0.5, 6)
	note.Size = UDim2.new(0.9, 0, 0, 22)
	note.TextXAlignment = Enum.TextXAlignment.Center

	-- The green of the menu's go buttons, breathing.
	local bar = Kit.frame(back, "Bar", Color3.new(1, 1, 1), 0)
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0.5, 40)
	bar.Size = UDim2.fromOffset(36, 4)
	Kit.corner(bar, 2)
	Kit.gradient(bar, Kit.C.greenTop, Kit.C.greenBottom).Rotation = 0
	local pulse = TweenService:Create(bar, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = UDim2.fromOffset(120, 4) })
	pulse:Play()

	gui.Parent = pg

	task.spawn(function()
		while not ready() do
			ReplicatedStorage:GetAttributeChangedSignal("WorldReady"):Wait()
		end
		pulse:Cancel()
		local info = TweenInfo.new(FADE_SECONDS)
		TweenService:Create(back, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(en, info, { TextTransparency = 1 }):Play()
		TweenService:Create(ar, info, { TextTransparency = 1 }):Play()
		TweenService:Create(note, info, { TextTransparency = 1 }):Play()
		TweenService:Create(bar, info, { BackgroundTransparency = 1 }):Play()
		task.wait(FADE_SECONDS)
		gui:Destroy()
	end)
end

return LoadCover
