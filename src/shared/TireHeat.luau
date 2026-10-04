--!strict
-- How much a tyre smokes, from how fast its contact patch slides over the
-- road and how hot that has made it (client TireSmoke; owner, 2026-10-04: "a
-- fully comprehensive tire smoke system" that fades in and out "at
-- appropriate times (i.e. drifting, starting stopping etc.)").
--
-- Real tyre smoke is the tread's rubber decomposing and vaporising once
-- friction has heated its surface past about 200 °C; the grey in burnout
-- smoke is fine rubber dust. Heat comes from sliding: the contact patch's
-- speed over the road (sideways in a drift, spinning in a burnout, dragged in
-- a lock-up), not the slip angle itself. So:
--   - a tyre that grips (slow slide) never smokes, however hard it corners;
--   - a slide heats the tread over a moment before it smokes, so smoke builds
--     in rather than switching on;
--   - a burnout smokes with the car standing still (the tread is sliding);
--   - when grip comes back the smoke drops to wisps at once (the rubber is no
--     longer being torn off) and those fade as the tread cools;
--   - the heat is friction times slide speed, and friction follows the load
--     on the tyre, so the loaded outside rear of a drift smokes hardest;
--   - on sand or dirt there is no smoke: the tread throws the ground up as
--     dust, at once, with no heat in it (owner, 2026-10-04: smoke "a lot
--     better, more accurate and realistic").
-- Pure functions, so the spec can drive it without a car.
local TireHeat = {}

export type Params = {
	gripSlipDeg: number, -- slip angle a gripping tyre runs without its tread sliding
	gripSlipRatio: number, -- and slip ratio (spin or lock, as a share of rolling speed)
	slideStartMps: number, -- contact-patch slide speed where heating begins
	slideFullMps: number, -- and where it is heating as hard as it can
	heatPerSec: number, -- how fast a fully sliding tread heats (heat units a second)
	coolPerSec: number, -- how fast it cools: heat falls by this fraction a second
	smokeHeat: number, -- heat (0..1) where smoke starts
	wisp: number, -- the share of smoke a hot tyre keeps giving off once it grips again
}

-- The speed the tyre's contact patch slides over the road, m/s, beyond what
-- the tyre takes up while it still grips. `contactVel` is the road-plane
-- velocity of the point under the wheel, `heading` the wheel's rolling
-- direction (unit, in the road plane), and `surfaceSpeed` the tread's own
-- speed from the wheel turning (omega × r, positive rolling forward).
--
-- A tyre gripping through a corner runs a few degrees of slip angle and a
-- few percent of slip ratio without its tread sliding (the carcass twists
-- instead), and that "slip" grows with speed: 7 degrees at 150 km/h is 5 m/s
-- of sideways velocity with no smoke at all. So the grip's share, gripSlipDeg
-- sideways and gripSlipRatio along, both scaled by how fast the patch rolls,
-- is taken off first; what's left is the tread really sliding: a drift, a
-- burnout's spin, a lock-up's drag.
function TireHeat.slideSpeed(p: Params, contactVel: Vector3, heading: Vector3, surfaceSpeed: number): number
	local flat = Vector3.new(contactVel.X, 0, contactVel.Z)
	local h = Vector3.new(heading.X, 0, heading.Z)
	if h.Magnitude < 1e-6 then
		return flat.Magnitude
	end
	h = h.Unit
	local along = flat:Dot(h)
	local across = (flat - h * along).Magnitude
	local roll = math.max(math.abs(along), math.abs(surfaceSpeed))
	local lat = math.max(0, across - math.abs(along) * math.tan(math.rad(p.gripSlipDeg)))
	local long = math.max(0, math.abs(surfaceSpeed - along) - roll * p.gripSlipRatio)
	return math.sqrt(lat * lat + long * long)
end

-- The velocity, m/s in the road plane, of the tread where it leaves the road:
-- the patch's own velocity less the tread running back under the turning
-- wheel. Zero for a tyre that rolls; sideways out of a drift, back out of a
-- burnout, along with the car in a lock-up. Fresh smoke leaves the tyre this
-- way (it is the vapour of the rubber being torn off) before the air stops it.
function TireHeat.treadVelocity(contactVel: Vector3, heading: Vector3, surfaceSpeed: number): Vector3
	local flat = Vector3.new(contactVel.X, 0, contactVel.Z)
	local h = Vector3.new(heading.X, 0, heading.Z)
	if h.Magnitude < 1e-6 then
		return flat
	end
	return flat - h.Unit * surfaceSpeed
end

-- Each wheel's share of the car's weight right now (1 = an even quarter),
-- from the sim's per-wheel loads. The heat a sliding tread makes is friction
-- times slide speed, and friction follows load: in a drift the loaded outside
-- rear smokes hardest and the light inside one less; under braking, the
-- fronts. Even shares when nothing is on the ground.
function TireHeat.loadShares(loads: { number }): { number }
	local total = 0
	for _, l in loads do
		total += math.max(0, l)
	end
	local out = {}
	for i, l in loads do
		out[i] = if total > 1e-6 then math.max(0, l) * #loads / total else 1
	end
	return out
end

-- Puffs a second that lay smoke evenly along the road: one every 1 /
-- perMetre metres the contact patch travels (counted up to capMps), never
-- fewer than perSecond, since a burnout's patch stands still. A fixed rate a
-- second leaves the puffs further apart the faster the car goes, so a fast
-- drift drew a string of separate clouds (owner, 2026-10-04: "patchy", "it
-- bursts clouds and doesn't follow the wheels").
function TireHeat.puffRate(perSecond: number, perMetre: number, groundMps: number, capMps: number): number
	return math.max(perSecond, math.min(math.abs(groundMps), capMps) * perMetre)
end

-- How hard the tread is heating, 0..1, at this slide speed.
function TireHeat.drive(p: Params, slideMps: number): number
	return math.clamp((slideMps - p.slideStartMps) / (p.slideFullMps - p.slideStartMps), 0, 1)
end

-- The tread's heat after `dt` seconds sliding at `slideMps` (0 when the
-- wheel is off the ground: nothing to slide on, and the air cools it).
-- `share` is the wheel's load share (loadShares; 1 if left out).
function TireHeat.step(p: Params, heat: number, slideMps: number, grounded: boolean, dt: number, share: number?): number
	local d = if grounded then TireHeat.drive(p, slideMps) * (share or 1) else 0
	-- Heating toward the drive level, cooling in proportion to the heat: the
	-- tread settles at a heat set by how hard it slides.
	local h = heat + (p.heatPerSec * d - p.coolPerSec * heat) * dt
	return math.clamp(h, 0, 1)
end

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- How much it smokes now, 0..1: nothing below smokeHeat; above it, full
-- while sliding hard and down to `wisp` of that once it grips. A lightly
-- loaded tyre tears off less rubber, so smokes less (`share`, as in step).
function TireHeat.intensity(p: Params, heat: number, slideMps: number, grounded: boolean, share: number?): number
	-- A wheel in the air has nothing under it to scrub rubber off onto.
	local hot = smoothstep((heat - p.smokeHeat) / (1 - p.smokeHeat))
	if hot <= 0 or not grounded then
		return 0
	end
	local tear = math.min(1, TireHeat.drive(p, slideMps) * (share or 1))
	return hot * (p.wisp + (1 - p.wisp) * tear)
end

export type DustParams = {
	slideStartMps: number, -- slide speed where a tyre starts throwing dust
	slideFullMps: number, -- and where it throws all it can
	rollStartMps: number, -- driving speed where even a rolling tyre lifts a little
	rollFullMps: number,
	rollMax: number, -- the most a rolling tyre lifts (0..1)
}

-- How much dust a tyre on loose ground throws, 0..1. No heat in it: sand and
-- dirt are thrown the moment the tread slides over them (and a fast tyre
-- lifts a thin trail rolling), and stop when it stops.
function TireHeat.dust(p: DustParams, slideMps: number, speedMps: number, grounded: boolean): number
	if not grounded then
		return 0
	end
	local slide = math.clamp((slideMps - p.slideStartMps) / (p.slideFullMps - p.slideStartMps), 0, 1)
	local roll = math.clamp((speedMps - p.rollStartMps) / (p.rollFullMps - p.rollStartMps), 0, 1) * p.rollMax
	return math.max(slide, roll)
end

-- Four wheels' smoke (0..1 each) as one number for the relay: 4 bits each,
-- FL in the lowest. 0 is no smoke anywhere.
function TireHeat.pack(levels: { number }): number
	local out = 0
	for i = 1, 4 do
		local q = math.clamp(math.floor((levels[i] or 0) * 15 + 0.5), 0, 15)
		out += q * 16 ^ (i - 1)
	end
	return out
end

function TireHeat.unpack(packed: number): { number }
	local out = {}
	local n = math.clamp(math.floor(packed), 0, 65535)
	for i = 1, 4 do
		out[i] = (n % 16) / 15
		n = n // 16
	end
	return out
end

return TireHeat
