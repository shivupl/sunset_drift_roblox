--!strict
-- Every tunable for the city section, in metres. Same rules as WorldConfig:
-- change a number, restart the server. Nothing in the city is hand-placed;
-- the grid, the parcels, the buildings and the furniture all come from this
-- file and a seeded random.
--
-- Placement. The highway runs from the start line along -Z for 3.6 km
-- (WorldConfig.presets.testRoad) and ends in the city: its centreline is the grid's central boulevard, and
-- the first roundabout is a wider gateway square that the full 72 m of
-- highway lands on. The grid is four 360 m blocks, two either side of
-- that axis and two deep: small on purpose. The owner asked for smaller
-- and more refined, modelled on Riyadh, so the money goes into each
-- frontage rather than into more of them.
local config = {
	enabled = true,
	seed = 774411,

	-- The north-west roundabout (nearest the highway) in world metres, then
	-- the grid grows east (+X) and south (-Z).
	-- z is the highway's length plus 22: the gateway square sits on its end.
	originM = { x = -360, z = -3622 },
	blocksX = 2,
	blocksZ = 2,
	blockM = 360, -- boulevard centre to boulevard centre
	-- The node the highway feeds: boulevard index along X (0-based) on the
	-- first row, and the square's width so a 72 m road lands on asphalt.
	gateway = { i = 1, widthM = 80 },

	boulevard = {
		widthM = 48, -- kerb to kerb, both carriageways, median, parking lanes (44 until lanes went from 5 m to 5.7 m)
		medianWidthM = 8,
		laneCount = 3, -- per carriageway
		parkingLaneM = 3, -- along each kerb
		kerbWidthM = 0.4,
		kerbHeightM = 0.12,
		medianKerbHeightM = 0.15,
		-- A kerbed lawn between the carriageway and the parcels on both
		-- sides, the wide planted verge Riyadh's boulevards have. It is also
		-- what gives a roundabout ring room at the corners.
		vergeM = 18,
	},
	sideStreet = {
		widthM = 16,
		laneCount = 1, -- per direction
	},
	-- Every boulevard crossing is a real roundabout (Roundabouts.luau): a
	-- circular carriageway carved out of the crossing, a raised island
	-- with a monument, splitter noses and give-way markings. They are the
	-- drift spots, so the ring is wide.
	roundabout = {
		radiusM = 48, -- outer edge of the carriageway
		gatewayRadiusM = 55, -- the highway's 79 m corridor has to fit into this one
		islandRadiusM = 22,
		gatewayIslandRadiusM = 27,
		islandHeightM = 0.35,
		laneWidthM = 6.5, -- ring lanes are marked at about this width
		splitterNoseRadiusM = 4, -- half the boulevard median
		kerbSegmentM = 3, -- the curved kerb is straight pieces this long
		-- The ring kerb stands this far above the boulevard kerb and the verge
		-- lawn, whose cut edge hides under it. Level with the lawn, they z-fought.
		kerbProudM = 0.03,
		-- Asphalt band this wide inside the ring kerb, covering the ring disc's
		-- polygon edge and any gap to the carved streets.
		rimWidthM = 1.5,
		lampSetbackM = 4, -- lamp posts this far outside the ring
		lampSpacingDeg = 24,
		palmsOnIsland = 8,
		lawnColor = Color3.fromRGB(74, 112, 58),
		shrubColor = Color3.fromRGB(88, 118, 66),
		-- The centrepieces, in turn round the grid. The gateway always
		-- gets the lit Riyadh arch and name wall.
		monuments = { "dallah", "obelisk", "fountain" },
		monumentScale = 1.5,
	},

	-- The city's futuristic layer: the same LED language as the backdrop
	-- skyline, close up. Strips up tower corners and rings round them, LED
	-- lines on the median kerbs, uplit palms along the verges, lit
	-- bollards and monuments on the roundabouts.
	lights = {
		coolLed = Color3.fromRGB(150, 214, 255),
		warmLed = Color3.fromRGB(255, 206, 150),
		medianLed = true,
		towerStripChance = 0.85,
		towerRingChance = 0.6,
		towerRingsMin = 3,
		towerRingsMax = 6,
		stripWidthM = 0.6,
		vergeLawnColor = Color3.fromRGB(96, 122, 70),
		vergePalmSpacingM = 26,
		vergePalmOffsetFrac = 0.62, -- across the verge from the carriageway kerb
	},
	-- Ramps are waypoint lists, relative to nothing: world metres. Width is
	-- one generous lane plus shoulders.
	-- Each point is { x, z, width }. The highway's outer kerb is at 39.4 m
	-- from its centreline; the ramp starts just outside it as a narrow
	-- taper the first version hid under the shoulder, and widens to a lane.
	-- No ramps now that the highway ends in the grid; the lists are kept
	-- for a preset that wants a side entry again.
	ramp = {
		widthM = 12,
		offRamp = {} :: { { number } },
		onRamp = {} :: { { number } },
	},

	surface = {
		thicknessM = 0.3,
		maxRunM = 80, -- slab length cap, for streaming
		-- Tints on the asphalt variant's colour map (WorldConfig.road), so
		-- near white; see the highway's asphaltColor.
		asphaltColor = Color3.fromRGB(178, 178, 182), -- 202/206 until the highway went slightly darker
		sideStreetColor = Color3.fromRGB(212, 210, 212),
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
		-- The tracks are SmoothPlastic, not the asphalt variant, so this is
		-- the rendered colour: a shade under what the grey asphalt renders as.
		-- (They were the asphalt tint darkened, which only worked while that
		-- tint was the road's actual dark colour.)
		tyreTrackColor = Color3.fromRGB(80, 80, 84),
		-- Pavement (sidewalk) between the kerb and the parcels.
		pavementWidthM = 4,
		pavementColor = Color3.fromRGB(176, 166, 146),
		pavementDropM = 0.0, -- flush with the kerb top, above the asphalt
		pavementHeightM = 0.12,
	},

	-- District per block, row by row from the north-west: what each block's
	-- four parcels are filled with.
	-- The owner cut the villa blocks: this is one dense core that runs into
	-- the skyline, so every block is commercial, towers or the plaza.
	districts = {
		{ "commercial", "towers" },
		{ "plaza", "commercial" },
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
		-- Fraction of first-floor window segments that glow. 0: at golden
		-- hour a lit strip on a textured wall read as a blank pale panel
		-- stuck to the facade, not as a lit room.
		litChance = 0,
		windowSegmentsPerFace = 3,
		acUnitChance = 0.8,
		acUnitsMax = 4,
		waterTankChance = 0.6,
		-- Share of shop slots that take a textured mesh building
		-- (AssetRegistry.cityBlocks) instead of the box shop, and how far
		-- a mesh may be scaled to fill its slot's frontage. Down from 0.65
		-- now that the European blocks are out: the box shops carry the
		-- Gulf character (arcades, sign boxes, Najdi parapets), the meshes
		-- are the office blocks between them.
		meshChance = 0.4,
		meshMinScale = 0.75,
		meshMaxScale = 1.25,
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
			awningChance = 0.7,
			awningDepthM = 1.8,
			awningHeightM = 3.3,
			fasciaHeightM = 0.9,
			-- Street-level and rooftop detail, per building.
			arcadeChance = 0.35, -- a colonnade along the ground floor instead of a flat front
			balconyChance = 0.45, -- a couple of balconies on the second and third floors
			billboardChance = 0.1, -- a rooftop billboard on a frame
			facadeAcChance = 0.6, -- AC units hung on the front at first-floor height
			-- A vertical sign standing off the corner, with the shop's name
			-- in Arabic down it. Was a blank white Neon box.
			verticalSignChance = 0.3,
			fasciaPalette = { Color3.fromRGB(180, 40, 40), Color3.fromRGB(30, 90, 60), Color3.fromRGB(40, 60, 140), Color3.fromRGB(200, 150, 30), Color3.fromRGB(240, 240, 235) },
			signChance = 0.85,
			-- Shop sign boxes carry a name in Arabic over English, the way
			-- every Riyadh shop fascia does. Picked at random per shop.
			shopNames = {
				{ "صيدلية", "PHARMACY" },
				{ "مطعم", "RESTAURANT" },
				{ "بقالة", "GROCERY" },
				{ "مغسلة", "LAUNDRY" },
				{ "اتصالات", "TELECOM" },
				{ "حلويات", "SWEETS" },
				{ "مقهى", "CAFE" },
				{ "ملابس", "FASHION" },
				{ "عطور", "PERFUMES" },
				{ "مكتبة", "BOOKSTORE" },
				{ "إطارات", "TYRES" },
				{ "ذهب", "GOLD" },
			},
			-- A Najdi parapet on a share of the shops: the row of square
			-- crenellations along the roof edge that says Riyadh from a car.
			crenellationChance = 0.4,
			-- A mashrabiya (a carved timber lattice screen) over an upper
			-- window on this share of shops, and a row of the triangular
			-- Najdi vents under the parapet on this share.
			mashrabiyaChance = 0.5,
			najdiVentChance = 0.55,
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
			crownColor = Color3.fromRGB(255, 186, 120),
			-- Share of tower spots that take a mesh tower (AssetRegistry.
			-- cityTowers), and the scale range for each: the office tower
			-- is 71 m at 1, the grey office block 37 m.
			meshChance = 0.5,
			meshScales = {
				officeTowerA = { 1.0, 1.3 },
				officeMidA = { 1.2, 1.6 },
			},
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
		lampSpacingM = 45,
		sideStreetLampSpacingM = 60,
		lampSetbackM = 1.0, -- from the kerb, on the pavement
		-- The city lamp is the highway's mesh post (WorldLighting.meshLamp)
		-- at this scale: 0.85 of the 10.6 m mesh is a 9 m boulevard post.
		lampMeshScale = 0.85,
		lampHeightM = 9,
		lampArmM = 3.5,
		poleWidthM = 0.22,
		poleColor = Color3.fromRGB(70, 72, 76),
		headSizeM = 0.6,
		parkedCarChance = 0.13, -- per parking slot along a boulevard kerb; a car is six parts
		parkedCarSlotM = 7,
		binSpacingM = 40,
		benchSpacingM = 60,
		busStopSpacingM = 170, -- shelters on the boulevard pavements
		pavementPalmSpacingM = 42, -- fan palms along the shop fronts
		hedgeLengthM = 10, -- a clipped hedge between median palms
		crosswalkStripes = 6,
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
