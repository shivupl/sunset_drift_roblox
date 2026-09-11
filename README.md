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
| Throttle / Brake (brake at a stop = reverse) | W / S | RT / LT | GAS / BRAKE (right) |
| Steer | A / D | left stick | < > (left) |
| Handbrake | Space | B | HAND |
| Clutch kick | Shift (tap) | X | KICK |
| Two-wheel / lean left | Q (hold) | LB (hold) | NATL, then LEAN< |
| Two-wheel / lean right | E (hold) | RB (hold) | NATL, then LEAN> |
| Exit car | F | Y | EXIT |
| Reset car (upright, nearest road point; back to the start if past the road) | R | Back | RESET |
| Reload CarConfig | L | — | RELOAD |

## Two-wheel ("natl")
Get above about 45 km/h first; nothing lifts at parking speed, and the lift is full from 80.
Holding Q or E puts the car up: the key you hold picks the side, so Q climbs onto the left pair.
Once it is up, balance by tapping: each press of the opposite key lands a full catch that fades
if you keep holding, so tap against the lean rather than leaning on the key. Steering still
steers, and it is the strongest lever up there: a small turn toward the low side drops the car,
away lifts it. With gas on the car runs straight (open diff, so the grounded rear barely drives).
If you slow to a crawl the car settles back onto four wheels by itself. Release both keys to land.

Touch is the exception, because the lean buttons cannot be on screen before the mode exists:
hold NATL to open it and a LEAN< / LEAN> pair appears inboard of the throttle cluster. The
first lean button you reach for still picks the side, as long as the car is not up yet.

## Phone test in Studio
Test → Device → pick a phone → Play. Touch buttons appear because the emulator reports
TouchEnabled: steer and NATL on the left, GAS/BRAKE/HAND/KICK on the right, the LEAN pair
inboard of GAS while two-wheel is live, EXIT/RESET/RELOAD along the top. Not verified on a
real phone or in the device emulator in this pass. Note the ergonomics: NATL sits under the
left thumb and the LEAN pair under the right, so leaning means coming off GAS.

## Drift feedback
Smoke off the rear tires, skid marks, and wheels that spin up or lock, all driven by the
sim's per-wheel slip and saturation. Tunables live under `effects` in CarConfig; set
`effects.enabled = false` on a weak phone. Sound is wired but silent until you paste asset ids you
own into `effects.screechSoundId` and `effects.engineSoundId`.

## Debug panel
Top-left while driving: speed, gear, rpm, inputs and available lock, drift angle, yaw rate, a
SPINS counter for completed 360s, two-wheel mode and roll with margin to tip, per-wheel slip
angle / load / SPIN or AIR, handbrake, kick, assist.

## Tafheet moves
Ta'geed (360): at 110 km/h or more, full lock and HAND together, and keep HAND held the whole
way round with the gas on. A tap will not do it: once the car is going backwards the rears grip
again and stop the rotation, a held handbrake keeps them locked and it comes round in about
3.5 s. Let go as the SPINS counter ticks and catch it. Sefty: the same, a short straight slide,
then the other way.

## Tuning
All numbers live in `src/shared/CarConfig.luau`; `TUNING.md` explains every field and which
way to move it. Press L in play to reload without rejoining. Verified: a Source change on the
server replicates to the client at runtime and L re-requires on both sides. Editing the module
inside Studio's script editor during play works with the reload key. Whether the Rojo plugin
pushes file edits into a running play session was not verified in this pass (the plugin was
installed but not connected during development); if it does not, edit the module in Studio
during play, or stop and replay after saving the file.

## Where things are
- `src/shared/VehicleSim/` — the physics: Suspension, Tire, Drivetrain, TwoWheel (pure) and
  `init.luau` (Roblox glue). `DESIGN.md` explains the choices.
- `src/server/` — road, car builder, spawner (seat, ownership, self-healing), remotes.
- `src/client/` — input (keyboard, gamepad, touch), vehicle controller, camera, debug panel.
- `src/shared/Tests/` — spec runner (102 assertions). Run it from `scripts/studio_tests.luau`,
  which clones the Shared folder first; requiring `Shared.Tests` directly can re-run stale code
  because Studio caches modules per instance and editing Source does not always invalidate it.

## Developer tooling
- `scripts/analyze.sh` — luau-lsp strict analysis over `src` with Roblox types.
- `scripts/mcp_sync.py --manifest` + `scripts/studio_loader.luau` — mirrors `src` into a Studio
  DataModel over a local HTTP server (`python3 -m http.server 8765 --bind 127.0.0.1`) without
  the Rojo plugin. Used with the Studio MCP during development; Rojo is the real path.
