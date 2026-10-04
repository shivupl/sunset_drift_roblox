--!strict
-- White tyre smoke on every car (CarConfig.effects; heat model in shared
-- TireHeat; owner, 2026-10-04: "a fully comprehensive tire smoke system"
-- that fades in and out "at appropriate times (i.e. drifting, starting
-- stopping etc.)").
--
-- The car you drive: each wheel's contact patch slide speed comes from the
-- chassis's motion and the sim's wheel state, heats that tyre (TireHeat), and
-- the heat sets its smoke. The four levels go to the server at most
-- smokeRelayHz a second, only when they change (CarControls), and the server
-- stamps them on the car as the TireSmoke attribute.
--
-- Everyone else's cars: the TireSmoke attribute sets their smoke, smoothed,
-- so what you see is what their driver sees (burnouts and lock-ups too, which
-- can't be told from how a car moves). Only cars within remoteSmokeMaxM of
-- the camera with someone in the driver's seat.
--
-- Each tyre has two emitters: wisps that come in with any smoke, and the
-- thick billowing layer that only comes in near full. Rates change; smoke
-- already in the air is never touched, so a cloud left behind a slide hangs
-- and dissolves on its own. Visual only.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared.ConfigLoader)
local VehicleRig = require(Shared.VehicleRig)
local TireHeat = require(Shared.TireHeat)
local Types = require(Shared.Types)

type Effects = typeof(ConfigLoader.current().effects)
type VehicleState = Types.VehicleState

local TireSmoke = {}

TireSmoke.ATTRIBUTE = "TireSmoke" -- on the car Model: TireHeat.pack of its four levels

local TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

type Layer = { thick: ParticleEmitter, wisp: ParticleEmitter, at: Attachment }

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

local function emitter(name: string, parent: Attachment, cfg: Effects, mps: number, thick: boolean): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.Texture = TEXTURE
	local life = if thick then cfg.smokeLifetime else cfg.smokeWispLifetime
	e.Lifetime = NumberRange.new(life * 0.7, life)
	e.Speed = NumberRange.new(cfg.smokeSpeedMps[1] / mps, cfg.smokeSpeedMps[2] / mps)
	e.SpreadAngle = Vector2.new(70, 70)
	e.EmissionDirection = Enum.NormalId.Top
	e.Drag = cfg.smokeDrag
	e.WindAffectsDrag = true
	e.Acceleration = Vector3.new(0, cfg.smokeRise / mps, 0)
	e.VelocityInheritance = 0 -- left behind where it was made; it hangs in the air
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-20, 20)
	e.LightEmission = cfg.smokeLightEmission
	e.LightInfluence = cfg.smokeLightInfluence
	e.Color = ColorSequence.new(cfg.smokeColor, cfg.smokeColorEnd)
	local s0 = cfg.smokeStartSize / mps
	local s1 = (if thick then cfg.smokeSize else cfg.smokeWispSize) / mps
	-- Small at the tyre, growing most once it has lifted off the road, so it
	-- doesn't slice into the asphalt.
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, s0, s0 * 0.25),
		NumberSequenceKeypoint.new(0.3, s0 + (s1 - s0) * 0.45, s1 * 0.1),
		NumberSequenceKeypoint.new(1, s1, s1 * 0.15),
	})
	local a0 = if thick then cfg.smokeTransparency else cfg.smokeWispTransparency
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), -- fades in over its first moment, so puffs never pop
		NumberSequenceKeypoint.new(0.06, a0),
		NumberSequenceKeypoint.new(0.4, a0 + (1 - a0) * 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.ZOffset = cfg.smokeZOffsetM / mps -- toward the camera, so the road doesn't slice it
	e.Parent = parent
	return e
end

-- Two emitters per wheel at its contact patch, just above the road.
local function layers(rig: VehicleRig.Handles, cfg: any, prefix: string): { Layer }
	local mps = cfg.units.metersPerStud
	local drop = (cfg.suspension.restLength - VehicleRig.staticSagM(cfg) + cfg.body.wheelRadius - 0.12) / mps
	local out: { Layer } = {}
	for _, def in VehicleRig.WHEELS do
		local a = Instance.new("Attachment")
		a.Name = prefix .. def.name
		a.Position = rig.rayOrigins[def.name].Position - Vector3.new(0, drop, 0)
		a.Parent = rig.chassis
		table.insert(out, {
			at = a,
			thick = emitter("Smoke", a, cfg.effects, mps, true),
			wisp = emitter("Wisp", a, cfg.effects, mps, false),
		})
	end
	return out
end

-- Stops a set of emitters and removes them once their last puff has faded,
-- so a cloud never vanishes mid-air.
local function release(ls: { Layer }, linger: number)
	for _, l in ls do
		l.thick.Rate = 0
		l.wisp.Rate = 0
		local at = l.at
		task.delay(linger, function()
			at:Destroy()
		end)
	end
end

local function setLevel(l: Layer, level: number, cfg: Effects, scale: number)
	l.wisp.Rate = cfg.smokeWispRate * level * scale
	l.thick.Rate = cfg.smokeThickRate * level * level * scale
end

-- The car you drive -------------------------------------------------------

type Own = {
	model: Model,
	rig: VehicleRig.Handles,
	cfg: any,
	layers: { Layer },
	heat: { number },
	levels: { number },
	sentPacked: number,
	sinceSend: number,
	scale: number,
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
		layers = layers(rig, cfg, "Smoke_"),
		heat = { 0, 0, 0, 0 },
		levels = { 0, 0, 0, 0 },
		-- Nothing sent yet: the first update always sends, so a level left
		-- on the car from its last driver is cleared at once.
		sentPacked = -1,
		sinceSend = math.huge,
		scale = qualityScale(cfg.effects),
	}
end

-- Each wheel's contact-patch slide speed, m/s, from the chassis's motion
-- (exact for where each wheel is) and the sim's wheel state (steer, spin).
function TireSmoke.slideSpeeds(rig: VehicleRig.Handles, cfg: any, state: VehicleState): { number }
	local mps = cfg.units.metersPerStud
	local chassis = rig.chassis
	local cf = chassis.CFrame
	local v, w = chassis.AssemblyLinearVelocity, chassis.AssemblyAngularVelocity
	local out = {}
	for i, def in VehicleRig.WHEELS do
		local ws = state.wheels[i]
		local hp = rig.rayOrigins[def.name].WorldPosition
		local pv = (v + w:Cross(hp - chassis.Position)) * mps -- m/s
		local heading = (cf * CFrame.Angles(0, -math.rad(ws.steerDeg), 0)).LookVector
		-- The handbrake locks the rears (the sim's "locked-rear feel",
		-- CarConfig.handbrake), though its per-wheel lock flag only trips once
		-- the tyre is saturated: a lever pulled in a straight line drags them.
		local surface = if state.handbrake and not def.front then 0 else ws.visualOmega * cfg.body.wheelRadius
		out[i] = TireHeat.slideSpeed(cfg.effects.tireHeat, pv, heading, surface)
	end
	return out
end

-- Every sim step, from VehicleController.
function TireSmoke.update(state: VehicleState, dt: number)
	local o = own
	if not o then
		return
	end
	local cfg = o.cfg.effects
	local p = cfg.tireHeat
	local slides = TireSmoke.slideSpeeds(o.rig, o.cfg, state)
	for i, l in o.layers do
		local ws = state.wheels[i]
		o.heat[i] = TireHeat.step(p, o.heat[i], slides[i], ws.grounded, dt)
		o.levels[i] = TireHeat.intensity(p, o.heat[i], slides[i], ws.grounded)
		setLevel(l, o.levels[i], cfg, o.scale)
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
	for i, l in o.layers do
		o.heat[i] = 0
		o.levels[i] = 0
		setLevel(l, 0, o.cfg.effects, o.scale)
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
	release(o.layers, o.cfg.effects.smokeLifetime)
	if o.sentPacked ~= 0 then
		send(0)
	end
end

-- Other players' cars -----------------------------------------------------

type Remote = {
	model: Model,
	rig: VehicleRig.Handles,
	cfg: any,
	layers: { Layer },
	shown: { number },
	scale: number,
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
		layers = layers(rig, cfg, "RemoteSmoke_"),
		shown = { 0, 0, 0, 0 },
		scale = qualityScale(cfg.effects),
	}
end

-- Eases what's drawn toward the relayed levels, so 10 Hz steps don't show.
-- A car nobody is driving shows none, whatever its attribute last said.
local function updateRemote(r: Remote, dt: number)
	local cfg = r.cfg.effects
	local packed = r.model:GetAttribute(TireSmoke.ATTRIBUTE)
	local driven = r.rig.seat.Occupant ~= nil
	local target = if driven and type(packed) == "number" then TireHeat.unpack(packed) else { 0, 0, 0, 0 }
	local k = 1 - math.exp(-12 * dt)
	for i, l in r.layers do
		r.shown[i] += (target[i] - r.shown[i]) * k
		setLevel(l, r.shown[i], cfg, r.scale)
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
				release(r.layers, r.cfg.effects.smokeLifetime)
			end
		end
	end)
end

return TireSmoke
