--!strict
-- UIKit: the single place UI code builds token-styled instances. Every
-- colour, font, size, radius, stroke and motion curve here comes from
-- UITheme (src/shared/UITheme.luau); UI_SYSTEM.md explains what each token
-- means and the rules for using it. Later screens (the garage panel, and a
-- re-skin of SpawnMenu/SettingsPanel) call only this API — no literal
-- Color3, font or size belongs in a caller.
--
-- touch: boolean picks touch sizes everywhere a size is chosen (through
-- UITheme.px/target). UIKit.isTouch() is the one place that reads the
-- player's own input state; everything else takes touch as a parameter so
-- it can be driven from a harness or a sample script without a LocalPlayer.
--
-- Notes on calls this brief left open:
-- * UIKit.corner/stroke/pad take no `touch` (the brief's own signatures).
--   Radius and stroke thickness have no touch variant in UI_SYSTEM.md, so
--   that is exact. Padding does scale with touch in the prose ("everything
--   scales by touchScale on touch, including spacing"), but pad()'s
--   signature has no way to know the screen — it always applies the
--   desktop space value. Components below that need touch-scaled interior
--   spacing (panel, button, badge) build their own UIPadding via the
--   private `scaledPad`, and do not call the public pad() for that.
-- * Shadow: a Frame sibling of the panel, one ZIndex behind, kept in sync
--   with the panel's Size/Position/AnchorPoint. Its corner radius is
--   radius.lg + shadow.spread (not just radius.lg) so the rounded corner
--   stays concentric with the panel once it is inflated by spread on every
--   side; UI_SYSTEM.md's "same radius (+spread)" note is read that way.
--   Cleans itself up on the panel's Destroying signal.
-- * Badge glyphs: "owned" text (eg. "✓ OWNED") is rendered exactly as the
--   caller passes it — UI_SYSTEM.md says that text is supplied by the
--   caller. "rare" gets its ◆ prepended here, since that mark is part of
--   the kind, not the caller's item name. "price" gets a small padlock
--   drawn from two Frames (a stroked ring for the shackle, a filled
--   rounded rectangle for the body) since UI_SYSTEM.md forbids emoji.
-- * Button/chip radius and role: UI_SYSTEM.md's radius table puts buttons
--   at radius.md and chips/badges at radius.sm (not `pill` — that is
--   reserved for toggles and the collapse handle) and puts both buttons
--   and chips under the `label` role. There is no named token for a
--   button's own interior horizontal padding, so `space.md` is used for
--   buttons and `space.sm` for chips (a call, not a token; easy to retune).
-- * Danger has no `dangerPressed` state in UITheme.button, so a pressed
--   danger button keeps the danger colours (no distinct pressed tween).
--
-- Fix round 1 (review): two Important findings, both addressed here.
-- * Wrapping: UIKit.text() takes an optional `wrap: boolean?` (default:
--   true for non-CAPS roles — body/heading/caption/price — false for CAPS
--   roles, which are short labels that should hug their content). When
--   wrap is true the label is AutomaticSize.Y, TextWrapped, and starts at
--   full parent width (`UDim2.new(1, 0, 0, 0)`) so a caller can narrow it;
--   when false it stays AutomaticSize.XY as before. Without this, a
--   TextLabel's glyphs are not clipped to its Size by Roblox, so long
--   card names/descriptions painted past their box into whatever sits
--   next to them. UIKit.title()'s English and Arabic labels are always
--   meant to read as one line each (UI_SYSTEM.md: "titles pair on one
--   line"), so both get TextWrapped + TextTruncate = AtEnd regardless of
--   mode: long text wraps within its bounded half/full width and then
--   ellipsises rather than pushing a second line into its sibling or
--   growing the row past the height `relayout` computed for it. Badge and
--   button/chip text call UIKit.text with `wrap = false` explicitly (they
--   must hug their content in a UIListLayout row; letting `price`'s
--   default-true wrap apply there would stretch them to fill their
--   parent's width instead).
-- * Layering: UIKit.panel(parent, touch, z) and UIKit.sheet(parent, touch,
--   z) take an optional base ZIndex so a confirm sheet can be told to sit
--   above an already-open panel. panel() defaults z = 2 (panel = z, its
--   shadow = z - 1) — unchanged from before when z is omitted. sheet()
--   defaults z = 1 (scrim = z, the sheet's own panel = z + 2, so its
--   shadow, set by panel(), lands at z + 1) — scrim(1) < shadow(2) <
--   sheet(3), same absolute numbers as before. A caller stacking a sheet
--   over a panel opened at panel z passes a sheet z greater than that
--   panel's z (eg. panel z=2, sheet z=10) to guarantee the sheet and its
--   scrim draw above it.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UITheme = require(Shared:WaitForChild("UITheme"))

export type ColorName =
	"asphalt950"
	| "asphalt900"
	| "asphalt800"
	| "asphalt700"
	| "asphalt600"
	| "asphalt500"
	| "paint"
	| "sand"
	| "sandDim"
	| "sodium"
	| "sodiumDeep"
	| "sodiumDim"
	| "lens"
	| "gantry"
	| "gantryBright"
	| "beacon"
	| "beaconDim"
	| "dusk"
	| "duskDim"

export type RadiusName = "sm" | "md" | "lg" | "pill"
export type SpaceName = "xxs" | "xs" | "sm" | "md" | "lg" | "xl" | "xxl" | "xxxl"
export type ButtonKind = "primary" | "secondary" | "danger"
export type BadgeKind = "owned" | "oncar" | "price" | "rare"

local UIKit = {}

-- The line width below which a title's Arabic line drops under the English
-- one instead of sitting at the right edge (a phone header). Not a design
-- token — a layout break point named by the brief.
local TITLE_STACK_WIDTH = 280

-- A tiny padlock's box, before touch scaling. Decorative only.
local PADLOCK_SIZE = 10

-- EDGE TO EDGE ----------------------------------------------------------------

-- A backdrop (a scrim, a fade, a shade) that reaches every edge of the
-- screen on every device. A ScreenGui's area stops short of a notch and a
-- home bar (and of Roblox's top bar without IgnoreGuiInset), and clips its
-- contents there by default; a backdrop sized to the gui, or bled past it
-- by a fixed number of pixels, leaves a strip of world showing on some
-- phone (the owner, 2026-10-08: "again with the boundries"; 2026-10-12: "i
-- want it fixed so that there is no wierd gap for any device"). This runs
-- `f` half a screen past each side of its parent, which must span the gui,
-- and lets the gui draw outside the safe area. Everything else in the gui
-- still lays out inside it (ScreenInsets).
function UIKit.edgeToEdge(f: GuiObject, gui: ScreenGui)
	f.AnchorPoint = Vector2.zero
	f.Position = UDim2.fromScale(-0.5, -0.5)
	f.Size = UDim2.fromScale(2, 2)
	gui.ClipToDeviceSafeArea = false
end

-- WHO IS PLAYING -------------------------------------------------------------

function UIKit.isTouch(): boolean
	return UserInputService.TouchEnabled or Players.LocalPlayer:GetAttribute("ForceTouch") == true
end

-- PRIMITIVES ------------------------------------------------------------------

function UIKit.corner(obj: GuiObject, radiusName: RadiusName): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, UITheme.radius[radiusName])
	c.Parent = obj
	return c
end

function UIKit.stroke(obj: GuiObject, colorName: ColorName, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = UITheme.color[colorName]
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = obj
	return s
end

-- Desktop-scale uniform padding (see the note at the top of the file for
-- why this does not take `touch`).
function UIKit.pad(obj: GuiObject, spaceName: SpaceName): UIPadding
	local amount = UDim.new(0, UITheme.space[spaceName])
	local p = Instance.new("UIPadding")
	p.PaddingTop = amount
	p.PaddingBottom = amount
	p.PaddingLeft = amount
	p.PaddingRight = amount
	p.Parent = obj
	return p
end

-- Internal: uniform padding scaled for the screen, for components that
-- know `touch` and need their interior spacing to grow with it.
local function scaledPad(obj: GuiObject, spaceName: SpaceName, touch: boolean): UIPadding
	local amount = UDim.new(0, UITheme.px(UITheme.space[spaceName], touch))
	local p = Instance.new("UIPadding")
	p.PaddingTop = amount
	p.PaddingBottom = amount
	p.PaddingLeft = amount
	p.PaddingRight = amount
	p.Parent = obj
	return p
end

-- TEXT -------------------------------------------------------------------------

-- A plain text label in a token role and colour. CAPS roles (see
-- UITheme.type) upper-case the text. `wrap` defaults to true for non-CAPS
-- roles (body/heading/caption/price — the running-text and descriptive
-- roles) and false for CAPS roles (short labels that should hug their
-- content): pass it explicitly to override. Wrapped labels are
-- AutomaticSize.Y, TextWrapped, starting at the parent's full width — set
-- Size.X afterward to narrow one. Unwrapped labels are AutomaticSize.XY, as
-- before.
function UIKit.text(parent: Instance, text: string, role: UITheme.Role, colorName: ColorName, touch: boolean, wrap: boolean?): TextLabel
	local spec = UITheme.type[role]
	local shouldWrap = if wrap == nil then not spec.caps else wrap
	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.BackgroundTransparency = 1
	l.TextWrapped = shouldWrap
	if shouldWrap then
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.Size = UDim2.new(1, 0, 0, 0)
	else
		l.AutomaticSize = Enum.AutomaticSize.XY
		l.Size = UDim2.fromOffset(0, 0)
	end
	l.FontFace = UITheme.font(role)
	l.TextSize = UITheme.textSize(role, touch)
	l.TextColor3 = UITheme.color[colorName]
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Text = if spec.caps then string.upper(text) else text
	l.Parent = parent
	return l
end

-- The bilingual title row: English left in `role`, Arabic at the right
-- edge in `sand` at arabicScale the size (same role, so Roblox's own
-- Arabic face renders at the requested weight). Below TITLE_STACK_WIDTH
-- the Arabic drops under the English, left-aligned, at body role x
-- arabicScale, because a title-sized Arabic line no longer fits a phone
-- header. Re-lays out live as the frame is resized.
function UIKit.title(parent: Instance, english: string, arabic: string, role: UITheme.Role, touch: boolean): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Title"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, UITheme.textSize(role, touch))
	frame.Parent = parent

	-- Both lines are meant to read as exactly one line each (UI_SYSTEM.md:
	-- "titles pair on one line"): wrapped + truncated rather than left to
	-- overflow into whichever sibling sits beside or below it.
	local en = UIKit.text(frame, english, role, "paint", touch, false)
	en.Name = "English"
	en.AutomaticSize = Enum.AutomaticSize.None
	en.TextXAlignment = Enum.TextXAlignment.Left
	en.TextWrapped = true
	en.TextTruncate = Enum.TextTruncate.AtEnd

	local ar = Instance.new("TextLabel")
	ar.Name = "Arabic"
	ar.BackgroundTransparency = 1
	ar.TextColor3 = UITheme.color.sand
	ar.TextYAlignment = Enum.TextYAlignment.Center
	ar.TextWrapped = true
	ar.TextTruncate = Enum.TextTruncate.AtEnd
	ar.Text = arabic
	ar.Parent = frame

	local gap = UITheme.px(UITheme.space.xxs, touch)

	local function relayout()
		local width = frame.AbsoluteSize.X
		local stacked = width > 0 and width < TITLE_STACK_WIDTH
		local englishHeight = UITheme.textSize(role, touch)
		if stacked then
			ar.FontFace = UITheme.font("body")
			ar.TextSize = math.floor(UITheme.textSize("body", touch) * UITheme.arabicScale + 0.5)
			ar.TextXAlignment = Enum.TextXAlignment.Left
			en.Size = UDim2.new(1, 0, 0, englishHeight)
			en.Position = UDim2.fromOffset(0, 0)
			ar.Size = UDim2.new(1, 0, 0, ar.TextSize)
			ar.Position = UDim2.fromOffset(0, englishHeight + gap)
			frame.Size = UDim2.new(1, 0, 0, englishHeight + gap + ar.TextSize)
		else
			ar.FontFace = UITheme.font(role)
			ar.TextSize = math.floor(UITheme.textSize(role, touch) * UITheme.arabicScale + 0.5)
			ar.TextXAlignment = Enum.TextXAlignment.Right
			local rowHeight = math.max(englishHeight, ar.TextSize)
			en.Size = UDim2.new(0.5, -gap, 0, rowHeight)
			en.Position = UDim2.fromOffset(0, 0)
			ar.Size = UDim2.new(0.5, -gap, 0, rowHeight)
			ar.Position = UDim2.new(0.5, gap, 0, 0)
			frame.Size = UDim2.new(1, 0, 0, rowHeight)
		end
	end

	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	relayout()
	return frame
end

-- PRESSABLE STATE --------------------------------------------------------------

type PressableState = {
	kind: ButtonKind,
	disabled: boolean,
	selected: boolean,
	stroke: UIStroke,
	apply: (pressed: boolean) -> (),
}

-- Keyed by instance, weak so a destroyed button's entry can be collected.
local pressables: { [TextButton]: PressableState } = setmetatable({}, { __mode = "k" }) :: any

local function pressedStateFor(kind: ButtonKind): UITheme.State
	if kind == "primary" then
		return UITheme.button.primaryPressed
	elseif kind == "secondary" then
		return UITheme.button.secondaryPressed
	end
	-- No dangerPressed token exists (see the file header note): a pressed
	-- danger button keeps the danger colours.
	return UITheme.button.danger
end

-- A TextButton wired to the token button states, radius and interior
-- padding, with the press tween and the UIStroke that secondary/selected
-- need. Shared by UIKit.button and UIKit.chip.
local function buildPressable(parent: Instance, label: string, kind: ButtonKind, touch: boolean, radiusName: RadiusName, paddingName: SpaceName): TextButton
	local labelRole: UITheme.Role = "label"
	local spec = UITheme.type[labelRole]
	local btn = Instance.new("TextButton")
	btn.Name = "Pressable"
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.AutomaticSize = Enum.AutomaticSize.X
	btn.Size = UDim2.new(0, 0, 0, UITheme.target(touch))
	btn.FontFace = UITheme.font("label")
	btn.TextSize = UITheme.textSize("label", touch)
	btn.Text = if spec.caps then string.upper(label) else label
	UIKit.corner(btn, radiusName)
	scaledPad(btn, paddingName, touch)
	local stroke = UIKit.stroke(btn, "asphalt600", UITheme.stroke.hairline)
	btn.Parent = parent

	local state: PressableState = {
		kind = kind,
		disabled = false,
		selected = false,
		stroke = stroke,
		apply = function() end,
	}

	local function apply(pressed: boolean)
		local visual: UITheme.State
		if state.disabled then
			visual = UITheme.button.disabled
		elseif state.selected then
			visual = UITheme.button.selected
		elseif pressed then
			visual = pressedStateFor(state.kind)
		else
			visual = UITheme.button[state.kind]
		end
		TweenService:Create(btn, UITheme.motion.quick, {
			BackgroundColor3 = visual.bg,
			TextColor3 = visual.text,
		}):Play()
		if visual.stroke then
			stroke.Color = visual.stroke
			stroke.Thickness = visual.strokeThickness or UITheme.stroke.hairline
			stroke.Transparency = 0
		else
			stroke.Transparency = 1
		end
		btn.Active = not state.disabled
		btn.Selectable = not state.disabled
	end
	state.apply = apply
	pressables[btn] = state

	btn.MouseButton1Down:Connect(function()
		apply(true)
	end)
	btn.MouseButton1Up:Connect(function()
		apply(false)
	end)
	btn.MouseLeave:Connect(function()
		apply(false)
	end)
	apply(false)
	return btn
end

-- Buttons: primary (sodium), secondary (asphalt800, hairline stroke) or
-- danger (beacon). radius.md, space.md interior padding, height floored at
-- UITheme.target(touch).
function UIKit.button(parent: Instance, label: string, kind: ButtonKind, touch: boolean): TextButton
	local btn = buildPressable(parent, label, kind, touch, "md", "md")
	btn.Name = "Button"
	return btn
end

-- A selectable pill: same pressable machinery as UIKit.button, styled as a
-- secondary control until UIKit.setSelected marks it (sodium stroke,
-- sodiumDim ground). radius.sm and space.sm per UI_SYSTEM.md's "chips,
-- badges" row. The chip does not flip its own selected state on a tap —
-- that is the caller's call (eg. one-of-many selection in a filter row).
function UIKit.chip(parent: Instance, label: string, touch: boolean): TextButton
	local btn = buildPressable(parent, label, "secondary", touch, "sm", "sm")
	btn.Name = "Chip"
	return btn
end

function UIKit.setDisabled(btn: TextButton, disabled: boolean)
	local state = pressables[btn]
	if not state then
		return
	end
	state.disabled = disabled
	state.apply(false)
end

function UIKit.setSelected(btn: TextButton, selected: boolean)
	local state = pressables[btn]
	if not state then
		return
	end
	state.selected = selected
	state.apply(false)
end

-- PANEL AND SHADOW --------------------------------------------------------------

-- asphalt900 at alpha.panel, radius.lg, space.lg interior padding, and a
-- shadow Frame kept as a lower-ZIndex sibling (assumes the ScreenGui uses
-- ZIndexBehavior.Sibling, as the rest of the UI does) rather than a wrapper
-- container, so UIKit.panel can return the single Frame the brief asks for.
-- `z` (default 2) is the panel's own ZIndex; its shadow sits at z - 1. Pass
-- a higher z to raise this panel above another one already on screen.
function UIKit.panel(parent: Instance, touch: boolean, z: number?): Frame
	local base = z or 2
	local shadow = Instance.new("Frame")
	shadow.Name = "PanelShadow"
	shadow.BackgroundColor3 = UITheme.color.asphalt950
	shadow.BackgroundTransparency = UITheme.shadow.transparency
	shadow.BorderSizePixel = 0
	local shadowCorner = Instance.new("UICorner")
	-- Same radius as the panel, plus spread, so the rounding stays
	-- concentric once the shadow is inflated on every side.
	shadowCorner.CornerRadius = UDim.new(0, UITheme.radius.lg + UITheme.px(UITheme.shadow.spread, touch))
	shadowCorner.Parent = shadow

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = UITheme.color.asphalt900
	panel.BackgroundTransparency = UITheme.alpha.panel
	panel.BorderSizePixel = 0
	panel.ZIndex = base
	UIKit.corner(panel, "lg")
	scaledPad(panel, "lg", touch)

	shadow.ZIndex = panel.ZIndex - 1

	local function syncShadow()
		local spread = UITheme.px(UITheme.shadow.spread, touch)
		local offsetY = UITheme.px(UITheme.shadow.offsetY, touch)
		shadow.AnchorPoint = panel.AnchorPoint
		shadow.Size = UDim2.new(panel.Size.X.Scale, panel.Size.X.Offset + spread * 2, panel.Size.Y.Scale, panel.Size.Y.Offset + spread * 2)
		shadow.Position = UDim2.new(panel.Position.X.Scale, panel.Position.X.Offset - spread, panel.Position.Y.Scale, panel.Position.Y.Offset - spread + offsetY)
	end
	panel:GetPropertyChangedSignal("Size"):Connect(syncShadow)
	panel:GetPropertyChangedSignal("Position"):Connect(syncShadow)
	panel:GetPropertyChangedSignal("AnchorPoint"):Connect(syncShadow)
	panel:GetPropertyChangedSignal("ZIndex"):Connect(function()
		shadow.ZIndex = panel.ZIndex - 1
	end)
	syncShadow()

	panel.Destroying:Connect(function()
		shadow:Destroy()
	end)

	shadow.Parent = parent
	panel.Parent = parent
	return panel
end

-- BADGES -------------------------------------------------------------------------

-- A tiny padlock drawn from two Frames (a stroked ring for the shackle, a
-- filled rounded rectangle for the body) since UI_SYSTEM.md forbids emoji.
local function buildPadlock(parent: Instance, colorName: ColorName, touch: boolean): Frame
	local size = UITheme.px(PADLOCK_SIZE, touch)
	local icon = Instance.new("Frame")
	icon.Name = "Padlock"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(size, size)

	local shackle = Instance.new("Frame")
	shackle.Name = "Shackle"
	shackle.BackgroundTransparency = 1
	shackle.AnchorPoint = Vector2.new(0.5, 0)
	shackle.Position = UDim2.new(0.5, 0, 0, 0)
	shackle.Size = UDim2.fromOffset(math.floor(size * 0.6 + 0.5), math.floor(size * 0.55 + 0.5))
	shackle.Parent = icon
	local shackleCorner = Instance.new("UICorner")
	shackleCorner.CornerRadius = UDim.new(1, 0)
	shackleCorner.Parent = shackle
	UIKit.stroke(shackle, colorName, 1)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundColor3 = UITheme.color[colorName]
	body.BorderSizePixel = 0
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.new(0.5, 0, 1, 0)
	body.Size = UDim2.fromOffset(size, math.floor(size * 0.55 + 0.5))
	UIKit.corner(body, "sm")
	body.Parent = icon

	icon.Parent = parent
	return icon
end

-- Shop-item badges (UI_SYSTEM.md "Shop items"): owned (gantry ground,
-- paint text — the caller's text already carries its own tick, eg.
-- "✓ OWNED"), oncar (sodium ground, asphalt900 text), price (sodiumDim
-- ground, sodium price-role text, with a drawn padlock) and rare (duskDim
-- ground, dusk text, a ◆ prepended here).
function UIKit.badge(parent: Instance, kind: BadgeKind, text: string, touch: boolean): Frame
	local bgName: ColorName, fgName: ColorName
	if kind == "owned" then
		bgName, fgName = "gantry", "paint"
	elseif kind == "oncar" then
		bgName, fgName = "sodium", "asphalt900"
	elseif kind == "price" then
		bgName, fgName = "sodiumDim", "sodium"
	else
		bgName, fgName = "duskDim", "dusk"
	end

	local frame = Instance.new("Frame")
	frame.Name = "Badge_" .. kind
	frame.BackgroundColor3 = UITheme.color[bgName]
	frame.BorderSizePixel = 0
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.Size = UDim2.fromOffset(0, 0)
	UIKit.corner(frame, "sm")
	scaledPad(frame, "xs", touch)

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.XY
	row.Size = UDim2.fromOffset(0, 0)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, UITheme.px(UITheme.space.xxs, touch))
	layout.Parent = row
	row.Parent = frame

	if kind == "price" then
		local lock = buildPadlock(row, fgName, touch)
		lock.LayoutOrder = 1
	end

	-- "Buttons, chips, badges" are the `label` role, except a price chip
	-- reads its amount in the `price` role (Oswald, digits, no CAPS).
	local role: UITheme.Role = if kind == "price" then "price" else "label"
	local spec = UITheme.type[role]
	local body = if spec.caps then string.upper(text) else text
	if kind == "rare" then
		body = "◆ " .. body
	end
	-- wrap = false: a badge hugs its own text in a UIListLayout row (the
	-- `price` role defaults to wrap = true, which would stretch it instead).
	local textLabel = UIKit.text(row, body, role, fgName, touch, false)
	textLabel.LayoutOrder = 2

	frame.Parent = parent
	return frame
end

-- SHEET -----------------------------------------------------------------------

-- A modal sheet: a scrim (asphalt950 at alpha.scrim) plus a panel-styled
-- Frame above it. Both are siblings of `parent`. `z` (default 1) is the
-- scrim's ZIndex; the sheet's own panel sits at z + 2, so its shadow
-- (drawn by UIKit.panel at panel z - 1) lands at z + 1 — scrim < shadow <
-- sheet. Pass a z above an already-open panel's own z (eg. that panel's
-- z=2, this sheet's z=10) to guarantee the confirm sheet and its scrim
-- draw above it. The caller wires dismiss-on-scrim-tap itself if it wants
-- one (the scrim is a plain Frame, per the brief's return type, not a
-- button).
function UIKit.sheet(parent: Instance, touch: boolean, z: number?): (Frame, Frame)
	local base = z or 1
	local scrim = Instance.new("Frame")
	scrim.Name = "Scrim"
	scrim.BackgroundColor3 = UITheme.color.asphalt950
	scrim.BackgroundTransparency = UITheme.alpha.scrim
	scrim.BorderSizePixel = 0
	scrim.ZIndex = base
	scrim.Parent = parent
	-- On a gui, the whole screen.
	if parent:IsA("ScreenGui") then
		UIKit.edgeToEdge(scrim, parent :: ScreenGui)
	else
		scrim.Size = UDim2.fromScale(1, 1)
	end

	local sheet = UIKit.panel(parent, touch, base + 2)
	sheet.Name = "Sheet"
	sheet.AnchorPoint = Vector2.new(0.5, 0.5)
	sheet.Position = UDim2.fromScale(0.5, 0.5)

	return sheet, scrim
end

return UIKit
