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
-- in CarMeshes, baked textures on ReplicatedStorage.CarLooks. The store cars
-- are referenced by mesh id (tools/carbody/README.md), each with its source
-- above its entry. The first test cars, the Hatch, Pickup and Cruiser from
-- a low-poly pack, were removed on 2026-11-08: no cabin for the first-person
-- view.
local VehicleRig = require(script.Parent.VehicleRig)

type CarEntry = VehicleRig.CarEntry

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
				{ name = "Trim_3", meshId = 84127318724682, mesh = "Krownvik/Trim_3", textureId = 1079416334, color = Color3.fromRGB(91, 93, 105), material = Enum.Material.SmoothPlastic, sizeM = { 0.1227, 0.0548, 0.031 }, offsetM = { -0.0002, 0.6645, -2.4056 } },
				{ name = "HeadLamps", meshId = 118510592082497, mesh = "Krownvik/HeadLamps", textureId = 1079416334, color = Color3.fromRGB(91, 93, 105), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.3976, 0.1361, 0.1107 }, offsetM = { -0.0002, 0.6534, -2.2899 } },
				{ name = "HeadLamps_2", meshId = 93405960489851, mesh = "Krownvik/HeadLamps_2", textureId = 1079416334, color = Color3.fromRGB(91, 93, 105), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.7554, 0.1399, 0.3728 }, offsetM = { -0.0002, 0.6509, -2.1138 } },
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
				{ name = "Trim_5", meshId = 128960774200329, mesh = "Krownvik/Trim_5", textureId = 1079416334, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.4384, 0.1896, 0.0306 }, offsetM = { 0.1686, 0.8343, 2.6518 } },
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
	-- THE KROWN VIK FLEET. The same mid-2000s V8 saloon in fleet trim: black
	-- grille, black steel wheels, the taxi-rank and patrol spec. Body:
	-- Creator Store model 14407499990 by mesh id (tools/carbody/storecar.py),
	-- interior kept; the owner asked for both Crown Vic candidates
	-- (2026-09-26). Removed: the grille and boot badges and both plates
	-- (parts of their own) and the engine under the bonnet; the maker's oval
	-- on the airbag is painted out (its pad samples a plain spot of the
	-- texture, generated piece Interior_2). Its left rims and caps face into
	-- the car in the store model and are turned to face out (storecar.py
	-- wheelFlip); its wheel SurfaceAppearances do not carry over (their
	-- textures do). 27,355 triangles in the store
	-- model, 27,017 here.
	--
	-- Its lamps are parts of their own: the headlamp, lens, corner parking
	-- lamps and the tinted covers light as the whole front lamp; the brake
	-- light and rear lamp face as the tail.
	--
	-- Placed at 0.2448 m a model stud on the real 2.913 m wheelbase.
	--
	-- Handling: the Krown Vik's (the shared saloon set at 1.85 t). Sounds:
	-- the Krown Vik's (this model has none of its own).
	krownvikfleet = {
		displayName = "Krown Vik Fleet",
		blurb = "The fleet-spec Krown Vik. Steel wheels, black grille, no nonsense.",
		order = 9,
		scale = 1.2,
		rig = {
			massKg = 1850,
			-- Nose at -2.58 m, tail at +2.83 m.
			collisionSizeM = { 1.9, 1.2, 5.0 },
			centerOfMassM = { 0, -0.3, -0.2 },
			shellMassFraction = 0.35,
			wheelbaseM = 2.913,
			trackWidthM = 1.5911,
			wheelRadiusM = 0.3392,
			wheelWidthM = 0.2979,
			-- The Krown Vik's seat: the same car.
			seatM = { -0.41, -0.6, 0.06 },
		},
		body = {
			paint = Color3.fromRGB(240, 240, 236),
			pieces = {
				{ name = "Body", meshId = 14406441050, paint = true, sizeM = { 0.0311, 0.1566, 0.1618 }, offsetM = { -0.9366, 0.7941, 1.8103 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_2", meshId = 14406441354, paint = true, sizeM = { 1.9672, 0.8002, 3.5876 }, offsetM = { -0.0014, 0.5996, 0.7392 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_3", meshId = 14406441336, paint = true, sizeM = { 1.7636, 0.4437, 0.6486 }, offsetM = { -0.0014, 1.1843, 1.3989 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_4", meshId = 14406441504, paint = true, sizeM = { 1.2302, 0.1165, 1.5486 }, offsetM = { -0.0014, 1.41, 0.5948 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim", meshId = 14406441517, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.0289, 0.048, 0.2235 }, offsetM = { 0.9524, 0.8567, 1.1077 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_5", meshId = 14406441507, paint = true, sizeM = { 0.4181, 1.1534, 1.0601 }, offsetM = { 0.7674, 0.861, 0.8111 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_2", meshId = 14406441541, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.2804, 0.8352, 0.9838 }, offsetM = { 0.7586, 0.9842, 0.7939 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Glass", meshId = 14406441546, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.65, castShadow = false, sizeM = { 0.2157, 0.4037, 0.8204 }, offsetM = { 0.739, 1.1779, 0.8281 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior", meshId = 14406441534, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.4089, 1.1509, 1.0604 }, offsetM = { 0.7627, 0.8621, 0.8111 }, rotationDeg = { 0, 180, 0 } },
				{ name = "TailLamps", meshId = 14406440539, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.6885, 0.3339, 0.8761 }, offsetM = { -0.0015, 0.9417, 2.2094 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Indicators", meshId = 14406441427, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.2666, 0.0311, 0.1819 }, offsetM = { 0.7171, 0.7369, 2.5621 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Indicators_2", meshId = 14406441128, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.2666, 0.0311, 0.1819 }, offsetM = { -0.72, 0.7369, 2.5621 }, rotationDeg = { 0, 180, 0 } },
				{ name = "TailLamps_2", meshId = 14406441381, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.7183, 0.2404, 0.2096 }, offsetM = { -0.0015, 0.8276, 2.5539 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_6", meshId = 14406441348, paint = true, sizeM = { 1.9398, 0.4021, 1.1094 }, offsetM = { -0.0014, 0.4498, 2.2757 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_3", meshId = 14406441326, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.902, 0.4017, 1.0886 }, offsetM = { -0.0023, 0.4514, 2.2653 }, rotationDeg = { 0, 180, 0 } },
				{ name = "ReverseLamps", meshId = 14406441422, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.6742, 0.1741, 0.0639 }, offsetM = { -0.0015, 0.7614, 2.6527 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_4", meshId = 14406734060, textureId = 14406734176, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.0208, 0.3814, 1.5457 }, offsetM = { -0.0014, 0.8411, 2.1759 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Trim_5", meshId = 14406441632, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.0368, 0.0365, 0.0042 }, offsetM = { 0.3703, 0.7755, 2.6775 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_6", meshId = 14406441630, textureId = 14406440629, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.2659, 0.1819, 0.0629 }, offsetM = { -0.0014, 0.7636, 2.6523 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_7", meshId = 14406441641, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.2748, 0.215, 0.0541 }, offsetM = { -0.0023, 0.7589, 2.6616 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_7", meshId = 14406441620, paint = true, sizeM = { 1.5457, 0.1709, 0.9605 }, offsetM = { -0.0014, 0.9498, 2.2035 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_2", meshId = 82841041063458, mesh = "Krownvikfleet/Interior_2", textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.3977, 0.3574, 0.2152 }, offsetM = { -0.382, 0.902, -0.278 } },
				{ name = "Trim_8", meshId = 14406441263, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.2458, 0.1449, 0.0893 }, offsetM = { -0.0023, 1.3058, -0.1875 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_9", meshId = 14406441365, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.2458, 0.0612, 0.01 }, offsetM = { -0.0023, 1.2762, -0.1767 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_10", meshId = 14406441452, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.0289, 0.048, 0.2235 }, offsetM = { -0.9554, 0.8567, 1.1077 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_8", meshId = 14406441448, paint = true, sizeM = { 0.4181, 1.1534, 1.0601 }, offsetM = { -0.7702, 0.861, 0.8111 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Glass_2", meshId = 14406441494, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.65, castShadow = false, sizeM = { 0.2157, 0.4037, 0.8204 }, offsetM = { -0.7436, 1.1779, 0.8281 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_11", meshId = 14406441480, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.2847, 0.8352, 0.9838 }, offsetM = { -0.761, 0.9842, 0.7939 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_3", meshId = 14406441466, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.4089, 1.1509, 1.0604 }, offsetM = { -0.7657, 0.8621, 0.8111 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_12", meshId = 14406440582, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.9221, 0.4017, 0.9652 }, offsetM = { -0.0023, 0.4514, 2.2036 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_13", meshId = 14406734089, textureId = 14406734176, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.1156, 0.0161, 1.0702 }, offsetM = { -0.0014, 0.6529, 2.6285 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Trim_14", meshId = 14406440982, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.8443, 0.6876, 1.6212 }, offsetM = { -0.0023, 0.6207, -1.6163 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_15", meshId = 14406441099, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.7539, 0.1369, 5.1073 }, offsetM = { -0.0025, 0.5189, 0.1421 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_16", meshId = 14406441206, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.7733, 0.1535, 5.0474 }, offsetM = { 0.0016, 0.6877, 0.1404 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_17", meshId = 14406441242, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.7199, 0.3814, 0.9388 }, offsetM = { -0.0023, 0.8429, 2.1926 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_18", meshId = 14406441589, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.575, 0.547, 0.8629 }, offsetM = { -0.0023, 0.7444, 2.1532 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Underbody", meshId = 14406441689, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.9295, 0.5312, 4.5528 }, offsetM = { -0.0023, 0.4669, 0.3444 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_19", meshId = 14406441692, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.7027, 0.4864, 2.8131 }, offsetM = { -0.0023, 1.1938, 0.4721 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_20", meshId = 14406441728, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.6151, 0.4526, 2.7815 }, offsetM = { -0.0014, 1.1751, 0.477 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Underbody_2", meshId = 14406440542, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.5632, 0.3322, 3.253 }, offsetM = { -0.0053, 0.339, 0.0027 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Underbody_3", meshId = 14406440581, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.5823, 0.2291, 3.0414 }, offsetM = { -0.0053, 0.3859, 0.1332 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Underbody_4", meshId = 14406441573, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.3017, 0.3381, 2.9896 }, offsetM = { -0.0053, 0.5625, 0.0018 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Underbody_5", meshId = 14406441618, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.5074, 0.1811, 3.7399 }, offsetM = { -0.0082, 0.3056, 0.0056 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Underbody_6", meshId = 14406440709, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.5254, 0.1446, 4.4064 }, offsetM = { -0.0023, 0.2585, 0.4698 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_21", meshId = 14406441713, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.493, 0.0382, 0.1249 }, offsetM = { 0.486, 1.0189, -0.7991 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_22", meshId = 14406441734, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.5799, 0.082, 0.2012 }, offsetM = { 0.2688, 1.0021, -0.8936 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Glass_3", meshId = 14406441009, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.65, castShadow = false, sizeM = { 1.524, 0.3721, 0.6121 }, offsetM = { -0.0023, 1.1876, -0.5403 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Glass_4", meshId = 14406441363, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.65, castShadow = false, sizeM = { 1.4109, 0.3204, 0.4453 }, offsetM = { -0.0023, 1.2061, 1.6148 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_23", meshId = 14406441011, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.289, 0.4697, 1.1383 }, offsetM = { 0.7383, 1.167, -0.1531 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_24", meshId = 14406440843, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.026, 0.048, 0.2203 }, offsetM = { 0.9561, 0.8455, 0.1523 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_9", meshId = 14406440822, paint = true, sizeM = { 0.418, 1.1586, 1.3409 }, offsetM = { 0.7674, 0.8581, -0.2483 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Glass_5", meshId = 14406441069, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.65, castShadow = false, sizeM = { 0.214, 0.414, 0.7792 }, offsetM = { 0.738, 1.1726, -0.0524 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_25", meshId = 14406441042, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.1875, 0.2159, 0.2775 }, offsetM = { 0.8701, 1.0578, -0.5633 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Glass_6", meshId = 14406440730, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, transparency = 0.45, castShadow = false, sizeM = { 0.2174, 0.2899, 0.7861 }, offsetM = { 0.7379, 1.2453, -0.0416 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_4", meshId = 14406440874, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.4067, 1.1564, 1.2771 }, offsetM = { 0.7616, 0.8594, -0.2164 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_10", meshId = 14406441437, paint = true, sizeM = { 0.2083, 0.1424, 0.1545 }, offsetM = { 0.9788, 1.0453, -0.5171 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_26", meshId = 14406441278, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.1804, 0.12, 0.0727 }, offsetM = { 0.975, 1.0464, -0.4829 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_5", meshId = 14406441055, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.3293, 0.2043, 0.1199 }, offsetM = { -0.3862, 0.9251, -0.3967 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_6", meshId = 14406441273, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.6151, 0.47, 0.5922 }, offsetM = { -0.0015, 0.8215, -0.6178 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_7", meshId = 14406441563, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.5858, 0.979, 1.6393 }, offsetM = { -0.0015, 0.7371, 0.502 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_8", meshId = 14406441178, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.9373, 1.1862, 2.7333 }, offsetM = { -0.0015, 0.8445, 0.501 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_27", meshId = 14406441255, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.1804, 0.12, 0.0727 }, offsetM = { -0.9752, 1.0464, -0.4829 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_11", meshId = 14406441164, paint = true, sizeM = { 0.2083, 0.1424, 0.1545 }, offsetM = { -0.9816, 1.0453, -0.5171 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Glass_7", meshId = 14406440735, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, transparency = 0.45, castShadow = false, sizeM = { 0.2174, 0.2899, 0.7861 }, offsetM = { -0.7426, 1.2453, -0.0416 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_12", meshId = 14406440752, paint = true, sizeM = { 0.418, 1.1586, 1.3409 }, offsetM = { -0.7702, 0.8581, -0.2483 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_28", meshId = 14406440762, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.026, 0.048, 0.2203 }, offsetM = { -0.9591, 0.8455, 0.1523 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_9", meshId = 14406440788, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.4067, 1.1564, 1.2771 }, offsetM = { -0.7646, 0.8594, -0.2164 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_29", meshId = 14406440809, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.2847, 0.4697, 1.1383 }, offsetM = { -0.7407, 1.167, -0.1531 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_30", meshId = 14406440804, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.1875, 0.2159, 0.2775 }, offsetM = { -0.8747, 1.0578, -0.5633 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Glass_8", meshId = 14406440841, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.65, castShadow = false, sizeM = { 0.214, 0.414, 0.7792 }, offsetM = { -0.7425, 1.1726, -0.0524 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_31", meshId = 14406440530, textureId = 14406440629, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.5916, 0.1921, 1.4195 }, offsetM = { -0.0014, 0.8983, -1.5132 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_13", meshId = 14406441104, paint = true, sizeM = { 1.5916, 0.1907, 1.3912 }, offsetM = { -0.0014, 0.9095, -1.5274 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_32", meshId = 14406441724, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.6291, 0.0362, 0.0496 }, offsetM = { -0.2309, 1.024, -0.8244 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_33", meshId = 14406441726, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.5319, 0.1014, 0.0465 }, offsetM = { -0.4651, 0.9976, -0.8563 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_34", meshId = 14406440652, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.225, 0.6932, 1.4349 }, offsetM = { 0.8416, 0.6262, -1.5231 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_14", meshId = 14406440852, paint = true, sizeM = { 0.2289, 0.6964, 1.4364 }, offsetM = { 0.8445, 0.6261, -1.5238 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_15", meshId = 14406440741, paint = true, sizeM = { 0.2289, 0.6964, 1.4364 }, offsetM = { -0.8473, 0.6261, -1.5238 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_35", meshId = 14406440657, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.225, 0.6932, 1.4349 }, offsetM = { -0.8462, 0.6262, -1.5231 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_36", meshId = 14406440964, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.8284, 0.2397, 0.124 }, offsetM = { -0.0001, 0.7088, -2.3879 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_37", meshId = 14406441065, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.7676, 0.1603, 0.115 }, offsetM = { -0.0023, 0.6991, -2.3603 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_38", meshId = 14406440653, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.4941, 0.2797, 0.2844 }, offsetM = { -0.0023, 0.7182, -2.2846 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_16", meshId = 14406440942, paint = true, sizeM = { 1.4941, 0.283, 0.2999 }, offsetM = { -0.0014, 0.7182, -2.2923 }, rotationDeg = { 0, 180, 0 } },
				{ name = "HeadLamps", meshId = 14406441159, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.65, castShadow = false, sizeM = { 1.4594, 0.1532, 0.1525 }, offsetM = { -0.0006, 0.6878, -2.3162 }, rotationDeg = { 0, 180, 0 } },
				{ name = "HeadLamps_2", meshId = 14406441190, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.65, castShadow = false, sizeM = { 1.7811, 0.1535, 0.3916 }, offsetM = { -0.0006, 0.6879, -2.1273 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_39", meshId = 14406441392, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.0596, 0.0834, 0.2165 }, offsetM = { -0.8466, 0.6867, -2.0754 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_40", meshId = 14406441398, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.0597, 0.0834, 0.2165 }, offsetM = { 0.8472, 0.6867, -2.0754 }, rotationDeg = { 0, 180, 0 } },
				{ name = "HeadLamps_3", meshId = 14406441302, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.104, 0.1393, 0.1688 }, offsetM = { 0.7658, 0.6869, -2.2294 }, rotationDeg = { 0, 180, 0 } },
				{ name = "HeadLamps_4", meshId = 14406441075, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.4266, 0.1369, 0.1393 }, offsetM = { 0.0002, 0.6904, -2.2885 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Indicators_3", meshId = 14406441419, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.1163, 0.1359, 0.1209 }, offsetM = { 0.477, 0.6899, -2.3163 }, rotationDeg = { 0, 180, 0 } },
				{ name = "HeadLamps_5", meshId = 14406441168, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.762, 0.1349, 0.2626 }, offsetM = { 0.0002, 0.6892, -2.0704 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Indicators_4", meshId = 14406441185, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.1162, 0.1359, 0.1209 }, offsetM = { -0.4765, 0.6899, -2.3163 }, rotationDeg = { 0, 180, 0 } },
				{ name = "HeadLamps_6", meshId = 14406441285, textureId = 14406440836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.104, 0.1393, 0.1688 }, offsetM = { -0.7653, 0.6869, -2.2294 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_41", meshId = 14406440972, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.3227, 0.1919, 0.1129 }, offsetM = { -0.0023, 0.4348, -2.5276 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_17", meshId = 14406440954, paint = true, sizeM = { 1.8373, 0.3706, 0.7508 }, offsetM = { -0.0014, 0.4282, -2.1966 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_42", meshId = 14406440913, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.7987, 0.3704, 0.6962 }, offsetM = { -0.0023, 0.4298, -2.1694 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_43", meshId = 14406440917, textureId = 14406440764, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.2754, 0.0712, 0.0969 }, offsetM = { -0.0023, 0.3278, -2.3951 }, rotationDeg = { 0, 180, 0 } },
			},
			wheelPieces = {
				{ name = "Tyre", meshId = 2176361415, textureId = 2176366836, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.2979, 0.6785, 0.6777 }, offsetM = { 0, 0, 0 }, rotationDeg = { 0, 0, 0 } },
				{ name = "Rim", meshId = 14229223888, textureId = 14229417264, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.5776, 0.5776, 0.0461 }, offsetM = { -0.1226, 0, -0.0001 }, rotationDeg = { 0, 89.994, 0 } },
				{ name = "Rim_Cap", meshId = 14229226343, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.2093, 0.2091, 0.0278 }, offsetM = { -0.1128, 0.0001, -0.0001 }, rotationDeg = { 0, 89.994, 0 } },
			},
		},
		tuning = {
			effects = {
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
				-- Opaque tail lenses: the Krown Vik's darker tail, so braking shows.
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
				{ name = "Chrome_3", meshId = 105175113520830, mesh = "Lekzas/Chrome_3", color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, sizeM = { 1.8031, 0.9497, 4.9353 }, offsetM = { 0, 0.9439, 0.1946 } },
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
				{ name = "Interior_4", meshId = 123562129311523, mesh = "LekzasCabin/Interior_4", color = Color3.fromRGB(53, 53, 53), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.615, 0.5267, 2.4264 }, offsetM = { 0, 0.7962, 0.1528 } },
				-- The steering wheel, cut out of the black cabin mesh so the first-person
				-- view can turn it (tools/carbody/wheelcut.py, CarCockpits).
				{ name = "SteeringWheel", meshId = 139003150685411, mesh = "LekzasCabin/SteeringWheel", color = Color3.fromRGB(53, 53, 53), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.3573, 0.3106, 0.1653 }, offsetM = { -0.3577, 0.9628, -0.4053 } },
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
	-- chrome boot strip that carries the maker's oval and lettering, and
	-- the maker's emblem on the steering wheel pad (P184, seen from the
	-- first-person view, 2026-11-08). The sunroof glass is a plain block with no mesh id, so the sunroof reads
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
				-- The grille's badge spot, empty since the badge was removed, showed a
				-- black hole (owner, 2026-09-27): the badge's own backing oval, turned
				-- to face out, flattened, tilted 30 degrees so all of it catches the
				-- light, and painted, fills it as a plain debadged grille.
				{ name = "Trim_Badge", meshId = 1579969758, paint = true, sizeM = { 0.1525, 0.0915, 0.004 }, offsetM = { -0.002, 0.7139, -2.2916 }, rotationDeg = { 30, 0, 0 } },
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
				{ name = "SteeringWheel_P69", meshId = 1578584236, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.2779, 0.1158, 0.0716 }, offsetM = { -0.3838, 0.8581, -0.3959 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P70", meshId = 1578606330, paint = true, sizeM = { 1.3631, 0.4036, 0.5204 }, offsetM = { -0.0018, 0.9229, 2.1291 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P71", meshId = 1578607620, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, sizeM = { 1.233, 0.1707, 0.124 }, offsetM = { -0.0018, 0.8927, 2.3165 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P72", meshId = 1579926606, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.2, castShadow = false, sizeM = { 0.1758, 0.366, 1.0286 }, offsetM = { 0.7063, 1.1676, -0.2477 }, rotationDeg = { 4.891, -180, 0 } },
				{ name = "P73", meshId = 1579872296, color = Color3.fromRGB(0, 0, 0), material = Enum.Material.SmoothPlastic, sizeM = { 0.3646, 0.1088, 0.0295 }, offsetM = { -0.3779, 0.9058, -0.7621 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P74", meshId = 1579929445, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 1.286, 0.2978, 0.8048 }, offsetM = { -0.0016, 1.272, 1.538 }, rotationDeg = { 0, -180, 0 } },
				{ name = "P75", meshId = 1579913505, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Plastic, sizeM = { 0.1212, 0.7485, 1.0468 }, offsetM = { -0.7389, 0.7465, -0.3742 }, rotationDeg = { 0, -180, 0 } },
				{ name = "TailLamps_P82", meshId = 1579944508, color = Color3.fromRGB(117, 0, 0), material = Enum.Material.SmoothPlastic, sizeM = { 1.6128, 0.1662, 0.3835 }, offsetM = { -0.0018, 0.8897, 2.1495 }, rotationDeg = { 0, -180, 0 } },
				{ name = "SteeringWheel_P85", meshId = 1578582244, color = Color3.fromRGB(99, 95, 98), material = Enum.Material.Plastic, sizeM = { 0.3417, 0.3212, 0.1629 }, offsetM = { -0.3838, 0.8907, -0.4086 }, rotationDeg = { 0, -180, 0 } },
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
			-- Front-wheel drive, as the real car: its drift styles are the
			-- front-drive ones (DriftStyles).
			drivetrain = { layout = "FWD" },
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
	-- Handling: the old Pickup's mass, so its measured springs and natl torques
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
				{ name = "Interior_Wood", meshId = 86100997329256, mesh = "BatrolCabin/Interior_Wood", textureId = 8941497327, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.4404, 0.2884, 0.1432 }, offsetM = { 0, 1.0775, -0.5113 } },
				{ name = "Body_Caps", meshId = 8941371341, paint = true, sizeM = { 3.2937, 1.4583, 2.1754 }, offsetM = { 0, 1.066, 1.0192 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Underbody_Shocks", meshId = 8941415688, color = Color3.fromRGB(239, 184, 56), material = Enum.Material.SmoothPlastic, sizeM = { 3.0067, 0.4035, 1.3356 }, offsetM = { 0, 0.6417, 0.0148 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Trim", meshId = 77071158495140, mesh = "BatrolCabin/Trim", color = Color3.fromRGB(99, 95, 98), material = Enum.Material.SmoothPlastic, sizeM = { 2.0573, 1.5194, 4.8889 }, offsetM = { -0.051, 1.0687, 0.0554 } },
				{ name = "Interior", meshId = 128361527322613, mesh = "BatrolCabin/Interior", color = Color3.fromRGB(43, 43, 43), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.7656, 1.3505, 3.4388 }, offsetM = { 0, 1.1363, 0.6884 } },
				-- The steering wheel, cut out of the cabin, wood trim, trim and glass
				-- meshes so the first-person view can turn it (tools/carbody/wheelcut.py,
				-- CarCockpits): the black rim and boss, the wood segments, the grey hub plate.
				{ name = "SteeringWheel", meshId = 92493692392428, mesh = "BatrolCabin/SteeringWheel", color = Color3.fromRGB(43, 43, 43), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.4486, 0.4511, 0.1854 }, offsetM = { -0.5045, 1.1356, -0.3462 } },
				{ name = "SteeringWheel_Wood", meshId = 128177701405816, mesh = "BatrolCabin/SteeringWheel_Wood", textureId = 8941497327, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.373, 0.4511, 0.1293 }, offsetM = { -0.5045, 1.1356, -0.3132 } },
				{ name = "SteeringWheel_Trim", meshId = 115880609536168, mesh = "BatrolCabin/SteeringWheel_Trim", color = Color3.fromRGB(99, 95, 98), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.3587, 0.2152, 0.0696 }, offsetM = { -0.488, 1.0998, -0.3211 } },
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
				{ name = "Glass", meshId = 120542391298254, mesh = "BatrolCabin/Glass", color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Glass, transparency = 0.7, castShadow = false, sizeM = { 1.7897, 1.1716, 4.684 }, offsetM = { 0.012, 1.2426, 0.0927 } },
				{ name = "FogLamps", meshId = 8941450998, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.6448, 0.6409, 1.6278 }, offsetM = { 0, 0.9531, -1.4546 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Chrome", meshId = 134304059207286, mesh = "Batrol/Chrome", color = Color3.fromRGB(248, 248, 248), material = Enum.Material.Metal, sizeM = { 1.905, 1.1262, 4.7811 }, offsetM = { 0.0246, 0.8758, 0.0436 } },
			},
			wheelPieces = {
				{ name = "Rim_Face", meshId = 8941522368, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, sizeM = { 0.5341, 0.508, 0.0382 }, offsetM = { -0.1366, 0.022, -0.0005 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Rim", meshId = 8941509678, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.5656, 0.5675, 0.3144 }, offsetM = { -0.0011, 0.0038, -0.0005 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Tyre", meshId = 8941514489, color = Color3.fromRGB(25, 25, 25), material = Enum.Material.Rubber, sizeM = { 0.8555, 0.856, 0.2888 }, offsetM = { 0, 0, 0 }, rotationDeg = { 0, 90, 0 } },
			},
		},
		tuning = {
			-- Four-wheel drive, as the real truck: its drift styles are the
			-- all-wheel-drive ones, which set the split (DriftStyles).
			drivetrain = { layout = "AWD" },
			-- The old Pickup's, measured at the same 2.2 t: it sits at the sedan's sag.
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
	-- Handling: the Batrol's (the old Pickup's mass, springs and natl torques).
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
			-- Four-wheel drive, as the real truck: its drift styles are the
			-- all-wheel-drive ones, which set the split (DriftStyles).
			drivetrain = { layout = "AWD" },
			-- The old Pickup's, measured at the same 2.2 t.
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
	-- THE TAHU. A late-2000s American full-size SUV from the Creator Store
	-- (asset 1370195897, an A-Chassis car), brought to the store-car standard
	-- (tools/carbody/README.md) by storecar.py tahu: store meshes by id,
	-- interior kept, 31,321 triangles of the store model's 44,112. Dropped:
	-- the engine under the bonnet, the maker's bowtie on the grille and the
	-- tailgate, the model and trim names across the tailgate; the model name
	-- above each front door's moulding is cut out of the door chrome
	-- (generated Chrome_3 and Chrome_5), the bowtie on the airbag painted out
	-- (generated SteeringWheel), and the rims' texture (a bowtie on the cap)
	-- left off for plain metal. The steering wheel is a piece of its own for
	-- the first-person view (the owner, 2026-11-07: "the wheel and whatnot
	-- can move"). Its own lamp parts, horn, startup and engine loop.
	--
	-- Placed at 0.2522 m a model stud, so its wheel centres sit on the real
	-- 2.946 m wheelbase: 5.08 m long, 1.60 m track, 0.78 m tyres.
	tahu = {
		displayName = "Tahu",
		blurb = "The big family hauler. Wide, tall and smooth across the sand.",
		order = 10,
		scale = 1.2,
		rig = {
			massKg = 2400,
			-- Nose at -2.40 m, tail at +2.68 m.
			collisionSizeM = { 1.95, 1.25, 4.9 },
			centerOfMassM = { 0, -0.25, -0.1 },
			shellMassFraction = 0.55,
			wheelbaseM = 2.946,
			trackWidthM = 1.5963,
			wheelRadiusM = 0.3885,
			wheelWidthM = 0.2433,
			-- The store model's driver seat (0.43 m left of centre), 0.55 m off
			-- the ground so a seated head clears the 1.82 m roof.
			seatM = { -0.43, -0.46, -0.18 },
		},
		body = {
			paint = Color3.fromRGB(236, 236, 232),
			pieces = {
				{ name = "Interior", meshId = 1225124666, textureId = 1225159452, color = Color3.fromRGB(49, 49, 49), material = Enum.Material.Sand, castShadow = false, sizeM = { 0.2183, 1.3735, 1.009 }, offsetM = { -0.7057, 1.002, 0.7504 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim", meshId = 1225124779, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 0.1796, 0.5096, 0.8153 }, offsetM = { -0.7328, 1.3848, 0.7214 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_2", meshId = 1225124448, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 0.354, 1.3736, 1.0126 }, offsetM = { -0.7725, 1.0019, 0.7521 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Body", meshId = 1225124027, paint = true, sizeM = { 0.3542, 1.3735, 1.0126 }, offsetM = { -0.7726, 1.002, 0.7521 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Chrome", meshId = 1225124544, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.0511, 0.3456, 0.8684 }, offsetM = { -0.9054, 0.8436, 0.7444 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Glass", meshId = 1225124141, textureId = 1225156333, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.3, castShadow = false, sizeM = { 0.1637, 0.5094, 0.8545 }, offsetM = { -0.7423, 1.3643, 0.7372 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Glass_2", meshId = 1225121440, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.6, castShadow = false, sizeM = { 0.175, 0.5211, 1.0962 }, offsetM = { -0.7395, 1.3426, -0.3472 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Interior_2", meshId = 1225122259, textureId = 1225159452, color = Color3.fromRGB(49, 49, 49), material = Enum.Material.Sand, castShadow = false, sizeM = { 0.2338, 1.3696, 1.2013 }, offsetM = { -0.7122, 0.9872, -0.3528 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_3", meshId = 1225121118, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 0.4643, 0.5023, 1.0244 }, offsetM = { -0.8752, 1.3571, -0.3137 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_4", meshId = 1225120668, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, sizeM = { 0.2498, 0.1502, 0.0772 }, offsetM = { -0.9699, 1.2077, -0.6601 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_5", meshId = 1225120840, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 0.3323, 1.3697, 1.2674 }, offsetM = { -0.7615, 0.9871, -0.3621 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Body_2", meshId = 1225120054, paint = true, sizeM = { 0.3412, 1.3697, 1.2674 }, offsetM = { -0.7659, 0.9871, -0.3621 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Chrome_2", meshId = 1225120354, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.0312, 0.0509, 0.241 }, offsetM = { -0.8883, 0.9774, 0.1163 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Chrome_3", meshId = 79513281908712, mesh = "Tahu/Chrome_3", color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.3783, 0.6432, 1.1581 }, offsetM = { -0.917, 0.9817, -0.3206 } },
				{ name = "Interior_3", meshId = 1225126108, color = Color3.fromRGB(49, 49, 49), material = Enum.Material.Sand, castShadow = false, sizeM = { 1.547, 0.2011, 1.1549 }, offsetM = { -0.0032, 1.0685, -1.7025 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Body_3", meshId = 1225125948, paint = true, sizeM = { 1.547, 0.2011, 1.1549 }, offsetM = { -0.0032, 1.0685, -1.7025 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Glass_3", meshId = 1225122881, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.6, castShadow = false, sizeM = { 0.1701, 0.5242, 1.0962 }, offsetM = { 0.7374, 1.3452, -0.3472 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Interior_4", meshId = 1225123512, textureId = 1225159452, color = Color3.fromRGB(49, 49, 49), material = Enum.Material.Sand, castShadow = false, sizeM = { 0.1762, 0.8248, 1.203 }, offsetM = { 0.7335, 0.7149, -0.3502 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_6", meshId = 1225123213, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 0.4645, 0.5023, 1.0244 }, offsetM = { 0.8675, 1.3572, -0.3136 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_7", meshId = 1225123086, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, sizeM = { 0.2497, 0.1587, 0.0772 }, offsetM = { 0.9623, 1.212, -0.6601 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_8", meshId = 1225123362, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 0.3329, 1.3696, 1.2674 }, offsetM = { 0.7539, 0.9872, -0.3621 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Body_4", meshId = 1225122783, paint = true, sizeM = { 0.3564, 1.3696, 1.2674 }, offsetM = { 0.7657, 0.9872, -0.3621 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Chrome_4", meshId = 1225123706, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.0312, 0.0509, 0.2411 }, offsetM = { 0.8807, 0.9775, 0.1164 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Chrome_5", meshId = 73402743829826, mesh = "Tahu/Chrome_5", color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.4022, 0.7083, 1.182 }, offsetM = { 0.8975, 1.0177, -0.3215 } },
				{ name = "Interior_5", meshId = 1225170657, textureId = 1225159452, color = Color3.fromRGB(49, 49, 4), material = Enum.Material.Sand, castShadow = false, sizeM = { 0.2309, 0.5779, 1.1969 }, offsetM = { 0.7046, 1.3728, -0.3626 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Interior_6", meshId = 1225125645, textureId = 1225159452, color = Color3.fromRGB(49, 49, 49), material = Enum.Material.Sand, castShadow = false, sizeM = { 0.2183, 1.3735, 1.009 }, offsetM = { 0.6968, 1.002, 0.7504 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_9", meshId = 1225125557, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 0.1798, 0.5096, 0.8154 }, offsetM = { 0.7249, 1.3848, 0.7215 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Chrome_6", meshId = 1225125730, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.0479, 0.3353, 0.8811 }, offsetM = { 0.896, 0.8487, 0.7381 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_10", meshId = 1225125408, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 0.3541, 1.3735, 1.0127 }, offsetM = { 0.7647, 1.002, 0.7522 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Body_5", meshId = 1225125303, paint = true, sizeM = { 0.3543, 1.3735, 1.0127 }, offsetM = { 0.7648, 1.002, 0.7522 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Glass_4", meshId = 1225125203, textureId = 1225156333, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.3, castShadow = false, sizeM = { 0.1638, 0.5094, 0.8545 }, offsetM = { 0.7274, 1.3663, 0.7373 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Interior_7", meshId = 1225129015, textureId = 1225159452, color = Color3.fromRGB(49, 49, 49), material = Enum.Material.Sand, castShadow = false, sizeM = { 1.5232, 0.561, 0.1538 }, offsetM = { -0.0033, 0.9289, 2.4253 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_11", meshId = 1225128872, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 0.5504, 0.1116, 0.0904 }, offsetM = { -0.0108, 1.2117, 2.5037 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Glass_5", meshId = 1225128582, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.1, castShadow = false, sizeM = { 1.5151, 0.46, 0.3482 }, offsetM = { -0.003, 1.4309, 2.3199 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Glass_6", meshId = 1225129242, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.5, castShadow = false, sizeM = { 1.5151, 0.46, 0.3482 }, offsetM = { -0.003, 1.4309, 2.3199 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Body_6", meshId = 1225128366, paint = true, sizeM = { 1.5232, 1.0429, 0.4211 }, offsetM = { -0.0033, 1.1688, 2.3356 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "TailLamps", meshId = 1225126758, color = Color3.fromRGB(151, 0, 0), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.5346, 0.0325, 0.0376 }, offsetM = { -0.0038, 1.652, 2.2326 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "SteeringWheel", meshId = 80954137553895, mesh = "Tahu/SteeringWheel", textureId = 1225158869, color = Color3.fromRGB(49, 49, 49), material = Enum.Material.Sand, castShadow = false, sizeM = { 0.3982, 0.3599, 0.1937 }, offsetM = { -0.4043, 1.1295, -0.6711 } },
				{ name = "Interior_8", meshId = 1225118070, textureId = 1225159452, color = Color3.fromRGB(49, 49, 49), material = Enum.Material.Sand, castShadow = false, sizeM = { 1.1721, 1.0418, 0.6367 }, offsetM = { 0.0055, 0.9659, 1.6457 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_12", meshId = 1225139641, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 1.8504, 0.9249, 0.8057 }, offsetM = { 0.0126, 0.7415, 2.2632 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Glass_7", meshId = 1225114685, textureId = 1225156333, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.1, castShadow = false, sizeM = { 1.691, 0.4571, 1.1178 }, offsetM = { -0.0032, 1.417, 1.7355 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Interior_9", meshId = 1225118070, textureId = 1225159452, color = Color3.fromRGB(49, 49, 49), material = Enum.Material.Sand, castShadow = false, sizeM = { 1.3883, 1.0418, 0.889 }, offsetM = { -0.0125, 0.9553, 0.7809 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_13", meshId = 1225139502, color = Color3.fromRGB(117, 0, 0), material = Enum.Material.SmoothPlastic, sizeM = { 1.7403, 0.4177, 0.1683 }, offsetM = { -0.0016, 0.9613, 2.3718 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_14", meshId = 1225115831, color = Color3.fromRGB(0, 0, 0), material = Enum.Material.SmoothPlastic, sizeM = { 1.4821, 0.4607, 0.7446 }, offsetM = { -0.0029, 1.4018, -0.765 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Interior_10", meshId = 1225117078, textureId = 1225162571, color = Color3.fromRGB(49, 49, 49), material = Enum.Material.Sand, castShadow = false, sizeM = { 1.5239, 0.9104, 1.3282 }, offsetM = { -0.0207, 0.7844, -0.4569 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Chrome_7", meshId = 1225137000, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 1.5157, 0.0203, 0.1038 }, offsetM = { -0.0081, 0.6447, 2.6154 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Glass_8", meshId = 1225114166, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.5, castShadow = false, sizeM = { 1.3686, 0.4016, 0.6173 }, offsetM = { -0.0029, 1.4107, -0.7463 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_15", meshId = 1225116638, textureId = 1225159452, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 1.6758, 1.3541, 3.5846 }, offsetM = { -0.0703, 0.9738, 0.8454 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Glass_9", meshId = 1225114943, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.6, castShadow = false, sizeM = { 1.691, 0.4571, 1.1178 }, offsetM = { -0.0032, 1.417, 1.7355 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Interior_11", meshId = 1225130226, textureId = 1225159452, color = Color3.fromRGB(49, 49, 49), material = Enum.Material.Sand, castShadow = false, sizeM = { 1.8826, 1.3785, 3.6175 }, offsetM = { -0.0031, 0.9978, 0.5814 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_16", meshId = 1225112574, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.Plastic, sizeM = { 1.1538, 0.1345, 1.7175 }, offsetM = { -0.0008, 1.7381, 1.1988 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Glass_10", meshId = 1225139189, color = Color3.fromRGB(151, 0, 0), material = Enum.Material.SmoothPlastic, transparency = 0.6, castShadow = false, sizeM = { 1.7824, 0.4611, 0.1804 }, offsetM = { -0.004, 0.9765, 2.3803 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Body_7", meshId = 1225114513, paint = true, sizeM = { 1.913, 1.4913, 4.7909 }, offsetM = { -0.0031, 1.0004, 0.278 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_17", meshId = 1225136025, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 1.7307, 0.3453, 0.0867 }, offsetM = { -0.0016, 0.9947, 2.3316 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_18", meshId = 1225115671, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.Sand, sizeM = { 1.913, 1.4104, 3.683 }, offsetM = { -0.0031, 0.9641, 0.6145 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Glass_11", meshId = 1225137226, color = Color3.fromRGB(99, 95, 98), material = Enum.Material.SmoothPlastic, transparency = 0.6, castShadow = false, sizeM = { 1.7222, 0.6137, 4.7116 }, offsetM = { -0.004, 0.7055, 0.1175 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Chrome_8", meshId = 1225112827, color = Color3.fromRGB(231, 231, 236), material = Enum.Material.Metal, sizeM = { 0.9426, 0.0348, 1.1786 }, offsetM = { 0.0002, 1.7877, 1.1776 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_19", meshId = 1225138625, color = Color3.fromRGB(151, 0, 0), material = Enum.Material.SmoothPlastic, sizeM = { 1.7398, 0.0616, 0.0897 }, offsetM = { -0.0016, 0.7803, 2.3382 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Indicators", meshId = 1225138906, color = Color3.fromRGB(226, 155, 64), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.639, 0.2035, 0.1011 }, offsetM = { -0.0031, 0.8576, -1.9833 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_20", meshId = 1225113509, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.Sand, sizeM = { 0.1759, 0.07, 0.0795 }, offsetM = { 0.6784, 0.2503, 2.1952 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Chrome_9", meshId = 1225113233, textureId = 1225177609, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.6057, 0.1826, 1.234 }, offsetM = { 0.4635, 0.2995, 1.6173 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_21", meshId = 1225116408, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 1.5952, 1.2978, 3.5882 }, offsetM = { -0.0029, 0.9627, 0.5812 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Interior_12", meshId = 1225138056, color = Color3.fromRGB(49, 49, 49), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.6614, 0.2702, 0.3235 }, offsetM = { -0.0031, 0.8542, -2.079 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Chrome_10", meshId = 1225113792, textureId = 1225177609, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.Metal, sizeM = { 1.5833, 0.7556, 3.3067 }, offsetM = { -0.0052, 0.5636, 0.1268 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Underbody", meshId = 1225115494, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.Metal, sizeM = { 1.7451, 0.0625, 4.6384 }, offsetM = { -0.0021, 0.3339, 0.0976 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "FogLamps", meshId = 1225137896, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.5163, 0.0912, 0.0286 }, offsetM = { -0.0015, 0.4168, -2.1011 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_22", meshId = 1225133321, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.SmoothPlastic, sizeM = { 1.5195, 0.2672, 0.2101 }, offsetM = { -0.0031, 1.0127, -1.2544 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "HeadLamps", meshId = 1225138287, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.3156, 0.1106, 0.0155 }, offsetM = { -0.0031, 0.8812, -2.1071 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_23", meshId = 1197442933, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.Plastic, sizeM = { 0.1736, 0.0601, 0.0671 }, offsetM = { -0.0103, 1.4938, -0.442 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_24", meshId = 1225112280, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.Plastic, sizeM = { 1.2322, 0.0689, 0.3581 }, offsetM = { -0.0032, 0.9974, -2.0894 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_25", meshId = 1225110341, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.Sand, sizeM = { 1.7459, 0.7138, 0.3446 }, offsetM = { 0.0003, 0.6422, -1.9632 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Chrome_11", meshId = 1225111872, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 1.0484, 0.3013, 0.1134 }, offsetM = { -0.0032, 0.8297, -2.2587 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Body_8", meshId = 1225110995, paint = true, sizeM = { 1.7571, 0.7135, 0.6034 }, offsetM = { 0.0003, 0.6405, -2.0926 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Chrome_12", meshId = 1225110825, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Metal, sizeM = { 1.2201, 0.0294, 0.1673 }, offsetM = { -0.0032, 0.992, -2.1087 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_26", meshId = 1225111350, color = Color3.fromRGB(32, 32, 32), material = Enum.Material.Sand, sizeM = { 1.5634, 0.7477, 0.4109 }, offsetM = { -0.0032, 0.6579, -2.0653 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Trim_27", meshId = 1043179032, textureId = 1225179077, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Sand, sizeM = { 1.106, 0.2816, 0.1025 }, offsetM = { -0.0033, 0.8309, -2.2538 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "HeadLamps_2", meshId = 1225138423, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.5864, 0.2169, 0.1599 }, offsetM = { -0.0031, 0.8531, -2.1223 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Indicators_2", meshId = 1225137800, color = Color3.fromRGB(218, 133, 65), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.1158, 0.0486, 0.0893 }, offsetM = { 0.7312, 0.7712, -2.1169 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "Indicators_3", meshId = 1225137651, color = Color3.fromRGB(218, 133, 65), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.1158, 0.0486, 0.0893 }, offsetM = { -0.7375, 0.7712, -2.1169 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "TailLamps_2", meshId = 1225136498, color = Color3.fromRGB(196, 40, 28), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0932, 0.1099, 0.0442 }, offsetM = { -0.817, 0.8841, 2.3948 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "ReverseLamps", meshId = 1225136725, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.7157, 0.0751, 0.0283 }, offsetM = { -0.0016, 0.987, 2.3846 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "TailLamps_3", meshId = 1225136193, color = Color3.fromRGB(196, 40, 28), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.7013, 0.1285, 0.0444 }, offsetM = { -0.0016, 1.101, 2.3713 }, rotationDeg = { 0.701, 180, 0 } },
				{ name = "TailLamps_4", meshId = 1225136430, color = Color3.fromRGB(196, 40, 28), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0932, 0.1099, 0.0442 }, offsetM = { 0.8139, 0.8841, 2.3948 }, rotationDeg = { 0.701, 180, 0 } },
			},
			wheelPieces = {
				{ name = "Tyre", meshId = 1225119407, color = Color3.fromRGB(0, 0, 0), material = Enum.Material.Concrete, sizeM = { 0.2433, 0.7769, 0.7767 }, offsetM = { 0, 0, 0 }, rotationDeg = { -0.701, 0, 0 } },
				{ name = "Rim", meshId = 1225119013, color = Color3.fromRGB(200, 202, 206), material = Enum.Material.Metal, sizeM = { 0.2381, 0.5367, 0.5365 }, offsetM = { 0.0026, 0, 0 }, rotationDeg = { -0.701, 0, 0 } },
			},
		},
		tuning = {
			-- Four-wheel drive, as its A-Chassis tune (Config "AWD").
			drivetrain = { layout = "AWD" },
			-- The Kruzer 80's, scaled to its 2.4 t.
			suspension = { stiffness = 49000, damping = 4600, antiRollFront = 9800, antiRollRear = 6500 },
			twoWheel = { liftTorque = 18000, leanInTorque = 6500, leanOutTorque = 6000, balanceSpring = 160 },
			effects = {
				-- The store model's own horn (it plays it at 0.95 speed) and
				-- startup.
				horn = { soundId = "rbxassetid://787905239" },
				-- Its A-Chassis stock "Rev" loop, one file for every layer. The
				-- plugin plays it at pitch 0.12 + 0.85 x rpm / 6700 (its
				-- redline), which is 1 at 6936 rpm: that is refRpm.
				engineAudio = {
					startSoundId = "rbxassetid://385436327",
					layers = {
						idle = { soundId = "rbxassetid://296747872", refRpm = 6936, volume = 0.5, eq = { 0, 0, -6 } },
						lowLoad = { soundId = "rbxassetid://296747872", refRpm = 6936, volume = 0.8, eq = { 3, 0, -3 } },
						highLoad = { soundId = "rbxassetid://296747872", refRpm = 6936, volume = 1, eq = { 0, 2, 2 } },
						overrun = { soundId = "rbxassetid://296747872", refRpm = 6936, volume = 0.5, eq = { 0, -2, -8 } },
					},
				},
			},
		},
	},
	-- THE SONATTA. A mid-2000s Korean family saloon from the Creator Store
	-- (asset 9547275128, an A-Chassis car), brought to the store-car standard
	-- (tools/carbody/README.md) by storecar.py sonatta: store meshes by id,
	-- interior kept, the engine dropped. The maker's badge front and back,
	-- its name, the model name and the engine badge are cut out of the
	-- chrome (generated Chrome), the grille badge's backing out of the window
	-- trim, whose texture also carries the tail lamps: they are split out as
	-- their own piece (generated Trim_2 and TailLamps). The badge on the
	-- airbag is painted out (generated SteeringWheel), the steering wheel a
	-- piece of its own for the first-person view. Its wheels are plain parts
	-- with decals in the store model, so it has the Batrol's wheel. Its own
	-- horn, startup and engine loop.
	--
	-- Placed at 0.2487 m a model stud, so its wheel centres sit on the real
	-- 2.73 m wheelbase: 4.70 m long, 1.61 m track, 0.68 m tyres.
	sonatta = {
		displayName = "Sonatta",
		blurb = "The quiet family saloon. Light, front-driven and quick to swing.",
		order = 11,
		scale = 1.2,
		rig = {
			massKg = 1550,
			-- Nose at -2.26 m, tail at +2.43 m.
			collisionSizeM = { 1.78, 1.15, 4.5 },
			centerOfMassM = { 0, -0.3, -0.15 },
			shellMassFraction = 0.35,
			wheelbaseM = 2.73,
			trackWidthM = 1.6073,
			wheelRadiusM = 0.3375,
			wheelWidthM = 0.2277,
			-- The store model's driver seat (0.44 m left of centre), 0.28 m off
			-- the ground so a seated head clears the 1.53 m roof.
			seatM = { -0.44, -0.63, -0.22 },
		},
		body = {
			paint = Color3.fromRGB(240, 240, 236),
			pieces = {
				{ name = "Chrome", meshId = 122381099208485, mesh = "Sonatta/Chrome", color = Color3.fromRGB(202, 203, 209), material = Enum.Material.Metal, sizeM = { 1.8308, 0.6374, 2.5914 }, offsetM = { 0.0068, 0.601, -0.1398 } },
				{ name = "Trim", meshId = 2114250357, textureId = 2114276920, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Plastic, sizeM = { 1.6589, 0.3886, 0.4924 }, offsetM = { 0.0942, 0.3845, -1.9339 }, rotationDeg = { -0.049, -0.081, -0.416 } },
				{ name = "Body", meshId = 2114228112, paint = true, sizeM = { 2.0466, 1.2963, 2.9161 }, offsetM = { 0.0069, 0.8754, 0.4931 }, rotationDeg = { -0.049, -0.081, -0.416 } },
				{ name = "Body_2", meshId = 2114229783, paint = true, sizeM = { 1.829, 1.103, 1.2729 }, offsetM = { 0.0262, 0.84, 1.7952 }, rotationDeg = { -0.049, -0.081, -0.416 } },
				{ name = "Body_3", meshId = 2114227243, paint = true, sizeM = { 1.1949, 0.7931, 1.4598 }, offsetM = { 0.3356, 0.6279, -1.5306 }, rotationDeg = { -0.049, -0.081, -0.416 } },
				{ name = "Body_4", meshId = 2114222485, paint = true, sizeM = { 1.8352, 0.8469, 1.9271 }, offsetM = { -0.0013, 0.6713, -1.2916 }, rotationDeg = { -0.049, -0.081, -0.416 } },
				{ name = "Interior", meshId = 2114255780, textureId = 2114280192, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Plastic, castShadow = false, sizeM = { 1.8646, 1.13, 2.357 }, offsetM = { 0.0066, 0.8961, 0.1325 }, rotationDeg = { -0.049, -0.081, -0.416 } },
				{ name = "Interior_2", meshId = 2114256299, textureId = 2114272240, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Plastic, castShadow = false, sizeM = { 1.6045, 1.2563, 2.8637 }, offsetM = { 0.0103, 0.8695, 0.4189 }, rotationDeg = { -0.049, -0.081, -0.416 } },
				{ name = "SteeringWheel", meshId = 72771107043309, mesh = "Sonatta/SteeringWheel", textureId = 2114280192, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.4085, 0.3821, 0.1977 }, offsetM = { -0.4035, 0.8779, -0.4069 } },
				{ name = "Interior_3", meshId = 2114248045, textureId = 2114272240, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Plastic, castShadow = false, sizeM = { 1.8646, 1.2185, 2.2005 }, offsetM = { 0.0061, 0.8519, 0.2109 }, rotationDeg = { -0.049, -0.081, -0.416 } },
				{ name = "Interior_4", meshId = 2114245655, textureId = 2114272240, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Plastic, castShadow = false, sizeM = { 1.1082, 1.2185, 1.5043 }, offsetM = { -0.3467, 0.8542, -0.1378 }, rotationDeg = { -0.049, -0.081, -0.416 } },
				{ name = "Glass", meshId = 2114248915, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Glass, transparency = 0.6, castShadow = false, sizeM = { 1.6718, 1.0801, 3.9623 }, offsetM = { 0.007, 0.8872, -0.1759 }, rotationDeg = { -0.049, -0.081, -0.416 } },
				{ name = "Trim_2", meshId = 125689742487269, mesh = "Sonatta/Trim_2", textureId = 2114274207, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Plastic, sizeM = { 2.0272, 1.1952, 3.4888 }, offsetM = { 0.0098, 0.9016, 0.6524 } },
				{ name = "TailLamps", meshId = 108318032589944, mesh = "Sonatta/TailLamps", textureId = 2114274207, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Plastic, castShadow = false, sizeM = { 1.6926, 0.1585, 0.3494 }, offsetM = { 0.0035, 0.9026, 2.1483 } },
				{ name = "Underbody", meshId = 2114249911, textureId = 2114276920, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Plastic, sizeM = { 1.8762, 0.5483, 4.2575 }, offsetM = { 0.0033, 0.4629, 0.2157 }, rotationDeg = { -0.049, -0.081, -0.416 } },
				{ name = "Trim_3", meshId = 2114251075, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Plastic, sizeM = { 1.5916, 0.0505, 0.4218 }, offsetM = { 0.0051, 0.2689, -1.9785 }, rotationDeg = { -0.049, -0.081, -0.416 } },
				{ name = "Trim_4", meshId = 2114252168, textureId = 2114277567, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Plastic, sizeM = { 1.8328, 0.5707, 0.57 }, offsetM = { 0.0076, 0.6157, -1.9563 }, rotationDeg = { -0.049, -0.081, -0.416 } },
				{ name = "Chrome_2", meshId = 2114251472, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.Metal, sizeM = { 1.8688, 1.1598, 3.3454 }, offsetM = { 0.0057, 0.8832, 0.6896 }, rotationDeg = { -0.049, -0.081, -0.416 } },
				{ name = "HeadLamps", meshId = 2114252527, textureId = 2114277567, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.Metal, castShadow = false, sizeM = { 1.6777, 0.4576, 0.359 }, offsetM = { 0.0073, 0.5727, -1.9786 }, rotationDeg = { -0.049, -0.081, -0.416 } },
				{ name = "HeadLamps_2", meshId = 2114250663, textureId = 2114277567, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.Metal, castShadow = false, sizeM = { 1.4568, 0.413, 0.1425 }, offsetM = { 0.0072, 0.5559, -1.9879 }, rotationDeg = { -0.049, -0.081, -0.416 } },
				{ name = "TailLamps_2", meshId = 2114230992, color = Color3.fromRGB(151, 0, 0), material = Enum.Material.Metal, castShadow = false, sizeM = { 1.2065, 0.0803, 0.055 }, offsetM = { 0.0037, 0.9095, 2.2739 }, rotationDeg = { -0.049, -0.081, -0.416 } },
			},
			wheelPieces = {
				{ name = "Rim_Face", meshId = 8941522368, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, sizeM = { 0.4211, 0.4006, 0.0301 }, offsetM = { -0.1077, 0.0173, -0.0004 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Rim", meshId = 8941509678, color = Color3.fromRGB(202, 203, 209), material = Enum.Material.SmoothPlastic, sizeM = { 0.446, 0.4475, 0.2479 }, offsetM = { -0.0009, 0.003, -0.0004 }, rotationDeg = { 0, 90, 0 } },
				{ name = "Tyre", meshId = 8941514489, color = Color3.fromRGB(25, 25, 25), material = Enum.Material.Rubber, sizeM = { 0.6746, 0.675, 0.2277 }, offsetM = { 0, 0, 0 }, rotationDeg = { 0, 90, 0 } },
			},
		},
		tuning = {
			-- Front-wheel drive, as the real car (its A-Chassis tune says RWD).
			drivetrain = { layout = "FWD" },
			effects = {
				-- The store model's own horn and startup.
				horn = { soundId = "rbxassetid://858930850" },
				-- Its A-Chassis "Rev" loop, one file for every layer. Its kit's
				-- pitch values give no clear reference rpm, so refRpm is a first
				-- guess to tune by ear.
				engineAudio = {
					startSoundId = "rbxassetid://538664949",
					layers = {
						idle = { soundId = "rbxassetid://785952066", refRpm = 4500, volume = 0.5, eq = { 0, 0, -6 } },
						lowLoad = { soundId = "rbxassetid://785952066", refRpm = 4500, volume = 0.8, eq = { 3, 0, -3 } },
						highLoad = { soundId = "rbxassetid://785952066", refRpm = 4500, volume = 1, eq = { 0, 2, 2 } },
						overrun = { soundId = "rbxassetid://785952066", refRpm = 4500, volume = 0.5, eq = { 0, -2, -8 } },
					},
				},
			},
		},
	},
	-- THE AKORD. A late-2000s Japanese family saloon from the Creator Store
	-- (asset 4913850907, an A-Chassis car), brought to the store-car standard
	-- (tools/carbody/README.md) by storecar.py akord: store meshes by id,
	-- interior kept, 87,874 triangles of the store model's 89,797. The
	-- maker's badge and its surround are cut out of the grille chrome
	-- (generated Chrome_6), the boot badge and the model's script name out of
	-- the boot chrome (generated Chrome_2). The steering wheel is a piece of
	-- its own for the first-person view. Its own lamps, horn, startup and
	-- engine loop, and its own wheels.
	--
	-- Placed at 0.2745 m a model stud, so its wheel centres sit on the real
	-- 2.80 m wheelbase: 4.99 m long, 1.64 m track, 0.68 m tyres.
	akord = {
		displayName = "Akord",
		blurb = "The sensible saloon with a wild side. Long, smooth and easy to hold sideways.",
		order = 12,
		scale = 1.2,
		rig = {
			massKg = 1550,
			-- Nose at -2.43 m, tail at +2.56 m.
			collisionSizeM = { 1.8, 1.15, 4.7 },
			centerOfMassM = { 0, -0.3, -0.15 },
			shellMassFraction = 0.35,
			wheelbaseM = 2.8,
			trackWidthM = 1.6423,
			wheelRadiusM = 0.3394,
			wheelWidthM = 0.2376,
			-- The store model's driver seat (0.37 m left of centre), 0.26 m off
			-- the ground so a seated head clears the 1.48 m roof.
			seatM = { -0.37, -0.65, -0.11 },
		},
		body = {
			paint = Color3.fromRGB(240, 240, 236),
			pieces = {
				{ name = "SteeringWheel", meshId = 2015794421, textureId = 2015794441, color = Color3.fromRGB(86, 66, 54), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.3851, 0.3416, 0.2022 }, offsetM = { -0.3973, 0.8922, -0.4816 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior", meshId = 2015498120, textureId = 2015498138, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.3156, 1.0926, 1.2572 }, offsetM = { 0.7919, 0.8316, -0.3245 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_2", meshId = 2015761043, textureId = 2015761053, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.2022, 0.4663, 1.2214 }, offsetM = { 0.743, 1.1508, -0.296 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim", meshId = 2015759652, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.1906, 0.1215, 0.048 }, offsetM = { 0.9836, 1.0197, -0.6035 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Glass", meshId = 2015760273, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.7, castShadow = false, sizeM = { 0.1765, 0.4331, 0.912 }, offsetM = { 0.7412, 1.1679, -0.1901 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_3", meshId = 2015499324, textureId = 2015499351, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.0572, 0.1243, 0.6703 }, offsetM = { 0.7378, 0.6396, -0.2207 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body", meshId = 2015461686, paint = true, sizeM = { 0.3191, 0.8181, 1.2061 }, offsetM = { 0.9271, 0.6929, -0.3521 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_2", meshId = 2015463524, paint = true, sizeM = { 0.3256, 0.5905, 1.2187 }, offsetM = { 0.7969, 1.1116, -0.2915 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_4", meshId = 2015495458, textureId = 2015495486, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.097, 0.6728, 1.0331 }, offsetM = { 0.7577, 0.6789, -0.3195 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_5", meshId = 2015767873, textureId = 2015767934, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0958, 0.5413, 0.8805 }, offsetM = { 0.7423, 0.6439, 0.7304 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_3", meshId = 2015765528, paint = true, sizeM = { 0.293, 0.5146, 1.1029 }, offsetM = { 0.7792, 1.151, 0.8016 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_6", meshId = 2015766939, textureId = 2015766948, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.3201, 1.1124, 1.1159 }, offsetM = { 0.7905, 0.8495, 0.7634 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_4", meshId = 2015763378, paint = true, sizeM = { 0.1568, 0.7578, 1.1028 }, offsetM = { 0.8806, 0.6722, 0.7549 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_7", meshId = 2015767527, textureId = 2015767581, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0572, 0.1306, 0.5683 }, offsetM = { 0.723, 0.7009, 0.7701 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Glass_2", meshId = 2015765963, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.7, castShadow = false, sizeM = { 0.1732, 0.3669, 0.9629 }, offsetM = { 0.7358, 1.2011, 0.8182 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Glass_3", meshId = 2015772701, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.7, castShadow = false, sizeM = { 0.1732, 0.3669, 0.9629 }, offsetM = { -0.7378, 1.2011, 0.8182 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_8", meshId = 2015774757, textureId = 2015774775, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0958, 0.5413, 0.8805 }, offsetM = { -0.7442, 0.6439, 0.7304 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_5", meshId = 2015773276, paint = true, sizeM = { 0.293, 0.5146, 1.1029 }, offsetM = { -0.7811, 1.151, 0.8016 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_9", meshId = 2015774493, textureId = 2015774514, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.3201, 1.1124, 1.1159 }, offsetM = { -0.7924, 0.8495, 0.7634 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_6", meshId = 2015772124, paint = true, sizeM = { 0.1568, 0.7578, 1.1028 }, offsetM = { -0.8825, 0.6722, 0.7549 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_10", meshId = 2015775771, textureId = 2015775808, color = Color3.fromRGB(86, 66, 54), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0572, 0.1306, 0.5683 }, offsetM = { -0.7249, 0.7009, 0.7701 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_11", meshId = 2015782323, textureId = 2015782367, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0572, 0.1243, 0.6703 }, offsetM = { -0.7397, 0.6396, -0.2207 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_12", meshId = 2015781494, textureId = 2015781510, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.3156, 1.0926, 1.2572 }, offsetM = { -0.7938, 0.8316, -0.3245 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_2", meshId = 2015780572, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.1906, 0.1215, 0.048 }, offsetM = { -0.9855, 1.0197, -0.6035 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_7", meshId = 2015780977, paint = true, sizeM = { 0.3256, 0.5905, 1.2187 }, offsetM = { -0.7989, 1.1116, -0.2915 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_13", meshId = 2015782049, textureId = 2015782068, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.097, 0.6728, 1.0331 }, offsetM = { -0.7596, 0.6789, -0.3195 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_14", meshId = 2015782713, textureId = 2015782731, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.2022, 0.4663, 1.2214 }, offsetM = { -0.7449, 1.1508, -0.296 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_8", meshId = 2015779701, paint = true, sizeM = { 0.3191, 0.8181, 1.2061 }, offsetM = { -0.929, 0.6929, -0.3521 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Glass_4", meshId = 2015779896, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.7, castShadow = false, sizeM = { 0.1765, 0.4331, 0.912 }, offsetM = { -0.7431, 1.1679, -0.1901 }, rotationDeg = { 0, 180, 0 } },
				{ name = "TailLamps", meshId = 2015907113, color = Color3.fromRGB(151, 0, 0), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.2519, 0.0683, 0.1517 }, offsetM = { -0.001, 0.9229, 2.3558 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome", meshId = 2015909870, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.1686, 0.0265, 0.136 }, offsetM = { -0.001, 0.8789, 2.3673 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_2", meshId = 96804573293319, mesh = "Akord/Chrome_2", color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.2901, 0.1613, 0.6428 }, offsetM = { -0.001, 1.0211, 2.1178 } },
				{ name = "Trim_3", meshId = 2015822398, color = Color3.fromRGB(120, 120, 120), material = Enum.Material.SmoothPlastic, sizeM = { 1.7266, 0.2173, 0.4479 }, offsetM = { -0.001, 0.7186, -1.9031 }, rotationDeg = { 0, 180, 0 } },
				{ name = "TailLamps_2", meshId = 2015870212, color = Color3.fromRGB(117, 0, 0), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.667, 0.2028, 0.6161 }, offsetM = { -0.001, 0.8724, 2.0854 }, rotationDeg = { 0, 180, 0 } },
				{ name = "TailLamps_3", meshId = 2015872492, color = Color3.fromRGB(255, 0, 0), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.5281, 0.1117, 0.0176 }, offsetM = { -0.001, 0.8821, 2.1732 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_4", meshId = 2015815115, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, sizeM = { 1.6848, 0.1454, 0.1653 }, offsetM = { -0.001, 0.7167, -1.9347 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_3", meshId = 2015890963, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.1393, 0.0507, 0.0544 }, offsetM = { -0.7301, 0.8087, 2.255 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Indicators", meshId = 2015861266, color = Color3.fromRGB(213, 115, 61), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0964, 0.0704, 0.0137 }, offsetM = { -0.5707, 0.6656, -2.1142 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_4", meshId = 2015891449, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.1393, 0.0507, 0.0544 }, offsetM = { 0.7282, 0.8087, 2.255 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Indicators_2", meshId = 2015861747, color = Color3.fromRGB(213, 115, 61), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0964, 0.0704, 0.0137 }, offsetM = { 0.5688, 0.6656, -2.1142 }, rotationDeg = { 0, 180, 0 } },
				{ name = "ReverseLamps", meshId = 2015894467, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.3298, 0.0591, 0.186 }, offsetM = { -0.001, 0.8075, 2.292 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_5", meshId = 2015458372, color = Color3.fromRGB(0, 0, 0), material = Enum.Material.SmoothPlastic, sizeM = { 0.701, 0.4625, 0.2404 }, offsetM = { -0.2287, 0.7301, -0.6435 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Indicators_3", meshId = 2015862367, color = Color3.fromRGB(226, 155, 64), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.7256, 0.1532, 0.217 }, offsetM = { -0.001, 0.7512, -1.7873 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_15", meshId = 2015452850, color = Color3.fromRGB(35, 35, 35), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.1233, 0.0395, 0.1687 }, offsetM = { -0.001, 0.5329, -0.3594 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_5", meshId = 2015457182, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.3004, 0.0906, 0.0137 }, offsetM = { -0.3959, 0.8729, -0.751 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_6", meshId = 2011699353, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 1.571, 1.2703, 3.5736 }, offsetM = { -0.001, 0.8454, -0.6298 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_7", meshId = 2011738638, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.2236, 0.0628, 0.0554 }, offsetM = { 0.0093, 0.7784, -0.5402 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_16", meshId = 2015772349, textureId = 2015772366, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.2061, 0.4136, 0.115 }, offsetM = { -0.7323, 1.2009, 0.3063 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_6", meshId = 93482226035481, mesh = "Akord/Chrome_6", color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.9229, 0.1731, 0.1769 }, offsetM = { -0.001, 0.6644, -2.2947 } },
				{ name = "Interior_17", meshId = 2015766380, textureId = 2015766398, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.2061, 0.4136, 0.115 }, offsetM = { 0.7304, 1.2009, 0.3063 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_9", meshId = 2011695945, paint = true, sizeM = { 1.9217, 1.2678, 4.9848 }, offsetM = { -0.001, 0.8467, 0.0699 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Glass_5", meshId = 2011698704, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.7, castShadow = false, sizeM = { 1.5211, 0.5162, 3.0877 }, offsetM = { -0.001, 1.2207, 0.4099 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_18", meshId = 2011729550, color = Color3.fromRGB(35, 35, 35), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.605, 0.9209, 0.7809 }, offsetM = { -0.4349, 0.7128, -0.0391 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_8", meshId = 2011815777, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.6737, 0.1886, 0.0783 }, offsetM = { -0.2432, 0.7935, -0.5679 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_19", meshId = 2011819914, color = Color3.fromRGB(35, 35, 35), material = Enum.Material.Plastic, castShadow = false, sizeM = { 1.4173, 0.7022, 1.0158 }, offsetM = { -0.001, 0.8252, 1.3957 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_20", meshId = 2011863105, textureId = 1715554130, color = Color3.fromRGB(86, 66, 54), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.516, 0.1057, 0.1198 }, offsetM = { 0.0079, 0.7552, -0.598 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_21", meshId = 2011741460, color = Color3.fromRGB(25, 25, 25), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.4746, 1.1633, 1.9558 }, offsetM = { -0.001, 0.7979, 0.331 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_22", meshId = 2011826159, color = Color3.fromRGB(35, 35, 35), material = Enum.Material.Plastic, castShadow = false, sizeM = { 1.689, 1.2188, 2.9376 }, offsetM = { -0.001, 0.8202, 0.3825 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_23", meshId = 2011732659, color = Color3.fromRGB(35, 35, 35), material = Enum.Material.Plastic, castShadow = false, sizeM = { 1.3814, 0.9912, 1.7344 }, offsetM = { -0.001, 0.8952, 0.484 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_9", meshId = 2015866440, color = Color3.fromRGB(16, 16, 16), material = Enum.Material.SmoothPlastic, sizeM = { 0.8032, 0.3135, 1.3875 }, offsetM = { 0.3868, 0.82, -1.5691 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_10", meshId = 2015915773, paint = true, sizeM = { 1.8927, 0.2992, 2.8786 }, offsetM = { -0.001, 0.274, 0.4357 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Underbody", meshId = 2015811390, color = Color3.fromRGB(16, 16, 16), material = Enum.Material.SmoothPlastic, sizeM = { 1.9031, 1.2008, 4.7363 }, offsetM = { -0.001, 0.8129, 0.0901 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_24", meshId = 2015916348, textureId = 2015916361, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.8892, 0.298, 2.8203 }, offsetM = { -0.001, 0.2733, 0.4066 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_25", meshId = 2011715163, color = Color3.fromRGB(35, 35, 35), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.605, 0.9209, 0.7809 }, offsetM = { 0.4329, 0.7128, -0.3136 }, rotationDeg = { 0, 180, 0 } },
				{ name = "TailLamps_4", meshId = 2015869806, color = Color3.fromRGB(117, 0, 0), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.667, 0.2028, 0.6161 }, offsetM = { -0.001, 0.8724, 2.0854 }, rotationDeg = { 0, 180, 0 } },
				{ name = "TailLamps_5", meshId = 2015924122, color = Color3.fromRGB(255, 0, 0), material = Enum.Material.SmoothPlastic, transparency = 0.8, castShadow = false, sizeM = { 1.6671, 0.2224, 4.5754 }, offsetM = { -0.001, 0.856, 0.1057 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_11", meshId = 2015915535, paint = true, sizeM = { 1.8992, 0.5318, 0.7454 }, offsetM = { -0.001, 0.4872, -2.0539 }, rotationDeg = { 0, 180, 0 } },
				{ name = "HeadLamps", meshId = 2015919032, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, transparency = 0.8, castShadow = false, sizeM = { 1.7408, 0.2124, 0.6 }, offsetM = { -0.001, 0.7286, -1.9564 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_26", meshId = 2015795361, textureId = 2015795377, color = Color3.fromRGB(86, 66, 54), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.7502, 0.6922, 0.953 }, offsetM = { -0.3226, 0.5573, -0.5655 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_12", meshId = 2015905928, paint = true, sizeM = { 1.2886, 0.4607, 0.6545 }, offsetM = { -0.001, 0.889, 2.1237 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_27", meshId = 2015790643, textureId = 2015790671, color = Color3.fromRGB(99, 95, 98), material = Enum.Material.Plastic, castShadow = false, sizeM = { 1.4865, 0.2319, 0.2002 }, offsetM = { 0.0036, 0.8065, -0.6613 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_7", meshId = 2015815927, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.5838, 0.0453, 0.0214 }, offsetM = { -0.001, 0.4102, -2.0328 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_28", meshId = 2015787576, textureId = 2015787593, color = Color3.fromRGB(205, 205, 205), material = Enum.Material.Plastic, castShadow = false, sizeM = { 1.5263, 0.6871, 1.4421 }, offsetM = { 0.0047, 0.6756, -0.4414 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_8", meshId = 2015830009, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.6986, 0.6355, 2.3654 }, offsetM = { -0.001, 0.6948, -0.9251 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Chrome_9", meshId = 2015821687, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.6596, 0.1904, 0.5333 }, offsetM = { -0.001, 0.8698, 2.124 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_29", meshId = 2015797621, textureId = 2015797766, color = Color3.fromRGB(33, 84, 185), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.7808, 0.3557, 0.3405 }, offsetM = { -0.2204, 0.7256, -0.4955 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_30", meshId = 2011828037, color = Color3.fromRGB(35, 35, 35), material = Enum.Material.Plastic, castShadow = false, sizeM = { 0.3692, 0.1957, 0.3232 }, offsetM = { 0.0088, 0.7717, -0.6905 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_31", meshId = 2015789093, textureId = 2015789110, color = Color3.fromRGB(99, 95, 98), material = Enum.Material.Plastic, castShadow = false, sizeM = { 1.5133, 0.4615, 1.4169 }, offsetM = { 0.0005, 0.5477, -0.4372 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Body_13", meshId = 2015912199, paint = true, sizeM = { 1.5548, 0.2453, 1.2686 }, offsetM = { -0.001, 0.8731, -1.6714 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Interior_32", meshId = 2015809391, textureId = 2015809416, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.3665, 0.1379, 0.7627 }, offsetM = { 0.0011, 0.8574, -1.7122 }, rotationDeg = { 0, 180, 0 } },
				{ name = "Trim_10", meshId = 2015897552, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 1.7427, 0.2228, 0.6081 }, offsetM = { -0.001, 0.7291, -1.9536 }, rotationDeg = { 0, 180, 0 } },
			},
			wheelPieces = {
				{ name = "Tyre", meshId = 2015927178, color = Color3.fromRGB(16, 16, 16), material = Enum.Material.SmoothPlastic, sizeM = { 0.2376, 0.6752, 0.6789 }, offsetM = { 0, 0, 0 }, rotationDeg = { 0, 0, 0 } },
				{ name = "Rim", meshId = 2015929412, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.2301, 0.5197, 0.5197 }, offsetM = { -0.01, 0.0012, 0.0001 }, rotationDeg = { 0, 0, 0 } },
			},
		},
		tuning = {
			-- Front-wheel drive, as the real car and its A-Chassis tune.
			drivetrain = { layout = "FWD" },
			effects = {
				-- The store model's own horn and startup.
				horn = { soundId = "rbxassetid://279713934" },
				-- Its A-Chassis stock "Rev" loop, one file for every layer. The
				-- plugin plays it at pitch 0.05 + rpm / 7000 (its redline), which
				-- is 1 at 6650 rpm: that is refRpm.
				engineAudio = {
					startSoundId = "rbxassetid://2016068496",
					layers = {
						idle = { soundId = "rbxassetid://1235897119", refRpm = 6650, volume = 0.5, eq = { 0, 0, -6 } },
						lowLoad = { soundId = "rbxassetid://1235897119", refRpm = 6650, volume = 0.8, eq = { 3, 0, -3 } },
						highLoad = { soundId = "rbxassetid://1235897119", refRpm = 6650, volume = 1, eq = { 0, 2, 2 } },
						overrun = { soundId = "rbxassetid://1235897119", refRpm = 6650, volume = 0.5, eq = { 0, -2, -8 } },
					},
				},
			},
		},
	},
	-- THE KAMRI SE. An early-2010s Japanese family saloon in sport trim from
	-- the Creator Store (asset 17767054086, an A-Chassis car), brought to the
	-- store-car standard (tools/carbody/README.md) by storecar.py kamri12:
	-- store meshes by id, interior kept, 76,722 triangles of the store
	-- model's 88,425. Dropped: one part that is nothing but badges (the
	-- maker's emblem front and back, the model name, the trim badge), the
	-- shark-fin aerial (5,081 triangles), the horns behind the bumper and the
	-- invisible kit parts; the emblem's backing split out of the grille
	-- and painted to fill the hole it left (generated Trim_4, Body_7); the
	-- tail and fog lamps split out of the textured trim (generated Trim_3,
	-- TailLamps, FogLamps); the airbag's emblem
	-- painted out (generated SteeringWheel), the steering wheel a piece of its
	-- own for the first-person view; the tyres' lettered texture left off.
	-- Its own wheels and horn; no engine loop in its kit, so the shared one.
	--
	-- Placed at 0.2866 m a model stud, so its wheel centres sit on the real
	-- 2.775 m wheelbase: 4.95 m long, 0.71 m tyres.
	kamri12 = {
		displayName = "Kamri SE",
		blurb = "The newer Kamri in sport trim. Sharp lines, quick hands.",
		order = 13,
		scale = 1.2,
		rig = {
			massKg = 1550,
			-- Nose at -2.40 m, tail at +2.56 m.
			collisionSizeM = { 1.8, 1.15, 4.6 },
			centerOfMassM = { 0, -0.3, -0.15 },
			shellMassFraction = 0.35,
			wheelbaseM = 2.775,
			trackWidthM = 1.733,
			wheelRadiusM = 0.3541,
			wheelWidthM = 0.2724,
			-- The store model's driver seat (0.40 m left of centre), 0.28 m off
			-- the ground so a seated head clears the 1.53 m roof.
			seatM = { -0.4, -0.65, -0.03 },
		},
		body = {
			paint = Color3.fromRGB(240, 240, 236),
			pieces = {
				{ name = "Trim", meshId = 8572225332, color = Color3.fromRGB(255, 0, 0), material = Enum.Material.Neon, sizeM = { 0.2133, 0.0229, 0.003 }, offsetM = { -0.0178, 1.1018, 1.8537 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Interior", meshId = 8399529986, color = Color3.fromRGB(47, 47, 47), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.3107, 0.087, 0.0694 }, offsetM = { -0.037, 1.2855, -0.4699 }, rotationDeg = { -3.434, 175.992, -0.939 } },
				{ name = "Interior_2", meshId = 8572225027, textureId = 8572225078, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.1726, 0.0841, 0.0582 }, offsetM = { -0.0171, 0.8783, -0.6493 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Body", meshId = 8572219729, paint = true, sizeM = { 1.9115, 0.1067, 1.3745 }, offsetM = { -0.0014, 0.9039, 0.63 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Body_2", meshId = 8572220072, paint = true, sizeM = { 1.3766, 0.0607, 0.1677 }, offsetM = { -0.0118, 1.0532, 2.3766 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Interior_3", meshId = 8572222178, textureId = 8572222260, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.1962, 0.568, 0.7261 }, offsetM = { -0.0179, 0.754, 0.0539 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Trim_2", meshId = 8572218846, color = Color3.fromRGB(43, 43, 43), material = Enum.Material.SmoothPlastic, sizeM = { 1.769, 1.2002, 4.7109 }, offsetM = { -0.0004, 0.8466, 0.0563 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Glass", meshId = 8572221413, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.5, castShadow = false, sizeM = { 1.6907, 0.4525, 1.772 }, offsetM = { -0.0109, 1.2158, 1.1548 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Body_3", meshId = 8572221196, paint = true, sizeM = { 2.0467, 0.6189, 0.9709 }, offsetM = { -0.0079, 0.5395, 2.0659 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Trim_3", meshId = 138093391095760, mesh = "Kamri12/Trim_3", textureId = 8572219089, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.7349, 0.6838, 4.4889 }, offsetM = { -0.0116, 0.6897, 0.1736 } },
				{ name = "TailLamps", meshId = 136791842063599, mesh = "Kamri12/TailLamps", textureId = 8572219089, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.653, 0.2181, 0.2013 }, offsetM = { -0.0122, 0.9195, 2.3461 } },
				{ name = "FogLamps", meshId = 95173905383077, mesh = "Kamri12/FogLamps", textureId = 8572219089, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.6161, 0.1565, 0.0707 }, offsetM = { 0.0175, 0.3654, -2.116 } },
				{ name = "Interior_4", meshId = 8572221775, color = Color3.fromRGB(159, 161, 172), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.9918, 0.0329, 0.0176 }, offsetM = { -0.0226, 1.0499, 0.3903 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Interior_5", meshId = 8572224903, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.7233, 0.8929, 2.1741 }, offsetM = { 0.0464, 0.9083, 0.2601 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Body_4", meshId = 8572220981, paint = true, sizeM = { 2.2434, 1.308, 4.7349 }, offsetM = { -0.004, 0.8483, 0.0946 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Interior_6", meshId = 8572222354, textureId = 8572222472, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.1838, 0.8033, 0.9366 }, offsetM = { -0.0184, 0.675, 0.9962 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Interior_7", meshId = 8572221625, color = Color3.fromRGB(62, 62, 62), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.3846, 0.8538, 0.7655 }, offsetM = { -0.0194, 0.8714, 0.079 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Interior_8", meshId = 8572223076, textureId = 8572223236, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.3948, 0.1507, 0.0244 }, offsetM = { -0.3987, 0.9335, -0.7714 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Body_5", meshId = 8572219952, paint = true, sizeM = { 0.7987, 0.1184, 0.0647 }, offsetM = { -0.01, 0.9349, 2.4128 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Body_6", meshId = 8572218189, paint = true, sizeM = { 1.9705, 0.6257, 0.7147 }, offsetM = { 0.012, 0.4884, -2.0312 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Interior_9", meshId = 8572222010, color = Color3.fromRGB(43, 43, 43), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.4305, 1.0212, 1.8021 }, offsetM = { -0.0175, 0.7853, 0.6131 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Trim_4", meshId = 76899469257086, mesh = "Kamri12/Trim_4", color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 2.2433, 1.3567, 4.8588 }, offsetM = { 0.0017, 0.8097, 0.0721 } },
				{ name = "Body_7", meshId = 102079551625526, mesh = "Kamri12/Body_7", paint = true, sizeM = { 0.1524, 0.096, 0.0249 }, offsetM = { 0.0144, 0.7159, -2.3048 } },
				{ name = "Interior_10", meshId = 8572223657, textureId = 8572223771, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, transparency = 0.1, castShadow = false, sizeM = { 1.5209, 1.0518, 0.6382 }, offsetM = { -0.0216, 0.8288, -0.4893 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Interior_11", meshId = 8572222861, color = Color3.fromRGB(43, 43, 43), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.7777, 1.1293, 2.5618 }, offsetM = { -0.0178, 0.8341, 0.1153 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "HeadLamps", meshId = 8572220221, textureId = 8572220331, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.7817, 0.1951, 0.4836 }, offsetM = { 0.0105, 0.7641, -2.0067 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Interior_12", meshId = 8572224103, textureId = 8572224160, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.1245, 0.2388, 0.2176 }, offsetM = { -0.0172, 0.9034, -0.6991 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Trim_5", meshId = 8572219397, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 2.2287, 0.1496, 0.0798 }, offsetM = { -0.0006, 1.0612, -0.6875 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Interior_13", meshId = 8572223891, textureId = 8572223989, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.306, 0.018, 0.0171 }, offsetM = { -0.018, 0.9368, -0.669 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Glass_2", meshId = 8572219269, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.7, castShadow = false, sizeM = { 1.7385, 0.5447, 1.575 }, offsetM = { -0.0045, 1.2253, -0.4153 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Interior_14", meshId = 8572222595, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.7742, 0.8139, 2.6806 }, offsetM = { -0.0166, 0.7466, 0.183 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Interior_15", meshId = 8572224302, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.4518, 0.4462, 0.8763 }, offsetM = { -0.016, 0.7878, -0.7778 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Interior_16", meshId = 8572224682, color = Color3.fromRGB(56, 56, 56), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.68, 0.5783, 2.5824 }, offsetM = { -0.0176, 0.7653, 0.0918 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Interior_17", meshId = 8572223482, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.7101, 1.2817, 3.1513 }, offsetM = { -0.0136, 0.8285, 0.4456 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Interior_18", meshId = 8572225443, color = Color3.fromRGB(255, 0, 0), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.5079, 0.4683, 1.4343 }, offsetM = { -0.0174, 0.6776, 0.2291 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "TailLamps_2", meshId = 8572225332, color = Color3.fromRGB(255, 0, 0), material = Enum.Material.Neon, castShadow = false, sizeM = { 0.2133, 0.0229, 0.003 }, offsetM = { -0.0178, 1.1018, 1.8537 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Interior_19", meshId = 8572225173, color = Color3.fromRGB(43, 43, 43), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.5796, 0.4017, 2.0999 }, offsetM = { -0.0105, 0.4314, -0.0252 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Interior_20", meshId = 8399529817, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.3012, 0.068, 0.0521 }, offsetM = { -0.0371, 1.2906, -0.4653 }, rotationDeg = { -3.434, 175.992, -0.939 } },
				{ name = "HeadLamps_2", meshId = 8572220833, color = Color3.fromRGB(253, 234, 141), material = Enum.Material.Neon, castShadow = false, sizeM = { 1.3001, 0.1243, 0.1312 }, offsetM = { 0.0112, 0.755, -2.1442 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "SteeringWheel", meshId = 137403950827118, mesh = "Kamri12/SteeringWheel", textureId = 8572224488, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.432, 0.3728, 0.2594 }, offsetM = { -0.4124, 0.9075, -0.5253 } },
			},
			wheelPieces = {
				{ name = "Tyre", meshId = 630951440, color = Color3.fromRGB(28, 28, 30), material = Enum.Material.Rubber, sizeM = { 0.2724, 0.7082, 0.7082 }, offsetM = { 0, 0, 0 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Rim", meshId = 8906916466, color = Color3.fromRGB(223, 223, 222), material = Enum.Material.Metal, sizeM = { 0.0787, 0.5141, 0.5075 }, offsetM = { -0.0979, 0.0011, -0.0026 }, rotationDeg = { 0.294, -0.258, 0.959 } },
				{ name = "Rim_Hub", meshId = 2050987638, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.2232, 0.2232, 0.1299 }, offsetM = { 0.0043, -0.0025, -0.001 }, rotationDeg = { -0.959, 89.737, 0.294 } },
				{ name = "Rim_Disc", meshId = 2050978857, color = Color3.fromRGB(159, 161, 172), material = Enum.Material.SmoothPlastic, sizeM = { 0.3743, 0.3743, 0.0358 }, offsetM = { 0.0042, -0.0025, -0.0012 }, rotationDeg = { 0.959, -90.263, -0.294 } },
			},
		},
		tuning = {
			-- Front-wheel drive, as the real car (its A-Chassis tune says AWD).
			drivetrain = { layout = "FWD" },
			effects = {
				-- The store model's own horn. It has no engine loop: the shared one.
				horn = { soundId = "rbxassetid://6397057263" },
			},
		},
	},
	-- THE KRUZER 300. A 2020s Japanese full-size 4x4 from the Creator Store
	-- (asset 116150803764919, an A-Chassis car), brought to the store-car
	-- standard (tools/carbody/README.md) by storecar.py kruzer300: store
	-- meshes by id, interior kept, 88,763 triangles of the store model's
	-- 95,805. Every badge is a part of its own and dropped: the maker's
	-- emblem on the grille, the tailgate, the airbag and the wheel centres,
	-- the model name across the tailgate and the trim badge; the tyres'
	-- lettered texture left off; the gauge display and the invisible kit
	-- parts dropped. The black oval the grille emblem sat on is split out of
	-- the grille plastic and painted (generated Trim_19, Body_12) so no hole
	-- is left. The steering wheel's parts are SteeringWheel pieces for
	-- the first-person view. Its own lamps, wheels, horn, startup and engine
	-- loop.
	--
	-- Placed at 0.2298 m a model stud, so its wheel centres sit on the real
	-- 2.85 m wheelbase: 5.00 m long, 1.69 m track, 0.79 m tyres.
	kruzer300 = {
		displayName = "Kruzer 300",
		blurb = "The new king of the dunes. Big, modern and smooth at any angle.",
		order = 14,
		scale = 1.2,
		rig = {
			massKg = 2500,
			-- Nose at -2.37 m, tail at +2.63 m.
			collisionSizeM = { 1.95, 1.3, 4.8 },
			centerOfMassM = { 0, -0.2, -0.1 },
			shellMassFraction = 0.55,
			wheelbaseM = 2.85,
			trackWidthM = 1.6867,
			wheelRadiusM = 0.3932,
			wheelWidthM = 0.2344,
			-- The store model's driver seat (0.42 m left of centre), 0.6 m off
			-- the ground so a seated head clears the 1.90 m roof.
			seatM = { -0.42, -0.45, 0.02 },
		},
		body = {
			paint = Color3.fromRGB(240, 240, 236),
			pieces = {
				{ name = "Glass", meshId = 12287728972, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.7, castShadow = false, sizeM = { 0.1495, 0.4949, 0.8736 }, offsetM = { -0.7492, 1.4969, -0.1256 } },
				{ name = "Chrome", meshId = 12287796867, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.0213, 0.0234, 0.0193 }, offsetM = { -0.6947, 1.139, -0.4262 } },
				{ name = "Chrome_2", meshId = 12287772715, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.1732, 0.5114, 1.1044 }, offsetM = { -0.7515, 1.4964, -0.1846 } },
				{ name = "Interior", meshId = 12287755636, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.3044, 0.6079, 1.0663 }, offsetM = { -0.8205, 1.4337, -0.1655 } },
				{ name = "Interior_2", meshId = 12287775482, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.1946, 1.2693, 1.1064 }, offsetM = { -0.7547, 1.12, -0.1854 } },
				{ name = "Interior_3", meshId = 12287791925, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0602, 0.2861, 0.2427 }, offsetM = { -0.7081, 0.6577, -0.5423 } },
				{ name = "Interior_4", meshId = 12287785085, textureId = 12287785676, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.0867, 0.0682, 0.2045 }, offsetM = { -0.7059, 0.9647, -0.2397 } },
				{ name = "Interior_5", meshId = 12287780909, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.1902, 0.6799, 0.8299 }, offsetM = { -0.7726, 0.8538, -0.2497 } },
				{ name = "Interior_6", meshId = 12287780336, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.1788, 0.5001, 0.8511 }, offsetM = { -0.7431, 1.0514, -0.2404 } },
				{ name = "Interior_7", meshId = 12287778417, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0926, 0.1865, 0.245 }, offsetM = { -0.7056, 1.0885, -0.3217 } },
				{ name = "Interior_8", meshId = 12287786838, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0477, 0.1321, 0.0729 }, offsetM = { -0.7089, 1.0879, -0.3989 } },
				{ name = "Interior_9", meshId = 12287790410, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0689, 0.1543, 0.09 }, offsetM = { -0.7077, 1.0882, -0.3971 } },
				{ name = "Interior_10", meshId = 12287786471, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.1761, 0.3324, 0.3688 }, offsetM = { -0.7345, 1.0616, -0.4803 } },
				{ name = "Interior_11", meshId = 12287797202, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0208, 0.0181, 0.011 }, offsetM = { -0.6945, 1.1418, -0.4216 } },
				{ name = "Body", meshId = 12287767448, paint = true, sizeM = { 0.1941, 0.8721, 1.104 }, offsetM = { -0.8839, 0.8859, -0.2547 } },
				{ name = "Glass_2", meshId = 12287760106, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.5, castShadow = false, sizeM = { 0.0264, 0.018, 0.1063 }, offsetM = { -1.0858, 1.3602, -0.4073 } },
				{ name = "Chrome_3", meshId = 12287733364, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.0253, 0.018, 0.1027 }, offsetM = { -1.0839, 1.3604, -0.4075 } },
				{ name = "Chrome_4", meshId = 12287756033, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.2089, 0.1837, 0.2282 }, offsetM = { -0.9956, 1.3325, -0.4638 } },
				{ name = "Chrome_5", meshId = 12287754195, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.2098, 0.1447, 0.2295 }, offsetM = { -0.9977, 1.3559, -0.4666 } },
				{ name = "Chrome_6", meshId = 12287733958, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.1759, 0.1542, 0.0825 }, offsetM = { -0.9984, 1.3336, -0.4085 } },
				{ name = "Glass_3", meshId = 12287758550, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.7, castShadow = false, sizeM = { 0.1495, 0.4949, 0.8736 }, offsetM = { 0.7557, 1.4969, -0.1256 } },
				{ name = "Interior_12", meshId = 12287792484, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0601, 0.2861, 0.2426 }, offsetM = { 0.7147, 0.6577, -0.5424 } },
				{ name = "Interior_13", meshId = 12287779220, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.1861, 0.5005, 0.8511 }, offsetM = { 0.746, 1.0512, -0.2404 } },
				{ name = "Interior_14", meshId = 12287782892, textureId = 12287783326, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.0867, 0.0682, 0.2045 }, offsetM = { 0.7124, 0.9647, -0.2397 } },
				{ name = "Interior_15", meshId = 12287789535, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0238, 0.0282, 0.0344 }, offsetM = { 0.7142, 1.0962, -0.4143 } },
				{ name = "Interior_16", meshId = 12287790726, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.071, 0.1543, 0.09 }, offsetM = { 0.7132, 1.0882, -0.3972 } },
				{ name = "Interior_17", meshId = 12287778823, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0926, 0.1868, 0.2449 }, offsetM = { 0.7122, 1.0887, -0.3216 } },
				{ name = "Interior_18", meshId = 12287786050, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.0915, 0.2154, 0.2393 }, offsetM = { 0.6999, 1.1199, -0.4739 } },
				{ name = "Interior_19", meshId = 12287780595, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.1898, 0.68, 0.8306 }, offsetM = { 0.7793, 0.8538, -0.2493 } },
				{ name = "Body_2", meshId = 12287767196, paint = true, sizeM = { 0.1941, 0.872, 1.1041 }, offsetM = { 0.8904, 0.8858, -0.2547 } },
				{ name = "Chrome_7", meshId = 12287773894, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.1732, 0.5114, 1.1043 }, offsetM = { 0.758, 1.4964, -0.1844 } },
				{ name = "Interior_20", meshId = 12287775823, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.1946, 1.2694, 1.1061 }, offsetM = { 0.7612, 1.12, -0.1853 } },
				{ name = "Interior_21", meshId = 12287755329, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.3044, 0.608, 1.0667 }, offsetM = { 0.827, 1.4337, -0.1657 } },
				{ name = "Glass_4", meshId = 12287760388, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.5, castShadow = false, sizeM = { 0.0264, 0.0186, 0.1072 }, offsetM = { 1.0923, 1.36, -0.4078 } },
				{ name = "Chrome_8", meshId = 12287766554, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.0253, 0.0181, 0.1027 }, offsetM = { 1.0905, 1.3605, -0.4076 } },
				{ name = "Chrome_9", meshId = 12287754619, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.2099, 0.1447, 0.2301 }, offsetM = { 1.0043, 1.3559, -0.4669 } },
				{ name = "Chrome_10", meshId = 12287772425, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.1759, 0.1542, 0.0825 }, offsetM = { 1.0049, 1.3336, -0.4085 } },
				{ name = "Chrome_11", meshId = 12287755026, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.209, 0.1838, 0.2283 }, offsetM = { 1.0021, 1.3325, -0.4638 } },
				{ name = "Chrome_12", meshId = 12287773049, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.1861, 0.5052, 0.9985 }, offsetM = { -0.7445, 1.5078, 0.7965 } },
				{ name = "Interior_22", meshId = 12287762311, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.2002, 0.4751, 0.9999 }, offsetM = { -0.7336, 1.5084, 0.8022 } },
				{ name = "Interior_23", meshId = 12287792863, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0583, 0.6569, 0.1845 }, offsetM = { -0.7227, 0.842, 0.4893 } },
				{ name = "Interior_24", meshId = 12287788586, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0361, 0.023, 0.0311 }, offsetM = { -0.722, 0.9842, 0.4999 } },
				{ name = "Interior_25", meshId = 12287781170, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.1794, 0.681, 0.7564 }, offsetM = { -0.7782, 0.8532, 0.7743 } },
				{ name = "Interior_26", meshId = 12287779810, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.18, 0.4967, 0.8289 }, offsetM = { -0.7423, 1.0477, 0.8103 } },
				{ name = "Interior_27", meshId = 12287784413, textureId = 12287784793, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.1074, 0.0659, 0.3389 }, offsetM = { -0.719, 0.9635, 0.5782 } },
				{ name = "Interior_28", meshId = 12287791061, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0094, 0.0769, 0.1224 }, offsetM = { -0.7471, 1.1451, 0.4986 } },
				{ name = "Interior_29", meshId = 12287778159, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0138, 0.0942, 0.3048 }, offsetM = { -0.7455, 1.1462, 0.5803 } },
				{ name = "Body_3", meshId = 12287768067, paint = true, sizeM = { 0.1881, 0.8337, 1.0766 }, offsetM = { -0.8857, 0.8676, 0.8058 } },
				{ name = "Interior_30", meshId = 12287776527, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.2141, 1.2754, 0.9979 }, offsetM = { -0.7445, 1.124, 0.7963 } },
				{ name = "Glass_5", meshId = 12287757776, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.25, castShadow = false, sizeM = { 0.1631, 0.4888, 0.9203 }, offsetM = { -0.7424, 1.5088, 0.8096 } },
				{ name = "Glass_6", meshId = 12287758200, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.25, castShadow = false, sizeM = { 0.163, 0.4888, 0.9203 }, offsetM = { 0.7489, 1.5088, 0.8096 } },
				{ name = "Body_4", meshId = 12287767733, paint = true, sizeM = { 0.1881, 0.8338, 1.0758 }, offsetM = { 0.8923, 0.8675, 0.8063 } },
				{ name = "Chrome_13", meshId = 12287773619, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.1861, 0.5052, 0.9984 }, offsetM = { 0.751, 1.5078, 0.7965 } },
				{ name = "Interior_31", meshId = 12287762597, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.2002, 0.4751, 0.9999 }, offsetM = { 0.7401, 1.5084, 0.8022 } },
				{ name = "Interior_32", meshId = 12287776187, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.2141, 1.2754, 0.9979 }, offsetM = { 0.7511, 1.124, 0.7962 } },
				{ name = "Interior_33", meshId = 12287781477, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.1794, 0.681, 0.7562 }, offsetM = { 0.7847, 0.8532, 0.7742 } },
				{ name = "Interior_34", meshId = 12287779527, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.1799, 0.4966, 0.8289 }, offsetM = { 0.7489, 1.0478, 0.8103 } },
				{ name = "Interior_35", meshId = 12287783762, textureId = 12287784200, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.1074, 0.0659, 0.3389 }, offsetM = { 0.7255, 0.9635, 0.5782 } },
				{ name = "Interior_36", meshId = 12287787674, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0361, 0.023, 0.0311 }, offsetM = { 0.7285, 0.9842, 0.4999 } },
				{ name = "Interior_37", meshId = 12287777678, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0138, 0.0942, 0.3048 }, offsetM = { 0.752, 1.1462, 0.5803 } },
				{ name = "Interior_38", meshId = 12287792218, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0583, 0.6569, 0.1843 }, offsetM = { 0.7293, 0.842, 0.4893 } },
				{ name = "Interior_39", meshId = 12287791415, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0094, 0.0764, 0.1227 }, offsetM = { 0.7536, 1.1452, 0.4987 } },
				{ name = "Trim", meshId = 1827397195, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.758, 0.0792, 0.2498 }, offsetM = { 0.2813, 1.3237, -0.9389 }, rotationDeg = { -4.473, 6.737, -0.221 } },
				{ name = "Trim_2", meshId = 1827397914, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 0.7311, 0.0809, 0.0583 }, offsetM = { -0.2579, 1.319, -0.9255 }, rotationDeg = { -3.953, -0.84, -0.058 } },
				{ name = "Interior_40", meshId = 12287799196, textureId = 12287799899, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.0204, 0.5342, 0.1889 }, offsetM = { 0.0042, 1.1657, 2.0394 } },
				{ name = "Interior_41", meshId = 12287804462, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 1.0143, 0.5303, 0.2092 }, offsetM = { 0.0042, 1.1719, 1.9978 } },
				{ name = "Interior_42", meshId = 12287804065, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 1.0134, 0.7554, 0.2266 }, offsetM = { 0.0042, 1.2851, 2.0069 } },
				{ name = "Interior_43", meshId = 12287803691, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.658, 0.0279, 0.0151 }, offsetM = { 0.0042, 1.4511, 2.08 } },
				{ name = "Interior_44", meshId = 12287803282, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.675, 0.3185, 0.0474 }, offsetM = { 0.004, 1.3161, 2.0732 } },
				{ name = "SteeringWheel", meshId = 12287796519, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.4132, 0.379, 0.1957 }, offsetM = { -0.4242, 1.2253, -0.3077 } },
				{ name = "SteeringWheel_2", meshId = 12287794880, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.3287, 0.2078, 0.183 }, offsetM = { -0.4242, 1.1574, -0.3075 } },
				{ name = "SteeringWheel_3", meshId = 12287751931, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.3141, 0.0192, 0.0127 }, offsetM = { -0.4242, 1.2018, -0.2926 } },
				{ name = "SteeringWheel_4", meshId = 12287794494, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.3541, 0.0805, 0.0702 }, offsetM = { -0.4242, 1.2144, -0.3175 } },
				{ name = "SteeringWheel_5", meshId = 12287793594, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.3237, 0.0424, 0.0249 }, offsetM = { -0.4242, 1.2278, -0.3045 } },
				{ name = "SteeringWheel_6", meshId = 12287795565, textureId = 12287796053, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.3752, 0.1432, 0.0659 }, offsetM = { -0.4244, 1.1476, -0.259 } },
				{ name = "SteeringWheel_7", meshId = 12287752868, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.1838, 0.1529, 0.1188 }, offsetM = { -0.4242, 1.2039, -0.3092 } },
				{ name = "FogLamps", meshId = 2543761421, color = Color3.fromRGB(91, 93, 105), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0002, 0.0206, 0.0002 }, offsetM = { 0.0032, 0.8367, 2.4701 } },
				{ name = "TailLamps", meshId = 12287769729, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.3199, 0.0246, 0.0189 }, offsetM = { 0.0061, 1.7267, 2.3161 } },
				{ name = "ReverseLamps", meshId = 12287770396, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.4541, 0.0223, 0.082 }, offsetM = { 0.0032, 1.0839, 2.4836 } },
				{ name = "TailLamps_2", meshId = 12287769413, color = Color3.fromRGB(151, 0, 0), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.4519, 0.0837, 0.0813 }, offsetM = { 0.0033, 1.1776, 2.5086 } },
				{ name = "Indicators", meshId = 12287770683, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.2263, 0.0222, 0.083 }, offsetM = { 0.6171, 1.1096, 2.4886 } },
				{ name = "Indicators_2", meshId = 12287771007, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.2264, 0.022, 0.0828 }, offsetM = { -0.6106, 1.1096, 2.4887 } },
				{ name = "Trim_3", meshId = 12287768776, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 1.4071, 0.046, 0.0513 }, offsetM = { 0.0033, 1.2008, 2.4857 } },
				{ name = "Trim_4", meshId = 12287763277, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, sizeM = { 0.1525, 0.0405, 0.0269 }, offsetM = { -0.0324, 1.0448, 2.5234 } },
				{ name = "Trim_5", meshId = 12287763606, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, sizeM = { 1.4666, 0.2005, 0.1476 }, offsetM = { 0.0032, 1.1568, 2.469 } },
				{ name = "Trim_6", meshId = 12287761739, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.452, 0.1076, 0.1303 }, offsetM = { 0.0033, 1.1778, 2.4851 } },
				{ name = "TailLamps_3", meshId = 12287760761, color = Color3.fromRGB(117, 0, 0), material = Enum.Material.SmoothPlastic, transparency = 0.5, castShadow = false, sizeM = { 1.4605, 0.1401, 0.134 }, offsetM = { -0.0029, 1.1898, 2.4887 } },
				{ name = "Glass_7", meshId = 12287760977, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.5, castShadow = false, sizeM = { 1.4627, 0.0697, 0.1151 }, offsetM = { -0.0029, 1.0861, 2.4917 } },
				{ name = "Trim_7", meshId = 12287763869, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, sizeM = { 0.2502, 0.0503, 0.0736 }, offsetM = { 0.1015, 1.3535, 2.4689 } },
				{ name = "Glass_8", meshId = 12287756647, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.25, castShadow = false, sizeM = { 1.4037, 0.4, 0.1915 }, offsetM = { 0.0033, 1.5134, 2.38 } },
				{ name = "Trim_8", meshId = 12287764830, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, sizeM = { 1.4023, 0.4269, 0.2325 }, offsetM = { 0.0033, 1.5294, 2.3926 } },
				{ name = "Body_5", meshId = 12287764404, paint = true, sizeM = { 1.4661, 1.137, 0.4383 }, offsetM = { 0.0034, 1.2474, 2.3355 } },
				{ name = "Trim_9", meshId = 12287777136, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, sizeM = { 1.3132, 0.9635, 0.2467 }, offsetM = { 0.0033, 1.2286, 2.3599 } },
				{ name = "Trim_10", meshId = 12287776796, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, sizeM = { 1.377, 1.0067, 0.2504 }, offsetM = { 0.0033, 1.2158, 2.3489 } },
				{ name = "Glass_9", meshId = 12287757439, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.5, castShadow = false, sizeM = { 0.3191, 0.0218, 0.0102 }, offsetM = { 0.0059, 1.7251, 2.3345 } },
				{ name = "Chrome_14", meshId = 12287747343, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.7754, 0.9493, 2.4384 }, offsetM = { 0.0042, 0.9855, 0.8939 } },
				{ name = "Chrome_15", meshId = 12287727337, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.6819, 1.2911, 4.9779 }, offsetM = { 0.0041, 1.115, 0.1314 } },
				{ name = "Trim_11", meshId = 12287774154, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.1501, 0.3557, 0.186 }, offsetM = { 0.0042, 0.9166, -2.2619 } },
				{ name = "Chrome_16", meshId = 12287765603, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.8771, 0.1072, 0.313 }, offsetM = { 0.0041, 0.5188, -2.2128 } },
				{ name = "Chrome_17", meshId = 12287772085, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.217, 0.054, 0.0011 }, offsetM = { 0.0042, 1.6429, -0.3571 } },
				{ name = "Glass_10", meshId = 12287729381, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.7, castShadow = false, sizeM = { 1.6055, 0.4715, 0.6783 }, offsetM = { 0.0042, 1.5217, -0.6357 } },
				{ name = "Glass_11", meshId = 12287757038, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.25, castShadow = false, sizeM = { 1.0081, 0.0389, 0.5523 }, offsetM = { 0.0042, 1.8276, 0.117 } },
				{ name = "Glass_12", meshId = 12287756330, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.25, castShadow = false, sizeM = { 1.647, 0.4663, 0.6458 }, offsetM = { 0.0042, 1.5199, 1.5563 } },
				{ name = "Interior_45", meshId = 12287751628, color = Color3.fromRGB(151, 0, 0), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.7894, 0.4746, 2.4544 }, offsetM = { -0.1554, 1.0244, 0.6365 } },
				{ name = "Interior_46", meshId = 12287736828, textureId = 12287737578, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 1.5689, 0.1868, 1.8083 }, offsetM = { 0.0042, 0.9985, 0.6132 } },
				{ name = "Interior_47", meshId = 12287750205, textureId = 12287750365, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.5338, 0.9888, 1.9174 }, offsetM = { 0.0043, 1.1024, 1.1567 } },
				{ name = "Interior_48", meshId = 12287798001, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.0884, 0.1535, 0.1635 }, offsetM = { -0.0059, 1.0441, -0.2464 } },
				{ name = "Interior_49", meshId = 12287732788, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 1.5253, 0.9691, 3.3074 }, offsetM = { 0.0042, 0.8845, 0.7757 } },
				{ name = "Interior_50", meshId = 12287749914, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 0.3916, 0.274, 0.2081 }, offsetM = { -0.4598, 0.5903, -0.8338 } },
				{ name = "Interior_51", meshId = 12287750659, color = Color3.fromRGB(44, 44, 44), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.1153, 0.2821, 1.1519 }, offsetM = { -0.0041, 1.3454, -0.03 } },
				{ name = "Interior_52", meshId = 12287738298, color = Color3.fromRGB(48, 48, 48), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.7989, 0.9315, 1.1462 }, offsetM = { -0.2322, 1.2741, -0.0299 } },
				{ name = "Interior_53", meshId = 12287748895, textureId = 12287749472, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 1.3722, 0.1898, 2.6669 }, offsetM = { 0.0042, 1.7251, 0.9177 } },
				{ name = "Interior_54", meshId = 12287724403, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 1.3158, 0.7158, 2.2224 }, offsetM = { 0.0041, 1.0431, 0.8209 } },
				{ name = "Interior_55", meshId = 12287908579, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 1.6736, 1.423, 3.5927 }, offsetM = { 0.0042, 1.1321, 0.6743 } },
				{ name = "Interior_56", meshId = 12287747967, textureId = 12287748592, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 1.6589, 0.9338, 3.4421 }, offsetM = { 0.0042, 0.9001, 0.6272 } },
				{ name = "Interior_57", meshId = 12287734793, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, castShadow = false, sizeM = { 1.6879, 1.1746, 3.5142 }, offsetM = { 0.0042, 1.1185, 0.661 } },
				{ name = "Trim_12", meshId = 12287743482, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, sizeM = { 1.5776, 1.2322, 1.5117 }, offsetM = { 0.0042, 1.1238, -0.0045 } },
				{ name = "Chrome_18", meshId = 12287798685, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.0628, 0.0537, 0.0623 }, offsetM = { -0.0026, 1.0894, -0.2691 } },
				{ name = "Chrome_19", meshId = 12287736051, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.6209, 1.2382, 1.3794 }, offsetM = { 0.0042, 1.1262, 0.0815 } },
				{ name = "Glass_13", meshId = 12287731703, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.5, castShadow = false, sizeM = { 1.8895, 0.1885, 0.496 }, offsetM = { 0.004, 1.0169, -2.0032 } },
				{ name = "Glass_14", meshId = 12287761222, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.5, castShadow = false, sizeM = { 1.7838, 0.0685, 0.3016 }, offsetM = { 0.0042, 1.0862, 2.3205 } },
				{ name = "TailLamps_4", meshId = 12287746640, color = Color3.fromRGB(117, 0, 0), material = Enum.Material.SmoothPlastic, transparency = 0.5, castShadow = false, sizeM = { 1.7837, 0.7017, 0.3879 }, offsetM = { 0.004, 0.9082, 2.3542 } },
				{ name = "Glass_15", meshId = 12287729844, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.SmoothPlastic, transparency = 0.5, castShadow = false, sizeM = { 1.8001, 0.5691, 0.0715 }, offsetM = { 0.0042, 0.7811, -2.1075 } },
				{ name = "Trim_13", meshId = 12287761491, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.774, 0.2294, 4.6895 }, offsetM = { 0.0043, 1.1118, 0.1207 } },
				{ name = "Trim_14", meshId = 12287764116, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, sizeM = { 1.7806, 0.1989, 0.3635 }, offsetM = { 0.0038, 1.1568, 2.2887 } },
				{ name = "Trim_15", meshId = 12287762882, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, sizeM = { 1.8837, 0.1816, 0.4747 }, offsetM = { 0.0042, 1.0175, -2.0079 } },
				{ name = "Chrome_20", meshId = 12287735497, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.4539, 0.4365, 0.6274 }, offsetM = { 0.0041, 1.5189, -0.4834 } },
				{ name = "Trim_16", meshId = 12287766856, color = Color3.fromRGB(117, 0, 0), material = Enum.Material.SmoothPlastic, sizeM = { 1.6428, 0.0355, 0.1502 }, offsetM = { 0.0036, 0.5753, 2.4626 } },
				{ name = "Chrome_21", meshId = 12287770032, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 1.6817, 0.022, 0.1333 }, offsetM = { 0.0042, 1.0839, 2.3807 } },
				{ name = "Body_6", meshId = 12287771745, paint = true, sizeM = { 0.0884, 0.0722, 0.1586 }, offsetM = { 0.0041, 1.86, 1.9592 } },
				{ name = "Body_7", meshId = 12287725141, paint = true, sizeM = { 1.9512, 1.4652, 3.4141 }, offsetM = { 0.0042, 1.1281, 0.7851 } },
				{ name = "Body_8", meshId = 12287758907, paint = true, sizeM = { 1.9615, 1.0489, 3.2355 }, offsetM = { 0.0042, 0.8017, -0.6461 } },
				{ name = "Body_9", meshId = 12287759216, paint = true, sizeM = { 1.9663, 0.5186, 3.9078 }, offsetM = { 0.0042, 0.7298, 0.0034 } },
				{ name = "Body_10", meshId = 12287759488, paint = true, sizeM = { 1.9562, 0.7597, 0.896 }, offsetM = { 0.0042, 0.6894, 2.1806 } },
				{ name = "Body_11", meshId = 12287759783, paint = true, sizeM = { 1.9576, 0.7503, 0.6623 }, offsetM = { 0.0042, 0.7086, -2.0415 } },
				{ name = "Trim_17", meshId = 12287765233, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, sizeM = { 1.9518, 0.4346, 3.4116 }, offsetM = { 0.0042, 0.5534, 0.9146 } },
				{ name = "Trim_18", meshId = 12287732330, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, sizeM = { 1.9075, 0.6578, 4.6424 }, offsetM = { 0.0042, 0.6033, 0.2487 } },
				{ name = "Trim_19", meshId = 102510695155717, mesh = "Kruzer300/Trim_19", textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, sizeM = { 1.8873, 0.6411, 4.917 }, offsetM = { 0.0042, 0.8081, 0.1036 } },
				{ name = "Body_12", meshId = 120003196441346, mesh = "Kruzer300/Body_12", paint = true, sizeM = { 0.1837, 0.1345, 0.0415 }, offsetM = { 0.0042, 0.9779, -2.3402 } },
				{ name = "Trim_20", meshId = 12287762031, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, sizeM = { 1.3258, 0.0971, 1.9137 }, offsetM = { 0.0042, 1.8459, 1.0552 } },
				{ name = "Trim_21", meshId = 12296109832, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, sizeM = { 1.9402, 0.2656, 2.9234 }, offsetM = { 0.0041, 0.343, 0.4773 } },
				{ name = "Trim_22", meshId = 12296149679, textureId = 10135996345, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Asphalt, sizeM = { 1.6648, 0.6299, 3.2616 }, offsetM = { 0.0041, 1.5193, 0.5047 } },
				{ name = "HeadLamps", meshId = 12287730444, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.6967, 0.0471, 0.1236 }, offsetM = { 0.0042, 1.0513, -2.0781 } },
				{ name = "HeadLamps_2", meshId = 12287730444, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.6967, 0.0471, 0.1236 }, offsetM = { 0.0042, 1.0513, -2.0781 } },
				{ name = "HeadLamps_3", meshId = 12287730444, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.6967, 0.0471, 0.1236 }, offsetM = { 0.0042, 1.0513, -2.0781 } },
				{ name = "TailLamps_5", meshId = 12287769083, color = Color3.fromRGB(151, 0, 0), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.6805, 0.0766, 0.112 }, offsetM = { 0.0039, 1.1741, 2.4094 } },
				{ name = "FogLamps_2", meshId = 12287765915, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.8009, 0.055, 0.0299 }, offsetM = { 0.0041, 0.5239, -2.0585 } },
				{ name = "Indicators_3", meshId = 12287766230, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.351, 0.1416, 0.3717 }, offsetM = { 0.7619, 1.0196, -2.0459 } },
				{ name = "Indicators_4", meshId = 12287731221, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.351, 0.1416, 0.3718 }, offsetM = { -0.7535, 1.0196, -2.0459 } },
				{ name = "Indicators_5", meshId = 12287771414, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.1071, 0.0219, 0.1325 }, offsetM = { -0.7831, 1.1096, 2.3856 } },
				{ name = "Indicators_6", meshId = 12287745557, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.1072, 0.022, 0.1326 }, offsetM = { 0.7914, 1.1096, 2.3856 } },
				{ name = "TailLamps_6", meshId = 12287768421, color = Color3.fromRGB(117, 0, 0), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 1.5989, 0.046, 0.0445 }, offsetM = { 0.0042, 1.2008, 2.4172 } },
				{ name = "HeadLamps_4", meshId = 2791670956, color = Color3.fromRGB(248, 248, 248), material = Enum.Material.SmoothPlastic, castShadow = false, sizeM = { 0.0002, 0.042, 0.0002 }, offsetM = { 0.0032, 0.5937, -1.893 } },
				{ name = "Trim_23", meshId = 1866395433, color = Color3.fromRGB(8, 8, 8), material = Enum.Material.Plastic, sizeM = { 0.6779, 0.1223, 0.6109 }, offsetM = { 0.0031, 0.7914, -1.3192 }, rotationDeg = { 0, -90, 0 } },
				{ name = "Trim_24", meshId = 2668285222, color = Color3.fromRGB(17, 17, 17), material = Enum.Material.Plastic, sizeM = { 0.8076, 0.164, 0.1364 }, offsetM = { 0.0032, 0.6087, -2.0221 } },
			},
			wheelPieces = {
				{ name = "Tyre", meshId = 12287797602, color = Color3.fromRGB(28, 28, 30), material = Enum.Material.Rubber, sizeM = { 0.2344, 0.7865, 0.7865 }, offsetM = { 0, 0, 0 }, rotationDeg = { 0, 0, 0 } },
				{ name = "Rim", meshId = 12287753440, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.1161, 0.5696, 0.5694 }, offsetM = { -0.0692, -0.0004, 0 }, rotationDeg = { 0, 0, 0 } },
				{ name = "Rim_Nuts", meshId = 12287753794, color = Color3.fromRGB(163, 162, 165), material = Enum.Material.SmoothPlastic, sizeM = { 0.021, 0.1754, 0.157 }, offsetM = { -0.0958, -0.0004, -0.0001 }, rotationDeg = { 0, 0, 0 } },
			},
		},
		tuning = {
			-- Four-wheel drive, as the real truck (its A-Chassis tune says RWD).
			drivetrain = { layout = "AWD" },
			-- The Tahu's, at its 2.5 t.
			suspension = { stiffness = 51000, damping = 4800, antiRollFront = 10200, antiRollRear = 6800 },
			twoWheel = { liftTorque = 18800, leanInTorque = 6800, leanOutTorque = 6200, balanceSpring = 165 },
			effects = {
				-- The store model's own horn, start chime and startup.
				horn = { soundId = "rbxassetid://2900822433" },
				-- Its A-Chassis "Rev" loop, one file for every layer. The plugin
				-- plays it at pitch rpm / 7000 (its redline): refRpm 7000.
				engineAudio = {
					chimeSoundId = "rbxassetid://6725068888",
					startSoundId = "rbxassetid://635482475",
					layers = {
						idle = { soundId = "rbxassetid://2101020049", refRpm = 7000, volume = 0.5, eq = { 0, 0, -6 } },
						lowLoad = { soundId = "rbxassetid://2101020049", refRpm = 7000, volume = 0.8, eq = { 3, 0, -3 } },
						highLoad = { soundId = "rbxassetid://2101020049", refRpm = 7000, volume = 1, eq = { 0, 2, 2 } },
						overrun = { soundId = "rbxassetid://2101020049", refRpm = 7000, volume = 0.5, eq = { 0, -2, -8 } },
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
