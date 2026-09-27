# Number plates: design

Agreed with the owner on 2026-09-26. First build: Saudi plates only, paid with
in-game cash, globally unique numbers, one equipped plate shown on whatever car
the player drives.

## Why

Plates are the game's differentiator: other drift games have cars, maps and
drifting; none sell plates, and Gulf plate culture is something the audience
already values. Two things make it worth doing now:

- **Retrofit cost.** Every car needs front and rear plate spots and a plate
  surface. Nine cars now is cheap; later it is annoying.
- **The registry must be right from day one.** A plate collision after launch
  means telling a player a plate they paid for is not theirs.

## Decisions

| Question | Decision |
|---|---|
| Countries | Saudi only first. Dubai, Abu Dhabi, Kuwait and Qatar later, each once its format table is confirmed against real references |
| Payment | In-game cash only for now. The registry is built so Robux can be added later without a redesign |
| Uniqueness | Per style, in the real format. Saudi "ABJ 7" is one plate; a later Dubai "A 7" is a different plate |
| Ownership | A player can own many plates and equips one; it shows on whatever car they drive |
| Custom text | Later, not in this build |
| Default plate | A random Saudi plate (3 letters, 4 digits), not registered. Picked again if the registry says someone owns it |
| Registry | One DataStore key per plate, claimed with `UpdateAsync` (option A). No MemoryStore |
| Pending claim | 120 s |
| Plate spots | A new module, `CarPlateMounts`, keyed by car id. The client builds the mounts. `VehicleRig`, `RigBuilder`, `BodyBuilder` and `CarCatalog` are not touched (the owner has uncommitted rig work there, which removes the old plate system) |

## What exists today (checked 2026-09-26)

- The committed code has a plate system: `PlateFront` / `PlateRear` attachments
  made by `RigBuilder` from `body.plates` in the catalog, and a 0.52 × 0.11 m
  quad with a swappable decal made by `BodyBuilder` (`RIG_SPEC.md` 7c). Only the
  hidden generated `kamri` used it. None of the nine playable cars have plates.
- The owner's uncommitted rig work removes that system. It is not reused; only
  the mount names `PlateFront` and `PlateRear` carry over.
- Its gaps, which this design fixes: one fixed size (real recesses vary), a
  decal per plate (no way to show arbitrary numbers), and no per-player data
  path (the plate came from the catalog, the same for everyone).
- `Economy.luau` keeps cash and best score in `HajwalaPlayer_v1`, with its
  rules: a failed load is never saved; writes go through `UpdateAsync`. There
  is no cross-server session lock.

## 1. Plate spots on each car

`src/shared/CarPlateMounts.luau` lists each car's spots in car space, metres
before the car's scale (like catalog pieces). The numbers below are
illustrative; each car's are measured:

```lua
krownvik = {
	front = { posM = { 0, 0.47, -2.62 }, format = "short" },
	rear = { posM = { 0, 0.79, 2.73 }, format = "short", tiltDeg = 8 },
},
```

- `format` is `short` or `long`, the two Saudi plate formats. It is chosen to
  fit the car's recess. The plate's size comes from the format, times the
  car's scale (1.2), so it fills the recess.
- `tiltDeg` tilts the plate about the car's X axis, for a recess on a sloping
  boot lid or bumper. Default 0.
- A car with no front spot has no `front` entry and shows no front plate.
- Front plates face -Z, rear plates face +Z.
- **Measuring.** Exact from the store model's plate parts for the Krown Vik,
  Krown Vik Fleet and Kruzer 80. By eye in Studio for the Lekzas, Batrol,
  Kamri, Hatch, Pickup and Cruiser. Every car is checked with screenshots from
  front and behind with the plate on.
- The Kruzer 80's plate mount (painted body colour) and the Krown Vik Fleet's
  empty brackets get the plate on them.

## 2. Drawing the plate

`src/client/CarPlates.luau` works like `CarLamps`:

- For every car in `workspace.Cars`, once its body is mounted, it creates the
  `PlateFront` / `PlateRear` attachments on the chassis from
  `CarPlateMounts`, and a thin plate part welded at each.
- A `SurfaceGui` on the plate's outer face draws the style from frames and
  text labels. No uploaded images.
- It reads one attribute on the car Model, `Plate` (the plate key, for example
  `SA:ABJ-7`), and redraws when it changes. No attribute: no plate.
- **Saudi layouts** (`src/shared/PlateStyles.luau`): a white plate with the
  blue KSA strip; Arabic digits and letters above, Latin below (short) or side
  by side (long). Each Arabic letter and digit is its own label: Saudi plates
  show letters separate, never joined, so there is no right-to-left shaping.
  Arabic letters are drawn right to left from the canonical form.
- **Open check, first task of the build:** that a Roblox font renders the 17
  Arabic plate letters and the Arabic-Indic digits. If not, the fallback is one
  uploaded sheet of 27 glyphs drawn with image labels.
- **Open check:** the real sizes of the two Saudi formats (about 52 × 11 cm
  long and 32 × 16 cm short) and the strip's layout, against a reference
  photo.

## 3. Plate strings

`src/shared/PlateText.luau` is the only place plate strings are parsed. The
purchase screen and the server both use it; the server always normalises
again and never trusts the client's string.

**Canonical form:** style code, a colon, the Latin letters in reading order, a
hyphen, the number without leading zeros. ASCII only. Example: `SA:ABJ-7`.

**Normalising, in order:**
1. Remove whitespace, hyphens, tatweel (U+0640), and the invisible direction
   and joining marks: U+200E LRM, U+200F RLM, U+061C ALM, U+200C ZWNJ,
   U+200D ZWJ. Without this, `7` and `7` with a hidden mark would be two keys.
2. Digits: Arabic-Indic `٠`–`٩` (U+0660–0669) and Persian `۰`–`۹`
   (U+06F0–06F9) become `0`–`9`.
3. Letters: Latin is uppercased. Arabic letters map one to one to their
   official Latin letter. The hamza forms أ إ آ and bare ا all become `A`.
4. Split into letters and digits. Saudi: exactly 3 letters and 1 to 4 digits.
   Leading zeros are dropped (`٠٠٧` = `007` = `7`). All zeros is rejected.
5. Any letter outside the 17 is rejected with a message; nothing is silently
   changed.

**Saudi letters** (to be checked against a reference before release):

| Arabic | أ | ب | ح | د | ر | س | ص | ط | ع | ق | ك | ل | م | ن | هـ | و | ى |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Latin | A | B | J | D | R | S | X | T | E | G | K | L | Z | N | H | U | V |

`PlateText` returns either the canonical key or a reason it was rejected, and
formats a key back into its Arabic and Latin halves for drawing.

## 4. The registry

`src/server/PlateRegistry.luau`, backed by the DataStore
`HajwalaPlates_v1`. It takes its store as a parameter, so tests pass a fake.

**Truth.** The plate's key is the only truth about who owns a plate. The
player's profile holds a copy for display, corrected against the key whenever
the profile loads.

**Plate key and value:**

```lua
-- key: "SA:ABJ-7"
{
	schema = 1,
	status = "free" | "pending" | "owned",
	owner = 123456, -- UserId; nil when free
	txn = "8f3c...", -- the transaction that set the current status (GenerateGUID)
	version = 7, -- goes up by one on every change; conditional writes check it
	pendingUntil = 1790000000, -- os.time(); only while pending
	since = 1790000000, -- when the current owner got it
	price = 25000, -- cash paid; used by refunds
	history = { { owner = 123456, at = 1790000000, how = "buy" } }, -- last 5 only
}
```

The owner's UserId is also passed as the key's user IDs on every write, so a
right-to-erasure request can find and free that user's plates.

**Buying (three writes):**
1. **Reserve.** `UpdateAsync` on the plate key. It succeeds only if the key is
   missing, `free`, or `pending` with `pendingUntil` in the past. It writes
   `pending`, the new `txn`, `pendingUntil = now + 120`, `version + 1`.
   Otherwise: "taken".
2. **Charge.** `Economy.transact` updates the profile in one `UpdateAsync`: it
   checks and subtracts the cash, and adds the purchase to `pendingTxns`
   (`txn`, key, price) and the plate to `plates`, marked pending. If there is
   not enough cash, nothing is charged, step 3 is skipped, and the
   reservation is freed with an `UpdateAsync` conditional on this `txn`.
3. **Confirm.** `UpdateAsync` on the plate key. It succeeds only if the key is
   still `pending` with this `txn`. It writes `owned`, `owner`, `since`,
   `price`, `version + 1`, and a history line. The profile then drops the txn
   from `pendingTxns` and marks the plate owned.

**Releasing (for refunds now, trading and selling later):**
1. The profile marks the plate "releasing" under a new `txn` and unequips it.
2. `UpdateAsync` on the plate key sets `free` (keeping `version + 1` and
   history). It succeeds only if the key says owned by this player at the
   expected version.
3. The profile drops the plate and credits any refund, recording the `txn` so
   it is never paid twice.

Freed keys are never deleted. The version keeps rising, so a late write from
an old transaction can never land on a plate that has since changed hands. A
freed plate is back in the pool immediately; a cooldown can be added later.

**Trading, later:** one conditional `UpdateAsync` moves the key from A to B;
both profiles catch up on their next load.

**Recovery on profile load.** For each transaction left in `pendingTxns`, the
key is read:

| Profile says | Key says | Action |
|---|---|---|
| buying, txn X | pending, txn X | confirm (step 3) |
| buying, txn X | owned by me, txn X | finish the profile side |
| buying, txn X | anything else | refund the price, drop the plate |
| releasing, txn Y | owned by me | free it (step 2), then step 3 |
| releasing, txn Y | free or not mine | finish the profile side (step 3) |

Owned plates are not all re-read on every load (that would cost a read per
plate). The equipped plate's key is checked when it is equipped and at join;
if the key says someone else owns it, it is removed from the profile and
unequipped. The player's own purchases never run in parallel: the server
runs one plate transaction per player at a time.

**Cost:** purchases and releases are rare. Availability checks are reads
cached for 30 s per plate. The default plate costs one read per join.

## 5. Buying and equipping

**Where:** a Plates tab in the existing car menu (`SpawnMenu`, M):
- **Your plates:** the ones owned, each with an Equip button.
- **Search:** letters and digits in either script, normalised with
  `PlateText`. A live preview in the current car's format, the price, and
  whether it is available.
- **Buy:** charges, reserves and equips.

**Remotes:** a `RemoteFunction` `PlateQuery` (check a plate: canonical key,
price, available) and a `RemoteFunction` `PlateAction` (buy, equip).
Rate-limited per player. Replies are one of: done, taken, invalid (with the
reason), not enough cash, shop unavailable (DataStore down; nothing charged).

**Prices** in `src/shared/PlateConfig.luau` (first guesses, for the owner to
set against how fast cash is earned):

| Digits | Price |
|---|---|
| 1 | 500,000 |
| 2 | 200,000 |
| 3 | 75,000 |
| 4 | 20,000 |

Three identical letters (`AAA`) or all digits identical (`7777`) cost double.

**Equipping** sets the `Plate` attribute on the player's car when they get in
and whenever they equip another. With nothing equipped, the car shows the
player's default plate for the session.

**Profile.** `HajwalaPlayer_v1` gains three fields: `plates` (list of
`{ key, state }`), `equipped` (a key or nil) and `pendingTxns`. They are new
fields only: an old profile reads them as empty, so there is no migration.
Cash is unchanged. The existing rule holds: a profile whose load failed is
never saved, so plates are never saved over.

## 6. Testing

- **`PlateText` tests** (the Studio spec runner, `Tests`): every Arabic-Indic
  and Persian digit; the hamza forms; each hidden mark; leading zeros; all
  zeros; letters outside the 17; Latin and Arabic input giving the same key;
  formatting a key back to both halves.
- **`PlateRegistry` tests** against a fake DataStore that can interleave two
  `UpdateAsync` calls on one key (two servers racing), fail between any two
  steps of a purchase or release, and move the clock past `pendingUntil`.
  Each test checks the two rules that matter: a plate never has two owners,
  and cash is either charged with the plate recorded or refunded.
- **Studio:** API access to DataStores is off in this place's settings, so
  Studio play uses the fake store until the owner turns it on (File > Game
  Settings > Security). An end-to-end purchase test needs it on once. The
  fake store is only ever chosen in Studio (`RunService:IsStudio()`): a live
  server with the DataStore down shows "shop unavailable" and never falls
  back to it.
- **In game:** every car checked front and behind with a plate on, as
  screenshots, and a short and long format each shown.

## Out of scope for this build

Robux purchases; custom text plates; the Dubai, Abu Dhabi, Kuwait and Qatar
styles; trading and selling back (the release path exists and is tested, but
no button); plates on the leaderboard; plate lights at night. The key format,
the registry and the profile fields are chosen so each can be added without
changing them.

## Files

| File | New or changed |
|---|---|
| `src/shared/PlateText.luau` | new: parsing and formatting |
| `src/shared/PlateStyles.luau` | new: the Saudi layouts |
| `src/shared/PlateConfig.luau` | new: prices and tunables |
| `src/shared/CarPlateMounts.luau` | new: plate spots per car |
| `src/client/CarPlates.luau` | new: draws plates on every car |
| `src/server/PlateRegistry.luau` | new: the registry |
| `src/server/PlateService.luau` | new: remotes, default plates, equip |
| `src/server/Economy.luau` | changed: `transact`, the new profile fields, recovery on load |
| `src/client/SpawnMenu.luau` | changed: the Plates tab |
| `src/server/Remotes.luau` | changed: `PlateQuery`, `PlateAction` |
| `src/shared/Tests/PlateText.spec.luau`, `PlateRegistry.spec.luau` | new |
| `tools/carbody/README.md`, `TUNING.md` | a plates section and a measuring step; `PlateConfig` |

`RIG_SPEC.md` is not changed: it is part of the owner's uncommitted rig
rework. The plates contract is documented in `tools/carbody/README.md` until
that rework lands.
