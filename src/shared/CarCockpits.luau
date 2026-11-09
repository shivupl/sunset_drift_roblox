--!strict
-- Where the driver sits in each car with a cabin: the first-person camera's
-- eye (CameraRig, the DRIVER view) and the steering wheel that turns with
-- the front wheels (client SteeringWheels). The owner, 2026-11-07: "work on
-- the first person view for all of them and the steering wheel moving also
-- in first person".
--
-- Car space as the catalog's offsetM: metres before the car's scale, +X
-- right, +Y up, forward -Z, from the body mount (tools/carbody/README.md).
--
-- A car with no entry has no first person: the DRIVER view is skipped on it
-- and its camera stays outside (the owner chose that for a car with no
-- cabin, over drawing the view through an empty shell; the cabin-less
-- Hatch, Pickup and Cruiser were then removed, 2026-11-08). The generated
-- Kamri, off the menu, has none.
--
-- wheel.pieces are the catalog body pieces that make the steering wheel;
-- they turn about the line through pivotM along axis, the steering column.
-- Both were fitted from the pieces' own triangles (Studio's mesh cache via
-- tools/carbody/carprobe.py, or the generated piece's buffers): axis the
-- direction the wheel's triangles spread least along (its face normal,
-- pointing back at the driver), pivotM the centre of their extent across
-- the wheel's face, so the rim turns round its own middle. Every wheel came
-- out tilted 18 to 28 degrees back from upright, as real columns are, and
-- each piece's extent matched its catalog sizeM. The diameter is the
-- fitted extent across the face.
--
-- eyeM is 0.29 m above and 0.62 m behind the wheel's centre, about where a
-- seated adult's eyes sit (a sedan's comes out 1.17 m off the road). At
-- 0.33 the roof lining filled the top 35 to 40% of the screen in the Akord,
-- Kamri SE and Krown Vik (Studio, 2026-11-07, at the view's 74 degrees).
local CarCockpits = {}

export type Wheel = {
	pieces: { string },
	pivotM: { number },
	axis: { number },
	-- The rim's middle, where hands hold it (first-person arms): half the
	-- fitted diameter less 12 mm of rim.
	radiusM: number,
}

export type Cockpit = {
	eyeM: { number },
	wheel: Wheel?,
}

local function behind(pivot: { number }, up: number, back: number): { number }
	return { pivot[1], pivot[2] + up, pivot[3] + back }
end

local EYE_UP_M = 0.29
local EYE_BACK_M = 0.62

-- lowerM: how much lower than the default this car's eye sits, where its
-- roof lining or sun visor still filled the top of the view.
local RIM_M = 0.012

local function cockpit(pieces: { string }, pivotM: { number }, axis: { number }, diameterM: number, lowerM: number?): Cockpit
	return {
		eyeM = behind(pivotM, EYE_UP_M - (lowerM or 0), EYE_BACK_M),
		wheel = { pieces = pieces, pivotM = pivotM, axis = axis, radiusM = diameterM / 2 - RIM_M },
	}
end

CarCockpits.cars = {
	tahu = cockpit({ "SteeringWheel" }, { -0.4042, 1.1233, -0.6836 }, { -0.001, 0.4277, 0.9039 }, 0.398),
	sonatta = cockpit({ "SteeringWheel" }, { -0.4034, 0.8794, -0.4032 }, { 0.0021, 0.4185, 0.9082 }, 0.414),
	-- A deep windscreen header: the lining still took the top third at the
	-- default height.
	akord = cockpit({ "SteeringWheel" }, { -0.3973, 0.8814, -0.4882 }, { 0, 0.3891, 0.9212 }, 0.385, 0.05),
	kamri12 = cockpit({ "SteeringWheel" }, { -0.4123, 0.8987, -0.5182 }, { -0.0102, 0.4696, 0.8828 }, 0.432, 0.03),
	-- Its wheel is the store kit's seven parts (rim, spokes, pad, buttons).
	kruzer300 = cockpit(
		{ "SteeringWheel", "SteeringWheel_2", "SteeringWheel_3", "SteeringWheel_4", "SteeringWheel_5", "SteeringWheel_6", "SteeringWheel_7" },
		{ -0.4242, 1.2207, -0.3195 },
		{ 0, 0.4084, 0.9128 },
		0.415
	),
	-- The older store cars predate the SteeringWheel role: their wheel is a
	-- cabin piece of its own, found by the store kit's names (the Fleet's
	-- "SteeringWheel_Meshpart", the Kruzer 80's mesh under its "SW" model)
	-- or, on the Krown Vik, the wheel-sized mesh at its "SW" pivot.
	-- Its big sun visors hang low.
	krownvik = cockpit({ "Interior_2" }, { -0.3891, 0.872, -0.2313 }, { 0, 0.3928, 0.9196 }, 0.400, 0.04),
	krownvikfleet = cockpit({ "Interior_2" }, { -0.382, 0.8945, -0.272 }, { 0.0011, 0.4135, 0.9105 }, 0.398),
	kruzer80 = cockpit({ "Interior_5" }, { -0.3954, 1.4408, -0.3207 }, { -0.0023, 0.3039, 0.9527 }, 0.289),
} :: { [string]: Cockpit }

function CarCockpits.of(carId: string?): Cockpit?
	return if carId then CarCockpits.cars[carId] else nil
end

return CarCockpits
