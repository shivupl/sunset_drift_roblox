--!strict
-- The Settings tab of the car menu. SpawnMenu owns the panel and shows this
-- in place of the car list.
--   * Time of day: one button per SkyConfig option (Sunset, Night). The
--     world changes at once, on this player's screen only (Sky).
--   * HUD style: one button per finish of the HUD (HudLab, Finishes.luau),
--     so a phone can pick one before driving (the owner, 2026-10-08: "there
--     is no way for me to cycle UIs on the phone"; 2026-10-10: "make a
--     couple variants of the same deisgn i can cycle through"). The STYLE
--     button while driving and U cycle the same list.
--
-- Its chrome reads UITheme (UI_SYSTEM.md); re-skinned onto the tokens on
-- 2026-09-28, replacing the Theme table SpawnMenu used to pass in.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkyConfig = require(Shared:WaitForChild("SkyConfig"))
local UITheme = require(Shared:WaitForChild("UITheme"))
local Players = game:GetService("Players")
local Sky = require(script.Parent.Sky)
local UIKit = require(script.Parent.UIKit)
local HudLab = require(script.Parent:WaitForChild("HudLab"))

local SettingsPanel = {}

local C = UITheme.color
local root: Frame? = nil
local heading: TextLabel? = nil
local row: Frame? = nil
local note: TextLabel? = nil
local skyButtons: { [string]: TextButton } = {}
local hudHeading: TextLabel? = nil
local hudGrid: Frame? = nil
local hudGridLayout: UIGridLayout? = nil
local hudNote: TextLabel? = nil
local hudButtons: { [string]: TextButton } = {}
-- Style buttons per row of the grid.
local HUD_COLUMNS = 3

-- The chosen sky and style take the selected state (sodiumDim, sodium stroke).
local function paint()
	local current = Sky.current()
	for id, b in skyButtons do
		UIKit.setSelected(b, id == current)
	end
	local style = HudLab.current()
	for id, b in hudButtons do
		UIKit.setSelected(b, id == style)
	end
end

local function hudRows(): number
	return math.max(1, math.ceil(#HudLab.styles() / HUD_COLUMNS))
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

function SettingsPanel.build(parent: Instance, layoutOrder: number): Frame
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

	-- A section title: title role in paint.
	local h = text(f, "TIME OF DAY", 1)
	h.FontFace = UITheme.font("title")
	h.TextColor3 = C.paint
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
		-- An option chip; paint() marks the chosen one selected.
		local b = UIKit.chip(r, option.label, UIKit.isTouch())
		b.Name = "Sky_" .. option.id
		b.AutomaticSize = Enum.AutomaticSize.None
		b.LayoutOrder = i
		b.Size = UDim2.new(1 / count, -8 * (count - 1) / count, 1, 0)
		b.Activated:Connect(function()
			Sky.set(option.id)
		end)
		skyButtons[option.id] = b
	end
	r.Parent = f
	row = r

	local n = text(f, "Changes only what you see", 3)
	-- A hint: caption role in sandDim.
	n.FontFace = UITheme.font("caption")
	n.TextColor3 = C.sandDim
	note = n

	local hh = text(f, "HUD STYLE", 4)
	hh.FontFace = UITheme.font("title")
	hh.TextColor3 = C.paint
	hudHeading = hh
	local grid = Instance.new("Frame")
	grid.Name = "HudStyle"
	grid.BackgroundTransparency = 1
	grid.LayoutOrder = 5
	local gl = Instance.new("UIGridLayout")
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.CellPadding = UDim2.fromOffset(8, 8)
	gl.Parent = grid
	hudGridLayout = gl
	for i, style in HudLab.styles() do
		local b = UIKit.chip(grid, style.name, UIKit.isTouch())
		b.Name = "Hud_" .. style.id
		b.AutomaticSize = Enum.AutomaticSize.None
		b.LayoutOrder = i
		b.Activated:Connect(function()
			HudLab.set(style.id)
		end)
		hudButtons[style.id] = b
	end
	grid.Parent = f
	hudGrid = grid
	local hn = text(f, "While driving: the STYLE button, or U", 6)
	hn.FontFace = UITheme.font("caption")
	hn.TextColor3 = C.sandDim
	hudNote = hn
	Players.LocalPlayer:GetAttributeChangedSignal("HudVariant"):Connect(paint)

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
	local rows = hudRows()
	local gridH = rows * rowH + (rows - 1) * 8
	return (headH + rowH + noteH) + (headH + gridH + noteH) + 8 * 5
end

-- Sizes the tab to the height the menu gives it.
function SettingsPanel.fit(height: number, isTouch: boolean)
	local f, h, r, n = root, heading, row, note
	if not f or not h or not r or not n then
		return
	end
	f.Size = UDim2.new(1, 0, 0, height)
	h.Size = UDim2.new(1, 0, 0, if isTouch then 26 else 22)
	h.TextSize = UITheme.textSize("title", isTouch)
	r.Size = UDim2.new(1, 0, 0, if isTouch then 56 else 44)
	for _, b in skyButtons do
		b.TextSize = UITheme.textSize("label", isTouch)
	end
	n.Size = UDim2.new(1, 0, 0, if isTouch then 22 else 18)
	n.TextSize = UITheme.textSize("caption", isTouch)
	local hh, grid, gl, hn = hudHeading, hudGrid, hudGridLayout, hudNote
	if hh and grid and gl and hn then
		local rowH = if isTouch then 56 else 44
		local rows = hudRows()
		hh.Size = h.Size
		hh.TextSize = h.TextSize
		grid.Size = UDim2.new(1, 0, 0, rows * rowH + (rows - 1) * 8)
		gl.CellSize = UDim2.new(1 / HUD_COLUMNS, -8 * (HUD_COLUMNS - 1) / HUD_COLUMNS, 0, rowH)
		for _, b in hudButtons do
			b.TextSize = UITheme.textSize("label", isTouch)
		end
		hn.Size = n.Size
		hn.TextSize = n.TextSize
	end
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
