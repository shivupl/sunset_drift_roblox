-- Paste into the Studio command bar / MCP execute_luau (Edit datamodel).
-- Pulls build/manifest.json from the local HTTP server and mirrors src into
-- the DataModel with the same tree as default.project.json.
-- Start the server first:  python3 -m http.server 8765 --bind 127.0.0.1
-- Regenerate the manifest: python3 scripts/mcp_sync.py --manifest
local HttpService = game:GetService("HttpService")
HttpService.HttpEnabled = true
local BASE = "http://127.0.0.1:8765/"
local manifest = HttpService:JSONDecode(HttpService:GetAsync(BASE .. "build/manifest.json?t=" .. os.time()))
local function resolve(pathParts)
	local node = game:GetService(pathParts[1])
	for i = 2, #pathParts do
		node = node:FindFirstChild(pathParts[i]) or error("missing " .. table.concat(pathParts, ".", 1, i))
	end
	return node
end
local count = 0
for _, e in manifest do
	local parent = resolve(e.parent)
	local inst = parent:FindFirstChild(e.name)
	if inst and inst.ClassName ~= e.className then inst:Destroy() inst = nil end
	if not inst then
		inst = Instance.new(e.className)
		inst.Name = e.name
		inst.Parent = parent
	end
	if e.file then
		local src = HttpService:GetAsync(BASE .. e.file .. "?t=" .. os.time())
		if inst.Source ~= src then inst.Source = src count += 1 end
	end
end
return "synced " .. count .. " sources of " .. #manifest .. " instances"
