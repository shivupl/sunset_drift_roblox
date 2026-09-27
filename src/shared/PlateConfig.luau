--!strict
-- Number plates: prices, timings and limits
-- (docs/superpowers/specs/2026-09-26-number-plates-design.md). TUNING.md,
-- "PlateConfig", says which way to move each.
local PlateConfig = {
	-- Price by how many digits the number has. First guesses (spec §5,
	-- 2026-09-26), for the owner to set against how fast cash is earned.
	prices = { [1] = 500_000, [2] = 200_000, [3] = 75_000, [4] = 20_000 } :: { [number]: number },
	-- Three identical letters (AAA) or all digits identical (77, 7777) cost this many times the price.
	repeatMultiplier = 2,
	-- Seconds a purchase holds a plate while the cash is taken; after this
	-- anyone may claim it (spec §4). Long enough for a slow profile write.
	pendingSeconds = 120,
	-- A server remembers whether a plate is free for this long, so typing
	-- in the search box does not read the store on every key (spec §4).
	availabilityCacheSeconds = 30,
	-- Lines of ownership history kept on a plate key.
	historyLength = 5,
	-- Longest plate text a player may send, in bytes (Arabic is 2 per letter).
	maxInputBytes = 64,
	-- Remote calls a player may make per second; more get "busy".
	queriesPerSecond = 4,
	actionsPerSecond = 1,
	-- Tries at a default plate nobody owns before keeping the last one
	-- (a default is never registered, so a clash is only cosmetic).
	defaultPicks = 3,
	-- How often an unfinished plate transaction is retried (seconds).
	retrySeconds = 30,
	-- Cash a new profile starts with in Studio's fake store, so buying can
	-- be tried there. Never used on a live server.
	studioCash = 2_000_000,
	-- The plate sits this far out from its spot, so it never fights the
	-- body's recess for the same pixels (metres, before the car's scale).
	standoffM = 0.006,
	-- Plate part thickness (metres, before the car's scale).
	thicknessM = 0.01,
	-- Plates further than this from the camera are not drawn (studs).
	drawDistanceStuds = 150,
}

return PlateConfig
