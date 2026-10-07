# HUD art

Image art for the HUD variants (`src/client/HudLab`), drawn as SVG so it can
be changed and re-rendered:

- `pro/` (after CarX Drift Racing 2): brushed pedals, a leather wheel, the
  tacho face and needle (`make_tacho.py` writes those two from the dial's
  angles), the handbrake, the NATL button, the button pill.
- `midnight/` (after Midnight Racing: Tokyo) and `arcade/` (after Driving
  Empire): each written by its `make.py` (smoked glass with lit edges; glossy
  toy shapes with thick outlines). Run it in its folder, then render.
- `kruzer/` (round two, after Tokyo Xtreme Racer 2025 and the 100-series
  Land Cruiser's amber cluster): `make.py` draws a whole instrument cluster
  and OEM controls with `kit.py` and `parts.py` and writes the PNGs itself.
- `kit.py`: the render kit for parts that should look made, not drawn: an
  object is a height map with per-pixel albedo, metalness, roughness and
  emission, lit like a product shot (a soft box overhead, a strip light at
  the left, a rim at the right, a dark studio), with ambient occlusion and a
  drop shadow, in linear light. Shapes are signed distance fields; text and
  vectors come in through resvg. numpy, Pillow and scipy (Anaconda's python3
  has them).
- `parts.py`: what the cluster variants share: dial bezels and faces, tick
  and numeral scales, needles, caps, cover glass, seven-segment (DSEG7) and
  dot-matrix character atlases, odometer drum strips, rubber pedals,
  dashboard switches.
- `render.py` renders every `<variant>/*.svg` to `out/<variant>_<name>.png`
  with resvg (`python3 -m pip install --target <dir> --only-binary=:all:
  resvg-py`, then run with `PYTHONPATH=<dir>`). Headless Chrome hung on this
  Mac, so it is not used.
- `fonts/ttf/`: the static TTFs the art uses (Google Fonts, OFL): Oswald Bold
  and SemiBold, Reem Kufi Bold, Orbitron Bold and Fredoka Bold, cut from the variable fonts with fontTools'
  instancer and renamed so an SVG asks for each by family name; Barlow and
  Barlow Condensed (static), Michroma; DSEG7 Classic (keshikan/DSEG, OFL,
  `fonts/DSEG-LICENSE.txt`) for seven-segment digits.

An atlas (`kruzer_lcd`, `kruzer_dots`) is a row of character cells the HUD
cuts with ImageRectOffset (`Instruments.chars`); its cell size and order are
in the variant's Luau. Dial layouts (where the LCD, gear window and lamps
sit, in the face's pixels) are printed by `make.py` and mirrored in the
variant's Luau.

To change a piece: edit the SVG (or make.py), render, serve `out/` over a local http
server, upload the PNG from Studio (the MCP upload tool), and put the new id
in `src/client/HudLab/Art.luau`. Roblox caps an image at 1024 px a side.
