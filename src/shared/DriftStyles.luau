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

-- Front-drive and all-wheel styles give the front tyres the rear's drive
-- grip (tires.rear.longitudinalGrip, 1.9): without it the fronts spin on
-- the launch the rear puts down cleanly.
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
			drift = { powerOverSteer = 0.7, gasHoldFromScale = 0.5, featherDegPerSec = 35, kickDeg = 14, kickSeconds = 0.25 },
		},
	},
	angle = {
		name = "High Angle",
		layout = "RWD",
		blurb = "Slides settle deep, 40 to 60 degrees, and carry their speed. All smoke.",
		tuning = {
			drivetrain = { layout = "RWD" },
			drift = { holdMinDeg = 40, holdMaxDeg = 60, holdEaseDegPerSec = 35, kickDeg = 8, slideReliefScale = 1.3 },
		},
	},
	-- FRONT DRIVE.
	handbrake = {
		name = "Handbrake",
		layout = "FWD",
		blurb = "The tafheet saloon. Throw it on the lever; the gas pulls it straighter, a lift swings the tail.",
		tuning = {
			drivetrain = { layout = "FWD" },
			tires = { front = { longitudinalGrip = FRONT_DRIVE_GRIP } },
			drift = { featherDegPerSec = -15, kickDeg = -6, holdDecayDegPerSec = 3 },
		},
	},
	liftoff = {
		name = "Lift-Off",
		layout = "FWD",
		blurb = "No lever needed: lift with the wheel turned and the tail comes round. Gas pulls it out.",
		tuning = {
			drivetrain = { layout = "FWD" },
			tires = { front = { longitudinalGrip = FRONT_DRIVE_GRIP } },
			drift = {
				liftThrow = 0.6, liftThrowSeconds = 0.6, liftThrowRearGrip = 0.6,
				featherDegPerSec = -25, kickDeg = -8, holdDecayDegPerSec = 2,
			},
		},
	},
	-- ALL-WHEEL DRIVE.
	rally = {
		name = "Rally",
		layout = "AWD",
		blurb = "A four-wheel power slide: shallow, driving forward. Flick it in.",
		tuning = {
			drivetrain = { layout = "AWD", frontShare = 0.45 },
			tires = { front = { longitudinalGrip = FRONT_DRIVE_GRIP }, slipModel = { flickRearGripMultiplier = 0.55 } },
			drift = {
				holdMaxDeg = 35, holdEaseDegPerSec = 25, featherDegPerSec = 10, kickDeg = -3,
				slideReliefScale = 1.25, liftThrow = 0.4, liftThrowRearGrip = 0.75,
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
