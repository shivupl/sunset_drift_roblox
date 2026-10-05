--!strict
local Throw = require(script.Parent.Parent.VehicleSim.Throw)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local cfg = {
		maxSteerDeg = 38,
		steerSpeedDegPerSec = 320,
		steerReturnDegPerSec = 520,
		driftAssist = 0.15,
		speedLockCurve = { { 0, 1 }, { 40, 1 }, { 90, 0.55 }, { 150, 0.32 }, { 300, 0.28 } },
		counterSteerReliefDeg = 25,
		counterSteerRelief = 1,
		throwRelief = 1,
		flickFromLock = 0.5,
		flickWindowSeconds = 0.45,
		flickRelief = 1,
		flickRearGripMultiplier = 0.35,
		flickGripSeconds = 0.5,
		throwYawRateDegPerSec = 150,
		throwYawGain = 600,
		throwYawMaxTorque = 16000,
		throwPathFilterSeconds = 0.05,
		throwHoldGain = 3,
		throwHoldMaxTorque = 60000,
		throwHoldSettleDegPerSec = 25,
		throwMinSpeedKmh = 30,
		throwFullSpeedKmh = 70,
		throwFinishAuthority = 0.6,
		throwFinishFromDeg = 25,
		throwFinishCarryDeg = 120,
		throwThrottleHold = 0.8,
		throwThrottleHoldFromDeg = 20,
		throwThrottleHoldGraceSeconds = 0.5,
		throwThrottleHoldKeepDeg = 10,
		slideYawDamping = 130,
	}
	local function inp(over: { [string]: any }): Throw.Input
		local i: Throw.Input = {
			steer = 0,
			permission = 0,
			flick = false,
			driftAngleDeg = 0,
			yawRateDeg = 0,
			pathRateDeg = 0,
			speedKmh = 100,
		}
		for k, v in over do
			(i :: any)[k] = v
		end
		return i
	end

	-- No permission, straight: plain damping against the yaw rate
	local st = Throw.new()
	t.near(Throw.step(st, cfg, inp({ yawRateDeg = 10 })), -1300, 1e-9, "damping opposes yaw with nothing in")
	t.near(Throw.step(st, cfg, inp({ yawRateDeg = 10, driftAngleDeg = 20 })), -1300, 1e-9, "still damping under throwFinishFromDeg")

	-- Lever in, full lock: the target is the throw rate on top of the path's turn, capped at the onset cap
	st = Throw.new()
	local onset = Throw.step(st, cfg, inp({ steer = 1, permission = 1 }))
	t.near(onset, 16000, 1e-9, "full lock from straight kicks at the onset cap")
	local held = Throw.step(st, cfg, inp({ steer = 1, permission = 1, yawRateDeg = 150 }))
	t.near(held, 0, 1e-9, "at the throw rate there is nothing left to add")
	local curve = Throw.step(st, cfg, inp({ steer = 1, permission = 1, yawRateDeg = 160, pathRateDeg = 10 }))
	t.near(curve, 0, 1e-9, "on a curving path the target rides on the path's own turn rate")
	local over = Throw.step(st, cfg, inp({ steer = 1, permission = 1, yawRateDeg = 200 }))
	t.ok(over < 0, "past the target it pulls back: no runaway")
	local half = Throw.step(st, cfg, inp({ steer = 0.5, permission = 1, yawRateDeg = 75 }))
	t.near(half, 0, 1e-9, "half lock is half the rate")
	local counter = Throw.step(st, cfg, inp({ steer = -1, permission = 1, yawRateDeg = 150 }))
	t.near(counter, -16000, 1e-9, "counter-steer under the lever reverses at the cap")

	-- Speed fade
	t.near(Throw.speedFactor(cfg, 30), 0, 1e-9, "no authority at the floor")
	t.near(Throw.speedFactor(cfg, 50), 0.5, 1e-9, "half way between the gates")
	t.near(Throw.step(st, cfg, inp({ steer = 1, permission = 1, speedKmh = 20 })), 0, 1e-9, "a parking-lot pull does nothing")
	-- ...lifted past 90 degrees with a permission in, so a starved spin finishes
	local starved = Throw.step(st, cfg, inp({ steer = 1, permission = 1, speedKmh = 40, driftAngleDeg = -120 }))
	t.near(starved, 16000 * 0.6, 1e-9, "past 90 the lever keeps finishAuthority however far the speed has faded")
	t.near(Throw.step(st, cfg, inp({ steer = 1, permission = 1, speedKmh = 20, driftAngleDeg = -120 })), 0, 1e-9, "but under throwMinSpeedKmh nothing finishes either")

	-- Wheel centred under the lever: track while the momentum settles, then hold
	st = Throw.new()
	Throw.step(st, cfg, inp({ steer = 1, permission = 1, yawRateDeg = 150 }))
	local catchTorque = Throw.step(st, cfg, inp({ steer = 0, permission = 1, yawRateDeg = 150, driftAngleDeg = -30 }))
	t.eq(st.holdLatched, false, "still moving: not latched")
	t.near(st.holdAngleDeg, -30, 1e-9, "the hold tracks the drift while it settles")
	t.near(catchTorque, -60000, 1e-9, "the catch uses the hold cap against the momentum")
	Throw.step(st, cfg, inp({ steer = 0, permission = 1, yawRateDeg = 5, driftAngleDeg = -45 }))
	t.eq(st.holdLatched, true, "settled: latched")
	t.near(st.holdAngleDeg, -45, 1e-9, "at the angle it settled on")
	local drifting = Throw.step(st, cfg, inp({ steer = 0, permission = 1, yawRateDeg = 0, driftAngleDeg = -55 }))
	-- error = -45 - (-55) = +10 -> wants negative yaw -> target -30 -> torque negative
	t.near(drifting, 600 * -30, 1e-9, "off the hold angle it asks for holdGain deg/s per degree back")
	t.near(st.holdAngleDeg, -45, 1e-9, "and keeps the hold angle")
	Throw.step(st, cfg, inp({ steer = 0.3, permission = 1 }))
	t.eq(st.holdLatched, false, "any steer releases the latch")

	-- Hands off past throwFinishFromDeg: the short way back
	st = Throw.new()
	local back = Throw.step(st, cfg, inp({ driftAngleDeg = 60, yawRateDeg = 0 }))
	t.near(back, 16000, 1e-9, "a 60-degree bail comes back at the onset cap: positive drift wants positive yaw")
	t.near(Throw.step(st, cfg, inp({ driftAngleDeg = 60, yawRateDeg = 0, speedKmh = 40 })), 16000 * 0.6, 1e-9, "finishAuthority is a floor under the speed fade, not a ceiling")
	local backLeft = Throw.step(st, cfg, inp({ driftAngleDeg = -60, yawRateDeg = 0 }))
	t.ok(backLeft < 0, "and the other way round")
	local momentum = Throw.step(st, cfg, inp({ driftAngleDeg = -60, yawRateDeg = 150 }))
	t.ok(momentum < 0, "below carryDeg the momentum is fought, not kept")
	local carry = Throw.step(st, cfg, inp({ driftAngleDeg = -150, yawRateDeg = 150 }))
	t.near(carry, -16000, 1e-9, "nearly backwards and rotating: carry on round, slowed toward the finish rate")
	t.near(Throw.step(st, cfg, inp({ driftAngleDeg = -150, yawRateDeg = 90 })), 0, 1e-9, "at the finish rate it is left alone")
	local stopped = Throw.step(st, cfg, inp({ driftAngleDeg = -150, yawRateDeg = 0 }))
	t.ok(stopped < 0, "nearly backwards and stopped: the short way")
	t.near(Throw.step(st, cfg, inp({ driftAngleDeg = 60, speedKmh = 20 })), -0, 1e-9, "too slow to finish: nothing")

	-- Hands on with no permission is the driver's: the controller stays out
	-- and the tyres do the work under plain damping.
	t.near(Throw.step(st, cfg, inp({ driftAngleDeg = 60, steer = -1, yawRateDeg = 20 })), -2600, 1e-9, "wheel turned, nothing in: damping only")
	t.near(Throw.step(st, cfg, inp({ driftAngleDeg = 150, steer = -1, yawRateDeg = 20 })), -16000, 1e-9, "past 90 the wheel steers the finish")

	-- The flick window is a permission on its own
	st = Throw.new()
	t.near(Throw.step(st, cfg, inp({ steer = 1, flick = true })), 16000, 1e-9, "flick with no lever still throws")
	-- angleRateDeg moves the latched hold: + toward straight
	st = Throw.new()
	Throw.step(st, cfg, inp({ permission = 1, driftAngleDeg = 30, yawRateDeg = 0 }))
	t.eq(st.holdLatched, true, "settled: latched at 30")
	Throw.step(st, cfg, inp({ permission = 1, driftAngleDeg = 30, angleRateDeg = 60, dt = 0.5 }))
	t.near(st.holdAngleDeg, 0 + 30 - 30, 1e-9, "60 deg/s toward straight for 0.5 s takes 30 off the hold")
	st = Throw.new()
	Throw.step(st, cfg, inp({ permission = 1, driftAngleDeg = -30 }))
	Throw.step(st, cfg, inp({ permission = 1, driftAngleDeg = -30, angleRateDeg = -20, dt = 0.5 }))
	t.near(st.holdAngleDeg, -40, 1e-9, "a negative rate grows the hold, on the left side too")
	st = Throw.new()
	Throw.step(st, cfg, inp({ permission = 1, driftAngleDeg = 10 }))
	Throw.step(st, cfg, inp({ permission = 1, driftAngleDeg = 10, angleRateDeg = 100, dt = 0.5 }))
	t.eq(st.holdAngleDeg, 0, "toward straight never crosses through it")
	-- with the wheel turned it rides on the rate target
	st = Throw.new()
	local plain = Throw.step(st, cfg, inp({ permission = 1, steer = 0.5, driftAngleDeg = 30, yawRateDeg = 75 }))
	local pushed = Throw.step(st, cfg, inp({ permission = 1, steer = 0.5, driftAngleDeg = 30, yawRateDeg = 75, angleRateDeg = 10 }))
	t.near(pushed - plain, 600 * 10, 1e-6, "with the wheel turned, the rate adds to the target (drift + side)")
	local pushedL = Throw.step(st, cfg, inp({ permission = 1, steer = -0.5, driftAngleDeg = -30, yawRateDeg = -75, angleRateDeg = 10 }))
	t.near(pushedL, -6000, 1e-6, "mirrored on the left")
	-- absent fields are today's controller
	st = Throw.new()
	t.near(Throw.step(st, cfg, inp({ permission = 1, steer = 1 })), 16000, 1e-9, "no angleRateDeg: unchanged")
end
