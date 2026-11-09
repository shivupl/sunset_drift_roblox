# Car picker art

Images for the CARS menu's car list (`src/client/CarPicker`). Upload ids are
in `src/client/CarPicker/Art.luau`.

- `make.py`: the UI pieces, white for the game to tint (`python3 make.py`):
  the slanted tab and SPAWN button (9-slice, the slant in the end caps), a
  car's box with its bottom-right corner cut and its thin and thick
  outlines, a soft round light, a thick ring, the panel's dot, the
  favourite stars, the stat bars' stripes, and the header icons (layout,
  plates, settings).
- `out/car_<id>.png`: each car on the same three-quarter front angle in
  daylight, cut out (720x400), keyed by `key.py`.

## A new car's photo

1. In Play, build a green booth only your client sees: anchored
   SmoothPlastic parts coloured (0, 255, 0), a floor and four walls,
   somewhere high (y 900).
2. Spawn the car, pivot it into the booth, let it settle, anchor its parts
   on the client, and hide your character (`LocalTransparencyModifier`).
3. Hold the camera at FOV 30 on the car's bounding box centre from the
   car's front left, `(-0.66, 0.26, -0.70)` in the car's space, at
   `(box length / 2) / tan(15 deg) * 1.05` (hook the camera's CFrame so the
   car camera does not move it), and `screen_capture`.
4. Studio saves the capture as `~/Library/Roblox/tmp-capture-storage/wob-<n>`
   (the newest). List `<car id> <file>` lines in a text file and run
   `python3 key.py out <that file>`: it keys out the green (alpha from how
   much greener than red or blue a pixel is), fills the glass and wheel holes
   with dark tint, takes the green off the edges, adds a soft shadow and
   puts every car on the same 720x400 canvas.
5. Upload `out/car_<id>.png` (serve `out/` over http and use the Studio MCP
   `upload_image`) and add the id to `Art.cars`.
   `upload_image` reads `http://localhost:<port>/...`; the same files at
   `127.0.0.1` failed to read (2026-11-08).

**Without spawning** (2026-11-08, the owner was sitting in a car in Play):
build the car on the client instead, the garage preview's way (the static
rig `GarageView.staticCar` makes, `BodyBuilder.mount`, `CarLamps` with the
headlamps on, `CarPlates`), so nobody's car is replaced. A camera hook
from `execute_luau` dies when the script returns, so use a separate
Scriptable camera as `workspace.CurrentCamera` instead. Afterwards the car
camera still holds the old camera object, which is gone: fire
`Remotes.DriveStart` to the driver for the car they are in (from the
Server datamodel) and the client restarts its camera without unseating
them. Put back only the HUD ScreenGuis you turned off (not the menu's).
