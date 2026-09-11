# Phase 0 Vehicle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One rear-wheel-drive sedan on a flat 2 km road with raycast suspension, a slip-angle tire model, handbrake and clutch-kick drift initiation, a holdable two-wheel mode, keyboard/gamepad/touch input, a chase camera, and an on-screen debug panel, all tunable from one CarConfig module.

**Architecture:** The car is one rigid assembly (chassis box + hidden ballast + massless visual wheels + VehicleSeat). A shared `VehicleSim` module raycasts each corner, computes suspension, tire, drivetrain, aero, gravity-correction and two-wheel forces in SI units, and writes the sum to one VectorForce and one Torque on the chassis. The client runs the sim for the car it has network ownership of; the server runs it with zero input for parked cars. Server owns spawning, seating, ownership and reset.

**Tech Stack:** Roblox Luau (`--!strict` everywhere), Rojo 7 via Rokit, no Wally packages, git. Testing: pure modules have spec files run by `ReplicatedStorage.Shared.Tests` inside Studio; physics is verified by driving the car through the Roblox Studio MCP (`execute_luau`, `start_stop_play`, `screen_capture`) and by the owner on keyboard and phone.

**Spec:** `docs/superpowers/specs/2026-09-10-phase0-vehicle-design.md`

## Global Constraints

- Every `.luau` file starts with `--!strict`.
- No deprecated body movers: no BodyVelocity, BodyGyro, BodyPosition, BodyForce, BodyThrust, BodyAngularVelocity. Only VectorForce, Torque, Weld, raycasts.
- Do not invent Roblox APIs. Every API used here is listed with its docs page in the task that first uses it. If unsure, check https://create.roblox.com/docs.
- `workspace.Gravity` stays at 196.2. The car's effective gravity is `CarConfig.units.gravity` (default 9.81 m/s²) applied through a counter-force inside the sim only.
- Units: config in SI. `CarConfig.units.metersPerStud = 0.28`. Mass in Roblox mass units equals kg. Force to sim: `N / metersPerStud`. Torque to sim: `Nm / metersPerStud²`.
- Rojo mapping: `src/server → ServerScriptService/Server`, `src/client → StarterPlayer/StarterPlayerScripts/Client`, `src/shared → ReplicatedStorage/Shared`.
- Body axes: chassis `LookVector` (−Z) is forward, `RightVector` (+X) is right, `UpVector` (+Y) is up. Front wheels are at −Z. Cylinder parts have their axis along X, which is the car's lateral axis, so wheels need no extra rotation.
- Sign conventions: steer +1 = right. Roll +deg = right side lower. Slip angle +deg = contact patch moving to the right of the wheel heading, producing a negative (leftward) lateral force.
- Mobile from day one: every action has a touch button.
- Commit after every task with a message starting `feat:`, `fix:`, `test:` or `docs:`, ending with the Co-Authored-By and Claude-Session trailers used in this repo's history.

## Roblox APIs used (all current, none deprecated)

| API | Docs |
|---|---|
| `WorldRoot:Raycast(origin, direction, RaycastParams)` | https://create.roblox.com/docs/reference/engine/classes/WorldRoot#Raycast |
| `RaycastParams`, `FilterType = Enum.RaycastFilterType.Exclude` | https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams |
| `BasePart.AssemblyLinearVelocity/AssemblyAngularVelocity/AssemblyMass/AssemblyCenterOfMass` | https://create.roblox.com/docs/reference/engine/classes/BasePart |
| `BasePart:SetNetworkOwner(player)`, `SetNetworkOwnershipAuto()` | https://create.roblox.com/docs/physics/network-ownership |
| `VectorForce` (`Force`, `ApplyAtCenterOfMass`, `RelativeTo`, `Attachment0`) | https://create.roblox.com/docs/reference/engine/classes/VectorForce |
| `Torque` (`Torque`, `RelativeTo`, `Attachment0`) | https://create.roblox.com/docs/reference/engine/classes/Torque |
| `Weld` (`Part0`, `Part1`, `C0`, `C1`) | https://create.roblox.com/docs/reference/engine/classes/Weld |
| `Model:PivotTo(cf)` / `GetPivot()` | https://create.roblox.com/docs/reference/engine/classes/PVInstance |
| `VehicleSeat.Occupant`, `Seat:Sit(humanoid)` | https://create.roblox.com/docs/reference/engine/classes/VehicleSeat |
| `ProximityPrompt.Triggered` | https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt |
| `ContextActionService:BindActionAtPriority`, `SetPosition`, `SetTitle`, `GetButton` | https://create.roblox.com/docs/reference/engine/classes/ContextActionService |
| `UserInputService.TouchEnabled/KeyboardEnabled/GamepadEnabled` | https://create.roblox.com/docs/reference/engine/classes/UserInputService |
| `RunService.PreSimulation`, `RenderStepped` | https://create.roblox.com/docs/reference/engine/classes/RunService |
| `Humanoid:SetStateEnabled`, `Humanoid.Sit`, `Humanoid.SeatPart` | https://create.roblox.com/docs/reference/engine/classes/Humanoid |
| `PhysicalProperties.new(density, friction, elasticity)` | https://create.roblox.com/docs/reference/engine/datatypes/PhysicalProperties |
| `Instance:SetAttribute/GetAttribute` | https://create.roblox.com/docs/reference/engine/classes/Instance#SetAttribute |

## File structure

```
rokit.toml                         pins rojo (+ luau-lsp for offline strict analysis)
default.project.json               Rojo tree
scripts/analyze.sh                 luau-lsp strict analysis over src (best effort)
README.md
DESIGN.md                          plain-language physics choices
TUNING.md                          field-by-field tuning guide
src/shared/Types.luau              InputState, WheelState, VehicleState, newInput()
src/shared/Units.luau              stud/metre and force/torque conversions
src/shared/Curve.luau              piecewise-linear lookup
src/shared/CarConfig.luau          all tunables, exports type Config
src/shared/ConfigLoader.luau       current() / reload() via ModuleScript clone
src/shared/Tests/init.luau         spec runner: require(...Shared.Tests)()
src/shared/Tests/Curve.spec.luau
src/shared/Tests/Units.spec.luau
src/shared/Tests/Suspension.spec.luau
src/shared/Tests/Tire.spec.luau
src/shared/Tests/Drivetrain.spec.luau
src/shared/Tests/TwoWheel.spec.luau
src/shared/VehicleSim/init.luau    Roblox glue: raycasts, force summation, wheel visuals, VehicleState
src/shared/VehicleSim/Suspension.luau   pure
src/shared/VehicleSim/Tire.luau         pure
src/shared/VehicleSim/Drivetrain.luau   pure
src/shared/VehicleSim/TwoWheel.luau     pure
src/server/init.server.luau        entry: road, remotes, spawner
src/server/Remotes.luau            creates RemoteEvents under ReplicatedStorage/Remotes
src/server/RoadBuilder.luau
src/server/CarBuilder.luau
src/server/CarSpawner.luau
src/client/init.client.luau        entry: waits for remotes, wires controller
src/client/Input/init.luau         InputState aggregation, ramps, attribute override
src/client/Input/Keyboard.luau
src/client/Input/Gamepad.luau
src/client/Input/Touch.luau
src/client/VehicleController.luau  runs VehicleSim on the owned car
src/client/CameraRig.luau
src/client/DebugPanel.luau
```

---

### Task 1: Toolchain, Rojo project, entry scripts, README, sync verified

**Files:**
- Create: `rokit.toml`, `default.project.json`, `.gitignore`, `README.md`, `scripts/analyze.sh`
- Create: `src/server/init.server.luau`, `src/client/init.client.luau`, `src/shared/Types.luau` (stub, replaced in Task 2)

**Interfaces:**
- Produces: a Studio place where `ReplicatedStorage.Shared`, `ServerScriptService.Server`, `StarterPlayer.StarterPlayerScripts.Client` exist and sync from disk.

- [ ] **Step 1: Install Rokit and pin Rojo**

```bash
cd /Users/home/Desktop/Roblox_Arabdrift
curl -fsSL https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
export PATH="$HOME/.rokit/bin:$PATH"
rokit init
rokit add rojo-rbx/rojo
rokit add JohnnyMorganz/luau-lsp   # optional; if it fails, remove the line from rokit.toml
rokit install
rojo --version
```
Expected: `Rojo 7.x.y`. If the rokit install script URL fails, download the release zip from https://github.com/rojo-rbx/rokit/releases for the machine's arch (`uname -m`) and put `rokit` in `~/.rokit/bin`.

- [ ] **Step 2: Write `default.project.json`**

```json
{
  "name": "Hajwala",
  "tree": {
    "$className": "DataModel",
    "ServerScriptService": {
      "Server": { "$path": "src/server" }
    },
    "ReplicatedStorage": {
      "Shared": { "$path": "src/shared" }
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "Client": { "$path": "src/client" }
      }
    }
  }
}
```

- [ ] **Step 3: Write `.gitignore`**

```
*.rbxl
*.rbxlx
*.rbxl.lock
/build/
/globalTypes.d.luau
.DS_Store
```

- [ ] **Step 4: Write entry scripts and a stub shared module**

`src/server/init.server.luau`:
```lua
--!strict
print("[Hajwala] server boot")
```
`src/client/init.client.luau`:
```lua
--!strict
print("[Hajwala] client boot")
```
`src/shared/Types.luau`:
```lua
--!strict
local Types = {}
return Types
```

- [ ] **Step 5: Write `scripts/analyze.sh` (best-effort strict type check without Studio)**

```bash
#!/usr/bin/env bash
# Runs luau-lsp strict analysis over src using Roblox global types.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.rokit/bin:$PATH"
if ! command -v luau-lsp >/dev/null; then echo "luau-lsp not installed (rokit add JohnnyMorganz/luau-lsp)"; exit 0; fi
if [ ! -f globalTypes.d.luau ]; then
  curl -fsSL -o globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
fi
luau-lsp analyze --definitions=globalTypes.d.luau --base-luaurc=.luaurc --sourcemap=sourcemap.json src
```
Also write `.luaurc`:
```json
{ "languageMode": "strict", "aliases": {} }
```
Generate the sourcemap when analyzing: `rojo sourcemap default.project.json -o sourcemap.json` (add this line before the analyze call in the script). Note: with the Rojo sourcemap, `script.Parent.X` requires resolve.

- [ ] **Step 6: Install the Rojo Studio plugin and serve**

```bash
rojo plugin install
rojo serve default.project.json
```
Expected: `Rojo server listening: Address: localhost Port: 34872`. Run serve in the background (`run_in_background`).

Studio: if the Rojo toolbar does not appear, restart Studio. Click Rojo → Connect (defaults localhost:34872). If the MCP session can reach the Studio window, the Connect button can be clicked via `screen_capture` + `user_mouse_input`; otherwise ask the owner to click it.

- [ ] **Step 7: Verify sync through the MCP**

Run via `execute_luau` (Edit datamodel):
```lua
local ok = game.ReplicatedStorage:FindFirstChild("Shared") ~= nil
	and game.ServerScriptService:FindFirstChild("Server") ~= nil
	and game.StarterPlayer.StarterPlayerScripts:FindFirstChild("Client") ~= nil
return "synced=" .. tostring(ok)
```
Expected: `synced=true`. Then `start_stop_play` → Play, `get_console_output` shows both boot prints, stop.

- [ ] **Step 8: Verify whether Rojo pushes edits into a running play session**

While play is running: edit `src/shared/Types.luau` to add `Types.MARK = 1`, save, wait 2 s, then `execute_luau` in the Server datamodel:
```lua
return game.ReplicatedStorage.Shared.Types.Source:find("MARK") ~= nil
```
Record the result (true or false) for README's reload section. Revert the edit.

- [ ] **Step 9: Write README.md**

```markdown
# Hajwala — Phase 0

Saudi hajwala drift feel on Roblox. Phase 0 is one car and one flat road.

## Setup
1. Install Rokit: `curl -fsSL https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash`
2. `rokit install` in this folder (installs the pinned Rojo).
3. `rojo plugin install` (puts the Rojo plugin in Studio's local plugins folder; restart Studio once).

## Run
1. `rojo serve` in this folder.
2. Open Roblox Studio, open any place (a baseplate is fine), Rojo toolbar → Connect.
3. Press Play. The server builds the road and parks a car for you. Walk up, press E (or tap the prompt) to get in.

## Controls
| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Throttle / Brake | W / S | RT / LT | buttons right |
| Steer | A / D | left stick | buttons left |
| Handbrake | Space | B | button |
| Clutch kick | Shift (tap) | X | button |
| Two-wheel | F (hold) | Y (hold) | button |
| Exit car | E | LB | button |
| Reset car | R | Back | small button |
| Reload CarConfig | L | — | small button |

## Tuning
All numbers live in `src/shared/CarConfig.luau`. See `TUNING.md`.
Press L in play to reload the config without rejoining. (Reload-during-play sync note filled in from Task 1 Step 8.)

## Phone test in Studio
Test → Device → pick a phone → Play. Touch buttons appear because the emulator reports TouchEnabled.
```

- [ ] **Step 10: Commit**

```bash
git add -A && git commit -m "feat: toolchain, Rojo project, entry scripts, README"
```

**What to test in Studio:** Rojo shows Connected; Play prints both boot lines in Output.

---

### Task 2: Shared foundations — Types, Units, Curve, CarConfig, ConfigLoader, test runner

**Files:**
- Create: `src/shared/Types.luau`, `src/shared/Units.luau`, `src/shared/Curve.luau`, `src/shared/CarConfig.luau`, `src/shared/ConfigLoader.luau`, `src/shared/Tests/init.luau`, `src/shared/Tests/Curve.spec.luau`, `src/shared/Tests/Units.spec.luau`

**Interfaces:**
- Produces: `Types.InputState`, `Types.WheelState`, `Types.VehicleState`, `Types.newInput()`; `Units.*`; `Curve.lookup(points, x)`; `CarConfig` table + `CarConfig.Config` type; `ConfigLoader.current()`, `ConfigLoader.reload()`; `require(Shared.Tests)() -> (passed, failed)`.

- [ ] **Step 1: Write the test runner `src/shared/Tests/init.luau`**

```lua
--!strict
-- Spec runner. Run in Studio (command bar or MCP execute_luau, Edit datamodel):
--   require(game.ReplicatedStorage.Shared.Tests)()
-- Each child ModuleScript returns function(t: T) and calls t.eq / t.near / t.ok.

export type T = {
	eq: (actual: any, expected: any, msg: string?) -> (),
	near: (actual: number, expected: number, eps: number, msg: string?) -> (),
	ok: (cond: boolean, msg: string?) -> (),
}

return function(): (number, number)
	local passed, failed = 0, 0
	local lines: { string } = {}

	for _, child in script:GetChildren() do
		if not child:IsA("ModuleScript") then
			continue
		end
		local name = child.Name
		local t: T = {
			eq = function(actual, expected, msg)
				if actual == expected then
					passed += 1
				else
					failed += 1
					table.insert(lines, `{name}: {msg or "eq"} expected {tostring(expected)} got {tostring(actual)}`)
				end
			end,
			near = function(actual, expected, eps, msg)
				if math.abs(actual - expected) <= eps then
					passed += 1
				else
					failed += 1
					table.insert(lines, `{name}: {msg or "near"} expected {expected}±{eps} got {actual}`)
				end
			end,
			ok = function(cond, msg)
				if cond then
					passed += 1
				else
					failed += 1
					table.insert(lines, `{name}: {msg or "ok"} was false`)
				end
			end,
		}
		local spec = (require :: any)(child) :: (T) -> ()
		local okRun, err = pcall(spec, t)
		if not okRun then
			failed += 1
			table.insert(lines, `{name}: error {tostring(err)}`)
		end
	end

	print(`[Tests] {passed} passed, {failed} failed`)
	for _, line in lines do
		warn(line)
	end
	return passed, failed
end
```

- [ ] **Step 2: Write failing specs for Curve and Units**

`src/shared/Tests/Curve.spec.luau`:
```lua
--!strict
local Curve = require(script.Parent.Parent.Curve)

return function(t)
	local pts = { { 0, 0 }, { 10, 100 }, { 20, 50 } }
	t.eq(Curve.lookup(pts, -5), 0, "clamps below")
	t.eq(Curve.lookup(pts, 25), 50, "clamps above")
	t.eq(Curve.lookup(pts, 5), 50, "interpolates first segment")
	t.eq(Curve.lookup(pts, 15), 75, "interpolates second segment")
	t.eq(Curve.lookup(pts, 10), 100, "exact knot")
end
```
`src/shared/Tests/Units.spec.luau`:
```lua
--!strict
local Units = require(script.Parent.Parent.Units)

return function(t)
	t.near(Units.mToStuds(2.8, 0.28), 10, 1e-9, "m to studs")
	t.near(Units.studsToM(10, 0.28), 2.8, 1e-9, "studs to m")
	t.near(Units.mpsToKmh(27.7778), 100, 0.01, "m/s to km/h")
	local f = Units.forceNToSim(Vector3.new(280, 0, 0), 0.28)
	t.near(f.X, 1000, 1e-6, "N to sim force")
	local tq = Units.torqueNmToSim(Vector3.new(0, 0.0784, 0), 0.28)
	t.near(tq.Y, 1, 1e-6, "Nm to sim torque")
end
```

- [ ] **Step 3: Run the runner, expect failures (modules missing)**

`execute_luau` (Edit): `return table.pack(require(game.ReplicatedStorage.Shared.Tests)())` → expect errors mentioning Curve/Units not found (the runner reports them as spec errors).

- [ ] **Step 4: Write `src/shared/Curve.luau`**

```lua
--!strict
-- Piecewise-linear lookup over a table of {x, y} points sorted by x.
-- Used for the engine torque curve and anything else tabulated in CarConfig.
local Curve = {}

export type Points = { { number } }

function Curve.lookup(points: Points, x: number): number
	local n = #points
	assert(n > 0, "Curve.lookup: empty table")
	if x <= points[1][1] then
		return points[1][2]
	end
	if x >= points[n][1] then
		return points[n][2]
	end
	for i = 1, n - 1 do
		local x0, y0 = points[i][1], points[i][2]
		local x1, y1 = points[i + 1][1], points[i + 1][2]
		if x >= x0 and x <= x1 then
			local t = if x1 > x0 then (x - x0) / (x1 - x0) else 0
			return y0 + (y1 - y0) * t
		end
	end
	return points[n][2]
end

return Curve
```

- [ ] **Step 5: Write `src/shared/Units.luau`**

```lua
--!strict
-- Conversions between SI (config, sim math) and Roblox units.
-- Convention: 1 Roblox mass unit == 1 kg (CarBuilder sets densities so the
-- assembly mass equals CarConfig.body.massKg). Lengths: metersPerStud.
local Units = {}

function Units.mToStuds(m: number, metersPerStud: number): number
	return m / metersPerStud
end

function Units.studsToM(s: number, metersPerStud: number): number
	return s * metersPerStud
end

function Units.vecStudsToM(v: Vector3, metersPerStud: number): Vector3
	return v * metersPerStud
end

function Units.vecMToStuds(v: Vector3, metersPerStud: number): Vector3
	return v / metersPerStud
end

function Units.mpsToKmh(v: number): number
	return v * 3.6
end

function Units.kmhToMps(v: number): number
	return v / 3.6
end

-- F_sim = m_rmu * a_studs = m_kg * (a_m / mps) = F_N / mps
function Units.forceNToSim(f: Vector3, metersPerStud: number): Vector3
	return f / metersPerStud
end

-- tau_sim = r_studs x F_sim = (r_m / mps) * (F_N / mps) = tau_Nm / mps^2
function Units.torqueNmToSim(t: Vector3, metersPerStud: number): Vector3
	return t / (metersPerStud * metersPerStud)
end

return Units
```

- [ ] **Step 6: Write `src/shared/Types.luau`**

```lua
--!strict
-- Shared data shapes. No logic beyond constructors.

export type InputState = {
	throttle: number, -- 0..1
	brake: number, -- 0..1
	steer: number, -- -1..1, + = right
	handbrake: boolean,
	twoWheel: boolean, -- held
	clutchKick: boolean, -- true for one step on press
	exit: boolean, -- edge
	reset: boolean, -- edge
	reload: boolean, -- edge
}

export type WheelState = {
	name: string,
	grounded: boolean,
	compression: number, -- m
	load: number, -- N
	slipAngleDeg: number,
	saturated: boolean, -- spinning or locked
	steerDeg: number,
	fx: number, -- N along wheel heading
	fy: number, -- N along wheel right
}

export type VehicleState = {
	speedMps: number,
	speedKmh: number,
	gear: number, -- -1 reverse, 1..n
	rpm: number,
	throttle: number,
	brake: number,
	steer: number,
	steerDeg: number,
	driftAngleDeg: number, -- angle between velocity and heading, + = velocity right of heading
	yawRateDegPerSec: number,
	twoWheelMode: string,
	rollDeg: number,
	rollMarginDeg: number,
	handbrake: boolean,
	clutchKick: boolean,
	driftAssist: number,
	wheels: { WheelState },
}

local Types = {}

function Types.newInput(): InputState
	return {
		throttle = 0,
		brake = 0,
		steer = 0,
		handbrake = false,
		twoWheel = false,
		clutchKick = false,
		exit = false,
		reset = false,
		reload = false,
	}
end

return Types
```

- [ ] **Step 7: Write `src/shared/CarConfig.luau`**

```lua
--!strict
-- Every tunable for the Phase 0 car. SI units unless the name says otherwise.
-- See TUNING.md for what each field does and which way to move it.
-- Reloadable in play with the L key (ConfigLoader clones and re-requires this module).

local config = {
	units = {
		metersPerStud = 0.28,
		-- Effective gravity on the car in m/s². workspace.Gravity stays 196.2;
		-- the sim adds an upward counter-force so the car falls at this rate.
		-- 54.936 (= 196.2 * 0.28) makes the counter-force zero for A/B tests.
		gravity = 9.81,
	},

	body = {
		massKg = 1600,
		bodySize = { 4.9, 1.3, 1.8 }, -- length (Z), height (Y), width (X), metres
		-- From the box centre: {lateral, up, forward}. Low and slightly forward.
		centerOfMassOffset = { 0, -0.35, 0.2 },
		wheelbase = 2.8,
		trackWidth = 1.55,
		wheelRadius = 0.33,
		wheelWidth = 0.22,
		shellMassFraction = 0.35, -- rest of the mass goes into the hidden ballast
		dragCoefficient = 0.32,
		frontalArea = 2.2,
		airDensity = 1.2,
		rollingResistance = 0.015,
	},

	suspension = {
		restLength = 0.35, -- hardpoint to wheel centre at full droop
		travel = 0.2,
		stiffness = 35000, -- N/m per corner
		damping = 2600, -- Ns/m per corner
		bumpStopStiffness = 350000, -- N/m past full travel
		antiRollFront = 8000, -- N/m of compression difference, front axle
		antiRollRear = 4000,
	},

	tires = {
		front = { grip = 1.05, peakSlipDeg = 8, slideSlipDeg = 25, slideGripRatio = 0.75 },
		rear = { grip = 1.0, peakSlipDeg = 7, slideSlipDeg = 22, slideGripRatio = 0.7 },
		speedFadeMps = 1.0, -- lateral force fades to zero below this speed
	},

	drivetrain = {
		torqueCurve = { { 1000, 180 }, { 2500, 260 }, { 4000, 300 }, { 5500, 290 }, { 6500, 240 }, { 7000, 0 } },
		gearRatios = { 3.5, 2.1, 1.4, 1.0, 0.8 },
		reverseRatio = 3.2,
		finalDrive = 3.9,
		drivelineEfficiency = 0.9,
		idleRpm = 900,
		redlineRpm = 6800,
		upshiftRpm = 6400,
		downshiftRpm = 3000,
		shiftTime = 0.15,
		spinRpmRate = 6000, -- rpm/s the engine climbs while the rear spins
		engineBrakeTorque = 40, -- Nm at redline, scales with rpm
		brakeForce = 14000, -- N total at full pedal
		brakeBias = 0.65, -- fraction on the front axle
		brakeFadeMps = 0.5, -- brakes fade to zero below this speed (no jitter at rest)
	},

	steering = {
		maxSteerDeg = 38,
		steerSpeedDegPerSec = 180,
		steerReturnDegPerSec = 360,
		driftAssist = 0.15, -- 0..1, adds this fraction of the drift angle as counter-steer
	},

	handbrake = {
		rearGripMultiplier = 0.35,
		brakeForce = 6000, -- N total on the rear axle
	},

	clutchKick = {
		multiplier = 2.5,
		duration = 0.3,
	},

	twoWheel = {
		liftTorque = 12000, -- Nm extra while lifting
		gravityCancel = 1.0, -- fraction of gravity's restoring torque cancelled while balanced
		targetRollDeg = 42,
		instability = 5, -- Nm/deg net divergence at target (about 1.5 s time constant)
		rollDamping = 20, -- Nm per deg/s
		balanceTorque = 1500, -- Nm at full steer
		tipRollDeg = 60, -- past this the mode releases and the car falls
		landingDamping = 60, -- Nm per deg/s while coming down
		suspensionBias = 1.8, -- grounded-side stiffness multiplier while lifted
	},

	input = {
		keyboardSteerRampPerSec = 4,
		keyboardSteerReturnPerSec = 8,
		touchSteerRampPerSec = 3,
		touchSteerReturnPerSec = 6,
		touchSteerCurve = 1.5, -- exponent on the ramped touch steer
		gamepadDeadzone = 0.12,
		triggerDeadzone = 0.05,
	},

	camera = {
		distance = 7.5,
		height = 2.6,
		lookHeight = 0.8,
		positionLag = 8, -- 1/s
		directionLag = 4, -- 1/s
		driftSwing = 0.6, -- 0 follow heading, 1 follow velocity
		baseFov = 70,
		fovPerKmh = 0.08,
		maxFov = 85,
		minSpeedForSwingMps = 3,
	},

	debug = {
		enabled = true,
		updateHz = 10,
	},
}

export type Config = typeof(config)

return config
```

- [ ] **Step 8: Write `src/shared/ConfigLoader.luau`**

```lua
--!strict
-- Holds the live CarConfig and reloads it by cloning the ModuleScript.
-- require() caches per instance, so requiring a fresh clone re-runs the
-- module's current Source. Works on client and server.
local Shared = script.Parent
local CarConfig = require(Shared.CarConfig)

export type Config = CarConfig.Config

local ConfigLoader = {}
local current: Config = CarConfig

function ConfigLoader.current(): Config
	return current
end

-- Returns the (possibly unchanged) config and an error string if reload failed.
function ConfigLoader.reload(): (Config, string?)
	local module = Shared:FindFirstChild("CarConfig")
	if not module or not module:IsA("ModuleScript") then
		return current, "CarConfig module missing"
	end
	local clone = module:Clone()
	clone.Parent = Shared
	local ok, result = pcall(require :: any, clone)
	clone:Destroy()
	if ok and typeof(result) == "table" then
		current = result :: Config
		return current, nil
	end
	return current, tostring(result)
end

return ConfigLoader
```

- [ ] **Step 9: Run specs, expect pass**

`execute_luau` (Edit): `local p, f = require(game.ReplicatedStorage.Shared.Tests)() return p .. "/" .. f` → expect `10/0`.

- [ ] **Step 10: Run `scripts/analyze.sh`, fix any strict errors. Commit**

```bash
git add -A && git commit -m "feat: shared foundations (types, units, curve, CarConfig, ConfigLoader, test runner)"
```

---

### Task 3: Test road

**Files:**
- Create: `src/server/RoadBuilder.luau`
- Modify: `src/server/init.server.luau`

**Interfaces:**
- Produces: `RoadBuilder.build(config): Model` returning `workspace.Road` with attributes `StartCFrame: CFrame` (studs, facing −Z down the road), `LengthStuds: number`, `HalfWidthStuds: number`, `BayCFrame: CFrame`, `SurfaceY: number`.

- [ ] **Step 1: Write `src/server/RoadBuilder.luau`**

```lua
--!strict
-- Builds the Phase 0 test road: 2 km straight, 60 m wide, dashed centreline,
-- a 400 m radius / 30° curve at the end, a sand ground plane, a parking bay.
-- Everything is built from CarConfig units so the road matches the car scale.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared.CarConfig)
local Units = require(Shared.Units)

type Config = CarConfig.Config

local RoadBuilder = {}

local ROAD_LENGTH_M = 2000
local ROAD_WIDTH_M = 60
local ROAD_THICKNESS_M = 1
local DASH_LENGTH_M = 6
local DASH_GAP_M = 6
local DASH_WIDTH_M = 0.3
local CURVE_RADIUS_M = 400
local CURVE_SWEEP_DEG = 30
local CURVE_SEGMENTS = 24
local BAY_LENGTH_M = 40
local GROUND_TILE_M = 500
local MAX_PART_STUDS = 2048

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function RoadBuilder.build(config: Config): Model
	local mps = config.units.metersPerStud
	local function s(m: number): number
		return Units.mToStuds(m, mps)
	end

	local existing = workspace:FindFirstChild("Road")
	if existing then
		existing:Destroy()
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	local road = Instance.new("Model")
	road.Name = "Road"

	local surfaceY = 0
	local thickness = s(ROAD_THICKNESS_M)
	local halfWidth = s(ROAD_WIDTH_M) / 2
	local asphalt = Color3.fromRGB(45, 45, 48)
	local sand = Color3.fromRGB(196, 176, 130)
	local paint = Color3.fromRGB(240, 220, 90)

	-- Ground plane: tiled because a Part axis maxes at 2048 studs.
	local groundTiles = Instance.new("Folder")
	groundTiles.Name = "Ground"
	groundTiles.Parent = road
	local tile = s(GROUND_TILE_M)
	for ix = -2, 2 do
		for iz = -5, 1 do
			part(
				"GroundTile",
				Vector3.new(tile, thickness, tile),
				CFrame.new(ix * tile, surfaceY - s(0.1) - thickness / 2, iz * tile),
				sand,
				Enum.Material.Sand,
				groundTiles
			)
		end
	end

	-- Straight: road runs from z = 0 toward -Z (Roblox forward).
	local straight = Instance.new("Folder")
	straight.Name = "Straight"
	straight.Parent = road
	local segLen = s(ROAD_LENGTH_M) / 4
	assert(segLen <= MAX_PART_STUDS, "road segment too long")
	for i = 0, 3 do
		local zCenter = -(i * segLen + segLen / 2)
		part(
			"Straight" .. i,
			Vector3.new(halfWidth * 2, thickness, segLen),
			CFrame.new(0, surfaceY - thickness / 2, zCenter),
			asphalt,
			Enum.Material.Asphalt,
			straight
		)
	end

	-- Centreline dashes.
	local dashes = Instance.new("Folder")
	dashes.Name = "Centreline"
	dashes.Parent = road
	local dashLen, dashGap = s(DASH_LENGTH_M), s(DASH_GAP_M)
	local z = -dashLen / 2
	while z > -s(ROAD_LENGTH_M) do
		local d = part(
			"Dash",
			Vector3.new(s(DASH_WIDTH_M), s(0.02), dashLen),
			CFrame.new(0, surfaceY + s(0.01), z),
			paint,
			Enum.Material.SmoothPlastic,
			dashes
		)
		d.CanCollide = false
		z -= dashLen + dashGap
	end

	-- Curve: arc to the left (-X) starting at the end of the straight.
	local curve = Instance.new("Folder")
	curve.Name = "Curve"
	curve.Parent = road
	local radius = s(CURVE_RADIUS_M)
	local endZ = -s(ROAD_LENGTH_M)
	local center = Vector3.new(-radius, surfaceY, endZ) -- arc centre to the left of the road end
	local sweep = math.rad(CURVE_SWEEP_DEG)
	local segAngle = sweep / CURVE_SEGMENTS
	local segChord = radius * segAngle
	for i = 0, CURVE_SEGMENTS - 1 do
		local a = (i + 0.5) * segAngle
		-- Point on the arc: start at angle 0 (road end), rotate toward -X.
		local pos = center + Vector3.new(math.cos(a) * radius, 0, -math.sin(a) * radius)
		local look = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, -math.cos(a)))
		part(
			"Curve" .. i,
			Vector3.new(halfWidth * 2, thickness, segChord * 1.1),
			look * CFrame.new(0, -thickness / 2, 0),
			asphalt,
			Enum.Material.Asphalt,
			curve
		)
		if i % 2 == 0 then
			local d = part(
				"Dash",
				Vector3.new(s(DASH_WIDTH_M), s(0.02), segChord * 0.5),
				look * CFrame.new(0, s(0.01), 0),
				paint,
				Enum.Material.SmoothPlastic,
				dashes
			)
			d.CanCollide = false
		end
	end

	-- Parking bay behind the start line (z > 0).
	local bay = part(
		"Bay",
		Vector3.new(halfWidth * 2, thickness, s(BAY_LENGTH_M)),
		CFrame.new(0, surfaceY - thickness / 2, s(BAY_LENGTH_M) / 2),
		Color3.fromRGB(60, 60, 64),
		Enum.Material.Concrete,
		road
	)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlayerSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(-halfWidth + 10, surfaceY + 0.5, s(BAY_LENGTH_M) / 2)
	spawn.Neutral = true
	spawn.Parent = road
	local old = workspace:FindFirstChild("SpawnLocation")
	if old then
		old:Destroy()
	end

	road:SetAttribute("StartCFrame", CFrame.new(0, surfaceY, 0)) -- facing -Z by default
	road:SetAttribute("LengthStuds", s(ROAD_LENGTH_M))
	road:SetAttribute("HalfWidthStuds", halfWidth)
	road:SetAttribute("BayCFrame", bay.CFrame * CFrame.new(0, thickness / 2, 0))
	road:SetAttribute("SurfaceY", surfaceY)
	road.Parent = workspace
	return road
end

return RoadBuilder
```

- [ ] **Step 2: Wire it in `src/server/init.server.luau`**

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared.ConfigLoader)
local RoadBuilder = require(script.RoadBuilder)

print("[Hajwala] server boot")
local road = RoadBuilder.build(ConfigLoader.current())
print("[Hajwala] road built:", road:GetAttribute("LengthStuds"), "studs")
```

- [ ] **Step 3: Play, verify**

`start_stop_play` → Play. `execute_luau` (Server): `return #workspace.Road.Straight:GetChildren() .. " straight, " .. #workspace.Road.Curve:GetChildren() .. " curve, " .. #workspace.Road.Centreline:GetChildren() .. " dashes"` → expect `4 straight, 24 curve, 178 dashes` (166 straight dashes + 12 curve dashes). `screen_capture` to eyeball. Stop.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: 2 km test road with centreline and end curve"
```

**What to test in Studio:** Play, walk to the road edge. Straight looks 60 m wide (about 214 studs), dashes visible, curve bends left at the far end. No baseplate seam.

---

### Task 4: Car model, spawner, remotes, seat and ownership handoff

**Files:**
- Create: `src/server/CarBuilder.luau`, `src/server/CarSpawner.luau`, `src/server/Remotes.luau`
- Modify: `src/server/init.server.luau`, `src/client/init.client.luau`

**Interfaces:**
- Produces: `CarBuilder.build(config, name): Model` with children `Chassis` (PrimaryPart, with Attachments `Hardpoint_FL/FR/RL/RR` and `Center`, a `VectorForce` named `SimForce`, a `Torque` named `SimTorque`, a `ProximityPrompt` named `EnterPrompt`), `Ballast`, `Wheel_FL/FR/RL/RR` (each with a `Weld` named `WheelWeld`, Part0 = Chassis), `DriverSeat` (VehicleSeat).
- Produces: `Remotes.create(): RemoteTable` where `RemoteTable = { DriveStart: RemoteEvent, DriveStop: RemoteEvent, ExitCar: RemoteEvent, ReloadConfig: RemoteEvent }` under `ReplicatedStorage.Remotes`.
- Produces: `CarSpawner.start(config, road, remotes)`; `CarSpawner.setConfig(config)`; `CarSpawner.setSimFactory(fn)` (Task 9 plugs the VehicleSim in; until then parked cars are simply anchored).
- Client: `DriveStart` fires with `(carModel: Model)`, `DriveStop` fires with no args.

- [ ] **Step 1: Write `src/server/Remotes.luau`**

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type RemoteTable = {
	DriveStart: RemoteEvent, -- server -> client (carModel)
	DriveStop: RemoteEvent, -- server -> client
	ExitCar: RemoteEvent, -- client -> server
	ReloadConfig: RemoteEvent, -- client -> server
}

local Remotes = {}

function Remotes.create(): RemoteTable
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	local function ev(name: string): RemoteEvent
		local e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = folder
		return e
	end
	local t: RemoteTable = {
		DriveStart = ev("DriveStart"),
		DriveStop = ev("DriveStop"),
		ExitCar = ev("ExitCar"),
		ReloadConfig = ev("ReloadConfig"),
	}
	folder.Parent = ReplicatedStorage
	return t
end

return Remotes
```

- [ ] **Step 2: Write `src/server/CarBuilder.luau`**

```lua
--!strict
-- Builds the placeholder sedan from CarConfig dimensions.
-- One rigid assembly: Chassis (collidable box, the PrimaryPart), Ballast
-- (hidden dense box that places the centre of mass), four massless
-- non-colliding wheel cylinders on Welds that the sim repositions every frame,
-- a VehicleSeat, hardpoint Attachments, one VectorForce and one Torque.
-- Roblox mass units == kg: densities are chosen so the assembly mass equals massKg.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared.CarConfig)

type Config = CarConfig.Config

local CarBuilder = {}

local WHEELS = {
	{ name = "FL", x = -1, z = -1 },
	{ name = "FR", x = 1, z = -1 },
	{ name = "RL", x = -1, z = 1 },
	{ name = "RR", x = 1, z = 1 },
}

-- Hardpoint position in chassis-local metres for a wheel. Shared with the sim
-- via the Attachments, but exposed so tests can check it.
function CarBuilder.hardpointLocalM(config: Config, xSign: number, zSign: number): Vector3
	local body = config.body
	return Vector3.new(
		xSign * body.trackWidth / 2,
		-body.bodySize[2] / 2 + config.suspension.restLength,
		zSign * body.wheelbase / 2 -- front is -Z
	)
end

function CarBuilder.build(config: Config, name: string): Model
	local mps = config.units.metersPerStud
	local function s(m: number): number
		return m / mps
	end
	local body = config.body
	local L, H, W = s(body.bodySize[1]), s(body.bodySize[2]), s(body.bodySize[3])

	local model = Instance.new("Model")
	model.Name = name

	-- Chassis shell
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(W, H, L)
	chassis.Color = Color3.fromRGB(230, 230, 235)
	chassis.Material = Enum.Material.SmoothPlastic
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	local shellMass = body.massKg * body.shellMassFraction
	chassis.CustomPhysicalProperties = PhysicalProperties.new(shellMass / (W * H * L), 0.3, 0.05)
	chassis.Anchored = true
	chassis.Parent = model
	model.PrimaryPart = chassis

	-- A stripe so heading is obvious in tests
	local hood = Instance.new("Part")
	hood.Name = "HoodStripe"
	hood.Size = Vector3.new(W * 0.3, 0.2, L * 0.3)
	hood.Color = Color3.fromRGB(200, 40, 40)
	hood.Material = Enum.Material.SmoothPlastic
	hood.Massless = true
	hood.CanCollide = false
	hood.CanQuery = false
	hood.CanTouch = false
	hood.CFrame = chassis.CFrame * CFrame.new(0, H / 2 + 0.1, -L * 0.3)
	hood.Parent = model
	local hoodWeld = Instance.new("WeldConstraint")
	hoodWeld.Part0 = chassis
	hoodWeld.Part1 = hood
	hoodWeld.Parent = hood

	-- Ballast: places the assembly centre of mass at body.centerOfMassOffset.
	-- CoM = (shell*0 + ballast*p) / total  =>  p = offset * total / ballast
	local ballastMass = body.massKg - shellMass
	local off = body.centerOfMassOffset
	local ballastPosM = Vector3.new(off[1], off[2], -off[3]) * (body.massKg / ballastMass)
	local side = 3 -- studs; Roblox density max is 100
	while ballastMass / (side * side * side) > 100 do
		side += 1
	end
	local ballast = Instance.new("Part")
	ballast.Name = "Ballast"
	ballast.Size = Vector3.new(side, side, side)
	ballast.Transparency = 1
	ballast.CanCollide = false
	ballast.CanQuery = false
	ballast.CanTouch = false
	ballast.CustomPhysicalProperties = PhysicalProperties.new(ballastMass / (side * side * side), 0, 0)
	ballast.CFrame = chassis.CFrame * CFrame.new(ballastPosM / mps)
	ballast.Parent = model
	local ballastWeld = Instance.new("WeldConstraint")
	ballastWeld.Part0 = chassis
	ballastWeld.Part1 = ballast
	ballastWeld.Parent = ballast

	-- Wheels and hardpoints
	local r = s(body.wheelRadius)
	for _, w in WHEELS do
		local hpM = CarBuilder.hardpointLocalM(config, w.x, w.z)
		local hp = hpM / mps

		local att = Instance.new("Attachment")
		att.Name = "Hardpoint_" .. w.name
		att.Position = hp
		att.Parent = chassis

		local wheel = Instance.new("Part")
		wheel.Name = "Wheel_" .. w.name
		wheel.Shape = Enum.PartType.Cylinder -- axis along X == car lateral axis
		wheel.Size = Vector3.new(s(body.wheelWidth), r * 2, r * 2)
		wheel.Color = Color3.fromRGB(30, 30, 30)
		wheel.Material = Enum.Material.Rubber
		wheel.Massless = true
		wheel.CanCollide = false
		wheel.CanQuery = false
		wheel.CanTouch = false
		wheel.CFrame = chassis.CFrame * CFrame.new(hp - Vector3.new(0, s(config.suspension.restLength), 0))
		wheel.Parent = model

		local weld = Instance.new("Weld")
		weld.Name = "WheelWeld"
		weld.Part0 = chassis
		weld.Part1 = wheel
		weld.C0 = CFrame.new(hp - Vector3.new(0, s(config.suspension.restLength), 0))
		weld.C1 = CFrame.new()
		weld.Parent = wheel
	end

	-- Seat (inside the body; entered via ProximityPrompt, not by touching)
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.Transparency = 0.6
	seat.Color = Color3.fromRGB(60, 60, 60)
	seat.CanCollide = false
	seat.CanQuery = false
	seat.Massless = true
	seat.MaxSpeed = 0 -- disable the built-in VehicleSeat motor
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.HeadsUpDisplay = false
	seat.CFrame = chassis.CFrame * CFrame.new(-s(0.4), 0, -s(0.2))
	seat.Parent = model
	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0 = chassis
	seatWeld.Part1 = seat
	seatWeld.Parent = seat

	-- Force actuators the sim writes to
	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Parent = chassis

	local vf = Instance.new("VectorForce")
	vf.Name = "SimForce"
	vf.Attachment0 = center
	vf.ApplyAtCenterOfMass = true
	vf.RelativeTo = Enum.ActuatorRelativeTo.World
	vf.Force = Vector3.zero
	vf.Parent = chassis

	local tq = Instance.new("Torque")
	tq.Name = "SimTorque"
	tq.Attachment0 = center
	tq.RelativeTo = Enum.ActuatorRelativeTo.World
	tq.Torque = Vector3.zero
	tq.Parent = chassis

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterPrompt"
	prompt.ActionText = "Enter car"
	prompt.ObjectText = "Sedan"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = chassis

	return model
end

return CarBuilder
```

- [ ] **Step 3: Write `src/server/CarSpawner.luau`**

```lua
--!strict
-- One parked car per player. Owns seating, network ownership handoff,
-- driverless simulation (plugged in by VehicleSim in Task 9), anchoring of
-- settled cars, exit, and config reload.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared.CarConfig)
local ConfigLoader = require(Shared.ConfigLoader)
local Types = require(Shared.Types)
local CarBuilder = require(script.Parent.CarBuilder)
local Remotes = require(script.Parent.Remotes)

type Config = CarConfig.Config

-- Minimal interface the spawner needs from a sim (VehicleSim satisfies it).
export type Sim = {
	step: (self: Sim, input: Types.InputState, dt: number) -> Types.VehicleState,
	setConfig: (self: Sim, config: Config) -> (),
}
export type SimFactory = (model: Model, config: Config) -> Sim

type Entry = {
	model: Model,
	chassis: BasePart,
	seat: VehicleSeat,
	prompt: ProximityPrompt,
	owner: Player,
	driver: Player?,
	sim: Sim?,
	stillTime: number,
}

local CarSpawner = {}

local cars: { [Player]: Entry } = {}
local config: Config = ConfigLoader.current()
local simFactory: SimFactory? = nil
local remotes: Remotes.RemoteTable
local road: Model
local slotCounter = 0
local zeroInput = Types.newInput()

local STILL_SPEED_STUDS = 0.5 / 0.28 -- 0.5 m/s
local STILL_SECONDS = 1

local function s(m: number): number
	return m / config.units.metersPerStud
end

local function unseat(entry: Entry)
	local hum = entry.seat.Occupant
	if hum then
		hum.Sit = false
	end
	local weld = entry.seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
end

local function onOccupantChanged(entry: Entry)
	local hum = entry.seat.Occupant
	if hum then
		local character = hum.Parent
		local player = if character then Players:GetPlayerFromCharacter(character) else nil
		if not player then
			unseat(entry)
			return
		end
		entry.driver = player
		entry.prompt.Enabled = false
		entry.chassis.Anchored = false
		entry.chassis:SetNetworkOwner(player)
		remotes.DriveStart:FireClient(player, entry.model)
	else
		local prev = entry.driver
		entry.driver = nil
		entry.prompt.Enabled = true
		entry.stillTime = 0
		if not entry.chassis.Anchored then
			entry.chassis:SetNetworkOwner(nil)
		end
		if prev then
			remotes.DriveStop:FireClient(prev)
			local character = prev.Character
			if character then
				task.defer(function()
					character:PivotTo(entry.model:GetPivot() * CFrame.new(-s(3), s(1.5), 0))
				end)
			end
		end
	end
end

local function spawnFor(player: Player)
	if cars[player] then
		return
	end
	local model = CarBuilder.build(config, "Car_" .. player.Name)
	model:SetAttribute("OwnerUserId", player.UserId)
	local chassis = model.PrimaryPart :: BasePart
	local seat = model:FindFirstChild("DriverSeat") :: VehicleSeat
	local prompt = chassis:FindFirstChild("EnterPrompt") :: ProximityPrompt

	local bay = road:GetAttribute("BayCFrame") :: CFrame
	local slotX = -s(20) + slotCounter * s(4)
	slotCounter += 1
	local restHeight = s(config.body.bodySize[2] / 2 + 0.45) -- spawn a little high, let it settle
	model:PivotTo(bay * CFrame.new(slotX, restHeight, 0))
	model.Parent = workspace:FindFirstChild("Cars") or (function()
		local f = Instance.new("Folder")
		f.Name = "Cars"
		f.Parent = workspace
		return f
	end)()

	local entry: Entry = {
		model = model,
		chassis = chassis,
		seat = seat,
		prompt = prompt,
		owner = player,
		driver = nil,
		sim = if simFactory then simFactory(model, config) else nil,
		stillTime = 0,
	}
	cars[player] = entry

	-- With no sim yet (before Task 9) the car stays anchored where it spawned.
	chassis.Anchored = entry.sim == nil

	prompt.Triggered:Connect(function(who: Player)
		if entry.driver ~= nil then
			return
		end
		local character = who.Character
		local hum = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not hum or hum.Health <= 0 then
			return
		end
		chassis.Anchored = false
		seat:Sit(hum)
	end)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		onOccupantChanged(entry)
	end)
end

local function despawn(player: Player)
	local entry = cars[player]
	if not entry then
		return
	end
	cars[player] = nil
	entry.model:Destroy()
end

local function stepDriverless(dt: number)
	for _, entry in cars do
		if entry.driver ~= nil or entry.sim == nil or entry.chassis.Anchored then
			continue
		end
		entry.sim:step(zeroInput, dt)
		if entry.chassis.AssemblyLinearVelocity.Magnitude < STILL_SPEED_STUDS then
			entry.stillTime += dt
			if entry.stillTime >= STILL_SECONDS then
				entry.chassis.Anchored = true
			end
		else
			entry.stillTime = 0
		end
	end
end

function CarSpawner.setSimFactory(factory: SimFactory)
	simFactory = factory
end

function CarSpawner.setConfig(newConfig: Config)
	config = newConfig
	for _, entry in cars do
		if entry.sim then
			entry.sim:setConfig(newConfig)
		end
	end
end

function CarSpawner.start(startConfig: Config, startRoad: Model, startRemotes: Remotes.RemoteTable)
	config = startConfig
	road = startRoad
	remotes = startRemotes

	Players.PlayerAdded:Connect(spawnFor)
	Players.PlayerRemoving:Connect(despawn)
	for _, p in Players:GetPlayers() do
		spawnFor(p)
	end

	RunService.PreSimulation:Connect(stepDriverless)

	remotes.ExitCar.OnServerEvent:Connect(function(player: Player)
		for _, entry in cars do
			if entry.driver == player then
				unseat(entry)
			end
		end
	end)

	remotes.ReloadConfig.OnServerEvent:Connect(function(player: Player)
		local newConfig, err = ConfigLoader.reload()
		if err then
			warn("[Hajwala] config reload failed:", err)
		end
		CarSpawner.setConfig(newConfig)
	end)
end

return CarSpawner
```

- [ ] **Step 4: Update `src/server/init.server.luau`**

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared.ConfigLoader)
local RoadBuilder = require(script.RoadBuilder)
local Remotes = require(script.Remotes)
local CarSpawner = require(script.CarSpawner)

print("[Hajwala] server boot")
local config = ConfigLoader.current()
local road = RoadBuilder.build(config)
local remotes = Remotes.create()
CarSpawner.start(config, road, remotes)
print("[Hajwala] ready")
```

- [ ] **Step 5: Update `src/client/init.client.luau` to log the handoff**

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local driveStart = remotes:WaitForChild("DriveStart") :: RemoteEvent
local driveStop = remotes:WaitForChild("DriveStop") :: RemoteEvent

print("[Hajwala] client boot")
driveStart.OnClientEvent:Connect(function(car: Model)
	print("[Hajwala] DriveStart", car:GetFullName())
end)
driveStop.OnClientEvent:Connect(function()
	print("[Hajwala] DriveStop")
end)
```

- [ ] **Step 6: Play and verify mass, CoM, seat flow**

`execute_luau` (Server) after Play:
```lua
local car = workspace.Cars:GetChildren()[1]
local c = car.PrimaryPart
local com = c.CFrame:PointToObjectSpace(c.AssemblyCenterOfMass) * 0.28
return string.format("mass=%.1f com=(%.2f, %.2f, %.2f) wheels=%d", c.AssemblyMass, com.X, com.Y, com.Z, #car:GetChildren())
```
Expected: mass ≈ 1600 (±1), com ≈ (0, −0.35, −0.2) metres (forward is −Z), 8 children (Chassis, HoodStripe, Ballast, 4 wheels, DriverSeat). Then walk the character to the car, press E: console shows `DriveStart`. `execute_luau` (Server): `return workspace.Cars:GetChildren()[1].PrimaryPart:GetNetworkOwner()` → the player. Note: the seated character adds its own mass to the assembly; that is expected.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: car model builder, spawner, seat/ownership handoff, remotes"
```

**What to test in Studio:** A white box with a red hood stripe and four black wheels is parked at the bay, anchored. Walk up, E → you sit inside it and Output prints DriveStart. There is no exit yet (Task 11); use Stop.

---

### Task 5: Suspension module (pure) + spec

**Files:**
- Create: `src/shared/VehicleSim/Suspension.luau`, `src/shared/Tests/Suspension.spec.luau`

**Interfaces:**
- Produces: `Suspension.step(prevCompression: number, hitDistanceM: number?, cfg: Suspension.Config, wheelRadius: number, stiffnessMult: number, dt: number): Suspension.Result` where `Result = { compression: number, force: number, grounded: boolean }`; `Suspension.antiRoll(k, compressionLeft, compressionRight): number`; `Suspension.rayLengthM(cfg, wheelRadius): number`.
- `Suspension.Config` is exactly `CarConfig.suspension`.

- [ ] **Step 1: Write the failing spec `src/shared/Tests/Suspension.spec.luau`**

```lua
--!strict
local Suspension = require(script.Parent.Parent.VehicleSim.Suspension)

return function(t)
	local cfg = { restLength = 0.35, travel = 0.2, stiffness = 35000, damping = 2600, bumpStopStiffness = 350000, antiRollFront = 8000, antiRollRear = 4000 }
	local r = 0.33

	local miss = Suspension.step(0.1, nil, cfg, r, 1, 1 / 60)
	t.eq(miss.grounded, false, "no hit -> not grounded")
	t.eq(miss.force, 0, "no hit -> zero force")

	-- Ground exactly at full droop: hit distance = rest + radius
	local droop = Suspension.step(0, 0.68, cfg, r, 1, 1 / 60)
	t.eq(droop.grounded, true, "hit -> grounded")
	t.near(droop.compression, 0, 1e-9, "full droop compression")
	t.near(droop.force, 0, 1e-6, "full droop force")

	-- 0.1 m compression, no velocity: force = k x
	local st = Suspension.step(0.1, 0.58, cfg, r, 1, 1 / 60)
	t.near(st.compression, 0.1, 1e-9, "compression")
	t.near(st.force, 3500, 1e-6, "spring force")

	-- Compressing at 0.6 m/s adds damping
	local dyn = Suspension.step(0.09, 0.58, cfg, r, 1, 1 / 60)
	t.near(dyn.force, 3500 + 2600 * 0.6, 1e-3, "damping adds")

	-- Rebounding fast: force clamps at zero (a spring cannot pull the car down)
	local reb = Suspension.step(0.19, 0.58, cfg, r, 1, 1 / 60)
	t.near(reb.force, 0, 1e-9, "no negative force")

	-- Past full travel: bump stop
	local bump = Suspension.step(0.2, 0.46, cfg, r, 1, 1 / 60) -- raw = 0.35 - 0.13 = 0.22
	t.near(bump.compression, 0.2, 1e-9, "compression clamps at travel")
	t.near(bump.force, 35000 * 0.2 + 350000 * 0.02, 1e-3, "bump stop adds")

	-- Stiffness multiplier (two-wheel bias)
	local biased = Suspension.step(0.1, 0.58, cfg, r, 2, 1 / 60)
	t.near(biased.force, 7000, 1e-6, "stiffness multiplier")

	t.near(Suspension.antiRoll(8000, 0.12, 0.08), 320, 1e-9, "anti-roll")
	t.near(Suspension.rayLengthM(cfg, r), 0.68 + 0.05, 1e-9, "ray length")
end
```

- [ ] **Step 2: Run runner, expect Suspension spec error (module missing)**

- [ ] **Step 3: Write `src/shared/VehicleSim/Suspension.luau`**

```lua
--!strict
-- Raycast suspension for one corner. Pure: no Roblox instances.
--
-- Why raycast (see DESIGN.md): one rigid body, per-corner spring loads that
-- shift with weight transfer, no constraint jitter, cheap on mobile, and the
-- tire model gets a clean normal load per wheel.
--
-- Geometry: the ray starts at the hardpoint and points along -body up.
-- Uncompressed, the wheel centre is restLength below the hardpoint and the
-- ground is restLength + wheelRadius below it. Compression is how much
-- closer the ground is than that.
local Suspension = {}

export type Config = {
	restLength: number,
	travel: number,
	stiffness: number,
	damping: number,
	bumpStopStiffness: number,
	antiRollFront: number,
	antiRollRear: number,
}

export type Result = {
	compression: number, -- m, 0..travel
	force: number, -- N along body up, >= 0
	grounded: boolean,
}

local RAY_MARGIN_M = 0.05

function Suspension.rayLengthM(cfg: Config, wheelRadius: number): number
	return cfg.restLength + wheelRadius + RAY_MARGIN_M
end

function Suspension.step(
	prevCompression: number,
	hitDistanceM: number?,
	cfg: Config,
	wheelRadius: number,
	stiffnessMult: number,
	dt: number
): Result
	if hitDistanceM == nil then
		return { compression = 0, force = 0, grounded = false }
	end
	local raw = cfg.restLength - (hitDistanceM - wheelRadius)
	if raw <= 0 then
		-- Ray hit beyond full droop: wheel is hanging, no load.
		return { compression = 0, force = 0, grounded = true }
	end
	local x = math.min(raw, cfg.travel)
	local dx = if dt > 0 then (x - prevCompression) / dt else 0
	-- Spring + damper. Damping on compression velocity is what makes the
	-- body "load up and settle" instead of bouncing; ~0.35 damping ratio.
	local force = cfg.stiffness * stiffnessMult * x + cfg.damping * dx
	if raw > cfg.travel then
		-- Bump stop: stiff extra spring past full travel so the body cannot
		-- sink through the wheels under two-wheel loads or hard landings.
		force += cfg.bumpStopStiffness * (raw - cfg.travel)
	end
	-- A spring cannot pull the chassis toward the ground.
	return { compression = x, force = math.max(force, 0), grounded = true }
end

-- Anti-roll bar: transfers load across an axle in proportion to the
-- compression difference. Returns the force to ADD to the left corner; the
-- right corner gets the negative. Stiffer front bar -> more understeer
-- (front loses grip first); stiffer rear bar -> more oversteer.
function Suspension.antiRoll(k: number, compressionLeft: number, compressionRight: number): number
	return k * (compressionLeft - compressionRight)
end

return Suspension
```

- [ ] **Step 4: Run runner, expect all pass. Commit**

```bash
git add -A && git commit -m "feat: raycast suspension module with spec"
```

---

### Task 6: Tire module (pure) + spec

**Files:**
- Create: `src/shared/VehicleSim/Tire.luau`, `src/shared/Tests/Tire.spec.luau`

**Interfaces:**
- Produces: `Tire.gripCurve(slipDeg, axle): number`, `Tire.slipAngleDeg(vLong, vLat): number`, `Tire.combine(fxDemand, fyDemand, fMax, slideGripRatio): (fx, fy, saturated)`, `Tire.compute(vLong, vLat, load, axle, gripMultiplier, fxDemand, speedFadeMps): Tire.Output` where `Output = { fx: number, fy: number, slipAngleDeg: number, saturated: boolean }`.
- `Tire.AxleConfig` is exactly `CarConfig.tires.front` / `.rear`.

- [ ] **Step 1: Write the failing spec `src/shared/Tests/Tire.spec.luau`**

```lua
--!strict
local Tire = require(script.Parent.Parent.VehicleSim.Tire)

return function(t)
	local axle = { grip = 1.0, peakSlipDeg = 8, slideSlipDeg = 24, slideGripRatio = 0.7 }

	-- Grip curve: linear rise, peak, linear decay, floor
	t.near(Tire.gripCurve(0, axle), 0, 1e-9, "zero slip")
	t.near(Tire.gripCurve(4, axle), 0.5, 1e-9, "half peak")
	t.near(Tire.gripCurve(8, axle), 1, 1e-9, "peak")
	t.near(Tire.gripCurve(16, axle), 0.85, 1e-9, "halfway down")
	t.near(Tire.gripCurve(24, axle), 0.7, 1e-9, "floor reached")
	t.near(Tire.gripCurve(80, axle), 0.7, 1e-9, "stays at floor")
	t.near(Tire.gripCurve(-8, axle), 1, 1e-9, "symmetric")

	-- Slip angle sign: sliding right (+vLat) => positive angle
	t.near(Tire.slipAngleDeg(10, 10), 45, 1e-9, "45 deg")
	t.near(Tire.slipAngleDeg(10, -10), -45, 1e-9, "-45 deg")
	t.near(Tire.slipAngleDeg(-10, 10), 45, 1e-9, "reversing uses |vLong|")

	-- Friction circle
	local fx, fy, sat = Tire.combine(0, 5000, 4000, 0.7)
	t.near(fx, 0, 1e-9, "no long demand")
	t.near(fy, 4000, 1e-9, "lateral clamps to circle")
	t.eq(sat, false, "not saturated")
	fx, fy, sat = Tire.combine(3000, 4000, 5000, 0.7)
	t.near(fx, 3000, 1e-9, "long has priority")
	t.near(fy, 4000, 1e-9, "3-4-5 fits")
	fx, fy, sat = Tire.combine(3000, -4000, 4000, 0.7)
	t.near(fy, -math.sqrt(4000 ^ 2 - 3000 ^ 2), 1e-6, "lateral reduced by long")
	fx, fy, sat = Tire.combine(6000, 2000, 4000, 0.7)
	t.eq(sat, true, "over the circle -> saturated")
	t.near(fx, 2800, 1e-9, "spinning long force = fMax * slide ratio")
	t.near(fy, 1400, 1e-9, "spinning lateral = demand * slide ratio")

	-- compute: sliding right at 20 m/s, 4000 N load -> leftward force
	local out = Tire.compute(20, 20, 4000, axle, 1, 0, 1)
	t.near(out.slipAngleDeg, 45, 1e-9, "slip angle")
	t.ok(out.fy < 0, "force opposes slide")
	t.near(out.fy, -4000 * Tire.gripCurve(45, axle), 1e-6, "magnitude from curve")
	-- speed fade at 0.2 m/s
	local slow = Tire.compute(0.1, 0.1, 4000, axle, 1, 0, 1)
	t.ok(math.abs(slow.fy) < 0.15 * 4000, "fades at low speed")
	-- drive force is not faded
	local drive = Tire.compute(0, 0, 4000, axle, 1, 1000, 1)
	t.near(drive.fx, 1000, 1e-9, "drive force at standstill")
	-- grip multiplier (handbrake) shrinks the circle
	local hb = Tire.compute(20, 20, 4000, axle, 0.35, 0, 1)
	t.near(hb.fy, -4000 * 0.35 * Tire.gripCurve(45, axle), 1e-6, "handbrake multiplier")
	-- no load, no force
	local air = Tire.compute(20, 20, 0, axle, 1, 500, 1)
	t.eq(air.fx, 0, "airborne fx")
	t.eq(air.fy, 0, "airborne fy")
end
```

- [ ] **Step 2: Run runner, expect Tire spec error**

- [ ] **Step 3: Write `src/shared/VehicleSim/Tire.luau`**

```lua
--!strict
-- Slip-angle tire model for one wheel. Pure: no Roblox instances.
--
-- Lateral grip rises linearly with slip angle to a peak, then decays to a
-- sliding floor. The falloff is what makes drift controllable: past the
-- peak the rear gives up some grip but not all, so a held slide is a
-- balance rather than a switch. Front and rear axles are tuned separately.
--
-- Combined force uses a friction circle with longitudinal demand taking
-- priority (the driver commands it): throttle eats rear lateral grip, so
-- too much throttle spins and too little straightens.
local Tire = {}

export type AxleConfig = {
	grip: number, -- peak friction coefficient
	peakSlipDeg: number, -- slip angle where grip peaks
	slideSlipDeg: number, -- slip angle where grip reaches the floor
	slideGripRatio: number, -- floor as a fraction of peak
}

export type Output = {
	fx: number, -- N along wheel heading (+ forward)
	fy: number, -- N along wheel right (+ right)
	slipAngleDeg: number,
	saturated: boolean, -- longitudinal demand exceeded the circle (spin/lock)
}

function Tire.gripCurve(slipDeg: number, axle: AxleConfig): number
	local a = math.abs(slipDeg)
	if a <= axle.peakSlipDeg then
		return a / axle.peakSlipDeg
	end
	if a >= axle.slideSlipDeg then
		return axle.slideGripRatio
	end
	local t = (a - axle.peakSlipDeg) / (axle.slideSlipDeg - axle.peakSlipDeg)
	return 1 - (1 - axle.slideGripRatio) * t
end

-- + when the contact patch moves to the right of the wheel heading.
function Tire.slipAngleDeg(vLong: number, vLat: number): number
	return math.deg(math.atan2(vLat, math.abs(vLong)))
end

function Tire.combine(fxDemand: number, fyDemand: number, fMax: number, slideGripRatio: number): (number, number, boolean)
	if fMax <= 0 then
		return 0, 0, false
	end
	if math.abs(fxDemand) > fMax then
		-- Wheel spinning or locked: both components drop to the sliding level.
		return math.sign(fxDemand) * fMax * slideGripRatio, fyDemand * slideGripRatio, true
	end
	local fyMax = math.sqrt(fMax * fMax - fxDemand * fxDemand)
	return fxDemand, math.clamp(fyDemand, -fyMax, fyMax), false
end

function Tire.compute(
	vLong: number,
	vLat: number,
	load: number,
	axle: AxleConfig,
	gripMultiplier: number,
	fxDemand: number,
	speedFadeMps: number
): Output
	if load <= 0 then
		return { fx = 0, fy = 0, slipAngleDeg = 0, saturated = false }
	end
	local slip = Tire.slipAngleDeg(vLong, vLat)
	local fMax = load * axle.grip * gripMultiplier
	local fyDemand = -math.sign(vLat) * fMax * Tire.gripCurve(slip, axle)
	local fx, fy, saturated = Tire.combine(fxDemand, fyDemand, fMax, axle.slideGripRatio)
	-- Lateral force fades out near standstill so a parked car does not
	-- twitch from numerical noise. Drive/brake demand is not faded here;
	-- braking is faded by the caller.
	local speed = math.sqrt(vLong * vLong + vLat * vLat)
	local fade = math.clamp(speed / speedFadeMps, 0, 1)
	return { fx = fx, fy = fy * fade, slipAngleDeg = slip, saturated = saturated }
end

return Tire
```

- [ ] **Step 4: Run runner, expect all pass. Commit**

```bash
git add -A && git commit -m "feat: slip-angle tire model with friction circle and spec"
```

---

### Task 7: Drivetrain module (pure) + spec

**Files:**
- Create: `src/shared/VehicleSim/Drivetrain.luau`, `src/shared/Tests/Drivetrain.spec.luau`

**Interfaces:**
- Produces: `Drivetrain.new(cfg): State`; `Drivetrain.step(state, cfg, kick, wheelRadius, dt, throttleIn, brakeIn, clutchKick, rearWheelSpeedMps, rearSpinning): Output` with `Output = { drivePerRearWheel, brakePerFrontWheel, brakePerRearWheel, engineBrakePerRearWheel, rpm, gear, torque }` (all numbers), `State = { gear: number, rpm: number, spinRpm: number, shiftTimer: number, kickTimer: number, kickHeld: boolean }`.
- `Drivetrain.Config` is `CarConfig.drivetrain`; `kick` is `CarConfig.clutchKick`.

- [ ] **Step 1: Write the failing spec `src/shared/Tests/Drivetrain.spec.luau`**

```lua
--!strict
local Drivetrain = require(script.Parent.Parent.VehicleSim.Drivetrain)

return function(t)
	local cfg = {
		torqueCurve = { { 1000, 200 }, { 4000, 300 }, { 7000, 0 } },
		gearRatios = { 3.5, 2.1, 1.4 },
		reverseRatio = 3.2,
		finalDrive = 3.9,
		drivelineEfficiency = 0.9,
		idleRpm = 900,
		redlineRpm = 6800,
		upshiftRpm = 6400,
		downshiftRpm = 3000,
		shiftTime = 0.15,
		spinRpmRate = 6000,
		engineBrakeTorque = 40,
		brakeForce = 14000,
		brakeBias = 0.65,
		brakeFadeMps = 0.5,
	}
	local kick = { multiplier = 2.5, duration = 0.3 }
	local r = 0.33
	local dt = 1 / 60

	-- Standstill, full throttle, gear 1: rpm idle, torque from curve at idle
	local st = Drivetrain.new(cfg)
	local out = Drivetrain.step(st, cfg, kick, r, dt, 1, 0, false, 0, false)
	t.eq(out.gear, 1, "starts in gear 1")
	t.near(out.rpm, 900, 1e-9, "idle rpm at standstill")
	local torqueAtIdle = 200 -- curve clamps below 1000
	t.near(out.torque, torqueAtIdle, 1e-9, "torque from curve")
	t.near(out.drivePerRearWheel, torqueAtIdle * 3.5 * 3.9 * 0.9 / r / 2, 1e-6, "drive force per wheel")

	-- 20 m/s in gear 1: rpm from wheels = 20/0.33 * 13.65 * 60/2pi = 7900 -> clamps to redline, upshifts
	st = Drivetrain.new(cfg)
	out = Drivetrain.step(st, cfg, kick, r, dt, 1, 0, false, 20, false)
	t.eq(out.gear, 2, "upshifts above upshiftRpm")
	t.near(out.torque, 0, 1e-9, "torque cut during shift")

	-- Clutch kick edge multiplies torque for its duration
	st = Drivetrain.new(cfg)
	out = Drivetrain.step(st, cfg, kick, r, dt, 1, 0, true, 5, false)
	local base = Drivetrain.step(Drivetrain.new(cfg), cfg, kick, r, dt, 1, 0, false, 5, false)
	t.near(out.torque, base.torque * 2.5, 1e-6, "kick multiplies torque")
	out = Drivetrain.step(st, cfg, kick, r, 0.31, 1, 0, true, 5, false) -- held, timer expires
	t.near(out.torque, base.torque, 1e-6, "kick expires and does not retrigger while held")

	-- Engine brake on lift
	st = Drivetrain.new(cfg)
	out = Drivetrain.step(st, cfg, kick, r, dt, 0, 0, false, 10, false)
	t.ok(out.engineBrakePerRearWheel > 0, "engine brake when lifted")
	t.near(out.drivePerRearWheel, 0, 1e-9, "no drive when lifted")

	-- Brakes split by bias
	out = Drivetrain.step(st, cfg, kick, r, dt, 0, 1, false, 10, false)
	t.near(out.brakePerFrontWheel, 14000 * 0.65 / 2, 1e-9, "front brake")
	t.near(out.brakePerRearWheel, 14000 * 0.35 / 2, 1e-9, "rear brake")

	-- Reverse: brake held at standstill with no throttle engages reverse, drive is negative
	st = Drivetrain.new(cfg)
	out = Drivetrain.step(st, cfg, kick, r, dt, 0, 1, false, 0, false)
	t.eq(out.gear, -1, "enters reverse")
	t.ok(out.drivePerRearWheel < 0, "reverse drive is negative")
	t.near(out.brakePerRearWheel, 0, 1e-9, "brake pedal drives in reverse")
	out = Drivetrain.step(st, cfg, kick, r, dt, 1, 0, false, -0.2, false)
	t.eq(out.gear, 1, "throttle from near-standstill leaves reverse")

	-- Wheelspin: rpm floats up toward redline
	st = Drivetrain.new(cfg)
	for _ = 1, 30 do
		out = Drivetrain.step(st, cfg, kick, r, dt, 1, 0, false, 5, true)
	end
	t.ok(out.rpm > 3000, "rpm climbs while spinning")
	t.eq(out.gear, 1, "spin does not upshift")
end
```

- [ ] **Step 2: Run runner, expect Drivetrain spec error**

- [ ] **Step 3: Write `src/shared/VehicleSim/Drivetrain.luau`**

```lua
--!strict
-- Engine, automatic gearbox, brakes, clutch kick. Pure: no Roblox instances.
--
-- Wheel spin is not integrated as a wheel angular velocity (too stiff for a
-- 60 Hz step). Instead the tire reports whether longitudinal demand exceeded
-- the friction circle; while it does, the engine rpm floats toward redline
-- and the drive force sits at the sliding level. Rpm otherwise derives from
-- rear wheel speed through the gearing, like a locked diff.
local Curve = require(script.Parent.Parent.Curve)

local Drivetrain = {}

export type Config = {
	torqueCurve: Curve.Points,
	gearRatios: { number },
	reverseRatio: number,
	finalDrive: number,
	drivelineEfficiency: number,
	idleRpm: number,
	redlineRpm: number,
	upshiftRpm: number,
	downshiftRpm: number,
	shiftTime: number,
	spinRpmRate: number,
	engineBrakeTorque: number,
	brakeForce: number,
	brakeBias: number,
	brakeFadeMps: number,
}

export type KickConfig = { multiplier: number, duration: number }

export type State = {
	gear: number, -- -1 reverse, 1..n
	rpm: number,
	spinRpm: number,
	shiftTimer: number,
	kickTimer: number,
	kickHeld: boolean,
}

export type Output = {
	drivePerRearWheel: number, -- N, signed (+ forward)
	brakePerFrontWheel: number, -- N magnitude
	brakePerRearWheel: number,
	engineBrakePerRearWheel: number, -- N magnitude
	rpm: number,
	gear: number,
	torque: number, -- Nm at the crank after throttle/kick/cut
}

local RPM_PER_RAD_S = 60 / (2 * math.pi)
local REVERSE_ENGAGE_MPS = 0.5

function Drivetrain.new(cfg: Config): State
	return { gear = 1, rpm = cfg.idleRpm, spinRpm = 0, shiftTimer = 0, kickTimer = 0, kickHeld = false }
end

function Drivetrain.step(
	state: State,
	cfg: Config,
	kick: KickConfig,
	wheelRadius: number,
	dt: number,
	throttleIn: number,
	brakeIn: number,
	clutchKick: boolean,
	rearWheelSpeedMps: number,
	rearSpinning: boolean
): Output
	local speed = rearWheelSpeedMps
	local throttle, brake = throttleIn, brakeIn

	-- Reverse: brake at a standstill engages it, throttle at a standstill leaves it.
	if state.gear == -1 then
		if throttleIn > 0 and speed > -REVERSE_ENGAGE_MPS then
			state.gear = 1
		end
	elseif brakeIn > 0 and throttleIn == 0 and math.abs(speed) < REVERSE_ENGAGE_MPS then
		state.gear = -1
	end

	local ratio: number
	if state.gear == -1 then
		ratio = -cfg.reverseRatio
		throttle, brake = brakeIn, throttleIn -- pedals swap meaning in reverse
	else
		ratio = cfg.gearRatios[state.gear]
	end
	local overall = ratio * cfg.finalDrive

	-- Rpm from the wheels, or floating up while the rear spins.
	local rpmFromWheel = math.abs(speed / wheelRadius * overall) * RPM_PER_RAD_S
	if rearSpinning and throttle > 0.1 then
		state.spinRpm = math.min(cfg.redlineRpm, math.max(state.spinRpm, rpmFromWheel) + cfg.spinRpmRate * throttle * dt)
	else
		state.spinRpm = math.max(rpmFromWheel, state.spinRpm - cfg.spinRpmRate * 2 * dt)
	end
	local rpm = math.clamp(math.max(rpmFromWheel, state.spinRpm), cfg.idleRpm, cfg.redlineRpm)
	state.rpm = rpm

	-- Automatic gearbox on wheel-derived rpm (wheelspin never upshifts).
	if state.shiftTimer > 0 then
		state.shiftTimer -= dt
	end
	if state.gear >= 1 and state.shiftTimer <= 0 then
		if rpmFromWheel >= cfg.upshiftRpm and state.gear < #cfg.gearRatios then
			state.gear += 1
			state.shiftTimer = cfg.shiftTime
		elseif rpmFromWheel <= cfg.downshiftRpm and state.gear > 1 then
			state.gear -= 1
			state.shiftTimer = cfg.shiftTime
		end
	end

	-- Clutch kick: edge-triggered torque spike. Holding does not retrigger.
	if clutchKick and not state.kickHeld then
		state.kickTimer = kick.duration
	end
	state.kickHeld = clutchKick
	state.kickTimer -= dt
	local kickMult = if state.kickTimer > 0 then kick.multiplier else 1

	-- Crank torque. Zero during a shift and at the rev limiter.
	local torque = 0
	if state.shiftTimer <= 0 and rpm < cfg.redlineRpm then
		torque = Curve.lookup(cfg.torqueCurve, rpm) * throttle * kickMult
	end
	local drivePerRearWheel = torque * overall * cfg.drivelineEfficiency / wheelRadius / 2

	-- Engine braking on lift: moves weight forward, which is what makes a
	-- lift-and-flick transition swing the rear.
	local engineBrake = 0
	if throttle < 0.05 and state.gear >= 1 then
		engineBrake = cfg.engineBrakeTorque * math.abs(overall) / wheelRadius / 2 * (rpm / cfg.redlineRpm)
	end

	local brakeTotal = cfg.brakeForce * brake
	return {
		drivePerRearWheel = drivePerRearWheel,
		brakePerFrontWheel = brakeTotal * cfg.brakeBias / 2,
		brakePerRearWheel = brakeTotal * (1 - cfg.brakeBias) / 2,
		engineBrakePerRearWheel = engineBrake,
		rpm = rpm,
		gear = state.gear,
		torque = torque,
	}
end

return Drivetrain
```

- [ ] **Step 4: Run runner, expect all pass. Commit**

```bash
git add -A && git commit -m "feat: drivetrain module (engine, auto gearbox, brakes, clutch kick) with spec"
```

---

### Task 8: Two-wheel module (pure) + spec

**Files:**
- Create: `src/shared/VehicleSim/TwoWheel.luau`, `src/shared/Tests/TwoWheel.spec.luau`

**Interfaces:**
- Produces: `TwoWheel.new(): State`; `TwoWheel.isActive(state): boolean` (lifting or balanced); `TwoWheel.gravityRestoringTorque(body, rollTowardDeg): number`; `TwoWheel.step(state, cfg, body, held, steer, rollDeg, rollRateDegPerSec, groundedLeft, groundedRight, dt): number` returning roll torque in Nm about the car's forward axis in world roll sign (+ rolls right).
- `State = { mode: "idle" | "lifting" | "balanced" | "tipped" | "landing", side: number, rollDeg: number, marginDeg: number }`; `Body = { massKg, gravity, comHeightM, halfTrackM }`; `TwoWheel.Config` is `CarConfig.twoWheel`.
- Sign conventions: `side = +1` means the car rolls right (right wheels stay down, left wheels lift). `rollDeg` + = right side lower. Steer + = right.

- [ ] **Step 1: Write the failing spec `src/shared/Tests/TwoWheel.spec.luau`**

```lua
--!strict
local TwoWheel = require(script.Parent.Parent.VehicleSim.TwoWheel)

return function(t)
	local cfg = {
		liftTorque = 12000,
		gravityCancel = 1.0,
		targetRollDeg = 42,
		instability = 5,
		rollDamping = 20,
		balanceTorque = 1500,
		tipRollDeg = 60,
		landingDamping = 60,
		suspensionBias = 1.8,
	}
	local body = { massKg = 1600, gravity = 9.81, comHeightM = 0.52, halfTrackM = 0.775 }
	local dt = 1 / 60

	-- Gravity torque: full restoring at 0 roll, zero at the static tip angle
	t.near(TwoWheel.gravityRestoringTorque(body, 0), 1600 * 9.81 * 0.775, 1e-6, "restoring at level")
	local tipDeg = math.deg(math.atan(0.775 / 0.52))
	t.near(TwoWheel.gravityRestoringTorque(body, tipDeg), 0, 1e-6, "zero at tip angle")
	t.ok(TwoWheel.gravityRestoringTorque(body, 70) < 0, "negative past tip")

	-- Idle, not held: nothing
	local st = TwoWheel.new()
	t.near(TwoWheel.step(st, cfg, body, false, 0, 0, 0, 2, 2, dt), 0, 1e-9, "idle no torque")
	t.eq(st.mode, "idle", "stays idle")
	t.eq(TwoWheel.isActive(st), false, "idle inactive")

	-- Press with no steer: lifts to the left (side -1), world torque negative
	local tq = TwoWheel.step(st, cfg, body, true, 0, 0, 0, 2, 2, dt)
	t.eq(st.mode, "lifting", "enters lifting")
	t.eq(st.side, -1, "default side left")
	t.near(tq, -12000, 1e-9, "lift torque toward left")
	t.eq(TwoWheel.isActive(st), true, "lifting active")

	-- Press with right steer: side +1
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 0.6, 0, 0, 2, 2, dt)
	t.eq(st.side, 1, "steer picks side")

	-- Reaching target-5 while lifting -> balanced; torque = gravity cancel + instability + damping
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 0.6, 0, 0, 2, 2, dt)
	tq = TwoWheel.step(st, cfg, body, true, 0, 38, 10, 0, 2, dt)
	t.eq(st.mode, "balanced", "enters balanced")
	local expected = TwoWheel.gravityRestoringTorque(body, 38) * 1.0 + 5 * (38 - 42) - 20 * 10
	t.near(tq, expected, 1e-6, "balanced torque")
	t.near(st.marginDeg, 60 - 38, 1e-9, "margin to tip")

	-- Steering toward the grounded side (steer +, side +) reduces the torque
	local withBalance = TwoWheel.step(st, cfg, body, true, 1, 38, 0, 0, 2, dt)
	local noBalance = TwoWheel.step(st, cfg, body, true, 0, 38, 0, 0, 2, dt)
	t.near(withBalance, noBalance - 1500, 1e-6, "balance input reduces roll")

	-- Past the tip angle: tipped, zero torque
	tq = TwoWheel.step(st, cfg, body, true, 0, 61, 0, 0, 2, dt)
	t.eq(st.mode, "tipped", "tips")
	t.near(tq, 0, 1e-9, "no torque when tipped")
	t.eq(TwoWheel.isActive(st), false, "tipped inactive")
	TwoWheel.step(st, cfg, body, false, 0, 80, 0, 0, 0, dt)
	t.eq(st.mode, "idle", "release after tip -> idle")

	-- Release while balanced -> landing with damping, then idle when all four touch
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 0.6, 0, 0, 2, 2, dt)
	TwoWheel.step(st, cfg, body, true, 0, 40, 0, 0, 2, dt)
	tq = TwoWheel.step(st, cfg, body, false, 0, 40, -30, 0, 2, dt)
	t.eq(st.mode, "landing", "release -> landing")
	t.near(tq, -60 * -30, 1e-6, "landing damping opposes roll rate (world sign)")
	TwoWheel.step(st, cfg, body, false, 0, 1, -5, 2, 2, dt)
	t.eq(st.mode, "idle", "landed")

	-- Balanced with roll falling back to level -> idle
	st = TwoWheel.new()
	TwoWheel.step(st, cfg, body, true, 0.6, 0, 0, 2, 2, dt)
	TwoWheel.step(st, cfg, body, true, 0, 40, 0, 0, 2, dt)
	TwoWheel.step(st, cfg, body, true, 0, 2, -50, 2, 2, dt)
	t.eq(st.mode, "idle", "came back down while held -> idle (can re-lift)")
end
```

- [ ] **Step 2: Run runner, expect TwoWheel spec error**

- [ ] **Step 3: Write `src/shared/VehicleSim/TwoWheel.luau`**

```lua
--!strict
-- Two-wheel ("natl") mode. Pure: no Roblox instances.
--
-- The car is an inverted pendulum pivoting on the two grounded contact
-- patches. Gravity's torque about that line is
--   m g (halfTrack cos(roll) - comHeight sin(roll))
-- which restores the car while roll is below the static tip angle
-- atan(halfTrack / comHeight) and pushes it over past that.
--
-- While balanced the controller cancels a configurable fraction of that
-- restoring torque and adds a small divergence (instability) so the
-- equilibrium is slightly unstable: ignore it and the car leans further,
-- correct it with steer and it comes back. Nothing here ever pulls the car
-- back toward the target angle by itself, so it is never "magnetized".
-- Past tipRollDeg the controller lets go and gravity finishes the job.
--
-- Frame: all torques are computed "toward the chosen side" (positive =
-- rolling further onto two wheels) and converted to the world roll sign
-- (+ = right side lower) by multiplying with side on return.
local TwoWheel = {}

export type Config = {
	liftTorque: number,
	gravityCancel: number,
	targetRollDeg: number,
	instability: number,
	rollDamping: number,
	balanceTorque: number,
	tipRollDeg: number,
	landingDamping: number,
	suspensionBias: number,
}

export type Body = {
	massKg: number,
	gravity: number,
	comHeightM: number,
	halfTrackM: number,
}

export type State = {
	mode: string, -- idle | lifting | balanced | tipped | landing
	side: number, -- +1 roll right (left wheels lift), -1 roll left
	rollDeg: number,
	marginDeg: number, -- degrees left before tipRollDeg
}

local SIDE_PICK_STEER = 0.2
local BALANCED_ENTRY_MARGIN_DEG = 5
local LANDED_ROLL_DEG = 3

function TwoWheel.new(): State
	return { mode = "idle", side = -1, rollDeg = 0, marginDeg = 0 }
end

function TwoWheel.isActive(state: State): boolean
	return state.mode == "lifting" or state.mode == "balanced"
end

-- Gravity's torque about the grounded contact line. Positive pushes the car
-- back down onto four wheels; negative (past the tip angle) pushes it over.
function TwoWheel.gravityRestoringTorque(body: Body, rollTowardDeg: number): number
	local th = math.rad(rollTowardDeg)
	return body.massKg * body.gravity * (body.halfTrackM * math.cos(th) - body.comHeightM * math.sin(th))
end

function TwoWheel.step(
	state: State,
	cfg: Config,
	body: Body,
	held: boolean,
	steer: number,
	rollDeg: number,
	rollRateDegPerSec: number,
	groundedLeft: number,
	groundedRight: number,
	dt: number
): number
	state.rollDeg = rollDeg

	if state.mode == "idle" then
		if not held then
			state.marginDeg = cfg.tipRollDeg
			return 0
		end
		state.side = if steer > SIDE_PICK_STEER then 1 elseif steer < -SIDE_PICK_STEER then -1 else -1
		state.mode = "lifting"
	elseif not held and state.mode ~= "landing" then
		state.mode = if state.mode == "tipped" then "idle" else "landing"
		if state.mode == "idle" then
			return 0
		end
	end

	local s = state.side
	local roll = rollDeg * s -- + = leaning onto the chosen side
	local rate = rollRateDegPerSec * s
	local torque = 0

	if state.mode == "lifting" then
		torque = cfg.liftTorque
		if roll >= cfg.targetRollDeg - BALANCED_ENTRY_MARGIN_DEG then
			state.mode = "balanced"
		end
	end

	if state.mode == "balanced" then
		if roll >= cfg.tipRollDeg then
			state.mode = "tipped"
			state.marginDeg = 0
			return 0
		end
		if roll < LANDED_ROLL_DEG then
			-- Came back down while still held: allow a fresh lift next press.
			state.mode = "idle"
			return 0
		end
		-- Cancel (most of) gravity's restoring torque, then diverge gently
		-- from the target so the player has to keep balancing.
		local cancel = math.max(TwoWheel.gravityRestoringTorque(body, roll), 0) * cfg.gravityCancel
		torque = cancel + cfg.instability * (roll - cfg.targetRollDeg) - cfg.rollDamping * rate
	end

	if state.mode == "lifting" or state.mode == "balanced" then
		-- Balance input: steering toward the grounded side brings the car
		-- down, steering away lifts it further. Same on every platform.
		torque -= cfg.balanceTorque * steer * s
	elseif state.mode == "landing" then
		torque = -cfg.landingDamping * rate
		if groundedLeft + groundedRight >= 4 or roll < LANDED_ROLL_DEG then
			state.mode = "idle"
		end
	elseif state.mode == "tipped" then
		torque = 0
	end

	state.marginDeg = cfg.tipRollDeg - roll
	return torque * s
end

return TwoWheel
```

- [ ] **Step 4: Run runner, expect all pass. Commit**

```bash
git add -A && git commit -m "feat: two-wheel balance module with spec"
```

---

### Task 9: VehicleSim glue, client controller, input aggregation, server driverless sim

**Files:**
- Create: `src/shared/VehicleSim/init.luau`, `src/client/VehicleController.luau`, `src/client/Input/init.luau`
- Modify: `src/server/init.server.luau`, `src/client/init.client.luau`

**Interfaces:**
- Produces: `VehicleSim.new(model, config): Sim`; `sim:step(input, dt): VehicleState`; `sim:setConfig(config)`; `sim:setCharacter(character: Model?)`.
- Produces: `Input.get(dt, config): InputState`; `Input.raw` table sources write into (Task 11); `Input.pulse(name)` for edge actions; attribute override on `Players.LocalPlayer`: `InputOverride: boolean`, `OvThrottle`, `OvBrake`, `OvSteer: number`, `OvHandbrake`, `OvTwoWheel`, `OvClutchKick: boolean` (consumed).
- Produces: `VehicleController.start(model, remotes)`, `VehicleController.stop()`, `VehicleController.lastState: VehicleState?`, `VehicleController.onState: ((VehicleState) -> ())?` hook used by DebugPanel and CameraRig.
- Consumes: Task 4 model layout, Task 5–8 modules.

- [ ] **Step 1: Write `src/shared/VehicleSim/init.luau`**

```lua
--!strict
-- Glue between Roblox and the pure physics modules. One instance per car.
-- step() raycasts each corner, computes every force in SI about the centre
-- of mass, writes one VectorForce and one Torque on the chassis, repositions
-- the visual wheels, and returns a VehicleState for the debug panel.
--
-- Runs on whoever owns the assembly: the driving client, or the server for a
-- parked car (zero input) so it keeps sitting on its springs.
local Shared = script.Parent
local Types = require(Shared.Types)
local Units = require(Shared.Units)
local CarConfig = require(Shared.CarConfig)
local Suspension = require(script.Suspension)
local Tire = require(script.Tire)
local Drivetrain = require(script.Drivetrain)
local TwoWheel = require(script.TwoWheel)

type Config = CarConfig.Config
type InputState = Types.InputState
type VehicleState = Types.VehicleState
type WheelState = Types.WheelState

type Wheel = {
	name: string,
	front: boolean,
	left: boolean,
	attachment: Attachment,
	part: BasePart,
	weld: Weld,
	compression: number,
	spinAngle: number,
	state: WheelState,
}

type Contact = {
	wheel: Wheel,
	hitDistM: number?,
	susp: Suspension.Result,
	hpM: Vector3,
	contactM: Vector3,
	normal: Vector3,
	heading: Vector3,
	right: Vector3,
	vLong: number,
	vLat: number,
	steerDeg: number,
}

local VehicleSim = {}
VehicleSim.__index = VehicleSim

export type Sim = typeof(setmetatable(
	{} :: {
		config: Config,
		model: Model,
		chassis: BasePart,
		vectorForce: VectorForce,
		torque: Torque,
		rayParams: RaycastParams,
		wheels: { Wheel },
		drivetrain: Drivetrain.State,
		twoWheel: TwoWheel.State,
		steerDeg: number,
		comHeightM: number,
		lastState: VehicleState,
	},
	VehicleSim
))

local WHEEL_DEFS = {
	{ name = "FL", front = true, left = true },
	{ name = "FR", front = true, left = false },
	{ name = "RL", front = false, left = true },
	{ name = "RR", front = false, left = false },
}

local function newWheelState(name: string): WheelState
	return {
		name = name,
		grounded = false,
		compression = 0,
		load = 0,
		slipAngleDeg = 0,
		saturated = false,
		steerDeg = 0,
		fx = 0,
		fy = 0,
	}
end

local function emptyState(wheels: { Wheel }): VehicleState
	local ws = {}
	for _, w in wheels do
		table.insert(ws, w.state)
	end
	return {
		speedMps = 0,
		speedKmh = 0,
		gear = 1,
		rpm = 0,
		throttle = 0,
		brake = 0,
		steer = 0,
		steerDeg = 0,
		driftAngleDeg = 0,
		yawRateDegPerSec = 0,
		twoWheelMode = "idle",
		rollDeg = 0,
		rollMarginDeg = 0,
		handbrake = false,
		clutchKick = false,
		driftAssist = 0,
		wheels = ws,
	}
end

local function isFinite(v: Vector3): boolean
	local m = v.Magnitude
	return m == m and m ~= math.huge
end

function VehicleSim.new(model: Model, config: Config): Sim
	local chassis = model.PrimaryPart :: BasePart
	local wheels: { Wheel } = {}
	for _, def in WHEEL_DEFS do
		local part = model:FindFirstChild("Wheel_" .. def.name) :: BasePart
		local weld = part:FindFirstChild("WheelWeld") :: Weld
		local attachment = chassis:FindFirstChild("Hardpoint_" .. def.name) :: Attachment
		table.insert(wheels, {
			name = def.name,
			front = def.front,
			left = def.left,
			attachment = attachment,
			part = part,
			weld = weld,
			compression = 0,
			spinAngle = 0,
			state = newWheelState(def.name),
		})
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { model }
	rayParams.IgnoreWater = true

	local self = setmetatable({
		config = config,
		model = model,
		chassis = chassis,
		vectorForce = chassis:FindFirstChild("SimForce") :: VectorForce,
		torque = chassis:FindFirstChild("SimTorque") :: Torque,
		rayParams = rayParams,
		wheels = wheels,
		drivetrain = Drivetrain.new(config.drivetrain),
		twoWheel = TwoWheel.new(),
		steerDeg = 0,
		comHeightM = 0.5,
		lastState = emptyState(wheels),
	}, VehicleSim)
	return self
end

function VehicleSim.setConfig(self: Sim, config: Config)
	self.config = config
end

-- The seated character is welded into the assembly; keep it out of the rays.
function VehicleSim.setCharacter(self: Sim, character: Model?)
	self.rayParams.FilterDescendantsInstances = if character then { self.model, character } else { self.model }
end

function VehicleSim.step(self: Sim, input: InputState, dt: number): VehicleState
	local cfg = self.config
	local mps = cfg.units.metersPerStud
	local chassis = self.chassis
	local cf = chassis.CFrame
	local up, forward, right = cf.UpVector, cf.LookVector, cf.RightVector
	local comM = chassis.AssemblyCenterOfMass * mps
	local vel = chassis.AssemblyLinearVelocity * mps -- m/s
	local angVel = chassis.AssemblyAngularVelocity -- rad/s
	local mass = chassis.AssemblyMass -- kg by convention (plus the seated character)
	local g = cfg.units.gravity
	local speed = vel.Magnitude

	local totalForce = Vector3.zero -- N, world
	local totalTorque = Vector3.zero -- Nm, world, about the centre of mass

	local function applyAt(force: Vector3, pointM: Vector3)
		totalForce += force
		totalTorque += (pointM - comM):Cross(force)
	end

	-- 1. Gravity correction. workspace.Gravity is 196.2 studs/s²; the car
	--    should fall at cfg.units.gravity. Push up by the difference so every
	--    load, roll and tip number downstream is honest. See DESIGN.md.
	totalForce += Vector3.new(0, mass * (workspace.Gravity * mps - g), 0)

	-- 2. Steering with rate limits and drift assist.
	local vLongBody = vel:Dot(forward)
	local vLatBody = vel:Dot(right)
	local driftAngleDeg = if speed > 1 then math.deg(math.atan2(vLatBody, vLongBody)) else 0
	-- Assist uses |vLong| so reversing does not read as a 180° drift.
	local assistAngleDeg = if speed > 1 then math.deg(math.atan2(vLatBody, math.abs(vLongBody))) else 0
	local steerTarget = input.steer * cfg.steering.maxSteerDeg
	local returning = math.abs(steerTarget) < math.abs(self.steerDeg) or steerTarget * self.steerDeg < 0
	local rate = if returning then cfg.steering.steerReturnDegPerSec else cfg.steering.steerSpeedDegPerSec
	self.steerDeg += math.clamp(steerTarget - self.steerDeg, -rate * dt, rate * dt)
	-- Drift angle + means velocity is right of heading (tail out left), so
	-- counter-steer is to the right: add a fraction of it.
	local effectiveSteerDeg = math.clamp(
		self.steerDeg + cfg.steering.driftAssist * assistAngleDeg,
		-cfg.steering.maxSteerDeg,
		cfg.steering.maxSteerDeg
	)

	-- 3. Raycasts and suspension.
	local twoWheelActive = TwoWheel.isActive(self.twoWheel)
	local rayLenM = Suspension.rayLengthM(cfg.suspension, cfg.body.wheelRadius)
	local contacts: { Contact } = {}
	local groundedLeft, groundedRight = 0, 0
	local groundYSum, groundCount = 0, 0
	for _, wheel in self.wheels do
		local hpStuds = wheel.attachment.WorldPosition
		local hit = workspace:Raycast(hpStuds, -up * (rayLenM / mps), self.rayParams)
		local hitDistM = if hit then hit.Distance * mps else nil
		-- Two-wheel: the loaded side carries double weight; stiffen it.
		local stiffnessMult = 1
		if twoWheelActive and ((self.twoWheel.side > 0) == (not wheel.left)) then
			stiffnessMult = cfg.twoWheel.suspensionBias
		end
		local susp = Suspension.step(wheel.compression, hitDistM, cfg.suspension, cfg.body.wheelRadius, stiffnessMult, dt)
		wheel.compression = susp.compression
		local hpM = hpStuds * mps
		local contactM = if hit then hit.Position * mps else hpM - up * rayLenM
		local normal = if hit then hit.Normal else up
		if susp.grounded and susp.force > 0 then
			if wheel.left then
				groundedLeft += 1
			else
				groundedRight += 1
			end
			groundYSum += contactM.Y
			groundCount += 1
		end
		local steerDeg = if wheel.front then effectiveSteerDeg else 0
		-- Positive steer = right = clockwise from above = negative rotation about up.
		local headingRaw = CFrame.fromAxisAngle(up, -math.rad(steerDeg)) * forward
		local heading = (headingRaw - normal * headingRaw:Dot(normal)).Unit
		local wRight = heading:Cross(normal) -- forward x up = right
		local vContact = vel + angVel:Cross(contactM - comM)
		table.insert(contacts, {
			wheel = wheel,
			hitDistM = hitDistM,
			susp = susp,
			hpM = hpM,
			contactM = contactM,
			normal = normal,
			heading = heading,
			right = wRight,
			vLong = vContact:Dot(heading),
			vLat = vContact:Dot(wRight),
			steerDeg = steerDeg,
		})
	end

	-- Anti-roll bars: only act when both wheels of an axle carry load.
	local function antiRoll(leftIdx: number, rightIdx: number, k: number)
		local l, r = contacts[leftIdx], contacts[rightIdx]
		if l.susp.force > 0 and r.susp.force > 0 then
			local d = Suspension.antiRoll(k, l.susp.compression, r.susp.compression)
			l.susp.force = math.max(l.susp.force + d, 0)
			r.susp.force = math.max(r.susp.force - d, 0)
		end
	end
	antiRoll(1, 2, cfg.suspension.antiRollFront)
	antiRoll(3, 4, cfg.suspension.antiRollRear)

	-- 4. Drivetrain from rear wheel speed and last step's spin state.
	local rearWheelSpeed = (contacts[3].vLong + contacts[4].vLong) / 2
	local rearSpinning = self.wheels[3].state.saturated or self.wheels[4].state.saturated
	local drive = Drivetrain.step(
		self.drivetrain,
		cfg.drivetrain,
		cfg.clutchKick,
		cfg.body.wheelRadius,
		dt,
		input.throttle,
		input.brake,
		input.clutchKick,
		rearWheelSpeed,
		rearSpinning
	)

	-- 5. Tire forces at the contact patches, suspension forces at the hardpoints.
	for _, c in contacts do
		local w = c.wheel
		local brakeFade = math.clamp(math.abs(c.vLong) / cfg.drivetrain.brakeFadeMps, 0, 1)
		local brakeDir = -math.sign(c.vLong)
		local fxDemand = 0
		local gripMult = 1
		if w.front then
			fxDemand = brakeDir * drive.brakePerFrontWheel * brakeFade
		else
			fxDemand = drive.drivePerRearWheel
				+ brakeDir * (drive.brakePerRearWheel + drive.engineBrakePerRearWheel) * brakeFade
			if input.handbrake then
				-- Handbrake cuts rear grip and drags the rear wheels; it must not stop the car.
				gripMult = cfg.handbrake.rearGripMultiplier
				fxDemand += brakeDir * cfg.handbrake.brakeForce / 2 * brakeFade
			end
		end
		local axle = if w.front then cfg.tires.front else cfg.tires.rear
		local out = Tire.compute(c.vLong, c.vLat, c.susp.force, axle, gripMult, fxDemand, cfg.tires.speedFadeMps)

		-- Tire force acts at ground level: lateral force x CoM height is the
		-- roll moment that loads the outside springs in a slide.
		applyAt(c.heading * out.fx + c.right * out.fy, c.contactM)
		-- Spring force acts along body up at the hardpoint.
		applyAt(up * c.susp.force, c.hpM)

		local ws = w.state
		ws.grounded = c.susp.grounded
		ws.compression = c.susp.compression
		ws.load = c.susp.force
		ws.slipAngleDeg = out.slipAngleDeg
		ws.saturated = out.saturated
		ws.steerDeg = c.steerDeg
		ws.fx = out.fx
		ws.fy = out.fy

		-- Visual wheel: sit at the ray hit (or full droop), steer, and roll.
		-- Forward rolling is a negative rotation about the lateral (+X) axis.
		w.spinAngle -= c.vLong / cfg.body.wheelRadius * dt
		local dropM = if c.hitDistM then math.min(c.hitDistM - cfg.body.wheelRadius, cfg.suspension.restLength) else cfg.suspension.restLength
		w.weld.C0 = CFrame.new(w.attachment.Position - Vector3.new(0, dropM / mps, 0))
			* CFrame.Angles(0, -math.rad(c.steerDeg), 0)
			* CFrame.Angles(w.spinAngle, 0, 0)
	end

	-- 6. Aero drag and rolling resistance at the centre of mass.
	if speed > 0.1 then
		local body = cfg.body
		local dragN = 0.5 * body.airDensity * body.dragCoefficient * body.frontalArea * speed * speed
		local rollN = body.rollingResistance * mass * g * math.clamp(speed, 0, 1) * (groundCount / 4)
		totalForce -= vel.Unit * (dragN + rollN)
	end

	-- 7. Two-wheel roll torque about the forward axis.
	local rollDeg = math.deg(math.asin(math.clamp(-right.Y, -1, 1))) -- + = right side lower
	local rollRate = math.deg(angVel:Dot(forward)) -- same sign convention
	if groundCount > 0 then
		self.comHeightM = comM.Y - groundYSum / groundCount
	end
	local body = { massKg = mass, gravity = g, comHeightM = self.comHeightM, halfTrackM = cfg.body.trackWidth / 2 }
	local rollTorque = TwoWheel.step(
		self.twoWheel,
		cfg.twoWheel,
		body,
		input.twoWheel,
		input.steer,
		rollDeg,
		rollRate,
		groundedLeft,
		groundedRight,
		dt
	)
	totalTorque += forward * rollTorque

	-- 8. Write the actuators. Never let a NaN into the physics engine.
	if not isFinite(totalForce) or not isFinite(totalTorque) then
		warn("[VehicleSim] non-finite force, zeroing this step")
		totalForce = Vector3.zero
		totalTorque = Vector3.zero
	end
	self.vectorForce.Force = Units.forceNToSim(totalForce, mps)
	self.torque.Torque = Units.torqueNmToSim(totalTorque, mps)

	-- 9. State for the debug panel and camera.
	local st = self.lastState
	st.speedMps = speed
	st.speedKmh = Units.mpsToKmh(speed)
	st.gear = drive.gear
	st.rpm = drive.rpm
	st.throttle = input.throttle
	st.brake = input.brake
	st.steer = input.steer
	st.steerDeg = effectiveSteerDeg
	st.driftAngleDeg = driftAngleDeg
	st.yawRateDegPerSec = -math.deg(angVel:Dot(up)) -- + = turning right
	st.twoWheelMode = self.twoWheel.mode
	st.rollDeg = rollDeg
	st.rollMarginDeg = self.twoWheel.marginDeg
	st.handbrake = input.handbrake
	st.clutchKick = self.drivetrain.kickTimer > 0
	st.driftAssist = cfg.steering.driftAssist
	return st
end

return VehicleSim
```

- [ ] **Step 2: Write `src/client/Input/init.luau`**

```lua
--!strict
-- Aggregates raw input from Keyboard, Gamepad and Touch (Task 11) into one
-- InputState per physics step, with per-source steer ramps. Also honours an
-- attribute override on the LocalPlayer so a test harness (the Studio MCP)
-- can drive the car without a keyboard.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local CarConfig = require(Shared.CarConfig)

type Config = CarConfig.Config
type InputState = Types.InputState

export type Raw = {
	throttle: number,
	brake: number,
	steerDigital: number, -- -1, 0, 1 from keys or touch buttons
	steerAnalog: number?, -- gamepad stick, nil when not driving with a pad
	handbrake: boolean,
	twoWheel: boolean,
	source: string, -- "keyboard" | "touch" | "gamepad"
}

local Input = {}

Input.raw = {
	throttle = 0,
	brake = 0,
	steerDigital = 0,
	steerAnalog = nil,
	handbrake = false,
	twoWheel = false,
	source = "keyboard",
} :: Raw

local edges = { clutchKick = false, exit = false, reset = false, reload = false }
local steerRamped = 0

-- Edge-triggered actions call this once per press.
function Input.pulse(name: string)
	edges[name] = true
end

local function readOverride(player: Player): InputState
	local out = Types.newInput()
	out.throttle = math.clamp(tonumber(player:GetAttribute("OvThrottle")) or 0, 0, 1)
	out.brake = math.clamp(tonumber(player:GetAttribute("OvBrake")) or 0, 0, 1)
	out.steer = math.clamp(tonumber(player:GetAttribute("OvSteer")) or 0, -1, 1)
	out.handbrake = player:GetAttribute("OvHandbrake") == true
	out.twoWheel = player:GetAttribute("OvTwoWheel") == true
	if player:GetAttribute("OvClutchKick") == true then
		out.clutchKick = true
		player:SetAttribute("OvClutchKick", false)
	end
	if player:GetAttribute("OvReset") == true then
		out.reset = true
		player:SetAttribute("OvReset", false)
	end
	return out
end

function Input.get(dt: number, cfg: Config): InputState
	local player = Players.LocalPlayer
	if player:GetAttribute("InputOverride") == true then
		return readOverride(player)
	end

	local raw = Input.raw
	local out = Types.newInput()
	out.throttle = raw.throttle
	out.brake = raw.brake
	out.handbrake = raw.handbrake
	out.twoWheel = raw.twoWheel

	if raw.steerAnalog ~= nil then
		out.steer = raw.steerAnalog
		steerRamped = out.steer
	else
		-- Digital steer ramps so a tap is a nudge and a hold is full lock.
		-- Touch ramps slower and through a curve so thumbs get fine control.
		local target = raw.steerDigital
		local rampUp, rampDown, curve
		if raw.source == "touch" then
			rampUp, rampDown, curve = cfg.input.touchSteerRampPerSec, cfg.input.touchSteerReturnPerSec, cfg.input.touchSteerCurve
		else
			rampUp, rampDown, curve = cfg.input.keyboardSteerRampPerSec, cfg.input.keyboardSteerReturnPerSec, 1
		end
		local returning = math.abs(target) < math.abs(steerRamped) or target * steerRamped < 0
		local rate = if returning then rampDown else rampUp
		steerRamped += math.clamp(target - steerRamped, -rate * dt, rate * dt)
		out.steer = math.sign(steerRamped) * math.abs(steerRamped) ^ curve
	end

	out.clutchKick = edges.clutchKick
	out.exit = edges.exit
	out.reset = edges.reset
	out.reload = edges.reload
	edges.clutchKick, edges.exit, edges.reset, edges.reload = false, false, false, false
	return out
end

return Input
```

- [ ] **Step 3: Write `src/client/VehicleController.luau`**

```lua
--!strict
-- Runs VehicleSim on the car this client owns, every PreSimulation.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local ConfigLoader = require(Shared.ConfigLoader)
local VehicleSim = require(Shared.VehicleSim)
local Input = require(script.Parent.Input)

type VehicleState = Types.VehicleState

local VehicleController = {}
VehicleController.lastState = nil :: VehicleState?
VehicleController.onState = nil :: ((VehicleState) -> ())?
VehicleController.onReload = nil :: (() -> ())?

local sim: VehicleSim.Sim? = nil
local car: Model? = nil
local conn: RBXScriptConnection? = nil
local exitRemote: RemoteEvent? = nil

local function setJumpEnabled(enabled: boolean)
	local character = Players.LocalPlayer.Character
	local hum = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if hum then
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled)
	end
end

-- Re-park upright at the nearest point on the road, zero velocity. The
-- client owns the assembly while driving, so it can move it directly.
local function resetCar(model: Model)
	local cfg = ConfigLoader.current()
	local mps = cfg.units.metersPerStud
	local road = workspace:FindFirstChild("Road")
	local chassis = model.PrimaryPart :: BasePart
	local pos = chassis.Position
	local halfWidth = if road then (road:GetAttribute("HalfWidthStuds") :: number) else 100
	local length = if road then (road:GetAttribute("LengthStuds") :: number) else 7000
	local surfaceY = if road then (road:GetAttribute("SurfaceY") :: number) else 0
	local x = math.clamp(pos.X, -halfWidth + 5 / mps, halfWidth - 5 / mps)
	local z = math.clamp(pos.Z, -length, 30 / mps)
	local y = surfaceY + (cfg.body.bodySize[2] / 2 + 0.4) / mps
	model:PivotTo(CFrame.new(x, y, z)) -- identity rotation faces -Z, down the road
	chassis.AssemblyLinearVelocity = Vector3.zero
	chassis.AssemblyAngularVelocity = Vector3.zero
end

function VehicleController.start(model: Model, remotes: Folder)
	VehicleController.stop()
	car = model
	exitRemote = remotes:FindFirstChild("ExitCar") :: RemoteEvent
	local s = VehicleSim.new(model, ConfigLoader.current())
	s:setCharacter(Players.LocalPlayer.Character)
	sim = s
	setJumpEnabled(false)
	conn = RunService.PreSimulation:Connect(function(dt: number)
		local cfg = ConfigLoader.current()
		local input = Input.get(dt, cfg)
		if input.exit and exitRemote then
			exitRemote:FireServer()
		end
		if input.reset then
			resetCar(model)
		end
		if input.reload and VehicleController.onReload then
			VehicleController.onReload()
		end
		local state = s:step(input, dt)
		VehicleController.lastState = state
		if VehicleController.onState then
			VehicleController.onState(state)
		end
	end)
end

function VehicleController.setConfig(config: ConfigLoader.Config)
	if sim then
		sim:setConfig(config)
	end
end

function VehicleController.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if car then
		local chassis = car.PrimaryPart
		if chassis then
			local vf = chassis:FindFirstChild("SimForce") :: VectorForce?
			local tq = chassis:FindFirstChild("SimTorque") :: Torque?
			if vf then
				vf.Force = Vector3.zero
			end
			if tq then
				tq.Torque = Vector3.zero
			end
		end
	end
	setJumpEnabled(true)
	sim = nil
	car = nil
	VehicleController.lastState = nil
end

function VehicleController.isDriving(): boolean
	return sim ~= nil
end

return VehicleController
```

- [ ] **Step 4: Update `src/client/init.client.luau`**

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local driveStart = remotes:WaitForChild("DriveStart") :: RemoteEvent
local driveStop = remotes:WaitForChild("DriveStop") :: RemoteEvent
local VehicleController = require(script.VehicleController)

print("[Hajwala] client boot")
driveStart.OnClientEvent:Connect(function(car: Model)
	print("[Hajwala] DriveStart", car:GetFullName())
	VehicleController.start(car, remotes)
end)
driveStop.OnClientEvent:Connect(function()
	print("[Hajwala] DriveStop")
	VehicleController.stop()
end)
```

- [ ] **Step 5: Plug the sim into the server spawner, `src/server/init.server.luau`**

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared.ConfigLoader)
local VehicleSim = require(Shared.VehicleSim)
local RoadBuilder = require(script.RoadBuilder)
local Remotes = require(script.Remotes)
local CarSpawner = require(script.CarSpawner)

print("[Hajwala] server boot")
local config = ConfigLoader.current()
local road = RoadBuilder.build(config)
local remotes = Remotes.create()
CarSpawner.setSimFactory(function(model: Model, cfg: ConfigLoader.Config): CarSpawner.Sim
	-- VehicleSim.Sim is a metatable type; cast to the spawner's structural Sim interface.
	return (VehicleSim.new(model, cfg) :: any) :: CarSpawner.Sim
end)
CarSpawner.start(config, road, remotes)
print("[Hajwala] ready")
```

- [ ] **Step 6: Verify the car settles on its springs (suspension test)**

Play. The car spawns 0.45 m above rest and drops. After 3 s, `execute_luau` (Server):
```lua
local car = workspace.Cars:GetChildren()[1]
local c = car.PrimaryPart
local hp = c:FindFirstChild("Hardpoint_FL").WorldPosition
local hit = workspace:Raycast(hp, Vector3.new(0, -5, 0), RaycastParams.new())
local compressionM = 0.35 - (hit.Distance * 0.28 - 0.33)
return string.format("anchored=%s velocity=%.3f compressionFL=%.3f m (expect ~0.11)", tostring(c.Anchored), c.AssemblyLinearVelocity.Magnitude, compressionM)
```
Expected: anchored=true after settling, compression about 0.11 m (1600 kg × 9.81 / 4 / 35000). If the car bounces forever, damping is not being applied (check `dx` sign). If it sinks to the bump stop, the gravity correction sign is wrong.

- [ ] **Step 7: Drive it from the MCP (tire and drivetrain test)**

Walk to the car, press E (or `execute_luau` on Server: `workspace.Cars:GetChildren()[1].DriverSeat:Sit(game.Players:GetPlayers()[1].Character.Humanoid)` after unanchoring the chassis). Then in the Client datamodel:
```lua
local p = game.Players.LocalPlayer
p:SetAttribute("InputOverride", true)
p:SetAttribute("OvThrottle", 1)
p:SetAttribute("OvSteer", 0)
task.wait(6)
local c = workspace.Cars:GetChildren()[1].PrimaryPart
return string.format("speed=%.1f km/h", c.AssemblyLinearVelocity.Magnitude * 0.28 * 3.6)
```
Expected: 80 to 120 km/h after 6 s, heading straight down the road (Z decreasing). Then handbrake test:
```lua
local p = game.Players.LocalPlayer
p:SetAttribute("OvSteer", 0.4)
task.wait(0.3)
p:SetAttribute("OvHandbrake", true)
task.wait(0.6)
p:SetAttribute("OvHandbrake", false)
local c = workspace.Cars:GetChildren()[1].PrimaryPart
local v = c.AssemblyLinearVelocity
local fwd = c.CFrame.LookVector
local drift = math.deg(math.atan2(v:Dot(c.CFrame.RightVector), v:Dot(fwd)))
return string.format("drift=%.0f deg speed=%.0f km/h", drift, v.Magnitude * 0.28 * 3.6)
```
Expected: drift angle beyond 20° within the 0.6 s and speed still above 60% of before (handbrake must not stop the car). Set `InputOverride` false afterwards.

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "feat: VehicleSim glue, client controller, input aggregation, server parked-car sim"
```

**What to test in Studio:** Car drops and settles with one or two bounces, no jitter. Enter the car; nothing moves yet without input bindings (Task 11) unless you use the override. Watch the wheels: they should sit on the road, not float or sink.

---

### Task 10: Debug panel

**Files:**
- Create: `src/client/DebugPanel.luau`
- Modify: `src/client/init.client.luau`

**Interfaces:**
- Produces: `DebugPanel.update(state: VehicleState)` (throttles itself to `config.debug.updateHz`), `DebugPanel.hide()`. Also mirrors key numbers to attributes on `Players.LocalPlayer` for the MCP harness: `DbgSpeedKmh`, `DbgGear`, `DbgRpm`, `DbgDriftDeg`, `DbgYawRate`, `DbgRollDeg`, `DbgMode`, `DbgSlipFL/FR/RL/RR`, `DbgSpinRL/RR`.

- [ ] **Step 1: Write `src/client/DebugPanel.luau`**

```lua
--!strict
-- On-screen numbers for tuning. Monospace block, top-left, 10 Hz.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local ConfigLoader = require(Shared.ConfigLoader)

type VehicleState = Types.VehicleState
type WheelState = Types.WheelState

local DebugPanel = {}

local label: TextLabel? = nil
local lastUpdate = 0

local function ensureLabel(): TextLabel
	if label then
		return label
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "HajwalaDebug"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10

	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.BackgroundColor3 = Color3.new(0, 0, 0)
	l.BackgroundTransparency = 0.35
	l.BorderSizePixel = 0
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.Code
	l.TextSize = 14
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Position = UDim2.fromOffset(8, 8)
	l.Size = UDim2.fromOffset(0, 0)
	l.Text = ""
	l.Parent = gui

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = l

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	label = l
	return l
end

local function wheelLine(ws: WheelState): string
	local flag = if ws.saturated then "SPIN" elseif not ws.grounded then "AIR " else "    "
	return string.format("%s slip %+6.1f° load %5.1fkN %s", ws.name, ws.slipAngleDeg, ws.load / 1000, flag)
end

function DebugPanel.update(state: VehicleState)
	local cfg = ConfigLoader.current()
	if not cfg.debug.enabled then
		DebugPanel.hide()
		return
	end
	local now = os.clock()
	if now - lastUpdate < 1 / cfg.debug.updateHz then
		return
	end
	lastUpdate = now

	local l = ensureLabel()
	l.Visible = true
	local w = state.wheels
	local gear = if state.gear == -1 then "R" else tostring(state.gear)
	l.Text = table.concat({
		string.format("SPD %5.1f km/h   GEAR %s   RPM %4.0f", state.speedKmh, gear, state.rpm),
		string.format("THR %.2f  BRK %.2f  STR %+.2f (%+5.1f°)", state.throttle, state.brake, state.steer, state.steerDeg),
		string.format("DRIFT %+6.1f°   YAW %+6.1f°/s", state.driftAngleDeg, state.yawRateDegPerSec),
		string.format("MODE %-8s  ROLL %+5.1f°  margin %5.1f°", state.twoWheelMode, state.rollDeg, state.rollMarginDeg),
		wheelLine(w[1]) .. "   " .. wheelLine(w[2]),
		wheelLine(w[3]) .. "   " .. wheelLine(w[4]),
		string.format("HB %s  KICK %s  ASSIST %.2f", if state.handbrake then "ON " else "off", if state.clutchKick then "ON " else "off", state.driftAssist),
	}, "\n")

	-- Mirror for the MCP harness (client-side attributes, readable in the Client datamodel).
	local p = Players.LocalPlayer
	p:SetAttribute("DbgSpeedKmh", state.speedKmh)
	p:SetAttribute("DbgGear", state.gear)
	p:SetAttribute("DbgRpm", state.rpm)
	p:SetAttribute("DbgDriftDeg", state.driftAngleDeg)
	p:SetAttribute("DbgYawRate", state.yawRateDegPerSec)
	p:SetAttribute("DbgRollDeg", state.rollDeg)
	p:SetAttribute("DbgMode", state.twoWheelMode)
	p:SetAttribute("DbgSlipFL", w[1].slipAngleDeg)
	p:SetAttribute("DbgSlipFR", w[2].slipAngleDeg)
	p:SetAttribute("DbgSlipRL", w[3].slipAngleDeg)
	p:SetAttribute("DbgSlipRR", w[4].slipAngleDeg)
	p:SetAttribute("DbgSpinRL", w[3].saturated)
	p:SetAttribute("DbgSpinRR", w[4].saturated)
end

function DebugPanel.hide()
	if label then
		label.Visible = false
	end
end

return DebugPanel
```

- [ ] **Step 2: Wire it in `src/client/init.client.luau`**

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local driveStart = remotes:WaitForChild("DriveStart") :: RemoteEvent
local driveStop = remotes:WaitForChild("DriveStop") :: RemoteEvent
local VehicleController = require(script.VehicleController)
local DebugPanel = require(script.DebugPanel)

print("[Hajwala] client boot")
VehicleController.onState = function(state)
	DebugPanel.update(state)
end
driveStart.OnClientEvent:Connect(function(car: Model)
	VehicleController.start(car, remotes)
end)
driveStop.OnClientEvent:Connect(function()
	VehicleController.stop()
	DebugPanel.hide()
end)
```

- [ ] **Step 3: Verify**

Play, enter the car, drive with the override from Task 9 Step 7. `screen_capture` shows the panel. `execute_luau` (Client): `local p = game.Players.LocalPlayer return p:GetAttribute("DbgSpeedKmh"), p:GetAttribute("DbgDriftDeg")` returns live numbers.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: debug panel with harness attributes"
```

**What to test in Studio:** Panel appears when seated, disappears when you leave. Numbers move with the car. Slip angles on the rear jump when the handbrake is on.

---

### Task 11: Input sources — keyboard, gamepad, touch

**Files:**
- Create: `src/client/Input/Keyboard.luau`, `src/client/Input/Gamepad.luau`, `src/client/Input/Touch.luau`
- Modify: `src/client/VehicleController.luau` (bind on start, unbind on stop)

**Interfaces:**
- Produces: `Keyboard.bind()/unbind()`, `Gamepad.bind()/unbind()`, `Touch.bind()/unbind()`. All write into `Input.raw` and call `Input.pulse(...)`.
- Bindings (from the spec): W/S throttle-brake, A/D steer, Space handbrake, Shift clutch kick, F two-wheel, E exit, R reset, L reload. Gamepad: RT/LT, left stick X, B handbrake, X clutch kick, Y two-wheel, LB exit, Back reset. Touch: buttons created by ContextActionService and laid out by viewport fraction.

- [ ] **Step 1: Write `src/client/Input/Keyboard.luau`**

```lua
--!strict
local ContextActionService = game:GetService("ContextActionService")
local Input = require(script.Parent)

local Keyboard = {}

local PRIORITY = Enum.ContextActionPriority.High.Value
local ACTIONS = {
	"HJ_KThrottle", "HJ_KBrake", "HJ_KLeft", "HJ_KRight", "HJ_KHandbrake",
	"HJ_KKick", "HJ_KTwoWheel", "HJ_KExit", "HJ_KReset", "HJ_KReload",
}
local left, right = false, false

local function updateSteer()
	Input.raw.steerAnalog = nil
	Input.raw.steerDigital = (if right then 1 else 0) - (if left then 1 else 0)
	Input.raw.source = "keyboard"
end

local function bind(name: string, handler: (boolean) -> (), ...: Enum.KeyCode)
	ContextActionService:BindActionAtPriority(name, function(_, state: Enum.UserInputState)
		handler(state == Enum.UserInputState.Begin)
		-- Sink so Space does not also jump the character out of the seat.
		return Enum.ContextActionResult.Sink
	end, false, PRIORITY, ...)
end

function Keyboard.bind()
	bind("HJ_KThrottle", function(down)
		Input.raw.throttle = if down then 1 else 0
		Input.raw.source = "keyboard"
	end, Enum.KeyCode.W, Enum.KeyCode.Up)
	bind("HJ_KBrake", function(down)
		Input.raw.brake = if down then 1 else 0
		Input.raw.source = "keyboard"
	end, Enum.KeyCode.S, Enum.KeyCode.Down)
	bind("HJ_KLeft", function(down)
		left = down
		updateSteer()
	end, Enum.KeyCode.A, Enum.KeyCode.Left)
	bind("HJ_KRight", function(down)
		right = down
		updateSteer()
	end, Enum.KeyCode.D, Enum.KeyCode.Right)
	bind("HJ_KHandbrake", function(down)
		Input.raw.handbrake = down
	end, Enum.KeyCode.Space)
	bind("HJ_KKick", function(down)
		if down then
			Input.pulse("clutchKick")
		end
	end, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
	bind("HJ_KTwoWheel", function(down)
		Input.raw.twoWheel = down
	end, Enum.KeyCode.F)
	bind("HJ_KExit", function(down)
		if down then
			Input.pulse("exit")
		end
	end, Enum.KeyCode.E)
	bind("HJ_KReset", function(down)
		if down then
			Input.pulse("reset")
		end
	end, Enum.KeyCode.R)
	bind("HJ_KReload", function(down)
		if down then
			Input.pulse("reload")
		end
	end, Enum.KeyCode.L)
end

function Keyboard.unbind()
	for _, name in ACTIONS do
		ContextActionService:UnbindAction(name)
	end
	left, right = false, false
	Input.raw.throttle, Input.raw.brake = 0, 0
	Input.raw.handbrake, Input.raw.twoWheel = false, false
	Input.raw.steerDigital = 0
end

return Keyboard
```

- [ ] **Step 2: Write `src/client/Input/Gamepad.luau`**

```lua
--!strict
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared.ConfigLoader)
local Input = require(script.Parent)

local Gamepad = {}

local PRIORITY = Enum.ContextActionPriority.High.Value
local ACTIONS = {
	"HJ_GThrottle", "HJ_GBrake", "HJ_GSteer", "HJ_GHandbrake", "HJ_GKick",
	"HJ_GTwoWheel", "HJ_GExit", "HJ_GReset",
}

local function applyDeadzone(v: number, dz: number): number
	local a = math.abs(v)
	if a < dz then
		return 0
	end
	return math.sign(v) * (a - dz) / (1 - dz)
end

local function bindAnalog(name: string, handler: (InputObject) -> (), key: Enum.KeyCode)
	ContextActionService:BindActionAtPriority(name, function(_, _state: Enum.UserInputState, obj: InputObject)
		handler(obj)
		return Enum.ContextActionResult.Sink
	end, false, PRIORITY, key)
end

local function bindButton(name: string, handler: (boolean) -> (), key: Enum.KeyCode)
	ContextActionService:BindActionAtPriority(name, function(_, state: Enum.UserInputState)
		handler(state == Enum.UserInputState.Begin)
		return Enum.ContextActionResult.Sink
	end, false, PRIORITY, key)
end

function Gamepad.bind()
	bindAnalog("HJ_GThrottle", function(obj)
		local cfg = ConfigLoader.current().input
		Input.raw.throttle = applyDeadzone(obj.Position.Z, cfg.triggerDeadzone)
		Input.raw.source = "gamepad"
	end, Enum.KeyCode.ButtonR2)
	bindAnalog("HJ_GBrake", function(obj)
		local cfg = ConfigLoader.current().input
		Input.raw.brake = applyDeadzone(obj.Position.Z, cfg.triggerDeadzone)
		Input.raw.source = "gamepad"
	end, Enum.KeyCode.ButtonL2)
	bindAnalog("HJ_GSteer", function(obj)
		local cfg = ConfigLoader.current().input
		local x = applyDeadzone(obj.Position.X, cfg.gamepadDeadzone)
		-- Centred stick hands steering back to digital sources.
		Input.raw.steerAnalog = if x == 0 then nil else x
		Input.raw.source = "gamepad"
	end, Enum.KeyCode.Thumbstick1)
	bindButton("HJ_GHandbrake", function(down)
		Input.raw.handbrake = down
	end, Enum.KeyCode.ButtonB)
	bindButton("HJ_GKick", function(down)
		if down then
			Input.pulse("clutchKick")
		end
	end, Enum.KeyCode.ButtonX)
	bindButton("HJ_GTwoWheel", function(down)
		Input.raw.twoWheel = down
	end, Enum.KeyCode.ButtonY)
	bindButton("HJ_GExit", function(down)
		if down then
			Input.pulse("exit")
		end
	end, Enum.KeyCode.ButtonL1)
	bindButton("HJ_GReset", function(down)
		if down then
			Input.pulse("reset")
		end
	end, Enum.KeyCode.ButtonSelect)
end

function Gamepad.unbind()
	for _, name in ACTIONS do
		ContextActionService:UnbindAction(name)
	end
	Input.raw.steerAnalog = nil
end

return Gamepad
```

- [ ] **Step 3: Write `src/client/Input/Touch.luau`**

```lua
--!strict
-- On-screen buttons for phones, created through ContextActionService
-- (createTouchButton = true) and laid out by viewport fraction so both
-- thumbs have a cluster: steer + two-wheel on the left, throttle/brake/
-- handbrake/kick on the right, small utility buttons along the top.
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Input = require(script.Parent)

local Touch = {}

local PRIORITY = Enum.ContextActionPriority.High.Value
local connections: { RBXScriptConnection } = {}
local bound: { string } = {}
local left, right = false, false

local function updateSteer()
	Input.raw.steerAnalog = nil
	Input.raw.steerDigital = (if right then 1 else 0) - (if left then 1 else 0)
	Input.raw.source = "touch"
end

-- xFrac/yFrac: centre of the button as a fraction of the viewport.
local function place(name: string, title: string, xFrac: number, yFrac: number, sizePx: number)
	local btn = ContextActionService:GetButton(name)
	if not btn then
		return
	end
	ContextActionService:SetTitle(name, title)
	btn.Size = UDim2.fromOffset(sizePx, sizePx)
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	local function layout()
		local parent = btn.Parent
		local cam = workspace.CurrentCamera
		if not parent or not parent:IsA("GuiObject") or not cam then
			return
		end
		local vp = cam.ViewportSize
		local target = Vector2.new(vp.X * xFrac, vp.Y * yFrac)
		local localPos = target - parent.AbsolutePosition
		btn.Position = UDim2.fromOffset(localPos.X, localPos.Y)
	end
	layout()
	local parent = btn.Parent
	if parent and parent:IsA("GuiObject") then
		table.insert(connections, parent:GetPropertyChangedSignal("AbsolutePosition"):Connect(layout))
		table.insert(connections, parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout))
	end
	local cam = workspace.CurrentCamera
	if cam then
		table.insert(connections, cam:GetPropertyChangedSignal("ViewportSize"):Connect(layout))
	end
end

local function bind(name: string, handler: (boolean) -> ())
	ContextActionService:BindActionAtPriority(name, function(_, state: Enum.UserInputState)
		handler(state == Enum.UserInputState.Begin)
		return Enum.ContextActionResult.Sink
	end, true, PRIORITY)
	table.insert(bound, name)
end

function Touch.bind()
	if not UserInputService.TouchEnabled then
		return
	end
	bind("HJ_TThrottle", function(down)
		Input.raw.throttle = if down then 1 else 0
		Input.raw.source = "touch"
	end)
	bind("HJ_TBrake", function(down)
		Input.raw.brake = if down then 1 else 0
		Input.raw.source = "touch"
	end)
	bind("HJ_TLeft", function(down)
		left = down
		updateSteer()
	end)
	bind("HJ_TRight", function(down)
		right = down
		updateSteer()
	end)
	bind("HJ_THandbrake", function(down)
		Input.raw.handbrake = down
	end)
	bind("HJ_TKick", function(down)
		if down then
			Input.pulse("clutchKick")
		end
	end)
	bind("HJ_TTwoWheel", function(down)
		Input.raw.twoWheel = down
	end)
	bind("HJ_TExit", function(down)
		if down then
			Input.pulse("exit")
		end
	end)
	bind("HJ_TReset", function(down)
		if down then
			Input.pulse("reset")
		end
	end)
	bind("HJ_TReload", function(down)
		if down then
			Input.pulse("reload")
		end
	end)

	-- Right thumb
	place("HJ_TThrottle", "GAS", 0.92, 0.80, 96)
	place("HJ_TBrake", "BRAKE", 0.80, 0.88, 72)
	place("HJ_THandbrake", "HAND", 0.92, 0.58, 72)
	place("HJ_TKick", "KICK", 0.80, 0.66, 60)
	-- Left thumb
	place("HJ_TLeft", "<", 0.08, 0.84, 96)
	place("HJ_TRight", ">", 0.22, 0.84, 96)
	place("HJ_TTwoWheel", "NATL", 0.15, 0.62, 72)
	-- Utility
	place("HJ_TExit", "EXIT", 0.56, 0.08, 44)
	place("HJ_TReset", "RESET", 0.64, 0.08, 44)
	place("HJ_TReload", "RELOAD", 0.72, 0.08, 44)
end

function Touch.unbind()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for _, name in bound do
		ContextActionService:UnbindAction(name)
	end
	table.clear(bound)
	left, right = false, false
end

return Touch
```

- [ ] **Step 4: Bind and unbind in `src/client/VehicleController.luau`**

Add requires after `local Input = require(script.Parent.Input)`:
```lua
local Keyboard = require(script.Parent.Input.Keyboard)
local Gamepad = require(script.Parent.Input.Gamepad)
local Touch = require(script.Parent.Input.Touch)
```
In `VehicleController.start`, after `setJumpEnabled(false)`:
```lua
	Keyboard.bind()
	Gamepad.bind()
	Touch.bind()
```
In `VehicleController.stop`, before `setJumpEnabled(true)`:
```lua
	Keyboard.unbind()
	Gamepad.unbind()
	Touch.unbind()
```

- [ ] **Step 5: Verify keyboard and touch**

Play with keyboard: W drives, A/D steer, Space slides without stopping the car, Shift kicks, E exits (character appears beside the car), R resets. Space must NOT eject you from the seat.
Phone: Test → Device → iPhone-class preset → Play. Buttons appear in the two clusters; drive with the mouse as a finger. `screen_capture` the layout.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: keyboard, gamepad and touch input bindings"
```

**What to test in Studio:** Keyboard drive down the road, handbrake initiation at 80 km/h. Then the phone preset: same thing with the mouse on the buttons. Steer on touch should feel slower to reach full lock than keyboard.

---

### Task 12: Chase camera

**Files:**
- Create: `src/client/CameraRig.luau`
- Modify: `src/client/VehicleController.luau`

**Interfaces:**
- Produces: `CameraRig.start(model: Model)`, `CameraRig.stop()`. Reads `CarConfig.camera` each frame via `ConfigLoader.current()`.

- [ ] **Step 1: Write `src/client/CameraRig.luau`**

```lua
--!strict
-- Chase camera: sits behind the car, lags, and swings toward the velocity
-- direction in a slide so the drift angle is visible from behind.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared.ConfigLoader)

local CameraRig = {}

local conn: RBXScriptConnection? = nil
local smoothedDir = Vector3.new(0, 0, -1)
local smoothedPos = Vector3.zero

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-4 then f.Unit else Vector3.new(0, 0, -1)
end

function CameraRig.start(model: Model)
	CameraRig.stop()
	local chassis = model.PrimaryPart :: BasePart
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	local cfg = ConfigLoader.current()
	local mps = cfg.units.metersPerStud
	smoothedDir = flat(chassis.CFrame.LookVector)
	smoothedPos = chassis.Position - smoothedDir * (cfg.camera.distance / mps) + Vector3.yAxis * (cfg.camera.height / mps)

	conn = RunService.RenderStepped:Connect(function(dt: number)
		local c = ConfigLoader.current()
		local camCfg = c.camera
		local metersPerStud = c.units.metersPerStud
		local pos = chassis.Position
		local heading = flat(chassis.CFrame.LookVector)
		local vel = chassis.AssemblyLinearVelocity * metersPerStud
		local speedMps = vel.Magnitude

		-- Blend heading toward the direction of travel while sliding forward.
		local desired = heading
		if speedMps > camCfg.minSpeedForSwingMps and vel:Dot(chassis.CFrame.LookVector) > 0 then
			local blended = heading:Lerp(flat(vel), camCfg.driftSwing)
			if blended.Magnitude > 0.1 then
				desired = blended.Unit
			end
		end
		local dirAlpha = 1 - math.exp(-camCfg.directionLag * dt)
		local nextDir = smoothedDir:Lerp(desired, dirAlpha)
		if nextDir.Magnitude > 0.1 then
			smoothedDir = nextDir.Unit
		end

		local target = pos - smoothedDir * (camCfg.distance / metersPerStud) + Vector3.yAxis * (camCfg.height / metersPerStud)
		local posAlpha = 1 - math.exp(-camCfg.positionLag * dt)
		smoothedPos = smoothedPos:Lerp(target, posAlpha)

		local look = pos + Vector3.yAxis * (camCfg.lookHeight / metersPerStud)
		cam.CFrame = CFrame.lookAt(smoothedPos, look)
		cam.FieldOfView = math.min(camCfg.baseFov + camCfg.fovPerKmh * speedMps * 3.6, camCfg.maxFov)
	end)
end

function CameraRig.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
	end
end

return CameraRig
```

- [ ] **Step 2: Wire into `src/client/VehicleController.luau`**

Add `local CameraRig = require(script.Parent.CameraRig)`. In `start`, after the input binds: `CameraRig.start(model)`. In `stop`, before `setJumpEnabled(true)`: `CameraRig.stop()`.

- [ ] **Step 3: Verify**

Drive, handbrake into a slide: camera swings so the car is seen at an angle, then eases back when straight. Exit: camera returns to normal character camera.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: chase camera with drift swing"
```

**What to test in Studio:** At 100 km/h the view widens slightly. In a 60° slide the car body sits diagonally in frame, not straight-on. No snapping when the slide ends.

---

### Task 13: Two-wheel integration test and first tune

**Files:**
- Modify: `src/shared/CarConfig.luau` (twoWheel values only)

**Interfaces:**
- Consumes: Task 8 module already integrated in Task 9; F / Y / NATL button from Task 11.

- [ ] **Step 1: Harness run**

Play, enter the car. In the Client datamodel:
```lua
local p = game.Players.LocalPlayer
p:SetAttribute("InputOverride", true)
p:SetAttribute("OvThrottle", 1)
task.wait(4) -- ~60 km/h
p:SetAttribute("OvThrottle", 0.4)
p:SetAttribute("OvTwoWheel", true)
local samples = {}
for i = 1, 30 do
	task.wait(0.1)
	table.insert(samples, string.format("%.1f:%s", p:GetAttribute("DbgRollDeg"), p:GetAttribute("DbgMode")))
end
p:SetAttribute("OvTwoWheel", false)
p:SetAttribute("OvThrottle", 0)
return table.concat(samples, " ")
```
Look for: roll rising to about 37° within 1 s (mode → balanced), then slowly increasing past 42° over the next 2 to 3 s with no steer, then reaching tipRollDeg and mode → tipped. Then repeat with `OvSteer` set to the grounded side (`-1` for the default left roll... note: default side is −1 = roll left, left wheels down, so steer −1 = toward grounded side brings it down) after it reaches balanced: roll should fall back.

- [ ] **Step 2: Tune**

- Lift too slow (over 1.5 s): raise `twoWheel.liftTorque`.
- Launches past target and tips immediately: raise `rollDamping`, lower `liftTorque`.
- Sits at target forever with no input: raise `instability` (it should drift 15° in about 2 s).
- Full steer cannot save it: raise `balanceTorque`.
- Bottoms out on the loaded side (loads above 10 kN on the panel): raise `suspensionBias`.
- Lands with a launch: raise `landingDamping`.
Edit CarConfig, press L (Task 14) or restart play, repeat Step 1. Record final values in TUNING.md (Task 14).

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: two-wheel tuning pass"
```

**What to test in Studio:** Hold F at 60 km/h: the car lifts onto two wheels in about a second and hangs there. Do nothing: it leans further and falls over after a few seconds. Tap steer toward the low side: it comes back. Release F: it drops onto four wheels with a suspension bounce, no launch. R to reset if it falls over.

---

### Task 14: Config reload path, DESIGN.md, TUNING.md, README notes

**Files:**
- Modify: `src/client/init.client.luau`
- Create: `DESIGN.md`, `TUNING.md`
- Modify: `README.md`

- [ ] **Step 1: Wire reload in `src/client/init.client.luau`**

Add after the `DebugPanel` require:
```lua
local ConfigLoader = require(ReplicatedStorage.Shared.ConfigLoader)
local reloadRemote = remotes:WaitForChild("ReloadConfig") :: RemoteEvent
VehicleController.onReload = function()
	local cfg, err = ConfigLoader.reload()
	if err then
		warn("[Hajwala] config reload failed:", err)
	else
		print("[Hajwala] config reloaded")
	end
	VehicleController.setConfig(cfg)
	reloadRemote:FireServer()
end
```

- [ ] **Step 2: Verify reload**

Play, enter the car. Change `steering.maxSteerDeg` to 10 in the ModuleScript (in Studio's script editor if Rojo does not sync during play, per Task 1 Step 8), press L. Output prints "config reloaded" on client and the steer angle on the panel now caps at ±10°. Restore the value.

- [ ] **Step 3: Write `DESIGN.md`**

```markdown
# DESIGN — why the car is built this way

## One rigid body, raycast suspension
The car is a single physics assembly: a box, a hidden ballast, four visual
wheels and a seat. Each corner fires a ray straight down from a hardpoint.
The distance to the ground gives that corner's spring compression, and the
spring plus damper force is applied at the hardpoint. Weight transfer is
not scripted: when the car pitches sideways the outside rays shorten, those
springs load up, the inside springs unload, and the tire model sees those
loads. That is the "heavy sedan leaning into a slide" look.

We chose raycasts over SpringConstraint + CylindricalConstraint wheels
because Roblox's built-in tire friction is close to on/off and cannot give a
grip curve that peaks and then fades. With visual-only wheels every newton
of tire force comes from our own model. It is also one body instead of five
per car, which matters on phones, and one body means network ownership is
a single handoff.

The cost: wheels do not physically touch curbs or bumps. Phase 0 is a flat
road, so nothing is lost yet. Bump stops on the springs keep the body from
sinking through the wheels under hard loads.

## Gravity
Roblox gravity is 196.2 studs/s². At our scale (0.28 m per stud) that is
5.6 times real gravity. If the tire model used real spring loads under that
gravity the car would corner 5.6 times too hard and never slide, and body
roll and two-wheel balance would be wrong. Changing workspace gravity would
break characters and everything on foot in later phases, so the sim applies
an upward counter-force of mass × (196.2 − g/0.28) on the chassis only.
`CarConfig.units.gravity` sets g; 9.81 is honest, 54.9 turns the correction
off for A/B comparison.

## Units
Config is in kilograms, metres, newtons, seconds. One Roblox mass unit is
treated as one kilogram (densities are set so the assembly mass equals the
config mass). Forces are divided by 0.28 on the way out, torques by 0.28².

## Tire model
For each grounded wheel we take the contact patch velocity, split it into
along-the-wheel and across-the-wheel, and compute the slip angle. Lateral
grip rises linearly to a peak slip angle, then decays to a sliding floor.
That fade is the whole point: past the peak the rear gives up some grip but
not all, so a slide is a balance you can hold rather than a switch that
flips. Front and rear have separate grip, peak, fade and floor numbers.

Longitudinal and lateral share a friction circle. Drive and brake demand is
taken first because the driver commands it; whatever is left of the circle
goes to lateral. So throttle in a slide eats rear lateral grip (more angle,
eventually a spin) and lifting gives it back (the car straightens). If
longitudinal demand exceeds the circle the wheel is spinning or locked and
both components drop to the sliding level.

## Drivetrain
Torque curve by rpm, automatic gearbox, welded-diff behaviour (equal drive
to both rear wheels). Wheel spin is not integrated; the tire reports when
demand exceeded grip and the engine rpm floats up while it does. Clutch kick
is a short torque multiplier. Engine braking on lift shifts weight forward,
which is what makes a lift-and-flick transition swing the rear across.

## Handbrake
Multiplies rear grip by a fraction and drags the rear wheels with a capped
force. The circle shrinks, the rear lets go, the car keeps most of its
speed. It cannot stop the car because the front is untouched.

## Steering and drift assist
Steer angle chases the input at a rate, faster on return. Drift assist adds
a fraction of the car's slip angle as automatic counter-steer. Default is
low; the physics already makes counter-steer effective because the front
tires are on the rising side of their curve while the rear is on the floor.

## Two-wheel ("natl")
On two wheels the car is an inverted pendulum pivoting on the grounded
contact patches. Gravity restores it below the static tip angle
atan(halfTrack / comHeight) and pushes it over above. While balanced the
controller cancels gravity's restoring torque and adds a small divergence,
so the car slowly leans further if ignored and comes back when the player
steers toward the low side. Nothing pulls it toward the target angle on its
own, so it never feels magnetized, and past the tip angle the controller
lets go so it falls honestly. The loaded side's springs are stiffened while
lifted because two springs now carry the whole car.

## Network
Server builds and parks cars and runs the sim with zero input for parked
ones. Sitting hands network ownership to the driver; their client runs the
sim on its own car. Leaving returns ownership to the server.
```

- [ ] **Step 4: Write `TUNING.md`**

For every CarConfig field: what it does, and which way to move it for the
three goals. Write it as a table per section. Content:

```markdown
# TUNING — every CarConfig field

Legend for the goal columns: ↑ raise the value, ↓ lower it, — no direct effect.
Goals: OS = more oversteer (rear steps out easier, holds bigger angle);
INIT = easier drift initiation; 2W = more two-wheel stability.
For the opposite effect move the other way.

## units
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| metersPerStud | World scale. Leave at 0.28. | — | — | — |
| gravity | Effective gravity on the car. Lower = lighter car, less load, less grip everywhere, slower weight transfer. 54.9 disables the correction. | — | — | ↑ (heavier restoring) |

## body
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| massKg | Total mass. More mass = more momentum in a slide, slower transitions. | — | ↓ | — |
| bodySize | Box dimensions. Height changes roll inertia. | — | — | — |
| centerOfMassOffset | Lower CoM = less roll, higher tip angle. Forward CoM = more front load = more rear slide. | forward ↑ | forward ↑ | lower (more negative Y) ↑ |
| wheelbase | Longer = more stable, slower rotation. | ↓ | ↓ | — |
| trackWidth | Wider = higher two-wheel tip angle, less roll. | — | — | ↑ |
| wheelRadius | Bigger = taller gearing, less drive force. | — | ↓ | — |
| shellMassFraction | Share of mass in the shell vs ballast. Only affects where the ballast sits. | — | — | — |
| dragCoefficient / frontalArea / airDensity | Top speed and how fast a slide bleeds speed. | — | — | — |
| rollingResistance | Coast-down drag. | — | — | — |

## suspension
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| restLength | Ride height at full droop. | — | — | — |
| travel | Usable compression before the bump stop. | — | — | ↑ |
| stiffness | Softer = more visible weight transfer, slower response. | — | — | ↑ |
| damping | Low = bouncy, high = dead. Aim for a bounce and a half. | — | — | ↑ |
| bumpStopStiffness | Keeps the body off the wheels when bottomed. | — | — | ↑ |
| antiRollFront | Stiffer front bar = front loses grip first = understeer. | ↓ | ↓ | — |
| antiRollRear | Stiffer rear bar = rear loses grip first = oversteer. | ↑ | ↑ | — |

## tires.front / tires.rear
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| grip | Peak friction. Rear lower than front = oversteer. | rear ↓ / front ↑ | rear ↓ | — |
| peakSlipDeg | Slip angle at peak. Lower rear = rear breaks away sooner. | rear ↓ | rear ↓ | — |
| slideSlipDeg | Where the fade ends. Wider gap to peak = gentler fade = more progressive slide. | — | — | — |
| slideGripRatio | Grip floor while sliding. Lower rear = bigger angles, harder to catch; higher = holds and recovers easier. | rear ↓ | rear ↓ | — |
| speedFadeMps | Speed below which lateral force fades. Only for parking jitter. | — | — | — |

## drivetrain
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| torqueCurve | Engine torque by rpm. More torque = more power-over. | ↑ | ↑ | — |
| gearRatios / finalDrive | Shorter (bigger numbers) = more drive force at speed = easier to break traction with throttle. | ↑ | ↑ | — |
| reverseRatio | Reverse gearing. | — | — | — |
| drivelineEfficiency | Scales all drive force. | ↑ | ↑ | — |
| idleRpm / redlineRpm | Rev range. | — | — | — |
| upshiftRpm / downshiftRpm | Shift points. Later upshift keeps the engine in the fat part of the curve for kicks. | — | ↑ upshift | — |
| shiftTime | Torque cut per shift. | — | — | — |
| spinRpmRate | How fast rpm climbs while spinning. Cosmetic. | — | — | — |
| engineBrakeTorque | Weight shift forward on lift. More = sharper lift-off rotation and easier transitions. | ↑ | ↑ | — |
| brakeForce / brakeBias | Pedal strength and split. More rear bias = brake-induced rotation. | bias ↓ | bias ↓ | — |
| brakeFadeMps | Anti-jitter at rest. | — | — | — |

## steering
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| maxSteerDeg | Lock. Must exceed the drift angles you want to hold minus assist. | ↑ | ↑ | — |
| steerSpeedDegPerSec | How fast the wheels turn in. Higher = snappier initiation, twitchier hold. | — | ↑ | — |
| steerReturnDegPerSec | How fast they return. | — | — | — |
| driftAssist | Automatic counter-steer fraction. Higher = easier hold, less skill. Keep low. | ↓ | — | — |

## handbrake
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| rearGripMultiplier | Rear grip while pulled. Lower = snaps out faster. | ↓ | ↓ | — |
| brakeForce | Rear drag while pulled. Too high scrubs speed. | — | ↑ | — |

## clutchKick
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| multiplier | Torque spike. Must push rear demand past the friction circle at your entry speed. | ↑ | ↑ | — |
| duration | Spike length. | — | ↑ | — |

## twoWheel
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| liftTorque | Extra roll torque while lifting. | — | — | ↓ (gentler arrival) |
| gravityCancel | Fraction of gravity's restoring torque cancelled while balanced. 1 = neutral, lower = it wants to come down. | — | — | ↓ |
| targetRollDeg | Angle where lifting hands over to balancing. | — | — | ↓ (further from tip) |
| instability | Net divergence from target, Nm/deg. 0 = sits there (magnetized). Higher = falls faster if ignored. | — | — | ↓ |
| rollDamping | Resists roll rate while balanced. | — | — | ↑ |
| balanceTorque | Steer authority while lifted. | — | — | ↑ |
| tipRollDeg | Where the controller lets go. Keep near atan(halfTrack/comHeight). | — | — | ↑ (but dishonest past the static tip) |
| landingDamping | Softens the drop back to four wheels. | — | — | ↑ |
| suspensionBias | Loaded-side spring multiplier while lifted. | — | — | ↑ |

## input
| Field | What it does |
|---|---|
| keyboardSteerRampPerSec / keyboardSteerReturnPerSec | Digital steer ramp. 4 = full lock in 0.25 s. |
| touchSteerRampPerSec / touchSteerReturnPerSec | Same for touch buttons, slower. |
| touchSteerCurve | Exponent on the ramped touch steer. Above 1 = finer control near centre. |
| gamepadDeadzone / triggerDeadzone | Stick and trigger deadzones. |

## camera
| Field | What it does |
|---|---|
| distance / height / lookHeight | Where the camera sits and aims. |
| positionLag / directionLag | Smoothing rates (1/s). Lower = lazier camera. |
| driftSwing | 0 looks along the heading, 1 along the velocity. |
| baseFov / fovPerKmh / maxFov | Speed-widened field of view. |
| minSpeedForSwingMps | Below this the camera ignores velocity direction. |

## debug
| Field | What it does |
|---|---|
| enabled | Show the panel. |
| updateHz | Panel refresh rate. |
```

- [ ] **Step 5: Update README reload note with the Task 1 Step 8 result. Commit**

```bash
git add -A && git commit -m "docs: DESIGN.md, TUNING.md, config reload wiring"
```

---

### Task 15: Tuning pass against the seven criteria

**Files:**
- Modify: `src/shared/CarConfig.luau`, `TUNING.md` (final values)

Run each harness in the Client datamodel with `InputOverride` on, read the `Dbg*` attributes, adjust, repeat. Then hand over for the keyboard and phone tests.

- [ ] **Step 1: Initiate on demand (criterion 1)**

At 100 km/h, steer 0.3 then handbrake for 0.5 s: `DbgDriftDeg` must pass 20° within 0.3 s of the pull. Same with a clutch kick at 0.3 steer in gear 2 or 3. Then full throttle at 0.1 steer in gear 3 for 3 s: drift angle must stay under 10° (no random spin-out).

- [ ] **Step 2: Hold a slide (criterion 2)**

Initiate at 100 km/h, then set `OvSteer` to counter-steer and `OvThrottle` 0.6. Sample `DbgDriftDeg` for 10 s. Goal: a steer value exists that holds 50 to 80° for 10 s on the straight without the angle walking off. If every steer value either straightens or spins, lower `tires.rear.slideGripRatio` a little (more holdable angle) or raise it (easier catch), and check `driftAssist`.

- [ ] **Step 3: Transition (criterion 3)**

From a held left slide, set throttle 0 and steer to the other side for 0.4 s, then back to counter-steer and throttle 0.6. `DbgDriftDeg` should cross zero and settle on the opposite sign within 1.5 s without exceeding 120° (spin) or staying under 15° (snapped straight). Tune `engineBrakeTorque` and `antiRollRear`.

- [ ] **Step 4: Recover honestly (criterion 4)**

In a held slide set throttle 1: angle grows past 90° and the car spins. Set throttle 0.2: angle decays and the car straightens. Both should take 1 to 2 s, not instant.

- [ ] **Step 5: Two-wheel (criterion 5)** — Task 13 procedure at 40 and 100 km/h.

- [ ] **Step 6: Mobile parity (criterion 6)**

Phone preset in Studio: repeat 1 to 3 with the mouse on the touch buttons. If initiation needs finer steer than the buttons give, lower `touchSteerRampPerSec` or raise `touchSteerCurve`.

- [ ] **Step 7: Readable (criterion 7)** — panel shows all numbers during the above.

- [ ] **Step 8: Record final values in TUNING.md under a "Phase 0 baseline" heading. Commit**

```bash
git add -A && git commit -m "feat: Phase 0 tuning baseline"
```

**What to test in Studio (owner, 20 minutes on a phone):** initiate with HAND or KICK at highway speed, hold with small < > taps and GAS feathering, transition with a GAS release and a < > flick, NATL at 60 km/h. If any of these needs the keyboard to work, the phase is not done.
