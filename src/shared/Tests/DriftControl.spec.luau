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

	-- The grace: the hold survives the straight moment of a transition
	s = DriftControl.new()
	run(s, c, inp({}), 0.1)
	o = run(s, c, inp({ driftAngleDeg = 2 }), 0.3)
	t.eq(o.gasHold, true, "under the gate for less than the grace, still held")
	o = run(s, c, inp({ driftAngleDeg = 2 }), 0.3)
	t.eq(o.gasHold, false, "past the grace with the wheel centred it lets go")
end
