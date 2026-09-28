--!strict
local SkyConfig = require(script.Parent.Parent.SkyConfig)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local seen: { [string]: boolean } = {}
	for _, o in SkyConfig.options do
		t.ok(not seen[o.id], `id {o.id} is unique`)
		seen[o.id] = true
		t.ok(o.label ~= "", `{o.id} has a label`)
		t.ok(o.clockTime >= 0 and o.clockTime < 24, `{o.id} clockTime is an hour of the day`)
	end
	t.ok(SkyConfig.find(SkyConfig.default) ~= nil, "the default is one of the options")
	t.eq(SkyConfig.resolve("night").id, "night", "a known id resolves to itself")
	t.eq(SkyConfig.resolve("noon").id, SkyConfig.default, "an unknown id falls back to the default")
	t.eq(SkyConfig.resolve(nil).id, SkyConfig.default, "no id falls back to the default")
	t.eq(SkyConfig.find("noon"), nil, "find refuses an unknown id")
end
