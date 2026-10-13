--!strict
-- What the menu (Menu) and its pages (Cars, Plates, Settings) share. The
-- menu owns the screen: the layout, the coins, the blur, taps, the confirm
-- sheet; a page says what its column, its subject and its action are, as
-- the garage panel does for its categories.
local Looks = script.Parent.Parent:WaitForChild("Garage"):WaitForChild("Looks")
local Types = require(Looks:WaitForChild("Types"))
local Parts = require(Looks:WaitForChild("Parts"))
local VehicleRig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("VehicleRig"))

export type Hooks = {
	cars: () -> { { id: string, entry: VehicleRig.CarEntry } },
	spawn: (id: string) -> boolean, -- false while a spawn cools down
	current: () -> string?, -- the car you are in
	busy: () -> boolean, -- a spawn is cooling down
	close: () -> (), -- EXIT: the spawn menu closes (and hands back the modal)
}

-- What a page gets from the menu.
export type Shell = {
	hooks: Hooks,
	touch: () -> boolean,
	-- Every state painted again (a choice, a reply, the cash).
	refresh: () -> (),
	-- The column built again (a sub-tab, a filter, a new list).
	fill: () -> (),
	toast: (text: string, kind: string) -> (),
	-- One of the garage's sounds (GarageSounds: tab, tap, fit, buy, error),
	-- so the menu sounds as the garage does.
	sound: (kind: string) -> (),
	-- The confirm sheet; `buy` runs on its BUY (it may yield) and the sheet
	-- closes after it.
	sheet: (info: Parts.SheetInfo, buy: () -> ()) -> (),
	-- A press and tap on `target`, tracked by the menu (a button in a
	-- phone's ScrollingFrame loses Activated and blocks the scroll), for
	-- things built in a form; registered again on every fill.
	tap: (target: GuiObject, scroll: ScrollingFrame?, onTap: () -> (), onDown: ((boolean) -> ())?) -> (),
	busy: () -> boolean, -- a sheet is open, or the menu is going out
	showing: () -> string?, -- the page up (its tab id), nil while closed
	-- The layout changed (Settings' SCREENS row): build the screen again.
	relayout: () -> (),
}

-- The subject drawn in the layout's stage, painted again on refresh.
export type Stage = { refresh: () -> (), destroy: () -> () }

export type Page = {
	tab: Types.TabDef,
	-- How the world behind reads: blurred (BlurEffect size) and dimmed
	-- (the dim's transparency). SETTINGS keeps it clear: the sky changes.
	blur: number,
	dim: number,
	views: () -> { Types.ViewDef },
	view: () -> string,
	setView: (id: string) -> (),
	note: () -> string?,
	entries: () -> { Types.Entry },
	stateOf: (e: Types.Entry) -> Types.EntryState,
	tap: (e: Types.Entry) -> (),
	foot: () -> Types.Foot,
	action: () -> (),
	-- The subject's name and its chip ("" for none).
	subject: () -> (string, string),
	-- The favourite star beside the subject: nil for none.
	starred: () -> boolean?,
	star: () -> (),
	-- A card's own star (the cars' wide cards): nil for none.
	starEntry: ((key: string) -> ())?,
	-- A search over the items: nil for none.
	search: { get: () -> string, set: (q: string) -> () }?,
	form: () -> Types.FormBuilder?,
	stage: (stage: Frame, touch: boolean) -> Stage,
	-- The page comes up (the menu opens on it, or its word is tapped).
	shown: () -> (),
	-- Painted again with everything else: what the form shows chosen.
	paint: () -> (),
}

return {}
