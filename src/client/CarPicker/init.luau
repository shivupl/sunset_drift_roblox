--!strict
-- The car picker: the CARS menu's car list, in the garage style the owner
-- picked from the mockups on 2026-10-11 ("implement all 3 of these in the
-- game itself and let me try between them"): COMPACT (a panel down the
-- left), SHOWROOM (the picked car on a stage beside the grid), STRIP (a
-- car-select band along the bottom). The LAYOUT button in the picker's
-- header cycles them; the choice is the LocalPlayer attribute
-- CarMenuLayout and lasts the session.
--
-- Each car's box shows only its photo, its name, a favourite star and its
-- drive type. Tapping a box picks it; SPAWN (RESPAWN for the car you are
-- in) asks for it. The tabs filter by drive (ALL, RWD, FWD, AWD) or show
-- the starred cars. Favourites last the session (saving them is a server
-- change for later).
--
-- SpawnMenu owns the rest: M and the CARS button open this; spawning, the
-- cooldown and the car you are in are its; PLATES and SETTINGS (the
-- header's plate and gear) open its panel on those tabs.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleRig = require(Shared:WaitForChild("VehicleRig"))
local DriftStyles = require(Shared:WaitForChild("DriftStyles"))

local Kit = require(script:WaitForChild("Kit"))
local Types = require(script:WaitForChild("Types"))
local Art = require(script:WaitForChild("Art"))

local LAYOUTS: { Types.Layout } = {
	{ id = "compact", name = "COMPACT", build = require(script:WaitForChild("Compact")).build },
	{ id = "showroom", name = "SHOWROOM", build = require(script:WaitForChild("Showroom")).build },
	{ id = "strip", name = "STRIP", build = require(script:WaitForChild("Strip")).build },
}
local ATTRIBUTE = "CarMenuLayout"

export type Hooks = {
	cars: () -> { { id: string, entry: VehicleRig.CarEntry } },
	spawn: (id: string) -> boolean, -- false while a spawn cools down
	current: () -> string?,
	busy: () -> boolean,
	openTab: (tab: string) -> (),
	closed: () -> (),
}

local CarPicker = {}

local player = Players.LocalPlayer
local hooks: Hooks? = nil
local gui: ScreenGui? = nil
local view: Types.View? = nil
local taps: Kit.Taps? = nil
local toast: TextLabel? = nil
local state: Types.State = {
	layout = LAYOUTS[1].id,
	filter = "all",
	selected = "",
	favs = {},
	query = "",
	current = nil,
	busy = false,
}

local function layout(): Types.Layout
	local id = player:GetAttribute(ATTRIBUTE)
	for _, l in LAYOUTS do
		if l.id == id then
			return l
		end
	end
	return LAYOUTS[1]
end

local function carList(): { Kit.Car }
	local h = hooks :: Hooks
	local out: { Kit.Car } = {}
	for _, c in h.cars() do
		local e = c.entry
		local tuning = e.tuning
		table.insert(out, {
			id = c.id,
			name = e.displayName,
			drive = DriftStyles.layoutOf({ drivetrain = (tuning and tuning.drivetrain) or {} }),
			blurb = e.blurb or "",
			kg = e.rig.massKg,
			lengthM = e.rig.collisionSizeM[3] * VehicleRig.scaleOf(e),
			image = Art.cars[c.id],
		})
	end
	return out
end

local function refresh()
	local h = hooks
	if h then
		state.current = h.current()
		state.busy = h.busy()
	end
	local v = view
	if v then
		v.refresh()
	end
end

local function showToast(text: string)
	local t = toast
	if not t then
		return
	end
	t.Text = text
	t.TextTransparency = 0
	t.Visible = true
	TweenService:Create(t, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.9), { TextTransparency = 1 }):Play()
end

local rebuild: () -> ()

local actions: Types.Actions = {
	pick = function(id: string)
		state.selected = id
		refresh()
	end,
	fav = function(id: string)
		if state.favs[id] then
			state.favs[id] = nil
		else
			state.favs[id] = true
		end
		refresh()
	end,
	filter = function(id: string)
		state.filter = id
		refresh()
	end,
	query = function(text: string)
		state.query = text
		refresh()
	end,
	spawn = function()
		local h = hooks
		if h and state.selected ~= "" then
			h.spawn(state.selected)
			refresh()
		end
	end,
	close = function()
		local h = hooks
		if h then
			h.closed() -- SpawnMenu.close: it closes this and hands back the modal
		else
			CarPicker.close()
		end
	end,
	plates = function()
		local h = hooks
		if h then
			h.openTab("plates")
		end
	end,
	settings = function()
		local h = hooks
		if h then
			h.openTab("settings")
		end
	end,
	nextLayout = function()
		local cur = layout()
		local i = table.find(LAYOUTS, cur) or 0
		local nxt = LAYOUTS[i % #LAYOUTS + 1]
		player:SetAttribute(ATTRIBUTE, nxt.id)
		rebuild()
		showToast("LAYOUT: " .. nxt.name)
	end,
}

rebuild = function()
	local g = gui
	if not g or not g.Enabled then
		return
	end
	local old = view
	view = nil
	if old then
		old.destroy()
	end
	local t = taps
	if t then
		t.destroy()
	end
	local newTaps = Kit.taps(function()
		return CarPicker.isOpen()
	end)
	taps = newTaps
	local l = layout()
	state.layout = l.id
	local ctx: Types.Ctx = {
		touch = Kit.isTouch(),
		screen = g.AbsoluteSize,
		cars = carList(),
		state = state,
		act = actions,
		taps = newTaps,
	}
	view = l.build(g, ctx)
	refresh()
end

function CarPicker.isOpen(): boolean
	return gui ~= nil and (gui :: ScreenGui).Enabled
end

function CarPicker.open()
	local g = gui
	if not g then
		return
	end
	local h = hooks :: Hooks
	-- Open on the car you are in; the search starts empty.
	local current = h.current()
	if current then
		state.selected = current
	elseif state.selected == "" then
		local first = h.cars()[1]
		state.selected = if first then first.id else ""
	end
	state.query = ""
	g.Enabled = true
	rebuild()
end

function CarPicker.close()
	local g = gui
	if g then
		g.Enabled = false
	end
	local v = view
	view = nil
	if v then
		v.destroy()
	end
	local t = taps
	taps = nil
	if t then
		t.destroy()
	end
end

-- The car you are in changed, or a spawn's cooldown ended.
function CarPicker.refresh()
	if CarPicker.isOpen() then
		refresh()
	end
end

function CarPicker.start(h: Hooks)
	hooks = h
	local g = Instance.new("ScreenGui")
	g.Name = "HajwalaCarPicker"
	g.ResetOnSpawn = false
	-- Under Roblox's top bar, like the spawn menu: the hit test the taps use
	-- matches input positions there (SpawnMenu, hits()).
	g.IgnoreGuiInset = false
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = 20
	g.Enabled = false
	local t = Kit.text(g, "Toast", "", 16, Enum.FontWeight.Heavy, true)
	t.AnchorPoint = Vector2.new(0.5, 0)
	t.Position = UDim2.new(0.5, 0, 0, 4)
	t.Size = UDim2.fromOffset(400, 24)
	t.TextXAlignment = Enum.TextXAlignment.Center
	t.TextStrokeTransparency = 0.5
	t.ZIndex = 10
	t.Visible = false
	toast = t
	g.Parent = player:WaitForChild("PlayerGui")
	gui = g
	g:GetPropertyChangedSignal("AbsoluteSize"):Connect(rebuild)
	player:GetAttributeChangedSignal("ForceTouch"):Connect(rebuild)
end

return CarPicker
