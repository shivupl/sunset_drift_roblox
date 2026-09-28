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
local DataStoreService = game:GetService("DataStoreService")
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
-- True once the registry was opened on a live DataStore (not Studio's fake,
-- not "none"): only then is there a real GetAsync budget to protect (fix 3).
local liveStore = false
local busy: { [Player]: boolean } = {}
-- True once a player's profile load has finished and it can be saved
-- (Economy.onLoaded's canSave). Buying or equipping before this, or after a
-- failed load, would write plate keys for a profile that is not being kept:
-- reserve/cancel would still touch the shared registry for a wallet nothing
-- here is really tracking, and the player would see a balance that is not
-- theirs to spend against.
local ready: { [Player]: boolean } = {}
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

-- Runs fn as this player's only plate transaction. First return is false if
-- one is already running (fn did not run at all, busy[player] untouched).
-- When it did run, the second return is false if fn raised (also logged
-- here), so a caller can tell "busy" apart from "ran but failed".
local function exclusive(player: Player, fn: () -> ()): (boolean, boolean)
	if busy[player] then
		return false, false
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
	return true, ok
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

-- Controller's ruling: a typing player can burst PlateQuery faster than the
-- availability cache alone protects the store, so also check the server's
-- actual GetAsync budget and back off before it runs out — keep the rest for
-- profile loads and plate settlement (buy/release/recover), which cannot
-- simply wait for a search box. Buy and equip reach the store the same way
-- (reserve/confirm/recover all read the key first), so they share this guard
-- rather than each carrying their own copy of it (fix 1, 2026-09-27 review).
local function readBudgetLow(): boolean
	if not liveStore then
		return false
	end
	local budget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetAsync)
	return budget < PlateConfig.minReadBudget
end

-- The plate style a remote call asked for: "SA" when none is given (the
-- first clients sent none), nil for anything unknown.
local function requestedStyle(style: any): string?
	if style == nil then
		return "SA"
	end
	return if PlateText.isStyle(style) then style else nil
end

local function query(player: Player, input: any, styleArg: any): Reply
	if not allowed("query", player, PlateConfig.queriesPerSecond) then
		return { status = "busy" }
	end
	if type(input) ~= "string" then
		return { status = "invalid", reason = "Type a plate" }
	end
	local style = requestedStyle(styleArg)
	if not style then
		return { status = "invalid", reason = "Unknown plate style" }
	end
	local key, reason = PlateText.normalise(style, input)
	if not key then
		return { status = "invalid", reason = reason }
	end
	local price = PlateText.price(key)
	local reg = registry
	if reg and readBudgetLow() then
		return { status = "busy" }
	end
	local free = if reg then reg.available(key) else nil
	if free == nil then
		return { status = "unavailable", key = key, price = price }
	end
	return { status = "ok", key = key, price = price, available = free }
end

local function action(player: Player, what: any, input: any, styleArg: any): Reply
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
	-- No profile to charge or fit a plate on yet, or its load failed
	-- (nothing here will be saved this session): query and unequip still
	-- work, but buying or equipping would touch the shared registry for a
	-- wallet that is not really being kept.
	if not ready[player] then
		return { status = "unavailable" }
	end
	if type(input) ~= "string" then
		return { status = "invalid", reason = "Type a plate" }
	end
	local style = requestedStyle(styleArg)
	if not style then
		return { status = "invalid", reason = "Unknown plate style" }
	end
	local key, reason = PlateText.normalise(style, input)
	if not key then
		return { status = "invalid", reason = reason }
	end
	local reg = registry
	if not reg then
		return { status = "unavailable" }
	end
	if readBudgetLow() then
		return { status = "busy" }
	end
	local reply: Reply = { status = "busy" }
	local ran, ok = exclusive(player, function()
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
	if ran and not ok then
		-- fn threw partway through: reply must not be left at the "busy"
		-- default, which would misreport a genuinely running transaction.
		reply = { status = "unavailable" }
	end
	return reply
end

local function onLoaded(player: Player, canSave: boolean)
	-- ready is set only once join recovery has run (fix 3, 2026-09-27
	-- review): pickDefault (a GetAsync per try) and the recover/checkEquipped
	-- pair below all yield, so setting it up front let an early buy or equip
	-- slip in and take `exclusive` while this join check was still pending,
	-- silently skipping it. Until ready flips, action() replies
	-- "unavailable" instead.
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
	ready[player] = canSave
end

function PlateService.start(remotes: Remotes.RemoteTable)
	local store, kind = Stores.open(STORE_NAME)
	liveStore = kind == "live"
	if store then
		registry = PlateRegistry.new(store, { clock = os.time })
	end
	-- Set before Economy starts, so no profile load is missed.
	Economy.onLoaded = onLoaded

	remotes.PlateQuery.OnServerInvoke = function(player: Player, input: any, style: any): any
		local ok, reply = pcall(query, player, input, style)
		return if ok then reply else { status = "unavailable" }
	end
	remotes.PlateAction.OnServerInvoke = function(player: Player, what: any, input: any, style: any): any
		local ok, reply = pcall(action, player, what, input, style)
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
		ready[player] = nil
		budgets.query[player] = nil
		budgets.action[player] = nil
	end)

	-- A new car takes its owner's plate (CarSpawner sets OwnerUserId before
	-- parenting it). ChildAdded is connected before the folder's existing
	-- children are stamped: CarSpawner can create workspace.Cars and parent
	-- the very first car into it in the same, unyielding call, so by the
	-- time WaitForChild below returns that car may already be there and
	-- would never fire ChildAdded if it were connected after the loop.
	local function stamp(child: Instance)
		local uid = child:GetAttribute("OwnerUserId")
		local owner = if type(uid) == "number" then Players:GetPlayerByUserId(uid) else nil
		if owner and child:IsA("Model") then
			child:SetAttribute("Plate", plateFor(owner))
		end
	end
	task.spawn(function()
		local cars = Workspace:WaitForChild("Cars", math.huge)
		cars.ChildAdded:Connect(stamp)
		for _, child in cars:GetChildren() do
			stamp(child)
		end
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
