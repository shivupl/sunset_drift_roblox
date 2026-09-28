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

-- Camera. One fixed framing, no zoom, no presets (owner's brief).
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

-- Entering and leaving (spec section 2).
-- The threshold is only watched while the character's root is this close
-- to the doorway, and never while seated (driving in does nothing).
GarageConfig.thresholdRangeM = 12
GarageConfig.fadeSeconds = 0.2 -- to asphalt950 and back, each way
-- On leaving, the camera starts this far behind and above the character
-- standing at ExitSpot (facing out), so it does not swing round from the
-- turntable framing. The default camera takes over from there.
GarageConfig.exitCamera = { backM = 4, upM = 1.6 }

-- Turntable.
GarageConfig.spinDegPerSec = 8
GarageConfig.dragDegPerPixel = 0.35 -- a horizontal drag outside the panel spins it
GarageConfig.inertiaSeconds = 1 -- a flick's spin decays to nothing over this
GarageConfig.resumeAfterSeconds = 3 -- auto-spin comes back this long after the last drag
-- A flick's release speed is capped here, so one hard swipe does not spin
-- the car in a blur.
GarageConfig.maxFlickDegPerSec = 360
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
		shadows = true, -- the car's shadow on the plate grounds it; the only shadowed light
	},
	-- A broad, soft light from the far side, lifting the shadow side.
	fill = {
		type = "SurfaceLight",
		positionM = Vector3.new(3.6, 2.6, 0.6),
		brightness = 1,
		rangeM = 12,
		angleDeg = 90,
		color = Color3.fromRGB(226, 232, 240),
		sizeM = 1.2, -- a broad face, so the fill reads as a soft panel
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
