--!strict
-- The sand material. One MaterialVariant on Roblox's Sand from a CC0 PBR set
-- (colour and normal maps), stamped on every Sand part in the world after
-- the build so the ground, the dunes, the berm and the drifts are one
-- material.
--
-- A MaterialVariant's maps cannot be written by a game script (they need
-- plugin capability), so the variant is a place asset: default.project.json
-- declares it under MaterialService and Rojo puts it in the place. setup()
-- only looks it up. When it is missing it tries to create it, which works
-- in Studio's command bar and the Edit-mode preview but not in a running
-- server, and otherwise warns and leaves Roblox's own sand in place: a part
-- whose MaterialVariant names nothing renders its base material.
local MaterialService = game:GetService("MaterialService")
local WorldConfig = require(script.Parent.WorldConfig)

type Config = WorldConfig.Config

local Sand = {}

Sand.VARIANT = "HajwalaSand"

local available = false

function Sand.setup(cfg: Config): boolean
	local s = cfg.ground.sand
	available = false
	if not s.enabled then
		return false
	end
	if MaterialService:FindFirstChild(Sand.VARIANT) then
		available = true
		return true
	end
	local ok, err = pcall(function()
		local mv = Instance.new("MaterialVariant")
		mv.Name = Sand.VARIANT
		mv.BaseMaterial = Enum.Material.Sand
		mv.ColorMap = `rbxassetid://{s.colorMap}`
		mv.NormalMap = `rbxassetid://{s.normalMap}`
		if s.roughnessMap > 0 then
			mv.RoughnessMap = `rbxassetid://{s.roughnessMap}`
		end
		mv.StudsPerTile = s.studsPerTile
		mv.Parent = MaterialService
	end)
	if ok then
		available = true
		return true
	end
	warn(
		`[World] sand variant "{Sand.VARIANT}" is not in MaterialService and cannot be made here ({err}). `
			.. "It is declared in default.project.json; sync the place with Rojo, or create it once in Studio. Using Roblox's sand."
	)
	return false
end

-- Every Sand part under root takes the variant. Returns how many.
function Sand.apply(cfg: Config, root: Instance): number
	if not available then
		return 0
	end
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Sand then
			d.MaterialVariant = Sand.VARIANT
			n += 1
		end
	end
	return n
end

return Sand
