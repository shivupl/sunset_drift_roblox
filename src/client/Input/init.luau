--!strict
-- Aggregates raw input from Keyboard, Gamepad and Touch into one InputState
-- per physics step, with per-source steer ramps. Also honours an attribute
-- override on the LocalPlayer so a test harness (the Studio MCP) can drive
-- the car without a keyboard.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local CarConfig = require(Shared.CarConfig)

type Config = CarConfig.Config
type InputState = Types.InputState

export type Raw = {
	throttle: number,
	brake: number,
	steerDigital: number, -- -1, 0, 1 from keys or touch buttons
	steerAnalog: number?, -- gamepad stick, nil when not driving with a pad
	handbrake: boolean,
	leanLeft: boolean,
	leanRight: boolean,
	-- Touch only: the NATL button. Keyboard and gamepad enter two-wheel by
	-- holding a lean control, so they leave this false.
	twoWheelButton: boolean,
	source: string, -- "keyboard" | "touch" | "gamepad"
}

local Input = {}

Input.raw = {
	throttle = 0,
	brake = 0,
	steerDigital = 0,
	steerAnalog = nil,
	handbrake = false,
	leanLeft = false,
	leanRight = false,
	twoWheelButton = false,
	source = "keyboard",
} :: Raw

local edges = { clutchKick = false, exit = false, reset = false, reload = false }
local steerRamped = 0

-- Edge-triggered actions call this once per press.
function Input.pulse(name: string)
	edges[name] = true
end

local function readOverride(player: Player): InputState
	local out = Types.newInput()
	out.throttle = math.clamp(tonumber(player:GetAttribute("OvThrottle")) or 0, 0, 1)
	out.brake = math.clamp(tonumber(player:GetAttribute("OvBrake")) or 0, 0, 1)
	out.steer = math.clamp(tonumber(player:GetAttribute("OvSteer")) or 0, -1, 1)
	out.handbrake = player:GetAttribute("OvHandbrake") == true
	out.lean = math.clamp(tonumber(player:GetAttribute("OvLean")) or 0, -1, 1)
	out.twoWheel = player:GetAttribute("OvTwoWheel") == true or out.lean ~= 0
	if player:GetAttribute("OvClutchKick") == true then
		out.clutchKick = true
		player:SetAttribute("OvClutchKick", false)
	end
	if player:GetAttribute("OvReset") == true then
		out.reset = true
		player:SetAttribute("OvReset", false)
	end
	return out
end

local function takeEdges(out: InputState)
	out.clutchKick = out.clutchKick or edges.clutchKick
	out.exit = edges.exit
	out.reset = out.reset or edges.reset
	out.reload = edges.reload
	edges.clutchKick, edges.exit, edges.reset, edges.reload = false, false, false, false
end

function Input.get(dt: number, cfg: Config): InputState
	local player = Players.LocalPlayer
	if player:GetAttribute("InputOverride") == true then
		-- Keys like L (reload) and E (exit) still work while the harness drives.
		local out = readOverride(player)
		takeEdges(out)
		return out
	end

	local raw = Input.raw
	local out = Types.newInput()
	out.throttle = raw.throttle
	out.brake = raw.brake
	out.handbrake = raw.handbrake
	-- Lean is digital and unramped: balancing wants the torque the instant
	-- the key goes down, not a ramp.
	out.lean = (if raw.leanRight then 1 else 0) - (if raw.leanLeft then 1 else 0)
	-- Holding a lean control is what puts the car up on two wheels. Touch is
	-- the exception: there the NATL button opens the mode and the lean
	-- buttons only then appear.
	out.twoWheel = raw.twoWheelButton or out.lean ~= 0

	if raw.steerAnalog ~= nil then
		out.steer = raw.steerAnalog
		steerRamped = out.steer
	else
		-- Digital steer ramps so a tap is a nudge and a hold is full lock.
		-- Touch ramps slower and through a curve so thumbs get fine control.
		local target = raw.steerDigital
		local rampUp, rampDown, curve
		if raw.source == "touch" then
			rampUp, rampDown, curve = cfg.input.touchSteerRampPerSec, cfg.input.touchSteerReturnPerSec, cfg.input.touchSteerCurve
		else
			rampUp, rampDown, curve = cfg.input.keyboardSteerRampPerSec, cfg.input.keyboardSteerReturnPerSec, 1
		end
		local returning = math.abs(target) < math.abs(steerRamped) or target * steerRamped < 0
		local rate = if returning then rampDown else rampUp
		steerRamped += math.clamp(target - steerRamped, -rate * dt, rate * dt)
		out.steer = math.sign(steerRamped) * math.abs(steerRamped) ^ curve
	end

	takeEdges(out)
	return out
end

return Input
