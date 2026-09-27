--!strict
-- The plate registry (docs/superpowers/specs/2026-09-26-number-plates-design.md §4).
--
-- One DataStore key per plate ("SA:ABJ-7"). The key is the only truth about
-- who owns a plate; a player's profile holds a copy for display and is
-- corrected against the key.
--
-- Every write is one UpdateAsync that checks the key's current state first,
-- so two servers can never both win a plate: the store re-runs the check if
-- the key changed underneath it. Every write adds one to the key's version,
-- so a late write from an old transaction can never land on a plate that
-- has since changed hands. Freed keys are never deleted.
--
-- The flows (buy, release, recover) carry a transaction id (txn) from the
-- key into the profile's pendingTxns, so a flow cut off at any point is
-- finished from what the key says (settle). The store and the profile side
-- (Wallet) are passed in: the tests pass FakeDataStore and a fake wallet.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlateConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlateConfig"))

export type Status = "free" | "pending" | "owned"
export type HistoryLine = { owner: number, at: number, how: string }
export type Record = {
	schema: number,
	status: Status,
	owner: number?, -- UserId; nil unless owned
	txn: string?, -- the transaction that set the current status
	version: number, -- up by one on every write
	pendingUntil: number?, -- os.time(); only while pending
	since: number?, -- when the current owner got it
	price: number?, -- cash paid; used by refunds
	history: { HistoryLine }, -- last PlateConfig.historyLength
}

export type PlateState = "pending" | "owned" | "releasing"
export type OwnedPlate = { key: string, state: PlateState }
export type PendingTxn = { txn: string, kind: "buy" | "release", key: string, price: number }
-- The plate part of a player's profile (Economy.Profile has these fields).
export type PlateProfile = {
	cash: number,
	plates: { OwnedPlate },
	equipped: string?,
	pendingTxns: { PendingTxn },
}
export type Outcome = "ok" | "refused" | "error"
-- The profile side. transact changes the profile in one durable write:
-- mutate gets a copy and returns false to change nothing ("refused"); on
-- "ok" the same change has been written and made live; on "error" the live
-- profile is unchanged (the write may or may not have landed).
export type Wallet = {
	view: () -> PlateProfile,
	transact: (mutate: (p: PlateProfile) -> boolean) -> Outcome,
}
export type Store = {
	GetAsync: (self: any, key: string, options: DataStoreGetOptions?) -> any,
	UpdateAsync: (self: any, key: string, transform: (old: any, info: any) -> (any, { number }?)) -> any,
}
export type Options = {
	clock: () -> number, -- os.time in the game; the tests move it
	newTxn: (() -> string)?, -- GenerateGUID in the game
}
export type BuyResult = "done" | "taken" | "cash" | "unavailable" | "owned" | "pending"
export type ReleaseResult = "done" | "notowned" | "unavailable" | "pending"
export type Registry = {
	read: (key: string) -> (Record, boolean),
	available: (key: string) -> boolean?,
	reserve: (key: string, userId: number, txn: string) -> "ok" | "taken" | "error",
	confirm: (key: string, userId: number, txn: string, price: number) -> "ok" | "lost" | "error",
	cancel: (key: string, txn: string) -> "ok" | "error",
	free: (key: string, userId: number, version: number, txn: string) -> "ok" | "notmine" | "error",
	buy: (wallet: Wallet, userId: number, key: string, price: number) -> BuyResult,
	release: (wallet: Wallet, userId: number, key: string, refund: number) -> ReleaseResult,
	recover: (wallet: Wallet, userId: number) -> (),
	checkEquipped: (wallet: Wallet, userId: number) -> (),
}

local PlateRegistry = {}

local function blank(): Record
	return { schema = 1, status = "free", version = 0, history = {} }
end

-- A key as stored (or missing) read into a fresh Record.
local function readRecord(raw: any): Record
	local r = blank()
	if type(raw) ~= "table" then
		return r
	end
	if raw.status == "pending" or raw.status == "owned" then
		r.status = raw.status
	end
	r.owner = tonumber(raw.owner)
	r.txn = if type(raw.txn) == "string" then raw.txn else nil
	r.version = tonumber(raw.version) or 0
	r.pendingUntil = tonumber(raw.pendingUntil)
	r.since = tonumber(raw.since)
	r.price = tonumber(raw.price)
	if type(raw.history) == "table" then
		for _, h in raw.history do
			local owner, at = tonumber(type(h) == "table" and h.owner), tonumber(type(h) == "table" and h.at)
			if owner and at then
				table.insert(r.history, { owner = owner, at = at, how = tostring(h.how) })
			end
		end
	end
	return r
end

local function note(r: Record, owner: number, at: number, how: string)
	table.insert(r.history, { owner = owner, at = at, how = how })
	while #r.history > PlateConfig.historyLength do
		table.remove(r.history, 1)
	end
end

-- Free, or a claim that has run out.
local function isOpen(r: Record, now: number): boolean
	return r.status == "free" or (r.status == "pending" and (r.pendingUntil or 0) < now)
end

local function findPlate(p: PlateProfile, key: string): OwnedPlate?
	for _, plate in p.plates do
		if plate.key == key then
			return plate
		end
	end
	return nil
end

local function dropPlate(p: PlateProfile, key: string)
	for i = #p.plates, 1, -1 do
		if p.plates[i].key == key then
			table.remove(p.plates, i)
		end
	end
	if p.equipped == key then
		p.equipped = nil
	end
end

-- Takes a transaction off the profile. False if it was not there: it is
-- already finished, so nothing more is done and nothing is paid twice.
local function dropTxn(p: PlateProfile, txn: string): boolean
	for i, t in p.pendingTxns do
		if t.txn == txn then
			table.remove(p.pendingTxns, i)
			return true
		end
	end
	return false
end

function PlateRegistry.new(store: Store, options: Options): Registry
	local clock = options.clock
	local newTxn = options.newTxn or function(): string
		return HttpService:GenerateGUID(false)
	end
	local cache: { [string]: { at: number, free: boolean } } = {}
	-- GetAsync caches per server for ~4 s; settle and checkEquipped must see the key as it is now.
	local noCache = Instance.new("DataStoreGetOptions")
	noCache.UseCache = false

	-- One conditional write. decide gets the key as it is now and changes
	-- it, or returns false to leave it alone. Returns the record written
	-- (nil when decide declined) and whether the call succeeded. A failed
	-- call may still have written (the store can fail after committing), so
	-- callers treat it as "don't know" and settle from a fresh read later.
	local function update(key: string, userId: number?, decide: (r: Record) -> boolean): (Record?, boolean)
		local written: Record? = nil
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old: any, _info: any): (any, { number }?)
				written = nil
				local r = readRecord(old)
				if not decide(r) then
					return nil, nil
				end
				r.version += 1
				written = r
				return r, if userId then { userId } else nil
			end)
		end)
		cache[key] = nil
		if not ok then
			warn(`[Plates] write to {key} failed: {tostring(err)}`)
			return nil, false
		end
		return written, true
	end

	local function read(key: string): (Record, boolean)
		local ok, raw = pcall(function()
			return store:GetAsync(key, noCache)
		end)
		if not ok then
			warn(`[Plates] read of {key} failed: {tostring(raw)}`)
			return blank(), false
		end
		return readRecord(raw), true
	end

	-- Whether a plate can be bought now; nil when the store cannot be read.
	local function available(key: string): boolean?
		local now = clock()
		local c = cache[key]
		if c and now - c.at < PlateConfig.availabilityCacheSeconds then
			return c.free
		end
		local r, ok = read(key)
		if not ok then
			return nil
		end
		local free = isOpen(r, now)
		cache[key] = { at = now, free = free }
		return free
	end

	-- Buying, step 1: claim the plate for pendingSeconds.
	local function reserve(key: string, userId: number, txn: string): "ok" | "taken" | "error"
		local now = clock()
		local written, ok = update(key, userId, function(r)
			if not isOpen(r, now) then
				return false
			end
			r.status = "pending"
			r.owner = nil
			r.txn = txn
			r.pendingUntil = now + PlateConfig.pendingSeconds
			return true
		end)
		if not ok then
			return "error"
		end
		return if written then "ok" else "taken"
	end

	-- Buying, step 3: only if the key still holds this purchase's claim.
	local function confirm(key: string, userId: number, txn: string, price: number): "ok" | "lost" | "error"
		local now = clock()
		local written, ok = update(key, userId, function(r)
			if r.status ~= "pending" or r.txn ~= txn then
				return false
			end
			r.status = "owned"
			r.owner = userId
			r.since = now
			r.price = price
			r.pendingUntil = nil
			note(r, userId, now, "buy")
			return true
		end)
		if not ok then
			return "error"
		end
		return if written then "ok" else "lost"
	end

	-- Lets go of a claim this purchase made (not enough cash, or the charge
	-- failed). Does nothing if the key moved on.
	local function cancel(key: string, txn: string): "ok" | "error"
		local _, ok = update(key, nil, function(r)
			if r.status ~= "pending" or r.txn ~= txn then
				return false
			end
			r.status = "free"
			r.txn = nil
			r.pendingUntil = nil
			return true
		end)
		return if ok then "ok" else "error"
	end

	-- Releasing, step 2: only if owned by this player at the version read.
	local function free(key: string, userId: number, version: number, txn: string): "ok" | "notmine" | "error"
		local now = clock()
		local written, ok = update(key, userId, function(r)
			if r.status ~= "owned" or r.owner ~= userId or r.version ~= version then
				return false
			end
			r.status = "free"
			r.owner = nil
			r.txn = txn
			r.since = nil
			r.price = nil
			note(r, userId, now, "release")
			return true
		end)
		if not ok then
			return "error"
		end
		return if written then "ok" else "notmine"
	end

	-- The profile side of a finished purchase: the plate is owned and fitted.
	local function finishBuy(wallet: Wallet, t: PendingTxn): boolean
		return wallet.transact(function(p)
			if not dropTxn(p, t.txn) then
				return false
			end
			local plate = findPlate(p, t.key)
			if plate then
				plate.state = "owned"
			else
				table.insert(p.plates, { key = t.key, state = "owned" })
			end
			p.equipped = t.key
			return true
		end) ~= "error"
	end

	-- The profile side of a refunded purchase or a finished release: the
	-- plate goes and t.price (the price, or the release's refund) comes
	-- back, in the same write that takes the transaction off.
	local function dropAndCredit(wallet: Wallet, t: PendingTxn): boolean
		return wallet.transact(function(p)
			if not dropTxn(p, t.txn) then
				return false
			end
			dropPlate(p, t.key)
			p.cash += t.price
			return true
		end) ~= "error"
	end

	-- Brings one transaction to its end from what the plate key says now
	-- (the recovery table, spec §4):
	--   buying,    key pending with this txn  -> confirm, then finish
	--   buying,    key owned by me, this txn   -> finish
	--   buying,    anything else               -> refund
	--   releasing, key owned by me             -> free it, then finish
	--   releasing, free or not mine            -> finish
	-- "pending" means the store could not be reached; try again later.
	local function settle(wallet: Wallet, userId: number, t: PendingTxn, depth: number?): "done" | "refunded" | "pending"
		local d = depth or 0
		if d > 3 then
			return "pending"
		end
		local rec, ok = read(t.key)
		if not ok then
			return "pending"
		end
		if t.kind == "buy" then
			if rec.status == "pending" and rec.txn == t.txn then
				local c = confirm(t.key, userId, t.txn, t.price)
				if c == "error" then
					return "pending"
				elseif c == "lost" then
					return settle(wallet, userId, t, d + 1)
				end
				return if finishBuy(wallet, t) then "done" else "pending"
			elseif rec.status == "owned" and rec.owner == userId and rec.txn == t.txn then
				return if finishBuy(wallet, t) then "done" else "pending"
			end
			return if dropAndCredit(wallet, t) then "refunded" else "pending"
		end
		if rec.status == "owned" and rec.owner == userId then
			local f = free(t.key, userId, rec.version, t.txn)
			if f == "error" then
				return "pending"
			elseif f == "notmine" then
				return settle(wallet, userId, t, d + 1)
			end
		end
		return if dropAndCredit(wallet, t) then "done" else "pending"
	end

	-- Every unfinished transaction on the profile, brought to its end.
	local function recover(wallet: Wallet, userId: number)
		for _, t in table.clone(wallet.view().pendingTxns) do
			settle(wallet, userId, t)
		end
	end

	-- Reserve, charge, confirm (spec §4, buying).
	local function buy(wallet: Wallet, userId: number, key: string, price: number): BuyResult
		recover(wallet, userId)
		local p = wallet.view()
		if #p.pendingTxns > 0 then
			return "pending"
		end
		if findPlate(p, key) then
			return "owned"
		end
		if p.cash < price then
			return "cash"
		end
		local txn = newTxn()
		local r = reserve(key, userId, txn)
		if r == "taken" then
			return "taken"
		elseif r == "error" then
			cancel(key, txn) -- the claim may have landed
			return "unavailable"
		end
		local t: PendingTxn = { txn = txn, kind = "buy", key = key, price = price }
		local charged = wallet.transact(function(q)
			if q.cash < price then
				return false
			end
			q.cash -= price
			table.insert(q.pendingTxns, table.clone(t))
			table.insert(q.plates, { key = key, state = "pending" })
			return true
		end)
		if charged ~= "ok" then
			-- Nothing is charged in this session. If the write landed
			-- anyway, the next load settles it from the key: if cancel
			-- freed the claim, it refunds; if cancel failed too, the key is
			-- still pending with this txn, so it confirms (charged once,
			-- plate owned).
			cancel(key, txn)
			return if charged == "refused" then "cash" else "unavailable"
		end
		local s = settle(wallet, userId, t)
		return if s == "done" then "done" elseif s == "refunded" then "taken" else "pending"
	end

	-- Mark, free, credit (spec §4, releasing). Built and tested now; no
	-- button sells or trades a plate yet.
	local function release(wallet: Wallet, userId: number, key: string, refund: number): ReleaseResult
		recover(wallet, userId)
		local p = wallet.view()
		if #p.pendingTxns > 0 then
			return "pending"
		end
		local plate = findPlate(p, key)
		if not plate or plate.state ~= "owned" then
			return "notowned"
		end
		local t: PendingTxn = { txn = newTxn(), kind = "release", key = key, price = refund }
		local marked = wallet.transact(function(q)
			local mine = findPlate(q, key)
			if not mine or mine.state ~= "owned" then
				return false
			end
			mine.state = "releasing"
			if q.equipped == key then
				q.equipped = nil
			end
			table.insert(q.pendingTxns, table.clone(t))
			return true
		end)
		if marked == "refused" then
			return "notowned"
		elseif marked == "error" then
			return "unavailable"
		end
		return if settle(wallet, userId, t) == "done" then "done" else "pending"
	end

	-- The equipped plate against its key (at join and on equip, spec §4):
	-- if the key says it is not this player's, it leaves the profile.
	local function checkEquipped(wallet: Wallet, userId: number)
		local key = wallet.view().equipped
		if not key then
			return
		end
		local plate = findPlate(wallet.view(), key)
		if plate and plate.state ~= "owned" then
			return -- mid-transaction: settle deals with it
		end
		if plate then
			local rec, ok = read(key)
			if not ok or (rec.status == "owned" and rec.owner == userId) then
				return
			end
		end
		wallet.transact(function(q)
			if q.equipped ~= key then
				return false
			end
			dropPlate(q, key)
			return true
		end)
	end

	return {
		read = read,
		available = available,
		reserve = reserve,
		confirm = confirm,
		cancel = cancel,
		free = free,
		buy = buy,
		release = release,
		recover = recover,
		checkEquipped = checkEquipped,
	}
end

return PlateRegistry
