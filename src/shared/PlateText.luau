--!strict
-- Plate strings: the one place they are parsed (spec §3). The purchase
-- screen and the server both use it; the server always normalises again
-- and never trusts the client's string.
--
-- Canonical key: style code, colon, the Latin letters in reading order, a
-- hyphen, the number without leading zeros. ASCII only: "SA:ABJ-7".
local PlateConfig = require(script.Parent.PlateConfig)

local PlateText = {}

export type Parts = {
	style: string,
	latin: { string }, -- the letters in reading order
	arabic: { string }, -- the same letters in Arabic: arabic[i] is latin[i] and is drawn above it
	digits: string, -- "7"
	arabicDigits: { string }, -- one per digit, same order as digits
}

-- The 17 Saudi plate letters and the Latin letter printed with each
-- (spec §3; checked against a reference in build Task 1).
local SA_LETTERS: { { arabic: string, latin: string } } = {
	{ arabic = "أ", latin = "A" },
	{ arabic = "ب", latin = "B" },
	{ arabic = "ح", latin = "J" },
	{ arabic = "د", latin = "D" },
	{ arabic = "ر", latin = "R" },
	{ arabic = "س", latin = "S" },
	{ arabic = "ص", latin = "X" },
	{ arabic = "ط", latin = "T" },
	{ arabic = "ع", latin = "E" },
	{ arabic = "ق", latin = "G" },
	{ arabic = "ك", latin = "K" },
	{ arabic = "ل", latin = "L" },
	{ arabic = "م", latin = "Z" },
	{ arabic = "ن", latin = "N" },
	{ arabic = "هـ", latin = "H" },
	{ arabic = "و", latin = "U" },
	{ arabic = "ى", latin = "V" },
}
PlateText.SA_LETTERS = SA_LETTERS

-- Arabic code point -> Latin letter. The hamza forms and bare alef are all
-- A. H is shown as ه with a tatweel; input loses the tatweel first, so the
-- bare ه is what arrives here.
local FROM_ARABIC: { [number]: string } = {
	[0x0623] = "A", [0x0625] = "A", [0x0622] = "A", [0x0627] = "A",
	[0x0628] = "B", [0x062D] = "J", [0x062F] = "D", [0x0631] = "R",
	[0x0633] = "S", [0x0635] = "X", [0x0637] = "T", [0x0639] = "E",
	[0x0642] = "G", [0x0643] = "K", [0x0644] = "L", [0x0645] = "Z",
	[0x0646] = "N", [0x0647] = "H", [0x0648] = "U", [0x0649] = "V",
}

local TO_ARABIC: { [string]: string } = {}
for _, l in SA_LETTERS do
	TO_ARABIC[l.latin] = l.arabic
end

-- Dropped before anything else: whitespace, hyphens, tatweel and the
-- invisible direction and joining marks. Without this, "7" and "7" with a
-- hidden mark would be two keys.
local DROP: { [number]: boolean } = {
	[9] = true, [10] = true, [11] = true, [12] = true, [13] = true, [32] = true,
	[45] = true, -- hyphen
	[0x00A0] = true, -- no-break space
	[0x0640] = true, -- tatweel
	[0x200E] = true, -- LRM
	[0x200F] = true, -- RLM
	[0x061C] = true, -- ALM
	[0x200C] = true, -- ZWNJ
	[0x200D] = true, -- ZWJ
}

-- The plate key for what a player typed, or nil and the reason to show them.
function PlateText.normalise(style: string, input: string): (string?, string?)
	if style ~= "SA" then
		return nil, "Only Saudi plates for now"
	end
	if #input > PlateConfig.maxInputBytes then
		return nil, "That is too long for a plate"
	end
	if not utf8.len(input) then
		return nil, "That is not valid text"
	end
	local letters: { string } = {}
	local digits: { string } = {}
	local groups = 0
	local last = ""
	local scripts: { [string]: boolean } = {} -- which scripts the letters came in
	for _, cp in utf8.codes(input) do
		if DROP[cp] then
			continue
		end
		local kind: string, ch: string = "", ""
		if cp >= 48 and cp <= 57 then
			kind, ch = "digit", string.char(cp)
		elseif cp >= 0x0660 and cp <= 0x0669 then
			kind, ch = "digit", tostring(cp - 0x0660)
		elseif cp >= 0x06F0 and cp <= 0x06F9 then
			kind, ch = "digit", tostring(cp - 0x06F0)
		elseif (cp >= 65 and cp <= 90) or (cp >= 97 and cp <= 122) then
			local up = string.upper(string.char(cp))
			if not TO_ARABIC[up] then
				return nil, `{up} is not a Saudi plate letter`
			end
			kind, ch = "letter", up
			scripts.latin = true
		elseif FROM_ARABIC[cp] then
			kind, ch = "letter", FROM_ARABIC[cp]
			scripts.arabic = true
		else
			return nil, `{utf8.char(cp)} is not a Saudi plate letter or digit`
		end
		if kind ~= last then
			groups += 1
			last = kind
		end
		table.insert(if kind == "letter" then letters else digits, ch)
	end
	if groups > 2 then
		return nil, "Put the letters together and the number together"
	end
	if scripts.latin and scripts.arabic then
		return nil, "Type the letters in one script, Arabic or English"
	end
	if #letters ~= 3 then
		return nil, "A Saudi plate has 3 letters"
	end
	if scripts.arabic then
		-- Arabic is typed in reading order, right to left, and each Arabic
		-- letter sits above its Latin letter on the plate, so the Latin
		-- reading order is the reverse (spec "Checked", 2026-09-27).
		letters = { letters[3], letters[2], letters[1] }
	end
	if #digits < 1 or #digits > 4 then
		return nil, "A Saudi plate has a number of 1 to 4 digits"
	end
	local number = tonumber(table.concat(digits)) :: number
	if number == 0 then
		return nil, "The number cannot be all zeros"
	end
	return `SA:{table.concat(letters)}-{number}`, nil
end

-- A key split into what a plate draws. nil for anything not a valid key.
function PlateText.parts(key: string): Parts?
	local style, letters, number = string.match(key, "^(%u%u):(%u+)%-(%d+)$")
	if not style or not letters or not number then
		return nil
	end
	if style ~= "SA" or #letters ~= 3 or #number > 4 or string.sub(number, 1, 1) == "0" then
		return nil
	end
	local latin: { string } = {}
	local arabic: { string } = {}
	for i = 1, #letters do
		local l = string.sub(letters, i, i)
		local a = TO_ARABIC[l]
		if not a then
			return nil
		end
		table.insert(latin, l)
		table.insert(arabic, a)
	end
	local arabicDigits: { string } = {}
	for i = 1, #number do
		table.insert(arabicDigits, utf8.char(0x0660 + (tonumber(string.sub(number, i, i)) :: number)))
	end
	return { style = style :: string, latin = latin, arabic = arabic, digits = number, arabicDigits = arabicDigits }
end

-- A random Saudi plate, 3 letters and 4 digits: the session's default
-- plate (spec §5). Never registered.
function PlateText.random(rng: Random): string
	local letters: { string } = {}
	for i = 1, 3 do
		letters[i] = SA_LETTERS[rng:NextInteger(1, #SA_LETTERS)].latin
	end
	return `SA:{table.concat(letters)}-{rng:NextInteger(1000, 9999)}`
end

-- What a plate costs in cash (PlateConfig). nil for anything not a valid key.
function PlateText.price(key: string): number?
	local p = PlateText.parts(key)
	if not p then
		return nil
	end
	local base = PlateConfig.prices[#p.digits]
	if not base then
		return nil
	end
	local sameLetters = p.latin[1] == p.latin[2] and p.latin[2] == p.latin[3]
	local first = string.sub(p.digits, 1, 1)
	local sameDigits = #p.digits > 1 and string.rep(first, #p.digits) == p.digits
	return if sameLetters or sameDigits then base * PlateConfig.repeatMultiplier else base
end

return PlateText
