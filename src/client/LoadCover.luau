--!strict
-- The cover shown while the server is still building the world.
--
-- A server builds the whole world when it starts, and a player testing alone
-- starts a new server with every join, so they arrive tens of seconds before
-- the road, the dunes and the car spawner exist. Without this they stand in a
-- half-built desert with a menu whose SPAWN buttons do nothing. The server
-- sets ReplicatedStorage's WorldReady attribute when the build is done.
--
-- Colours and type read UITheme (UI_SYSTEM.md); re-skinned onto the tokens
-- on 2026-09-28: the name in hero, the note in body, the bar in sodium.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UITheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local UIKit = require(script.Parent.UIKit)

local LoadCover = {}

local C = UITheme.color

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
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100 -- over the HUD and the cars menu
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = C.asphalt900
	back.BorderSizePixel = 0
	back.Active = true -- swallow taps meant for what is underneath
	back.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.AnchorPoint = Vector2.new(0.5, 1)
	title.Position = UDim2.new(0.5, 0, 0.5, -4)
	title.Size = UDim2.new(0.9, 0, 0, UITheme.textSize("hero", touch))
	title.BackgroundTransparency = 1
	title.FontFace = UITheme.font("hero")
	title.TextSize = UITheme.textSize("hero", touch)
	title.TextColor3 = C.paint
	title.Text = "HAJWALA"
	title.Parent = back

	local note = Instance.new("TextLabel")
	note.Name = "Note"
	note.AnchorPoint = Vector2.new(0.5, 0)
	note.Position = UDim2.new(0.5, 0, 0.5, 4)
	note.Size = UDim2.new(0.9, 0, 0, 22)
	note.BackgroundTransparency = 1
	note.FontFace = UITheme.font("body")
	note.TextSize = UITheme.textSize("body", touch)
	note.TextColor3 = C.sand
	note.Text = "Laying out the desert"
	note.Parent = back

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0.5, 38)
	bar.Size = UDim2.fromOffset(36, 3)
	bar.BackgroundColor3 = C.sodium
	bar.BorderSizePixel = 0
	bar.Parent = back
	local pulse = TweenService:Create(bar, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = UDim2.fromOffset(120, 3) })
	pulse:Play()

	gui.Parent = pg

	task.spawn(function()
		while not ready() do
			ReplicatedStorage:GetAttributeChangedSignal("WorldReady"):Wait()
		end
		pulse:Cancel()
		local info = TweenInfo.new(FADE_SECONDS)
		TweenService:Create(back, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(title, info, { TextTransparency = 1 }):Play()
		TweenService:Create(note, info, { TextTransparency = 1 }):Play()
		TweenService:Create(bar, info, { BackgroundTransparency = 1 }):Play()
		task.wait(FADE_SECONDS)
		gui:Destroy()
	end)
end

return LoadCover
