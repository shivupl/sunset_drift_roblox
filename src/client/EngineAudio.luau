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
-- On top of the layers, four events read off the same state: an upshift
-- dips the engine (the torque cut), an off-throttle downshift blips the
-- pitch, lifting fast fires a crackle of exhaust pops, and sitting on the
-- redline cuts the engine in and out like a limiter. The note also kicks
-- up when the throttle goes back on: an rpm offset for the audio only,
-- since the sim's rpm follows the wheels. Lifting off has no offset; the
-- note falls as the sim's rpm does.
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

-- Event state.
local rng = Random.new()
local clock = 0 -- simulated seconds since attach
local lastGear = 1
local lastLoad = 0
local dipUntil = -1
local blipAt = -math.huge
local shiftSound: Sound? = nil
local pops: { Sound } = {} -- a small pool so pops can overlap
local nextPop = 1
local popQueue: { number } = {} -- clock times of pops still to fire
local punch = 0 -- rpm the note sits over it after the throttle goes on

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

	local audio = cfg.effects.engineAudio
	local function oneShot(name: string, id: string): Sound
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = id
		s.RollOffMaxDistance = 120
		s.Parent = chassis
		return s
	end
	if audio.shiftSoundId ~= "" then
		shiftSound = oneShot("Engine_shift", audio.shiftSoundId)
	end
	if audio.crackleSoundId ~= "" then
		for i = 1, 3 do
			table.insert(pops, oneShot("Engine_pop" .. i, audio.crackleSoundId))
		end
	end
end

local function pop(audio: typeof(ConfigLoader.current().effects.engineAudio))
	local s = pops[nextPop]
	nextPop = nextPop % #pops + 1
	s.PlaybackSpeed = rng:NextNumber(audio.cracklePitch[1], audio.cracklePitch[2])
	s.Volume = audio.crackleVolume * rng:NextNumber(audio.crackleVolumeRange[1], audio.crackleVolumeRange[2])
	s.TimePosition = 0
	s:Play()
end

function EngineAudio.update(state: VehicleState, dt: number)
	if #voices == 0 then
		return
	end
	local cfg = ConfigLoader.forCar(carId)
	local audio = cfg.effects.engineAudio
	local drive = cfg.drivetrain
	local layers = layersOf(cfg)
	local simRpm = state.rpm
	-- The pedals swap meaning in reverse (Drivetrain), so the brake is the
	-- engine's load there; otherwise reversing sounds like lifting off.
	local throttle = math.clamp(if state.gear == -1 then state.brake else state.throttle, 0, 1)

	-- Punch: the note kicks over the sim's rpm when the throttle goes on.
	local pressed = throttle - lastLoad
	if pressed > 0 then
		local kmh = math.abs(state.speedKmh)
		local fade = math.clamp((kmh - audio.punchFullKmh) / (audio.punchFadeKmh - audio.punchFullKmh), 0, 1)
		local factor = 1 - (1 - audio.punchMinFactor) * fade
		punch = math.min(audio.punchRpm, punch + audio.punchRpm * pressed * factor)
	end
	punch *= math.exp(-dt / math.max(audio.punchDecaySeconds, 1e-3))
	local rpm = math.clamp(simRpm + punch, drive.idleRpm, drive.redlineRpm)

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
	clock += dt

	-- Events. Gear changes into or out of reverse are not shifts.
	local gear = state.gear
	if gear >= 1 and lastGear >= 1 and gear ~= lastGear then
		if gear > lastGear then
			dipUntil = clock + audio.shiftDipSeconds
			if shiftSound then
				shiftSound.Volume = audio.shiftSoundVolume
				shiftSound.TimePosition = 0
				shiftSound:Play()
			end
		elseif throttle < 0.1 then
			blipAt = clock
		end
	end
	lastGear = gear

	if #pops > 0 then
		local fast = simRpm >= audio.crackleMinRpm and math.abs(state.speedKmh) >= audio.crackleMinKmh
		if fast and lastLoad >= audio.crackleLiftFrom and throttle < 0.1 then
			local n = rng:NextInteger(audio.crackleBurstPops[1], audio.crackleBurstPops[2])
			for _ = 1, n do
				table.insert(popQueue, clock + rng:NextNumber(0, audio.crackleBurstSeconds))
			end
		end
		for i = #popQueue, 1, -1 do
			if popQueue[i] <= clock then
				table.remove(popQueue, i)
				-- Back on the throttle cancels what is left of a burst.
				if throttle < 0.1 then
					pop(audio)
				end
			end
		end
	end
	lastLoad = throttle

	local gainMul, pitchMul = 1, 1
	if clock < dipUntil then
		gainMul = audio.shiftDipGain
	end
	local sinceBlip = clock - blipAt
	if sinceBlip >= 0 and sinceBlip < audio.blipRiseSeconds + audio.blipFallSeconds then
		local b = if sinceBlip < audio.blipRiseSeconds
			then sinceBlip / audio.blipRiseSeconds
			else 1 - (sinceBlip - audio.blipRiseSeconds) / audio.blipFallSeconds
		pitchMul = 1 + audio.blipPitch * b
		gainMul *= 1 + 0.3 * b
	end
	if simRpm >= drive.redlineRpm - audio.limiterBandRpm and throttle > 0.5 then
		-- Square wave: on for half of each cycle, cut for the other half.
		if (clock * audio.limiterHz) % 1 >= 0.5 then
			gainMul *= audio.limiterDipGain
			pitchMul *= 0.97
		end
	end

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
		v.sound.Volume = audio.masterVolume * math.sqrt(power) * gainMul
		if power > 1e-6 then
			v.eq.LowGain = low / power
			v.eq.MidGain = mid / power
			v.eq.HighGain = hi / power
		end
		v.sound.PlaybackSpeed = (rpm / v.refRpm) ^ audio.pitchExponent * pitchMul
	end
end

function EngineAudio.detach()
	for _, v in voices do
		v.sound:Destroy()
	end
	table.clear(voices)
	table.clear(gains)
	for _, s in pops do
		s:Destroy()
	end
	table.clear(pops)
	table.clear(popQueue)
	if shiftSound then
		shiftSound:Destroy()
		shiftSound = nil
	end
	nextPop = 1
	clock = 0
	lastGear = 1
	lastLoad = 0
	dipUntil = -1
	blipAt = -math.huge
	punch = 0
	carId = nil
end

return EngineAudio
