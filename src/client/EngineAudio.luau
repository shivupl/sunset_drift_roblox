--!strict
-- The engine you hear, on the driver's client. Four layers (idle, low load,
-- high load, overrun) crossfaded by the rpm and throttle the sim already
-- reports; nothing here computes engine state of its own. Pitch follows
-- rpm, so the gearbox is heard as the rpm drop at each shift.
--
-- Weights are equal-power: idle against the rest by rpm just above idle,
-- low against high load by rpm, and on-load against overrun by throttle.
-- The squares sum to one, so the level never dips between layers.
--
-- Layers that share a sound id share one Sound, whose volume and EQ blend
-- from those layers. Several copies of one loop playing together would
-- drift out of phase and comb; this way a placeholder set built from one
-- loop is a tone blend, and a real four-loop pack is four Sounds.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local ConfigLoader = require(Shared.ConfigLoader)
local VehicleRig = require(Shared.VehicleRig)

type VehicleState = Types.VehicleState

type Layer = {
	soundId: string,
	refRpm: number,
	volume: number,
	eq: { number },
}

type Voice = {
	sound: Sound,
	eq: EqualizerSoundEffect,
	refRpm: number,
	members: { string }, -- layer names this Sound plays
}

local EngineAudio = {}

local LAYER_NAMES = { "idle", "lowLoad", "highLoad", "overrun" }
local HALF_PI = math.pi / 2

local voices: { Voice } = {}
local gains: { [string]: number } = {}
local carId: string? = nil

local function layersOf(cfg: ConfigLoader.Config): { [string]: Layer }
	local layers = (cfg.effects.engineAudio.layers :: any) :: { [string]: Layer }
	return layers
end

function EngineAudio.attach(model: Model)
	EngineAudio.detach()
	local id = model:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
	carId = if type(id) == "string" then id else nil
	local cfg = ConfigLoader.forCar(carId)
	if not cfg.effects.enabled then
		return
	end
	local chassis = VehicleRig.handles(model).chassis
	local layers = layersOf(cfg)
	local byId: { [string]: Voice } = {}
	for _, name in LAYER_NAMES do
		local layer = layers[name]
		gains[name] = 0
		if layer and layer.soundId ~= "" then
			local voice = byId[layer.soundId]
			if not voice then
				local s = Instance.new("Sound")
				s.Name = "Engine_" .. name
				s.SoundId = layer.soundId
				s.Looped = true
				s.Volume = 0
				s.RollOffMaxDistance = 120
				local eq = Instance.new("EqualizerSoundEffect")
				eq.Parent = s
				s.Parent = chassis
				s:Play()
				local v: Voice = { sound = s, eq = eq, refRpm = layer.refRpm, members = {} }
				byId[layer.soundId] = v
				table.insert(voices, v)
				voice = v
			end
			table.insert(voice.members, name)
		end
	end
end

function EngineAudio.update(state: VehicleState, dt: number)
	if #voices == 0 then
		return
	end
	local cfg = ConfigLoader.forCar(carId)
	local audio = cfg.effects.engineAudio
	local drive = cfg.drivetrain
	local layers = layersOf(cfg)
	local rpm = state.rpm
	-- The pedals swap meaning in reverse (Drivetrain), so the brake is the
	-- engine's load there; otherwise reversing sounds like lifting off.
	local throttle = math.clamp(if state.gear == -1 then state.brake else state.throttle, 0, 1)

	-- Target weights, equal-power on each of the three axes.
	local offIdle = math.clamp((rpm - drive.idleRpm) / audio.idleFadeRpm, 0, 1) * HALF_PI
	local high = math.clamp((rpm - audio.loadBlendStartRpm) / (audio.loadBlendEndRpm - audio.loadBlendStartRpm), 0, 1) * HALF_PI
	local load = throttle * HALF_PI
	local running = math.sin(offIdle)
	local target = {
		idle = math.cos(offIdle),
		lowLoad = running * math.sin(load) * math.cos(high),
		highLoad = running * math.sin(load) * math.sin(high),
		overrun = running * math.cos(load),
	}
	-- A few frames of smoothing so a stab of throttle does not click.
	local k = 1 - math.exp(-dt / math.max(audio.gainSmoothSeconds, 1e-3))
	for _, name in LAYER_NAMES do
		gains[name] += (target[name] - gains[name]) * k
	end

	for _, v in voices do
		-- Power-sum the member layers; EQ is their power-weighted average.
		local power, low, mid, hi = 0, 0, 0, 0
		for _, name in v.members do
			local layer = layers[name]
			local g = gains[name] * layer.volume
			local p = g * g
			power += p
			low += layer.eq[1] * p
			mid += layer.eq[2] * p
			hi += layer.eq[3] * p
		end
		v.sound.Volume = audio.masterVolume * math.sqrt(power)
		if power > 1e-6 then
			v.eq.LowGain = low / power
			v.eq.MidGain = mid / power
			v.eq.HighGain = hi / power
		end
		v.sound.PlaybackSpeed = (rpm / v.refRpm) ^ audio.pitchExponent
	end
end

function EngineAudio.detach()
	for _, v in voices do
		v.sound:Destroy()
	end
	table.clear(voices)
	table.clear(gains)
	carId = nil
end

return EngineAudio
