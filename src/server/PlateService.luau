--!strict
-- Number plates for players (docs/superpowers/specs/2026-09-26-number-plates-design.md §4, §5).
--
-- Remotes: PlateQuery (is this plate valid, what does it cost, is it free)
-- and PlateAction (buy, equip, unequip). Both are rate-limited and always
-- normalise the player's text again (PlateText); nothing the client says
-- about a plate is trusted.
--
-- Each car carries the plate to draw as the Model attribute "Plate"
-- (CarPlates draws it on every client): its owner's equipped plate, or a
-- random default plate for the session. Player attributes: Plates and
-- PlateEquipped (Economy), PlateDefault (here).
--
-- One plate transaction per player at a time. Any left unfinished (the
-- store was down) is retried every retrySeconds and at the next join.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlateText = require(Shared:WaitForChild("PlateText"))
local PlateConfig = require(Shared:WaitForChild("PlateConfig"))
local Economy = require(script.Parent.Economy)
local PlateRegistry = require(script.Parent.PlateRegistry)
local Stores = require(script.Parent.Stores)
local Remotes = require(script.Parent.Remotes)

local STORE_NAME = "HajwalaPlates_v1"

type Reply = { status: string, key: string?, price: number?, available: boolean?, reason: string? }

local PlateService = {}

local registry: PlateRegistry.Registry? = nil
local busy: { [Player]: boolean } = {}
local budgets: { [string]: { [Player]: { at: number, n: number } } } = { query = {}, action = {} }

local function allowed(kind: string, player: Player, perSecond: number): boolean
	local b = budgets[kind]
	local now = os.clock()
	local cur = b[player]
	if not cur or now - cur.at >= 1 then
		b[player] = { at = now, n = 1 }
		return true
	end
	cur.n += 1
	return cur.n <= perSecond
end

local function plateFor(player: Player): string?
	local equipped = player:GetAttribute("PlateEquipped")
	if type(equipped) == "string" then
		return equipped
	end
	local default = player:GetAttribute("PlateDefault")
	return if type(default) == "string" then default else nil
end

local function carOf(player: Player): Model?
	local cars = Workspace:FindFirstChild("Cars")
	if not cars then
		return nil
	end
	for _, m in cars:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("OwnerUserId") == player.UserId then
			return m
		end
	end
	return nil
end

local function refreshCar(player: Player)
	local car = carOf(player)
	if car then
		car:SetAttribute("Plate", plateFor(player))
	end
end

-- Runs fn as this player's only plate transaction. False if one is running.
local function exclusive(player: Player, fn: () -> ()): boolean
	if busy[player] then
		return false
	end
	busy[player] = true
	-- Wrapped rather than passed directly: pcall of a bare `() -> ()` value
	-- infers exactly one return (ok), so `local ok, err = pcall(fn)` fails to
	-- typecheck; a fresh closure lets it infer the usual (ok, err) pair.
	local ok, err = pcall(function()
		fn()
	end)
	busy[player] = nil
	if not ok then
		warn(`[Plates] {player.Name}: {tostring(err)}`)
	end
	return true
end

-- A default plate nobody owns (spec §5). Never registered.
local function pickDefault(): string
	local rng = Random.new()
	local key = PlateText.random(rng)
	local reg = registry
	if not reg then
		return key
	end
	for _ = 1, PlateConfig.defaultPicks do
		if reg.available(key) ~= false then
			return key
		end
		key = PlateText.random(rng)
	end
	return key
end

local function query(player: Player, input: any): Reply
	if not allowed("query", player, PlateConfig.queriesPerSecond) then
		return { status = "busy" }
	end
	if type(input) ~= "string" then
		return { status = "invalid", reason = "Type a plate" }
	end
	local key, reason = PlateText.normalise("SA", input)
	if not key then
		return { status = "invalid", reason = reason }
	end
	local price = PlateText.price(key)
	local reg = registry
	local free = if reg then reg.available(key) else nil
	if free == nil then
		return { status = "unavailable", key = key, price = price }
	end
	return { status = "ok", key = key, price = price, available = free }
end

local function action(player: Player, what: any, input: any): Reply
	if not allowed("action", player, PlateConfig.actionsPerSecond) then
		return { status = "busy" }
	end
	if what == "unequip" then
		Economy.setEquipped(player, nil)
		return { status = "done" }
	end
	if what ~= "buy" and what ~= "equip" then
		return { status = "invalid", reason = "Unknown action" }
	end
	if type(input) ~= "string" then
		return { status = "invalid", reason = "Type a plate" }
	end
	local key, reason = PlateText.normalise("SA", input)
	if not key then
		return { status = "invalid", reason = reason }
	end
	local reg = registry
	if not reg then
		return { status = "unavailable" }
	end
	local reply: Reply = { status = "busy" }
	exclusive(player, function()
		local wallet = Economy.wallet(player)
		if what == "equip" then
			if not Economy.setEquipped(player, key) then
				reply = { status = "notowned", key = key }
				return
			end
			reg.checkEquipped(wallet, player.UserId)
			local kept = player:GetAttribute("PlateEquipped") == key
			reply = { status = if kept then "done" else "taken", key = key }
		else
			local price = PlateText.price(key) :: number
			reply = { status = reg.buy(wallet, player.UserId, key, price), key = key, price = price }
		end
	end)
	return reply
end

local function onLoaded(player: Player, canSave: boolean)
	player:SetAttribute("PlateDefault", pickDefault())
	refreshCar(player)
	local reg = registry
	if reg and canSave then
		exclusive(player, function()
			local wallet = Economy.wallet(player)
			reg.recover(wallet, player.UserId)
			reg.checkEquipped(wallet, player.UserId)
		end)
	end
end

function PlateService.start(remotes: Remotes.RemoteTable)
	local store = Stores.open(STORE_NAME)
	if store then
		registry = PlateRegistry.new(store, { clock = os.time })
	end
	-- Set before Economy starts, so no profile load is missed.
	Economy.onLoaded = onLoaded

	remotes.PlateQuery.OnServerInvoke = function(player: Player, input: any): any
		local ok, reply = pcall(query, player, input)
		return if ok then reply else { status = "unavailable" }
	end
	remotes.PlateAction.OnServerInvoke = function(player: Player, what: any, input: any): any
		local ok, reply = pcall(action, player, what, input)
		return if ok then reply else { status = "unavailable" }
	end

	local function watch(player: Player)
		player:GetAttributeChangedSignal("PlateEquipped"):Connect(function()
			refreshCar(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		budgets.query[player] = nil
		budgets.action[player] = nil
	end)

	-- A new car takes its owner's plate (CarSpawner sets OwnerUserId before
	-- parenting it).
	task.spawn(function()
		local cars = Workspace:WaitForChild("Cars", math.huge)
		cars.ChildAdded:Connect(function(child)
			local uid = child:GetAttribute("OwnerUserId")
			local owner = if type(uid) == "number" then Players:GetPlayerByUserId(uid) else nil
			if owner and child:IsA("Model") then
				child:SetAttribute("Plate", plateFor(owner))
			end
		end)
	end)

	-- Unfinished transactions, retried.
	task.spawn(function()
		while true do
			task.wait(PlateConfig.retrySeconds)
			local reg = registry
			if not reg then
				continue
			end
			for _, player in Players:GetPlayers() do
				local p = Economy.profile(player)
				if p and #p.pendingTxns > 0 then
					task.spawn(exclusive, player, function()
						reg.recover(Economy.wallet(player), player.UserId)
					end)
				end
			end
		end
	end)
end

return PlateService
