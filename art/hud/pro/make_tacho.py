#!/usr/bin/env python3
"""Writes tacho_face.svg and needle.svg for PRO: the dial runs from FROM_DEG
(0 rpm) to TO_DEG (8000 rpm), 0 = straight up, clockwise; the same angles the
needle is turned by in Roblox (HudLab/Variants/Pro.luau TACHO_FROM/TO)."""
import math

FROM_DEG, TO_DEG, MAX_K, REDLINE_K = -135, 100, 8, 6.8
C, SIZE = 400, 800


def at(deg, r):
    a = math.radians(deg)
    return C + r * math.sin(a), C - r * math.cos(a)


def deg_of(k):
    return FROM_DEG + (TO_DEG - FROM_DEG) * k / MAX_K


ticks = []
for i in range(0, MAX_K * 4 + 1):
    k = i / 4
    d = deg_of(k)
    major = i % 4 == 0
    r1, r2 = (350, 300) if major else (350, 324)
    x1, y1 = at(d, r1)
    x2, y2 = at(d, r2)
    col = "#ff3b2b" if k >= REDLINE_K else "#f2f4f6"
    w = 7 if major else 3.5
    ticks.append(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{col}" stroke-width="{w}" stroke-linecap="round"/>')
nums = []
for k in range(MAX_K + 1):
    x, y = at(deg_of(k), 252)
    col = "#ff5a45" if k >= 7 else "#f2f4f6"
    nums.append(f'<text x="{x:.1f}" y="{y + 24:.1f}" text-anchor="middle" font-family="Oswald SemiBold" font-size="68" fill="{col}">{k}</text>')
# The red band along the outside from the redline to the end.
a0, a1 = deg_of(REDLINE_K), deg_of(MAX_K)
xa, ya = at(a0, 362)
xb, yb = at(a1, 362)
band = f'<path d="M{xa:.1f} {ya:.1f} A362 362 0 0 1 {xb:.1f} {yb:.1f}" fill="none" stroke="#ff3b2b" stroke-width="12" stroke-opacity="0.85"/>'

face = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">
  <defs>
    <filter id="shadow" x="-10%" y="-10%" width="120%" height="125%"><feDropShadow dx="0" dy="14" stdDeviation="14" flood-color="#000" flood-opacity="0.6"/></filter>
    <filter id="bezel" x="-5%" y="-5%" width="110%" height="110%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="9" result="h"/>
      <feSpecularLighting in="h" surfaceScale="7" specularConstant="0.9" specularExponent="26" lighting-color="#fff" result="spec"><feDistantLight azimuth="225" elevation="45"/></feSpecularLighting>
      <feComposite in="spec" in2="SourceAlpha" operator="in" result="sp"/>
      <feComposite in="SourceGraphic" in2="sp" operator="arithmetic" k1="0" k2="1" k3="0.5" k4="0"/>
    </filter>
    <filter id="grain" x="0" y="0" width="100%" height="100%">
      <feTurbulence type="fractalNoise" baseFrequency="1.2" numOctaves="2" seed="21" result="g"/>
      <feColorMatrix in="g" type="matrix" values="0 0 0 0 0.2  0 0 0 0 0.2  0 0 0 0 0.22  0 0 0 0.25 0" result="gc"/>
      <feComposite in="gc" in2="SourceAlpha" operator="in" result="gi"/>
      <feMerge><feMergeNode in="SourceGraphic"/><feMergeNode in="gi"/></feMerge>
    </filter>
    <linearGradient id="chrome" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="0.35" stop-color="#8e949c"/><stop offset="0.55" stop-color="#eef0f3"/><stop offset="1" stop-color="#43474d"/></linearGradient>
    <radialGradient id="face" cx="0.5" cy="0.45" r="0.6"><stop offset="0" stop-color="#262a31"/><stop offset="0.75" stop-color="#121418"/><stop offset="1" stop-color="#07080a"/></radialGradient>
    <linearGradient id="glare" x1="0" y1="0" x2="0.6" y2="1"><stop offset="0" stop-color="#ffffff" stop-opacity="0.16"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/></linearGradient>
    <clipPath id="faceClip"><circle cx="{C}" cy="{C}" r="368"/></clipPath>
  </defs>
  <g filter="url(#shadow)"><circle cx="{C}" cy="{C}" r="396" fill="url(#chrome)" filter="url(#bezel)"/></g>
  <circle cx="{C}" cy="{C}" r="368" fill="url(#face)" filter="url(#grain)"/>
  <circle cx="{C}" cy="{C}" r="368" fill="none" stroke="#000" stroke-opacity="0.7" stroke-width="6"/>
  {band}
  {"".join(ticks)}
  {"".join(nums)}
  <text x="{C}" y="{C - 120}" text-anchor="middle" font-family="Oswald SemiBold" font-size="30" letter-spacing="4" fill="#9aa1aa">x1000 r/min</text>
  <g clip-path="url(#faceClip)"><ellipse cx="300" cy="190" rx="330" ry="210" fill="url(#glare)" transform="rotate(-20 300 190)"/></g>
</svg>
'''
open("tacho_face.svg", "w").write(face)

needle = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">
  <defs>
    <filter id="glow" x="-200%" y="-20%" width="500%" height="140%"><feGaussianBlur stdDeviation="7"/></filter>
    <filter id="cap" x="-10%" y="-10%" width="120%" height="130%">
      <feDropShadow dx="0" dy="6" stdDeviation="6" flood-color="#000" flood-opacity="0.6"/>
    </filter>
    <linearGradient id="red" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ff7a52"/><stop offset="0.5" stop-color="#ff3b2b"/><stop offset="1" stop-color="#c9200f"/></linearGradient>
    <radialGradient id="capG" cx="0.4" cy="0.35" r="0.7"><stop offset="0" stop-color="#5a5f66"/><stop offset="1" stop-color="#0d0e10"/></radialGradient>
  </defs>
  <path d="M{C - 9} {C + 40} L{C - 3} {C - 330} L{C + 3} {C - 330} L{C + 9} {C + 40} Z" fill="#ff3b2b" opacity="0.65" filter="url(#glow)"/>
  <path d="M{C - 9} {C + 40} L{C - 3} {C - 330} L{C + 3} {C - 330} L{C + 9} {C + 40} Z" fill="url(#red)"/>
  <path d="M{C - 1} {C - 20} L{C - 1} {C - 320} L{C + 1} {C - 320} L{C + 1} {C - 20} Z" fill="#ffd2c4" opacity="0.85"/>
  <circle cx="{C}" cy="{C}" r="46" fill="url(#capG)" filter="url(#cap)"/>
  <circle cx="{C}" cy="{C}" r="46" fill="none" stroke="#8c9198" stroke-width="3"/>
</svg>
'''
open("needle.svg", "w").write(needle)
print("ok")
