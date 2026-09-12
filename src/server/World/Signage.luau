--!strict
-- Overhead gantries spanning the road, roadside direction boards and
-- speed-limit signs.
--
-- The store's highway signs are all plain-part builds of US exit signs, so
-- these are modelled here from parts, properly: a gantry is a lattice
-- portal frame (twin-column legs with ties, a truss beam of two chords with
-- verticals and diagonals every bay) with green boards hung under it on
-- brackets, each board with a white border strip; a roadside sign is a
-- board on twin galvanised posts; a speed sign is a red ring and a white
-- disc on one post.
--
-- Text is a SurfaceGui with TextLabels rather than a texture: it needs no
-- asset to vet, it stays crisp at any distance, and the road names are going
-- to be replaced with real ones later, which a texture would make a re-upload
-- instead of a config edit.
--
-- Every sign is CanCollide false. A gantry leg sits outside the shoulder
-- anyway, but a car that gets up there must not be stopped by it.
local WorldConfig = require(script.Parent.WorldConfig)
local Build = require(script.Parent.Build)
local RoadNetwork = require(script.Parent.RoadNetwork)

type Config = WorldConfig.Config
type Context = RoadNetwork.Context
type Path = RoadNetwork.Path
type Sg = typeof(WorldConfig.signage)

local Signage = {}

-- Lines on a board: Arabic above, English below, a route shield or a
-- distance under that.
local function panelGui(part: BasePart, cfg: Config, arabic: string, english: string, shield: string, pixelsPerStud: number)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignFace"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	gui.LightInfluence = 0 -- readable at night without a light on it
	gui.MaxDistance = 900
	gui.Adornee = part
	gui.Parent = part

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 2)
	layout.Parent = gui

	local function line(text: string, size: number, order: number, font: Enum.Font)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, size)
		l.Text = text
		l.Font = font
		l.TextScaled = true
		l.TextColor3 = cfg.signage.textColor
		l.LayoutOrder = order
		l.Parent = gui
	end
	line(arabic, 0.36, 1, Enum.Font.GothamMedium)
	line(english, 0.3, 2, Enum.Font.GothamBold)
	line(shield, 0.2, 3, Enum.Font.GothamBold)
end

-- A sign board: the panel, a white border strip round its face, a dark
-- back. `cf` is the board's centre, Front toward the traffic.
local function board(cfg: Config, ctx: Context, parent: Instance, cf: CFrame, widthM: number, heightM: number, colour: Color3, text: { string }, pixelsPerStud: number): Part
	local sg = cfg.signage
	local w, h = ctx.s(widthM), ctx.s(heightM)
	local panel = Build.part({
		name = "Panel",
		size = Vector3.new(w, h, ctx.s(0.12)),
		cframe = cf,
		color = colour,
		material = Enum.Material.SmoothPlastic,
		parent = parent,
		castShadow = cfg.shadows.signage,
	})
	panelGui(panel, cfg, text[1], text[2], text[3], pixelsPerStud)
	local bw = ctx.s(sg.borderWidthM)
	local proud = ctx.s(0.075)
	for _, e in { { 0, h / 2 - bw / 2, w, bw }, { 0, -h / 2 + bw / 2, w, bw }, { w / 2 - bw / 2, 0, bw, h }, { -w / 2 + bw / 2, 0, bw, h } } do
		Build.part({
			name = "Border",
			size = Vector3.new(e[3], e[4], ctx.s(0.02)),
			cframe = cf * CFrame.new(e[1], e[2], -proud),
			color = sg.borderColor,
			material = Enum.Material.SmoothPlastic,
			parent = parent,
		})
	end
	-- Aluminium back with two stiffening rails.
	for _, y in { h * 0.3, -h * 0.3 } do
		Build.part({
			name = "Rail",
			size = Vector3.new(w * 0.98, ctx.s(0.08), ctx.s(0.06)),
			cframe = cf * CFrame.new(0, y, ctx.s(0.09)),
			color = sg.postColor,
			material = Enum.Material.Metal,
			parent = parent,
		})
	end
	return panel
end

-- One lattice leg: two columns with horizontal ties and a base plate.
local function leg(cfg: Config, ctx: Context, parent: Instance, foot: Vector3, along: Vector3, heightM: number)
	local sg = cfg.signage
	local col = ctx.s(sg.legColumnM)
	local spread = ctx.s(sg.legSpreadM)
	local h = ctx.s(heightM)
	for _, side in { -1, 1 } do
		local base = foot + along * (side * spread / 2)
		Build.part({
			name = "Column",
			size = Vector3.new(col, h, col),
			cframe = CFrame.new(base + Vector3.new(0, h / 2, 0)),
			color = sg.postColor,
			material = Enum.Material.Metal,
			parent = parent,
			castShadow = cfg.shadows.signage,
		})
	end
	Build.part({
		name = "BasePlate",
		size = Vector3.new(ctx.s(0.7), ctx.s(0.5), spread + ctx.s(0.7)),
		cframe = CFrame.lookAt(foot + Vector3.new(0, ctx.s(0.25), 0), foot + Vector3.new(0, ctx.s(0.25), 0) + along),
		color = Color3.fromRGB(150, 146, 138),
		material = Enum.Material.Concrete,
		parent = parent,
	})
	-- Ties every 1.6 m, and a diagonal between each pair.
	local tie = ctx.s(0.1)
	local step = ctx.s(1.6)
	local y = step
	local flip = 1
	while y < h - ctx.s(0.4) do
		local mid = foot + Vector3.new(0, y, 0)
		Build.part({
			name = "Tie",
			size = Vector3.new(tie, tie, spread),
			cframe = CFrame.lookAt(mid, mid + along),
			color = sg.postColor,
			material = Enum.Material.Metal,
			parent = parent,
		})
		local a = foot + Vector3.new(0, y, 0) + along * (-flip * spread / 2)
		local b = foot + Vector3.new(0, y + step, 0) + along * (flip * spread / 2)
		if y + step < h - ctx.s(0.4) then
			local m = (a + b) / 2
			Build.part({
				name = "Brace",
				size = Vector3.new(tie * 0.8, tie * 0.8, (b - a).Magnitude),
				cframe = CFrame.lookAt(m, b),
				color = sg.postColor,
				material = Enum.Material.Metal,
				parent = parent,
			})
		end
		flip = -flip
		y += step
	end
end

-- The truss beam between two points at the top of the legs: two chords,
-- verticals every bay and a diagonal in each bay.
local function truss(cfg: Config, ctx: Context, parent: Instance, a: Vector3, b: Vector3)
	local sg = cfg.signage
	local chord = ctx.s(sg.chordM)
	local depth = ctx.s(sg.trussDepthM)
	local brace = ctx.s(sg.braceM)
	local span = (b - a).Magnitude
	local dir = (b - a).Unit
	local mid = (a + b) / 2
	for _, y in { 0, -depth } do
		Build.part({
			name = "Chord",
			size = Vector3.new(chord, chord, span),
			cframe = CFrame.lookAt(mid + Vector3.new(0, y, 0), mid + Vector3.new(0, y, 0) + dir),
			color = sg.postColor,
			material = Enum.Material.Metal,
			parent = parent,
			castShadow = cfg.shadows.signage,
		})
	end
	local bay = ctx.s(sg.bayM)
	local n = math.max(1, math.floor(span / bay))
	local step = span / n
	for i = 0, n do
		local p = a + dir * (i * step)
		Build.part({
			name = "Vertical",
			size = Vector3.new(brace, depth, brace),
			cframe = CFrame.new(p + Vector3.new(0, -depth / 2, 0)),
			color = sg.postColor,
			material = Enum.Material.Metal,
			parent = parent,
		})
		if i < n then
			local top = if i % 2 == 0 then p else p + dir * step
			local bottom = (if i % 2 == 0 then p + dir * step else p) - Vector3.new(0, depth, 0)
			local m = (top + bottom) / 2
			Build.part({
				name = "Diagonal",
				size = Vector3.new(brace * 0.8, brace * 0.8, (top - bottom).Magnitude),
				cframe = CFrame.lookAt(m, top),
				color = sg.postColor,
				material = Enum.Material.Metal,
				parent = parent,
			})
		end
	end
end

function Signage.build(cfg: Config, ctx: Context, path: Path, parent: Instance): Folder
	local sg = cfg.signage
	local r = cfg.road
	local folder = Build.folder("Signage", parent)
	local totalM = RoadNetwork.lengthM(path)
	local standoff = r.shoulderWidthM + r.kerbWidthM + sg.setbackM
	local lay = RoadNetwork.layout(path, ctx)

	-- Overhead gantries: a lattice portal frame across the whole corridor
	-- with a centre leg in the median, a board over each carriageway.
	local gantryIndex = 0
	RoadNetwork.repeatAlong(path, ctx, sg.gantrySpacingM, sg.gantryFirstM, totalM, function(p)
		gantryIndex += 1
		local gantry = Build.folder("Gantry", folder)
		local height = ctx.s(sg.gantryHeightM)
		local reach = p.halfWidth + ctx.s(standoff)
		local right = p.cframe.RightVector
		local look = p.cframe.LookVector
		for _, x in { -reach, 0, reach } do
			leg(cfg, ctx, gantry, p.position + right * x, look, sg.gantryHeightM)
		end
		local top = p.position + Vector3.new(0, height, 0)
		truss(cfg, ctx, gantry, top - right * reach, top + right * reach)

		-- One board over each carriageway, facing the traffic that uses it,
		-- hung under the truss on two brackets.
		for _, side in { -1, 1 } do
			local text = sg.gantryTexts[(gantryIndex + (if side > 0 then 1 else 0) - 1) % #sg.gantryTexts + 1]
			local centre = p.position + right * (side * ctx.s(lay.centreM))
			local w = ctx.s(sg.panelWidthM)
			local panelCentre = centre + Vector3.new(0, height - ctx.s(sg.trussDepthM) - ctx.s(sg.panelHeightM) / 2 - ctx.s(0.3), 0)
			-- The board faces the traffic on its carriageway: on the right
			-- carriageway (side +1) that is traffic heading along the road.
			local facing = if side > 0 then -look else look
			local cf = CFrame.lookAt(panelCentre, panelCentre + facing)
			board(cfg, ctx, gantry, cf, sg.panelWidthM, sg.panelHeightM, sg.panelColor, text, 28)
			for _, bx in { -w * 0.3, w * 0.3 } do
				local bp = panelCentre + right * bx + Vector3.new(0, ctx.s(sg.panelHeightM) / 2 + ctx.s(0.15), 0)
				Build.part({
					name = "Bracket",
					size = Vector3.new(ctx.s(0.1), ctx.s(0.3), ctx.s(0.4)),
					cframe = CFrame.lookAt(bp, bp + look),
					color = sg.postColor,
					material = Enum.Material.Metal,
					parent = gantry,
				})
			end
		end
	end)

	-- Roadside boards on twin posts, alternating sides; green direction
	-- boards and blue distance boards in turn.
	if sg.roadsideEnabled then
		local index = 0
		RoadNetwork.repeatAlong(path, ctx, sg.roadsideSpacingM, sg.roadsideSpacingM, totalM, function(p)
			index += 1
			local side = if index % 2 == 0 then 1 else -1
			local sign = Build.folder("RoadsideSign", folder)
			local right = p.cframe.RightVector
			local look = p.cframe.LookVector
			local base = p.position + right * (side * (p.halfWidth + ctx.s(standoff + 1.5)))
			local postH = ctx.s(sg.roadsidePostHeightM)
			local w = ctx.s(sg.roadsideWidthM)
			for _, dx in { -w * 0.38, w * 0.38 } do
				local foot = base + right * dx
				Build.part({
					name = "SignPost",
					size = Vector3.new(ctx.s(0.09), postH, ctx.s(0.09)),
					cframe = CFrame.new(foot + Vector3.new(0, postH / 2, 0)),
					color = sg.postColor,
					material = Enum.Material.Metal,
					parent = sign,
				})
			end
			local blue = index % 2 == 0
			local text = if blue then sg.roadsideTexts[(index // 2 - 1) % #sg.roadsideTexts + 1] else sg.gantryTexts[(index // 2) % #sg.gantryTexts + 1]
			local facePos = base + Vector3.new(0, postH + ctx.s(sg.roadsideHeightM) / 2 - ctx.s(0.2), 0)
			-- Faces oncoming traffic on its own side of the road.
			local facing = if side > 0 then -look else look
			board(cfg, ctx, sign, CFrame.lookAt(facePos, facePos + facing), sg.roadsideWidthM, sg.roadsideHeightM, if blue then sg.panelBlueColor else sg.panelColor, text, 40)
		end)
	end

	-- Speed limit: a red ring and a white disc on one post, both shoulders.
	local sp = sg.speedSigns
	if sp.enabled then
		RoadNetwork.repeatAlong(path, ctx, sp.spacingM, sp.firstM, totalM, function(p)
			for _, side in { -1, 1 } do
				local sign = Build.folder("SpeedSign", folder)
				local right = p.cframe.RightVector
				local look = p.cframe.LookVector
				local base = p.position + right * (side * (p.halfWidth + ctx.s(standoff + 0.6)))
				local postH = ctx.s(sp.postHeightM)
				Build.part({
					name = "SignPost",
					size = Vector3.new(ctx.s(0.08), postH, ctx.s(0.08)),
					cframe = CFrame.new(base + Vector3.new(0, postH / 2, 0)),
					color = sg.postColor,
					material = Enum.Material.Metal,
					parent = sign,
				})
				local d = ctx.s(sp.diameterM)
				local centre = base + Vector3.new(0, postH + d / 2 - ctx.s(0.1), 0)
				local facing = if side > 0 then -look else look
				-- A cylinder's axis is X; turned so its flat face meets the traffic.
				local cf = CFrame.lookAt(centre, centre + facing) * CFrame.Angles(0, math.pi / 2, 0)
				local ring = Build.part({ name = "Ring", size = Vector3.new(ctx.s(0.04), d, d), cframe = cf, color = Color3.fromRGB(200, 30, 30), material = Enum.Material.SmoothPlastic, parent = sign })
				ring.Shape = Enum.PartType.Cylinder
				local disc = Build.part({ name = "Disc", size = Vector3.new(ctx.s(0.02), d * 0.72, d * 0.72), cframe = cf * CFrame.new(-ctx.s(0.03), 0, 0), color = Color3.fromRGB(245, 245, 240), material = Enum.Material.SmoothPlastic, parent = sign })
				disc.Shape = Enum.PartType.Cylinder
				-- The number sits on a thin square in front of the disc.
				local face = Build.part({ name = "Limit", size = Vector3.new(d * 0.5, d * 0.5, ctx.s(0.01)), cframe = CFrame.lookAt(centre, centre + facing) * CFrame.new(0, 0, -ctx.s(0.05)), color = Color3.fromRGB(245, 245, 240), material = Enum.Material.SmoothPlastic, parent = sign })
				local gui = Instance.new("SurfaceGui")
				gui.Face = Enum.NormalId.Front
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 60
				gui.LightInfluence = 0
				gui.MaxDistance = 400
				gui.Parent = face
				local l = Instance.new("TextLabel")
				l.BackgroundTransparency = 1
				l.Size = UDim2.fromScale(1, 1)
				l.Text = sp.limit
				l.Font = Enum.Font.GothamBlack
				l.TextScaled = true
				l.TextColor3 = Color3.fromRGB(20, 20, 24)
				l.Parent = gui
			end
		end)
	end

	return folder
end

return Signage
