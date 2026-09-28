--!strict
-- Where a driver stands after leaving a car: beside the driver's door, clear
-- of the body, facing the way the car points. The owner exited right under
-- the car (2026-09-27): the server alone moved the character, and the
-- character belongs to the player's client, whose own position won. So the
-- server and the leaving player's client both put the character here.
local VehicleRig = require(script.Parent.VehicleRig)

local ExitSpot = {}

-- gapM: clear space between the car's side and the player (spawn.exitGapM).
-- liftM: how far above the chassis centre the character is placed, so it
-- lands on its feet rather than in the ground (spawn.exitLiftM).
function ExitSpot.cframe(model: Model, gapM: number, liftM: number, metersPerStud: number): CFrame?
	local ok, handles = pcall(VehicleRig.handles, model)
	if not ok then
		return nil
	end
	local chassis = handles.chassis
	-- The driver's seat is left of centre, on the car's -X side.
	local side = chassis.Size.X / 2 + gapM / metersPerStud
	-- Level directions, so a rolled or pitched car still puts the player
	-- beside it on their feet, facing along the car.
	local look = chassis.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	local facing = CFrame.lookAt(chassis.Position, chassis.Position + flat.Unit)
	local spot = chassis.Position - facing.RightVector * side + Vector3.new(0, liftM / metersPerStud, 0)
	return CFrame.lookAt(spot, spot + flat.Unit)
end

return ExitSpot
