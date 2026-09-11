--!strict
-- Mesh assets referenced by id, and the one way they are allowed to load.
--
-- MeshPart.MeshId is not writable from a script, so the only runtime routes
-- to a mesh are AssetService:CreateMeshPartAsync or a SpecialMesh. This uses
-- CreateMeshPartAsync. The builder makes its own MeshPart from the bare mesh
-- id, so the Creator Store model the id came from never enters the game and
-- whatever scripts it carried never ship.
--
-- A prop is a list of pieces (a date palm is a trunk mesh and a crown mesh)
-- with sizes in metres and an offset for each piece from the prop's base, so
-- swapping an id does not move anything.
--
-- Vetting: no scripts shipped (structural, see above), no real-world brand,
-- low poly by eye in the viewport. Roblox exposes no triangle count to Lua,
-- and EditableMesh refuses assets the place owner did not upload, so the
-- sub-3,000 check has to be made in Studio's Asset Manager.
local AssetService = game:GetService("AssetService")

local AssetRegistry = {}

export type Piece = {
	meshId: number,
	textureId: number, -- 0 for none; the piece is then coloured
	sizeM: Vector3, -- metres, at scale 1
	offsetM: Vector3, -- centre of the piece from the prop base, metres
	color: Color3?, -- applied when there is no texture
	material: Enum.Material?,
}

export type Prop = {
	name: string,
	creator: string,
	notes: string,
	pieces: { Piece },
}

-- Palm pack by RewqNeveraH (store 136594315861568). Textured trunk and a real
-- date-palm crown. The two together are the signature tree of the map.
local DATE_PALM: Prop = {
	name = "Date palm, textured",
	creator = "RewqNeveraH",
	notes = "Trunk 1242062543 + crown 1242062493, textures from the same pack.",
	pieces = {
		{ meshId = 1242062543, textureId = 1242063083, sizeM = Vector3.new(0.9, 11.7, 0.95), offsetM = Vector3.new(0, 5.85, 0) },
		{ meshId = 1242062493, textureId = 1242063026, sizeM = Vector3.new(6.6, 7.1, 6.7), offsetM = Vector3.new(0, 11.7 - 1.1 + 3.55, 0) },
	},
}

-- Untextured pair that appears in two separate packs. Slimmer and taller,
-- coloured here. Used as the second variety so a row is never one tree.
local FAN_PALM: Prop = {
	name = "Palm, untextured, coloured",
	creator = "unknown, shared across packs",
	notes = "Trunk 3397171347 + crown 3397175421.",
	pieces = {
		{ meshId = 3397171347, textureId = 0, sizeM = Vector3.new(0.7, 15.8, 0.78), offsetM = Vector3.new(0, 7.9, 0), color = Color3.fromRGB(96, 78, 58), material = Enum.Material.Wood },
		{ meshId = 3397175421, textureId = 0, sizeM = Vector3.new(4.4, 4.7, 4.4), offsetM = Vector3.new(0, 15.8 - 0.9 + 2.35, 0), color = Color3.fromRGB(58, 84, 46), material = Enum.Material.Grass },
	},
}

local ROCK_A: Prop = {
	name = "Desert boulder",
	creator = "Rock3t047Prism9078 (store 137743275162571)",
	notes = "Textured low poly boulder.",
	pieces = { { meshId = 4991467397, textureId = 4857011580, sizeM = Vector3.new(2, 1.05, 1.95), offsetM = Vector3.new(0, 0.45, 0) } },
}
local ROCK_B: Prop = {
	name = "Desert boulder, small",
	creator = "same pack",
	notes = "",
	pieces = { { meshId = 4991467831, textureId = 4857011580, sizeM = Vector3.new(1.35, 0.7, 1.3), offsetM = Vector3.new(0, 0.3, 0) } },
}

-- Single untextured low poly bush (store 82802741090640, LuckyFire4868),
-- coloured down to desert scrub.
local SCRUB: Prop = {
	name = "Desert scrub",
	creator = "LuckyFire4868",
	notes = "Mesh 7191451797, one piece, coloured.",
	pieces = { { meshId = 7191451797, textureId = 0, sizeM = Vector3.new(2.6, 1.2, 2), offsetM = Vector3.new(0, 0.55, 0), color = Color3.fromRGB(80, 90, 58), material = Enum.Material.Grass } },
}

AssetRegistry.props = {
	scrub = SCRUB,
	datePalm = DATE_PALM,
	fanPalm = FAN_PALM,
	rockA = ROCK_A,
	rockB = ROCK_B,
} :: { [string]: Prop }

-- Skyboxes. A Sky is six textures and nothing else, so there is nothing to
-- sandbox; the check is brand and content. Ids live in WorldConfig with the
-- time of day that uses them; this is the provenance.
AssetRegistry.skyboxes = {
	hdSunset = "store 5133032250 'HD Sunset Skybox' by PeZsmistic: a photographed sunset, 500 stars, no sun disc. Used by goldenHour.",
	rejectedVexiad = "store 407719830: older, lower resolution, not tried in the viewport.",
}

-- Candidates looked at and rejected, so nobody searches for them twice.
AssetRegistry.rejected = {
	"1436325105, 10354687850, 3097584763, 18363394399: script-free but cartoon coconut palms, bright green, wrong tree for Riyadh",
	"76007165574946, 79982036713249: Philips-branded lamp housings, real-world brand",
	"87617624889799: six spam scripts and only a bare trunk mesh",
}

-- Cache of loaded template MeshParts per mesh id. CreateMeshPartAsync yields
-- and hits the network, so it runs once per id and everything after is a
-- Clone, which is what makes planting three hundred palms at server start
-- affordable.
local templates: { [number]: MeshPart? } = {}
local failed: { [number]: boolean } = {}

local function template(meshId: number): MeshPart?
	if templates[meshId] then
		return templates[meshId]
	end
	if failed[meshId] then
		return nil
	end
	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromAssetId(meshId), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Automatic,
		})
	end)
	if not ok or not result then
		warn(`[World] mesh {meshId} failed to load: {tostring(result)}; using the primitive stand-in`)
		failed[meshId] = true
		return nil
	end
	templates[meshId] = result
	return result
end

-- Preloads every mesh in the registry. Called once before planting so the
-- yields happen up front rather than in the middle of a scatter loop.
function AssetRegistry.preload(): number
	local n = 0
	for _, prop in AssetRegistry.props do
		for _, piece in prop.pieces do
			if template(piece.meshId) then
				n += 1
			end
		end
	end
	return n
end

function AssetRegistry.hasProp(key: string): boolean
	local prop = AssetRegistry.props[key]
	if not prop then
		return false
	end
	for _, piece in prop.pieces do
		if not template(piece.meshId) then
			return false
		end
	end
	return true
end

-- Builds the prop at a base CFrame (its feet), scaled, with every piece an
-- inert scenery part. Returns nil if any piece failed to load, so the caller
-- can fall back to its primitive.
function AssetRegistry.place(key: string, base: CFrame, scale: number, mps: number, parent: Instance, castShadow: boolean): Model?
	local prop = AssetRegistry.props[key]
	if not prop or not AssetRegistry.hasProp(key) then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = key
	for _, piece in prop.pieces do
		local t = template(piece.meshId) :: MeshPart
		local m = t:Clone()
		m.Name = key
		m.Anchored = true
		m.CanCollide = false
		m.CanQuery = false
		m.CanTouch = false
		m.CastShadow = castShadow
		m.Size = piece.sizeM * scale / mps
		if piece.textureId > 0 then
			m.TextureID = `rbxassetid://{piece.textureId}`
		else
			m.TextureID = ""
			m.Color = piece.color or Color3.fromRGB(120, 110, 100)
			m.Material = piece.material or Enum.Material.Plastic
		end
		m.CFrame = base * CFrame.new(piece.offsetM * scale / mps)
		m.Parent = model
	end
	model.Parent = parent
	return model
end

return AssetRegistry
