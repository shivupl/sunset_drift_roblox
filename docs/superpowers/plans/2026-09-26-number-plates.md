# Number Plates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Players buy globally unique Saudi number plates with in-game cash, own many, equip one, and see it drawn front and rear on whatever car they drive.

**Architecture:**
- **Registry.** A DataStore key per plate (`HajwalaPlates_v1`) is the only truth about who owns it. Every write is one conditional `UpdateAsync`.
- **Transactions.** Purchases and releases carry a transaction id from the plate key into the player's profile (`pendingTxns`). A flow cut off at any point is finished from what the key says (`settle`).
- **Drawing.** Each client draws plates from frames and text labels on a thin part at each spot listed per car in `CarPlateMounts`. The spot is driven by the car Model attribute `Plate`.
- **Buying.** Done from a Plates tab in the car menu.

**Tech Stack:** Luau (`--!strict`), Roblox DataStoreService / RemoteFunction / SurfaceGui, Rojo 7.7, luau-lsp, the repo's Studio spec runner, Studio MCP, Python 3 + numpy for `tools/carbody/storecar.py`.

**Spec:** `docs/superpowers/specs/2026-09-26-number-plates-design.md`. Read it first; this plan argues from it.

## Global Constraints

- `--!strict` on every Luau file. No invented or deprecated APIs.
- Tunables live in `src/shared/PlateConfig.luau`, never inline. Comment the why next to each number.
- **DataStore names:** `HajwalaPlates_v1` (plates), `HajwalaPlayer_v1` (profiles, existing; key prefix `p_`).
- **Canonical plate key:** ASCII `SA:ABJ-7` (style, colon, Latin letters in reading order, hyphen, number without leading zeros).
- **Pending claim:** 120 s. **Availability cache:** 30 s per plate. **History:** last 5 lines.
- **Prices:** 1 digit 500,000; 2 digits 200,000; 3 digits 75,000; 4 digits 20,000. Three identical letters or all digits identical (2+ digits) cost double.
- **Fake store:** used only in Studio (`RunService:IsStudio()`). A live server with no DataStore shows "shop unavailable" and never falls back to the fake.
- **A profile whose load failed is never saved.**
- **No real brands** in names or text.
- **Do not edit** `VehicleRig.luau`, `RigBuilder.luau`, `BodyBuilder.luau`, `CarCatalog.luau` or `RIG_SPEC.md`. The owner has uncommitted rig work in the first four and in `RIG_SPEC.md`, `VehicleRig.spec.luau` and `tools/carbody/kamri.py` / `meshkit.py`.
- **Git:**
  - Stage specific files only (`git add <paths>`, never `-A` or `.`).
  - End every commit message with the two trailers below.
  - After each commit, give the owner `https://github.com/shivupl/sunset_drift_roblox/commit/<sha>`, and ask before pushing.
  ```
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01PWSgvAKV3x1En9iuoQun7D
  ```
- **Docs travel with the change:** TUNING.md for `PlateConfig`, `tools/carbody/README.md` for plate spots.
- **Owner-facing results:** measured numbers in tables, screenshots for anything visual. Feel and price calls are the owner's.

## How to run things

- **Specs (Studio, Edit datamodel)**
  - Rojo must be serving (`rojo serve`, plugin connected) so the Edit tree has the latest files.
  - Run with MCP `execute_luau`:
    ```lua
    return require(game.ReplicatedStorage.Shared:Clone().Tests)()
    ```
  - It prints `[Tests] N passed, M failed`, then one `warn` per failure, prefixed with the spec name. Read them with MCP `get_console_output`.
  - **Baseline:** 14 failures, all prefixed `VehicleRig.spec`. They come from the owner's uncommitted rig work. Any other failure is yours.
- **Type check:** `bash scripts/analyze.sh`. Known baseline errors are in `World/init.luau`, `Station.luau` and `BodyBuilder.luau`. Only new errors in files you touched matter.
- **Play checks:**
  - Stop and start Play after server changes. Rojo syncs into Edit only.
  - Before touching a car in Play, check `DriverSeat.Occupant`: the owner may be testing by hand.
  - The Client datamodel is where `game.Players.LocalPlayer` exists.

## Decisions this plan adds to the spec

1. **Two more server files, for testability.**
   - `src/server/FakeDataStore.luau`: the fake the spec's tests and Studio need.
   - `src/server/Stores.luau`: picks a real or fake store.
2. **A new client file for the Plates tab.** `src/client/PlatesPanel.luau` holds the tab's contents, because `SpawnMenu.luau` is already 779 lines. SpawnMenu only gains the tab bar and the swap.
3. **Release checks the version it just read.** The profile's plate entries carry no version. A release frees the key conditionally on "owned by me at the version I just read" (in `settle`), which is the same compare-and-set.
4. **Both Saudi formats are two rows** (Arabic above Latin; digits left, letters right). The strip is on the right of the short plate and in the centre of the long one. Task 1's reference check found this, correcting the spec's "side by side" guess for the long format. The layout is data in `PlateStyles`.
5. **The flows take a `Wallet` interface.** `Economy` provides one per player; the tests provide one over the fake store. This lets every failure point be tested without Players.
6. **Buying equips the plate** (spec §5: "Buy: charges, reserves and equips"), recovery included.
7. **Arabic input is in reading order.** Arabic letters typed by a player are in Arabic reading order (right to left), and each Arabic letter sits above its Latin letter on the plate. So `PlateText` reverses an Arabic letter group to get the Latin order (`حبأ` is `ABJ`), and refuses letters mixing the two scripts.

## File map

| File | Responsibility |
|---|---|
| `src/shared/PlateConfig.luau` | New. Prices, timings and limits |
| `src/shared/PlateText.luau` | New. Normalise input to a key, split a key for drawing, random default plate, price |
| `src/shared/PlateStyles.luau` | New. Saudi sizes, colours and layout (pure `layout`), and `draw` into any GUI container |
| `src/shared/CarPlateMounts.luau` | New. Plate spots per car id, and the spot's CFrame |
| `src/server/FakeDataStore.luau` | New. In-memory store with failure and race hooks |
| `src/server/Stores.luau` | New. `open(name)`: live, or fake in Studio without access |
| `src/server/PlateRegistry.luau` | New. Key writes (reserve, confirm, cancel, free), availability, and the flows (buy, release, settle, recover, checkEquipped) |
| `src/server/PlateService.luau` | New. Remotes, rate limits, one transaction per player, default plates, the `Plate` attribute on cars, retries |
| `src/server/Economy.luau` | Changed. Profile fields, one write at a time, `transact`, `wallet`, `setEquipped`, `onLoaded`, `Stores` |
| `src/server/Remotes.luau` | Changed. `PlateQuery` and `PlateAction` RemoteFunctions |
| `src/server/init.server.luau` | Changed. Start PlateService before ScoreService |
| `src/client/CarPlates.luau` | New. Builds and redraws plates on every car; `place` doubles as the live tuning hook |
| `src/client/PlatesPanel.luau` | New. The Plates tab |
| `src/client/SpawnMenu.luau` | Changed. Tab bar (CARS / PLATES) and swap |
| `src/client/init.client.luau` | Changed. `CarPlates.start()` |
| `src/shared/Tests/PlateText.spec.luau` | New |
| `src/shared/Tests/PlateRegistry.spec.luau` | New |
| `src/shared/Tests/PlateStyles.spec.luau` | New |
| `src/shared/Tests/CarPlateMounts.spec.luau` | New |
| `tools/carbody/storecar.py` | Changed. `--spots` prints store parts' centres in car space |
| `TUNING.md`, `tools/carbody/README.md`, `BRANCH_STATUS.md` | Docs |

---

### Task 1: Branch, font check and reference check (spike)

The answer decides whether glyphs are text labels (planned) or an uploaded sheet (stop and ask the owner). The spike also sets the real sizes and layout. Nothing from the spike is kept except a findings note in the spec.

**Files:**
- Modify: `docs/superpowers/specs/2026-09-26-number-plates-design.md` (append a "Checked" section)

- [ ] **Step 1: Branch**

```bash
git checkout -b plates
git status --short
```
Expected: on `plates`. The owner's uncommitted files are still listed as modified, and nothing is staged.

- [ ] **Step 2: Render every plate glyph in Studio (Edit)**

Run with MCP `execute_luau` (Edit datamodel):

```lua
local glyphs = "أ ب ح د ر س ص ط ع ق ك ل م ن هـ و ى   ٠١٢٣٤٥٦٧٨٩   ABJDRSXTEGKLZNHUV 0123456789   السعودية K S A"
local fonts = { Enum.Font.GothamBold, Enum.Font.GothamBlack, Enum.Font.Arial, Enum.Font.SourceSansBold, Enum.Font.Roboto }
local part = Instance.new("Part")
part.Name = "PlateGlyphCheck"
part.Anchored = true
part.Size = Vector3.new(40, #fonts * 4, 1)
part.CFrame = workspace.CurrentCamera.CFrame * CFrame.new(0, 0, -45)
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Back
gui.CanvasSize = Vector2.new(2000, #fonts * 200)
gui.Parent = part
for i, font in fonts do
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 200)
	l.Position = UDim2.fromOffset(0, (i - 1) * 200)
	l.BackgroundColor3 = Color3.new(1, 1, 1)
	l.TextColor3 = Color3.new(0, 0, 0)
	l.Font = font
	l.TextScaled = true
	l.Text = font.Name .. ": " .. glyphs
	l.Parent = gui
end
part.Parent = workspace
return "placed"
```

Focus Studio (`osascript -e 'tell application "RobloxStudio" to activate'`), wait 2 s, then `screen_capture`. If the part is not facing the camera, change `gui.Face` to `Front` and capture again.

Expected:
- All 17 letters, each shown as its isolated form (no tofu boxes).
- The Arabic-Indic digits ٠–٩.
- "السعودية" joined correctly.
- Note which font reads best for Latin and which for Arabic.

- [ ] **Step 3: Clean up**

```lua
local p = workspace:FindFirstChild("PlateGlyphCheck")
if p then p:Destroy() end
return "removed"
```

- [ ] **Step 4: If any Arabic glyph is missing, stop**

Report to the owner with the screenshot. The fallback in the spec (an uploaded sheet of 27 glyphs drawn with ImageLabels) changes Task 7 and needs their go-ahead. Otherwise continue.

- [ ] **Step 5: Reference check**

Use WebSearch or WebFetch on sources about the current Saudi number plate (Wikipedia "Vehicle registration plates of Saudi Arabia" and photos). Settle:

1. The sizes of the long and short plates, in cm.
2. Which side the KSA strip is on, its colour, and what it shows.
3. For each row: which side the digits are on and which side the letters are.
4. Whether the Arabic letters above are the Latin letters' order mirrored. Take a real plate and compare its Arabic row against its Latin row.
5. The 17-letter table in spec §3, letter by letter.

- [ ] **Step 6: Record the findings in the spec**

Append to `docs/superpowers/specs/2026-09-26-number-plates-design.md`:

```markdown
## Checked (2026-09-26, build Task 1)

| Question | Finding | Source |
|---|---|---|
| Arabic letters and digits render in a Roblox font | <yes/no; best fonts: Latin <font>, Arabic <font>> | Studio screenshot |
| Long plate size | <w × h cm> | <link> |
| Short plate size | <w × h cm> | <link> |
| KSA strip | <side, colour, contents> | <link> |
| Row layout | <digits left/right, letters left/right, Arabic row on top?> | <link> |
| Arabic letter order vs Latin | <mirrored or same> | <link> |
| Letter table | <matches / differences> | <link> |
```

Fill every cell with what you found. If the letter table differs from spec §3, also correct the table in §3 in the same edit.

- [ ] **Step 7: Commit**

```bash
git add docs/superpowers/specs/2026-09-26-number-plates-design.md
git commit -m "Plates spec: font and reference checks" -m "<one line per finding>" -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PWSgvAKV3x1En9iuoQun7D"
```

---

### Task 2: PlateConfig and PlateText

**Files:**
- Create: `src/shared/PlateConfig.luau`
- Create: `src/shared/PlateText.luau`
- Test: `src/shared/Tests/PlateText.spec.luau`
- Modify: `TUNING.md` (append a `PlateConfig` section)

**Interfaces:**
- Produces:
  - `PlateConfig`: a table with the fields below.
  - `PlateText.normalise(style: string, input: string): (string?, string?)` returns the key, or nil and a user-facing reason.
  - `PlateText.parts(key: string): PlateText.Parts?`
  - `PlateText.random(rng: Random): string`
  - `PlateText.price(key: string): number?`
  - `PlateText.SA_LETTERS: { { arabic: string, latin: string } }`
  - `export type Parts = { style: string, latin: { string }, arabic: { string }, digits: string, arabicDigits: { string } }`

- [ ] **Step 1: Write the failing test**

Create `src/shared/Tests/PlateText.spec.luau`:

```lua
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
```

- [ ] **Step 2: Run it and see it fail**

Run the specs. Expected: a failure line `PlateText.spec: error ... PlateText is not a valid member` (or similar), plus the 14 baseline `VehicleRig.spec` failures.

- [ ] **Step 3: Write PlateConfig**

Create `src/shared/PlateConfig.luau`:

```lua
--!strict
-- Number plates: prices, timings and limits
-- (docs/superpowers/specs/2026-09-26-number-plates-design.md). TUNING.md,
-- "PlateConfig", says which way to move each.
local PlateConfig = {
	-- Price by how many digits the number has. First guesses (spec §5,
	-- 2026-09-26), for the owner to set against how fast cash is earned.
	prices = { [1] = 500_000, [2] = 200_000, [3] = 75_000, [4] = 20_000 } :: { [number]: number },
	-- Three identical letters (AAA) or all digits identical (77, 7777) cost this many times the price.
	repeatMultiplier = 2,
	-- Seconds a purchase holds a plate while the cash is taken; after this
	-- anyone may claim it (spec §4). Long enough for a slow profile write.
	pendingSeconds = 120,
	-- A server remembers whether a plate is free for this long, so typing
	-- in the search box does not read the store on every key (spec §4).
	availabilityCacheSeconds = 30,
	-- Lines of ownership history kept on a plate key.
	historyLength = 5,
	-- Longest plate text a player may send, in bytes (Arabic is 2 per letter).
	maxInputBytes = 64,
	-- Remote calls a player may make per second; more get "busy".
	queriesPerSecond = 4,
	actionsPerSecond = 1,
	-- Tries at a default plate nobody owns before keeping the last one
	-- (a default is never registered, so a clash is only cosmetic).
	defaultPicks = 3,
	-- How often an unfinished plate transaction is retried (seconds).
	retrySeconds = 30,
	-- Cash a new profile starts with in Studio's fake store, so buying can
	-- be tried there. Never used on a live server.
	studioCash = 2_000_000,
	-- The plate sits this far out from its spot, so it never fights the
	-- body's recess for the same pixels (metres, before the car's scale).
	standoffM = 0.006,
	-- Plate part thickness (metres, before the car's scale).
	thicknessM = 0.01,
	-- Plates further than this from the camera are not drawn (studs).
	drawDistanceStuds = 150,
}

return PlateConfig
```

- [ ] **Step 4: Write PlateText**

Create `src/shared/PlateText.luau`:

```lua
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
	return { style = style, latin = latin, arabic = arabic, digits = number, arabicDigits = arabicDigits }
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
```

- [ ] **Step 5: Run the specs and see them pass**

Expected: no `PlateText.spec` lines. The only failures are the 14 `VehicleRig.spec` baseline.

- [ ] **Step 6: Type check**

Run `bash scripts/analyze.sh 2>&1 | grep -E "PlateText|PlateConfig"`. Expected: no output.

- [ ] **Step 7: Document PlateConfig in TUNING.md**

Append to `TUNING.md`:

```markdown
# Plates (`src/shared/PlateConfig.luau`)

Number plates (docs/superpowers/specs/2026-09-26-number-plates-design.md).

| Field | What it does | Which way |
|---|---|---|
| `prices[1..4]` | Cash price by number of digits (500,000 / 200,000 / 75,000 / 20,000) | First guesses; the owner sets them against how fast cash is earned |
| `repeatMultiplier` | Price multiplier for AAA letters or all-identical digits (2) | Up to make those rarer |
| `pendingSeconds` | How long a purchase holds a plate while cash is taken (120) | Down frees abandoned claims sooner; never below a slow profile write (~10 s) |
| `availabilityCacheSeconds` | How long a server trusts a "free" answer (30) | Down shows sold plates sooner, at a read per plate per search |
| `historyLength` | Owner history lines kept on a plate key (5) | |
| `maxInputBytes` | Longest plate text accepted (64) | |
| `queriesPerSecond`, `actionsPerSecond` | Remote rate limits per player (4, 1) | Down if the DataStore budget runs short |
| `defaultPicks` | Tries to find a default plate nobody owns (3) | |
| `retrySeconds` | Retry period for an unfinished purchase or release (30) | |
| `studioCash` | Starting cash in Studio's fake store (2,000,000) | Studio only |
| `standoffM`, `thicknessM` | Plate offset from its spot and thickness (0.006, 0.01 m) | Up `standoffM` if a plate flickers against the body |
| `drawDistanceStuds` | Plates beyond this are not drawn (150) | Down for phone performance |
```

- [ ] **Step 8: Commit**

```bash
git add src/shared/PlateConfig.luau src/shared/PlateText.luau src/shared/Tests/PlateText.spec.luau TUNING.md
git commit -m "Plates: PlateText parses plate strings, PlateConfig holds prices" -m "Arabic-Indic and Persian digits, hamza forms, hidden marks and tatweel all normalise to one ASCII key (SA:ABJ-7); anything outside the 17 letters is refused with a reason." -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PWSgvAKV3x1En9iuoQun7D"
```

---

### Task 3: FakeDataStore, Stores and the registry's key writes

**Files:**
- Create: `src/server/FakeDataStore.luau`
- Create: `src/server/Stores.luau`
- Create: `src/server/PlateRegistry.luau`
- Test: `src/shared/Tests/PlateRegistry.spec.luau`

**Interfaces:**
- Consumes: `PlateConfig` (Task 2).
- Produces:
  - `FakeDataStore.new(): Fake`. A `Fake` has fields `data`, `userIds`, `ops`, `hook`, `beforeCommit` and methods `GetAsync` and `UpdateAsync`.
  - `FakeDataStore.copy(v: any): any`
  - `Stores.open(name: string): (any, Stores.Kind)`, where `Kind = "live" | "fake" | "none"`.
  - `PlateRegistry.new(store: Store, options: Options): Registry`, with:
    - `read(key): (Record, boolean)`
    - `available(key): boolean?`
    - `reserve(key, userId, txn): "ok"|"taken"|"error"`
    - `confirm(key, userId, txn, price): "ok"|"lost"|"error"`
    - `cancel(key, txn): "ok"|"error"`
    - `free(key, userId, version, txn): "ok"|"notmine"|"error"`
  - Exported types: `Record`, `Status`, `OwnedPlate`, `PendingTxn`, `PlateProfile`, `Outcome`, `Wallet`, `Store`, `Options`, `Registry`, `BuyResult`, `ReleaseResult`. Task 4 fills in the flows.

- [ ] **Step 1: Write the failing test (key writes and races)**

Create `src/shared/Tests/PlateRegistry.spec.luau`:

```lua
--!strict
-- PlateRegistry against FakeDataStore (spec §6): two servers racing, a
-- failure at every step of a purchase and a release, and the clock moved
-- past a pending claim. After each, the two rules that matter:
--   * a plate never has two owners;
--   * cash is charged exactly when the plate is recorded, or refunded.
-- The modules are server modules, cloned so each run gets fresh code.
local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")
local PlateRegistry = (require :: any)(Server:WaitForChild("PlateRegistry"):Clone())
local FakeDataStore = (require :: any)(Server:WaitForChild("FakeDataStore"):Clone())
local PlateConfig = require(script.Parent.Parent.PlateConfig)
local Tests = require(script.Parent)
type T = Tests.T

local KEY = "SA:ABJ-7"
local PRICE = 500000
local START = 2000000
local REFUND = 250000

type TestWallet = {
	userId: number,
	view: () -> any,
	transact: (mutate: (p: any) -> boolean) -> string,
	reload: () -> (),
}

-- A profile over the fake store, written the way Economy.transact writes:
-- change a copy, write it whole, and only then make the same change to the
-- live profile.
local function newWallet(store: any, userId: number, cash: number?): TestWallet
	local profileKey = "p_" .. userId
	local live: any = { cash = cash or START, plates = {}, pendingTxns = {} }
	store.data[profileKey] = FakeDataStore.copy(live)
	local w: any = { userId = userId }
	w.view = function()
		return live
	end
	w.transact = function(mutate: (p: any) -> boolean): string
		local draft = FakeDataStore.copy(live)
		if not mutate(draft) then
			return "refused"
		end
		local ok = pcall(function()
			store:UpdateAsync(profileKey, function()
				return FakeDataStore.copy(draft), nil
			end)
		end)
		if not ok then
			return "error"
		end
		mutate(live)
		return "ok"
	end
	-- A server crash: this session's memory is gone; the next session loads
	-- what was written.
	w.reload = function()
		live = FakeDataStore.copy(store.data[profileKey])
	end
	return w :: TestWallet
end

-- A fresh store and clock, and a way to start "servers" on them. Every
-- server shares the transaction counter, so ids are t1, t2, ...
local function world(): (any, { now: number }, () -> any)
	local store = FakeDataStore.new()
	local clock = { now = 1000 }
	local n = 0
	local function registry(): any
		return PlateRegistry.new(store, {
			clock = function(): number
				return clock.now
			end,
			newTxn = function(): string
				n += 1
				return "t" .. n
			end,
		})
	end
	return store, clock, registry
end

return function(t: T)
	do -- Reserve, confirm, cancel, free on one key
		local store, clock, registry = world()
		local reg = registry()
		t.eq(reg.reserve(KEY, 1, "a"), "ok", "a missing key can be reserved")
		t.eq(store.data[KEY].status, "pending", "reserved is pending")
		t.eq(store.data[KEY].version, 1, "first write is version 1")
		t.eq(reg.reserve(KEY, 2, "b"), "taken", "a live claim blocks another")
		t.eq(reg.confirm(KEY, 1, "wrong", PRICE), "lost", "confirm needs the same txn")
		t.eq(reg.confirm(KEY, 1, "a", PRICE), "ok", "confirm with the txn")
		t.eq(store.data[KEY].owner, 1, "owned by the buyer")
		t.eq(store.data[KEY].price, PRICE, "price kept for refunds")
		t.eq(#store.data[KEY].history, 1, "one history line")
		t.eq(store.userIds[KEY][1], 1, "the owner's UserId is on the write (right to erasure)")
		t.eq(reg.reserve(KEY, 2, "c"), "taken", "an owned plate cannot be reserved")
		local v = store.data[KEY].version
		t.eq(reg.free(KEY, 2, v, "d"), "notmine", "only the owner frees it")
		t.eq(reg.free(KEY, 1, v - 1, "d"), "notmine", "a stale version does not free it")
		t.eq(reg.free(KEY, 1, v, "d"), "ok", "the owner frees it at the version read")
		t.eq(store.data[KEY].status, "free", "free again")
		t.eq(store.data[KEY].version, v + 1, "version keeps rising")
		t.eq(reg.reserve(KEY, 2, "e"), "ok", "a freed plate is back in the pool")
		t.eq(reg.cancel(KEY, "wrong"), "ok", "cancel with another txn is a no-op")
		t.eq(store.data[KEY].status, "pending", "still pending")
		t.eq(reg.cancel(KEY, "e"), "ok", "cancel with the txn")
		t.eq(store.data[KEY].status, "free", "cancelled claim is free")

		-- A claim that has run out can be taken
		reg.reserve(KEY, 1, "f")
		clock.now += PlateConfig.pendingSeconds - 1
		t.eq(reg.reserve(KEY, 2, "g"), "taken", "claim still live just before it runs out")
		clock.now += 2
		t.eq(reg.reserve(KEY, 2, "g"), "ok", "a run-out claim is open")
	end

	do -- History keeps the last historyLength lines
		local store, _, registry = world()
		local reg = registry()
		for i = 1, PlateConfig.historyLength + 3 do
			reg.reserve(KEY, i, "r" .. i)
			reg.confirm(KEY, i, "r" .. i, PRICE)
			reg.free(KEY, i, store.data[KEY].version, "f" .. i)
		end
		t.eq(#store.data[KEY].history, PlateConfig.historyLength, "history is trimmed")
	end

	do -- Two servers reserve at once: the write that lands second re-checks and backs off
		local store, _, registry = world()
		local reg1, reg2 = registry(), registry()
		local second: string? = nil
		store.beforeCommit = function(k: string)
			if k ~= KEY then
				return
			end
			store.beforeCommit = nil
			second = reg2.reserve(KEY, 2, "b")
		end
		t.eq(reg1.reserve(KEY, 1, "a"), "taken", "race: the later write is refused")
		t.eq(second, "ok", "race: the earlier write wins")
		t.eq(store.data[KEY].txn, "b", "race: the key holds the winner's txn")
	end

	do -- A write that fails before or after landing reports an error
		local store, _, registry = world()
		local reg = registry()
		store.hook = function(_op: string, _k: string, phase: string)
			if phase == "before" then
				error("down")
			end
		end
		t.eq(reg.reserve(KEY, 1, "a"), "error", "store down: error")
		t.eq(store.data[KEY], nil, "nothing written")
		store.hook = function(_op: string, _k: string, phase: string)
			if phase == "after" then
				error("lost reply")
			end
		end
		t.eq(reg.reserve(KEY, 1, "a"), "error", "reply lost: error")
		t.eq(store.data[KEY].status, "pending", "but the write landed")
		store.hook = nil
		local _, ok = reg.read(KEY)
		t.ok(ok, "reads work again")
	end

	do -- Availability is cached per server for availabilityCacheSeconds
		local store, clock, registry = world()
		local reg1, reg2 = registry(), registry()
		t.eq(reg2.available(KEY), true, "free before anyone buys")
		reg1.reserve(KEY, 1, "a")
		reg1.confirm(KEY, 1, "a", PRICE)
		t.eq(reg1.available(KEY), false, "the writing server knows at once")
		t.eq(reg2.available(KEY), true, "another server may show it free until its cache runs out")
		clock.now += PlateConfig.availabilityCacheSeconds
		t.eq(reg2.available(KEY), false, "then it knows")
		store.hook = function()
			error("down")
		end
		clock.now += PlateConfig.availabilityCacheSeconds
		t.eq(reg2.available(KEY), nil, "unknown while the store is down")
		store.hook = nil
	end
end
```

- [ ] **Step 2: Run it and see it fail**

Expected: `PlateRegistry.spec: error ... PlateRegistry is not a valid member` (or `Server` not found if Rojo has not synced; check Rojo is connected).

- [ ] **Step 3: Write FakeDataStore**

Create `src/server/FakeDataStore.luau`:

```lua
--!strict
-- An in-memory DataStore for the plate tests, and for Studio when this
-- place's API access to DataStores is off (spec §6). Only ever chosen in
-- Studio (Stores.open); a live server never falls back to it.
--
-- It behaves like the real store where the registry depends on it: values
-- are copied in and out (the real store round-trips JSON), and UpdateAsync
-- runs the transform again when the key changed between its read and its
-- write. Tests steer it with two hooks:
--   hook(op, key, phase)  called before and after every call. Erroring in
--                         it fails the call; after "after", the write has
--                         landed but the caller still sees an error, as the
--                         real store can do.
--   beforeCommit(key)     called inside every UpdateAsync, after its
--                         transform and before its write. A test runs a
--                         second server's write here to race this one, and
--                         clears the hook itself first.
local FakeDataStore = {}

export type Phase = "before" | "after"
export type Fake = {
	data: { [string]: any },
	userIds: { [string]: { number } },
	ops: number, -- calls started so far
	hook: ((op: string, key: string, phase: Phase) -> ())?,
	beforeCommit: ((key: string) -> ())?,
	GetAsync: (self: Fake, key: string) -> any,
	UpdateAsync: (self: Fake, key: string, transform: (old: any, info: any) -> (any, { number }?)) -> any,
}

local function copy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = copy(x)
	end
	return out
end
FakeDataStore.copy = copy

function FakeDataStore.new(): Fake
	local self: any = { data = {}, userIds = {}, ops = 0 }

	function self.GetAsync(_: any, key: string): any
		self.ops += 1
		local hook = self.hook
		if hook then
			hook("get", key, "before")
		end
		local value = copy(self.data[key])
		if hook then
			hook("get", key, "after")
		end
		return value
	end

	function self.UpdateAsync(_: any, key: string, transform: (old: any, info: any) -> (any, { number }?)): any
		self.ops += 1
		local hook = self.hook
		if hook then
			hook("update", key, "before")
		end
		for _ = 1, 8 do
			local seen = self.data[key]
			local new, ids = transform(copy(seen), nil)
			local race = self.beforeCommit
			if race then
				race(key)
			end
			if self.data[key] == seen then
				if new ~= nil then
					self.data[key] = copy(new)
					if ids then
						self.userIds[key] = table.clone(ids)
					end
				end
				if hook then
					hook("update", key, "after")
				end
				return copy(new)
			end
			-- Another write landed in between: run the transform again on
			-- the new value, as the real store does.
		end
		error("FakeDataStore: UpdateAsync kept losing the race")
	end

	return self :: Fake
end

return FakeDataStore
```

- [ ] **Step 4: Write Stores**

Create `src/server/Stores.luau`:

```lua
--!strict
-- Opens a DataStore. In Studio with this place's API access to DataStores
-- off (File > Game Settings > Security), an in-memory fake instead, for the
-- session (spec §6). A live server never gets the fake: with no DataStore
-- it gets nil, and the callers say so (no saving; plate shop unavailable).
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local FakeDataStore = require(script.Parent.FakeDataStore)

export type Kind = "live" | "fake" | "none"

local Stores = {}

local fakes: { [string]: FakeDataStore.Fake } = {}

function Stores.open(name: string): (any, Kind)
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	if RunService:IsStudio() then
		-- GetDataStore succeeds in Studio even without access; the first read fails.
		local reachable = ok and pcall(function()
			return (store :: DataStore):GetAsync("__studio_probe")
		end)
		if not reachable then
			local fake = fakes[name] or FakeDataStore.new()
			fakes[name] = fake
			warn(`[Hajwala] Studio has no DataStore access: "{name}" is an in-memory fake for this session`)
			return fake, "fake"
		end
	end
	if not ok then
		warn(`[Hajwala] no DataStore "{name}": {tostring(store)}`)
		return nil, "none"
	end
	return store, "live"
end

return Stores
```

- [ ] **Step 5: Write PlateRegistry (key writes)**

Create `src/server/PlateRegistry.luau`:

```lua
--!strict
-- The plate registry (docs/superpowers/specs/2026-09-26-number-plates-design.md §4).
--
-- One DataStore key per plate ("SA:ABJ-7"). The key is the only truth about
-- who owns a plate; a player's profile holds a copy for display and is
-- corrected against the key.
--
-- Every write is one UpdateAsync that checks the key's current state first,
-- so two servers can never both win a plate: the store re-runs the check if
-- the key changed underneath it. Every write adds one to the key's version,
-- so a late write from an old transaction can never land on a plate that
-- has since changed hands. Freed keys are never deleted.
--
-- The flows (buy, release, recover) carry a transaction id (txn) from the
-- key into the profile's pendingTxns, so a flow cut off at any point is
-- finished from what the key says (settle). The store and the profile side
-- (Wallet) are passed in: the tests pass FakeDataStore and a fake wallet.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlateConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlateConfig"))

export type Status = "free" | "pending" | "owned"
export type HistoryLine = { owner: number, at: number, how: string }
export type Record = {
	schema: number,
	status: Status,
	owner: number?, -- UserId; nil unless owned
	txn: string?, -- the transaction that set the current status
	version: number, -- up by one on every write
	pendingUntil: number?, -- os.time(); only while pending
	since: number?, -- when the current owner got it
	price: number?, -- cash paid; used by refunds
	history: { HistoryLine }, -- last PlateConfig.historyLength
}

export type PlateState = "pending" | "owned" | "releasing"
export type OwnedPlate = { key: string, state: PlateState }
export type PendingTxn = { txn: string, kind: "buy" | "release", key: string, price: number }
-- The plate part of a player's profile (Economy.Profile has these fields).
export type PlateProfile = {
	cash: number,
	plates: { OwnedPlate },
	equipped: string?,
	pendingTxns: { PendingTxn },
}
export type Outcome = "ok" | "refused" | "error"
-- The profile side. transact changes the profile in one durable write:
-- mutate gets a copy and returns false to change nothing ("refused"); on
-- "ok" the same change has been written and made live; on "error" the live
-- profile is unchanged (the write may or may not have landed).
export type Wallet = {
	view: () -> PlateProfile,
	transact: (mutate: (p: PlateProfile) -> boolean) -> Outcome,
}
export type Store = {
	GetAsync: (self: any, key: string) -> any,
	UpdateAsync: (self: any, key: string, transform: (old: any, info: any) -> (any, { number }?)) -> any,
}
export type Options = {
	clock: () -> number, -- os.time in the game; the tests move it
	newTxn: (() -> string)?, -- GenerateGUID in the game
}
export type BuyResult = "done" | "taken" | "cash" | "unavailable" | "owned" | "pending"
export type ReleaseResult = "done" | "notowned" | "unavailable" | "pending"
export type Registry = {
	read: (key: string) -> (Record, boolean),
	available: (key: string) -> boolean?,
	reserve: (key: string, userId: number, txn: string) -> "ok" | "taken" | "error",
	confirm: (key: string, userId: number, txn: string, price: number) -> "ok" | "lost" | "error",
	cancel: (key: string, txn: string) -> "ok" | "error",
	free: (key: string, userId: number, version: number, txn: string) -> "ok" | "notmine" | "error",
	buy: (wallet: Wallet, userId: number, key: string, price: number) -> BuyResult,
	release: (wallet: Wallet, userId: number, key: string, refund: number) -> ReleaseResult,
	recover: (wallet: Wallet, userId: number) -> (),
	checkEquipped: (wallet: Wallet, userId: number) -> (),
}

local PlateRegistry = {}

local function blank(): Record
	return { schema = 1, status = "free", version = 0, history = {} }
end

-- A key as stored (or missing) read into a fresh Record.
local function readRecord(raw: any): Record
	local r = blank()
	if type(raw) ~= "table" then
		return r
	end
	if raw.status == "pending" or raw.status == "owned" then
		r.status = raw.status
	end
	r.owner = tonumber(raw.owner)
	r.txn = if type(raw.txn) == "string" then raw.txn else nil
	r.version = tonumber(raw.version) or 0
	r.pendingUntil = tonumber(raw.pendingUntil)
	r.since = tonumber(raw.since)
	r.price = tonumber(raw.price)
	if type(raw.history) == "table" then
		for _, h in raw.history do
			local owner, at = tonumber(type(h) == "table" and h.owner), tonumber(type(h) == "table" and h.at)
			if owner and at then
				table.insert(r.history, { owner = owner, at = at, how = tostring(h.how) })
			end
		end
	end
	return r
end

local function note(r: Record, owner: number, at: number, how: string)
	table.insert(r.history, { owner = owner, at = at, how = how })
	while #r.history > PlateConfig.historyLength do
		table.remove(r.history, 1)
	end
end

-- Free, or a claim that has run out.
local function isOpen(r: Record, now: number): boolean
	return r.status == "free" or (r.status == "pending" and (r.pendingUntil or 0) < now)
end

function PlateRegistry.new(store: Store, options: Options): Registry
	local clock = options.clock
	local newTxn = options.newTxn or function(): string
		return HttpService:GenerateGUID(false)
	end
	local cache: { [string]: { at: number, free: boolean } } = {}

	-- One conditional write. decide gets the key as it is now and changes
	-- it, or returns false to leave it alone. Returns the record written
	-- (nil when decide declined) and whether the call succeeded. A failed
	-- call may still have written (the store can fail after committing), so
	-- callers treat it as "don't know" and settle from a fresh read later.
	local function update(key: string, userId: number?, decide: (r: Record) -> boolean): (Record?, boolean)
		local written: Record? = nil
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old: any, _info: any): (any, { number }?)
				written = nil
				local r = readRecord(old)
				if not decide(r) then
					return nil, nil
				end
				r.version += 1
				written = r
				return r, if userId then { userId } else nil
			end)
		end)
		cache[key] = nil
		if not ok then
			warn(`[Plates] write to {key} failed: {tostring(err)}`)
			return nil, false
		end
		return written, true
	end

	local function read(key: string): (Record, boolean)
		local ok, raw = pcall(function()
			return store:GetAsync(key)
		end)
		if not ok then
			warn(`[Plates] read of {key} failed: {tostring(raw)}`)
			return blank(), false
		end
		return readRecord(raw), true
	end

	-- Whether a plate can be bought now; nil when the store cannot be read.
	local function available(key: string): boolean?
		local now = clock()
		local c = cache[key]
		if c and now - c.at < PlateConfig.availabilityCacheSeconds then
			return c.free
		end
		local r, ok = read(key)
		if not ok then
			return nil
		end
		local free = isOpen(r, now)
		cache[key] = { at = now, free = free }
		return free
	end

	-- Buying, step 1: claim the plate for pendingSeconds.
	local function reserve(key: string, userId: number, txn: string): "ok" | "taken" | "error"
		local now = clock()
		local written, ok = update(key, userId, function(r)
			if not isOpen(r, now) then
				return false
			end
			r.status = "pending"
			r.owner = nil
			r.txn = txn
			r.pendingUntil = now + PlateConfig.pendingSeconds
			return true
		end)
		if not ok then
			return "error"
		end
		return if written then "ok" else "taken"
	end

	-- Buying, step 3: only if the key still holds this purchase's claim.
	local function confirm(key: string, userId: number, txn: string, price: number): "ok" | "lost" | "error"
		local now = clock()
		local written, ok = update(key, userId, function(r)
			if r.status ~= "pending" or r.txn ~= txn then
				return false
			end
			r.status = "owned"
			r.owner = userId
			r.since = now
			r.price = price
			r.pendingUntil = nil
			note(r, userId, now, "buy")
			return true
		end)
		if not ok then
			return "error"
		end
		return if written then "ok" else "lost"
	end

	-- Lets go of a claim this purchase made (not enough cash, or the charge
	-- failed). Does nothing if the key moved on.
	local function cancel(key: string, txn: string): "ok" | "error"
		local _, ok = update(key, nil, function(r)
			if r.status ~= "pending" or r.txn ~= txn then
				return false
			end
			r.status = "free"
			r.txn = nil
			r.pendingUntil = nil
			return true
		end)
		return if ok then "ok" else "error"
	end

	-- Releasing, step 2: only if owned by this player at the version read.
	local function free(key: string, userId: number, version: number, txn: string): "ok" | "notmine" | "error"
		local now = clock()
		local written, ok = update(key, userId, function(r)
			if r.status ~= "owned" or r.owner ~= userId or r.version ~= version then
				return false
			end
			r.status = "free"
			r.owner = nil
			r.txn = txn
			r.since = nil
			r.price = nil
			note(r, userId, now, "release")
			return true
		end)
		if not ok then
			return "error"
		end
		return if written then "ok" else "notmine"
	end

	-- FLOWS (Task 4)

	return {
		read = read,
		available = available,
		reserve = reserve,
		confirm = confirm,
		cancel = cancel,
		free = free,
		buy = function(): BuyResult
			return "unavailable"
		end,
		release = function(): ReleaseResult
			return "unavailable"
		end,
		recover = function() end,
		checkEquipped = function() end,
	} :: any
end

return PlateRegistry
```

(The flow stubs keep the module loadable and typed until Task 4 replaces them.)

- [ ] **Step 6: Run the specs and see them pass**

Expected: no `PlateRegistry.spec` lines; only the 14 baseline failures.

- [ ] **Step 7: Type check**

Run `bash scripts/analyze.sh 2>&1 | grep -E "PlateRegistry|FakeDataStore|Stores"`. Expected: no output.

- [ ] **Step 8: Commit**

```bash
git add src/server/FakeDataStore.luau src/server/Stores.luau src/server/PlateRegistry.luau src/shared/Tests/PlateRegistry.spec.luau
git commit -m "Plates: registry key writes, one conditional UpdateAsync each" -m "Reserve, confirm, cancel and free each check the key first and bump its version; a race re-runs the check. FakeDataStore stands in for tests and for Studio without DataStore access." -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PWSgvAKV3x1En9iuoQun7D"
```

---

### Task 4: Registry flows: buy, release, settle, recover, checkEquipped

**Files:**
- Modify: `src/server/PlateRegistry.luau` (replace the `-- FLOWS (Task 4)` marker and the stubbed return)
- Test: `src/shared/Tests/PlateRegistry.spec.luau` (append)

**Interfaces:**
- Consumes: the Task 3 key writes, `Wallet`, `PendingTxn`, `PlateProfile`.
- Produces:
  - `Registry.buy(wallet, userId, key, price): BuyResult`
  - `Registry.release(wallet, userId, key, refund): ReleaseResult`
  - `Registry.recover(wallet, userId)`
  - `Registry.checkEquipped(wallet, userId)`
  - A finished purchase leaves the plate `owned` in `wallet.view().plates` and sets `equipped` to it.

- [ ] **Step 1: Write the failing tests**

In `src/shared/Tests/PlateRegistry.spec.luau`, add these two helpers above `return function(t: T)`:

```lua
-- The rules, for one plate and some players. ownerCash is what the plate's
-- owner must have left; otherCash is what everyone else must have.
local function check(t: T, label: string, store: any, wallets: { TestWallet }, ownerCash: number, otherCash: number)
	local rec = store.data[KEY]
	local owner = if type(rec) == "table" and rec.status == "owned" then rec.owner else nil
	for _, w in wallets do
		local p = w.view()
		t.eq(#p.pendingTxns, 0, `{label}: user {w.userId} has nothing unfinished`)
		local has: any = nil
		for _, plate in p.plates do
			if plate.key == KEY then
				has = plate
			end
		end
		if owner == w.userId then
			t.ok(has ~= nil and has.state == "owned", `{label}: user {w.userId} owns it and has it`)
			t.eq(p.cash, ownerCash, `{label}: user {w.userId} paid exactly once`)
		else
			t.ok(has == nil, `{label}: user {w.userId} does not own it and does not have it`)
			t.eq(p.cash, otherCash, `{label}: user {w.userId} is square`)
		end
	end
end

-- Failure modes, counted in store calls from when failAt is called:
--   once-before   call `at` fails, nothing written; later calls work
--   once-after    call `at` writes, then fails; later calls work
--   crash-before  call `at` and every later call fail, nothing written
--   crash-after   call `at` writes then fails; every later call fails
local MODES = { "once-before", "once-after", "crash-before", "crash-after" }
local function failAt(store: any, mode: string, at: number)
	store.ops = 0
	store.hook = function(_op: string, _key: string, phase: string)
		local n = store.ops
		local hit
		if mode == "once-before" then
			hit = n == at and phase == "before"
		elseif mode == "once-after" then
			hit = n == at and phase == "after"
		elseif mode == "crash-before" then
			hit = n >= at and phase == "before"
		else
			hit = (n == at and phase == "after") or (n > at and phase == "before")
		end
		if hit then
			error(`fake failure ({mode} at {at})`)
		end
	end
end
```

Then add these blocks just before the final `end` of the returned function:

```lua
	do -- A clean purchase, a second one, and not enough cash
		local store, _, registry = world()
		local reg = registry()
		local w1 = newWallet(store, 1)
		t.eq(reg.buy(w1, 1, KEY, PRICE), "done", "clean purchase")
		t.eq(w1.view().equipped, KEY, "buying equips it")
		check(t, "clean purchase", store, { w1 }, START - PRICE, START)
		t.eq(reg.buy(w1, 1, KEY, PRICE), "owned", "buying it again")
		local poor = newWallet(store, 3, 100)
		t.eq(reg.buy(poor, 3, "SA:ABJ-8", PRICE), "cash", "not enough cash")
		t.eq(store.data["SA:ABJ-8"], nil, "the plate was never touched")
		t.eq(poor.view().cash, 100, "nothing charged")
	end

	do -- Cash spent between the check and the charge: the claim is let go at once
		local store, _, registry = world()
		local reg = registry()
		local w1 = newWallet(store, 1)
		store.beforeCommit = function(k: string)
			if k ~= KEY then
				return
			end
			store.beforeCommit = nil
			w1.view().cash = 0
		end
		t.eq(reg.buy(w1, 1, KEY, PRICE), "cash", "refused at the charge")
		t.eq(store.data[KEY].status, "free", "claim let go")
		t.eq(w1.view().cash, 0, "nothing charged")
	end

	do -- Two servers buy the same plate at once
		local store, _, registry = world()
		local reg1, reg2 = registry(), registry()
		local w1, w2 = newWallet(store, 1), newWallet(store, 2)
		local second: string? = nil
		store.beforeCommit = function(k: string)
			if k ~= KEY then
				return
			end
			store.beforeCommit = nil
			second = reg2.buy(w2, 2, KEY, PRICE)
		end
		t.eq(reg1.buy(w1, 1, KEY, PRICE), "taken", "race: the later buyer is told it is taken")
		t.eq(second, "done", "race: the earlier buyer gets it")
		check(t, "race", store, { w1, w2 }, START - PRICE, START)
	end

	do -- A charge slower than the claim: someone else takes the plate, the first buyer is refunded
		local store, clock, registry = world()
		local reg1, reg2 = registry(), registry()
		local w1, w2 = newWallet(store, 1), newWallet(store, 2)
		store.beforeCommit = function(k: string)
			if k ~= "p_1" then
				return
			end
			store.beforeCommit = nil
			clock.now += PlateConfig.pendingSeconds + 1
			reg2.buy(w2, 2, KEY, PRICE)
		end
		t.eq(reg1.buy(w1, 1, KEY, PRICE), "taken", "slow charge: told it is taken")
		check(t, "slow charge", store, { w1, w2 }, START - PRICE, START)
	end

	do -- A late write from an old transaction never lands after the plate changed hands
		local store, _, registry = world()
		local reg = registry()
		local w1, w2 = newWallet(store, 1), newWallet(store, 2)
		reg.buy(w1, 1, KEY, PRICE) -- txn t1
		local oldVersion = store.data[KEY].version
		t.eq(reg.release(w1, 1, KEY, REFUND), "done", "released")
		t.eq(reg.buy(w2, 2, KEY, PRICE), "done", "bought by someone else")
		t.eq(reg.confirm(KEY, 1, "t1", PRICE), "lost", "the old confirm does not land")
		t.eq(reg.free(KEY, 2, oldVersion, "late"), "notmine", "an old version does not free it")
		t.eq(store.data[KEY].owner, 2, "still the new owner's")
		check(t, "changed hands", store, { w2 }, START - PRICE, START)
	end

	do -- The equipped plate is checked against its key: someone else's goes
		local store, _, registry = world()
		local reg = registry()
		local w1 = newWallet(store, 1)
		reg.buy(w1, 1, KEY, PRICE)
		store.data[KEY].owner = 2
		reg.checkEquipped(w1, 1)
		t.eq(w1.view().equipped, nil, "unequipped")
		t.eq(#w1.view().plates, 0, "and removed")
	end

	-- A failure at every store call of a purchase, then recovery. With
	-- `late`, someone else buys after the claim has run out, before the
	-- first buyer's session recovers.
	local probe, _, probeRegistry = world()
	local pw = newWallet(probe, 1)
	probe.ops = 0
	probeRegistry().buy(pw, 1, KEY, PRICE)
	local buySteps = probe.ops
	t.ok(buySteps >= 4, `a purchase is {buySteps} store calls`)
	for at = 1, buySteps do
		for _, mode in MODES do
			for _, late in { false, true } do
				local label = `buy, {mode} at call {at}{if late then ", then another buyer" else ""}`
				local store, clock, registry = world()
				local reg = registry()
				local w1, w2 = newWallet(store, 1), newWallet(store, 2)
				failAt(store, mode, at)
				reg.buy(w1, 1, KEY, PRICE)
				store.hook = nil
				if string.sub(mode, 1, 5) == "crash" then
					w1.reload()
					reg = registry()
				end
				if late then
					clock.now += PlateConfig.pendingSeconds + 1
					registry().buy(w2, 2, KEY, PRICE)
				end
				reg.recover(w1, 1)
				check(t, label, store, { w1, w2 }, START - PRICE, START)
				-- What was written must settle the same way.
				w1.reload()
				registry().recover(w1, 1)
				check(t, label .. " (reloaded)", store, { w1, w2 }, START - PRICE, START)
			end
		end
	end

	-- A failure at every store call of a release, then recovery.
	local function ownedWorld(): (any, () -> any, TestWallet)
		local store, _, registry = world()
		local w1 = newWallet(store, 1)
		registry().buy(w1, 1, KEY, PRICE)
		return store, registry, w1
	end
	local rs, rreg, rw = ownedWorld()
	rs.ops = 0
	t.eq(rreg().release(rw, 1, KEY, REFUND), "done", "clean release")
	local releaseSteps = rs.ops
	check(t, "clean release", rs, { rw }, START - PRICE, START - PRICE + REFUND)
	t.eq(rs.data[KEY].status, "free", "released plate is free")
	for at = 1, releaseSteps do
		for _, mode in MODES do
			local label = `release, {mode} at call {at}`
			local store, registry, w1 = ownedWorld()
			local reg = registry()
			failAt(store, mode, at)
			reg.release(w1, 1, KEY, REFUND)
			store.hook = nil
			if string.sub(mode, 1, 5) == "crash" then
				w1.reload()
				reg = registry()
			end
			reg.recover(w1, 1)
			check(t, label, store, { w1 }, START - PRICE, START - PRICE + REFUND)
			w1.reload()
			registry().recover(w1, 1)
			check(t, label .. " (reloaded)", store, { w1 }, START - PRICE, START - PRICE + REFUND)
		end
	end
```

- [ ] **Step 2: Run the specs and see them fail**

Expected: many `PlateRegistry.spec` failures, starting with `clean purchase expected done got unavailable`.

- [ ] **Step 3: Write the flows**

In `src/server/PlateRegistry.luau`, add these helpers just above `function PlateRegistry.new`:

```lua
local function findPlate(p: PlateProfile, key: string): OwnedPlate?
	for _, plate in p.plates do
		if plate.key == key then
			return plate
		end
	end
	return nil
end

local function dropPlate(p: PlateProfile, key: string)
	for i = #p.plates, 1, -1 do
		if p.plates[i].key == key then
			table.remove(p.plates, i)
		end
	end
	if p.equipped == key then
		p.equipped = nil
	end
end

-- Takes a transaction off the profile. False if it was not there: it is
-- already finished, so nothing more is done and nothing is paid twice.
local function dropTxn(p: PlateProfile, txn: string): boolean
	for i, t in p.pendingTxns do
		if t.txn == txn then
			table.remove(p.pendingTxns, i)
			return true
		end
	end
	return false
end
```

Replace the line `-- FLOWS (Task 4)` and the whole `return { ... } :: any` block after it with:

```lua
	-- The profile side of a finished purchase: the plate is owned and fitted.
	local function finishBuy(wallet: Wallet, t: PendingTxn): boolean
		return wallet.transact(function(p)
			if not dropTxn(p, t.txn) then
				return false
			end
			local plate = findPlate(p, t.key)
			if plate then
				plate.state = "owned"
			else
				table.insert(p.plates, { key = t.key, state = "owned" })
			end
			p.equipped = t.key
			return true
		end) ~= "error"
	end

	-- The profile side of a refunded purchase or a finished release: the
	-- plate goes and t.price (the price, or the release's refund) comes
	-- back, in the same write that takes the transaction off.
	local function dropAndCredit(wallet: Wallet, t: PendingTxn): boolean
		return wallet.transact(function(p)
			if not dropTxn(p, t.txn) then
				return false
			end
			dropPlate(p, t.key)
			p.cash += t.price
			return true
		end) ~= "error"
	end

	-- Brings one transaction to its end from what the plate key says now
	-- (the recovery table, spec §4):
	--   buying,    key pending with this txn  -> confirm, then finish
	--   buying,    key owned by me, this txn   -> finish
	--   buying,    anything else               -> refund
	--   releasing, key owned by me             -> free it, then finish
	--   releasing, free or not mine            -> finish
	-- "pending" means the store could not be reached; try again later.
	local function settle(wallet: Wallet, userId: number, t: PendingTxn, depth: number?): "done" | "refunded" | "pending"
		local d = depth or 0
		if d > 3 then
			return "pending"
		end
		local rec, ok = read(t.key)
		if not ok then
			return "pending"
		end
		if t.kind == "buy" then
			if rec.status == "pending" and rec.txn == t.txn then
				local c = confirm(t.key, userId, t.txn, t.price)
				if c == "error" then
					return "pending"
				elseif c == "lost" then
					return settle(wallet, userId, t, d + 1)
				end
				return if finishBuy(wallet, t) then "done" else "pending"
			elseif rec.status == "owned" and rec.owner == userId and rec.txn == t.txn then
				return if finishBuy(wallet, t) then "done" else "pending"
			end
			return if dropAndCredit(wallet, t) then "refunded" else "pending"
		end
		if rec.status == "owned" and rec.owner == userId then
			local f = free(t.key, userId, rec.version, t.txn)
			if f == "error" then
				return "pending"
			elseif f == "notmine" then
				return settle(wallet, userId, t, d + 1)
			end
		end
		return if dropAndCredit(wallet, t) then "done" else "pending"
	end

	-- Every unfinished transaction on the profile, brought to its end.
	local function recover(wallet: Wallet, userId: number)
		for _, t in table.clone(wallet.view().pendingTxns) do
			settle(wallet, userId, t)
		end
	end

	-- Reserve, charge, confirm (spec §4, buying).
	local function buy(wallet: Wallet, userId: number, key: string, price: number): BuyResult
		recover(wallet, userId)
		local p = wallet.view()
		if #p.pendingTxns > 0 then
			return "pending"
		end
		if findPlate(p, key) then
			return "owned"
		end
		if p.cash < price then
			return "cash"
		end
		local txn = newTxn()
		local r = reserve(key, userId, txn)
		if r == "taken" then
			return "taken"
		elseif r == "error" then
			cancel(key, txn) -- the claim may have landed
			return "unavailable"
		end
		local t: PendingTxn = { txn = txn, kind = "buy", key = key, price = price }
		local charged = wallet.transact(function(q)
			if q.cash < price then
				return false
			end
			q.cash -= price
			table.insert(q.pendingTxns, table.clone(t))
			table.insert(q.plates, { key = key, state = "pending" })
			return true
		end)
		if charged ~= "ok" then
			-- Nothing is charged in this session. If the write landed
			-- anyway, the next load finds the key free and refunds.
			cancel(key, txn)
			return if charged == "refused" then "cash" else "unavailable"
		end
		local s = settle(wallet, userId, t)
		return if s == "done" then "done" elseif s == "refunded" then "taken" else "pending"
	end

	-- Mark, free, credit (spec §4, releasing). Built and tested now; no
	-- button sells or trades a plate yet.
	local function release(wallet: Wallet, userId: number, key: string, refund: number): ReleaseResult
		recover(wallet, userId)
		local p = wallet.view()
		if #p.pendingTxns > 0 then
			return "pending"
		end
		local plate = findPlate(p, key)
		if not plate or plate.state ~= "owned" then
			return "notowned"
		end
		local t: PendingTxn = { txn = newTxn(), kind = "release", key = key, price = refund }
		local marked = wallet.transact(function(q)
			local mine = findPlate(q, key)
			if not mine or mine.state ~= "owned" then
				return false
			end
			mine.state = "releasing"
			if q.equipped == key then
				q.equipped = nil
			end
			table.insert(q.pendingTxns, table.clone(t))
			return true
		end)
		if marked == "refused" then
			return "notowned"
		elseif marked == "error" then
			return "unavailable"
		end
		return if settle(wallet, userId, t) == "done" then "done" else "pending"
	end

	-- The equipped plate against its key (at join and on equip, spec §4):
	-- if the key says it is not this player's, it leaves the profile.
	local function checkEquipped(wallet: Wallet, userId: number)
		local key = wallet.view().equipped
		if not key then
			return
		end
		local plate = findPlate(wallet.view(), key)
		if plate and plate.state ~= "owned" then
			return -- mid-transaction: settle deals with it
		end
		if plate then
			local rec, ok = read(key)
			if not ok or (rec.status == "owned" and rec.owner == userId) then
				return
			end
		end
		wallet.transact(function(q)
			if q.equipped ~= key then
				return false
			end
			dropPlate(q, key)
			return true
		end)
	end

	return {
		read = read,
		available = available,
		reserve = reserve,
		confirm = confirm,
		cancel = cancel,
		free = free,
		buy = buy,
		release = release,
		recover = recover,
		checkEquipped = checkEquipped,
	}
```

- [ ] **Step 4: Run the specs and see them pass**

Expected: no `PlateRegistry.spec` lines. Also note the printed pass count, which should be several hundred higher than before (the sweeps).

If a sweep case fails, read its label, for example `buy, crash-after at call 2 (reloaded)`. Reproduce that one case alone before changing anything (superpowers:systematic-debugging). Never loosen `check`.

- [ ] **Step 5: Type check**

Run `bash scripts/analyze.sh 2>&1 | grep -E "PlateRegistry"`. Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add src/server/PlateRegistry.luau src/shared/Tests/PlateRegistry.spec.luau
git commit -m "Plates: buy, release and recovery, safe at every failure point" -m "A purchase or release carries its txn into the profile; settle finishes it from what the key says. Tested with a failure at every store call (before and after the write lands, once and as a crash), two servers racing, and claims running out." -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PWSgvAKV3x1En9iuoQun7D"
```

---

### Task 5: Economy: plate fields, transact, wallet

**Files:**
- Modify: `src/server/Economy.luau` (full replacement below)

**Interfaces:**
- Consumes:
  - `Stores.open`, `Stores.Kind` (Task 3).
  - `PlateRegistry.OwnedPlate`, `PendingTxn`, `Wallet`, `PlateProfile`, `Outcome` (Task 3).
  - `PlateConfig.studioCash` (Task 2).
- Produces:
  - `Economy.Profile` gains `plates`, `equipped` and `pendingTxns`.
  - `Economy.transact(player, mutate): Outcome`
  - `Economy.wallet(player): PlateRegistry.Wallet`
  - `Economy.setEquipped(player, key: string?): boolean`
  - `Economy.onLoaded: ((player, savable: boolean) -> ())?`
  - Player attributes: `Plates` (owned keys, comma-joined) and `PlateEquipped`.
  - Unchanged: `load`, `save`, `release`, `profile`, `award`, `recordScore`, `step`, `start`.

- [ ] **Step 1: Replace Economy.luau**

Write `src/server/Economy.luau`:

```lua
--!strict
-- Cash, the all-time best and number plates, persisted per player.
--
-- Everything the client can see is an attribute on the Player (Cash,
-- SessionBest, BestScore, Plates, PlateEquipped): attributes replicate
-- server to client on their own, and a client writing one locally changes
-- nothing on the server. No remote carries a balance, so there is nothing
-- to forge.
--
-- Data safety rules, in order of how much they matter:
--   1. A profile whose load failed is never saved. Overwriting a real
--      balance with a fresh zero is the one unrecoverable mistake here.
--   2. Writes go through UpdateAsync, so the all-time best merges with
--      whatever is already stored rather than clobbering it.
--   3. One write per player at a time: a save holding an older copy must
--      never land after a plate transaction's write.
--   4. Autosave on a timer, save on leave, and save everyone on shutdown.
--
-- Plates (docs/superpowers/specs/2026-09-26-number-plates-design.md §4, §5):
-- the profile holds a copy of the plates a player owns, the one equipped,
-- and any plate transaction not yet finished (pendingTxns). The plate's own
-- key (PlateRegistry) is the truth. Money that moves with a plate moves in
-- one write with the transaction's record (transact), so it is charged once
-- and refunded at most once.
--
-- Not implemented: cross-server session locking. Roblox keeps a player in
-- one server at a time, so the exposure is a rejoin racing the old server's
-- save. Rule 2 keeps the best score safe through that; cash could lose the
-- last few seconds. Plates are safe: the key is the truth and recovery
-- re-reads it. Worth revisiting when teleports arrive (Phase 2).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlateConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlateConfig"))
local PlateRegistry = require(script.Parent.PlateRegistry)
local Stores = require(script.Parent.Stores)

local STORE_NAME = "HajwalaPlayer_v1"
local KEY_PREFIX = "p_"
local LOAD_ATTEMPTS = 4

export type Profile = {
	cash: number,
	bestScore: number,
	plates: { PlateRegistry.OwnedPlate },
	equipped: string?,
	pendingTxns: { PlateRegistry.PendingTxn },
}

local Economy = {}

-- Called when a player's profile load has finished. savable is false when
-- it failed or there is no store: nothing will be saved this session.
Economy.onLoaded = nil :: ((player: Player, savable: boolean) -> ())?

local store: any = nil
local storeKind: Stores.Kind = "none"
local profiles: { [Player]: Profile } = {}
local savable: { [Player]: boolean } = {}
local writing: { [Player]: boolean } = {}
local autosaveTimer = 0

local function key(player: Player): string
	return KEY_PREFIX .. player.UserId
end

local function fresh(): Profile
	return { cash = 0, bestScore = 0, plates = {}, equipped = nil, pendingTxns = {} }
end

local function publish(player: Player)
	local p = profiles[player]
	if not p or not player.Parent then
		return
	end
	player:SetAttribute("Cash", p.cash)
	player:SetAttribute("BestScore", p.bestScore)
	local owned: { string } = {}
	for _, plate in p.plates do
		if plate.state == "owned" then
			table.insert(owned, plate.key)
		end
	end
	player:SetAttribute("Plates", table.concat(owned, ","))
	player:SetAttribute("PlateEquipped", p.equipped)
end

-- A stored profile read defensively. The plate fields are new (2026-09-26):
-- an older profile has none and reads them as empty, so nothing migrates.
local function readProfile(raw: any): Profile
	local p = fresh()
	if type(raw) ~= "table" then
		return p
	end
	p.cash = math.max(tonumber(raw.cash) or 0, 0)
	p.bestScore = math.max(tonumber(raw.bestScore) or 0, 0)
	if type(raw.plates) == "table" then
		for _, e in raw.plates do
			if type(e) == "table" and type(e.key) == "string" and (e.state == "pending" or e.state == "owned" or e.state == "releasing") then
				table.insert(p.plates, { key = e.key, state = e.state })
			end
		end
	end
	if type(raw.equipped) == "string" then
		p.equipped = raw.equipped
	end
	if type(raw.pendingTxns) == "table" then
		for _, t in raw.pendingTxns do
			local price = type(t) == "table" and tonumber(t.price)
			if price and type(t.txn) == "string" and type(t.key) == "string" and (t.kind == "buy" or t.kind == "release") then
				table.insert(p.pendingTxns, { txn = t.txn, kind = t.kind, key = t.key, price = price })
			end
		end
	end
	return p
end

local function copyProfile(p: Profile): Profile
	local out = fresh()
	out.cash = p.cash
	out.bestScore = p.bestScore
	out.equipped = p.equipped
	for _, plate in p.plates do
		table.insert(out.plates, table.clone(plate))
	end
	for _, t in p.pendingTxns do
		table.insert(out.pendingTxns, table.clone(t))
	end
	return out
end

-- What is written: this session's profile, with the all-time best merged
-- rather than overwritten (another session may have set a higher best).
local function encode(p: Profile, old: any): any
	local out = copyProfile(p)
	out.bestScore = math.max(p.bestScore, readProfile(old).bestScore)
	return out
end

local function lock(player: Player)
	while writing[player] do
		task.wait()
	end
	writing[player] = true
end

local function unlock(player: Player)
	writing[player] = nil
end

local function loaded(player: Player, ok: boolean)
	local cb = Economy.onLoaded
	if cb and player.Parent then
		task.spawn(cb, player, ok)
	end
end

function Economy.load(player: Player)
	if profiles[player] then
		return
	end
	-- Start the session at zero so the HUD has numbers immediately; the
	-- stored values replace them when the read lands.
	profiles[player] = fresh()
	savable[player] = false
	player:SetAttribute("SessionBest", 0)
	publish(player)

	local s = store
	if not s then
		loaded(player, false)
		return
	end
	local ok, result
	for attempt = 1, LOAD_ATTEMPTS do
		ok, result = pcall(function()
			return s:GetAsync(key(player))
		end)
		if ok then
			break
		end
		task.wait(attempt)
		if not player.Parent then
			return
		end
	end
	if not player.Parent then
		return
	end
	if not ok then
		warn(`[Hajwala] profile load failed for {player.Name}, playing without saving: {tostring(result)}`)
		loaded(player, false)
		return
	end
	local p = readProfile(result)
	if storeKind == "fake" and result == nil then
		p.cash = PlateConfig.studioCash
	end
	profiles[player] = p
	savable[player] = true
	publish(player)
	loaded(player, true)
end

function Economy.save(player: Player)
	local s = store
	if not s or not profiles[player] or not savable[player] then
		return
	end
	lock(player)
	local p = profiles[player]
	if p then
		local ok, err = pcall(function()
			s:UpdateAsync(key(player), function(old: any)
				return encode(p, old)
			end)
		end)
		if not ok then
			warn(`[Hajwala] profile save failed for {player.Name}: {tostring(err)}`)
		end
	end
	unlock(player)
end

-- Changes the profile in one durable write (PlateRegistry.Wallet): mutate
-- gets a copy and returns false to change nothing ("refused"). On "ok" the
-- copy has been written and the same change made to the live profile. It is
-- made again rather than the copy kept, because cash earned while the write
-- was in flight is on the live profile. On "error" the live profile is
-- unchanged.
function Economy.transact(player: Player, mutate: (p: Profile) -> boolean): PlateRegistry.Outcome
	local s = store
	if not s or not profiles[player] or not savable[player] then
		return "error"
	end
	lock(player)
	local live = profiles[player]
	if not live then
		unlock(player)
		return "error"
	end
	local draft = copyProfile(live)
	if not mutate(draft) then
		unlock(player)
		return "refused"
	end
	local ok, err = pcall(function()
		s:UpdateAsync(key(player), function(old: any)
			return encode(draft, old)
		end)
	end)
	unlock(player)
	if not ok then
		warn(`[Hajwala] profile write failed for {player.Name}: {tostring(err)}`)
		return "error"
	end
	mutate(live)
	publish(player)
	return "ok"
end

-- The profile side of the plate flows, for PlateRegistry.
function Economy.wallet(player: Player): PlateRegistry.Wallet
	return {
		view = function(): PlateRegistry.PlateProfile
			return (profiles[player] or fresh()) :: any
		end,
		transact = function(mutate: (p: PlateRegistry.PlateProfile) -> boolean): PlateRegistry.Outcome
			return Economy.transact(player, mutate :: any)
		end,
	}
end

-- Equips a plate the player owns, or nil for the session's default plate.
-- Kept in memory; the next save writes it. False if not owned.
function Economy.setEquipped(player: Player, plateKey: string?): boolean
	local p = profiles[player]
	if not p then
		return false
	end
	if plateKey then
		local owned = false
		for _, plate in p.plates do
			if plate.key == plateKey and plate.state == "owned" then
				owned = true
			end
		end
		if not owned then
			return false
		end
	end
	p.equipped = plateKey
	publish(player)
	return true
end

function Economy.release(player: Player)
	Economy.save(player)
	profiles[player] = nil
	savable[player] = nil
	writing[player] = nil
end

function Economy.profile(player: Player): Profile?
	return profiles[player]
end

-- Returns the new balance. Amounts are always computed on the server.
function Economy.award(player: Player, cash: number): number
	local p = profiles[player]
	if not p or cash <= 0 then
		return if p then p.cash else 0
	end
	p.cash += math.floor(cash)
	publish(player)
	return p.cash
end

-- Returns true when this is a new personal best.
function Economy.recordScore(player: Player, points: number): boolean
	local p = profiles[player]
	if not p then
		return false
	end
	local sessionBest = (tonumber(player:GetAttribute("SessionBest")) or 0)
	if points > sessionBest then
		player:SetAttribute("SessionBest", points)
	end
	if points <= p.bestScore then
		return false
	end
	p.bestScore = points
	publish(player)
	return true
end

function Economy.step(dt: number, autosaveSeconds: number)
	autosaveTimer += dt
	if autosaveTimer < autosaveSeconds then
		return
	end
	autosaveTimer = 0
	for _, player in Players:GetPlayers() do
		if savable[player] then
			task.spawn(Economy.save, player)
		end
	end
end

function Economy.start()
	store, storeKind = Stores.open(STORE_NAME)
	if storeKind == "none" then
		warn("[Hajwala] no DataStore, cash will not persist")
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(Economy.load, player)
	end)
	Players.PlayerRemoving:Connect(Economy.release)
	for _, player in Players:GetPlayers() do
		task.spawn(Economy.load, player)
	end

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				Economy.save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 20
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return Economy
```

- [ ] **Step 2: Type check**

Run `bash scripts/analyze.sh 2>&1 | grep -E "Economy|ScoreService"`. Expected: no output. Economy's public functions used by ScoreService (`award`, `recordScore`, `step`, `start`) keep their signatures.

- [ ] **Step 3: Check it in Play**

1. Stop and start Play.
2. In the Server datamodel, run with MCP `execute_luau`:

```lua
local Economy = require(game.ServerScriptService.Server.Economy)
local player = game.Players:GetPlayers()[1]
local p = Economy.profile(player)
return string.format("cash %s plates %d pending %d attr Plates=%q", tostring(p and p.cash), p and #p.plates or -1, p and #p.pendingTxns or -1, tostring(player:GetAttribute("Plates")))
```

(From the MCP context `require` may return a separate module instance. If `profile` is nil, read the attributes on the player instead: `Cash`, `Plates`.)

Expected:
- **Studio without DataStore access:** the console shows the `in-memory fake` warning for `HajwalaPlayer_v1`, `Cash` = 2000000 and `Plates` = "".
- **Studio with access:** `Cash` equals the stored balance.

Also check that the HUD cash shows and a slide still banks cash. Drive one slide with the harness (CLAUDE.md, Driving harness).

- [ ] **Step 4: Commit**

```bash
git add src/server/Economy.luau
git commit -m "Economy: plate fields on the profile, one write at a time, transact" -m "The profile gains plates, equipped and pendingTxns (new fields only, no migration). transact writes a change durably before making it live, so a plate charge and its record land together. Studio without DataStore access uses the fake store with studioCash." -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PWSgvAKV3x1En9iuoQun7D"
```

---

### Task 6: Remotes and PlateService

**Files:**
- Modify: `src/server/Remotes.luau`
- Create: `src/server/PlateService.luau`
- Modify: `src/server/init.server.luau`

**Interfaces:**
- Consumes:
  - `Economy.wallet`, `setEquipped`, `profile`, `onLoaded` (Task 5).
  - `PlateRegistry.new`, `Registry` (Tasks 3–4).
  - `Stores.open` (Task 3).
  - `PlateText.normalise`, `price`, `random` (Task 2).
- Produces:
  - `remotes.PlateQuery: RemoteFunction`. Its reply is `{ status = "ok"|"invalid"|"unavailable"|"busy", key?, price?, available?, reason? }`.
  - `remotes.PlateAction: RemoteFunction`, called with `(what: "buy"|"equip"|"unequip", text: string)`. Its reply is `{ status = "done"|"taken"|"cash"|"unavailable"|"owned"|"pending"|"notowned"|"invalid"|"busy", key?, price?, reason? }`.
  - The Player attribute `PlateDefault`.
  - The car Model attribute `Plate`, set on every car in `workspace.Cars` from its `OwnerUserId`.

- [ ] **Step 1: Add the RemoteFunctions**

In `src/server/Remotes.luau`, add to `RemoteTable` after `Horn`:

```lua
	PlateQuery: RemoteFunction, -- client -> server (typed plate text) -> { status, key, price, available, reason } (PlateService)
	PlateAction: RemoteFunction, -- client -> server ("buy" | "equip" | "unequip", plate text) -> { status, reason } (PlateService)
```

After the `ev` function, add:

```lua
	local function fn(name: string): RemoteFunction
		local f = Instance.new("RemoteFunction")
		f.Name = name
		f.Parent = folder
		return f
	end
```

In the table `t`, after `Horn = ev("Horn"),`, add:

```lua
		PlateQuery = fn("PlateQuery"),
		PlateAction = fn("PlateAction"),
```

- [ ] **Step 2: Write PlateService**

Create `src/server/PlateService.luau`:

```lua
--!strict
-- Number plates for players (docs/superpowers/specs/2026-09-26-number-plates-design.md §4, §5).
--
-- Remotes: PlateQuery (is this plate valid, what does it cost, is it free)
-- and PlateAction (buy, equip, unequip). Both are rate-limited and always
-- normalise the player's text again (PlateText); nothing the client says
-- about a plate is trusted.
--
-- Each car carries the plate to draw as the Model attribute "Plate"
-- (CarPlates draws it on every client): its owner's equipped plate, or a
-- random default plate for the session. Player attributes: Plates and
-- PlateEquipped (Economy), PlateDefault (here).
--
-- One plate transaction per player at a time. Any left unfinished (the
-- store was down) is retried every retrySeconds and at the next join.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlateText = require(Shared:WaitForChild("PlateText"))
local PlateConfig = require(Shared:WaitForChild("PlateConfig"))
local Economy = require(script.Parent.Economy)
local PlateRegistry = require(script.Parent.PlateRegistry)
local Stores = require(script.Parent.Stores)
local Remotes = require(script.Parent.Remotes)

local STORE_NAME = "HajwalaPlates_v1"

type Reply = { status: string, key: string?, price: number?, available: boolean?, reason: string? }

local PlateService = {}

local registry: PlateRegistry.Registry? = nil
local busy: { [Player]: boolean } = {}
local budgets: { [string]: { [Player]: { at: number, n: number } } } = { query = {}, action = {} }

local function allowed(kind: string, player: Player, perSecond: number): boolean
	local b = budgets[kind]
	local now = os.clock()
	local cur = b[player]
	if not cur or now - cur.at >= 1 then
		b[player] = { at = now, n = 1 }
		return true
	end
	cur.n += 1
	return cur.n <= perSecond
end

local function plateFor(player: Player): string?
	local equipped = player:GetAttribute("PlateEquipped")
	if type(equipped) == "string" then
		return equipped
	end
	local default = player:GetAttribute("PlateDefault")
	return if type(default) == "string" then default else nil
end

local function carOf(player: Player): Model?
	local cars = Workspace:FindFirstChild("Cars")
	if not cars then
		return nil
	end
	for _, m in cars:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("OwnerUserId") == player.UserId then
			return m
		end
	end
	return nil
end

local function refreshCar(player: Player)
	local car = carOf(player)
	if car then
		car:SetAttribute("Plate", plateFor(player))
	end
end

-- Runs fn as this player's only plate transaction. False if one is running.
local function exclusive(player: Player, fn: () -> ()): boolean
	if busy[player] then
		return false
	end
	busy[player] = true
	local ok, err = pcall(fn)
	busy[player] = nil
	if not ok then
		warn(`[Plates] {player.Name}: {tostring(err)}`)
	end
	return true
end

-- A default plate nobody owns (spec §5). Never registered.
local function pickDefault(): string
	local rng = Random.new()
	local key = PlateText.random(rng)
	local reg = registry
	if not reg then
		return key
	end
	for _ = 1, PlateConfig.defaultPicks do
		if reg.available(key) ~= false then
			return key
		end
		key = PlateText.random(rng)
	end
	return key
end

local function query(player: Player, input: any): Reply
	if not allowed("query", player, PlateConfig.queriesPerSecond) then
		return { status = "busy" }
	end
	if type(input) ~= "string" then
		return { status = "invalid", reason = "Type a plate" }
	end
	local key, reason = PlateText.normalise("SA", input)
	if not key then
		return { status = "invalid", reason = reason }
	end
	local price = PlateText.price(key)
	local reg = registry
	local free = if reg then reg.available(key) else nil
	if free == nil then
		return { status = "unavailable", key = key, price = price }
	end
	return { status = "ok", key = key, price = price, available = free }
end

local function action(player: Player, what: any, input: any): Reply
	if not allowed("action", player, PlateConfig.actionsPerSecond) then
		return { status = "busy" }
	end
	if what == "unequip" then
		Economy.setEquipped(player, nil)
		return { status = "done" }
	end
	if what ~= "buy" and what ~= "equip" then
		return { status = "invalid", reason = "Unknown action" }
	end
	if type(input) ~= "string" then
		return { status = "invalid", reason = "Type a plate" }
	end
	local key, reason = PlateText.normalise("SA", input)
	if not key then
		return { status = "invalid", reason = reason }
	end
	local reg = registry
	if not reg then
		return { status = "unavailable" }
	end
	local reply: Reply = { status = "busy" }
	exclusive(player, function()
		local wallet = Economy.wallet(player)
		if what == "equip" then
			if not Economy.setEquipped(player, key) then
				reply = { status = "notowned", key = key }
				return
			end
			reg.checkEquipped(wallet, player.UserId)
			local kept = player:GetAttribute("PlateEquipped") == key
			reply = { status = if kept then "done" else "taken", key = key }
		else
			local price = PlateText.price(key) :: number
			reply = { status = reg.buy(wallet, player.UserId, key, price), key = key, price = price }
		end
	end)
	return reply
end

local function onLoaded(player: Player, canSave: boolean)
	player:SetAttribute("PlateDefault", pickDefault())
	refreshCar(player)
	local reg = registry
	if reg and canSave then
		exclusive(player, function()
			local wallet = Economy.wallet(player)
			reg.recover(wallet, player.UserId)
			reg.checkEquipped(wallet, player.UserId)
		end)
	end
end

function PlateService.start(remotes: Remotes.RemoteTable)
	local store = Stores.open(STORE_NAME)
	if store then
		registry = PlateRegistry.new(store, { clock = os.time })
	end
	-- Set before Economy starts, so no profile load is missed.
	Economy.onLoaded = onLoaded

	remotes.PlateQuery.OnServerInvoke = function(player: Player, input: any): any
		local ok, reply = pcall(query, player, input)
		return if ok then reply else { status = "unavailable" }
	end
	remotes.PlateAction.OnServerInvoke = function(player: Player, what: any, input: any): any
		local ok, reply = pcall(action, player, what, input)
		return if ok then reply else { status = "unavailable" }
	end

	local function watch(player: Player)
		player:GetAttributeChangedSignal("PlateEquipped"):Connect(function()
			refreshCar(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		budgets.query[player] = nil
		budgets.action[player] = nil
	end)

	-- A new car takes its owner's plate (CarSpawner sets OwnerUserId before
	-- parenting it).
	task.spawn(function()
		local cars = Workspace:WaitForChild("Cars", math.huge)
		cars.ChildAdded:Connect(function(child)
			local uid = child:GetAttribute("OwnerUserId")
			local owner = if type(uid) == "number" then Players:GetPlayerByUserId(uid) else nil
			if owner and child:IsA("Model") then
				child:SetAttribute("Plate", plateFor(owner))
			end
		end)
	end)

	-- Unfinished transactions, retried.
	task.spawn(function()
		while true do
			task.wait(PlateConfig.retrySeconds)
			local reg = registry
			if not reg then
				continue
			end
			for _, player in Players:GetPlayers() do
				local p = Economy.profile(player)
				if p and #p.pendingTxns > 0 then
					task.spawn(exclusive, player, function()
						reg.recover(Economy.wallet(player), player.UserId)
					end)
				end
			end
		end
	end)
end

return PlateService
```

- [ ] **Step 3: Start it**

In `src/server/init.server.luau`, add after `local CarControls = require(script.CarControls)`:

```lua
local PlateService = require(script.PlateService)
```

and replace:

```lua
ScoreService.start(config, remotes)
```

with:

```lua
-- Before ScoreService.start, which starts Economy: plates hook its profile loads.
PlateService.start(remotes)
ScoreService.start(config, remotes)
```

- [ ] **Step 4: Type check**

Run `bash scripts/analyze.sh 2>&1 | grep -E "PlateService|Remotes|init.server"`. Expected: no new output. `init.server.luau` has no known baseline.

- [ ] **Step 5: Check end to end in Play**

1. Stop and start Play, and spawn any car (M menu).
2. In the Client datamodel, run:

```lua
local R = game.ReplicatedStorage.Remotes
local lp = game.Players.LocalPlayer
local out = {}
local function show(label, r)
	local parts = {}
	for k, v in r do table.insert(parts, k .. "=" .. tostring(v)) end
	table.sort(parts)
	table.insert(out, label .. ": " .. table.concat(parts, " "))
end
table.insert(out, "default " .. tostring(lp:GetAttribute("PlateDefault")) .. ", cash " .. tostring(lp:GetAttribute("Cash")))
show("query ABJ 7", R.PlateQuery:InvokeServer("ABJ 7"))
show("query arabic", R.PlateQuery:InvokeServer("حبأ ٤٥٦٧"))
show("query bad", R.PlateQuery:InvokeServer("ABC 7"))
task.wait(1.1)
show("buy", R.PlateAction:InvokeServer("buy", "حبأ ٤٥٦٧"))
task.wait(1.1)
local car = workspace.Cars:FindFirstChild("Car_" .. lp.Name)
table.insert(out, "after: cash " .. tostring(lp:GetAttribute("Cash")) .. ", Plates " .. tostring(lp:GetAttribute("Plates")) .. ", equipped " .. tostring(lp:GetAttribute("PlateEquipped")) .. ", car Plate " .. tostring(car and car:GetAttribute("Plate")))
show("buy again", R.PlateAction:InvokeServer("buy", "ABJ4567"))
task.wait(1.1)
show("unequip", R.PlateAction:InvokeServer("unequip", ""))
table.insert(out, "car Plate now " .. tostring(car and car:GetAttribute("Plate")))
return table.concat(out, "\n")
```

Expected:
- A default like `SA:XTE-4821`.
- `query ABJ 7` gives `status=ok available=true price=500000 key=SA:ABJ-7`.
- `query arabic` gives `key=SA:ABJ-4567 price=20000`.
- `query bad` gives `status=invalid` with a reason.
- `buy` gives `status=done`.
- After the buy, cash has dropped by 20,000, `Plates` is `SA:ABJ-4567`, and both equipped and the car's `Plate` are `SA:ABJ-4567`.
- `buy again` gives `status=owned`.
- After `unequip`, the car's `Plate` goes back to the default.

Record these as a before/after table for the owner.

- [ ] **Step 6: Commit**

```bash
git add src/server/Remotes.luau src/server/PlateService.luau src/server/init.server.luau
git commit -m "Plates: PlateService, PlateQuery and PlateAction remotes" -m "Rate-limited, one transaction per player, text normalised again on the server. Each car gets its owner's plate as the Plate attribute: the equipped one, or a random default for the session." -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PWSgvAKV3x1En9iuoQun7D"
```

---

### Task 7: PlateStyles: the Saudi plate's look

**Files:**
- Create: `src/shared/PlateStyles.luau`
- Test: `src/shared/Tests/PlateStyles.spec.luau`

**Interfaces:**
- Consumes: `PlateText.parts` (Task 2), and the Task 1 findings (sizes, strip, row layout, Arabic order, fonts).
- Produces:
  - `export type Format = "short" | "long"`
  - `PlateStyles.SIZE_M: { short: Vector2, long: Vector2 }` (metres)
  - `PlateStyles.PIXELS_PER_M: number`
  - `PlateStyles.layout(key: string, format: Format): Art?`, where `Art = { blocks: { Block }, cells: { Cell } }`
  - `Cell = { text, role, rect, font, color }`, where `role` is one of `"arabicLetter" | "arabicDigit" | "latinLetter" | "latinDigit" | "strip"` and `rect` is `{x,y,w,h}` in 0..1 of the plate from the top left.
  - `PlateStyles.draw(parent: Instance, key: string?, format: Format): Frame?` creates or replaces a child `PlateArt` and returns nil (drawing nothing) for no key or a bad key.

The values below already carry the Task 1 findings (spec "Checked" section): real sizes, a white strip (private plates), the strip on the right of the short plate and in the centre of the long one, and each Arabic letter drawn directly above its Latin letter (no mirroring). Tune the `LAYOUT` numbers against the reference images in `.superpowers/sdd/2026-09-26-number-plates/plate_ref_*.png` if the screenshot in Step 5 reads wrong.

- [ ] **Step 1: Write the failing test**

Create `src/shared/Tests/PlateStyles.spec.luau`:

```lua
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

	for _, format in { "short", "long" } :: { PlateStyles.Format } do
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
	t.ok(PlateStyles.SIZE_M.long.X / PlateStyles.SIZE_M.long.Y > PlateStyles.SIZE_M.short.X / PlateStyles.SIZE_M.short.Y, "long is the longer format")
end
```

- [ ] **Step 2: Run it and see it fail**

Expected: `PlateStyles.spec: error ... PlateStyles is not a valid member`.

- [ ] **Step 3: Write PlateStyles**

Create `src/shared/PlateStyles.luau`:

```lua
--!strict
-- How plates look (spec §2): frames and text labels, no images. Every
-- glyph is its own label, so Arabic letters are never joined and nothing
-- needs right-to-left shaping. layout() is the pure part (tested);
-- draw() turns it into instances inside any GUI container, a car's
-- SurfaceGui or the menu's preview alike.
--
-- Saudi private plate (checked in build Task 1, the spec's "Checked"
-- section): white, a digits block on the left and a letters block on the
-- right, each with Arabic above Latin. Each Arabic letter sits directly
-- above its Latin letter, so the Arabic row reads (right to left) in the
-- reverse order of the Latin. The KSA strip is a column on the right of
-- the short plate and between the two blocks on the long one.
local PlateText = require(script.Parent.PlateText)

export type Format = "short" | "long"
export type Rect = { x: number, y: number, w: number, h: number }
export type Role = "arabicLetter" | "arabicDigit" | "latinLetter" | "latinDigit" | "strip"
export type Cell = { text: string, role: Role, rect: Rect, font: Enum.Font, color: Color3 }
export type Block = { rect: Rect, color: Color3 }
export type Art = { blocks: { Block }, cells: { Cell } }

local PlateStyles = {}

-- Real plate sizes in metres (spec §2; build Task 1).
PlateStyles.SIZE_M = {
	short = Vector2.new(0.335, 0.155), -- the "US size", the one most used in Saudi Arabia
	long = Vector2.new(0.55, 0.11), -- the "EU size"
} :: { [Format]: Vector2 }

-- SurfaceGui canvas pixels per metre of plate: a long plate is 550 px wide.
PlateStyles.PIXELS_PER_M = 1000

local COLORS = {
	plate = Color3.fromRGB(246, 246, 242),
	ink = Color3.fromRGB(18, 18, 20),
	strip = Color3.fromRGB(246, 246, 242), -- white on private plates (yellow taxi, blue commercial)
	stripInk = Color3.fromRGB(18, 18, 20),
}
PlateStyles.COLORS = COLORS

-- Roblox draws Arabic in one fallback face whatever the font (build Task
-- 1), so only the Latin choice matters; GothamBold matches the HUD.
local FONTS = {
	latin = Enum.Font.GothamBold,
	arabic = Enum.Font.GothamBold,
}

type Layout = {
	strip: Rect,
	arabicDigits: Rect,
	arabicLetters: Rect,
	latinDigits: Rect,
	latinLetters: Rect,
	lines: { Rect }, -- the thin rules between the four fields
	border: number, -- border thickness, fraction of the plate's height
	arabicMirrored: boolean, -- arabic[1] drawn rightmost (false on Saudi plates: each Arabic letter above its Latin one)
}

local LAYOUT: { [Format]: Layout } = {
	-- Digits | letters | strip.
	short = {
		strip = { x = 0.85, y = 0, w = 0.15, h = 1 },
		arabicDigits = { x = 0.04, y = 0.07, w = 0.40, h = 0.40 },
		arabicLetters = { x = 0.47, y = 0.07, w = 0.36, h = 0.40 },
		latinDigits = { x = 0.04, y = 0.53, w = 0.40, h = 0.40 },
		latinLetters = { x = 0.47, y = 0.53, w = 0.36, h = 0.40 },
		lines = {
			{ x = 0.452, y = 0.06, w = 0.008, h = 0.88 },
			{ x = 0.846, y = 0, w = 0.008, h = 1 },
			{ x = 0.03, y = 0.495, w = 0.81, h = 0.01 },
		},
		border = 0.03,
		arabicMirrored = false,
	},
	-- Digits | strip | letters.
	long = {
		strip = { x = 0.43, y = 0, w = 0.14, h = 1 },
		arabicDigits = { x = 0.03, y = 0.08, w = 0.38, h = 0.39 },
		arabicLetters = { x = 0.59, y = 0.08, w = 0.38, h = 0.39 },
		latinDigits = { x = 0.03, y = 0.53, w = 0.38, h = 0.39 },
		latinLetters = { x = 0.59, y = 0.53, w = 0.38, h = 0.39 },
		lines = {
			{ x = 0.425, y = 0, w = 0.005, h = 1 },
			{ x = 0.57, y = 0, w = 0.005, h = 1 },
			{ x = 0.02, y = 0.495, w = 0.4, h = 0.01 },
			{ x = 0.58, y = 0.495, w = 0.4, h = 0.01 },
		},
		border = 0.035,
		arabicMirrored = false,
	},
}

-- Glyphs spread evenly across a rect, first on the left (or the right).
local function spread(out: { Cell }, glyphs: { string }, rect: Rect, role: Role, font: Enum.Font, color: Color3, rightToLeft: boolean)
	local n = #glyphs
	for i, g in glyphs do
		local slot = if rightToLeft then n - i else i - 1
		table.insert(out, {
			text = g,
			role = role,
			font = font,
			color = color,
			rect = { x = rect.x + slot * rect.w / n, y = rect.y, w = rect.w / n, h = rect.h },
		})
	end
end

-- The plate for a key as plain data; nil for anything not a valid key.
function PlateStyles.layout(key: string, format: Format): Art?
	local p = PlateText.parts(key)
	local l = LAYOUT[format]
	if not p or not l then
		return nil
	end
	local size = PlateStyles.SIZE_M[format]
	local bx = l.border * size.Y / size.X -- the same thickness on the sides
	local blocks: { Block } = {
		{ rect = l.strip, color = COLORS.strip },
		{ rect = { x = 0, y = 0, w = 1, h = l.border }, color = COLORS.ink },
		{ rect = { x = 0, y = 1 - l.border, w = 1, h = l.border }, color = COLORS.ink },
		{ rect = { x = 0, y = 0, w = bx, h = 1 }, color = COLORS.ink },
		{ rect = { x = 1 - bx, y = 0, w = bx, h = 1 }, color = COLORS.ink },
	}
	for _, line in l.lines do
		table.insert(blocks, { rect = line, color = COLORS.ink })
	end
	local cells: { Cell } = {}
	local latinDigits: { string } = {}
	for i = 1, #p.digits do
		table.insert(latinDigits, string.sub(p.digits, i, i))
	end
	spread(cells, p.arabicDigits, l.arabicDigits, "arabicDigit", FONTS.arabic, COLORS.ink, false)
	spread(cells, p.arabic, l.arabicLetters, "arabicLetter", FONTS.arabic, COLORS.ink, l.arabicMirrored)
	spread(cells, latinDigits, l.latinDigits, "latinDigit", FONTS.latin, COLORS.ink, false)
	spread(cells, p.latin, l.latinLetters, "latinLetter", FONTS.latin, COLORS.ink, false)
	-- The strip: the country in Arabic on top, K S A stacked below.
	local s = l.strip
	table.insert(cells, { text = "السعودية", role = "strip", font = FONTS.arabic, color = COLORS.stripInk, rect = { x = s.x + s.w * 0.1, y = 0.08, w = s.w * 0.8, h = 0.2 } })
	for i, ch in { "K", "S", "A" } do
		table.insert(cells, { text = ch, role = "strip", font = FONTS.latin, color = COLORS.stripInk, rect = { x = s.x + s.w * 0.2, y = 0.34 + (i - 1) * 0.2, w = s.w * 0.6, h = 0.18 } })
	end
	return { blocks = blocks, cells = cells }
end

local function place(o: GuiObject, r: Rect)
	o.Position = UDim2.fromScale(r.x, r.y)
	o.Size = UDim2.fromScale(r.w, r.h)
end

-- Draws a plate into a GUI container, replacing what was drawn before
-- (the child "PlateArt"). Draws nothing and returns nil for no key.
function PlateStyles.draw(parent: Instance, key: string?, format: Format): Frame?
	local old = parent:FindFirstChild("PlateArt")
	if old then
		old:Destroy()
	end
	local art = if key then PlateStyles.layout(key, format) else nil
	if not art then
		return nil
	end
	local size = PlateStyles.SIZE_M[format]
	local f = Instance.new("Frame")
	f.Name = "PlateArt"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = COLORS.plate
	f.BorderSizePixel = 0
	f.ClipsDescendants = true
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = size.X / size.Y
	aspect.Parent = f
	for _, b in art.blocks do
		local fill = Instance.new("Frame")
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = b.color
		place(fill, b.rect)
		fill.Parent = f
	end
	for _, c in art.cells do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Text = c.text
		l.Font = c.font
		l.TextColor3 = c.color
		l.TextScaled = true
		place(l, c.rect)
		l.Parent = f
	end
	f.Parent = parent
	return f
end

return PlateStyles
```

- [ ] **Step 4: Run the specs and see them pass**

Expected: no `PlateStyles.spec` lines.

- [ ] **Step 5: Look at it (Edit)**

Run with MCP `execute_luau` (Edit):

```lua
local PlateStyles = require(game.ReplicatedStorage.Shared:Clone().PlateStyles)
local sg = Instance.new("ScreenGui")
sg.Name = "PlatePreviewCheck"
sg.Parent = game:GetService("StarterGui")
for i, spec in { { "SA:ABJ-7", "short" }, { "SA:HUV-4567", "short" }, { "SA:ABJ-7", "long" }, { "SA:XTE-1234", "long" } } do
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromOffset(420, 150)
	box.Position = UDim2.fromOffset(40 + ((i - 1) % 2) * 460, 60 + math.floor((i - 1) / 2) * 180)
	box.Parent = sg
	PlateStyles.draw(box, spec[1], spec[2] :: any)
end
return "drawn"
```

Focus Studio and `screen_capture`, then destroy `StarterGui.PlatePreviewCheck`. Show the owner the screenshot next to the Task 1 reference photo. Adjust the `LAYOUT` numbers if anything reads wrong (spacing, strip text size), and re-run the spec after any change.

- [ ] **Step 6: Commit**

```bash
git add src/shared/PlateStyles.luau src/shared/Tests/PlateStyles.spec.luau
git commit -m "Plates: PlateStyles draws the Saudi plate from labels" -m "Short and long formats, the KSA strip, Arabic above Latin, one label per glyph. layout() is pure and tested; draw() works in a SurfaceGui or the menu." -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PWSgvAKV3x1En9iuoQun7D"
```

---

### Task 8: CarPlateMounts, CarPlates, and the three cars measured exactly

**Files:**
- Create: `src/shared/CarPlateMounts.luau`
- Test: `src/shared/Tests/CarPlateMounts.spec.luau`
- Create: `src/client/CarPlates.luau`
- Modify: `src/client/init.client.luau`
- Modify: `tools/carbody/storecar.py` (add `--spots`)

**Interfaces:**
- Consumes:
  - `PlateStyles.SIZE_M`, `PIXELS_PER_M`, `draw`, `Format` (Task 7).
  - `PlateConfig.standoffM`, `thicknessM`, `drawDistanceStuds`.
  - `VehicleRig.handles(model).chassis` / `.bodyMount`, `VehicleRig.scaleOf`, `VehicleRig.CAR_ID_ATTRIBUTE`, `ConfigLoader.entry`, `ConfigLoader.forCar(id).units.metersPerStud`.
  - The car attribute `Plate` (Task 6).
- Produces:
  - `export type Spot = { posM: { number }, format: PlateStyles.Format, tiltDeg: number? }` and `export type Mounts = { front: Spot?, rear: Spot? }`.
  - `CarPlateMounts.cars: { [string]: Mounts }`
  - `CarPlateMounts.cframe(spot: Spot, rear: boolean, k: number, mps: number): CFrame`
  - `CarPlates.start()` and `CarPlates.place(model: Model, mounts: Mounts)`.

- [ ] **Step 1: Write the failing test**

Create `src/shared/Tests/CarPlateMounts.spec.luau`:

```lua
--!strict
local CarPlateMounts = require(script.Parent.Parent.CarPlateMounts)
local PlateStyles = require(script.Parent.Parent.PlateStyles)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local function near(v: Vector3, w: Vector3, label: string)
		t.near((v - w).Magnitude, 0, 1e-6, label)
	end
	-- Front plates face forward (-Z), rear plates backward (+Z); a Part's
	-- Front face is its -Z, which is the LookVector.
	local spot: CarPlateMounts.Spot = { posM = { 0.1, 0.5, -2 }, format = "short" }
	local front = CarPlateMounts.cframe(spot, false, 1.2, 0.28)
	near(front.LookVector, Vector3.new(0, 0, -1), "front plate faces forward")
	near(front.Position, Vector3.new(0.1, 0.5, -2) * (1.2 / 0.28), "position is metres times scale over metres per stud")
	local rear = CarPlateMounts.cframe({ posM = { 0, 0.8, 2.5 }, format = "short" }, true, 1, 0.28)
	near(rear.LookVector, Vector3.new(0, 0, 1), "rear plate faces backward")
	-- tiltDeg leans the top in toward the car
	local tiltedRear = CarPlateMounts.cframe({ posM = { 0, 0.8, 2.5 }, format = "short", tiltDeg = 10 }, true, 1, 0.28)
	t.ok(tiltedRear.UpVector.Z < 0, "tilted rear plate's top leans forward, into the car")
	local tiltedFront = CarPlateMounts.cframe({ posM = { 0, 0.5, -2 }, format = "short", tiltDeg = 10 }, false, 1, 0.28)
	t.ok(tiltedFront.UpVector.Z > 0, "tilted front plate's top leans back, into the car")

	-- Every listed spot is sane
	for id, m in CarPlateMounts.cars do
		for _, side in { "front", "rear" } do
			local s = (m :: any)[side] :: CarPlateMounts.Spot?
			if s then
				t.ok(PlateStyles.SIZE_M[s.format] ~= nil, `{id} {side}: known format`)
				t.eq(#s.posM, 3, `{id} {side}: x, y, z`)
				t.ok(if side == "front" then s.posM[3] < 0 else s.posM[3] > 0, `{id} {side}: on the right end of the car`)
				t.ok(s.posM[2] > 0.1 and s.posM[2] < 1.6, `{id} {side}: a plausible height`)
			end
		end
		t.ok(m.rear ~= nil, `{id}: has a rear plate`)
	end
end
```

- [ ] **Step 2: Run it and see it fail**

Expected: `CarPlateMounts.spec: error ... CarPlateMounts is not a valid member`.

- [ ] **Step 3: Write CarPlateMounts (no cars yet)**

Create `src/shared/CarPlateMounts.luau`:

```lua
--!strict
-- Where each car's number plates go (spec §1), keyed by car id.
--
-- Positions are car space in metres before the car's scale, the same frame
-- as the catalog's body pieces (offsetM): +X right, +Y up, forward is -Z,
-- the origin on the ground under the wheelbase centre, measured from the
-- body mount. A front plate faces -Z and a rear plate +Z. tiltDeg leans the
-- plate's top in toward the car, for a recess on a sloping boot lid or
-- bumper. A car with no front spot has no front entry and shows no front
-- plate. format is the Saudi plate that fits the recess (PlateStyles).
--
-- How each spot was measured: tools/carbody/README.md, "Plates".
local PlateStyles = require(script.Parent.PlateStyles)

export type Spot = { posM: { number }, format: PlateStyles.Format, tiltDeg: number? }
export type Mounts = { front: Spot?, rear: Spot? }

local CarPlateMounts = {}

CarPlateMounts.cars = {} :: { [string]: Mounts }

-- The plate's frame relative to the car's body mount, in studs. Its -Z (a
-- Part's Front face, where the plate is drawn) points out of the car.
function CarPlateMounts.cframe(spot: Spot, rear: boolean, k: number, mps: number): CFrame
	local p = spot.posM
	return CFrame.new(Vector3.new(p[1], p[2], p[3]) * (k / mps))
		* CFrame.Angles(0, if rear then math.pi else 0, 0)
		* CFrame.Angles(math.rad(spot.tiltDeg or 0), 0, 0)
end

return CarPlateMounts
```

- [ ] **Step 4: Run the specs and see them pass**

Expected: no `CarPlateMounts.spec` lines (there are no cars yet, so only the frame checks run).

- [ ] **Step 5: Write CarPlates**

Create `src/client/CarPlates.luau`:

```lua
--!strict
-- Number plates on every car this client sees (spec §2). Like CarLights:
-- built once the rig is readable, redrawn whenever the car's "Plate"
-- attribute changes (PlateService sets it). A plate is a thin part welded
-- at each spot in CarPlateMounts, with a SurfaceGui drawing the style
-- (PlateStyles). No attribute: no plate shows.
--
-- place() also serves measuring: call it from the Client datamodel with
-- trial mounts to see a spot at once (tools/carbody/README.md, "Plates").
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleRig = require(Shared:WaitForChild("VehicleRig"))
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local CarPlateMounts = require(Shared:WaitForChild("CarPlateMounts"))
local PlateStyles = require(Shared:WaitForChild("PlateStyles"))
local PlateConfig = require(Shared:WaitForChild("PlateConfig"))

local CarPlates = {}

local FOLDER = "Plates"
local WAIT_SECONDS = 10

local watching: { [Model]: RBXScriptConnection } = {}

local function carIdOf(model: Model): string?
	local id = model:GetAttribute(VehicleRig.CAR_ID_ATTRIBUTE)
	return if type(id) == "string" then id else nil
end

-- (Re)builds the plates on a car from these mounts and draws its Plate.
function CarPlates.place(model: Model, mounts: CarPlateMounts.Mounts)
	local old = model:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	local previous = watching[model]
	if previous then
		previous:Disconnect()
		watching[model] = nil
	end
	local handles = VehicleRig.handles(model)
	local carId = carIdOf(model)
	local k = VehicleRig.scaleOf(ConfigLoader.entry(carId))
	local mps = ConfigLoader.forCar(carId).units.metersPerStud
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	local drawn: { { gui: SurfaceGui, part: BasePart, format: PlateStyles.Format } } = {}
	for _, side in { { name = "PlateFront", spot = mounts.front, rear = false }, { name = "PlateRear", spot = mounts.rear, rear = true } } do
		local spot = side.spot
		if not spot then
			continue
		end
		local found = handles.chassis:FindFirstChild(side.name)
		local at: Attachment
		if found and found:IsA("Attachment") then
			at = found
		else
			at = Instance.new("Attachment")
			at.Name = side.name
			at.Parent = handles.chassis
		end
		at.CFrame = handles.bodyMount.CFrame
			* CarPlateMounts.cframe(spot, side.rear, k, mps)
			* CFrame.new(0, 0, -PlateConfig.standoffM * k / mps)
		local sizeM = PlateStyles.SIZE_M[spot.format]
		local part = Instance.new("Part")
		part.Name = side.name
		part.Size = Vector3.new(sizeM.X, sizeM.Y, PlateConfig.thicknessM) * (k / mps)
		part.Color = PlateStyles.COLORS.plate
		part.Material = Enum.Material.SmoothPlastic
		part.CastShadow = false
		part.Anchored = false
		part.Massless = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CFrame = at.WorldCFrame
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handles.chassis
		weld.Part1 = part
		weld.Parent = part
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = sizeM * PlateStyles.PIXELS_PER_M
		gui.LightInfluence = 1 -- lit like the car, not glowing at night
		gui.MaxDistance = PlateConfig.drawDistanceStuds
		gui.Parent = part
		part.Parent = folder
		table.insert(drawn, { gui = gui, part = part, format = spot.format })
	end
	folder.Parent = model
	local function draw()
		local key = model:GetAttribute("Plate")
		for _, d in drawn do
			local art = PlateStyles.draw(d.gui, if type(key) == "string" then key else nil, d.format)
			d.part.Transparency = if art then 0 else 1
		end
	end
	draw()
	watching[model] = model:GetAttributeChangedSignal("Plate"):Connect(draw)
end

local function build(model: Model)
	local deadline = os.clock() + WAIT_SECONDS
	while model.Parent do
		if carIdOf(model) ~= nil and pcall(VehicleRig.handles, model) then
			break
		end
		if os.clock() > deadline then
			return
		end
		task.wait(0.1)
	end
	if not model.Parent then
		return
	end
	local mounts = CarPlateMounts.cars[carIdOf(model) :: string]
	if not mounts then
		return
	end
	local ok, err = pcall(CarPlates.place, model, mounts)
	if not ok then
		warn(`[CarPlates] {model.Name}: {err}`)
	end
	model.Destroying:Connect(function()
		local c = watching[model]
		if c then
			c:Disconnect()
			watching[model] = nil
		end
	end)
end

function CarPlates.start()
	task.spawn(function()
		local cars = Workspace:WaitForChild("Cars", math.huge)
		cars.ChildAdded:Connect(function(child)
			if child:IsA("Model") then
				task.spawn(build, child)
			end
		end)
		for _, child in cars:GetChildren() do
			if child:IsA("Model") then
				task.spawn(build, child)
			end
		end
	end)
end

return CarPlates
```

In `src/client/init.client.luau`, add `local CarPlates = require(script.CarPlates)` after the `CarLights` require. Add `CarPlates.start()` on the line after `CarLights.start()`.

- [ ] **Step 6: Add `--spots` to storecar.py**

In `tools/carbody/storecar.py`:

1. Move the lines of `build()` from `# Wheel centres, and the car's axes from them.` through `origin = centre - up * radius_st` into a new function above `build`:

```python
def car_frame(car, by):
    """The car's frame from its wheels (docstring steps 1 and 2).

    Returns B (columns: right, up, back), the origin, metres per model
    stud, the tyre centres, the tyre radius in studs, and the front and
    rear axle groups.
    """
    # (the moved lines, unchanged)
    return B, origin, mps, C, radius_st, front, rear
```

2. In `build()`, call `B, origin, mps, C, radius_st, front, rear = car_frame(car, by)` where the lines were. `track_m` and everything after stay in `build()`.

3. Add before `if __name__ == "__main__":`:

```python
def spots(key, indices):
    """Prints store parts' centres in car space (metres, before the car's
    scale) and the facing of their thinnest side: the numbers for
    CarPlateMounts (README.md, "Plates")."""
    car = CARS[key]
    parts = json.load(open(os.path.join(ROOT, "assets", "cars", key, "parts.json")))
    by = {p["i"]: p for p in parts}
    B, origin, mps, *_ = car_frame(car, by)
    for i in indices:
        p = by[i]
        R = B.T @ np.array(p["cf"][3:], dtype=float).reshape(3, 3)
        pos = B.T @ (np.array(p["cf"][:3], dtype=float) - origin) * mps
        size = np.array(p["s"], dtype=float) * mps
        thin = int(np.argmin(size))
        normal = R[:, thin]
        if normal[2] * pos[2] < 0:
            normal = -normal  # point out of the car
        tilt = math.degrees(math.atan2(normal[1], abs(normal[2])))
        print(f"{key} part {i} {p['n']!r}: posM = {{ {pos[0]:.3f}, {pos[1]:.3f}, {pos[2]:.3f} }}, "
              f"size {size[0]:.3f} x {size[1]:.3f} x {size[2]:.3f} m, "
              f"tiltDeg = {-tilt:.1f}")
```

In a `parts.json` entry, check the name key used (`"n"` or `"name"`) with `python3 -c "import json;print(json.load(open('assets/cars/krownvik/parts.json'))[0].keys())"`, and use that key.

4. Change the `__main__` block to:

```python
if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[2] == "--spots":
        spots(sys.argv[1], [int(x) for x in sys.argv[3].split(",")])
    else:
        for key in sys.argv[1:] or list(CARS):
            build(key)
```

- [ ] **Step 7: Check the refactor changed nothing**

```bash
for car in kruzer80 lekzas krownvik krownvikfleet; do python3 tools/carbody/storecar.py $car; done
git status --short assets/cars src/shared/CarMeshes
```
Expected: no files listed as modified (only the already-untracked `assets/cars/kruzer100/`). If anything changed, the refactor moved a line wrongly: fix it before going on.

- [ ] **Step 8: Measure the three store plates**

```bash
python3 tools/carbody/storecar.py krownvik --spots 16,82
python3 tools/carbody/storecar.py krownvikfleet --spots 126,17
python3 tools/carbody/storecar.py kruzer80 --spots 36
```

(Krown Vik: 16 front, 82 rear. Fleet: 126 front, 17 rear. Kruzer 80: 36 is the rear mount.) Pick `format` from each part's size: nearer 33.5 × 15.5 cm is `short`, nearer 55 × 11 cm is `long`. The Kruzer 80 has a front spot too: take its position by eye in Step 10.

- [ ] **Step 9: Enter them**

In `src/shared/CarPlateMounts.luau`, replace `CarPlateMounts.cars = {} :: { [string]: Mounts }` with the measured numbers in this shape (one entry per car, numbers from Step 8, rounded to 3 decimals):

```lua
CarPlateMounts.cars = {
	-- Store plate parts 16 (front) and 82 (rear), storecar.py --spots.
	krownvik = {
		front = { posM = { <x>, <y>, <z> }, format = "<short|long>", tiltDeg = <deg> },
		rear = { posM = { <x>, <y>, <z> }, format = "<short|long>", tiltDeg = <deg> },
	},
	-- Store plate parts 126 (front) and 17 (rear): the empty brackets.
	krownvikfleet = { ... },
	-- Rear: the store plate mount, part 36 (painted body colour, 2026-09-25).
	kruzer80 = { ... },
} :: { [string]: Mounts }
```

Omit `tiltDeg` when the helper printed less than 2 degrees.

- [ ] **Step 10: Look at them in Play, and add the Kruzer 80's front spot**

1. Stop and start Play. Spawn each of the three cars in turn (`SpawnCar:FireServer(id)` from the Client datamodel). Check `DriverSeat.Occupant` first.
2. Put the camera about 5 m off the front, then off the rear, and `screen_capture` each.
3. To try a spot live, run in the Client datamodel:

```lua
local lp = game.Players.LocalPlayer
local car = workspace.Cars:FindFirstChild("Car_" .. lp.Name)
local CarPlates = require(lp.PlayerScripts.Client.CarPlates)
CarPlates.place(car, {
	front = { posM = { 0, 0.45, -2.35 }, format = "long" },
	rear = { posM = { 0, 0.82, 2.4 }, format = "short", tiltDeg = 5 },
})
return "placed"
```

Adjust until the plate sits flush in the recess, then copy the numbers into `CarPlateMounts`. Expected: every plate sits in its recess or bracket, face out, text upright and readable, and no plate is visible through the body.

- [ ] **Step 11: Run specs and type check**

Specs: no `CarPlateMounts.spec`, `PlateStyles.spec`, `PlateText.spec` or `PlateRegistry.spec` lines. Run `bash scripts/analyze.sh 2>&1 | grep -E "CarPlates|CarPlateMounts|init.client"`: no output.

- [ ] **Step 12: Commit**

```bash
git add src/shared/CarPlateMounts.luau src/shared/Tests/CarPlateMounts.spec.luau src/client/CarPlates.luau src/client/init.client.luau tools/carbody/storecar.py
git commit -m "Plates on cars: CarPlateMounts and CarPlates, three cars measured" -m "Plates are drawn per client on a thin part at each car's spots, from the car's Plate attribute. Krown Vik, Krown Vik Fleet and Kruzer 80 measured from their store plate parts (storecar.py --spots)." -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PWSgvAKV3x1En9iuoQun7D"
```

Show the owner the six screenshots.

---

### Task 9: The other six cars, and the README

**Files:**
- Modify: `src/shared/CarPlateMounts.luau` (add lekzas, batrol, kamri07, hatch, pickup, cruiser)
- Modify: `src/shared/Tests/CarPlateMounts.spec.luau` (every playable car has a rear plate)
- Modify: `tools/carbody/README.md`

**Interfaces:**
- Consumes: `CarPlates.place` (Task 8) for live measuring, and `ConfigLoader.catalog()`.
- Produces: a spot for every playable car. That is every catalog car not marked `hidden`: hatch, pickup, cruiser, krownvik, krownvikfleet, lekzas, kamri07, batrol and kruzer80.

- [ ] **Step 1: Write the failing test**

Append to `src/shared/Tests/CarPlateMounts.spec.luau`, just before the final `end`:

```lua
	-- Every car on the menu carries plates
	local ConfigLoader = require(script.Parent.Parent.ConfigLoader)
	for id, entry in ConfigLoader.catalog().cars do
		if not (entry :: any).hidden then
			t.ok(CarPlateMounts.cars[id] ~= nil, `{id}: has plate spots`)
		end
	end
```

- [ ] **Step 2: Run it and see it fail**

Expected: six failures: `CarPlateMounts.spec: lekzas: has plate spots was false`, and the same for batrol, kamri07, hatch, pickup and cruiser.

- [ ] **Step 3: Get a starting point for each car**

In Play, with each car spawned in turn (check `DriverSeat.Occupant` first), run in the Client datamodel:

```lua
local lp = game.Players.LocalPlayer
local car = workspace.Cars:FindFirstChild("Car_" .. lp.Name)
local mount = car.Chassis.BodyMount
local k = 1.2 -- every playable car's scale (CarCatalog)
local mps = 0.28
local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
for _, part in car.Body:GetChildren() do
	if part:IsA("BasePart") and part.Transparency < 1 then
		local c = mount.WorldCFrame:PointToObjectSpace(part.Position) * mps / k
		lo, hi = lo:Min(c), hi:Max(c)
	end
end
return string.format("%s body x %.2f..%.2f y %.2f..%.2f z %.2f..%.2f (m, before scale)", car:GetAttribute("CarId"), lo.X, hi.X, lo.Y, hi.Y, lo.Z, hi.Z)
```

Start the front spot at `{ 0, 0.45, lo.Z + 0.03 }` and the rear at `{ 0, 0.75, hi.Z - 0.03 }`. Refine with `CarPlates.place` and screenshots (the Task 8 Step 10 snippet) until each plate sits in its recess. On a car with no front recess (look at the front screenshot), leave `front` out.

- [ ] **Step 4: Enter the six cars**

Add each to `CarPlateMounts.cars` with a one-line comment saying it was measured by eye, for example `-- By eye in Studio (2026-09-26): the boot-lid recess, which slopes about 6°.`

- [ ] **Step 5: Run the specs and see them pass**

Expected: no `CarPlateMounts.spec` lines.

- [ ] **Step 6: Screenshots of all nine cars**

For each playable car, take two screenshots, front and behind at about 5 m, with a plate on:
- Use the default plate for most.
- Equip a bought 1-digit plate on at least one car and a 4-digit plate on another.
- Show at least one `short` and one `long` format.

Put them in a table for the owner: car, format front/rear, and anything off.

- [ ] **Step 7: README plates section**

In `tools/carbody/README.md`:
1. Add a section before `## Steps for a new car`:

```markdown
## Plates

Every playable car carries a front and a rear number plate spot
(`src/shared/CarPlateMounts.luau`, keyed by car id), and every client draws
the plate from the car's `Plate` attribute (`src/client/CarPlates.luau`,
`src/shared/PlateStyles.luau`; design in
`docs/superpowers/specs/2026-09-26-number-plates-design.md`).

- **Frame:** car space in metres before the car's scale, the same as the
  catalog's `offsetM`. A front plate faces -Z, a rear plate +Z; `tiltDeg`
  leans the top in toward the car.
- **Format:** `short` (33.5 × 15.5 cm) or `long` (55 × 11 cm),
  whichever fills the recess. The plate is that size times the car's scale.
- **Plate spot on the body:** keep the recess or bracket bare and
  uncovered (the body standard above). The plate goes on it.
- **Measuring, exact:** when the store model has a plate part, run
  `python3 tools/carbody/storecar.py <car> --spots <part>,<part>` for its
  centre, size and tilt.
- **Measuring, by eye:** spawn the car and call `CarPlates.place(car, mounts)`
  from the Client datamodel with trial numbers; screenshot front and
  behind; adjust.
- The contract lives here until the owner's rig rework lands in
  `RIG_SPEC.md`.
```

2. In `## Steps for a new car`, step 6, replace `and the plate spot, before calling it done.` with `and add its plate spots to CarPlateMounts ("Plates" above) and check them front and behind, before calling it done.`
3. In the cars table under `## Cars`, add a note for each car saying how its plate spots were measured (exact or by eye).

- [ ] **Step 8: Commit**

```bash
git add src/shared/CarPlateMounts.luau src/shared/Tests/CarPlateMounts.spec.luau tools/carbody/README.md
git commit -m "Plates on all nine cars; plate spots in the car standard" -m "Lekzas, Batrol, Kamri, Hatch, Pickup and Cruiser measured by eye with CarPlates.place. README: the plate contract, how to measure, and a plate step for new cars." -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PWSgvAKV3x1En9iuoQun7D"
```

Also update the memory note `car-body-standard.md`: add a bullet saying each car gets plate spots in CarPlateMounts, measured per the README.

---

### Task 10: The Plates tab

**Files:**
- Create: `src/client/PlatesPanel.luau`
- Modify: `src/client/SpawnMenu.luau`

**Interfaces:**
- Consumes:
  - `PlateText.normalise`, `parts`, `price` (Task 2); `PlateStyles.draw`, `SIZE_M` (Task 7); `CarPlateMounts.cars` (Task 8).
  - Remotes `PlateQuery` and `PlateAction`, with replies as in Task 6.
  - Player attributes `Plates`, `PlateEquipped`, `PlateDefault` and `Cash`.
- Produces:
  - `export type Theme = { card: Color3, white: Color3, muted: Color3, hot: Color3, hotDim: Color3 }`
  - `PlatesPanel.build(parent: Instance, theme: Theme, layoutOrder: number): Frame`
  - `PlatesPanel.fit(height: number, touch: boolean)`
  - `PlatesPanel.setVisible(visible: boolean)`
  - `PlatesPanel.setCar(carId: string?)`
  - `PlatesPanel.start(remotes: Folder)`

- [ ] **Step 1: Write PlatesPanel**

Create `src/client/PlatesPanel.luau`:

```lua
--!strict
-- The Plates tab of the car menu (docs/superpowers/specs/2026-09-26-number-plates-design.md §5).
-- SpawnMenu owns the panel and shows this in place of the car list.
--   * Search: letters and digits in either script. PlateText answers at
--     once here; the server is asked (PlateQuery) for the price and whether
--     the plate is free once typing pauses.
--   * A preview in the current car's rear plate format.
--   * Buy, then your plates, each with an Equip button, and the session's
--     default plate.
-- What you own comes from Player attributes set by the server (Plates,
-- PlateEquipped, PlateDefault); nothing here is trusted by the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlateText = require(Shared:WaitForChild("PlateText"))
local PlateStyles = require(Shared:WaitForChild("PlateStyles"))
local CarPlateMounts = require(Shared:WaitForChild("CarPlateMounts"))

export type Theme = { card: Color3, white: Color3, muted: Color3, hot: Color3, hotDim: Color3 }

local PlatesPanel = {}

-- Seconds typing must pause before the server is asked.
local QUERY_DELAY = 0.35

local MESSAGES: { [string]: string } = {
	done = "Done",
	taken = "Someone else owns this plate",
	cash = "Not enough cash",
	unavailable = "The plate shop is unavailable right now. Nothing was charged",
	pending = "Your purchase is finishing. It will show in a moment",
	owned = "You already own this plate",
	notowned = "You don't own this plate",
	busy = "One moment…",
}

local theme: Theme? = nil
local root: Frame? = nil
local search: TextBox? = nil
local previewBox: Frame? = nil
local info: TextLabel? = nil
local buyButton: TextButton? = nil
local list: ScrollingFrame? = nil
local heading: TextLabel? = nil
local topRow: Frame? = nil
local queryRemote: RemoteFunction? = nil
local actionRemote: RemoteFunction? = nil
local carId: string? = nil
local current: { key: string?, price: number?, free: boolean } = { key = nil, price = nil, free = false }
local asked = 0
local touch = false

local function t(): Theme
	return theme :: Theme
end

local function money(n: number): string
	return (tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function shown(key: string): string
	local p = PlateText.parts(key)
	return if p then `{table.concat(p.latin)} {p.digits}` else key
end

local function format(): PlateStyles.Format
	local mounts = if carId then CarPlateMounts.cars[carId] else nil
	local rear = if mounts then mounts.rear else nil
	return if rear then rear.format else "short"
end

local function ownedKeys(): { string }
	local raw = Players.LocalPlayer:GetAttribute("Plates")
	local out: { string } = {}
	if type(raw) == "string" then
		for k in string.gmatch(raw, "[^,]+") do
			table.insert(out, k)
		end
	end
	return out
end

local function owns(key: string): boolean
	return table.find(ownedKeys(), key) ~= nil
end

local function setInfo(text: string, color: Color3)
	if info then
		(info :: TextLabel).Text = text;
		(info :: TextLabel).TextColor3 = color
	end
end

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function button(parent: Instance, text: string): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBlack
	b.Text = text
	b.TextSize = 16
	b.TextColor3 = Color3.fromRGB(15, 15, 18)
	b.BackgroundColor3 = t().hot
	corner(b, 8)
	b.Parent = parent
	return b
end

local function refreshBuy()
	local b = buyButton
	if not b then
		return
	end
	local cash = tonumber(Players.LocalPlayer:GetAttribute("Cash")) or 0
	local key, price = current.key, current.price
	local can = key ~= nil and price ~= nil and current.free and not owns(key) and cash >= price
	b.BackgroundColor3 = if can then t().hot else t().hotDim
	b.Text = if price then `BUY  {money(price)}` else "BUY"
end

local function drawPreview(key: string?)
	local box = previewBox
	if box then
		PlateStyles.draw(box, key or (Players.LocalPlayer:GetAttribute("PlateDefault") :: string?), format())
	end
end

local refreshOwned: () -> ()

local function doAction(what: string, key: string)
	local remote = actionRemote
	if not remote then
		return
	end
	setInfo(MESSAGES.busy, t().muted)
	local ok, reply = pcall(function()
		return remote:InvokeServer(what, key)
	end)
	local status = if ok and type(reply) == "table" then reply.status else "unavailable"
	if status == "invalid" then
		setInfo(reply.reason or "Not a plate", t().hot)
	else
		setInfo(MESSAGES[status] or MESSAGES.unavailable, if status == "done" then t().white else t().hot)
	end
	if status == "done" or status == "taken" then
		current.free = false
	end
	refreshOwned()
	refreshBuy()
end

local function onSearch()
	local box = search
	if not box then
		return
	end
	local text = box.Text
	asked += 1
	local mine = asked
	current = { key = nil, price = nil, free = false }
	refreshBuy()
	if text == "" then
		drawPreview(nil)
		setInfo("Type 3 letters and a number, in Arabic or English", t().muted)
		return
	end
	local key, reason = PlateText.normalise("SA", text)
	if not key then
		drawPreview(nil)
		setInfo(reason or "Not a plate", t().hot)
		return
	end
	drawPreview(key)
	if owns(key) then
		setInfo(`{shown(key)} is yours`, t().white)
		return
	end
	local price = PlateText.price(key) :: number
	current = { key = key, price = price, free = false }
	refreshBuy()
	setInfo(`{money(price)} cash · checking…`, t().muted)
	task.delay(QUERY_DELAY, function()
		local remote = queryRemote
		if mine ~= asked or not remote then
			return
		end
		local ok, reply = pcall(function()
			return remote:InvokeServer(text)
		end)
		if mine ~= asked then
			return
		end
		if not ok or type(reply) ~= "table" then
			setInfo(MESSAGES.unavailable, t().hot)
		elseif reply.status == "ok" then
			current = { key = reply.key, price = reply.price, free = reply.available == true }
			if current.free then
				setInfo(`{money(reply.price)} cash · available`, t().white)
			else
				setInfo(MESSAGES.taken, t().hot)
			end
		elseif reply.status == "invalid" then
			setInfo(reply.reason or "Not a plate", t().hot)
		else
			setInfo(MESSAGES[reply.status] or MESSAGES.unavailable, t().hot)
		end
		refreshBuy()
	end)
end

local function rowHeight(): number
	return if touch then 72 else 56
end

local function row(parent: Instance, order: number, key: string, caption: string, fitted: boolean, onPress: () -> ())
	local h = rowHeight()
	local f = Instance.new("Frame")
	f.BackgroundColor3 = t().card
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, 0, 0, h)
	f.LayoutOrder = order
	corner(f, 10)
	local mini = Instance.new("Frame")
	mini.BackgroundTransparency = 1
	mini.Position = UDim2.fromOffset(10, math.floor(h * 0.12))
	mini.Size = UDim2.fromOffset(math.floor(h * 1.9), math.floor(h * 0.76))
	mini.Parent = f
	PlateStyles.draw(mini, key, format())
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = if touch then 18 else 15
	l.TextColor3 = t().white
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = caption
	l.Position = UDim2.fromOffset(math.floor(h * 1.9) + 22, 0)
	l.Size = UDim2.new(1, -(math.floor(h * 1.9) + 22 + 130), 1, 0)
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = f
	local b = button(f, if fitted then "FITTED" else "EQUIP")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -10, 0.5, 0)
	b.Size = UDim2.fromOffset(110, math.floor(h * 0.64))
	if fitted then
		b.BackgroundColor3 = t().hotDim
	end
	b.Activated:Connect(function()
		if not fitted then
			onPress()
		end
	end)
	f.Parent = parent
end

refreshOwned = function()
	local l = list
	if not l then
		return
	end
	for _, child in l:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local player = Players.LocalPlayer
	local equipped = player:GetAttribute("PlateEquipped")
	local default = player:GetAttribute("PlateDefault")
	if type(default) == "string" then
		row(l, 0, default, `{shown(default)} · default this session`, equipped == nil, function()
			doAction("unequip", "")
		end)
	end
	local keys = ownedKeys()
	for i, key in keys do
		row(l, i, key, shown(key), equipped == key, function()
			doAction("equip", key)
		end)
	end
	if #keys == 0 then
		local hint = Instance.new("TextLabel")
		hint.BackgroundTransparency = 1
		hint.Font = Enum.Font.GothamMedium
		hint.TextSize = 14
		hint.TextColor3 = t().muted
		hint.Text = "Plates you buy show here"
		hint.Size = UDim2.new(1, 0, 0, 28)
		hint.LayoutOrder = 999
		hint.Parent = l
	end
end

function PlatesPanel.build(parent: Instance, th: Theme, layoutOrder: number): Frame
	theme = th
	local f = Instance.new("Frame")
	f.Name = "Plates"
	f.BackgroundTransparency = 1
	f.LayoutOrder = layoutOrder
	f.Visible = false
	f.Size = UDim2.new(1, 0, 0, 300)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = f

	local top = Instance.new("Frame")
	top.BackgroundTransparency = 1
	top.LayoutOrder = 1
	top.Size = UDim2.new(1, 0, 0, 44)
	top.Parent = f
	topRow = top
	local box = Instance.new("TextBox")
	box.BackgroundColor3 = th.card
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.GothamBold
	box.TextSize = 20
	box.TextColor3 = th.white
	box.PlaceholderText = "ABJ 7   ·   حبأ ٧"
	box.PlaceholderColor3 = th.muted
	box.Text = ""
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Size = UDim2.new(1, -170, 1, 0)
	corner(box, 8)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.Parent = box
	box.Parent = top
	box:GetPropertyChangedSignal("Text"):Connect(onSearch)
	search = box
	local buy = button(top, "BUY")
	buy.AnchorPoint = Vector2.new(1, 0)
	buy.Position = UDim2.fromScale(1, 0)
	buy.Size = UDim2.new(0, 160, 1, 0)
	buy.Activated:Connect(function()
		local key = current.key
		if key and current.free then
			doAction("buy", key)
		end
	end)
	buyButton = buy

	local preview = Instance.new("Frame")
	preview.BackgroundTransparency = 1
	preview.LayoutOrder = 2
	preview.Size = UDim2.new(1, 0, 0, 84)
	preview.Parent = f
	previewBox = preview

	local line = Instance.new("TextLabel")
	line.BackgroundTransparency = 1
	line.Font = Enum.Font.GothamMedium
	line.TextSize = 14
	line.TextColor3 = th.muted
	line.LayoutOrder = 3
	line.Size = UDim2.new(1, 0, 0, 20)
	line.Parent = f
	info = line

	local head = Instance.new("TextLabel")
	head.BackgroundTransparency = 1
	head.Font = Enum.Font.GothamBlack
	head.TextSize = 14
	head.TextColor3 = th.muted
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.Text = "YOUR PLATES"
	head.LayoutOrder = 4
	head.Size = UDim2.new(1, 0, 0, 18)
	head.Parent = f
	heading = head

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = 5
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = th.muted
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Size = UDim2.new(1, 0, 0, 120)
	local rows = Instance.new("UIListLayout")
	rows.SortOrder = Enum.SortOrder.LayoutOrder
	rows.Padding = UDim.new(0, 6)
	rows.Parent = scroll
	scroll.Parent = f
	list = scroll

	f.Parent = parent
	root = f
	return f
end

-- Sizes the tab to the height the menu gives it.
function PlatesPanel.fit(height: number, isTouch: boolean)
	touch = isTouch
	local f, top, preview, scroll = root, topRow, previewBox, list
	if not f or not top or not preview or not scroll or not info or not heading then
		return
	end
	local topH = if isTouch then 56 else 44
	local previewH = if isTouch then 96 else 84
	f.Size = UDim2.new(1, 0, 0, height)
	top.Size = UDim2.new(1, 0, 0, topH)
	preview.Size = UDim2.new(1, 0, 0, previewH)
	local fixed = topH + previewH + 20 + 18 + 8 * 4
	scroll.Size = UDim2.new(1, 0, 0, math.max(height - fixed, rowHeight()))
	scroll.ScrollBarThickness = if isTouch then 6 else 4
end

function PlatesPanel.setVisible(visible: boolean)
	local f = root
	if not f then
		return
	end
	f.Visible = visible
	if visible then
		refreshOwned()
		onSearch()
	end
end

function PlatesPanel.setCar(id: string?)
	if id then
		carId = id
	end
	if root and (root :: Frame).Visible then
		refreshOwned()
		onSearch()
	end
end

function PlatesPanel.start(remotes: Folder)
	queryRemote = remotes:WaitForChild("PlateQuery") :: RemoteFunction
	actionRemote = remotes:WaitForChild("PlateAction") :: RemoteFunction
	local player = Players.LocalPlayer
	for _, name in { "Plates", "PlateEquipped", "PlateDefault", "Cash" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if root and (root :: Frame).Visible then
				refreshOwned()
				refreshBuy()
			end
		end)
	end
end

return PlatesPanel
```

- [ ] **Step 2: Add the tab bar to SpawnMenu**

Edits in `src/client/SpawnMenu.luau`:

1. After `local VehicleRig = require(Shared.VehicleRig)`, add:
```lua
local PlatesPanel = require(script.Parent.PlatesPanel)
```
2. After `local waitingUntil = 0`, add:
```lua
local tabs: Frame? = nil
local tabButtons: { [string]: TextButton } = {}
local showing: "cars" | "plates" = "cars"
```
3. In `type Metrics`, add the field `tabH: number,` after `headerH: number,`. In the desktop table returned by `metrics()`, add `tabH = 34,`. In the phone table, add `tabH = math.clamp(unit * 0.08, 40, 56),`.
4. In `fit()`, replace:
```lua
	local chrome = m.pad * 2 + m.headerH + m.gap * 2 + m.footerH
	local room = math.max(vp.Y - topMargin - bottomMargin - chrome, math.floor(m.cardH * 0.6))
	local want = #cards * (m.cardH + m.gap) - m.gap
	local listH = math.min(want, room)
	scroll.Size = UDim2.new(1, 0, 0, listH)
```
with:
```lua
	local chrome = m.pad * 2 + m.headerH + m.tabH + m.gap * 3 + m.footerH
	local room = math.max(vp.Y - topMargin - bottomMargin - chrome, math.floor(m.cardH * 0.6))
	local want = #cards * (m.cardH + m.gap) - m.gap
	-- The plates tab takes all the room; the car list only what it needs.
	local listH = if showing == "plates" then room else math.min(want, room)
	scroll.Size = UDim2.new(1, 0, 0, listH)
	PlatesPanel.fit(listH, m.touch)
	if tabs then
		(tabs :: Frame).Size = UDim2.new(1, 0, 0, m.tabH)
		for _, b in tabButtons do
			b.TextSize = math.floor(m.tabH * 0.42)
		end
	end
```
5. Add above `local function build()`:
```lua
local function paintTabs()
	for name, b in tabButtons do
		local on = name == showing
		b.BackgroundColor3 = if on then HOT else CARD
		b.TextColor3 = if on then INK else MUTED
	end
end

local function show(which: "cars" | "plates")
	showing = which
	if list then
		(list :: ScrollingFrame).Visible = which == "cars"
	end
	PlatesPanel.setVisible(which == "plates")
	if title then
		(title :: TextLabel).Text = if which == "cars" then "CHOOSE YOUR CAR" else "NUMBER PLATES"
	end
	if subtitle then
		(subtitle :: TextLabel).Text = if which == "cars" then "اختر سيارتك" else "لوحات"
	end
	if status then
		(status :: TextLabel).Text = if which == "plates"
			then "Plates are yours alone: nobody else can own the same one"
			elseif isTouch() then "Tap a car to spawn it   ·   CARS reopens this"
			else "Click a car to spawn it   ·   M reopens this"
	end
	paintTabs()
	fit()
end
```
6. In `build()`, after the close button's `close.Activated` connection, add the tab row:
```lua
	local tabRow = Instance.new("Frame")
	tabRow.Name = "Tabs"
	tabRow.BackgroundTransparency = 1
	tabRow.LayoutOrder = 2
	tabRow.Size = UDim2.new(1, 0, 0, 34)
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabRow
	for i, pair in { { "cars", "CARS" }, { "plates", "PLATES" } } do
		local b = Instance.new("TextButton")
		b.Name = pair[2]
		b.AutoButtonColor = false
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBlack
		b.Text = pair[2]
		b.TextSize = 14
		b.LayoutOrder = i
		b.Size = UDim2.new(0.5, -4, 1, 0)
		corner(b, 8)
		b.Parent = tabRow
		tabButtons[pair[1]] = b
		b.Activated:Connect(function()
			show(pair[1] :: any)
		end)
	end
	tabRow.Parent = p
	tabs = tabRow
```
7. In `build()`, change `scroll.LayoutOrder = 2` to `scroll.LayoutOrder = 3` and `footer.LayoutOrder = 3` to `footer.LayoutOrder = 4`. After `list = scroll` (before building the cards), add:
```lua
	PlatesPanel.build(p, { card = CARD, white = WHITE, muted = MUTED, hot = HOT, hotDim = HOT_DIM }, 3)
```
8. In `SpawnMenu.open()`, replace the `if status then ... end` block that sets the footer text with `show(showing)`. It sets the footer, fits and paints the tabs.
9. In `SpawnMenu.setCurrent`, add `PlatesPanel.setCar(carId)` before `refreshButtons()`.
10. In `SpawnMenu.start`, add `PlatesPanel.start(remotes)` before `build()`.

- [ ] **Step 3: Type check**

Run `bash scripts/analyze.sh 2>&1 | grep -E "SpawnMenu|PlatesPanel"`. Expected: no output.

- [ ] **Step 4: Try it in Play (desktop)**

Stop and start Play, spawn a car, press M, and tap PLATES. Do each of these, taking a `screen_capture` after each, and use MCP `user_mouse_input` / `user_keyboard_input` for real input:
1. Type `ABJ 7`. Expected: a preview of SA:ABJ-7 in the car's rear format, and the price `500,000 cash · available`.
2. Type `حبأ ٤٥٦٧`. Expected: the preview shows ABJ 4567 and the price is 20,000.
3. Type `ABC 7`. Expected: the reason shows in orange and Buy is dimmed.
4. Press Buy on a 4-digit plate. Expected: "Done". The plate is listed as FITTED, the cash drops, and the car's plate changes (screenshot from behind the car).
5. Press EQUIP on the default row. Expected: the car goes back to the default plate.
6. Switch back to CARS. Expected: the car list works as before, and spawning still works.

- [ ] **Step 5: Try it in touch layout**

Set `ForceTouch = true` on the LocalPlayer, reopen the menu, and take a `screen_capture` of the PLATES tab. Expected: nothing is cut off, the rows are thumb-sized, and the list scrolls with `scrollDown`. Set `ForceTouch` back to nil afterwards.

- [ ] **Step 6: Commit**

```bash
git add src/client/PlatesPanel.luau src/client/SpawnMenu.luau
git commit -m "Plates tab in the car menu: search, preview, buy, equip" -m "Search takes Arabic or English; a live preview in the car's plate format, the price and availability from the server; your plates and the session default with Equip." -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PWSgvAKV3x1En9iuoQun7D"
```

Show the owner the screenshots (desktop and touch).

---

### Task 11: Final checks, branch status, hand-off

**Files:**
- Modify: `BRANCH_STATUS.md`

- [ ] **Step 1: Full spec run**

Run the specs. Expected: the only failures are the 14 `VehicleRig.spec` baseline. Record the pass count.

- [ ] **Step 2: Full type check**

Run `bash scripts/analyze.sh 2>&1 | grep -vE "World/init.luau|Station.luau|BodyBuilder.luau" | grep -iE "error"`. Expected: no errors in any file this plan touched.

- [ ] **Step 3: A clean join in Play**

1. Stop and start Play and spawn a car.
2. Confirm that the default plate shows front and rear, and that no warnings from `[Plates]` or `[CarPlates]` appear in the console except the Studio fake-store notice.
3. Buy a plate. Then stop and start Play: with the fake store, the plate is gone (in-memory by design). Say so in the report.
4. If the owner has turned on Studio API access to DataStores, the plate must still be there after the restart, fitted. Report whichever case applied.

- [ ] **Step 4: Record the branch**

In `BRANCH_STATUS.md`, after the line about `car-crownvic`, add:

```markdown
`plates` (number plates: Saudi, cash, unique registry; spec and plan in docs/superpowers) is
the current short-lived branch, to merge into `main` when the owner has checked it.
```

- [ ] **Step 5: Commit**

```bash
git add BRANCH_STATUS.md
git commit -m "Branch status: plates" -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PWSgvAKV3x1En9iuoQun7D"
```

- [ ] **Step 6: Report to the owner**

Include:
1. A commit table: sha, one line each, and the link format.
2. The test count before and after.
3. The Task 6 remote results table.
4. The nine-car screenshot table.
5. The menu screenshots.
6. Open points:
   - The prices in `PlateConfig.prices` are first guesses: the owner sets them.
   - Turning on Studio DataStore access (File > Game Settings > Security) allows one real end-to-end purchase test.
   - Any Task 1 finding that changed the spec.

Ask before pushing; after the owner agrees, `git push -u origin plates`. Merge to `main` only when asked, using the stash routine in CLAUDE.md for the owner's `CarCatalog.luau` edits.
