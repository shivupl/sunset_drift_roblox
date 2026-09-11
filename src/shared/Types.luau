--!strict
-- Shared data shapes. No logic beyond constructors.

export type InputState = {
	throttle: number, -- 0..1
	brake: number, -- 0..1
	steer: number, -- -1..1, + = right
	handbrake: boolean,
	twoWheel: boolean, -- held
	clutchKick: boolean, -- true for one step on press
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
	driftAngleDeg: number, -- angle between velocity and heading, + = velocity right of heading
	yawRateDegPerSec: number,
	twoWheelMode: string,
	rollDeg: number,
	rollMarginDeg: number,
	handbrake: boolean,
	clutchKick: boolean,
	driftAssist: number,
	wheels: { WheelState },
}

local Types = {}

function Types.newInput(): InputState
	return {
		throttle = 0,
		brake = 0,
		steer = 0,
		handbrake = false,
		twoWheel = false,
		clutchKick = false,
		exit = false,
		reset = false,
		reload = false,
	}
end

return Types
