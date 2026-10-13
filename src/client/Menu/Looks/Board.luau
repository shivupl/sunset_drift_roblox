--!strict
-- BOARD: the menu's SETTINGS as one panel (the canvas's "B. Settings"; the
-- owner, 2026-10-12: "implement this version that we had planned but remove
-- the buttons at the bottom"). A graphite panel the showroom's size, a
-- header with the page's words, a note and the close, and under it the
-- page's form filling the rest: Settings draws its three columns there
-- (the time of day as art tiles, the HUD's finishes as cards with a mock
-- readout, the camera and the HUD's version as slanted choices). The
-- bottom bar the canvas had (CARS, PLATES, SETTINGS, the note, the close)
-- went: the words are the showroom's switch and the top bar, so the note
-- and the close moved up into the header. No action: what is picked is in
-- force at once.
local Client = script.Parent.Parent.Parent
local Kit = require(Client:WaitForChild("CarPicker"):WaitForChild("Kit"))
local Looks = Client:WaitForChild("Garage"):WaitForChild("Looks")
local Types = require(Looks:WaitForChild("Types"))
local Parts = require(Looks:WaitForChild("Parts"))

local Board = {}

local function tabOf(ctx: Types.Ctx, id: string): Types.TabDef?
	for _, t in ctx.tabs do
		if t.id == id then
			return t
		end
	end
	return nil
end

function Board.build(gui: ScreenGui, ctx: Types.Ctx): Types.View
	local touch = ctx.touch
	local root, room = Parts.root(gui, ctx, "Board")
	local scale = Parts.scaleFor(touch, ctx.screen)
	-- The showroom's frame, so SETTINGS sits where CARS and PLATES do.
	local w = if touch then math.min(748, room.X - 16) else math.min(1060, room.X - 40)
	-- Under the phone's top row, which stays up (ctx.top).
	local y0 = (if touch then 8 else 12) + math.ceil(ctx.top or 0)
	local h = if touch then room.Y - y0 - 8 else math.min(604, room.Y - y0 - 12)
	local x0 = math.floor((room.X - w) / 2)
	local padX = if touch then 12 else 16
	local padY = if touch then 10 else 16

	local panel, body = Kit.panel(root, "Settings", if touch then 14 else 16)
	panel.Position = UDim2.fromOffset(x0, y0)
	panel.Size = UDim2.fromOffset(w, h)
	Kit.pad(body, padY, padX, padY, padX)
	Kit.list(body, true, if touch then 8 else 12)
	local inner = w - 2 * padX

	-- The header: the close (always, top left: the owner, 2026-10-13), the
	-- page's words, the note.
	local headH = if touch then 36 else 44
	local header = Kit.frame(body, "Header")
	header.LayoutOrder = 1
	header.Size = UDim2.new(1, 0, 0, headH)
	Kit.list(header, false, 8, Enum.VerticalAlignment.Center)
	local close = Kit.iconButton(header, "Close", nil, if touch then 32 else 36, "×")
	close.LayoutOrder = 0
	close.Activated:Connect(function()
		if not ctx.busy() then
			ctx.act.leave()
		end
	end)
	local def = tabOf(ctx, ctx.tab()) or { id = ctx.tab(), label = string.upper(ctx.tab()), arabic = "", icon = 0 }
	local heading = Parts.heading(header, def, if touch then 17 else 22)
	heading.LayoutOrder = 1
	local spacer = Kit.frame(header, "Spacer")
	spacer.LayoutOrder = 2
	spacer.Size = UDim2.fromOffset(0, 1)
	Kit.fill(spacer)
	-- What lasts: the time of day goes to the profile; the HUD's finish,
	-- its version and the camera are the session's.
	local note = Kit.text(header, "Note", "Time of day saves to your account", if touch then 11 else 13, Enum.FontWeight.SemiBold, false, Kit.C.sub)
	note.LayoutOrder = 3
	note.AutomaticSize = Enum.AutomaticSize.X
	note.Size = UDim2.fromScale(0, 1)
	note.TextTruncate = Enum.TextTruncate.None

	-- The stage: nothing is drawn in it (the world is the subject), but a
	-- controller expects one.
	local stage = Kit.frame(root, "Stage")
	stage.Size = UDim2.fromOffset(0, 0)
	stage.Visible = false

	local form: Types.Form? = nil

	local function fill()
		local f = form
		if f then
			f.root:Destroy()
		end
		form = nil
		local builder = if ctx.form then ctx.form() else nil
		if builder then
			local made = builder(body, inner, false, nil)
			made.root.LayoutOrder = 2
			if made.fills then
				Kit.fill(made.root)
			end
			form = made
		end
	end

	local function refresh() end

	local pieces: Parts.Pieces = {
		room = room,
		scale = scale,
		left = {},
		right = { panel },
		top = {},
		bottom = {},
		content = { panel },
	}
	return {
		root = root,
		stage = stage,
		fill = fill,
		refresh = refresh,
		pop = function(_key: string) end,
		destroy = function()
			root:Destroy()
		end,
		intro = function(switch_: boolean)
			Parts.intro(pieces, switch_)
		end,
		outro = function(): number
			return Parts.outro(pieces)
		end,
	}
end

return Board
