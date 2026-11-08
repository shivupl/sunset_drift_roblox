--!strict
-- Store car dump (README "Steps for a new car", step 1). Not game code: put it
-- in a ModuleScript in ServerStorage in Studio Edit and call
--     require(game.ServerStorage.StoreDump)("tahu", 1370195897)
-- It loads the model with game:GetObjects (scripts deleted before it is
-- parented, never inserted into the place), preloads its meshes into
-- Studio's cache, and prints every BasePart to Studio's log as PARTDUMP lines
-- (index in GetDescendants order, name, parent, class, CFrame, Size,
-- colour, material, transparency, and for MeshParts the mesh and texture
-- ids, MeshSize and any SurfaceAppearance ColorMap). storedump.py turns them
-- into assets/cars/<car>/parts.json with each mesh's triangles. The model is
-- left in the workspace as _StoreDump_<car> at the show spot (0, 600, 0) for
-- looking at; destroy it after.
local HttpService = game:GetService("HttpService")
local ContentProvider = game:GetService("ContentProvider")

local function idOf(s: string): number?
	return tonumber(string.match(s, "%d+$") or "")
end

return function(key: string, assetId: number): string
	local old = workspace:FindFirstChild("_StoreDump_" .. key)
	if old then
		old:Destroy()
	end
	local root = game:GetObjects("rbxassetid://" .. assetId)[1]
	for _, d in root:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	local model: Model
	if root:IsA("Model") then
		model = root
	else
		model = Instance.new("Model")
		root.Parent = model
	end
	model.Name = "_StoreDump_" .. key
	local rows: { { [string]: any } } = {}
	local mps: { MeshPart } = {}
	local i = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			i += 1
			d:SetAttribute("DumpIndex", i)
			local c = d.CFrame
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c:GetComponents()
			local col = d.Color
			local row: { [string]: any } = {
				i = i,
				n = d.Name,
				p = (d.Parent :: Instance).Name,
				c = d.ClassName,
				cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
				s = { d.Size.X, d.Size.Y, d.Size.Z },
				col = { math.round(col.R * 255), math.round(col.G * 255), math.round(col.B * 255) },
				mat = d.Material.Name,
				tr = d.Transparency,
			}
			if d:IsA("MeshPart") then
				table.insert(mps, d)
				row.mesh = idOf(d.MeshId)
				row.tex = idOf(d.TextureID)
				row.ms = { d.MeshSize.X, d.MeshSize.Y, d.MeshSize.Z }
				local sa = d:FindFirstChildOfClass("SurfaceAppearance")
				if sa then
					row.sa = idOf(sa.ColorMap)
				end
			elseif d:IsA("Part") then
				row.shape = d.Shape.Name
			end
			table.insert(rows, row)
		end
	end
	model.Parent = workspace
	pcall(function()
		model:PivotTo(CFrame.new(0, 600, 0) * (model:GetPivot() - model:GetPivot().Position))
	end)
	local done = false
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(mps)
		end)
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < 15 do
		task.wait(0.2)
	end
	local js = HttpService:JSONEncode(rows)
	local n = math.ceil(#js / 900)
	local run = tostring(DateTime.now().UnixTimestampMillis)
	for k = 1, n do
		print("PARTDUMP|" .. key .. "|" .. run .. "|" .. k .. "|" .. n .. "|" .. string.sub(js, (k - 1) * 900 + 1, k * 900))
	end
	return string.format("%s: %d parts, %d meshes, run %s", key, i, #mps, run)
end
