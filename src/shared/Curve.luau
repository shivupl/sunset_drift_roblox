--!strict
-- Piecewise-linear lookup over a table of {x, y} points sorted by x.
-- Used for the engine torque curve and anything else tabulated in CarConfig.
local Curve = {}

export type Points = { { number } }

function Curve.lookup(points: Points, x: number): number
	local n = #points
	assert(n > 0, "Curve.lookup: empty table")
	if x <= points[1][1] then
		return points[1][2]
	end
	if x >= points[n][1] then
		return points[n][2]
	end
	for i = 1, n - 1 do
		local x0, y0 = points[i][1], points[i][2]
		local x1, y1 = points[i + 1][1], points[i + 1][2]
		if x >= x0 and x <= x1 then
			local t = if x1 > x0 then (x - x0) / (x1 - x0) else 0
			return y0 + (y1 - y0) * t
		end
	end
	return points[n][2]
end

return Curve
