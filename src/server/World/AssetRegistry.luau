--!strict
-- Mesh assets referenced by id, with the metadata each one was vetted on.
--
-- Nothing here is inserted into the place. The builders read this table at
-- runtime and create MeshParts from the ids. An entry with id = 0 has no
-- approved mesh yet and the builder falls back to its primitive stand-in, so
-- the whole world is buildable and testable before a single mesh is picked.
--
-- Vetting bar, per the build brief: under 3,000 triangles, zero scripts, a
-- creator with a real upload history, and nothing modelling or named after a
-- real-world brand. Fill in triangles/scripts/creator when an id is approved
-- so the numbers travel with the asset.
local AssetRegistry = {}

export type Entry = {
	id: number, -- rbxassetid, 0 means none approved yet
	name: string,
	creator: string,
	triangles: number,
	scripts: number,
	-- Metres the mesh should end up, so a swap does not change the layout.
	targetHeightM: number,
	notes: string,
}

local function pending(name: string, targetHeightM: number, notes: string): Entry
	return { id = 0, name = name, creator = "", triangles = 0, scripts = 0, targetHeightM = targetHeightM, notes = notes }
end

-- Candidates found on the Creator Store and awaiting a pick. Every source
-- model carried spam scripts ("CoreValidation", "CoreTextureSystem"), which
-- is normal for free store models and does not matter here: the builder takes
-- the MeshId and builds its OWN MeshPart, so nothing executable ever ships.
-- Roblox does not expose triangle counts to Lua, so the sub-3,000 check has
-- to be made in Studio.
AssetRegistry.candidates = {
	datePalm = {
		{ meshId = 1242062543, texture = 1242063083, note = "Palm Tree Pack trunk, slim, 3.3 x 41.8 studs" },
		{ meshId = 1242062493, texture = 1242063026, note = "matching frond crown, 23.7 x 25.3 studs" },
		{ meshId = 3397171347, texture = 0, note = "untextured trunk, appears in two separate packs" },
		{ meshId = 3397175421, texture = 0, note = "matching untextured crown" },
	},
	desertRock = {
		{ meshId = 4991467397, texture = 4857011580, note = "low poly boulder, 7.1 x 3.7 x 6.9 studs" },
		{ meshId = 4991467831, texture = 4857011580, note = "smaller sibling, 4.8 x 2.5 x 4.7 studs" },
	},
}

AssetRegistry.entries = {
	datePalm = pending("Date palm", 7.5, "Primitive stand-in: box trunk plus angled frond boxes."),
	datePalmShort = pending("Date palm, short", 4.5, "Variety for clumps. Same stand-in, scaled."),
	desertRock = pending("Desert rock", 1.6, "Primitive stand-in: a rotated box."),
	lampHead = pending("Lamp housing", 0.75, "Primitive stand-in: a box. Only swap if the box reads wrong."),
	roadsideSignPost = pending("Sign post", 2.2, "Primitive stand-in: a thin box."),
} :: { [string]: Entry }

function AssetRegistry.get(key: string): Entry?
	return AssetRegistry.entries[key]
end

-- True when an approved mesh exists for this key; false means build the
-- primitive stand-in instead.
function AssetRegistry.hasMesh(key: string): boolean
	local entry = AssetRegistry.entries[key]
	return entry ~= nil and entry.id > 0
end

-- Creates a MeshPart for an approved asset, or nil when there is none. The
-- caller owns parenting and placement.
function AssetRegistry.createMesh(key: string): MeshPart?
	local entry = AssetRegistry.entries[key]
	if not entry or entry.id <= 0 then
		return nil
	end
	local ok, mesh = pcall(function()
		local m = Instance.new("MeshPart")
		m.MeshId = `rbxassetid://{entry.id}`
		return m
	end)
	if not ok then
		return nil
	end
	return mesh
end

return AssetRegistry
