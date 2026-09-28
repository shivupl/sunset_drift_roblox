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
	local prices = PlateConfig.prices.SA
	local double = PlateConfig.repeatMultiplier
	t.eq(PlateText.price("SA:ABJ-7"), prices[1], "1 digit")
	t.eq(PlateText.price("SA:ABJ-12"), prices[2], "2 digits")
	t.eq(PlateText.price("SA:ABJ-77"), prices[2] * double, "2 identical digits")
	t.eq(PlateText.price("SA:ABJ-123"), prices[3], "3 digits")
	t.eq(PlateText.price("SA:ABJ-1234"), prices[4], "4 digits")
	t.eq(PlateText.price("SA:AAA-1234"), prices[4] * double, "three identical letters")
	t.eq(PlateText.price("SA:ABJ-7777"), prices[4] * double, "all digits identical")
	t.eq(PlateText.price("SA:AAA-7777"), prices[4] * double, "both still only double")
	-- Dubai (docs/superpowers/specs/2026-09-27-dubai-plates-design.md)
	local function du(s: string): string?
		return (PlateText.normalise("DU", s))
	end
	local function duReason(s: string): string?
		local _, r = PlateText.normalise("DU", s)
		return r
	end
	t.eq(du("A 12345"), "DU:A-12345", "dubai code and number")
	t.eq(du("a-7"), "DU:A-7", "lower case code")
	t.eq(du("12345 A"), "DU:A-12345", "number first")
	t.eq(du("AA 0007"), "DU:AA-7", "double code, leading zeros")
	t.eq(du("Z" .. utf8.char(0x0661, 0x0662)), "DU:Z-12", "arabic-indic digits")
	t.eq(du("Z" .. utf8.char(0x06F5)), "DU:Z-5", "persian digit")
	for _, code in { "AA", "BB", "CC", "DD", "EE" } do
		t.eq(du(code .. " 9"), `DU:{code}-9`, "double code " .. code)
	end
	for _, bad in { "FF 1", "AB 1", "ABC 1", "A 123456", "A 00000", "A", "7", "A7B", "أ 7", string.rep("A", 100) } do
		t.eq(du(bad), nil, "dubai rejected: " .. bad)
		t.ok(duReason(bad) ~= nil, "dubai reason for: " .. bad)
	end
	t.eq(PlateText.normalise("XX", "A 1"), nil, "unknown style")
	-- A Dubai key is never read as a Saudi one, and the other way round
	t.eq(PlateText.normalise("SA", "A 12345"), nil, "a dubai plate is not a saudi plate")
	local d = PlateText.parts("DU:AA-12345")
	t.ok(d ~= nil, "parts of a dubai key")
	if d then
		t.eq(d.style, "DU", "style")
		t.eq(table.concat(d.latin), "AA", "code")
		t.eq(d.digits, "12345", "digits")
		t.eq(#d.arabic, 0, "no arabic letters on a dubai plate")
	end
	for _, badKey in { "DU:FF-1", "DU:A-123456", "DU:A-07", "DU:A-0" } do
		t.eq(PlateText.parts(badKey), nil, "not a dubai key: " .. badKey)
	end
	t.eq(PlateText.styleOf("DU:A-7"), "DU", "style of a dubai key")
	t.eq(PlateText.styleOf("SA:ABJ-7"), "SA", "style of a saudi key")
	t.eq(PlateText.typed("DU:AA-12345"), "AA 12345", "dubai key as typed text")
	t.eq(PlateText.typed("SA:ABJ-7"), "ABJ 7", "saudi key as typed text")
	t.eq(PlateText.normalise("DU", PlateText.typed("DU:AA-12345") :: string), "DU:AA-12345", "typed text round trip")
	t.ok(PlateText.isStyle("SA") and PlateText.isStyle("DU") and not PlateText.isStyle("XX"), "known styles")
	local dp = PlateConfig.prices.DU
	t.eq(PlateText.price("DU:A-7"), dp[1], "dubai 1 digit")
	t.eq(PlateText.price("DU:A-12"), dp[2], "dubai 2 digits")
	t.eq(PlateText.price("DU:A-123"), dp[3], "dubai 3 digits")
	t.eq(PlateText.price("DU:A-1234"), dp[4], "dubai 4 digits")
	t.eq(PlateText.price("DU:A-12345"), dp[5], "dubai 5 digits")
	t.eq(PlateText.price("DU:AA-55555"), dp[5] * double, "dubai all digits identical")
	-- Abu Dhabi and Kuwait (docs/superpowers/specs/2026-09-27-abu-dhabi-kuwait-plates-design.md)
	local function key2(style: string, s: string): string?
		return (PlateText.normalise(style, s))
	end
	local function why2(style: string, s: string): string?
		local _, r = PlateText.normalise(style, s)
		return r
	end
	t.eq(key2("AD", "20 10234"), "AD:20-10234", "abu dhabi code and number")
	t.eq(key2("AD", "1-7"), "AD:1-7", "abu dhabi code 1, hyphen")
	t.eq(key2("AD", "050 00099"), "AD:50-99", "abu dhabi code 50, leading zeros")
	t.eq(key2("AD", utf8.char(0x0662, 0x0660) .. " " .. utf8.char(0x0661, 0x0662)), "AD:20-12", "abu dhabi arabic-indic digits")
	for _, code in { 1, 4, 13, 22, 50 } do
		t.eq(key2("AD", `{code} 5`), `AD:{code}-5`, "abu dhabi code " .. code)
	end
	for _, bad in { "2 5", "3 5", "23 5", "49 5", "51 5", "0 5", "20 123456", "20 0", "2010234", "20", "A 20 5", "20 5 6" } do
		t.eq(key2("AD", bad), nil, "abu dhabi rejected: " .. bad)
		t.ok(why2("AD", bad) ~= nil, "abu dhabi reason for: " .. bad)
	end
	t.eq(key2("KW", "10-23456"), "KW:10-23456", "kuwait code and number")
	t.eq(key2("KW", "1 1"), "KW:1-1", "kuwait smallest")
	t.eq(key2("KW", "89 99999"), "KW:89-99999", "kuwait largest")
	t.eq(key2("KW", utf8.char(0x06F1, 0x06F0) .. "-" .. utf8.char(0x06F5)), "KW:10-5", "kuwait persian digits")
	for _, bad in { "0 5", "90 5", "10 123456", "10 00000", "1023456", "10", "K 10 5" } do
		t.eq(key2("KW", bad), nil, "kuwait rejected: " .. bad)
		t.ok(why2("KW", bad) ~= nil, "kuwait reason for: " .. bad)
	end
	for _, k in { "AD:20-10234", "AD:1-7", "KW:10-23456", "KW:89-5" } do
		local q = PlateText.parts(k)
		t.ok(q ~= nil, "parts of " .. k)
		t.eq(PlateText.normalise(string.sub(k, 1, 2), PlateText.typed(k) :: string), k, "typed round trip " .. k)
	end
	local ad = PlateText.parts("AD:20-10234")
	if ad then
		t.eq(table.concat(ad.latin), "20", "abu dhabi code in parts")
		t.eq(ad.digits, "10234", "abu dhabi digits in parts")
	end
	for _, badKey in { "AD:2-5", "AD:20-123456", "AD:020-5", "KW:90-5", "KW:10-05", "KW:A-5" } do
		t.eq(PlateText.parts(badKey), nil, "not a key: " .. badKey)
	end
	t.ok(PlateText.isStyle("AD") and PlateText.isStyle("KW"), "abu dhabi and kuwait are styles")
	t.eq(PlateText.price("AD:20-7"), PlateConfig.prices.AD[1], "abu dhabi 1 digit")
	t.eq(PlateText.price("AD:20-12345"), PlateConfig.prices.AD[5], "abu dhabi 5 digits")
	t.eq(PlateText.price("KW:10-99"), PlateConfig.prices.KW[2] * double, "kuwait identical digits")
	t.eq(PlateText.price("KW:10-23456"), PlateConfig.prices.KW[5], "kuwait 5 digits")
	-- The existing styles are unchanged by the new runs
	t.eq(PlateText.normalise("SA", "ABJ 12 34"), "SA:ABJ-1234", "saudi digits may still be spaced")
	t.eq(PlateText.normalise("DU", "A 12 345"), "DU:A-12345", "dubai digits may still be spaced")
end
