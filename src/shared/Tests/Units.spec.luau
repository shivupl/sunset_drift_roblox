--!strict
local Units = require(script.Parent.Parent.Units)

return function(t)
	t.near(Units.mToStuds(2.8, 0.28), 10, 1e-9, "m to studs")
	t.near(Units.studsToM(10, 0.28), 2.8, 1e-9, "studs to m")
	t.near(Units.mpsToKmh(27.7778), 100, 0.01, "m/s to km/h")
	local f = Units.forceNToSim(Vector3.new(280, 0, 0), 0.28)
	t.near(f.X, 1000, 1e-6, "N to sim force")
	local tq = Units.torqueNmToSim(Vector3.new(0, 0.0784, 0), 0.28)
	t.near(tq.Y, 1, 1e-6, "Nm to sim torque")
end
