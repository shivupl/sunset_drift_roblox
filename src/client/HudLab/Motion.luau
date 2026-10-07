--!strict
-- Motion for the HUD variants (hud-variants, 2026-10-07; the owner: "i need
-- a way more alive UI"). Everything on those HUDs moves through these: a
-- damped spring that chases a target (needles, pops, pedals), a rolling
-- counter that eases a number toward its value, and a shake.
local Motion = {}

export type Spring = { x: number, v: number, freq: number, damp: number }

-- freq in Hz (how fast it answers), damp 1 = critically damped (no
-- overshoot), under 1 overshoots and settles: a needle at 0.55 swings past
-- and back, which reads as a real gauge.
function Motion.spring(x: number, freq: number, damp: number): Spring
	return { x = x, v = 0, freq = freq, damp = damp }
end

-- Steps the spring toward target over dt, in 1/120 s substeps so a long
-- frame does not explode it.
function Motion.step(s: Spring, target: number, dt: number): number
	local w = 2 * math.pi * s.freq
	local n = math.max(1, math.ceil(dt * 120))
	local h = dt / n
	for _ = 1, n do
		local a = w * w * (target - s.x) - 2 * s.damp * w * s.v
		s.v += a * h
		s.x += s.v * h
	end
	return s.x
end

-- A kick: adds velocity, so a spring resting at 1 pops out and back.
function Motion.kick(s: Spring, v: number)
	s.v += v
end

-- A counter that rolls toward its value: fast enough to keep up with a
-- slide's points, slow enough that the digits visibly spin. rate is 1/s.
export type Roller = { shown: number }

function Motion.roller(): Roller
	return { shown = 0 }
end

function Motion.roll(r: Roller, target: number, dt: number, rate: number): number
	if target < r.shown then
		r.shown = target -- a new slide starts from zero at once
	else
		local step = (target - r.shown) * (1 - math.exp(-rate * dt))
		r.shown = math.min(target, r.shown + math.max(step, 1))
	end
	return r.shown
end

-- A random offset in pixels, amp at most, for a shaking readout.
function Motion.shake(amp: number): UDim2
	if amp <= 0 then
		return UDim2.new()
	end
	return UDim2.fromOffset((math.random() * 2 - 1) * amp, (math.random() * 2 - 1) * amp)
end

-- Comma-grouped integer: 12,340.
function Motion.comma(n: number): string
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

return Motion
