--!strict
-- Cash, the all-time best and number plates, persisted per player.
--
-- Everything the client can see is an attribute on the Player (Cash,
-- SessionBest, BestScore, Plates, PlateEquipped, Sky): attributes replicate
-- server to client on their own, and a client writing one locally changes
-- nothing on the server. No remote carries a balance, so there is nothing
-- to forge.
--
-- Data safety rules, in order of how much they matter:
--   1. A profile whose load failed is never saved. Overwriting a real
--      balance with a fresh zero is the one unrecoverable mistake here.
--   2. Writes go through UpdateAsync, so the all-time best merges with
--      whatever is already stored rather than clobbering it.
--   3. One write per player at a time: a save holding an older copy must
--      never land after a plate transaction's write.
--   4. Autosave on a timer, save on leave, and save everyone on shutdown.
--
-- Plates (docs/superpowers/specs/2026-09-26-number-plates-design.md §4, §5):
-- the profile holds a copy of the plates a player owns, the one equipped,
-- and any plate transaction not yet finished (pendingTxns). The plate's own
-- key (PlateRegistry) is the truth. Money that moves with a plate moves in
-- one write with the transaction's record (transact), so it is charged once
-- and refunded at most once.
--
-- Not implemented: cross-server session locking. Roblox keeps a player in
-- one server at a time, so the exposure is a rejoin racing the old server's
-- save. Rule 2 keeps the best score safe through that; cash could lose the
-- last few seconds. A plate never gets two owners even so: the key is the
-- truth and recovery re-reads it; the cash side shares the rejoin-race
-- exposure described above (fix 6, 2026-09-27 review: "plates are safe"
-- overclaimed this). Worth revisiting when teleports arrive (Phase 2).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlateConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlateConfig"))
local SkyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SkyConfig"))
local PlateRegistry = require(script.Parent.PlateRegistry)
local Stores = require(script.Parent.Stores)

local STORE_NAME = "HajwalaPlayer_v1"
local KEY_PREFIX = "p_"
local LOAD_ATTEMPTS = 4

export type Profile = {
	cash: number,
	bestScore: number,
	plates: { PlateRegistry.OwnedPlate },
	equipped: string?,
	pendingTxns: { PlateRegistry.PendingTxn },
	sky: string?, -- the time of day picked in the menu (SkyConfig id); nil = the default
}

local Economy = {}

-- Called when a player's profile load has finished. savable is false when
-- it failed or there is no store: nothing will be saved this session.
Economy.onLoaded = nil :: ((player: Player, savable: boolean) -> ())?

local store: any = nil
local storeKind: Stores.Kind = "none"
local profiles: { [Player]: Profile } = {}
local savable: { [Player]: boolean } = {}
local writing: { [Player]: boolean } = {}
local autosaveTimer = 0

local function key(player: Player): string
	return KEY_PREFIX .. player.UserId
end

local function fresh(): Profile
	return { cash = 0, bestScore = 0, plates = {}, equipped = nil, pendingTxns = {}, sky = nil }
end

local function publish(player: Player)
	local p = profiles[player]
	if not p or not player.Parent then
		return
	end
	player:SetAttribute("Cash", p.cash)
	player:SetAttribute("BestScore", p.bestScore)
	local owned: { string } = {}
	for _, plate in p.plates do
		if plate.state == "owned" then
			table.insert(owned, plate.key)
		end
	end
	player:SetAttribute("Plates", table.concat(owned, ","))
	player:SetAttribute("PlateEquipped", p.equipped)
	player:SetAttribute("Sky", p.sky)
end

-- A stored profile read defensively. The plate fields are new (2026-09-26):
-- an older profile has none and reads them as empty, so nothing migrates.
local function readProfile(raw: any): Profile
	local p = fresh()
	if type(raw) ~= "table" then
		return p
	end
	p.cash = math.max(tonumber(raw.cash) or 0, 0)
	p.bestScore = math.max(tonumber(raw.bestScore) or 0, 0)
	if type(raw.plates) == "table" then
		for _, e in raw.plates do
			if type(e) == "table" and type(e.key) == "string" and (e.state == "pending" or e.state == "owned" or e.state == "releasing") then
				table.insert(p.plates, { key = e.key, state = e.state })
			end
		end
	end
	if type(raw.equipped) == "string" then
		p.equipped = raw.equipped
	end
	-- New 2026-09-28; an older profile has none and gets the default sky.
	if type(raw.sky) == "string" and SkyConfig.find(raw.sky) then
		p.sky = raw.sky
	end
	if type(raw.pendingTxns) == "table" then
		for _, t in raw.pendingTxns do
			if type(t) == "table" and type(t.txn) == "string" and type(t.key) == "string" and (t.kind == "buy" or t.kind == "release") then
				local price = tonumber(t.price)
				if price then
					-- Never negative: a refund credits this amount to cash.
					table.insert(p.pendingTxns, { txn = t.txn, kind = t.kind, key = t.key, price = math.max(price, 0) })
				end
			end
		end
	end
	return p
end

local function copyProfile(p: Profile): Profile
	local out = fresh()
	out.cash = p.cash
	out.bestScore = p.bestScore
	out.equipped = p.equipped
	out.sky = p.sky
	for _, plate in p.plates do
		table.insert(out.plates, table.clone(plate))
	end
	for _, t in p.pendingTxns do
		table.insert(out.pendingTxns, table.clone(t))
	end
	return out
end

-- What is written: this session's profile, with the all-time best merged
-- rather than overwritten (another session may have set a higher best).
local function encode(p: Profile, old: any): any
	local out = copyProfile(p)
	out.bestScore = math.max(p.bestScore, readProfile(old).bestScore)
	return out
end

local function lock(player: Player)
	while writing[player] do
		task.wait()
	end
	writing[player] = true
end

local function unlock(player: Player)
	writing[player] = nil
end

local function loaded(player: Player, ok: boolean)
	local cb = Economy.onLoaded
	if cb and player.Parent then
		task.spawn(cb, player, ok)
	end
end

function Economy.load(player: Player)
	if profiles[player] then
		return
	end
	-- Start the session at zero so the HUD has numbers immediately; the
	-- stored values replace them when the read lands.
	profiles[player] = fresh()
	savable[player] = false
	player:SetAttribute("SessionBest", 0)
	publish(player)

	local s = store
	if not s then
		loaded(player, false)
		return
	end
	local ok, result
	for attempt = 1, LOAD_ATTEMPTS do
		ok, result = pcall(function()
			return s:GetAsync(key(player))
		end)
		if ok then
			break
		end
		task.wait(attempt)
		if not player.Parent then
			return
		end
	end
	if not player.Parent then
		return
	end
	if not ok then
		warn(`[Hajwala] profile load failed for {player.Name}, playing without saving: {tostring(result)}`)
		loaded(player, false)
		return
	end
	local p = readProfile(result)
	if storeKind == "fake" and result == nil then
		p.cash = PlateConfig.studioCash
	end
	-- A sky picked while the read was in flight is newer than the stored one.
	local session = profiles[player]
	if session and session.sky then
		p.sky = session.sky
	end
	profiles[player] = p
	savable[player] = true
	publish(player)
	loaded(player, true)
end

function Economy.save(player: Player)
	local s = store
	if not s or not profiles[player] or not savable[player] then
		return
	end
	lock(player)
	local p = profiles[player]
	if p then
		local ok, err = pcall(function()
			s:UpdateAsync(key(player), function(old: any)
				return encode(p, old)
			end)
		end)
		if not ok then
			warn(`[Hajwala] profile save failed for {player.Name}: {tostring(err)}`)
		end
	end
	unlock(player)
end

-- Changes the profile in one durable write (PlateRegistry.Wallet): mutate
-- gets a copy and returns false to change nothing ("refused"). On "ok" the
-- copy has been written and the same change made to the live profile. It is
-- made again rather than the copy kept, because cash earned while the write
-- was in flight is on the live profile. On "error" the live profile is
-- unchanged.
function Economy.transact(player: Player, mutate: (p: Profile) -> boolean): PlateRegistry.Outcome
	local s = store
	if not s or not profiles[player] or not savable[player] then
		return "error"
	end
	lock(player)
	local live = profiles[player]
	if not live then
		unlock(player)
		return "error"
	end
	local draft = copyProfile(live)
	local mutateOk, wantsWrite = pcall(mutate, draft)
	if not mutateOk then
		unlock(player)
		warn(`[Hajwala] transact mutate failed for {player.Name}: {tostring(wantsWrite)}`)
		return "error"
	end
	if not wantsWrite then
		unlock(player)
		return "refused"
	end
	local ok, err = pcall(function()
		s:UpdateAsync(key(player), function(old: any)
			return encode(draft, old)
		end)
	end)
	unlock(player)
	if not ok then
		warn(`[Hajwala] profile write failed for {player.Name}: {tostring(err)}`)
		return "error"
	end
	-- The write already landed: if this second call to mutate fails, the live
	-- profile is now out of step with what was just saved. That is worse than
	-- the write failing outright, so it gets a loud warning rather than the
	-- ordinary one above.
	local liveOk, liveErr = pcall(mutate, live)
	if not liveOk then
		warn(`[Hajwala] transact wrote {player.Name}'s profile but could not apply the same change live: {tostring(liveErr)}`)
	end
	publish(player)
	return "ok"
end

-- The profile side of the plate flows, for PlateRegistry.
function Economy.wallet(player: Player): PlateRegistry.Wallet
	return {
		view = function(): PlateRegistry.PlateProfile
			return (profiles[player] or fresh()) :: any
		end,
		transact = function(mutate: (p: PlateRegistry.PlateProfile) -> boolean): PlateRegistry.Outcome
			return Economy.transact(player, mutate :: any)
		end,
	}
end

-- Equips a plate the player owns, or nil for the session's default plate.
-- Kept in memory; the next save writes it. False if not owned.
function Economy.setEquipped(player: Player, plateKey: string?): boolean
	local p = profiles[player]
	if not p then
		return false
	end
	if plateKey then
		local owned = false
		for _, plate in p.plates do
			if plate.key == plateKey and plate.state == "owned" then
				owned = true
			end
		end
		if not owned then
			return false
		end
	end
	p.equipped = plateKey
	publish(player)
	return true
end

-- Picks the time of day the player sees (SkyConfig id). Kept in memory; the
-- next save writes it. False for an unknown id.
function Economy.setSky(player: Player, id: string): boolean
	local p = profiles[player]
	if not p or not SkyConfig.find(id) then
		return false
	end
	p.sky = id
	publish(player)
	return true
end

function Economy.release(player: Player)
	Economy.save(player)
	profiles[player] = nil
	savable[player] = nil
	writing[player] = nil
end

function Economy.profile(player: Player): Profile?
	return profiles[player]
end

-- Returns the new balance. Amounts are always computed on the server.
function Economy.award(player: Player, cash: number): number
	local p = profiles[player]
	if not p or cash <= 0 then
		return if p then p.cash else 0
	end
	p.cash += math.floor(cash)
	publish(player)
	return p.cash
end

-- Returns true when this is a new personal best.
function Economy.recordScore(player: Player, points: number): boolean
	local p = profiles[player]
	if not p then
		return false
	end
	local sessionBest = (tonumber(player:GetAttribute("SessionBest")) or 0)
	if points > sessionBest then
		player:SetAttribute("SessionBest", points)
	end
	if points <= p.bestScore then
		return false
	end
	p.bestScore = points
	publish(player)
	return true
end

function Economy.step(dt: number, autosaveSeconds: number)
	autosaveTimer += dt
	if autosaveTimer < autosaveSeconds then
		return
	end
	autosaveTimer = 0
	for _, player in Players:GetPlayers() do
		-- A write already in flight (most likely a plate transaction) has
		-- the lock; queuing this autosave behind it would just make it wait
		-- on Economy.save's own lock() (fix 4, 2026-09-27 review) instead of
		-- being skipped this cycle as before. The leave-save and shutdown
		-- save still go through Economy.save and wait on the lock as they
		-- always have — only the periodic autosave skips a busy player.
		if savable[player] and not writing[player] then
			task.spawn(Economy.save, player)
		end
	end
end

function Economy.start()
	store, storeKind = Stores.open(STORE_NAME)
	if storeKind == "none" then
		warn("[Hajwala] no DataStore, cash will not persist")
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(Economy.load, player)
	end)
	Players.PlayerRemoving:Connect(Economy.release)
	for _, player in Players:GetPlayers() do
		task.spawn(Economy.load, player)
	end

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				Economy.save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 20
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return Economy
