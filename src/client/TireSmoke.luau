--!strict
-- White tyre smoke on every car (CarConfig.effects; heat model in shared
-- TireHeat; owner, 2026-10-04: "a fully comprehensive tire smoke system"
-- that fades in and out "at appropriate times (i.e. drifting, starting
-- stopping etc.)", then "a lot better, more accurate and realistic").
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
-- Each tyre has three smoke layers (smokeLayers: spray, billow, haze) and a
-- dust layer. They share one attachment at the contact patch that turns every
-- step to face the way the tread is sliding, so fresh smoke is thrown out of
-- a drift's arc or back out of a burnout. A ray finds what each tyre is on:
-- on sand or dirt it throws dust instead of smoke. Rates change; smoke
-- already in the air is never touched, so a cloud left behind a slide hangs
-- and dissolves on its own. Visual only.
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
type LayerConfig = typeof(ConfigLoader.current().effects.smokeLayers.spray)
type VehicleState = Types.VehicleState

local TireSmoke = {}

TireSmoke.ATTRIBUTE = "TireSmoke" -- on the car Model: TireHeat.pack of its four levels

-- Fresh smoke leaves the tread this far above the horizontal: it rolls up off
-- the road rather than skimming along it.
local THROW_PITCH = math.rad(15)
-- Below this tread speed (m/s) there is no telling which way it slides (the
-- wisps of a tyre that has gripped again): it rises off the back of the tyre.
local STILL_TREAD_MPS = 0.3
-- Surface checks: one wheel a step, so each wheel every fourth step.
local PROBE_DOWN_M = 2.5

type Wheel = {
	at: Attachment,
	base: Vector3, -- the contact patch, chassis space (studs)
	spray: ParticleEmitter,
	billow: ParticleEmitter,
	haze: ParticleEmitter,
	dust: ParticleEmitter,
	loose: boolean, -- on sand or dirt: dust, not smoke
	dustColor: Color3?,
	seed: number, -- where its puffing sits in the noise
}

-- Every emitter made, so a texture that fails to load can be swapped on all.
local emitters: { [ParticleEmitter]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local textureFailed = false

local function texture(cfg: Effects): string
	return if textureFailed then cfg.smokeTextureFallback else cfg.smokeTexture
end

-- Fetch the texture once; if it can't be had (deleted, moderated, offline),
-- every emitter falls back to Roblox's built-in smoke.
task.spawn(function()
	local cfg = ConfigLoader.current().effects
	ContentProvider:PreloadAsync({ cfg.smokeTexture }, function(_, status: Enum.AssetFetchStatus)
		if status ~= Enum.AssetFetchStatus.Success then
			textureFailed = true
			for e in emitters do
				e.Texture = cfg.smokeTextureFallback
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

local function emitter(name: string, parent: Attachment, layer: LayerConfig, cfg: Effects, mps: number, brightness: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.Texture = texture(cfg)
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
	local wind = cfg.smokeWindMps
	e.Acceleration = Vector3.new(wind[1] * k, layer.riseMps * k, wind[2] * k) / mps
	e.VelocityInheritance = layer.inherit -- the air the car drags along in its wake
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-layer.rotSpeedDeg, layer.rotSpeedDeg)
	e.LightEmission = cfg.smokeLightEmission
	e.LightInfluence = cfg.smokeLightInfluence
	e.Brightness = brightness
	e.Color = ColorSequence.new(cfg.smokeColor, cfg.smokeColorEnd)
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
		NumberSequenceKeypoint.new(0.06, a[1]),
		NumberSequenceKeypoint.new(0.5, a[2]),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.ZOffset = cfg.smokeZOffsetM / mps -- toward the camera, so the road doesn't slice it
	e.Parent = parent
	emitters[e] = true
	return e
end

-- One attachment per wheel at its contact patch, just above the road, with
-- its four emitters.
local function wheels(rig: VehicleRig.Handles, cfg: any, prefix: string): { Wheel }
	local mps = cfg.units.metersPerStud
	local fx: Effects = cfg.effects
	local drop = (cfg.suspension.restLength - VehicleRig.staticSagM(cfg) + cfg.body.wheelRadius - 0.12) / mps
	local out: { Wheel } = {}
	for i, def in VehicleRig.WHEELS do
		local a = Instance.new("Attachment")
		a.Name = prefix .. def.name
		local base = rig.rayOrigins[def.name].Position - Vector3.new(0, drop, 0)
		a.Position = base
		a.Parent = rig.chassis
		local L = fx.smokeLayers
		table.insert(out, {
			at = a,
			base = base,
			spray = emitter("Spray", a, L.spray, fx, mps, fx.smokeBrightness),
			billow = emitter("Billow", a, L.billow, fx, mps, fx.smokeBrightness),
			haze = emitter("Haze", a, L.haze, fx, mps, fx.smokeBrightness),
			dust = emitter("Dust", a, fx.dust.layer, fx, mps, 1),
			loose = false,
			dustColor = nil,
			seed = i * 1.37 + 0.5, -- off the integer lattice, where math.noise is 0
		})
	end
	return out
end

-- How long the slowest puff lives: what to wait before removing emitters.
local function longestLife(cfg: Effects): number
	local L = cfg.smokeLayers
	local t = cfg.dust.layer.lifetime[2]
	for _, layer in { L.spray, L.billow, L.haze } do
		t = math.max(t, layer.lifetime[2])
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
		w.spray.Rate = 0
		w.billow.Rate = 0
		w.haze.Rate = 0
		w.dust.Rate = 0
		local at = w.at
		task.delay(linger, function()
			at:Destroy()
		end)
	end
end

-- Turns a wheel's attachment to throw along the tread's slide (world m/s, in
-- the road plane), and sets each layer's launch speed from it.
local function aim(w: Wheel, chassisCf: CFrame, tread: Vector3, cfg: Effects, mps: number)
	local speed = tread.Magnitude
	local flat = if speed > STILL_TREAD_MPS then tread / speed else -flatAhead(chassisCf)
	local dir = flat * math.cos(THROW_PITCH) + Vector3.yAxis * math.sin(THROW_PITCH)
	local localDir = chassisCf:VectorToObjectSpace(dir)
	w.at.CFrame = CFrame.lookAt(w.base, w.base + localDir)
	local function launch(e: ParticleEmitter, layer: LayerConfig)
		local s = math.min(speed * layer.throw, layer.maxSpeedMps) / mps
		e.Speed = NumberRange.new(s * 0.6, s)
	end
	local L = cfg.smokeLayers
	launch(w.spray, L.spray)
	launch(w.billow, L.billow)
	launch(w.haze, L.haze)
	launch(w.dust, cfg.dust.layer)
end

-- Rates from the smoke and dust levels (0..1), puffing with a slow noise.
local function setLevel(w: Wheel, smoke: number, dust: number, cfg: Effects, scale: number, t: number)
	local pulse = 1 + cfg.smokePulse * math.noise(t * cfg.smokePulseHz, w.seed)
	local k = scale * math.max(0, pulse)
	local L = cfg.smokeLayers
	w.spray.Rate = L.spray.rate * smoke ^ L.spray.power * k
	w.billow.Rate = L.billow.rate * smoke ^ L.billow.power * k
	w.haze.Rate = L.haze.rate * smoke ^ L.haze.power * k
	w.dust.Rate = cfg.dust.layer.rate * dust ^ cfg.dust.layer.power * k
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

-- Each wheel's contact-patch slide speed (m/s, beyond grip) and the tread's
-- velocity over the road (m/s, world), from the chassis's motion (exact for
-- where each wheel is) and the sim's wheel state (steer, spin).
function TireSmoke.contacts(rig: VehicleRig.Handles, cfg: any, state: VehicleState): ({ number }, { Vector3 })
	local mps = cfg.units.metersPerStud
	local chassis = rig.chassis
	local cf = chassis.CFrame
	local v, w = chassis.AssemblyLinearVelocity, chassis.AssemblyAngularVelocity
	local slides, treads = {}, {}
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
	end
	return slides, treads
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
	local slides, treads = TireSmoke.contacts(o.rig, o.cfg, state)
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
		-- One level a wheel for everyone else; their own ray says which it is.
		o.levels[i] = math.max(smoke, o.dust[i])
		aim(w, cf, treads[i], cfg, mps)
		setLevel(w, smoke, o.dust[i], cfg, o.scale, o.t)
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
		setLevel(w, 0, 0, o.cfg.effects, o.scale, o.t)
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
		if level > 0.01 then
			local hp = r.rig.rayOrigins[VehicleRig.WHEELS[i].name].WorldPosition
			local pv = (v + w:Cross(hp - chassis.Position)) * mps
			local tread = TireHeat.treadVelocity(pv, heading, Vector3.new(pv.X, 0, pv.Z):Dot(heading))
			if tread.Magnitude < 1 then
				tread = -heading * 4
			end
			aim(wheel, cf, tread, cfg, mps)
		end
		if wheel.loose then
			setLevel(wheel, 0, level, cfg, r.scale, r.t)
		else
			setLevel(wheel, level, 0, cfg, r.scale, r.t)
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
