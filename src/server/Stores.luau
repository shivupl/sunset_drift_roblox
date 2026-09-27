--!strict
-- Opens a DataStore. In Studio with this place's API access to DataStores
-- off (File > Game Settings > Security), an in-memory fake instead, for the
-- session (spec §6). A live server never gets the fake: with no DataStore
-- it gets nil, and the callers say so (no saving; plate shop unavailable).
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local FakeDataStore = require(script.Parent.FakeDataStore)

export type Kind = "live" | "fake" | "none"

local Stores = {}

local fakes: { [string]: FakeDataStore.Fake } = {}

function Stores.open(name: string): (any, Kind)
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	if RunService:IsStudio() then
		-- GetDataStore succeeds in Studio even without access; the first read fails.
		local reachable = ok and pcall(function()
			return (store :: DataStore):GetAsync("__studio_probe")
		end)
		if not reachable then
			local fake = fakes[name] or FakeDataStore.new()
			fakes[name] = fake
			warn(`[Hajwala] Studio has no DataStore access: "{name}" is an in-memory fake for this session`)
			return fake, "fake"
		end
	end
	if not ok then
		warn(`[Hajwala] no DataStore "{name}": {tostring(store)}`)
		return nil, "none"
	end
	return store, "live"
end

return Stores
