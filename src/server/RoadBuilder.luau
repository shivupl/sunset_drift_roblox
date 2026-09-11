--!strict
-- Builds the Phase 0 test road from CarConfig.road: a straight with a dashed
-- centreline, a wider transition pad partway down, a gentle curve at the end,
-- a sand ground plane, and a parking bay. Built in CarConfig units so the
-- road matches the car scale.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared.CarConfig)
local Units = require(Shared.Units)

type Config = CarConfig.Config

local RoadBuilder = {}

local MAX_PART_STUDS = 2048

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function RoadBuilder.build(config: Config): Model
	local mps = config.units.metersPerStud
	local R = config.road
	local ROAD_LENGTH_M, ROAD_WIDTH_M, ROAD_THICKNESS_M = R.lengthM, R.widthM, R.thicknessM
	local DASH_LENGTH_M, DASH_GAP_M, DASH_WIDTH_M = R.dashLengthM, R.dashGapM, R.dashWidthM
	local CURVE_RADIUS_M, CURVE_SWEEP_DEG, CURVE_SEGMENTS = R.curveRadiusM, R.curveSweepDeg, R.curveSegments
	local BAY_LENGTH_M, GROUND_TILE_M = R.bayLengthM, R.groundTileM
	local function s(m: number): number
		return Units.mToStuds(m, mps)
	end

	local existing = workspace:FindFirstChild("Road")
	if existing then
		existing:Destroy()
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	local road = Instance.new("Model")
	road.Name = "Road"

	local surfaceY = 0
	local thickness = s(ROAD_THICKNESS_M)
	local halfWidth = s(ROAD_WIDTH_M) / 2
	local asphalt = Color3.fromRGB(45, 45, 48)
	local sand = Color3.fromRGB(196, 176, 130)
	local paint = Color3.fromRGB(240, 220, 90)

	-- Ground plane: tiled because a Part axis maxes at 2048 studs. Covers the
	-- straight, the curve and 500 m of run-off beyond the end.
	local groundTiles = Instance.new("Folder")
	groundTiles.Name = "Ground"
	groundTiles.Parent = road
	local tile = s(GROUND_TILE_M)
	local tilesZ = math.ceil((ROAD_LENGTH_M + CURVE_RADIUS_M + 500) / GROUND_TILE_M)
	for ix = -2, 2 do
		for iz = -tilesZ, 1 do
			part(
				"GroundTile",
				Vector3.new(tile, thickness, tile),
				CFrame.new(ix * tile, surfaceY - s(0.1) - thickness / 2, iz * tile),
				sand,
				Enum.Material.Sand,
				groundTiles
			)
		end
	end

	-- Straight: road runs from z = 0 toward -Z (Roblox forward).
	local straight = Instance.new("Folder")
	straight.Name = "Straight"
	straight.Parent = road
	local segCount = math.max(4, math.ceil(s(ROAD_LENGTH_M) / MAX_PART_STUDS))
	local segLen = s(ROAD_LENGTH_M) / segCount
	assert(segLen <= MAX_PART_STUDS, "road segment too long")
	for i = 0, segCount - 1 do
		local zCenter = -(i * segLen + segLen / 2)
		part(
			"Straight" .. i,
			Vector3.new(halfWidth * 2, thickness, segLen),
			CFrame.new(0, surfaceY - thickness / 2, zCenter),
			asphalt,
			Enum.Material.Asphalt,
			straight
		)
	end

	-- Transition pad: two wings flush with the road (no overlap, so no
	-- z-fighting) that widen the straight for left-right swings.
	local padWing = (R.padWidthM - ROAD_WIDTH_M) / 2
	if padWing > 0 and R.padLengthM > 0 then
		local pad = Instance.new("Folder")
		pad.Name = "TransitionPad"
		pad.Parent = road
		local padZ = -(s(R.padStartM) + s(R.padLengthM) / 2)
		local padShade = Color3.fromRGB(58, 58, 62)
		for _, sign in { -1, 1 } do
			part(
				"PadWing",
				Vector3.new(s(padWing), thickness, s(R.padLengthM)),
				CFrame.new(sign * (halfWidth + s(padWing) / 2), surfaceY - thickness / 2, padZ),
				padShade,
				Enum.Material.Asphalt,
				pad
			)
		end
		-- Edge lines marking the start and end of the pad.
		for _, zEdge in { -s(R.padStartM), -(s(R.padStartM) + s(R.padLengthM)) } do
			local line = part(
				"PadEdge",
				Vector3.new(s(R.padWidthM), s(0.02), s(DASH_WIDTH_M)),
				CFrame.new(0, surfaceY + s(0.01), zEdge),
				paint,
				Enum.Material.SmoothPlastic,
				pad
			)
			line.CanCollide = false
		end
		road:SetAttribute("PadStartStuds", -s(R.padStartM))
		road:SetAttribute("PadEndStuds", -(s(R.padStartM) + s(R.padLengthM)))
	end

	-- Centreline dashes.
	local dashes = Instance.new("Folder")
	dashes.Name = "Centreline"
	dashes.Parent = road
	local dashLen, dashGap = s(DASH_LENGTH_M), s(DASH_GAP_M)
	local z = -dashLen / 2
	while z > -s(ROAD_LENGTH_M) do
		local d = part(
			"Dash",
			Vector3.new(s(DASH_WIDTH_M), s(0.02), dashLen),
			CFrame.new(0, surfaceY + s(0.01), z),
			paint,
			Enum.Material.SmoothPlastic,
			dashes
		)
		d.CanCollide = false
		z -= dashLen + dashGap
	end

	-- Curve: arc to the left (-X) starting at the end of the straight.
	local curve = Instance.new("Folder")
	curve.Name = "Curve"
	curve.Parent = road
	local radius = s(CURVE_RADIUS_M)
	local endZ = -s(ROAD_LENGTH_M)
	local center = Vector3.new(-radius, surfaceY, endZ) -- arc centre to the left of the road end
	local sweep = math.rad(CURVE_SWEEP_DEG)
	local segAngle = sweep / CURVE_SEGMENTS
	local segChord = radius * segAngle
	for i = 0, CURVE_SEGMENTS - 1 do
		local a = (i + 0.5) * segAngle
		-- Point on the arc: start at angle 0 (road end), rotate toward -X.
		local pos = center + Vector3.new(math.cos(a) * radius, 0, -math.sin(a) * radius)
		local look = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, -math.cos(a)))
		part(
			"Curve" .. i,
			Vector3.new(halfWidth * 2, thickness, segChord * 1.1),
			look * CFrame.new(0, -thickness / 2, 0),
			asphalt,
			Enum.Material.Asphalt,
			curve
		)
		if i % 2 == 0 then
			local d = part(
				"Dash",
				Vector3.new(s(DASH_WIDTH_M), s(0.02), segChord * 0.5),
				look * CFrame.new(0, s(0.01), 0),
				paint,
				Enum.Material.SmoothPlastic,
				dashes
			)
			d.CanCollide = false
		end
	end

	-- Parking bay behind the start line (z > 0).
	local bay = part(
		"Bay",
		Vector3.new(halfWidth * 2, thickness, s(BAY_LENGTH_M)),
		CFrame.new(0, surfaceY - thickness / 2, s(BAY_LENGTH_M) / 2),
		Color3.fromRGB(60, 60, 64),
		Enum.Material.Concrete,
		road
	)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlayerSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(-halfWidth + 10, surfaceY + 0.5, s(BAY_LENGTH_M) / 2)
	spawn.Neutral = true
	spawn.Parent = road
	local old = workspace:FindFirstChild("SpawnLocation")
	if old then
		old:Destroy()
	end

	road:SetAttribute("StartCFrame", CFrame.new(0, surfaceY, 0)) -- facing -Z by default
	road:SetAttribute("LengthStuds", s(ROAD_LENGTH_M))
	road:SetAttribute("HalfWidthStuds", halfWidth)
	road:SetAttribute("BayCFrame", bay.CFrame * CFrame.new(0, thickness / 2, 0))
	road:SetAttribute("SurfaceY", surfaceY)
	road.Parent = workspace
	return road
end

return RoadBuilder
