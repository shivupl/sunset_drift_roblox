--!strict
-- Runs the shared Scoring module on the car this client is driving, purely
-- so the HUD has a number that moves with no network delay. The server runs
-- the same module on its own samples and decides what actually gets banked;
-- when a slide ends this sends the client's figure as a claim and the server
-- settles it. See ScoreService for the trust model.
--
-- A reset needs no special handling: the car's speed collapses to zero in a
-- single step, which the impact test reads as a crash and drops the slide.
-- The server sees the same teleport and clears its copy, so both sides end
-- up in the same place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local ConfigLoader = require(Shared.ConfigLoader)
local Scoring = require(Shared.Scoring)

type VehicleState = Types.VehicleState

local ScoreController = {}

ScoreController.state = Scoring.new()
-- Set by the client entry point once the remotes are resolved.
ScoreController.submit = nil :: ((points: number) -> ())?
-- Fired the step a 360 completes, with the bonus it paid and the count so
-- far in this slide. The HUD flashes it; a 30 Hz poll would miss the step.
ScoreController.onSpin = nil :: ((bonus: number, spins: number) -> ())?

function ScoreController.step(vehicleState: VehicleState, dt: number)
	local cfg = ConfigLoader.current().scoring
	local state = Scoring.step(ScoreController.state, cfg, {
		speedKmh = vehicleState.speedKmh,
		driftAngleDeg = vehicleState.driftAngleDeg,
	}, dt)
	if state.banked > 0 and ScoreController.submit then
		ScoreController.submit(state.banked)
	end
	if state.spun > 0 and ScoreController.onSpin then
		ScoreController.onSpin(state.spun, state.spins)
	end
end

function ScoreController.clear()
	Scoring.clear(ScoreController.state)
end

return ScoreController
