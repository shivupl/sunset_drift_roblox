--!strict
-- The desktop's key guide (desktop-ui, 2026-10-14; the owner: "put a small
-- guide on which keys are for what"): the driving keys as keycaps with a
-- word each, bottom left, in the form the desk layout asks for
-- (Desk.guide). A keycap lights sodium while its key is held, so the
-- guide also shows what the car is being told. The keys that sit on the
-- top row's tabs (M, F, V, U) are not repeated here.
--
--   line    one row on a soft dark blot (DASH)
--   stack   two columns on the blot (STRIP)
--   glass   one row on a slanted glass strip, the tabs' own shape (CLUSTER)
--
-- Pixel sizes, a desktop's (the canvas's "The pieces" board): the keycap
-- 22 tall with a 2 px lip, its letter 11, the word 12; 4 between keycaps,
-- 6 before the word, 22 between pairs. The keycap is also the top row's
-- (TopBar draws a tab's key with KeyGuide.cap), so one keycap means one
-- thing everywhere.
local UserInputService = game:GetService("UserInputService")

local Client = script.Parent.Parent
local Kit = require(Client:WaitForChild("CarPicker"):WaitForChild("Kit"))
local PickerArt = require(Client:WaitForChild("CarPicker"):WaitForChild("Art"))

local KeyGuide = {}

-- The keycap.
local CAP_H = 22
local CAP_PAD = 5
local CAP_FONT = 11
local CAP_RADIUS = 4
local LIP = 2
local CAP_BG = Color3.fromHex("#0C0D0F")
local CAP_EDGE = Color3.fromHex("#3D3832")
local CAP_INK = Color3.fromHex("#E8E2CD")
local CAP_LIP = Color3.fromHex("#000000")
-- Lit while held: sodium, the edge the lamp's lens, the ink dark.
local LIT_BG = Color3.fromHex("#FFBA5C")
local LIT_EDGE = Color3.fromHex("#FFD592")
local LIT_INK = Color3.fromHex("#2B1903")
local LIT_LIP = Color3.fromHex("#E08A2E")
-- The word after the keys.
local WORD_FONT = 12
local WORD_INK = Color3.fromHex("#C6AC84")
local KEY_GAP = 4
local WORD_GAP = 6
-- Between pairs on a line; the stack's rows and columns.
local PAIR_GAP = 22
local ROW_GAP = 8
local COL_GAP = 28
-- The blot: asphalt950, 0.55 see-through, 10 round, 10/16 padding.
local BLOT = Color3.fromRGB(12, 12, 13)
local BLOT_ALPHA = 0.55
local BLOT_RADIUS = 10
local BLOT_PAD_Y, BLOT_PAD_X = 10, 16
-- The glass strip: the tabs' slanted shape, 48 tall, 22 of padding at
-- each end, 24 between pairs; dark glass with a faint rim.
local GLASS_H = 48
local GLASS_PAD = 22
local GLASS_GAP = 24
local GLASS_ALPHA = 0.5
local RIM_ALPHA = 0.88
-- In from the screen's bottom left corner.
local EDGE_X, EDGE_Y = 24, 28
local GLASS_EDGE_X = 40

type Pair = { keys: { Enum.KeyCode }, caps: { string }, word: string, long: string? }
local PAIRS: { Pair } = {
	{ keys = { Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D }, caps = { "W", "A", "S", "D" }, word = "DRIVE" },
	{ keys = { Enum.KeyCode.Space }, caps = { "SPACE" }, word = "HAND", long = "HANDBRAKE" },
	{ keys = { Enum.KeyCode.Q, Enum.KeyCode.E }, caps = { "Q", "E" }, word = "NATL" },
	{ keys = { Enum.KeyCode.R }, caps = { "R" }, word = "RESET" },
	{ keys = { Enum.KeyCode.H }, caps = { "H" }, word = "HORN" },
	{ keys = { Enum.KeyCode.G }, caps = { "G" }, word = "LIGHTS" },
}

export type Cap = { root: Frame, setLit: (on: boolean) -> () }

-- A keycap with `letter` on it, `h` tall (the guide's 22; a tab's is
-- sized to the tab), as wide as the letter needs and never narrower than
-- it is tall.
function KeyGuide.cap(parent: Instance, letter: string, h: number?): Cap
	local size = h or CAP_H
	local font = math.max(8, math.floor(size * CAP_FONT / CAP_H + 0.5))
	local pad = math.floor(size * CAP_PAD / CAP_H + 0.5)
	local lip = math.max(1, math.floor(size * LIP / CAP_H + 0.5))
	local root = Kit.frame(parent, "Key_" .. letter, CAP_BG, 0)
	root.AutomaticSize = Enum.AutomaticSize.X
	root.Size = UDim2.fromOffset(0, size)
	Kit.corner(root, CAP_RADIUS)
	local edge = Kit.stroke(root, CAP_EDGE, 1, 0)
	local min = Instance.new("UISizeConstraint")
	min.MinSize = Vector2.new(size, size)
	min.Parent = root
	local lipF = Kit.frame(root, "Lip", CAP_LIP, 0.35)
	lipF.AnchorPoint = Vector2.new(0, 1)
	lipF.Position = UDim2.fromScale(0, 1)
	lipF.Size = UDim2.new(1, 0, 0, lip + CAP_RADIUS)
	Kit.corner(lipF, CAP_RADIUS)
	local cover = Kit.frame(root, "Face", CAP_BG, 0)
	cover.Size = UDim2.new(1, 0, 1, -lip)
	Kit.corner(cover, CAP_RADIUS)
	local t = Kit.text(cover, "Letter", letter, font, Enum.FontWeight.ExtraBold, false, CAP_INK)
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.new(0, 0, 1, 0)
	t.TextTruncate = Enum.TextTruncate.None
	t.TextXAlignment = Enum.TextXAlignment.Center
	t.ZIndex = 2
	Kit.pad(t, 0, pad, 0, pad)
	local lit = false
	return {
		root = root,
		setLit = function(on: boolean)
			if on == lit then
				return
			end
			lit = on
			root.BackgroundColor3 = if on then LIT_BG else CAP_BG
			cover.BackgroundColor3 = if on then LIT_BG else CAP_BG
			lipF.BackgroundColor3 = if on then LIT_LIP else CAP_LIP
			lipF.BackgroundTransparency = if on then 0 else 0.35
			edge.Color = if on then LIT_EDGE else CAP_EDGE
			t.TextColor3 = if on then LIT_INK else CAP_INK
		end,
	}
end

export type Guide = {
	root: Frame,
	update: (dt: number) -> (),
	destroy: () -> (),
}

type Lit = { keys: { Enum.KeyCode }, caps: { Cap } }

-- One pair: its keycaps in a row and the word after them.
local function pair(parent: Instance, p: Pair, order: number, long: boolean, out: { Lit })
	local row = Kit.frame(parent, "Pair_" .. p.word)
	row.LayoutOrder = order
	row.AutomaticSize = Enum.AutomaticSize.XY
	Kit.list(row, false, KEY_GAP, Enum.VerticalAlignment.Center)
	local caps: { Cap } = {}
	for i, letter in p.caps do
		local c = KeyGuide.cap(row, letter)
		c.root.LayoutOrder = i
		table.insert(caps, c)
	end
	local w = Kit.text(row, "Word", if long then p.long or p.word else p.word, WORD_FONT, Enum.FontWeight.SemiBold, false, WORD_INK)
	w.LayoutOrder = 10
	w.AutomaticSize = Enum.AutomaticSize.X
	w.Size = UDim2.fromOffset(0, CAP_H)
	w.TextTruncate = Enum.TextTruncate.None
	Kit.pad(w, 0, 0, 0, WORD_GAP)
	table.insert(out, { keys = p.keys, caps = caps })
end

-- The guide in `form` ("line", "stack" or "glass"), in the HUD's root
-- (the screen), bottom left.
function KeyGuide.build(parent: Instance, form: string): Guide
	local lit: { Lit } = {}
	local root = Kit.frame(parent, "KeyGuide")
	root.AnchorPoint = Vector2.new(0, 1)
	root.AutomaticSize = Enum.AutomaticSize.XY
	root.ZIndex = 3
	if form == "glass" then
		root.Position = UDim2.new(0, GLASS_EDGE_X, 1, -EDGE_Y)
		root.Size = UDim2.fromOffset(0, GLASS_H)
		local function slice(o: ImageLabel)
			o.Image = PickerArt.tab
			o.ScaleType = Enum.ScaleType.Slice
			o.SliceCenter = PickerArt.tabSlice
			o.SliceScale = GLASS_H / PickerArt.tabH
		end
		local rim = Kit.image(root, "Rim", PickerArt.tab, Color3.new(1, 1, 1), RIM_ALPHA)
		slice(rim)
		rim.Size = UDim2.fromScale(1, 1)
		local fill = Kit.image(root, "Fill", PickerArt.tab, Kit.C.chip, GLASS_ALPHA)
		slice(fill)
		fill.Position = UDim2.fromOffset(1, 1)
		fill.Size = UDim2.new(1, -2, 1, -2)
		local inner = Kit.frame(root, "Inner")
		inner.AutomaticSize = Enum.AutomaticSize.X
		inner.Size = UDim2.fromOffset(0, GLASS_H)
		inner.ZIndex = 2
		Kit.pad(inner, 0, GLASS_PAD, 0, GLASS_PAD)
		Kit.list(inner, false, GLASS_GAP, Enum.VerticalAlignment.Center)
		for i, p in PAIRS do
			pair(inner, p, i, false, lit)
		end
	else
		root.Position = UDim2.new(0, EDGE_X, 1, -EDGE_Y)
		root.BackgroundColor3 = BLOT
		root.BackgroundTransparency = BLOT_ALPHA
		Kit.corner(root, BLOT_RADIUS)
		Kit.pad(root, BLOT_PAD_Y, BLOT_PAD_X, BLOT_PAD_Y, BLOT_PAD_X)
		if form == "stack" then
			Kit.list(root, false, COL_GAP, Enum.VerticalAlignment.Top)
			local cols = { Kit.frame(root, "Left"), Kit.frame(root, "Right") }
			for i, c in cols do
				c.LayoutOrder = i
				c.AutomaticSize = Enum.AutomaticSize.XY
				Kit.list(c, true, ROW_GAP)
			end
			-- Down the left, then down the right.
			local half = math.ceil(#PAIRS / 2)
			for i, p in PAIRS do
				pair(cols[if i <= half then 1 else 2], p, i, true, lit)
			end
		else
			Kit.list(root, false, PAIR_GAP, Enum.VerticalAlignment.Center)
			for i, p in PAIRS do
				pair(root, p, i, false, lit)
			end
		end
	end
	-- Every zindex above the HUD's glow and shade.
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = math.max(d.ZIndex, 3)
		end
	end
	return {
		root = root,
		update = function(_dt: number)
			for _, l in lit do
				for i, key in l.keys do
					local c = l.caps[if #l.caps == 1 then 1 else i]
					if c then
						c.setLit(UserInputService:IsKeyDown(key))
					end
				end
			end
		end,
		destroy = function()
			root:Destroy()
		end,
	}
end

return KeyGuide
