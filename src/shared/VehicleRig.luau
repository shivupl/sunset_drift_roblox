--!strict
-- THE RIG CONTRACT. Every car in the game is two things:
--
--   Rig   the physics. One collision box (Chassis, the PrimaryPart), a hidden
--         ballast that places the centre of mass, four ray origins the
--         suspension casts from, four wheel hubs the sim moves every frame,
--         the driver's seat, and the force actuators. Built from numbers.
--   Body  the look. MeshParts only, massless, never colliding, never queried,
--         welded to named mount attachments on the rig. Built from meshes.
--
-- This module is the one place that knows the names and the geometry that
-- join the two, so the sim, the spawner, the effects and the builders all
-- agree. RIG_SPEC.md is the written version; the specs in
-- Tests/VehicleRig.spec.luau hold this file to it.
--
-- Pure except handles(), which reads a built model.
local Shared = script.Parent
local CarConfig = require(Shared.CarConfig)

local VehicleRig = {}

--------------------------------------------------------------------------
-- Names
--------------------------------------------------------------------------

VehicleRig.RIG = "Rig" -- Model holding the physics parts
VehicleRig.BODY = "Body" -- Folder holding the visual MeshParts
VehicleRig.CHASSIS = "Chassis" -- the collision box; the car Model's PrimaryPart
VehicleRig.BALLAST = "Ballast"
VehicleRig.SEAT = "DriverSeat"
VehicleRig.PROMPT = "EnterPrompt" -- ProximityPrompt on Chassis
VehicleRig.FORCE = "SimForce" -- VectorForce on Chassis
VehicleRig.TORQUE = "SimTorque" -- Torque on Chassis
VehicleRig.CENTER = "Center" -- Attachment on Chassis the actuators use
VehicleRig.BODY_MOUNT = "BodyMount" -- Attachment on Chassis at the car-space origin
VehicleRig.WHEEL_MOUNT = "WheelMount" -- Attachment on each hub at the wheel centre
VehicleRig.WHEEL_WELD = "WheelWeld" -- Weld on each hub, Part0 = Chassis; the sim writes C0
VehicleRig.CAR_ID_ATTRIBUTE = "CarId" -- on the car Model
VehicleRig.PLATE_FRONT = "PlateFront" -- Attachment on Chassis: the front plate's centre, facing -Z
VehicleRig.PLATE_REAR = "PlateRear" -- Attachment on Chassis: the rear plate's centre, facing +Z
VehicleRig.PLATE_SIZE_M = { 0.52, 0.11 } -- width, height: a Saudi plate
VehicleRig.LAMP_ATTRIBUTE = "Lamp" -- on a lamp lens part: "head" or "tail"

function VehicleRig.rayOriginName(wheel: string): string
	return "RayOrigin_" .. wheel
end

function VehicleRig.hubName(wheel: string): string
	return "Hub_" .. wheel
end

export type WheelDef = { name: string, front: boolean, left: boolean, x: number, z: number }

-- Car space: +X right, +Y up, -Z forward (the way a Roblox CFrame looks).
VehicleRig.WHEELS = {
	{ name = "FL", front = true, left = true, x = -1, z = -1 },
	{ name = "FR", front = true, left = false, x = 1, z = -1 },
	{ name = "RL", front = false, left = true, x = -1, z = 1 },
	{ name = "RR", front = false, left = false, x = 1, z = 1 },
} :: { WheelDef }

--------------------------------------------------------------------------
-- Catalog entry types
--------------------------------------------------------------------------

type Vec3 = { number } -- { x, y, z }

-- The physics geometry a car supplies. Metres, kilograms.
export type RigGeometry = {
	massKg: number,
	collisionSizeM: Vec3, -- the box: width (X), height (Y), length (Z)
	centerOfMassM: Vec3, -- from the box centre, car space
	shellMassFraction: number, -- of massKg in the box; the rest is the ballast
	wheelbaseM: number,
	trackWidthM: number,
	wheelRadiusM: number,
	wheelWidthM: number,
	seatM: Vec3, -- seat centre from the box centre, car space
}

-- One visual mesh. Placed by the centre of its bounding box. The mesh is an
-- uploaded asset (meshId), generated data in the repo (mesh, "<Module>/<Piece>"
-- under Shared.CarMeshes, made by tools/carbody), or both: a generated mesh
-- imported through Studio's 3D Importer keeps its data path and gains the
-- asset id, which is then used (no EditableMesh needed; RIG_SPEC.md 7).
export type BodyPiece = {
	name: string,
	meshId: number?,
	mesh: string?,
	-- A SurfaceAppearance template in ReplicatedStorage.CarLooks: colour,
	-- metalness and roughness maps. With paint = true its Color is the paint
	-- (AlphaMode TintMask: the colour map's alpha marks the painted texels).
	look: string?,
	-- A lamp lens: coloured from body.lamps[lamp], and switched between
	-- unlit glass and glowing Neon by BodyBuilder.setLamps.
	lamp: string?, -- "head" | "tail"
	textureId: number?, -- asset meshes only; nil or 0: coloured by color/material
	sizeM: Vec3, -- bounding box size in the mount's space
	offsetM: Vec3, -- bounding box centre in the mount's space
	rotationDeg: Vec3?, -- extra X, Y, Z rotation, applied Y then X then Z
	color: Color3?,
	paint: boolean?, -- take the entry's paint colour instead of color
	material: Enum.Material?,
	transparency: number?,
	castShadow: boolean?, -- default true
}

-- Plate mounts, car space (origin on the ground, like pieces), and the
-- texture every plate shows until the plate system sets its own.
export type PlateSpec = {
	front: Vec3?,
	rear: Vec3?,
	textureId: number,
}

export type BodySpec = {
	paint: Color3,
	lamps: { head: Color3, tail: Color3 }?, -- this car's lens colours
	plates: PlateSpec?,
	-- Mounted to BodyMount: offsets are car space (origin on the ground).
	pieces: { BodyPiece },
	-- Mounted to every WheelMount: offsets are wheel space (origin at the
	-- wheel centre, axle along X, authored as a LEFT wheel, outer face -X).
	-- The right-hand hubs get the same pieces turned 180 degrees about Y.
	wheelPieces: { BodyPiece },
}

export type CarEntry = {
	displayName: string,
	blurb: string?, -- one line for the spawn menu
	order: number?, -- position in the spawn menu, low first; then by name
	-- Optional uniform size multiplier, default 1. The rig and body numbers
	-- stay as measured off the meshes; the builders and configFor multiply
	-- them, and configFor rescales the handling terms that only depend on
	-- size (see sizeCompensation) so a bigger car drives like the original.
	scale: number?,
	rig: RigGeometry,
	body: BodySpec,
	-- Optional partial CarConfig: any handling field this car tunes
	-- differently, deep-merged over the shared CarConfig.
	tuning: { [string]: any }?,
}

--------------------------------------------------------------------------
-- Effective config: shared handling + this car's rig + its overrides
--------------------------------------------------------------------------

local function deepCopy<T>(t: T): T
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t :: any do
		out[k] = deepCopy(v)
	end
	return (out :: any) :: T
end

local function deepMerge(into: { [string]: any }, from: { [string]: any })
	for k, v in from do
		if type(v) == "table" and type(into[k]) == "table" and #v == 0 then
			deepMerge(into[k], v)
		else
			into[k] = deepCopy(v)
		end
	end
end

-- The two-wheel controller's torques and torque gains, which all balance
-- against gravity's roll torque.
local TWO_WHEEL_TORQUES = { "liftTorque", "leanTorque", "instability", "balanceSpring", "rollDamping", "leanInTorque", "leanOutTorque", "landingDamping" }

function VehicleRig.scaleOf(entry: CarEntry): number
	local k = entry.scale
	return if type(k) == "number" and k > 0 then k else 1
end

-- Scaling a car by k changes more than its looks: a wheel k times bigger
-- turns k times less force out of the same torque and needs k^2 the
-- inertia to spin up the same, and a box k times bigger spins k^2 slower
-- for the same mass. These are the terms that depend on size alone, set
-- so the car behaves the same per metre of road:
--   drivetrain.finalDrive       x k    same force at the tyre, same rpm at any speed
--   slipModel.wheelInertia      x k^2  same wheel spin-up
--   slipModel.handbrakeTorque   x k    same locking force at the tyre
--   body.shellMassFraction      / k^2  same yaw, roll and pitch inertia
--   twoWheel torques and gains  x k    gravity's torque about the grounded
--                                      wheels is m g (halfTrack, comHeight),
--                                      both k times longer
-- Nothing else is touched: grip, springs, aero, steering and the throw
-- controller stay the shared tuning. Measured on the sedan at 1.2 they
-- drive the same without help (see RIG_SPEC.md).
function VehicleRig.sizeCompensation(cfg: any, k: number)
	if k == 1 then
		return
	end
	cfg.drivetrain.finalDrive *= k
	local sm = cfg.tires.slipModel
	if sm then
		sm.wheelInertia *= k * k
		sm.handbrakeTorque *= k
	end
	cfg.body.shellMassFraction /= k * k
	local tw = cfg.twoWheel
	if tw then
		for _, field in TWO_WHEEL_TORQUES do
			if type(tw[field]) == "number" then
				tw[field] *= k
			end
		end
	end
end

-- The body geometry fields the sim reads, filled from the rig (times the
-- car's scale). Returned as a fresh table; neither argument is modified.
function VehicleRig.configFor(base: CarConfig.Config, entry: CarEntry): CarConfig.Config
	local cfg = deepCopy(base) :: any
	if entry.tuning then
		deepMerge(cfg, entry.tuning)
	end
	local r = entry.rig
	local k = VehicleRig.scaleOf(entry)
	local b = cfg.body
	b.massKg = r.massKg
	-- The sim's legacy order is length, height, width.
	b.bodySize = { r.collisionSizeM[3] * k, r.collisionSizeM[2] * k, r.collisionSizeM[1] * k }
	-- The sim's legacy centre of mass is {lateral, up, forward}; car space
	-- forward is -Z.
	b.centerOfMassOffset = { r.centerOfMassM[1] * k, r.centerOfMassM[2] * k, -r.centerOfMassM[3] * k }
	b.shellMassFraction = r.shellMassFraction
	b.wheelbase = r.wheelbaseM * k
	b.trackWidth = r.trackWidthM * k
	b.wheelRadius = r.wheelRadiusM * k
	b.wheelWidth = r.wheelWidthM * k
	VehicleRig.sizeCompensation(cfg, k)
	return cfg :: CarConfig.Config
end

-- The seat, chassis-local metres.
function VehicleRig.seatM(entry: CarEntry): Vector3
	local s = entry.rig.seatM
	local k = VehicleRig.scaleOf(entry)
	return Vector3.new(s[1], s[2], s[3]) * k
end

--------------------------------------------------------------------------
-- Geometry, chassis-local metres unless named otherwise
--------------------------------------------------------------------------

-- Where a corner's suspension ray starts. The box's bottom face sits at the
-- wheel centre with the spring at full droop, so the hardpoint is
-- restLength above that.
function VehicleRig.rayOriginM(cfg: CarConfig.Config, wheel: WheelDef): Vector3
	local b = cfg.body
	return Vector3.new(wheel.x * b.trackWidth / 2, -b.bodySize[2] / 2 + cfg.suspension.restLength, wheel.z * b.wheelbase / 2)
end

-- How far each spring compresses holding the car up, in metres.
function VehicleRig.staticSagM(cfg: CarConfig.Config): number
	return cfg.body.massKg * cfg.units.gravity / 4 / cfg.suspension.stiffness
end

-- Height of the box centre above the ground with the car at rest.
function VehicleRig.restHeightM(cfg: CarConfig.Config): number
	return cfg.body.bodySize[2] / 2 - VehicleRig.staticSagM(cfg) + cfg.body.wheelRadius
end

-- The car-space origin (the ground under the box centre, car at rest).
function VehicleRig.bodyMountM(cfg: CarConfig.Config): Vector3
	return Vector3.new(0, -VehicleRig.restHeightM(cfg), 0)
end

-- A wheel's centre in car space with the car at rest.
function VehicleRig.wheelCentreCarM(cfg: CarConfig.Config, wheel: WheelDef): Vector3
	local b = cfg.body
	return Vector3.new(wheel.x * b.trackWidth / 2, b.wheelRadius, wheel.z * b.wheelbase / 2)
end

-- Hub offset (chassis-local metres) for a given suspension drop below the ray origin.
function VehicleRig.hubM(cfg: CarConfig.Config, wheel: WheelDef, dropM: number): Vector3
	return VehicleRig.rayOriginM(cfg, wheel) - Vector3.new(0, dropM, 0)
end

-- A plate attachment's CFrame on the chassis, studs, or nil if the car has
-- no such plate. Front plates face -Z, rear plates are turned to face +Z.
function VehicleRig.plateCFrame(cfg: CarConfig.Config, entry: CarEntry, which: "front" | "rear"): CFrame?
	local plates = entry.body.plates
	local at = plates and plates[which]
	if not at then
		return nil
	end
	local k = VehicleRig.scaleOf(entry)
	local mps = cfg.units.metersPerStud
	local pos = (VehicleRig.bodyMountM(cfg) + Vector3.new(at[1], at[2], at[3]) * k) / mps
	return CFrame.new(pos) * (if which == "rear" then CFrame.Angles(0, math.pi, 0) else CFrame.identity)
end

-- CFrame of a piece relative to its mount, in studs, for a car of scale k.
function VehicleRig.pieceCFrame(piece: BodyPiece, mps: number, mirrored: boolean, k: number?): CFrame
	local o = piece.offsetM
	local f = (k or 1) / mps
	local rot = piece.rotationDeg or { 0, 0, 0 }
	local cf = CFrame.new(o[1] * f, o[2] * f, o[3] * f)
		* CFrame.fromEulerAnglesYXZ(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
	if mirrored then
		cf = CFrame.Angles(0, math.pi, 0) * cf
	end
	return cf
end

--------------------------------------------------------------------------
-- Validation
--------------------------------------------------------------------------

local function positive(problems: { string }, id: string, name: string, v: any)
	if type(v) ~= "number" or v <= 0 then
		table.insert(problems, `{id}: rig.{name} must be a positive number`)
	end
end

local function vec(problems: { string }, where: string, v: any, needPositive: boolean)
	if type(v) ~= "table" or #v ~= 3 then
		table.insert(problems, `{where} must be {"{"} x, y, z {"}"}`)
		return
	end
	for i = 1, 3 do
		if type(v[i]) ~= "number" or (needPositive and v[i] <= 0) then
			table.insert(problems, `{where}[{i}] must be a {if needPositive then "positive " else ""}number`)
		end
	end
end

local function pieces(problems: { string }, where: string, list: any)
	if type(list) ~= "table" then
		table.insert(problems, `{where} must be a list of pieces`)
		return
	end
	local seen: { [string]: boolean } = {}
	for i, p in list do
		local at = `{where}[{i}]`
		if type(p.name) ~= "string" or p.name == "" then
			table.insert(problems, `{at}.name is missing`)
		elseif seen[p.name] then
			table.insert(problems, `{at}.name "{p.name}" is used twice`)
		else
			seen[p.name] = true
		end
		local hasAsset = type(p.meshId) == "number" and p.meshId > 0
		local hasData = type(p.mesh) == "string" and string.match(p.mesh, "^[%w_]+/[%w_]+$") ~= nil
		if not hasAsset and not hasData then
			table.insert(problems, `{at} needs a meshId (an asset id) or a mesh ("Module/Piece")`)
		end
		if p.mesh ~= nil and not hasData then
			table.insert(problems, `{at}.mesh must be "Module/Piece"`)
		end
		if p.look ~= nil and type(p.look) ~= "string" then
			table.insert(problems, `{at}.look must be the name of a CarLooks SurfaceAppearance`)
		end
		if p.lamp ~= nil and p.lamp ~= "head" and p.lamp ~= "tail" then
			table.insert(problems, `{at}.lamp must be "head" or "tail"`)
		end
		vec(problems, `{at}.sizeM`, p.sizeM, true)
		vec(problems, `{at}.offsetM`, p.offsetM, false)
		if p.rotationDeg ~= nil then
			vec(problems, `{at}.rotationDeg`, p.rotationDeg, false)
		end
	end
end

-- Everything wrong with an entry, as sentences. Empty means it will build.
function VehicleRig.validate(id: string, entry: any): { string }
	local problems: { string } = {}
	if type(entry) ~= "table" then
		return { `{id}: entry is not a table` }
	end
	if type(entry.displayName) ~= "string" then
		table.insert(problems, `{id}: displayName is missing`)
	end
	if entry.blurb ~= nil and type(entry.blurb) ~= "string" then
		table.insert(problems, `{id}: blurb must be a string`)
	end
	if entry.order ~= nil and type(entry.order) ~= "number" then
		table.insert(problems, `{id}: order must be a number`)
	end
	if entry.scale ~= nil and (type(entry.scale) ~= "number" or entry.scale < 0.5 or entry.scale > 2) then
		table.insert(problems, `{id}: scale must be a number from 0.5 to 2`)
	end
	local r = entry.rig
	if type(r) ~= "table" then
		table.insert(problems, `{id}: rig is missing`)
	else
		for _, name in { "massKg", "wheelbaseM", "trackWidthM", "wheelRadiusM", "wheelWidthM" } do
			positive(problems, id, name, r[name])
		end
		vec(problems, `{id}: rig.collisionSizeM`, r.collisionSizeM, true)
		vec(problems, `{id}: rig.centerOfMassM`, r.centerOfMassM, false)
		vec(problems, `{id}: rig.seatM`, r.seatM, false)
		if type(r.shellMassFraction) ~= "number" or r.shellMassFraction <= 0 or r.shellMassFraction >= 1 then
			table.insert(problems, `{id}: rig.shellMassFraction must be between 0 and 1`)
		end
		if type(r.collisionSizeM) == "table" and type(r.trackWidthM) == "number" and type(r.collisionSizeM[1]) == "number" then
			if r.trackWidthM > r.collisionSizeM[1] + 0.5 then
				table.insert(problems, `{id}: rig.trackWidthM is far wider than the collision box`)
			end
		end
		if type(r.collisionSizeM) == "table" and type(r.wheelbaseM) == "number" and type(r.collisionSizeM[3]) == "number" then
			if r.wheelbaseM >= r.collisionSizeM[3] then
				table.insert(problems, `{id}: rig.wheelbaseM must be shorter than the collision box`)
			end
		end
	end
	local b = entry.body
	if type(b) ~= "table" then
		table.insert(problems, `{id}: body is missing`)
	else
		if typeof(b.paint) ~= "Color3" then
			table.insert(problems, `{id}: body.paint must be a Color3`)
		end
		pieces(problems, `{id}: body.pieces`, b.pieces)
		pieces(problems, `{id}: body.wheelPieces`, b.wheelPieces)
		local hasLampPiece = false
		for _, p in (if type(b.pieces) == "table" then b.pieces else {}) do
			if type(p) == "table" and p.lamp ~= nil then
				hasLampPiece = true
			end
		end
		if b.lamps ~= nil or hasLampPiece then
			if type(b.lamps) ~= "table" or typeof(b.lamps.head) ~= "Color3" or typeof(b.lamps.tail) ~= "Color3" then
				table.insert(problems, `{id}: body.lamps needs head and tail Color3s when a piece is a lamp`)
			end
		end
		if b.plates ~= nil then
			if type(b.plates) ~= "table" then
				table.insert(problems, `{id}: body.plates must be a table`)
			else
				if type(b.plates.textureId) ~= "number" or b.plates.textureId <= 0 then
					table.insert(problems, `{id}: body.plates.textureId must be an image asset id`)
				end
				for _, which in { "front", "rear" } do
					if b.plates[which] ~= nil then
						vec(problems, `{id}: body.plates.{which}`, b.plates[which], false)
					end
				end
			end
		end
		if type(b.pieces) == "table" and #b.pieces == 0 then
			table.insert(problems, `{id}: body.pieces is empty`)
		end
		-- The tyre is the largest wheel piece; its diameter is what reads
		-- against the physics radius.
		if type(b.wheelPieces) == "table" and type(r) == "table" and type(r.wheelRadiusM) == "number" then
			local biggest = 0
			for _, p in b.wheelPieces do
				if type(p.sizeM) == "table" and type(p.sizeM[2]) == "number" then
					biggest = math.max(biggest, p.sizeM[2])
				end
			end
			if biggest > 0 and math.abs(biggest - 2 * r.wheelRadiusM) > 0.1 * r.wheelRadiusM then
				table.insert(problems, `{id}: the largest wheel piece is {biggest} m tall but 2 x wheelRadiusM is {2 * r.wheelRadiusM}`)
			end
		end
	end
	if entry.tuning ~= nil and type(entry.tuning) ~= "table" then
		table.insert(problems, `{id}: tuning must be a table of CarConfig overrides`)
	end
	return problems
end

--------------------------------------------------------------------------
-- Handles into a built car
--------------------------------------------------------------------------

export type Hub = { part: BasePart, weld: Weld, mount: Attachment }

export type Handles = {
	model: Model,
	carId: string?,
	rig: Model,
	chassis: BasePart,
	seat: VehicleSeat,
	prompt: ProximityPrompt,
	force: VectorForce,
	torque: Torque,
	bodyMount: Attachment,
	rayOrigins: { [string]: Attachment },
	hubs: { [string]: Hub },
	plates: { front: Attachment?, rear: Attachment? },
	body: Folder?,
}

local function need<T>(parent: Instance, name: string, className: string): T
	local found = parent:FindFirstChild(name)
	if not found or not found:IsA(className) then
		error(`[VehicleRig] {parent:GetFullName()} has no {className} "{name}" (see RIG_SPEC.md)`, 3)
	end
	return (found :: any) :: T
end

-- Every contract instance of a built car, or an error naming the first
-- one that is missing.
function VehicleRig.handles(model: Model): Handles
	local rig = need(model, VehicleRig.RIG, "Model") :: Model
	local chassis = need(rig, VehicleRig.CHASSIS, "BasePart") :: BasePart
	local rayOrigins: { [string]: Attachment } = {}
	local hubs: { [string]: Hub } = {}
	for _, w in VehicleRig.WHEELS do
		rayOrigins[w.name] = need(chassis, VehicleRig.rayOriginName(w.name), "Attachment")
		local hub = need(rig, VehicleRig.hubName(w.name), "BasePart") :: BasePart
		hubs[w.name] = {
			part = hub,
			weld = need(hub, VehicleRig.WHEEL_WELD, "Weld"),
			mount = need(hub, VehicleRig.WHEEL_MOUNT, "Attachment"),
		}
	end
	local body = model:FindFirstChild(VehicleRig.BODY)
	local carId = model:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
	return {
		model = model,
		carId = if type(carId) == "string" then carId else nil,
		rig = rig,
		chassis = chassis,
		seat = need(rig, VehicleRig.SEAT, "VehicleSeat"),
		prompt = need(chassis, VehicleRig.PROMPT, "ProximityPrompt"),
		force = need(chassis, VehicleRig.FORCE, "VectorForce"),
		torque = need(chassis, VehicleRig.TORQUE, "Torque"),
		bodyMount = need(chassis, VehicleRig.BODY_MOUNT, "Attachment"),
		rayOrigins = rayOrigins,
		hubs = hubs,
		plates = {
			front = chassis:FindFirstChild(VehicleRig.PLATE_FRONT) :: Attachment?,
			rear = chassis:FindFirstChild(VehicleRig.PLATE_REAR) :: Attachment?,
		},
		body = if body and body:IsA("Folder") then body else nil,
	}
end

return VehicleRig
