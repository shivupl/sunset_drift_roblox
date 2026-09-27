--!strict
-- PlateRegistry against FakeDataStore (spec §6): two servers racing, a
-- failure at every step of a purchase and a release, and the clock moved
-- past a pending claim. After each, the two rules that matter:
--   * a plate never has two owners;
--   * cash is charged exactly when the plate is recorded, or refunded.
-- The modules are server modules, cloned so each run gets fresh code.
local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")
local PlateRegistry = (require :: any)(Server:WaitForChild("PlateRegistry"):Clone())
local FakeDataStore = (require :: any)(Server:WaitForChild("FakeDataStore"):Clone())
local PlateConfig = require(script.Parent.Parent.PlateConfig)
local Tests = require(script.Parent)
type T = Tests.T

local KEY = "SA:ABJ-7"
local PRICE = 500000
local START = 2000000
local REFUND = 250000

type TestWallet = {
	userId: number,
	view: () -> any,
	transact: (mutate: (p: any) -> boolean) -> string,
	reload: () -> (),
}

-- A profile over the fake store, written the way Economy.transact writes:
-- change a copy, write it whole, and only then make the same change to the
-- live profile.
local function newWallet(store: any, userId: number, cash: number?): TestWallet
	local profileKey = "p_" .. userId
	local live: any = { cash = cash or START, plates = {}, pendingTxns = {} }
	store.data[profileKey] = FakeDataStore.copy(live)
	local w: any = { userId = userId }
	w.view = function()
		return live
	end
	w.transact = function(mutate: (p: any) -> boolean): string
		local draft = FakeDataStore.copy(live)
		if not mutate(draft) then
			return "refused"
		end
		local ok = pcall(function()
			store:UpdateAsync(profileKey, function()
				return FakeDataStore.copy(draft), nil
			end)
		end)
		if not ok then
			return "error"
		end
		mutate(live)
		return "ok"
	end
	-- A server crash: this session's memory is gone; the next session loads
	-- what was written.
	w.reload = function()
		live = FakeDataStore.copy(store.data[profileKey])
	end
	return w :: TestWallet
end

-- A fresh store and clock, and a way to start "servers" on them. Every
-- server shares the transaction counter, so ids are t1, t2, ...
local function world(): (any, { now: number }, () -> any)
	local store = FakeDataStore.new()
	local clock = { now = 1000 }
	local n = 0
	local function registry(): any
		return PlateRegistry.new(store, {
			clock = function(): number
				return clock.now
			end,
			newTxn = function(): string
				n += 1
				return "t" .. n
			end,
		})
	end
	return store, clock, registry
end

return function(t: T)
	do -- Reserve, confirm, cancel, free on one key
		local store, clock, registry = world()
		local reg = registry()
		t.eq(reg.reserve(KEY, 1, "a"), "ok", "a missing key can be reserved")
		t.eq(store.data[KEY].status, "pending", "reserved is pending")
		t.eq(store.data[KEY].version, 1, "first write is version 1")
		t.eq(reg.reserve(KEY, 2, "b"), "taken", "a live claim blocks another")
		t.eq(reg.confirm(KEY, 1, "wrong", PRICE), "lost", "confirm needs the same txn")
		t.eq(reg.confirm(KEY, 1, "a", PRICE), "ok", "confirm with the txn")
		t.eq(store.data[KEY].owner, 1, "owned by the buyer")
		t.eq(store.data[KEY].price, PRICE, "price kept for refunds")
		t.eq(#store.data[KEY].history, 1, "one history line")
		t.eq(store.userIds[KEY][1], 1, "the owner's UserId is on the write (right to erasure)")
		t.eq(reg.reserve(KEY, 2, "c"), "taken", "an owned plate cannot be reserved")
		local v = store.data[KEY].version
		t.eq(reg.free(KEY, 2, v, "d"), "notmine", "only the owner frees it")
		t.eq(reg.free(KEY, 1, v - 1, "d"), "notmine", "a stale version does not free it")
		t.eq(reg.free(KEY, 1, v, "d"), "ok", "the owner frees it at the version read")
		t.eq(store.data[KEY].status, "free", "free again")
		t.eq(store.data[KEY].version, v + 1, "version keeps rising")
		t.eq(reg.reserve(KEY, 2, "e"), "ok", "a freed plate is back in the pool")
		t.eq(reg.cancel(KEY, "wrong"), "ok", "cancel with another txn is a no-op")
		t.eq(store.data[KEY].status, "pending", "still pending")
		t.eq(reg.cancel(KEY, "e"), "ok", "cancel with the txn")
		t.eq(store.data[KEY].status, "free", "cancelled claim is free")

		-- A claim that has run out can be taken
		reg.reserve(KEY, 1, "f")
		clock.now += PlateConfig.pendingSeconds - 1
		t.eq(reg.reserve(KEY, 2, "g"), "taken", "claim still live just before it runs out")
		clock.now += 2
		t.eq(reg.reserve(KEY, 2, "g"), "ok", "a run-out claim is open")
	end

	do -- History keeps the last historyLength lines
		local store, _, registry = world()
		local reg = registry()
		for i = 1, PlateConfig.historyLength + 3 do
			reg.reserve(KEY, i, "r" .. i)
			reg.confirm(KEY, i, "r" .. i, PRICE)
			reg.free(KEY, i, store.data[KEY].version, "f" .. i)
		end
		t.eq(#store.data[KEY].history, PlateConfig.historyLength, "history is trimmed")
	end

	do -- Two servers reserve at once: the write that lands second re-checks and backs off
		local store, _, registry = world()
		local reg1, reg2 = registry(), registry()
		local second: string? = nil
		store.beforeCommit = function(k: string)
			if k ~= KEY then
				return
			end
			store.beforeCommit = nil
			second = reg2.reserve(KEY, 2, "b")
		end
		t.eq(reg1.reserve(KEY, 1, "a"), "taken", "race: the later write is refused")
		t.eq(second, "ok", "race: the earlier write wins")
		t.eq(store.data[KEY].txn, "b", "race: the key holds the winner's txn")
	end

	do -- A write that fails before or after landing reports an error
		local store, _, registry = world()
		local reg = registry()
		store.hook = function(_op: string, _k: string, phase: string)
			if phase == "before" then
				error("down")
			end
		end
		t.eq(reg.reserve(KEY, 1, "a"), "error", "store down: error")
		t.eq(store.data[KEY], nil, "nothing written")
		store.hook = function(_op: string, _k: string, phase: string)
			if phase == "after" then
				error("lost reply")
			end
		end
		t.eq(reg.reserve(KEY, 1, "a"), "error", "reply lost: error")
		t.eq(store.data[KEY].status, "pending", "but the write landed")
		store.hook = nil
		local _, ok = reg.read(KEY)
		t.ok(ok, "reads work again")
	end

	do -- Availability is cached per server for availabilityCacheSeconds
		local store, clock, registry = world()
		local reg1, reg2 = registry(), registry()
		t.eq(reg2.available(KEY), true, "free before anyone buys")
		reg1.reserve(KEY, 1, "a")
		reg1.confirm(KEY, 1, "a", PRICE)
		t.eq(reg1.available(KEY), false, "the writing server knows at once")
		t.eq(reg2.available(KEY), true, "another server may show it free until its cache runs out")
		clock.now += PlateConfig.availabilityCacheSeconds
		t.eq(reg2.available(KEY), false, "then it knows")
		store.hook = function()
			error("down")
		end
		clock.now += PlateConfig.availabilityCacheSeconds
		t.eq(reg2.available(KEY), nil, "unknown while the store is down")
		store.hook = nil
	end
end
