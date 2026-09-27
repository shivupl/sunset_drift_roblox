--!strict
-- An in-memory DataStore for the plate tests, and for Studio when this
-- place's API access to DataStores is off (spec §6). Only ever chosen in
-- Studio (Stores.open); a live server never falls back to it.
--
-- It behaves like the real store where the registry depends on it: values
-- are copied in and out (the real store round-trips JSON), and UpdateAsync
-- runs the transform again when the key changed between its read and its
-- write. Tests steer it with two hooks:
--   hook(op, key, phase)  called before and after every call. Erroring in
--                         it fails the call; after "after", the write has
--                         landed but the caller still sees an error, as the
--                         real store can do.
--   beforeCommit(key)     called inside every UpdateAsync, after its
--                         transform and before its write. A test runs a
--                         second server's write here to race this one, and
--                         clears the hook itself first.
local FakeDataStore = {}

export type Phase = "before" | "after"
export type Fake = {
	data: { [string]: any },
	userIds: { [string]: { number } },
	ops: number, -- calls started so far
	hook: ((op: string, key: string, phase: Phase) -> ())?,
	beforeCommit: ((key: string) -> ())?,
	GetAsync: (self: Fake, key: string, options: any?) -> any,
	UpdateAsync: (self: Fake, key: string, transform: (old: any, info: any) -> (any, { number }?)) -> any,
}

local function copy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = copy(x)
	end
	return out
end
FakeDataStore.copy = copy

function FakeDataStore.new(): Fake
	local self: any = { data = {}, userIds = {}, ops = 0 }

	function self.GetAsync(_: any, key: string, _options: any?): any
		self.ops += 1
		local hook = self.hook
		if hook then
			hook("get", key, "before")
		end
		local value = copy(self.data[key])
		if hook then
			hook("get", key, "after")
		end
		return value
	end

	function self.UpdateAsync(_: any, key: string, transform: (old: any, info: any) -> (any, { number }?)): any
		self.ops += 1
		local hook = self.hook
		if hook then
			hook("update", key, "before")
		end
		for _ = 1, 8 do
			local seen = self.data[key]
			local new, ids = transform(copy(seen), nil)
			local race = self.beforeCommit
			if race then
				race(key)
			end
			if self.data[key] == seen then
				if new ~= nil then
					self.data[key] = copy(new)
					if ids then
						self.userIds[key] = table.clone(ids)
					end
				end
				if hook then
					hook("update", key, "after")
				end
				return copy(new)
			end
			-- Another write landed in between: run the transform again on
			-- the new value, as the real store does.
		end
		error("FakeDataStore: UpdateAsync kept losing the race")
	end

	return self :: Fake
end

return FakeDataStore
