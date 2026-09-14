"""Copies a generated car's numbers into its CarCatalog entry: every piece
with mesh = "<Car>/<Piece>" gets the generator's sizeM and offsetM, and
body.plates gets the plate mounts. Run after the car's generator.

  python3 tools/carbody/apply_catalog.py kamri
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def fmt(v):
    return "{ " + ", ".join(("0" if abs(x) < 5e-5 else f"{x:.4f}".rstrip("0").rstrip(".")) for x in v) + " }"


def main():
    car = sys.argv[1]
    module = car[0].upper() + car[1:]
    summary = json.load(open(os.path.join(ROOT, "assets", "cars", car, "summary.json")))
    path = os.path.join(ROOT, "src", "shared", "CarCatalog.luau")
    text = open(path).read()
    changed = 0
    for name, info in summary.items():
        if not isinstance(info, dict) or "sizeM" not in info:
            continue
        pattern = re.compile(r'(mesh = "' + module + "/" + name + r'"[^\n]*?sizeM = )\{[^}]*\}(, offsetM = )\{[^}]*\}')
        text, n = pattern.subn(lambda m: m.group(1) + fmt(info["sizeM"]) + m.group(2) + fmt(info["offsetM"]), text)
        changed += n
    if "plates" in summary:
        p = summary["plates"]
        text, n = re.subn(r"plates = \{ front = \{[^}]*\}, rear = \{[^}]*\},",
                          f"plates = {{ front = {fmt(p['front'])}, rear = {fmt(p['rear'])},", text)
        changed += n
    open(path, "w").write(text)
    print(f"{changed} catalog values updated for {module}")


if __name__ == "__main__":
    main()
