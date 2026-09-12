--!strict
-- Every tunable for the night highway environment, in real units (metres,
-- degrees, seconds), grouped by system. Same style as CarConfig: change a
-- number here and restart the server. The world is built once at server
-- start and never rebuilt, so there is no live reload for this file.
--
-- Scale comes from CarConfig.units.metersPerStud so the world matches the
-- car. This module only reads that value; nothing here touches vehicle code.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared.CarConfig)

-- A road is described either by an explicit waypoint list or by segment
-- descriptors that expand into one. Declared up front so a preset can mix
-- straights and curves in the same array under strict types.
export type Waypoint = { xM: number, zM: number, widthM: number, bankingDeg: number }
export type Segment = {
	kind: string, -- "straight" | "curve"
	widthM: number,
	lengthM: number?, -- straight
	radiusM: number?, -- curve
	sweepDeg: number?, -- curve
	direction: number?, -- curve: -1 turns left, 1 turns right
	bankingDeg: number?,
}
export type Preset = {
	bayLengthM: number,
	pad: { startM: number, lengthM: number, widthM: number }?,
	segments: { Segment }?,
	waypoints: { Waypoint }?,
}

local config = {
	-- Which road layout to build. Presets live at the bottom of this file.
	preset = "testRoad",

	units = {
		metersPerStud = CarConfig.units.metersPerStud,
	},

	road = {
		-- Dual carriageway. A preset's widthM is the whole corridor, edge to
		-- edge; the median comes out of the middle and each carriageway gets
		-- half of what is left. 120 m total with a 26 m median gives two 47 m
		-- carriageways of four lanes, which is the "room to make a mistake"
		-- the map is for.
		-- Narrowed from 26 to 14, then to 8 on request: a strip with a lamp
		-- post down the middle and a palm either side of it, no more.
		medianWidthM = 8,
		medianColor = Color3.fromRGB(150, 128, 94),
		medianMaterial = Enum.Material.Ground,
		medianDropM = 0.04, -- median sits this far below the asphalt
		thicknessM = 1,
		-- Segment length the road is chopped into along a curve. Shorter is
		-- smoother and costs more parts. A straight run is emitted as one
		-- part regardless, up to the engine's 2048 stud axis limit.
		curveSegmentM = 18,
		-- Two segments whose headings differ by less than this count as one
		-- straight run and merge into a single part.
		straightThresholdDeg = 0.35,
		-- ...but a merged run is chopped at this length. Merging to the
		-- engine's 2048 stud limit looks like the obvious win and is not: a
		-- part belongs to the streaming region containing its CENTRE, so a
		-- 2048 stud slab is absent until you are nearly on top of it. At 80 m
		-- a 2 km barrier is still 25 parts instead of a thousand, and each
		-- one streams when you actually approach it.
		maxMergedRunM = 80,
		-- The Road model is Persistent, so its long thin strips need no
		-- streaming cap at all: 550 m is just under the engine's 2,048 studs.
		-- Only the asphalt slabs stay at 80 m, for the per-slab tone and seams.
		longRunM = 550,
		-- Segments only overlap where the road actually turns. On a straight
		-- an overlap would put two coplanar top faces in the same place and
		-- z-fight; on a curve the faces meet at an angle and resolve cleanly,
		-- and the overlap is what closes the wedge gap on the outside edge.
		jointOverlapM = 1.2,
		-- Markings and shoulders sit this far above the asphalt. Enough to
		-- beat depth precision at 2 km, small enough that the suspension
		-- raycast never notices a step.
		markingEpsilonM = 0.02,
		markingThicknessM = 0.05,
		dashLengthM = 7,
		dashGapM = 14, -- long gaps are what a real highway has; five lanes each way makes every dash count
		dashWidthM = 0.3,
		edgeLineWidthM = 0.25,
		-- Six per carriageway on request: 28 m each way in 4.7 m lanes.
		laneCount = 6, -- per carriageway
		shoulderWidthM = 3,
		-- Kerbs are a visual lip only. Nothing on the map collides except the
		-- ground, and a 12 cm collidable step at 200 km/h is a launch ramp.
		kerbWidthM = 0.4,
		kerbHeightM = 0.07,
		asphaltColor = Color3.fromRGB(52, 50, 54),
		padColor = Color3.fromRGB(48, 48, 53),
		shoulderColor = Color3.fromRGB(70, 66, 60),
		kerbColor = Color3.fromRGB(120, 118, 112),
		paintColor = Color3.fromRGB(232, 226, 205),
		bayColor = Color3.fromRGB(58, 58, 62),

		-- Surface wear. The road is the biggest thing on screen and a single
		-- flat colour is what makes it read as a prop. None of this is
		-- geometry the car can feel; it all sits at markingEpsilon or is a
		-- colour change on a slab that already exists.
		wear = {
			seed = 5150,
			slabTone = 0.07, -- per-slab colour jitter, fraction toward black or white
			-- Polished tyre tracks, two per lane where the wheels actually run.
			tyreTracksEnabled = true,
			tyreTrackWidthM = 0.85,
			tyreTrackGapM = 1.65, -- between the two tracks of one lane
			tyreTrackDarken = 0.16,
			-- A darker line across the road at every slab joint.
			seamsEnabled = true,
			seamWidthM = 0.14,
			seamDarken = 0.32,
			-- Repair patches: a slightly different shade of asphalt.
			patchesEnabled = true,
			patchSpacingM = 60,
			patchChance = 0.55,
			patchMinLengthM = 3,
			patchMaxLengthM = 14,
			patchTone = 0.16,
			-- Markings are painted, driven over and sun-bleached, never crisp.
			markingWear = 0.4, -- fraction of each dash's colour pulled toward the road
			markingFadeMax = 0.3, -- most transparent a worn dash gets
		},
	},

	ground = {
		-- Sand plane, tiled because a Part axis maxes out at 2048 studs.
		-- 550 m is 1,964 studs. A Part axis caps at 2,048, and a tile past
		-- that silently shrinks and leaves a hole in the desert.
		tileM = 550,
		-- How far the sand reaches past the road on every side. Far enough
		-- that the horizon is haze, not an edge.
		marginM = 4000,
		thicknessM = 1,
		dropM = 0.05, -- sand sits this far below the asphalt; small so running wide is a bump, not a drop
		-- Two tones dithered by distance from the road so the desert is not
		-- one flat colour sheet. No texture: a texture on a plane this size
		-- is a large-surface draw we have not measured.
		nearColor = Color3.fromRGB(138, 118, 86),
		farColor = Color3.fromRGB(112, 95, 70),
		farStartM = 300, -- distance from the road centre where far colour takes over
		-- Undulation, cheaply: low ridges built from two wedges back to back,
		-- scattered beyond the shoulder band and sunk into the plane. Sixteen
		-- triangles each. Never collidable and never near the road.
		dunes = {
			enabled = true,
			seed = 3311,
			spacingM = 110, -- along the road
			jitterM = 50,
			minEdgeM = 140,
			maxEdgeM = 1400,
			minLengthM = 60,
			maxLengthM = 220,
			minWidthM = 30,
			maxWidthM = 90,
			minHeightM = 1.5,
			maxHeightM = 5,
			color = Color3.fromRGB(130, 112, 82),
		},
	},

	-- The dune field: a natural border on the sunset side of the road. It
	-- starts far enough out that nothing in it rises above the sun (the
	-- build prints the tallest crest angle next to the sun's elevation) and
	-- it is never collidable. Every form is a sand ellipsoid, rolled so the
	-- side facing the road is the steep slip face, sunk so its foot is
	-- buried; the rock outcrops are store meshes. All distances in metres.
	duneField = {
		enabled = true,
		seed = 4471,
		-- "sun" picks the side Lighting's sun is on at build time; "left"
		-- and "right" are relative to the direction of travel.
		side = "sun",
		innerM = 750, -- nearest crest to the road centreline
		outerM = 1900,
		startM = -900, -- along the road; negative is behind the start line
		endM = 3300, -- past the city
		-- Crest height envelope: small at the inner edge, full height by
		-- fullDepthM into the field, so the border rises away from the road.
		-- 70 m at 1,300 m out is a 3.1 degree silhouette against a sun at
		-- 5.4 degrees; the build prints both.
		edgeHeightM = 12,
		fullHeightM = 70,
		fullDepthM = 550,
		-- Patchiness. Positions where this noise is under the threshold get
		-- nothing, so the field has bays and gaps instead of a wall.
		gapNoiseScaleM = 800,
		gapThreshold = -0.45,
		-- Broad flat sheets laid first, so the floor between the dunes rolls
		-- instead of showing the plane.
		sheets = {
			count = 45,
			minLengthM = 400,
			maxLengthM = 900,
			minWidthM = 200,
			maxWidthM = 420,
			minHeightM = 6,
			maxHeightM = 14,
			sink = 0.6,
		},
		-- Long seif ridges parallel to the road, the bulk of the silhouette.
		ridges = {
			count = 200,
			minLengthM = 260,
			maxLengthM = 620,
			minWidthM = 90,
			maxWidthM = 170,
			minHeightFrac = 0.6, -- of the envelope
			maxHeightFrac = 1,
			minTiltDeg = 24, -- roll toward the road: bigger is a steeper slip face
			maxTiltDeg = 38,
			yawJitterDeg = 22,
			sink = 0.4, -- fraction of the ellipsoid below ground
			spacingFrac = 0.1, -- of length; two ridges never sit closer than this
		},
		-- Sharp-crested seifs: a prism with a long windward slope away from
		-- the road and a short slip face toward it at the angle of repose,
		-- with a mound over each end so the prism's cut ends never show.
		seifs = {
			count = 70,
			minLengthM = 200,
			maxLengthM = 480,
			minHeightFrac = 0.7,
			maxHeightFrac = 1,
			slipFaceDeg = 33,
			windwardDeg = 17,
			yawJitterDeg = 14,
			sink = 0.25, -- of height, buried
			spacingFrac = 0.16,
		},
		-- Crescents: a body across the wind with two horns toward the road.
		barchans = {
			count = 70,
			minBodyM = 130, -- across the wind (along the road)
			maxBodyM = 240,
			minDepthM = 90, -- upwind to slip face
			maxDepthM = 150,
			minHeightFrac = 0.45,
			maxHeightFrac = 0.75,
			hornLengthFrac = 0.6, -- of body
			hornWidthFrac = 0.28,
			hornHeightFrac = 0.42,
			hornAngleDeg = 48, -- from the wind line
			tiltDeg = 24,
			sink = 0.42,
		},
		-- Low mounds, biased to the inner edge, so the field fades in rather
		-- than starting with a wall.
		mounds = {
			count = 420,
			minWidthM = 40,
			maxWidthM = 140,
			minHeightM = 3,
			maxHeightM = 14,
			elongation = 2.4, -- max length over width
			sink = 0.55,
			innerBias = 1.4, -- >1 pushes them toward the inner edge
		},
		-- Sandstone outcrops between the dunes, from AssetRegistry.outcrops.
		outcrops = {
			count = 30,
			minDepthFrac = 0.15,
			maxDepthFrac = 0.9,
			minScale = 2,
			maxScale = 4,
		},
		-- Scrub at the foot of the field, for anyone who drives out there.
		scrubCount = 60,
		scrubDepthM = 140,
		-- Red Sands palette; per-form variation keeps the field from being
		-- one flat colour.
		color = Color3.fromRGB(170, 124, 80),
		moundColor = Color3.fromRGB(150, 118, 82),
		colorVariation = 0.1,
		-- Skyline ring buildings that would stand behind the field are
		-- dropped, so the sunset side is dunes against sky and nothing else.
		clearSkylineBehind = true,
		skylineMarginM = 400,
	},

	-- No barriers. There is nothing between the road and the sand; running
	-- wide costs speed, not the run. The module was removed rather than
	-- disabled so nothing can bring it back by accident.

	lamps = {
		enabled = true,
		spacingM = 45,
		-- Outer shoulders always. The median gets a double-arm post every
		-- spacing too, offset by half a spacing so the three rows interleave.
		medianLamps = true,
		medianSpacingM = 22, -- twice the density of the outer rows, on request
		setbackM = 1.2, -- from the kerb to the pole
		-- Perfect repetition is what makes a row of lamps read as generated.
		jitterSeed = 4417,
		yawJitterDeg = 2.5,
		heightJitter = 0.035, -- fraction of pole height
		bothSides = true, -- false alternates sides, which halves the part count
		poleHeightM = 10,
		poleWidthM = 0.26, -- square section: a box is 12 triangles, a cylinder is ~100
		-- The boom has to clear the shoulder, the kerb and the barrier before
		-- it is over any asphalt, which is about 6 m from the pole. At 2.6 m
		-- every pool of light landed on the shoulder and the road stayed
		-- black. Real highway booms are this long for the same reason.
		armLengthM = 8,
		headSizeM = 0.75,
		poleColor = Color3.fromRGB(74, 76, 80),
		-- The emitter part is Neon so an unlit lamp still reads as a lamp.
		bulbColor = Color3.fromRGB(255, 186, 92),
		headOffColor = Color3.fromRGB(58, 58, 62), -- unlit housing in daylight
		-- Live PointLight settings. Only maxLiveLights of these exist at once.
		lightColor = Color3.fromRGB(255, 170, 74),
		lightBrightness = 3.2,
		lightRangeM = 34,
		-- Hard cap on Light instances in the whole client. Roblox degrades
		-- badly past a handful of dynamic lights.
		maxLiveLights = 12,
		-- How often the client re-picks which lamps are lit. Not per frame.
		lightUpdateInterval = 0.25,
	},

	signage = {
		enabled = true,
		gantrySpacingM = 600,
		gantryFirstM = 300,
		setbackM = 1.5, -- from the kerb to the post
		gantryHeightM = 7.2,
		gantryPostWidthM = 0.5,
		gantryBeamDepthM = 0.7,
		panelWidthM = 7,
		panelHeightM = 3,
		panelColor = Color3.fromRGB(22, 96, 58),
		postColor = Color3.fromRGB(86, 88, 92),
		textColor = Color3.fromRGB(240, 240, 235),
		-- PLACEHOLDER road names. Replace with real Riyadh route names.
		-- Each entry is { arabic, english, shield }.
		gantryTexts = {
			{ "الطريق الدائري", "Ring Road", "N 65" },
			{ "طريق الملك فهد", "King Fahd Rd", "N 5" },
			{ "الدرعية", "Diriyah", "12 km" },
			{ "طريق الملك خالد", "King Khalid Rd", "N 40" },
		},
		roadsideEnabled = true,
		roadsideSpacingM = 250,
		roadsideWidthM = 1.6,
		roadsideHeightM = 1.1,
		roadsidePostHeightM = 2.2,
	},

	cityscape = {
		enabled = true,
		seed = 20260911,
		-- The skyline is a ring around the middle of the road, not a band
		-- beside it: bands parallel to the road are invisible from the road.
		-- Two rings of ordinary city, then a dense downtown cluster ahead of
		-- the road (the direction the player spends the session looking),
		-- with two landmark towers in it. Rebuilt on request: the first pass
		-- was ninety boxes in one ring and read as a bar chart.
		-- One far ring: the separate skyline on the horizon that was there
		-- from the first pass, which the owner wants visible from a distance.
		-- Tall blocks and towers only, far out, so from the road it reads as
		-- a skyline and never as scattered small buildings (the near ring of
		-- low blocks that did read that way is gone). Anything that would
		-- land in the city grid is skipped.
		rings = {
			{ distanceM = 2700, depthM = 900, count = 110, minWidthM = 45, maxWidthM = 160, minHeightM = 45, maxHeightM = 120, towerChance = 0.3, towerMinHeightM = 130, towerMaxHeightM = 270 },
		},
		-- Downtown: a KAFD-style cluster in a sector centred on the road's
		-- direction of travel. Dense, tall, slim.
		downtown = {
			enabled = true,
			-- The cluster sits in a sector this far round from the road's
			-- direction of travel (+90 is the right-hand side, which is where
			-- the city grid is) so the grid's boulevards run into it.
			sectorOffsetDeg = 0, -- straight ahead: the towers rise at the end of the highway, behind the grid
			sectorDeg = 22, -- half-angle of the sector
			minDistanceM = 2250,
			maxDistanceM = 3000,
			count = 64,
			minWidthM = 28,
			maxWidthM = 64,
			minHeightM = 150,
			maxHeightM = 360,
			-- Sodium haze along the base of the cluster: one wide dim Neon
			-- slab, the cheapest "there are a million lights over there".
			glowEnabled = true,
			glowWidthM = 1800,
			glowHeightM = 60,
			glowColor = Color3.fromRGB(255, 176, 96),
			glowTransparency = 0.72,
		},
		-- Landmarks, both in the downtown sector: a Kingdom-Centre style
		-- tower (two pillars over a slab with a sky bridge, the arch at the
		-- top) and a Faisaliah-style pyramid with the globe near its tip.
		landmarks = {
			enabled = true,
			kingdom = { heightM = 340, widthM = 120, depthM = 50, archStartFrac = 0.6, bridgeFrac = 0.92, offsetDeg = -5, distanceM = 2400 },
			faisaliah = { heightM = 300, baseWidthM = 120, globeFrac = 0.8, globeDiameterM = 28, offsetDeg = 6, distanceM = 2500 },
		},
		-- Building detail. Tiers: a second, narrower box on top of a share
		-- of the blocks and towers. Crowns: a dim lit band at the top of a
		-- tower. Antennas on some towers. Windows are emissive bands split
		-- into segments of different brightness so floors read as lit and
		-- unlit rather than one bar.
		tierChance = 0.35,
		crownChance = 0.6,
		antennaChance = 0.4,
		antennaHeightM = 22,
		windowSegments = 2, -- per band
		blockBandsMin = 1,
		blockBandsMax = 3,
		towerBandsMin = 4,
		towerBandsMax = 7,
		windowHeightM = 2.6,
		windowInsetM = 0.4,
		windowColorWarm = Color3.fromRGB(255, 214, 150),
		windowColorCool = Color3.fromRGB(196, 222, 255),
		coolFraction = 0.3,
		crownColor = Color3.fromRGB(255, 200, 140),
		-- A warm mid tone rather than a dark silhouette: the haze tints it to
		-- whatever the hour calls for, and a near-black block stays near-black
		-- at golden hour, which is the wrong read. Towers lean bluer (glass).
		-- Darker than the first pass: the haze adds sky colour to everything
		-- at this range, so a mid tone came out as pale slabs.
		color = Color3.fromRGB(86, 76, 70),
		towerColor = Color3.fromRGB(58, 68, 90),
		colorVariation = 0.3,
		-- Fraction of tall buildings that get a red aircraft warning light.
		beaconChance = 0.5,
		beaconColor = Color3.fromRGB(255, 70, 60),
	},

	scatter = {
		enabled = true,
		seed = 776611,
		-- Real meshes from AssetRegistry when they load; the primitive
		-- stand-ins only appear if a mesh fails to load.
		useMeshes = true,
		-- Palms are planted in loose clumps so they read as planted rather
		-- than evenly generated.
		palm = {
			enabled = true,
			-- The central reservation is the signature planting: a clump
			-- every medianClumpSpacingM, jittered along and across the median,
			-- never inside medianMarginM of a kerb.
			medianEnabled = true,
			-- Sparse now: a pair every 90 m in the 8 m median, never more
			-- than medianMaxPerClump, so the strip reads as a planted
			-- divider rather than a grove.
			medianClumpSpacingM = 90,
			medianJitterM = 20,
			medianMarginM = 2.2,
			medianMaxPerClump = 2,
			-- Variety picks: fraction of palms that use the second mesh.
			varietyFraction = 0.3,
			minScale = 0.8,
			maxScale = 1.25,
			-- Outer shoulders, thinning out with distance. Denser than the
			-- first pass on request: a clump every 45 m instead of 70, up to
			-- four trees, reaching 60 m out.
			clumpSpacingM = 45, -- average distance between clumps
			clumpJitterM = 16,
			minPerClump = 2,
			maxPerClump = 4,
			spreadM = 8, -- how far members of a clump sit from its centre
			minEdgeM = 10, -- never closer than this to the road edge
			maxEdgeM = 60,
			trunkHeightM = 6.5,
			trunkWidthM = 0.42,
			leanMaxRad = 0.16, -- palms lean; a vertical pole reads as a lamp post
			frondCount = 5,
			frondLengthM = 3.2,
			frondWidthM = 0.55,
			trunkColor = Color3.fromRGB(78, 64, 46),
			frondColor = Color3.fromRGB(38, 52, 32),
		},
		scrub = {
			enabled = true,
			spacingM = 16,
			jitterM = 7,
			minEdgeM = 4,
			maxEdgeM = 140,
			medianChance = 0.25, -- some low scrub in the median between clumps
			minSizeM = 0.7,
			maxSizeM = 1.9,
			color = Color3.fromRGB(78, 88, 56),
			colorVariation = 0.2,
		},
		rock = {
			enabled = true,
			spacingM = 55,
			jitterM = 20,
			minEdgeM = 14,
			maxEdgeM = 120,
			minSizeM = 0.6,
			maxSizeM = 2.4,
			color = Color3.fromRGB(88, 80, 66),
		},
		debris = {
			enabled = true,
			spacingM = 90,
			jitterM = 25,
			minEdgeM = 3,
			maxEdgeM = 12,
			minSizeM = 0.3,
			maxSizeM = 0.9,
			color = Color3.fromRGB(100, 94, 82),
		},
		-- Density falls off with distance from the road so the near shoulder
		-- reads as maintained and the far desert as empty.
		falloffStartM = 40,
		falloffEndM = 160,
		-- Roadside artifacts: a camp every so often out past the verge, with
		-- a tent, a carpet laid out in front of it, and a couple of camels.
		artifacts = {
			enabled = true,
			seed = 90210,
			campSpacingM = 320,
			campJitterM = 120,
			campChance = 0.75,
			minEdgeM = 30,
			maxEdgeM = 110,
			camelsMin = 1,
			camelsMax = 3,
			camelSpreadM = 9,
			carpetChance = 0.85,
			carpetSizeM = Vector2.new(3, 4.2),
			-- Loose camels away from any camp, on their own.
			strayCamelSpacingM = 260,
			strayCamelChance = 0.5,
		},
	},

	-- Time of day. Pick one of the presets below; every light, colour and
	-- haze value comes from it, so sliding from golden hour to night is a
	-- one-word change here.
	timeOfDay = "goldenHour",

	-- Sun position is ClockTime plus GeographicLatitude. Roblox gives no
	-- direct azimuth control: the sun tracks east to west, and the road runs
	-- north-south along -Z, so a low evening sun automatically rakes across
	-- the asphalt from the side. Latitude tilts that path; Riyadh is 24.7.
	timesOfDay = {
		-- The default. Sun just under the horizon: the sky still carries
		-- colour, the road is comfortably readable, and it is dark enough
		-- that the street lamps and the lit windows across the city actually
		-- register instead of being washed out by daylight.
		dusk = {
			-- Sun right on the horizon. 18.2 puts it 3 degrees under and the
			-- sky goes essentially black; this keeps a warm band and a blue
			-- gradient above it while still being dark enough that the lamps
			-- and the lit windows read.
			clockTime = 17.95,
			geographicLatitude = 24.7,
			ambient = Color3.fromRGB(74, 70, 82),
			outdoorAmbient = Color3.fromRGB(96, 90, 104),
			brightness = 1.6,
			exposureCompensation = 0.05,
			colorShiftTop = Color3.fromRGB(255, 190, 138),
			colorShiftBottom = Color3.fromRGB(72, 70, 86),
			globalShadows = true,
			atmosphere = {
				density = 0.3,
				offset = 0.14,
				color = Color3.fromRGB(240, 168, 112),
				-- Decay is the colour the sky falls to away from the sun.
				-- A warm-grey decay mixed with the dusk sky reads olive; a
				-- blue one keeps the warm band low and the dome blue.
				decay = Color3.fromRGB(58, 72, 124),
				glare = 0.24,
				-- Haze smears the atmosphere Color across the whole dome, not
				-- just the horizon. Above about 1 the warm tint reaches the
				-- zenith and mixes with the blue into olive; keep it low and
				-- the warmth stays where the sun is.
				haze = 0.6,
			},
			sunRays = { enabled = true, intensity = 0.04, spread = 0.9 },
			sky = { starCount = 1400, celestialBodiesShown = true, sunAngularSize = 12, useSkyObject = false, skybox = nil },
			lamps = { enabled = true, brightness = 2.4, rangeM = 30 },
		},
		goldenHour = {
			-- Roblox has no sun azimuth control; latitude is the only lever on
			-- it. At Riyadh's real 24.7 the sun sits exactly 90 degrees off the
			-- road, so driving down it you look at a blue sky with the sunset
			-- off-screen on both sides. 60 swings it to 127 degrees: ahead and
			-- to the left, so the warm sky is in the windscreen and every palm
			-- throws its shadow diagonally across the asphalt toward you.
			-- Measured with Lighting:GetSunDirection; see WORLD.md.
			clockTime = 17.55, -- about 5 degrees up
			geographicLatitude = 60,
			ambient = Color3.fromRGB(96, 84, 82),
			outdoorAmbient = Color3.fromRGB(128, 110, 100),
			brightness = 2.2,
			exposureCompensation = -0.15,
			colorShiftTop = Color3.fromRGB(255, 196, 140),
			colorShiftBottom = Color3.fromRGB(92, 82, 88),
			globalShadows = true,
			atmosphere = {
				density = 0.26,
				offset = 0.12,
				color = Color3.fromRGB(244, 176, 118),
				decay = Color3.fromRGB(80, 78, 120),
				glare = 0.32,
				haze = 0.9,
			},
			sunRays = { enabled = true, intensity = 0.05, spread = 0.9 },
			-- A painted skybox, because the procedural dome stays day-blue
			-- until the sun is on the horizon and only then goes warm. This is
			-- a photographed sunset (store 5133032250, "HD Sunset Skybox",
			-- PeZsmistic): six textures, no scripts, nothing branded. The ids
			-- are recorded in AssetRegistry.skyboxes.
			sky = {
				starCount = 200,
				celestialBodiesShown = true,
				sunAngularSize = 14,
				useSkyObject = true,
				skybox = { bk = 5133008838, dn = 5132998156, ft = 5132998362, lf = 5132998795, rt = 5132998563, up = 5132999149 },
			},
			-- Lamps off. Lit heads are Neon slabs, and in daylight a Neon slab
			-- reads as a yellow sticker; a dark housing reads as a lamp. The
			-- dusk and night presets light them.
			lamps = { enabled = false, brightness = 1.1, rangeM = 22 },
		},
		blueHour = {
			clockTime = 18.6,
			geographicLatitude = 24.7,
			ambient = Color3.fromRGB(64, 68, 88),
			outdoorAmbient = Color3.fromRGB(82, 88, 112),
			brightness = 1.5,
			exposureCompensation = 0.05,
			colorShiftTop = Color3.fromRGB(140, 150, 200),
			colorShiftBottom = Color3.fromRGB(72, 68, 78),
			globalShadows = true,
			atmosphere = {
				density = 0.38,
				offset = 0.15,
				color = Color3.fromRGB(150, 150, 180),
				decay = Color3.fromRGB(78, 84, 116),
				glare = 0.2,
				haze = 2,
			},
			sunRays = { enabled = false, intensity = 0.03, spread = 0.9 },
			sky = { starCount = 900, celestialBodiesShown = true, sunAngularSize = 11, useSkyObject = false, skybox = nil },
			lamps = { enabled = true, brightness = 2, rangeM = 28 },
		},
		night = {
			clockTime = 0.4,
			geographicLatitude = 24.7,
			ambient = Color3.fromRGB(46, 52, 70),
			outdoorAmbient = Color3.fromRGB(58, 64, 86),
			brightness = 1.35,
			exposureCompensation = 0.2,
			colorShiftTop = Color3.fromRGB(60, 70, 110),
			colorShiftBottom = Color3.fromRGB(30, 34, 50),
			globalShadows = true,
			atmosphere = {
				density = 0.32,
				offset = 0.1,
				color = Color3.fromRGB(58, 62, 84),
				decay = Color3.fromRGB(26, 32, 52),
				glare = 0.15,
				haze = 1.4,
			},
			sunRays = { enabled = false, intensity = 0, spread = 1 },
			sky = { starCount = 4200, celestialBodiesShown = false, sunAngularSize = 0, useSkyObject = false, skybox = nil },
			lamps = { enabled = true, brightness = 3.2, rangeM = 34 },
		},
	},

	-- Which object types cast shadows. Long raking shadows across the road
	-- are the single biggest realism win at golden hour, and they are also
	-- the biggest render cost, so this is a per-type switch. The road, the
	-- sand and the markings never cast: they are flat on the ground and
	-- their shadows would be invisible anyway.
	-- Measured: with barriers casting, 643 shadow casters sat in frustum at
	-- once and the frame rate fell to 15. Shadow cost scales with the number
	-- of casters, not their size, so the rule is few and tall. Lamps, gantries
	-- and palms are sparse and throw the long raking shadows across the road
	-- that make the hour read; a kilometre of barrier throws a thin strip
	-- nobody looks at, for hundreds of casters.
	shadows = {
		lamps = true,
		signage = true,
		palms = true,
		rocks = false,
		cityscape = false,
		dunes = true,
	},

	-- Legacy distance fog stays off: Atmosphere does the distance fade, and
	-- fog thick enough to sell distance also hides the road edge.
	fogEnabled = false,

	-- Lighting.Technology is a place setting. A script can neither write it
	-- nor read it. ShadowMap is what these shadows are tuned for; Voxel is
	-- the mobile fallback and makes them blobby. See WORLD.md.
	technology = "ShadowMap",

	streaming = {
		enabled = true,
		-- The car covers ~240 studs a second at 240 km/h, so the target
		-- radius is roughly eight seconds of road ahead.
		targetRadius = 2048,
		minRadius = 512,
		-- The skyline is a backdrop. Persistent keeps it replicated at all
		-- times so the horizon never pops, which costs ~90 boxes of memory
		-- and nothing else.
		cityscapePersistent = true,
		-- The road itself is Persistent too, and this one is not cosmetic.
		-- The client owns its car's physics, so the suspension raycast runs
		-- against whatever the CLIENT has. A car at 240 km/h outruns the
		-- streamer, finds no road under it and falls out of the world; that
		-- is exactly what happened before this was turned on. Barriers go the
		-- same way because a barrier that has not streamed in is one the car
		-- drives straight through.
		roadPersistent = true,
		-- The median palms too: at 161 km/h with the default streaming radius
		-- none were in frustum and the reservation was bare ahead of the car.
		-- About 650 mesh pieces, always replicated.
		palmsPersistent = true,
		-- The dune field sits past the streaming radius; as a border it has
		-- to be there from every viewpoint.
		dunesPersistent = true,
	},

	debug = {
		-- Prints the part and estimated triangle count per system at build.
		report = true,
	},

	-- A preset is either an explicit waypoint list or a list of segment
	-- descriptors that expand into one. A waypoint is
	-- { xM, zM, widthM, bankingDeg }; RoadNetwork walks between them.
	presets = {
		-- The Phase 0 physics test road, kept so tuning still has its
		-- reference surface: 2 km straight, a 400 m transition pad starting
		-- at 900 m, then a 400 m radius 30 degree curve.
		testRoad = {
			bayLengthM = 40,
			pad = { startM = 900, lengthM = 400, widthM = 160 },
			-- 64 m: an 8 m median and two 28 m carriageways of six 4.7 m lanes.
			-- The straight ends in the city's gateway roundabout; the old
			-- 30 degree curve at the end went when the city moved to where
			-- the highway points (it survives in ringRoad).
			segments = {
				{ kind = "straight", lengthM = 2000, widthM = 64 } :: Segment,
			},
		},
		-- A longer ring-road loop for driving rather than measuring.
		ringRoad = {
			bayLengthM = 40,
			pad = { startM = 700, lengthM = 400, widthM = 150 },
			segments = {
				{ kind = "straight", lengthM = 1400, widthM = 58 } :: Segment,
				{ kind = "curve", radiusM = 520, sweepDeg = 42, direction = -1, widthM = 58 },
				{ kind = "straight", lengthM = 900, widthM = 58 },
				{ kind = "curve", radiusM = 380, sweepDeg = 55, direction = 1, widthM = 58 },
				{ kind = "straight", lengthM = 1600, widthM = 58 },
				{ kind = "curve", radiusM = 600, sweepDeg = 38, direction = -1, widthM = 58 },
				{ kind = "straight", lengthM = 1100, widthM = 58 },
			},
		},
	},
}

export type Config = typeof(config)

return config
