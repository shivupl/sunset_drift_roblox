--!strict
-- The rig contract (RIG_SPEC.md) held to numbers.
local Shared = script.Parent.Parent
local VehicleRig = require(Shared.VehicleRig)
local CarConfig = require(Shared.CarConfig)
local CarCatalog = require(Shared.CarCatalog)
local ConfigLoader = require(Shared.ConfigLoader)
local BodyBuilder = require(Shared.BodyBuilder)
local MeshData = require(Shared.MeshData)
local Tests = require(script.Parent)
type T = Tests.T

local function clone(t: any): any
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t do
		out[k] = clone(v)
	end
	return out
end

-- The Phase 0 sedan as it was migrated to the rig contract: the fixed
-- reference for the numbers below, whatever the catalog holds now.
local PHASE0_SEDAN: any = {
	displayName = "Sedan",
	rig = {
		massKg = 1600,
		collisionSizeM = { 1.8, 1.3, 4.9 },
		centerOfMassM = { 0, -0.35, -0.2 },
		shellMassFraction = 0.35,
		wheelbaseM = 2.8,
		trackWidthM = 1.55,
		wheelRadiusM = 0.33,
		wheelWidthM = 0.22,
		seatM = { -0.4, -0.6, -0.2 },
	},
	body = {
		paint = Color3.fromRGB(236, 236, 232),
		pieces = {
			{ name = "Shell", meshId = 9339166843, sizeM = { 1.899, 1.208, 4.697 }, offsetM = { 0, 0.765, 0.047 }, paint = true },
			{ name = "Glass", meshId = 9339167457, sizeM = { 1.899, 1.21, 4.679 }, offsetM = { 0, 0.766, 0.054 }, paint = false },
		},
		wheelPieces = {
			{ name = "Tyre", meshId = 9496370049, sizeM = { 0.257, 0.66, 0.66 }, offsetM = { 0, 0, 0 }, paint = false },
		},
	},
}

return function(t: T)
	-- Every car in the catalog builds.
	local count = 0
	for id, entry in CarCatalog.cars do
		count += 1
		local problems = VehicleRig.validate(id, entry)
		t.eq(#problems, 0, `{id} validates ({table.concat(problems, "; ")})`)
	end
	t.ok(count >= 2, "the catalog has at least two cars")
	t.ok(CarCatalog.cars[CarCatalog.defaultCarId] ~= nil, "the default car exists")

	-- The migration kept the Phase 0 physics: the sedan's rig at scale 1 is
	-- the old CarConfig.body, number for number.
	local sedanOne = clone(PHASE0_SEDAN)
	sedanOne.scale = nil
	local sedan = VehicleRig.configFor(CarConfig, sedanOne)
	local b = sedan.body
	t.eq(b.massKg, 1600, "sedan mass")
	t.eq(b.bodySize[1], 4.9, "sedan box length")
	t.eq(b.bodySize[2], 1.3, "sedan box height")
	t.eq(b.bodySize[3], 1.8, "sedan box width")
	t.near(b.centerOfMassOffset[1], 0, 1e-9, "sedan CoM lateral")
	t.near(b.centerOfMassOffset[2], -0.35, 1e-9, "sedan CoM up")
	t.near(b.centerOfMassOffset[3], 0.2, 1e-9, "sedan CoM forward (legacy +forward)")
	t.eq(b.wheelbase, 2.8, "sedan wheelbase")
	t.eq(b.trackWidth, 1.55, "sedan track")
	t.eq(b.wheelRadius, 0.33, "sedan wheel radius")
	t.eq(b.wheelWidth, 0.22, "sedan wheel width")
	t.eq(b.shellMassFraction, 0.35, "sedan shell fraction")
	t.eq(b.dragCoefficient, CarConfig.body.dragCoefficient, "shared aero carries through")

	-- configFor copies: the shared config and the entry are untouched.
	t.eq(CarConfig.body.massKg, 0, "CarConfig.body keeps its placeholder")
	local batrol = VehicleRig.configFor(CarConfig, CarCatalog.cars.batrol)
	t.eq(batrol.suspension.stiffness, 45000, "a car's tuning overrides the shared value")
	t.eq(CarConfig.suspension.stiffness, 35000, "without changing the shared value")
	t.eq(batrol.suspension.travel, CarConfig.suspension.travel, "fields it does not override are shared")
	t.ok(batrol.drivetrain.gearRatios ~= CarConfig.drivetrain.gearRatios, "merged tables are copies")

	-- Arrays in tuning replace, dictionaries merge.
	local custom = clone(PHASE0_SEDAN)
	custom.scale = nil
	custom.tuning = { drivetrain = { gearRatios = { 3.0, 2.0 } } }
	local customCfg = VehicleRig.configFor(CarConfig, custom)
	t.eq(#customCfg.drivetrain.gearRatios, 2, "an array override replaces the whole array")
	t.eq(customCfg.drivetrain.finalDrive, CarConfig.drivetrain.finalDrive, "and leaves its siblings")

	-- Geometry. The ray origin is the old CarBuilder hardpoint. Vector3 is
	-- single precision, so these compare to a micron.
	local fl = VehicleRig.WHEELS[1]
	local origin = VehicleRig.rayOriginM(sedan, fl)
	t.near(origin.X, -0.775, 1e-6, "FL ray origin X is -track/2")
	t.near(origin.Y, -0.65 + 0.35, 1e-6, "ray origin sits restLength above the box bottom")
	t.near(origin.Z, -1.4, 1e-6, "FL ray origin Z is -wheelbase/2 (front is -Z)")
	t.eq(fl.name, "FL", "wheel order starts front left")
	t.ok(fl.front and fl.left, "FL is front and left")

	local sag = VehicleRig.staticSagM(sedan)
	t.near(sag, 1600 * 9.81 / 4 / 35000, 1e-9, "static sag is weight over four springs")
	t.near(VehicleRig.restHeightM(sedan), 0.65 - sag + 0.33, 1e-9, "rest height of the box centre")
	t.near(VehicleRig.restHeightM(sedan), 0.868, 0.002, "matches the 0.867 m measured in play")
	-- At rest a hub is (restLength - sag) under its ray origin, and that
	-- point is the wheel centre in car space.
	local hubRest = VehicleRig.hubM(sedan, fl, sedan.suspension.restLength - sag)
	local mount = VehicleRig.bodyMountM(sedan)
	local wheelCar = VehicleRig.wheelCentreCarM(sedan, fl)
	t.near(hubRest.Y - mount.Y, wheelCar.Y, 1e-6, "the resting hub is the wheel centre in car space")
	t.near(wheelCar.Y, 0.33, 1e-6, "a resting wheel centre is one radius off the ground")

	-- Pieces: mirrored for the right side, offsets in metres.
	local mps = 0.28
	local piece = { name = "p", meshId = 1, sizeM = { 1, 1, 1 }, offsetM = { -0.28, 0.56, 0 } }
	local left = VehicleRig.pieceCFrame(piece, mps, false)
	local right = VehicleRig.pieceCFrame(piece, mps, true)
	t.near(left.Position.X, -1, 1e-6, "left piece offset in studs")
	t.near(right.Position.X, 1, 1e-6, "mirrored piece moves to the other side")
	t.near(right.Position.Y, 2, 1e-6, "mirroring keeps height")
	t.near(right.LookVector.Z, 1, 1e-6, "mirrored piece is turned 180 degrees")

	-- Validation catches the mistakes a new car will make.
	local function problemsWith(mutate: (any) -> ()): { string }
		local e = clone(PHASE0_SEDAN)
		mutate(e)
		return VehicleRig.validate("test", e)
	end
	t.ok(#problemsWith(function(e) e.body.pieces[1].meshId = nil end) > 0, "missing mesh id")
	t.ok(#problemsWith(function(e) e.body.pieces[2].name = e.body.pieces[1].name end) > 0, "duplicate piece name")
	t.ok(#problemsWith(function(e) e.rig.wheelRadiusM = 0.5 end) > 0, "tyre diameter disagrees with the physics radius")
	t.ok(#problemsWith(function(e) e.rig.wheelbaseM = 6 end) > 0, "wheelbase longer than the box")
	t.ok(#problemsWith(function(e) e.rig.shellMassFraction = 1 end) > 0, "shell fraction leaves no ballast")
	t.ok(#problemsWith(function(e) e.rig.collisionSizeM = { 1, 1 } end) > 0, "a two-number size")
	t.ok(#problemsWith(function(e) e.body.paint = "white" end) > 0, "paint that is not a Color3")
	t.ok(#problemsWith(function(e) e.rig = nil end) > 0, "no rig")
	t.eq(#problemsWith(function(_e) end), 0, "an untouched copy is clean")
	t.eq(#problemsWith(function(e) e.body.pieces[1].mesh = "Kamri/Body" end), 0, "a generated mesh with its imported asset id is fine")
	t.ok(#problemsWith(function(e)
		e.body.pieces[1].meshId = nil
		e.body.pieces[1].mesh = "Kamri Body"
	end) > 0, "a generated mesh path that is not Module/Piece")
	t.eq(#problemsWith(function(e)
		e.body.pieces[1].meshId = nil
		e.body.pieces[1].mesh = "Kamri/Body"
	end), 0, "a generated mesh instead of an asset is fine")

	-- Generated meshes: every catalog piece that names one finds it, places
	-- it by the generator's own bounding box, and the buffers decode to the
	-- sizes the header claims.
	for id, entry in CarCatalog.cars do
		for _, list in { entry.body.pieces, entry.body.wheelPieces } do
			for _, p in list do
				if not p.mesh then
					continue
				end
				local data = BodyBuilder.meshData(p.mesh)
				t.ok(data ~= nil, `{id} {p.name}: generated mesh {p.mesh} exists`)
				if not data then
					continue
				end
				for axis = 1, 3 do
					t.near(p.sizeM[axis], data.sizeM[axis], 1e-3, `{id} {p.name}: sizeM[{axis}] matches the generator`)
					t.near(p.offsetM[axis], data.offsetM[axis], 1e-3, `{id} {p.name}: offsetM[{axis}] matches the generator`)
				end
				t.eq(buffer.len(MeshData.base64(data.positions)), data.counts[1] * 6, `{id} {p.name}: positions decode`)
				t.eq(buffer.len(MeshData.base64(data.normals)), data.counts[2] * 3, `{id} {p.name}: normals decode`)
				t.eq(buffer.len(MeshData.base64(data.uvs)), data.counts[3] * 4, `{id} {p.name}: uvs decode`)
				t.eq(buffer.len(MeshData.base64(data.triangles)), data.triangleCount * 18, `{id} {p.name}: triangles decode`)
			end
		end
	end
	t.ok(#problemsWith(function(e) e.body.pieces[1].lamp = "head" end) > 0, "a lamp piece on a car with no lamp colours")
	t.ok(#problemsWith(function(e)
		e.body.lamps = { head = Color3.new(1, 1, 1), tail = Color3.new(1, 0, 0) }
		e.body.pieces[1].lamp = "fog"
	end) > 0, "a lamp that is neither head nor tail")
	t.ok(#problemsWith(function(e) e.body.plates = { front = { 0, 0.5, -2.3 } } end) > 0, "plates without a texture")
	t.eq(#problemsWith(function(e) e.body.plates = { front = { 0, 0.5, -2.3 }, rear = { 0, 0.6, 2.4 }, textureId = 1 } end), 0, "plates with mounts and a texture")

	-- Plate mounts: car space plus the body mount, rear turned to face back.
	local withPlates = clone(PHASE0_SEDAN)
	withPlates.body.plates = { front = { 0, 0.5, -2.3 }, rear = { 0, 0.6, 2.4 }, textureId = 1 }
	local front = VehicleRig.plateCFrame(sedan, withPlates, "front") :: CFrame
	local rear = VehicleRig.plateCFrame(sedan, withPlates, "rear") :: CFrame
	t.near(front.Position.Y * 0.28, VehicleRig.bodyMountM(sedan).Y + 0.5, 1e-5, "front plate height is car space above the ground")
	t.near(front.LookVector.Z, -1, 1e-6, "the front plate faces forward (-Z)")
	t.near(rear.LookVector.Z, 1, 1e-6, "the rear plate faces back (+Z)")
	t.ok(VehicleRig.plateCFrame(sedan, PHASE0_SEDAN, "front") == nil, "no plates, no mount")

	local decoded = MeshData.base64("AQID/w==")
	t.eq(buffer.len(decoded), 4, "base64 padding")
	t.eq(buffer.readu8(decoded, 3), 255, "base64 bytes")

	-- Scale: geometry grows, and the size-only handling terms follow so the
	-- car drives the same per metre.
	local k = 1.2
	local big = clone(PHASE0_SEDAN)
	big.scale = k
	local bigCfg = VehicleRig.configFor(CarConfig, big)
	t.near(bigCfg.body.bodySize[1], 4.9 * k, 1e-9, "scale multiplies the box")
	t.near(bigCfg.body.wheelbase, 2.8 * k, 1e-9, "and the wheelbase")
	t.near(bigCfg.body.wheelRadius, 0.33 * k, 1e-9, "and the wheel radius")
	t.near(bigCfg.body.centerOfMassOffset[2], -0.35 * k, 1e-9, "and the centre of mass offset")
	t.eq(bigCfg.body.massKg, 1600, "but not the mass")
	t.near(bigCfg.drivetrain.finalDrive, CarConfig.drivetrain.finalDrive * k, 1e-9, "final drive keeps the force at the tyre")
	t.near(bigCfg.drivetrain.finalDrive / bigCfg.body.wheelRadius, CarConfig.drivetrain.finalDrive / 0.33, 1e-9, "and the rpm at a given speed")
	t.near(bigCfg.tires.slipModel.wheelInertia / bigCfg.body.wheelRadius ^ 2, CarConfig.tires.slipModel.wheelInertia / 0.33 ^ 2, 1e-9, "wheel spin-up is unchanged")
	t.near(bigCfg.tires.slipModel.handbrakeTorque / bigCfg.body.wheelRadius, CarConfig.tires.slipModel.handbrakeTorque / 0.33, 1e-9, "handbrake force at the tyre is unchanged")
	-- The box's inertia, m/12 (a^2 + b^2) of the shell, holds across scales.
	local function shellYaw(c: any): number
		local m = c.body.massKg * c.body.shellMassFraction
		return m / 12 * (c.body.bodySize[1] ^ 2 + c.body.bodySize[3] ^ 2)
	end
	t.near(shellYaw(bigCfg), shellYaw(sedan), 1e-6, "shell yaw inertia is unchanged")
	t.near(VehicleRig.seatM(big).Y, -0.6 * k, 1e-6, "the seat scales with the car")
	t.near(bigCfg.twoWheel.liftTorque, CarConfig.twoWheel.liftTorque * k, 1e-6, "two-wheel torques follow gravity's longer lever")
	t.near(bigCfg.twoWheel.rollDamping, CarConfig.twoWheel.rollDamping * k, 1e-6, "and so do its gains")
	t.eq(bigCfg.twoWheel.targetRollDeg, CarConfig.twoWheel.targetRollDeg, "angles do not scale")
	local piece2 = { name = "p", meshId = 1, sizeM = { 1, 1, 1 }, offsetM = { 0, 0.28, 0 } }
	t.near(VehicleRig.pieceCFrame(piece2, mps, false, k).Position.Y, k, 1e-6, "body pieces move out with the scale")
	t.ok(#problemsWith(function(e) e.scale = 5 end) > 0, "an absurd scale")
	t.ok(#problemsWith(function(e) e.blurb = 12 end) > 0, "a menu blurb that is not text")
	t.ok(#problemsWith(function(e) e.order = "first" end) > 0, "a menu order that is not a number")
	for id, entry in CarCatalog.cars do
		t.ok(type(entry.blurb) == "string" and #entry.blurb > 0, `{id} has a spawn menu blurb`)
	end

	-- The loader resolves unknown ids to the default car.
	t.eq(ConfigLoader.resolveCarId("no-such-car"), CarCatalog.defaultCarId, "unknown car falls back to the default")
	t.eq(ConfigLoader.resolveCarId("batrol"), "batrol", "a known car resolves to itself")
	t.eq(ConfigLoader.forCar("batrol").body.massKg, 2200, "forCar hands out the merged config")
end
