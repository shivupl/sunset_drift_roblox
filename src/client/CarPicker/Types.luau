--!strict
-- What the car picker hands each layout (Compact, Showroom, Strip).
local Kit = require(script.Parent:WaitForChild("Kit"))

export type State = {
	layout: string,
	filter: string, -- "all", "rwd", "fwd", "awd" or "fav"
	selected: string, -- the picked car's id
	favs: { [string]: boolean },
	query: string,
	current: string?, -- the car you are in
	busy: boolean, -- a spawn is cooling down
}

export type Actions = {
	pick: (id: string) -> (),
	fav: (id: string) -> (),
	filter: (id: string) -> (),
	query: (text: string) -> (),
	spawn: () -> (),
	close: () -> (),
	plates: () -> (),
	settings: () -> (),
	nextLayout: () -> (),
}

export type Ctx = {
	touch: boolean,
	screen: Vector2, -- the room the picker has, in pixels
	cars: { Kit.Car },
	state: State,
	act: Actions,
	taps: Kit.Taps,
}

export type View = {
	refresh: () -> (),
	destroy: () -> (),
}

export type Layout = {
	id: string,
	name: string,
	build: (gui: ScreenGui, ctx: Ctx) -> View,
}

return {}
