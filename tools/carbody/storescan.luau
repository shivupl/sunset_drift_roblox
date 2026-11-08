--!strict
-- Store car scan (README "Finding store cars"). Not game code: paste into a
-- ModuleScript in ServerStorage in Studio Edit, then from the command bar or
-- MCP execute_luau run, a handful of ids at a time (each call must finish in
-- about two minutes):
--     require(game.ServerStorage.StoreScan)({ 1370195897, 9547275128 })
-- It loads each model with game:GetObjects (never inserted into the place;
-- scripts deleted before it is parented), prints a CARSCAN line per car to
-- Studio's log (storescan.py reads them and adds the triangles up from
-- Studio's mesh cache), and returns one summary line per car: parts, meshes,
-- seats, and any part named SW or *steer* (a steering wheel of its own, which
-- the first-person view can turn). Preloading each car's meshes puts them in
-- the cache; a car whose assets never finish loading is given 8 s.
local HttpService = game:GetService("HttpService")
local ContentProvider = game:GetService("ContentProvider")

return function(IDS: { number }): string
	local summary: { string } = {}
	local holder = Instance.new("Folder")
	holder.Name = "_StoreScan"
	holder.Parent = workspace
	for _, id in IDS do
		local rec: { [string]: any } = { id = id }
		local ok, objs = pcall(function()
			return game:GetObjects("rbxassetid://" .. id)
		end)
		if not ok or not objs[1] then
			table.insert(summary, id .. " ERR " .. string.sub(tostring(objs), 1, 80))
		else
			local root = objs[1]
			for _, d in root:GetDescendants() do
				if d:IsA("LuaSourceContainer") then
					d:Destroy()
				end
			end
			rec.name = root.Name
			local parts, seats = 0, 0
			local sw: { string }, uniq: { [string]: number }, mps: { MeshPart } = {}, {}, {}
			for _, d in root:GetDescendants() do
				if d:IsA("BasePart") then
					parts += 1
				end
				if d:IsA("MeshPart") then
					table.insert(mps, d :: MeshPart)
					local m = (d :: MeshPart).MeshSize
					local k = string.format("%.4f,%.4f,%.4f", m.X, m.Y, m.Z)
					uniq[k] = (uniq[k] or 0) + 1
				end
				if d:IsA("Seat") or d:IsA("VehicleSeat") then
					seats += 1
				end
				local n = string.lower(d.Name)
				if (d:IsA("Model") or d:IsA("BasePart")) and (n == "sw" or n:find("steer")) then
					local c = 0
					local pool: { Instance } = if d:IsA("Model") then d:GetDescendants() else { d }
					for _, x in pool do
						if x:IsA("BasePart") then
							c += 1
						end
					end
					if c > 0 then
						table.insert(sw, (d.Parent :: Instance).Name .. "." .. d.Name .. ":" .. c)
					end
				end
			end
			local list: { string } = {}
			for k, c in uniq do
				table.insert(list, k .. "x" .. c)
			end
			rec.parts, rec.meshes, rec.seats, rec.sw = parts, #mps, seats, sw
			rec.sizes = table.concat(list, ";")
			if root:IsA("Model") then
				pcall(function()
					root:PivotTo(CFrame.new(0, 2000, 0))
				end)
			end
			root.Parent = holder
			local done = false
			task.spawn(function()
				pcall(function()
					ContentProvider:PreloadAsync(mps)
				end)
				done = true
			end)
			local t0 = os.clock()
			while not done and os.clock() - t0 < 8 do
				task.wait(0.2)
			end
			local js = HttpService:JSONEncode(rec)
			local n = math.ceil(#js / 900)
			for i = 1, n do
				print("CARSCAN|" .. id .. "|" .. i .. "|" .. n .. "|" .. string.sub(js, (i - 1) * 900 + 1, i * 900))
			end
			table.insert(summary, string.format("%d %s | parts %d meshes %d seats %d sw %s", id, root.Name, parts, #mps, seats, table.concat(sw, " ")))
			root:Destroy()
		end
	end
	holder:Destroy()
	return table.concat(summary, "\n")
end
