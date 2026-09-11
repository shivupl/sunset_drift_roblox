--!strict
-- Authoritative drift scoring.
--
-- The client runs the same Scoring module for its live HUD, but the number
-- that gets banked is decided here. The server samples every driven car's
-- replicated pose and velocity, derives its own speed and drift angle, and
-- steps its own copy of the scoring state. When a slide ends the client's
-- claim is settled against that total: an honest claim is paid in full, a
-- claim larger than what the server saw is capped at it, and a claim that
-- never arrives is replaced by the server's own figure.
--
-- Nothing the client sends can raise a balance. The remote carries one
-- number, that number is only ever an upper bound on a payout the server
-- already computed, and it is rate limited. Cash itself lives in Economy
-- and reaches the client as a replicated attribute.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared.CarConfig)
local Scoring = require(Shared.Scoring)
local Economy = require(script.Parent.Economy)
local Remotes = require(script.Parent.Remotes)

type Config = CarConfig.Config

local ScoreService = {}

type Session = {
	player: Player,
	chassis: BasePart,
	state: Scoring.State,
	lastPos: Vector3,
	sampleTime: number, -- time accumulated since the last sample
	claim: number?,
	claimAt: number,
	submits: number, -- submissions inside the current second
	submitWindow: number,
	-- Last sample, kept only so ScoreService.debug can report it.
	lastSpeedKmh: number,
	lastDriftDeg: number,
	lastDrop: string,
}

local MAX_SUBMITS_PER_SECOND = 4
local MAX_CLAIM = 1e9

local config: Config
local remotes: Remotes.RemoteTable
local sessions: { [Player]: Session } = {}
local records: Folder
-- Server-side tuning readout: one attribute per driver holding what the
-- server thinks their slide is worth, so a client figure can be compared
-- against it. Lives in ServerStorage, which never replicates, and is only
-- written while debug.enabled is on. Turn that off for a real server.
local probe: Folder

local function ensureProbe(): Folder
	local existing = ServerStorage:FindFirstChild("HajwalaScoreProbe")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "HajwalaScoreProbe"
	folder.Parent = ServerStorage
	return folder
end

local function ensureRecords(): Folder
	local existing = ReplicatedStorage:FindFirstChild("Records")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Records"
	folder:SetAttribute("BestScore", 0)
	folder:SetAttribute("BestHolder", "")
	folder.Parent = ReplicatedStorage
	return folder
end

local function offerRecord(player: Player, points: number)
	if points <= ((tonumber(records:GetAttribute("BestScore")) or 0)) then
		return
	end
	records:SetAttribute("BestScore", points)
	records:SetAttribute("BestHolder", player.DisplayName)
end

local function settle(session: Session, serverPoints: number)
	local cfg = config.scoring
	local claim = session.claim
	if claim ~= nil and os.clock() - session.claimAt > cfg.claimWindowSeconds then
		claim = nil
	end
	local points = Scoring.settle(cfg, serverPoints, claim)
	session.claim = nil
	if points < cfg.minBankPoints then
		return
	end
	local cash = Scoring.cashFor(cfg, points)
	Economy.award(session.player, cash)
	Economy.recordScore(session.player, points)
	offerRecord(session.player, points)
	remotes.SlideResult:FireClient(session.player, points, cash)
end

local function sample(session: Session, dt: number)
	local cfg = config.scoring
	local chassis = session.chassis
	if chassis.Parent == nil then
		return
	end
	local pos = chassis.Position
	local speedKmh, driftAngleDeg = Scoring.observe(chassis.CFrame, chassis.AssemblyLinearVelocity, config.units.metersPerStud)

	-- A car that moved further than its own speed allows, or is reporting a
	-- speed no car reaches, is not driving: throw the slide away rather than
	-- score it. A legitimate reset trips this too, which is the right
	-- outcome, so it is not worth warning about.
	if not Scoring.plausible(cfg, session.lastPos, pos, speedKmh, dt, config.units.metersPerStud) then
		Scoring.clear(session.state)
		session.claim = nil
		session.lastPos = pos
		session.lastDrop = "implausible"
		return
	end
	session.lastPos = pos
	session.lastSpeedKmh = speedKmh
	session.lastDriftDeg = driftAngleDeg

	local state = Scoring.step(session.state, cfg, { speedKmh = speedKmh, driftAngleDeg = driftAngleDeg }, dt)
	if state.banked > 0 then
		settle(session, state.banked)
	elseif state.dropped then
		session.claim = nil
		session.lastDrop = state.reason
		remotes.SlideResult:FireClient(session.player, 0, 0)
	end
	if config.debug.enabled then
		probe:SetAttribute(session.player.Name, ScoreService.debug(session.player))
	end
end

local function step(dt: number)
	Economy.step(dt, config.scoring.autosaveSeconds)
	local period = 1 / math.max(config.scoring.sampleHz, 1)
	for _, session in sessions do
		session.sampleTime += dt
		if session.sampleTime >= period then
			local used = session.sampleTime
			session.sampleTime = 0
			sample(session, used)
		end
	end
end

-- Called by CarSpawner when a player takes or leaves a car.
function ScoreService.setDriving(player: Player, model: Model?)
	if model == nil then
		sessions[player] = nil
		return
	end
	local chassis = model.PrimaryPart
	if not chassis then
		return
	end
	sessions[player] = {
		player = player,
		chassis = chassis,
		state = Scoring.new(),
		lastPos = chassis.Position,
		sampleTime = 0,
		claim = nil,
		claimAt = 0,
		submits = 0,
		submitWindow = os.clock(),
		lastSpeedKmh = 0,
		lastDriftDeg = 0,
		lastDrop = "",
	}
end

-- What the server thinks is happening to this player's car. Tuning and test
-- harness only; nothing reads it in normal play.
function ScoreService.debug(player: Player): string
	local session = sessions[player]
	if not session then
		return "no session"
	end
	local st = session.state
	return string.format(
		"active=%s pts=%.0f mult=%.2f grace=%.2f | sample spd=%.1f drift=%+.1f avg=%.1f | claim=%s lastDrop=%s",
		tostring(st.active), st.points, st.multiplier, st.graceTime,
		session.lastSpeedKmh, session.lastDriftDeg, st.speedAvg,
		tostring(session.claim), session.lastDrop
	)
end

function ScoreService.setConfig(newConfig: Config)
	config = newConfig
end

function ScoreService.start(startConfig: Config, startRemotes: Remotes.RemoteTable)
	config = startConfig
	remotes = startRemotes
	records = ensureRecords()
	probe = ensureProbe()
	Economy.start()

	remotes.SubmitSlide.OnServerEvent:Connect(function(player: Player, claimed: any)
		local session = sessions[player]
		if not session then
			return
		end
		local now = os.clock()
		if now - session.submitWindow >= 1 then
			session.submitWindow = now
			session.submits = 0
		end
		session.submits += 1
		if session.submits > MAX_SUBMITS_PER_SECOND then
			return
		end
		local points = tonumber(claimed)
		if points == nil or points ~= points or points <= 0 or points > MAX_CLAIM then
			return
		end
		session.claim = points
		session.claimAt = now
	end)

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)

	RunService.Heartbeat:Connect(step)
end

return ScoreService
