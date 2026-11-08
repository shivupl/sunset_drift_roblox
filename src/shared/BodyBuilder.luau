--!strict
-- Mounts a car's Body onto its built Rig: MeshParts only, every one
-- massless, non-colliding, unqueryable and untouchable, welded to a mount
-- attachment. It adds nothing to the physics: the assembly's mass, centre of
-- mass and collision are exactly the rig's, and the suspension rays already
-- ignore the whole car.
--
-- Runs on each client (CarBodies), never the server: a generated mesh is an
-- EditableMesh, which does not replicate, and a body is visual only, so
-- every client building its own costs the network nothing.
--
-- A piece's mesh is an uploaded asset (meshId, loaded once per id with
-- CreateMeshPartAsync) or generated data (mesh, decoded once by MeshData);
-- the asset wins when a piece has both.
-- A mesh that fails to load gets a plain box of the same size in its place
-- and a warning, so a bad piece shows as a grey block instead of an
-- invisible car.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = script.Parent
local CarConfig = require(Shared.CarConfig)
local VehicleRig = require(Shared.VehicleRig)
local MeshData = require(Shared.MeshData)

type Config = CarConfig.Config
type BodyPiece = VehicleRig.BodyPiece

local BodyBuilder = {}

local assetTemplates: { [number]: MeshPart } = {}
local LOAD_ATTEMPTS = 3
-- How long a car waits for its meshes before building with boxes for the rest.
local PRELOAD_TIMEOUT = 30
local failed: { [string]: string } = {}

local function assetTemplate(meshId: number): MeshPart?
	if assetTemplates[meshId] then
		return assetTemplates[meshId]
	end
	local key = tostring(meshId)
	if failed[key] then
		return nil
	end
	-- A store car is dozens of meshes and the asset service drops the odd
	-- fetch ("could not fetch"); a second try almost always gets it.
	local ok, result
	for attempt = 1, LOAD_ATTEMPTS do
		ok, result = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromAssetId(meshId), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
				RenderFidelity = Enum.RenderFidelity.Automatic,
			})
		end)
		if ok and result then
			assetTemplates[meshId] = result
			return result
		end
		if attempt < LOAD_ATTEMPTS then
			task.wait(attempt)
		end
	end
	failed[key] = tostring(result)
	warn(`[BodyBuilder] mesh {meshId} failed to load ({result}); a box stands in for it`)
	return nil
end

-- The generated data for "Module/Piece", or nil.
function BodyBuilder.meshData(path: string): MeshData.Piece?
	local moduleName, pieceName = string.match(path, "^([%w_]+)/([%w_]+)$")
	local folder = Shared:FindFirstChild("CarMeshes")
	local module = if folder and moduleName then folder:FindFirstChild(moduleName) else nil
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	local data = (require :: any)(module)
	return data[pieceName :: string]
end

local warnedEditable = false
local warnedBudget = false

-- Holds the generated mesh at path for one car: its template, or nil (the
-- piece is left off). Each non-nil answer is one hold, given back by
-- releaseData. A broken piece is remembered and not tried again; a full
-- EditableMesh budget is not, because a slot comes free when a car goes.
local function acquireData(path: string): MeshPart?
	if failed[path] then
		return nil
	end
	local piece = BodyBuilder.meshData(path)
	if not piece then
		failed[path] = "no such generated mesh"
		warn(`[BodyBuilder] no generated mesh {path}; the piece is left off`)
		return nil
	end
	local ok, result = pcall(MeshData.acquire, piece)
	if ok then
		return result
	end
	local why = tostring(result)
	if string.find(why, MeshData.BUDGET_ERROR, 1, true) then
		if not warnedBudget then
			warnedBudget = true
			warn(
				`[BodyBuilder] out of EditableMesh slots (8 per client) at {path}: generated pieces are left off`
					.. " until a car goes. Upload them and give each its meshId (tools/carbody/README.md) to need none."
			)
		end
		return nil
	end
	failed[path] = why
	if string.find(why, "EditableMesh is not accessible", 1, true) then
		if not warnedEditable then
			warnedEditable = true
			warn(
				"[BodyBuilder] generated car meshes need EditableMesh, which this experience has off. Turn on"
					.. " 'Allow Mesh / Image APIs' (Studio: File > Game Settings > Security; published: Creator"
					.. " Dashboard), or import assets/cars/upload/<Car>.obj with the 3D Importer and give each"
					.. " piece its meshId (RIG_SPEC.md 7). Those pieces are left off until then."
			)
		end
	else
		warn(`[BodyBuilder] generated mesh {path} failed ({why}); the piece is left off`)
	end
	return nil
end

local function releaseData(path: string)
	local piece = BodyBuilder.meshData(path)
	if piece then
		MeshData.release(piece)
	end
end

-- Loads every uploaded mesh a car needs, up front, so building never yields
-- halfway. Asset meshes are fetched all at once: one at a time, a store car's
-- 90-odd meshes took most of a minute and the car sat there as a bare rig.
-- Generated pieces are made by mount, which holds them for the car's life.
-- Returns how many pieces have a mesh ready or generated data to make one.
function BodyBuilder.preload(entry: VehicleRig.CarEntry): number
	local pending = 0
	local wanted: { [number]: boolean } = {}
	for _, list in { entry.body.pieces, entry.body.wheelPieces } do
		for _, piece in list do
			local id = piece.meshId
			if id and not assetTemplates[id] and not failed[tostring(id)] and not wanted[id] then
				wanted[id] = true
				pending += 1
				task.spawn(function()
					assetTemplate(id)
					pending -= 1
				end)
			end
		end
	end
	local deadline = os.clock() + PRELOAD_TIMEOUT
	while pending > 0 and os.clock() < deadline do
		task.wait(0.05)
	end
	local n = 0
	for _, list in { entry.body.pieces, entry.body.wheelPieces } do
		for _, piece in list do
			local ready = if piece.meshId
				then (if assetTemplates[piece.meshId] then true else false)
				else piece.mesh ~= nil and not failed[piece.mesh :: string] and BodyBuilder.meshData(piece.mesh :: string) ~= nil
			if ready then
				n += 1
			end
		end
	end
	return n
end

local LAMP_OFF_TRANSPARENCY = 0.65 -- unlit: a clear lens, the housing shows through

local function makePiece(piece: BodyPiece, t: MeshPart?, body: VehicleRig.BodySpec, mps: number, k: number, name: string): BasePart
	local paint = body.paint
	local part: BasePart
	if t then
		local m = t:Clone()
		if not piece.look then
			local textureId = piece.textureId or 0
			m.TextureID = if textureId > 0 then `rbxassetid://{textureId}` else ""
		end
		part = m
	else
		part = Instance.new("Part")
	end
	part.Name = name
	part.Size = Vector3.new(piece.sizeM[1], piece.sizeM[2], piece.sizeM[3]) * (k / mps)
	part.Color = if piece.paint then paint else (piece.color or Color3.fromRGB(160, 160, 160))
	part:SetAttribute("Painted", if piece.paint then true else nil) -- CarCosmetics repaints these
	part.Material = piece.material or Enum.Material.SmoothPlastic
	part.Transparency = piece.transparency or 0
	part.CastShadow = piece.castShadow ~= false
	if piece.lamp and body.lamps then
		-- Unlit: tinted glass over the housing. setLamps makes it Neon.
		part.Color = (body.lamps :: any)[piece.lamp]
		part.Material = Enum.Material.Glass
		part.Transparency = LAMP_OFF_TRANSPARENCY
		part.CastShadow = false
		part:SetAttribute(VehicleRig.LAMP_ATTRIBUTE, piece.lamp)
	end
	if piece.look and t then
		local looks = ReplicatedStorage:FindFirstChild("CarLooks")
		local lookTemplate = looks and looks:FindFirstChild(piece.look)
		if lookTemplate and lookTemplate:IsA("SurfaceAppearance") then
			local sa = lookTemplate:Clone()
			if piece.paint then
				sa.Color = paint
			end
			sa.Parent = part
		else
			warn(`[BodyBuilder] no SurfaceAppearance "{piece.look}" in ReplicatedStorage.CarLooks`)
		end
	end
	-- Never part of the physics.
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.EnableFluidForces = false
	return part
end

local function mount(part: BasePart, at: Attachment, offset: CFrame, parent: Instance)
	part.CFrame = at.WorldCFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = at.Parent :: BasePart
	weld.Part1 = part
	weld.Parent = part
	part.Parent = parent
end

-- Builds the Body folder on a rig built by RigBuilder. On a car already in
-- the world the pieces are placed from the mounts as they are now, which is
-- right for the hubs (they carry the wheels wherever they sit) and for the
-- chassis.
function BodyBuilder.mount(model: Model, cfg: Config, entry: VehicleRig.CarEntry): Folder
	BodyBuilder.preload(entry)
	local handles = VehicleRig.handles(model)
	local mps = cfg.units.metersPerStud
	local k = VehicleRig.scaleOf(entry)
	local folder = Instance.new("Folder")
	folder.Name = VehicleRig.BODY
	-- The generated pieces this car holds (MeshData.acquire), one hold per
	-- path, given back when the car goes so its EditableMesh slots come free.
	local held: { [string]: MeshPart } = {}
	local asked: { [string]: boolean } = {}
	local function templateFor(piece: BodyPiece): MeshPart?
		if piece.meshId then
			return assetTemplate(piece.meshId)
		end
		local path = piece.mesh :: string
		if not asked[path] then
			asked[path] = true
			local t = acquireData(path)
			if t then
				held[path] = t
			end
		end
		return held[path]
	end
	for _, piece in entry.body.pieces do
		-- A generated piece that cannot load (EditableMesh off or out of
		-- slots, no uploaded meshId yet) is left off: a stand-in box the size
		-- of a whole-car chrome piece covered the Batrol (the owner,
		-- 2026-09-25: no chrome until the upload rather than a box).
		local t = templateFor(piece)
		if not piece.meshId and piece.mesh and not t then
			continue
		end
		local part = makePiece(piece, t, entry.body, mps, k, piece.name)
		mount(part, handles.bodyMount, VehicleRig.pieceCFrame(piece, mps, false, k), folder)
	end
	for _, w in VehicleRig.WHEELS do
		local hub = handles.hubs[w.name]
		for _, piece in entry.body.wheelPieces do
			local t = templateFor(piece)
			if not piece.meshId and piece.mesh and not t then
				continue
			end
			local part = makePiece(piece, t, entry.body, mps, k, `{piece.name}_{w.name}`)
			mount(part, hub.mount, VehicleRig.pieceCFrame(piece, mps, not w.left, k), folder)
		end
	end
	if next(held) then
		local released = false
		local function release()
			if released then
				return
			end
			released = true
			for path in held do
				releaseData(path)
			end
		end
		-- A car swap destroys the old model; a body rebuilt in place drops its
		-- folder. Either way nothing shows these clones any more.
		model.Destroying:Connect(release)
		folder.Destroying:Connect(release)
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(game) then
				release()
			end
		end)
		folder.AncestryChanged:Connect(function()
			if not folder:IsDescendantOf(model) then
				release()
			end
		end)
		if not model.Parent then
			release() -- the car went while its pieces were being made
		end
	end
	-- Plates: a thin quad on each plate mount with the texture on its outer
	-- face. The plate system swaps textures through setPlateTexture.
	local plates = entry.body.plates
	if plates then
		local w, h = VehicleRig.PLATE_SIZE_M[1], VehicleRig.PLATE_SIZE_M[2]
		local mounts: { { name: string, at: Attachment? } } = {
			{ name = "PlateFront", at = handles.plates.front },
			{ name = "PlateRear", at = handles.plates.rear },
		}
		for _, m in mounts do
			local at = m.at
			if not at then
				continue
			end
			local plate = Instance.new("Part")
			plate.Name = m.name
			plate.Size = Vector3.new(w, h, 0.004) * (k / mps)
			plate.Color = Color3.fromRGB(244, 244, 240)
			plate.Material = Enum.Material.SmoothPlastic
			plate.CastShadow = false
			plate.Anchored = false
			plate.Massless = true
			plate.CanCollide = false
			plate.CanQuery = false
			plate.CanTouch = false
			local decal = Instance.new("Decal")
			decal.Name = "PlateTexture"
			decal.Face = Enum.NormalId.Front -- -Z of the part, which the mount points outward
			decal.Texture = `rbxassetid://{plates.textureId}`
			decal.Parent = plate
			mount(plate, at, CFrame.identity, folder)
		end
	end
	folder.Parent = model
	return folder
end

-- Lights the lamps of a mounted body: head and tail each on (Neon, their
-- colour) or off (tinted glass). Leaves a kind alone when it is nil.
function BodyBuilder.setLamps(model: Model, state: { head: boolean?, tail: boolean? })
	local body = model:FindFirstChild(VehicleRig.BODY)
	if not body then
		return
	end
	for _, part in body:GetChildren() do
		local kind = part:GetAttribute(VehicleRig.LAMP_ATTRIBUTE)
		local on = if kind then (state :: any)[kind] else nil
		if on ~= nil and part:IsA("BasePart") then
			part.Material = if on then Enum.Material.Neon else Enum.Material.Glass
			part.Transparency = if on then 0 else LAMP_OFF_TRANSPARENCY
		end
	end
end

-- Puts a texture on a mounted body's plates ("front", "rear" or both).
function BodyBuilder.setPlateTexture(model: Model, textureId: number, which: ("front" | "rear")?)
	local body = model:FindFirstChild(VehicleRig.BODY)
	if not body then
		return
	end
	local names: { string } = if which == "front" then { "PlateFront" } elseif which == "rear" then { "PlateRear" } else { "PlateFront", "PlateRear" }
	for _, name in names do
		local plate = body:FindFirstChild(name)
		local decal = plate and plate:FindFirstChild("PlateTexture")
		if decal and decal:IsA("Decal") then
			decal.Texture = `rbxassetid://{textureId}`
		end
	end
end

return BodyBuilder
