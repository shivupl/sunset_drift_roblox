--!strict
-- Every car in the game. Adding one is an entry here plus its meshes: no
-- code changes. The contract each entry follows (car space, the mounts, the
-- wheel convention, what a new car must supply) is RIG_SPEC.md, and
-- VehicleRig.validate() checks every entry at server start.
--
-- Handling that every car shares lives in CarConfig. An entry's `tuning`
-- overrides any part of it for that car only.
--
-- Bodies. The Kamri's is made in the repo (tools/carbody): generated meshes
-- in CarMeshes, baked textures on ReplicatedStorage.CarLooks. The hatch's
-- comes from "Low Poly Cars Pack: Mesh Vehicle Road Race" (store
-- 120535861432410, Ninja131Venom): free, no scripts shipped (the builder
-- makes its own MeshParts from the bare mesh ids), no real brands; its
-- numbers were measured off the pack model in Studio. The pickup's and the
-- cruiser's sources are above their entries.
local VehicleRig = require(script.Parent.VehicleRig)

type CarEntry = VehicleRig.CarEntry

local RUBBER = Color3.fromRGB(28, 28, 30)
local RIM = Color3.fromRGB(176, 180, 186)
local GLASS = Color3.fromRGB(24, 30, 36)
local HEADLAMP = Color3.fromRGB(236, 234, 220)
local TAILLAMP = Color3.fromRGB(190, 24, 24)

-- The pack's wheel, shared by both cars: a tyre and a rim, authored as a
-- left wheel (outer face -X). Sized for a 0.33 m radius; a car with another
-- radius scales these by radius / 0.33.
local function wheelPieces(radiusM: number): { VehicleRig.BodyPiece }
	local k = radiusM / 0.33
	return {
		{ name = "Tyre", meshId = 9496370049, sizeM = { 0.257 * k, 0.66 * k, 0.66 * k }, offsetM = { 0, 0, 0 }, color = RUBBER, material = Enum.Material.Rubber },
		{ name = "Rim", meshId = 9496369889, sizeM = { 0.26 * k, 0.482 * k, 0.482 * k }, offsetM = { -0.016 * k, 0.005 * k, 0 }, color = RIM, material = Enum.Material.Metal },
	}
end

local cars: { [string]: CarEntry } = {
	-- THE KAMRI. A large Japanese four-door saloon in the shape of a mid-2000s
	-- family sedan, no make or badge. The first car with a body made in the
	-- repo: tools/carbody/kamri.py generates the meshes (src/shared/CarMeshes/
	-- Kamri) and bakes the textures (assets/cars/kamri, uploaded; the ids are
	-- on the CarLooks SurfaceAppearances). sizeM and offsetM below are the
	-- generator's numbers; a spec fails if they drift apart.
	--
	-- Real proportions: 4.805 m long, 1.82 m wide, 1.47 m tall, 2.775 m
	-- wheelbase, 1.575 m track, 215/60 R16 tyres. It takes the Phase 0
	-- sedan's place and its handling: same mass, centre of mass height and
	-- shared tuning, on its own (real) wheelbase, track and tyres.
	kamri = {
		displayName = "Kamri",
		-- Replaced by kamri07 (the store body) as the Kamri and the default car.
		-- Kept, off the menu, for the generated-body work; spawnable by id.
		hidden = true,
		blurb = "The big Japanese saloon. Planted, predictable, carries a slide.",
		order = 1,
		scale = 1.2,
		rig = {
			massKg = 1600,
			-- Box bottom 0.21 m off the ground at rest, top 1.41 m: inside the
			-- body from the sills to under the roof.
			collisionSizeM = { 1.8, 1.2, 4.7 },
			-- 0.51 m above the ground at rest, where the sedan's was.
			centerOfMassM = { 0, -0.3, -0.2 },
			shellMassFraction = 0.35,
			wheelbaseM = 2.775,
			trackWidthM = 1.575,
			wheelRadiusM = 0.326,
			wheelWidthM = 0.215,
			-- Driver's side, over the front seat cushion, 0.28 m off the ground
			-- (the body sits 2 cm lower since the proportion pass).
			seatM = { -0.38, -0.53, 0.12 },
		},
		body = {
			paint = Color3.fromRGB(236, 236, 232),
			-- Lens colours; the lenses glow in them when lit (BodyBuilder.setLamps).
			lamps = { head = Color3.fromRGB(246, 242, 228), tail = Color3.fromRGB(205, 18, 22) },
			-- Plate mounts off the generator's nose and tail; the default plate
			-- texture is tools/carbody/plate.py.
			plates = { front = { 0, 0.505, -2.365 }, rear = { 0, 0.595, 2.4755 }, textureId = 125828616185618 },
			pieces = {
				{ name = "Body", mesh = "Kamri/Body", look = "Kamri_Body", paint = true, sizeM = { 2.1074, 1.2547, 4.8357 }, offsetM = { 0, 0.7974, 0.0524 } },
				{ name = "Glass", mesh = "Kamri/Glass", sizeM = { 1.7388, 0.4404, 2.66 }, offsetM = { 0, 1.1798, 0.41 }, color = Color3.fromRGB(30, 40, 44), material = Enum.Material.Glass, transparency = 0.45, castShadow = false },
				{ name = "Interior", mesh = "Kamri/Interior", sizeM = { 1.626, 1.0847, 2.6809 }, offsetM = { 0, 0.8224, 0.4104 }, color = Color3.fromRGB(34, 34, 36), castShadow = false },
				-- Recessed lamps: lenses in their own pieces, housings behind them.
				{ name = "HeadLamps", mesh = "Kamri/HeadLamps", lamp = "head", sizeM = { 1.7833, 0.2647, 0.3809 }, offsetM = { 0, 0.6805, -2.1372 } },
				{ name = "TailLamps", mesh = "Kamri/TailLamps", lamp = "tail", sizeM = { 1.7634, 0.2758, 0.2636 }, offsetM = { 0, 0.8964, 2.3029 } },
				{ name = "LampHousings", mesh = "Kamri/LampHousings", sizeM = { 1.7953, 0.4974, 4.7739 }, offsetM = { 0, 0.7868, 0.0536 }, color = Color3.fromRGB(78, 80, 84), material = Enum.Material.Metal, castShadow = false },
				-- Recessed grille with real slats, dark matte.
				{ name = "Grille", mesh = "Kamri/Grille", sizeM = { 0.9, 0.1884, 0.1089 }, offsetM = { 0, 0.6308, -2.2889 }, color = Color3.fromRGB(38, 38, 42), material = Enum.Material.Plastic, castShadow = false },
			},
			wheelPieces = {
				{ name = "Tyre", mesh = "Kamri/Tyre", look = "Kamri_Tyre", sizeM = { 0.215, 0.652, 0.652 }, offsetM = { 0, 0, 0 }, material = Enum.Material.Rubber },
				{ name = "Rim", mesh = "Kamri/Rim", look = "Kamri_Rim", sizeM = { 0.187, 0.417, 0.417 }, offsetM = { -0.0035, 0, 0 }, material = Enum.Material.Metal },
			},
		},
	},

	-- A second car to prove the contract: the pack's hatch, uniformly
	-- scaled to 4.3 m (0.17 m per pack stud), with its rig measured off the
	-- mesh. Lighter, shorter, wider.
	hatch = {
		displayName = "Hatch",
		blurb = "Light and quick off the line. Snaps round.",
		order = 2,
		scale = 1.2, -- the same world size as the sedan
		rig = {
			massKg = 1250,
			collisionSizeM = { 1.95, 0.85, 4.25 },
			centerOfMassM = { 0, -0.2, -0.15 },
			shellMassFraction = 0.35,
			wheelbaseM = 2.508,
			trackWidthM = 1.639,
			wheelRadiusM = 0.32,
			wheelWidthM = 0.22,
			-- As low as the box allows. It is a low car: a seated avatar's head
			-- still shows over its roof.
			seatM = { -0.4, -0.3, 0.05 },
		},
		body = {
			paint = Color3.fromRGB(214, 96, 36),
			pieces = {
				{ name = "Shell", meshId = 9339152185, sizeM = { 1.991, 0.959, 4.301 }, offsetM = { 0.01, 0.598, -0.087 }, paint = true, material = Enum.Material.SmoothPlastic },
				{ name = "Glass", meshId = 9339153338, sizeM = { 1.985, 0.934, 4.252 }, offsetM = { 0.01, 0.585, -0.112 }, color = GLASS, material = Enum.Material.Glass },
				{ name = "RearLamps", meshId = 9339153021, sizeM = { 1.692, 0.381, 1.47 }, offsetM = { 0.01, 0.862, 1.242 }, color = TAILLAMP, material = Enum.Material.Neon, castShadow = false },
				{ name = "RoofVent", meshId = 9339152369, sizeM = { 0.841, 0.14, 0.898 }, offsetM = { 0.007, 0.956, 0.966 }, color = GLASS, material = Enum.Material.SmoothPlastic },
				{ name = "HeadLamps", meshId = 9339153182, sizeM = { 1.612, 0.193, 0.492 }, offsetM = { 0.01, 0.608, -1.818 }, color = HEADLAMP, material = Enum.Material.Neon, castShadow = false },
				{ name = "ExhaustL", meshId = 9339152604, sizeM = { 0.079, 0.281, 0.524 }, offsetM = { -0.05, 0.342, 1.835 }, color = Color3.fromRGB(120, 122, 126), material = Enum.Material.Metal },
				{ name = "ExhaustR", meshId = 9339152838, sizeM = { 0.079, 0.281, 0.524 }, offsetM = { 0.076, 0.342, 1.835 }, color = Color3.fromRGB(120, 122, 126), material = Enum.Material.Metal },
			},
			wheelPieces = wheelPieces(0.32),
		},
		tuning = {
			-- Lighter car, same springs: soften them in proportion so it
			-- sits and rolls like the sedan instead of riding on stilts.
			suspension = { stiffness = 27000, damping = 2100 },
		},
	},

	-- THE PICKUP. A 2.2 t work truck: long, heavy at the back, a lazy engine
	-- turning a lot of rotating mass. Body: "Pickup Truck No Wheels" by
	-- BadBoy12522 (store 7408695529), one textured mesh with empty arches,
	-- no brand. Measured in Studio against a 0.1 m ruler at 5.3 m long:
	-- arches at -1.74 and +1.41 m from the mesh centre (3.15 m wheelbase),
	-- wells 1.64 m apart, 1.94 m wide without mirrors, the underside 0.33 m
	-- off the ground on 0.38 m tyres.
	pickup = {
		displayName = "Pickup",
		blurb = "2.2 tonnes, tail-heavy, slow to wind up. Once it goes, it goes.",
		order = 3,
		scale = 1.2,
		rig = {
			massKg = 2200,
			collisionSizeM = { 1.85, 1.25, 5.1 },
			-- Rearward: the bed and axle are the weight, 0.25 m behind centre.
			centerOfMassM = { 0, -0.2, 0.25 },
			-- More of the mass out in the long body and bed, less in a lump at
			-- the centre: a bigger yaw and roll inertia to wind up.
			shellMassFraction = 0.55,
			wheelbaseM = 3.15,
			trackWidthM = 1.64,
			wheelRadiusM = 0.38,
			wheelWidthM = 0.26,
			seatM = { -0.42, -0.55, -0.45 },
		},
		body = {
			paint = Color3.fromRGB(214, 206, 194),
			pieces = {
				{ name = "Shell", meshId = 7408695235, textureId = 7408695426, sizeM = { 2.29, 1.61, 5.3 }, offsetM = { 0, 1.135, 0.165 } },
			},
			wheelPieces = wheelPieces(0.38),
		},
		tuning = {
			-- Heavier on stiffer springs, so it sits at the sedan's sag.
			suspension = { stiffness = 45000, damping = 4200, antiRollFront = 9000, antiRollRear = 6000 },
			drivetrain = {
				-- A tired lump: a flat, low curve that runs out early.
				torqueCurve = { { 1000, 400 }, { 2000, 540 }, { 3200, 580 }, { 4500, 540 }, { 5400, 410 }, { 6000, 0 } },
				redlineRpm = 6000,
				upshiftRpm = 5600,
				downshiftRpm = 2600,
				shiftTime = 0.2,
				topSpeedKmh = 180,
				-- Same brakes as the sedan hauling 600 kg more: it stops late.
				brakeForce = 15000,
			},
			tires = {
				-- The rear carries the weight and bites; the front is light.
				front = { grip = 0.95, slideGripRatio = 0.8 },
				rear = { grip = 1.1, slideGripRatio = 0.88, longitudinalGrip = 1.7 },
				slipModel = {
					-- High inertia: heavy wheels and a heavy flywheel, so it
					-- revs up slowly and a spinning rear keeps spinning.
					wheelInertia = 2.8,
					engineInertia = 0.45,
					-- Momentum: once sideways it carries speed.
					slideRelief = 0.35,
					leverRelief = 0.75,
				},
			},
			steering = {
				maxSteerDeg = 34,
				steerSpeedDegPerSec = 200,
				-- Its size fights a throw: less help rotating it.
				throwYawMaxTorque = 13000,
			},
			-- 600 kg more to lever onto two wheels. With the shared torques it
			-- rose 11 degrees and dropped; at 21000/7500 it went up as easily
			-- as the sedan. These get it up, lower and briefly.
			twoWheel = { liftTorque = 16500, leanInTorque = 6000, leanOutTorque = 5500, balanceSpring = 150 },
		},
	},

	-- THE CRUISER. A big, soft 1.8 t saloon: wallowing springs, a slow
	-- nose, a torquey low-revving engine, and a tail that settles into a
	-- slide and stays there. Body: "Sedan (No Wheels)" by BadBoy12522
	-- (store 5991320944) with the creator's all-colour texture (decal
	-- 5995377260, image 5995377253), no brand. Measured at 5.4 m long: arches
	-- at -1.64 and +1.34 m (3.0 m wheelbase), wells 1.70 m apart, 2.02 m wide
	-- without mirrors, the underside 0.25 m off the ground on 0.35 m tyres.
	cruiser = {
		displayName = "Cruiser",
		blurb = "Big soft saloon. Lazy on the way in, holds a slide all day.",
		order = 4,
		scale = 1.2,
		rig = {
			massKg = 1800,
			collisionSizeM = { 1.9, 1.1, 5.2 },
			centerOfMassM = { 0, -0.25, -0.1 },
			-- A long body with its mass spread out: slow to start rotating.
			shellMassFraction = 0.6,
			wheelbaseM = 3.0,
			trackWidthM = 1.7,
			wheelRadiusM = 0.35,
			wheelWidthM = 0.24,
			seatM = { -0.42, -0.45, 0 },
		},
		body = {
			paint = Color3.fromRGB(196, 190, 180),
			pieces = {
				{ name = "Shell", meshId = 5991320872, textureId = 5995377253, sizeM = { 2.26, 1.23, 5.4 }, offsetM = { 0, 0.865, 0.15 } },
			},
			wheelPieces = wheelPieces(0.35),
		},
		tuning = {
			-- Soft and long: sits 0.2 m into 0.32 m of travel, rolls a lot,
			-- and the low damping lets it float over a load change.
			suspension = { restLength = 0.45, travel = 0.32, stiffness = 20000, damping = 1400, antiRollFront = 1500, antiRollRear = 600 },
			drivetrain = {
				-- A big lazy V8: most of its pull by 2,500 rpm, gone by 5,500.
				torqueCurve = { { 1000, 450 }, { 2500, 600 }, { 3500, 620 }, { 4500, 560 }, { 5500, 420 }, { 6000, 0 } },
				redlineRpm = 6000,
				upshiftRpm = 5400,
				downshiftRpm = 2400,
				shiftTime = 0.14,
				topSpeedKmh = 200,
			},
			tires = {
				-- A soft front that pushes on turn-in, a rear that keeps most
				-- of its grip once sliding instead of letting go.
				front = { grip = 0.95, peakSlipDeg = 12, riseShape = 1.0 },
				rear = { grip = 1.02, slideGripRatio = 0.84, falloffShape = 2.0, deepSlideGripRatio = 0.6 },
				slipModel = {
					slideRelief = 0.4,
					leverRelief = 0.8,
				},
			},
			steering = {
				-- Lazy turn-in: the wheel winds on slowly.
				steerSpeedDegPerSec = 100,
				steerReturnDegPerSec = 300,
				-- A slow rack at speed: less lock for the same input past 60 km/h.
				-- The counter-steer relief still gives the whole wheel back in a slide.
				speedLockCurve = { { 0, 1 }, { 40, 1 }, { 90, 0.45 }, { 150, 0.27 }, { 220, 0.24 }, { 300, 0.24 } },
				-- Holds a slide easily: half throttle past 15 degrees is enough to
				-- keep one (the sedan wants 0.8 past 20), the hold is stiffer,
				-- and it forgives a second of lifting through a transition.
				throwThrottleHold = 0.5,
				throwThrottleHoldFromDeg = 15,
				throwThrottleHoldGraceSeconds = 1.0,
				throwThrottleHoldKeepDeg = 6,
				throwHoldGain = 8,
				-- A released slide settles slower and swings wider.
				slideYawDamping = 100,
			},
		},
	},

	-- THE KROWN VIK. The mid-2000s American full-size V8 saloon: body on
	-- frame, rear drive, the Gulf's taxi and patrol car. Body: Creator Store
	-- model 2930898738 by mesh id (tools/carbody/storecar.py), interior kept;
	-- the owner picked it over 14407499990 on looks (2026-09-26). Removed: the
	-- maker's oval, painted into a shared texture, cut out of the grille and
	-- the boot badge by texture coordinates (generated pieces Trim_3 and
	-- Trim_5); the wheel centre caps (all oval); the badge in the steering
	-- wheel; the model name in raised letters on the boot panel; the plates
	-- and lamp glass effects, which are decals and never carried over.
	-- 32,976 triangles in the store model, 31,890 here.
	--
	-- The lamps are its textured lamp faces, the real lamp shapes: the
	-- tail-light mesh, and the headlamp and corner-lamp faces split out of
	-- the grille mesh, with the clear covers over them and over the reverse
	-- lamps lighting as the whole lamp face. The corner lamps light with the
	-- headlamps (the owner: the whole front lamp lit); their amber is in the
	-- same faces' texture, so it shows with the lamps off. The
	-- kit's own lamp parts are boxes hidden inside the lamps to carry its
	-- lights, and stay unlit.
	--
	-- Placed at 0.2535 m a model stud on the real 2.913 m wheelbase.
	--
	-- Handling: the shared saloon set, like the Kamri, at about its real 1.85 t.
	krownvik = {
		displayName = "Krown Vik",
		blurb = "Big, soft and V8. Every taxi rank's favourite, now sideways.",
		order = 8,
		scale = 1.2,
		rig = {
			massKg = 1850,
			-- Nose at -2.56 m, tail at +2.82 m.
			collisionSizeM = { 1.9, 1.2, 5.0 },
			centerOfMassM = { 0, -0.3, -0.2 },
			shellMassFraction = 0.35,
			wheelbaseM = 2.913,
			trackWidthM = 1.6365,
			wheelRadiusM = 0.3278,
			wheelWidthM = 0.2271,
			-- The store model's driver seat (0.41 m left of centre), 0.22 m off
			-- the ground so a seated head clears the 1.44 m roof.
			seatM = { -0.41, -0.6, 0.06 },
		},
		body = {
			paint = Color3.fromRGB(240, 240, 236),
			pieces = {
				{ name = "Interior", meshId = 1079880560, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.2116, 0.1512, 0.0883 }, offsetM = { -0.0015, 1.2802, -0.148 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim", meshId = 1079823287, color = Color3.fromRGB(117, 0, 0), material = Enum.Material.SmoothPlastic, sizeM = { 0.2651, 0.1378, 0.181 }, offsetM = { -0.7147, 0.7717, 2.5505 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_2", meshId = 1079428220, textureId = 1079415901, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 1.8912, 0.4047, 1.0833 }, offsetM = { -0.0002, 0.4327, 2.2556 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_3", mesh = "Krownvik/Trim_3", textureId = 1079416334, color = Color3.fromRGB(91, 93, 105), material = Enum.Material.SmoothPlastic, sizeM = { 0.1227, 0.0548, 0.031 }, offsetM = { -0.0002, 0.6645, -2.4056 } },
				{ name = "HeadLamps", mesh = "Krownvik/HeadLamps", textureId = 1079416334, color = Color3.fromRGB(91, 93, 105), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.3976, 0.1361, 0.1107 }, offsetM = { -0.0002, 0.6534, -2.2899 } },
				{ name = "HeadLamps_2", mesh = "Krownvik/HeadLamps_2", textureId = 1079416334, color = Color3.fromRGB(91, 93, 105), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.7554, 0.1399, 0.3728 }, offsetM = { -0.0002, 0.6509, -2.1138 } },
				{ name = "Body", meshId = 1079951000, paint = true, sizeM = { 0.416, 1.1537, 1.053 }, offsetM = { -0.7649, 0.8369, 0.8082 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_4", meshId = 1079911410, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 0.1185, 0.0752, 0.908 }, offsetM = { -0.9017, 0.9635, -0.1347 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Glass", meshId = 1079960630, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.Glass, transparency = 0.3, castShadow = false, sizeM = { 0.1923, 0.375, 0.3058 }, offsetM = { 0.748, 1.1467, 1.0784 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome", meshId = 1079941694, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.0282, 0.0622, 0.1306 }, offsetM = { 0.8164, 0.714, -0.2871 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Glass_2", meshId = 1079951864, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.Glass, transparency = 0.3, castShadow = false, sizeM = { 0.2144, 0.4038, 0.4887 }, offsetM = { -0.7374, 1.153, 0.6596 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Glass_3", meshId = 1079940683, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.Glass, transparency = 0.3, castShadow = false, sizeM = { 0.2127, 0.4168, 0.7732 }, offsetM = { 0.7358, 1.1458, -0.0536 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Glass_4", meshId = 1079911694, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.Glass, transparency = 0.3, castShadow = false, sizeM = { 0.2127, 0.4168, 0.7732 }, offsetM = { -0.7363, 1.1458, -0.0536 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Glass_5", meshId = 1079960508, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.Glass, transparency = 0.3, castShadow = false, sizeM = { 0.2144, 0.4038, 0.4887 }, offsetM = { 0.7369, 1.153, 0.6596 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_2", meshId = 1079432062, paint = true, sizeM = { 1.5826, 0.2069, 1.4124 }, offsetM = { -0.0002, 0.8723, -1.5048 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_3", meshId = 1079807752, paint = true, sizeM = { 1.5368, 0.3595, 1.0147 }, offsetM = { -0.0002, 0.8371, 2.1643 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_5", mesh = "Krownvik/Trim_5", textureId = 1079416334, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.4384, 0.1896, 0.0306 }, offsetM = { 0.1686, 0.8343, 2.6518 } },
				{ name = "Trim_6", meshId = 1079808667, color = Color3.fromRGB(0, 0, 0), material = Enum.Material.SmoothPlastic, sizeM = { 1.2589, 0.1493, 0.044 }, offsetM = { -0.0002, 0.7644, 2.647 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_2", meshId = 1079903410, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.3945, 0.3674, 0.2197 }, offsetM = { -0.3891, 0.8786, -0.2387 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_7", meshId = 1079811109, textureId = 1079415901, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 1.5368, 0.3784, 0.9597 }, offsetM = { -0.0002, 0.8242, 2.1943 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_3", meshId = 1079904281, color = Color3.fromRGB(49, 49, 49), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.2712, 0.0655, 0.048 }, offsetM = { -0.3887, 0.8241, -0.1935 }, rotationDeg = { 0, 180, 0 } },
				{ name = "ReverseLamps", meshId = 1079809454, textureId = 1079416334, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, transparency = 0.6, castShadow = false, sizeM = { 0.6703, 0.174, 0.0644 }, offsetM = { -0.0002, 0.7436, 2.6404 }, rotationDeg = { 0, 180, 0 } },
				{ name = "ReverseLamps_2", meshId = 1079809454, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.6703, 0.174, 0.0644 }, offsetM = { -0.0002, 0.7436, 2.6366 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_2", meshId = 1079809176, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 1.2676, 0.2141, 0.055 }, offsetM = { -0.0002, 0.742, 2.6493 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_8", meshId = 1079942079, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 0.0733, 0.3063, 0.5434 }, offsetM = { 0.8026, 0.8096, -0.1147 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_4", meshId = 1079938092, paint = true, sizeM = { 0.5216, 1.163, 1.3313 }, offsetM = { 0.8173, 0.832, -0.2477 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_4", meshId = 1079941118, textureId = 1079415609, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0705, 0.0489, 0.1054 }, offsetM = { 0.7543, 0.6148, 0.1385 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_3", meshId = 1079939672, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.0258, 0.0488, 0.2192 }, offsetM = { 0.952, 0.8182, 0.1525 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_9", meshId = 1079940865, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 0.331, 0.4444, 1.1068 }, offsetM = { 0.795, 1.1423, -0.145 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_10", meshId = 1079941899, textureId = 1079416334, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.0696, 0.1639, 0.1342 }, offsetM = { 0.7828, 1.0423, -0.4885 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_4", meshId = 1079939872, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.4442, 0.4739, 1.1303 }, offsetM = { 0.837, 1.1401, -0.1529 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_5", meshId = 1079941547, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.1504, 0.7896, 1.0003 }, offsetM = { 0.7844, 0.6835, -0.2334 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_6", meshId = 1079960856, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.1395, 0.6832, 0.9082 }, offsetM = { 0.7935, 0.6235, 0.7926 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_5", meshId = 1079960971, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.0282, 0.061, 0.1453 }, offsetM = { 0.8381, 0.6851, 0.575 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_6", meshId = 1079960427, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.2634, 0.4564, 0.9647 }, offsetM = { 0.7465, 1.1488, 0.7972 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_7", meshId = 1079960288, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.0287, 0.0488, 0.2223 }, offsetM = { 0.9483, 0.833, 1.1028 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_11", meshId = 1079960737, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 0.2373, 0.7361, 0.9258 }, offsetM = { 0.7484, 0.9969, 0.7808 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_5", meshId = 1079960161, paint = true, sizeM = { 0.416, 1.1537, 1.053 }, offsetM = { 0.7644, 0.8369, 0.8083 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_7", meshId = 1079913237, textureId = 1079415609, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.1792, 0.3406, 0.7475 }, offsetM = { -0.8005, 0.7583, -0.1644 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_8", meshId = 1079930331, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.1504, 0.8023, 1.0094 }, offsetM = { -0.7762, 0.6848, -0.2191 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_8", meshId = 1079911222, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.4442, 0.4739, 1.1303 }, offsetM = { -0.8374, 1.1401, -0.1529 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_12", meshId = 1079915509, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 0.1323, 0.309, 0.713 }, offsetM = { -0.824, 0.8092, -0.1816 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_13", meshId = 1079914951, textureId = 1079416334, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.2144, 0.313, 0.8051 }, offsetM = { -0.8557, 0.9677, -0.153 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_9", meshId = 1079930542, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.0282, 0.0628, 0.1318 }, offsetM = { -0.8083, 0.7128, -0.2733 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_10", meshId = 1079912110, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.0762, 0.1348, 0.8002 }, offsetM = { -0.9272, 0.8612, -0.138 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_6", meshId = 1079910963, paint = true, sizeM = { 0.5216, 1.163, 1.3313 }, offsetM = { -0.8177, 0.832, -0.2477 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_14", meshId = 1079913037, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 0.331, 0.4444, 1.1068 }, offsetM = { -0.7954, 1.1423, -0.145 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_11", meshId = 1079952778, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.0282, 0.0622, 0.1424 }, offsetM = { -0.8343, 0.6824, 0.5983 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_9", meshId = 1079952235, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.1395, 0.6964, 0.8901 }, offsetM = { -0.7897, 0.6197, 0.8116 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Glass_6", meshId = 1079951684, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.Glass, transparency = 0.3, castShadow = false, sizeM = { 0.1923, 0.375, 0.3058 }, offsetM = { -0.7484, 1.1467, 1.0784 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_12", meshId = 1079952016, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.2634, 0.4564, 0.9647 }, offsetM = { -0.747, 1.1488, 0.7972 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_15", meshId = 1079952115, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 0.2373, 0.7398, 0.9258 }, offsetM = { -0.7488, 0.995, 0.7808 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_13", meshId = 1079951544, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.0287, 0.0488, 0.2223 }, offsetM = { -0.9488, 0.833, 1.1028 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_16", meshId = 1079964870, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, sizeM = { 1.422, 0.1373, 0.1568 }, offsetM = { -0.0002, 0.654, -2.2844 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_17", meshId = 1079968631, color = Color3.fromRGB(170, 85, 0), material = Enum.Material.SmoothPlastic, sizeM = { 0.1665, 0.1399, 0.3728 }, offsetM = { -0.7947, 0.6496, -2.1125 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_18", meshId = 1079966669, color = Color3.fromRGB(170, 85, 0), material = Enum.Material.SmoothPlastic, sizeM = { 0.1665, 0.1399, 0.3728 }, offsetM = { 0.7917, 0.6496, -2.1125 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_19", meshId = 1079822602, color = Color3.fromRGB(117, 0, 0), material = Enum.Material.SmoothPlastic, sizeM = { 1.5033, 0.3306, 0.8732 }, offsetM = { -0.0002, 0.9221, 2.1985 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_20", meshId = 1079823831, color = Color3.fromRGB(117, 0, 0), material = Enum.Material.SmoothPlastic, sizeM = { 0.2651, 0.1378, 0.181 }, offsetM = { 0.7143, 0.7717, 2.5505 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_7", meshId = 1079429009, paint = true, sizeM = { 1.9278, 0.4047, 1.1039 }, offsetM = { -0.0002, 0.4327, 2.2659 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_14", meshId = 1079428671, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 1.8903, 0.0312, 0.9454 }, offsetM = { -0.0002, 0.5177, 2.3455 }, rotationDeg = { 0, 180, 0 } },
				{ name = "TailLamps", meshId = 1079824025, textureId = 1079416334, color = Color3.fromRGB(196, 40, 28), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.7087, 0.2407, 0.2085 }, offsetM = { -0.0002, 0.8091, 2.5424 }, rotationDeg = { 0, 180, 0 } },
				{ name = "HeadLamps_3", meshId = 1079829842, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, transparency = 0.7, castShadow = false, sizeM = { 0.1813, 0.1541, 0.3897 }, offsetM = { -0.7968, 0.653, -2.1154 }, rotationDeg = { 0, 180, 0 } },
				{ name = "HeadLamps_4", meshId = 1079829252, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, transparency = 0.7, castShadow = false, sizeM = { 0.1813, 0.1541, 0.3897 }, offsetM = { 0.7963, 0.653, -2.1154 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_8", meshId = 1079797878, paint = true, sizeM = { 1.9097, 0.6971, 1.4282 }, offsetM = { -0.0002, 0.5972, -1.5155 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_15", meshId = 1079824843, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 1.7384, 0.0557, 0.2281 }, offsetM = { -0.0002, 0.6619, 2.5384 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_9", meshId = 1079815908, paint = true, sizeM = { 1.956, 1.2741, 3.7197 }, offsetM = { -0.0002, 0.8073, 0.8143 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Underbody", meshId = 1079817579, textureId = 1079415901, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Fabric, sizeM = { 1.9185, 1.2538, 5.097 }, offsetM = { -0.0002, 0.7844, 0.1359 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_21", meshId = 1079798784, textureId = 1079415901, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 1.902, 0.6939, 1.4267 }, offsetM = { -0.0002, 0.5956, -1.5147 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_22", meshId = 1080668195, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 1.606, 0.455, 2.767 }, offsetM = { -0.0002, 1.1477, 0.4744 } },
				{ name = "Interior_10", meshId = 1079838832, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.1974, 0.2381, 0.1333 }, offsetM = { 0.0087, 0.832, -0.4263 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_11", meshId = 1079858678, color = Color3.fromRGB(49, 49, 49), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.9996, 0.187, 0.1379 }, offsetM = { -0.2776, 0.9175, -0.4548 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_12", meshId = 1079868788, textureId = 1079417127, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.4256, 0.9371, 0.9142 }, offsetM = { 0.0015, 0.7134, 0.1338 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_13", meshId = 1079878192, textureId = 1079417127, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.4746, 0.4077, 0.5433 }, offsetM = { -0.0007, 1.1455, 0.1039 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_14", meshId = 1079817097, textureId = 1079416334, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Sand, castShadow = false, sizeM = { 1.9263, 1.1609, 3.896 }, offsetM = { -0.0002, 0.8309, -0.0901 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_16", meshId = 1079877383, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 1.434, 0.0446, 0.0743 }, offsetM = { 0, 0.9228, 0.3266 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_15", meshId = 1079820099, color = Color3.fromRGB(199, 172, 120), material = Enum.Material.Fabric, castShadow = false, sizeM = { 1.5768, 0.5029, 0.3435 }, offsetM = { -0.0002, 0.7594, 1.1431 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_16", meshId = 1079864458, color = Color3.fromRGB(108, 95, 86), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.6197, 0.4968, 0.5921 }, offsetM = { -0.0076, 0.7873, -0.5818 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_17", meshId = 1079873551, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.1234, 0.2096, 0.0663 }, offsetM = { -0.288, 0.9083, -0.385 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_18", meshId = 1079868244, textureId = 1079417127, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.6681, 0.7469, 0.845 }, offsetM = { -0.001, 0.6165, 0.9974 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_17", meshId = 1079871464, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 1.427, 0.7077, 1.3317 }, offsetM = { 0.0015, 0.6484, 0.6041 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_19", meshId = 1079876716, textureId = 1079417127, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.0783, 0.0523, 1.0564 }, offsetM = { -0.0022, 1.334, 0.361 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_20", meshId = 1079819784, color = Color3.fromRGB(199, 172, 120), material = Enum.Material.Fabric, castShadow = false, sizeM = { 1.606, 1.1562, 2.5725 }, offsetM = { -0.0002, 0.7989, 0.4267 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_21", meshId = 1079872841, color = Color3.fromRGB(196, 40, 28), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.4749, 0.0435, 0.8998 }, offsetM = { 0.0087, 0.4301, 0.5007 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_22", meshId = 1079859133, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.4611, 0.105, 0.1288 }, offsetM = { -0.0152, 0.8837, -0.4676 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_23", meshId = 1079861942, color = Color3.fromRGB(105, 64, 40), material = Enum.Material.Wood, castShadow = false, sizeM = { 1.5316, 0.0313, 0.0553 }, offsetM = { -0.0086, 0.8192, -0.4048 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_24", meshId = 1079881264, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.2034, 0.044, 0.0136 }, offsetM = { -0.0015, 1.2418, -0.1273 }, rotationDeg = { 0, 180, 0 } },
				{ name = "HeadLamps_5", meshId = 1079830260, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, transparency = 0.7, castShadow = false, sizeM = { 1.4546, 0.1535, 0.1511 }, offsetM = { -0.0002, 0.6527, -2.3036 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_23", meshId = 1079418529, textureId = 1079415901, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 1.8065, 0.6121, 0.6924 }, offsetM = { -0.0002, 0.5165, -2.1562 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_10", meshId = 1079423248, paint = true, sizeM = { 1.8265, 0.6155, 0.7464 }, offsetM = { -0.0002, 0.5182, -2.1832 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_18", meshId = 1079422754, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 1.7715, 0.3476, 0.574 }, offsetM = { -0.0002, 0.6198, -2.2696 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Glass_7", meshId = 1080666644, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.Glass, transparency = 0.3, castShadow = false, sizeM = { 1.5154, 0.374, 2.6699 }, offsetM = { -0.0002, 1.1591, 0.4922 } },
			},
			wheelPieces = {
				{ name = "Tyre", meshId = 1079832529, color = Color3.fromRGB(0, 0, 0), material = Enum.Material.Concrete, sizeM = { 0.2271, 0.6556, 0.6522 }, offsetM = { 0, 0, 0 }, rotationDeg = { 0, 0, 0 } },
				{ name = "Rim", meshId = 1079833195, color = Color3.fromRGB(159, 161, 172), material = Enum.Material.Metal, sizeM = { 0.2164, 0.4406, 0.4457 }, offsetM = { -0.0011, -0.0001, 0 }, rotationDeg = { 0, 0, 0 } },
				{ name = "Rim_Disc", meshId = 1079834210, textureId = 1079415901, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Metal, sizeM = { 0.0258, 0.3321, 0.3307 }, offsetM = { 0.054, 0.004, -0.0001 }, rotationDeg = { 0, 0, 0 } },
			},
		},
		tuning = {
			effects = {
				-- The store model's own sounds (its "Set" script, a different kit
				-- from A-Chassis): one engine file for every layer (the layers
				-- differ by EQ). The kit plays it at rpm / 5000 (the idle at 0.9
				-- of that; layers sharing a file share one Sound, so one refRpm),
				-- so refRpm is 5000. Its startup and horn too; its door chime
				-- (339544300) is private and will not load here, so it keeps
				-- the shared chime.
				engineAudio = {
					startSoundId = "rbxassetid://169394147",
					layers = {
						idle = { soundId = "rbxassetid://426479434", refRpm = 5000, volume = 0.5, eq = { 0, 0, -6 } },
						lowLoad = { soundId = "rbxassetid://426479434", refRpm = 5000, volume = 0.8, eq = { 3, 0, -3 } },
						highLoad = { soundId = "rbxassetid://426479434", refRpm = 5000, volume = 1, eq = { 0, 2, 2 } },
						overrun = { soundId = "rbxassetid://426479434", refRpm = 5000, volume = 0.5, eq = { 0, -2, -8 } },
					},
				},
				horn = { soundId = "rbxassetid://143133249" },
				-- Its tail lenses are opaque, so the shared tail colour lit them
				-- nearly as bright as the brake: the Kruzer 80's darker tail.
				lamps = { tailColor = Color3.fromRGB(105, 5, 7) },
			},
		},
	},
	-- THE LEKZAS. The early-2000s Japanese luxury saloon: the long, quiet
	-- one the Gulf drifts in a thobe. Body: Creator Store model 5405292580 by
	-- mesh id (tools/carbody/storecar.py), interior kept. Removed: the
	-- maker's grille emblem, boot emblem and the two boot scripts, all cut
	-- out of the one chrome mesh (8,447 to 4,532 triangles). That chrome is a
	-- generated piece, so it is left off until assets/cars/lekzas/Chrome_3.obj
	-- is uploaded and its meshId goes on the piece (the owner, 2026-09-25: no
	-- chrome rather than a grey box). 51,081 triangles in the store model,
	-- 47,070 here. The wheel caps and steering wheel carry no logo.
	--
	-- Placed at 0.2514 m a model stud on the real 2.925 m wheelbase.
	--
	-- Handling: the shared saloon set, like the Kamri, at its real 1.8 t.
	lekzas = {
		displayName = "Lekzas",
		blurb = "Long, heavy and silent. Floats through a slide like it owns the road.",
		order = 7,
		scale = 1.2,
		rig = {
			massKg = 1800,
			-- Nose at -2.28 m, tail at +2.67 m.
			collisionSizeM = { 1.85, 1.2, 4.7 },
			centerOfMassM = { 0, -0.3, -0.2 },
			shellMassFraction = 0.35,
			wheelbaseM = 2.925,
			trackWidthM = 1.5462,
			wheelRadiusM = 0.3459,
			wheelWidthM = 0.2271,
			-- The store model's driver seat (0.31 m left of centre), 0.30 m off
			-- the ground so a seated head clears the 1.60 m roof.
			seatM = { -0.31, -0.54, -0.1 },
		},
		body = {
			paint = Color3.fromRGB(211, 190, 150),
			pieces = {
				{ name = "Trim", meshId = 4719876638, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, sizeM = { 0.1557, 0.0516, 0.1574 }, offsetM = { 0.747, 0.7014, -1.9891 } },
				{ name = "Trim_2", meshId = 4719876924, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, sizeM = { 0.1386, 0.1386, 0.0753 }, offsetM = { 0.7275, 0.7913, -1.8703 } },
				{ name = "Trim_3", meshId = 4719876785, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, sizeM = { 0.1039, 0.1039, 0.071 }, offsetM = { 0.584, 0.7517, -2.015 } },
				{ name = "HeadLamps", meshId = 4719875291, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.Glass, transparency = 0.9, castShadow = false, sizeM = { 1.6726, 0.5338, 0.3898 }, offsetM = { 0, 0.6222, -1.9797 } },
				{ name = "Body", meshId = 4719886987, paint = true, sizeM = { 1.7799, 0.8003, 1.5183 }, offsetM = { 0, 0.6188, -1.519 } },
				{ name = "Body_2", meshId = 4719887184, paint = true, sizeM = { 2.0297, 0.807, 3.5225 }, offsetM = { 0, 0.7118, 0.9015 } },
				{ name = "Underbody", meshId = 4719875050, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 1.758, 0.5556, 4.7636 }, offsetM = { 0, 0.464, 0.1915 } },
				{ name = "Chrome", meshId = 4719874909, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, sizeM = { 1.6743, 0.4108, 0.6216 }, offsetM = { 0, 0.8877, 2.248 } },
				{ name = "Chrome_2", meshId = 4719872556, color = Color3.fromRGB(166, 166, 166), material = Enum.Material.SmoothPlastic, sizeM = { 1.2769, 0.1926, 0.5904 }, offsetM = { 0, 0.3282, 2.2411 } },
				{ name = "Trim_4", meshId = 4719872314, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 1.6185, 1.2515, 4.2052 }, offsetM = { 0, 0.9766, -0.1419 } },
				{ name = "Chrome_3", mesh = "Lekzas/Chrome_3", color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, sizeM = { 1.8031, 0.9497, 4.9353 }, offsetM = { 0, 0.9439, 0.1946 } },
				{ name = "Interior", meshId = 4719874133, color = Color3.fromRGB(196, 190, 185), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.564, 0.8563, 1.8664 }, offsetM = { 0, 0.829, 0.529 } },
				{ name = "Trim_5", meshId = 4719873524, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 1.7543, 1.0752, 4.7963 }, offsetM = { 0, 0.8409, 0.1715 } },
				{ name = "Trim_6", meshId = 4719873364, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 1.5231, 0.4078, 3.1297 }, offsetM = { 0, 1.1821, 0.5044 } },
				{ name = "Interior_2", meshId = 4719874301, color = Color3.fromRGB(196, 190, 185), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.6056, 1.1565, 3.1147 }, offsetM = { 0, 0.8602, 0.5119 } },
				{ name = "Trim_7", meshId = 4719877150, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, sizeM = { 0.1039, 0.1039, 0.071 }, offsetM = { -0.584, 0.7517, -2.015 } },
				{ name = "Trim_8", meshId = 4719877042, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, sizeM = { 0.1557, 0.0516, 0.1574 }, offsetM = { -0.747, 0.7014, -1.9891 } },
				{ name = "Trim_9", meshId = 4719877295, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, sizeM = { 0.1386, 0.1386, 0.0753 }, offsetM = { -0.7275, 0.7913, -1.8703 } },
				{ name = "FogLamps", meshId = 4719877575, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.2345, 0.0767, 0.1471 }, offsetM = { 0.7191, 0.3936, -2.101 } },
				{ name = "Indicators", meshId = 4719877704, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.Glass, transparency = 0.1, castShadow = false, sizeM = { 0.2336, 0.0549, 0.2106 }, offsetM = { -0.703, 0.7985, 2.4379 } },
				{ name = "FogLamps_2", meshId = 4719877425, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.2345, 0.0767, 0.1469 }, offsetM = { -0.7191, 0.3936, -2.1009 } },
				{ name = "TailLamps", meshId = 4719878008, color = Color3.fromRGB(151, 0, 0), material = Enum.Material.Glass, transparency = 0.2, castShadow = false, sizeM = { 0.2384, 0.2332, 0.0442 }, offsetM = { -0.5195, 0.799, 2.5367 } },
				{ name = "TailLamps_2", meshId = 4719878224, color = Color3.fromRGB(151, 0, 0), material = Enum.Material.Glass, transparency = 0.2, castShadow = false, sizeM = { 0.2384, 0.2332, 0.0442 }, offsetM = { 0.5195, 0.799, 2.5367 } },
				{ name = "Indicators_2", meshId = 4719877800, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.Glass, transparency = 0.1, castShadow = false, sizeM = { 0.2336, 0.0549, 0.2106 }, offsetM = { 0.703, 0.7985, 2.4379 } },
				{ name = "TailLamps_3", meshId = 4719877910, color = Color3.fromRGB(151, 0, 0), material = Enum.Material.Glass, transparency = 0.2, castShadow = false, sizeM = { 0.2922, 0.2362, 0.292 }, offsetM = { -0.691, 0.8004, 2.4034 } },
				{ name = "TailLamps_4", meshId = 4719878124, color = Color3.fromRGB(151, 0, 0), material = Enum.Material.Glass, transparency = 0.2, castShadow = false, sizeM = { 0.2922, 0.2362, 0.292 }, offsetM = { 0.691, 0.8004, 2.4034 } },
				{ name = "Body_3", meshId = 4719878876, paint = true, sizeM = { 1.8177, 1.2919, 3.7322 }, offsetM = { 0, 0.8321, 0.8003 } },
				{ name = "TailLamps_5", meshId = 4719878328, color = Color3.fromRGB(151, 0, 0), material = Enum.Material.Glass, transparency = 0.2, castShadow = false, sizeM = { 0.2368, 0.0285, 0.0272 }, offsetM = { 0, 1.0789, 1.9644 } },
				{ name = "ReverseLamps", meshId = 4719878442, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.Glass, transparency = 0.1, castShadow = false, sizeM = { 1.2116, 0.0546, 0.0272 }, offsetM = { 0, 0.7987, 2.5419 } },
				{ name = "Trim_10", meshId = 4719878599, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 2.006, 0.3351, 0.2774 }, offsetM = { 0, 1.1511, -0.451 } },
				{ name = "Glass", meshId = 4719880211, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.8, castShadow = false, sizeM = { 1.6133, 0.4409, 3.03 }, offsetM = { 0, 1.1842, 0.5206 } },
				{ name = "Glass_2", meshId = 4719880088, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.5, castShadow = false, sizeM = { 1.1597, 0.057, 0.1192 }, offsetM = { 0, 1.344, -0.3583 } },
				{ name = "Interior_3", meshId = 4719875583, color = Color3.fromRGB(34, 0, 0), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.4885, 0.3479, 1.7492 }, offsetM = { 0, 0.4581, -0.1454 } },
				{ name = "Indicators_3", meshId = 4719876344, color = Color3.fromRGB(200, 174, 102), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.6497, 0.0516, 0.1574 }, offsetM = { 0, 0.7014, -1.9891 } },
				{ name = "Interior_4", meshId = 4719875427, color = Color3.fromRGB(53, 53, 53), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.615, 0.5852, 2.4264 }, offsetM = { 0, 0.8255, 0.1528 } },
				{ name = "Indicators_4", meshId = 4719876485, color = Color3.fromRGB(200, 174, 102), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.7906, 0.0317, 0.0693 }, offsetM = { 0, 0.7468, -1.0171 } },
			},
			wheelPieces = {
				{ name = "Tyre", meshId = 4719879990, color = Color3.fromRGB(23, 23, 23), material = Enum.Material.SmoothPlastic, sizeM = { 0.2271, 0.6917, 0.6918 }, offsetM = { 0, 0, 0 }, rotationDeg = { 0, 0, 0 } },
				{ name = "Rim", meshId = 4719876196, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, sizeM = { 0.2054, 0.4603, 0.4603 }, offsetM = { -0.0027, 0, 0 }, rotationDeg = { 0, 0, 0 } },
				{ name = "Rim_Cap", meshId = 4719873069, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, sizeM = { 0.0258, 0.1271, 0.1364 }, offsetM = { -0.0792, 0.0056, 0 }, rotationDeg = { 0, 0, 0 } },
				{ name = "Rim_Nuts", meshId = 4719873885, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.037, 0.1393, 0.1464 }, offsetM = { -0.0478, 0.0056, 0 }, rotationDeg = { 0, 0, 0 } },
				{ name = "Rim_Disc", meshId = 4719879363, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Metal, sizeM = { 0.0126, 0.3168, 0.3167 }, offsetM = { 0.0283, 0, 0 }, rotationDeg = { 0, 0, 0 } },
			},
		},
		tuning = {
			effects = {
				-- Its A-Chassis "Rev" loop, one file for every layer (the layers
				-- differ by EQ). The plugin plays it at pitch 0.05 + 1.1 x rpm /
				-- 7250, which is 1 at 6260 rpm: that is refRpm. No horn or
				-- ignition sounds in the model, so it keeps the shared ones.
				engineAudio = {
					layers = {
						idle = { soundId = "rbxassetid://1489232045", refRpm = 6260, volume = 0.5, eq = { 0, 0, -6 } },
						lowLoad = { soundId = "rbxassetid://1489232045", refRpm = 6260, volume = 0.8, eq = { 3, 0, -3 } },
						highLoad = { soundId = "rbxassetid://1489232045", refRpm = 6260, volume = 1, eq = { 0, 2, 2 } },
						overrun = { soundId = "rbxassetid://1489232045", refRpm = 6260, volume = 0.5, eq = { 0, -2, -8 } },
					},
				},
			},
		},
	},
	-- THE KAMRI (id kamri07; the default car since it replaced the
	-- generated-body kamri above). A mid-2000s Japanese saloon from the Creator Store
	-- (asset 876308553, an A-Chassis car). The body is the store model's own
	-- meshes, untouched and referenced by id (no upload): 89 of its parts,
	-- 143,632 triangles of the original 158,140, interior included. Removed
	-- only what cannot be seen: the parts no ray from outside reaches
	-- (brackets, stacked duplicates), the engine bay, the boot interior and
	-- the floor pan and tray under the car; and the badges, including the
	-- chrome boot strip that carries the maker's oval and lettering. The
	-- sunroof glass is a plain block with no mesh id, so the sunroof reads
	-- open. assets/cars/kamri07/README.md has the list.
	--
	-- Placed from the Studio model at 0.2505 m a stud, so its wheel centres
	-- sit on the real 2.775 m wheelbase: 4.83 m long, 1.52 m track, 0.66 m
	-- tyres. Same mass and handling as the Kamri.
	kamri07 = {
		displayName = "Kamri",
		blurb = "The big Japanese saloon. Planted, predictable, carries a slide.",
		order = 1,
		scale = 1.2,
		rig = {
			massKg = 1600,
			-- Nose at -2.36 m, tail at +2.47 m.
			collisionSizeM = { 1.8, 1.2, 4.6 },
			centerOfMassM = { 0, -0.3, -0.2 },
			shellMassFraction = 0.35,
			wheelbaseM = 2.775,
			trackWidthM = 1.5226,
			wheelRadiusM = 0.3299,
			wheelWidthM = 0.2505,
			-- Behind the wheel (0.38 m left, 0.55 m behind it), 0.25 m off the
			-- ground: a seated head tops out at 1.45 m, under the 1.48 m roof.
			seatM = { -0.38, -0.57, -0.15 },
		},
		body = {
			paint = Color3.fromRGB(236, 236, 232),
			pieces = {
				{ name = "P21", meshId = 1579912421, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, sizeM = { 0.2141, 0.7215, 1.1872 }, offsetM = { -0.7158, 1.0472, -0.3043 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P23", meshId = 1578513038, color = Color3.fromRGB(50, 50, 50), material = Enum.Material.Sand, sizeM = { 1.4874, 0.4411, 2.0403 }, offsetM = { -0.002, 0.4506, -0.0864 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P24", meshId = 1579911664, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Plastic, sizeM = { 0.2136, 0.7234, 1.1778 }, offsetM = { -0.7199, 1.0307, -0.3005 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P31", meshId = 1578441700, color = Color3.fromRGB(99, 95, 98), material = Enum.Material.SmoothPlastic, sizeM = { 1.2788, 0.2059, 3.9089 }, offsetM = { -0.0018, 0.2693, 0.2753 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P32", meshId = 1579913008, color = Color3.fromRGB(99, 95, 98), material = Enum.Material.SmoothPlastic, sizeM = { 0.415, 1.0496, 1.1716 }, offsetM = { -0.8055, 0.8594, -0.3354 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P34", meshId = 1579917137, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.2, castShadow = false, sizeM = { 0.1758, 0.366, 1.0286 }, offsetM = { -0.7133, 1.2102, 0.8177 }, rotationDeg = { 0, -180, 0 } },
				{ name = "Indicators_P35", meshId = 1579962001, color = Color3.fromRGB(208, 142, 0), material = Enum.Material.SmoothPlastic, sizeM = { 1.693, 0.1134, 0.2075 }, offsetM = { -0.0018, 0.7415, -1.8222 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P37", meshId = 1579933123, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.35, castShadow = false, sizeM = { 1.476, 0.433, 0.9045 }, offsetM = { -0.0018, 1.1649, -0.765 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P38", meshId = 1578419470, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.4564, 0.154, 0.0946 }, offsetM = { -0.002, 0.6511, -2.2573 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P40", meshId = 1578410642, paint = true, sizeM = { 1.8057, 0.5801, 0.8856 }, offsetM = { -0.0018, 0.5514, 2.0372 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P41", meshId = 1578435612, color = Color3.fromRGB(5, 5, 5), material = Enum.Material.SmoothPlastic, sizeM = { 1.8038, 0.5426, 4.681 }, offsetM = { -0.0018, 0.4721, 0.0659 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P42", meshId = 1578483202, color = Color3.fromRGB(99, 95, 98), material = Enum.Material.Plastic, sizeM = { 1.3747, 0.468, 0.7265 }, offsetM = { -0.003, 0.8232, -0.8483 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P50", meshId = 1578529801, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Plastic, sizeM = { 1.6489, 1.1321, 4.1536 }, offsetM = { -0.0018, 0.8655, 0.2775 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P58", meshId = 1578416837, color = Color3.fromRGB(25, 25, 25), material = Enum.Material.SmoothPlastic, sizeM = { 1.5156, 0.5046, 0.2904 }, offsetM = { -0.002, 0.5074, -2.1715 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P60", meshId = 2056500521, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 1.3207, 0.0935, 0.1162 }, offsetM = { 0.0017, 0.3918, 2.3916 } },
				{ name = "P61", meshId = 2056494859, paint = true, sizeM = { 1.7685, 0.1848, 0.7016 }, offsetM = { 0.0017, 0.3835, 2.1116 } },
				{ name = "P62", meshId = 2056494443, paint = true, sizeM = { 1.7882, 0.1661, 2.02 }, offsetM = { -0.0007, 0.2911, 0.0108 } },
				{ name = "P63", meshId = 2056493341, paint = true, sizeM = { 1.8126, 0.2043, 0.5946 }, offsetM = { -0.0013, 0.3175, -2.0692 } },
				{ name = "HeadLamps_P64", meshId = 1579955059, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, transparency = 0.75, castShadow = false, sizeM = { 1.6954, 0.2012, 0.4798 }, offsetM = { -0.0018, 0.6999, -1.9544 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P65", meshId = 1579914286, color = Color3.fromRGB(99, 95, 98), material = Enum.Material.SmoothPlastic, sizeM = { 0.0131, 0.1688, 0.2779 }, offsetM = { -0.7242, 0.5924, -0.6367 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P66", meshId = 1579906934, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, sizeM = { 0.2078, 0.6908, 1.1326 }, offsetM = { 0.7156, 1.0629, 0.7963 }, rotationDeg = { 0, -180, 0 } },
				{ name = "TailLamps_P68", meshId = 1579949728, color = Color3.fromRGB(117, 0, 0), material = Enum.Material.SmoothPlastic, sizeM = { 1.2099, 0.1673, 0.077 }, offsetM = { -0.0018, 0.8723, 2.3135 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P69", meshId = 1578584236, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.2779, 0.1158, 0.0716 }, offsetM = { -0.3838, 0.8581, -0.3959 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P70", meshId = 1578606330, paint = true, sizeM = { 1.3631, 0.4036, 0.5204 }, offsetM = { -0.0018, 0.9229, 2.1291 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P71", meshId = 1578607620, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, sizeM = { 1.233, 0.1707, 0.124 }, offsetM = { -0.0018, 0.8927, 2.3165 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P72", meshId = 1579926606, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.2, castShadow = false, sizeM = { 0.1758, 0.366, 1.0286 }, offsetM = { 0.7063, 1.1676, -0.2477 }, rotationDeg = { 4.891, -180, 0 } },
				{ name = "P73", meshId = 1579872296, color = Color3.fromRGB(0, 0, 0), material = Enum.Material.SmoothPlastic, sizeM = { 0.3646, 0.1088, 0.0295 }, offsetM = { -0.3779, 0.9058, -0.7621 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P74", meshId = 1579929445, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 1.286, 0.2978, 0.8048 }, offsetM = { -0.0016, 1.272, 1.538 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P75", meshId = 1579913505, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Plastic, sizeM = { 0.1212, 0.7485, 1.0468 }, offsetM = { -0.7389, 0.7465, -0.3742 }, rotationDeg = { 0, -180, 0 } },
				{ name = "TailLamps_P82", meshId = 1579944508, color = Color3.fromRGB(117, 0, 0), material = Enum.Material.SmoothPlastic, sizeM = { 1.6128, 0.1662, 0.3835 }, offsetM = { -0.0018, 0.8897, 2.1495 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P85", meshId = 1578582244, color = Color3.fromRGB(99, 95, 98), material = Enum.Material.Plastic, sizeM = { 0.3417, 0.3212, 0.1629 }, offsetM = { -0.3838, 0.8907, -0.4086 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P92", meshId = 1579885532, paint = true, sizeM = { 1.1392, 0.1148, 1.5376 }, offsetM = { -0.0018, 1.423, 0.3834 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P93", meshId = 1579897436, paint = true, sizeM = { 0.4131, 1.1313, 1.2562 }, offsetM = { 0.8088, 0.8414, -0.3399 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P94", meshId = 1579898449, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Plastic, sizeM = { 0.1212, 0.7485, 1.0468 }, offsetM = { 0.7354, 0.7465, -0.3742 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P101", meshId = 1579899876, color = Color3.fromRGB(99, 95, 98), material = Enum.Material.SmoothPlastic, sizeM = { 0.0131, 0.1688, 0.2779 }, offsetM = { 0.7207, 0.5924, -0.6367 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P102", meshId = 1579903619, paint = true, sizeM = { 0.3046, 1.1076, 1.1734 }, offsetM = { 0.7548, 0.8536, 0.7869 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P103", meshId = 1579892656, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, sizeM = { 0.2637, 0.9398, 1.2948 }, offsetM = { 0.7417, 0.9372, -0.3582 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P104", meshId = 1579893317, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.1756, 0.1083, 0.0452 }, offsetM = { 0.9188, 1.0503, -0.6269 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P105", meshId = 1579945277, color = Color3.fromRGB(180, 180, 180), material = Enum.Material.SmoothPlastic, sizeM = { 1.5916, 0.0503, 0.2071 }, offsetM = { -0.0018, 0.9367, 2.0876 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P107", meshId = 1579969442, paint = true, sizeM = { 1.8102, 0.6006, 0.7659 }, offsetM = { -0.002, 0.4998, -1.9617 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P108", meshId = 1578467301, color = Color3.fromRGB(99, 95, 98), material = Enum.Material.SmoothPlastic, sizeM = { 1.3945, 0.0795, 0.0541 }, offsetM = { -0.0018, 0.7029, -1.9853 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P110", meshId = 1578503237, color = Color3.fromRGB(25, 25, 25), material = Enum.Material.SmoothPlastic, sizeM = { 1.6178, 1.2012, 3.4395 }, offsetM = { -0.0012, 0.8735, 0.6592 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P111", meshId = 1578494195, color = Color3.fromRGB(25, 25, 25), material = Enum.Material.SmoothPlastic, sizeM = { 1.713, 1.2019, 4.5709 }, offsetM = { -0.0018, 0.8732, 0.0935 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P112", meshId = 1579907874, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.2636, 1.0447, 1.1106 }, offsetM = { -0.7308, 0.869, 0.7861 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P113", meshId = 1579891432, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Plastic, sizeM = { 0.218, 0.739, 1.1863 }, offsetM = { 0.7142, 1.0385, -0.3048 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P120", meshId = 1579907808, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.2636, 1.0447, 1.1106 }, offsetM = { 0.7273, 0.869, 0.7861 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P121", meshId = 1578553072, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.3899, 0.2273, 0.5006 }, offsetM = { -0.6505, 0.6878, -1.9397 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P122", meshId = 1579903488, paint = true, sizeM = { 0.3046, 1.1076, 1.1734 }, offsetM = { -0.7583, 0.8536, 0.7869 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P123", meshId = 1578551066, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.3899, 0.2273, 0.5006 }, offsetM = { 0.647, 0.6878, -1.9397 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P124", meshId = 1579887662, paint = true, sizeM = { 0.3831, 1.2735, 4.1733 }, offsetM = { -0.7202, 0.8151, 0.1885 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P125", meshId = 1579896612, color = Color3.fromRGB(99, 95, 98), material = Enum.Material.SmoothPlastic, sizeM = { 0.415, 1.0496, 1.1716 }, offsetM = { 0.802, 0.8594, -0.3354 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P127", meshId = 1579887453, paint = true, sizeM = { 0.3831, 1.2735, 4.1733 }, offsetM = { 0.7167, 0.8151, 0.1885 }, rotationDeg = { 0, -180, 0 } },
				{ name = "TailLamps_P128", meshId = 1579938672, color = Color3.fromRGB(117, 0, 0), material = Enum.Material.SmoothPlastic, sizeM = { 1.233, 0.1851, 0.0933 }, offsetM = { -0.0018, 0.8757, 2.3185 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P129", meshId = 1579878795, color = Color3.fromRGB(25, 25, 25), material = Enum.Material.SmoothPlastic, sizeM = { 0.4281, 0.2142, 0.146 }, offsetM = { -0.3786, 0.9227, -0.7007 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P130", meshId = 1579904325, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Plastic, sizeM = { 0.1241, 0.6803, 1.0443 }, offsetM = { -0.7289, 0.7228, 0.774 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P137", meshId = 1579905387, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Plastic, sizeM = { 0.2086, 0.3939, 1.0903 }, offsetM = { 0.7103, 1.1964, 0.776 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P144", meshId = 1579905495, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Plastic, sizeM = { 0.2086, 0.3939, 1.0903 }, offsetM = { -0.7139, 1.1964, 0.776 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P151", meshId = 1579910792, paint = true, sizeM = { 0.4131, 1.1313, 1.2562 }, offsetM = { -0.8123, 0.8414, -0.3399 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P153", meshId = 1579923036, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.2, castShadow = false, sizeM = { 0.1758, 0.366, 1.0286 }, offsetM = { -0.7068, 1.1578, -0.2407 }, rotationDeg = { 4.8489, -180, 0 } },
				{ name = "P154", meshId = 1579912586, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.1756, 0.1083, 0.0452 }, offsetM = { -0.9223, 1.0503, -0.6269 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P155", meshId = 1579916853, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.2, castShadow = false, sizeM = { 0.1758, 0.366, 1.0286 }, offsetM = { 0.7097, 1.2102, 0.8177 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P156", meshId = 1578604810, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 1.2015, 0.3764, 0.6761 }, offsetM = { -0.0175, 0.9161, 2.0494 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P157", meshId = 1578475704, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 1.6579, 1.1599, 3.2076 }, offsetM = { -0.0018, 0.8425, 0.2573 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P158", meshId = 1578480446, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Plastic, sizeM = { 1.4984, 0.9265, 3.1207 }, offsetM = { -0.0022, 0.7727, 0.3861 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P165", meshId = 1578600646, paint = true, sizeM = { 1.3984, 0.4415, 0.5814 }, offsetM = { -0.0018, 0.922, 2.1057 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P166", meshId = 1578410270, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.7754, 0.1451, 0.1323 }, offsetM = { -0.002, 0.6625, -2.2177 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P167", meshId = 1579880523, color = Color3.fromRGB(25, 25, 25), material = Enum.Material.SmoothPlastic, sizeM = { 1.1842, 0.2337, 2.644 }, offsetM = { -0.0018, 0.9683, 0.5451 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P172", meshId = 1579917000, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.45, castShadow = false, sizeM = { 1.2471, 0.2663, 0.7177 }, offsetM = { -0.0016, 1.2779, 1.5274 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P174", meshId = 1578511094, color = Color3.fromRGB(150, 150, 150), material = Enum.Material.SmoothPlastic, sizeM = { 1.4522, 0.5172, 2.9112 }, offsetM = { -0.0031, 1.1628, 0.4046 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P176", meshId = 1578612881, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 1.804, 0.8234, 3.7795 }, offsetM = { -0.0018, 1.0689, 0.0588 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P177", meshId = 1579904429, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Plastic, sizeM = { 0.1241, 0.6803, 1.0443 }, offsetM = { 0.7253, 0.7228, 0.774 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P184", meshId = 1578586121, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.0535, 0.032, 0.018 }, offsetM = { -0.3842, 0.8928, -0.3809 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P185", meshId = 1579906867, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, sizeM = { 0.2078, 0.6908, 1.1326 }, offsetM = { -0.7191, 1.0629, 0.7963 }, rotationDeg = { 0, -180, 0 } },
				{ name = "TailLamps_P189", meshId = 1579940451, color = Color3.fromRGB(151, 0, 0), material = Enum.Material.SmoothPlastic, sizeM = { 1.1574, 0.0989, 0.0371 }, offsetM = { -0.0022, 0.8463, 2.3464 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P190", meshId = 1578413350, paint = true, sizeM = { 0.8899, 0.1815, 0.1946 }, offsetM = { -0.002, 0.647, -2.2294 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P192", meshId = 1578422540, paint = true, sizeM = { 1.6012, 0.2558, 1.1741 }, offsetM = { -0.0018, 0.8798, -1.6389 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P193", meshId = 1578419078, color = Color3.fromRGB(0, 0, 0), material = Enum.Material.SmoothPlastic, sizeM = { 0.9316, 0.5092, 0.2183 }, offsetM = { -0.002, 0.5271, -2.2085 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P194", meshId = 1578508163, color = Color3.fromRGB(100, 100, 100), material = Enum.Material.SmoothPlastic, sizeM = { 1.2357, 0.9511, 2.6699 }, offsetM = { -0.0563, 0.8604, 0.3476 }, rotationDeg = { 0, -180, 0 } },
				{ name = "TailLamps_P197", meshId = 1579871681, color = Color3.fromRGB(151, 0, 0), material = Enum.Material.SmoothPlastic, sizeM = { 1.554, 0.0856, 0.1335 }, offsetM = { -0.0018, 0.8705, 2.2375 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P198", meshId = 1579956134, color = Color3.fromRGB(99, 95, 98), material = Enum.Material.SmoothPlastic, transparency = 0.85, castShadow = false, sizeM = { 1.6168, 0.1883, 0.4114 }, offsetM = { -0.0018, 0.8787, 2.1635 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P199", meshId = 1578565887, color = Color3.fromRGB(66, 66, 66), material = Enum.Material.SmoothPlastic, sizeM = { 1.3872, 0.0746, 0.0196 }, offsetM = { -0.0018, 0.7017, -2.0181 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P200", meshId = 1578569802, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.0778, 0.0778, 0.0131 }, offsetM = { 0.7668, 0.7281, -1.8991 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P201", meshId = 1578569560, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.0778, 0.0778, 0.0131 }, offsetM = { -0.7703, 0.7281, -1.8991 }, rotationDeg = { 0, -180, 0 } },
				{ name = "ReverseLamps_P202", meshId = 1579947012, color = Color3.fromRGB(180, 180, 180), material = Enum.Material.SmoothPlastic, sizeM = { 0.1565, 0.0598, 0.1344 }, offsetM = { 0.681, 0.9317, 2.2468 }, rotationDeg = { 0, -180, 0 } },
				{ name = "ReverseLamps_P203", meshId = 1579947133, color = Color3.fromRGB(180, 180, 180), material = Enum.Material.SmoothPlastic, sizeM = { 0.1565, 0.0598, 0.1344 }, offsetM = { -0.6845, 0.9317, 2.2468 }, rotationDeg = { 0, -180, 0 } },
				{ name = "TailLamps_P204", meshId = 1579882681, color = Color3.fromRGB(151, 0, 0), material = Enum.Material.SmoothPlastic, sizeM = { 1.3167, 0.0828, 0.0256 }, offsetM = { -0.0018, 0.8613, 2.3155 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P205", meshId = 1578573312, color = Color3.fromRGB(99, 95, 98), material = Enum.Material.SmoothPlastic, sizeM = { 0.2514, 0.0166, 0.0131 }, offsetM = { -0.002, 1.1704, 1.8257 }, rotationDeg = { 0, -180, 0 } },
				{ name = "ReverseLamps_P206", meshId = 1579939714, color = Color3.fromRGB(180, 180, 180), material = Enum.Material.SmoothPlastic, sizeM = { 0.1363, 0.0609, 0.0558 }, offsetM = { 0.5337, 0.9253, 2.323 }, rotationDeg = { 0, -180, 0 } },
				{ name = "ReverseLamps_P207", meshId = 1579939828, color = Color3.fromRGB(180, 180, 180), material = Enum.Material.SmoothPlastic, sizeM = { 0.1363, 0.0609, 0.0558 }, offsetM = { -0.5372, 0.9253, 2.323 }, rotationDeg = { 0, -180, 0 } },
			},
			wheelPieces = {
				{ name = "Tyre", meshId = 1547269887, color = Color3.fromRGB(25, 25, 25), material = Enum.Material.Rubber, sizeM = { 0.2505, 0.6598, 0.6598 }, offsetM = { 0, 0, 0 } },
				{ name = "Rim", meshId = 1547270813, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Metal, sizeM = { 0.0511, 0.4274, 0.4274 }, offsetM = { -0.1048, 0.0001, 0 } },
			},
		},
		tuning = {
			effects = {
				-- The store Camry's own engine: its A-Chassis "AdvancedEngineSound"
				-- set, low and high rpm each on and off throttle (low on and off
				-- are one file). The owner (2026-09-25) liked these sets; the
				-- shared SR20 loops are what every other car uses. refRpm is a
				-- first guess, not measured (the plugin's own pitch rule sits in
				-- its script): tune by ear, lower plays higher.
				engineAudio = {
					layers = {
						idle = { soundId = "rbxassetid://4723793582", refRpm = 2200, volume = 0.5, eq = { 0, 0, -2 } },
						lowLoad = { soundId = "rbxassetid://4723793582", refRpm = 2200, volume = 0.8, eq = { 1, 0, 0 } },
						highLoad = { soundId = "rbxassetid://2813604037", refRpm = 5200, volume = 1, eq = { 0, 0, 0 } },
						overrun = { soundId = "rbxassetid://2813595665", refRpm = 5200, volume = 0.55, eq = { 0, 0, 0 } },
					},
				},
			},
		},
	},
	-- THE BATROL (the Gulf's own name for it). A late-90s Japanese full-size
	-- 4x4, the long five-door: tall, boxy, heavy, the desert car. Body: the
	-- Creator Store model 8941542327 (IamNobody7, no scripts), one MeshPart
	-- per material, referenced by mesh id like the Kamri. Removed: the
	-- lettering inside the cabin, and the maker's grille and tailgate badges,
	-- which are geometry inside the chrome mesh, so the chrome is rebuilt
	-- without them (CarMeshes/Batrol, tools/carbody/batrol.py): 1,306
	-- triangles to 384.
	--
	-- Placed at 0.2442 m a model stud, so its wheel centres sit on the real
	-- 2.97 m wheelbase: 5.06 m long, 1.87 m tall, 0.86 m tyres. Piece names
	-- follow the body standard (tools/carbody/README.md).
	--
	-- Handling: the pickup's mass, so its measured springs and natl torques
	-- carry over; the rest is shared.
	batrol = {
		displayName = "Batrol",
		blurb = "Tall, heavy, built for the sand. Made to ride on two wheels.",
		order = 5,
		scale = 1.2,
		rig = {
			massKg = 2200,
			-- Nose at -2.39 m, tail lamps at +2.50 m (the spare wheel to +2.67).
			collisionSizeM = { 1.85, 1.3, 4.7 },
			-- A tall body: the mass sits higher than the saloons'.
			centerOfMassM = { 0, -0.2, -0.1 },
			shellMassFraction = 0.55,
			wheelbaseM = 2.97,
			trackWidthM = 1.6643,
			wheelRadiusM = 0.428,
			wheelWidthM = 0.2888,
			-- Driver's side, high: the seat 0.7 m off the ground at rest.
			seatM = { -0.4, -0.26, -0.1 },
		},
		body = {
			paint = Color3.fromRGB(236, 236, 232),
			pieces = {
				{ name = "HeadLamps", meshId = 8941430640, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.2836, 0.1954, 1.7227 }, offsetM = { -0.0007, 0.9785, -2.1075 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Interior_Wood", meshId = 8941497189, textureId = 8941497327, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.3343, 0.4511, 0.9112 }, offsetM = { -0.2354, 1.1356, -0.4157 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Body_Caps", meshId = 8941371341, paint = true, sizeM = { 3.2937, 1.4583, 2.1754 }, offsetM = { 0, 1.066, 1.0192 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Underbody_Shocks", meshId = 8941415688, color = Color3.fromRGB(239, 184, 56), material = Enum.Material.SmoothPlastic, sizeM = { 3.0067, 0.4035, 1.3356 }, offsetM = { 0, 0.6417, 0.0148 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Trim", meshId = 8941396835, color = Color3.fromRGB(99, 95, 98), material = Enum.Material.SmoothPlastic, sizeM = { 4.8889, 1.5194, 2.0573 }, offsetM = { -0.051, 1.0687, 0.0554 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Interior", meshId = 8941480817, color = Color3.fromRGB(43, 43, 43), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 3.4388, 1.3505, 1.7656 }, offsetM = { 0, 1.1363, 0.6884 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Underbody_Floor", meshId = 8941383056, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 3.3718, 1.3049, 1.7656 }, offsetM = { 0, 1.1223, 0.655 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Indicators", meshId = 8941435381, color = Color3.fromRGB(170, 85, 0), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.1107, 0.0771, 1.6913 }, offsetM = { 0, 0.9862, -2.0211 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Trim_LowerGrille", meshId = 8941445129, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.1139, 0.2811, 0.6574 }, offsetM = { -0.001, 0.6489, -2.3044 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Underbody", meshId = 8941378347, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 4.7287, 1.5528, 2.0445 }, offsetM = { -0.0447, 1.0823, 0.1355 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Body_Scoop", meshId = 8941458917, paint = true, sizeM = { 3.4768, 0.5091, 2.054 }, offsetM = { -0.0494, 1.0646, 0.1332 }, rotationDeg = { 0, 90, 0 } },
				{ name = "TailLamps", meshId = 8941465426, color = Color3.fromRGB(117, 0, 0), material = Enum.Material.Glass, transparency = 0.5, castShadow = false, sizeM = { 0.1865, 0.6899, 1.8138 }, offsetM = { 0, 0.893, 2.4066 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Body", meshId = 8941363995, paint = true, sizeM = { 4.8848, 1.5366, 1.9589 }, offsetM = { 0, 1.1044, 0.0512 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Trim_Windows", meshId = 8941387847, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.9503, 0.4599, 1.7527 }, offsetM = { 0, 1.5099, 1.6278 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Trim_Housings", meshId = 8941366429, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 3.1926, 0.9081, 1.2589 }, offsetM = { -0.0869, 0.7916, -0.6214 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Interior_Dash", meshId = 8941493309, textureId = 8941493447, color = Color3.fromRGB(231, 231, 236), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.1015, 0.2915, 0.2651 }, offsetM = { 0, 1.0783, -0.4835 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Chrome_Upper", meshId = 8941439338, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, sizeM = { 1.8667, 0.8366, 2.1469 }, offsetM = { 0, 1.2779, -1.2045 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Trim_Grille", meshId = 8941421362, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.8232, 0.6167, 0.9392 }, offsetM = { 0, 0.9902, -1.957 }, rotationDeg = { 0, 90, 0 } },
				{ name = "ReverseLamps", meshId = 8941470873, color = Color3.fromRGB(231, 231, 236), material = Enum.Material.Glass, transparency = 0.5, castShadow = false, sizeM = { 0.1191, 0.0891, 1.8051 }, offsetM = { 0, 1.0489, 2.3729 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Interior_Red", meshId = 8941488774, color = Color3.fromRGB(196, 40, 28), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.6501, 0.4298, 0.9096 }, offsetM = { -0.2187, 1.0254, -0.3073 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Glass", meshId = 8941426631, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Glass, transparency = 0.7, castShadow = false, sizeM = { 4.684, 1.1716, 1.7897 }, offsetM = { 0.012, 1.2426, 0.0927 }, rotationDeg = { 0, 90, 0 } },
				{ name = "FogLamps", meshId = 8941450998, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.6448, 0.6409, 1.6278 }, offsetM = { 0, 0.9531, -1.4546 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Chrome", mesh = "Batrol/Chrome", color = Color3.fromRGB(248, 248, 248), material = Enum.Material.Metal, sizeM = { 1.905, 1.1262, 4.7811 }, offsetM = { 0.0246, 0.8758, 0.0436 } },
			},
			wheelPieces = {
				{ name = "Rim_Face", meshId = 8941522368, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, sizeM = { 0.5341, 0.508, 0.0382 }, offsetM = { -0.1366, 0.022, -0.0005 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Rim", meshId = 8941509678, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.5656, 0.5675, 0.3144 }, offsetM = { -0.0011, 0.0038, -0.0005 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Tyre", meshId = 8941514489, color = Color3.fromRGB(25, 25, 25), material = Enum.Material.Rubber, sizeM = { 0.8555, 0.856, 0.2888 }, offsetM = { 0, 0, 0 }, rotationDeg = { 0, 90, 0 } },
			},
		},
		tuning = {
			-- The pickup's, measured at the same 2.2 t: it sits at the sedan's sag.
			suspension = { stiffness = 45000, damping = 4200, antiRollFront = 9000, antiRollRear = 6000 },
			twoWheel = { liftTorque = 16500, leanInTorque = 6000, leanOutTorque = 5500, balanceSpring = 150 },
			-- Its store model had no sounds: the Kruzer 80's horn, the 4x4 one.
			effects = { horn = { soundId = "rbxassetid://948464506" } },
		},
	},
	-- THE KRUZER 80. The early-90s Japanese full-size 4x4, the boxy one: the
	-- Gulf's nostalgia car. Body: Creator Store model 13118106368, chosen for
	-- its full interior (dash, gauges, seats), by mesh id like the Kamri
	-- (tools/carbody/storecar.py). Removed: the roof rack, storage box,
	-- jerry cans, roof spare, light bar (the tailgate spare stays, shrunk
	-- to 0.8 so it clears the right tail lamp; the plate mount painted), the
	-- grille badge, the tailgate emblem, lettering and grade badges, the
	-- mudflap lettering, the flame stripes, the lettering on the door
	-- mouldings (now plain black) and a cluster of plain parts on the dash.
	-- 163,478 triangles in the store model, 137,884 here: 59,768 of them the
	-- four wheels and 15,521 the tailgate spare (simplified rim and hub for
	-- upload in assets/cars/kruzer80 bring the lot to about 87,500).
	--
	-- Placed at 0.2658 m a model stud on the real 2.85 m wheelbase; it sits
	-- lifted on 0.95 m tyres, as the store built it.
	--
	-- Handling: the Batrol's (the pickup's mass, springs and natl torques).
	kruzer80 = {
		displayName = "Kruzer 80",
		blurb = "The boxy legend. Lifted, heavy, and happiest on two wheels.",
		order = 6,
		scale = 1.2,
		rig = {
			massKg = 2200,
			-- Nose at -2.27 m, tail at +2.50 m.
			collisionSizeM = { 1.85, 1.3, 4.6 },
			centerOfMassM = { 0, -0.2, -0.1 },
			shellMassFraction = 0.55,
			wheelbaseM = 2.85,
			trackWidthM = 1.607,
			wheelRadiusM = 0.4738,
			wheelWidthM = 0.3229,
			-- Driver's side, behind the wheel.
			seatM = { -0.4, -0.2, 0 },
		},
		body = {
			paint = Color3.fromRGB(236, 236, 232),
			pieces = {
				{ name = "Trim", meshId = 7183576257, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.1221, 0.5023, 0.9629 }, offsetM = { -0.7262, 1.7388, -0.1586 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome", meshId = 7183583399, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.1617, 0.1502, 0.0463 }, offsetM = { -0.9119, 1.5766, -0.4592 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_2", meshId = 7183581429, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.2608, 0.3782, 0.8066 }, offsetM = { -0.879, 1.4772, -0.1848 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Interior", meshId = 7183586112, color = Color3.fromRGB(139, 131, 112), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.219, 0.6961, 0.9159 }, offsetM = { -0.7642, 1.1451, -0.2242 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Glass", meshId = 7183584681, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.65, castShadow = false, sizeM = { 0.109, 0.4388, 0.7007 }, offsetM = { -0.7222, 1.7161, -0.0812 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_3", meshId = 7183580231, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.2643, 0.9934, 1.0543 }, offsetM = { -0.7817, 1.4991, -0.1981 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Body", meshId = 7183586905, paint = true, sizeM = { 0.2174, 1.2145, 1.0677 }, offsetM = { -0.7686, 1.3826, -0.1966 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Body_2", meshId = 7183855938, paint = true, sizeM = { 0.1159, 0.7194, 1.0677 }, offsetM = { -0.8352, 1.1351, -0.1965 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_4", meshId = 7183530998, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.2608, 0.3782, 0.8066 }, offsetM = { 0.8812, 1.4766, -0.1769 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_5", meshId = 7183533632, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.1617, 0.1502, 0.0463 }, offsetM = { 0.9166, 1.5759, -0.446 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Glass_2", meshId = 7183536003, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.65, castShadow = false, sizeM = { 0.109, 0.4388, 0.7007 }, offsetM = { 0.7236, 1.7156, -0.0748 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Interior_2", meshId = 7183546042, color = Color3.fromRGB(139, 131, 112), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.219, 0.6961, 0.9159 }, offsetM = { 0.7664, 1.1446, -0.2173 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_6", meshId = 7183529057, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.2643, 0.9934, 1.0543 }, offsetM = { 0.7839, 1.4986, -0.1911 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Body_3", meshId = 7183547145, paint = true, sizeM = { 0.2162, 1.2145, 1.0677 }, offsetM = { 0.7714, 1.382, -0.1897 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Trim_2", meshId = 7183551127, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.1221, 0.5023, 0.9629 }, offsetM = { 0.7282, 1.7383, -0.1521 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Body_4", meshId = 7183864921, paint = true, sizeM = { 0.1159, 0.7194, 1.0677 }, offsetM = { 0.837, 1.1345, -0.189 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Trim_3", meshId = 7183520443, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 1.5028, 0.2244, 1.1696 }, offsetM = { 0.0072, 1.4077, -1.5556 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Body_5", meshId = 7183521568, paint = true, sizeM = { 1.5028, 0.2176, 1.1796 }, offsetM = { 0.0072, 1.4042, -1.5606 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Trim_4", meshId = 7183627029, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.125, 0.4994, 0.8205 }, offsetM = { -0.7294, 1.746, 0.7333 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Body_6", meshId = 7183629784, paint = true, sizeM = { 0.1576, 0.4742, 0.3926 }, offsetM = { -0.8719, 1.0241, 1.0115 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Glass_3", meshId = 7183632642, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.65, castShadow = false, sizeM = { 0.1033, 0.4461, 0.7158 }, offsetM = { -0.7293, 1.7258, 0.7391 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_7", meshId = 7183628798, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.2651, 0.9955, 0.8558 }, offsetM = { -0.7866, 1.5017, 0.7226 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Interior_3", meshId = 7183633717, color = Color3.fromRGB(139, 131, 112), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.219, 0.6926, 0.8031 }, offsetM = { -0.7685, 1.1485, 0.7416 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_8", meshId = 7183630855, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.0227, 0.0823, 0.1687 }, offsetM = { -0.8761, 1.3566, 1.051 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Body_7", meshId = 7183634474, paint = true, sizeM = { 0.2151, 1.2143, 0.9188 }, offsetM = { -0.7687, 1.3886, 0.7483 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Body_8", meshId = 7183859959, paint = true, sizeM = { 0.1277, 0.7295, 0.9154 }, offsetM = { -0.8345, 1.1462, 0.7466 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Trim_5", meshId = 7183558163, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.125, 0.4994, 0.8205 }, offsetM = { 0.7235, 1.7455, 0.7399 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Body_9", meshId = 7183569060, paint = true, sizeM = { 0.2149, 1.2143, 0.9188 }, offsetM = { 0.7625, 1.3881, 0.7552 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Body_10", meshId = 7183564467, paint = true, sizeM = { 0.1576, 0.4751, 0.3926 }, offsetM = { 0.8629, 1.023, 1.0193 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_9", meshId = 7183563565, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.2651, 0.9955, 0.8558 }, offsetM = { 0.7805, 1.5011, 0.7297 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_10", meshId = 7183565111, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.0227, 0.0823, 0.1687 }, offsetM = { 0.867, 1.356, 1.0588 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Glass_4", meshId = 7183566443, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.65, castShadow = false, sizeM = { 0.1033, 0.4461, 0.7158 }, offsetM = { 0.7233, 1.7253, 0.7436 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Interior_4", meshId = 7183568218, color = Color3.fromRGB(139, 131, 112), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.219, 0.6926, 0.8031 }, offsetM = { 0.7621, 1.1479, 0.7485 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Body_11", meshId = 7183863012, paint = true, sizeM = { 0.1277, 0.7295, 0.9154 }, offsetM = { 0.828, 1.1456, 0.7542 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Interior_5", meshId = 7059314279, color = Color3.fromRGB(139, 131, 112), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.2865, 0.2734, 0.1204 }, offsetM = { -0.3954, 1.4447, -0.3156 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Trim_6", meshId = 7183657497, paint = true, sizeM = { 0.4899, 0.3, 0.0988 }, offsetM = { -0.3308, 1.1106, 2.4517 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Body_12", meshId = 7183663664, paint = true, sizeM = { 1.4747, 0.3094, 0.0449 }, offsetM = { -0.0107, 1.0965, 2.402 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Interior_6", meshId = 7183666805, color = Color3.fromRGB(139, 131, 112), material = Enum.Material.Plastic, castShadow = false, sizeM = { 1.4747, 0.3095, 0.0146 }, offsetM = { -0.0106, 1.0964, 2.3884 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Body_13", meshId = 7183640688, paint = true, sizeM = { 1.4743, 0.8526, 0.3843 }, offsetM = { -0.0097, 1.6739, 2.2323 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Interior_7", meshId = 7183648001, color = Color3.fromRGB(139, 131, 112), material = Enum.Material.Plastic, castShadow = false, sizeM = { 1.4743, 0.8522, 0.3498 }, offsetM = { -0.0096, 1.6741, 2.2151 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_11", meshId = 7183652180, textureId = 7178421786, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.3215, 0.6102, 0.2579 }, offsetM = { -0.0098, 1.7333, 2.2579 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Glass_5", meshId = 7183654593, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.65, castShadow = false, sizeM = { 1.295, 0.4733, 0.1678 }, offsetM = { -0.0098, 1.7416, 2.2503 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Interior_8", meshId = 7179270077, color = Color3.fromRGB(139, 131, 112), material = Enum.Material.Plastic, castShadow = false, sizeM = { 1.3419, 0.8731, 1.5991 }, offsetM = { -0.0064, 1.2829, 0.4969 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_12", meshId = 7179239923, textureId = 6455678243, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Sand, sizeM = { 1.3378, 0.6391, 0.4735 }, offsetM = { -0.0018, 1.1833, -0.7411 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_13", meshId = 7183470331, textureId = 7178421786, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.8895, 1.5793, 4.586 }, offsetM = { -0.0038, 1.2315, 0.132 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_14", meshId = 7179092566, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.6848, 0.1469, 0.2355 }, offsetM = { 0.0059, 1.2113, -2.0329 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Trim_7", meshId = 6965456090, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.1522, 0.1507, 0.1814 }, offsetM = { -0.0382, 1.1076, -0.3556 }, rotationDeg = { -0.096, -0.257, -0.019 } },
				{ name = "Trim_8", meshId = 6793812557, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.0491, 0.323, 0.0941 }, offsetM = { -0.0326, 1.2156, -0.2761 }, rotationDeg = { -8.422, -179.796, 0.02 } },
				{ name = "Trim_9", meshId = 6793811977, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.0495, 0.0722, 0.0497 }, offsetM = { -0.0283, 1.3606, -0.2104 }, rotationDeg = { -8.422, -179.796, 0.02 } },
				{ name = "Trim_10", meshId = 6112450464, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.0517, 0.0822, 0.0574 }, offsetM = { 0.1054, 1.1692, -0.4073 }, rotationDeg = { -0.096, -0.257, -0.02 } },
				{ name = "Trim_11", meshId = 6965457308, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.1555, 0.1503, 0.1813 }, offsetM = { -0.0363, 1.1078, -0.3556 }, rotationDeg = { -0.096, -0.257, -0.019 } },
				{ name = "Trim_12", meshId = 6112449974, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.1546, 0.1708, 0.1692 }, offsetM = { 0.103, 1.0548, -0.4292 }, rotationDeg = { -0.096, -0.257, -0.02 } },
				{ name = "Interior_9", meshId = 7179205254, textureId = 7179126327, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.747, 0.3549, 0.0893 }, offsetM = { -0.306, 1.399, -0.5156 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Body_14", meshId = 7183849143, paint = true, sizeM = { 1.8034, 1.4098, 4.5664 }, offsetM = { -0.0059, 1.4085, 0.1239 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Trim_13", meshId = 7183769575, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 1.6585, 0.6162, 3.138 }, offsetM = { 0.0156, 0.7717, -0.0154 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_15", meshId = 7179089543, textureId = 7178413730, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.647, 0.12, 0.1833 }, offsetM = { 0.0058, 1.212, -2.0093 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "HeadLamps", meshId = 7179086809, textureId = 7178421786, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, transparency = 0.3, castShadow = false, sizeM = { 1.6703, 0.1362, 0.2237 }, offsetM = { 0.0059, 1.2108, -2.0331 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_16", meshId = 7179433262, textureId = 5659523781, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.8558, 0.156, 0.0449 }, offsetM = { -0.2674, 1.5024, -0.5206 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Glass_6", meshId = 7179095753, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.65, castShadow = false, sizeM = { 1.5491, 0.4185, 0.8579 }, offsetM = { -0.0103, 1.7481, 1.6138 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Interior_10", meshId = 7179257508, color = Color3.fromRGB(139, 131, 112), material = Enum.Material.Plastic, castShadow = false, sizeM = { 1.5491, 1.3037, 3.4616 }, offsetM = { -0.0061, 1.4458, 0.6622 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Glass_7", meshId = 7183513741, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.65, castShadow = false, sizeM = { 1.4561, 0.4763, 0.5116 }, offsetM = { -0.0006, 1.7494, -0.5494 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Trim_14", meshId = 7183499814, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 1.8741, 0.2855, 0.4759 }, offsetM = { 0.0063, 0.8741, -2.0236 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Trim_15", meshId = 7183494046, textureId = 7178421786, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 1.4748, 0.2448, 0.0687 }, offsetM = { -0.014, 0.8212, 2.3757 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Trim_16", meshId = 7183493064, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 1.9088, 0.3052, 0.7018 }, offsetM = { -0.013, 0.7942, 2.1469 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Body_15", meshId = 7183471089, paint = true, sizeM = { 1.8933, 0.3413, 0.727 }, offsetM = { -0.0103, 1.0942, 1.5712 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_17", meshId = 7179474127, textureId = 7178428892, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.5777, 0.3438, 1.1786 }, offsetM = { 0.0038, 1.3356, -1.56 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_18", meshId = 7183460886, color = Color3.fromRGB(237, 234, 234), material = Enum.Material.SmoothPlastic, sizeM = { 0.8348, 0.2496, 0.018 }, offsetM = { 0.0064, 1.1683, -2.1453 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_19", meshId = 7179415727, textureId = 6455678243, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Sand, sizeM = { 0.5102, 0.2344, 0.2578 }, offsetM = { -0.4308, 1.3135, -0.5012 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Interior_11", meshId = 7179411407, textureId = 7179126327, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Sand, castShadow = false, sizeM = { 0.4708, 0.0817, 0.0621 }, offsetM = { -0.4507, 1.354, -0.4809 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_20", meshId = 7179282624, textureId = 6455678243, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Sand, sizeM = { 0.0458, 0.0911, 0.4798 }, offsetM = { -0.1416, 1.0259, -0.0733 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Interior_12", meshId = 7179275468, color = Color3.fromRGB(139, 131, 112), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.2279, 0.3067, 0.5255 }, offsetM = { -0.0069, 0.9926, 0.1669 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_21", meshId = 7179457131, textureId = 7179461888, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.7617, 0.0595, 0.0875 }, offsetM = { 0.0005, 1.3352, -0.8286 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Trim_17", meshId = 7183501759, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.9088, 0.0805, 0.0988 }, offsetM = { 0.0071, 0.9142, -2.1979 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Chrome_22", meshId = 7183489455, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.7167, 0.0449, 0.0669 }, offsetM = { -0.0143, 0.8501, 2.4399 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Trim_18", meshId = 7183486479, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.7188, 0.1343, 0.0492 }, offsetM = { -0.0143, 0.7745, 2.4489 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Trim_19", meshId = 7183483096, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 1.9088, 0.4687, 0.2185 }, offsetM = { -0.0119, 0.7011, 1.9054 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Body_16", meshId = 7183448044, paint = true, sizeM = { 1.8895, 0.6648, 1.1962 }, offsetM = { 0.0028, 0.9464, -1.3742 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "TailLamps", meshId = 7183465515, textureId = 7178421786, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.7594, 0.3332, 0.0862 }, offsetM = { -0.0138, 1.2054, 2.3571 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Interior_13", meshId = 7179423875, color = Color3.fromRGB(139, 131, 112), material = Enum.Material.Plastic, castShadow = false, sizeM = { 1.458, 0.8132, 0.7608 }, offsetM = { -0.01, 1.4962, -0.6883 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Spare", meshId = 6906932103, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.6998, 0.4283, 0.37 }, offsetM = { 0.3544, 1.2201, 2.3736 }, rotationDeg = { 0.095, 179.743, 0.02 } },
				{ name = "Spare_2", meshId = 7170792043, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.0438, 0.147, 0.1538 }, offsetM = { 0.3097, 1.2347, 2.6421 }, rotationDeg = { 0.02, 89.743, -0.095 } },
				{ name = "Spare_3", meshId = 7158532335, textureId = 7158522363, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.2533, 0.7436, 0.7419 }, offsetM = { 0.31, 1.2346, 2.5893 }, rotationDeg = { 0.02, 89.743, -0.095 } },
				{ name = "Spare_4", meshId = 7170793054, color = Color3.fromRGB(237, 234, 234), material = Enum.Material.SmoothPlastic, sizeM = { 0.1154, 0.3724, 0.3724 }, offsetM = { 0.3097, 1.2347, 2.6421 }, rotationDeg = { 0.02, 89.743, -0.095 } },
				{ name = "Interior_14", meshId = 2972069424, textureId = 2972069630, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.1853, 0.0985, 0.0755 }, offsetM = { 0.1683, 1.4654, -0.6894 }, rotationDeg = { 0.095, 179.743, 0.02 } },
			},
			wheelPieces = {
				{ name = "Tyre", meshId = 7158532335, textureId = 7158522363, color = Color3.fromRGB(237, 234, 234), material = Enum.Material.WoodPlanks, sizeM = { 0.3229, 0.9477, 0.9456 }, offsetM = { 0, 0, 0 }, rotationDeg = { -5.151, -0.254, -0.019 } },
				{ name = "Rim", meshId = 7170793054, color = Color3.fromRGB(237, 234, 234), material = Enum.Material.SmoothPlastic, sizeM = { 0.147, 0.4746, 0.4746 }, offsetM = { -0.0678, 0, -0.0003 }, rotationDeg = { -5.151, -0.254, -0.019 } },
				{ name = "Rim_Hub", meshId = 7170792043, color = Color3.fromRGB(237, 234, 234), material = Enum.Material.SmoothPlastic, sizeM = { 0.0559, 0.1874, 0.196 }, offsetM = { -0.0678, 0, -0.0003 }, rotationDeg = { -5.151, -0.254, -0.019 } },
			},
		},
		tuning = {
			-- The pickup's, measured at the same 2.2 t.
			suspension = { stiffness = 45000, damping = 4200, antiRollFront = 9000, antiRollRear = 6000 },
			twoWheel = { liftTorque = 16500, leanInTorque = 6000, leanOutTorque = 5500, balanceSpring = 150 },
			effects = {
				-- The store model's own horn.
				horn = { soundId = "rbxassetid://948464506" },
				-- Its tail lenses are opaque (the Batrol's are half-see-through
				-- glass), so the shared tail colour lit them nearly as bright as
				-- the brake. Darker, so braking jumps like the Batrol's (owner,
				-- 2026-09-25: "darken the tail lights a bit").
				lamps = { tailColor = Color3.fromRGB(105, 5, 7) },
				-- Its A-Chassis stock "Rev" loop, one file for every layer (it
				-- shares one Sound; the layers differ by EQ). refRpm is a first
				-- guess to tune by ear.
				engineAudio = {
					layers = {
						idle = { soundId = "rbxassetid://358130654", refRpm = 3500, volume = 0.5, eq = { 0, 0, -6 } },
						lowLoad = { soundId = "rbxassetid://358130654", refRpm = 3500, volume = 0.8, eq = { 3, 0, -3 } },
						highLoad = { soundId = "rbxassetid://358130654", refRpm = 3500, volume = 1, eq = { 0, 2, 2 } },
						overrun = { soundId = "rbxassetid://358130654", refRpm = 3500, volume = 0.5, eq = { 0, -2, -8 } },
					},
				},
			},
		},
	},

}

return {
	defaultCarId = "kamri07",
	cars = cars,
}
