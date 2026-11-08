--!strict
-- Run in Studio Edit (execute_luau or the command bar) after importing
-- assets/cars/upload/<Car>.obj files with the 3D Importer. Finds every
-- imported MeshPart named <Car>_<Piece> anywhere in the workspace and prints
-- one line per piece: "<Car>/<Piece> <meshId> <MeshSize>", plus the piece's
-- sizeM from the generated module, so a wrong import (a squashed or merged
-- mesh) shows before the id goes into CarCatalog. Returns the same text.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local folder = Shared:WaitForChild("CarMeshes")
local out = {}
for _, d in workspace:GetDescendants() do
	if not d:IsA("MeshPart") then
		continue
	end
	local car, piece = string.match(d.Name, "^(%w+)_(.+)$")
	local module = car and folder:FindFirstChild(car)
	if not module or not module:IsA("ModuleScript") then
		continue
	end
	local data = (require :: any)(module:Clone())[piece]
	if not data then
		continue
	end
	local id = string.match(d.MeshId, "(%d+)$") or "NONE"
	local m = d.MeshSize
	local s = data.sizeM
	table.insert(out, string.format("%s/%s %s mesh %.4f %.4f %.4f size %.4f %.4f %.4f", car :: string, piece :: string, id, m.X, m.Y, m.Z, s[1], s[2], s[3]))
end
table.sort(out)
local text = table.concat(out, "\n")
print(text)
return text
