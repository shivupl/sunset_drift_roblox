--!strict
-- How car paint catches the light: side variants for the owner to compare in
-- Studio (B cycles them; the LocalPlayer attribute PaintLook names one), per
-- keep-design-variations. Once the owner picks, the rest go.
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
-- The coat only reaches the cars in `cars` (the owner: "for testing and
-- development purposes rn we will work on only the camry"); add a car id
-- to try it on another. The sun hour reaches everything.
local PaintLooks = {}

export type Look = {
	name: string,
	blurb: string,
	-- The clear coat: the least Reflectance a painted piece gets. A finish
	-- that already reflects more keeps its own; a finish with clearcoat =
	-- false (matte) gets none.
	clearcoat: number,
	-- The hour each SkyConfig option is shown at instead of its own, by
	-- option id; a missing option keeps its hour.
	sunClockTime: { [string]: number },
}

PaintLooks.ATTRIBUTE = "PaintLook"

PaintLooks.looks = {
	main = {
		name = "Main",
		blurb = "Clear coat, sunset sun 6 degrees up",
		clearcoat = 0.2,
		sunClockTime = { sunset = 17.5 },
	},
	-- The car-only part: the paint shows the sky, the sky stays as picked.
	coat = {
		name = "Clear coat",
		blurb = "Clear coat, the Sunset sky as it was",
		clearcoat = 0.2,
		sunClockTime = {},
	},
	-- A deeper, wetter coat: more of the sky on the panels, colour paler.
	wet = {
		name = "Wet",
		blurb = "Thick clear coat, sunset sun 6 degrees up",
		clearcoat = 0.35,
		sunClockTime = { sunset = 17.5 },
	},
	-- Exactly what the game had.
	old = {
		name = "As before",
		blurb = "No clear coat, the Sunset sky as it was",
		clearcoat = 0,
		sunClockTime = {},
	},
} :: { [string]: Look }

PaintLooks.order = { "main", "coat", "wet", "old" }

-- The cars the clear coat is tried on.
PaintLooks.cars = { kamri07 = true } :: { [string]: boolean }

function PaintLooks.resolve(id: any): string
	if type(id) == "string" and PaintLooks.looks[id] then
		return id
	end
	return "main"
end

-- The Reflectance a painted piece of this car gets under this finish:
-- `own` is the reflectance the finish would give it (the finish's, or the
-- piece's factory value under the stock finish).
function PaintLooks.reflectance(lookId: string?, carId: string, finish: { clearcoat: boolean? }, own: number): number
	if not PaintLooks.cars[carId] or finish.clearcoat == false then
		return own
	end
	return math.max(own, PaintLooks.looks[PaintLooks.resolve(lookId)].clearcoat)
end

-- The hour the sky option `skyId` is shown at under this look, or nil for
-- the option's own.
function PaintLooks.sunClockTime(lookId: string?, skyId: string): number?
	return PaintLooks.looks[PaintLooks.resolve(lookId)].sunClockTime[skyId]
end

return PaintLooks
