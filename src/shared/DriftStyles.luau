--!strict
-- Drift modes, per drivetrain. The owner, 2026-10-05: "I want the drift
-- style to differ slightly depending on the drivestyle of the vehicle
-- (awd,rwd,fwd,etc) ... implement a couple different styles (multiple for
-- each) that i can test and try out in game", and then (the drift
-- overhaul) "a full overhaul and perfection of the drifting system,
-- different modes I can try different styles for each drivetype. all
-- research based ... from throlle bursts to stable trifting and the
-- standdard hajwala 360s". Research and design in docs/superpowers/specs/
-- 2026-10-05-drift-overhaul-*.md.
--
-- A car's catalog entry says which wheels it drives (drivetrain.layout).
-- A mode is a tyre in the garage (CosmeticsConfig, garage-tyres-flames;
-- the owner, 2026-10-05: "make the differnt driftmodes we made different
-- tire options in the garage instead of drift options in the car menu. by
-- default start all at classic"): the car drives the mode of the tyre
-- fitted to it, Classic until one is bought, and in Studio O cycles them
-- (client DriftStyle). Each layout has Classic, the drift-feel default,
-- and three modes. A mode is a partial CarConfig deep-merged over the car's
-- own config: the line, the pedals, the dial, the torque split, never a
-- key a catalog car tunes (DriftStyles.spec), so each car keeps its own
-- character. The lever's 360 is the same move on every mode; a mode only
-- sets how fast it comes round (steering.throwYawRateDegPerSec) and the
-- line sends it straight on.
local DriftStyles = {}

export type Style = {
	name: string,
	layout: string, -- "RWD" | "FWD" | "AWD"
	blurb: string, -- one line for the garage's tyre row
	tuning: { [string]: any },
}

DriftStyles.layouts = { "RWD", "FWD", "AWD" }
DriftStyles.layoutName = {
	RWD = "Rear-wheel drive",
	FWD = "Front-wheel drive",
	AWD = "All-wheel drive",
}

-- Front-drive and all-wheel styles give the driven fronts the rear's drive
-- grip (tires.front.longitudinalGrip, the rear's 1.9). All-wheel drive's
-- launch then measured the same as rear drive's on the Batrol (0-100 5.19
-- against 5.25 s). Front drive launches slower (weight leaves the fronts):
-- the Kamri's 0-100 is 4.16 s against 3.69. 2.3 brought it to 3.9, but the
-- fronts then scrubbed so hard in a spin that the lever 360 took 3.42 s
-- against 2.52 and a hands-off catch 1.25 s (Play, 2026-10-05): the tricks
-- win, front drive keeps its slower launch.
local FRONT_DRIVE_GRIP = 1.9

-- The line (CarConfig.line, VehicleSim/Line.luau) every new mode shares:
-- a held slide runs straight on down the highway with the wheel centred,
-- the wheel aims it across the lanes, held into the slide it takes a
-- corner, and a highway 360 goes straight on (the owner, 2026-10-05:
-- "make sure its easy to control the sideway drifting within the highway
-- boundries").
local LINE = { hold = 0.9, steerG = 0.35, intoRelease = 1, leverHold = 1 }

-- Part throttle (a trigger) keeps a hold over 0.35 and tightens it toward
-- straight the further off full gas: the gamepad's throttle angle.
local PAD_KEEP = 0.35

DriftStyles.styles = {
	-- REAR DRIVE. Research: docs/superpowers/specs/
	-- 2026-10-05-drift-overhaul-research.md ("the throttle sets the angle,
	-- the wheel sets the path").
	hajwala = {
		name = "Hajwala",
		layout = "RWD",
		blurb = "Hold the gas and the slide widens to 40; lift to tighten it. Steer to aim it down the road. Space spins.",
		tuning = {
			drivetrain = { layout = "RWD" },
			line = LINE,
			-- The research's Power Hold: gas grows the angle at 12 deg/s to the
			-- band's top (slow build-up fails least, 10-20 deg/s), a lift
			-- shrinks it at 40, the stab kicks 8 with a surge. Steering into it
			-- turns at half the rate and stops at 45; counter-steer keeps the
			-- whole rate, so a transition swings through.
			drift = {
				holdDecayDegPerSec = -12, holdMinDeg = 20, holdMaxDeg = 40, holdEaseDegPerSec = 30,
				featherDegPerSec = 40, kickDeg = 8, kickDriveScale = 1.5,
				dialMaxDeg = 45, dialIntoScale = 0.5,
				keepThrottle = PAD_KEEP, partialDegPerSec = 30,
			},
		},
	},
	power = {
		name = "Kick",
		layout = "RWD",
		blurb = "Gas and lock break it loose. Double-tap the gas to kick it out; every stab kicks wider. Full lock on the gas spins it.",
		tuning = {
			drivetrain = { layout = "RWD" },
			-- A looser line than the others: 0.85 lets a held slide drift 13 m
			-- in 4 s toward its nose (0.75 was 21 m; Hajwala's 0.9 is 9).
			line = { hold = 0.85, steerG = 0.3, intoRelease = 1, leverHold = 1 },
			-- Power-over from 30 to 90 km/h (a low-gear move; over it a full-key
			-- lane change must not throw the car), the clutch-kick entry at any
			-- speed (a lift and the gas back with the wheel turned: FR Legends'
			-- double tap, hajwala's neutral drop), and a 14-degree stab with the
			-- drive doubled for a quarter second (the clutch dumped: +8-15
			-- degrees, research). Gas grows it at 15 deg/s to 45. No ceiling:
			-- full lock on the gas comes round (the gas 360).
			drift = {
				powerOverSteer = 0.7, powerOverThrow = 0.5, powerOverRearGrip = 0.8, powerOverMaxKmh = 90,
				gasHoldFromScale = 0.5,
				kickThrow = 0.5, kickThrowSeconds = 0.3, kickThrowRearGrip = 0.7,
				holdDecayDegPerSec = -15, holdMinDeg = 25, holdMaxDeg = 45, holdEaseDegPerSec = 30,
				featherDegPerSec = 45, kickDeg = 14, kickSeconds = 0.25, kickDriveScale = 2,
				keepThrottle = PAD_KEEP, partialDegPerSec = 35,
			},
		},
	},
	angle = {
		name = "High Angle",
		layout = "RWD",
		blurb = "Deep slides, 45 to 55 degrees, that carry their speed. Lift to bring it in; steer to aim it.",
		tuning = {
			drivetrain = { layout = "RWD" },
			line = LINE,
			-- The research's Long Angle: 45-55 (MARTY 45, TRI peaks past 55),
			-- assisted, since 38 degrees of lock cannot hold much past 45 on
			-- a straight by itself. More slide momentum carries the speed.
			drift = {
				holdDecayDegPerSec = -10, holdMinDeg = 45, holdMaxDeg = 55, holdEaseDegPerSec = 35,
				-- A lift brings it in at 55 deg/s for a quarter second before
				-- the catch: from 55 degrees, 0.90-0.97 s to straight (35 deg/s
				-- and 0.3 s: 1.01). A 0.6 s press swings it through: a chain of
				-- 41-53 degrees inside 3 m of the line (Play, 2026-10-05).
				featherSeconds = 0.25, featherDegPerSec = 55,
				kickDeg = 10, kickDriveScale = 1.5, slideReliefScale = 1.3,
				dialMaxDeg = 60, dialIntoScale = 0.6,
				keepThrottle = PAD_KEEP, partialDegPerSec = 25,
			},
		},
	},
	classic = {
		name = "Classic",
		layout = "RWD",
		blurb = "The everyday tyre: the wheel sets the angle, the slide follows the tyres. Space spins.",
		tuning = { drivetrain = { layout = "RWD" } },
	},

	-- FRONT DRIVE. A front-drive car holds a slide only with the rear braked
	-- (the lever), and the gas pulls it straight with no countersteer
	-- (Velenis; research 2026-10-05).
	tafheet = {
		name = "Tafheet",
		layout = "FWD",
		blurb = "The Kamri way: throw it and hold the lever to keep it sideways. Let go and the gas pulls it straight; a lift swings the tail.",
		tuning = {
			drivetrain = { layout = "FWD" },
			tires = { front = { longitudinalGrip = FRONT_DRIVE_GRIP } },
			line = { hold = 0.95, steerG = 0.35, intoRelease = 1, leverHold = 1 },
			-- On the gas alone the fronts pull it straight at 15 deg/s (research
			-- 15-25); a lift swings the tail 10 deg/s (lift-off oversteer); the
			-- stab pulls 8 in.
			drift = {
				holdDecayDegPerSec = 15, holdMaxDeg = 50, holdEaseDegPerSec = 30,
				featherDegPerSec = -10, kickDeg = -8, kickDriveScale = 1.3,
				dialMaxDeg = 50, dialIntoScale = 0.5,
			},
			-- Front drive comes out of a slide still yawing outward: the
			-- hands-off catch's authority from 15 degrees (drift-feel, Play).
			steering = { throwFinishFromDeg = 15 },
		},
	},
	liftoff = {
		name = "Lift-Off",
		layout = "FWD",
		blurb = "No lever needed: lift with the wheel turned and the tail comes round. Short slides; gas pulls it out.",
		tuning = {
			drivetrain = { layout = "FWD" },
			tires = { front = { longitudinalGrip = FRONT_DRIVE_GRIP } },
			line = LINE,
			-- Lift at 60 km/h or more with the wheel past half: 0.3 for 0.4 s
			-- with the rear at 0.6 (a full-key lift at 100 peaks 32 degrees,
			-- Play, 2026-10-05). Gas pulls it straight at 12 deg/s; slides are
			-- short by nature.
			drift = {
				liftThrow = 0.3, liftThrowSeconds = 0.4, liftThrowRearGrip = 0.6,
				holdDecayDegPerSec = 12, holdMaxDeg = 35, holdEaseDegPerSec = 30,
				featherDegPerSec = -10, kickDeg = -8,
				dialMaxDeg = 40, dialIntoScale = 0.5,
			},
			steering = { throwFinishFromDeg = 15 },
		},
	},
	pivot = {
		name = "Pivot",
		layout = "FWD",
		blurb = "Left-foot braking: on the gas, tap the brake turning in to throw it; hold both to swing it wider.",
		tuning = {
			drivetrain = { layout = "FWD" },
			tires = { front = { longitudinalGrip = FRONT_DRIVE_GRIP } },
			line = LINE,
			-- The brake tapped on the gas with the wheel turned throws the tail
			-- (weight onto the nose; off the gas it is only a brake); brake and
			-- gas together pivot it wider at 35 deg/s on a quarter of the brake
			-- (25 netted +5 in half a second against the gas's pull, losing 2
			-- km/h); the gas alone pulls it in (Play, 2026-10-05).
			drift = {
				brakeThrow = 0.5, brakeThrowSeconds = 0.35, brakeThrowRearGrip = 0.6,
				brakeGrowDegPerSec = 35, brakeGrowBrakeScale = 0.25,
				holdDecayDegPerSec = 10, holdMaxDeg = 45, holdEaseDegPerSec = 30,
				featherDegPerSec = 0, kickDeg = -6,
				dialMaxDeg = 50, dialIntoScale = 0.5,
			},
			steering = { throwFinishFromDeg = 15 },
		},
	},
	classicFwd = {
		name = "Classic",
		layout = "FWD",
		blurb = "The everyday tyre: throw it on the lever and hold it on the gas.",
		tuning = {
			drivetrain = { layout = "FWD" },
			tires = { front = { longitudinalGrip = FRONT_DRIVE_GRIP } },
			drift = { featherSeconds = 0.25, featherDegPerSec = 0, kickDeg = -6, holdDecayDegPerSec = 2 },
			steering = { throwFinishFromDeg = 15 },
		},
	},

	-- ALL-WHEEL DRIVE. The strategy flips at about 25:75 front to rear
	-- (Eberhart, TU Wien): above it gas widens a slide like rear drive,
	-- under it gas straightens it and adds speed.
	rally = {
		name = "Rally",
		layout = "AWD",
		blurb = "Shallow four-wheel slides that drive forward: gas straightens and pulls you on, a lift rotates it. Flick it in, or brake on the gas.",
		tuning = {
			drivetrain = { layout = "AWD", frontShare = 0.45 },
			tires = { front = { longitudinalGrip = FRONT_DRIVE_GRIP }, slipModel = { flickRearGripMultiplier = 0.55 } },
			line = LINE,
			-- Band 15-30: gas pulls it in at 6 deg/s to 15 and holds it there,
			-- driving forward (with no floor the slide was gone in 2 s, 97 to
			-- 122 km/h: a flick, not a slide); a 0.2 s lift rotates it 5 (the
			-- research's +5); the stab drives forward (-4). The brake entry is
			-- the rally pendulum's left-foot brake, on the gas only: braking
			-- into a corner off the gas threw the car (final review). Play,
			-- 2026-10-05.
			drift = {
				holdDecayDegPerSec = 6, holdMinDeg = 15, holdMaxDeg = 30, holdEaseDegPerSec = 25,
				featherDegPerSec = -25, kickDeg = -4, kickDriveScale = 1.4, slideReliefScale = 1.4,
				-- On the gas the brake slows the car less, so the throw is
				-- stronger: 0.6 for 0.4 s at 0.5 takes it to 32 from 100 (0.45 at
				-- 0.6: 17, short of the gas hold's 20).
				brakeThrow = 0.6, brakeThrowSeconds = 0.4, brakeThrowRearGrip = 0.5,
				dialMaxDeg = 35, dialIntoScale = 0.5,
			},
			-- The 360 a touch slower (2.8 s: the fronts keep pulling), and the
			-- hands-off catch's authority from 15 degrees, as front drive: from
			-- a 24-degree slide held at its floor the catch took 1.3 s.
			steering = { throwYawRateDegPerSec = 140, throwFinishFromDeg = 15 },
		},
	},
	driftmode = {
		name = "Drift Mode",
		layout = "AWD",
		blurb = "The factory drift mode: drive to the rear, so gas widens it like rear drive, and the fronts catch it sooner.",
		tuning = {
			drivetrain = { layout = "AWD", frontShare = 0.2 },
			tires = { front = { longitudinalGrip = FRONT_DRIVE_GRIP } },
			line = LINE,
			-- 20:80 (Focus RS 30:70, GR Yaris 30:70, E63 0:100): band 25-40,
			-- gas grows it at 10 deg/s, the stab +7; the fronts' pull catches
			-- it from 20 degrees.
			drift = {
				holdDecayDegPerSec = -10, holdMinDeg = 25, holdMaxDeg = 40, holdEaseDegPerSec = 30,
				featherDegPerSec = 40, kickDeg = 7, kickDriveScale = 1.5,
				dialMaxDeg = 45, dialIntoScale = 0.5,
				keepThrottle = PAD_KEEP, partialDegPerSec = 25,
			},
			steering = { throwFinishFromDeg = 20 },
		},
	},
	tatweef = {
		name = "Tatweef",
		layout = "AWD",
		blurb = "The heavy 4x4 sideways pass: long shallow slides you steer across the lanes. Slow, heavy 360s.",
		tuning = {
			drivetrain = { layout = "AWD", frontShare = 0.41 },
			tires = { front = { longitudinalGrip = FRONT_DRIVE_GRIP } },
			-- The Land Cruiser's 41:59. The wheel mostly steers the slide
			-- across the lanes (a quarter of the rate into it, 28 at most):
			-- the research's assist where the player "only steers the path".
			line = { hold = 1, steerG = 0.5, intoRelease = 0.5, leverHold = 1 },
			drift = {
				holdMinDeg = 12, holdMaxDeg = 25, holdEaseDegPerSec = 20,
				featherDegPerSec = 20, kickDeg = 4, slideReliefScale = 1.3,
				dialMaxDeg = 28, dialIntoScale = 0.25,
			},
			-- Heavy: the 360 comes round slower (2.8-3.2 s, research).
			steering = { throwYawRateDegPerSec = 125 },
		},
	},
	classicAwd = {
		name = "Classic",
		layout = "AWD",
		blurb = "The everyday tyre: all four wheels pull, the wheel sets the angle, the slide follows the tyres.",
		tuning = {
			drivetrain = { layout = "AWD", frontShare = 0.45 },
			tires = { front = { longitudinalGrip = FRONT_DRIVE_GRIP }, slipModel = { flickRearGripMultiplier = 0.55 } },
			drift = {
				holdMaxDeg = 35, holdEaseDegPerSec = 25, featherDegPerSec = 10, kickDeg = -3,
				slideReliefScale = 1.25,
			},
		},
	},
} :: { [string]: Style }

-- The order Studio's Shift+O cycles; within a layout, the first is its
-- default: Classic, the free tyre (garage-tyres-flames: "by default start
-- all at classic").
DriftStyles.order = {
	"classic", "hajwala", "power", "angle",
	"classicFwd", "tafheet", "liftoff", "pivot",
	"classicAwd", "rally", "driftmode", "tatweef",
}

-- A config's layout: "RWD" unless it says FWD or AWD.
function DriftStyles.layoutOf(cfg: any): string
	local d = type(cfg) == "table" and cfg.drivetrain
	local l = type(d) == "table" and d.layout
	if l == "FWD" or l == "AWD" then
		return l
	end
	return "RWD"
end

function DriftStyles.forLayout(layout: string): { string }
	local out = {}
	for _, id in DriftStyles.order do
		if DriftStyles.styles[id].layout == layout then
			table.insert(out, id)
		end
	end
	return out
end

function DriftStyles.default(layout: string): string
	return DriftStyles.forLayout(layout)[1] or "classic"
end

-- The id if it names a style of this layout, else the layout's default (a
-- stale attribute, a style since removed).
function DriftStyles.resolve(layout: string, id: any): string
	if type(id) == "string" and DriftStyles.styles[id] and DriftStyles.styles[id].layout == layout then
		return id
	end
	return DriftStyles.default(layout)
end

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

local function deepMerge(into: { [string]: any }, from: { [string]: any })
	for k, v in from do
		if type(v) == "table" and type(into[k]) == "table" and #v == 0 then
			deepMerge(into[k], v)
		else
			into[k] = deepCopy(v)
		end
	end
end

-- A copy of a config with a partial config deep-merged over it (arrays
-- replace). Studio's DriftLab attribute goes through this (client
-- DriftStyle).
function DriftStyles.merge(base: any, over: { [string]: any }): any
	local cfg = deepCopy(base)
	deepMerge(cfg, over)
	return cfg
end

-- A car's config with a style on it: a copy, never the car's own table.
function DriftStyles.apply(base: any, id: string): any
	local cfg = deepCopy(base)
	local style = DriftStyles.styles[id]
	if style then
		deepMerge(cfg, style.tuning)
		cfg.drivetrain.layout = style.layout
	end
	return cfg
end

return DriftStyles
