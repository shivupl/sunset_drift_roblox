--!strict
-- The twelve lights.
--
-- Roblox degrades badly past a handful of dynamic lights, so the world has
-- two hundred lamp posts and a fixed pool of SpotLights that is never larger
-- than WorldSettings.MaxLiveLights. A SpotLight, not a PointLight: it hangs
-- under the lens and shines down in a wide cone, so the light lands on the
-- road as a pool instead of glowing the sky above the head. On a throttled interval the pool moves to
-- whichever tagged lamp heads are nearest the camera. Every other lamp is
-- unlit Neon geometry, which still reads as a lamp at distance.
--
-- This lives on the client because "nearest to the camera" only means
-- anything here. It is the one part of the world system that keeps running
-- after the build, and it runs on a timed loop with an exit flag, not on
-- Heartbeat or RenderStepped.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLights = {}

local LAMP_TAG = "HajwalaLamp"

local pool: { SpotLight } = {}
local assigned: { [SpotLight]: BasePart? } = {}
local running = false
-- The garage view lights its bay with its own four lights and suspends the
-- pool meanwhile, so the client never holds more than MaxLiveLights (12).
local suspended = false

local function settings(): Folder?
	local f = ReplicatedStorage:FindFirstChild("WorldSettings")
	return if f and f:IsA("Folder") then f else nil
end

local function num(f: Folder?, key: string, fallback: number): number
	local v = if f then tonumber(f:GetAttribute(key)) else nil
	return v or fallback
end

local function buildPool(f: Folder?)
	-- The time of day decides whether street lamps are lit at all. At golden
	-- hour they are geometry only, and the pool is simply empty.
	local lit = if f then f:GetAttribute("LampsLit") ~= false else true
	local want = if lit then math.floor(num(f, "MaxLiveLights", 12)) else 0
	local color = (if f then f:GetAttribute("LightColor") else nil) :: Color3?
	local brightness = num(f, "LightBrightness", 2.5)
	local range = num(f, "LightRangeStuds", 80)
	local angle = num(f, "LightAngleDeg", 120)
	while #pool > want do
		local light = table.remove(pool)
		if light then
			assigned[light] = nil
			light:Destroy()
		end
	end
	while #pool < want do
		local light = Instance.new("SpotLight")
		light.Name = "LampLight"
		light.Color = color or Color3.fromRGB(255, 170, 74)
		light.Brightness = brightness
		light.Range = range
		light.Angle = angle
		light.Face = Enum.NormalId.Bottom -- the lens part is level, so Bottom is straight down
		light.Shadows = false -- shadows from a street lamp cost more than they show at night
		light.Enabled = false
		table.insert(pool, light)
		assigned[light] = nil
	end
end

local function update()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local origin = camera.CFrame.Position
	local want = #pool
	if want == 0 or suspended then
		return
	end

	-- Nearest lamps to the camera. A couple of hundred distance checks four
	-- times a second is nothing; doing it per frame would be.
	local lamps = CollectionService:GetTagged(LAMP_TAG)
	local ranked: { { part: BasePart, d: number } } = {}
	for _, inst in lamps do
		if inst:IsA("BasePart") then
			table.insert(ranked, { part = inst, d = (inst.Position - origin).Magnitude })
		end
	end
	table.sort(ranked, function(a, b)
		return a.d < b.d
	end)

	local target: { [BasePart]: boolean } = {}
	for i = 1, math.min(want, #ranked) do
		target[ranked[i].part] = true
	end

	-- Keep lights that are still in range where they are, so nothing flickers
	-- just because the ordering shuffled.
	local free: { SpotLight } = {}
	for _, light in pool do
		local host = assigned[light]
		if host and host.Parent and target[host] then
			target[host] = nil -- already covered
		else
			light.Enabled = false
			light.Parent = nil
			assigned[light] = nil
			table.insert(free, light)
		end
	end

	for part in target do
		local light = table.remove(free)
		if not light then
			break
		end
		light.Parent = part
		light.Enabled = true
		assigned[light] = part
	end
end

local function darkenAll()
	for _, light in pool do
		light.Enabled = false
		light.Parent = nil
		assigned[light] = nil
	end
end

function WorldLights.start()
	if running then
		return
	end
	running = true
	local f = settings()
	buildPool(f)
	local interval = num(f, "LightUpdateInterval", 0.25)
	task.spawn(function()
		-- Exits when stop() clears the flag; never a bare while true.
		while running do
			-- pcall of a () -> () needs the cast under strict mode.
			local ok, err = pcall(update :: () -> any)
			if not ok then
				warn("[WorldLights]", err)
			end
			task.wait(interval)
		end
	end)
end

function WorldLights.stop()
	running = false
	darkenAll()
end

-- Puts every pooled light out without destroying the pool (the garage view,
-- which brings its own lights). The loop keeps running and does nothing.
function WorldLights.suspend()
	suspended = true
	darkenAll()
end

-- Lets the pool light the nearest lamps again, at once rather than on the
-- next tick.
function WorldLights.resume()
	if not suspended then
		return
	end
	suspended = false
	if running then
		local ok, err = pcall(update :: () -> any)
		if not ok then
			warn("[WorldLights]", err)
		end
	end
end

-- How many lights are live right now. Used by the performance report.
function WorldLights.liveCount(): number
	local n = 0
	for _, light in pool do
		if light.Enabled and light.Parent then
			n += 1
		end
	end
	return n
end

return WorldLights
