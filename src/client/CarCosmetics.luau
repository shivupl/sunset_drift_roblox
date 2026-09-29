--!strict
-- A car's garage look on this client's copy of its body (garage spec §4-5):
-- paint and finish on the painted pieces, a rim finish, head and tail lamp
-- colours, a windscreen strip and exhaust tips. The server stamps the look
-- on the car Model's `Look` attribute (CarLook); watch() applies it now and
-- on every change, so a change shows on every client without a respawn.
-- apply() also serves the garage's client-only preview car.
--
-- Everything here is visual: the strip and tips are massless, non-colliding,
-- unqueryable parts welded to the chassis, like the plates (CarPlates).
-- Stock in every slot puts back what BodyBuilder built: the originals are
-- remembered on the first apply to a body, and again whenever the model gets
-- a new body or car id (the garage preview re-mounts on the same model).
--
-- The exhaust follows one standard on every car (CarCosmeticMounts, garage
-- round 2 §1): the car's own pipes or a built factory one, or aftermarket
-- tips on pipes running forward into the body; either way an ExhaustOutlet
-- Attachment at each mouth of the exhaust fitted (only the tips once tips
-- are on), LookVector out of the pipe (outlets()).
--
-- Paint and finish need `paint = true` body pieces. The pickup and cruiser
-- are single textured shells with none, so paint does nothing on them;
-- paintable() tells the garage panel to grey those out. Owner follow-up:
-- a paint split of those shells in CarCatalog (garage plan, task 3 fix 1).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetService = game:GetService("AssetService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleRig = require(Shared:WaitForChild("VehicleRig"))
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local CarLook = require(Shared:WaitForChild("CarLook"))
local CarLamps = require(Shared:WaitForChild("CarLamps"))
local CarCosmeticMounts = require(Shared:WaitForChild("CarCosmeticMounts"))
local CarStripShapes = require(Shared:WaitForChild("CarStripShapes"))
local UITheme = require(Shared:WaitForChild("UITheme"))
local CosmeticsConfig = require(Shared:WaitForChild("CosmeticsConfig"))
local MeshData = require(Shared:WaitForChild("MeshData"))
local ExhaustTips = require(Shared:WaitForChild("CosmeticMeshes"):WaitForChild("ExhaustTips"))

local CarCosmetics = {}

local R = CosmeticsConfig.render

-- The exhaust outlets' names (outlets()): the flame contract.
local OUTLET = "ExhaustOutlet"
local OUTLETS = "ExhaustOutlets"

type Original = { part: BasePart, color: Color3, material: Enum.Material, reflectance: number, transparency: number, sa: SurfaceAppearance?, saColor: Color3? }
-- A window piece and its role (CarCosmeticMounts windows).
type WindowRole = "side" | "screen" | "whole"
type Window = { o: Original, role: WindowRole }

-- The built sun strip: one slat Part per CarStripShapes entry in a folder,
-- each with its own canvas (the whole strip, shifted to its slice).
type Slat = { part: Part, canvas: Frame, gradient: UIGradient, label: TextLabel, along: number }
type Strip = { folder: Folder, slats: { Slat } }

type State = {
	body: Instance,
	carId: string,
	paint: { Original },
	rims: { Original },
	windows: { Window },
	strip: Strip?,
	exhaust: Folder?,
	tipStyle: string?, -- the tip style whose template this car holds (acquireTip)
	-- Bumped whenever the car's tips are taken off (a new look, a new body,
	-- the model going): an exhaust build that yielded for a template checks it
	-- afterwards and drops a stale result (garage round 3 fix 2).
	exhaustGen: number,
	-- The exhaust item this car's tips were built for (or are being built
	-- for, while exhaustBuilding holds that build's generation): a look
	-- change that leaves the exhaust as it is does not rebuild it (final
	-- review I1: each paint click rebuilt the tips and, as their only
	-- wearer, their EditableMesh).
	exhaustItem: string?,
	exhaustBuilding: number?,
}

local states: { [Model]: State } = {}
local watching: { [Model]: RBXScriptConnection } = {}

local function remember(part: BasePart): Original
	local sa = part:FindFirstChildOfClass("SurfaceAppearance")
	return {
		part = part,
		color = part.Color,
		material = part.Material,
		reflectance = part.Reflectance,
		transparency = part.Transparency,
		sa = sa,
		saColor = if sa then sa.Color else nil,
	}
end

-- The painted pieces (BodyBuilder stamps `Painted`) and the rim pieces:
-- wheel pieces named *Rim* (not a Rim_Disc, which is the brake disc behind
-- the rim), or, on a car without one, its Metal wheel pieces.
local function collect(body: Instance, carId: string): State
	local entry = ConfigLoader.entry(carId)
	local wheelNames: { [string]: boolean } = {}
	for _, piece in entry.body.wheelPieces do
		for _, w in VehicleRig.WHEELS do
			wheelNames[`{piece.name}_{w.name}`] = true
		end
	end
	local s: State = { body = body, carId = carId, paint = {}, rims = {}, windows = {}, exhaustGen = 0 }
	local mounts = CarCosmeticMounts.cars[carId]
	local windows = mounts and mounts.windows
	local function addWindows(names: { string }?, role: WindowRole)
		if not names then
			return
		end
		for _, name in names do
			local part = body:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				table.insert(s.windows, { o = remember(part), role = role })
			end
		end
	end
	if windows then
		addWindows(windows.side, "side")
		addWindows(windows.screen, "screen")
		addWindows(windows.whole, "whole")
	end
	local metal: { Original } = {}
	for _, part in body:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		if part:GetAttribute("Painted") == true then
			table.insert(s.paint, remember(part))
		elseif wheelNames[part.Name] then
			local lower = string.lower(part.Name)
			if string.find(lower, "rim", 1, true) and not string.find(lower, "disc", 1, true) then
				table.insert(s.rims, remember(part))
			elseif part.Material == Enum.Material.Metal then
				table.insert(metal, remember(part))
			end
		end
	end
	if #s.rims == 0 then
		s.rims = metal
	end
	return s
end

-- A finish's colour treatment (CosmeticsConfig FINISH): value and
-- saturation lowered by its darken and desaturate.
local function treat(c: Color3, finish: CosmeticsConfig.Item): Color3
	if not finish.darken and not finish.desaturate then
		return c
	end
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s * (1 - (finish.desaturate or 0)), v * (1 - (finish.darken or 0)))
end

local function paint(s: State, look: CarLook.Look)
	local colour = CarLook.item(look, "paint").color
	local finish = CarLook.item(look, "finish")
	for _, o in s.paint do
		local c = colour or o.color
		if o.sa then
			-- A SurfaceAppearance carries its own material maps: it takes
			-- the colour only.
			o.sa.Color = colour or (o.saColor :: Color3)
			continue
		end
		o.part.Color = treat(c, finish)
		o.part.Material = finish.material or o.material
		o.part.Reflectance = if finish.material then finish.reflectance or 0 else o.reflectance
	end
end

local function rims(s: State, look: CarLook.Look)
	local item = CarLook.item(look, "rims")
	for _, o in s.rims do
		if o.sa then
			o.sa.Color = item.color or (o.saColor :: Color3)
			continue
		end
		o.part.Color = item.color or o.color
		o.part.Material = item.material or o.material
		o.part.Reflectance = if item.material then item.reflectance or 0 else o.reflectance
	end
end

-- Window tint (CosmeticsConfig TINT): the film's colour on SmoothPlastic, at
-- its transparency for the piece's role; an all-round piece takes halfway
-- between the side and windscreen values. SmoothPlastic whatever the
-- factory glass was: a Glass-material piece reads by its colour (the
-- krownvik's is white at 0.3 and looks clear), so a dark film on Glass went
-- pitch black at the same transparency (lab check, 2026-09-28). Stock puts
-- every piece back as it was built.
local function tint(s: State, look: CarLook.Look)
	local item = CarLook.item(look, "tint")
	local side, screen = item.glassTransparency, item.screenTransparency
	for _, w in s.windows do
		local o = w.o
		if o.sa then
			-- A SurfaceAppearance piece keeps its own maps; tint would not read
			-- on it. CarCosmeticMounts.spec keeps such pieces out of windows.
			continue
		end
		if item.glassColor and side and screen then
			o.part.Color = item.glassColor
			o.part.Material = Enum.Material.SmoothPlastic
			o.part.Transparency = if w.role == "side" then side elseif w.role == "screen" then screen else (side + screen) / 2
		else
			o.part.Color = o.color
			o.part.Material = o.material
			o.part.Transparency = o.transparency
		end
	end
end

local function lamps(model: Model, look: CarLook.Look)
	model:SetAttribute(CarLamps.LOOK_HEAD, CarLook.item(look, "head").color)
	model:SetAttribute(CarLamps.LOOK_TAIL, CarLook.item(look, "tail").color)
	CarLamps.apply(model)
end

-- A part that is only ever seen: welded to the chassis at the body mount
-- plus this offset, and nothing to the physics.
local function dress<P>(part: P & BasePart, name: string, handles: VehicleRig.Handles, offset: CFrame): P
	part.Name = name
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.EnableFluidForces = false
	part.CastShadow = false
	part.CFrame = handles.bodyMount.WorldCFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handles.chassis
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function visualPart(name: string, handles: VehicleRig.Handles, offset: CFrame): Part
	return dress(Instance.new("Part"), name, handles, offset)
end

-- The sun strip (garage round 3 §3): slats moulded to the windscreen
-- (CarStripShapes, generated from each car's glass mesh), each a flat card
-- at its spot on the glass with a SurfaceGui that shows its own slice of the
-- one strip canvas: a clipping frame holding the whole canvas (gradient and
-- text) shifted left by where the slat starts, so text and gradient run on
-- across slats. Neighbours overlap a hair (CosmeticsConfig.render
-- stripOverlapM), so no seam shows.
local function slat(shape: CarStripShapes.Shape, sl: CarStripShapes.Slat, i: number, folder: Folder, handles: VehicleRig.Handles, f: number): Slat
	local c, n, r = sl.centreM, sl.normal, sl.right
	local right = Vector3.new(r[1], r[2], r[3])
	local back = -Vector3.new(n[1], n[2], n[3])
	-- right x up = back, so the Front face (-Z) looks out along the normal.
	local offset = CFrame.fromMatrix(Vector3.new(c[1], c[2], c[3]) * f, right, back:Cross(right), back)
	local part = visualPart(`Slat{i}`, handles, offset)
	part.Size = Vector3.new(sl.widthM, sl.heightM, R.stripThicknessM) * f
	-- Opaque, in the strip's colour: a SurfaceGui on a fully transparent
	-- part behind the (transparent) windscreen does not draw at all.
	part.Material = Enum.Material.SmoothPlastic
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(sl.widthM, sl.heightM) * R.stripPixelsPerM
	gui.LightInfluence = 1 -- lit like the car, not glowing at night
	gui.MaxDistance = R.stripDrawStuds
	gui.Parent = part
	local clip = Instance.new("Frame")
	clip.Size = UDim2.fromScale(1, 1)
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Parent = gui
	local canvas = Instance.new("Frame")
	-- In scale, not pixels: UDim offsets are whole pixels, so each slat's
	-- shift would round on its own and neighbours could repeat or skip a
	-- column (up to 2.5 mm) where a letter crosses a join (fix round 1, M1).
	canvas.Size = UDim2.fromScale(shape.lengthM / sl.widthM, 1)
	canvas.Position = UDim2.fromScale(-sl.fromM / sl.widthM, 0)
	canvas.BorderSizePixel = 0
	canvas.Parent = clip
	local gradient = Instance.new("UIGradient")
	gradient.Parent = canvas
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.92, 0.8)
	label.TextScaled = true
	label.FontFace = UITheme.font("display")
	label.Parent = canvas
	part.Parent = folder
	-- Where the slat's middle sits along the canvas, 0 to 1: its own colour
	-- (its thin sides) is the gradient's there.
	local along = math.clamp((sl.fromM + sl.widthM / 2) / shape.lengthM, 0, 1)
	return { part = part, canvas = canvas, gradient = gradient, label = label, along = along }
end

local function strip(s: State, model: Model, body: Instance, carId: string, look: CarLook.Look)
	local item = CarLook.item(look, "decal")
	local mounts = CarCosmeticMounts.cars[carId]
	local shape = if mounts and mounts.windscreen then CarStripShapes[carId] else nil
	if not shape or item.stripColor == nil then
		-- None means none: the slats go, and are built again when a strip is.
		if s.strip then
			s.strip.folder:Destroy()
			s.strip = nil
		end
		return
	end
	if s.strip and s.strip.folder.Parent ~= body then
		s.strip = nil -- destroyed with its body or by someone else
	end
	if not s.strip then
		local handles = VehicleRig.handles(model)
		local k = VehicleRig.scaleOf(ConfigLoader.entry(carId))
		local mps = ConfigLoader.forCar(carId).units.metersPerStud
		local folder = Instance.new("Folder")
		folder.Name = "LookStrip"
		local slats = {}
		for i, sl in shape.slats do
			table.insert(slats, slat(shape, sl, i, folder, handles, k / mps))
		end
		folder.Parent = body
		s.strip = { folder = folder, slats = slats }
	end
	local st = s.strip :: Strip
	local c1 = item.stripColor :: Color3
	local c2 = item.stripColor2 or c1
	local colors = ColorSequence.new(c1, c2)
	local text = item.text or ""
	for _, sl in st.slats do
		sl.part.Transparency = 0
		-- The slat's sides show its part colour: the gradient's colour there,
		-- so a gradient strip has no amber rim along its purple end.
		sl.part.Color = c1:Lerp(c2, sl.along)
		sl.canvas.BackgroundColor3 = Color3.new(1, 1, 1)
		sl.gradient.Color = colors
		sl.label.Text = text
		sl.label.TextColor3 = item.textColor or Color3.new(1, 1, 1)
		sl.label.Visible = text ~= ""
	end
end

-- A pipe or tip: a cylinder along the car's Z (a Cylinder's axis is its X;
-- turned a quarter about Y it runs along Z), centred at `at` (car metres),
-- `length` long. s is studs per car metre.
local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0)
local function cylinder(name: string, handles: VehicleRig.Handles, s: number, at: Vector3, length: number, radius: number): Part
	local part = visualPart(name, handles, CFrame.new(at * s) * ALONG_Z)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(length, radius * 2, radius * 2) * s
	return part
end

-- The dark bore of a pipe whose open end is at z: as long as the pipe's
-- visible length, flush with (2 mm past) its open end, hidden inside it
-- everywhere else, so the mouth reads as a hole.
local function bore(name: string, handles: VehicleRig.Handles, s: number, x: number, y: number, z: number, length: number, radius: number): Part
	local part = cylinder(name, handles, s, Vector3.new(x, y, z + 0.002 - length / 2), length, radius)
	part.Color = R.boreColor
	part.Material = Enum.Material.SmoothPlastic
	return part
end

-- A generated tip mesh (tools/cosmetics/exhaust_tips.py): the MeshData piece
-- plus where its pipe goes in and its bores, in its own tip space (mouth at
-- the origin, +Z out of the mouth; the quad's pair mesh in pair space).
type TipBore = ExhaustTips.Bore
type TipMesh = ExhaustTips.TipPiece
type TipStyle = CosmeticsConfig.TipStyle

local function tipMesh(name: string): TipMesh
	local piece = ExhaustTips.pieces[name]
	assert(piece, `[CarCosmetics] no tip mesh {name}`)
	return piece
end

-- Tip templates, one per style, shared by every car on this client. A style
-- built from its generated mesh holds an EditableMesh, and a client holds
-- only 8 (BEHAVIOURS: destroying the EditableMesh frees its slot but blanks
-- every MeshPart made from it). So each is counted by the cars wearing it
-- and freed with its EditableMesh when the last one takes it off, and made
-- only while render.tipMeshReserve slots stay free for car bodies after it.
-- A style with a meshAssetId is built from the uploaded asset instead: no
-- EditableMesh, kept for the session.
--
-- Making one yields (CreateMeshPartAsync), and several cars can ask for the
-- same style at once (each car's watch runs in its own thread), so a build is
-- single-flight (garage round 3 fix 2): the first asker puts a pending entry
-- in before it yields, later askers count themselves on it and wait for the
-- same result. users counts every holder, pending or not; a release while
-- the build is under way is settled when it lands.
type TipTemplate = {
	part: MeshPart?,
	em: EditableMesh?,
	users: number,
	pending: boolean,
	done: BindableEvent,
}
local tipTemplates: { [string]: TipTemplate } = {}
local warned: { [string]: boolean } = {}
-- Set when a slot probe comes up short; cleared when a tip template frees a
-- slot. Until then no style probes again, so a client at the cap stops
-- printing the engine's "Failed to create empty EditableMesh" per probe.
local probeShort = false

-- The EditableMesh slots tips leave free for car bodies: the most any
-- catalog car's generated pieces take (each distinct generated mesh path is
-- one template, MeshData / BodyBuilder), or render.tipMeshReserve if that is
-- more. Worked out once from the catalog, so a car added later is covered.
local reserveCache: number? = nil
local function tipMeshReserve(): number
	if reserveCache then
		return reserveCache
	end
	local most = 0
	for id in ConfigLoader.catalog().cars do
		local body = ConfigLoader.entry(id).body
		local paths: { [string]: boolean } = {}
		local count = 0
		local function add(piece: any)
			if piece.mesh and not piece.meshId and not paths[piece.mesh] then
				paths[piece.mesh] = true
				count += 1
			end
		end
		for _, piece in body.pieces do
			add(piece)
		end
		for _, piece in body.wheelPieces do
			add(piece)
		end
		most = math.max(most, count)
	end
	local reserve = math.max(most, R.tipMeshReserve)
	reserveCache = reserve
	return reserve
end

-- How many EditableMeshes could still be made, counting to `upTo`: made and
-- destroyed at once (an empty one is enough; the cap is a count).
local function freeMeshSlots(upTo: number): number
	local made: { EditableMesh } = {}
	for _ = 1, upTo do
		local ok, em = pcall(function(): EditableMesh?
			return AssetService:CreateEditableMesh()
		end)
		if not ok or not em then
			break
		end
		table.insert(made, em)
	end
	for _, em in made do
		em:Destroy()
	end
	return #made
end

local PART_OPTIONS = {
	CollisionFidelity = Enum.CollisionFidelity.Box,
	RenderFidelity = Enum.RenderFidelity.Precise,
}

-- Builds a style's template: (part, em) or (nil, nil, why). Never leaves an
-- EditableMesh behind on failure.
local function buildTip(style: TipStyle): (MeshPart?, EditableMesh?, string?)
	if style.meshAssetId then
		local ok, part = pcall(function(): MeshPart
			-- Automatic: an uploaded mesh gets the engine's distance LODs,
			-- which a tip a few centimetres across can take.
			return AssetService:CreateMeshPartAsync(Content.fromUri(`rbxassetid://{style.meshAssetId}`), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
				RenderFidelity = Enum.RenderFidelity.Automatic,
			})
		end)
		if ok then
			-- The importer's half turn (render.uploadedTipTurnDeg); meshAt
			-- turns every clone back.
			part:SetAttribute("TipTurnDeg", R.uploadedTipTurnDeg)
			if style.textureAssetId then
				part.TextureID = `rbxassetid://{style.textureAssetId}`
			end
			return part, nil, nil
		end
		return nil, nil, tostring(part)
	end
	local reserve = tipMeshReserve()
	if probeShort or freeMeshSlots(reserve + 1) < reserve + 1 then
		probeShort = true
		return nil, nil, `fewer than {reserve} EditableMesh slots would stay free`
	end
	local okEm, em = pcall(MeshData.editable, tipMesh(style.mesh))
	if not okEm then
		return nil, nil, tostring(em)
	end
	local ok, part = pcall(function(): MeshPart
		return AssetService:CreateMeshPartAsync(Content.fromObject(em), PART_OPTIONS)
	end)
	if not ok then
		em:Destroy() -- a failed part must not keep its slot
		return nil, nil, tostring(part)
	end
	return part, em, nil
end

local function destroyTemplate(name: string, t: TipTemplate)
	if tipTemplates[name] == t then
		tipTemplates[name] = nil
	end
	if t.part then
		t.part:Destroy()
	end
	if t.em then
		t.em:Destroy()
		probeShort = false -- a slot came free
	end
end

-- Holds a style's template for one car: its part, or nil (cylinder tips; the
-- hold is then not kept). May yield.
local function acquireTip(name: string, style: TipStyle): MeshPart?
	local t = tipTemplates[name]
	if t then
		t.users += 1
		if t.pending then
			t.done.Event:Wait()
		end
		if t.part then
			return t.part
		end
		t.users -= 1 -- the build this caller waited on failed
		return nil
	end
	local entry: TipTemplate = { part = nil, em = nil, users = 1, pending = true, done = Instance.new("BindableEvent") }
	tipTemplates[name] = entry
	local part, em, why = buildTip(style)
	entry.pending = false
	entry.part, entry.em = part, em
	if not part then
		tipTemplates[name] = nil
		entry.users = 0
		if not warned[name] then
			warned[name] = true
			warn(`[CarCosmetics] tip style {name}: cylinder tips instead ({why})`)
		end
	end
	entry.done:Fire()
	if part and entry.users <= 0 and em then
		-- Everyone who asked let go while it was being made (their cars were
		-- restyled or destroyed during the yield).
		destroyTemplate(name, entry)
		return nil
	end
	return part
end

local function releaseTip(name: string)
	local t = tipTemplates[name]
	if not t then
		return
	end
	t.users -= 1
	if t.users <= 0 and not t.pending and t.em then
		destroyTemplate(name, t)
	end
end

-- Takes a car's tips off: its folder and its hold on a tip template. Any
-- exhaust build still waiting on a template for this car is now stale.
local function clearExhaust(s: State)
	s.exhaustGen += 1
	s.exhaustItem = nil
	s.exhaustBuilding = nil
	if s.exhaust then
		s.exhaust:Destroy()
		s.exhaust = nil
	end
	if s.tipStyle then
		releaseTip(s.tipStyle)
		s.tipStyle = nil
	end
end

-- A cylinder along a frame's Z (car metres), centred on it, `length` long,
-- scaled by s: the fallback tip and its bore, turned like the tip would be.
local function cylinderAt(name: string, handles: VehicleRig.Handles, s: number, frame: CFrame, length: number, radius: number): Part
	local part = visualPart(name, handles, CFrame.new(frame.Position * s) * frame.Rotation * ALONG_Z)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(length, radius * 2, radius * 2) * s
	return part
end

-- A clone of a tip template at `frame` (car metres, tip space: +Z out of the
-- mouth) scaled by s (studs per car metre), welded like any visual part.
local function meshAt(name: string, template: MeshPart, mesh: TipMesh, handles: VehicleRig.Handles, s: number, frame: CFrame): MeshPart
	local o = mesh.offsetM
	local part = template:Clone()
	part.Size = Vector3.new(mesh.sizeM[1], mesh.sizeM[2], mesh.sizeM[3]) * s
	local turn = template:GetAttribute("TipTurnDeg")
	local at = frame * CFrame.new(o[1], o[2], o[3]) * CFrame.Angles(0, math.rad(if type(turn) == "number" then turn else 0), 0)
	return dress(part, name, handles, CFrame.new(at.Position * s) * at.Rotation)
end

-- A tip's bore: a flat dark disc closing the tip's open mesh at its floor,
-- 2 mm bigger than the inner wall so no seam shows, turned with the slash cut
-- where there is one. A Part with a sphere SpecialMesh 1 cm deep: that
-- stretches to an oval, where a cylinder SpecialMesh stays round (the Big
-- Oval showed a round disc in an oval mouth, Studio 2026-09-28).
local BORE_DISC_M = 0.01
local function boreDisc(name: string, handles: VehicleRig.Handles, s: number, frame: CFrame, b: TipBore): Part
	local at = frame
		* CFrame.new(b.xM, 0, b.zM)
		* CFrame.Angles(math.rad(b.tiltDeg), 0, 0)
		* CFrame.new(0, 0, -BORE_DISC_M / 2)
	local part = dress(Instance.new("Part"), name, handles, CFrame.new(at.Position * s) * at.Rotation)
	part.Size = Vector3.new((b.radiusM[1] + 0.002) * 2, (b.radiusM[2] + 0.002) * 2, BORE_DISC_M) * s
	part.Color = R.tipBoreColor
	part.Material = Enum.Material.SmoothPlastic
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- The pipes' bend knobs, as CarCosmeticMounts.pipeRoute takes them.
local BEND = CarCosmeticMounts.pipeBend(R)

-- A cylinder from a to b (car metres), scaled by s.
local function between(name: string, handles: VehicleRig.Handles, s: number, a: Vector3, b: Vector3, radius: number): Part
	-- Up is X: a pipe never runs across the car, and a cylinder's roll does
	-- not show.
	local look = CFrame.lookAt((a + b) / 2, b, Vector3.xAxis)
	local part = visualPart(name, handles, CFrame.new(look.Position * s) * look.Rotation * ALONG_Z)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new((b - a).Magnitude, radius * 2, radius * 2) * s
	return part
end

-- A routed pipe (garage round 3 §2, CarCosmeticMounts.pipeRoute): straight
-- forward from the tip's inlet (or a factory pipe's mouth), then bent up into
-- the body, its end hidden there, with a small rubber hanger on the straight.
-- Plain Parts (controller ruling: EditableMeshes are too few): a cylinder per
-- straight or bend chord, a ball the pipe's size at every joint so the bend
-- reads smooth. The first cylinder, the one at the tip or mouth, is named
-- `first` (the factory pipe's is the one flames glow on); the rest `rest`_k.
local function routedPipe(folder: Folder, first: string, rest: string, handles: VehicleRig.Handles, s: number, route: CarCosmeticMounts.PipeRoute, radius: number, color: Color3)
	local function paint(part: Part)
		part.Color = color
		part.Material = Enum.Material.Metal
		part.Parent = folder
	end
	for k, seg in route.segments do
		paint(between(if k == 1 then first else `{rest}_{k}`, handles, s, seg.a, seg.b, radius))
	end
	for k, p in route.joints do
		local ball = visualPart(`{rest}Joint{k}`, handles, CFrame.new(p * s))
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.one * radius * 2 * s
		paint(ball)
	end
	local h = route.hanger
	if h then
		local height = (h.b - h.a).Magnitude
		local hanger = visualPart(`{rest}Hanger`, handles, CFrame.new((h.a + h.b) / 2 * s))
		hanger.Size = Vector3.new(R.hangerWidthM, height, R.hangerThickM) * s
		hanger.Color = R.hangerColor
		hanger.Material = Enum.Material.Rubber
		hanger.Parent = folder
	end
end

-- The exhaust fitted to the car (garage round 2 §1, the exhaust standard):
-- stock (no tips) builds a plain pipe at each stock outlet whose body has
-- none (factory = true) and leaves the car's own pipes be; tips build each
-- modelled tip (garage round 3 §1: the item's tipStyle, its mesh's mouth on
-- CarCosmeticMounts.tipFrames, a dark disc closing its bore) and the pipe
-- it sits on, running forward under the car and bending up into the body
-- (garage round 3 §2, routedPipe; a tip over one of the car's own pipes
-- hides that pipe's mouth inside it). Factory pipes are routed the same
-- way. A quad is two pair meshes, each on its own Y inlet with one pipe: a
-- quad car has two pipes. Without a tip mesh (acquireTip) the tips are round
-- 2's cylinders, their pipes routed the same way.
-- One ExhaustOutlet Attachment goes at each mouth of the exhaust fitted: the
-- stock outlets, or with tips on only the tips (they replace the whole
-- exhaust; an own pipe left showing, like the hatch's, gets none)
-- (CarCosmeticMounts.outletFrames), on an invisible part welded at the body
-- mount: flames and any other exhaust effect use only those (outlets()).
local function exhaust(s: State, model: Model, body: Instance, carId: string, look: CarLook.Look)
	local item = CarLook.item(look, "exhaust")
	-- Unchanged (same item on the same body, built or being built): leave it.
	-- A new body or car gets a new state (apply), so only the item can differ.
	if s.exhaustItem == item.id and (s.exhaustBuilding ~= nil or (s.exhaust ~= nil and s.exhaust.Parent == body)) then
		return
	end
	-- This build supersedes any still waiting on a template. The old tips
	-- stay on (and keep their hold on their template) until this one is ready,
	-- so a style going onto its own last wearer is never dropped and rebuilt.
	s.exhaustGen += 1
	local gen = s.exhaustGen
	s.exhaustItem = item.id
	s.exhaustBuilding = gen
	local function takeOffOld()
		if s.exhaust then
			s.exhaust:Destroy()
			s.exhaust = nil
		end
		if s.tipStyle then
			releaseTip(s.tipStyle)
			s.tipStyle = nil
		end
	end
	local mounts = CarCosmeticMounts.cars[carId]
	local spot = mounts and mounts.exhaust
	if not spot then
		takeOffOld()
		s.exhaustBuilding = nil
		return
	end
	local n = item.tips or 0
	local handles = VehicleRig.handles(model)
	local k = VehicleRig.scaleOf(ConfigLoader.entry(carId))
	local mps = ConfigLoader.forCar(carId).units.metersPerStud
	local sc = k / mps
	local folder = Instance.new("Folder")
	folder.Name = "LookExhaust"
	if n > 0 then
		local styleName = if item.tipStyle and R.tipStyles[item.tipStyle] then item.tipStyle else "rolled"
		local style = R.tipStyles[styleName]
		local mesh = tipMesh(style.mesh)
		local colour = if style.baked then R.bakedTipColor else item.tipColor or Color3.fromRGB(200, 200, 200)
		local material = item.tipMaterial or Enum.Material.Metal
		local template = acquireTip(styleName, style)
		-- acquireTip may have yielded: if the car was restyled again, re-bodied
		-- or destroyed meanwhile, this build is stale. Let go of what it took
		-- and leave the newer build (or nothing) in place.
		if s.exhaustGen ~= gen or states[model] ~= s or not body.Parent then
			if template then
				releaseTip(styleName)
			end
			folder:Destroy()
			return
		end
		-- The new hold is in; now the old tips can go (same style: its users
		-- went up then down, so the template stays).
		takeOffOld()
		if template then
			s.tipStyle = styleName
		end
		-- Pair or single comes from the style alone (CosmeticsConfig.spec
		-- holds pair to exactly the quad items): the pieces, their pipes and
		-- the fallback's pipes all follow it (CarCosmeticMounts.pieceFrames).
		local paired = style.pair == true
		-- Each pipe's inlet frame (CarCosmeticMounts.pipeInlets, the same the
		-- spec walks): one per tip, or one per quad pair.
		local inlets: { CFrame }
		if template then
			local inletM = Vector3.new(mesh.inletM[1], mesh.inletM[2], mesh.inletM[3])
			inlets = CarCosmeticMounts.pipeInlets(spot, n, R, inletM, paired)
			local frames = CarCosmeticMounts.pieceFrames(spot, n, R.quadPairGapM, paired)
			for i, frame in frames do
				local tip = meshAt(if paired then `TipPair{i}` else `Tip{i}`, template, mesh, handles, sc, frame)
				tip.Color = colour
				tip.Material = material
				tip.Parent = folder
				for j, b in mesh.bores do
					local id = if paired then (i - 1) * 2 + j else i
					boreDisc(`Bore{id}`, handles, sc, frame, b).Parent = folder
				end
			end
		else
			-- The fallback: round 2's cylinder tips, one per mouth, as long as
			-- a rolled tip (mouth to collar), turned with the tip frame (a quad
			-- pair's yaw included, so flames leave along the cylinder). Pipes as
			-- the mesh tips have them: one per tip, one per quad pair (its pipe
			-- starts between the pair's two cylinders, overlapping both).
			local len = -tipMesh("Rolled").inletM[3]
			local back = Vector3.new(0, 0, -len)
			inlets = CarCosmeticMounts.pipeInlets(spot, n, R, back, paired)
			for i, f in CarCosmeticMounts.tipFrames(spot, n, R.quadPairGapM) do
				local tip = cylinderAt(`Tip{i}`, handles, sc, f * CFrame.new(0, 0, -len / 2), len, R.tipRadiusM)
				tip.Color = colour
				tip.Material = material
				tip.Parent = folder
				local core = cylinderAt(`Bore{i}`, handles, sc, f * CFrame.new(0, 0, 0.002 - len / 2), len, R.tipRadiusM - 0.012)
				core.Color = R.boreColor
				core.Material = Enum.Material.SmoothPlastic
				core.Parent = folder
			end
		end
		-- Every pipe runs forward to where round 2 measured it (pipeRunFromM),
		-- then bends up riseM into the body (garage round 3 §2).
		local frontZ = CarCosmeticMounts.pipeFrontZ(spot, R)
		for i, inlet in inlets do
			local route = CarCosmeticMounts.pipeRoute(inlet.Position, inlet.ZVector, R.pipeOverlapM, frontZ, spot.riseM, R.pipeRadiusM, BEND)
			routedPipe(folder, `Pipe{i}`, `Pipe{i}`, handles, sc, route, R.pipeRadiusM, R.pipeColor)
		end
	else
		takeOffOld()
		for i, o in spot.stock do
			if not o.factory then
				continue
			end
			local x, y, z = o.posM[1], o.posM[2], o.posM[3]
			local len = o.pipeLengthM or spot.tips.pipeLengthM
			-- Routed like the tips' pipes, from its mouth: FactoryPipe{i} is the
			-- straight at the mouth (the part flames glow), Factory{i}_k the rest.
			local route = CarCosmeticMounts.pipeRoute(Vector3.new(x, y, z), Vector3.zAxis, 0, z - len, o.riseM or spot.riseM, R.factoryPipeRadiusM, BEND)
			routedPipe(folder, `FactoryPipe{i}`, `Factory{i}`, handles, sc, route, R.factoryPipeRadiusM, R.factoryPipeColor)
			bore(`FactoryBore{i}`, handles, sc, x, y, z, len, R.factoryBoreRadiusM).Parent = folder
		end
	end
	-- The outlets' holder: invisible, at the body mount, so each outlet's
	-- CFrame is its car-space frame in studs.
	local holder = visualPart(OUTLETS, handles, CFrame.identity)
	holder.Size = Vector3.one * 0.05
	holder.Transparency = 1
	for _, frame in CarCosmeticMounts.outletFrames(spot, n, R.quadPairGapM) do
		local a = Instance.new("Attachment")
		a.Name = OUTLET
		a.CFrame = CarCosmeticMounts.toStuds(frame, k, mps)
		a.Parent = holder
	end
	holder.Parent = folder
	folder.Parent = body
	s.exhaust = folder
	s.exhaustBuilding = nil
end

-- The car's exhaust outlets, for flames and any other exhaust effect: one
-- Attachment per pipe mouth of the exhaust fitted now (stock or tips), at the
-- centre of the mouth. Orientation convention: WorldCFrame.LookVector (the
-- attachment's -Z, Enum.NormalId.Front) points out of the pipe, the way the
-- gas leaves, following the pipe (out of the tip for tips, the stock pipe's
-- own angle where it has one); UpVector is as near car-up as that allows. A
-- ParticleEmitter under one with EmissionDirection = Front shoots out of the
-- pipe. Rebuilt (new instances) whenever the look changes; empty on a car
-- with no built body or no exhaust spot.
function CarCosmetics.outlets(model: Model): { Attachment }
	local out: { Attachment } = {}
	local ok, handles = pcall(VehicleRig.handles, model)
	local body = if ok then handles.body else nil
	local folder = body and body:FindFirstChild("LookExhaust")
	local holder = folder and folder:FindFirstChild(OUTLETS)
	if not holder then
		return out
	end
	for _, a in holder:GetChildren() do
		if a:IsA("Attachment") and a.Name == OUTLET then
			table.insert(out, a)
		end
	end
	return out
end

-- Whether paint and finish show on this car: its body has a painted piece.
function CarCosmetics.paintable(carId: string): boolean
	for _, piece in ConfigLoader.entry(carId).body.pieces do
		if piece.paint then
			return true
		end
	end
	return false
end

-- Whether this car has a spot for a windscreen strip, exhaust tips or
-- window tint (CarCosmeticMounts); the garage panel greys SUN STRIPS / EXHAUST /
-- TINT items out on a car without one, like paint on a car with no painted
-- piece. Every catalog car has a strip and exhaust spot
-- (CarCosmeticMounts.spec); the hatch, pickup and cruiser have no windows
-- tint can show on.
function CarCosmetics.hasSpot(carId: string, spot: "windscreen" | "exhaust" | "windows"): boolean
	local mounts = CarCosmeticMounts.cars[carId]
	if not mounts then
		return false
	end
	if spot == "windscreen" then
		return mounts.windscreen ~= nil and CarStripShapes[carId] ~= nil
	elseif spot == "exhaust" then
		return mounts.exhaust ~= nil
	end
	return mounts.windows ~= nil
end

-- Puts this look on a car's built body. Safe to call again with a new look.
function CarCosmetics.apply(model: Model, look: CarLook.Look, carId: string)
	local body = VehicleRig.handles(model).body
	if not body then
		return
	end
	local s: State? = states[model]
	if s and (s.body ~= body or s.carId ~= carId or not s.body.Parent) then
		-- A new body (or car) on the same model: the remembered pieces and the
		-- built strip and tips belong to the old one.
		if s.strip then
			s.strip.folder:Destroy()
		end
		clearExhaust(s)
		s = nil
	end
	if not s then
		if not states[model] then
			model.Destroying:Once(function()
				local gone = states[model]
				if gone then
					clearExhaust(gone) -- frees its tip template when nobody else wears it
				end
				states[model] = nil
			end)
		end
		s = collect(body, carId)
		states[model] = s
	end
	assert(s)
	paint(s, look)
	rims(s, look)
	tint(s, look)
	lamps(model, look)
	strip(s, model, body, carId, look)
	exhaust(s, model, body, carId, look)
end

-- Applies the model's Look attribute now and whenever it changes.
function CarCosmetics.watch(model: Model)
	if watching[model] then
		return
	end
	local function update()
		local id = model:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
		if type(id) ~= "string" then
			return
		end
		local look = CarLook.decode(model:GetAttribute(CarLook.ATTRIBUTE))
		local ok, err = pcall(function()
			CarCosmetics.apply(model, look, id)
		end)
		if not ok then
			warn(`[CarCosmetics] {model.Name} ({id}): {err}`)
		end
	end
	watching[model] = model:GetAttributeChangedSignal(CarLook.ATTRIBUTE):Connect(update)
	model.Destroying:Once(function()
		local c = watching[model]
		if c then
			c:Disconnect()
			watching[model] = nil
		end
	end)
	update()
end

return CarCosmetics
