"""Copies assets/cars/looks.json (the uploaded texture ids of every car
look) into default.project.json as ReplicatedStorage.CarLooks, the
SurfaceAppearance templates BodyBuilder clones. Run after uploading a
texture and pasting its new id into looks.json.

Studio without Rojo: the MCP sync snippet reads the same looks.json."""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
looks = json.load(open(os.path.join(ROOT, "assets", "cars", "looks.json")))
project_path = os.path.join(ROOT, "default.project.json")
project = json.load(open(project_path))
folder = {"$className": "Folder"}
for name, props in sorted(looks.items()):
    folder[name] = {
        "$className": "SurfaceAppearance",
        "$properties": {k: v for k, v in props.items() if k != "source"},
    }
project["tree"]["ReplicatedStorage"]["CarLooks"] = folder
with open(project_path, "w") as fh:
    json.dump(project, fh, indent=2)
    fh.write("\n")
print(f"CarLooks: {', '.join(sorted(looks))}")
