--!strict
-- The garage's interior looks: how the display bay is dressed, lit and graded
-- while a player is in it. The owner, 2026-11-09: "work heavily on the garage
-- aesthetics. 1. the garage interior making it more appealing, you can create
-- multiple versions ... 2. the garage lighting - needs to be optimal and needs
-- to be best to show car edits ... quality work reflective of a tripleA title".
--
-- Side variants per keep-design-variations: Tungsten is the main look (the
-- owner chose the garage direction over the studios, below); After Hours,
-- Golden Bay, and the first cut's Studio, Gallery and Workshop are the
-- others. In Studio, T cycles them while the garage view
-- is open (the LocalPlayer attribute GarageTheme holds the choice); players
-- get Tungsten. Once the owner picks, the rest go.
--
-- The client (Garage/GarageInterior) builds the dressing on every client from
-- this, over the server's shell (WorldConfig.garage), and while the view is
-- open swaps in the look's lights, sky, ambient and grading (GarageView).
--
-- Positions are metres in the view frame (GarageConfig): origin at the
-- turntable's top centre, -Z into the garage (the back wall), +X toward the
-- lift bay, +Y up. The display bay's inside, measured from the shell on
-- 2026-11-09: back wall face z -6.06, front wall face z 9.26 (the door is
-- x -2.5..2.5 there, 4 m high), left wall face x -6.16, the line of columns
-- between the bays x 6.5 (columns at z 4.1 and -1.9), floor top y -0.03,
-- roof beams' underside y 6.1. The full framing's eye is about
-- (-4.1, 1.5, 7.0) looking at the back-right corner, so what fills the
-- screen behind the car is the back wall and the lift bay beyond the columns.
local GarageThemes = {}

GarageThemes.ATTRIBUTE = "GarageTheme"

-- The room, view frame metres (see the header).
GarageThemes.room = {
	backZ = -6.06,
	frontZ = 9.26,
	leftX = -6.16,
	splitX = 6.5, -- the column line between the display and lift bays
	floorY = -0.03,
	ceilingY = 6.05, -- a dropped ceiling, just under the roof beams
	door = { halfWidthM = 2.5, heightM = 4 },
	columnsZ = { 4.1, -1.9 },
	turntableRadiusM = 2.7,
}

-- One of the view's lights: aimed at the turntable's centre
-- GarageConfig.aimHeightM up unless `aimM` says where. Range is capped at the
-- engine's 60 studs (16.8 m). Brightness is for the default sky option (the
-- view scales it by the option's exposure, GarageConfig.aimHeightM's note).
export type Light = {
	type: string, -- "SpotLight" | "SurfaceLight" | "PointLight"
	positionM: Vector3,
	aimM: Vector3?,
	brightness: number,
	rangeM: number,
	angleDeg: number,
	color: Color3,
	sizeM: number?,
	shadows: boolean?,
}

-- The view's grading, on Lighting while the view is open and put back after.
export type Env = {
	-- The studio sky the paint and floor reflect (GarageThemes.skies).
	sky: string,
	-- Lighting.Ambient: what the room's unlit faces show. Low reads as a dark
	-- room with the car lit; high flattens it.
	ambient: Color3,
	-- Over the world's bloom while the view is open.
	bloom: { intensity: number, size: number, threshold: number },
	grade: { brightness: number, contrast: number, saturation: number, tint: Color3 },
	-- Depth of field: the background softens behind the car, which stays
	-- sharp (focus follows the camera's distance to the car).
	dof: { farIntensity: number, inFocusRadiusM: number }?,
}

-- A hanging enamel lamp (the cozy looks): its shade's centre in the view
-- frame, and the SpotLight it throws straight down. The view adds the light
-- to the look's own (GarageInterior.lights).
export type Pendant = { positionM: Vector3, brightness: number, rangeM: number, angleDeg: number }

-- Text on the back wall: a painted tin sign, or glowing neon.
export type Sign = { text: string, arabic: string?, positionM: Vector3, sizeM: Vector2, neon: boolean, color: Color3, background: Color3? }

export type Theme = {
	name: string,
	blurb: string,
	kind: string, -- the builder: "cozy" | "studio" | "gallery" | "workshop"
	colors: { [string]: Color3 },
	-- The cozy looks' dressing.
	pendants: { Pendant }?,
	-- A lamp on an arm over the back wall's sign and pegboard; its light
	-- shines from positionM toward aimM, warm like the bulbs.
	wallLamp: { positionM: Vector3, aimM: Vector3, brightness: number, rangeM: number, angleDeg: number }?,
	signs: { Sign }?,
	dust: boolean?, -- motes drifting in the light (Golden Bay)
	-- The interior's painted-on light while the view is open, as a factor
	-- on GarageConfig.bakedGlow: below 1 the shell stops lighting itself, so
	-- the room is lit by the look's lights and keeps its shadows.
	bakedGlowView: number?,
	-- The glossy floor's Reflectance while the view is open (it shows the
	-- studio sky's panels); outside the view the floor keeps `floorReflect`
	-- so it does not mirror the sunset to someone walking past.
	floorReflectView: number,
	floorReflect: number,
	lights: { Light },
	env: Env,
}

-- The studio skies (tools/garage/studio_sky.py, uploaded 2026-11-09): image
-- asset ids, one image for the four walls, one up, one down. Roblox's
-- Reflectance shows the Sky's skybox, not the room, so indoors a shiny car
-- showed sunset clouds and red gloss read pink; with the dark box red reads
-- deep, with the box's softboxes streaking down the doors (measured on the
-- turntable 2026-11-09, through the images' thumbnails). The view swaps a
-- sky in only once all three images have loaded (a fresh upload is not
-- served until it clears moderation); until then the paint reflects the
-- world's sky as before. Thumbnails (rbxthumb) are not used as sky faces:
-- Studio's 3D view stopped drawing in the session that tried them.
GarageThemes.skies = {
	dark = { side = 89900233873023, up = 86454614617481, down = 95555084878333 },
	light = { side = 82829558744743, up = 116004750615370, down = 98642957239019 },
} :: { [string]: { side: number, up: number, down: number } }

function GarageThemes.skyImage(id: number): string
	return `rbxassetid://{id}`
end

local COOL = Color3.fromRGB(236, 242, 255)
local NEUTRAL = Color3.fromRGB(255, 250, 242)
local WARM = Color3.fromRGB(255, 226, 186)

GarageThemes.themes = {
	-- THE COZY LOOKS (2026-11-09). The owner, on the Workshop look: "this one
	-- where it looks like an actual garage is the direction i want to head
	-- but why is it so bright/glowy? i wanted a more cozy kind of aesthetic
	-- ... with more ambient mechanic shop vibes. make some more variations".
	-- What made it glow: a 1.4 softbox and two 1+ spots on a white car under
	-- the world's bloom (threshold 1.1), and the turntable ring as Neon. The
	-- research (warm 2700-3000 K light in layers, pools from visible
	-- fixtures, dim ambient, a faint cool fill from outside, lived-in
	-- clutter; TUNING.md "GarageThemes") gives these: the real workshop
	-- walls, its own lamps doing the lighting, warm and low, and bloom only
	-- on the bulbs.
	--
	-- Tungsten: three enamel pendants over the car in warm pools, the shell's
	-- strips dimmed to a warm glow, a pegboard, oil-can shelves, a tin sign
	-- and a clock on the back wall, a faint dusk-blue fill from the door.
	tungsten = {
		name = "Tungsten",
		blurb = "Warm pendant lamps, a lived-in workshop",
		kind = "cozy",
		colors = {
			strip = Color3.fromRGB(176, 132, 84), -- the shell's strip lenses, a warm low glow
			shade = Color3.fromRGB(38, 62, 50), -- green enamel
			bulb = Color3.fromRGB(255, 198, 130),
			cord = Color3.fromRGB(24, 24, 26),
			pegboard = Color3.fromRGB(132, 100, 66),
			tool = Color3.fromRGB(46, 48, 52),
			toolRed = Color3.fromRGB(150, 34, 28),
			shelf = Color3.fromRGB(70, 72, 76),
			can1 = Color3.fromRGB(176, 40, 30),
			can2 = Color3.fromRGB(214, 168, 40),
			can3 = Color3.fromRGB(40, 78, 140),
			can4 = Color3.fromRGB(46, 96, 58),
			clock = Color3.fromRGB(232, 226, 210),
			mat = Color3.fromRGB(30, 30, 32),
			-- The display bay's back wall: with the photo backdrop gone the
			-- shell shows its outside sandstone there, which read as a dirt
			-- wall; red brick reads as a workshop (measured live 2026-11-09).
			brick = Color3.fromRGB(122, 70, 52),
		},
		-- 1.6, measured live: at 1.1, with the shell's painted-on light still
		-- on, the room lit flat and the lamps made no pools; with that light
		-- off (bakedGlowView 0) 2.2 burned a white car, 1.6 gave a warm pool
		-- with the paint still reading.
		pendants = {
			{ positionM = Vector3.new(-1.7, 3.5, 0.2), brightness = 1.6, rangeM = 9, angleDeg = 75 },
			{ positionM = Vector3.new(0, 3.5, 0.2), brightness = 1.6, rangeM = 9, angleDeg = 75 },
			{ positionM = Vector3.new(1.7, 3.5, 0.2), brightness = 1.6, rangeM = 9, angleDeg = 75 },
		},
		-- A caged lamp on an arm over the sign and pegboard, lighting the
		-- wall down (the room's own fixtures light the room).
		-- 1.2: from 0.9 to 1.6 made little difference live (the light grazes
		-- the brick), so it stays moderate.
		wallLamp = { positionM = Vector3.new(-2.6, 4.1, -5.55), aimM = Vector3.new(-2.6, 1.2, -6.0), brightness = 1.2, rangeM = 7, angleDeg = 70 },
		signs = {
			{ text = "HAJWALA MOTORS", arabic = "هجولة", positionM = Vector3.new(-1.2, 2.9, -5.93), sizeM = Vector2.new(2.2, 0.9), neon = false, color = Color3.fromRGB(236, 226, 200), background = Color3.fromRGB(34, 64, 52) },
		},
		-- The shell's painted-on light off in the view: at 0.35 it lit the
		-- room flat and took the pools away.
		bakedGlowView = 0,
		floorReflectView = 0.03,
		floorReflect = 0,
		lights = {
			-- A soft warm panel along the camera side, low: the long line down
			-- the doors, so paint still reads between the pendants' pools.
			{ type = "SurfaceLight", positionM = Vector3.new(-5.4, 1.4, 1.2), brightness = 0.45, rangeM = 9, angleDeg = 80, color = Color3.fromRGB(255, 214, 170), sizeM = 2 },
			-- Dusk through the open door, behind the camera: faint and blue, so
			-- the shadow side is cool against the warm lamps.
			{ type = "SpotLight", positionM = Vector3.new(0, 3.2, 8.8), brightness = 0.35, rangeM = 14, angleDeg = 70, color = Color3.fromRGB(150, 176, 220) },
			-- A pool over the lift car beyond the columns, so the workshop
			-- behind has a lit corner of its own.
			{ type = "SpotLight", positionM = Vector3.new(11.5, 4.6, -1.5), aimM = Vector3.new(11.5, 0, -1.5), brightness = 0.8, rangeM = 9, angleDeg = 80, color = Color3.fromRGB(255, 196, 130) },
			-- Low and warm off the floor: sills, wheels.
			{ type = "PointLight", positionM = Vector3.new(0, 0.3, 3.0), brightness = 0.2, rangeM = 4.5, angleDeg = 0, color = Color3.fromRGB(255, 200, 150) },
		},
		env = {
			sky = "dark",
			-- 66/54/44: at 44/36/30 with the painted-on light off the room
			-- went black past the pool (pegboard, shelf gone).
			ambient = Color3.fromRGB(66, 54, 44),
			bloom = { intensity = 0.45, size = 18, threshold = 1.6 },
			grade = { brightness = -0.02, contrast = 0.1, saturation = 0.06, tint = Color3.fromRGB(255, 238, 220) },
			dof = { farIntensity = 0.12, inFocusRadiusM = 5 },
		},
	},
	-- After Hours: the shop shut for the night. One lamp over the car, the
	-- strips off, moonlight through the high window and the door, a red neon
	-- sign on the back wall. Moodiest; the car is the lit thing.
	afterHours = {
		name = "After Hours",
		blurb = "One lamp, moonlight, a neon sign",
		kind = "cozy",
		colors = {
			strip = Color3.fromRGB(60, 58, 54), -- off
			shade = Color3.fromRGB(24, 24, 26),
			bulb = Color3.fromRGB(255, 206, 150),
			cord = Color3.fromRGB(20, 20, 22),
			pegboard = Color3.fromRGB(112, 86, 58),
			tool = Color3.fromRGB(40, 42, 46),
			toolRed = Color3.fromRGB(130, 30, 26),
			shelf = Color3.fromRGB(60, 62, 66),
			can1 = Color3.fromRGB(150, 36, 28),
			can2 = Color3.fromRGB(190, 150, 36),
			can3 = Color3.fromRGB(36, 70, 128),
			can4 = Color3.fromRGB(40, 86, 52),
			clock = Color3.fromRGB(210, 206, 196),
			mat = Color3.fromRGB(26, 26, 28),
			brick = Color3.fromRGB(96, 58, 46),
		},
		pendants = {
			{ positionM = Vector3.new(0, 3.6, 0.2), brightness = 1.6, rangeM = 10, angleDeg = 85 },
		},
		wallLamp = { positionM = Vector3.new(-4.0, 3.6, -5.55), aimM = Vector3.new(-4.0, 1.0, -6.0), brightness = 0.5, rangeM = 6, angleDeg = 70 },
		signs = {
			{ text = "هجولة", positionM = Vector3.new(-2.2, 3.1, -5.93), sizeM = Vector2.new(1.8, 0.8), neon = true, color = Color3.fromRGB(255, 70, 90) },
		},
		bakedGlowView = 0,
		floorReflectView = 0.04,
		floorReflect = 0,
		lights = {
			-- Moonlight from the door, behind the camera: the cool side.
			{ type = "SpotLight", positionM = Vector3.new(0, 3.4, 8.8), brightness = 0.55, rangeM = 15, angleDeg = 60, color = Color3.fromRGB(120, 150, 210) },
			-- The neon's red spill on the wall and the car's flank toward it.
			-- 0.4: at 0.6 it bathed the whole wall and a red car in red (live).
			{ type = "PointLight", positionM = Vector3.new(-2.2, 3.1, -5.5), brightness = 0.4, rangeM = 5, angleDeg = 0, color = Color3.fromRGB(255, 60, 80) },
			-- A soft warm line down the doors, very low.
			{ type = "SurfaceLight", positionM = Vector3.new(-5.4, 1.4, 1.2), brightness = 0.3, rangeM = 9, angleDeg = 80, color = Color3.fromRGB(255, 214, 170), sizeM = 2 },
			-- The bench lamp beyond the columns, a small warm pool.
			{ type = "SpotLight", positionM = Vector3.new(9.7, 2.4, -5.6), aimM = Vector3.new(9.7, 0.9, -5.9), brightness = 0.7, rangeM = 5, angleDeg = 80, color = Color3.fromRGB(255, 190, 120) },
		},
		env = {
			sky = "dark",
			ambient = Color3.fromRGB(34, 36, 46),
			bloom = { intensity = 0.6, size = 20, threshold = 1.5 },
			grade = { brightness = -0.03, contrast = 0.14, saturation = 0.05, tint = Color3.fromRGB(240, 242, 255) },
			dof = { farIntensity = 0.14, inFocusRadiusM = 5 },
		},
	},
	-- Golden Bay: the shutter up at the end of the day, the low sun coming in
	-- through the door across the floor and the car, dust drifting in it, the
	-- inside left in warm shade.
	goldenBay = {
		name = "Golden Bay",
		blurb = "Evening sun through the door, dust in the air",
		kind = "cozy",
		colors = {
			strip = Color3.fromRGB(120, 96, 70), -- off but catching the light
			shade = Color3.fromRGB(70, 42, 30), -- rust-red enamel
			bulb = Color3.fromRGB(150, 120, 90), -- unlit
			cord = Color3.fromRGB(24, 24, 26),
			pegboard = Color3.fromRGB(138, 104, 68),
			tool = Color3.fromRGB(48, 50, 54),
			toolRed = Color3.fromRGB(156, 36, 30),
			shelf = Color3.fromRGB(74, 76, 80),
			can1 = Color3.fromRGB(180, 44, 32),
			can2 = Color3.fromRGB(220, 172, 44),
			can3 = Color3.fromRGB(44, 82, 146),
			can4 = Color3.fromRGB(50, 100, 62),
			clock = Color3.fromRGB(236, 228, 210),
			mat = Color3.fromRGB(32, 30, 30),
			brick = Color3.fromRGB(132, 78, 56),
		},
		-- Unlit: brightness 0 adds no light (they stay as fixtures).
		pendants = {
			{ positionM = Vector3.new(-1.7, 3.6, 0.2), brightness = 0, rangeM = 1, angleDeg = 60 },
			{ positionM = Vector3.new(1.7, 3.6, 0.2), brightness = 0, rangeM = 1, angleDeg = 60 },
		},
		signs = {
			{ text = "HAJWALA MOTORS", arabic = "هجولة", positionM = Vector3.new(-1.2, 2.9, -5.93), sizeM = Vector2.new(2.2, 0.9), neon = false, color = Color3.fromRGB(240, 228, 200), background = Color3.fromRGB(120, 40, 30) },
		},
		dust = true,
		bakedGlowView = 0,
		floorReflectView = 0.03,
		floorReflect = 0,
		lights = {
			-- The sun through the door: low, warm, from the front left, across
			-- the car and onto the floor and back wall.
			{ type = "SpotLight", positionM = Vector3.new(-1.5, 2.6, 9.0), aimM = Vector3.new(0.6, 0.3, -2.0), brightness = 2.2, rangeM = 16.8, angleDeg = 40, color = Color3.fromRGB(255, 166, 92) },
			-- Its bounce off the floor and walls, everywhere, warm and dim.
			{ type = "SurfaceLight", positionM = Vector3.new(0, 5.6, 0.4), aimM = Vector3.new(0, 0, 0.4), brightness = 0.4, rangeM = 12, angleDeg = 120, color = Color3.fromRGB(255, 196, 150), sizeM = 4 },
			-- The shade side, cool: sky from the high window.
			{ type = "SurfaceLight", positionM = Vector3.new(5.6, 2.6, -1.0), brightness = 0.3, rangeM = 9, angleDeg = 80, color = Color3.fromRGB(150, 170, 210), sizeM = 2 },
		},
		env = {
			sky = "dark",
			ambient = Color3.fromRGB(62, 48, 38),
			bloom = { intensity = 0.55, size = 24, threshold = 1.3 },
			grade = { brightness = 0, contrast = 0.08, saturation = 0.1, tint = Color3.fromRGB(255, 232, 205) },
			dof = { farIntensity = 0.12, inFocusRadiusM = 5 },
		},
	},
	-- A dark detailing studio: black epoxy floor, charcoal walls with upright
	-- LED strips, a honeycomb LED grid over the turntable, a lit amber ring
	-- round it, and a smoked glass wall to the workshop beyond. Dark rooms
	-- make paint read: the car is the brightest thing on screen.
	studio = {
		name = "Studio",
		blurb = "Dark detailing studio, honeycomb lights",
		kind = "studio",
		-- Measured live 2026-11-09: walls at 30/31/34 with ambient 34 read as
		-- a black void (only the lights and the ring showed); 46/48/54 under
		-- ambient 58 and a wash down the back wall reads as a dark room.
		-- Neon glows by its colour: the UI's sodium (255/186/92) rendered as
		-- a hard yellow ring, 214/118/36 at 20% transparency as amber.
		colors = {
			floor = Color3.fromRGB(28, 29, 32),
			wall = Color3.fromRGB(46, 48, 54),
			wallPanel = Color3.fromRGB(56, 58, 64),
			ceiling = Color3.fromRGB(16, 16, 18),
			led = Color3.fromRGB(196, 202, 214),
			softbox = Color3.fromRGB(206, 212, 224),
			ring = Color3.fromRGB(214, 118, 36),
			plate = Color3.fromRGB(40, 42, 46),
			glass = Color3.fromRGB(20, 22, 26),
			trim = Color3.fromRGB(70, 72, 78),
		},
		floorReflectView = 0.09,
		floorReflect = 0.02,
		lights = {
			-- The honeycomb's light: a broad soft panel straight down.
			{ type = "SurfaceLight", positionM = Vector3.new(0, 5.4, 0.4), aimM = Vector3.new(0, 0, 0.4), brightness = 1.6, rangeM = 14, angleDeg = 110, color = COOL, sizeM = 4 },
			-- Two side strips at shoulder height, either side: the long
			-- highlight down the doors that shows a car's lines.
			{ type = "SurfaceLight", positionM = Vector3.new(-5.4, 1.6, 0.2), brightness = 0.9, rangeM = 9, angleDeg = 70, color = COOL, sizeM = 2 },
			{ type = "SurfaceLight", positionM = Vector3.new(5.6, 1.6, 0.2), brightness = 0.9, rangeM = 9, angleDeg = 70, color = COOL, sizeM = 2 },
			-- The key, on the camera's side, high: shape and the paint's sheen.
			-- 0.7, from 1: a factory white car blew out to flat white.
			{ type = "SpotLight", positionM = Vector3.new(-3.2, 4.2, 5.2), brightness = 0.7, rangeM = 16, angleDeg = 60, color = NEUTRAL },
			-- A rim from behind and above: the roofline off the dark wall.
			{ type = "SpotLight", positionM = Vector3.new(1.4, 4.6, -5.2), brightness = 1.6, rangeM = 13, angleDeg = 55, color = COOL },
			-- A wash down the back wall from where it meets the ceiling, so
			-- the wall behind the car reads (bright at the top, falling off).
			{ type = "SurfaceLight", positionM = Vector3.new(-0.5, 5.8, -5.3), aimM = Vector3.new(-0.5, 0, -5.9), brightness = 1.2, rangeM = 9, angleDeg = 80, color = COOL, sizeM = 4 },
			-- Low and warm off the amber ring: sills, wheels, tyres.
			{ type = "PointLight", positionM = Vector3.new(0, 0.3, 3.2), brightness = 0.35, rangeM = 5, angleDeg = 0, color = WARM },
		},
		env = {
			sky = "dark",
			ambient = Color3.fromRGB(58, 60, 68),
			bloom = { intensity = 0.7, size = 22, threshold = 1.15 },
			grade = { brightness = 0.02, contrast = 0.12, saturation = 0.08, tint = Color3.fromRGB(250, 252, 255) },
			dof = { farIntensity = 0.18, inFocusRadiusM = 5 },
		},
	},
	-- A white photo studio: a curved white backdrop (cyclorama) that has no
	-- corner, a pale floor, one big overhead light box. Bright and even; dark
	-- paints and tints read best here.
	gallery = {
		name = "Gallery",
		blurb = "White cyclorama, overhead light box",
		kind = "gallery",
		colors = {
			floor = Color3.fromRGB(196, 196, 194),
			wall = Color3.fromRGB(226, 226, 224),
			ceiling = Color3.fromRGB(214, 214, 212),
			led = Color3.fromRGB(246, 248, 252),
			ring = Color3.fromRGB(240, 242, 246),
			plate = Color3.fromRGB(150, 152, 156),
			trim = Color3.fromRGB(180, 180, 178),
		},
		floorReflectView = 0.06,
		floorReflect = 0,
		lights = {
			{ type = "SurfaceLight", positionM = Vector3.new(0, 5.7, 0.4), aimM = Vector3.new(0, 0, 0.4), brightness = 1.3, rangeM = 14, angleDeg = 120, color = NEUTRAL, sizeM = 5 },
			{ type = "SurfaceLight", positionM = Vector3.new(-5.4, 2.2, 1.5), brightness = 0.6, rangeM = 10, angleDeg = 90, color = NEUTRAL, sizeM = 3 },
			{ type = "SurfaceLight", positionM = Vector3.new(5.6, 2.2, 1.5), brightness = 0.6, rangeM = 10, angleDeg = 90, color = NEUTRAL, sizeM = 3 },
			{ type = "SpotLight", positionM = Vector3.new(-3.2, 4.2, 5.2), brightness = 0.7, rangeM = 16, angleDeg = 70, color = NEUTRAL },
			{ type = "PointLight", positionM = Vector3.new(0, 0.3, 3.2), brightness = 0.3, rangeM = 5, angleDeg = 0, color = NEUTRAL },
		},
		env = {
			sky = "light",
			ambient = Color3.fromRGB(120, 120, 124),
			bloom = { intensity = 0.5, size = 20, threshold = 1.3 },
			grade = { brightness = 0.02, contrast = 0.06, saturation = 0.04, tint = Color3.fromRGB(255, 255, 255) },
			dof = { farIntensity = 0.12, inFocusRadiusM = 6 },
		},
	},
	-- The workshop as built (the shell, the lift bay, the tools), with the
	-- view's lighting brought up to the others: the dark studio sky for the
	-- paint, the amber ring, a warmer three-point rig.
	workshop = {
		name = "Workshop",
		blurb = "The working garage, relit",
		kind = "workshop",
		colors = {
			ring = Color3.fromRGB(214, 118, 36), -- Studio's amber (the UI's sodium read hard yellow as Neon)
			plate = Color3.fromRGB(60, 62, 66),
		},
		floorReflectView = 0.05,
		floorReflect = 0,
		lights = {
			{ type = "SurfaceLight", positionM = Vector3.new(0, 4.6, 0.3), aimM = Vector3.new(0, 0, 0.3), brightness = 1.4, rangeM = 12, angleDeg = 120, color = NEUTRAL, sizeM = 3 },
			{ type = "SpotLight", positionM = Vector3.new(-3.2, 4.2, 5.2), brightness = 1, rangeM = 16, angleDeg = 60, color = WARM },
			{ type = "SpotLight", positionM = Vector3.new(1.6, 3.8, -4.2), brightness = 1.5, rangeM = 12, angleDeg = 60, color = WARM },
			{ type = "SurfaceLight", positionM = Vector3.new(-5.4, 1.6, 0.2), brightness = 0.6, rangeM = 9, angleDeg = 70, color = NEUTRAL, sizeM = 2 },
			{ type = "PointLight", positionM = Vector3.new(0, 0.35, 2.9), brightness = 0.4, rangeM = 5, angleDeg = 0, color = WARM },
		},
		env = {
			sky = "dark",
			ambient = Color3.fromRGB(70, 66, 62),
			bloom = { intensity = 0.8, size = 24, threshold = 1.1 },
			grade = { brightness = 0, contrast = 0.08, saturation = 0.06, tint = Color3.fromRGB(255, 250, 244) },
			dof = { farIntensity = 0.15, inFocusRadiusM = 5 },
		},
	},
} :: { [string]: Theme }

-- The cozy looks first (the owner's direction, 2026-11-09), Tungsten main;
-- the first cut's three after them, kept to compare.
GarageThemes.order = { "tungsten", "afterHours", "goldenBay", "studio", "gallery", "workshop" }

function GarageThemes.resolve(id: any): string
	if type(id) == "string" and GarageThemes.themes[id] then
		return id
	end
	return "tungsten"
end

function GarageThemes.get(id: any): Theme
	return GarageThemes.themes[GarageThemes.resolve(id)]
end

return GarageThemes
