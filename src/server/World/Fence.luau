--!strict
-- The border: a chain-link fence either side of the highway (WorldConfig.fence).
--
-- It follows the fence line Relief.border works out, the same lookup the
-- dunes and Scatter read, so the three always agree: 250 ft past each road
-- edge, pushed out round the back of the petrol station, closed across
-- behind the start line, and stopping short of the city gateway.
--
-- Built cheaply: square posts every postSpacingM, and between them long
-- runs, not per-bay pieces. Wherever the line is straight and level, one
-- panel, one top rail, the barbed strands and one invisible wall cover the
-- whole stretch. The mesh is a tiled Texture on an invisible panel, so the
-- desert and the skyline show through it, and the panel casts no shadow
-- (a shadow would be a solid rectangle).
local WorldConfig = require(script.Parent.WorldConfig)
local Build = require(script.Parent.Build)
local RoadNetwork = require(script.Parent.RoadNetwork)
local Relief = require(script.Parent.Relief)

type Config = WorldConfig.Config
type Context = RoadNetwork.Context
type Path = RoadNetwork.Path

local Fence = {}

-- A run keeps going while the line turns less than this and rises less than
-- RUN_RISE_M between posts.
local RUN_TURN_DEG = 0.35
local RUN_RISE_M = 0.05
local RUN_MAX_M = 400

function Fence.build(cfg: Config, ctx: Context, path: Path, parent: Instance): Folder
	local fc = cfg.fence
	local folder = Build.folder("Fence", parent)
	local border = Relief.border(cfg, ctx, path)
	local totalM = RoadNetwork.lengthM(path)
	local groundY = ctx.surfaceY - ctx.s(cfg.ground.dropM)
	local H = ctx.s(fc.heightM)

	-- A spot on the fence line, on whatever ground is there.
	local function onGround(pos: Vector3): Vector3
		local y = Relief.surfaceY(Vector3.new(pos.X, groundY, pos.Z))
		return Vector3.new(pos.X, math.max(y or groundY, groundY), pos.Z)
	end
	local function point(side: number, along: number): Vector3
		local p = RoadNetwork.sample(path, math.clamp(along, 0, totalM))
		local pos = p.position
			+ p.cframe.LookVector * ctx.s(math.min(along, 0))
			+ p.cframe.RightVector * ctx.s(side * border.fenceAt(side, along))
		return onGround(pos)
	end

	local posts = 0
	local runs = 0

	local function post(pos: Vector3)
		local extra = if fc.barbedWire then ctx.s(fc.barbedHeightsM[#fc.barbedHeightsM] + 0.04) else 0
		local height = H + extra
		Build.part({
			name = "FencePost",
			size = Vector3.new(ctx.s(fc.postWidthM), height, ctx.s(fc.postWidthM)),
			cframe = CFrame.new(pos + Vector3.new(0, height / 2, 0)),
			color = fc.postColor,
			material = Enum.Material.Metal,
			parent = folder,
			castShadow = true, -- long post shadows across the sand at golden hour
		})
		posts += 1
	end

	-- One straight stretch from a to b (ground points).
	local function run(a: Vector3, b: Vector3)
		local span = b - a
		local length = span.Magnitude
		if length < 1e-3 then
			return
		end
		local mid = (a + b) / 2
		local frame = CFrame.lookAt(mid, b)
		local function piece(lift: number, size: Vector3, name: string, props: { [string]: any }): Part
			return Build.part({
				name = name,
				size = size,
				cframe = frame * CFrame.new(0, lift, 0),
				color = props.color or fc.postColor,
				material = props.material or Enum.Material.Metal,
				parent = folder,
				transparency = props.transparency,
				collide = props.collide,
				query = props.query,
				castShadow = props.shadow == true,
			})
		end
		-- The mesh.
		local panel = piece(H / 2, Vector3.new(ctx.s(0.02), H, length), "FenceMesh", { transparency = 1 })
		for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
			local tex = Instance.new("Texture")
			tex.Texture = `rbxassetid://{fc.meshTextureId}`
			tex.Face = face
			tex.StudsPerTileU = ctx.s(fc.meshTileM)
			tex.StudsPerTileV = ctx.s(fc.meshTileM)
			tex.Transparency = fc.meshTransparency
			tex.Parent = panel
		end
		-- Top rail and the barbed strands.
		piece(H - ctx.s(fc.railWidthM) / 2, Vector3.new(ctx.s(fc.railWidthM), ctx.s(fc.railWidthM), length), "FenceRail", { shadow = true })
		if fc.barbedWire then
			for _, h in fc.barbedHeightsM do
				piece(H + ctx.s(h), Vector3.new(ctx.s(0.012), ctx.s(0.012), length), "BarbedWire", { color = fc.barbedColor })
			end
		end
		-- The stop: tall and invisible, in the fence.
		local wallH = ctx.s(fc.wallHeightM)
		piece(wallH / 2, Vector3.new(ctx.s(0.5), wallH, length), "FenceWall", { transparency = 1, collide = true, query = true })
		runs += 1
	end

	-- A line of posts, merged into runs.
	local function build(points: { Vector3 })
		for _, p in points do
			post(p)
		end
		local startIndex = 1
		for i = 2, #points do
			local a, b = points[startIndex], points[i]
			local dirRun = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			local breakHere = i == #points
			if not breakHere then
				local nextPoint = points[i + 1]
				local seg = Vector3.new(nextPoint.X - b.X, 0, nextPoint.Z - b.Z)
				local turn = if dirRun.Magnitude > 1e-3 and seg.Magnitude > 1e-3
					then math.deg(math.acos(math.clamp(dirRun.Unit:Dot(seg.Unit), -1, 1)))
					else 0
				local rise = math.abs((nextPoint.Y - b.Y) - (b.Y - points[i - 1].Y)) * ctx.mps
				breakHere = turn > RUN_TURN_DEG or rise > RUN_RISE_M or (nextPoint - a).Magnitude * ctx.mps > RUN_MAX_M
			end
			if breakHere then
				run(a, b)
				startIndex = i
			end
		end
	end

	local spacing = fc.postSpacingM
	local sides: { [number]: { Vector3 } } = { [-1] = {}, [1] = {} }
	for _, side in { -1, 1 } do
		local along = -fc.behindStartM
		while along < border.fenceEndM do
			table.insert(sides[side], point(side, along))
			along += spacing
		end
		table.insert(sides[side], point(side, border.fenceEndM))
		build(sides[side])
	end

	-- Across behind the start line, between the two side fences' first posts.
	local left, right = sides[-1][1], sides[1][1]
	local width = (right - left).Magnitude * ctx.mps
	local n = math.max(1, math.round(width / spacing))
	local cross: { Vector3 } = {}
	for k = 0, n do
		table.insert(cross, onGround(left:Lerp(right, k / n)))
	end
	-- The two corner posts are already there.
	local inner = table.clone(cross)
	table.remove(inner, 1)
	table.remove(inner, #inner)
	for _, p in inner do
		post(p)
	end
	run(cross[1], cross[#cross])

	if cfg.debug.report then
		print(string.format("[World] fence: %d posts, %d runs, %.0f m either side", posts, runs, border.fenceEndM + fc.behindStartM))
	end
	return folder
end

return Fence
