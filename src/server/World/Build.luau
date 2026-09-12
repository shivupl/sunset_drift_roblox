--!strict
-- Part construction helpers shared by every world builder.
--
-- This exists so the performance flags are applied in exactly one place. The
-- brief requires every scenery part to be Anchored, CanTouch false, CanQuery
-- false and CanCollide false unless it is a barrier, with CastShadow off.
-- Setting those by hand in six modules is how one of them ends up wrong.
local Build = {}

-- Roblox caps a Part axis at 2048 studs.
Build.MAX_PART_STUDS = 2048

export type Opts = {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	parent: Instance,
	-- Scenery defaults to inert. Only the road surface and barriers opt in.
	collide: boolean?,
	query: boolean?,
	transparency: number?,
	castShadow: boolean?,
}

function Build.part(o: Opts): Part
	local p = Instance.new("Part")
	p.Name = o.name
	p.Anchored = true
	p.Size = o.size
	p.CFrame = o.cframe
	p.Color = o.color
	p.Material = o.material or Enum.Material.SmoothPlastic
	p.Transparency = o.transparency or 0
	p.CanCollide = o.collide == true
	-- A part the car can hit must also be queryable; the suspension raycast
	-- is how the car finds the road at all.
	p.CanQuery = if o.query ~= nil then o.query else (o.collide == true)
	p.CanTouch = false
	p.CastShadow = o.castShadow == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = o.parent
	return p
end

-- Same flags, a wedge instead of a box. Used for the jersey barrier flanks,
-- where a plain cuboid is the thing that reads as fake at speed.
function Build.wedge(o: Opts): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = o.name
	p.Anchored = true
	p.Size = o.size
	p.CFrame = o.cframe
	p.Color = o.color
	p.Material = o.material or Enum.Material.SmoothPlastic
	p.Transparency = o.transparency or 0
	p.CanCollide = o.collide == true
	p.CanQuery = if o.query ~= nil then o.query else (o.collide == true)
	p.CanTouch = false
	p.CastShadow = o.castShadow == true
	p.Parent = o.parent
	return p
end

-- A corner wedge: four of them make a square pyramid, which is how the
-- Faisaliah-style landmark is built without a mesh.
function Build.cornerWedge(o: Opts): CornerWedgePart
	local p = Instance.new("CornerWedgePart")
	p.Name = o.name
	p.Anchored = true
	p.Size = o.size
	p.CFrame = o.cframe
	p.Color = o.color
	p.Material = o.material or Enum.Material.SmoothPlastic
	p.Transparency = o.transparency or 0
	p.CanCollide = o.collide == true
	p.CanQuery = if o.query ~= nil then o.query else (o.collide == true)
	p.CanTouch = false
	p.CastShadow = o.castShadow == true
	p.Parent = o.parent
	return p
end

function Build.folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Deterministic per-system randomness: every server builds the same world.
function Build.rng(seed: number): Random
	return Random.new(seed)
end

function Build.countParts(root: Instance): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

-- Triangle estimate. Roblox does not expose a real count to Lua, so this is
-- the standard per-shape figure: a box is 12, a wedge 8, and a cylinder or
-- sphere is roughly 100 at full detail. MeshParts report their own only in
-- Studio, so an approved mesh contributes its registry figure instead.
function Build.estimateTriangles(root: Instance): number
	local tris = 0
	for _, d in root:GetDescendants() do
		if d:IsA("MeshPart") then
			tris += 800 -- placeholder until a real mesh is approved
		elseif d:IsA("WedgePart") or d:IsA("CornerWedgePart") then
			tris += 8
		elseif d:IsA("Part") then
			local shape = (d :: Part).Shape
			local special = d:FindFirstChildWhichIsA("SpecialMesh")
			if special and special.MeshType == Enum.MeshType.Sphere then
				tris += 400 -- the dune ellipsoids; Roblox's sphere mesh is not counted anywhere it can be read
			elseif shape == Enum.PartType.Ball then
				tris += 96
			elseif shape == Enum.PartType.Cylinder then
				tris += 108
			else
				tris += 12
			end
		elseif d:IsA("BasePart") then
			tris += 12
		end
	end
	return tris
end

return Build
