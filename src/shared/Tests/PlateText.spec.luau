--!strict
local PlateText = require(script.Parent.Parent.PlateText)
local PlateConfig = require(script.Parent.Parent.PlateConfig)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local function key(s: string): string?
		return (PlateText.normalise("SA", s))
	end
	local function reason(s: string): string?
		local _, r = PlateText.normalise("SA", s)
		return r
	end

	-- Latin, any case, spaces and hyphens anywhere, either group first
	t.eq(key("ABJ 7"), "SA:ABJ-7", "latin with a space")
	t.eq(key("abj-0007"), "SA:ABJ-7", "lower case and leading zeros")
	t.eq(key(" A B J 1234 "), "SA:ABJ-1234", "spaces everywhere")
	t.eq(key("7 ABJ"), "SA:ABJ-7", "number first")

	-- Every Arabic-Indic and Persian digit
	for d = 0, 9 do
		local want = `SA:ABJ-{tonumber(d .. "1")}`
		t.eq(key("ABJ" .. utf8.char(0x0660 + d) .. "1"), want, `arabic-indic digit {d}`)
		t.eq(key("ABJ" .. utf8.char(0x06F0 + d) .. "1"), want, `persian digit {d}`)
	end

	-- Every Arabic plate letter gives its Latin letter's key
	for _, l in PlateText.SA_LETTERS do
		t.eq(key(l.arabic .. l.arabic .. l.arabic .. "5"), `SA:{string.rep(l.latin, 3)}-5`, `arabic {l.latin}`)
	end
	-- Arabic letters are typed in Arabic reading order (right to left): ح ب أ
	-- is the plate that reads ABJ in Latin (spec "Checked": each Arabic letter
	-- sits above its Latin letter, so the Arabic row reads the other way).
	t.eq(key("حبأ٧"), "SA:ABJ-7", "arabic letters, reading order, and digit")
	t.eq(key("حبأ ٠٠٧"), "SA:ABJ-7", "arabic leading zeros")

	-- The hamza forms and bare alef are all A
	for _, a in { "أ", "إ", "آ", "ا" } do
		t.eq(key("حب" .. a .. "7"), "SA:ABJ-7", "alef form " .. a)
	end

	-- Hidden marks and tatweel change nothing
	for _, cp in { 0x200E, 0x200F, 0x061C, 0x200C, 0x200D, 0x0640 } do
		t.eq(key("ABJ" .. utf8.char(cp) .. "7"), "SA:ABJ-7", string.format("mark U+%04X", cp))
	end

	-- Rejected, each with a reason
	for _, bad in { "ABJ 0000", "ABC 7", "أبج 7", "AB 7", "ABJD 7", "ABJ 12345", "ABJ", "A7BJ", "Aبح 7", string.rep("A", 100) } do
		t.eq(key(bad), nil, "rejected: " .. bad)
		t.ok(reason(bad) ~= nil, "a reason for: " .. bad)
	end

	-- A key back into its halves
	local p = PlateText.parts("SA:ABJ-7")
	t.ok(p ~= nil, "parts of a canonical key")
	if p then
		t.eq(table.concat(p.latin, ","), "A,B,J", "latin letters")
		t.eq(table.concat(p.arabic, ","), "أ,ب,ح", "arabic letters")
		t.eq(p.digits, "7", "digits")
		t.eq(table.concat(p.arabicDigits), "٧", "arabic digits")
	end
	t.eq(PlateText.parts("SA:ABC-7"), nil, "C is not a plate letter")
	t.eq(PlateText.parts("garbage"), nil, "not a key")
	for _, k in { "SA:ABJ-7", "SA:HUV-9999", "SA:XTE-10" } do
		local q = PlateText.parts(k) :: PlateText.Parts
		local typed: { string } = {}
		for i = #q.arabic, 1, -1 do
			table.insert(typed, q.arabic[i]) -- typed in reading order, right to left
		end
		t.eq(key(table.concat(typed) .. table.concat(q.arabicDigits)), k, "arabic round trip " .. k)
	end

	-- Random default plates are canonical, with 3 letters and 4 digits
	local rng = Random.new(1)
	for _ = 1, 50 do
		local k = PlateText.random(rng)
		t.eq(key(string.sub(k, 4)), k, "random plate " .. k)
		t.eq(#(PlateText.parts(k) :: PlateText.Parts).digits, 4, "four digits " .. k)
	end

	-- Prices
	local prices = PlateConfig.prices
	local double = PlateConfig.repeatMultiplier
	t.eq(PlateText.price("SA:ABJ-7"), prices[1], "1 digit")
	t.eq(PlateText.price("SA:ABJ-12"), prices[2], "2 digits")
	t.eq(PlateText.price("SA:ABJ-77"), prices[2] * double, "2 identical digits")
	t.eq(PlateText.price("SA:ABJ-123"), prices[3], "3 digits")
	t.eq(PlateText.price("SA:ABJ-1234"), prices[4], "4 digits")
	t.eq(PlateText.price("SA:AAA-1234"), prices[4] * double, "three identical letters")
	t.eq(PlateText.price("SA:ABJ-7777"), prices[4] * double, "all digits identical")
	t.eq(PlateText.price("SA:AAA-7777"), prices[4] * double, "both still only double")
end
