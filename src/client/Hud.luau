--!strict
-- Driver HUD: the client's door to it. The HUD itself is HudLab (layout D in
-- a finish: the tacho bottom middle, the cash top right, the drift board top
-- middle while sliding). The card this module used to draw (CLASSIC) went on
-- 2026-10-10 with the other trial styles (the owner: "remove all the other
-- HUD layouts we have and keep this").
--
-- The live number comes from the client's own copy of Scoring so it moves
-- with the car. The banked number comes back from the server, because that
-- is the one that was actually paid.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local ConfigLoader = require(Shared.ConfigLoader)
local Scoring = require(Shared.Scoring)
local HudLab = require(script.Parent:WaitForChild("HudLab"))

type VehicleState = Types.VehicleState

local Hud = {}

-- Called when the server reports what a finished slide was worth. points of
-- zero means the slide was lost rather than banked.
function Hud.flashResult(points: number, cash: number)
	HudLab.flashResult(points, cash)
end

-- A 360 completed inside the slide in progress.
function Hud.flashSpin(bonus: number, spins: number)
	HudLab.flashSpin(bonus, spins)
end

function Hud.update(state: VehicleState, score: Scoring.State)
	if not ConfigLoader.current().hud.enabled then
		Hud.hide()
		return
	end
	HudLab.update(state, score)
end

function Hud.hide()
	HudLab.hide()
end

return Hud
