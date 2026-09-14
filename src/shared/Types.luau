--!strict
-- Shared data shapes. No logic beyond constructors.

export type InputState = {
	throttle: number, -- 0..1
	brake: number, -- 0..1
	steer: number, -- -1..1, + = right
	lean: number, -- -1..1, two-wheel balance axis, + = lean right (right minus left)
	leanLeft: number, -- 0/1, the left lean control by itself
	leanRight: number, -- 0/1, the right lean control by itself
	handbrake: boolean,
	kick: boolean, -- held: clutch kick (CarConfig.kick)
	twoWheel: boolean, -- mode held (a lean key, or the touch NATL button)
	exit: boolean, -- edge
	reset: boolean, -- edge
	reload: boolean, -- edge
}

export type WheelState = {
	name: string,
	grounded: boolean,
	compression: number, -- m
	load: number, -- N
	slipAngleDeg: number,
	saturated: boolean, -- spinning or locked
	locked: boolean, -- saturated by braking (wheel stopped), as opposed to spinning
	visualOmega: number, -- rad/s the wheel model turns at (spins up when driven loose, stops when locked)
	steerDeg: number,
	fx: number, -- N along wheel heading
	fy: number, -- N along wheel right
}

export type VehicleState = {
	speedMps: number,
	speedKmh: number,
	gear: number, -- -1 reverse, 1..n
	rpm: number,
	throttle: number,
	brake: number,
	steer: number,
	steerDeg: number,
	steerLock: number, -- 0..1 fraction of maxSteerDeg currently available
	lean: number,
	driftAngleDeg: number, -- angle between velocity and heading, + = velocity right of heading
	yawRateDegPerSec: number,
	spinCount: number, -- full 360s completed while sliding since the last straight
	spinProgressDeg: number, -- yaw accumulated in the current rotation
	twoWheelMode: string,
	rollDeg: number,
	rollMarginDeg: number,
	handbrake: boolean,
	kicking: boolean, -- a clutch kick is dumping or being held
	kickCount: number, -- kicks so far; effects fire on a change
	driftAssist: number,
	wheels: { WheelState },
}

local Types = {}

function Types.newInput(): InputState
	return {
		throttle = 0,
		brake = 0,
		steer = 0,
		lean = 0,
		leanLeft = 0,
		leanRight = 0,
		handbrake = false,
		kick = false,
		twoWheel = false,
		exit = false,
		reset = false,
		reload = false,
	}
end

return Types
