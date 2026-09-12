--!strict
-- The berm: the edge of the playable area on both sides of the highway, a
-- long sand hill the car can drive up.
--
-- Cross-section, from the road outward: a gentle collidable slope (the only
-- scenery besides the road that collides), a short steep lip at the top, an
-- invisible wall standing on the crest so nothing gets over, then a cosmetic
-- rounded crest of mounds and a back slope down to the plane so it reads as
-- a dune line from either side. The sun side is farther out and lower so the
-- sunset and the far dune field stay in view over it.
--
-- Built as a road ribbon, so it follows the path in straight runs; on a
-- curved preset the runs are short and the outside corners open slightly.
local WorldConfig = require(script.Parent.WorldConfig)
local Build = require(script.Parent.Build)
local RoadNetwork = require(script.Parent.RoadNetwork)
local Dunes = require(script.Parent.Dunes)

type Config = WorldConfig.Config
type Context = RoadNetwork.Context
type Path = RoadNetwork.Path

local Berm = {}

local function tint(rng: Random, base: Color3, variation: number): Color3
	local t = rng:NextNumber(-variation, variation)
	return if t < 0 then base:Lerp(Color3.new(0, 0, 0), -t) else base:Lerp(Color3.new(1, 1, 1), t)
end

function Berm.build(cfg: Config, ctx: Context, path: Path, parent: Instance): Model
	local b = cfg.berm
	local model = Instance.new("Model")
	model.Name = "Berm"
	model.Parent = parent
	local rng = Build.rng(b.seed)
	local sunSide = Dunes.sideSign(cfg, path)
	local groundY = ctx.surfaceY - ctx.s(cfg.ground.dropM)
	local toM = math.min(b.endM, RoadNetwork.lengthM(path))

	for _, side in { -1, 1 } do
		local prof = if side == sunSide then b.sun else b.other
		local slopeH = prof.slopeWidthM * math.tan(math.rad(prof.slopeDeg))
		local lipH = prof.lipWidthM * math.tan(math.rad(prof.lipDeg))
		local crestM = prof.footM + prof.slopeWidthM + prof.lipWidthM
		local crestH = slopeH + lipH
		local backW = crestH / math.tan(math.rad(prof.backDeg))

		-- Everything is placed in the run frame: local X is lateral (+X is
		-- the road's right), local Z along the road. out is the unit
		-- lateral direction away from the road for this side.
		local function emit(cf: CFrame, length: number, _width: number, runIndex: number)
			local color = tint(rng, b.color, b.colorVariation)
			-- Lateral metres from the centreline to a frame-local X in studs.
			local function lx(m: number): number
				return side * ctx.s(m)
			end
			-- A WedgePart's tall face is at its +Z end and its slope runs
			-- down to -Z. Yaw so the slope's low edge points the way given.
			local function wedge(name: string, fromM: number, widthM: number, baseY: number, heightM: number, lowEdgeOut: boolean, collide: boolean, col: Color3)
				local lowDir = if lowEdgeOut then side else -side
				local yaw = -lowDir * math.pi / 2
				Build.wedge({
					name = name,
					size = Vector3.new(length, ctx.s(heightM), ctx.s(widthM)),
					cframe = cf * CFrame.new(lx(fromM + widthM / 2), baseY - cf.Y + ctx.s(heightM) / 2, 0) * CFrame.Angles(0, yaw, 0),
					color = col,
					material = Enum.Material.Sand,
					parent = model,
					collide = collide,
					query = collide,
					castShadow = false,
				})
			end
			-- Drivable slope, low edge toward the road.
			wedge("BermSlope", prof.footM, prof.slopeWidthM, groundY, slopeH, false, true, color)
			-- Lip, stacked on a filler box so there is no void under it.
			-- Boxes are not yawed like the wedges: in the run frame their
			-- Size.X is lateral and Size.Z runs along the road.
			Build.part({
				name = "BermLipBase",
				size = Vector3.new(ctx.s(prof.lipWidthM), ctx.s(slopeH), length),
				cframe = cf * CFrame.new(lx(prof.footM + prof.slopeWidthM + prof.lipWidthM / 2), groundY - cf.Y + ctx.s(slopeH) / 2, 0),
				color = color,
				material = Enum.Material.Sand,
				parent = model,
				collide = true,
				query = true,
			})
			wedge("BermLip", prof.footM + prof.slopeWidthM, prof.lipWidthM, groundY + ctx.s(slopeH), lipH, false, true, color)
			-- The wall on the crest. Invisible and tall: a car that launches
			-- off the lip at 200 km/h carries 150 m of climb. Queryable too,
			-- because a colliding part with CanQuery off is not honoured
			-- reliably; the suspension rays point down and the camera rig
			-- does not raycast, so nothing else notices it.
			Build.part({
				name = "BermWall",
				size = Vector3.new(ctx.s(1), ctx.s(b.wallHeightM), length),
				cframe = cf * CFrame.new(lx(crestM + 0.5), groundY - cf.Y + ctx.s(b.wallHeightM) / 2, 0),
				color = color,
				parent = model,
				collide = true,
				query = true,
				transparency = 1,
			})
			-- Back slope, cosmetic, low edge outward.
			wedge("BermBack", crestM, backW, groundY, crestH, true, false, color)

			-- Crest mounds along this run, sunk into the crest so only a
			-- rounded top shows above the lip.
			local along = -length / 2 + ctx.s(rng:NextNumber(0, b.moundSpacingM))
			while along < length / 2 do
				local w = rng:NextNumber(b.moundMinWidthM, b.moundMaxWidthM)
				local l = rng:NextNumber(b.moundMinLengthM, b.moundMaxLengthM)
				local extra = rng:NextNumber(prof.crestMoundMinM, prof.crestMoundMaxM)
				-- Height of the ellipsoid: its top sits extra above the
				-- crest, its centre on the crest line, so half is buried.
				local h = extra * 2
				Build.ellipsoid({
					name = "BermCrest",
					size = Vector3.new(ctx.s(w), ctx.s(h), ctx.s(l)),
					cframe = cf * CFrame.new(lx(crestM + w * b.moundBackFrac + rng:NextNumber(-3, 3)), groundY - cf.Y + ctx.s(crestH), along) * CFrame.Angles(0, math.rad(rng:NextNumber(-8, 8)), 0),
					color = tint(rng, b.crestColor, b.colorVariation),
					material = Enum.Material.Sand,
					parent = model,
					castShadow = false,
				})
				along += ctx.s(b.moundSpacingM + rng:NextNumber(-b.moundJitterM, b.moundJitterM))
			end
		end

		RoadNetwork.ribbon({
			name = "Berm",
			parent = model,
			path = path,
			ctx = ctx,
			offsetM = 0,
			widthM = 1,
			heightM = 1,
			yM = 0,
			color = b.color,
			toM = toM,
			runCapM = b.runCapM,
			emit = emit,
		})

		-- A mound over the far end so the profile's cut faces never show.
		-- The start-line end stays open.
		local endPt = RoadNetwork.sample(path, toM)
		local w = prof.slopeWidthM + prof.lipWidthM + backW
		Build.ellipsoid({
			name = "BermEnd",
			size = Vector3.new(ctx.s(w * 1.1), ctx.s(crestH * 2.2), ctx.s(w * 0.9)),
			cframe = CFrame.new(endPt.position + endPt.cframe.RightVector * (side * ctx.s(prof.footM + w / 2)) + Vector3.new(0, groundY - endPt.position.Y, 0)) * endPt.cframe.Rotation,
			color = tint(rng, b.color, b.colorVariation),
			material = Enum.Material.Sand,
			parent = model,
			castShadow = false,
		})
	end

	if cfg.streaming.enabled then
		pcall(function()
			model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end)
	end
	return model
end

return Berm
