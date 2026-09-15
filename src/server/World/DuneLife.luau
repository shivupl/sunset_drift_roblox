--!strict
-- Life out in the dune field (WorldConfig.duneLife): sparse palms and
-- acacias, and a handful of small scenes on the sand between the flat strip
-- beside the road and the fence.
--
-- The scenes:
-- - **Oasis:** a clump of palms with scrub and rocks.
-- - **Camp:** a tent, a carpet, a fire and camels.
-- - **Majlis:** an open-air sitting area, with a carpet, floor cushions, a
--   fire, and a tray with a dallah and cups.
-- - **Wreck:** a hajwala car left to the sand, with its tyres.
-- - **Tyre stacks:** the kind drifters mark a spot with.
-- - **Water tanker:** a trailer with a trough and camels at it.
-- - **Camels:** strays.
--
-- Everything is sparse on purpose. Each scene wants a flattish spot, keeps
-- clear of the others, the station and the fence, and never stands on a
-- mound's face.
-- Nothing collides. It runs after the fence, which has already waited for
-- the relief terrain to be raycastable.
local WorldConfig = require(script.Parent.WorldConfig)
local Build = require(script.Parent.Build)
local RoadNetwork = require(script.Parent.RoadNetwork)
local AssetRegistry = require(script.Parent.AssetRegistry)
local Relief = require(script.Parent.Relief)
local Station = require(script.Parent.Station)

type Config = WorldConfig.Config
type Context = RoadNetwork.Context
type Path = RoadNetwork.Path

local DuneLife = {}

local FABRICS = {
	Color3.fromRGB(140, 38, 40), -- sadu red
	Color3.fromRGB(112, 30, 36),
	Color3.fromRGB(48, 44, 60), -- indigo black
	Color3.fromRGB(170, 120, 60), -- ochre
}
-- Cushions: not the ochre, which disappears against the sand.
local CUSHIONS = { FABRICS[1], FABRICS[2], FABRICS[3] }

function DuneLife.build(cfg: Config, ctx: Context, path: Path, parent: Instance): (Folder, { [string]: number })
	local dl = cfg.duneLife
	local folder = Build.folder("DuneLife", parent)
	local counts: { [string]: number } = {}
	local border = Relief.border(cfg, ctx, path)
	if not border.enabled then
		return folder, counts
	end
	local rng = Build.rng(dl.seed)
	local totalM = RoadNetwork.lengthM(path)
	local groundY = ctx.surfaceY - ctx.s(cfg.ground.dropM)
	local stationDistance = Station.keepOutDistance(cfg, ctx, path)
	local shadows = cfg.shadows.palms
	local s = ctx.s

	local function bump(key: string)
		counts[key] = (counts[key] or 0) + 1
	end

	-- A spot on the plane at (along, lateral) metres, and the road's frame there.
	local function world(along: number, lateral: number): (Vector3, CFrame)
		local p = RoadNetwork.sample(path, math.clamp(along, 0, totalM))
		local extra = if along < 0 then along elseif along > totalM then along - totalM else 0
		local pos = p.position + p.cframe.LookVector * s(extra) + p.cframe.RightVector * s(lateral)
		return Vector3.new(pos.X, groundY, pos.Z), p.cframe
	end
	-- The same spot, on the sand.
	local function onSand(pos: Vector3): Vector3
		local y = Relief.surfaceY(Vector3.new(pos.X, groundY, pos.Z))
		return Vector3.new(pos.X, math.max(y or groundY, groundY), pos.Z)
	end

	-- Places taken, flat, with their radius in studs.
	local taken: { { pos: Vector3, r: number } } = {}
	local fromAlong = -(cfg.fence.behindStartM - dl.fenceMarginM)
	local toAlong = border.endM - dl.endMarginM

	-- A spot for something radiusM across (half width), no more than flatM
	-- from level across it, spacingM clear of everything placed. Returns
	-- the spot on the sand and the yaw that faces the road, or nil.
	local function site(radiusM: number, flatM: number, spacingM: number): (Vector3?, number)
		for _ = 1, 80 do
			local along = rng:NextNumber(fromAlong, toAlong)
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local fenceM = border.fenceAt(side, along) - dl.fenceMarginM
			local behind = along < -border.capNearM - dl.nearMarginM
			local lateralAbs = rng:NextNumber(if behind then 0 else border.nearM + dl.nearMarginM, fenceM)
			if lateralAbs > fenceM then
				continue
			end
			local lateral = side * lateralAbs
			-- Never on a mound's face.
			local moundM = border.layersAt(along, lateral)
			if moundM - border.sinkM > dl.maxMoundM then
				continue
			end
			local flat, frame = world(along, lateral)
			if stationDistance(flat) < radiusM + dl.stationGapM then
				continue
			end
			local r = s(radiusM)
			local clear = true
			for _, t in taken do
				local d = Vector3.new(t.pos.X - flat.X, 0, t.pos.Z - flat.Z).Magnitude
				if d < t.r + r + s(spacingM) then
					clear = false
					break
				end
			end
			if not clear then
				continue
			end
			local centre = onSand(flat)
			local lo, hi = centre.Y, centre.Y
			for k = 0, 5 do
				local a = k / 6 * 2 * math.pi
				local y = onSand(flat + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)).Y
				lo, hi = math.min(lo, y), math.max(hi, y)
			end
			if (hi - lo) * ctx.mps > flatM then
				continue
			end
			table.insert(taken, { pos = flat, r = r })
			-- Facing the road (behind the start line, facing the start).
			local toRoad = if behind then frame.LookVector else -frame.RightVector * side
			return centre, math.atan2(-toRoad.X, -toRoad.Z)
		end
		return nil, 0
	end

	-- PIECES --------------------------------------------------------------

	local function palm(at: Vector3)
		local p = cfg.scatter.palm
		local lean = p.leanMaxRad
		local base = CFrame.new(onSand(at))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			* CFrame.Angles(rng:NextNumber(-lean, lean), 0, rng:NextNumber(-lean, lean))
		local key = if rng:NextNumber() < p.varietyFraction then "fanPalm" else "datePalm"
		if AssetRegistry.place(key, base, rng:NextNumber(p.minScale, p.maxScale), ctx.mps, folder, shadows) then
			bump("palms")
		end
	end

	local function scrub(at: Vector3)
		local sc = cfg.scatter.scrub
		local key = AssetRegistry.scrubs[rng:NextInteger(1, #AssetRegistry.scrubs)]
		local unit = if key == "scrub" then 2 else 1.12
		local base = CFrame.new(onSand(at)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local model = AssetRegistry.place(key, base, rng:NextNumber(sc.minSizeM, sc.maxSizeM) / unit, ctx.mps, folder, false)
		if model then
			local tint = rng:NextNumber(-sc.colorVariation, sc.colorVariation)
			for _, part in model:GetChildren() do
				if part:IsA("BasePart") then
					part.Color = if tint < 0 then sc.color:Lerp(Color3.new(0, 0, 0), -tint) else sc.color:Lerp(Color3.new(1, 1, 1), tint)
				end
			end
		end
	end

	local function rock(at: Vector3, sizeM: number)
		local key = if rng:NextNumber() < 0.5 then "rockA" else "rockB"
		local base = CFrame.new(onSand(at) - Vector3.new(0, s(sizeM * 0.1), 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		AssetRegistry.place(key, base, sizeM / 1.6, ctx.mps, folder, cfg.shadows.rocks)
	end

	local function camel(at: Vector3, yaw: number)
		local base = CFrame.new(onSand(at)) * CFrame.Angles(0, yaw, 0)
		if AssetRegistry.place("camel", base, rng:NextNumber(0.9, 1.1), ctx.mps, folder, shadows) then
			bump("camels")
		end
	end

	-- A flat thing lying on the sand, following the ground's tilt a little.
	local function carpet(at: Vector3, yaw: number, sizeM: Vector2, color: Color3): Part
		local part = Build.part({
			name = "Carpet",
			size = Vector3.new(s(sizeM.X), s(0.04), s(sizeM.Y)),
			cframe = CFrame.new(onSand(at) + Vector3.new(0, s(0.03), 0)) * CFrame.Angles(0, yaw, 0),
			color = color,
			material = Enum.Material.Fabric,
			parent = folder,
		})
		local decalId = AssetRegistry.decals.carpet
		if decalId > 0 then
			local d = Instance.new("Decal")
			d.Name = "Pattern"
			d.Face = Enum.NormalId.Top
			d.Texture = `rbxassetid://{decalId}`
			d.Parent = part
		end
		return part
	end

	local function cylinder(name: string, cf: CFrame, lengthM: number, diameterM: number, color: Color3, material: Enum.Material): Part
		local part = Build.part({
			name = name,
			size = Vector3.new(s(lengthM), s(diameterM), s(diameterM)),
			cframe = cf,
			color = color,
			material = material,
			parent = folder,
		})
		part.Shape = Enum.PartType.Cylinder
		return part
	end

	-- A ring of stones, a few logs and embers, with a small warm light.
	local function fire(at: Vector3)
		local c = onSand(at)
		for k = 1, 7 do
			local a = k / 7 * 2 * math.pi
			Build.part({
				name = "FireStone",
				size = Vector3.new(s(0.2), s(0.13), s(0.16)),
				cframe = CFrame.new(c + Vector3.new(math.cos(a) * s(0.5), s(0.05), math.sin(a) * s(0.5))) * CFrame.Angles(0, -a, 0),
				color = Color3.fromRGB(70, 64, 58),
				material = Enum.Material.Slate,
				parent = folder,
			})
		end
		for k = 1, 3 do
			local a = k / 3 * math.pi + rng:NextNumber(-0.2, 0.2)
			Build.part({
				name = "FireLog",
				size = Vector3.new(s(0.09), s(0.09), s(0.7)),
				cframe = CFrame.new(c + Vector3.new(0, s(0.08 + k * 0.03), 0)) * CFrame.Angles(0, a, 0),
				color = Color3.fromRGB(46, 34, 26),
				material = Enum.Material.Wood,
				parent = folder,
			})
		end
		local ember = Build.part({
			name = "Embers",
			size = Vector3.new(s(0.45), s(0.05), s(0.45)),
			cframe = CFrame.new(c + Vector3.new(0, s(0.04), 0)),
			color = Color3.fromRGB(255, 110, 30),
			material = Enum.Material.Neon,
			parent = folder,
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 150, 70)
		-- Small and warm: a campfire, not a floodlight on the sand.
		light.Brightness = 0.6
		light.Range = s(6)
		light.Shadows = false
		light.Parent = ember
	end

	-- A tyre lying flat, centred at c.
	local function tyre(c: CFrame, scale: number)
		local base = c * CFrame.Angles(0, 0, math.pi / 2) * CFrame.new(0, -s(0.28 * scale), 0)
		AssetRegistry.place("wheel", base, scale, ctx.mps, folder, false)
	end

	-- SCENES --------------------------------------------------------------

	local function oasis()
		local c, _yaw = site(12, 1.2, dl.sceneSpacingM)
		if not c then
			return
		end
		for _ = 1, rng:NextInteger(3, 6) do
			palm(c + Vector3.new(s(rng:NextNumber(-9, 9)), 0, s(rng:NextNumber(-9, 9))))
		end
		for _ = 1, rng:NextInteger(5, 9) do
			scrub(c + Vector3.new(s(rng:NextNumber(-12, 12)), 0, s(rng:NextNumber(-12, 12))))
		end
		for _ = 1, rng:NextInteger(2, 4) do
			rock(c + Vector3.new(s(rng:NextNumber(-11, 11)), 0, s(rng:NextNumber(-11, 11))), rng:NextNumber(0.6, 1.6))
		end
		bump("oases")
	end

	local function camp()
		local c, yaw = site(10, 0.7, dl.sceneSpacingM)
		if not c then
			return
		end
		local frame = CFrame.new(c) * CFrame.Angles(0, yaw + rng:NextNumber(-0.4, 0.4), 0)
		AssetRegistry.place("tent", CFrame.new(onSand(frame.Position)) * frame.Rotation, rng:NextNumber(1.0, 1.2), ctx.mps, folder, shadows)
		carpet((frame * CFrame.new(0, 0, -s(4.4))).Position, yaw + rng:NextNumber(-0.3, 0.3), Vector2.new(3, 4.2), FABRICS[rng:NextInteger(1, #FABRICS)])
		fire((frame * CFrame.new(s(rng:NextNumber(-1, 1)), 0, -s(8))).Position)
		for i = 1, rng:NextInteger(1, 3) do
			local side = if i % 2 == 0 then 1 else -1
			camel((frame * CFrame.new(side * s(rng:NextNumber(5, 8)), 0, s(rng:NextNumber(-3, 3)))).Position, rng:NextNumber(0, math.pi * 2))
		end
		bump("camps")
	end

	local function majlis()
		local c, yaw = site(7, 0.5, dl.sceneSpacingM)
		if not c then
			return
		end
		local frame = CFrame.new(c) * CFrame.Angles(0, yaw + rng:NextNumber(-0.5, 0.5), 0)
		local fabric = FABRICS[rng:NextInteger(1, #FABRICS)]
		carpet(frame.Position, yaw, Vector2.new(5, 6), fabric)
		-- Floor cushions along three sides, backrests behind them.
		local cushion = CUSHIONS[rng:NextInteger(1, #CUSHIONS)]
		local function seat(offset: Vector3, turn: number)
			local cf = CFrame.new(onSand((frame * CFrame.new(offset)).Position)) * frame.Rotation * CFrame.Angles(0, turn, 0)
			Build.part({ name = "Cushion", size = Vector3.new(s(1.6), s(0.14), s(0.7)), cframe = cf * CFrame.new(0, s(0.1), 0), color = cushion, material = Enum.Material.Fabric, parent = folder })
			Build.part({ name = "Backrest", size = Vector3.new(s(1.6), s(0.45), s(0.22)), cframe = cf * CFrame.new(0, s(0.3), s(0.3)), color = cushion, material = Enum.Material.Fabric, parent = folder })
		end
		for _, x in { -1.7, 0, 1.7 } do
			seat(Vector3.new(s(x), 0, s(2.6)), 0)
		end
		for _, z in { -1.2, 0.6 } do
			seat(Vector3.new(-s(2.1), 0, s(z)), -math.pi / 2)
			seat(Vector3.new(s(2.1), 0, s(z)), math.pi / 2)
		end
		-- The tray: a brass dallah and a few finjan cups.
		local tray = CFrame.new(onSand(frame.Position)) * frame.Rotation * CFrame.new(0, s(0.07), s(0.3))
		cylinder("Tray", tray * CFrame.Angles(0, 0, math.pi / 2), 0.03, 0.7, Color3.fromRGB(176, 140, 72), Enum.Material.Metal)
		local brass = Color3.fromRGB(196, 158, 80)
		local pot = tray * CFrame.new(-s(0.12), 0, 0)
		cylinder("Dallah", pot * CFrame.new(0, s(0.12), 0) * CFrame.Angles(0, 0, math.pi / 2), 0.2, 0.15, brass, Enum.Material.Metal)
		Build.wedge({ name = "DallahLid", size = Vector3.new(s(0.12), s(0.09), s(0.12)), cframe = pot * CFrame.new(0, s(0.265), 0), color = brass, material = Enum.Material.Metal, parent = folder })
		Build.wedge({ name = "DallahSpout", size = Vector3.new(s(0.03), s(0.12), s(0.14)), cframe = pot * CFrame.new(0, s(0.18), -s(0.13)) * CFrame.Angles(0, math.pi, 0), color = brass, material = Enum.Material.Metal, parent = folder })
		for k = 1, 4 do
			local a = k / 4 * math.pi + 0.3
			cylinder("Finjan", tray * CFrame.new(s(0.12 + math.cos(a) * 0.16), s(0.035), s(math.sin(a) * 0.2)) * CFrame.Angles(0, 0, math.pi / 2), 0.05, 0.06, Color3.fromRGB(236, 232, 220), Enum.Material.SmoothPlastic)
		end
		fire((frame * CFrame.new(0, 0, -s(4.6))).Position)
		bump("majlis")
	end

	local function wreck()
		local c, yaw = site(6, 0.6, dl.sceneSpacingM)
		if not c then
			return
		end
		-- An old saloon, sun-faded, no wheels, sunk to its sills and tipped.
		local base = CFrame.new(c - Vector3.new(0, s(0.45), 0))
			* CFrame.Angles(0, yaw + rng:NextNumber(0, math.pi * 2), 0)
			* CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(0.05, 0.12))
		local car = AssetRegistry.place("carA", base, 1, ctx.mps, folder, true)
		if car then
			local paint = ({ Color3.fromRGB(196, 186, 164), Color3.fromRGB(150, 96, 70), Color3.fromRGB(170, 170, 160) })[rng:NextInteger(1, 3)]
			for _, part in car:GetChildren() do
				if part:IsA("BasePart") then
					if part.Material == Enum.Material.Glass then
						part.Color = Color3.fromRGB(120, 110, 92)
						part.Material = Enum.Material.SmoothPlastic
						part.Transparency = 0.25
					else
						part.Color = paint
						part.Material = Enum.Material.Sand
					end
				end
			end
		end
		-- Its tyres, one stood against it and the rest in a heap.
		local heap = base * CFrame.new(s(2.4), 0, s(1.2))
		for k = 1, rng:NextInteger(2, 4) do
			tyre(CFrame.new(onSand((heap * CFrame.new(s(rng:NextNumber(-0.3, 0.3)), 0, s(rng:NextNumber(-0.3, 0.3)))).Position) + Vector3.new(0, s(0.15 + (k - 1) * 0.3), 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), 1.25)
		end
		scrub(c + Vector3.new(s(rng:NextNumber(-4, 4)), 0, s(rng:NextNumber(-4, 4))))
		bump("wrecks")
	end

	local function tyreStacks()
		local c, _yaw = site(4, 0.5, dl.sceneSpacingM)
		if not c then
			return
		end
		for _ = 1, rng:NextInteger(1, 3) do
			local at = onSand(c + Vector3.new(s(rng:NextNumber(-3, 3)), 0, s(rng:NextNumber(-3, 3))))
			for k = 1, rng:NextInteger(3, 6) do
				tyre(CFrame.new(at + Vector3.new(s(rng:NextNumber(-0.05, 0.05)), s(0.15 + (k - 1) * 0.3), s(rng:NextNumber(-0.05, 0.05)))) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), 1.25)
			end
		end
		bump("tyreStacks")
	end

	local function waterTank()
		local c, yaw = site(9, 0.6, dl.sceneSpacingM)
		if not c then
			return
		end
		local frame = CFrame.new(c) * CFrame.Angles(0, yaw + math.pi / 2 + rng:NextNumber(-0.5, 0.5), 0)
		local chassis = frame * CFrame.new(0, s(0.75), 0)
		Build.part({ name = "TrailerBed", size = Vector3.new(s(1.8), s(0.16), s(4.6)), cframe = chassis, color = Color3.fromRGB(60, 58, 54), material = Enum.Material.Metal, parent = folder })
		Build.part({ name = "TowBar", size = Vector3.new(s(0.12), s(0.12), s(1.8)), cframe = chassis * CFrame.new(0, 0, -s(3.1)), color = Color3.fromRGB(60, 58, 54), material = Enum.Material.Metal, parent = folder })
		-- Painted steel: Metal at this colour renders as chrome.
		local tank = cylinder("WaterTank", chassis * CFrame.new(0, s(1.0), 0) * CFrame.Angles(0, math.pi / 2, 0), 4.4, 1.8, Color3.fromRGB(206, 200, 186), Enum.Material.SmoothPlastic)
		tank.CastShadow = true
		for _, x in { -1, 1 } do
			for _, z in { -0.5, 0.5 } do
				-- Wheel centre 0.38 m off the sand, just under its 0.45 m radius,
				-- so the tyres sit in the sand; the mesh's foot is 0.28 x scale
				-- below its centre.
				local wheelBase = chassis * CFrame.new(x * s(1.0), -s(0.37), s(z)) * CFrame.new(0, -s(0.28 * 1.6), 0)
				AssetRegistry.place("wheel", wheelBase, 1.6, ctx.mps, folder, false)
			end
		end
		local trough = CFrame.new(onSand((frame * CFrame.new(s(3.2), 0, 0)).Position)) * frame.Rotation
		Build.part({ name = "Trough", size = Vector3.new(s(0.7), s(0.45), s(3.2)), cframe = trough * CFrame.new(0, s(0.2), 0), color = Color3.fromRGB(90, 96, 100), material = Enum.Material.Metal, parent = folder })
		Build.part({ name = "TroughWater", size = Vector3.new(s(0.55), s(0.02), s(3.05)), cframe = trough * CFrame.new(0, s(0.4), 0), color = Color3.fromRGB(70, 110, 120), material = Enum.Material.Glass, parent = folder })
		-- Camels at the trough, each at its own place along it, heads in.
		local places = { -1.6, 0, 1.6 }
		for i = 1, rng:NextInteger(2, 3) do
			local at = trough * CFrame.new(s(1.9 + rng:NextNumber(0, 0.4)), 0, s(places[i] * 1.2))
			camel(at.Position, math.atan2(-frame.RightVector.X, -frame.RightVector.Z) + math.pi / 2 + rng:NextNumber(-0.25, 0.25))
		end
		bump("waterTanks")
	end

	local function camels()
		local c, _yaw = site(8, 1.5, dl.sceneSpacingM * 0.5)
		if not c then
			return
		end
		local heading = rng:NextNumber(0, math.pi * 2)
		for _ = 1, rng:NextInteger(2, 4) do
			camel(c + Vector3.new(s(rng:NextNumber(-7, 7)), 0, s(rng:NextNumber(-7, 7))), heading + rng:NextNumber(-0.7, 0.7))
		end
		bump("camelGroups")
	end

	for _ = 1, dl.oases do
		oasis()
	end
	for _ = 1, dl.camps do
		camp()
	end
	for _ = 1, dl.majlis do
		majlis()
	end
	for _ = 1, dl.wrecks do
		wreck()
	end
	for _ = 1, dl.tyreStacks do
		tyreStacks()
	end
	for _ = 1, dl.waterTanks do
		waterTank()
	end
	for _ = 1, dl.camelGroups do
		camels()
	end
	for _ = 1, dl.lonePalms do
		local c = site(3, 2, dl.loneSpacingM)
		if c then
			for _ = 1, rng:NextInteger(1, 2) do
				palm(c + Vector3.new(s(rng:NextNumber(-3, 3)), 0, s(rng:NextNumber(-3, 3))))
			end
		end
	end
	for _ = 1, dl.acacias do
		local c = site(4, 1.5, dl.loneSpacingM)
		if c then
			local base = CFrame.new(c) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			if AssetRegistry.place("desertTree", base, rng:NextNumber(1.0, 1.5), ctx.mps, folder, shadows) then
				bump("acacias")
			end
		end
	end

	return folder, counts
end

return DuneLife
