--!strict
-- The rig contract (RIG_SPEC.md) held to numbers.
local Shared = script.Parent.Parent
local VehicleRig = require(Shared.VehicleRig)
local CarConfig = require(Shared.CarConfig)
local CarCatalog = require(Shared.CarCatalog)
local ConfigLoader = require(Shared.ConfigLoader)
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

	-- The migration kept the Phase 0 physics: the sedan's merged config is
	-- the old CarConfig.body, number for number.
	local sedan = VehicleRig.configFor(CarConfig, CarCatalog.cars.sedan)
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
	local hatch = VehicleRig.configFor(CarConfig, CarCatalog.cars.hatch)
	t.eq(hatch.suspension.stiffness, 27000, "a car's tuning overrides the shared value")
	t.eq(CarConfig.suspension.stiffness, 35000, "without changing the shared value")
	t.eq(hatch.suspension.travel, CarConfig.suspension.travel, "fields it does not override are shared")
	t.ok(hatch.drivetrain.gearRatios ~= CarConfig.drivetrain.gearRatios, "merged tables are copies")

	-- Arrays in tuning replace, dictionaries merge.
	local custom = clone(CarCatalog.cars.sedan)
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
		local e = clone(CarCatalog.cars.sedan)
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

	-- The loader resolves unknown ids to the default car.
	t.eq(ConfigLoader.resolveCarId("no-such-car"), CarCatalog.defaultCarId, "unknown car falls back to the default")
	t.eq(ConfigLoader.resolveCarId("hatch"), "hatch", "a known car resolves to itself")
	t.eq(ConfigLoader.forCar("hatch").body.massKg, 1250, "forCar hands out the merged config")
end
