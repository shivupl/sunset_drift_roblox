--!strict
-- On-screen numbers for tuning. Monospace block, top-left, 10 Hz.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local ConfigLoader = require(Shared.ConfigLoader)

type VehicleState = Types.VehicleState
type WheelState = Types.WheelState

local DebugPanel = {}

local label: TextLabel? = nil
local lastUpdate = 0

local function ensureLabel(): TextLabel
	if label then
		return label
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "HajwalaDebug"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10

	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.BackgroundColor3 = Color3.new(0, 0, 0)
	l.BackgroundTransparency = 0.35
	l.BorderSizePixel = 0
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.Code
	l.TextSize = 14
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Position = UDim2.fromOffset(8, 8)
	l.Size = UDim2.fromOffset(0, 0)
	l.Text = ""
	l.Parent = gui

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = l

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	label = l
	return l
end

local function wheelLine(ws: WheelState): string
	local flag = if ws.saturated then "SPIN" elseif not ws.grounded then "AIR " else "    "
	return string.format("%s slip %+6.1f° load %5.1fkN %s", ws.name, ws.slipAngleDeg, ws.load / 1000, flag)
end

function DebugPanel.update(state: VehicleState)
	local cfg = ConfigLoader.current()
	if not cfg.debug.enabled then
		DebugPanel.hide()
		return
	end
	local now = os.clock()
	if now - lastUpdate < 1 / cfg.debug.updateHz then
		return
	end
	lastUpdate = now

	local l = ensureLabel()
	l.Visible = true
	local w = state.wheels
	local gear = if state.gear == -1 then "R" else tostring(state.gear)
	l.Text = table.concat({
		string.format("SPD %5.1f km/h   GEAR %s   RPM %4.0f", state.speedKmh, gear, state.rpm),
		string.format(
			"THR %.2f  BRK %.2f  STR %+.2f (%+5.1f°)  LOCK %3.0f%%",
			state.throttle,
			state.brake,
			state.steer,
			state.steerDeg,
			state.steerLock * 100
		),
		string.format("DRIFT %+6.1f°   YAW %+6.1f°/s", state.driftAngleDeg, state.yawRateDegPerSec),
		string.format(
			"MODE %-8s  ROLL %+5.1f°  margin %5.1f°  LEAN %+d",
			state.twoWheelMode,
			state.rollDeg,
			state.rollMarginDeg,
			state.lean
		),
		wheelLine(w[1]) .. "   " .. wheelLine(w[2]),
		wheelLine(w[3]) .. "   " .. wheelLine(w[4]),
		string.format(
			"HB %s  KICK %s  ASSIST %.2f",
			if state.handbrake then "ON " else "off",
			if state.clutchKick then "ON " else "off",
			state.driftAssist
		),
	}, "\n")

	-- Mirror for the MCP harness (client-side attributes, readable in the Client datamodel).
	local p = Players.LocalPlayer
	p:SetAttribute("DbgSpeedKmh", state.speedKmh)
	p:SetAttribute("DbgGear", state.gear)
	p:SetAttribute("DbgRpm", state.rpm)
	p:SetAttribute("DbgDriftDeg", state.driftAngleDeg)
	p:SetAttribute("DbgYawRate", state.yawRateDegPerSec)
	p:SetAttribute("DbgRollDeg", state.rollDeg)
	p:SetAttribute("DbgLean", state.lean)
	p:SetAttribute("DbgSteerLock", state.steerLock)
	p:SetAttribute("DbgMode", state.twoWheelMode)
	p:SetAttribute("DbgSlipFL", w[1].slipAngleDeg)
	p:SetAttribute("DbgSlipFR", w[2].slipAngleDeg)
	p:SetAttribute("DbgSlipRL", w[3].slipAngleDeg)
	p:SetAttribute("DbgSlipRR", w[4].slipAngleDeg)
	p:SetAttribute("DbgSpinRL", w[3].saturated)
	p:SetAttribute("DbgSpinRR", w[4].saturated)
end

function DebugPanel.hide()
	if label then
		label.Visible = false
	end
end

return DebugPanel
