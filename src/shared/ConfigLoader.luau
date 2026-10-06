--!strict
-- Holds the live CarConfig, CarCatalog and DriftStyles and reloads them by
-- cloning the ModuleScripts (the drift styles too, so a style's numbers can
-- be tried live with L, 2026-10-05). require() caches per instance, so requiring a fresh clone
-- re-runs the module's current Source. Works on client and server.
--
-- A car never drives on CarConfig directly: forCar() hands out the shared
-- handling merged with that car's rig and tuning (VehicleRig.configFor),
-- built once per car per reload.
local Shared = script.Parent
local CarConfig = require(Shared.CarConfig)
local CarCatalog = require(Shared.CarCatalog)
local VehicleRig = require(Shared.VehicleRig)
local DriftStyles = require(Shared.DriftStyles)

export type Config = CarConfig.Config
export type Catalog = typeof(CarCatalog)
export type Styles = typeof(DriftStyles)

local ConfigLoader = {}
local current: Config = CarConfig
local catalog: Catalog = CarCatalog
local styles: Styles = DriftStyles
local perCar: { [string]: Config } = {}

function ConfigLoader.current(): Config
	return current
end

function ConfigLoader.catalog(): Catalog
	return catalog
end

-- The live drift styles (DriftStyles; the client's DriftStyle applies them).
function ConfigLoader.driftStyles(): Styles
	return styles
end

-- The id that actually builds: the requested one if the catalog has it,
-- otherwise the catalog's default.
function ConfigLoader.resolveCarId(carId: string?): string
	if carId and catalog.cars[carId] then
		return carId
	end
	return catalog.defaultCarId
end

function ConfigLoader.entry(carId: string?): VehicleRig.CarEntry
	return catalog.cars[ConfigLoader.resolveCarId(carId)]
end

-- The config a given car drives on.
function ConfigLoader.forCar(carId: string?): Config
	local id = ConfigLoader.resolveCarId(carId)
	local cfg = perCar[id]
	if not cfg then
		cfg = VehicleRig.configFor(current, catalog.cars[id])
		perCar[id] = cfg
	end
	return cfg
end

local function fresh(name: string): (boolean, any)
	local module = Shared:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then
		return false, `{name} module missing`
	end
	local clone = module:Clone()
	clone.Parent = Shared
	local ok, result = pcall(require :: any, clone)
	clone:Destroy()
	if ok and typeof(result) == "table" then
		return true, result
	end
	return false, tostring(result)
end

-- Returns the (possibly unchanged) config and an error string if reload failed.
function ConfigLoader.reload(): (Config, string?)
	local okConfig, configResult = fresh("CarConfig")
	local okCatalog, catalogResult = fresh("CarCatalog")
	local okStyles, stylesResult = fresh("DriftStyles")
	if okStyles then
		styles = stylesResult :: Styles
	end
	if okConfig then
		current = configResult :: Config
	end
	if okCatalog then
		catalog = catalogResult :: Catalog
	end
	table.clear(perCar)
	if not okConfig then
		return current, configResult :: string
	end
	if not okCatalog then
		return current, catalogResult :: string
	end
	if not okStyles then
		return current, stylesResult :: string
	end
	return current, nil
end

return ConfigLoader
