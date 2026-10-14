# Garage and customisation: design

Asked by the owner on 2026-09-28: a garage the player walks into on foot,
which becomes a customisation view with their car on a turntable. The
owner gave the shape and constraints and left the details to us ("self-
ideate ... use your own discretion"); every decision below that was ours
is marked **Decision** with the reason, so it can be overruled.

The UI system (`UI_SYSTEM.md`, `src/shared/UITheme.luau`) came first and is
done (commit 04d232c). Everything here uses it.

## Research this rests on

- **Bodies are built on each client** (`BodyBuilder` via `CarBodies`), from
  the car Model's `CarId` attribute; the server builds only the physics rig.
  So a look must travel as an attribute on the car Model and be applied by
  every client, exactly as the plate does (`Plate` attribute, `CarPlates`
  redraws on change).
- **Paint** is one `Color3` per catalog entry (`body.paint`) applied to
  pieces flagged `paint = true`; 68 of 69 painted pieces are plain meshes
  (SmoothPlastic), one uses a SurfaceAppearance tint mask. Material and
  Reflectance are never set today.
- **Wheels** are per-car `wheelPieces` (tyre + rim meshes sized to the rig's
  wheel radius); nothing swaps them.
- **Lamps**: `CarLamps.apply` lights lens parts found by name from
  `effects.lamps` colours (per car via tuning). An instance override is one
  lookup away.
- **Exhaust**: sound only (`EngineAudio` crackle), and the engine is heard
  **only by the driver**. One car (the hatch) has exhaust tip meshes.
- **World**: the left wing of the transition pad (X −84..−36 m, Z −1700..
  −1300 m) is 48 × 400 m of flat, collidable, empty asphalt, directly across
  the highway from the spawn bay (X 60, Z −1500) and the station.
- **Money**: `Economy.transact` is one locked, copy-mutate-UpdateAsync write.
  Cosmetics are not globally unique, so the plate registry's per-key
  reservation is not needed; the rest of PlateService's discipline is.
- **Light pool**: 12 pooled SpotLights on the client, given to the nearest
  `HajwalaLamp`-tagged parts. Nothing else makes lights except DuneLife's
  campfire PointLights.

## 1. The building

**Decision: on the left pad wing, facing the road**, centred at along-road
1,530 m and 60 m left of the centreline (world X −60, Z −1530). It faces
+X, across the carriageway toward the bay and the station, so it is the
first thing seen on the left when a player spawns, and a player crosses one
carriageway to reach it. Not beside the station: the right wing is full
(bay and station keep-out overlap).

- **Footprint** 26 m along the road × 16 m deep, 6.5 m eaves: two bays side
  by side. The **display bay** (left, 13 m) holds the turntable; the **lift
  bay** (right) holds a car raised on a two-post lift.
- **Front** (road side): a roller-door opening over each bay; the display
  bay's door is open (a walk-through gap 5 m wide × 4 m high, the roller
  shutter rolled up into a box at the lintel), the lift bay's is closed
  with the shutter down. A sign over the doors: `GARAGE` / `كراج` on a
  sodium-lit fascia (UI tokens reused as world colours).
- **Apron**: a painted parking apron on the pad in front, 3 bays marked,
  so "park outside" is obvious. Arrow and `GARAGE` painted on the road
  side.
- **Structure**: sandstone-rendered block walls outside (the station's
  palette), corrugated roof edge, one small high window strip. Walls and
  doors collide; decoration does not (the world's rule).
- **Config-driven**: every dimension, colour and prop placement in
  `WorldConfig.garage`, built by `src/server/World/Garage.luau` from
  primitives, placed with a u/v local frame like the station. A
  `Garage.keepOut` rectangle keeps scatter and dune life off it. Part and
  triangle counts print in a `[World] garage:` line and the tally table.

### Interior (the workshop)

- **Floor**: sealed concrete, lighter than the road. Tyre marks: long thin
  dark arcs (flat parts, 70–85% transparent) sweeping in from the door.
  Oil stains: flat dark cylinders (discs) of 1–2 m, 60–80% transparent, a
  few overlapping under the lift. **Decision:** flat parts, not Decals,
  so no image assets.
- **Strip lighting**: two rows of long Neon strip fittings on the ceiling
  per bay, warm white (`lens` 255, 236, 200), in housings.
- **Walls**: tool boards (pegboard panels with tool silhouettes as thin
  parts: spanners, a hammer, a coil of air hose), steel shelving units with
  tyres and boxes, a red roll cab (tool chest), a workbench with a vice,
  an air compressor, a tyre stack, a jack, a fire extinguisher.
- **Lift bay**: a two-post lift with arms, and a car raised 1.8 m on it
  (**Decision:** a client-built body, because bodies are built on the
  client; the kamri07, stock). Built once when the garage streams in.
- **Display bay**: a turntable: a round steel plate 5.4 m across, flush in
  a shallow ring, with a darker ring edge, in front of a wall painted a
  flat warm grey (a studio-like backdrop so the car reads).

### Light and the live-light cap

**Decision:** while a player is in the customisation view, their client
suspends the world lamp pool (its lights are far away anyway) and lights
the display bay with **four** lights of its own: a key SpotLight above
and in front, a fill SurfaceLight from the backdrop side, a warm rim
SpotLight from behind, and a soft PointLight low under the front for the
lower body. Twelve pooled plus none, or zero pooled plus four: the client
never holds more than `lamps.maxLiveLights` (12). On leaving, the pool
resumes. Outside the view, the garage's strip fittings are tagged
`HajwalaLamp`, so the pool lights them like any lamp when a player stands
near.

The car's paint must read: the key is bright and slightly warm, so gloss
and metallic finishes show a highlight; `Lighting.EnvironmentSpecularScale`
is left as it is (the world's).

## 2. Entering and leaving

- **Threshold**: an invisible, non-colliding box `DoorZone` across the open
  doorway, 0.6 m deep. **Decision:** the client detects its own character's
  root crossing into the interior side (a position test each frame while
  within 12 m of the garage, not Touched events), so there is no server
  round trip before the view starts.
- **Enter**: fade to asphalt950 in 0.2 s; character control off
  (`PlayerModule:GetControls():Disable()`), character hidden
  (LocalTransparencyModifier 1); camera to Scriptable, on its fixed framing;
  the preview car appears on the turntable; the panel slides in; fade back.
- **The car shown**: the player's current car id (`CarId` attribute), with
  that car's saved look. Their real spawned car is untouched and stays
  parked outside.
- **Leave**: a `LEAVE` button (and Esc / B on a gamepad / back on touch):
  fade, restore camera to Custom, controls on, character shown, character
  placed 3 m outside the door facing out, panel slides away.
- **Driving into the garage** does nothing: the zone only reacts to a
  character on foot (not seated). (Superseded by garage round 2 §3: a slow
  drive through the door parks the car and opens the view.)
- **From the car menu** (2026-10-14, the owner: "clicking customize should
  take me to the actual garage"): CUSTOMIZE on the picked car takes you to
  the garage from anywhere, that car on the turntable (`GarageView.visit`).
  On foot it is a walk-in from where you stand; LEAVE stands you at the
  door. Driving your own car it is a drive-in from afar: the server's
  `bringIn` is `driveIn` without the doorway and speed checks, and it stands
  the player beside the parked car (`GarageConfig.visit.standBesideM`) so
  `driveOut` finds them within `leaveRangeM`; LEAVE seats them back in the
  car. In someone else's car, or as a passenger, a notice and nothing
  moves. Far from the garage its parts may be streamed out, so the view
  first asks to stream in around the folder's `DoorPosition` attribute
  (set by the build; the folder itself never streams).

## 3. The view

- **Framing**: one fixed camera, 3/4 front view from the right, the whole
  car in frame with a margin, eye 1.5 m up, FOV 40° (a long lens flattens
  less and flatters the car). The turntable centre sits right of the
  screen's middle so the panel on the left does not cover the car
  (**Decision:** the panel is on the left; the car turns into the right).
  Framing distance is computed from the car's bounding box, so every car
  fits.
- **Turntable**: rotates at 8°/s. Dragging horizontally anywhere outside
  the panel spins it (mouse or touch), with inertia that decays over 1 s;
  the auto-rotation resumes 3 s after the last drag.
- No zoom, no camera presets (owner's brief).

## 4. The panel

- **Left side**, full height, 360 px on desktop, 42% of the width (max
  420 px) on touch, `asphalt900` at 0.06 transparency, radius `lg` on the
  right edge only (it docks to the left edge).
- **Header**: `GARAGE` (display) / `كراج` (sand, right) and the player's
  cash in `price` type.
- **Categories**: a column of icon-less text tabs down the panel's inner
  edge would eat width, so **Decision:** a horizontal scrolling row of
  chips under the header: `MY CARS`, `PAINT`, `WHEELS`, `PLATES`,
  `LIGHTS`, `DECALS`, `EXHAUST`. Selected chip = `button.selected`.
- **Items**: a two-column grid of cards (one column under 340 px): a
  swatch or preview tile, the name (`heading`), and the state badge from
  UI_SYSTEM.md (ON CAR / OWNED / price chip).
- **Live preview**: tapping any card applies it to the turntable car at
  once. Owned items are also **equipped** at once (saved to this car; no
  confirm, no money). Unowned items preview only; the panel's foot shows
  `PREVIEWING · <price> · BUY`.
- **Buying**: `BUY` opens a confirm sheet over the panel (item, price, cash
  after, `BUY` and `CANCEL`). Only `BUY` in the sheet charges. After a buy
  the item is owned and equipped.
- **Leaving with an unbought preview**: the preview is dropped; the car
  goes back to its saved look. Switching category keeps the preview until
  another card is chosen or the view closes.
- **Collapse**: a pill handle on the panel's edge (and the `H` key / a
  gamepad button) slides the panel out; the car re-centres. Tap the handle
  to bring it back.
- **Phone**: every target 48 px, the chips row scrolls with a finger, the
  collapse handle sits at mid-height on the panel edge where a left thumb
  reaches.

### Categories and what they hold

Prices are first guesses for the owner, in the plate economy's range
(plates are 10k–1M). Every category has a free **Stock** item that puts the
car's catalog look back.

| Category | Items (v1) | How it shows on the car |
|---|---|---|
| **My cars** | Every catalog car; the one you are customising is selected. `DRIVE THIS` sets your car (the existing `CarId` switch). | Swaps the turntable car and its saved look. |
| **Paint** | 12 colours (golden-hour-derived and classic: Pearl White, Desert Sand, Sodium Orange, Dune Gold, Asphalt Black, Gantry Green, Beacon Red, Night Blue, Dusk Violet, Silver, Gunmetal, Riyadh Rose) × **finish** chosen in a row above: Gloss, Matte, Metallic, Chrome. Colours cost; Gloss is free, Matte and Metallic cost, Chrome is rare. A colour and a finish are separate items. | `paint = true` pieces: Color, Material (SmoothPlastic / Metal / Foil), Reflectance (per finish, tuned in the lit bay). The SurfaceAppearance piece takes the colour only. |
| **Wheels** | **Decision (v1):** rim finishes on the car's own rims: Stock, Gloss Black, Chrome, Gold, Bronze, Gunmetal, White. New rim meshes are a later pass (they need store meshes vetted per wheel size). | Wheel pieces named `Rim*` (or the Metal wheel piece): Color, Material, Reflectance. |
| **Plates** | The player's owned plates plus their default plate; choosing one puts it on **this car**. Buying plates stays in the Plates tab (the registry flow); a `SHOP PLATES` button opens it. | The car's `Plate` attribute (existing). |
| **Lights** | Headlight colour: Stock, Xenon White, Ice Blue, Halogen Yellow, Amber. Tail colour: Stock, Deep Red, Smoked. | `CarLamps.apply` reads the override before the car's `effects.lamps` colours. |
| **Decals** | **Decision:** a windscreen sun strip across the top of the windscreen, the Gulf tuning signature: None, `هجولة` strip (black), `SUNSET DRIFT` strip, `طارت` strip (sodium), Gradient strip (sodium to dusk). | A SurfaceGui strip on a thin part at a per-car windscreen spot (`CarCosmeticMounts`), like the plates. |
| **Exhaust** | Stock, Single Chrome Tip, Twin Chrome Tips, Quad Tips, Burnt Titanium Twin (rare). Each has a sound profile. | Visible tip cylinders at a per-car rear spot (`CarCosmeticMounts.exhaust`), seen by everyone; the driver hears the profile (engine volume and crackle frequency). |

## 5. Data

### Catalog (shared, `src/shared/CosmeticsConfig.luau`)

```
Item = { id: string, category: Category, name: string, price: number,
         rare: boolean?, data: {...} }   -- data per category
Category = "paint" | "finish" | "rims" | "head" | "tail" | "decal" | "exhaust"
```

Ids are stable strings (`paint_sand`, `finish_matte`, `rims_chrome`, ...);
never renamed once shipped. `stock_*` items cost 0 and are always owned.
Plates are not in this catalog (the registry owns them).

### Profile (server, `Economy`)

- `cosmetics: { string }`: ids the account owns. Per account, not per car.
- `looks: { [carId]: Look }` where `Look = { paint: id?, finish: id?,
  rims: id?, head: id?, tail: id?, decal: id?, exhaust: id?, plate: string? }`.
  Missing = stock. `plate` is a plate key the player owns; missing = the
  account's equipped plate (today's behaviour).
- `readProfile` drops unknown ids and ids the account does not own.
- `encode` merges `cosmetics` as a union with what is stored, so a stale
  save can never un-own an item.
- Published to the owner as Player attributes `Cosmetics` (comma-joined
  ids) and `Looks` (JSON), for the panel.

### On the car (every client)

- The server stamps the car Model's `Look` attribute: the look for that
  car id, as a compact string `paint=paint_sand;finish=finish_matte;...`
  (`CarLook.encode` / `decode`, shared). It is set on spawn and whenever
  the owner saves a change to the car id they are driving, so other
  players see a change at once.
- The per-car plate goes through the existing path: `PlateService` asks
  the look's plate first.
- **Client** `CarCosmetics` applies a look to any built body: on the spawned
  cars (listening to `Look`, after `CarBodies` built the body) and on the
  turntable preview (directly, from the panel's preview state).

### Remotes (server `CosmeticsService`)

- `CosmeticsAction(what, ...)` RemoteFunction:
  - `("equip", carId, category, id)`: id must be owned (or stock) and in
    that category; saves to `looks[carId]`, restamps the car. No money.
  - `("buy", id)`: price from the server catalog, never the client; one
    `Economy.transact` that refuses if already owned or cash < price,
    else takes the cash and adds the id. Returns `{ status }`: `done`,
    `owned`, `cash`, `unavailable`, `busy`, `unknown`.
  - `("plate", carId, plateKey?)`: sets the per-car plate (owned or nil).
- Discipline copied from PlateService: a `ready` gate (refuse until the
  profile loaded and is savable), a per-player rate limit (4 actions/s),
  an `exclusive` per-player lock around each action, server-side validation
  of every argument.

## 6. Files

| New | Purpose |
|---|---|
| `src/shared/CosmeticsConfig.luau` | Catalog, prices, finish values, sound profiles |
| `src/shared/CarLook.luau` | Look type, encode/decode, resolve against the catalog |
| `src/shared/CarCosmeticMounts.luau` | Per-car windscreen strip and exhaust spots |
| `src/server/CosmeticsService.luau` | Remotes, validation, stamping `Look` |
| `src/server/World/Garage.luau` | The building, interior, turntable, door zone |
| `src/client/CarCosmetics.luau` | Apply a look to a built body (paint, rims, decal, exhaust tips, lamp overrides) |
| `src/client/Garage/GarageView.luau` | Threshold, enter/leave, camera, turntable, lights |
| `src/client/Garage/GaragePanel.luau` | The panel |
| `src/client/UIKit.luau` | Token-built components (panel, button, chip, card, badge, sheet) |
| specs | `CosmeticsConfig.spec`, `CarLook.spec` |

| Changed | How |
|---|---|
| `Economy.luau` | `cosmetics`, `looks`; `buyCosmetic`, `setLook` |
| `PlateService.luau` | Per-car plate from the look first |
| `CarLamps.luau` | Colour override from the look |
| `EngineAudio.luau` | Exhaust sound profile from the look (driver only) |
| `CarBodies.luau` | Call `CarCosmetics` after a body is built |
| `World/init.luau`, `WorldConfig.luau` | Build and tally the garage; `garage` config |
| `Remotes.luau`, `init.server.luau`, `init.client.luau` | Wiring |
| `SpawnMenu`, `PlatesPanel`, `SettingsPanel`, `Hud`, `LoadCover` | Re-skinned on UITheme (owner: every UI uses the tokens) |
| Docs | WORLD.md (garage), TUNING.md (garage, cosmetics), UI_SYSTEM.md |

Untouched: `VehicleSim`, scoring, handling. Nothing cosmetic changes a
physics value.

## 7. Testing

- Specs: catalog integrity (unique ids, categories, stock items free),
  look encode/decode round trip and rejection of junk, prices server-side.
- Studio, Play: walk in through the door, check the view, spin, collapse,
  preview, buy with confirm, equip, leave; a second look at the spawned car
  showing the saved look; phone layout with `ForceTouch`.
- Screenshots: the building from the bay, the interior, the view with the
  panel, desktop and phone.
- Numbers: garage part and triangle counts; the live-light count in the
  view (≤ 12); frame time in the view.
