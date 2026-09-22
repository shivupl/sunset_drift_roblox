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

	-- THE KAMRI S. The owner's own sculpt of the same XV40-shape saloon
	-- (white toyota car 3d model.fbx, 50,367 triangles, one fused mesh with
	-- no UVs), cleaned by tools/carbody/fbx_body.py into 12,061 triangles
	-- across eight pieces: badges pressed flat, glass cut out of the shell and
	-- the side windows glazed, lamps and grille cut by outline, the front-left
	-- wheel split into tyre and rim. tools/carbody/fbx_pieces.py writes the
	-- meshes (src/shared/CarMeshes/KamriS). sizeM and offsetM below are its
	-- numbers.
	--
	-- Scaled so its wheel centres land on the Kamri's real 2.775 m wheelbase
	-- and 1.575 m track: 4.54 m long, 1.82 m wide without mirrors, roof at
	-- 1.52 m. Same rig as the Kamri, so it drives the same; only the box is
	-- shorter, to stay inside the shorter nose.
	kamriS = {
		displayName = "Kamri S",
		blurb = "The Kamri, resculpted. Same planted chassis, sharper body.",
		order = 5,
		scale = 1.2,
		rig = {
			massKg = 1600,
			-- Nose at -2.13 m, tail at +2.41 m: a 4.2 m box stays inside both.
			collisionSizeM = { 1.8, 1.2, 4.2 },
			centerOfMassM = { 0, -0.3, -0.2 },
			shellMassFraction = 0.35,
			wheelbaseM = 2.775,
			trackWidthM = 1.575,
			wheelRadiusM = 0.326,
			wheelWidthM = 0.215,
			-- Over the driver's cushion (-0.39 m across, -0.22 m along), 0.28 m
			-- off the ground: a seated head tops out at 1.48 m, under the
			-- 1.52 m roof.
			seatM = { -0.39, -0.53, -0.22 },
		},
		body = {
			paint = Color3.fromRGB(236, 236, 232),
			pieces = {
				{ name = "Body", mesh = "KamriS/Body", paint = true, sizeM = { 1.9708, 1.2824, 4.5358 }, offsetM = { 0, 0.878, 0.1407 } },
				{ name = "Glass", mesh = "KamriS/Glass", sizeM = { 1.6398, 0.5162, 2.9061 }, offsetM = { 0, 1.1747, 0.3788 }, color = Color3.fromRGB(30, 40, 44), material = Enum.Material.Glass, transparency = 0.45, castShadow = false },
				{ name = "HeadLamps", mesh = "KamriS/HeadLamps", sizeM = { 1.652, 0.2374, 0.3944 }, offsetM = { -0.0058, 0.7519, -1.8427 }, color = Color3.fromRGB(246, 242, 228), material = Enum.Material.Glass, castShadow = false },
				{ name = "TailLamps", mesh = "KamriS/TailLamps", sizeM = { 1.6524, 0.1783, 0.3639 }, offsetM = { 0, 0.8785, 2.1343 }, color = Color3.fromRGB(205, 18, 22), material = Enum.Material.Glass, castShadow = false },
				-- Grille, intakes, wipers, exhausts, antenna, underbody.
				{ name = "Trim", mesh = "KamriS/Trim", sizeM = { 1.8178, 1.4217, 4.4484 }, offsetM = { 0.001, 0.8163, 0.1195 }, color = Color3.fromRGB(28, 28, 31), material = Enum.Material.Plastic, castShadow = false },
				{ name = "Interior", mesh = "KamriS/Interior", sizeM = { 1.4765, 1.1097, 2.0316 }, offsetM = { 0, 0.9153, 0.4849 }, color = Color3.fromRGB(34, 34, 36), castShadow = false },
			},
			wheelPieces = {
				{ name = "Tyre", mesh = "KamriS/Tyre", sizeM = { 0.2111, 0.6627, 0.6666 }, offsetM = { 0.0108, 0.0003, -0.0002 }, color = Color3.fromRGB(24, 24, 26), material = Enum.Material.Rubber },
				{ name = "Rim", mesh = "KamriS/Rim", sizeM = { 0.2319, 0.4893, 0.4882 }, offsetM = { -0.0007, -0.0011, -0.0005 }, color = Color3.fromRGB(188, 190, 194), material = Enum.Material.Metal },
			},
		},
	},

	-- THE KAMRI '07. A mid-2000s Japanese saloon from the Creator Store
	-- (asset 876308553, an A-Chassis car), debadged and cut down for the game
	-- by tools/carbody/store_body.py: scripts, GUIs, sounds and lights
	-- stripped in Studio; the engine bay and every face no ray from outside
	-- can reach (inner skins of panels) deleted; the maker's ovals and script
	-- lettering cut; the rear cabin trimmed harder than the front. 158,140
	-- triangles in, 28,452 out, in eleven pieces. Uniformly scaled at
	-- 0.2505 m a stud so its wheel centres sit on the real 2.775 m wheelbase:
	-- 4.83 m long, 1.52 m track, 0.66 m tyres. Same mass and handling as the
	-- Kamri.
	kamri07 = {
		displayName = "Kamri '07",
		blurb = "The real-deal saloon. Same planted chassis as the Kamri.",
		order = 6,
		scale = 1.2,
		rig = {
			massKg = 1600,
			-- Nose at -2.36 m, tail at +2.47 m.
			collisionSizeM = { 1.8, 1.2, 4.6 },
			centerOfMassM = { 0, -0.3, -0.2 },
			shellMassFraction = 0.35,
			wheelbaseM = 2.775,
			trackWidthM = 1.523,
			wheelRadiusM = 0.33,
			wheelWidthM = 0.215,
			-- Behind the wheel (-0.38 m across), 0.25 m off the ground: a
			-- seated head tops out at 1.45 m, under the 1.48 m roof.
			seatM = { -0.38, -0.56, 0.05 },
		},
		body = {
			paint = Color3.fromRGB(236, 236, 232),
			pieces = {
				{ name = "Body", mesh = "Kamri07/Body", paint = true, sizeM = { 2.0342, 1.3019, 4.8331 }, offsetM = { -0.0019, 0.8294, 0.0546 } },
				{ name = "Glass", mesh = "Kamri07/Glass", sizeM = { 1.5989, 0.5071, 3.1035 }, offsetM = { -0.0019, 1.2019, 0.3345 }, color = Color3.fromRGB(24, 30, 34), material = Enum.Material.Glass, transparency = 0.35, castShadow = false },
				{ name = "Lenses", mesh = "Kamri07/Lenses", sizeM = { 1.6954, 0.3736, 4.5635 }, offsetM = { -0.0019, 0.7861, 0.0875 }, color = Color3.fromRGB(200, 205, 210), material = Enum.Material.Glass, transparency = 0.7, castShadow = false },
				{ name = "TailLamps", mesh = "Kamri07/TailLamps", sizeM = { 1.6077, 0.1851, 0.3123 }, offsetM = { -0.0026, 0.8757, 2.2063 }, color = Color3.fromRGB(150, 8, 10), material = Enum.Material.Glass, castShadow = false },
				{ name = "Chrome", mesh = "Kamri07/Chrome", sizeM = { 1.6425, 0.7107, 3.2897 }, offsetM = { -0.0019, 1.0526, 0.7486 }, color = Color3.fromRGB(205, 207, 210), material = Enum.Material.Metal },
				{ name = "Trim", mesh = "Kamri07/Trim", sizeM = { 2.0167, 1.2756, 4.7605 }, offsetM = { -0.0019, 0.8385, 0.0625 }, color = Color3.fromRGB(22, 22, 24), material = Enum.Material.Plastic },
				{ name = "Grey", mesh = "Kamri07/Grey", sizeM = { 1.8157, 1.2251, 4.5376 }, offsetM = { -0.1049, 0.7789, -0.0151 }, color = Color3.fromRGB(70, 70, 74), material = Enum.Material.Plastic },
				{ name = "InteriorDark", mesh = "Kamri07/InteriorDark", sizeM = { 1.7094, 1.3243, 4.5792 }, offsetM = { -0.0019, 0.8083, 0.1007 }, color = Color3.fromRGB(28, 28, 30), castShadow = false },
				{ name = "InteriorLight", mesh = "Kamri07/InteriorLight", sizeM = { 1.8306, 1.104, 3.1736 }, offsetM = { 0.103, 0.882, 0.38 }, color = Color3.fromRGB(120, 116, 108), castShadow = false },
			},
			wheelPieces = {
				{ name = "Tyre", mesh = "Kamri07/Tyre", sizeM = { 0.2509, 0.6598, 0.6598 }, offsetM = { 0.0001, 0, 0 }, color = Color3.fromRGB(24, 24, 26), material = Enum.Material.Rubber },
				{ name = "Rim", mesh = "Kamri07/Rim", sizeM = { 0.0511, 0.4274, 0.4274 }, offsetM = { -0.1048, 0.0001, 0 }, color = Color3.fromRGB(188, 190, 194), material = Enum.Material.Metal },
			},
		},
	},
}

return {
	defaultCarId = "kamri",
	cars = cars,
}
