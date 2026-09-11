--!strict
-- Spec runner. Run in Studio (command bar or MCP execute_luau, Edit datamodel):
--   require(game.ReplicatedStorage.Shared.Tests)()
-- Each child ModuleScript returns function(t: T) and calls t.eq / t.near / t.ok.

export type T = {
	eq: (actual: any, expected: any, msg: string?) -> (),
	near: (actual: number, expected: number, eps: number, msg: string?) -> (),
	ok: (cond: boolean, msg: string?) -> (),
}

return function(): (number, number)
	local passed, failed = 0, 0
	local lines: { string } = {}

	for _, child in script:GetChildren() do
		if not child:IsA("ModuleScript") then
			continue
		end
		local name = child.Name
		local t: T = {
			eq = function(actual, expected, msg)
				if actual == expected then
					passed += 1
				else
					failed += 1
					table.insert(lines, `{name}: {msg or "eq"} expected {tostring(expected)} got {tostring(actual)}`)
				end
			end,
			near = function(actual, expected, eps, msg)
				if math.abs(actual - expected) <= eps then
					passed += 1
				else
					failed += 1
					table.insert(lines, `{name}: {msg or "near"} expected {expected}±{eps} got {actual}`)
				end
			end,
			ok = function(cond, msg)
				if cond then
					passed += 1
				else
					failed += 1
					table.insert(lines, `{name}: {msg or "ok"} was false`)
				end
			end,
		}
		local spec = (require :: any)(child) :: (T) -> any
		local okRun, err = pcall(spec, t)
		if not okRun then
			failed += 1
			table.insert(lines, `{name}: error {tostring(err)}`)
		end
	end

	print(`[Tests] {passed} passed, {failed} failed`)
	for _, line in lines do
		warn(line)
	end
	return passed, failed
end
