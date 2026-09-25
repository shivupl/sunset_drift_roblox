--!strict
-- Glow panels for lamps that cannot glow themselves. A lamp piece with a
-- store texture shows its texture whatever the material, so turning it Neon
-- does nothing; the Kruzer 80's lamps are all painted into its body texture.
-- For such a car, each spot here becomes a thin Neon panel over the lamp,
-- invisible when the lamp is off (CarLamps).
--
-- Car space, metres, before the car's scale (like CarCatalog): pos is the
-- panel's centre, size its width and height; front panels face -Z, rear +Z.
-- Measured against the body's pieces and checked from the driver's view and
-- behind. A car with plain lamp pieces (HeadLamps, TailLamps, ReverseLamps)
-- needs nothing here.
export type Spot = { pos: { number }, size: { number } }
export type Spots = { head: { Spot }?, tail: { Spot }?, reverse: { Spot }? }

local spots: { [string]: Spots } = {
	kruzer80 = {
		head = {
			{ pos = { -0.63, 1.21, -2.16 }, size = { 0.36, 0.14 } },
			{ pos = { 0.63, 1.21, -2.16 }, size = { 0.36, 0.14 } },
		},
		tail = {
			{ pos = { -0.84, 1.1, 2.42 }, size = { 0.14, 0.2 } },
			{ pos = { 0.84, 1.1, 2.42 }, size = { 0.14, 0.2 } },
		},
		reverse = {
			{ pos = { -0.84, 0.96, 2.42 }, size = { 0.14, 0.06 } },
			{ pos = { 0.84, 0.96, 2.42 }, size = { 0.14, 0.06 } },
		},
	},
}

return spots
