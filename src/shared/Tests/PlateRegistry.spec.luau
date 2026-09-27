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

-- The rules, for one plate and some players. ownerCash is what the plate's
-- owner must have left; otherCash is what everyone else must have.
local function check(t: T, label: string, store: any, wallets: { TestWallet }, ownerCash: number, otherCash: number)
	local rec = store.data[KEY]
	local owner = if type(rec) == "table" and rec.status == "owned" then rec.owner else nil
	for _, w in wallets do
		local p = w.view()
		t.eq(#p.pendingTxns, 0, `{label}: user {w.userId} has nothing unfinished`)
		local has: any = nil
		for _, plate in p.plates do
			if plate.key == KEY then
				has = plate
			end
		end
		if owner == w.userId then
			t.ok(has ~= nil and has.state == "owned", `{label}: user {w.userId} owns it and has it`)
			t.eq(p.cash, ownerCash, `{label}: user {w.userId} paid exactly once`)
		else
			t.ok(has == nil, `{label}: user {w.userId} does not own it and does not have it`)
			t.eq(p.cash, otherCash, `{label}: user {w.userId} is square`)
		end
	end
end

-- Failure modes, counted in store calls from when failAt is called:
--   once-before   call `at` fails, nothing written; later calls work
--   once-after    call `at` writes, then fails; later calls work
--   crash-before  call `at` and every later call fail, nothing written
--   crash-after   call `at` writes then fails; every later call fails
local MODES = { "once-before", "once-after", "crash-before", "crash-after" }
local function failAt(store: any, mode: string, at: number)
	store.ops = 0
	store.hook = function(_op: string, _key: string, phase: string)
		local n = store.ops
		local hit
		if mode == "once-before" then
			hit = n == at and phase == "before"
		elseif mode == "once-after" then
			hit = n == at and phase == "after"
		elseif mode == "crash-before" then
			hit = n >= at and phase == "before"
		else
			hit = (n == at and phase == "after") or (n > at and phase == "before")
		end
		if hit then
			error(`fake failure ({mode} at {at})`)
		end
	end
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

	do -- A clean purchase, a second one, and not enough cash
		local store, _, registry = world()
		local reg = registry()
		local w1 = newWallet(store, 1)
		t.eq(reg.buy(w1, 1, KEY, PRICE), "done", "clean purchase")
		t.eq(w1.view().equipped, KEY, "buying equips it")
		check(t, "clean purchase", store, { w1 }, START - PRICE, START)
		t.eq(reg.buy(w1, 1, KEY, PRICE), "owned", "buying it again")
		local poor = newWallet(store, 3, 100)
		t.eq(reg.buy(poor, 3, "SA:ABJ-8", PRICE), "cash", "not enough cash")
		t.eq(store.data["SA:ABJ-8"], nil, "the plate was never touched")
		t.eq(poor.view().cash, 100, "nothing charged")
	end

	do -- Cash spent between the check and the charge: the claim is let go at once
		local store, _, registry = world()
		local reg = registry()
		local w1 = newWallet(store, 1)
		store.beforeCommit = function(k: string)
			if k ~= KEY then
				return
			end
			store.beforeCommit = nil
			w1.view().cash = 0
		end
		t.eq(reg.buy(w1, 1, KEY, PRICE), "cash", "refused at the charge")
		t.eq(store.data[KEY].status, "free", "claim let go")
		t.eq(w1.view().cash, 0, "nothing charged")
	end

	do -- Two servers buy the same plate at once
		local store, _, registry = world()
		local reg1, reg2 = registry(), registry()
		local w1, w2 = newWallet(store, 1), newWallet(store, 2)
		local second: string? = nil
		store.beforeCommit = function(k: string)
			if k ~= KEY then
				return
			end
			store.beforeCommit = nil
			second = reg2.buy(w2, 2, KEY, PRICE)
		end
		t.eq(reg1.buy(w1, 1, KEY, PRICE), "taken", "race: the later buyer is told it is taken")
		t.eq(second, "done", "race: the earlier buyer gets it")
		check(t, "race", store, { w1, w2 }, START - PRICE, START)
	end

	do -- A charge slower than the claim: someone else takes the plate, the first buyer is refunded
		local store, clock, registry = world()
		local reg1, reg2 = registry(), registry()
		local w1, w2 = newWallet(store, 1), newWallet(store, 2)
		store.beforeCommit = function(k: string)
			if k ~= "p_1" then
				return
			end
			store.beforeCommit = nil
			clock.now += PlateConfig.pendingSeconds + 1
			reg2.buy(w2, 2, KEY, PRICE)
		end
		t.eq(reg1.buy(w1, 1, KEY, PRICE), "taken", "slow charge: told it is taken")
		check(t, "slow charge", store, { w1, w2 }, START - PRICE, START)
	end

	do -- A late write from an old transaction never lands after the plate changed hands
		local store, _, registry = world()
		local reg = registry()
		local w1, w2 = newWallet(store, 1), newWallet(store, 2)
		reg.buy(w1, 1, KEY, PRICE) -- txn t1
		local oldVersion = store.data[KEY].version
		t.eq(reg.release(w1, 1, KEY, REFUND), "done", "released")
		t.eq(reg.buy(w2, 2, KEY, PRICE), "done", "bought by someone else")
		t.eq(reg.confirm(KEY, 1, "t1", PRICE), "lost", "the old confirm does not land")
		t.eq(reg.free(KEY, 2, oldVersion, "late"), "notmine", "an old version does not free it")
		t.eq(store.data[KEY].owner, 2, "still the new owner's")
		check(t, "changed hands", store, { w2 }, START - PRICE, START)
	end

	do -- The equipped plate is checked against its key: someone else's goes
		local store, _, registry = world()
		local reg = registry()
		local w1 = newWallet(store, 1)
		reg.buy(w1, 1, KEY, PRICE)
		store.data[KEY].owner = 2
		reg.checkEquipped(w1, 1)
		t.eq(w1.view().equipped, nil, "unequipped")
		t.eq(#w1.view().plates, 0, "and removed")
	end

	-- A failure at every store call of a purchase, then recovery. With
	-- `late`, someone else buys after the claim has run out, before the
	-- first buyer's session recovers.
	local probe, _, probeRegistry = world()
	local pw = newWallet(probe, 1)
	probe.ops = 0
	probeRegistry().buy(pw, 1, KEY, PRICE)
	local buySteps = probe.ops
	t.ok(buySteps >= 4, `a purchase is {buySteps} store calls`)
	for at = 1, buySteps do
		for _, mode in MODES do
			for _, late in { false, true } do
				local label = `buy, {mode} at call {at}{if late then ", then another buyer" else ""}`
				local store, clock, registry = world()
				local reg = registry()
				local w1, w2 = newWallet(store, 1), newWallet(store, 2)
				failAt(store, mode, at)
				reg.buy(w1, 1, KEY, PRICE)
				store.hook = nil
				if string.sub(mode, 1, 5) == "crash" then
					w1.reload()
					reg = registry()
				end
				if late then
					clock.now += PlateConfig.pendingSeconds + 1
					registry().buy(w2, 2, KEY, PRICE)
				end
				reg.recover(w1, 1)
				check(t, label, store, { w1, w2 }, START - PRICE, START)
				-- What was written must settle the same way.
				w1.reload()
				registry().recover(w1, 1)
				check(t, label .. " (reloaded)", store, { w1, w2 }, START - PRICE, START)
			end
		end
	end

	-- A failure at every store call of a release, then recovery.
	local function ownedWorld(): (any, () -> any, TestWallet)
		local store, _, registry = world()
		local w1 = newWallet(store, 1)
		registry().buy(w1, 1, KEY, PRICE)
		return store, registry, w1
	end
	local rs, rreg, rw = ownedWorld()
	rs.ops = 0
	t.eq(rreg().release(rw, 1, KEY, REFUND), "done", "clean release")
	local releaseSteps = rs.ops
	check(t, "clean release", rs, { rw }, START - PRICE, START - PRICE + REFUND)
	t.eq(rs.data[KEY].status, "free", "released plate is free")
	for at = 1, releaseSteps do
		for _, mode in MODES do
			local label = `release, {mode} at call {at}`
			local store, registry, w1 = ownedWorld()
			local reg = registry()
			failAt(store, mode, at)
			reg.release(w1, 1, KEY, REFUND)
			store.hook = nil
			if string.sub(mode, 1, 5) == "crash" then
				w1.reload()
				reg = registry()
			end
			reg.recover(w1, 1)
			check(t, label, store, { w1 }, START - PRICE, START - PRICE + REFUND)
			w1.reload()
			registry().recover(w1, 1)
			check(t, label .. " (reloaded)", store, { w1 }, START - PRICE, START - PRICE + REFUND)
		end
	end
end
