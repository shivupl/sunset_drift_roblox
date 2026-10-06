--!strict
-- The server half of the garage (docs/superpowers/specs/2026-09-28-garage-design.md §5).
--
-- Remote CosmeticsAction (RemoteFunction), each returning { status }:
--   ("buy", id)                  buy a cosmetic at CosmeticsConfig's price
--   ("equip", carId, slot, id)   fit an owned cosmetic to one car (stock id or nil clears);
--                                a tyre only to a car of its drivetrain (garage-tyres-flames)
--   ("plate", carId, plateKey?)  pick one of my plates for one car (nil clears)
-- status: done | owned | cash | unavailable | busy | unknown | notowned.
--
-- Same discipline as PlateService: nothing the client says is trusted (every
-- argument is type-checked, the price always comes from CosmeticsConfig),
-- actions are rate-limited, one at a time per player, and refused until the
-- player's profile has loaded and can be saved.
--
-- Each car carries its owner's look for that car as the Model attribute
-- "Look" (CarLook.encode), stamped on spawn and again after any change.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CosmeticsConfig = require(Shared:WaitForChild("CosmeticsConfig"))
local CarLook = require(Shared:WaitForChild("CarLook"))
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local Economy = require(script.Parent.Economy)
local PlateService = require(script.Parent.PlateService)
local Remotes = require(script.Parent.Remotes)

type Reply = { status: string }

local CosmeticsService = {}

-- Longest id or plate key accepted from a client before any lookup.
local MAX_ARG_LENGTH = 64

local ready: { [Player]: boolean } = {}
local busy: { [Player]: boolean } = {}
local budget: { [Player]: { at: number, n: number } } = {}

local function allowed(player: Player): boolean
	local now = os.clock()
	local b = budget[player]
	if not b or now - b.at >= 1 then
		budget[player] = { at = now, n = 1 }
		return true
	end
	b.n += 1
	return b.n <= CosmeticsConfig.actionsPerSecond
end

local function isText(v: any): boolean
	return type(v) == "string" and #v > 0 and #v <= MAX_ARG_LENGTH
end

local function carOf(player: Player): Model?
	local cars = Workspace:FindFirstChild("Cars")
	if not cars then
		return nil
	end
	for _, m in cars:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("OwnerUserId") == player.UserId then
			return m
		end
	end
	return nil
end

local function stampCar(owner: Player, car: Model)
	local carId = car:GetAttribute("CarId")
	if type(carId) == "string" then
		car:SetAttribute(CarLook.ATTRIBUTE, CarLook.encode(Economy.look(owner, carId)))
	end
end

-- After a change to carId's look: re-stamp the owner's car if it is that car.
local function restamp(player: Player, carId: string?)
	local car = carOf(player)
	if car and (carId == nil or car:GetAttribute("CarId") == carId) then
		stampCar(player, car)
	end
end

-- Runs fn as this player's only cosmetics action. False if one is already
-- running (fn did not run). The second return is false if fn raised.
local function exclusive(player: Player, fn: () -> ()): (boolean, boolean)
	if busy[player] then
		return false, false
	end
	busy[player] = true
	local ok, err = pcall(function()
		fn()
	end)
	busy[player] = nil
	if not ok then
		warn(`[Cosmetics] {player.Name}: {tostring(err)}`)
	end
	return true, ok
end

local function buy(player: Player, id: any): Reply
	if not isText(id) then
		return { status = "unknown" }
	end
	local item = CosmeticsConfig.find(id)
	if not item then
		return { status = "unknown" }
	end
	if Economy.owns(player, id) then
		return { status = "owned" }
	end
	if not ready[player] then
		return { status = "unavailable" }
	end
	local outcome = Economy.buyCosmetic(player, id, item.price)
	if outcome == "ok" then
		return { status = "done" }
	elseif outcome == "refused" then
		return { status = if Economy.owns(player, id) then "owned" else "cash" }
	end
	return { status = "unavailable" }
end

local function isCar(carId: any): boolean
	-- ConfigLoader.entry falls back to the default car for an unknown id, so
	-- ask the catalog itself.
	return isText(carId) and ConfigLoader.catalog().cars[carId] ~= nil
end

local function equip(player: Player, carId: any, slot: any, id: any): Reply
	if not isCar(carId) or type(slot) ~= "string" or not table.find(CarLook.SLOTS, slot :: any) then
		return { status = "unknown" }
	end
	if id ~= nil then
		if not isText(id) then
			return { status = "unknown" }
		end
		local item = CosmeticsConfig.find(id)
		if not item or (item.category :: string) ~= slot then
			return { status = "unknown" }
		end
		-- A tyre is a drift mode of one drivetrain (DriftStyles): it goes
		-- only on a car that drives the same wheels.
		local layout = ConfigLoader.driftStyles().layoutOf(ConfigLoader.forCar(carId))
		if not CosmeticsConfig.fits(item, layout) then
			return { status = "unknown" }
		end
		if not Economy.owns(player, id) then
			return { status = "notowned" }
		end
	end
	if not ready[player] then
		return { status = "unavailable" }
	end
	if not Economy.setLook(player, carId, slot, id) then
		return { status = "unavailable" }
	end
	restamp(player, carId)
	return { status = "done" }
end

local function plate(player: Player, carId: any, key: any): Reply
	if not isCar(carId) then
		return { status = "unknown" }
	end
	if key ~= nil then
		if not isText(key) then
			return { status = "unknown" }
		end
		if not PlateService.owns(player, key) then
			return { status = "notowned" }
		end
	end
	if not ready[player] then
		return { status = "unavailable" }
	end
	if not Economy.setLook(player, carId, "plate", key) then
		return { status = "unavailable" }
	end
	restamp(player, carId)
	PlateService.refresh(player)
	return { status = "done" }
end

local function action(player: Player, what: any, a: any, b: any, c: any): Reply
	if not allowed(player) then
		return { status = "busy" }
	end
	if what ~= "buy" and what ~= "equip" and what ~= "plate" then
		return { status = "unknown" }
	end
	local reply: Reply = { status = "busy" }
	local ran, ok = exclusive(player, function()
		if what == "buy" then
			reply = buy(player, a)
		elseif what == "equip" then
			reply = equip(player, a, b, c)
		else
			reply = plate(player, a, b)
		end
	end)
	if ran and not ok then
		reply = { status = "unavailable" }
	end
	return reply
end

function CosmeticsService.start(remotes: Remotes.RemoteTable)
	-- Economy.onLoaded is a single slot and PlateService has already set it
	-- (init.server.luau starts PlateService first): chain after it rather
	-- than replace it. The previous handler runs on its own thread, since
	-- its join recovery yields and cosmetics need not wait for plates.
	local previous = Economy.onLoaded
	Economy.onLoaded = function(player: Player, canSave: boolean)
		if previous then
			task.spawn(previous, player, canSave)
		end
		ready[player] = canSave
		-- The car may have spawned before the stored looks arrived.
		restamp(player, nil)
	end

	remotes.CosmeticsAction.OnServerInvoke = function(player: Player, what: any, a: any, b: any, c: any): any
		local ok, reply = pcall(action, player, what, a, b, c)
		return if ok then reply else { status = "unavailable" }
	end

	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
		busy[player] = nil
		budget[player] = nil
	end)

	-- A new car takes its owner's look for that car. ChildAdded is connected
	-- before the existing children are stamped, for the reason given in
	-- PlateService.start (the first car can land in the same call that
	-- creates workspace.Cars).
	local function stamp(child: Instance)
		local uid = child:GetAttribute("OwnerUserId")
		local owner = if type(uid) == "number" then Players:GetPlayerByUserId(uid) else nil
		if owner and child:IsA("Model") then
			stampCar(owner, child)
		end
	end
	task.spawn(function()
		local cars = Workspace:WaitForChild("Cars", math.huge)
		cars.ChildAdded:Connect(stamp)
		for _, child in cars:GetChildren() do
			stamp(child)
		end
	end)
end

return CosmeticsService
