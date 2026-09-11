--!strict
-- Jersey barriers, their reflective markers, and the chain-link fence behind
-- them. Barriers are the ONLY scenery the car is allowed to hit: everything
-- else in the world is CanCollide false so a drifting car is never stopped by
-- a lamp post or a palm.
--
-- Runs merge. A straight kilometre of barrier is two parts (the 2048 stud
-- axis cap), not a thousand little ones.
local WorldConfig = require(script.Parent.WorldConfig)
local Build = require(script.Parent.Build)
local RoadNetwork = require(script.Parent.RoadNetwork)

type Config = WorldConfig.Config
type Context = RoadNetwork.Context
type Path = RoadNetwork.Path

local Barriers = {}

function Barriers.build(cfg: Config, ctx: Context, path: Path, parent: Instance): Model
	local b = cfg.barriers
	local r = cfg.road
	-- A Model rather than a Folder: only Models carry ModelStreamingMode, and
	-- a barrier that has not streamed in is a barrier the car drives through.
	local folder = Instance.new("Model")
	folder.Name = "Barriers"
	folder.Parent = parent
	if cfg.streaming.enabled and cfg.streaming.barriersPersistent then
		pcall(function()
			folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end)
	end
	local totalM = RoadNetwork.lengthM(path)
	local rng = Build.rng(b.variationSeed)
	local castShadow = cfg.shadows.barriers

	-- Outside the shoulder and the kerb, so the barrier sits where a real one
	-- would rather than on the running surface.
	local edgeOffset = r.shoulderWidthM + r.kerbWidthM + b.offsetM

	-- Jersey profile, built in the run's local frame: X lateral, Y up, Z along
	-- the road. Base slab, a wedge flaring out on each side, then the upper
	-- wall. Only the base slab collides; the flares and the wall sit inside
	-- its footprint so the car hits one clean surface rather than a staircase.
	local function jersey(cf: CFrame, length: number, _width: number)
		local baseW = ctx.s(b.baseWidthM)
		local baseH = ctx.s(b.baseHeightM)
		local flareTop = ctx.s(b.flareHeightM)
		local topW = ctx.s(b.topWidthM)
		local total = ctx.s(b.heightM)
		local tint = rng:NextNumber(-b.colorVariation, b.colorVariation)
		local color = if tint < 0
			then b.color:Lerp(Color3.new(0, 0, 0), -tint)
			else b.color:Lerp(Color3.new(1, 1, 1), tint)

		-- The collidable body: full height at the top width, so the car slides
		-- along a flat wall instead of catching on the flare.
		Build.part({
			name = "JerseyBody",
			size = Vector3.new(topW, total, length),
			cframe = cf * CFrame.new(0, total / 2, 0),
			color = color,
			material = Enum.Material.Concrete,
			parent = folder,
			collide = true,
			castShadow = castShadow,
		})
		-- Flared foot, non-collidable decoration on both sides.
		Build.part({
			name = "JerseyBase",
			size = Vector3.new(baseW, baseH, length),
			cframe = cf * CFrame.new(0, baseH / 2, 0),
			color = color,
			material = Enum.Material.Concrete,
			parent = folder,
			castShadow = castShadow,
		})
		local run = (baseW - topW) / 2
		local rise = flareTop - baseH
		for _, side in { -1, 1 } do
			-- The wedge slopes along its local Z, so it is turned to put that
			-- axis across the road and the sign mirrors it to the far side.
			local w = Build.wedge({
				name = "JerseyFlare",
				size = Vector3.new(length, rise, run),
				cframe = cf
					* CFrame.new(side * (topW / 2 + run / 2), baseH + rise / 2, 0)
					* CFrame.Angles(0, math.rad(90 * side), 0),
				color = color,
				material = Enum.Material.Concrete,
				parent = folder,
				castShadow = castShadow,
			})
			w.Name = "JerseyFlare"
		end
		-- Occasional scuff: a dark smear at bumper height on the traffic face.
		if rng:NextNumber() < b.scuffChance then
			Build.part({
				name = "Scuff",
				size = Vector3.new(ctx.s(0.03), ctx.s(0.16), length * rng:NextNumber(0.2, 0.6)),
				cframe = cf * CFrame.new(0, ctx.s(0.55), length * rng:NextNumber(-0.2, 0.2)),
				color = b.scuffColor,
				material = Enum.Material.Concrete,
				parent = folder,
				transparency = rng:NextNumber(0.25, 0.6),
			})
		end
	end

	for _, side in { -1, 1 } do
		RoadNetwork.ribbon({
			name = "Jersey",
			parent = folder,
			path = path,
			ctx = ctx,
			offsetM = side * (edgeOffset + b.baseWidthM / 2),
			edgeRelative = true,
			widthM = b.baseWidthM,
			heightM = b.heightM,
			yM = 0,
			color = b.color,
			material = Enum.Material.Concrete,
			collide = true,
			castShadow = castShadow,
			emit = jersey,
		})

		-- Reflective markers on the traffic face. Small, inert, and Neon so
		-- they catch the eye without needing a light of their own.
		RoadNetwork.repeatAlong(path, ctx, b.markerSpacingM, b.markerSpacingM / 2, totalM, function(p)
			local lateral = side * (p.halfWidth + ctx.s(edgeOffset))
			local pos = p.position
				+ p.cframe.RightVector * lateral
				+ Vector3.new(0, ctx.s(b.heightM * 0.78), 0)
			Build.part({
				name = "Marker",
				size = Vector3.new(ctx.s(0.05), ctx.s(b.markerSizeM), ctx.s(b.markerSizeM)),
				cframe = CFrame.lookAt(pos, pos + p.cframe.LookVector),
				color = b.markerColor,
				material = Enum.Material.Neon,
				parent = folder,
			})
		end)

		if b.railEnabled then
			-- Corrugated beam: two thin slabs with a gap, which reads as the
			-- W profile at speed for a fraction of the geometry.
			for _, dy in { -0.09, 0.09 } do
				RoadNetwork.ribbon({
					name = "GuardRail",
					parent = folder,
					path = path,
					ctx = ctx,
					offsetM = side * (edgeOffset + b.railOffsetM),
					edgeRelative = true,
					widthM = b.railThicknessM,
					heightM = b.railDepthM / 2,
					yM = b.railHeightM + dy,
					color = b.railColor,
					material = Enum.Material.CorrodedMetal,
					castShadow = castShadow,
				})
			end
			RoadNetwork.repeatAlong(path, ctx, b.railPostSpacingM, 0, totalM, function(p)
				local lateral = side * (p.halfWidth + ctx.s(edgeOffset + b.railOffsetM))
				local h = ctx.s(b.railHeightM + b.railDepthM / 2)
				local pos = p.position + p.cframe.RightVector * lateral + Vector3.new(0, h / 2, 0)
				Build.part({
					name = "RailPost",
					size = Vector3.new(ctx.s(0.09), h, ctx.s(0.13)),
					cframe = CFrame.lookAt(pos, pos + p.cframe.LookVector),
					color = b.railPostColor,
					material = Enum.Material.Metal,
					parent = folder,
					castShadow = castShadow,
				})
			end)
		end
	end

	return folder
end

return Barriers
