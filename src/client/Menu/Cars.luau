--!strict
-- The menu's CARS: the car picker's SHOWROOM (the owner's favourite of its
-- three layouts) in the frame every screen shares. The picked car stands in
-- the middle on a soft light with its weight and length under it, level
-- with the bottom row; its name, drive and favourite star are the subject over it; the
-- column under the coins holds the drive filters (ALL, RWD, FWD, AWD, the
-- starred ones) and every car as a square block; SPAWN THIS CAR (RESPAWN
-- for the one you are in) is the action. Favourites last the session.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleRig = require(Shared:WaitForChild("VehicleRig"))
local DriftStyles = require(Shared:WaitForChild("DriftStyles"))

local Client = script.Parent.Parent
local Kit = require(Client:WaitForChild("CarPicker"):WaitForChild("Kit"))
local Art = require(Client:WaitForChild("CarPicker"):WaitForChild("Art"))
local Looks = Client:WaitForChild("Garage"):WaitForChild("Looks")
local Types = require(Looks:WaitForChild("Types"))
local Parts = require(Looks:WaitForChild("Parts"))
local Page = require(script.Parent:WaitForChild("Page"))

local Cars = {}

type Car = {
	id: string,
	name: string,
	drive: string,
	blurb: string,
	kg: number,
	lengthM: number,
	photo: string?,
	paint: Color3,
}

local FILTERS: { Types.ViewDef } = {
	{ id = "all", label = "ALL" },
	{ id = "rwd", label = "RWD" },
	{ id = "fwd", label = "FWD" },
	{ id = "awd", label = "AWD" },
	{ id = "fav", label = "", star = true },
}

-- The bars' ends: the lightest and heaviest, shortest and longest cars the
-- game has (the picker's stats).
local KG_FROM, KG_SPAN = 1000, 1400
local M_FROM, M_SPAN = 4.5, 2

function Cars.new(shell: Page.Shell): Page.Page
	local filter = "all"
	local query = ""
	local selected = ""
	local favs: { [string]: boolean } = {}

	local function list(): { Car }
		local out: { Car } = {}
		for _, c in shell.hooks.cars() do
			local e = c.entry
			local tuning = e.tuning
			table.insert(out, {
				id = c.id,
				name = e.displayName,
				drive = DriftStyles.layoutOf({ drivetrain = (tuning and tuning.drivetrain) or {} }),
				blurb = e.blurb or "",
				kg = e.rig.massKg,
				lengthM = e.rig.collisionSizeM[3] * VehicleRig.scaleOf(e),
				photo = Art.cars[c.id],
				paint = e.body.paint,
			})
		end
		return out
	end

	local function find(id: string): Car?
		local all = list()
		for _, c in all do
			if c.id == id then
				return c
			end
		end
		return all[1]
	end

	local function visible(c: Car): boolean
		if query ~= "" and not string.find(string.lower(c.name), string.lower(query), 1, true) then
			return false
		end
		if filter == "fav" then
			return favs[c.id] == true
		end
		return filter == "all" or string.lower(c.drive) == filter
	end

	local function toggleFav(id: string)
		if id == "" then
			return
		end
		if favs[id] then
			favs[id] = nil
		else
			favs[id] = true
		end
		if filter == "fav" then
			shell.fill()
		end
		shell.refresh()
	end

	local function picked(): Car?
		return find(selected)
	end

	local function drawPhoto(tile: Frame, c: Car)
		local photo = c.photo
		if photo then
			-- The picker's photo on its dark stage.
			tile.BackgroundColor3 = Kit.C.tileTop
			local img = Kit.image(tile, "Photo", photo)
			img.ScaleType = Enum.ScaleType.Fit
			img.Size = UDim2.fromScale(1, 1)
		else
			tile.BackgroundColor3 = c.paint
		end
	end

	local page: Page.Page
	page = {
		tab = { id = "cars", label = "CARS", arabic = "سيارات", icon = Parts.ICON.cars },
		blur = 16,
		dim = 0.5,
		views = function()
			return FILTERS
		end,
		view = function()
			return filter
		end,
		setView = function(id: string)
			if id ~= filter then
				filter = id
				shell.fill()
				shell.refresh()
			end
		end,
		note = function()
			if filter == "fav" and next(favs) == nil then
				return "Star a car to keep it here."
			end
			if query ~= "" and #page.entries() == 0 then
				return "No car matches that."
			end
			return nil
		end,
		entries = function()
			local out: { Types.Entry } = {}
			for _, c in list() do
				if visible(c) then
					table.insert(out, {
						key = c.id,
						slot = nil,
						name = c.name,
						price = 0,
						rare = false,
						shape = "car",
						fades = false,
						draw = function(tile: Frame)
							drawPhoto(tile, c)
						end,
						image = c.photo,
						chip = c.drive,
					})
				end
			end
			return out
		end,
		stateOf = function(e: Types.Entry): Types.EntryState
			local inUse = e.key == shell.hooks.current()
			local c = find(e.key)
			return {
				chosen = e.key == selected,
				disabled = false,
				word = if inUse then "✓ IN USE" else (if c then c.drive else ""),
				kind = if inUse then "owned" else "note",
				starred = favs[e.key] == true,
			}
		end,
		tap = function(e: Types.Entry)
			if e.key ~= selected then
				selected = e.key
				shell.refresh()
			end
		end,
		foot = function(): Types.Foot
			local c = picked()
			local busy = shell.hooks.busy()
			local now = c ~= nil and c.id == shell.hooks.current()
			return {
				name = if c then c.name else "",
				rare = false,
				note = "",
				action = if c == nil then "none" elseif busy then "wait" else "drive",
				price = 0,
				label = if busy then "…" elseif now then "RESPAWN" else "SPAWN THIS CAR",
			}
		end,
		action = function()
			local c = picked()
			if c and not shell.hooks.busy() then
				shell.hooks.spawn(c.id)
			end
		end,
		subject = function()
			local c = picked()
			if c then
				return c.name, c.drive
			end
			return "", ""
		end,
		starred = function()
			return favs[selected] == true
		end,
		star = function()
			toggleFav(selected)
		end,
		starEntry = toggleFav,
		search = {
			get = function()
				return query
			end,
			set = function(q: string)
				if q ~= query then
					query = q
					shell.fill()
					shell.refresh()
				end
			end,
		},
		form = function()
			return nil
		end,
		stage = function(frame: Frame, touch: boolean): Page.Stage
			-- The car on a soft light, the drive huge and faint behind it,
			-- its weight and length in a row level with the bottom buttons.
			local rowH = if touch then 52 else 60
			local holder = Kit.frame(frame, "Car")
			holder.Size = UDim2.fromScale(1, 1)
			local art = Kit.frame(holder, "Art")
			art.Size = UDim2.new(1, 0, 1, -(rowH + 6))
			local spot = Kit.image(art, "Spot", Art.spot, Kit.C.spot, 0.2)
			spot.AnchorPoint = Vector2.new(0.5, 0.5)
			spot.Position = UDim2.fromScale(0.5, 0.48)
			spot.Size = UDim2.fromScale(1.05, 1.25)
			local mark = Kit.text(art, "Watermark", "", if touch then 120 else 180, Enum.FontWeight.Heavy, true)
			mark.TextTransparency = 0.93
			mark.AnchorPoint = Vector2.new(0.5, 0.5)
			mark.Position = UDim2.fromScale(0.5, 0.46)
			mark.Size = UDim2.fromScale(1, 0.7)
			mark.TextXAlignment = Enum.TextXAlignment.Center
			mark.TextTruncate = Enum.TextTruncate.None
			local floor = Kit.image(art, "Floor", Art.spot, Color3.new(0, 0, 0), 0.35)
			floor.AnchorPoint = Vector2.new(0.5, 1)
			floor.Position = UDim2.fromScale(0.5, 0.97)
			floor.Size = UDim2.fromScale(0.78, 0.16)
			local photo = Kit.image(art, "Photo", "")
			photo.ScaleType = Enum.ScaleType.Fit
			photo.AnchorPoint = Vector2.new(0.5, 0.5)
			photo.Position = UDim2.fromScale(0.5, 0.5)
			photo.Size = UDim2.fromScale(0.94, 0.96)
			local blurb = Kit.text(art, "Blurb", "", if touch then 11 else 13, Enum.FontWeight.SemiBold, false, Kit.C.sub)
			blurb.AnchorPoint = Vector2.new(0.5, 1)
			blurb.Position = UDim2.fromScale(0.5, 1)
			blurb.Size = UDim2.new(1, 0, 0, if touch then 14 else 17)
			blurb.TextXAlignment = Enum.TextXAlignment.Center
			blurb.Visible = not touch -- a phone has the room for the car only

			-- Weight and length, side by side: the word, the value, a bar.
			local stats = Kit.frame(holder, "Stats")
			stats.AnchorPoint = Vector2.new(0, 1)
			stats.Position = UDim2.fromScale(0, 1)
			stats.Size = UDim2.new(1, 0, 0, rowH)
			local sl = Kit.list(stats, false, if touch then 14 else 20, Enum.VerticalAlignment.Center)
			sl.HorizontalAlignment = Enum.HorizontalAlignment.Center
			local function stat(order: number, label: string): (TextLabel, ImageLabel)
				local cell = Kit.frame(stats, label)
				cell.LayoutOrder = order
				cell.Size = UDim2.new(0.5, -(if touch then 7 else 10), 1, 0)
				local l = Kit.text(cell, "Label", label, if touch then 10 else 12, Enum.FontWeight.Bold, false, Kit.C.sub)
				l.Position = UDim2.fromOffset(0, if touch then 6 else 8)
				l.Size = UDim2.new(0.38, 0, 0, if touch then 14 else 16)
				local v = Kit.text(cell, "Value", "", if touch then 15 else 18, Enum.FontWeight.ExtraBold, true)
				v.AnchorPoint = Vector2.new(1, 0)
				v.Position = UDim2.new(1, 0, 0, if touch then 3 else 5)
				v.Size = UDim2.new(0.62, 0, 0, if touch then 19 else 23)
				v.TextXAlignment = Enum.TextXAlignment.Right
				local barH = if touch then 8 else 10
				local track = Kit.frame(cell, "Track", Color3.new(0, 0, 0), 0.45)
				track.AnchorPoint = Vector2.new(0, 1)
				track.Position = UDim2.new(0, 0, 1, -(if touch then 8 else 10))
				track.Size = UDim2.new(1, 0, 0, barH)
				track.ClipsDescendants = true
				Kit.corner(track, math.floor(barH / 2))
				Kit.stroke(track, Color3.new(1, 1, 1), 1, 0.8)
				local bar = Kit.image(track, "Bar", Art.stripes)
				bar.ScaleType = Enum.ScaleType.Tile
				bar.TileSize = UDim2.fromOffset(8, 8)
				bar.Size = UDim2.fromScale(0.5, 1)
				Kit.corner(bar, math.floor(barH / 2))
				return v, bar
			end
			local kgV, kgBar = stat(1, "Weight")
			local mV, mBar = stat(2, "Length")

			local shownId: string? = nil
			return {
				refresh = function()
					local c = picked()
					if not c then
						holder.Visible = false
						return
					end
					holder.Visible = true
					photo.Image = c.photo or ""
					mark.Text = c.drive
					blurb.Text = c.blurb
					kgV.Text = Parts.money(c.kg) .. " kg"
					mV.Text = string.format("%.1f m", c.lengthM)
					local kgTo = UDim2.fromScale(math.clamp((c.kg - KG_FROM) / KG_SPAN, 0.06, 1), 1)
					local mTo = UDim2.fromScale(math.clamp((c.lengthM - M_FROM) / M_SPAN, 0.06, 1), 1)
					if shownId == nil then
						kgBar.Size, mBar.Size = kgTo, mTo
					elseif shownId ~= c.id then
						-- A new car drives onto the stage; its bars run to
						-- its numbers.
						Parts.slideIn(photo, if touch then 36 else 54, 0)
						game:GetService("TweenService"):Create(kgBar, Parts.SETTLE, { Size = kgTo }):Play()
						game:GetService("TweenService"):Create(mBar, Parts.SETTLE, { Size = mTo }):Play()
					end
					shownId = c.id
				end,
				destroy = function()
					holder:Destroy()
				end,
			}
		end,
		paint = function() end,
		shown = function()
			-- On the car you are in; else the one picked last; else the first.
			local cur = shell.hooks.current()
			if cur then
				selected = cur
			elseif selected == "" then
				local first = list()[1]
				selected = if first then first.id else ""
			end
		end,
	}
	return page
end

return Cars
