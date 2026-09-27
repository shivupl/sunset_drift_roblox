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
	GetAsync: (self: any, key: string) -> any,
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

function PlateRegistry.new(store: Store, options: Options): Registry
	local clock = options.clock
	local newTxn = options.newTxn or function(): string
		return HttpService:GenerateGUID(false)
	end
	local cache: { [string]: { at: number, free: boolean } } = {}

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
			return store:GetAsync(key)
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

	-- FLOWS (Task 4)

	return {
		read = read,
		available = available,
		reserve = reserve,
		confirm = confirm,
		cancel = cancel,
		free = free,
		buy = function(): BuyResult
			return "unavailable"
		end,
		release = function(): ReleaseResult
			return "unavailable"
		end,
		recover = function() end,
		checkEquipped = function() end,
	} :: any
end

return PlateRegistry
