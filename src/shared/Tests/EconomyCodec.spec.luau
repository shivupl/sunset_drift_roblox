--!strict
-- Economy's profile read and write (garage round 2 §4, 2026-09-28: the owner
-- asked to "continue to create tests"). Economy is server code: its pure
-- halves are exposed as Economy.codec and driven here against FakeDataStore,
-- which copies values in and out as the real store's JSON round trip does.
-- setLook is driven through a stand-in player with no store (Economy.load
-- then gives a fresh, unsavable profile, and nothing is written).
--
-- What must hold:
--   * a write merges the RAW stored cosmetic ids, so a server that does not
--     know an item another one sold never un-owns it (task 2 review);
--   * a stored look for a car this catalog lacks is written back exactly;
--   * a car's look set back to stock is cleared, and an all-stock look is
--     dropped rather than stored empty;
--   * the tint slot (garage round 2 §4) saves and loads like the others.
-- The modules are server modules, cloned into a detached folder so each run
-- gets fresh code and Economy's script.Parent siblings resolve.
local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")
local Tests = require(script.Parent)
type T = Tests.T

local lab = Instance.new("Folder")
lab.Name = "EconomyCodecLab"
for _, name in { "Economy", "PlateRegistry", "Stores", "FakeDataStore" } do
	Server:WaitForChild(name):Clone().Parent = lab
end
local Economy = (require :: any)(lab:WaitForChild("Economy"))
local FakeDataStore = (require :: any)(lab:WaitForChild("FakeDataStore"))
local codec = Economy.codec

local KEY = "p_1"

-- A car this version's catalog does not have, and an item id it does not
-- know: what a newer server could have stored.
local FUTURE_CAR = "future_car_x"
local FUTURE_ITEM = "paint_future_x"

-- One save the way Economy.save does it: UpdateAsync with encode.
local function save(fake: any, p: any)
	fake:UpdateAsync(KEY, function(old: any)
		return codec.encode(p, old)
	end)
end

local function has(list: { string }, id: string): boolean
	return table.find(list, id) ~= nil
end

local function count(list: { string }, id: string): number
	local n = 0
	for _, x in list do
		if x == id then
			n += 1
		end
	end
	return n
end

-- A stand-in Player for setLook: Economy only reads Parent and UserId and
-- writes attributes on it.
local function standIn(): any
	local attrs: { [string]: any } = {}
	return {
		Name = "CodecSpec",
		UserId = -4242,
		Parent = true,
		attrs = attrs,
		SetAttribute = function(_: any, k: string, v: any)
			attrs[k] = v
		end,
		GetAttribute = function(_: any, k: string): any
			return attrs[k]
		end,
	}
end

return function(t: T)
	-- Reading: nothing stored, or junk, is a fresh profile.
	local empty = codec.readProfile(nil)
	t.eq(empty.cash, 0, "no profile reads as zero cash")
	t.eq(#empty.cosmetics, 0, "no profile owns nothing")
	t.eq(next(empty.looks), nil, "no profile has no looks")
	t.eq(codec.readProfile("junk").cash, 0, "a non-table profile reads as fresh")

	-- Reading drops stock ids, unknown ids and repeats from what is owned.
	local read = codec.readProfile({
		cash = 5000,
		cosmetics = { "paint_pearl", "paint_stock", FUTURE_ITEM, "paint_pearl", 42 :: any, "tint_dark" },
	})
	t.eq(#read.cosmetics, 2, "read keeps only known, bought, distinct ids")
	t.ok(has(read.cosmetics, "paint_pearl") and has(read.cosmetics, "tint_dark"), "read keeps paint_pearl and tint_dark")
	t.ok(not has(read.cosmetics, FUTURE_ITEM), "read drops an id this catalog does not know")

	-- Reading looks: owned ids kept, unowned dropped, an all-stock look and a
	-- look left empty by cleaning are dropped, the tint slot kept.
	local looks = codec.readProfile({
		cosmetics = { "paint_pearl", "tint_limo" },
		looks = {
			lekzas = { paint = "paint_pearl", tint = "tint_limo", rims = "rims_gold" },
			kamri07 = { paint = "paint_stock", tint = "tint_stock" },
			kruzer80 = { paint = "paint_red" },
			[FUTURE_CAR] = { paint = "paint_pearl" },
		},
	}).looks
	local lek = looks.lekzas
	t.ok(lek ~= nil, "lekzas look read")
	if lek then
		t.eq(lek.paint, "paint_pearl", "owned paint kept")
		t.eq(lek.tint, "tint_limo", "owned tint kept")
		t.eq(lek.rims, nil, "unowned rims dropped")
	end
	-- An all-stock look cleans to stock ids only; it is still an entry, but
	-- carries nothing a car would show differently.
	local k07 = looks.kamri07
	t.ok(k07 == nil or (k07.paint == "paint_stock" and k07.tint == "tint_stock"), "an all-stock look reads as stock")
	t.eq(looks.kruzer80, nil, "a look with nothing owned is dropped")
	t.ok(looks[FUTURE_CAR] ~= nil, "a look for a car this catalog lacks is read")

	-- Writing: the raw stored cosmetic ids are merged, unknown ones included.
	local fake = FakeDataStore.new()
	fake.data[KEY] = { cash = 100, bestScore = 900, cosmetics = { FUTURE_ITEM, "paint_pearl" } }
	local p = codec.readProfile(FakeDataStore.copy(fake.data[KEY]))
	t.ok(not has(p.cosmetics, FUTURE_ITEM), "this server's profile does not list the unknown id")
	table.insert(p.cosmetics, "tint_light") -- bought this session
	p.bestScore = 500 -- lower than stored
	save(fake, p)
	local stored = fake.data[KEY]
	t.ok(has(stored.cosmetics, FUTURE_ITEM), "a write keeps an id another server sold")
	t.ok(has(stored.cosmetics, "tint_light"), "a write keeps this session's purchase")
	t.eq(count(stored.cosmetics, "paint_pearl"), 1, "a write does not repeat an id in both lists")
	t.eq(stored.bestScore, 900, "a write keeps the higher stored best")

	-- Writing: a stored look for an unknown car goes back exactly as stored,
	-- unknown ids and all; a known car's look comes from this session.
	fake.data[KEY] = {
		cosmetics = { "paint_pearl", "tint_dark" },
		looks = {
			[FUTURE_CAR] = { paint = FUTURE_ITEM, tint = "tint_dark" },
			lekzas = { paint = "paint_pearl", tint = "tint_dark" },
		},
	}
	local q = codec.readProfile(FakeDataStore.copy(fake.data[KEY]))
	-- The player sets the lekzas back to factory this session.
	q.looks.lekzas = nil
	save(fake, q)
	local future = fake.data[KEY].looks[FUTURE_CAR]
	t.ok(future ~= nil, "an unknown car's look is written back")
	if future then
		t.eq(future.paint, FUTURE_ITEM, "an unknown car's look keeps an id this server does not know")
		t.eq(future.tint, "tint_dark", "an unknown car's look keeps its tint")
	end
	t.eq(fake.data[KEY].looks.lekzas, nil, "a known car cleared this session is not written back from the stored copy")

	-- A round trip through the store keeps a tint look.
	local r = codec.fresh()
	r.cosmetics = { "tint_limo", "paint_teal" }
	r.looks.kamri07 = { tint = "tint_limo", paint = "paint_teal" }
	fake.data[KEY] = nil
	save(fake, r)
	local back = codec.readProfile(FakeDataStore.copy(fake.data[KEY]))
	local k = back.looks.kamri07
	t.ok(k ~= nil and k.tint == "tint_limo" and k.paint == "paint_teal", "a tint look survives a save and a load")

	-- setLook: stock clears a slot, an all-stock look is dropped, a wrong
	-- category or an unowned id is refused, tint is a slot.
	local player = standIn()
	Economy.load(player)
	local prof = Economy.profile(player)
	t.ok(prof ~= nil, "a stand-in player gets a profile with no store")
	if prof then
		table.insert(prof.cosmetics, "tint_dark")
		table.insert(prof.cosmetics, "paint_red")
		t.ok(Economy.setLook(player, "lekzas", "tint", "tint_dark"), "setLook takes an owned tint")
		t.ok(Economy.setLook(player, "lekzas", "paint", "paint_red"), "setLook takes an owned paint")
		t.eq(Economy.look(player, "lekzas").tint, "tint_dark", "the tint is on the look")
		t.ok(not Economy.setLook(player, "lekzas", "tint", "tint_limo"), "setLook refuses an unowned tint")
		t.ok(not Economy.setLook(player, "lekzas", "tint", "paint_red"), "setLook refuses a paint in the tint slot")
		t.ok(Economy.setLook(player, "lekzas", "tint", "tint_stock"), "setLook takes the stock tint")
		t.eq(Economy.look(player, "lekzas").tint, nil, "stock clears the slot")
		t.ok(Economy.setLook(player, "lekzas", "paint", nil), "setLook takes nil")
		t.eq(prof.looks.lekzas, nil, "an all-factory look is dropped, not stored empty")
		t.ok(player.attrs.Looks == "[]" or player.attrs.Looks == "{}", "the published looks are empty")
	end
	Economy.release(player)
	t.eq(Economy.profile(player), nil, "release forgets the stand-in")
	lab:Destroy()
end
