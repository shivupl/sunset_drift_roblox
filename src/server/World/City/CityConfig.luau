--!strict
-- Every tunable for the city section, in metres. Same rules as WorldConfig:
-- change a number, restart the server. Nothing in the city is hand-placed;
-- the grid, the parcels, the buildings and the furniture all come from this
-- file and a seeded random.
--
-- Placement. The highway runs from the start line along -Z. Saudi drives on
-- the right, so the carriageway that travels toward -Z is the +X one, and a
-- right-hand exit from it lands on the +X side: the city sits there, its
-- first roundabout 200 m east of the highway centreline, 650 m down the
-- road. The off-ramp leaves the outer lane at 380 m and the on-ramp rejoins
-- at 1,800 m, both in the direction of travel.
local config = {
	enabled = true,
	seed = 774411,

	-- The north-west roundabout (nearest the highway) in world metres, then
	-- the grid grows east (+X) and south (-Z).
	originM = { x = 200, z = -650 },
	blocksX = 3,
	blocksZ = 2,
	blockM = 420, -- boulevard centre to boulevard centre

	boulevard = {
		widthM = 44, -- kerb to kerb, both carriageways, median, parking lanes
		medianWidthM = 8,
		laneCount = 3, -- per carriageway
		parkingLaneM = 3, -- along each kerb
		kerbWidthM = 0.4,
		kerbHeightM = 0.12,
		medianKerbHeightM = 0.15,
	},
	sideStreet = {
		widthM = 16,
		laneCount = 1, -- per direction
	},
	roundabout = {
		islandRadiusM = 15,
		islandHeightM = 0.35,
		-- Every boulevard crossing is a roundabout: they are the drift spots.
		palmsOnIsland = 5,
	},
	-- Ramps are waypoint lists, relative to nothing: world metres. Width is
	-- one generous lane plus shoulders.
	-- Each point is { x, z, width }. The highway's outer kerb is at 35.4 m
	-- from its centreline; the ramp starts just outside it as a narrow
	-- taper the first version hid under the shoulder, and widens to a lane.
	ramp = {
		widthM = 12,
		offRamp = { { 40, -300, 5 }, { 42, -400, 9 }, { 50, -480, 12 }, { 75, -560, 12 }, { 120, -620, 12 }, { 165, -645, 12 }, { 200, -650, 12 } },
		onRamp = { { 200, -1490, 12 }, { 165, -1495, 12 }, { 120, -1520, 12 }, { 75, -1580, 12 }, { 50, -1660, 12 }, { 42, -1740, 9 }, { 40, -1840, 5 } },
	},

	surface = {
		thicknessM = 0.3,
		maxRunM = 80, -- slab length cap, for streaming
		asphaltColor = Color3.fromRGB(56, 54, 57),
		sideStreetColor = Color3.fromRGB(62, 60, 62),
		slabTone = 0.06, -- per-slab colour jitter
		kerbColor = Color3.fromRGB(166, 158, 142),
		kerbDust = 0.18, -- fraction of the kerb pulled toward the sand colour
		medianColor = Color3.fromRGB(150, 128, 94),
		paintColor = Color3.fromRGB(228, 222, 200),
		markingEpsilonM = 0.02,
		markingThicknessM = 0.05,
		dashLengthM = 6,
		dashGapM = 18,
		dashWidthM = 0.25,
		edgeLineWidthM = 0.2,
		tyreTracksEnabled = true,
		tyreTrackWidthM = 0.8,
		tyreTrackGapM = 1.6,
		tyreTrackDarken = 0.15,
		-- Pavement (sidewalk) between the kerb and the parcels.
		pavementWidthM = 4,
		pavementColor = Color3.fromRGB(176, 166, 146),
		pavementDropM = 0.0, -- flush with the kerb top, above the asphalt
		pavementHeightM = 0.12,
	},

	-- District per block, row by row from the north-west: what each block's
	-- four parcels are filled with.
	districts = {
		{ "commercial", "towers", "plaza" },
		{ "residential", "residential", "lot" },
	},

	buildings = {
		storeyM = 3.6,
		-- Sand, cream and warm grey, with the occasional colour.
		palette = {
			Color3.fromRGB(214, 196, 160),
			Color3.fromRGB(226, 212, 180),
			Color3.fromRGB(198, 184, 156),
			Color3.fromRGB(206, 190, 170),
			Color3.fromRGB(184, 176, 164),
			Color3.fromRGB(190, 170, 140),
		},
		accentPalette = {
			Color3.fromRGB(150, 112, 90),
			Color3.fromRGB(96, 120, 130),
			Color3.fromRGB(170, 140, 96),
		},
		accentChance = 0.12,
		tone = 0.08, -- per-part tonal jitter
		stainChance = 0.5, -- a darker stain band at the base of a wall
		stainHeightM = 1.2,
		parapetHeightM = 0.9,
		parapetThicknessM = 0.3,
		windowBandHeightM = 1.5,
		windowInsetM = 0.15,
		windowDark = Color3.fromRGB(38, 40, 48),
		windowLit = Color3.fromRGB(255, 214, 150),
		litChance = 0.35, -- fraction of window segments lit at golden hour
		windowSegmentsPerFace = 3,
		acUnitChance = 0.8,
		acUnitsMax = 4,
		waterTankChance = 0.6,
		commercial = {
			minWidthM = 18,
			maxWidthM = 36,
			minDepthM = 16,
			maxDepthM = 26,
			minStoreys = 3,
			maxStoreys = 7,
			gapChance = 0.3,
			gapM = 4,
			setbackM = 1.5, -- from the pavement edge
			awningChance = 0.8,
			awningDepthM = 1.8,
			awningHeightM = 3.3,
			fasciaHeightM = 0.9,
			fasciaPalette = { Color3.fromRGB(180, 40, 40), Color3.fromRGB(30, 90, 60), Color3.fromRGB(40, 60, 140), Color3.fromRGB(200, 150, 30), Color3.fromRGB(240, 240, 235) },
			signChance = 0.6,
		},
		residential = {
			lotWidthM = 28,
			lotDepthM = 30,
			lotGapM = 1.2,
			wallHeightM = 2.4,
			wallThicknessM = 0.3,
			gateWidthM = 4,
			gateHeightM = 2.2,
			gateColor = Color3.fromRGB(70, 66, 60),
			villaSetbackM = 4,
			villaMinWidthM = 13,
			villaMaxWidthM = 18,
			villaMinDepthM = 12,
			villaMaxDepthM = 17,
			minStoreys = 2,
			maxStoreys = 3,
			tierChance = 0.5,
			dishChance = 0.7,
		},
		towers = {
			count = 4,
			podiumStoreys = 3,
			podiumMinM = 46,
			podiumMaxM = 60,
			minStoreys = 14,
			maxStoreys = 30,
			minWidthM = 22,
			maxWidthM = 32,
			glassColor = Color3.fromRGB(96, 120, 140),
			frameColor = Color3.fromRGB(210, 206, 196),
			setbackChance = 0.5,
			crownColor = Color3.fromRGB(255, 200, 140),
		},
		plaza = {
			bayLengthM = 5,
			bayWidthM = 2.6,
			bayLineWidthM = 0.12,
			rowSpacingM = 16,
			marginM = 12,
			planterSpacingM = 14,
		},
	},

	furniture = {
		-- Densities after the performance pass: the first build put 570
		-- parked cars, 270 lamps and 260 palms on the boulevards for 6,200
		-- parts of furniture. This is about a third of that and reads the
		-- same from a moving car.
		medianPalmSpacingM = 28,
		medianPalmJitterM = 4,
		lampSpacingM = 60,
		sideStreetLampSpacingM = 75,
		lampSetbackM = 1.0, -- from the kerb, on the pavement
		lampHeightM = 9,
		lampArmM = 3.5,
		poleWidthM = 0.22,
		poleColor = Color3.fromRGB(70, 72, 76),
		headSizeM = 0.6,
		parkedCarChance = 0.12, -- per parking slot along a boulevard kerb; a car is five parts
		parkedCarSlotM = 7,
		binSpacingM = 45,
		benchSpacingM = 70,
		plazaLampSpacingM = 40,
		signalsAtRoundabouts = false, -- roundabouts have none; side-street T junctions get a signal
	},

	-- Shadow casters are the render cost that scales worst, so: building
	-- bodies and palms cast (the raking golden-hour shadows across the
	-- street are the look), compound walls, furniture, lamps and every
	-- small piece do not.
	shadows = {
		buildings = true,
		compoundWalls = false,
		palms = true,
		lamps = false,
		furniture = false,
	},

	streaming = {
		-- Streets are streamed: they sit at the same level as the sand
		-- beneath, so a slab that has not arrived is a 5 cm step, not a
		-- hole. Buildings are streamed too; nothing in the city goes past
		-- 120 km/h.
		streetsPersistent = false,
		buildingsPersistent = false,
	},
}

export type Config = typeof(config)

return config
