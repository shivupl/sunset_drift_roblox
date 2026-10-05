--!strict
local Line = require(script.Parent.Parent.VehicleSim.Line)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local G = 9.81
	local function cfgWith(over: { [string]: any }): Line.Config
		local c: Line.Config = {
			hold = 1,
			steerG = 0.5,
			leverSteerShare = 0,
			maxG = 1,
			fromDeg = 8,
			fullDeg = 16,
			minKmh = 30,
			fullKmh = 50,
			intoRelease = 0,
			leverHold = 1,
			leverMinKmh = 30,
			leverFullKmh = 50,
		}
		for k, v in over do
			(c :: any)[k] = v
		end
		return c
	end
	local function inp(over: { [string]: any }): Line.Input
		local i: Line.Input = {
			held = true,
			lever = false,
			steer = 0,
			driftAngleDeg = 30,
			speedKmh = 100,
			tyreLatAccel = -8,
			gravity = G,
		}
		for k, v in over do
			(i :: any)[k] = v
		end
		return i
	end

	-- Nothing unless a slide is held
	t.eq(Line.accel(cfgWith({}), inp({ held = false })), 0, "no held slide, no line")

	-- Wheel centred: the slide's own curve is taken out, hold of it
	t.near(Line.accel(cfgWith({}), inp({})), 8, 1e-6, "full hold cancels the tyres' curve")
	t.near(Line.accel(cfgWith({ hold = 0.75 }), inp({})), 6, 1e-6, "a partial hold takes out its share")
	t.near(Line.accel(cfgWith({}), inp({ tyreLatAccel = 5 })), -5, 1e-6, "either side")
	t.eq(Line.accel(cfgWith({ hold = 0, steerG = 0 }), inp({ steer = 1 })), 0, "hold 0 and steerG 0 is off")

	-- Never more than maxG
	t.near(Line.accel(cfgWith({}), inp({ tyreLatAccel = -15 })), G, 1e-6, "capped at maxG")
	t.near(Line.accel(cfgWith({ maxG = 0.5 }), inp({ tyreLatAccel = 15 })), -0.5 * G, 1e-6, "capped either way")

	-- The wheel aims it: full steer asks for steerG toward the steered side
	t.near(Line.accel(cfgWith({}), inp({ steer = 1, tyreLatAccel = 0 })), 0.5 * G, 1e-6, "steer right goes right")
	t.near(Line.accel(cfgWith({}), inp({ steer = -0.5, tyreLatAccel = 0 })), -0.25 * G, 1e-6, "half left, half the g")
	t.near(Line.accel(cfgWith({ maxG = 2 }), inp({ steer = 1, tyreLatAccel = -8 })), 8 + 0.5 * G, 1e-6, "steer on top of the hold")
	t.near(Line.accel(cfgWith({ hold = 0.5 }), inp({ steer = 1, tyreLatAccel = 2 })), 0.5 * G - 1, 1e-6, "steer with a partial hold")

	-- Under the lever the wheel is the spin's, so only leverSteerShare of it aims
	t.near(Line.accel(cfgWith({}), inp({ lever = true, steer = 1, tyreLatAccel = -8 })), 8, 1e-6, "a spin goes straight on")
	t.near(Line.accel(cfgWith({ leverSteerShare = 0.5 }), inp({ lever = true, steer = 1, tyreLatAccel = 0 })), 0.25 * G, 1e-6, "leverSteerShare")

	-- Fades in with the angle, and with speed
	t.eq(Line.accel(cfgWith({}), inp({ driftAngleDeg = 5 })), 0, "under fromDeg, nothing")
	t.near(Line.accel(cfgWith({}), inp({ driftAngleDeg = -12 })), 4, 1e-6, "halfway in, half (sign of the angle does not matter)")
	t.near(Line.accel(cfgWith({}), inp({ driftAngleDeg = 170 })), 8, 1e-6, "through a spin, full")
	t.eq(Line.accel(cfgWith({}), inp({ speedKmh = 20 })), 0, "too slow, nothing")
	t.near(Line.accel(cfgWith({}), inp({ speedKmh = 40 })), 4, 1e-6, "halfway up the speed, half")

	-- Steering into the slide (the wheel against the drift's sign) lets the
	-- hold go by intoRelease, so a drift steered into a corner takes it:
	-- the tyres' own curve comes back on top of steerG.
	local rel = cfgWith({ intoRelease = 1 })
	t.near(Line.accel(rel, inp({ steer = -1 })), -0.5 * G, 1e-6, "full into: no hold, only steerG")
	t.near(Line.accel(rel, inp({ steer = -0.5 })), -0.25 * G + 4, 1e-6, "half into: half the hold")
	t.near(Line.accel(rel, inp({ steer = 1, driftAngleDeg = -30, tyreLatAccel = 8 })), 0.5 * G, 1e-6, "mirrored")
	t.near(Line.accel(rel, inp({ steer = 0.5, tyreLatAccel = -2 })), 0.25 * G + 2, 1e-6, "counter-steer keeps the whole hold")

	-- The lever has its own hold, from straight (a spin's onset is where its
	-- path turns), and its own speeds (a city handbrake turn stays a turn)
	local lev = cfgWith({ leverHold = 0.5, leverMinKmh = 60, leverFullKmh = 90, intoRelease = 1 })
	t.near(Line.accel(lev, inp({ lever = true, driftAngleDeg = 2 })), 4, 1e-6, "under the lever, from straight, its own hold")
	t.near(Line.accel(lev, inp({ lever = true, steer = -1 })), 4, 1e-6, "the lever's hold is not released by the wheel")
	t.near(Line.accel(lev, inp({ lever = true, speedKmh = 75 })), 2, 1e-6, "halfway up the lever's speeds, half")
	t.eq(Line.accel(lev, inp({ lever = true, speedKmh = 55 })), 0, "a city handbrake turn: nothing")
end
