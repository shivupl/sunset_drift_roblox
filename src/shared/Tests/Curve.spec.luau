--!strict
local Curve = require(script.Parent.Parent.Curve)

return function(t)
	local pts = { { 0, 0 }, { 10, 100 }, { 20, 50 } }
	t.eq(Curve.lookup(pts, -5), 0, "clamps below")
	t.eq(Curve.lookup(pts, 25), 50, "clamps above")
	t.eq(Curve.lookup(pts, 5), 50, "interpolates first segment")
	t.eq(Curve.lookup(pts, 15), 75, "interpolates second segment")
	t.eq(Curve.lookup(pts, 10), 100, "exact knot")
end
