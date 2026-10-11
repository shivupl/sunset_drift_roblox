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
	steerDigital: number, -- -1, 0, 1 from keys
	steerAnalog: number?, -- gamepad stick or touch steer pad, nil when steering with keys
	handbrake: boolean,
	leanLeft: boolean,
	leanRight: boolean,
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
	source = "keyboard",
} :: Raw

local edges = { exit = false, reset = false, reload = false }
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
	local ovLean = math.clamp(tonumber(player:GetAttribute("OvLean")) or 0, -1, 1)
	out.leanLeft = if player:GetAttribute("OvLeanLeft") == true or ovLean < 0 then 1 else 0
	out.leanRight = if player:GetAttribute("OvLeanRight") == true or ovLean > 0 then 1 else 0
	out.lean = out.leanRight - out.leanLeft
	out.twoWheel = player:GetAttribute("OvTwoWheel") == true
	if player:GetAttribute("OvReset") == true then
		out.reset = true
		player:SetAttribute("OvReset", false)
	end
	if player:GetAttribute("OvReload") == true then
		out.reload = true
		player:SetAttribute("OvReload", false)
	end
	return out
end

local function takeEdges(out: InputState)
	out.exit = edges.exit
	out.reset = out.reset or edges.reset
	out.reload = out.reload or edges.reload
	edges.exit, edges.reset, edges.reload = false, false, false
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
	out.leanLeft = if raw.leanLeft then 1 else 0
	out.leanRight = if raw.leanRight then 1 else 0
	out.lean = out.leanRight - out.leanLeft
	-- twoWheel is the sim's held-toggle path, used only by the OvTwoWheel
	-- harness now: on every platform a tap of a lean control lifts the car
	-- and the mode latches inside the sim (the phone's NATL buttons are the
	-- lean keys since 2026-10-10; its NATL toggle is gone).
	out.twoWheel = false

	if raw.steerAnalog ~= nil then
		local target = raw.steerAnalog
		if raw.source == "touch" then
			-- The steer pad is positional, so the wheel chases the thumb at
			-- a fixed rate: a jump across the pad is a quick counter-steer,
			-- not an instant one.
			local rate = cfg.input.touchSteerRatePerSec
			steerRamped += math.clamp(target - steerRamped, -rate * dt, rate * dt)
		else
			steerRamped = target
		end
		out.steer = steerRamped
	else
		-- Digital steer ramps so a tap is a nudge and a hold is full lock.
		local target = raw.steerDigital
		local returning = math.abs(target) < math.abs(steerRamped) or target * steerRamped < 0
		local rate = if returning then cfg.input.keyboardSteerReturnPerSec else cfg.input.keyboardSteerRampPerSec
		steerRamped += math.clamp(target - steerRamped, -rate * dt, rate * dt)
		out.steer = steerRamped
	end

	takeEdges(out)
	return out
end

return Input
