-- Paste into the Studio command bar / MCP execute_luau (Edit datamodel).
-- Runs the spec suite against the CURRENT source of every shared module.
--
-- require() caches per instance and setting .Source does not reliably
-- invalidate that cache in Edit mode, so cloning the whole Shared folder is
-- what makes a re-run actually re-evaluate the code you just synced.
local shared = game.ReplicatedStorage.Shared
local clone = shared:Clone()
clone.Name = "SharedTestClone"
clone.Parent = game.ReplicatedStorage
local ok, passed, failed = pcall(function()
	return require(clone.Tests)()
end)
clone:Destroy()
if not ok then
	return "runner error: " .. tostring(passed)
end
return "tests " .. tostring(passed) .. " passed, " .. tostring(failed) .. " failed"
