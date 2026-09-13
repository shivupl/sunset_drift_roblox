--!strict
-- Mounts a car's Body onto its built Rig: MeshParts only, every one
-- massless, non-colliding, unqueryable and untouchable, welded to a mount
-- attachment. It adds nothing to the physics: the assembly's mass, centre of
-- mass and collision are exactly the rig's, and the suspension rays already
-- ignore the whole car.
--
-- Meshes load through AssetService:CreateMeshPartAsync from the bare mesh
-- ids in the catalog, once per id, so no store model and none of its
-- scripts ever enter the game. A mesh that fails to load gets a plain box of
-- the same size in its place and a warning, so a bad id shows as a grey
-- block instead of an invisible car.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared.CarConfig)
local VehicleRig = require(Shared.VehicleRig)

type Config = CarConfig.Config
type BodyPiece = VehicleRig.BodyPiece

local BodyBuilder = {}

local templates: { [number]: MeshPart } = {}
local failed: { [number]: string } = {}

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
	if ok and result then
		templates[meshId] = result
		return result
	end
	failed[meshId] = tostring(result)
	warn(`[BodyBuilder] mesh {meshId} failed to load ({result}); a box stands in for it`)
	return nil
end

-- Loads every mesh a car needs, up front, so building never yields halfway.
function BodyBuilder.preload(entry: VehicleRig.CarEntry): number
	local n = 0
	for _, list in { entry.body.pieces, entry.body.wheelPieces } do
		for _, piece in list do
			if template(piece.meshId) then
				n += 1
			end
		end
	end
	return n
end

local function makePiece(piece: BodyPiece, paint: Color3, mps: number, k: number, name: string): BasePart
	local t = template(piece.meshId)
	local part: BasePart
	if t then
		local m = t:Clone()
		local textureId = piece.textureId or 0
		m.TextureID = if textureId > 0 then `rbxassetid://{textureId}` else ""
		part = m
	else
		part = Instance.new("Part")
	end
	part.Name = name
	part.Size = Vector3.new(piece.sizeM[1], piece.sizeM[2], piece.sizeM[3]) * (k / mps)
	part.Color = if piece.paint then paint else (piece.color or Color3.fromRGB(160, 160, 160))
	part.Material = piece.material or Enum.Material.SmoothPlastic
	part.Transparency = piece.transparency or 0
	part.CastShadow = piece.castShadow ~= false
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

-- Builds the Body folder on a rig built by RigBuilder, before the car is
-- moved into the world.
function BodyBuilder.mount(model: Model, cfg: Config, entry: VehicleRig.CarEntry): Folder
	local handles = VehicleRig.handles(model)
	local mps = cfg.units.metersPerStud
	local k = VehicleRig.scaleOf(entry)
	local folder = Instance.new("Folder")
	folder.Name = VehicleRig.BODY
	folder.Parent = model

	for _, piece in entry.body.pieces do
		local part = makePiece(piece, entry.body.paint, mps, k, piece.name)
		mount(part, handles.bodyMount, VehicleRig.pieceCFrame(piece, mps, false, k), folder)
	end
	for _, w in VehicleRig.WHEELS do
		local hub = handles.hubs[w.name]
		for _, piece in entry.body.wheelPieces do
			local part = makePiece(piece, entry.body.paint, mps, k, `{piece.name}_{w.name}`)
			mount(part, hub.mount, VehicleRig.pieceCFrame(piece, mps, not w.left, k), folder)
		end
	end
	return folder
end

return BodyBuilder
