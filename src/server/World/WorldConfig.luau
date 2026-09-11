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
		dashLengthM = 6,
		dashGapM = 6,
		dashWidthM = 0.3,
		edgeLineWidthM = 0.25,
		laneCount = 4, -- lane divider dashes, not counting the outer edge lines
		shoulderWidthM = 3,
		kerbWidthM = 0.5,
		kerbHeightM = 0.12,
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
		tileM = 400,
		-- How far the sand reaches past the road bounding box on every side.
		marginM = 1200,
		thicknessM = 1,
		dropM = 0.12, -- how far the sand sits below the road surface
		-- Two tones dithered by distance from the road so the desert is not
		-- one flat colour sheet. No texture: a texture on a plane this size
		-- is a large-surface draw we have not measured.
		nearColor = Color3.fromRGB(138, 118, 86),
		farColor = Color3.fromRGB(112, 95, 70),
		farStartM = 300, -- distance from the road centre where far colour takes over
	},

	barriers = {
		enabled = true,
		-- Distance from the road edge (outside the shoulder) to the barrier face.
		offsetM = 1.5,
		-- Real jersey profile, in metres, measured off a standard F-shape:
		-- a wide flat base, a steep flare, then a near-vertical upper wall.
		-- A plain cuboid is the single most obvious "this is Roblox" tell on
		-- a highway, because the flare catches the light differently from the
		-- wall and a box has no flare to catch it.
		heightM = 0.95,
		baseWidthM = 0.6,
		baseHeightM = 0.08,
		flareHeightM = 0.25, -- top of the angled section
		topWidthM = 0.38,
		color = Color3.fromRGB(168, 162, 150),
		-- Each run is tinted a little differently, so a kilometre of barrier
		-- does not read as one extruded object.
		variationSeed = 9182,
		colorVariation = 0.13, -- fraction toward black or white, per run
		scuffChance = 0.3, -- runs that get a dark scuff mark
		scuffColor = Color3.fromRGB(74, 70, 66),
		-- Reflective strips on the barrier face, every this far.
		markerSpacingM = 24,
		markerColor = Color3.fromRGB(240, 150, 40),
		markerSizeM = 0.18,
		-- Guard rail outside the jersey line: thin corrugated beam on posts,
		-- the way a real shoulder rail is, not a slab.
		railEnabled = true,
		railOffsetM = 5,
		railHeightM = 0.75, -- beam centre height
		railDepthM = 0.32, -- beam face height
		railThicknessM = 0.04,
		-- Real posts are about 2 m apart. At 2.2 km that is 1,100 posts a side
		-- and it cost 45 fps on its own; at 12 m the run still reads as a
		-- posted rail at speed. This is the single most expensive number in
		-- the file, so change it knowing that.
		railPostSpacingM = 12,
		railColor = Color3.fromRGB(158, 158, 162),
		railPostColor = Color3.fromRGB(112, 112, 116),
	},

	lamps = {
		enabled = true,
		spacingM = 45,
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
		distanceM = 2600, -- radius to the near edge of the ring
		bandDepthM = 900, -- buildings scatter this much further out
		count = 90,
		-- Mostly low blocks with a few towers, which is what a real skyline
		-- is. Uniform heights read as a bar chart.
		minWidthM = 40,
		maxWidthM = 160,
		minHeightM = 28,
		maxHeightM = 90, -- the ordinary blocks
		towerChance = 0.16,
		towerMinHeightM = 120,
		towerMaxHeightM = 260,
		-- A warm mid tone rather than a dark silhouette: the haze tints it to
		-- whatever the hour calls for, and a near-black block stays near-black
		-- at golden hour, which is the wrong read.
		color = Color3.fromRGB(104, 92, 86),
		colorVariation = 0.18,
		-- Window bands: a few emissive strips per building rather than one
		-- part per window. See WORLD.md for why this beat a texture.
		windowBandsMin = 1,
		windowBandsMax = 4,
		windowColor = Color3.fromRGB(255, 214, 150),
		windowHeightM = 2.5,
		windowInsetM = 0.4,
		-- Fraction of buildings that get a red aircraft warning light.
		beaconChance = 0.12,
		beaconColor = Color3.fromRGB(255, 70, 60),
	},

	scatter = {
		enabled = true,
		seed = 776611,
		-- Palms are planted in loose clumps so they read as planted rather
		-- than evenly generated.
		palm = {
			enabled = true,
			clumpSpacingM = 70, -- average distance between clumps
			clumpJitterM = 22,
			minPerClump = 2,
			maxPerClump = 3,
			spreadM = 7, -- how far members of a clump sit from its centre
			minEdgeM = 10, -- never closer than this to the road edge
			maxEdgeM = 45,
			trunkHeightM = 6.5,
			trunkWidthM = 0.42,
			leanMaxRad = 0.16, -- palms lean; a vertical pole reads as a lamp post
			frondCount = 5,
			frondLengthM = 3.2,
			frondWidthM = 0.55,
			trunkColor = Color3.fromRGB(78, 64, 46),
			frondColor = Color3.fromRGB(38, 52, 32),
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
	},

	-- Time of day. Pick one of the presets below; every light, colour and
	-- haze value comes from it, so sliding from golden hour to night is a
	-- one-word change here.
	timeOfDay = "dusk",

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
			sky = { starCount = 1400, celestialBodiesShown = true, sunAngularSize = 12, useSkyObject = false },
			lamps = { enabled = true, brightness = 2.4, rangeM = 30 },
		},
		goldenHour = {
			-- Measured with Lighting:GetSunDirection at latitude 24.7: this
			-- puts the sun 4 degrees above the horizon at 91 degrees to the
			-- road, which is as close to straight across the asphalt as the
			-- engine's sun path allows. 17.35 gives 10 degrees if the shadows
			-- come out too long.
			clockTime = 17.7,
			geographicLatitude = 24.7,
			-- Raking light needs a dark-ish ambient or the shadows wash out,
			-- but the car has to stay readable in them. These were set by
			-- looking at the car in shadow, not by eye on the sky.
			ambient = Color3.fromRGB(74, 66, 64),
			outdoorAmbient = Color3.fromRGB(104, 88, 78),
			brightness = 2.1,
			exposureCompensation = -0.1,
			colorShiftTop = Color3.fromRGB(255, 206, 156),
			colorShiftBottom = Color3.fromRGB(86, 74, 72),
			-- Shadows are most of the realism at this hour, so they are on
			-- and the things that cast them are listed in `shadows` below.
			globalShadows = true,
			-- Warm dusty haze. Riyadh air carries sand, so the horizon glows
			-- and fades instead of ending. Density is the main distance knob.
			-- Tuned down hard from the first pass. At density 0.42 with haze
			-- 2.6 the road faded out about 200 m ahead and the horizon
			-- disappeared entirely, which breaks the readability rule. This
			-- still glows and fades; it just does not swallow the road.
			atmosphere = {
				density = 0.2,
				offset = 0.1,
				color = Color3.fromRGB(240, 176, 118),
				decay = Color3.fromRGB(158, 104, 82),
				glare = 0.3,
				haze = 1.3,
			},
			sunRays = { enabled = true, intensity = 0.06, spread = 0.9 },
			sky = { starCount = 0, celestialBodiesShown = true, sunAngularSize = 13, useSkyObject = false },
			-- Street lamps are geometry at this hour; the manager still runs
			-- so the night preset needs no other change.
			lamps = { enabled = false, brightness = 0.5, rangeM = 18 },
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
			sky = { starCount = 900, celestialBodiesShown = true, sunAngularSize = 11, useSkyObject = false },
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
			sky = { starCount = 4200, celestialBodiesShown = false, sunAngularSize = 0, useSkyObject = false },
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
		barriers = false,
		lamps = true,
		signage = true,
		palms = true,
		rocks = false,
		cityscape = false,
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
		barriersPersistent = true,
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
			segments = {
				{ kind = "straight", lengthM = 2000, widthM = 60 } :: Segment,
				{ kind = "curve", radiusM = 400, sweepDeg = 30, direction = -1, widthM = 60 },
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
