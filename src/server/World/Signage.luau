--!strict
-- Overhead gantries spanning the road, and smaller roadside signs.
--
-- Text is a SurfaceGui with TextLabels rather than a texture: it needs no
-- asset to vet, it stays crisp at any distance, and the road names are going
-- to be replaced with real ones later, which a texture would make a re-upload
-- instead of a config edit.
--
-- Every sign is CanCollide false. A gantry post sits outside the barrier line
-- anyway, but a car that gets up there must not be stopped by it.
local WorldConfig = require(script.Parent.WorldConfig)
local Build = require(script.Parent.Build)
local RoadNetwork = require(script.Parent.RoadNetwork)

type Config = WorldConfig.Config
type Context = RoadNetwork.Context
type Path = RoadNetwork.Path

local Signage = {}

-- Two lines on a green panel: Arabic above, English below, with a small route
-- shield to the side. Placeholder names live in WorldConfig.signage.
local function panelGui(part: BasePart, cfg: Config, arabic: string, english: string, shield: string)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignFace"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 28
	gui.LightInfluence = 0 -- readable at night without a light on it
	gui.MaxDistance = 900
	gui.Adornee = part
	gui.Parent = part

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
	line(arabic, 0.34, 1, Enum.Font.GothamMedium)
	line(english, 0.3, 2, Enum.Font.GothamBold)
	line(shield, 0.2, 3, Enum.Font.GothamBold)
end

function Signage.build(cfg: Config, ctx: Context, path: Path, parent: Instance): Folder
	local sg = cfg.signage
	local r = cfg.road
	local folder = Build.folder("Signage", parent)
	local totalM = RoadNetwork.lengthM(path)
	local standoff = r.shoulderWidthM + r.kerbWidthM + cfg.barriers.offsetM + cfg.barriers.baseWidthM + 1.2

	-- Overhead gantries.
	local gantryIndex = 0
	RoadNetwork.repeatAlong(path, ctx, sg.gantrySpacingM, sg.gantryFirstM, totalM, function(p)
		gantryIndex += 1
		local gantry = Build.folder("Gantry", folder)
		local height = ctx.s(sg.gantryHeightM)
		local postW = ctx.s(sg.gantryPostWidthM)
		local reach = p.halfWidth + ctx.s(standoff)

		for _, side in { -1, 1 } do
			local base = p.position + p.cframe.RightVector * (side * reach)
			Build.part({
				name = "Post",
				size = Vector3.new(postW, height, postW),
				cframe = CFrame.new(base + Vector3.new(0, height / 2, 0)),
				color = sg.postColor,
				material = Enum.Material.Metal,
				parent = gantry,
				castShadow = cfg.shadows.signage,
			})
		end

		-- One beam across the whole span, not one per lane.
		local beamPos = p.position + Vector3.new(0, height - ctx.s(sg.gantryBeamDepthM) / 2, 0)
		Build.part({
			name = "Beam",
			size = Vector3.new(reach * 2, ctx.s(sg.gantryBeamDepthM), postW),
			cframe = CFrame.lookAt(beamPos, beamPos + p.cframe.LookVector) * CFrame.Angles(0, math.rad(90), 0),
			color = sg.postColor,
			material = Enum.Material.Metal,
			parent = gantry,
			castShadow = cfg.shadows.signage,
		})

		local text = sg.gantryTexts[(gantryIndex - 1) % #sg.gantryTexts + 1]
		local panelPos = p.position
			+ Vector3.new(0, height - ctx.s(sg.gantryBeamDepthM) - ctx.s(sg.panelHeightM) / 2, 0)
			- p.cframe.LookVector * ctx.s(0.2)
		local panel = Build.part({
			name = "Panel",
			size = Vector3.new(ctx.s(sg.panelWidthM), ctx.s(sg.panelHeightM), ctx.s(0.14)),
			-- Facing back down the road, so a driver reads it head on.
			cframe = CFrame.lookAt(panelPos, panelPos - p.cframe.LookVector),
			color = sg.panelColor,
			material = Enum.Material.Metal,
			parent = gantry,
			castShadow = cfg.shadows.signage,
		})
		panelGui(panel, cfg, text[1], text[2], text[3])
	end)

	-- Small roadside signs, alternating sides, at a lower frequency.
	if sg.roadsideEnabled then
		local index = 0
		RoadNetwork.repeatAlong(path, ctx, sg.roadsideSpacingM, sg.roadsideSpacingM, totalM, function(p)
			index += 1
			local side = if index % 2 == 0 then 1 else -1
			local base = p.position + p.cframe.RightVector * (side * (p.halfWidth + ctx.s(standoff + 1.5)))
			local postH = ctx.s(sg.roadsidePostHeightM)
			Build.part({
				name = "SignPost",
				size = Vector3.new(ctx.s(0.1), postH, ctx.s(0.1)),
				cframe = CFrame.new(base + Vector3.new(0, postH / 2, 0)),
				color = sg.postColor,
				material = Enum.Material.Metal,
				parent = folder,
			})
			local facePos = base + Vector3.new(0, postH, 0)
			Build.part({
				name = "SignFace",
				size = Vector3.new(ctx.s(sg.roadsideWidthM), ctx.s(sg.roadsideHeightM), ctx.s(0.08)),
				cframe = CFrame.lookAt(facePos, facePos - p.cframe.LookVector),
				color = sg.panelColor,
				material = Enum.Material.Metal,
				parent = folder,
				castShadow = cfg.shadows.signage,
			})
		end)
	end

	return folder
end

return Signage
