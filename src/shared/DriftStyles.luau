--!strict
-- Drift styles (the owner, 2026-10-05: "I want the drift style to differ
-- slightly depending on the drivestyle of the vehicle (awd,rwd,fwd,etc) ...
-- implement a couple different styles (multiple for each) that i can test
-- and try out in game"). Research in docs/superpowers/specs/
-- 2026-10-05-drift-feel-research.md.
--
-- A car's catalog entry says which wheels it drives (drivetrain.layout);
-- the styles of that layout are offered in the menu's Settings tab, its
-- first is the default, and in Studio O cycles them (client DriftStyle).
-- A style is a partial CarConfig deep-merged over the car's own config: the
-- torque split and the pedal knobs (CarConfig.drift, DriftControl), never a
-- key a catalog car tunes (DriftStyles.spec), so each car keeps its own
-- character. Nothing here acts while the lever is in: the lever's 360s,
-- holds and catches are the same on every style.
local DriftStyles = {}

export type Style = {
	name: string,
	layout: string, -- "RWD" | "FWD" | "AWD"
	blurb: string, -- one line for the Settings tab
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

DriftStyles.styles = {
	-- REAR DRIVE.
	classic = {
		name = "Classic",
		layout = "RWD",
		blurb = "The car as you know it. A quick lift tightens it, the gas back kicks it out.",
		tuning = { drivetrain = { layout = "RWD" } },
	},
	power = {
		name = "Power Over",
		layout = "RWD",
		blurb = "Gas and full lock break the rear loose. Every stab of the gas kicks it wider.",
		tuning = {
			drivetrain = { layout = "RWD" },
			-- Full lock and gas from 30 km/h throw the car at half the lever's
			-- authority with the rear's grip at 0.8, until the gas hold takes
			-- it from 10 degrees (traction control alone left the tyres
			-- gripping: 1.5 degrees at 50 km/h). A feather tightens it fast and
			-- the stab kicks 14 back: the clutch kick.
			drift = {
				powerOverSteer = 0.7, powerOverThrow = 0.5, powerOverRearGrip = 0.8, gasHoldFromScale = 0.5,
				featherDegPerSec = 60, kickDeg = 14, kickSeconds = 0.25,
			},
		},
	},
	angle = {
		name = "High Angle",
		layout = "RWD",
		blurb = "Slides settle deep, 40 to 60 degrees, and carry their speed. Swing it with long taps; lift to straighten.",
		tuning = {
			drivetrain = { layout = "RWD" },
			-- Held 44-46 degrees for 4 s from 100, losing 7-8 km/h (Play,
			-- 2026-10-05). Lift past the feather to straighten: the band grows
			-- any held angle back to 40.
			drift = { holdMinDeg = 40, holdMaxDeg = 60, holdEaseDegPerSec = 35, kickDeg = 10, slideReliefScale = 1.3 },
		},
	},
	-- FRONT DRIVE.
	handbrake = {
		name = "Handbrake",
		layout = "FWD",
		blurb = "The tafheet saloon. Throw it on the lever and carry it; slides fade, and a stab of gas pulls it straighter.",
		tuning = {
			drivetrain = { layout = "FWD" },
			tires = { front = { longitudinalGrip = FRONT_DRIVE_GRIP } },
			-- The gas back after a lift pulls 6 degrees in, and a held slide
			-- fades 2 degrees a second. The lift itself holds the angle, for a
			-- shorter 0.25 s: with the lift swinging the tail (-15 deg/s) a
			-- hands-off catch from 22 degrees swung to 25 first and took 1.1 s.
			drift = { featherSeconds = 0.25, featherDegPerSec = 0, kickDeg = -6, holdDecayDegPerSec = 2 },
			-- Front drive comes out of a gas-held slide still yawing outward
			-- (the driven fronts were bending the path): let go at 23 degrees
			-- it carried the angle half a second before the tyres turned it,
			-- 1.1-1.2 s to straight. The hands-off catch's authority from 15
			-- degrees instead of 25 brings that to 0.58 (rear drive: 0.63).
			-- Play, 2026-10-05.
			steering = { throwFinishFromDeg = 15 },
		},
	},
	liftoff = {
		name = "Lift-Off",
		layout = "FWD",
		blurb = "No lever needed: lift with the wheel turned and the tail comes round. Gas pulls it out.",
		tuning = {
			drivetrain = { layout = "FWD" },
			tires = { front = { longitudinalGrip = FRONT_DRIVE_GRIP } },
			-- Lift at 60 km/h or more with the wheel past half and the tail
			-- comes round: a half-second lift at 100 with the wheel at 0.8 is
			-- past 20 degrees in 0.31 s and settles at 35-37 on the gas. At
			-- 0.6 for 0.6 s it swung to 55-58 and held 50; at 0.45 for 0.45 s,
			-- 50 and 45 (Play, 2026-10-05). Its lifts swing the tail, so a
			-- hands-off catch from 18 degrees takes 0.9 s.
			drift = {
				liftThrow = 0.3, liftThrowSeconds = 0.4, liftThrowRearGrip = 0.6,
				featherDegPerSec = -10, kickDeg = -8, holdDecayDegPerSec = 2,
			},
			-- As Handbrake: the catch's authority from 15 degrees.
			steering = { throwFinishFromDeg = 15 },
		},
	},
	-- ALL-WHEEL DRIVE.
	rally = {
		name = "Rally",
		layout = "AWD",
		blurb = "A four-wheel power slide: shallow, driving forward. Flick it in.",
		tuning = {
			drivetrain = { layout = "AWD", frontShare = 0.45 },
			-- The stronger Scandinavian flick (the flick's rear grip 0.55
			-- against 0.7). It had a lift throw too (0.4), taken off: the
			-- all-wheel cars' default must drive like the car as it was, and a
			-- lift with the wheel past half at 60 km/h, an ordinary keyboard
			-- lane change, threw the tail out (final review, 2026-10-05).
			tires = { front = { longitudinalGrip = FRONT_DRIVE_GRIP }, slipModel = { flickRearGripMultiplier = 0.55 } },
			drift = {
				holdMaxDeg = 35, holdEaseDegPerSec = 25, featherDegPerSec = 10, kickDeg = -3,
				slideReliefScale = 1.25,
			},
		},
	},
	driftmode = {
		name = "Drift Mode",
		layout = "AWD",
		blurb = "The factory drift mode: most of the drive to the rear. Holds like rear drive, catches sooner.",
		tuning = {
			drivetrain = { layout = "AWD", frontShare = 0.15 },
			tires = { front = { longitudinalGrip = FRONT_DRIVE_GRIP } },
			drift = { kickDeg = 8, featherDegPerSec = 20 },
		},
	},
} :: { [string]: Style }

-- The order the menu shows and Studio's Shift+O cycles; within a layout,
-- the first is its default.
DriftStyles.order = { "classic", "power", "angle", "handbrake", "liftoff", "rally", "driftmode" }

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
