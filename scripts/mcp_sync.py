#!/usr/bin/env python3
"""Emit Luau chunks that mirror src/ into a Studio DataModel using the same
tree as default.project.json. Used by the Studio MCP (execute_luau) as a
fallback when the Rojo plugin is not connected. Rojo remains the real sync.

Usage: scripts/mcp_sync.py [--out DIR]   writes one .luau chunk per root
"""
import os, sys, json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOTS = [
    ("src/server", ["ServerScriptService"], "Server"),
    ("src/client", ["StarterPlayer", "StarterPlayerScripts"], "Client"),
    ("src/shared", ["ReplicatedStorage"], "Shared"),
]

def long_string(s: str) -> str:
    level = 1
    while ("]" + "=" * level + "]") in s:
        level += 1
    eq = "=" * level
    return f"[{eq}[\n{s}]{eq}]"

def class_for(fname: str):
    if fname == "init.server.luau": return "Script", True
    if fname == "init.client.luau": return "LocalScript", True
    if fname == "init.luau": return "ModuleScript", True
    if fname.endswith(".server.luau"): return "Script", False
    if fname.endswith(".client.luau"): return "LocalScript", False
    if fname.endswith(".luau"): return "ModuleScript", False
    return None, False

def inst_name(fname: str) -> str:
    for suf in (".server.luau", ".client.luau", ".luau"):
        if fname.endswith(suf): return fname[: -len(suf)]
    return fname

def walk(dir_path: str, parent_expr: str, name: str, lines: list):
    entries = sorted(os.listdir(dir_path))
    init = next((e for e in entries if e in ("init.server.luau", "init.client.luau", "init.luau")), None)
    if init:
        cls, _ = class_for(init)
        src = open(os.path.join(dir_path, init), encoding="utf-8").read()
        var = f"n{len(lines)}"
        lines.append(f'local {var} = ensure({parent_expr}, "{name}", "{cls}")')
        lines.append(f'{var}.Source = {long_string(src)}')
    else:
        var = f"n{len(lines)}"
        lines.append(f'local {var} = ensure({parent_expr}, "{name}", "Folder")')
    for e in entries:
        full = os.path.join(dir_path, e)
        if os.path.isdir(full):
            walk(full, var, e, lines)
        elif e != init and e.endswith(".luau"):
            cls, _ = class_for(e)
            src = open(full, encoding="utf-8").read()
            v = f"n{len(lines)}"
            lines.append(f'local {v} = ensure({var}, "{inst_name(e)}", "{cls}")')
            lines.append(f'{v}.Source = {long_string(src)}')
    return var

HEADER = '''local function ensure(parent, name, className)
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName ~= className then existing:Destroy() existing = nil end
	if not existing then existing = Instance.new(className) existing.Name = name existing.Parent = parent end
	return existing
end
'''

def manifest():
    """Write build/manifest.json: ordered list of {parent, name, className, file}."""
    entries = []
    def walk_m(dir_path, parent_path, name):
        rel = os.path.relpath(dir_path, ROOT)
        entries_here = sorted(os.listdir(dir_path))
        init = next((e for e in entries_here if e in ("init.server.luau", "init.client.luau", "init.luau")), None)
        cls = class_for(init)[0] if init else "Folder"
        entries.append({"parent": parent_path, "name": name, "className": cls,
                        "file": (rel + "/" + init) if init else None})
        my_path = parent_path + [name]
        for e in entries_here:
            full = os.path.join(dir_path, e)
            if os.path.isdir(full):
                walk_m(full, my_path, e)
            elif e != init and e.endswith(".luau"):
                entries.append({"parent": my_path, "name": inst_name(e), "className": class_for(e)[0],
                                "file": rel + "/" + e})
    for rel, services, name in ROOTS:
        walk_m(os.path.join(ROOT, rel), services, name)
    os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
    with open(os.path.join(ROOT, "build", "manifest.json"), "w") as f:
        json.dump(entries, f)
    print(f"manifest: {len(entries)} entries")

def main():
    if "--manifest" in sys.argv:
        manifest(); return
    out_dir = None
    if "--out" in sys.argv:
        out_dir = sys.argv[sys.argv.index("--out") + 1]
        os.makedirs(out_dir, exist_ok=True)
    chunks = []
    for rel, services, name in ROOTS:
        lines = []
        parent = "game:GetService(\"" + services[0] + "\")"
        for s in services[1:]:
            parent = f'{parent}:FindFirstChild("{s}")'
        walk(os.path.join(ROOT, rel), parent, name, lines)
        code = HEADER + "\n".join(lines) + f'\nreturn "synced {name}: {len(lines)} ops"\n'
        chunks.append((name, code))
    for name, code in chunks:
        if out_dir:
            open(os.path.join(out_dir, f"sync_{name}.luau"), "w", encoding="utf-8").write(code)
        else:
            print(f"=== {name}: {len(code)} bytes")
    if out_dir:
        print(json.dumps([os.path.join(out_dir, f"sync_{n}.luau") for n, _ in chunks]))

if __name__ == "__main__":
    main()
