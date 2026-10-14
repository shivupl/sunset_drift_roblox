--!strict
-- The garage's customisation view: the camera, the turntable's spin and the
-- four lights the view brings with it. Asked by the owner on 2026-09-28
-- (docs/superpowers/specs/2026-09-28-garage-design.md sections 1 and 3).
-- Shared because the client runs the view and cannot require server
-- modules; the building itself is WorldConfig.garage on the server.
--
-- Positions are metres in the view frame: origin at the turntable's top
-- centre, -Z (LookVector) pointing into the garage (DoorZone's LookVector),
-- +X to the right as you look in from the door, +Y up. So +Z is toward the
-- door, where the camera is.
local GarageConfig = {}

export type ViewLight = {
	type: string, -- "SpotLight" | "SurfaceLight" | "PointLight"
	positionM: Vector3,
	brightness: number,
	rangeM: number,
	angleDeg: number, -- SpotLight / SurfaceLight cone; ignored by a PointLight
	color: Color3,
	sizeM: number?, -- the square emitting face of a SurfaceLight's anchor; default 0.2
	shadows: boolean?, -- default false
}

-- Camera. The full framing (the `full` shot below): the whole car. Until
-- garage-polish (2026-10-05) it was the only one ("no zoom, no presets",
-- the 2026-09-28 brief); now each part has its close shot (`shots`).
-- The spec asked for 40 (a long lens flattens less and flatters the car),
-- but at 40 the distance that fits the kamri07 is 10.3 m, and at 35 degrees
-- round that put the eye in the display bay's front-left corner, inside the
-- tyre rack by the door (measured in Play 2026-09-28: 0.26 m from the side
-- wall). 50 brings it to 8.1 m. Lower is a longer lens and a farther eye.
GarageConfig.fovDeg = 50
GarageConfig.eyeHeightM = 1.5
-- Degrees round from the car's nose toward its right: 3/4 front right.
-- 30, not the spec's 35, keeps the eye clear of the side wall's rack.
GarageConfig.yawDeg = 30
-- Distance is computed from the car's bounding box; this is the margin
-- round it, so every car fits whatever its size.
GarageConfig.framingMargin = 1.15
-- The car's centre sits this fraction of the screen width right of the
-- middle, so the panel on the left does not cover it.
GarageConfig.screenOffset = 0.18
-- The same per garage layout (GaragePanel, 2026-10-12: a phone has
-- SHOWCASE's variants, a PC DOCK as well; SHADE is parked): DOCK and
-- SHADE keep their panels on the left; SHOWCASE's variants put the car in
-- the middle between the words and the blocks down the right.
GarageConfig.layoutOffset = {
	dock = 0.2,
	showcase = -0.06,
	glass = -0.06,
	frame = -0.06,
	shade = 0.22,
} :: { [string]: number }

-- The garage shell's parts hidden while the view is up, on this screen
-- only: the dark steel beams under the roof crossed right behind the cash
-- and read as its shadow (the owner's phone, 2026-10-12: "remove ... the
-- shaddow next ot the coins", "a shaddow behind the coins thing to the
-- right"). Names in the shell (server World/Garage).
GarageConfig.viewHides = { "RoofBeam", "Beam" } :: { string }

-- Entering and leaving (spec section 2).
-- The threshold is only watched while the character's root is this close
-- to the doorway; while seated the car's chassis is watched instead
-- (driveIn below).
GarageConfig.thresholdRangeM = 12
GarageConfig.fadeSeconds = 0.2 -- to asphalt950 and back, each way
-- How long a short message (the car could not be shown) stays up.
GarageConfig.noticeSeconds = 3
-- On leaving, the camera starts this far behind and above the character
-- standing at ExitSpot (facing out), so it does not swing round from the
-- turntable framing. The default camera takes over from there.
GarageConfig.exitCamera = { backM = 4, upM = 1.6 }

-- Driving in (garage round 2 §3; the owner, 2026-09-28: "also add the
-- ability to not only walk in but drive a car in as well"). While seated
-- as the driver of your own car, the chassis's centre crossing DoorZone
-- inward below maxKmh opens the view with that car; faster does nothing
-- and the walls stop the car as before.
--   maxKmh: the spec's "~20 km/h", a crawl through a 5 m door. Higher lets
--     a quicker entry count; lower asks for a slower one.
--   serverSlack: the server checks the replicated speed against
--     maxKmh * this, so a car the client saw at 19.9 is not refused for
--     reading 20.5 a moment later.
--   zoneMarginM: how far past DoorZone's box (sideways, and along the
--     car's travel) the chassis may be when the server checks; the car
--     keeps rolling while the request is in flight (5.5 m/s at 20 km/h,
--     about 0.5 m over 100 ms of ping), so 3 m is generous.
--   outM: the drive-out spot, measured from DoorZone's centre straight out
--     of the door along the ground; the car's middle parks there facing
--     away from the door. 7, so that a 5 m car's tail (2.5 m) stays clear
--     of ExitSpot (3.15 m from the zone's centre) with room to stand, and
--     the nose short of the painted arrow (8.4 m out) - the car sits on the
--     keep-clear hatch in front of the open door.
--   clearM: a car of anyone else's, or another player, within this box
--     (the parking spot's footprint, width x length, metres) refuses the
--     drive-in, so a parked car never lands on another car or a person.
--   leaveRangeM: the server seats a player back in the parked car only if
--     their character's root is this close to DoorZone's centre. In the
--     view the character stands beside the parked car (about 7 m out) or
--     at ExitSpot (3 m), so 20 is generous; anything farther is not a
--     leave from the garage and gets the walk-in exit instead.
--   blockedText: shown when the spot is taken and the drive-in refused.
--   holdSeconds: on driving out the car stays anchored, seated, until the
--     client's car controller runs and says "go" (a free car fell until
--     then and 2 in 5 drive-outs ended on their side, 2026-09-28); if the
--     client never says so, the server lets go after this long. Longer
--     only matters for a client that hangs; shorter risks the fall again
--     on a slow one.
GarageConfig.driveIn = {
	maxKmh = 20,
	serverSlack = 1.25,
	zoneMarginM = 3,
	outM = 7,
	clearM = Vector2.new(3, 6),
	leaveRangeM = 20,
	blockedText = "Someone's parked out front. Try again in a moment.",
	holdSeconds = 2,
}

-- CUSTOMIZE in the car menu takes you to the garage from anywhere (the
-- owner, 2026-10-14: "clicking customize should take me to the actual
-- garage"): on foot as a walk-in, driving your own car as a drive-in from
-- afar (GarageService "bringIn" parks it on the drive-out spot). What is
-- said when it cannot:
--   seatedText: in a car that is not yours to park (a passenger, someone
--     else's car).
--   noGarageText: the garage is not built or not on this client yet.
--   standBesideM: after a bring-in the player stands this far to the
--     right of the parked car, on the apron (within driveIn.leaveRangeM).
--   streamSeconds: how long to wait for the garage's parts to stream in
--     when CUSTOMIZE is tapped far from it (the world streams at 2,048
--     studs; the highway is longer).
GarageConfig.visit = {
	seatedText = "Get out of the car first.",
	noGarageText = "The garage is not here yet.",
	standBesideM = 3,
	streamSeconds = 5,
}

-- Turntable.
GarageConfig.spinDegPerSec = 8
GarageConfig.dragDegPerPixel = 0.35 -- a horizontal drag outside the panel spins it
GarageConfig.inertiaSeconds = 1 -- a flick's spin decays to nothing over this
GarageConfig.resumeAfterSeconds = 3 -- auto-spin comes back this long after the last drag
-- A flick's release speed is capped here, so one hard swipe does not spin
-- the car in a blur.
GarageConfig.maxFlickDegPerSec = 360
-- Close shots (garage-polish; the owner, 2026-10-05: "when selecting
-- exhaust tips or flames, it should like zoom into that part and for the
-- flames, shoudl do a quick play of it ... overall improve and polish the
-- garage"). Each category and sub-tab of the panel has a shot (`views`).
-- A close shot turns the turntable so the car shows the camera one side
-- and holds it there (no spin), and the camera comes in toward a point on
-- the car. The camera keeps the full framing's bearing and only comes
-- closer, so it never meets a wall: the eye is the aim point moved
-- distanceM back toward the full framing's eye, eyeHeightM over the
-- turntable's top, turned like the full framing so the aim sits
-- screenOffset right of centre. A drag goes back out to `full`.
--   faceDeg: which way the car faces the camera, degrees round from its
--     nose toward its right: 0 nose on, 90 the right side, 180 the rear.
--   aim: "hub" (the wheel `hub` names, VehicleRig.WHEELS), "outlets" (the
--     exhaust outlets' middle, CarCosmetics.outlets) or "box"; `box` is
--     the point in the body's bounding box, as fractions: x -1 left to 1
--     right, y 0 bottom to 1 top, z -1 rear to 1 front. A hub or outlets
--     the car lacks falls back to `box`.
--   distanceM / eyeHeightM: the eye from the aim (flat), and its height.
--   fovDeg: the lens, default fovDeg above. brake: the brake lights on.
-- Numbers are first framings, checked in Play on the Krown Vik.
export type Shot = {
	faceDeg: number,
	aim: string,
	hub: string?,
	box: { x: number, y: number, z: number },
	distanceM: number,
	eyeHeightM: number,
	fovDeg: number?,
	brake: boolean?,
}
GarageConfig.shots = {
	-- The side windows, square on: the tint.
	side = { faceDeg = 90, aim = "box", box = { x = 1, y = 0.68, z = 0 }, distanceM = 4.2, eyeHeightM = 1.35 },
	-- The front-right wheel, low and a little from the front: rims, tyres.
	-- At 2.3 m the wheel filled the frame and the arch was cut off (Krown
	-- Vik, Play 2026-10-05).
	wheel = { faceDeg = 75, aim = "hub", hub = "FR", box = { x = 1, y = 0.25, z = 0.6 }, distanceM = 3, eyeHeightM = 0.7 },
	-- The front-right corner: the headlights.
	head = { faceDeg = 35, aim = "box", box = { x = 0.6, y = 0.55, z = 1 }, distanceM = 3, eyeHeightM = 1 },
	-- The rear-right corner, brake lights on: the tail lights.
	tail = { faceDeg = 150, aim = "box", box = { x = 0.6, y = 0.6, z = -1 }, distanceM = 3, eyeHeightM = 1.1, brake = true },
	-- The windscreen's top from in front and above: the sun strip.
	windscreen = { faceDeg = 10, aim = "box", box = { x = 0, y = 0.85, z = 0.3 }, distanceM = 3.6, eyeHeightM = 2.4 },
	-- The rear, square on: the plate.
	plate = { faceDeg = 180, aim = "box", box = { x = 0, y = 0.35, z = -1 }, distanceM = 2.8, eyeHeightM = 0.9 },
	-- The exhaust: REV's old angle (garage round 2 §2), a rear 3/4 15
	-- degrees past square on, where both tips and their flames sat clear
	-- of the panel (turnDeg 35 put the right-hand flame off the screen's
	-- edge; Play, Kamri, titanium, 2026-09-28). Low: from 0.8 m the Krown
	-- Vik's factory pipe was hidden under its bumper (Play, 2026-10-05).
	exhaust = { faceDeg = 195, aim = "outlets", box = { x = 0, y = 0.2, z = -1 }, distanceM = 3, eyeHeightM = 0.45 },
} :: { [string]: Shot }
-- The shot with no close-up: the full framing above, the turntable turning.
GarageConfig.FULL = "full"

-- Moving between shots: the camera takes UITheme.motion.camera (0.8 s,
-- Sine in-out) from wherever it was; the turntable eases to the shot's
-- angle with this time constant (seconds) and has arrived within
-- arriveDeg, when a shot's onArrive (REV's burst) runs. 0.25 s took about
-- 1.1 s from 76 degrees away (measured for REV, 2026-09-28).
GarageConfig.focus = { easeSeconds = 0.25, arriveDeg = 1.5 }

-- The panel's views: per category, its sub-tabs in order (more than one
-- shows them as a row of words), each with its label and shot. One view
-- shows no sub-tabs. ids are the panel's, not stored anywhere.
export type View = { id: string, label: string, shot: string }
GarageConfig.views = {
	cars = { { id = "cars", label = "MY CARS", shot = "full" } },
	-- FINISH is a sub-tab of its own (garage-ui-overhaul, 2026-10-06): the
	-- finish pills above the colours took three rows.
	paint = {
		{ id = "colour", label = "COLOUR", shot = "full" },
		{ id = "finish", label = "FINISH", shot = "full" },
		{ id = "tint", label = "TINT", shot = "side" },
	},
	rims = { { id = "rims", label = "RIMS", shot = "wheel" }, { id = "tyres", label = "TYRES", shot = "wheel" } },
	plates = { { id = "plates", label = "PLATES", shot = "plate" } },
	lights = { { id = "head", label = "HEADLIGHTS", shot = "head" }, { id = "tail", label = "TAIL LIGHTS", shot = "tail" } },
	decal = { { id = "decal", label = "SUN STRIPS", shot = "windscreen" } },
	exhaust = { { id = "tips", label = "TIPS", shot = "exhaust" }, { id = "flames", label = "FLAMES", shot = "exhaust" } },
} :: { [string]: { View } }

-- A headlight colour tapped: the lamps blink this many times, off for
-- offSeconds and back on for onSeconds each, so the colour reads lit.
GarageConfig.headFlash = { blinks = 2, offSeconds = 0.09, onSeconds = 0.14 }
-- The panel's sounds, for this player only (client Garage/GarageSounds):
-- a category or sub-tab, an unbought item previewed, an owned item
-- fitted, a purchase, an error. Picked unheard for the owner to try
-- (garage-polish, 2026-10-05): Roblox's own UI set (clicks, Delete) and
-- Pro Sound Effects' (Creator Store, licensed by Roblox) impact wrench and
-- cash register. A sound that fails to load is skipped. volume 0 mutes one.
GarageConfig.sounds = {
	tab = { id = "rbxassetid://15675032796", volume = 0.5 }, -- Roblox_UI_Small_Click
	tap = { id = "rbxassetid://15675059323", volume = 0.45 }, -- Roblox_UI_Bright_Click
	fit = { id = "rbxassetid://9117704306", volume = 0.3 }, -- Pneumatic Impact Wrench Drill On Off 4 (SFX), 1.1 s
	buy = { id = "rbxassetid://9113728049", volume = 0.5 }, -- Cash Register 2 (SFX), 1.7 s
	error = { id = "rbxassetid://15675075163", volume = 0.45 }, -- Roblox_UI_Delete
} :: { [string]: { id: string, volume: number } }

-- The panel's motion (garage-polish): a card shrinks to pressScale while
-- pressed, pops to popScale and back when its item is fitted or bought,
-- and the cash readout counts down over cashCountSeconds after a purchase.
GarageConfig.feel = { pressScale = 0.96, popScale = 1.06, cashCountSeconds = 0.6 }

-- The preview's headlights (and so its tails) are on, so the Lights
-- category's colours show on the turntable; off would leave the lenses as
-- plain glass.
GarageConfig.previewLampsOn = true

-- The view's own lights, used while the view is open with the world lamp
-- pool suspended, so the client never holds more than
-- WorldConfig.lamps.maxLiveLights (12): four here, none pooled. A spot
-- light aims at the turntable's centre 0.6 m up (the car's middle).
--
-- Brightness is for the default sky option. Another option's
-- ExposureCompensation brightens or darkens the whole frame, lights and all
-- (night is +0.4 stops over sunset, and a white car blew out under the key,
-- measured 2026-09-28), so the client scales every view light by
-- 2^(default exposure - that option's exposure): the car reads the same
-- under either sky.
GarageConfig.aimHeightM = 0.6
GarageConfig.lights = {
	-- Above and in front, on the camera's side: bright and slightly warm,
	-- so gloss and metallic paint get a highlight.
	key = {
		type = "SpotLight",
		positionM = Vector3.new(-2.2, 4.4, 3.8),
		-- 1, from 3 (measured 2026-09-28): at 3, and still at 1.5, a white
		-- car's lit side passed the world's bloom threshold (1.1) and
		-- glowed; at 1 white reads white with shading and a Night Blue
		-- metallic still shows its highlight. Higher is a hotter highlight.
		brightness = 1,
		rangeM = 16,
		angleDeg = 70,
		color = Color3.fromRGB(255, 244, 228),
		-- Under Lighting.Technology ShadowMap (this place) local lights cast
		-- no shadow and give no specular highlight; this only matters if the
		-- place moves to Future, where it would ground the car on the plate.
		shadows = true,
	},
	-- A softbox: a broad panel over the car, facing down. Moved 2026-09-28
	-- from the far side (3.6, 2.6, 0.6), brightness 1, 1.2 m face: the
	-- Glass finishes (see CosmeticsConfig FINISH) take their sheen from the
	-- view's lights, and from overhead it lands on the bonnet and roof, the
	-- faces the camera sees. It is still the "fill": it lifts the shadow side.
	fill = {
		type = "SurfaceLight",
		positionM = Vector3.new(0, 4.6, 0.3),
		brightness = 1.5,
		rangeM = 11,
		angleDeg = 120,
		color = Color3.fromRGB(226, 232, 240),
		sizeM = 3, -- a broad face, so the sheen is soft and wide
	},
	-- Warm, from behind and above: an edge on the roof and shoulders
	-- against the backdrop.
	rim = {
		type = "SpotLight",
		positionM = Vector3.new(1.6, 3.8, -4.2),
		brightness = 1.5, -- from 2.5, with the key (the edge stays brighter than the key)
		rangeM = 12,
		angleDeg = 60,
		color = Color3.fromRGB(255, 204, 150),
	},
	-- Low under the front, soft, for the lower body and the wheels.
	under = {
		type = "PointLight",
		positionM = Vector3.new(0, 0.35, 2.9),
		brightness = 0.4, -- from 0.8: the sills bloomed on a white car
		rangeM = 5,
		angleDeg = 0,
		color = Color3.fromRGB(255, 236, 200),
	},
} :: { key: ViewLight, fill: ViewLight, rim: ViewLight, under: ViewLight }

-- The interior's painted-on light (WorldConfig.garage.bakedLight: SurfaceGuis
-- at a LightInfluence below 1) per sky option (SkyConfig ids). The client
-- sets each panel to 1 - (1 - built) * glow: 1 keeps the built value, 0
-- turns the paint into ordinary lit paint. Options not listed keep 1.
-- Night 0.5, measured 2026-09-28: at night the lamp pool lights the strip
-- fittings when a player is near, and at 1 the interior read flat and
-- whitish through the door; at 0 it read as real light pools but would go
-- dark whenever the pool is lighting other lamps. Sunset keeps what the
-- build verified (the pool is dark at golden hour).
GarageConfig.bakedGlow = { sunset = 1, night = 0.5 } :: { [string]: number }
-- Parts whose SurfaceGui glows on purpose (the sign) are left alone.
GarageConfig.bakedGlowSkip = { Fascia = true } :: { [string]: boolean }

return GarageConfig
