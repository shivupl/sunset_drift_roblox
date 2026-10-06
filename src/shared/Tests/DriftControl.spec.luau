--!strict
local DriftControl = require(script.Parent.Parent.VehicleSim.DriftControl)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local gates = {
		throwThrottleHold = 0.8,
		throwThrottleHoldFromDeg = 20,
		throwThrottleHoldGraceSeconds = 0.5,
		throwThrottleHoldKeepDeg = 10,
	}
	local function cfgWith(over: { [string]: any }): DriftControl.Config
		local c: DriftControl.Config = {
			featherSeconds = 0.3,
			featherDegPerSec = 25,
			kickDeg = 5,
			kickSeconds = 0.2,
			holdDecayDegPerSec = 0,
			holdMinDeg = 0,
			holdMaxDeg = 180,
			holdEaseDegPerSec = 30,
			liftThrow = 0,
			liftThrowSeconds = 0.5,
			liftThrowMinKmh = 60,
			liftThrowSteer = 0.5,
			liftThrowRearGrip = 1,
			liftFrom = 0.6,
			liftTo = 0.1,
			liftWindowSeconds = 0.15,
			powerOverSteer = 2,
			powerOverMinKmh = 30,
			powerOverThrow = 0,
			powerOverRearGrip = 1,
			gasHoldFromScale = 1,
			slideReliefScale = 1,
			keepThrottle = 1,
			partialDegPerSec = 0,
			kickDriveScale = 1,
			kickThrow = 0,
			kickThrowSeconds = 0.4,
			kickThrowMinKmh = 40,
			kickThrowSteer = 0.6,
			kickThrowRearGrip = 1,
			brakeThrow = 0,
			brakeThrowSeconds = 0.4,
			brakeThrowMinKmh = 50,
			brakeThrowSteer = 0.5,
			brakeThrowRearGrip = 1,
			brakeThrowFrom = 0.5,
			brakeGrowDegPerSec = 0,
			brakeGrowBrakeScale = 1,
			powerOverMaxKmh = 1000,
		}
		for k, v in over do
			(c :: any)[k] = v
		end
		return c
	end
	local function inp(over: { [string]: any }): DriftControl.Input
		local i: DriftControl.Input = { throttle = 1, steer = 0, driftAngleDeg = 30, speedKmh = 100, lever = 0, twoWheel = false }
		for k, v in over do
			(i :: any)[k] = v
		end
		return i
	end
	local dt = 1 / 60
	local function run(s: DriftControl.State, c: DriftControl.Config, i: DriftControl.Input, seconds: number): DriftControl.Output
		local out
		for _ = 1, math.max(1, math.floor(seconds / dt + 0.5)) do
			out = DriftControl.step(s, c, gates, i, dt)
		end
		return out
	end

	-- The gas hold as it was: gas past the gate and sideways arms it
	local c = cfgWith({})
	local s = DriftControl.new()
	local o = run(s, c, inp({}), 0.1)
	t.eq(o.gasHold, true, "gas and sideways arm the hold")
	t.eq(o.angleRateDeg, 0, "a plain hold moves nothing")
	o = run(s, c, inp({ throttle = 0.5 }), dt)
	t.eq(o.feathering, true, "a lift under the gate starts a feather")
	t.eq(o.gasHold, true, "the hold survives the start of a feather")
	t.near(o.angleRateDeg, 25, 1e-9, "a feather moves the angle at featherDegPerSec")
	-- a short lift then the gas back: kick
	run(s, c, inp({ throttle = 0 }), 0.2)
	o = run(s, c, inp({}), dt)
	t.eq(o.gasHold, true, "the gas back inside the feather keeps the hold")
	t.eq(o.feathering, false, "and ends the feather")
	t.near(o.angleRateDeg, -5 / 0.2, 1e-9, "the stab kicks: kickDeg over kickSeconds, away from straight")
	o = run(s, c, inp({}), 0.25)
	t.eq(o.angleRateDeg, 0, "the kick is over after kickSeconds")

	-- A long lift drops the hold, as before
	s = DriftControl.new()
	run(s, c, inp({}), 0.1)
	o = run(s, c, inp({ throttle = 0 }), 0.35)
	t.eq(o.gasHold, false, "a lift longer than featherSeconds drops the hold")
	t.eq(o.feathering, false, "and is no longer a feather")
	o = run(s, c, inp({}), dt)
	t.eq(o.angleRateDeg, 0, "gas after a dropped hold is not a kick")

	-- featherSeconds 0 is the old car: any lift drops it at once
	s = DriftControl.new()
	local old = cfgWith({ featherSeconds = 0 })
	run(s, old, inp({}), 0.1)
	o = run(s, old, inp({ throttle = 0 }), dt)
	t.eq(o.gasHold, false, "featherSeconds 0: the first lifted step drops the hold")

	-- A feather only exists while a hold does
	s = DriftControl.new()
	o = run(s, c, inp({ throttle = 0, driftAngleDeg = 5 }), 0.1)
	t.eq(o.feathering, false, "no hold, no feather")

	-- Nothing moves the angle under the lever
	s = DriftControl.new()
	run(s, c, inp({ lever = 1 }), 0.1)
	o = run(s, c, inp({ throttle = 0, lever = 1 }), dt)
	t.eq(o.angleRateDeg, 0, "under the lever a feather moves nothing")
	local decay = cfgWith({ holdDecayDegPerSec = 4 })
	s = DriftControl.new()
	o = run(s, decay, inp({ lever = 1 }), 0.1)
	t.eq(o.angleRateDeg, 0, "under the lever the hold does not decay")
	o = run(s, decay, inp({}), dt)
	t.near(o.angleRateDeg, 4, 1e-9, "on the gas alone it decays at holdDecayDegPerSec")

	-- The band: under holdMinDeg it grows, over holdMaxDeg it comes back
	local band = cfgWith({ holdMinDeg = 40, holdMaxDeg = 60, holdEaseDegPerSec = 35 })
	s = DriftControl.new()
	o = run(s, band, inp({ driftAngleDeg = 30 }), 0.1)
	t.near(o.angleRateDeg, -35, 1e-9, "under holdMinDeg the held angle grows at holdEaseDegPerSec")
	o = run(s, band, inp({ driftAngleDeg = 70 }), dt)
	t.near(o.angleRateDeg, 35, 1e-9, "over holdMaxDeg it comes back")
	o = run(s, band, inp({ driftAngleDeg = 50 }), dt)
	t.eq(o.angleRateDeg, 0, "inside the band it is left alone")
	o = run(s, band, inp({ driftAngleDeg = -30 }), dt)
	t.near(o.angleRateDeg, -35, 1e-9, "the band works the same way on either side (rate is toward straight)")
	-- A held slide swinging through straight (a transition) is grown back to the band
	o = run(s, band, inp({ driftAngleDeg = 4 }), dt)
	t.near(o.angleRateDeg, -35, 1e-9, "a held slide passing straight is grown back up to holdMinDeg")
	o = run(s, band, inp({ driftAngleDeg = 0.5 }), dt)
	t.eq(o.angleRateDeg, 0, "but not dead straight, with no side to grow it on")

	-- The lift throw: a fast lift with the wheel turned at speed, before the slide
	local lift = cfgWith({ liftThrow = 0.6, liftThrowRearGrip = 0.7, liftThrowSeconds = 0.5 })
	s = DriftControl.new()
	run(s, lift, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2 }), 0.1)
	o = run(s, lift, inp({ throttle = 0, steer = 0.8, driftAngleDeg = 2 }), dt)
	t.near(o.throw, 0.6, 1e-9, "a lift with the wheel turned throws the car")
	t.near(o.rearGrip, 0.7, 1e-9, "and cuts the rear's grip")
	o = run(s, lift, inp({ throttle = 0, steer = 0.8, driftAngleDeg = 2 }), 0.55)
	t.eq(o.throw, 0, "the throw lasts liftThrowSeconds")
	t.eq(o.rearGrip, 1, "and so does the grip cut")
	s = DriftControl.new()
	run(s, lift, inp({ throttle = 1, steer = 0.2, driftAngleDeg = 2 }), 0.1)
	o = run(s, lift, inp({ throttle = 0, steer = 0.2, driftAngleDeg = 2 }), dt)
	t.eq(o.throw, 0, "a lift with the wheel straight is not a throw")
	s = DriftControl.new()
	run(s, lift, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2, speedKmh = 40 }), 0.1)
	o = run(s, lift, inp({ throttle = 0, steer = 0.8, driftAngleDeg = 2, speedKmh = 40 }), dt)
	t.eq(o.throw, 0, "under liftThrowMinKmh a lift is not a throw")
	s = DriftControl.new()
	run(s, lift, inp({ throttle = 0.5, steer = 0.8, driftAngleDeg = 2 }), 0.1)
	o = run(s, lift, inp({ throttle = 0, steer = 0.8, driftAngleDeg = 2 }), dt)
	t.eq(o.throw, 0, "a lift from part throttle is not a throw")
	s = DriftControl.new()
	run(s, lift, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2, lever = 1 }), 0.1)
	o = run(s, lift, inp({ throttle = 0, steer = 0.8, driftAngleDeg = 2, lever = 1 }), dt)
	t.eq(o.throw, 0, "under the lever a lift is not a throw")
	s = DriftControl.new()
	run(s, cfgWith({}), inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2 }), 0.1)
	o = run(s, cfgWith({}), inp({ throttle = 0, steer = 0.8, driftAngleDeg = 2 }), dt)
	t.eq(o.throw, 0, "liftThrow 0 is off")

	-- Nothing of a lift acts under the lever (final review I2)
	s = DriftControl.new()
	run(s, c, inp({ lever = 1 }), 0.1)
	o = run(s, c, inp({ throttle = 0, lever = 1 }), dt)
	t.eq(o.gasHold, false, "a lift with the lever in drops the gas hold at once (no feather)")
	t.eq(o.feathering, false, "and is not a feather")
	s = DriftControl.new()
	run(s, c, inp({}), 0.1)
	o = run(s, c, inp({ throttle = 0, leverNow = true }), dt)
	t.eq(o.gasHold, false, "a lift in the same step as the lever is not a feather either")
	s = DriftControl.new()
	run(s, lift, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2 }), 0.1)
	o = run(s, lift, inp({ throttle = 0, steer = 0.8, driftAngleDeg = 2 }), dt)
	t.near(o.throw, 0.6, 1e-9, "armed by a lift just before the lever")
	o = run(s, lift, inp({ throttle = 0, steer = 0.8, driftAngleDeg = 2, lever = 1 }), dt)
	t.eq(o.throw, 0, "a lift throw stops when the lever goes in")
	t.eq(o.rearGrip, 1, "and so does its grip cut")
	o = run(s, lift, inp({ throttle = 0, steer = 0.8, driftAngleDeg = 2 }), dt)
	t.eq(o.throw, 0, "and does not come back after the lever")
	s = DriftControl.new()
	run(s, lift, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2 }), 0.1)
	o = run(s, lift, inp({ throttle = 0, steer = 0.8, driftAngleDeg = 2, leverNow = true }), dt)
	t.eq(o.throw, 0, "a lift in the same step as the lever is not a throw")

	-- A trigger let go over a few frames is still a lift (final review I3)
	s = DriftControl.new()
	run(s, lift, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2 }), 0.1)
	run(s, lift, inp({ throttle = 0.5, steer = 0.8, driftAngleDeg = 2 }), dt)
	o = run(s, lift, inp({ throttle = 0.05, steer = 0.8, driftAngleDeg = 2 }), dt)
	t.near(o.throw, 0.6, 1e-9, "a trigger let go over three frames (1, 0.5, 0.05) is a lift")
	s = DriftControl.new()
	run(s, lift, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2 }), 0.1)
	run(s, lift, inp({ throttle = 0.4, steer = 0.8, driftAngleDeg = 2 }), 0.3)
	o = run(s, lift, inp({ throttle = 0.05, steer = 0.8, driftAngleDeg = 2 }), dt)
	t.eq(o.throw, 0, "easing off over a third of a second is not a lift")
	local l = DriftControl.newLift()
	t.eq(DriftControl.liftStep(l, 1, 0.6, 0.1, 0.15, dt), false, "on the gas: no lift")
	t.eq(DriftControl.liftStep(l, 0, 0.6, 0.1, 0.15, dt), true, "off in one step: a lift")
	t.eq(DriftControl.liftStep(l, 0, 0.6, 0.1, 0.15, dt), false, "a lift fires once")
	t.eq(DriftControl.liftStep(DriftControl.newLift(), 0, 0.6, 0.1, 0.15, dt), false, "never on the gas: no lift")

	-- Power-over: traction control steps aside with the wheel turned past powerOverSteer
	o = DriftControl.step(DriftControl.new(), cfgWith({ powerOverSteer = 0.7 }), gates, inp({ steer = 0.8, driftAngleDeg = 0 }), dt)
	t.eq(o.tractionAside, true, "past powerOverSteer the launch and traction control step aside")
	o = DriftControl.step(DriftControl.new(), cfgWith({}), gates, inp({ steer = 1, driftAngleDeg = 0 }), dt)
	t.eq(o.tractionAside, false, "powerOverSteer above 1 never steps aside")
	-- ...and with powerOverThrow, gas and the wheel turned throw the car until the hold takes it
	local pw = cfgWith({ powerOverSteer = 0.7, powerOverThrow = 0.5, powerOverRearGrip = 0.8, powerOverMinKmh = 30 })
	s = DriftControl.new()
	o = DriftControl.step(s, pw, gates, inp({ steer = 0.8, driftAngleDeg = 2, speedKmh = 50 }), dt)
	t.near(o.throw, 0.5, 1e-9, "gas and the wheel past powerOverSteer throw the car")
	t.near(o.rearGrip, 0.8, 1e-9, "and lighten the rear")
	o = DriftControl.step(s, pw, gates, inp({ steer = 0.8, driftAngleDeg = 25, speedKmh = 50 }), dt)
	t.eq(o.gasHold, true, "once sideways the gas hold takes over")
	t.eq(o.throw, 0, "and the power throw stops")
	t.eq(o.rearGrip, 1, "with the rear's grip back")
	t.eq(DriftControl.step(DriftControl.new(), pw, gates, inp({ steer = 0.8, driftAngleDeg = 2, speedKmh = 20 }), dt).throw, 0, "not under powerOverMinKmh")
	local pwMax = cfgWith({ powerOverSteer = 0.7, powerOverThrow = 0.5, powerOverMinKmh = 30, powerOverMaxKmh = 90 })
	t.eq(DriftControl.step(DriftControl.new(), pwMax, gates, inp({ steer = 0.8, driftAngleDeg = 2, speedKmh = 100 }), dt).throw, 0, "not over powerOverMaxKmh (a highway lane change)")
	t.near(DriftControl.step(DriftControl.new(), pwMax, gates, inp({ steer = 0.8, driftAngleDeg = 2, speedKmh = 80 }), dt).throw, 0.5, 1e-9, "under it, a throw")
	t.eq(DriftControl.step(DriftControl.new(), pw, gates, inp({ steer = 0.8, driftAngleDeg = 2, throttle = 0.5 }), dt).throw, 0, "not on part throttle")
	t.eq(DriftControl.step(DriftControl.new(), pw, gates, inp({ steer = 0.5, driftAngleDeg = 2 }), dt).throw, 0, "not with the wheel short of powerOverSteer")
	t.eq(DriftControl.step(DriftControl.new(), pw, gates, inp({ steer = 0.8, driftAngleDeg = 2, lever = 1 }), dt).throw, 0, "not under the lever")
	t.eq(DriftControl.step(DriftControl.new(), cfgWith({ powerOverSteer = 0.7 }), gates, inp({ steer = 0.8, driftAngleDeg = 2 }), dt).throw, 0, "powerOverThrow 0 is off")
	-- ...and the gas hold arms lower
	s = DriftControl.new()
	o = run(s, cfgWith({ gasHoldFromScale = 0.5 }), inp({ driftAngleDeg = 12 }), dt)
	t.eq(o.gasHold, true, "gasHoldFromScale 0.5 arms the hold at half the angle")
	s = DriftControl.new()
	o = run(s, cfgWith({}), inp({ driftAngleDeg = 12 }), dt)
	t.eq(o.gasHold, false, "at scale 1 twelve degrees is under the gate")

	-- Two wheels: no gas hold, no feather
	s = DriftControl.new()
	o = run(s, c, inp({ twoWheel = true }), 0.1)
	t.eq(o.gasHold, false, "no gas hold on two wheels")

	-- Reset clears everything mid-feather and mid-kick
	s = DriftControl.new()
	run(s, c, inp({}), 0.1)
	run(s, c, inp({ throttle = 0 }), 0.1)
	DriftControl.reset(s)
	o = run(s, c, inp({ driftAngleDeg = 5 }), dt)
	t.eq(o.gasHold, false, "a reset drops the hold")
	t.eq(o.angleRateDeg, 0, "and no kick comes after it")

	-- Part throttle (a trigger): over keepThrottle an armed hold stays, and
	-- the angle tightens toward straight by partialDegPerSec at the floor,
	-- nothing at full gas. Arming still takes the gate.
	local pad = cfgWith({ keepThrottle = 0.3, partialDegPerSec = 21 })
	s = DriftControl.new()
	run(s, pad, inp({}), 0.1)
	o = run(s, pad, inp({ throttle = 0.5 }), 0.4)
	t.eq(o.gasHold, true, "part throttle over keepThrottle keeps the hold")
	t.eq(o.feathering, false, "and is not a feather")
	t.near(o.angleRateDeg, 21 * 0.5 / 0.7, 1e-9, "it tightens in proportion to how far off full gas")
	o = run(s, pad, inp({ throttle = 1 }), dt)
	t.eq(o.angleRateDeg, 0, "full gas: nothing")
	o = run(s, pad, inp({ throttle = 0.2 }), dt)
	t.eq(o.feathering, true, "under keepThrottle it is a lift")
	s = DriftControl.new()
	o = run(s, pad, inp({ throttle = 0.5 }), 0.2)
	t.eq(o.gasHold, false, "part throttle never arms a hold")
	-- ...and lets go like full gas does: straight, wheel centred, for the
	-- grace (final review: a cruise on part trigger kept it armed for good)
	s = DriftControl.new()
	run(s, pad, inp({}), 0.1)
	o = run(s, pad, inp({ throttle = 0.6, driftAngleDeg = 2 }), 0.3)
	t.eq(o.gasHold, true, "part throttle, straight, inside the grace: still held")
	o = run(s, pad, inp({ throttle = 0.6, driftAngleDeg = 2 }), 0.4)
	t.eq(o.gasHold, false, "past the grace it lets go")
	-- ...and part throttle tightens it under the band's floor
	local padBand = cfgWith({ keepThrottle = 0.3, partialDegPerSec = 21, holdMinDeg = 20, holdMaxDeg = 40 })
	s = DriftControl.new()
	run(s, padBand, inp({ driftAngleDeg = 25 }), 0.1)
	o = run(s, padBand, inp({ throttle = 0.5, driftAngleDeg = 15 }), dt)
	t.ok(o.angleRateDeg > 0, "part throttle under holdMinDeg still tightens")
	-- A trigger let go and pressed again passes through part throttle on the
	-- way: the stab still kicks (final review)
	s = DriftControl.new()
	run(s, pad, inp({}), 0.1)
	run(s, pad, inp({ throttle = 0.5 }), dt)
	run(s, pad, inp({ throttle = 0 }), 0.1)
	run(s, pad, inp({ throttle = 0.5 }), dt)
	o = run(s, pad, inp({}), dt)
	t.near(o.angleRateDeg, -5 / 0.2, 1e-9, "a trigger's stab through part throttle kicks")
	s = DriftControl.new()
	run(s, pad, inp({}), 0.1)
	run(s, pad, inp({ throttle = 0.5 }), 0.1)
	o = run(s, pad, inp({}), dt)
	t.eq(o.angleRateDeg, 0, "easing to part throttle and back is no kick")
	s = DriftControl.new()
	run(s, pad, inp({}), 0.1)
	run(s, pad, inp({ throttle = 0 }), 0.1)
	run(s, pad, inp({ throttle = 0.5 }), 0.4)
	o = run(s, pad, inp({}), dt)
	t.eq(o.angleRateDeg, 0, "a lift that lingers on part throttle past featherSeconds is no kick")
	t.eq(o.gasHold, true, "but the hold stays")

	-- The kick's drive: the stab after a feather pushes the driven wheels
	-- kickDriveScale times as hard for kickSeconds (the clutch dumped)
	local surge = cfgWith({ kickDriveScale = 1.8 })
	s = DriftControl.new()
	o = run(s, surge, inp({}), 0.1)
	t.eq(o.driveScale, 1, "no kick, no surge")
	run(s, surge, inp({ throttle = 0 }), 0.15)
	o = run(s, surge, inp({}), dt)
	t.near(o.driveScale, 1.8, 1e-9, "the stab surges the drive")
	o = run(s, surge, inp({}), 0.25)
	t.eq(o.driveScale, 1, "for kickSeconds")

	-- The clutch-kick entry: on the gas with the wheel turned, before the
	-- car is sideways, a lift and the gas back inside featherSeconds throws
	-- it (kickThrow) with the drive surging
	local ck = cfgWith({ kickThrow = 0.7, kickThrowRearGrip = 0.6, kickDriveScale = 1.5 })
	local function stab(cfg: DriftControl.Config, over: { [string]: any }, liftFor: number): DriftControl.Output
		local st = DriftControl.new()
		local function i(x: { [string]: any }): DriftControl.Input
			local base: { [string]: any } = { steer = 0.8, driftAngleDeg = 2, speedKmh = 80 }
			for k, v in over do
				base[k] = v
			end
			for k, v in x do
				base[k] = v
			end
			return inp(base)
		end
		run(st, cfg, i({ throttle = 1 }), 0.3)
		run(st, cfg, i({ throttle = 0 }), liftFor)
		return run(st, cfg, i({ throttle = 1 }), dt)
	end
	o = stab(ck, {}, 0.15)
	t.near(o.throw, 0.7, 1e-9, "a lift and stab with the wheel turned throws the car")
	t.near(o.rearGrip, 0.6, 1e-9, "lightening the rear")
	t.near(o.driveScale, 1.5, 1e-9, "with the drive surging")
	t.eq(stab(ck, {}, 0.4).throw, 0, "a lift longer than featherSeconds is not a kick")
	t.eq(stab(ck, { steer = 0.3 }, 0.15).throw, 0, "not with the wheel short of kickThrowSteer")
	t.eq(stab(ck, { speedKmh = 30 }, 0.15).throw, 0, "not under kickThrowMinKmh")
	t.eq(stab(ck, { lever = 1 }, 0.15).throw, 0, "not under the lever")
	t.eq(stab(cfgWith({}), {}, 0.15).throw, 0, "kickThrow 0 is off")
	s = DriftControl.new()
	run(s, ck, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2, speedKmh = 80 }), 0.3)
	run(s, ck, inp({ throttle = 0.75, steer = 0.8, driftAngleDeg = 2, speedKmh = 80 }), 0.1)
	o = run(s, ck, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2, speedKmh = 80 }), dt)
	t.eq(o.throw, 0, "a trigger wobbling under the gate is not a kick (final review)")
	s = DriftControl.new()
	run(s, ck, inp({ throttle = 0, steer = 0.8, driftAngleDeg = 2, speedKmh = 80 }), 0.1)
	o = run(s, ck, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2, speedKmh = 80 }), dt)
	t.eq(o.throw, 0, "the first press of the gas is not a kick")
	s = DriftControl.new()
	run(s, ck, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2, speedKmh = 80 }), 0.3)
	run(s, ck, inp({ throttle = 0, steer = 0.8, driftAngleDeg = 2, speedKmh = 80 }), 0.15)
	run(s, ck, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2, speedKmh = 80 }), dt)
	o = run(s, ck, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2, speedKmh = 80 }), 0.45)
	t.eq(o.throw, 0, "the kick throw lasts kickThrowSeconds")

	-- The brake entry: the brake pressed with the wheel turned at speed,
	-- before the car is sideways, throws it (brakeThrow), once per press
	local bk = cfgWith({ brakeThrow = 0.6, brakeThrowRearGrip = 0.5 })
	local function press(cfg: DriftControl.Config, over: { [string]: any }): DriftControl.Output
		local st = DriftControl.new()
		local base: { [string]: any } = { throttle = 1, steer = 0.8, driftAngleDeg = 2, speedKmh = 100, brake = 0 }
		for k, v in over do
			base[k] = v
		end
		run(st, cfg, inp(base), 0.1)
		base.brake = 1
		return run(st, cfg, inp(base), dt)
	end
	o = press(bk, {})
	t.near(o.throw, 0.6, 1e-9, "the brake with the wheel turned throws the car")
	t.near(o.rearGrip, 0.5, 1e-9, "lightening the rear")
	t.eq(press(bk, { steer = 0.2 }).throw, 0, "not with the wheel short of brakeThrowSteer")
	t.eq(press(bk, { speedKmh = 40 }).throw, 0, "not under brakeThrowMinKmh")
	t.eq(press(bk, { lever = 1 }).throw, 0, "not under the lever")
	t.eq(press(bk, { driftAngleDeg = 30 }).throw, 0, "not once sideways")
	t.eq(press(cfgWith({}), {}).throw, 0, "brakeThrow 0 is off")
	t.eq(press(bk, { throttle = 0 }).throw, 0, "an ordinary brake off the gas is not a throw (final review: braking into a corner)")
	s = DriftControl.new()
	run(s, bk, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2, brake = 1 }), 0.6)
	o = run(s, bk, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2, brake = 1 }), dt)
	t.eq(o.throw, 0, "a held brake throws once, for brakeThrowSeconds")
	t.eq(DriftControl.step(DriftControl.new(), bk, gates, inp({ brake = nil }), dt).throw, 0, "no brake input is no brake")

	-- The pivot: brake and gas together in a held slide grow the angle
	local pv = cfgWith({ brakeGrowDegPerSec = 20 })
	s = DriftControl.new()
	o = run(s, pv, inp({}), 0.1)
	t.eq(o.angleRateDeg, 0, "held, no brake: nothing")
	o = run(s, pv, inp({ brake = 1 }), dt)
	t.near(o.angleRateDeg, -20, 1e-9, "brake and gas together grow it at brakeGrowDegPerSec")
	t.eq(o.gasHold, true, "and keep the hold")
	o = run(s, pv, inp({ brake = 1, lever = 1 }), dt)
	t.eq(o.angleRateDeg, 0, "not under the lever")
	s = DriftControl.new()
	o = run(s, pv, inp({ brake = 1, driftAngleDeg = 5 }), 0.1)
	t.eq(o.angleRateDeg, 0, "not without a held slide")
	s = DriftControl.new()
	run(s, cfgWith({}), inp({}), 0.1)
	t.eq(run(s, cfgWith({}), inp({ brake = 1 }), dt).angleRateDeg, 0, "brakeGrowDegPerSec 0 is off")
	-- ...with the brake's force scaled down while it pivots (a light left
	-- foot; a key is a full brake)
	local pvs = cfgWith({ brakeGrowDegPerSec = 20, brakeGrowBrakeScale = 0.25 })
	s = DriftControl.new()
	o = run(s, pvs, inp({}), 0.1)
	t.eq(o.brakeScale, 1, "no brake: the whole brake")
	o = run(s, pvs, inp({ brake = 1 }), dt)
	t.near(o.brakeScale, 0.25, 1e-9, "pivoting: brakeGrowBrakeScale of the brake")
	s = DriftControl.new()
	o = run(s, pvs, inp({ brake = 1, throttle = 0, driftAngleDeg = 2 }), dt)
	t.eq(o.brakeScale, 1, "braking without a held slide is a whole brake")

	-- Reset clears the throws and the surge
	s = DriftControl.new()
	run(s, ck, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2, speedKmh = 80 }), 0.3)
	run(s, ck, inp({ throttle = 0, steer = 0.8, driftAngleDeg = 2, speedKmh = 80 }), 0.15)
	run(s, ck, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2, speedKmh = 80 }), dt)
	DriftControl.reset(s)
	o = run(s, ck, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2, speedKmh = 80 }), dt)
	t.eq(o.throw, 0, "a reset ends a kick throw")
	t.eq(o.driveScale, 1, "and its surge")

	-- The grace: the hold survives the straight moment of a transition
	s = DriftControl.new()
	run(s, c, inp({}), 0.1)
	o = run(s, c, inp({ driftAngleDeg = 2 }), 0.3)
	t.eq(o.gasHold, true, "under the gate for less than the grace, still held")
	o = run(s, c, inp({ driftAngleDeg = 2 }), 0.3)
	t.eq(o.gasHold, false, "past the grace with the wheel centred it lets go")
end
