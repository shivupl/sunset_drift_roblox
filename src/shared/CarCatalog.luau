--!strict
-- Every car in the game. Adding one is an entry here plus its meshes: no
-- code changes. The contract each entry follows (car space, the mounts, the
-- wheel convention, what a new car must supply) is RIG_SPEC.md, and
-- VehicleRig.validate() checks every entry at server start.
--
-- Handling that every car shares lives in CarConfig. An entry's `tuning`
-- overrides any part of it for that car only.
--
-- Both current bodies come from "Low Poly Cars Pack: Mesh Vehicle Road Race"
-- (store 120535861432410, Ninja131Venom): free, no scripts shipped (the
-- builder makes its own MeshParts from the bare mesh ids), no real brands.
-- The pack's Cybertruck and Rimac are real brands and are not used. The
-- numbers below were measured off the pack model in Studio: wheel centres,
-- then every piece's bounding box relative to them, scaled.
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
	-- The Phase 0 car. Its rig is exactly the old CarBuilder box, so the
	-- physics did not change in the migration; the body is the pack's
	-- saloon, scaled so its axles sit on the rig's 2.8 m wheelbase and
	-- 1.55 m track (0.181 m per pack stud along and up, 0.193 across).
	sedan = {
		displayName = "Sedan",
		blurb = "The heavy saloon. Long, planted, carries a slide.",
		order = 1,
		-- 1.2: at the pack's real-world 4.9 m it read small next to the wide
		-- lanes and put a seated avatar's head (1.2 m above the seat, hair
		-- included) through the 1.37 m roof. Now 5.9 m with a 1.65 m roof.
		-- The numbers below stay as measured; the scale multiplies them.
		scale = 1.2,
		rig = {
			massKg = 1600,
			collisionSizeM = { 1.8, 1.3, 4.9 },
			centerOfMassM = { 0, -0.35, -0.2 }, -- low and a little forward
			shellMassFraction = 0.35,
			wheelbaseM = 2.8,
			trackWidthM = 1.55,
			wheelRadiusM = 0.33,
			wheelWidthM = 0.22,
			-- Low in the box: 0.35 m off the ground at scale 1.2, so the seated
			-- driver's head (1.2 m above the seat) stays under the roof.
			seatM = { -0.4, -0.6, -0.2 },
		},
		body = {
			paint = Color3.fromRGB(236, 236, 232),
			pieces = {
				-- 9339166843 is the paint and 9339167457 the windows and trim (the
				-- pack colours them red and black). AssetRegistry's parked-car
				-- note had them the other way round.
				{ name = "Shell", meshId = 9339166843, sizeM = { 1.899, 1.208, 4.697 }, offsetM = { 0, 0.765, 0.047 }, paint = true, material = Enum.Material.SmoothPlastic },
				{ name = "Glass", meshId = 9339167457, sizeM = { 1.899, 1.21, 4.679 }, offsetM = { 0, 0.766, 0.054 }, color = GLASS, material = Enum.Material.Glass },
				{ name = "TailLamps", meshId = 9339167038, sizeM = { 1.624, 0.165, 0.204 }, offsetM = { 0, 0.861, 2.189 }, color = TAILLAMP, material = Enum.Material.Neon, castShadow = false },
				{ name = "HeadLamps", meshId = 9339167191, sizeM = { 1.75, 0.15, 0.347 }, offsetM = { 0, 0.639, -1.976 }, color = HEADLAMP, material = Enum.Material.Neon, castShadow = false },
			},
			wheelPieces = wheelPieces(0.33),
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
}

return {
	defaultCarId = "sedan",
	cars = cars,
}
