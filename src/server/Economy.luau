--!strict
-- Cash and the all-time best, persisted per player.
--
-- Everything the client can see is an attribute on the Player (Cash,
-- SessionBest, BestScore): attributes replicate server to client on their
-- own, and a client writing one locally changes nothing on the server. No
-- remote carries a balance, so there is nothing to forge.
--
-- Data safety rules, in order of how much they matter:
--   1. A profile whose load failed is never saved. Overwriting a real
--      balance with a fresh zero is the one unrecoverable mistake here.
--   2. Writes go through UpdateAsync, so the all-time best merges with
--      whatever is already stored rather than clobbering it.
--   3. Autosave on a timer, save on leave, and save everyone on shutdown.
--
-- Not implemented: cross-server session locking. Roblox keeps a player in
-- one server at a time, so the exposure is a rejoin racing the old server's
-- save. Rule 2 keeps the best score safe through that; cash could lose the
-- last few seconds. Worth revisiting when teleports arrive (Phase 2).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local STORE_NAME = "HajwalaPlayer_v1"
local KEY_PREFIX = "p_"
local LOAD_ATTEMPTS = 4

export type Profile = {
	cash: number,
	bestScore: number,
}

local Economy = {}

local store: DataStore? = nil
local storeError: string? = nil
local profiles: { [Player]: Profile } = {}
local savable: { [Player]: boolean } = {}
local saving: { [Player]: boolean } = {}
local autosaveTimer = 0

local function key(player: Player): string
	return KEY_PREFIX .. player.UserId
end

local function publish(player: Player)
	local p = profiles[player]
	if not p or not player.Parent then
		return
	end
	player:SetAttribute("Cash", p.cash)
	player:SetAttribute("BestScore", p.bestScore)
end

local function readProfile(raw: any): Profile
	local p: Profile = { cash = 0, bestScore = 0 }
	if type(raw) == "table" then
		p.cash = math.max(tonumber(raw.cash) or 0, 0)
		p.bestScore = math.max(tonumber(raw.bestScore) or 0, 0)
	end
	return p
end

function Economy.load(player: Player)
	if profiles[player] then
		return
	end
	-- Start the session at zero so the HUD has numbers immediately; the
	-- stored values replace them when the read lands.
	profiles[player] = { cash = 0, bestScore = 0 }
	savable[player] = false
	player:SetAttribute("SessionBest", 0)
	publish(player)

	local s = store
	if not s then
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
		return
	end
	profiles[player] = readProfile(result)
	savable[player] = true
	publish(player)
end

function Economy.save(player: Player)
	local s = store
	local p = profiles[player]
	if not s or not p or not savable[player] or saving[player] then
		return
	end
	saving[player] = true
	local ok, err = pcall(function()
		s:UpdateAsync(key(player), function(old: any)
			local stored = readProfile(old)
			return {
				cash = p.cash,
				-- Merge rather than overwrite: another session may have set a
				-- higher best since this one loaded.
				bestScore = math.max(p.bestScore, stored.bestScore),
			}
		end)
	end)
	saving[player] = false
	if not ok then
		warn(`[Hajwala] profile save failed for {player.Name}: {tostring(err)}`)
	end
end

function Economy.release(player: Player)
	Economy.save(player)
	profiles[player] = nil
	savable[player] = nil
	saving[player] = nil
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
		if savable[player] then
			task.spawn(Economy.save, player)
		end
	end
end

function Economy.start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		storeError = tostring(result)
		warn(`[Hajwala] no DataStore, cash will not persist: {storeError}`)
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
