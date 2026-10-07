#!/usr/bin/env python3
"""Writes ARCADE's art (after Driving Empire): chunky glossy shapes with a
thick dark outline, a lip under each for depth, a gloss highlight on top, and
bubbly outlined lettering.

Run from this folder; then art/hud/render.py renders the SVGs.
"""
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
OUT = "#0f1418"
WHITE = "#fbfbf7"

DEFS = """
    <filter id="shadow" x="-30%" y="-20%" width="160%" height="150%"><feDropShadow dx="0" dy="8" stdDeviation="8" flood-color="#000" flood-opacity="0.45"/></filter>
    <filter id="glow" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="12"/></filter>
    <linearGradient id="gloss" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#fff" stop-opacity="0.65"/>
      <stop offset="1" stop-color="#fff" stop-opacity="0.05"/>
    </linearGradient>
"""


def svg(w, h, body, defs=""):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
        f"<defs>{DEFS}{defs}</defs>{body}</svg>\n"
    )


def grad(gid, top, mid, bottom):
    return (
        f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{top}"/><stop offset="0.55" stop-color="{mid}"/>'
        f'<stop offset="1" stop-color="{bottom}"/></linearGradient>'
    )


def chunky_rect(x, y, w, h, r, fill, lip):
    """The lip (darker, offset down), the body with its outline, and the
    gloss band across the top third."""
    return f"""
  <g filter="url(#shadow)">
    <rect x="{x}" y="{y + 16}" width="{w}" height="{h}" rx="{r}" fill="{lip}" stroke="{OUT}" stroke-width="10"/>
    <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="url(#{fill})" stroke="{OUT}" stroke-width="10"/>
  </g>
  <rect x="{x + 22}" y="{y + 16}" width="{w - 44}" height="{h * 0.3:.0f}" rx="{max(r - 16, 8)}" fill="url(#gloss)"/>"""


def bubble(x, y, text, size, fill=WHITE, stroke_w=14, spacing=2):
    return f"""
  <text x="{x}" y="{y}" text-anchor="middle" font-family="Fredoka Bold" font-size="{size}" letter-spacing="{spacing}" fill="{OUT}" stroke="{OUT}" stroke-width="{stroke_w}" stroke-linejoin="round">{text}</text>
  <text x="{x}" y="{y}" text-anchor="middle" font-family="Fredoka Bold" font-size="{size}" letter-spacing="{spacing}" fill="{fill}">{text}</text>"""


def chevron(cx, cy, s, up=True):
    d = -1 if up else 1
    return (
        f'<path d="M{cx - s} {cy - d * s * 0.5} L{cx} {cy + d * s * 0.5} L{cx + s} {cy - d * s * 0.5}" '
        f'fill="none" stroke="{OUT}" stroke-width="30" stroke-linecap="round" stroke-linejoin="round"/>'
        f'<path d="M{cx - s} {cy - d * s * 0.5} L{cx} {cy + d * s * 0.5} L{cx + s} {cy - d * s * 0.5}" '
        f'fill="none" stroke="{WHITE}" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"/>'
    )


def pedals():
    g = grad("green", "#7df29d", "#3ddc6e", "#1e9e48")
    body = chunky_rect(30, 20, 340, 920, 70, "green", "#13702f")
    body += chevron(200, 210, 80) + chevron(200, 330, 80)
    body += bubble(200, 560, "GAS", 120)
    body += chevron(200, 740, 80) + chevron(200, 860, 80)
    (HERE / "pedal_gas.svg").write_text(svg(400, 1000, body, g))
    r = grad("red", "#ff9a9a", "#ff4d4d", "#c42a2a")
    body = chunky_rect(30, 20, 500, 440, 70, "red", "#8e1d1d")
    for y in (110, 360):
        body += f'<rect x="120" y="{y - 22}" width="320" height="44" rx="22" fill="{WHITE}" stroke="{OUT}" stroke-width="10"/>'
    body += bubble(280, 270, "BRAKE", 100)
    (HERE / "pedal_brake.svg").write_text(svg(560, 520, body, r))


def pad():
    g = grad("padg", "#3d4954", "#26303a", "#161c22")
    body = f"""
  <g filter="url(#shadow)">
    <circle cx="400" cy="410" r="364" fill="#0b0f13" stroke="{OUT}" stroke-width="12"/>
    <circle cx="400" cy="398" r="364" fill="url(#padg)" stroke="{OUT}" stroke-width="12"/>
  </g>
  <circle cx="400" cy="400" r="316" fill="none" stroke="#fff" stroke-opacity="0.08" stroke-width="40"/>"""
    for sx in (-1, 1):
        x = 400 + sx * 290
        body += (
            f'<path d="M{x - sx * 30} 350 L{x + sx * 40} 400 L{x - sx * 30} 450 Z" fill="{WHITE}" '
            f'stroke="{OUT}" stroke-width="10" stroke-linejoin="round"/>'
        )
    (HERE / "pad_base.svg").write_text(svg(800, 800, body, g))
    k = grad("knobg", "#ffffff", "#e3e9ef", "#aebbc7")
    knob = f"""
  <g filter="url(#shadow)">
    <circle cx="200" cy="212" r="170" fill="#7d8a96" stroke="{OUT}" stroke-width="12"/>
    <circle cx="200" cy="200" r="170" fill="url(#knobg)" stroke="{OUT}" stroke-width="12"/>
  </g>
  <ellipse cx="200" cy="130" rx="110" ry="60" fill="url(#gloss)"/>
  <circle cx="200" cy="200" r="70" fill="none" stroke="{OUT}" stroke-opacity="0.18" stroke-width="10"/>"""
    (HERE / "pad_knob.svg").write_text(svg(400, 400, knob, k))


def lever():
    g = grad("trackg", "#3d4954", "#26303a", "#161c22")
    body = chunky_rect(40, 14, 140, 596, 60, "trackg", "#0b0f13")
    body += f'<rect x="92" y="72" width="36" height="470" rx="18" fill="#05080a" stroke="{OUT}" stroke-width="6"/>'
    (HERE / "lever_track.svg").write_text(svg(220, 640, body, g))
    o = grad("orange", "#ffd08a", "#ff9f1c", "#d97a00")
    body = chunky_rect(40, 40, 220, 240, 80, "orange", "#a35a00")
    body += bubble(150, 210, "HAND", 64, stroke_w=12)
    (HERE / "lever_handle.svg").write_text(svg(300, 340, body, o))


def natl(lit):
    top, mid, bottom = ("#b5f7ff", "#2ee6ff", "#0aa9c2") if lit else ("#5b6b78", "#33404b", "#1d252d")
    g = grad("natlg", top, mid, bottom)
    halo = f'<circle cx="160" cy="160" r="140" fill="#2ee6ff" opacity="0.7" filter="url(#glow)"/>' if lit else ""
    body = f"""{halo}
  <g filter="url(#shadow)">
    <circle cx="160" cy="172" r="130" fill="{bottom}" stroke="{OUT}" stroke-width="12"/>
    <circle cx="160" cy="160" r="130" fill="url(#natlg)" stroke="{OUT}" stroke-width="12"/>
  </g>
  <ellipse cx="160" cy="104" rx="88" ry="44" fill="url(#gloss)"/>""" + bubble(160, 186, "NATL", 70, stroke_w=12)
    (HERE / f"natl_{'on' if lit else 'off'}.svg").write_text(svg(320, 320, body, g))


def pill():
    g = grad("pillg", "#3d4954", "#26303a", "#161c22")
    body = f"""
  <rect x="8" y="16" width="284" height="96" rx="48" fill="#0b0f13" stroke="{OUT}" stroke-width="8"/>
  <rect x="8" y="8" width="284" height="96" rx="48" fill="url(#pillg)" stroke="{OUT}" stroke-width="8"/>
  <rect x="30" y="16" width="240" height="30" rx="15" fill="url(#gloss)" opacity="0.6"/>"""
    (HERE / "pill.svg").write_text(svg(300, 120, body, g))


def coin():
    g = grad("coing", "#fff2b3", "#ffd23f", "#e0a800")
    body = f"""
  <g filter="url(#shadow)">
    <circle cx="128" cy="136" r="104" fill="#b88600" stroke="{OUT}" stroke-width="10"/>
    <circle cx="128" cy="128" r="104" fill="url(#coing)" stroke="{OUT}" stroke-width="10"/>
  </g>
  <circle cx="128" cy="128" r="74" fill="none" stroke="#b88600" stroke-width="10"/>
  <path d="M128 80 L142 114 L178 114 L149 135 L160 170 L128 149 L96 170 L107 135 L78 114 L114 114 Z" fill="#fff6c8" stroke="#b88600" stroke-width="6" stroke-linejoin="round"/>
  <ellipse cx="108" cy="76" rx="44" ry="20" fill="#fff" opacity="0.5"/>"""
    (HERE / "coin.svg").write_text(svg(256, 256, body, g))


def gauge():
    g = '<radialGradient id="face" cx="0.5" cy="0.4" r="0.6"><stop offset="0" stop-color="#2f3a45"/><stop offset="1" stop-color="#12181e"/></radialGradient>'
    body = f"""
  <g filter="url(#shadow)">
    <circle cx="400" cy="410" r="364" fill="#0b0f13" stroke="{OUT}" stroke-width="14"/>
    <circle cx="400" cy="398" r="364" fill="url(#face)" stroke="{OUT}" stroke-width="14"/>
  </g>
  <circle cx="400" cy="400" r="300" fill="none" stroke="#000" stroke-opacity="0.35" stroke-width="46"/>
  <ellipse cx="400" cy="170" rx="250" ry="90" fill="url(#gloss)" opacity="0.35"/>"""
    (HERE / "gauge_face.svg").write_text(svg(800, 800, body, g))


pedals()
pad()
lever()
natl(False)
natl(True)
pill()
coin()
gauge()
print("ok")
