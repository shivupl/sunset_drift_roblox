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
}

-- Camera. One fixed framing, no zoom, no presets (owner's brief).
GarageConfig.fovDeg = 40 -- a long lens flattens less and flatters the car
GarageConfig.eyeHeightM = 1.5
-- Degrees round from the car's nose toward its right: 3/4 front right.
GarageConfig.yawDeg = 35
-- Distance is computed from the car's bounding box; this is the margin
-- round it, so every car fits whatever its size.
GarageConfig.framingMargin = 1.15
-- The car's centre sits this fraction of the screen width right of the
-- middle, so the panel on the left does not cover it.
GarageConfig.screenOffset = 0.18

-- Turntable.
GarageConfig.spinDegPerSec = 8
GarageConfig.dragDegPerPixel = 0.35 -- a horizontal drag outside the panel spins it
GarageConfig.inertiaSeconds = 1 -- a flick's spin decays to nothing over this
GarageConfig.resumeAfterSeconds = 3 -- auto-spin comes back this long after the last drag

-- The view's own lights, used while the view is open with the world lamp
-- pool suspended, so the client never holds more than
-- WorldConfig.lamps.maxLiveLights (12): four here, none pooled. A spot
-- light aims at the turntable's centre 0.6 m up (the car's middle).
GarageConfig.aimHeightM = 0.6
GarageConfig.lights = {
	-- Above and in front, on the camera's side: bright and slightly warm,
	-- so gloss and metallic paint get a highlight.
	key = {
		type = "SpotLight",
		positionM = Vector3.new(-2.2, 4.4, 3.8),
		brightness = 3,
		rangeM = 16,
		angleDeg = 70,
		color = Color3.fromRGB(255, 244, 228),
	},
	-- A broad, soft light from the far side, lifting the shadow side.
	fill = {
		type = "SurfaceLight",
		positionM = Vector3.new(3.6, 2.6, 0.6),
		brightness = 1,
		rangeM = 12,
		angleDeg = 90,
		color = Color3.fromRGB(226, 232, 240),
	},
	-- Warm, from behind and above: an edge on the roof and shoulders
	-- against the backdrop.
	rim = {
		type = "SpotLight",
		positionM = Vector3.new(1.6, 3.8, -4.2),
		brightness = 2.5,
		rangeM = 12,
		angleDeg = 60,
		color = Color3.fromRGB(255, 204, 150),
	},
	-- Low under the front, soft, for the lower body and the wheels.
	under = {
		type = "PointLight",
		positionM = Vector3.new(0, 0.35, 2.9),
		brightness = 0.8,
		rangeM = 5,
		angleDeg = 0,
		color = Color3.fromRGB(255, 236, 200),
	},
} :: { key: ViewLight, fill: ViewLight, rim: ViewLight, under: ViewLight }

return GarageConfig
