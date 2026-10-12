--!strict
-- The menu's PLATES (docs/superpowers/specs/2026-09-26-number-plates-design.md
-- §5), in the frame every screen shares (ui-flow, 2026-10-12; it was the
-- old spawn menu's panel on the UITheme tokens, and the owner: "tapping
-- plates/settings jumps to the old menu whose style is different").
--   * The sub-tabs pick the plate style being searched: KSA, DUBAI, ABU
--     DHABI, KUWAIT.
--   * The search box: letters and digits in either script. PlateText
--     answers at once; the server (PlateQuery) is asked for the price and
--     whether the plate is free once typing pauses. The plate typed (or the
--     style's sample) is the subject, big in the middle, in the rear plate
--     format of the car you are in.
--   * Under it your plates as blocks: the one on your car edged green with
--     ON CAR; tap another to fit it.
--   * BUY with the price opens the confirm sheet; only its BUY charges
--     (UI_SYSTEM.md: nothing is ever charged from a single tap).
-- What you own comes from Player attributes the server sets (Plates,
-- PlateEquipped, PlateDefault); nothing here is trusted by the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlateText = require(Shared:WaitForChild("PlateText"))
local PlateStyles = require(Shared:WaitForChild("PlateStyles"))
local CarPlateMounts = require(Shared:WaitForChild("CarPlateMounts"))

local Client = script.Parent.Parent
local Kit = require(Client:WaitForChild("CarPicker"):WaitForChild("Kit"))
local Art = require(Client:WaitForChild("CarPicker"):WaitForChild("Art"))
local Looks = Client:WaitForChild("Garage"):WaitForChild("Looks")
local Types = require(Looks:WaitForChild("Types"))
local Parts = require(Looks:WaitForChild("Parts"))
local Page = require(script.Parent:WaitForChild("Page"))

local Plates = {}

-- Seconds typing must pause before the server is asked.
local QUERY_DELAY = 0.35

local MESSAGES: { [string]: string } = {
	done = "Done",
	taken = "Someone else owns this plate",
	cash = "Not enough cash. Nothing was charged",
	unavailable = "The plate shop is unavailable right now. Nothing was charged",
	pending = "Your purchase is finishing. It will show in a moment",
	owned = "You already own this plate",
	notowned = "You don't own this plate",
	busy = "One moment, then try again",
}

-- What each style's search box expects, as a hint, and the plate shown
-- until a valid one is typed, so picking a style shows its design at once
-- (owner, 2026-09-27).
local HINTS: { [string]: { placeholder: string, empty: string, sample: string } } = {
	SA = { placeholder = "ABJ 7   ·   حبأ ٧", empty = "3 letters and a number, Arabic or English", sample = "SA:ABJ-1234" },
	DU = { placeholder = "A 12345", empty = "A code (A to Z, AA to EE) and up to 5 digits", sample = "DU:A-12345" },
	AD = { placeholder = "20 10234", empty = "A code (1, 4 to 22, 50), a space, up to 5 digits", sample = "AD:20-10234" },
	KW = { placeholder = "10 23456", empty = "A code (1 to 89), a space, up to 5 digits", sample = "KW:10-23456" },
}

type Status = "hint" | "checking" | "free" | "taken" | "owned" | "error"

function Plates.new(shell: Page.Shell, remotes: Folder): Page.Page
	local player = Players.LocalPlayer
	local queryRemote = remotes:WaitForChild("PlateQuery") :: RemoteFunction
	local actionRemote = remotes:WaitForChild("PlateAction") :: RemoteFunction
	local style = "SA"
	local query = ""
	local asked = 0
	-- The plate typed, once it is one: its key, price and whether the
	-- server said it is free.
	local typed: { key: string?, price: number?, free: boolean } = { key = nil, price = nil, free = false }
	local status: Status = "hint"
	local message = HINTS[style].empty
	local statusLabel: TextLabel? = nil

	local function money(n: number): string
		return Parts.money(n)
	end

	-- A plate as a player reads it, with its country: "KSA ABJ 7".
	local function shown(key: string): string
		local t = PlateText.typed(key)
		if not t then
			return key
		end
		local code = PlateText.styleOf(key)
		for _, st in PlateText.STYLES do
			if st.code == code then
				return `{st.name} {t}`
			end
		end
		return t
	end

	local function styleName(code: string?): string
		for _, st in PlateText.STYLES do
			if st.code == code then
				return st.name
			end
		end
		return ""
	end

	local function format(): PlateStyles.Format
		local id = shell.hooks.current()
		local mounts = if id then CarPlateMounts.cars[id] else nil
		local rear = if mounts then mounts.rear else nil
		return if rear then rear.format else "short"
	end

	local function ownedKeys(): { string }
		local raw = player:GetAttribute("Plates")
		local out: { string } = {}
		if type(raw) == "string" then
			for k in string.gmatch(raw, "[^,]+") do
				table.insert(out, k)
			end
		end
		return out
	end

	local function owns(key: string): boolean
		return table.find(ownedKeys(), key) ~= nil
	end

	local function equipped(): string?
		local e = player:GetAttribute("PlateEquipped")
		return if type(e) == "string" and e ~= "" then e else nil
	end

	local function default(): string?
		local d = player:GetAttribute("PlateDefault")
		return if type(d) == "string" then d else nil
	end

	-- The key on the car now: the one fitted, or the session's default.
	local function onCar(): string?
		return equipped() or default()
	end

	local function paintStatus()
		local l = statusLabel
		if not l then
			return
		end
		l.Text = message
		l.TextColor3 = if status == "free"
			then Parts.C.sodium
			elseif status == "taken" or status == "error" then Parts.C.beacon
			elseif status == "owned" then Kit.C.green
			else Kit.C.sub
	end

	local function setStatus(s: Status, text: string)
		status, message = s, text
		paintStatus()
		shell.refresh()
	end

	local function act(what: string, key: string): string
		-- The server normalises what it is sent as typed text, and a key
		-- ("SA:ABJ-7") is not typed text, so send the plate as a player
		-- would type it, with its style.
		local t = if key == "" then "" else (PlateText.typed(key) or "")
		local keyStyle = if key == "" then nil else PlateText.styleOf(key)
		local ok, reply = pcall(function()
			return actionRemote:InvokeServer(what, t, keyStyle)
		end)
		return if ok and type(reply) == "table" then (reply.status or "unavailable") else "unavailable"
	end

	local function search()
		asked += 1
		local mine = asked
		typed = { key = nil, price = nil, free = false }
		if query == "" then
			setStatus("hint", HINTS[style].empty)
			return
		end
		local searching = style
		local key, reason = PlateText.normalise(searching, query)
		if not key then
			setStatus("error", reason or "Not a plate")
			return
		end
		if owns(key) then
			typed = { key = key, price = nil, free = false }
			setStatus("owned", "✓ Yours already")
			return
		end
		local price = PlateText.price(key) :: number
		typed = { key = key, price = price, free = false }
		setStatus("checking", `{money(price)} · checking…`)
		task.delay(QUERY_DELAY, function()
			if mine ~= asked then
				return
			end
			local text = query
			local ok, reply = pcall(function()
				return queryRemote:InvokeServer(text, searching)
			end)
			if mine ~= asked then
				return
			end
			if not ok or type(reply) ~= "table" then
				setStatus("error", MESSAGES.unavailable)
			elseif reply.status == "ok" then
				typed = { key = reply.key, price = reply.price, free = reply.available == true }
				if typed.free then
					setStatus("free", `{money(reply.price)} · free to buy`)
				else
					setStatus("taken", MESSAGES.taken)
				end
			elseif reply.status == "invalid" then
				setStatus("error", reply.reason or "Not a plate")
			else
				setStatus("error", MESSAGES[reply.status] or MESSAGES.unavailable)
			end
		end)
	end

	-- What the middle shows: the plate typed; else the one on your car,
	-- if it is of the style picked; else the style's sample, so picking a
	-- style shows its design at once.
	local function subjectKey(): string
		local key = typed.key
		if key then
			return key
		end
		local mine = onCar()
		if mine and PlateText.styleOf(mine) == style then
			return mine
		end
		return HINTS[style].sample
	end

	local function plateEntry(key: string, name: string): Types.Entry
		return {
			key = key,
			slot = "plate",
			name = name,
			price = 0,
			rare = false,
			shape = "wide",
			fades = false,
			draw = function(tile: Frame)
				-- The plate art is the swatch, edges and all.
				tile.BackgroundTransparency = 1
				local edge = tile:FindFirstChildOfClass("UIStroke")
				if edge then
					edge:Destroy()
				end
				PlateStyles.draw(tile, if key == "" then default() else key, format())
			end,
		}
	end

	local page: Page.Page
	page = {
		tab = { id = "plates", label = "PLATES", arabic = "لوحات", icon = Parts.ICON.plates },
		blur = 16,
		dim = 0.5,
		views = function()
			local out: { Types.ViewDef } = {}
			for _, st in PlateText.STYLES do
				table.insert(out, { id = st.code, label = st.name })
			end
			return out
		end,
		view = function()
			return style
		end,
		setView = function(id: string)
			if id ~= style and HINTS[id] then
				style = id
				shell.fill()
				search()
			end
		end,
		note = function()
			return nil
		end,
		entries = function()
			local out: { Types.Entry } = {}
			if default() then
				table.insert(out, plateEntry("", "Default"))
			end
			for _, k in ownedKeys() do
				table.insert(out, plateEntry(k, shown(k)))
			end
			return out
		end,
		stateOf = function(e: Types.Entry): Types.EntryState
			local on = if e.key == "" then equipped() == nil else equipped() == e.key
			return {
				chosen = on,
				disabled = false,
				word = if on then "ON CAR" elseif e.key == "" then "THIS SESSION" else "✓ OWNED",
				kind = if on then "oncar" elseif e.key == "" then "note" else "owned",
			}
		end,
		tap = function(e: Types.Entry)
			local on = if e.key == "" then equipped() == nil else equipped() == e.key
			if on then
				return
			end
			task.spawn(function()
				local s = act(if e.key == "" then "unequip" else "equip", e.key)
				if s ~= "done" then
					shell.toast(MESSAGES[s] or MESSAGES.unavailable, "error")
				end
				shell.refresh()
			end)
		end,
		foot = function(): Types.Foot
			local key, price = typed.key, typed.price
			if key and price and typed.free and not owns(key) then
				return { name = shown(key), rare = false, note = "Yours alone", action = "buy", price = price }
			end
			local fitted = onCar()
			return {
				name = if fitted then shown(fitted) else "",
				rare = false,
				note = "On your car",
				action = "none",
				price = 0,
			}
		end,
		action = function()
			local key, price = typed.key, typed.price
			if not key or not price or not typed.free or owns(key) then
				return
			end
			shell.sheet({
				title = "BUY THIS PLATE",
				name = shown(key),
				rare = false,
				what = "Yours alone: nobody else can own it",
				price = price,
				entry = plateEntry(key, shown(key)),
			}, function()
				local s = act("buy", key)
				if s == "done" then
					typed.free = false
					shell.toast(`Bought {shown(key)}`, "done")
					-- A plate bought goes on the car you are in.
					act("equip", key)
					setStatus("owned", "✓ Yours already")
				else
					shell.toast(MESSAGES[s] or MESSAGES.unavailable, "error")
					if s == "taken" then
						typed.free = false
						setStatus("taken", MESSAGES.taken)
					end
				end
			end)
		end,
		subject = function()
			local key = subjectKey()
			return PlateText.typed(key) or key, styleName(PlateText.styleOf(key))
		end,
		starred = function()
			return nil
		end,
		star = function() end,
		form = function()
			return function(parent: Frame, width: number): Types.Form
				local touch = shell.touch()
				local boxH = if touch then 34 else 40
				local f = Kit.frame(parent, "Search")
				f.Size = UDim2.fromOffset(width, 0)
				f.AutomaticSize = Enum.AutomaticSize.Y
				Kit.list(f, true, 4)
				local field = Kit.frame(f, "Field", Color3.new(1, 1, 1), 0.93)
				field.Size = UDim2.new(1, 0, 0, boxH)
				Kit.corner(field, 9)
				Kit.stroke(field, Color3.new(1, 1, 1), 1, 0.86)
				local glass = Kit.image(field, "Icon", Art.search, Kit.C.green)
				glass.AnchorPoint = Vector2.new(0, 0.5)
				glass.Position = UDim2.new(0, 10, 0.5, 0)
				glass.Size = UDim2.fromOffset(if touch then 14 else 16, if touch then 14 else 16)
				local box = Instance.new("TextBox")
				box.Name = "Query"
				box.BackgroundTransparency = 1
				box.ClearTextOnFocus = false
				box.Text = query
				box.PlaceholderText = HINTS[style].placeholder
				box.PlaceholderColor3 = Kit.C.faint
				box.TextColor3 = Kit.C.text
				box.TextSize = if touch then 14 else 16
				box.FontFace = Kit.font(Enum.FontWeight.Bold)
				box.TextXAlignment = Enum.TextXAlignment.Left
				box.Position = UDim2.fromOffset(if touch then 31 else 35, 0)
				box.Size = UDim2.new(1, -(if touch then 38 else 44), 1, 0)
				box.Parent = field
				box:GetPropertyChangedSignal("Text"):Connect(function()
					if box.Text ~= query then
						query = box.Text
						search()
					end
				end)
				-- Under the confirm sheet the box gives its focus back, so the
				-- plate being bought cannot change under it.
				box.Focused:Connect(function()
					if shell.busy() then
						box:ReleaseFocus()
					end
				end)
				local line = Kit.text(f, "Status", "", if touch then 10 else 12, Enum.FontWeight.SemiBold, false, Kit.C.sub)
				line.LayoutOrder = 1
				line.Size = UDim2.new(1, 0, 0, if touch then 14 else 16)
				line.Position = UDim2.fromOffset(4, 0)
				statusLabel = line
				paintStatus()
				return { root = f, fills = false }
			end
		end,
		stage = function(frame: Frame, touch: boolean): Page.Stage
			-- The plate, big, on a soft light; level with the bottom row a
			-- line saying what owning one means.
			local rowH = if touch then 52 else 60
			local holder = Kit.frame(frame, "Plate")
			holder.Size = UDim2.fromScale(1, 1)
			local spot = Kit.image(holder, "Spot", Art.spot, Kit.C.spot, 0.25)
			spot.AnchorPoint = Vector2.new(0.5, 0.5)
			spot.Position = UDim2.new(0.5, 0, 0.5, -math.floor(rowH / 2))
			spot.Size = UDim2.fromScale(1, 1.1)
			local art = Kit.frame(holder, "Art")
			art.AnchorPoint = Vector2.new(0.5, 0.5)
			art.Position = UDim2.new(0.5, 0, 0.5, -math.floor(rowH / 2))
			art.Size = UDim2.new(0.74, 0, 1, -(rowH + 56))
			local line = Kit.text(holder, "Line", "Plates are yours alone: nobody else can own the same one", if touch then 11 else 13, Enum.FontWeight.SemiBold, false, Kit.C.sub)
			line.AnchorPoint = Vector2.new(0.5, 1)
			line.Position = UDim2.new(0.5, 0, 1, -math.floor((rowH - 14) / 2))
			line.Size = UDim2.new(1, 0, 0, if touch then 14 else 16)
			line.TextXAlignment = Enum.TextXAlignment.Center
			local drawn: string? = nil
			return {
				refresh = function()
					local key = subjectKey()
					local sig = key .. "|" .. format()
					if sig ~= drawn then
						local first = drawn == nil
						drawn = sig
						PlateStyles.draw(art, key, format())
						if not first then
							Parts.settle(art, Parts.LIFT)
						end
					end
				end,
				destroy = function()
					holder:Destroy()
				end,
			}
		end,
		paint = function() end,
		shown = function()
			search()
		end,
	}

	for _, name in { "Plates", "PlateEquipped", "PlateDefault" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			-- A plate bought or fitted elsewhere: the list.
			if shell.showing() ~= "plates" then
				return
			end
			if name == "Plates" then
				shell.fill()
			end
			shell.refresh()
		end)
	end
	return page
end

return Plates
