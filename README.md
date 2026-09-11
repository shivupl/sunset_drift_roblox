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
3. Press Play. The server builds the road, deletes the baseplate, and parks a white car
   with a red hood stripe in the bay behind the start line. You spawn beside it.
4. Walk up and press E (or tap the prompt on touch). The debug panel appears and the
   chase camera takes over. E again gets out.

## Controls
| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Throttle / Brake | W / S | RT / LT | GAS / BRAKE (right thumb) |
| Steer | A / D | left stick | steer pad (left thumb, position = angle, slide to counter-steer) |

That is the whole control set: steer, throttle, brake, handbrake, two-wheel, lean, reset,
exit, reload. There is no clutch kick and no shifter.

## Gears and reverse
The gearbox is automatic and there is nothing to shift. Reverse is not a gear you select
either: hold the brake for `drivetrain.reverseHoldSeconds` (0.4 s) after the car has already
stopped and it engages, and any throttle puts you back in drive. The hold is why braking hard
to a standstill stays in drive instead of snapping into reverse the moment the car settles.
| Handbrake | Space | B | HAND |
| Two-wheel / lean left | Q (tap) | LB (tap) | NATL (tap), then lean slider left |
| Two-wheel / lean right | E (tap) | RB (tap) | NATL (tap), then lean slider right |
| Exit car | F | Y | EXIT |
| Reset car (upright, nearest road point; back to the start if past the road) | R | Back | RESET |
| Reload CarConfig | L | — | LOAD |
| Toggle debug panel | — | — | DBG |

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

Touch is the exception, because the lean control cannot be on screen before the mode exists:
tap NATL to open it (it stays on, so the thumb is free) and the lean slider appears directly
above the steer pad. The first direction you push it picks the side, as long as the car is
not up yet. NATL switches itself off when the car lands; tap it again to lift.

## Phone test in Studio
Test → Device → pick a phone → Play. The touch HUD is our own ScreenGui, and Roblox's
thumbstick and jump button are hidden while driving. Left half: the steer pad along the
bottom, the lean slider directly above it, NATL above that. Right half: GAS in the corner
with BRAKE inboard, and HAND directly above GAS so the thumb slides between throttle and
handbrake without lifting. EXIT / RESET / LOAD / DBG sit small along the top, right of the
speed readout.

Both sliders are positional and spring back to centre. The steer pad is analog: where the
thumb sits is the angle, the ends are full lock, and sliding across is a counter-steer
without lifting. The lean slider only appears once the car is in two-wheel mode, and it is
digital past `input.touchLeanDeadzone`, because balancing wants taps rather than a held axis,
so flick it out and let it snap back. Sizes scale with the screen height and
`input.touchScale`. To see the touch HUD on a desktop session, set the LocalPlayer attribute
`ForceTouch = true` before getting in.

## Driver HUD
Top centre on every platform: speed and gear, the slide in progress with its chain
multiplier, then drift angle, SPINS while a 360 is under way, NATL roll while on two wheels,
and a bottom line with your cash, your session best and the server best with its holder.
A completed 360 flashes "360! +500" beside the live counter. When a slide ends the row shows
what the server banked and what it paid, or DROPPED if you lost it. `hud.enabled` turns the
whole thing off.

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
`effects.enabled = false` on a weak phone. Sound uses two free Creator Store loops (a Roblox
Resources engine loop and a skid loop); swap the ids in `effects.screechSoundId` and
`effects.engineSoundId` for your own.

## Debug panel
Top-left while driving on PC; hidden on phones until you tap DBG (`debug.showOnTouch` flips
the default). Speed, gear, rpm, inputs and available lock, drift angle, yaw rate, a SPINS
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
All numbers live in `src/shared/CarConfig.luau`; `TUNING.md` explains every field and which
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
- `src/server/` — road, car builder, spawner (seat, ownership, self-healing), remotes.
- `src/server/World/` — the highway environment; `World/City/` the city section off the
  off-ramp. `WORLD.md` explains both.
- `src/client/` — input (keyboard, gamepad, touch HUD), vehicle controller, camera, driver HUD, debug panel.
- `src/shared/Tests/` — spec runner (252 assertions). Run it from `scripts/studio_tests.luau`,
  which clones the Shared folder first; requiring `Shared.Tests` directly can re-run stale code
  because Studio caches modules per instance and editing Source does not always invalidate it.

## Developer tooling
- `scripts/analyze.sh` — luau-lsp strict analysis over `src` with Roblox types.
- `scripts/mcp_sync.py --manifest` + `scripts/studio_loader.luau` — mirrors `src` into a Studio
  DataModel over a local HTTP server (`python3 -m http.server 8765 --bind 127.0.0.1`) without
  the Rojo plugin. Used with the Studio MCP during development; Rojo is the real path.
