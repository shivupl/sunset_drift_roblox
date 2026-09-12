--!strict
-- The two MaterialVariants the world is built out of, and the one rule for
-- applying them: every part of a given base material gets the variant, so
-- nothing can be left behind looking like stock Roblox.
--
-- A MaterialVariant's maps cannot be written by a game script -- setting
-- BaseMaterial or a map needs plugin capability, and trying it in a server
-- script throws and takes the whole world build down with it. So the
-- variants are place assets: default.project.json declares them under
-- MaterialService and Rojo puts them in the place. setup() only looks them
-- up. When one is missing it tries to create it anyway, which works from
-- Studio's command bar and the Edit-mode preview but not in a running
-- server, and otherwise warns and leaves the stock material: a part whose
-- MaterialVariant names nothing renders its base material.
local MaterialService = game:GetService("MaterialService")
local WorldConfig = require(script.Parent.WorldConfig)

type Config = WorldConfig.Config

local Materials = {}

export type Spec = {
	name: string,
	base: Enum.Material,
	colorMap: number,
	normalMap: number,
	roughnessMap: number,
	studsPerTile: number,
}

Materials.SAND = "HajwalaSand"
Materials.ASPHALT = "HajwalaAsphalt"

local ready: { [string]: boolean } = {}

local function ensure(spec: Spec): boolean
	if MaterialService:FindFirstChild(spec.name) then
		ready[spec.name] = true
		return true
	end
	local ok, err = pcall(function()
		local mv = Instance.new("MaterialVariant")
		mv.Name = spec.name
		mv.BaseMaterial = spec.base
		mv.ColorMap = `rbxassetid://{spec.colorMap}`
		if spec.normalMap > 0 then
			mv.NormalMap = `rbxassetid://{spec.normalMap}`
		end
		if spec.roughnessMap > 0 then
			mv.RoughnessMap = `rbxassetid://{spec.roughnessMap}`
		end
		mv.StudsPerTile = spec.studsPerTile
		mv.Parent = MaterialService
	end)
	if ok then
		ready[spec.name] = true
		return true
	end
	ready[spec.name] = false
	warn(
		`[World] material variant "{spec.name}" is not in MaterialService and cannot be made here ({err}). `
			.. "It is declared in default.project.json; sync the place with Rojo, or make it once in Studio. Using the stock material."
	)
	return false
end

function Materials.setup(cfg: Config)
	table.clear(ready)
	local sand = cfg.ground.sand
	if sand.enabled then
		ensure({
			name = Materials.SAND,
			base = Enum.Material.Sand,
			colorMap = sand.colorMap,
			normalMap = sand.normalMap,
			-- The set's roughness map reads as glossy in Roblox and gave the
			-- desert a wet sheen with specular glints on every crest toward
			-- the sun. Left out on purpose; sand is matte.
			roughnessMap = sand.roughnessMap,
			studsPerTile = sand.studsPerTile,
		})
	end
	local asphalt = cfg.road.asphalt
	if asphalt.enabled then
		ensure({
			name = Materials.ASPHALT,
			base = Enum.Material.Asphalt,
			colorMap = asphalt.colorMap,
			normalMap = asphalt.normalMap,
			roughnessMap = 0,
			studsPerTile = asphalt.studsPerTile,
		})
	end
end

-- Stamps both variants across everything under root. Returns how many parts
-- of each. Run once after the build, so no builder has to remember.
function Materials.apply(root: Instance): (number, number)
	local sand, asphalt = 0, 0
	local sandOn, asphaltOn = ready[Materials.SAND], ready[Materials.ASPHALT]
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			if sandOn and d.Material == Enum.Material.Sand then
				d.MaterialVariant = Materials.SAND
				sand += 1
			elseif asphaltOn and d.Material == Enum.Material.Asphalt then
				d.MaterialVariant = Materials.ASPHALT
				asphalt += 1
			end
		end
	end
	return sand, asphalt
end

return Materials
