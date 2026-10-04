--!strict
-- White tyre smoke on every car (CarConfig.effects; heat model in shared
-- TireHeat; owner, 2026-10-04: "a fully comprehensive tire smoke system"
-- that fades in and out "at appropriate times (i.e. drifting, starting
-- stopping etc.)", then "a lot better, more accurate and realistic", then on
-- the road less "patchy", following the wheels, and less of it).
--
-- The car you drive: each wheel's contact patch slide speed comes from the
-- chassis's motion and the sim's wheel state, heats that tyre (TireHeat,
-- harder the more load it carries), and the heat sets its smoke. The four
-- levels go to the server at most smokeRelayHz a second, only when they
-- change (CarControls), and the server stamps them on the car as the
-- TireSmoke attribute.
--
-- Everyone else's cars: the TireSmoke attribute sets their smoke, smoothed,
-- so what you see is what their driver sees (burnouts and lock-ups too, which
-- can't be told from how a car moves). Only cars within remoteSmokeMaxM of
-- the camera with someone in the driver's seat.
--
-- Each tyre has two attachments. Road smoke (smokeLayers: trail and its
-- wisps, billow, haze) is born at the live contact patch, where the wheel really touches
-- the road, and laid by distance with Emit (TireHeat.puffRate), so it lies
-- evenly along the tyre's track at any speed. Dust on sand or dirt keeps its
-- own attachment at the wheel's rest contact patch, its own settings
-- (CarConfig.effects.dust) and its running rate, exactly as the owner signed
-- it off. A ray finds what each tyre is on. Smoke already in the air is never
-- touched, so a cloud left behind a slide hangs and dissolves on its own.
-- Visual only.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared.ConfigLoader)
local VehicleRig = require(Shared.VehicleRig)
local TireHeat = require(Shared.TireHeat)
local Types = require(Shared.Types)

type Effects = typeof(ConfigLoader.current().effects)
type SmokeLayer = typeof(ConfigLoader.current().effects.smokeLayers.trail)
type VehicleState = Types.VehicleState

-- What an emitter is drawn from: a smoke layer or the dust layer.
type Visual = {
	lifetime: { number },
	sizeM: { number },
	transparency: { number },
	throw: number,
	maxSpeedMps: number,
	spreadDeg: number,
	drag: number,
	riseMps: number,
	inherit: number,
	rotSpeedDeg: number,
	squash: { number },
}

-- How a set of emitters is lit and placed: the smoke's, or the dust's own.
type Look = {
	texture: string,
	windMps: { number },
	lightInfluence: number,
	lightEmission: number,
	brightness: number,
	zOffsetM: number,
	color: ColorSequence,
}

local TireSmoke = {}

TireSmoke.ATTRIBUTE = "TireSmoke" -- on the car Model: TireHeat.pack of its four levels

-- Below this tread speed (m/s) there is no telling which way it slides (the
-- wisps of a tyre that has gripped again): it rises off the back of the tyre.
local STILL_TREAD_MPS = 0.3
-- Surface checks: one wheel a step, so each wheel every fourth step.
local PROBE_DOWN_M = 2.5
-- Smoke is born this far above the road, so a new puff isn't half under it.
local PATCH_LIFT_M = 0.12
-- The most puffs one layer lets out in a step (after a hitch, say).
local MAX_EMIT = 6
-- Dust fades in over this share of its life, as when the owner signed it off.
local DUST_FADE_IN = 0.06

local SMOKE_LAYERS = { "trail", "wisp", "billow", "haze" }

type Wheel = {
	at: Attachment, -- dust: at the rest contact patch, turned to its throw
	base: Vector3, -- that patch, chassis space (studs)
	dust: ParticleEmitter,
	smokeAt: Attachment, -- smoke: at the live contact patch
	hub: Weld, -- the wheel's weld; its C0 is where the wheel is now
	smoke: { [string]: ParticleEmitter },
	owed: { [string]: number }, -- puffs each smoke layer is owed (fractions carry over)
	shown: number, -- the smoke level puffs are laid at, eased
	loose: boolean, -- on sand or dirt: dust, not smoke
	dustColor: Color3?,
	seed: number, -- where its dust puffing sits in the noise
}

-- Every emitter made, with the texture it asked for, so a texture that fails
-- to load can be swapped on all that use it.
local emitters: { [ParticleEmitter]: string } = setmetatable({}, { __mode = "k" }) :: any
local failed: { [string]: boolean } = {}

-- Fetch the textures once; if one can't be had (deleted, moderated,
-- offline), its emitters fall back to Roblox's built-in smoke.
task.spawn(function()
	local cfg = ConfigLoader.current().effects
	local fallback = cfg.smokeTextureFallback
	ContentProvider:PreloadAsync({ cfg.smokeTexture, cfg.dust.texture }, function(id: string, status: Enum.AssetFetchStatus)
		if status ~= Enum.AssetFetchStatus.Success then
			failed[id] = true
			for e, wanted in emitters do
				if wanted == id then
					e.Texture = fallback
				end
			end
		end
	end)
end)

-- How much of the rate this client draws: lower on low graphics settings.
local function qualityScale(cfg: Effects): number
	local ok, level = pcall(function(): number
		return (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel.Value
	end)
	-- 0 is "Automatic": draw it all.
	if ok and type(level) == "number" and level > 0 and level < cfg.lowQualityLevel then
		return cfg.lowQualitySmokeScale
	end
	return 1
end

local function smokeLook(cfg: Effects): Look
	return {
		texture = cfg.smokeTexture,
		windMps = cfg.smokeWindMps,
		lightInfluence = cfg.smokeLightInfluence,
		lightEmission = cfg.smokeLightEmission,
		brightness = cfg.smokeBrightness,
		zOffsetM = cfg.smokeZOffsetM,
		color = ColorSequence.new(cfg.smokeColor, cfg.smokeColorEnd),
	}
end

local function dustLook(cfg: Effects): Look
	local d = cfg.dust
	return {
		texture = d.texture,
		windMps = d.windMps,
		lightInfluence = d.lightInfluence,
		lightEmission = d.lightEmission,
		brightness = d.brightness,
		zOffsetM = d.zOffsetM,
		-- Replaced by the ground's colour (probe) before any dust is let out.
		color = ColorSequence.new(Color3.new(1, 1, 1)),
	}
end

-- `fadeIn` is the share of a puff's life it takes to fade in.
local function emitter(name: string, parent: Attachment, layer: Visual, look: Look, cfg: Effects, mps: number, fadeIn: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.Texture = if failed[look.texture] then cfg.smokeTextureFallback else look.texture
	e.Lifetime = NumberRange.new(layer.lifetime[1], layer.lifetime[2])
	e.Speed = NumberRange.new(0)
	e.SpreadAngle = Vector2.new(layer.spreadDeg, layer.spreadDeg)
	e.EmissionDirection = Enum.NormalId.Front -- the attachment faces the throw
	e.Drag = layer.drag
	e.WindAffectsDrag = true
	-- Roblox's drag halves the speed `drag` times a second, so it pulls a
	-- puff toward still air at rate k = drag ln 2. A steady push of k times a
	-- velocity settles the puff at that velocity: the climb and the breeze.
	local k = layer.drag * math.log(2)
	local wind = look.windMps
	e.Acceleration = Vector3.new(wind[1] * k, layer.riseMps * k, wind[2] * k) / mps
	e.VelocityInheritance = layer.inherit -- the air the car drags along in its wake
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-layer.rotSpeedDeg, layer.rotSpeedDeg)
	e.LightEmission = look.lightEmission
	e.LightInfluence = look.lightInfluence
	e.Brightness = look.brightness
	e.Color = look.color
	local s = layer.sizeM
	-- Small at the tyre so it doesn't slice into the road, spreading fastest
	-- over its first quarter, then slowly.
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, s[1] / mps, s[1] * 0.2 / mps),
		NumberSequenceKeypoint.new(0.25, s[2] / mps, s[2] * 0.15 / mps),
		NumberSequenceKeypoint.new(1, s[3] / mps, s[3] * 0.15 / mps),
	})
	local q = layer.squash
	e.Squash = NumberSequence.new({
		NumberSequenceKeypoint.new(0, q[1]),
		NumberSequenceKeypoint.new(0.3, q[2]),
		NumberSequenceKeypoint.new(1, q[3]),
	})
	local a = layer.transparency
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), -- fades in over its first moment, so puffs never pop
		NumberSequenceKeypoint.new(fadeIn, a[1]),
		NumberSequenceKeypoint.new(0.5, a[2]),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.ZOffset = look.zOffsetM / mps -- toward the camera, so the road doesn't slice it
	e.Parent = parent
	emitters[e] = look.texture
	return e
end

-- Each wheel's two attachments and their emitters.
local function wheels(rig: VehicleRig.Handles, cfg: any, prefix: string): { Wheel }
	local mps = cfg.units.metersPerStud
	local fx: Effects = cfg.effects
	local drop = (cfg.suspension.restLength - VehicleRig.staticSagM(cfg) + cfg.body.wheelRadius - PATCH_LIFT_M) / mps
	local smoke, dust = smokeLook(fx), dustLook(fx)
	local out: { Wheel } = {}
	for i, def in VehicleRig.WHEELS do
		local a = Instance.new("Attachment")
		a.Name = prefix .. def.name
		local base = rig.rayOrigins[def.name].Position - Vector3.new(0, drop, 0)
		a.Position = base
		a.Parent = rig.chassis
		local s = Instance.new("Attachment")
		s.Name = prefix .. "Road" .. def.name
		s.Position = base
		s.Parent = rig.chassis
		local emitted: { [string]: ParticleEmitter } = {}
		local owed: { [string]: number } = {}
		for _, name in SMOKE_LAYERS do
			local layer: SmokeLayer = (fx.smokeLayers :: any)[name]
			emitted[name] = emitter(name, s, layer, smoke, fx, mps, layer.fadeIn)
			owed[name] = 0
		end
		table.insert(out, {
			at = a,
			base = base,
			dust = emitter("Dust", a, fx.dust.layer, dust, fx, mps, DUST_FADE_IN),
			smokeAt = s,
			hub = rig.hubs[def.name].weld,
			smoke = emitted,
			owed = owed,
			shown = 0,
			loose = false,
			dustColor = nil,
			seed = i * 1.37 + 0.5, -- off the integer lattice, where math.noise is 0
		})
	end
	return out
end

-- How long the slowest puff lives: what to wait before removing emitters.
local function longestLife(cfg: Effects): number
	local t = cfg.dust.layer.lifetime[2]
	for _, name in SMOKE_LAYERS do
		t = math.max(t, (cfg.smokeLayers :: any)[name].lifetime[2])
	end
	return t
end

-- The way a frame points, flattened onto the road (its back if it points
-- straight up or down, as when standing on its nose).
local function flatAhead(cf: CFrame): Vector3
	local f = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if f.Magnitude < 1e-3 then
		f = Vector3.new(-cf.UpVector.X, 0, -cf.UpVector.Z)
	end
	return if f.Magnitude < 1e-3 then Vector3.zAxis else f.Unit
end

-- Stops a set of emitters and removes them once their last puff has faded,
-- so a cloud never vanishes mid-air.
local function release(ws: { Wheel }, linger: number)
	for _, w in ws do
		w.dust.Rate = 0
		local at, smokeAt = w.at, w.smokeAt
		task.delay(linger, function()
			at:Destroy()
			smokeAt:Destroy()
		end)
	end
end

-- Which way to throw, chassis space: along the tread's slide (world m/s, in
-- the road plane), tipped up by `pitch`.
local function throwDir(chassisCf: CFrame, tread: Vector3, pitch: number): (Vector3, number)
	local speed = tread.Magnitude
	local flat = if speed > STILL_TREAD_MPS then tread / speed else -flatAhead(chassisCf)
	local dir = flat * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)
	return chassisCf:VectorToObjectSpace(dir), speed
end

-- Dust: turns its attachment to throw along the tread's slide and sets the
-- launch speed from it.
local function aimDust(w: Wheel, chassisCf: CFrame, tread: Vector3, cfg: Effects, mps: number)
	local d = cfg.dust
	local dir, speed = throwDir(chassisCf, tread, math.rad(d.pitchDeg))
	w.at.CFrame = CFrame.lookAt(w.base, w.base + dir)
	local s = math.min(speed * d.layer.throw, d.layer.maxSpeedMps) / mps
	w.dust.Speed = NumberRange.new(s * 0.6, s)
end

-- Dust's rate from its level (0..1), puffing with a slow noise.
local function setDust(w: Wheel, level: number, cfg: Effects, scale: number, t: number)
	local d = cfg.dust
	local pulse = 1 + d.pulse * math.noise(t * d.pulseHz, w.seed)
	w.dust.Rate = d.layer.rate * level ^ d.layer.power * scale * math.max(0, pulse)
end

-- Smoke: moves its attachment to where the tyre touches the road now (the
-- wheel's weld, which the sim or WheelVisuals sets with the springs), turned
-- to the tread's slide, and sets each layer's launch speed.
local function aimSmoke(w: Wheel, chassisCf: CFrame, tread: Vector3, cfg: any, mps: number)
	local fx: Effects = cfg.effects
	local patch = w.hub.C0.Position - Vector3.new(0, (cfg.body.wheelRadius - PATCH_LIFT_M) / mps, 0)
	local dir, speed = throwDir(chassisCf, tread, math.rad(fx.smokePitchDeg))
	w.smokeAt.CFrame = CFrame.lookAt(patch, patch + dir)
	for _, name in SMOKE_LAYERS do
		local layer: SmokeLayer = (fx.smokeLayers :: any)[name]
		local s = math.min(speed * layer.throw, layer.maxSpeedMps) / mps
		w.smoke[name].Speed = NumberRange.new(s * 0.6, s)
	end
end

-- Lets out the puffs each smoke layer is owed for `dt` at this level, laid by
-- the distance the contact patch has covered (groundMps, m/s). The trail and
-- its wisps split one stream (TireHeat.streamShares); billow and haze go by
-- the level to their `power`.
local function emitSmoke(w: Wheel, level: number, groundMps: number, cfg: Effects, scale: number, dt: number)
	local full, wisp = TireHeat.streamShares(level, cfg.smokeWispTaper)
	for _, name in SMOKE_LAYERS do
		local layer: SmokeLayer = (cfg.smokeLayers :: any)[name]
		local share = if name == "trail" then full elseif name == "wisp" then wisp else level ^ layer.power
		local rate = TireHeat.puffRate(layer.perSecond, layer.perMetre, groundMps, cfg.smokeTravelCapMps)
		local owed = w.owed[name] + rate * share * scale * dt
		local n = math.floor(owed)
		if n > 0 then
			w.smoke[name]:Emit(math.min(n, MAX_EMIT))
			owed -= n
		end
		w.owed[name] = owed
	end
end

-- Casts down from one wheel's hardpoint and notes whether it is on loose
-- ground, and if so that ground's colour for the dust.
local function probe(w: Wheel, origin: Vector3, params: RaycastParams, cfg: Effects, mps: number)
	local hit = workspace:Raycast(origin, Vector3.new(0, -PROBE_DOWN_M / mps, 0), params)
	if not hit then
		return -- in the air: keep what it was on
	end
	w.loose = table.find(cfg.dust.materials, hit.Material) ~= nil
	if not w.loose then
		return
	end
	local base = if hit.Instance:IsA("Terrain")
		then (hit.Instance :: Terrain):GetMaterialColor(hit.Material)
		else (hit.Instance :: BasePart).Color
	local c = base:Lerp(Color3.new(1, 1, 1), cfg.dust.lighten)
	local was = w.dustColor
	-- Recolouring touches the dust already in the air, so only on a real
	-- change of ground.
	if not was or math.abs(was.R - c.R) + math.abs(was.G - c.G) + math.abs(was.B - c.B) > 0.06 then
		w.dustColor = c
		w.dust.Color = ColorSequence.new(c, c:Lerp(Color3.new(1, 1, 1), 0.15))
	end
end

local function rayParams(model: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { model }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	return params
end

-- Eases a level toward a target, quicker up than down.
local function ease(level: number, target: number, dt: number, attack: number, release: number): number
	local tau = if target > level then attack else release
	return level + (target - level) * (1 - math.exp(-dt / math.max(tau, 1e-3)))
end

local function flatSpeed(v: Vector3): number
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

-- The car you drive -------------------------------------------------------

type Own = {
	model: Model,
	rig: VehicleRig.Handles,
	cfg: any,
	wheels: { Wheel },
	heat: { number },
	levels: { number },
	dust: { number },
	sentPacked: number,
	sinceSend: number,
	scale: number,
	t: number,
	probeAt: number,
	params: RaycastParams,
}
local own: Own? = nil
local relay: RemoteEvent? = nil

function TireSmoke.setRemotes(remotes: Folder)
	local r = remotes:FindFirstChild("TireSmoke")
	relay = if r and r:IsA("RemoteEvent") then r else nil
end

local function send(packed: number)
	if relay then
		relay:FireServer(packed)
	end
end

function TireSmoke.attach(model: Model)
	TireSmoke.detach()
	local id = model:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
	local cfg = ConfigLoader.forCar(if type(id) == "string" then id else nil)
	if not cfg.effects.enabled then
		return
	end
	local rig = VehicleRig.handles(model)
	own = {
		model = model,
		rig = rig,
		cfg = cfg,
		wheels = wheels(rig, cfg, "Smoke_"),
		heat = { 0, 0, 0, 0 },
		levels = { 0, 0, 0, 0 },
		dust = { 0, 0, 0, 0 },
		-- Nothing sent yet: the first update always sends, so a level left
		-- on the car from its last driver is cleared at once.
		sentPacked = -1,
		sinceSend = math.huge,
		scale = qualityScale(cfg.effects),
		t = 0,
		probeAt = 0,
		params = rayParams(model),
	}
end

-- Each wheel's contact-patch slide speed (m/s, beyond grip), the tread's
-- velocity over the road (m/s, world) and the patch's own speed over the
-- road (m/s), from the chassis's motion (exact for where each wheel is) and
-- the sim's wheel state (steer, spin).
function TireSmoke.contacts(rig: VehicleRig.Handles, cfg: any, state: VehicleState): ({ number }, { Vector3 }, { number })
	local mps = cfg.units.metersPerStud
	local chassis = rig.chassis
	local cf = chassis.CFrame
	local v, w = chassis.AssemblyLinearVelocity, chassis.AssemblyAngularVelocity
	local slides, treads, grounds = {}, {}, {}
	for i, def in VehicleRig.WHEELS do
		local ws = state.wheels[i]
		local hp = rig.rayOrigins[def.name].WorldPosition
		local pv = (v + w:Cross(hp - chassis.Position)) * mps -- m/s
		local heading = (cf * CFrame.Angles(0, -math.rad(ws.steerDeg), 0)).LookVector
		-- The handbrake locks the rears (the sim's "locked-rear feel",
		-- CarConfig.handbrake), though its per-wheel lock flag only trips once
		-- the tyre is saturated: a lever pulled in a straight line drags them.
		local surface = if state.handbrake and not def.front then 0 else ws.visualOmega * cfg.body.wheelRadius
		slides[i] = TireHeat.slideSpeed(cfg.effects.tireHeat, pv, heading, surface)
		treads[i] = TireHeat.treadVelocity(pv, heading, surface)
		grounds[i] = flatSpeed(pv)
	end
	return slides, treads, grounds
end

-- Every sim step, from VehicleController.
function TireSmoke.update(state: VehicleState, dt: number)
	local o = own
	if not o then
		return
	end
	local cfg: Effects = o.cfg.effects
	local mps = o.cfg.units.metersPerStud
	local p = cfg.tireHeat
	o.t += dt
	-- What the tyres are on: one wheel a step.
	o.probeAt = o.probeAt % #o.wheels + 1
	local probeName = VehicleRig.WHEELS[o.probeAt].name
	probe(o.wheels[o.probeAt], o.rig.rayOrigins[probeName].WorldPosition, o.params, cfg, mps)
	local slides, treads, grounds = TireSmoke.contacts(o.rig, o.cfg, state)
	local loads = {}
	for i, ws in state.wheels do
		loads[i] = if ws.grounded then ws.load else 0
	end
	local shares = TireHeat.loadShares(loads)
	local cf = o.rig.chassis.CFrame
	for i, w in o.wheels do
		local ws = state.wheels[i]
		-- Sand never cooks the tread: there the tyre cools and throws dust.
		local slide = if w.loose then 0 else slides[i]
		o.heat[i] = TireHeat.step(p, o.heat[i], slide, ws.grounded, dt, shares[i])
		local smoke = if w.loose then 0 else TireHeat.intensity(p, o.heat[i], slide, ws.grounded, shares[i])
		local dustTarget = if w.loose then TireHeat.dust(cfg.dust.amount, slides[i], state.speedMps, ws.grounded) else 0
		o.dust[i] = ease(o.dust[i], dustTarget, dt, cfg.dust.attackSeconds, cfg.dust.releaseSeconds)
		w.shown = ease(w.shown, smoke, dt, cfg.smokeAttackSeconds, cfg.smokeReleaseSeconds)
		-- One level a wheel for everyone else; their own ray says which it is.
		o.levels[i] = math.max(w.shown, o.dust[i])
		aimDust(w, cf, treads[i], cfg, mps)
		setDust(w, o.dust[i], cfg, o.scale, o.t)
		if w.shown > 0.005 then
			aimSmoke(w, cf, treads[i], o.cfg, mps)
			emitSmoke(w, w.shown, grounds[i], cfg, o.scale, dt)
		end
	end
	-- Tell everyone else, only when it changed, at most smokeRelayHz.
	o.sinceSend += dt
	local packed = TireHeat.pack(o.levels)
	if packed ~= o.sentPacked and o.sinceSend >= 1 / cfg.smokeRelayHz then
		o.sentPacked = packed
		o.sinceSend = 0
		send(packed)
	end
end

-- Stops the smoke where it is without forgetting the car: while the sim isn't
-- stepping (a flip, a hold) nothing feeds it, so it mustn't keep emitting at
-- its last level.
function TireSmoke.pause()
	local o = own
	if not o then
		return
	end
	for i, w in o.wheels do
		o.heat[i] = 0
		o.levels[i] = 0
		o.dust[i] = 0
		w.shown = 0
		setDust(w, 0, o.cfg.effects, o.scale, o.t)
	end
	if o.sentPacked ~= 0 then
		o.sentPacked = 0
		send(0)
	end
end

-- The smoke levels and tyre heats of the car you drive now (tests, debug).
function TireSmoke.levels(): ({ number }?, { number }?)
	local o = own
	if not o then
		return nil, nil
	end
	return table.clone(o.levels), table.clone(o.heat)
end

function TireSmoke.detach()
	local o = own
	if not o then
		return
	end
	own = nil
	release(o.wheels, longestLife(o.cfg.effects))
	if o.sentPacked ~= 0 then
		send(0)
	end
end

-- Other players' cars -----------------------------------------------------

type Remote = {
	model: Model,
	rig: VehicleRig.Handles,
	cfg: any,
	wheels: { Wheel },
	shown: { number },
	scale: number,
	t: number,
	probeAt: number,
	params: RaycastParams,
}

local remotes: { [Model]: Remote } = {}

local function attachRemote(model: Model): Remote?
	local ok, rig = pcall(VehicleRig.handles, model)
	if not ok then
		return nil
	end
	local id = model:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
	local cfg = ConfigLoader.forCar(if type(id) == "string" then id else nil)
	if not cfg.effects.enabled then
		return nil
	end
	return {
		model = model,
		rig = rig,
		cfg = cfg,
		wheels = wheels(rig, cfg, "RemoteSmoke_"),
		shown = { 0, 0, 0, 0 },
		scale = qualityScale(cfg.effects),
		t = 0,
		probeAt = 0,
		params = rayParams(model),
	}
end

-- Eases what's drawn toward the relayed levels, so 10 Hz steps don't show.
-- A car nobody is driving shows none, whatever its attribute last said.
-- The throw direction comes from how the car moves here: a rear tyre's
-- sideways slide is the car's own sideways motion at that wheel (the wheel's
-- spin isn't relayed, so a burnout or lock-up just throws it back).
local function updateRemote(r: Remote, dt: number)
	local cfg: Effects = r.cfg.effects
	local mps = r.cfg.units.metersPerStud
	r.t += dt
	local packed = r.model:GetAttribute(TireSmoke.ATTRIBUTE)
	local driven = r.rig.seat.Occupant ~= nil
	local target = if driven and type(packed) == "number" then TireHeat.unpack(packed) else { 0, 0, 0, 0 }
	r.probeAt = r.probeAt % #r.wheels + 1
	local probeName = VehicleRig.WHEELS[r.probeAt].name
	probe(r.wheels[r.probeAt], r.rig.rayOrigins[probeName].WorldPosition, r.params, cfg, mps)
	local chassis = r.rig.chassis
	local cf = chassis.CFrame
	local v, w = chassis.AssemblyLinearVelocity, chassis.AssemblyAngularVelocity
	local heading = flatAhead(cf)
	local k = 1 - math.exp(-12 * dt)
	for i, wheel in r.wheels do
		r.shown[i] += (target[i] - r.shown[i]) * k
		local level = r.shown[i]
		local hp = r.rig.rayOrigins[VehicleRig.WHEELS[i].name].WorldPosition
		local pv = (v + w:Cross(hp - chassis.Position)) * mps
		if level > 0.01 then
			local tread = TireHeat.treadVelocity(pv, heading, Vector3.new(pv.X, 0, pv.Z):Dot(heading))
			if tread.Magnitude < 1 then
				tread = -heading * 4
			end
			aimDust(wheel, cf, tread, cfg, mps)
			if not wheel.loose then
				aimSmoke(wheel, cf, tread, r.cfg, mps)
			end
		end
		if wheel.loose then
			setDust(wheel, level, cfg, r.scale, r.t)
		else
			setDust(wheel, 0, cfg, r.scale, r.t)
			if level > 0.01 then
				emitSmoke(wheel, level, flatSpeed(pv), cfg, r.scale, dt)
			end
		end
	end
end

local started = false

-- Smoke for every car but `mine()` (the one this client drives, smoked from
-- its sim through attach / update).
function TireSmoke.start(mine: () -> Model?)
	if started then
		return
	end
	started = true
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 / 30 then
			return
		end
		local step = acc
		acc = 0
		local folder = workspace:FindFirstChild("Cars")
		local camera = workspace.CurrentCamera
		local skip = mine()
		local seen: { [Model]: boolean } = {}
		if folder and camera then
			local eye = camera.CFrame.Position
			local shared = ConfigLoader.current()
			for _, model in folder:GetChildren() do
				if not model:IsA("Model") or model == skip then
					continue
				end
				local primary = model.PrimaryPart
				if not primary then
					continue
				end
				local r = remotes[model]
				local mps = if r then r.cfg.units.metersPerStud else shared.units.metersPerStud
				local maxM = if r then r.cfg.effects.remoteSmokeMaxM else shared.effects.remoteSmokeMaxM
				if (primary.Position - eye).Magnitude * mps > maxM then
					continue
				end
				local live = r or attachRemote(model)
				if not live then
					continue
				end
				remotes[model] = live
				seen[model] = true
				updateRemote(live, step)
			end
		end
		for model, r in remotes do
			if not seen[model] then
				remotes[model] = nil
				release(r.wheels, longestLife(r.cfg.effects))
			end
		end
	end)
end

return TireSmoke
