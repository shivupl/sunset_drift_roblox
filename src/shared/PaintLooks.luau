--!strict
-- How car paint catches the light: side variants for the owner to compare in
-- Studio (B cycles them; the LocalPlayer attribute PaintLook names one), per
-- keep-design-variations. Once the owner picks, the rest go. Each look is a
-- sun hour and a finish ladder: how each garage finish (CosmeticsConfig
-- FINISH) is painted on the cars being tried.
--
-- The owner, 2026-11-08: "improve the overall color and shading of the cars
-- ... make it look not flat ... so the sun has an effect on it". Measured that
-- day on the road in Play with five red and five white Kamris side by side:
--   * The paint was SmoothPlastic at Reflectance 0: it never shows the sky,
--     so it reads as flat colour. A clear coat (Reflectance) lays the sky
--     over it: the bright sunset on the boot and the sides facing away from
--     the sun, darker below. 0.2 read as paint; 0.45 washed red toward pink.
--   * The bigger part is the sun. The Sunset sky (SkyConfig, 17.68) puts the
--     sun 3.5 degrees up, and Roblox gives a sun that low almost no direct
--     light: a ball showed no lit side at all, and Brightness 3.5, a third
--     less OutdoorAmbient or a thinner Atmosphere changed nothing. At 17.6
--     (4.8 degrees) shading begins; at 17.5 (6 degrees) the cars have a lit
--     side, a shaded side and warm reflections, and the sky is still a
--     sunset. So the main look also moves the Sunset sky to 17.5. That moves
--     it for every car and the whole world, which is the owner's call.
--   * Tried and dropped: a warm SpotLight from the sun's side on each car
--     (it glowed and lit a patch of road), Metal (no different from
--     SmoothPlastic on these meshes, as the garage found).
--
-- The finish ladders, 2026-11-09. The first cut laid that 0.2 coat under
-- every finish as a floor, and the owner found "the factory finish ... looks
-- more like the glossy one" and asked to "make sure there is an actual
-- difference between the finishes". Measured with five red Kamris on the
-- sand at 17.5, from the sun's side and against it: under the floor, factory
-- and gloss looked the same and so did metallic and chrome (chrome's own
-- 0.15 was under the coat). SmoothPlastic's reflectance barely shows outdoors
-- (0.04 and 0.25 looked alike); Glass is what reads as shine. So each look
-- now names every finish outright:
--   factory  the car's own material, a touch of sky (0.1): solid colour
--   gloss    Glass 0.3: the colour with bright sky over the panels
--   matte    SmoothPlastic 0, 40% darker and 35% less saturated: brick-dull
--            (the garage's 20% and 30% read close to factory outdoors)
--   metallic Glass 0.35 on a 40% darker base: a deep colour with a warm sheen
--   chrome   Glass 0.7, 40% less saturated: pale tinted silver
-- All five read apart, so none was cut.
--
-- The ladders are for cars out in the world; the garage's turntable has its
-- own (GARAGE), tuned under its lights. They only reach
-- the cars in `cars` (the owner: "for testing and
-- development purposes rn we will work on only the camry"); add a car id
-- to try them on another. The sun hour reaches everything.
local PaintLooks = {}

-- How one finish is painted: the material (nil: the piece's own), the
-- reflectance (with no material, the least the piece gets: a factory piece
-- already shinier keeps its own), and the colour's value and saturation
-- lowered by darken and desaturate (0..1).
export type Finish = { material: Enum.Material?, reflectance: number?, darken: number?, desaturate: number? }

-- What CarCosmetics puts on a painted piece.
export type Paint = { material: Enum.Material, reflectance: number, darken: number, desaturate: number }

export type Look = {
	name: string,
	blurb: string,
	-- How each finish is painted out in the world, by CosmeticsConfig
	-- finish id; nil (or a finish missing): the CosmeticsConfig finish as it
	-- is (the game as it was).
	finishes: { [string]: Finish }?,
	-- The same for the garage's turntable car, under its lights.
	garage: { [string]: Finish }?,
	-- The hour each SkyConfig option is shown at instead of its own, by
	-- option id; a missing option keeps its hour.
	sunClockTime: { [string]: number },
}

PaintLooks.ATTRIBUTE = "PaintLook"

local GLASS = Enum.Material.Glass
local SMOOTH = Enum.Material.SmoothPlastic

-- The ladder measured on the sand (the header): each finish its own look.
local LADDER: { [string]: Finish } = {
	finish_stock = { reflectance = 0.1 },
	finish_gloss = { material = GLASS, reflectance = 0.3 },
	finish_matte = { material = SMOOTH, reflectance = 0, darken = 0.4, desaturate = 0.35 },
	finish_metallic = { material = GLASS, reflectance = 0.35, darken = 0.4 },
	finish_chrome = { material = GLASS, reflectance = 0.7, desaturate = 0.4 },
}

-- The garage's turntable, measured there 2026-11-09 with the spin held so
-- each finish was seen from one angle: the owner found "gloss and factory
-- looks the same" there, where gloss was Glass 0 (a faint sheen over factory
-- SmoothPlastic). The bay's walls wash Glass toward coral past about 0.05
-- (0.1 was coral, 0.3 a pink car), so gloss gets 0.04: lighter, with a
-- sheen, still red. That made the old metallic (Glass 0.05, 25% darker)
-- read like gloss, so metallic takes a much darker base: a deep, muted
-- colour with a sheen. Factory, matte and chrome keep the CosmeticsConfig
-- values tuned in that bay.
local GARAGE: { [string]: Finish } = {
	finish_gloss = { material = GLASS, reflectance = 0.04 },
	finish_metallic = { material = GLASS, reflectance = 0.06, darken = 0.45 },
}

-- Every shiny finish a step wetter, matte as it is.
local WET: { [string]: Finish } = {
	finish_stock = { reflectance = 0.2 },
	finish_gloss = { material = GLASS, reflectance = 0.4 },
	finish_matte = LADDER.finish_matte,
	finish_metallic = { material = GLASS, reflectance = 0.45, darken = 0.4 },
	finish_chrome = { material = GLASS, reflectance = 0.8, desaturate = 0.4 },
}

PaintLooks.looks = {
	main = {
		name = "Main",
		blurb = "Finishes apart, sunset sun 6 degrees up",
		finishes = LADDER,
		garage = GARAGE,
		sunClockTime = { sunset = 17.5 },
	},
	-- The car-only part: the finishes, the sky as picked.
	coat = {
		name = "Finishes only",
		blurb = "Finishes apart, the Sunset sky as it was",
		finishes = LADDER,
		garage = GARAGE,
		sunClockTime = {},
	},
	wet = {
		name = "Wet",
		blurb = "Every shiny finish wetter, sunset sun 6 degrees up",
		finishes = WET,
		garage = GARAGE,
		sunClockTime = { sunset = 17.5 },
	},
	-- Exactly what the game had.
	old = {
		name = "As before",
		blurb = "The garage finishes as they were, the Sunset sky as it was",
		sunClockTime = {},
	},
} :: { [string]: Look }

PaintLooks.order = { "main", "coat", "wet", "old" }

-- The cars the ladders are tried on.
PaintLooks.cars = { kamri07 = true } :: { [string]: boolean }

function PaintLooks.resolve(id: any): string
	if type(id) == "string" and PaintLooks.looks[id] then
		return id
	end
	return "main"
end

-- How a painted piece of this car is painted under this look and finish:
-- `finish` is the CosmeticsConfig item, `ownMaterial` and `ownReflectance`
-- the piece's factory values. `outdoors` is false for the garage's
-- turntable car, which takes the look's garage ladder: the bay's lit walls
-- wash Glass toward pink (gloss at 0.3 there was a pink car, 2026-11-09).
function PaintLooks.paint(lookId: string?, carId: string, finishId: string, finish: Finish, ownMaterial: Enum.Material, ownReflectance: number, outdoors: boolean): Paint
	local look = PaintLooks.looks[PaintLooks.resolve(lookId)]
	local ladder = if not PaintLooks.cars[carId] then nil elseif outdoors then look.finishes else look.garage
	local f = (ladder and ladder[finishId]) or finish
	local reflectance = if f.material then f.reflectance or 0 else math.max(ownReflectance, f.reflectance or 0)
	return {
		material = f.material or ownMaterial,
		reflectance = reflectance,
		darken = f.darken or 0,
		desaturate = f.desaturate or 0,
	}
end

-- The hour the sky option `skyId` is shown at under this look, or nil for
-- the option's own.
function PaintLooks.sunClockTime(lookId: string?, skyId: string): number?
	return PaintLooks.looks[PaintLooks.resolve(lookId)].sunClockTime[skyId]
end

return PaintLooks
