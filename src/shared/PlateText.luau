--!strict
-- Plate strings: the one place they are parsed (spec §3). The purchase
-- screen and the server both use it; the server always normalises again
-- and never trusts the client's string.
--
-- Canonical key: style code, colon, the Latin letters in reading order (or
-- the Dubai code), a hyphen, the number without leading zeros. ASCII only:
-- "SA:ABJ-7", "DU:AA-12345".
local PlateConfig = require(script.Parent.PlateConfig)

local PlateText = {}

export type Parts = {
	style: string,
	latin: { string }, -- the letters in reading order (Dubai: its code letters; Abu Dhabi, Kuwait: its code number, one entry)
	arabic: { string }, -- Saudi: the same letters in Arabic, arabic[i] is latin[i] and is drawn above it; Dubai: empty
	digits: string, -- "7"
	arabicDigits: { string }, -- Saudi only: one per digit, same order as digits
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

-- The styles a player can buy, in menu order. The code is the start of
-- every key of that style, so plates of two styles never collide.
local STYLES: { { code: string, name: string } } = {
	{ code = "SA", name = "KSA" },
	{ code = "DU", name = "DUBAI" }, -- docs/superpowers/specs/2026-09-27-dubai-plates-design.md
	{ code = "AD", name = "ABU DHABI" }, -- docs/superpowers/specs/2026-09-27-abu-dhabi-kuwait-plates-design.md
	{ code = "KW", name = "KUWAIT" }, -- same
}
PlateText.STYLES = STYLES

function PlateText.isStyle(code: any): boolean
	for _, st in STYLES do
		if st.code == code then
			return true
		end
	end
	return false
end

-- Dubai codes (2026-09-27 reference check): a single letter, or one of the
-- five double codes.
local DU_CODES: { [string]: boolean } = { AA = true, BB = true, CC = true, DD = true, EE = true }
for c = 65, 90 do
	DU_CODES[string.char(c)] = true
end

-- Abu Dhabi private codes: 1, 4 to 22, and 50 (the UAE's 50th National
-- Day); Kuwait: 1 to 89 (2026-09-27 reference check).
local function adCode(n: number): boolean
	return n == 1 or n == 50 or (n >= 4 and n <= 22)
end
local function kwCode(n: number): boolean
	return n >= 1 and n <= 89
end

-- Styles whose code is a number: the code test, how the reason lists the
-- codes, and an example of the typed format.
local NUMERIC: { [string]: { name: string, ok: (number) -> boolean, codes: string, example: string } } = {
	AD = { name = "Abu Dhabi", ok = adCode, codes = "1, 4 to 22, or 50", example = "20 10234" },
	KW = { name = "Kuwait", ok = kwCode, codes = "1 to 89", example = "10 23456" },
}

type Run = { kind: string, text: string }

type Scan = {
	letters: { string }, -- Latin, uppercase; Arabic letters already mapped to Latin
	digits: { string }, -- 0-9
	groups: number, -- runs of letters or digits, in order
	latin: boolean, -- a letter was typed in Latin
	arabic: boolean, -- a letter was typed in Arabic
	runs: { Run }, -- letters and digits as typed, split by spaces and hyphens
}

-- Characters that end a run of digits or letters as typed (the rest of DROP,
-- tatweel and hidden marks, never split anything).
local SEPARATOR: { [number]: boolean } = {
	[9] = true, [10] = true, [11] = true, [12] = true, [13] = true, [32] = true,
	[45] = true, [0x00A0] = true,
}

-- What a player typed, split into letters and digits. Every style's rules
-- work on this, so hidden marks and Arabic-Indic digits normalise the same
-- way everywhere. nil and a reason for anything that is not a letter or a
-- digit.
local function scan(input: string): (Scan?, string?)
	if #input > PlateConfig.maxInputBytes then
		return nil, "That is too long for a plate"
	end
	if not utf8.len(input) then
		return nil, "That is not valid text"
	end
	local out: Scan = { letters = {}, digits = {}, groups = 0, latin = false, arabic = false, runs = {} }
	local last = ""
	local run: Run? = nil
	for _, cp in utf8.codes(input) do
		if DROP[cp] then
			if SEPARATOR[cp] then
				run = nil
			end
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
			kind, ch = "letter", string.upper(string.char(cp))
			out.latin = true
		elseif FROM_ARABIC[cp] then
			kind, ch = "letter", FROM_ARABIC[cp]
			out.arabic = true
		else
			return nil, `{utf8.char(cp)} is not a plate letter or digit`
		end
		if kind ~= last then
			out.groups += 1
			last = kind
		end
		table.insert(if kind == "letter" then out.letters else out.digits, ch)
		local current = run
		if current and current.kind == kind then
			current.text ..= ch
		else
			local fresh: Run = { kind = kind, text = ch }
			table.insert(out.runs, fresh)
			run = fresh
		end
	end
	if out.groups > 2 then
		return nil, "Put the letters together and the number together"
	end
	return out, nil
end

-- The number part: 1 to maxDigits digits, leading zeros dropped, not all zeros.
local function number(digits: { string }, maxDigits: number, name: string): (number?, string?)
	if #digits < 1 or #digits > maxDigits then
		return nil, `A {name} plate has a number of 1 to {maxDigits} digits`
	end
	local n = tonumber(table.concat(digits)) :: number
	if n == 0 then
		return nil, "The number cannot be all zeros"
	end
	return n, nil
end

local function normaliseSA(sc: Scan): (string?, string?)
	if sc.latin and sc.arabic then
		return nil, "Type the letters in one script, Arabic or English"
	end
	for _, l in sc.letters do
		if not TO_ARABIC[l] then
			return nil, `{l} is not a Saudi plate letter`
		end
	end
	if #sc.letters ~= 3 then
		return nil, "A Saudi plate has 3 letters"
	end
	local letters = sc.letters
	if sc.arabic then
		-- Arabic is typed in reading order, right to left, and each Arabic
		-- letter sits above its Latin letter on the plate, so the Latin
		-- reading order is the reverse (spec "Checked", 2026-09-27).
		letters = { letters[3], letters[2], letters[1] }
	end
	local n, why = number(sc.digits, 4, "Saudi")
	if not n then
		return nil, why
	end
	return `SA:{table.concat(letters)}-{n}`, nil
end

local function normaliseDU(sc: Scan): (string?, string?)
	if sc.arabic then
		return nil, "Dubai codes are English letters"
	end
	local code = table.concat(sc.letters)
	if code == "" then
		return nil, "A Dubai plate has a code letter, A to Z"
	end
	if not DU_CODES[code] then
		return nil, `{code} is not a Dubai code (A to Z, or AA, BB, CC, DD, EE)`
	end
	local n, why = number(sc.digits, 5, "Dubai")
	if not n then
		return nil, why
	end
	return `DU:{code}-{n}`, nil
end

-- Abu Dhabi and Kuwait: a code and a number, both digits, so they must be
-- typed as two groups ("20 10234"); run together they cannot be told apart.
local function normaliseNumeric(style: string, sc: Scan): (string?, string?)
	local rule = NUMERIC[style]
	if #sc.letters > 0 then
		return nil, `{rule.name} plates are all digits: the code, then the number`
	end
	if #sc.runs ~= 2 then
		return nil, `Type the code, a space, then the number, like {rule.example}`
	end
	local code = tonumber(sc.runs[1].text) :: number
	if not rule.ok(code) then
		return nil, `{sc.runs[1].text} is not a {rule.name} code ({rule.codes})`
	end
	local numberDigits: { string } = {}
	for i = 1, #sc.runs[2].text do
		table.insert(numberDigits, string.sub(sc.runs[2].text, i, i))
	end
	local n, why = number(numberDigits, 5, rule.name)
	if not n then
		return nil, why
	end
	return `{style}:{code}-{n}`, nil
end

-- The plate key for what a player typed in a style, or nil and the reason
-- to show them.
function PlateText.normalise(style: string, input: string): (string?, string?)
	if not PlateText.isStyle(style) then
		return nil, "Unknown plate style"
	end
	local sc, why = scan(input)
	if not sc then
		return nil, why
	end
	if style == "DU" then
		return normaliseDU(sc)
	elseif NUMERIC[style] then
		return normaliseNumeric(style, sc)
	end
	return normaliseSA(sc)
end

-- A key split into what a plate draws. nil for anything not a valid key.
function PlateText.parts(key: string): Parts?
	local style, letters, digits = string.match(key, "^(%u%u):(%w+)%-(%d+)$")
	if not style or not letters or not digits or string.sub(digits, 1, 1) == "0" then
		return nil
	end
	local numeric = NUMERIC[style]
	if numeric then
		local code = tonumber(letters)
		if not code or string.sub(letters, 1, 1) == "0" or not numeric.ok(code) or #digits > 5 then
			return nil
		end
		return { style = style :: string, latin = { letters }, arabic = {}, digits = digits, arabicDigits = {} }
	end
	if style == "DU" then
		if not DU_CODES[letters] or #digits > 5 then
			return nil
		end
		local code: { string } = {}
		for i = 1, #letters do
			table.insert(code, string.sub(letters, i, i))
		end
		return { style = "DU", latin = code, arabic = {}, digits = digits, arabicDigits = {} }
	end
	if style ~= "SA" or #letters ~= 3 or #digits > 4 then
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
	for i = 1, #digits do
		table.insert(arabicDigits, utf8.char(0x0660 + (tonumber(string.sub(digits, i, i)) :: number)))
	end
	return { style = style :: string, latin = latin, arabic = arabic, digits = digits, arabicDigits = arabicDigits }
end

-- The style code of a key ("SA", "DU"); nil for anything not a valid key.
function PlateText.styleOf(key: string): string?
	local p = PlateText.parts(key)
	return if p then p.style else nil
end

-- A key as a player would type it ("ABJ 7", "AA 12345"): what the menu
-- sends back to the server, which only ever takes typed text.
function PlateText.typed(key: string): string?
	local p = PlateText.parts(key)
	return if p then `{table.concat(p.latin)} {p.digits}` else nil
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
	local byDigits = PlateConfig.prices[p.style]
	local base = byDigits and byDigits[#p.digits]
	if not base then
		return nil
	end
	local sameLetters = p.style == "SA" and p.latin[1] == p.latin[2] and p.latin[2] == p.latin[3]
	local first = string.sub(p.digits, 1, 1)
	local sameDigits = #p.digits > 1 and string.rep(first, #p.digits) == p.digits
	return if sameLetters or sameDigits then base * PlateConfig.repeatMultiplier else base
end

return PlateText
