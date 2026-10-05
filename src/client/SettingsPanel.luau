--!strict
-- The Settings tab of the car menu. SpawnMenu owns the panel and shows this
-- in place of the car list.
--   * Time of day: one button per SkyConfig option (Sunset, Night). The
--     world changes at once, on this player's screen only (Sky).
--   * Drift style: one chip per style of the current car's drivetrain
--     (DriftStyles), and the chosen one's line under them; the car takes
--     it at once (DriftStyle). The owner, 2026-10-05: styles "that i can
--     test and try out in game".
--
-- Its chrome reads UITheme (UI_SYSTEM.md); re-skinned onto the tokens on
-- 2026-09-28, replacing the Theme table SpawnMenu used to pass in.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkyConfig = require(Shared:WaitForChild("SkyConfig"))
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local UITheme = require(Shared:WaitForChild("UITheme"))
local Sky = require(script.Parent.Sky)
local DriftStyle = require(script.Parent.DriftStyle)
local UIKit = require(script.Parent.UIKit)

local SettingsPanel = {}

local C = UITheme.color
local root: ScrollingFrame? = nil
local heading: TextLabel? = nil
local row: Frame? = nil
local note: TextLabel? = nil
local skyButtons: { [string]: TextButton } = {}
local driftHeading: TextLabel? = nil
local driftRow: Frame? = nil
local driftNote: TextLabel? = nil
local driftButtons: { [string]: TextButton } = {}
local driftLayout: string? = nil -- the drivetrain the chips were built for
local touchNow = UIKit.isTouch()

-- The chosen sky and drift style take the selected state (sodiumDim,
-- sodium stroke); the drift style's line goes under its chips.
local function paint()
	local current = Sky.current()
	for id, b in skyButtons do
		UIKit.setSelected(b, id == current)
	end
	local layout = DriftStyle.carLayout()
	local chosen = DriftStyle.current(layout)
	for id, b in driftButtons do
		UIKit.setSelected(b, id == chosen)
	end
	local n = driftNote
	if n then
		n.Text = ConfigLoader.driftStyles().styles[chosen].blurb
	end
end

-- One chip per style of the car's drivetrain, rebuilt when it changes.
local function buildDriftChips()
	local r, h = driftRow, driftHeading
	if not r or not h then
		return
	end
	local layout = DriftStyle.carLayout()
	h.Text = "DRIFT MODE · " .. string.upper(ConfigLoader.driftStyles().layoutName[layout])
	if driftLayout == layout then
		return
	end
	driftLayout = layout
	for _, b in driftButtons do
		b:Destroy()
	end
	table.clear(driftButtons)
	local ids = ConfigLoader.driftStyles().forLayout(layout)
	local count = #ids
	for i, id in ids do
		local b = UIKit.chip(r, ConfigLoader.driftStyles().styles[id].name, touchNow)
		b.Name = "Drift_" .. id
		b.AutomaticSize = Enum.AutomaticSize.None
		b.LayoutOrder = i
		b.Size = UDim2.new(1 / count, -8 * (count - 1) / count, 1, 0)
		b.TextSize = UITheme.textSize("label", touchNow)
		b.Activated:Connect(function()
			DriftStyle.set(id)
		end)
		driftButtons[id] = b
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

-- The tab scrolls: with the drift styles under the time of day it needs
-- 270 px on touch, and a phone in landscape leaves the tab 163-222, where
-- the chips ran over the footer and the blurb off the panel (final review,
-- 2026-10-05). The Plates tab's list scrolls its buttons the same way.
function SettingsPanel.build(parent: Instance, layoutOrder: number): ScrollingFrame
	local f = Instance.new("ScrollingFrame")
	f.Name = "Settings"
	f.BorderSizePixel = 0
	f.ScrollBarThickness = 4
	f.ScrollBarImageColor3 = C.asphalt500
	f.CanvasSize = UDim2.fromOffset(0, 0)
	f.AutomaticCanvasSize = Enum.AutomaticSize.Y
	f.ScrollingDirection = Enum.ScrollingDirection.Y
	-- When it scrolls, the bar takes its own strip instead of covering the
	-- chips' right edge.
	f.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
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

	-- Drift style: a section title like the sky's, a row of chips, the
	-- chosen style's line (wrapping, two lines).
	local dh = text(f, "DRIFT MODE", 4)
	dh.FontFace = UITheme.font("title")
	dh.TextColor3 = C.paint
	driftHeading = dh
	local dr = Instance.new("Frame")
	dr.Name = "Drift"
	dr.BackgroundTransparency = 1
	dr.LayoutOrder = 5
	local drLayout = Instance.new("UIListLayout")
	drLayout.FillDirection = Enum.FillDirection.Horizontal
	drLayout.SortOrder = Enum.SortOrder.LayoutOrder
	drLayout.Padding = UDim.new(0, 8)
	drLayout.Parent = dr
	dr.Parent = f
	driftRow = dr
	local dn = text(f, "", 6)
	dn.FontFace = UITheme.font("caption")
	dn.TextColor3 = C.sandDim
	dn.TextWrapped = true
	dn.TextYAlignment = Enum.TextYAlignment.Top
	driftNote = dn
	buildDriftChips()

	Sky.changed = function()
		paint()
	end
	DriftStyle.panelChanged = function()
		buildDriftChips()
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
	-- Time of day (title, row, note) and drift style (title, row, a
	-- two-line note), 8 between each.
	return headH + rowH + noteH + headH + rowH + 2 * noteH + 8 * 5
end

-- Sizes the tab to the height the menu gives it.
function SettingsPanel.fit(height: number, isTouch: boolean)
	local f, h, r, n = root, heading, row, note
	if not f or not h or not r or not n then
		return
	end
	f.Size = UDim2.new(1, 0, 0, height)
	f.ScrollBarThickness = if isTouch then 6 else 4
	h.Size = UDim2.new(1, 0, 0, if isTouch then 26 else 22)
	h.TextSize = UITheme.textSize("title", isTouch)
	r.Size = UDim2.new(1, 0, 0, if isTouch then 56 else 44)
	for _, b in skyButtons do
		b.TextSize = UITheme.textSize("label", isTouch)
	end
	n.Size = UDim2.new(1, 0, 0, if isTouch then 22 else 18)
	n.TextSize = UITheme.textSize("caption", isTouch)
	touchNow = isTouch
	local dh, dr, dn = driftHeading, driftRow, driftNote
	if dh and dr and dn then
		dh.Size = h.Size
		dh.TextSize = h.TextSize
		dr.Size = r.Size
		for _, b in driftButtons do
			b.TextSize = UITheme.textSize("label", isTouch)
		end
		dn.Size = UDim2.new(1, 0, 0, 2 * (if isTouch then 22 else 18))
		dn.TextSize = n.TextSize
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
