--!strict
-- The Settings tab of the car menu. SpawnMenu owns the panel and shows this
-- in place of the car list.
--   * Time of day: one button per SkyConfig option (Sunset, Night). The
--     world changes at once, on this player's screen only (Sky).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SkyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SkyConfig"))
local Sky = require(script.Parent.Sky)

export type Theme = { card: Color3, white: Color3, muted: Color3, hot: Color3, hotDim: Color3 }

local SettingsPanel = {}

local INK = Color3.fromRGB(15, 15, 18)

local theme: Theme? = nil
local root: Frame? = nil
local heading: TextLabel? = nil
local row: Frame? = nil
local note: TextLabel? = nil
local skyButtons: { [string]: TextButton } = {}

local function t(): Theme
	return theme :: Theme
end

local function paint()
	local current = Sky.current()
	for id, b in skyButtons do
		local on = id == current
		b.BackgroundColor3 = if on then t().hot else t().card
		b.TextColor3 = if on then INK else t().muted
	end
end

local function text(parent: Instance, s: string, order: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = s
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.LayoutOrder = order
	l.Parent = parent
	return l
end

function SettingsPanel.build(parent: Instance, th: Theme, layoutOrder: number): Frame
	theme = th
	local f = Instance.new("Frame")
	f.Name = "Settings"
	f.BackgroundTransparency = 1
	f.LayoutOrder = layoutOrder
	f.Visible = false
	f.Size = UDim2.new(1, 0, 0, 120)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = f

	local h = text(f, "TIME OF DAY", 1)
	h.Font = Enum.Font.GothamBlack
	h.TextColor3 = th.white
	heading = h

	local r = Instance.new("Frame")
	r.Name = "Sky"
	r.BackgroundTransparency = 1
	r.LayoutOrder = 2
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.Parent = r
	local count = #SkyConfig.options
	for i, option in SkyConfig.options do
		local b = Instance.new("TextButton")
		b.Name = "Sky_" .. option.id
		b.AutoButtonColor = false
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBlack
		b.Text = string.upper(option.label)
		b.LayoutOrder = i
		b.Size = UDim2.new(1 / count, -8 * (count - 1) / count, 1, 0)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = b
		b.Parent = r
		b.Activated:Connect(function()
			Sky.set(option.id)
		end)
		skyButtons[option.id] = b
	end
	r.Parent = f
	row = r

	local n = text(f, "Changes only what you see", 3)
	n.Font = Enum.Font.GothamMedium
	n.TextColor3 = th.muted
	note = n

	Sky.changed = function()
		paint()
	end
	paint()
	f.Parent = parent
	root = f
	return f
end

-- The height the tab needs at this size, for the menu to give it.
function SettingsPanel.height(isTouch: boolean): number
	local headH = if isTouch then 26 else 22
	local rowH = if isTouch then 56 else 44
	local noteH = if isTouch then 22 else 18
	return headH + rowH + noteH + 8 * 2
end

-- Sizes the tab to the height the menu gives it.
function SettingsPanel.fit(height: number, isTouch: boolean)
	local f, h, r, n = root, heading, row, note
	if not f or not h or not r or not n then
		return
	end
	f.Size = UDim2.new(1, 0, 0, height)
	h.Size = UDim2.new(1, 0, 0, if isTouch then 26 else 22)
	h.TextSize = if isTouch then 18 else 15
	r.Size = UDim2.new(1, 0, 0, if isTouch then 56 else 44)
	for _, b in skyButtons do
		b.TextSize = if isTouch then 20 else 16
	end
	n.Size = UDim2.new(1, 0, 0, if isTouch then 22 else 18)
	n.TextSize = if isTouch then 15 else 13
end

function SettingsPanel.setVisible(visible: boolean)
	local f = root
	if f then
		f.Visible = visible
		if visible then
			paint()
		end
	end
end

return SettingsPanel
