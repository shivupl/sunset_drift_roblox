# Hajwala — Phase 0

Saudi hajwala drift feel on Roblox. Phase 0 is one car and one flat road.

## Setup
1. Install Rokit: `curl -fsSL https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash`
2. `rokit install` in this folder (installs the pinned Rojo and luau-lsp).
3. `rojo plugin install` (puts the Rojo plugin in Studio's local plugins folder; restart Studio once).

## Run
1. `rojo serve` in this folder.
2. Open Roblox Studio, open any place (a baseplate is fine), Rojo toolbar → Connect (localhost:34872).
3. Press Play. The server builds the road and parks a car for you. Walk up, press E (or tap the prompt) to get in.

## Controls
| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Throttle / Brake | W / S | RT / LT | GAS / BRAKE (right) |
| Steer | A / D | left stick | < > (left) |
| Handbrake | Space | B | HAND |
| Clutch kick | Shift (tap) | X | KICK |
| Two-wheel | F (hold) | Y (hold) | NATL |
| Exit car | E | LB | EXIT |
| Reset car | R | Back | RESET |
| Reload CarConfig | L | — | RELOAD |

## Tuning
All numbers live in `src/shared/CarConfig.luau`. See `TUNING.md` for what each one does.
Press L in play to reload the config without rejoining. Whether Rojo pushes file edits into a
running play session is noted below once verified; editing the module inside Studio's script
editor during play always works with the reload key.

## Phone test in Studio
Test → Device → pick a phone → Play. Touch buttons appear because the emulator reports TouchEnabled.

## Strict type check without Studio
`scripts/analyze.sh` runs luau-lsp over `src` with Roblox types.

## Fallback sync without the Rojo plugin
`scripts/mcp_sync.py --out DIR` emits Luau chunks that mirror `src` into a Studio DataModel with the
same tree as `default.project.json`. Used by the Studio MCP during development; Rojo is the real path.
