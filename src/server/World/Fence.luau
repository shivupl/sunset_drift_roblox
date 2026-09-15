--!strict
-- The border: a chain-link fence either side of the highway (WorldConfig.fence).
--
-- It follows the fence line Relief.border works out, the same lookup the
-- dunes and Scatter read, so the three always agree: 400 m past each road
-- edge, pushed out round the back of the petrol station, closed across
-- behind the start line, and stopping short of the city gateway.
--
-- It runs over the dunes: every post stands on the sand under it.
--
-- Built cheaply: square posts every postSpacingM, and between them long
-- runs, not per-bay pieces. Wherever the ground stays within RUN_SAG_M of a
-- straight line, one panel, one top rail, the barbed strands and one
-- invisible wall cover the whole stretch; each post then reaches from the
-- sand up to that run's rail, so the rail is straight and the posts meet
-- it. The mesh is a tiled Texture on an invisible panel, so the
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

-- A run keeps going while every post in it stays within RUN_BEND_M sideways
-- and RUN_SAG_M up or down of the straight line from its first post to its
-- last: the panel's foot floats or sinks by at most that on a dune.
local RUN_BEND_M = 0.1
local RUN_SAG_M = 0.35
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
	-- Terrain written in the relief pass is not raycastable for a frame or
	-- more (longer the more there is), and a post placed before then stands
	-- on the plane, buried in the dune. Wait until a spot where the fence
	-- crosses a dune reads as sand.
	local probe: Vector3? = nil
	local probeAlong = 0
	while not probe and probeAlong < border.fenceEndM do
		for _, side in { -1, 1 } do
			local lateral = side * border.fenceAt(side, probeAlong)
			if border.heightAt(probeAlong, lateral) > border.sinkM + 0.5 then
				local p = RoadNetwork.sample(path, math.clamp(probeAlong, 0, totalM))
				probe = p.position + p.cframe.RightVector * ctx.s(lateral)
				break
			end
		end
		probeAlong += 25
	end
	if probe then
		local deadline = os.clock() + 10
		while os.clock() < deadline do
			local y = Relief.surfaceY(Vector3.new(probe.X, groundY, probe.Z))
			if y and y > groundY + ctx.s(0.3) then
				break
			end
			task.wait(0.1)
		end
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

	-- A post standing on the sand at pos, up to the rail at railY (the top
	-- of the mesh) and the barbed strands above.
	local function post(pos: Vector3, railY: number)
		local extra = if fc.barbedWire then ctx.s(fc.barbedHeightsM[#fc.barbedHeightsM] + 0.04) else 0
		local height = math.max(railY - pos.Y, H * 0.5) + extra
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
		-- The stop: tall and invisible, in the fence, reaching a little under
		-- the panel's foot where the sand dips below the run.
		local wallH = ctx.s(fc.wallHeightM)
		local under = ctx.s(RUN_SAG_M + 1)
		piece((wallH - under) / 2, Vector3.new(ctx.s(0.5), wallH + under, length), "FenceWall", { transparency = 1, collide = true, query = true })
		runs += 1
	end

	-- A line of posts on the ground, merged into runs. The end posts are
	-- left out when skipEnds (they belong to the side fences).
	local function build(points: { Vector3 }, skipEnds: boolean)
		local function straight(first: number, last: number): boolean
			local a, b = points[first], points[last]
			local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			local len = flat.Magnitude
			if len * ctx.mps > RUN_MAX_M then
				return false
			end
			if len < 1e-3 then
				return true
			end
			local dir = flat / len
			for k = first + 1, last - 1 do
				local p = points[k]
				local rel = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
				local along = rel:Dot(dir)
				local side = (rel - dir * along).Magnitude * ctx.mps
				local sag = math.abs(p.Y - (a.Y + (b.Y - a.Y) * along / len)) * ctx.mps
				if side > RUN_BEND_M or sag > RUN_SAG_M then
					return false
				end
			end
			return true
		end
		-- Runs from post to post, and the rail height at every post.
		local railY = table.create(#points, 0)
		local first = 1
		while first < #points do
			local last = first + 1
			while last < #points and straight(first, last + 1) do
				last += 1
			end
			local a, b = points[first], points[last]
			local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			local len = flat.Magnitude
			for k = first, last do
				local p = points[k]
				local t = if len > 1e-3 then Vector3.new(p.X - a.X, 0, p.Z - a.Z):Dot(flat) / (len * len) else 0
				railY[k] = a.Y + (b.Y - a.Y) * t + H
			end
			run(a, b)
			first = last
		end
		for k, p in points do
			if not (skipEnds and (k == 1 or k == #points)) then
				post(p, railY[k])
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
		build(sides[side], false)
	end

	-- Across behind the start line, between the two side fences' first posts.
	local left, right = sides[-1][1], sides[1][1]
	local width = (right - left).Magnitude * ctx.mps
	local n = math.max(1, math.round(width / spacing))
	local cross: { Vector3 } = {}
	for k = 0, n do
		table.insert(cross, onGround(left:Lerp(right, k / n)))
	end
	build(cross, true) -- the two corner posts are already there

	if cfg.debug.report then
		print(string.format("[World] fence: %d posts, %d runs, %.0f m either side", posts, runs, border.fenceEndM + fc.behindStartM))
	end
	return folder
end

return Fence
