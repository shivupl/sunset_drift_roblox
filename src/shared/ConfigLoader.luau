--!strict
-- Holds the live CarConfig and reloads it by cloning the ModuleScript.
-- require() caches per instance, so requiring a fresh clone re-runs the
-- module's current Source. Works on client and server.
local Shared = script.Parent
local CarConfig = require(Shared.CarConfig)

export type Config = CarConfig.Config

local ConfigLoader = {}
local current: Config = CarConfig

function ConfigLoader.current(): Config
	return current
end

-- Returns the (possibly unchanged) config and an error string if reload failed.
function ConfigLoader.reload(): (Config, string?)
	local module = Shared:FindFirstChild("CarConfig")
	if not module or not module:IsA("ModuleScript") then
		return current, "CarConfig module missing"
	end
	local clone = module:Clone()
	clone.Parent = Shared
	local ok, result = pcall(require :: any, clone)
	clone:Destroy()
	if ok and typeof(result) == "table" then
		current = result :: Config
		return current, nil
	end
	return current, tostring(result)
end

return ConfigLoader
