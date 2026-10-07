#!/usr/bin/env python3
"""Writes MIDNIGHT's art (after Midnight Racing: Tokyo): smoked dark glass
with lit edges, thin white instrument lines, cyan light, a red needle.

Run from this folder; then art/hud/render.py renders the SVGs. The dial runs
from FROM_DEG (0 rpm) to TO_DEG (8000), the angles the needle is turned by in
HudLab/Variants/Midnight.luau.
"""
import math
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
CYAN = "#3adcf2"
WHITE = "#f2f4f5"
RED = "#ff3e3e"
FROM_DEG, TO_DEG, MAX_K, REDLINE_K = -132, 112, 8, 6.8

DEFS = f"""
    <filter id="glow" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="9"/></filter>
    <filter id="softglow" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="4"/></filter>
    <filter id="shadow" x="-30%" y="-20%" width="160%" height="150%"><feDropShadow dx="0" dy="10" stdDeviation="12" flood-color="#000" flood-opacity="0.6"/></filter>
    <linearGradient id="glass" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#16212b" stop-opacity="0.86"/>
      <stop offset="1" stop-color="#04070a" stop-opacity="0.92"/>
    </linearGradient>
    <linearGradient id="edge" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{WHITE}"/>
      <stop offset="0.5" stop-color="{CYAN}"/>
      <stop offset="1" stop-color="{WHITE}" stop-opacity="0.5"/>
    </linearGradient>
    <linearGradient id="gloss" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#fff" stop-opacity="0.2"/>
      <stop offset="1" stop-color="#fff" stop-opacity="0"/>
    </linearGradient>
"""


def svg(w, h, body, defs=""):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
        f"<defs>{DEFS}{defs}</defs>{body}</svg>\n"
    )


def glass_panel(x, y, w, h, r, lit=False):
    """A smoked-glass panel: cyan halo, glass body, gloss on the top half,
    a lit edge and a fainter inner one."""
    halo = 0.55 if lit else 0.3
    return f"""
  <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="none" stroke="{CYAN}" stroke-width="10" opacity="{halo}" filter="url(#glow)"/>
  <g filter="url(#shadow)"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="url(#glass)"/></g>
  <clipPath id="c{x}{y}"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}"/></clipPath>
  <rect x="{x}" y="{y}" width="{w}" height="{h * 0.48:.0f}" fill="url(#gloss)" clip-path="url(#c{x}{y})"/>
  <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="none" stroke="url(#edge)" stroke-width="4"/>
  <rect x="{x + 9}" y="{y + 9}" width="{w - 18}" height="{h - 18}" rx="{max(r - 9, 2)}" fill="none" stroke="{CYAN}" stroke-opacity="0.22" stroke-width="2"/>"""


def glow_text(x, y, text, size, color=WHITE, spacing=6):
    return f"""
  <text x="{x}" y="{y}" text-anchor="middle" font-family="Orbitron Bold" font-size="{size}" letter-spacing="{spacing}" fill="{CYAN}" opacity="0.8" filter="url(#softglow)">{text}</text>
  <text x="{x}" y="{y}" text-anchor="middle" font-family="Orbitron Bold" font-size="{size}" letter-spacing="{spacing}" fill="{color}">{text}</text>"""


def lines(x, w, ys, h=10):
    return "".join(
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{h / 2}" fill="{WHITE}" fill-opacity="0.22"/>' for y in ys
    )


def pedal(name, w, h, label, line_ys, label_y, size):
    body = glass_panel(24, 20, w - 48, h - 48, 44)
    body += lines(70, w - 140, line_ys)
    body += glow_text(w / 2, label_y, label, size)
    (HERE / f"{name}.svg").write_text(svg(w, h, body))


def at(deg, r, c=400):
    a = math.radians(deg)
    return c + r * math.sin(a), c - r * math.cos(a)


def deg_of(k):
    return FROM_DEG + (TO_DEG - FROM_DEG) * k / MAX_K


def tacho():
    parts = [
        f'<circle cx="400" cy="400" r="392" fill="none" stroke="{CYAN}" stroke-width="10" opacity="0.25" filter="url(#glow)"/>',
        '<circle cx="400" cy="400" r="388" fill="#05080b" fill-opacity="0.62"/>',
        f'<circle cx="400" cy="400" r="388" fill="none" stroke="{WHITE}" stroke-width="4"/>',
        f'<circle cx="400" cy="400" r="370" fill="none" stroke="{WHITE}" stroke-opacity="0.25" stroke-width="2"/>',
    ]
    for i in range(MAX_K * 10 + 1):
        k = i / 10
        major, half = i % 10 == 0, i % 5 == 0
        r1, r2 = 360, (318 if major else 336 if half else 346)
        x1, y1 = at(deg_of(k), r1)
        x2, y2 = at(deg_of(k), r2)
        col = RED if k >= REDLINE_K else WHITE
        sw = 5 if major else 2.5
        parts.append(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{col}" stroke-width="{sw}" stroke-linecap="round"/>')
    for k in range(MAX_K + 1):
        x, y = at(deg_of(k), 268)
        col = RED if k >= 7 else WHITE
        parts.append(f'<text x="{x:.1f}" y="{y + 20:.1f}" text-anchor="middle" font-family="Orbitron Bold" font-size="54" fill="{col}">{k}</text>')
    a, b = at(deg_of(REDLINE_K), 376), at(deg_of(MAX_K), 376)
    parts.append(f'<path d="M{a[0]:.1f} {a[1]:.1f} A376 376 0 0 1 {b[0]:.1f} {b[1]:.1f}" fill="none" stroke="{RED}" stroke-width="8" opacity="0.9"/>')
    parts.append(f'<text x="400" y="290" text-anchor="middle" font-family="Orbitron Bold" font-size="24" letter-spacing="4" fill="{WHITE}" fill-opacity="0.6">x1000 RPM</text>')
    (HERE / "tacho_face.svg").write_text(svg(800, 800, "".join(parts)))
    needle = f"""
  <path d="M396 430 L398.5 50 L401.5 50 L404 430 Z" fill="{RED}" opacity="0.7" filter="url(#softglow)"/>
  <path d="M396 430 L398.5 50 L401.5 50 L404 430 Z" fill="{RED}"/>
  <circle cx="400" cy="400" r="30" fill="#05080b"/>
  <circle cx="400" cy="400" r="30" fill="none" stroke="{WHITE}" stroke-width="3"/>"""
    (HERE / "needle.svg").write_text(svg(800, 800, needle))


def lever():
    body = glass_panel(50, 16, 120, 608, 40)
    body += f'<rect x="96" y="70" width="28" height="500" rx="14" fill="#000" fill-opacity="0.75"/>'
    body += "".join(
        f'<rect x="138" y="{y}" width="18" height="4" rx="2" fill="{CYAN}" fill-opacity="{o}"/>'
        for y, o in ((230, 0.9), (270, 0.6), (310, 0.6), (350, 0.9))
    )
    (HERE / "lever_track.svg").write_text(svg(220, 640, body))
    handle = glass_panel(40, 40, 220, 250, 70)
    handle += f'<rect x="80" y="104" width="140" height="10" rx="5" fill="{CYAN}" opacity="0.9"/>'
    handle += f'<rect x="80" y="104" width="140" height="10" rx="5" fill="{CYAN}" filter="url(#softglow)"/>'
    handle += lines(84, 132, (150, 178, 206), 8)
    handle += glow_text(150, 262, "HAND", 34, spacing=5)
    (HERE / "lever_handle.svg").write_text(svg(300, 340, handle))


def natl(lit):
    ring = 0.9 if lit else 0.35
    fill = CYAN if lit else "#05080b"
    fo = 0.85 if lit else 0.7
    txt = "#04121a" if lit else WHITE
    body = f"""
  <circle cx="160" cy="160" r="136" fill="none" stroke="{CYAN}" stroke-width="14" opacity="{ring}" filter="url(#glow)"/>
  <g filter="url(#shadow)"><circle cx="160" cy="160" r="128" fill="{fill}" fill-opacity="{fo}"/></g>
  <circle cx="160" cy="160" r="128" fill="none" stroke="url(#edge)" stroke-width="5"/>
  <ellipse cx="160" cy="100" rx="96" ry="52" fill="url(#gloss)"/>
  <text x="160" y="182" text-anchor="middle" font-family="Orbitron Bold" font-size="56" letter-spacing="4" fill="{txt}">NATL</text>"""
    (HERE / f"natl_{'on' if lit else 'off'}.svg").write_text(svg(320, 320, body))


def pill():
    body = f"""
  <rect x="8" y="8" width="284" height="104" rx="52" fill="url(#glass)"/>
  <rect x="8" y="8" width="284" height="50" rx="25" fill="url(#gloss)"/>
  <rect x="8" y="8" width="284" height="104" rx="52" fill="none" stroke="url(#edge)" stroke-width="3"/>"""
    (HERE / "pill.svg").write_text(svg(300, 120, body))


def slider():
    body = glass_panel(16, 16, 868, 168, 84)
    for i, x in enumerate((90, 130, 770, 810)):
        d = -1 if i < 2 else 1
        o = 0.5 if i in (0, 3) else 0.9
        body += f'<path d="M{x - 14 * d} 72 L{x + 14 * d} 100 L{x - 14 * d} 128" fill="none" stroke="{CYAN}" stroke-width="8" stroke-linecap="round" stroke-linejoin="round" opacity="{o}"/>'
    body += f'<rect x="446" y="56" width="8" height="88" rx="4" fill="{WHITE}" fill-opacity="0.35"/>'
    (HERE / "slider_track.svg").write_text(svg(900, 200, body))
    knob = f"""
  <circle cx="100" cy="100" r="84" fill="{CYAN}" opacity="0.55" filter="url(#glow)"/>
  <circle cx="100" cy="100" r="76" fill="#eef8fb"/>
  <circle cx="100" cy="100" r="76" fill="none" stroke="{CYAN}" stroke-width="6"/>
  <ellipse cx="100" cy="72" rx="52" ry="30" fill="#fff" fill-opacity="0.6"/>
  <circle cx="100" cy="100" r="22" fill="none" stroke="{CYAN}" stroke-opacity="0.6" stroke-width="4"/>"""
    (HERE / "slider_knob.svg").write_text(svg(200, 200, knob))


pedal("pedal_gas", 400, 1000, "GAS", (120, 200, 280, 700, 780, 860), 520, 92)
pedal("pedal_brake", 560, 520, "BRAKE", (90, 160, 340, 410), 278, 74)
tacho()
lever()
natl(False)
natl(True)
pill()
slider()
print("ok")
