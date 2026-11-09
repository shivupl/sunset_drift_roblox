--!strict
-- The garage's interior looks: how the display bay is dressed, lit and graded
-- while a player is in it. The owner, 2026-11-09: "work heavily on the garage
-- aesthetics. 1. the garage interior making it more appealing, you can create
-- multiple versions ... 2. the garage lighting - needs to be optimal and needs
-- to be best to show car edits ... quality work reflective of a tripleA title".
--
-- Side variants per keep-design-variations: Studio is the main look; Gallery
-- and Workshop are the others. In Studio, T cycles them while the garage view
-- is open (the LocalPlayer attribute GarageTheme holds the choice); players
-- get Studio. Once the owner picks, the rest go.
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

export type Theme = {
	name: string,
	blurb: string,
	kind: string, -- the builder: "studio" | "gallery" | "workshop"
	colors: { [string]: Color3 },
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

GarageThemes.order = { "studio", "gallery", "workshop" }

function GarageThemes.resolve(id: any): string
	if type(id) == "string" and GarageThemes.themes[id] then
		return id
	end
	return "studio"
end

function GarageThemes.get(id: any): Theme
	return GarageThemes.themes[GarageThemes.resolve(id)]
end

return GarageThemes
