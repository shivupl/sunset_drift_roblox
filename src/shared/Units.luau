--!strict
-- Conversions between SI (config, sim math) and Roblox units.
-- Convention: 1 Roblox mass unit == 1 kg (RigBuilder sets densities so the
-- assembly mass equals CarConfig.body.massKg). Lengths: metersPerStud.
local Units = {}

function Units.mToStuds(m: number, metersPerStud: number): number
	return m / metersPerStud
end

function Units.studsToM(s: number, metersPerStud: number): number
	return s * metersPerStud
end

function Units.vecStudsToM(v: Vector3, metersPerStud: number): Vector3
	return v * metersPerStud
end

function Units.vecMToStuds(v: Vector3, metersPerStud: number): Vector3
	return v / metersPerStud
end

function Units.mpsToKmh(v: number): number
	return v * 3.6
end

function Units.kmhToMps(v: number): number
	return v / 3.6
end

-- F_sim = m_rmu * a_studs = m_kg * (a_m / mps) = F_N / mps
function Units.forceNToSim(f: Vector3, metersPerStud: number): Vector3
	return f / metersPerStud
end

-- tau_sim = r_studs x F_sim = (r_m / mps) * (F_N / mps) = tau_Nm / mps^2
function Units.torqueNmToSim(t: Vector3, metersPerStud: number): Vector3
	return t / (metersPerStud * metersPerStud)
end

return Units
