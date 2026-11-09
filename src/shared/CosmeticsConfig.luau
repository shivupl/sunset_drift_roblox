--!strict
-- Garage cosmetics: paint, finish, rims, head/tail lamp colour, sun strips
-- (the "decal" category), exhaust tips, window tint, tyres (the drift
-- mode) and exhaust flames (the flame style). Asked by the owner on
-- 2026-09-28, alongside the garage and customisation spec
-- (hajwala-project-phases.md / the 2026-09-28 garage design docs): every
-- car should have paint, wheels, lights, a strip and an exhaust to buy and
-- swap, priced in the same economy as PlateConfig's plate prices (10,000 to
-- 1,000,000). The prices below are first guesses for the owner to weigh
-- against how fast cash is earned, same as PlateConfig's.
--
-- Ids are permanent: they are stored on player profiles (as a CarLook
-- string) and never renamed once shipped, only added to. A stock id per
-- category (price 0) is the factory look nobody has to buy; CarLook falls
-- back to it when nothing is owned or chosen for that slot.
--
-- Tyres and flames (garage-tyres-flames, the owner, 2026-10-05: "make the
-- differnt driftmodes we made different tire options in the garage instead
-- of drift options in the car menu. by default start all at classic ...
-- same for the tire flames. have classic be the default and the other
-- flames purchasable in the garage"). A tyre is a drift mode
-- (DriftStyles): each fits one drivetrain, bought once for every car with
-- it; the stock Classic tyre is each drivetrain's Classic. A flame is an
-- exhaust flame style (ExhaustStyles); the stock one is Classic.
local CosmeticsConfig = {}

export type Category = "paint" | "finish" | "rims" | "head" | "tail" | "decal" | "exhaust" | "tint" | "tyre" | "flame"

export type Item = {
	id: string,
	category: Category,
	name: string,
	price: number,
	rare: boolean?,
	color: Color3?,
	material: Enum.Material?,
	reflectance: number?,
	darken: number?, -- finish only: the paint colour's value this much lower (0..1)
	desaturate: number?, -- finish only: the paint colour's saturation this much lower (0..1)
	text: string?,
	textColor: Color3?,
	stripColor: Color3?,
	stripColor2: Color3?,
	tips: number?,
	tipColor: Color3?,
	tipMaterial: Enum.Material?,
	-- Exhaust only: the tip's modelled shape, a key of render.tipStyles.
	tipStyle: string?,
	engineVolume: number?,
	crackleChance: number?,
	-- Exhaust only: the flame profile (ExhaustFlames, CosmeticsConfig.flames).
	-- flameSize scales every flame length and size; flameCore tints the hot
	-- core at the mouth, flameColor the tongue's body. The profile's pop
	-- multiplier is crackleChance: every pop is one flame, so one knob sets
	-- both what you hear and what you see.
	flameSize: number?,
	flameCore: Color3?,
	flameColor: Color3?,
	-- Tint only: the film's colour, and the transparency it gives the side
	-- and rear windows (glassTransparency) and the windscreen
	-- (screenTransparency) (CarCosmeticMounts windows, CarCosmetics).
	glassColor: Color3?,
	glassTransparency: number?,
	screenTransparency: number?,
	-- Tyre only: the drift mode it drives (a DriftStyles id) and the
	-- drivetrain it fits ("RWD", "FWD", "AWD"). The stock tyre has neither:
	-- it is every drivetrain's Classic (DriftStyles.default).
	driftStyle: string?,
	layout: string?,
	-- Flame only: the exhaust flame style (an ExhaustStyles id). Its tile in
	-- the garage runs from flameCore to flameColor, the style's own colours.
	flameStyle: string?,
}

-- Garage actions (buy, equip, plate) a player may send per second through
-- CosmeticsAction; more get "busy". Each is one tap in the garage, so 4 is
-- well above a person and well below a script (garage plan, task 2,
-- 2026-09-28; same idea as PlateConfig.actionsPerSecond).
CosmeticsConfig.actionsPerSecond = 4

-- An exhaust tip style (render.tipStyles; CarCosmetics builds from it).
export type TipStyle = { mesh: string, pair: boolean?, baked: boolean?, meshAssetId: number?, textureAssetId: number?, tileAspect: number? }

-- How a look is drawn on the car (CarCosmetics, CarLamps; garage plan,
-- task 3, 2026-09-28). The spots themselves are per car, CarCosmeticMounts.
CosmeticsConfig.render = {
	-- A chosen tail colour's brake lamp: that colour this much brighter (HSV
	-- value), so braking still reads over the tail lamps. Smoked (#4A0A0C)
	-- brakes at #670E11, which is dim: raise this if braking gets lost.
	brakeBrighten = 0.4,
	-- The sun strip: thin cards, their canvas drawn at this many pixels
	-- per metre, not drawn past drawStuds (the text is unreadable by then).
	stripThicknessM = 0.004,
	stripPixelsPerM = 400,
	stripDrawStuds = 250,
	-- Garage round 3 §3 (2026-09-28): the strip is moulded to each windscreen
	-- as this many flat slats across it, each on the glass at its spot
	-- (tools/cosmetics/strip_shapes.py writes CarStripShapes from these three;
	-- run it again after changing them). 14 keeps a slat under ~10 cm on the
	-- widest screen, where a flat slat and the glass's curve across part by
	-- under 2 mm; more slats cost one part and one SurfaceGui each.
	stripSlats = 14,
	-- Each slat runs this far past its share at both ends, so neighbours
	-- overlap by twice it and no seam shows where two meet at an angle.
	stripOverlapM = 0.004,
	-- The gap between a slat and the glass: off the outer face on opaque
	-- glass, behind the inner face on see-through glass (the round-2 cards sat
	-- about 1 cm off by eye; this is to the nearest point under the slat).
	stripGlassGapM = 0.006,
	-- Exhaust tips (garage round 3 §1, 2026-09-28: modelled in Blender,
	-- tools/cosmetics/exhaust_tips.py, shipped as MeshData modules in
	-- src/shared/CosmeticMeshes/ExhaustTips; the plain cylinders with a
	-- separate dark bore of round 2 are gone). Each item's tipStyle names one
	-- of these. mesh is the generated piece: one mesh per style, so one
	-- EditableMesh on a client (a client holds only 8, BEHAVIOURS; fix round
	-- 1 cut the tips from 8 to at most 4). The quad's mesh is a whole pair on
	-- its Y inlet (pair = true), so a quad car has two pipes. baked means the
	-- mesh carries its own colours (the titanium's heat tint), so it takes
	-- bakedTipColor instead of the item's tipColor (vertex colours multiply
	-- the part colour). meshAssetId (optional): the same mesh uploaded from
	-- tools/cosmetics/out (README there); when set the tip is built from the
	-- asset and costs no EditableMesh at all.
	-- The four asset ids: uploaded 2026-09-29 by the owner through Studio's
	-- 3D importer from tools/cosmetics/out (the "Upload them" decision after
	-- round 3: a client's 8 EditableMeshes are shared with generated car
	-- bodies, so busy clients showed cylinder tips). Each imported MeshSize
	-- matched the generated piece's sizeM to the millimetre. Re-upload and
	-- change the id whenever exhaust_tips.py changes that shape.
	tipStyles = {
		rolled = { mesh = "Rolled", meshAssetId = 120516588176242 },
		quad = { mesh = "QuadPair", pair = true, meshAssetId = 104062955067546 },
		-- The slash's heat colours: Studio's importer drops OBJ vertex colours
		-- (its first upload, 102623740780891, came in plain), so its OBJ carries
		-- texture coordinates into a colour strip (tools/cosmetics/out
		-- Slash_ramp.png, uploaded as textureAssetId); the textured OBJ was
		-- imported 2026-09-29 as meshAssetId.
		slash = { mesh = "Slash", baked = true, meshAssetId = 119518854633085, textureAssetId = 81508963160342 },
		-- tileAspect: the garage panel draws its tip this many times wider than
		-- tall (the barrel is 25 x 16 cm).
		oval = { mesh = "Oval", tileAspect = 1.56, meshAssetId = 103926423140060 },
	} :: { [string]: TipStyle },
	-- Studio's 3D importer turns an OBJ half round about Y: the uploaded tips
	-- came in with their mouth facing -Z (the closed inlet where the mouth
	-- should be; side by side with the generated pieces, Studio 2026-09-29).
	-- Every tip is symmetric across X, so a half turn about Y matches the
	-- generated mesh exactly, slash cut included. Applied to tips built from a
	-- meshAssetId only.
	uploadedTipTurnDeg = 180,
	-- Near white so the baked heat colours show at their own value; pure
	-- white on Metal read a touch hot under the garage lights.
	bakedTipColor = Color3.fromHex("#EEEDEA"),
	-- Each tip's bore is closed 1.6 cm in by a flat dark disc Part in this colour,
	-- SmoothPlastic: matte, because Metal and Foil mirror the world through a
	-- dark vertex colour (a Foil bore showed the bumper and the car's pipes,
	-- Studio 2026-09-28). The last centimetre of inner wall is on the mesh,
	-- darkening toward it. Round 2's bore was #121214.
	-- #141416 read brown-grey under the sunset and the bay lights, a lit
	-- disc rather than a hole.
	tipBoreColor = Color3.fromHex("#060607"),
	-- A tip style takes an EditableMesh only if at least this many stay free
	-- after it, so car bodies always come first: CarCosmetics uses the most
	-- EditableMeshes any catalog car's generated pieces need (worked out from
	-- the catalog at runtime) or this, whichever is more. Measured in Play
	-- 2026-09-29 on the working-copy catalog (final review M1): kamri 5 (Body, Glass, Interior, Rim,
	-- Tyre), krownvik 4, lekzas 1, batrol 1, krownvikfleet 1; kamri07 (the
	-- default car) and kruzer80 none (store meshes).
	-- So the reserve is 5 today: a client with no generated car in view can
	-- have 3 tip styles as meshes at once, and one with a kamri none
	-- (cylinder tips). The old 4 left a kamri arriving after four tip styles
	-- one piece short, a grey box for the session. Otherwise the style uses
	-- cylinder tips; a style's mesh is freed when no car on the client wears
	-- it. This number is only a floor now.
	tipMeshReserve = 4,
	-- The round tips' outer radius (the generator builds Rolled and Quad at
	-- it: CosmeticsConfig.spec), 0.09 m before the car's scale. Quad tips
	-- are two pairs, each pair's tips quadPairGapM apart centre to centre (at
	-- least 2 x tipRadiusM, or they overlap: CarCosmeticMounts.spec; the
	-- generator's QuadPair is built for this gap).
	tipRadiusM = 0.09,
	quadPairGapM = 0.2,
	-- The factory pipe's dark bore (below).
	boreColor = Color3.fromRGB(18, 18, 20),
	-- Where a tip's pipe ends forward: pipeLengthM (CarCosmeticMounts, per
	-- car) forward of a point this far in from the mouth. 0.16 m is round
	-- 2's tip length, which every car's pipeLengthM was measured from, so
	-- the pipes still end hidden where they did; they now start inside each
	-- tip's inlet collar instead (the tips are longer, with a reducer).
	pipeRunFromM = 0.16,
	-- The pipe each tip sits on, running forward under the car for the car's
	-- tips.pipeLengthM (CarCosmeticMounts), so a tip is attached, never a
	-- floating can (garage round 2, 2026-09-28: "exhausts should be attached
	-- in some sense to the car - not floating"). 0.04 m radius: plainly
	-- thinner than the tip, and inside every tip's 0.046 m inlet collar
	-- (spec). It starts pipeOverlapM inside the collar so no seam shows.
	pipeRadiusM = 0.04,
	pipeOverlapM = 0.03,
	pipeColor = Color3.fromRGB(62, 60, 58),
	-- A factory pipe, built where a car's body has none (a stock outlet with
	-- factory = true): a plain 0.032 m radius dark pipe with a 0.022 m bore,
	-- the same run forward as the tips' pipe. Small and plain on purpose, it
	-- is the car's standard exhaust, not a tip.
	factoryPipeRadiusM = 0.032,
	factoryBoreRadiusM = 0.022,
	factoryPipeColor = Color3.fromRGB(70, 68, 66),
	-- The pipes' route (garage round 3 §2, 2026-09-28: pipes routed up into
	-- the car, not stopping in mid-air): straight forward the car's run, then
	-- a bend up into the underbody, its end riseM above the pipe
	-- (CarCosmeticMounts, per car) and pipeEndBuryM more, so the end's whole
	-- rim is inside the body. Plain Parts, not an EditableMesh (controller
	-- ruling: a client holds 8, shared with car bodies and tips): the bend is
	-- pipeBendSegments cylinders per pipeBendMaxDeg with a ball at each joint,
	-- so it reads as one smooth bend. A smaller rise bends less (fewer
	-- segments); a larger one bends the full pipeBendMaxDeg, then runs
	-- straight up. 0.1 m centreline radius: 2.5 pipe radii, a mandrel bend,
	-- and short enough to end in front of every car's tips well behind the
	-- tyres (spec). 3 segments over 90° (30° each): round at driving distance
	-- from rear 3/4 and the side; raise it if the bend looks faceted up close
	-- in the garage, at 2 parts per segment per pipe.
	pipeBendRadiusM = 0.1,
	pipeBendMaxDeg = 90,
	pipeBendSegments = 3,
	pipeEndBuryM = 0.02,
	-- A tip turned on the car (the krownvik and fleet quad pairs, about 10°)
	-- has its pipe leave along the tip's own axis for this far past the inlet
	-- before it turns to run straight forward, at a ball joint.
	pipeAxisRunM = 0.05,
	-- A small dark rubber hanger on each pipe's straight run, this far behind
	-- the bend, from the pipe up into the underbody (riseM and the bury above),
	-- so the pipe reads as hung from the car. Thin and dark on purpose: it is
	-- a detail seen from low down, not a feature.
	hangerBackM = 0.08,
	-- No hanger where it would be taller than this (the rise plus the bury):
	-- on the kruzer80's open underside it was a 32 cm black strap beside the
	-- riser (fix round 1), which is a feature, not a detail. 0.12 keeps the
	-- batrol's 11 cm one.
	hangerMaxM = 0.12,
	hangerWidthM = 0.03,
	hangerThickM = 0.014,
	hangerColor = Color3.fromHex("#161617"),
}

-- Exhaust flames (ExhaustFlames; garage round 2 §2, 2026-09-28: the owner
-- asked for "really refined and polished exhaust flame animations"; the
-- parked car-backfire branch's 0.09 s puffs of one texture were judged
-- poor). One pop is a layered burst at every ExhaustOutlet, all Emit, never
-- a running emitter, all from Roblox's built-in particle textures, and no
-- Light (the live-light cap):
--   core   a short blue-white cone at the mouth, the hot gas
--   tongue the flame's body: fat near the mouth, stretched along its speed
--   lick   thinner, faster, wispier flames past the tongue, so the whole
--          flame tapers to a point (one emitter cannot tie size to reach)
--   sparks a few hot flecks thrown back, falling
--   smoke  a faint dark wisp left behind after
-- Lengths are metres before the car's scale; the item's flameSize scales
-- them all. Each layer: texture, count (min, max particles per pop at each
-- outlet), lifetime (s), speed (m/s), spreadDeg, drag, riseMps2 (upward
-- acceleration; negative falls), size, transparency and squash keyframes
-- ({time, value} over the particle's life; squash below 0 stretches it
-- along its motion, the particle drawn VelocityParallel), color (from, to)
-- where the layer has its own colour, lightEmission and brightness,
-- jetSeconds (let the count out over this long, a few a frame, so the
-- flame is one tongue from the mouth rather than a clump that leaves it),
-- alongMotion (drawn VelocityParallel, else facing the camera) and zOffsetM
-- (drawn this much nearer the camera, so the core shows through). locked
-- layers ride with the car (a 0.1 s core left in the air at 150 km/h would
-- smear 1.7 m behind); the rest are left in the world, inheriting part of
-- the car's velocity so they drift back from the car.
CosmeticsConfig.flames = {
	-- Where each flame starts: this far out along the outlet's LookVector,
	-- plus however far the mouth sits inside the bumper (a stock mouth up to
	-- ~9 cm in on the kamri07, CarCosmeticMounts bumperZ), so the core is
	-- never born hidden inside the body.
	mouthLeadM = 0.015,
	-- At speed the locked layers reach further back, as the airflow drags
	-- the flame out of the pipe: their speed times 1 + trailGain * f, f
	-- rising from 0 at rest to 1 at trailFullKmh.
	trailFullKmh = 160,
	trailGain = 1.2,
	-- The world-space layers (sparks, smoke) keep this much of the car's
	-- velocity when they are born, so they fall back from the car rather
	-- than being dropped on the road at once.
	inheritVelocity = 0.8,
	-- The tip's own glow for a moment after each pop: its colour pulled this
	-- far toward glowColor, easing back over glowSeconds. Only built tips and
	-- factory pipes glow; a car's own mesh pipe is left as it is.
	glowColor = Color3.fromHex("#FF6A1E"),
	glowAmount = 0.6,
	glowSeconds = 0.45,
	-- Particle time for inspecting the effect in Studio: each emitter's
	-- TimeScale, with jets and delays stretched to match, so a harness can
	-- run a pop at 0.1 and freeze it at any age (BEHAVIOURS, "Freeze a
	-- particle effect"). Must stay 1 in play; nothing in the game sets it.
	timeScale = 1,
	layers = {
		core = {
			texture = "rbxasset://textures/particles/explosion01_implosion_main.dds",
			count = { 5, 5 },
			jetSeconds = 0.09,
			lifetime = { 0.05, 0.08 },
			speed = { 0.5, 1.2 },
			spreadDeg = 4,
			drag = 0,
			riseMps2 = 0,
			size = { { 0, 0.07 }, { 0.3, 0.1 }, { 1, 0.04 } },
			transparency = { { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } },
			squash = { { 0, -1.2 }, { 1, -0.8 } },
			-- The item's flameCore, this much toward white at birth. Brightness
			-- 1 and little light emission: brighter, or additive over the
			-- tongue, and the blue clipped to white under the bloom.
			whiteAtBirth = 0.45,
			lightEmission = 0.15,
			brightness = 1,
			locked = true,
			alongMotion = true,
			zOffsetM = 0.08,
		},
		-- A soft glow on the mouth the moment it pops, facing the camera, so
		-- the pop reads from straight behind too (where the flame points at
		-- the camera and foreshortens to nothing) and stands in for the light
		-- the live-light cap rules out. In the item's flameColor.
		flash = {
			texture = "rbxasset://textures/particles/explosion01_implosion_main.dds",
			count = { 1, 1 },
			lifetime = { 0.07, 0.09 },
			speed = { 0, 0 },
			spreadDeg = 0,
			drag = 0,
			riseMps2 = 0,
			size = { { 0, 0.35 }, { 0.25, 0.6 }, { 1, 0.4 } },
			transparency = { { 0, 0.35 }, { 1, 1 } },
			squash = { { 0, 0 }, { 1, 0 } },
			lightEmission = 1,
			brightness = 1.2,
			locked = true,
			alongMotion = false,
			zOffsetM = 0.02,
		},
		tongue = {
			texture = "rbxasset://textures/particles/explosion01_implosion_main.dds",
			count = { 9, 10 },
			jetSeconds = 0.08,
			lifetime = { 0.14, 0.22 },
			speed = { 3, 8 },
			spreadDeg = 8,
			drag = 6,
			-- Enough lift that the flame curls up as it dies (a few cm would
			-- not show): about 15 cm over its life.
			riseMps2 = 8,
			-- Fullest early and shrinking after, so the far end tapers.
			size = { { 0, 0.1 }, { 0.12, 0.18 }, { 0.6, 0.08 }, { 1, 0.02 } },
			-- Thin at birth so the core shows at the mouth, fullest a quarter
			-- of the way out.
			transparency = { { 0, 0.5 }, { 0.25, 0.15 }, { 0.6, 0.3 }, { 1, 1 } },
			squash = { { 0, -1.2 }, { 1, -0.6 } },
			-- Orange-yellow at birth, the item's flameColor by a third of its
			-- life, deep red as it dies (the lick uses the same ramp).
			hot = Color3.fromHex("#FFC05A"),
			dying = Color3.fromHex("#C0300A"),
			lightEmission = 0.6,
			brightness = 0.9,
			locked = true,
			alongMotion = true,
			zOffsetM = 0.03,
		},
		lick = {
			texture = "rbxasset://textures/particles/explosion01_implosion_main.dds",
			count = { 5, 6 },
			jetSeconds = 0.09,
			lifetime = { 0.14, 0.22 },
			speed = { 3, 8 },
			spreadDeg = 10,
			drag = 5,
			riseMps2 = 10,
			size = { { 0, 0.14 }, { 0.12, 0.24 }, { 0.6, 0.1 }, { 1, 0.03 } },
			transparency = { { 0, 0.8 }, { 0.3, 0.6 }, { 0.6, 0.7 }, { 1, 1 } },
			squash = { { 0, -1.3 }, { 1, -0.8 } },
			lightEmission = 0.5,
			brightness = 1,
			locked = true,
			alongMotion = true,
			zOffsetM = 0,
		},
		sparks = {
			texture = "rbxasset://textures/particles/explosion01_implosion_main.dds",
			count = { 0, 3 },
			lifetime = { 0.25, 0.45 },
			speed = { 4, 8 },
			spreadDeg = 18,
			drag = 1.5,
			riseMps2 = -3,
			size = { { 0, 0.015 }, { 1, 0 } },
			transparency = { { 0, 0 }, { 1, 0.4 } },
			squash = { { 0, -2.5 }, { 1, -2.5 } },
			color = { from = Color3.fromHex("#FFE2A0"), to = Color3.fromHex("#FF5A14") },
			lightEmission = 1,
			brightness = 3,
			locked = false,
			alongMotion = true,
			zOffsetM = 0,
		},
		smoke = {
			texture = "rbxasset://textures/particles/smoke_main.dds",
			count = { 1, 1 },
			lifetime = { 0.6, 1 },
			speed = { 0.4, 0.9 },
			spreadDeg = 15,
			drag = 1,
			riseMps2 = 0.4,
			size = { { 0, 0.12 }, { 1, 0.45 } },
			transparency = { { 0, 0.82 }, { 1, 1 } },
			squash = { { 0, 0 }, { 1, 0 } },
			color = { from = Color3.fromHex("#2A2622"), to = Color3.fromHex("#4A4540") },
			lightEmission = 0,
			brightness = 1,
			locked = false,
			alongMotion = false,
			zOffsetM = -0.03,
			-- Born a moment after the flame, as the pop's gas cools.
			delaySeconds = 0.06,
		},
	},
}

-- Panel order: also the order categories' chips appear in within the panel.
-- tint was added last (garage round 2 §4), then tyre and flame
-- (garage-tyres-flames), so every look string written before them encodes
-- exactly as it did.
CosmeticsConfig.CATEGORIES = { "paint", "finish", "rims", "head", "tail", "decal", "exhaust", "tint", "tyre", "flame" } :: { Category }

-- Ordered as shown in the panel within each category.
CosmeticsConfig.items = {
	-- PAINT. The body colour. Stock keeps the catalog's own paint (no
	-- override); every other swatch is a flat Color3 the applier paints on.
	{ id = "paint_stock", category = "paint", name = "Factory", price = 0 },
	{ id = "paint_pearl", category = "paint", name = "Pearl White", price = 15000, color = Color3.fromHex("#EDEAE2") },
	{ id = "paint_sand", category = "paint", name = "Desert Sand", price = 15000, color = Color3.fromHex("#C9AE84") },
	{ id = "paint_sodium", category = "paint", name = "Sodium Orange", price = 25000, color = Color3.fromHex("#F08A24") },
	{ id = "paint_gold", category = "paint", name = "Dune Gold", price = 40000, color = Color3.fromHex("#B8913A") },
	{ id = "paint_black", category = "paint", name = "Asphalt Black", price = 15000, color = Color3.fromHex("#16151A") },
	{ id = "paint_green", category = "paint", name = "Gantry Green", price = 25000, color = Color3.fromHex("#145C38") },
	{ id = "paint_red", category = "paint", name = "Beacon Red", price = 25000, color = Color3.fromHex("#B3161E") },
	{ id = "paint_blue", category = "paint", name = "Night Blue", price = 25000, color = Color3.fromHex("#1B2A4E") },
	{ id = "paint_violet", category = "paint", name = "Dusk Violet", price = 40000, rare = true, color = Color3.fromHex("#5A2E6E") },
	{ id = "paint_silver", category = "paint", name = "Silver", price = 15000, color = Color3.fromHex("#A9ABAE") },
	{ id = "paint_gunmetal", category = "paint", name = "Gunmetal", price = 20000, color = Color3.fromHex("#3D4046") },
	{ id = "paint_rose", category = "paint", name = "Riyadh Rose", price = 40000, rare = true, color = Color3.fromHex("#C77D86") },
	-- Garage round 2 §4 (2026-09-28: "a handful more options, not many"):
	-- four colours the list lacked: a clay, a teal, a pale blue and an olive.
	-- Picked in the lit bay on the kamri07, whose lights lift and warm every
	-- colour: #9A4B30 clay rendered as a second Sodium Orange and a saffron
	-- yellow as a second Sodium, so the clay is taken dark and brown and the
	-- yellow was dropped for the blue; the first olive (#5C5A3C) read
	-- mustard beside Dune Gold, so it is taken greener.
	{ id = "paint_clay", category = "paint", name = "Najd Clay", price = 25000, color = Color3.fromHex("#6B4636") },
	{ id = "paint_teal", category = "paint", name = "Oasis Teal", price = 25000, color = Color3.fromHex("#1E6B68") },
	{ id = "paint_gulf", category = "paint", name = "Gulf Blue", price = 30000, color = Color3.fromHex("#7A9BB5") },
	{ id = "paint_olive", category = "paint", name = "Wadi Olive", price = 20000, color = Color3.fromHex("#474E36") },

	-- FINISH. The paint's material, reflectance and darkening; stock is the
	-- catalog's own material at reflectance 0.
	--
	-- Retuned in the lit bay 2026-09-28 (garage task 6, fix round 2), because
	-- the first values did not read: Lighting.Technology is ShadowMap, where
	-- the view's SpotLights give no specular highlight at all, Metal and Foil
	-- ignore Reflectance on these meshes (a red Lekzas at Metal 0.08 and at
	-- 0.35 was the same flat red as SmoothPlastic), and EnvironmentSpecular-
	-- and EnvironmentDiffuseScale changed nothing measurable indoors. Glass is
	-- the one material that answers the view's lights: at Reflectance 0 it
	-- keeps the paint colour and lays a lit sheen over the bonnet, roof and
	-- flanks (clear coat); more Reflectance washes the panels toward a pale
	-- silver. So the finishes are a ladder on Glass:
	--   matte    flat SmoothPlastic, the colour 20% darker and 30% less
	--            saturated: no sheen, and dull beside the factory colour
	--            (the old 8% darker could not be told from factory on red)
	--   gloss    Glass 0: the colour, with the lit sheen
	--   metallic Glass 0.05 over the colour 25% darker: sheen over the whole
	--            panel on a deeper base
	--   chrome   Glass 0.15 on the colour: pale liquid silver tinted by it
	--            (0.3 and a colour lightened toward white read as a plain
	--            white car)
	{ id = "finish_stock", category = "finish", name = "Factory", price = 0, reflectance = 0 },
	{ id = "finish_gloss", category = "finish", name = "Gloss", price = 10000, material = Enum.Material.Glass, reflectance = 0 },
	{ id = "finish_matte", category = "finish", name = "Matte", price = 30000, material = Enum.Material.SmoothPlastic, reflectance = 0, darken = 0.2, desaturate = 0.3 },
	{ id = "finish_metallic", category = "finish", name = "Metallic", price = 45000, material = Enum.Material.Glass, reflectance = 0.05, darken = 0.25 },
	{ id = "finish_chrome", category = "finish", name = "Chrome", price = 200000, rare = true, material = Enum.Material.Glass, reflectance = 0.15 },

	-- RIMS.
	{ id = "rims_stock", category = "rims", name = "Factory", price = 0 },
	{ id = "rims_black", category = "rims", name = "Gloss Black", price = 12000, color = Color3.fromHex("#121214"), material = Enum.Material.SmoothPlastic, reflectance = 0.1 },
	-- Chrome and gold on Glass, for the reason under FINISH (Foil and Metal
	-- read flat in the bay; 2026-09-28).
	{ id = "rims_chrome", category = "rims", name = "Chrome", price = 30000, color = Color3.fromHex("#B8BCC2"), material = Enum.Material.Glass, reflectance = 0.15 },
	{ id = "rims_gold", category = "rims", name = "Gold", price = 60000, rare = true, color = Color3.fromHex("#B8892E"), material = Enum.Material.Glass, reflectance = 0.05 },
	{ id = "rims_bronze", category = "rims", name = "Bronze", price = 35000, color = Color3.fromHex("#8C6A3F"), material = Enum.Material.Metal, reflectance = 0.1 },
	{ id = "rims_gunmetal", category = "rims", name = "Gunmetal", price = 20000, color = Color3.fromHex("#3A3C40"), material = Enum.Material.Metal, reflectance = 0.08 },
	{ id = "rims_white", category = "rims", name = "White", price = 20000, color = Color3.fromHex("#EDEDEA"), material = Enum.Material.SmoothPlastic, reflectance = 0.08 },
	-- Garage round 2 §4: two more, both on Glass at the gloss end of the
	-- FINISH ladder (reflectance 0 keeps the colour, with the lit sheen).
	{ id = "rims_red", category = "rims", name = "Candy Red", price = 25000, color = Color3.fromHex("#A3161C"), material = Enum.Material.Glass, reflectance = 0 },
	{ id = "rims_champagne", category = "rims", name = "Champagne", price = 35000, color = Color3.fromHex("#C4AE84"), material = Enum.Material.Glass, reflectance = 0.05 },

	-- HEAD (headlamp colour).
	{ id = "head_stock", category = "head", name = "Factory", price = 0 },
	{ id = "head_xenon", category = "head", name = "Xenon White", price = 20000, color = Color3.fromHex("#EAF2FF") },
	{ id = "head_ice", category = "head", name = "Ice Blue", price = 30000, color = Color3.fromHex("#A8D4FF") },
	{ id = "head_yellow", category = "head", name = "Halogen Yellow", price = 20000, color = Color3.fromHex("#FFD877") },
	{ id = "head_amber", category = "head", name = "Amber", price = 25000, color = Color3.fromHex("#FFB347") },

	-- TAIL (tail lamp colour).
	{ id = "tail_stock", category = "tail", name = "Factory", price = 0 },
	{ id = "tail_deep", category = "tail", name = "Deep Red", price = 15000, color = Color3.fromHex("#8A0508") },
	{ id = "tail_smoked", category = "tail", name = "Smoked", price = 25000, color = Color3.fromHex("#4A0A0C") },

	-- DECAL: the sun strip across the windscreen's top, with text, or none.
	-- The player reads SUN STRIPS (garage round 3 §4); the category, slot key
	-- and ids stay "decal" because profiles store them.
	{ id = "decal_none", category = "decal", name = "None", price = 0 },
	{ id = "decal_hajwala", category = "decal", name = "Hajwala Strip", price = 20000, text = "هجولة", stripColor = Color3.fromHex("#111111"), textColor = Color3.fromHex("#EDEAE2") },
	{ id = "decal_sunset", category = "decal", name = "Sunset Drift", price = 20000, text = "SUNSET DRIFT", stripColor = Color3.fromHex("#111111"), textColor = Color3.fromHex("#FFBA5C") },
	{ id = "decal_tarat", category = "decal", name = "Tarat", price = 25000, text = "طارت", stripColor = Color3.fromHex("#FFBA5C"), textColor = Color3.fromHex("#15130F") },
	{ id = "decal_gradient", category = "decal", name = "Dusk Gradient", price = 50000, rare = true, text = "", stripColor = Color3.fromHex("#FFBA5C"), stripColor2 = Color3.fromHex("#5A2E6E") },
	-- Garage round 2 §4: two more strips, a light one (the others are dark or
	-- sodium) and the game's other move.
	{ id = "decal_natl", category = "decal", name = "Natl", price = 25000, text = "نطل", stripColor = Color3.fromHex("#111111"), textColor = Color3.fromHex("#6FD39A") },
	{ id = "decal_white", category = "decal", name = "White Strip", price = 20000, text = "HAJWALA", stripColor = Color3.fromHex("#EDEAE2"), textColor = Color3.fromHex("#15130F") },

	-- EXHAUST: tip count, tip colour/material, and the sound tweaks they buy
	-- (engineVolume multiplies the engine sound, crackleChance the pops), and
	-- the flame profile (garage round 2 §2): factory small and orange, the
	-- sport tips larger and yellower with a bluer core, the burnt titanium
	-- largest with a blue-violet core, like the heat tint on its tips.
	-- Chrome tips (single, twin, oval) are light Metal (garage round 3 fix 1:
	-- #D8DADD Foil crinkled close up and bloomed near white under the garage
	-- lights). tipMaterial is the knob.
	{ id = "exhaust_stock", category = "exhaust", name = "Factory", price = 0, tips = 0, engineVolume = 1, crackleChance = 1, flameSize = 0.9, flameCore = Color3.fromHex("#6C8CFF"), flameColor = Color3.fromHex("#FF6A1A") },
	{ id = "exhaust_single", category = "exhaust", name = "Single Chrome Tip", price = 15000, tips = 1, tipStyle = "rolled", tipColor = Color3.fromHex("#C2C6CC"), tipMaterial = Enum.Material.Metal, engineVolume = 1.1, crackleChance = 1.3, flameSize = 1.2, flameCore = Color3.fromHex("#3A6BFF"), flameColor = Color3.fromHex("#FF7A1E") },
	{ id = "exhaust_twin", category = "exhaust", name = "Twin Chrome Tips", price = 30000, tips = 2, tipStyle = "rolled", tipColor = Color3.fromHex("#C2C6CC"), tipMaterial = Enum.Material.Metal, engineVolume = 1.2, crackleChance = 1.6, flameSize = 1.25, flameCore = Color3.fromHex("#3A6BFF"), flameColor = Color3.fromHex("#FF7A1E") },
	{ id = "exhaust_quad", category = "exhaust", name = "Quad Tips", price = 60000, tips = 4, tipStyle = "quad", tipColor = Color3.fromHex("#2A2A2E"), tipMaterial = Enum.Material.Metal, engineVolume = 1.3, crackleChance = 2, flameSize = 1.4, flameCore = Color3.fromHex("#2E62FF"), flameColor = Color3.fromHex("#FF8A24") },
	{ id = "exhaust_titanium", category = "exhaust", name = "Burnt Titanium Twin", price = 120000, rare = true, tips = 2, tipStyle = "slash", tipColor = Color3.fromHex("#6F5A8C"), tipMaterial = Enum.Material.Metal, engineVolume = 1.35, crackleChance = 2.5, flameSize = 1.5, flameCore = Color3.fromHex("#6A3CFF"), flameColor = Color3.fromHex("#FF6A2A") },
	-- Garage round 3 §1: one big oval rolled chrome tip, priced between the
	-- twin and the quad. Its flame is the single's, a little bigger (1.3
	-- against 1.2, still under the titanium's 1.5), and it pops a little
	-- more; the sound between the single's and the twin's.
	{ id = "exhaust_oval", category = "exhaust", name = "Big Oval Tip", price = 45000, tips = 1, tipStyle = "oval", tipColor = Color3.fromHex("#C2C6CC"), tipMaterial = Enum.Material.Metal, engineVolume = 1.15, crackleChance = 1.4, flameSize = 1.3, flameCore = Color3.fromHex("#3A6BFF"), flameColor = Color3.fromHex("#FF7A1E") },

	-- TINT (window film; garage round 2 §4, 2026-09-28: "window tint (glass
	-- colour and transparency, per car, under PAINT as a third row)"). Each
	-- is one film, the same on every car: the glass takes its colour on
	-- SmoothPlastic, the side and rear windows its glassTransparency, the
	-- windscreen its screenTransparency, and a piece that is both (the
	-- lekzas' and batrol's all-round glass) halfway between
	-- (CarCosmetics). screenTransparency stays light on every film, so the
	-- windscreen reads as legal and the strip and the cabin still show
	-- through it. Absolute, not relative to the factory glass: on the
	-- kamri07, whose factory doors are already dark (0.2), Light is lighter
	-- than factory; a film relative to factory did nothing at all there.
	-- Limo stops short of opaque (0.12, not 0), so the windows keep a
	-- little depth rather than turning to flat black plastic. Factory puts
	-- every piece back as the car was built. The pieces are per car
	-- (CarCosmeticMounts windows).
	{ id = "tint_stock", category = "tint", name = "Factory", price = 0 },
	{ id = "tint_light", category = "tint", name = "Light", price = 15000, glassColor = Color3.fromHex("#1C2328"), glassTransparency = 0.5, screenTransparency = 0.7 },
	{ id = "tint_dark", category = "tint", name = "Dark", price = 25000, glassColor = Color3.fromHex("#121619"), glassTransparency = 0.3, screenTransparency = 0.62 },
	{ id = "tint_limo", category = "tint", name = "Limo", price = 45000, rare = true, glassColor = Color3.fromHex("#0A0B0D"), glassTransparency = 0.12, screenTransparency = 0.55 },

	-- TYRES: the drift mode (DriftStyles; garage-tyres-flames). Classic is
	-- free and fits every car; the rest fit their own drivetrain only, and
	-- the garage shows a car the ones it can take. The modes are the drift
	-- overhaul's (2026-10-05), each tuned in Play; they change the handling,
	-- so they are priced alike, a first guess at 25,000 for the owner to
	-- weigh like every price here.
	{ id = "tyre_classic", category = "tyre", name = "Classic", price = 0 },
	{ id = "tyre_hajwala", category = "tyre", name = "Hajwala", price = 25000, driftStyle = "hajwala", layout = "RWD" },
	{ id = "tyre_kick", category = "tyre", name = "Kick", price = 25000, driftStyle = "power", layout = "RWD" },
	{ id = "tyre_angle", category = "tyre", name = "High Angle", price = 25000, driftStyle = "angle", layout = "RWD" },
	{ id = "tyre_tafheet", category = "tyre", name = "Tafheet", price = 25000, driftStyle = "tafheet", layout = "FWD" },
	{ id = "tyre_liftoff", category = "tyre", name = "Lift-Off", price = 25000, driftStyle = "liftoff", layout = "FWD" },
	{ id = "tyre_pivot", category = "tyre", name = "Pivot", price = 25000, driftStyle = "pivot", layout = "FWD" },
	{ id = "tyre_rally", category = "tyre", name = "Rally", price = 25000, driftStyle = "rally", layout = "AWD" },
	{ id = "tyre_driftmode", category = "tyre", name = "Drift Mode", price = 25000, driftStyle = "driftmode", layout = "AWD" },
	{ id = "tyre_tatweef", category = "tyre", name = "Tatweef", price = 25000, driftStyle = "tatweef", layout = "AWD" },

	-- FLAMES: the exhaust flame style (ExhaustStyles; garage-tyres-flames).
	-- Classic, the garage round 2 flame, is free; the 2026-10-04 styles are
	-- bought, a first guess priced by how much show they put on: Crackle's
	-- dense pops, 2-Step's even bangs, Blue Flame's long blue jets. The
	-- exhaust tips still scale whichever flame is on (crackleChance,
	-- flameSize).
	{ id = "flame_classic", category = "flame", name = "Classic", price = 0, flameStyle = "classic", flameCore = Color3.fromHex("#6C8CFF"), flameColor = Color3.fromHex("#FF6A1A") },
	{ id = "flame_crackle", category = "flame", name = "Crackle", price = 20000, flameStyle = "crackle", flameCore = Color3.fromHex("#4A7BFF"), flameColor = Color3.fromHex("#FF8A2A") },
	{ id = "flame_twostep", category = "flame", name = "2-Step", price = 30000, flameStyle = "twostep", flameCore = Color3.fromHex("#FFD27A"), flameColor = Color3.fromHex("#FF8A2A") },
	{ id = "flame_blue", category = "flame", name = "Blue Flame", price = 40000, rare = true, flameStyle = "blue", flameCore = Color3.fromHex("#2E5BFF"), flameColor = Color3.fromHex("#B040FF") },
} :: { Item }

local byId: { [string]: Item } = {}
local stockByCategory: { [string]: string } = {}
for _, item in CosmeticsConfig.items do
	byId[item.id] = item
	if item.price == 0 then
		stockByCategory[item.category] = item.id
	end
end
CosmeticsConfig.byId = byId

-- Every item in a category, in panel order.
function CosmeticsConfig.inCategory(c: Category): { Item }
	local out: { Item } = {}
	for _, item in CosmeticsConfig.items do
		if item.category == c then
			table.insert(out, item)
		end
	end
	return out
end

-- The free, factory-default item id for a category.
function CosmeticsConfig.stockId(c: Category): string
	local id = stockByCategory[c]
	assert(id, `no stock item for category {c}`)
	return id
end

-- Whether an id is a category's free, factory-default item.
function CosmeticsConfig.isStock(id: string): boolean
	local item = byId[id]
	return item ~= nil and item.price == 0
end

-- Whether an item fits a car of this drivetrain ("RWD", "FWD", "AWD"):
-- a tyre only its own; everything else, and the stock tyre, every car.
function CosmeticsConfig.fits(item: Item, layout: string): boolean
	return item.layout == nil or item.layout == layout
end

-- The item with this id, or nil.
function CosmeticsConfig.find(id: string?): Item?
	if id == nil then
		return nil
	end
	return byId[id]
end

return CosmeticsConfig
