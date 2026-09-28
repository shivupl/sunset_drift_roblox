--!strict
-- The server half of the time-of-day choice (client Sky, SkyConfig). A player
-- sends the id they picked in the menu; it is kept in their profile, which
-- publishes it back as the Sky attribute and saves it with everything else.
-- It changes nothing anyone else sees: each client lights its own world.
local Players = game:GetService("Players")
local Economy = require(script.Parent.Economy)
local Remotes = require(script.Parent.Remotes)

local SkyService = {}

-- Picks a player may send per second; more are dropped. Each is one click.
local MAX_PER_SECOND = 5

local budget: { [Player]: { at: number, n: number } } = {}

local function allowed(player: Player): boolean
	local now = os.clock()
	local b = budget[player]
	if not b or now - b.at >= 1 then
		budget[player] = { at = now, n = 1 }
		return true
	end
	b.n += 1
	return b.n <= MAX_PER_SECOND
end

function SkyService.start(remotes: Remotes.RemoteTable)
	remotes.SetSky.OnServerEvent:Connect(function(player: Player, id: any)
		if type(id) ~= "string" or #id > 32 or not allowed(player) then
			return
		end
		Economy.setSky(player, id)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		budget[player] = nil
	end)
end

return SkyService
