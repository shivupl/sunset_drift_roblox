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

-- ONE PALETTE FOR THE SAND. Every sand surface in the world -- the plane,
-- the terrain strip, the berm, the far dune field, the drifts, the median --
-- takes its colour from these three, so nothing can drift out of match
-- again. They are light because they multiply the sand colour map.
--
-- SAND is the ground tone. LIGHT is wind-blown and crest sand, which catches
-- more light. DARK is compacted, shadowed or gravel-mixed ground.
local SAND = Color3.fromRGB(198, 172, 132)
local SAND_LIGHT = Color3.fromRGB(216, 194, 156)
local SAND_DARK = Color3.fromRGB(170, 146, 110)

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
		medianColor = SAND_DARK,
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
		-- Six per carriageway on request: 32 m each way in 5.3 m lanes
		-- (widened from 4.7 m on request; the preset width sets it).
		laneCount = 6, -- per carriageway
		shoulderWidthM = 3,
		-- Kerbs are a visual lip only. Nothing on the map collides except the
		-- ground, and a 12 cm collidable step at 200 km/h is a launch ramp.
		kerbWidthM = 0.4,
		kerbHeightM = 0.07,
		-- The transition pad's wings widen in over this length at each end
		-- (a flat triangle of asphalt) instead of starting with a square
		-- corner, and the outer shoulder and kerb follow the wing's edge
		-- rather than cutting across it.
		padTaperM = 60,
		-- Painted slot lines across the parking bay, one each side of every
		-- CarSpawner slot.
		baySlotLines = true,
		-- The asphalt colours tint the variant's colour map below, so they
		-- sit near white: the map carries the actual grey. A dark tint on it
		-- (these were 52, 50, 54) is the near-black road the owner asked to
		-- lose; the old map could not go grey even at a white tint.
		asphaltColor = Color3.fromRGB(206, 206, 210),
		padColor = Color3.fromRGB(206, 206, 212),
		-- Concrete is stock material, so these are the rendered colour.
		shoulderColor = Color3.fromRGB(112, 108, 102),
		kerbColor = Color3.fromRGB(158, 156, 150),
		paintColor = Color3.fromRGB(232, 226, 205),
		bayColor = Color3.fromRGB(104, 104, 108),
		-- The asphalt itself: a MaterialVariant on Roblox's Asphalt, built
		-- from ambientCG Asphalt031 (CC0), a plain mid-grey road surface,
		-- colour and OpenGL normal uploaded as images. It replaced Road007,
		-- which is dark asphalt. Only the carriageways, pad and city streets
		-- are Asphalt; kerbs, shoulders, the bay and every marking are
		-- Concrete, so the paint stays crisp over a grainy surface. Same
		-- declare-in-the-place rule as the sand variant.
		asphalt = {
			enabled = true,
			colorMap = 129207220183204,
			normalMap = 79343445077860,
			studsPerTile = 26, -- about 7 m: grain without a visible repeat at speed
		},

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
			tyreTrackDarken = 0.07, -- 0.16 on the dark road; on grey it read as painted stripes
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
		-- One tone. The sand map below supplies the grain and the atmosphere
		-- supplies the distance fade, so a second tone is not needed; the
		-- near/far split and the per-tile noise tint that used to live here
		-- drew the tile grid on the desert as visible rectangles.
		color = SAND,
		-- The sand itself: a MaterialVariant on the Sand material built at
		-- server start from a CC0 PBR set (3Dtextures "Sand 005" via
		-- PixelHix, store decals 8282523787 / 8282524799 / 8282525263; the
		-- ids here are the images behind them). Applied to every Sand part
		-- in the world after the build, so ground, dunes, berm and drifts
		-- all match. Off falls back to Roblox's own sand.
		sand = {
			enabled = true,
			colorMap = 8282523778,
			normalMap = 8282524789,
			-- The set's roughness map (image 8282525243) reads as glossy in
			-- Roblox and gave the desert a wet sheen and specular glints on
			-- every dune crest toward the sun. 0 leaves it out: matte sand.
			roughnessMap = 0,
			studsPerTile = 20, -- about 5.6 m; smaller shows more grain close to the car but repeats sooner
		},
		-- Undulation, cheaply: low ridges built from two wedges back to back,
		-- scattered beyond the shoulder band and sunk into the plane. Sixteen
		-- triangles each. Never collidable and never near the road.
		dunes = {
			enabled = false, -- plain flat sand; the ridges come back with the borders
			seed = 3311,
			spacingM = 110, -- along the road
			jitterM = 50,
			minEdgeM = 330, -- beyond the berm's back slope
			maxEdgeM = 1400,
			minLengthM = 60,
			maxLengthM = 220,
			minWidthM = 30,
			maxWidthM = 90,
			minHeightM = 1.5,
			maxHeightM = 5,
			color = SAND_DARK,
		},
	},

	-- The dune field: a natural border on the sunset side of the road. It
	-- starts far enough out that nothing in it rises above the sun (the
	-- build prints the tallest crest angle next to the sun's elevation) and
	-- it is never collidable. Every form is a sand ellipsoid, rolled so the
	-- side facing the road is the steep slip face, sunk so its foot is
	-- buried; the rock outcrops are store meshes. All distances in metres.
	duneField = {
		-- OFF, with the berm: plain flat sand to the horizon.
		enabled = false,
		seed = 4471,
		-- "sun" picks the side Lighting's sun is on at build time; "left"
		-- and "right" are relative to the direction of travel.
		side = "sun",
		innerM = 750, -- nearest crest to the road centreline
		outerM = 1900,
		startM = -900, -- along the road; negative is behind the start line
		endM = 4900, -- past the city
		-- Crest height envelope: small at the inner edge, full height by
		-- fullDepthM into the field, so the border rises away from the road.
		-- Kept under the sun and over the berm: 50 m at 1.3 km is 2.2
		-- degrees, clear of the sun-side berm crest at 1.3 and well under a
		-- sun at 5.4, so the field reads as a horizon without touching the
		-- disc. The build prints the tallest crest angle and the sun's.
		edgeHeightM = 8,
		fullHeightM = 50,
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
			count = 260,
			minWidthM = 55,
			maxWidthM = 170,
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
		color = SAND,
		moundColor = SAND_DARK,
		colorVariation = 0.1,
		-- Skyline ring buildings that would stand behind the field are
		-- dropped, so the sunset side is dunes against sky and nothing else.
		clearSkylineBehind = true,
		skylineMarginM = 400,
	},

	-- THE NEAR DESERT, AND THE EDGE OF THE WORLD.
	--
	-- One strip of smooth terrain either side of the road carries the whole
	-- cross-section: the desert floor from innerGapM past the asphalt, then
	-- the berm rising out of that same floor to a crest, then a back slope
	-- down to the plane again. It is one height function, so there is no
	-- seam anywhere in it -- the berm used to be a separate stack of wedges
	-- and boxes, and every one of its cut edges showed.
	--
	-- Terrain is used here and nowhere else in the world because it only
	-- reaches the client inside the streaming radius (573 m), and this strip
	-- is the one piece of sand the car is ever near. It all collides, at
	-- real slopes, so running wide feels like sand and the crest stops you.
	relief = {
		-- ON: low dunes either side of the highway (berm below), with the
		-- chain-link fence behind them. No swell or ripple noise on the sand:
		-- the owner wanted calm shapes, nothing to bump over.
		enabled = true,
		seed = 8083,
		-- The strip starts right at the asphalt edge: a band of the flat sand
		-- plane between the two showed as a different sand.
		innerGapM = 0.5, -- from the asphalt edge to the strip
		featherM = 6, -- the strip's inner and outer edges blend down to the plane over this
		sinkM = 0.15, -- the dune terrain sits this far down, so it breaks the plane where its slope has just begun, not as a ledge
		shellM = 3.5, -- solid sand below the surface; a shell, because nothing digs
		hummocks = {
			perKm = 0, -- none: the sand between the road and the dunes is flat, on request
			minRadiusM = 3,
			maxRadiusM = 9,
			minHeightM = 0.5,
			maxHeightM = 1.6,
			scrubChance = 0.4, -- a nabkha: a bush with its own mound
		},
		-- Patches of a darker, coarser material where a slow noise is high:
		-- gravel flats between the sand.
		gravel = { threshold = 0.36, scaleM = 60, material = Enum.Material.Ground },
		-- The same tint as the plane: the terrain now wears the plane's sand
		-- MaterialVariant (Relief sets the base material override), and with
		-- it the old one-step-darker tint (for stock terrain sand, which
		-- rendered brighter) came out a shade off at the dune's foot.
		sandColor = SAND,
		gravelColor = Color3.fromRGB(138, 118, 90),
		chunkStuds = 128, -- voxel write chunk; 32 columns of 4 studs

		-- Low dunes over all the sand between a flat strip beside the road and
		-- the fence: a random field of soft, rounded mounds of different sizes,
		-- turned a little off the road, thick in places and thin in others.
		-- Each leaves the sand at a grazing angle, so there is no foot line,
		-- and nothing small on them to bump over. They were a chain along the
		-- road; the owner wanted them random and out to the fence. They keep
		-- clear of the station and sink away before the city.
		berm = {
			enabled = true,
			endM = 3540, -- the far end: the dunes are gone by here, short of the city gateway
			endTaperM = 220, -- heights sink to nothing over this before endM
			-- Nothing of a dune shows nearer the centreline than nearM, about
			-- 100 m past the 39.4 m road edge. It was 128 m (89 m past the
			-- edge); the owner wanted a bit more.
			nearM = 140,
			capNearM = 100, -- the same, behind the start line
			field = {
				perKm2 = 100, -- mounds per square km of sand they may use
				patchWavelengthM = 500, -- the slow noise that makes thick and thin stretches
				minDensity = 0.15, -- in the thinnest stretches, this fraction of tries still counts
				maxOverlapM = 0.8, -- no mound where the others already stand this high (no lumps on shoulders)
				pastFenceM = 30, -- mounds may run this far over the fence line: the fence goes over the dunes
			},
			-- Light waves under the mounds: from a wandering start line past
			-- the flat strip, long low crests run over all the sand to the
			-- fence, so once the dunes begin the ground never goes back to
			-- dead flat. math.noise spans about -0.5..0.5.
			waves = {
				enabled = true,
				baseM = 0.35, -- lowest, above the sunk base (sinkM less shows), so no flat patches
				amplitudeM = 0.7, -- crest height over that
				spacingM = 60, -- across the crests
				crestLengthM = 200, -- along them
				angleDeg = 25, -- crests turned this far off the road
				detail = 0.3, -- a second, finer octave, as a fraction
				startWanderM = 45, -- the start line wanders out this far past nearM
				startWanderWavelengthM = 260,
				rampM = 60, -- rising from nothing over this, flush
				pastFenceM = 70, -- carried on under and beyond the fence, gone by this far past it
				fadeM = 40, -- eased out over the last of that, so no edge shows
			},
			-- Each mound, drawn at random from these ranges.
			lengthM = { 90, 220 }, -- along the road, rim to rim before sinking
			nearSpreadM = { 40, 58 }, -- half width toward the road: the long, gentle side (steepest about 7 deg)
			farSpreadM = { 24, 34 }, -- half width behind (steepest about 12 deg)
			heightM = { 1.6, 3.4 }, -- above the sunk base; sinkM less shows. Skewed low; low ones are smaller all round.
			yawDeg = 20, -- turned off the road by up to this
			-- Overlapping mounds add, eased from the first number toward the
			-- second, so two tall ones make a broad hill and not a peak.
			overlapM = { 2.8, 4.0 },
			clearanceGapM = 30, -- no mound comes within this of the petrol station's site
			wallHeightM = 150, -- the invisible stop where the fence would be, only built when the fence is off
			wallPieceM = 12,
		},
	},

	-- No barriers at the road. There is nothing between the road and the
	-- sand; running wide costs speed, not the run. The edge of the world is
	-- the berm above. The old barrier module was removed rather than
	-- disabled so nothing can bring it back by accident.

	lamps = {
		enabled = true,
		spacingM = 45,
		-- Outer shoulders always. The median gets a double-arm post every
		-- spacing too, offset by half a spacing so the three rows interleave.
		medianLamps = true,
		-- The outer spacing, so each median post stands halfway between two
		-- shoulder lamps. 22 (twice the density) read as too many.
		medianSpacingM = 45,
		-- The post is one store mesh (AssetRegistry.highwayLamp): concrete
		-- pedestal, tapering pole, curved cobra arm and head in one textured
		-- piece. Off, or if the mesh fails to load, the box stand-in below
		-- is built instead.
		useMesh = true,
		-- The mesh is 10.6 m tall at scale 1 with the head 4.5 m out from
		-- the pole. 1.15 makes a 12.2 m highway post reaching 5.1 m, which
		-- with the pole a hand past the kerb puts the head over the outer
		-- lane. Real Saudi highway posts are 12 m.
		meshScale = 1.15,
		-- A median post is two mesh posts back to back; the second stands
		-- this far along the road so the two poles read as one thick pole
		-- and never share a surface.
		pairGapM = 0.12,
		setbackM = 0.4, -- from the kerb to the pole
		-- The lens: a thin slab under the head, Neon when the hour lights
		-- the lamps, dark glass otherwise. Metres at scale 1; the light
		-- manager hangs its SpotLight from it, shining down.
		lensSizeM = Vector3.new(1.05, 0.08, 0.6),
		lensLitColor = Color3.fromRGB(255, 236, 200), -- warm-white LED
		lensLitTransparency = 0.1, -- a hair of transparency takes the bloom off a solid Neon slab
		lensOffColor = Color3.fromRGB(190, 196, 204),
		lensOffTransparency = 0.25,
		-- Perfect repetition is what makes a row of lamps read as generated.
		jitterSeed = 4417,
		yawJitterDeg = 2.5,
		heightJitter = 0.035, -- fraction of pole height
		bothSides = true, -- false alternates sides, which halves the part count
		-- The box stand-in. Only built when the mesh is off or missing.
		poleHeightM = 10,
		poleWidthM = 0.26,
		armLengthM = 8,
		headSizeM = 0.75,
		poleColor = Color3.fromRGB(74, 76, 80),
		bulbColor = Color3.fromRGB(255, 186, 92),
		headOffColor = Color3.fromRGB(58, 58, 62), -- unlit housing in daylight
		-- Live SpotLight settings. Only maxLiveLights of these exist at once.
		-- Warm white to match the lens; the cone is wide so a 12 m post
		-- lights a pool the width of a carriageway.
		lightColor = Color3.fromRGB(255, 220, 170),
		lightBrightness = 3.2,
		lightRangeM = 34,
		lightAngleDeg = 120,
		-- Hard cap on Light instances in the whole client. Roblox degrades
		-- badly past a handful of dynamic lights.
		maxLiveLights = 12,
		-- How often the client re-picks which lamps are lit. Not per frame.
		lightUpdateInterval = 0.25,
	},

	-- THE PETROL STATION. The first structure in the game: a ring-road
	-- station beside the parking bay, set back from the transition pad's
	-- right-hand wing with an entry apron before it and an exit apron after
	-- it. Built from primitives by Station.luau, placed and sized entirely
	-- from here. Local frame: u is across the road (+ away from it), v is
	-- along it (+ the direction of travel), both in metres from the
	-- station origin, and everything below is at scale 1.
	--
	-- Orientation is chosen for the golden-hour sun, which sits low over
	-- the far side of the highway: it lights the road-facing fronts of the
	-- canopy and the shop, and the canopy's shadow runs away from the road
	-- and down the direction of travel, across the open forecourt and
	-- clear of the shop, which stands upstream of it.
	station = {
		enabled = true,
		alongM = 1500, -- distance along the road of the origin (the bay's centre); inside the pad
		lateralM = 122, -- from the road centreline to the origin, right-hand side
		yawDeg = 0, -- extra turn about the origin; the aprons follow
		scale = 1,
		pumpCount = 6, -- 4 to 6; split across the two islands
		seed = 3131,
		-- Invented, no real brand: "Star of the Road".
		nameArabic = "نجمة الدرب",
		nameEnglish = "NAJMAT AL DARB",
		shopArabic = "ميني ماركت",
		shopEnglish = "MINI MARKET",
		prices = { { "91", "2.18" }, { "95", "2.33" }, { "ديزل  DIESEL", "1.66" } },

		-- Footprint (u from, u to, v from, v to) of the concrete forecourt.
		-- Deep enough behind the canopy that its golden-hour shadow, about
		-- 60 m long and thrown away from the road, lands on the concrete.
		forecourt = { u0 = -26, u1 = 60, v0 = -66, v1 = 68 },
		forecourtPanels = { across = 2, along = 2 }, -- concrete bays, each its own tone
		apronWidthM = 14,
		apronFlareM = 6,
		entryV = -52, -- apron centres along v
		exitV = 54,
		keepOutMarginM = 8, -- scatter stays this far clear of the whole site

		canopy = {
			u = -6, v = 14, -- centre
			acrossM = 22, alongM = 36,
			clearanceM = 5.8, -- soffit height; a pickup is 2 m
			fasciaM = 1.6, -- deep enough to carry the name at road distance
			columnM = 0.45,
			columnInsetV = 11.4, -- columns near the island ends, v = centre +- this, inside the bumpers
		},
		islands = { u = { -11, -1 }, lengthM = 26, widthM = 1.6, heightM = 0.18 },
		shop = {
			u = 48, v = -40, -- centre; back of the lot, clear of the canopy shadow
			depthM = 11, lengthM = 26, heightM = 4.4, parapetM = 0.8,
		},
		-- The price totem at the pad edge 40 m before the entrance: 14 m, so it is
		-- what a driver on the highway sees first of a site set back past the bay.
		pylon = { u = -34, v = -110, heightM = 14, widthM = 3.2, yawTowardRoadDeg = 25 },
		palms = { { -31, 66 }, { 64, -64 }, { 64, 2 } }, -- built from parts, 96 triangles each
		parkedCars = 2,

		colors = {
			concrete = Color3.fromRGB(176, 170, 158),
			concreteUnder = Color3.fromRGB(160, 156, 148), -- the bay under the canopy, oil-darkened
			apron = Color3.fromRGB(206, 206, 212), -- asphalt tint, like the pad
			fascia = Color3.fromRGB(238, 234, 224),
			brand = Color3.fromRGB(0, 104, 78), -- deep green
			brandGold = Color3.fromRGB(214, 170, 82),
			soffit = Color3.fromRGB(226, 222, 212),
			column = Color3.fromRGB(214, 212, 206),
			sandstone = Color3.fromRGB(210, 182, 138),
			sandstoneDark = Color3.fromRGB(176, 148, 108),
			glass = Color3.fromRGB(120, 150, 156),
			interior = Color3.fromRGB(255, 226, 180),
			pumpBody = Color3.fromRGB(232, 230, 224),
			kerb = Color3.fromRGB(196, 190, 176),
			bumper = Color3.fromRGB(232, 184, 40),
			paint = Color3.fromRGB(236, 232, 214),
			metal = Color3.fromRGB(120, 124, 128),
			stain = Color3.fromRGB(34, 32, 30),
			light = Color3.fromRGB(255, 232, 196), -- warm strip lens
		},
	},

	-- THE BORDER: a chain-link fence either side of the highway, 250 m
	-- past each road edge, well behind the low dunes. Galvanised square
	-- posts, a top rail, the mesh as a see-through texture (the desert and
	-- the skyline show through it), and two strands of barbed wire, the
	-- utility-land fence along every Saudi highway. It goes round the back
	-- of the petrol station, closes across behind the start line and ends
	-- short of the city gateway. An invisible wall stands in it, tall, so
	-- nothing jumps it.
	fence = {
		enabled = true,
		-- From the outer edge of the shoulder and kerb: 400 m (about 1,300 ft),
		-- with the dune field running out to it. It was 250 ft, then 250 m;
		-- the owner asked for it further back each time.
		fromRoadEdgeM = 400,
		behindStartM = 400, -- the cross fence behind the start line
		endM = 3540, -- where the side fences stop, short of the city gateway
		heightM = 2.4,
		postSpacingM = 6,
		postWidthM = 0.07, -- square galvanised tube
		railWidthM = 0.05,
		postColor = Color3.fromRGB(150, 154, 158),
		-- The mesh: 8 diamonds a tile, tiled every meshTileM (so a diamond
		-- is about 7.5 cm). At a distance it mips down to a faint grey veil.
		meshTextureId = 137967953738964, -- assets/world/chainlink.png
		meshTileM = 0.6,
		meshTransparency = 0.05,
		barbedWire = true,
		barbedHeightsM = { 0.12, 0.26 }, -- above the top rail
		barbedColor = Color3.fromRGB(110, 112, 116),
		-- Round the station: this far past its site, eased back over blendM.
		clearanceGapM = 20,
		clearanceBlendM = 120,
		wallHeightM = 150,
	},

	signage = {
		enabled = true,
		gantrySpacingM = 600,
		gantryFirstM = 300,
		setbackM = 1.5, -- from the kerb to the post
		-- Top of the truss. The boards hang under it, so their bottom edge is
		-- this minus trussDepthM, panelHeightM and 0.3 m of bracket: 6 m of
		-- clearance at 11. At 7.6 the boards came down to 2.6 m, head height
		-- on a car roof, and read as a sign on the road rather than over it.
		gantryHeightM = 11,
		-- The gantry is a lattice portal frame, the kind that spans every
		-- Saudi motorway: each leg two columns with ties, the beam a truss
		-- of two chords with verticals and diagonals every bayM.
		legColumnM = 0.32,
		legSpreadM = 1.3, -- between the two columns of a leg
		trussDepthM = 1.5,
		chordM = 0.24,
		bayM = 3.2,
		braceM = 0.14,
		panelWidthM = 7.5,
		panelHeightM = 3.2,
		-- Panels: green with a white border strip, the way Saudi direction
		-- signs are, hung from the truss on two brackets.
		panelColor = Color3.fromRGB(16, 92, 52),
		panelBlueColor = Color3.fromRGB(10, 56, 140), -- distance and service signs
		borderWidthM = 0.12,
		borderColor = Color3.fromRGB(236, 236, 230),
		postColor = Color3.fromRGB(150, 152, 156), -- galvanised
		textColor = Color3.fromRGB(240, 240, 235),
		-- PLACEHOLDER road names. Replace with real Riyadh route names.
		-- Each entry is { arabic, english, shield }.
		gantryTexts = {
			{ "الطريق الدائري", "Ring Road", "N 65" },
			{ "طريق الملك فهد", "King Fahd Rd", "N 5" },
			{ "الدرعية", "Diriyah", "12 km" },
			{ "طريق الملك خالد", "King Khalid Rd", "N 40" },
		},
		-- Roadside signs on twin posts, alternating sides and alternating
		-- green direction boards with blue distance boards.
		roadsideEnabled = true,
		roadsideSpacingM = 250,
		roadsideWidthM = 2.4,
		roadsideHeightM = 1.5,
		roadsidePostHeightM = 2.6,
		roadsideTexts = {
			{ "الرياض", "Riyadh", "18 km" },
			{ "مخرج", "Exit", "2 km" },
			{ "الخرج", "Al Kharj", "64 km" },
			{ "استراحة", "Rest area", "5 km" },
		},
		-- Round speed-limit signs on a single post: red ring, white disc.
		speedSigns = {
			enabled = true,
			spacingM = 500,
			firstM = 150,
			limit = "120",
			diameterM = 0.9,
			postHeightM = 2.4,
		},
	},

	cityscape = {
		enabled = true,
		seed = 20260911,
		-- THE BACKDROP SKYLINE is a separate city on the horizon, and it is
		-- a band along the RIGHT of the road: the side away from the sun,
		-- which keeps the sunset clean on the left and leaves the view
		-- straight ahead to the detailed city.
		--
		-- A band, not a sector round the middle of the road, so that it is
		-- there for the whole drive: it runs from behind the start line to
		-- the city gateway, densest and tallest near the start, thinning
		-- toward the far end. Two rows give it depth: a front row of low
		-- blocks close in, so the towers behind have a foot, and a back row
		-- of the tall stuff. Distances are from the road centreline; along
		-- distances are from the start line, negative behind it.
		--
		-- It sits inside 2.5 km because golden-hour haze takes nearly
		-- everything past that; at 1.3 to 2.4 km it reads as a city.
		band = {
			side = 1, -- +1 is the road's right; -1 its left
			fromAlongM = -1100,
			toAlongM = 3500, -- the city gateway
			-- Density along the band: full at densestAlongM, easing off to
			-- thinFraction of it at both ends, so the city has a middle.
			densestAlongM = 750, -- square on from the spawn bay
			thinFraction = 0.3,
			rows = {
				{
					nearM = 1300,
					farM = 1600,
					count = 230, -- slots along the band; the density curve thins them (150 over the old 3 km band)
					minWidthM = 40,
					maxWidthM = 110,
					minHeightM = 30,
					maxHeightM = 100,
					towerChance = 0.12,
					towerMinHeightM = 120,
					towerMaxHeightM = 200,
				},
				{
					nearM = 1600,
					farM = 2400,
					count = 322, -- 210 over the old 3 km band
					minWidthM = 50,
					maxWidthM = 150,
					minHeightM = 90,
					maxHeightM = 220,
					towerChance = 0.5, -- half towers: the verticals are what carry a silhouette
					towerMinHeightM = 220,
					towerMaxHeightM = 380,
				},
			},
		},
		-- Downtown: a KAFD-style cluster of tall slim towers on the band,
		-- centred between the start line and the spawn bay so it is square
		-- on the right from both. Dense, tall, slim. It moved 400 m down the
		-- road with the bay when the highway was extended.
		downtown = {
			enabled = true,
			alongM = 750, -- centre, from the start line
			spreadM = 600, -- half-length along the road
			nearM = 1500,
			farM = 2250,
			count = 80,
			minWidthM = 28,
			maxWidthM = 64,
			minHeightM = 160,
			maxHeightM = 400,
			-- Sodium haze along the base of the cluster: one wide dim Neon
			-- slab, the cheapest "there are a million lights over there".
			-- Wide, low and faint: any narrower or more solid and it stops
			-- being haze and starts being an orange slab in the desert.
			glowEnabled = true,
			glowWidthM = 3400,
			glowHeightM = 70,
			glowColor = Color3.fromRGB(255, 176, 96),
			glowTransparency = 0.74,
		},
		-- Landmarks, both in the downtown: a Kingdom-Centre style tower
		-- (two pillars over a slab with a sky bridge, the arch at the top)
		-- and a Faisaliah-style pyramid with the globe near its tip.
		landmarks = {
			enabled = true,
			kingdom = { heightM = 340, widthM = 120, depthM = 50, archStartFrac = 0.6, bridgeFrac = 0.92, alongM = 600, lateralM = 1950 },
			faisaliah = { heightM = 300, baseWidthM = 120, globeFrac = 0.8, globeDiameterM = 28, alongM = 960, lateralM = 2050 },
		},
		-- LIGHTS. The backdrop city is lit at every time of day, because a
		-- dark silhouette on the horizon is not what anyone wants to look
		-- at. Away from the sun it has the sky to itself, so this is where
		-- the map gets its glamour: LED verticals up the tower corners,
		-- lit rings round them at intervals, a lit roof edge on the blocks,
		-- a needle spire on some towers, and the window bands.
		--
		-- Neon at this distance is what survives the haze, so everything
		-- here is solid Neon (transparency 0) unless dayExtraTransparency
		-- pulls it back; at 0 the lights are what you see first.
		lights = {
			alwaysOn = true,
			dayExtraTransparency = 0,
			-- Vertical LED strips up the corners of a share of the towers,
			-- which is what reads as a modern Gulf skyline at this range.
			ledStripChance = 0.7,
			ledStripWidthM = 1.5,
			ledStripFromFrac = 0.06, -- up the tower from the base
			ledStripToFrac = 0.97,
			ledTransparency = 0,
			-- What colour a strip, ring or spire comes in. Weights, not
			-- fractions. Mostly gold and cool white, with the odd magenta,
			-- cyan and green the way Riyadh's towers actually light up.
			ledPalette = {
				{ color = Color3.fromRGB(255, 200, 120), weight = 4 },
				{ color = Color3.fromRGB(170, 220, 255), weight = 3 },
				{ color = Color3.fromRGB(255, 90, 200), weight = 1.2 },
				{ color = Color3.fromRGB(90, 230, 255), weight = 1 },
				{ color = Color3.fromRGB(110, 255, 150), weight = 0.6 },
			},
			-- Horizontal lit rings round a share of the towers, at random
			-- floors: a box a hair wider than the body, one part each.
			ringChance = 0.55,
			ringsMin = 2,
			ringsMax = 5,
			ringHeightM = 1.3,
			-- A lit line along the roof edge of a share of the blocks, so
			-- the flat tops are not dead.
			roofEdgeChance = 0.6,
			roofEdgeColor = Color3.fromRGB(255, 206, 150),
			-- A lit needle on some towers, in the strip's colour.
			spireChance = 0.22,
			spireHeightM = 45,
			spireWidthM = 2.2,
		},
		tierChance = 0.4,
		crownChance = 0.8,
		antennaChance = 0.35,
		antennaHeightM = 22,
		windowSegments = 2, -- per band
		blockBandsMin = 1,
		blockBandsMax = 3,
		towerBandsMin = 3,
		towerBandsMax = 6,
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
		towerColor = Color3.fromRGB(52, 62, 86),
		colorVariation = 0.3,
		-- Fraction of tall buildings that get a red aircraft warning light.
		beaconChance = 0.7,
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
		-- Scrub is drawn from AssetRegistry.scrubs: five desert grass and
		-- shrub clumps plus the old bush, coloured to the same olive.
		scrub = {
			enabled = true,
			spacingM = 9,
			jitterM = 4,
			clusterMin = 1, -- clumps per spot
			clusterMax = 4,
			clusterSpreadM = 3.5,
			minEdgeM = 4,
			maxEdgeM = 140,
			medianChance = 0.25, -- some low scrub in the median between clumps
			minSizeM = 0.9,
			maxSizeM = 2.4,
			color = Color3.fromRGB(104, 112, 74),
			colorVariation = 0.22,
		},
		-- Acacia-style desert trees on the verge, sparse: one every couple
		-- of hundred metres is what the Riyadh ring road actually has.
		tree = {
			enabled = true,
			spacingM = 150,
			jitterM = 60,
			chance = 0.7,
			minEdgeM = 12,
			maxEdgeM = 90,
			minScale = 1.3, -- the mesh is 4.5 m tall at 1
			maxScale = 2.1,
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
		-- Sand blown onto the shoulder, banked against the outer kerb: a
		-- thin wedge every so often, the hajwala highway's signature.
		-- Cosmetic; a car running wide passes through 20 cm of it.
		drift = {
			enabled = true,
			spacingM = 38,
			jitterM = 16,
			chance = 0.55,
			minLengthM = 6,
			maxLengthM = 24,
			minWidthM = 1.2,
			maxWidthM = 2.8,
			minHeightM = 0.1,
			maxHeightM = 0.28,
			color = SAND_LIGHT,
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
				-- 0.2, down from 0.26: at 0.26 the backdrop skyline at 1.3
				-- to 2.4 km was a grey ghost and its lights were lost; at
				-- 0.2 it reads as a lit city and the sunset side still has
				-- its warm band. Below 0.18 the horizon goes hard.
				density = 0.2,
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
			-- Lamps on, gently. With the box heads a lit Neon slab in daylight
			-- read as a yellow sticker; under the mesh head a warm-white lens
			-- reads as a highway coming on at sunset, which is exactly the
			-- hour this is. The pools on the road are faint at this exposure.
			lamps = { enabled = true, brightness = 1.4, rangeM = 28 },
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
		-- The main highway: a 3.6 km straight from the start line to the
		-- city, with the 400 m transition pad (spawn bay and station) at
		-- 1.3 km. It was the Phase 0 test road, 2 km with the pad at 900 m;
		-- the owner asked for more road before the spawn and much more
		-- between the spawn and the city (700 m then, 1.9 km now).
		testRoad = {
			bayLengthM = 40,
			-- The pad grows with the road so its wings, and the bay on the
			-- right-hand one, stay 48 m wide.
			pad = { startM = 1300, lengthM = 400, widthM = 168 },
			-- 72 m: an 8 m median and two 32 m carriageways of six 5.3 m lanes
			-- (64 m and 4.7 m lanes until the owner asked for wider).
			-- The straight ends in the city's gateway roundabout; the old
			-- 30 degree curve at the end went when the city moved to where
			-- the highway points (it survives in ringRoad).
			segments = {
				-- Keep CityConfig.originM.z at -(this + 22) so the gateway
				-- roundabout stays on the road's end.
				{ kind = "straight", lengthM = 3600, widthM = 72 } :: Segment,
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
