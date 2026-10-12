--!strict
-- What the garage panel (GaragePanel, the controller) and its layouts
-- (Dock, Showcase, Shade) share. The controller owns every choice and the
-- talk with the server; a layout draws them and hands taps back.

local Types = {}

-- A category: the rail's, the dock's or the word list's.
export type TabDef = { id: string, label: string, arabic: string, icon: number }
-- A sub-tab of the category showing (GarageConfig.views).
export type ViewDef = { id: string, label: string }

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
}

-- The word under an item's name (UI_SYSTEM.md "Shop items").
export type WordKind = "oncar" | "owned" | "price" | "note" | "none"
export type EntryState = {
	chosen: boolean, -- showing on the turntable car now
	disabled: boolean,
	word: string,
	kind: WordKind,
}

-- What the action button does now: BUY the preview, DRIVE THIS car, or
-- nothing (the item showing is already on the car).
export type Action = "buy" | "drive" | "oncar" | "none"
export type Foot = {
	name: string,
	rare: boolean,
	note: string,
	action: Action,
	price: number,
	entry: Entry?, -- the item it names, for its swatch
}

export type Actions = {
	tab: (id: string) -> (),
	view: (id: string) -> (),
	entry: (e: Entry) -> (),
	action: () -> (),
	extra: () -> (), -- REV or SHOP PLATES
	leave: () -> (),
	nextLayout: () -> (),
	collapse: () -> (),
}

export type Ctx = {
	touch: boolean,
	screen: Vector2,
	tabs: { TabDef },
	tab: () -> string,
	views: () -> { ViewDef },
	view: () -> string,
	extra: () -> string?, -- "rev", "shop" or nil
	note: () -> string?,
	entries: () -> { Entry },
	stateOf: (e: Entry) -> EntryState,
	foot: () -> Foot,
	carName: () -> string,
	carDrive: () -> string,
	act: Actions,
	-- An item's press and tap, tracked through UserInputService (a button in
	-- a phone's ScrollingFrame never sees Activated).
	tap: (gui: GuiObject, scroll: ScrollingFrame?, onTap: () -> (), onDown: ((boolean) -> ())?) -> (),
	-- A confirm sheet is open: buttons under it ignore taps.
	busy: () -> boolean,
}

export type View = {
	root: GuiObject, -- hidden while the panel is folded away
	fill: () -> (), -- the tab's sub-tabs, note and items, built again
	refresh: () -> (), -- every state painted again
	setCash: (text: string) -> (),
	pop: (key: string) -> (),
	destroy: () -> (),
}

-- Where the car sits beside it is GarageConfig.layoutOffset[id].
export type Layout = {
	id: string,
	name: string,
	build: (gui: ScreenGui, ctx: Ctx) -> View,
}

return Types
