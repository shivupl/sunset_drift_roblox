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

-- Roadside camp tent (store 111251373766912, AidenSilverByte2871): one
-- textured mesh. A canvas camp tent rather than a woven bedouin one; the
-- store had no bedouin tent that was not a locker room or a pirate hut.
local TENT: Prop = {
	name = "Camp tent",
	creator = "AidenSilverByte2871",
	notes = "Mesh 109174258219103, texture 102982560673097. Sized 4.9 x 2.4 x 4.2 m.",
	pieces = { { meshId = 109174258219103, textureId = 102982560673097, sizeM = Vector3.new(4.9, 2.4, 4.2), offsetM = Vector3.new(0, 1.2, 0) } },
}

-- Camel (store 12252661019 "Realistic Camel Mesh", ZeeeeeeeeeeMx): one
-- textured mesh, no scripts, no rig. The mesh's long axis is X.
local CAMEL: Prop = {
	name = "Camel",
	creator = "ZeeeeeeeeeeMx",
	notes = "Mesh 12206932216, texture 12206913055. Sized 3.4 x 2.7 x 1.0 m.",
	pieces = { { meshId = 12206932216, textureId = 12206913055, sizeM = Vector3.new(3.4, 2.7, 1.0), offsetM = Vector3.new(0, 1.35, 0) } },
}

-- City street furniture. All checked in Studio: mesh pieces only, scripts
-- in the source models never ship (see the header), no brands.

-- Street lamp 6 from ItsLassie's "Low Poly Street Lamp Pack (Recolorable)"
-- (store 13352449389, ~600 triangles for the whole lamp per the listing).
-- The pack is modelled at ten times life size; 0.16 makes a 9 m post. The
-- pack's "Accent" piece is an ornamental base the size of a house and is
-- left out. Offsets are from the foot of the pole at scale 1.
local STREET_LAMP: Prop = {
	name = "Street lamp, bracket arm",
	creator = "ItsLassie",
	notes = "Pole 13352449304, bracket 13352449299, head 13352449302. Head last so the light manager can find it.",
	pieces = {
		{ meshId = 13352449304, textureId = 0, sizeM = Vector3.new(3.85, 41.33, 3.85), offsetM = Vector3.new(0, 20.67, 0), color = Color3.fromRGB(64, 66, 70), material = Enum.Material.Metal },
		{ meshId = 13352449299, textureId = 0, sizeM = Vector3.new(1.72, 17.2, 12.98), offsetM = Vector3.new(0, 51.53, 5.74), color = Color3.fromRGB(64, 66, 70), material = Enum.Material.Metal },
		{ meshId = 13352449302, textureId = 0, sizeM = Vector3.new(9.46, 1.18, 7.89), offsetM = Vector3.new(0, 49.98, 11.49), color = Color3.fromRGB(58, 58, 62), material = Enum.Material.Metal },
	},
}

-- Park bench (store 111011567981764, H0ll0wa1Spark1): seat and frame
-- meshes, untextured, coloured here. Three scripts in the source model.
local BENCH: Prop = {
	name = "Bench",
	creator = "H0ll0wa1Spark1",
	notes = "Seat 6671752804, frame 6671751459. 2.1 m long.",
	pieces = {
		{ meshId = 6671751459, textureId = 0, sizeM = Vector3.new(1.82, 0.95, 0.67), offsetM = Vector3.new(0, 0.47, 0), color = Color3.fromRGB(50, 52, 56), material = Enum.Material.Metal },
		{ meshId = 6671752804, textureId = 0, sizeM = Vector3.new(2.1, 0.55, 0.63), offsetM = Vector3.new(0, 0.75, 0), color = Color3.fromRGB(120, 90, 60), material = Enum.Material.Wood },
	},
}

-- Street bin (store 80065378719436, Alexander727BlockSto): one textured mesh.
local BIN: Prop = {
	name = "Street bin",
	creator = "Alexander727BlockSto",
	notes = "Mesh 677133470, texture 677133544. 0.5 x 1.0 m.",
	pieces = { { meshId = 677133470, textureId = 677133544, sizeM = Vector3.new(0.5, 1.0, 0.5), offsetM = Vector3.new(0, 0.5, 0) } },
}

-- Split AC outdoor unit (store 107250899765573, XxWillowV3nomxX2016): one
-- plain mesh, coloured. Fan face is the +X side.
local AC_UNIT: Prop = {
	name = "AC unit",
	creator = "XxWillowV3nomxX2016",
	notes = "Mesh 12294174423. 0.3 deep x 0.9 x 1.0 m.",
	pieces = { { meshId = 12294174423, textureId = 0, sizeM = Vector3.new(0.3, 0.9, 1.0), offsetM = Vector3.new(0, 0.45, 0), color = Color3.fromRGB(214, 214, 208), material = Enum.Material.Metal } },
}

-- Parked cars from "Low Poly Cars Pack: Mesh Vehicle Road Race" (store
-- 120535861432410, Ninja131Venom). Two generic bodies used; the pack's
-- Cybertruck and Rimac are real-world brands and are not. Body colour is
-- set by the caller; the wheel mesh is the pack's own.
local CAR_A: Prop = {
	name = "Parked car, saloon",
	creator = "Ninja131Venom",
	notes = "Body 9339167457, 2.8 x 1.9 x 7.3 m in the pack; long axis Z.",
	pieces = {
		{ meshId = 9339167457, textureId = 0, sizeM = Vector3.new(1.85, 1.35, 4.8), offsetM = Vector3.new(0, 0.82, 0), color = Color3.fromRGB(220, 220, 220), material = Enum.Material.SmoothPlastic },
		-- The pack splits each car into body and glass; without the glass
		-- piece the car read as a bathtub.
		{ meshId = 9339166843, textureId = 0, sizeM = Vector3.new(1.85, 1.35, 4.8), offsetM = Vector3.new(0, 0.82, 0), color = Color3.fromRGB(40, 48, 58), material = Enum.Material.Glass },
	},
}
local CAR_B: Prop = {
	name = "Parked car, hatch",
	creator = "Ninja131Venom",
	notes = "Body 9339152185, 3.3 x 1.6 x 7.1 m in the pack; long axis Z.",
	pieces = {
		{ meshId = 9339152185, textureId = 0, sizeM = Vector3.new(1.9, 1.3, 4.4), offsetM = Vector3.new(0, 0.78, 0), color = Color3.fromRGB(200, 200, 200), material = Enum.Material.SmoothPlastic },
		{ meshId = 9339153338, textureId = 0, sizeM = Vector3.new(1.9, 1.3, 4.4), offsetM = Vector3.new(0, 0.78, 0), color = Color3.fromRGB(40, 48, 58), material = Enum.Material.Glass },
	},
}
local WHEEL: Prop = {
	name = "Car wheel",
	creator = "Ninja131Venom",
	notes = "Mesh 9496370049, axis X.",
	pieces = { { meshId = 9496370049, textureId = 0, sizeM = Vector3.new(0.24, 0.56, 0.56), offsetM = Vector3.new(0, 0.28, 0), color = Color3.fromRGB(30, 30, 32), material = Enum.Material.Rubber } },
}

AssetRegistry.props = {
	tent = TENT,
	camel = CAMEL,
	scrub = SCRUB,
	datePalm = DATE_PALM,
	fanPalm = FAN_PALM,
	rockA = ROCK_A,
	rockB = ROCK_B,
	streetLamp = STREET_LAMP,
	bench = BENCH,
	bin = BIN,
	acUnit = AC_UNIT,
	carA = CAR_A,
	carB = CAR_B,
	wheel = WHEEL,
} :: { [string]: Prop }

-- Facade textures: tiled window grids for building walls. Every id here is
-- the IMAGE behind a Creator Store decal, not the decal itself: a decal id
-- in a Texture does not load, and the image id is only reachable from
-- inside Studio (InsertService:LoadAsset on the decal, then read
-- Decal.Texture). All twelve candidates were put on boards in the viewport
-- and looked at; no brands, no text. Tiles cover about three storeys.
AssetRegistry.facades = {
	-- Mid-rise: concrete and render with window rows. Store decal id in
	-- the note, image id in the table.
	midRise = {
		34658495, -- "Building Texture 52" by soraroxas2346, decal 34658496: light concrete
		33968018, -- "Building Texture 42" by soraroxas2346, decal 33968019: grey grid
		6019587856, -- "0034-old-building-texture-seamless" by Dragonfirebro059, decal 6019587863: beige, dark windows
		1020167159, -- "TexturesCom_HighRiseResidential0011_1" by SkyNymph, decal 1020167162
		36805732, -- "Building Texture 75" by soraroxas2346, decal 36805733: warm grey rows
	},
	-- Glass: tower curtain walls.
	glass = {
		15883053882, -- "BUILDING WINDOW" by Daniel_1234567888, decal 15883053903: blue panels
		10607676333, -- "Skyscraper1" by StarDucks Cafe, decal 10607676364: blue-violet grid
		13654404035, -- "tower windows texture" by Redagb, decal 13654404066: teal grid
		1020167485, -- "TexturesCom_HighRiseGlass0104_3" by SkyNymph, decal 1020167489: pale glass
		166325357, -- "Building Texture" by burkerdnff, decal 166325358: dark grid
	},
}

-- Puts a tiled facade on the given faces of a part. tileStuds is the
-- height of one tile; the U scale follows the same figure so the grid
-- stays square. A random offset breaks the repetition between neighbours.
function AssetRegistry.facade(part: BasePart, kind: string, rng: Random, faces: { Enum.NormalId }, tileStuds: number, tint: Color3?, transparency: number?)
	local list = AssetRegistry.facades[kind]
	if not list or #list == 0 then
		return
	end
	local id = list[rng:NextInteger(1, #list)]
	local offU, offV = rng:NextNumber(0, tileStuds), rng:NextNumber(0, tileStuds)
	for _, face in faces do
		local t = Instance.new("Texture")
		t.Name = "Facade"
		t.Texture = `rbxassetid://{id}`
		t.Face = face
		t.StudsPerTileU = tileStuds
		t.StudsPerTileV = tileStuds
		t.OffsetStudsU = offU
		t.OffsetStudsV = offV
		if tint then
			t.Color3 = tint
		end
		t.Transparency = transparency or 0
		t.Parent = part
	end
end

-- Skyboxes. A Sky is six textures and nothing else, so there is nothing to
-- sandbox; the check is brand and content. Ids live in WorldConfig with the
-- time of day that uses them; this is the provenance.
AssetRegistry.skyboxes = {
	hdSunset = "store 5133032250 'HD Sunset Skybox' by PeZsmistic: a photographed sunset, 500 stars, no sun disc. Used by goldenHour.",
	rejectedVexiad = "store 407719830: older, lower resolution, not tried in the viewport.",
}

-- Candidates looked at and rejected, so nobody searches for them twice.
-- Decal textures used on plain parts. A carpet is a thin Part with this on
-- top: no mesh, twelve triangles, and the whole pattern in one image.
AssetRegistry.decals = {
	carpet = 6868651347, -- store 8014263912 "Carpet" by Alpha Center Incorporation, script-free
}

AssetRegistry.rejected = {
	"117065453277405, 82617805024996: titled 'camel', the mesh is a cactus (5073961801)",
	"84580755589494: camel built from 22 plain parts and 3 scripts; 1434176204: 136 plain parts",
	"117652095491156: 'Persian rug' is eight parts and thirteen scripts",
	"1436325105, 10354687850, 3097584763, 18363394399: script-free but cartoon coconut palms, bright green, wrong tree for Riyadh",
	"76007165574946, 79982036713249: Philips-branded lamp housings, real-world brand",
	"87617624889799: six spam scripts and only a bare trunk mesh",
	"89044383946547: traffic light is six plain parts and five scripts; built from boxes instead",
	"123728150857841, 14047515737: satellite dishes are plain-part builds; built from a tilted cylinder instead",
	"120535861432410: the Cybertruck and Rimac in the car pack are real-world brands; only the two generic bodies are used",
	"98926724774714: parked cars named after real models",
}

-- Cache of loaded template MeshParts per mesh id. CreateMeshPartAsync yields
-- and hits the network, so it runs once per id and everything after is a
-- Clone, which is what makes planting three hundred palms at server start
-- affordable.
local templates: { [number]: MeshPart? } = {}
local failed: { [number]: boolean } = {}

local function template(meshId: number): MeshPart?
	if meshId <= 0 then
		return nil
	end
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
