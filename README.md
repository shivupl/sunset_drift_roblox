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
| Two-wheel (hold; steer picks the side) | F | Y | NATL |
| Exit car | E | LB | EXIT |
| Reset car (upright, nearest road point; back to the start if past the road) | R | Back | RESET |
| Reload CarConfig | L | — | RELOAD |

## Phone test in Studio
Test → Device → pick a phone → Play. Touch buttons appear because the emulator reports
TouchEnabled: steer and NATL on the left, GAS/BRAKE/HAND/KICK on the right, EXIT/RESET/RELOAD
along the top. Not yet verified on a real phone in this pass.

## Debug panel
Top-left while driving: speed, gear, rpm, inputs, drift angle, yaw rate, two-wheel mode and
roll with margin to tip, per-wheel slip angle / load / SPIN or AIR, handbrake, kick, assist.

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
- `src/shared/Tests/` — spec runner. In Studio: `require(game.ReplicatedStorage.Shared.Tests)()`
  (93 assertions).

## Developer tooling
- `scripts/analyze.sh` — luau-lsp strict analysis over `src` with Roblox types.
- `scripts/mcp_sync.py --manifest` + `scripts/studio_loader.luau` — mirrors `src` into a Studio
  DataModel over a local HTTP server (`python3 -m http.server 8765 --bind 127.0.0.1`) without
  the Rojo plugin. Used with the Studio MCP during development; Rojo is the real path.
