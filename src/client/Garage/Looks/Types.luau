--!strict
-- What a screen's controller and its layouts (Dock, Showcase, Shade)
-- share. Two controllers draw through them: the garage panel (GaragePanel)
-- and the menu (Menu: CARS, PLATES, SETTINGS), so every phone screen is the
-- same frame (ui-flow, 2026-10-12: "string together the entire UI ... stop
-- it from being so choppy and disconnected"). The controller owns every
-- choice and the talk with the server; a layout draws them and hands taps
-- back.

local Types = {}

-- A category: the rail's, the dock's or the word list's. Its icon is a cell
-- of the garage's sheet (Parts.ICONS), or of `sheet` when given (the top
-- bar's, for SETTINGS).
export type TabDef = { id: string, label: string, arabic: string, icon: number, sheet: string? }
-- A sub-tab of the category showing (GarageConfig.views); `star` draws
-- the favourites' star in place of a word (the menu's cars).
export type ViewDef = { id: string, label: string, star: boolean? }

-- How an item is drawn: a palette swatch (a colour), a list row, a row with
-- a banner (sun strips, plates), a car with its photo.
export type Shape = "swatch" | "row" | "wide" | "car"

export type Entry = {
	key: string, -- item id, car id, or plate key ("" = the account's plate)
	slot: string?, -- nil for a car
	name: string,
	price: number,
	rare: boolean,
	shape: Shape,
	draw: (tile: Frame) -> (), -- paints the swatch
	fades: boolean, -- the swatch fades when the car can't show it
	-- A car's photo and its drive word, for the picker's wide card
	-- (Parts.cards; the menu's CARS looks, 2026-10-12).
	image: string?,
	chip: string?,
}

-- The word under an item's name (UI_SYSTEM.md "Shop items").
export type WordKind = "oncar" | "owned" | "price" | "note" | "none"
export type EntryState = {
	chosen: boolean, -- showing on the turntable car now
	disabled: boolean,
	word: string,
	kind: WordKind,
	starred: boolean?, -- its own star lit (a car card's)
}

-- What the action button does now: BUY the preview, DRIVE THIS car (or
-- the green action `label` names: SPAWN THIS CAR), wait (`label`, faded),
-- or nothing (the item showing is already on the car).
export type Action = "buy" | "drive" | "wait" | "oncar" | "none"
export type Foot = {
	name: string,
	rare: boolean,
	note: string,
	action: Action,
	price: number,
	entry: Entry?, -- the item it names, for its swatch
	label: string?, -- the green action's words, when not DRIVE THIS
}

-- What a screen shows above its items instead of (or before) them: the
-- plate search, the settings' rows. Built again on every fill, as wide as
-- the column; `fills` takes the column's height and hides the items.
export type Form = { root: GuiObject, fills: boolean }
-- `shade`: the column has no panel under it (FRAME), for the form's fades;
-- `scroller`: the layout's up/down control (Parts.scroller), in their place.
export type FormBuilder = (parent: Frame, width: number, shade: boolean, scroller: string?) -> Form

export type Actions = {
	tab: (id: string) -> (),
	view: (id: string) -> (),
	entry: (e: Entry) -> (),
	action: () -> (),
	extra: () -> (), -- REV or SHOP PLATES
	leave: () -> (),
	nextLayout: () -> (),
	collapse: () -> (),
	star: (() -> ())?, -- the favourite star tapped
	starEntry: ((e: Entry) -> ())?, -- a card's own star tapped
	customize: (() -> ())?, -- CUSTOMIZE on the picked car (the menu)
}

export type Ctx = {
	touch: boolean,
	screen: Vector2,
	-- The place, small over the subject: GARAGE, HAJWALA.
	title: { en: string, ar: string },
	tabs: { TabDef },
	tab: () -> string,
	views: () -> { ViewDef },
	view: () -> string,
	extra: () -> string?, -- "rev", "shop" or nil
	note: () -> string?,
	entries: () -> { Entry },
	stateOf: (e: Entry) -> EntryState,
	foot: () -> Foot,
	-- The subject, big under the title: the car's name and its drive chip
	-- ("" for none), a plate, nothing.
	carName: () -> string,
	carDrive: () -> string,
	-- A favourite star beside the subject (the menu's cars); nil: none.
	starred: (() -> boolean?)?,
	-- The form for the tab showing (Form), or nil.
	form: (() -> FormBuilder?)?,
	-- A search over the items (the menu's cars), for a layout with a box.
	search: { get: () -> string, set: (q: string) -> (), has: () -> boolean }?,
	act: Actions,
	-- An item's press and tap, tracked through UserInputService (a button in
	-- a phone's ScrollingFrame never sees Activated).
	tap: (gui: GuiObject, scroll: ScrollingFrame?, onTap: () -> (), onDown: ((boolean) -> ())?) -> (),
	-- A confirm sheet is open: buttons under it ignore taps.
	busy: () -> boolean,
	-- The cash pill's right edge and foot, in the panel gui's pixels
	-- (Parts.coinAnchor), for a right side to line up under it; nil: none.
	coins: Vector2?,
	-- The phone's top row stays up over the menu with its panels hanging
	-- under it (2026-10-13): the drawing pixels to leave clear at the top
	-- for it (mostly 0: it ends above the gui); nil: no row (the garage, a
	-- desktop).
	top: number?,
}

export type View = {
	root: GuiObject, -- hidden while the panel is folded away
	fill: () -> (), -- the tab's sub-tabs, note and items, built again
	refresh: () -> (), -- every state painted again
	pop: (key: string) -> (),
	destroy: () -> (),
	-- The room the layout leaves for the subject (between the words and the
	-- items, under the title), for a controller that draws one (the menu's
	-- car photo, its plate); the garage's car is the 3D one behind.
	stage: Frame,
	-- Its pieces slide in from the edges they live on (Parts.motion);
	-- `switch` when coming from a screen in the same frame (the garage's
	-- SHOP PLATES to the menu): only the content settles. outro slides them
	-- back out and returns how long that takes.
	intro: (switch: boolean) -> (),
	outro: () -> number,
}

-- Where the car sits beside it is GarageConfig.layoutOffset[id].
export type Layout = {
	id: string,
	name: string,
	build: (gui: ScreenGui, ctx: Ctx) -> View,
}

return Types
