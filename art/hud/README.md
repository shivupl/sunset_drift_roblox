# HUD art

Image art for the driving HUD and phone controls (`src/client/HudLab`, STREET
D on layout D). Each `make.py` draws its parts with `kit.py` and `parts.py`
and writes the PNGs itself:

- `streetd/`: layout D in its finishes (STREET D, SODIUM, CARBON; `python3
  make.py [finish ...]`): per finish a round button base, the smoked tacho,
  the cash pill and drift board, the pedals; shared, the icons (white, the
  HUD tints them), the lit halo and the readouts' italic digits (`num`).
- `street/`: the STREET cluster from the HUD trial (after Initial D Arcade
  Stage and CarX Street). The HUD uses its gear digits; the rest of its
  parts were for the cluster.

The other trial styles (PRO, MIDNIGHT, ARCADE, KRUZER, KABRIS, GHOST) and
their art were removed on 2026-10-10, when the owner kept STREET D (then
asked for finishes of it).

- `kit.py`: the render kit for parts that should look made, not drawn: an
  object is a height map with per-pixel albedo, metalness, roughness and
  emission, lit like a product shot (a soft box overhead, a strip light at
  the left, a rim at the right, a dark studio), with ambient occlusion and a
  drop shadow, in linear light. Shapes are signed distance fields; text and
  vectors come in through resvg. numpy, Pillow and scipy (Anaconda's python3
  has them).
- `parts.py`: the shared parts: dial bezels and faces, tick
  and numeral scales, needles, caps, cover glass, seven-segment (DSEG7) and
  dot-matrix character atlases, odometer drum strips, rubber pedals,
  dashboard switches.
- resvg draws the text and vectors (`python3 -m pip install --target <dir>
  --only-binary=:all: resvg-py`, then run make.py with `PYTHONPATH=<dir>`).
  Headless Chrome hung on this Mac, so it is not used.
- `fonts/ttf/`: the static TTFs the art uses: Barlow Condensed Bold and Bold
  Italic (Google Fonts, OFL); DSEG7 and DSEG14 Classic Bold (keshikan/DSEG,
  OFL, `fonts/DSEG-LICENSE.txt`) for `parts.py`'s seven- and
  fourteen-segment atlases.

An atlas (`num`, `street_gear`, `hud_icons`) is a grid of character cells the HUD cuts
with ImageRectOffset; its cell size and order are in `StreetHud.luau` and
`LayoutD.luau`.

To change a piece: edit make.py, run it, serve `out/` over a local http
server, upload the PNG from Studio (the MCP upload tool), and put the new id
in `src/client/HudLab/Art.luau`. Roblox caps an image at 1024 px a side.
