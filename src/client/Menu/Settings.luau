--!strict
-- The menu's SETTINGS, in the frame every screen shares (ui-flow,
-- 2026-10-12; it was the old spawn menu's panel, where its rows ran into
-- each other on a phone). The column is the settings, each a row of the
-- slanted choices the sub-tabs use, the one in force green:
--   TIME OF DAY    Sunset or Night (SkyConfig); the world changes at once,
--                  on this screen only, and the world behind is left
--                  unblurred so it shows.
--   SCREEN LAYOUT  the layout every menu and the garage follow (Layouts).
--   HUD STYLE      the driving HUD's finish (HudLab; STYLE or U cycle it).
--   HUD LAYOUT     the driving HUD's version (HudLab; Y cycles it).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SkyConfig"))

local Client = script.Parent.Parent
local Kit = require(Client:WaitForChild("CarPicker"):WaitForChild("Kit"))
local Art = require(Client:WaitForChild("CarPicker"):WaitForChild("Art"))
local Sky = require(Client:WaitForChild("Sky"))
local HudLab = require(Client:WaitForChild("HudLab"))
local Looks = Client:WaitForChild("Garage"):WaitForChild("Looks")
local Types = require(Looks:WaitForChild("Types"))
local Parts = require(Looks:WaitForChild("Parts"))
local Layouts = require(Looks:WaitForChild("Layouts"))
local Page = require(script.Parent:WaitForChild("Page"))

local Settings = {}

type Option = { id: string, label: string }
type Row = {
	title: string,
	hint: string?,
	options: () -> { Option },
	current: () -> string,
	pick: (id: string) -> (),
}

local ROWS: { Row } = {
	{
		title = "TIME OF DAY",
		hint = "Changes only what you see",
		options = function()
			local out: { Option } = {}
			for _, o in SkyConfig.options do
				table.insert(out, { id = o.id, label = string.upper(o.label) })
			end
			return out
		end,
		current = Sky.current,
		pick = Sky.set,
	},
	{
		title = "SCREEN LAYOUT",
		hint = "Every menu and the garage",
		options = function()
			local out: { Option } = {}
			for _, l in Layouts.list do
				table.insert(out, { id = l.id, label = l.name })
			end
			return out
		end,
		current = function()
			return Layouts.current().id
		end,
		pick = Layouts.set,
	},
	{
		title = "HUD STYLE",
		hint = "While driving: STYLE, or U",
		options = function()
			local out: { Option } = {}
			for _, s in HudLab.styles() do
				table.insert(out, { id = s.id, label = s.name })
			end
			return out
		end,
		current = HudLab.current,
		pick = HudLab.set,
	},
	{
		title = "HUD LAYOUT",
		hint = nil,
		options = function()
			local out: { Option } = {}
			for _, v in HudLab.versions() do
				table.insert(out, { id = v.id, label = v.name })
			end
			return out
		end,
		current = HudLab.currentVersion,
		pick = HudLab.setVersion,
	},
}

function Settings.new(shell: Page.Shell): Page.Page
	-- The choices drawn by the last fill, to paint.
	local drawn: { { row: Row, id: string, b: ImageLabel, g: UIGradient, t: TextLabel } } = {}

	local function paint()
		for _, d in drawn do
			local on = d.row.current() == d.id
			d.g.Enabled = on
			d.b.ImageTransparency = if on then 0 else 0.92
			d.t.TextColor3 = if on then Kit.C.text else Kit.C.tabInk
		end
	end

	local page: Page.Page
	page = {
		tab = { id = "settings", label = "SETTINGS", arabic = "إعدادات", icon = Parts.TOPBAR_ICON.settings, sheet = Parts.TOPBAR_ICONS },
		blur = 0,
		dim = 0.8,
		views = function()
			return {}
		end,
		view = function()
			return "settings"
		end,
		setView = function(_id: string) end,
		note = function()
			return nil
		end,
		entries = function()
			return {}
		end,
		stateOf = function(_e: Types.Entry): Types.EntryState
			return { chosen = false, disabled = false, word = "", kind = "none" }
		end,
		tap = function(_e: Types.Entry) end,
		-- DONE: what is picked is in force already; this is the way out
		-- where the other screens have their action, so no layout shows a
		-- hole there.
		foot = function(): Types.Foot
			return { name = "", rare = false, note = "", action = "drive", price = 0, label = "DONE" }
		end,
		action = function()
			shell.hooks.close()
		end,
		subject = function()
			return "", ""
		end,
		starred = function()
			return nil
		end,
		star = function() end,
		form = function()
			return function(parent: Frame, width: number, shade: boolean): Types.Form
				local touch = shell.touch()
				table.clear(drawn)
				-- The rows scroll on a phone; an end with more past it fades,
				-- as the items do.
				local holder = Kit.frame(parent, "Settings")
				holder.Size = UDim2.fromOffset(width, 0)
				local scroll = Instance.new("ScrollingFrame")
				scroll.Name = "Rows"
				scroll.BackgroundTransparency = 1
				scroll.BorderSizePixel = 0
				scroll.Size = UDim2.fromScale(1, 1)
				scroll.ScrollBarThickness = 3
				scroll.ScrollBarImageColor3 = Color3.new(1, 1, 1)
				scroll.ScrollBarImageTransparency = 0.8
				scroll.ScrollingDirection = Enum.ScrollingDirection.Y
				scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
				scroll.CanvasSize = UDim2.new()
				scroll.Parent = holder
				Parts.fades(holder, touch, shade).watch(scroll)
				Kit.pad(scroll, 2, 6, 6, 2)
				Kit.list(scroll, true, if touch then 12 else 16)
				local h = if touch then 30 else 36
				local size = if touch then 10 else 12
				local gap = 6
				for i, row in ROWS do
					local section = Kit.frame(scroll, "Row" .. i)
					section.LayoutOrder = i
					section.AutomaticSize = Enum.AutomaticSize.Y
					section.Size = UDim2.new(1, 0, 0, 0)
					Kit.list(section, true, 5)
					local title = Kit.text(section, "Title", row.title, if touch then 11 else 13, Enum.FontWeight.ExtraBold, true, Kit.C.sub)
					title.Size = UDim2.new(1, 0, 0, if touch then 14 else 16)
					local options = row.options()
					-- Three across at most; four go two by two.
					local per = if #options == 4 then 2 else math.min(#options, 3)
					local grid = Kit.frame(section, "Choices")
					grid.LayoutOrder = 1
					grid.AutomaticSize = Enum.AutomaticSize.Y
					grid.Size = UDim2.new(1, 0, 0, 0)
					local layout = Instance.new("UIGridLayout")
					layout.SortOrder = Enum.SortOrder.LayoutOrder
					layout.CellPadding = UDim2.fromOffset(gap, gap)
					local inner = width - 8
					layout.CellSize = UDim2.fromOffset(math.floor((inner - gap * (per - 1)) / per), h)
					layout.Parent = grid
					for j, o in options do
						-- An image, not a button: the menu follows the press
						-- (shell.tap), as it does the blocks, so a tap that
						-- moves a little still counts and the rows still
						-- scroll under a thumb.
						local b = Instance.new("ImageLabel")
						b.Name = "Choice_" .. o.id
						b.LayoutOrder = j
						b.BackgroundTransparency = 1
						b.Image = Art.tab
						b.ScaleType = Enum.ScaleType.Slice
						b.SliceCenter = Art.tabSlice
						b.SliceScale = h / Art.tabH
						local g = Kit.gradient(b, Kit.C.greenTop, Kit.C.greenBottom)
						local t = Kit.text(b, "Label", o.label, size, Enum.FontWeight.ExtraBold, true, Kit.C.tabInk)
						t.Size = UDim2.fromScale(1, 1)
						t.TextXAlignment = Enum.TextXAlignment.Center
						t.TextTruncate = Enum.TextTruncate.None
						local press = Instance.new("UIScale")
						press.Parent = b
						b.Parent = grid
						shell.tap(b, scroll, function()
							if not shell.busy() and row.current() ~= o.id then
								shell.sound("tab")
								row.pick(o.id)
								paint()
							end
						end, function(down: boolean)
							press.Scale = if down then 0.96 else 1
						end)
						table.insert(drawn, { row = row, id = o.id, b = b, g = g, t = t })
					end
					local hint = row.hint
					if hint then
						local n = Kit.text(section, "Hint", hint, if touch then 10 else 11, Enum.FontWeight.SemiBold, false, Kit.C.faint)
						n.LayoutOrder = 2
						n.Size = UDim2.new(1, 0, 0, if touch then 13 else 15)
					end
				end
				paint()
				return { root = holder, fills = true }
			end
		end,
		stage = function(frame: Frame, _touch: boolean): Page.Stage
			-- Nothing: the world itself is what these change.
			local holder = Kit.frame(frame, "Clear")
			holder.Size = UDim2.fromScale(1, 1)
			return {
				refresh = function() end,
				destroy = function()
					holder:Destroy()
				end,
			}
		end,
		paint = paint,
		shown = function() end,
	}

	-- A choice made elsewhere (U, Y, STYLE, the LAYOUT button) shows here.
	Sky.changed = function()
		paint()
	end
	local player = Players.LocalPlayer
	for _, name in { "HudVariant", "HudLayout", Layouts.ATTRIBUTE } do
		player:GetAttributeChangedSignal(name):Connect(paint)
	end
	return page
end

return Settings
