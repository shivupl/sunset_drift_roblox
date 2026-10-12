--!strict
-- Speed you can feel (speed-feel, 2026-10-05: the owner, "overall game
-- driving feels pretty slow ... needs to feel at least 50% faster if not
-- 2x"). The desert highway is wide and sparse, so little streams past the
-- camera at any speed. From CarConfig.speedFeel: faint speed lines in the
-- outer ring of the screen, running out from the point the car is heading
-- for, and a wind roar that rises with speed. The camera's own part (the
-- wider view, the follow, the shake) is CameraRig's.
--
-- Studio: the LocalPlayer attribute SpeedFeelKmh forces the speed the
-- effects and the camera read, so a parked car can be framed at 200 km/h.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))

local SpeedFeel = {}

local PREVIEW_ATTRIBUTE = "SpeedFeelKmh"
-- Lines kept in the pool: more than perSecond x the longest lifetime.
local POOL = 24

type Line = {
	frame: Frame,
	age: number,
	life: number,
	angle: number, -- radians, screen space (y down)
	from: number, -- radius at birth, fraction of the half-diagonal
	to: number, -- at death
	length: number, -- fraction of the half-diagonal
}

local conn: RBXScriptConnection? = nil
local gui: ScreenGui? = nil
local lines: { Line } = {}
local free: { Frame } = {}
local owed = 0 -- fractional lines owed to the spawn rate
local lastCentre: Vector2? = nil -- where the lines last ran out from
local wind: Sound? = nil
local rng = Random.new()

-- The speed the effects read: the car's, or Studio's preview.
function SpeedFeel.kmh(actualKmh: number): number
	if RunService:IsStudio() then
		local forced = Players.LocalPlayer:GetAttribute(PREVIEW_ATTRIBUTE)
		if type(forced) == "number" then
			return forced
		end
	end
	return actualKmh
end

-- 0 under `from`, 1 from `full`, linear between.
function SpeedFeel.ramp(kmh: number, from: number, full: number): number
	if full <= from then
		return if kmh >= from then 1 else 0
	end
	return math.clamp((kmh - from) / (full - from), 0, 1)
end

local function newFrame(parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = "Line"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Visible = false
	-- Soft ends: clear at both tips, solid in the middle.
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
	f.Parent = parent
	return f
end

-- A random direction outside the wedge below the car.
local function pickAngle(avoidDeg: number): number
	for _ = 1, 8 do
		local a = rng:NextNumber(0, 2 * math.pi)
		-- Screen y points down, so straight down is +90 degrees.
		local off = math.abs(((math.deg(a) - 90 + 180) % 360) - 180)
		if off > avoidDeg then
			return a
		end
	end
	return 0
end

function SpeedFeel.start(model: Model)
	SpeedFeel.stop()
	local chassis = model.PrimaryPart
	local cam = workspace.CurrentCamera
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not chassis or not cam or not playerGui then
		return
	end
	local sg = Instance.new("ScreenGui")
	sg.Name = "SpeedLines"
	sg.IgnoreGuiInset = true
	-- The whole screen: the lines are placed in the viewport's pixels
	-- (WorldToViewportPoint), which a notch's inset would shift, and they
	-- run to the screen's edges (UIKit.edgeToEdge).
	sg.ScreenInsets = Enum.ScreenInsets.None
	sg.ClipToDeviceSafeArea = false
	sg.ResetOnSpawn = false
	sg.DisplayOrder = -1 -- under the HUD
	sg.Parent = playerGui
	gui = sg
	for _ = 1, POOL do
		table.insert(free, newFrame(sg))
	end
	local w = ConfigLoader.current().speedFeel.wind
	if w.soundId ~= "" then
		local snd = Instance.new("Sound")
		snd.Name = "SpeedWind"
		snd.SoundId = w.soundId
		snd.Looped = true
		snd.Volume = 0
		snd.Parent = cam
		wind = snd
	end

	conn = RunService.RenderStepped:Connect(function(dt: number)
		local cfg = ConfigLoader.current()
		local feel = cfg.speedFeel
		local vel = chassis.AssemblyLinearVelocity
		local kmh = SpeedFeel.kmh(vel.Magnitude * cfg.units.metersPerStud * 3.6)

		-- Speed lines, around the point the car is heading for.
		local l = feel.lines
		local view = cam.ViewportSize
		local halfDiag = view.Magnitude / 2
		local camCf = cam.CFrame
		local ahead = if vel.Magnitude > 1 then vel.Unit else camCf.LookVector
		-- Only while the car is going where the camera looks: through a 360
		-- the point it heads for swings off the screen, and the lines faded
		-- out instead of radiating from the middle over a receding view
		-- (speed-feel review).
		local facing = math.clamp((ahead:Dot(camCf.LookVector) - 0.5) / 0.4, 0, 1)
		local k = SpeedFeel.ramp(kmh, l.fromKmh, l.fullKmh) * facing
		local vp, onScreen = cam:WorldToViewportPoint(camCf.Position + ahead * 1000)
		local centre = lastCentre or view / 2
		if onScreen then
			centre = Vector2.new(vp.X, vp.Y)
		end
		lastCentre = centre
		owed += l.perSecond * k * dt
		while owed >= 1 and #free > 0 do
			owed -= 1
			local f = table.remove(free) :: Frame
			table.insert(lines, {
				frame = f,
				age = 0,
				life = rng:NextNumber(l.lifetime[1], l.lifetime[2]),
				angle = pickAngle(l.avoidDeg),
				from = rng:NextNumber(l.innerRadius, l.midRadius),
				to = l.outerRadius,
				length = l.length[1] + (l.length[2] - l.length[1]) * k * rng:NextNumber(0.6, 1),
			})
		end
		owed = math.min(owed, 1)
		for i = #lines, 1, -1 do
			local ln = lines[i]
			ln.age += dt
			local t = ln.age / ln.life
			local f = ln.frame
			if t >= 1 then
				f.Visible = false
				table.insert(free, f)
				table.remove(lines, i)
			else
				local r = (ln.from + (ln.to - ln.from) * t) * halfDiag
				local d = Vector2.new(math.cos(ln.angle), math.sin(ln.angle))
				local p = centre + d * r
				f.Position = UDim2.fromOffset(p.X, p.Y)
				f.Size = UDim2.fromOffset(ln.length * halfDiag, l.thickness)
				f.Rotation = math.deg(ln.angle)
				f.BackgroundColor3 = l.color
				-- Fades in and out over its life, and with the view.
				f.BackgroundTransparency = 1 - (1 - l.transparency) * math.sin(math.pi * t) * facing
				f.Visible = true
			end
		end

		local snd = wind
		if snd then
			local wcfg = feel.wind
			local wk = SpeedFeel.ramp(kmh, wcfg.fromKmh, wcfg.fullKmh)
			snd.Volume = wcfg.volume * wk
			snd.PlaybackSpeed = wcfg.pitchMin + (wcfg.pitchMax - wcfg.pitchMin) * wk
			if wk > 0 and not snd.IsPlaying then
				snd:Play()
			elseif wk <= 0 and snd.IsPlaying then
				snd:Stop()
			end
		end
	end)
end

function SpeedFeel.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
	table.clear(lines)
	table.clear(free)
	owed = 0
	lastCentre = nil
	if wind then
		wind:Destroy()
		wind = nil
	end
end

return SpeedFeel
