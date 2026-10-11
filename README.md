# Hajwala — Phase 0

Saudi hajwala drift feel on Roblox. Phase 0 is one car and one flat road.

## Setup (once)
1. Install Rokit: `curl -fsSL https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash`
2. In this folder: `rokit install` (installs the pinned Rojo 7.7 and luau-lsp).
3. `rojo plugin install`, then restart Roblox Studio so it loads the plugin.

## Play
1. In this folder: `rojo serve`
2. Studio: open any place (a baseplate is fine). Rojo toolbar → Connect (localhost:34872).
   The tree appears under ReplicatedStorage/Shared, ServerScriptService/Server and
   StarterPlayer/StarterPlayerScripts/Client.
3. Press Play. The server builds the world and you start on foot beside the parking bay,
   with the spawn menu open.
4. Tap or click a car (anywhere on its card) to spawn it. It is built in your bay slot with you in the driver's seat,
   and the chase camera takes over. M (or the CARS button at the bottom of the screen)
   opens the menu again at any time; spawning while driving swaps the car you are in.
   F gets out; walk up to a parked car and press E to get back in.

## Controls
| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Throttle / Brake | W / S | RT / LT | GAS / BRAKE (right thumb) |
| Steer | A / D | left stick | ◀ / ▶ buttons (left thumb; held, they ramp to full lock like the keys) |

That is the whole control set: steer, throttle, brake, handbrake, two-wheel, lean, reset,
exit, reload. There is no clutch kick and no shifter.

## Gears and reverse
The gearbox is automatic and there is nothing to shift. Reverse is not a gear you select
either: hold the brake for `drivetrain.reverseHoldSeconds` (0.4 s) after the car has already
stopped and it engages, and any throttle puts you back in drive. The hold is why braking hard
to a standstill stays in drive instead of snapping into reverse the moment the car settles.
| Handbrake | Space | B | HAND |
| Two-wheel / lean left | Q (tap) | LB (tap) | NATL over ◀ (tap) |
| Two-wheel / lean right | E (tap) | RB (tap) | NATL over ▶ (tap) |
| Exit car | F | Y | EXIT |
| Spawn menu (choose / respawn a car) | M | — | CARS (top bar) |
| Reset car (upright, nearest road point; back to the start if past the road) | R | Back | RESET |
| Reload CarConfig | L | — | — |
| HUD style (finish) | U | — | STYLE |

## Two-wheel ("natl")
Get to 90 km/h first; nothing lifts below that. Tap Q or E and the car throws itself up on
that side, big, to around 50 degrees. It wants to come back down: the first tap gets it up, and
you keep it up by tapping the same key every second and a half or so, because gravity is only
mostly cancelled and an ignored car drops back onto four wheels in about three seconds. Do
not hold the key: leaning on it keeps pushing and the car goes over in about a second. Keep
the speed up too; below 90 the hold fades and the car settles down even while you tap. Tap
the other key to catch it if it climbs too far; hold that key and the car lands at once.
Steering still steers, and it is the strongest lever up there: a small turn toward the low side
drops the car, away lifts it. With gas on the car runs straight (open diff, so the grounded rear
barely drives). If you slow to a crawl the car settles back onto four wheels by itself.

On a phone the two NATL buttons are Q and E: NATL◀ over ◀, NATL▶ over ▶, the way Q and E
sit over A and D, so the right thumb stays on the gas. They show up once the car is fast
enough to lift and stay while it is up, and the side it is up on is lit.

## Phone test in Studio
Test → Device → pick a phone → Play. The touch controls are our own ScreenGui
(`src/client/HudLab/LayoutD.luau`), and Roblox's thumbstick and jump button are hidden while
driving. Bottom left: the two round steer buttons, a NATL button over each (above lift
speed). Bottom right: the tall GAS in the corner, BRAKE left of it, a round HAND button over
the brake. Top right: EXIT, RESET and STYLE, left of the cash. Everything is sized and
spaced from the screen's height and kept inside the phone's safe area, and every control's
hit box is the shape you see.

The pedals give part throttle low on the plate. At rest the controls let a little of the
road through; under a thumb they go solid. To see the touch controls on a desktop session,
set the LocalPlayer attribute `ForceTouch = true` before getting in.

## Driver HUD
Layout D (`src/client/HudLab`) in one of three finishes, STREET D, SODIUM or CARBON (STYLE
on a phone, U on a keyboard, or Settings > HUD STYLE): a small see-through tacho bottom middle with the gear and
the speed; your cash top right, with your session best and the server best; and, while you
slide, a drift board top middle with the points, the chain multiplier and the angle as a bar.
Under the board a thin bar drains while the slide is between swings: the grace left to link
the next one before it banks. On two wheels the board shows the roll instead of the angle, its
bar filling toward the tip and turning amber, then red, as the margin runs out. Each move is
stamped just left of the car as it ends, in tafheet's own words: a 360 as it comes round
(تخميسة!, a spin, with its bonus), two wheels as the car lands (ترفيع!, with the time up, a
second or more and not tipped), a chain of x3 or more as it banks (هجولة!, drifting itself).
The screen's edges glow with the chain. When a slide ends the board shows what the server banked, or DROPPED if you lost it.
`hud.enabled` turns the whole thing off.

## Scoring and cash
A slide opens past `scoring.minAngleDeg` of drift above `scoring.minSpeedKmh` and pays angle
x speed x time. Every direction change inside the slide steps the multiplier, and the grace
window is what links a left-right swing into one long slide instead of two short ones. A full
360 inside the slide adds `scoring.spinBonusPoints` times the multiplier; a 720 adds it twice.
Two wheels score too: past `scoring.natlMinRollDeg` of roll the run pays
`scoring.natlPointsPerSecond` scaled by speed, on top of anything the drift angle is earning.
Going straight banks it and converts to cash at `scoring.cashPerPoint`. Hitting something
hard, or spinning to a stop without ever straightening up, drops the run.

The client scores the car for the live HUD, but the server scores every driven car
independently from replicated physics and pays out the smaller of your claim and what it saw
times `scoring.serverTolerance`. Nothing a client sends can raise a balance. Cash and records
reach the client only as replicated attributes.

Cash persists through a DataStore. In Studio that needs Game Settings → Security → Enable
Studio Access to API Services; without it you get a "profile load failed, playing without
saving" warning and the session runs with no persistence, which is deliberate — a profile
whose load failed is never saved over.

## Drift feedback
Smoke off the rear tires, skid marks, and wheels that spin up or lock, all driven by the
sim's per-wheel slip and saturation. Tunables live under `effects` in CarConfig; set
`effects.enabled = false` on a weak phone. The tyre screech is a free Creator Store skid
loop (`effects.screechSoundId`). The engine (client `EngineAudio`) is four layers, idle, low
load, high load and overrun, crossfaded by the sim's rpm and throttle; for now all four are
one free engine loop told apart by EQ. Paste a matched loop pack's ids and recorded rpm into
`effects.engineAudio.layers`.

## Debug panel
Top-left while driving on PC; hidden on phones unless `debug.showOnTouch`. Speed, gear, rpm, inputs and available lock, drift angle, yaw rate, a SPINS
counter for completed 360s, two-wheel mode and roll with margin to tip, per-wheel slip
angle / load / SPIN or AIR, handbrake, assist.

## Tafheet moves
The lever is permission and the wheel is the dial. With HAND held, how far you turn the wheel
is how fast the car comes round; centre it and the car holds whatever angle it has; turn the
other way and the angle comes back. Let go of HAND and the car catches itself.

Held slide: at 100 km/h pull HAND, tap the wheel to one side for a moment and centre it. The
car settles at 25 to 40 degrees and stays there. Now let the lever go and keep the gas
floored: the gas holds the slide with the rear gripping again, so it barely loses speed.
Flick the wheel the other way for half a second and centre it and the car swings through and
holds the other side; keep going and the chain multiplier climbs. Lift the gas and the car
comes back to straight on its own. Counter-steer at any point to bring the angle down.

Ta'geed (360): at 110 km/h or more, full lock and HAND together, gas on, and keep both until
the SPINS counter ticks (about 2.7 s), then let go and the car straightens. It exits around
75 km/h, so a 720 from 110 crawls through its second turn and exits under 50; from 150 it
comes round twice with speed to spare. Let go of everything at any angle and the car brings
itself back to straight, the short way, in a second or two, never ending up backwards. Sefty: a held slide, then full opposite lock under
the lever swings it through to the other side in about a second, and centring holds it there.

## Tuning
Shared handling lives in `src/shared/CarConfig.luau` and per-car geometry in `src/shared/CarCatalog.luau`; `TUNING.md` explains every field and which
way to move it. Press L in play to reload without rejoining. Verified: a Source change on the
server replicates to the client at runtime and L re-requires on both sides. Editing the module
inside Studio's script editor during play works with the reload key. Whether the Rojo plugin
pushes file edits into a running play session was not verified in this pass (the plugin was
installed but not connected during development); if it does not, edit the module in Studio
during play, or stop and replay after saving the file.

## Where things are
- `src/shared/VehicleSim/` — the physics: Suspension, Tire, Drivetrain, TwoWheel, Throw (the
  360 / held-slide / catch controller), all pure, and `init.luau` (Roblox glue). `DESIGN.md`
  explains the choices.
- `src/shared/CarCatalog.luau` — every car: its rig numbers, its body meshes, its tuning overrides.
  Adding a car is an entry here plus meshes; `RIG_SPEC.md` is the contract.
- `src/shared/VehicleRig.luau` — the rig/body contract in code: names, geometry, validation.
- `src/server/` — road, RigBuilder (physics parts), spawner (car choice, seat, ownership,
  self-healing), remotes.
- `src/shared/BodyBuilder.luau`, `MeshData.luau`, `CarMeshes/` — car bodies, mounted by every
  client (`src/client/CarBodies.luau`); `WheelVisuals.luau` moves the wheels of cars the client is
  not driving. Generated bodies come from `tools/carbody` (RIG_SPEC.md §7b). They need the
  experience's "Allow Mesh / Image APIs" setting on, or their OBJ meshes imported as assets.
- `src/server/World/` — the highway environment; `World/City/` the city section off the
  off-ramp. `WORLD.md` explains both.
- `src/client/` — input (keyboard, gamepad, touch HUD), vehicle controller, camera, driver HUD, debug panel.
- `src/shared/Tests/` — spec runner (347 assertions). Run it from `scripts/studio_tests.luau`,
  which clones the Shared folder first; requiring `Shared.Tests` directly can re-run stale code
  because Studio caches modules per instance and editing Source does not always invalidate it.

## Developer tooling
- `scripts/analyze.sh` — luau-lsp strict analysis over `src` with Roblox types.
- `scripts/mcp_sync.py --manifest` + `scripts/studio_loader.luau` — mirrors `src` into a Studio
  DataModel over a local HTTP server (`python3 -m http.server 8765 --bind 127.0.0.1`) without
  the Rojo plugin. Used with the Studio MCP during development; Rojo is the real path.
