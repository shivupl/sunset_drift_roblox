# HUD art

Image art for the HUD variants (`src/client/HudLab`), drawn as SVG so it can
be changed and re-rendered:

- `pro/` (after CarX Drift Racing 2): brushed pedals, a leather wheel, the
  tacho face and needle (`make_tacho.py` writes those two from the dial's
  angles), the handbrake, the NATL button, the button pill.
- `midnight/` (after Midnight Racing: Tokyo) and `arcade/` (after Driving
  Empire): each written by its `make.py` (smoked glass with lit edges; glossy
  toy shapes with thick outlines). Run it in its folder, then render.
- `render.py` renders every `<variant>/*.svg` to `out/<variant>_<name>.png`
  with resvg (`python3 -m pip install --target <dir> --only-binary=:all:
  resvg-py`, then run with `PYTHONPATH=<dir>`). Headless Chrome hung on this
  Mac, so it is not used.
- `fonts/ttf/`: the static TTFs the art uses (Google Fonts, OFL): Oswald Bold
  and SemiBold, Reem Kufi Bold, Orbitron Bold and Fredoka Bold, cut from the variable fonts with fontTools'
  instancer and renamed so an SVG asks for each by family name.

To change a piece: edit the SVG, render, serve `out/` over a local http
server, upload the PNG from Studio (the MCP upload tool), and put the new id
in `src/client/HudLab/Art.luau`. Roblox caps an image at 1024 px a side.
