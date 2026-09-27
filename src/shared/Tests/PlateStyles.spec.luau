--!strict
local PlateStyles = require(script.Parent.Parent.PlateStyles)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	-- The cells of one role, read left to right.
	local function row(art: PlateStyles.Art, role: string): string
		local cells = {}
		for _, c in art.cells do
			if c.role == role then
				table.insert(cells, c)
			end
		end
		table.sort(cells, function(a, b)
			return a.rect.x < b.rect.x
		end)
		local out = {}
		for _, c in cells do
			table.insert(out, c.text)
		end
		return table.concat(out, ",")
	end

	local formats: { PlateStyles.Format } = { "short", "long" }
	for _, format: PlateStyles.Format in formats do
		local art = PlateStyles.layout("SA:ABJ-47", format)
		t.ok(art ~= nil, format .. ": a valid key lays out")
		if not art then
			continue
		end
		t.eq(row(art, "latinLetter"), "A,B,J", format .. ": latin letters read left to right")
		t.eq(row(art, "arabicLetter"), "أ,ب,ح", format .. ": each arabic letter above its latin letter")
		t.eq(row(art, "latinDigit"), "4,7", format .. ": latin digits")
		t.eq(row(art, "arabicDigit"), "٤,٧", format .. ": arabic digits, same order")
		for _, c in art.cells do
			local r = c.rect
			t.ok(r.x >= 0 and r.y >= 0 and r.x + r.w <= 1.0001 and r.y + r.h <= 1.0001, `{format}: {c.text} inside the plate`)
		end
		for _, b in art.blocks do
			local r = b.rect
			t.ok(r.x >= 0 and r.y >= 0 and r.x + r.w <= 1.0001 and r.y + r.h <= 1.0001, format .. ": block inside the plate")
		end
		t.ok(PlateStyles.SIZE_M[format].X > PlateStyles.SIZE_M[format].Y, format .. ": wider than tall")
	end
	t.eq(PlateStyles.layout("garbage", "short"), nil, "bad key: nothing")
	local longSize = PlateStyles.SIZE_M[formats[2]]
	local shortSize = PlateStyles.SIZE_M[formats[1]]
	t.ok(longSize.X / longSize.Y > shortSize.X / shortSize.Y, "long is the longer format")
end
