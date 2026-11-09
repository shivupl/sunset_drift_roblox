--!strict
-- The working dash gauges three store cars came with, put back (the owner,
-- 2026-11-08: "yea put those guages back"). Each store model carried its
-- dials as invisible parts in front of the painted dials, with a
-- SurfaceGui each: a needle that turned, the backlit numbers, and a small
-- screen with the gear and the clock. The body build keeps meshes only, so
-- they were lost; client DashGauges rebuilds them from this and drives
-- them from the car's own speed, revs and gear.
--
-- Placement is the store part's, in car space as the catalog's offsetM
-- (metres before the car's scale, +X right, +Y up, forward -Z, from the
-- body mount), with its rotation (CFrame.fromEulerAnglesYXZ, degrees),
-- size and face, so each SurfaceGui lands where the store put it. Read
-- from the store models in Studio and moved into car space with
-- storecar.car_frame, 2026-11-08.
--
-- A needle is a bar from the canvas centre, pointing along the canvas's
-- left at 0 degrees, turned clockwise by zeroDeg + degPerUnit * value and
-- held between zeroDeg and maxDeg. Only the Krown Vik's dials are the store
-- kit as it was (its numbers 30 degrees apart from -30: 20 mph a step on
-- the speedometer, 1000 rpm on the tachometer); the Tahu's and Kamri SE's
-- store gauges did not line up with their printed dials, so theirs are
-- placed and fitted to the printed numbers, measured in Studio.
local CarDashes = {}

-- startPx: where the bar starts out from the centre (a needle whose hub is
-- hidden under a printed display shows only its outer part).
export type Needle = { color: Color3, widthPx: number, lengthPx: number, startPx: number? }
export type Labels = { texts: { string }, startDeg: number, stepDeg: number, redFrom: number?, textSize: number }
export type Dial = {
	name: string,
	posM: { number },
	rotationDeg: { number },
	sizeM: { number },
	face: Enum.NormalId,
	reads: "speedMph" | "rpm",
	zeroDeg: number,
	degPerUnit: number,
	maxDeg: number,
	needle: Needle,
	labels: Labels?,
	-- How much the scene's light dims it: 0 glows like a backlit dial.
	lightInfluence: number,
}
export type Screen = {
	posM: { number },
	rotationDeg: { number },
	sizeM: { number },
	face: Enum.NormalId,
	canvas: { number },
	background: { image: string, color: Color3, transparency: number }?,
	-- Text centres, canvas pixels down from the top.
	clockY: number,
	clockSize: number,
	gearY: number,
	gearSize: number,
	lightInfluence: number,
}
export type Dash = { dials: { Dial }, screen: Screen? }

local WHITE = Color3.fromRGB(255, 255, 255)
local CANVAS = 210

-- The kit's needle: 2.1 px wide, 110 px long on its 210 px canvas, white.
local KIT_NEEDLE: Needle = { color = WHITE, widthPx = 2.1, lengthPx = 110 }
local KIT_SPEED: Labels = { texts = { "0", "20", "40", "60", "80", "100", "120", "140", "160" }, startDeg = -30, stepDeg = 30, textSize = 24 }
local KIT_REVS: Labels = { texts = { "0", "1", "2", "3", "4", "5", "6", "7" }, startDeg = -30, stepDeg = 30, redFrom = 8, textSize = 24 }

local function kitDial(name: string, reads: "speedMph" | "rpm", posM: { number }, rotationDeg: { number }, sizeM: { number }): Dial
	local speed = reads == "speedMph"
	return {
		name = name,
		posM = posM,
		rotationDeg = rotationDeg,
		sizeM = sizeM,
		face = Enum.NormalId.Bottom,
		reads = reads,
		zeroDeg = -30,
		degPerUnit = if speed then 30 / 20 else 30 / 1000,
		maxDeg = if speed then 210 else 180,
		needle = KIT_NEEDLE,
		labels = if speed then KIT_SPEED else KIT_REVS,
		lightInfluence = 0.2,
	}
end

local function kitScreen(posM: { number }, rotationDeg: { number }, sizeM: { number }): Screen
	return {
		posM = posM,
		rotationDeg = rotationDeg,
		sizeM = sizeM,
		face = Enum.NormalId.Bottom,
		canvas = { 100, 150 },
		background = { image = "rbxassetid://183229491", color = Color3.fromRGB(0, 170, 255), transparency = 0.3 },
		clockY = 75,
		clockSize = 28,
		gearY = 110,
		gearSize = 48,
		lightInfluence = 0,
	}
end

-- A needle on a dial printed on the dash (the Tahu): the kit's
-- orientation (face toward the driver), a 9 cm square screen, no numbers.
local TAHU_RED = Color3.fromRGB(190, 30, 20)
local function tahuDial(name: string, reads: "speedMph" | "rpm", posM: { number }, zeroDeg: number, degPerUnit: number, top: number): Dial
	return {
		name = name,
		posM = posM,
		rotationDeg = { -0.128, -89.665, 110.846 },
		sizeM = { 0.09, 0.0604, 0.09 },
		face = Enum.NormalId.Bottom,
		reads = reads,
		zeroDeg = zeroDeg,
		degPerUnit = degPerUnit,
		maxDeg = zeroDeg + degPerUnit * top,
		needle = { color = TAHU_RED, widthPx = 4, lengthPx = 93 },
		lightInfluence = 0.2,
	}
end

CarDashes.cars = {
	-- Its store model carried the Krown Vik's kit, but behind the dash face
	-- and the wrong way round (speedometer where the tachometer is), so
	-- nothing of it ever showed. Its dials are printed on the dash, needles
	-- and all: these are its own needles on them instead, red like the
	-- printed ones, 1 cm in front of the dial faces, the centres found by
	-- sighting the printed hubs from two eyes (2026-11-08) and the angles
	-- fitted to the printed numbers (within 3 degrees): revs -9.8 + 0.03374
	-- a rpm to 6000, speed -7.5 + 1.67 a mph to 120. The printed needles
	-- still show beneath, at rest.
	tahu = {
		dials = {
			tahuDial("Speed", "speedMph", { -0.3519, 1.1318, -0.8728 }, -7.5, 1.67, 120),
			tahuDial("Revs", "rpm", { -0.4603, 1.1289, -0.8768 }, -9.8, 0.03374, 6000),
		},
	},
	-- The same kit; in the store model nothing drove it, so its needles sat
	-- at zero there too.
	krownvik = {
		dials = {
			kitDial("Speed", "speedMph", { -0.4854, 0.9025, -0.5293 }, { 0.396, -90.918, 113.322 }, { 0.1124, 0.0607, 0.1124 }),
			kitDial("Revs", "rpm", { -0.3007, 0.9051, -0.5264 }, { 0.396, -90.918, 113.322 }, { 0.1124, 0.0607, 0.1124 }),
		},
		screen = kitScreen({ -0.3929, 0.9127, -0.5194 }, { 0.396, -90.918, 113.322 }, { 0.0726, 0.0507, 0.0507 }),
	},
	-- Its own first-person gauge script drew blue needles, but its speedo
	-- screen was stretched 2:1 (the needle shrank as it rose) and its rev
	-- needle turned 4 cm left of the printed rev counter's centre, in the
	-- store model too. So: square screens, the rev dial moved onto the
	-- printed centre (measured from the driver's view, 2026-11-08), and
	-- both needles fitted to the printed numbers (within 3 degrees): speed
	-- -15.6 + 1.553 a mph to 140, revs -6 + 0.01572 a rpm to 8000. The rev
	-- screen is turned a quarter round from the speedo's (its 0 points up),
	-- so its angles are 90 less; its hub is under the printed display, so
	-- only the needle's outer part shows. Its gear and clock screen sat
	-- behind the dash, and the car prints its own displays: left out.
	kamri12 = {
		dials = {
			{
				name = "Speed",
				posM = { -0.3965, 0.9169, -0.7809 },
				rotationDeg = { 5.718, -88.887, -93.111 },
				sizeM = { 0.1854, 0.035, 0.1854 },
				face = Enum.NormalId.Top,
				reads = "speedMph",
				zeroDeg = -15.6,
				degPerUnit = 1.553,
				maxDeg = -15.6 + 1.553 * 140,
				needle = { color = Color3.fromRGB(0, 0, 255), widthPx = 4, lengthPx = 78 },
				lightInfluence = 0,
			},
			{
				name = "Revs",
				posM = { -0.5027, 0.9064, -0.7732 },
				rotationDeg = { -88.699, 76.673, 103.072 },
				sizeM = { 0.11, 0.0397, 0.11 },
				face = Enum.NormalId.Top,
				reads = "rpm",
				zeroDeg = -96,
				degPerUnit = 0.01572,
				maxDeg = -96 + 0.01572 * 8000,
				needle = { color = Color3.fromRGB(0, 0, 255), widthPx = 4, lengthPx = 88, startPx = 52 },
				lightInfluence = 0,
			},
		},
	},
} :: { [string]: Dash }

CarDashes.CANVAS = CANVAS

function CarDashes.of(carId: string?): Dash?
	return if carId then CarDashes.cars[carId] else nil
end

-- A needle's turn for a reading, degrees, held on the dial.
function CarDashes.needleDeg(dial: Dial, value: number): number
	return math.clamp(dial.zeroDeg + dial.degPerUnit * math.max(value, 0), dial.zeroDeg, dial.maxDeg)
end

return CarDashes
