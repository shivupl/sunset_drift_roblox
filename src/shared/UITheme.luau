--!strict
-- The game's design tokens. Every interface reads its colours, type, spacing,
-- radii, strokes and states from here; UI_SYSTEM.md explains each value and
-- the rules for using them. Asked by the owner on 2026-09-28 ("my UI looks
-- generic because nothing defines what it should look like").
--
-- The palette is taken from the world, with the source value noted beside
-- each one: worn asphalt for surfaces, lane paint for text, sand for
-- secondary text, the sodium lamp for the one accent, the gantry sign green
-- for "yours", the aircraft beacon for danger, the skyline's dusk glow for
-- rare items.
--
-- Sizes are pixels at desktop scale. On a touch screen every size goes
-- through UITheme.px(size, true), which scales it by touchScale and floors
-- tap targets at minTouchTarget.

export type Role = "hero" | "display" | "title" | "heading" | "body" | "label" | "caption" | "price"

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

local UITheme = {}

-- COLOUR -------------------------------------------------------------------
UITheme.color = {
	-- Surfaces: worn asphalt at night, warm rather than neutral. The world's
	-- rendered asphalt (88, 88, 92) and the skyline bodies (62, 56, 54),
	-- taken darker and nudged toward the sand so black never reads blue.
	asphalt950 = hex("#0D0C0B"), -- scrim behind modals
	asphalt900 = hex("#15130F"), -- panels
	asphalt800 = hex("#1F1C18"), -- cards, inputs
	asphalt700 = hex("#2B2722"), -- cards pressed / hovered
	asphalt600 = hex("#3D3832"), -- strokes, dividers
	asphalt500 = hex("#5E5750"), -- disabled text, idle icons

	-- Text: lane paint (232, 226, 205) and sand (198, 172, 132).
	paint = hex("#E8E2CD"), -- primary text
	sand = hex("#C6AC84"), -- secondary text, Arabic under English
	sandDim = hex("#9C8768"), -- tertiary text, hints

	-- The one accent: the sodium lamp (255, 186, 92). Buttons you press,
	-- the selected thing, prices. Never decorative.
	sodium = hex("#FFBA5C"),
	sodiumDeep = hex("#E08A2E"), -- pressed
	sodiumDim = hex("#4A3418"), -- selected background, price chip ground
	lens = hex("#FFECC8"), -- focus ring, the brightest highlight (lit lens 255, 236, 200)

	-- Yours: the highway gantry sign green (16, 92, 52), lifted for text.
	gantry = hex("#105C34"), -- owned badge ground
	gantryBright = hex("#5CCB8A"), -- owned text and ticks

	-- Danger: the aircraft warning beacon (255, 70, 60), softened.
	beacon = hex("#F0533F"),
	beaconDim = hex("#4A1A14"),

	-- Rare: the skyline aura's dusk violet (140, 76, 150). Only a rarity
	-- mark on premium items; never a button.
	dusk = hex("#B784C9"),
	duskDim = hex("#352040"),
}

-- Transparency (0 opaque .. 1 clear) for layered surfaces.
UITheme.alpha = {
	panel = 0.06, -- a panel lets a hint of the world through
	scrim = 0.45, -- the dim behind a modal
	disabled = 0.5, -- whole-element fade for a disabled control
	-- The HUD card and the CARS button float over the road while you drive,
	-- so they let far more of it through than a menu panel does. 0.35 is
	-- what both used before the tokens existed (2026-09-28).
	hud = 0.35,
}

-- TYPE ---------------------------------------------------------------------
-- Display is Oswald: condensed caps like the plates and road signs. Body is
-- Builder Sans, Roblox's own UI face, clear at 12 px on a phone. Arabic has
-- no family of its own: Roblox falls back to its Arabic face for Arabic
-- glyphs in any family, at the requested weight.
UITheme.family = {
	display = "rbxasset://fonts/families/Oswald.json",
	body = "rbxasset://fonts/families/BuilderSans.json",
}

export type TypeSpec = { family: string, weight: Enum.FontWeight, size: number, caps: boolean }

UITheme.type = {
	hero = { family = UITheme.family.display, weight = Enum.FontWeight.Bold, size = 40, caps = true },
	display = { family = UITheme.family.display, weight = Enum.FontWeight.Bold, size = 28, caps = true },
	title = { family = UITheme.family.display, weight = Enum.FontWeight.SemiBold, size = 20, caps = true },
	heading = { family = UITheme.family.body, weight = Enum.FontWeight.Bold, size = 16, caps = false },
	body = { family = UITheme.family.body, weight = Enum.FontWeight.Medium, size = 14, caps = false },
	label = { family = UITheme.family.body, weight = Enum.FontWeight.Bold, size = 12, caps = true },
	caption = { family = UITheme.family.body, weight = Enum.FontWeight.Regular, size = 12, caps = false },
	price = { family = UITheme.family.display, weight = Enum.FontWeight.SemiBold, size = 16, caps = false },
} :: { [Role]: TypeSpec }

-- Arabic set beside or under English runs this much larger, because Arabic
-- glyphs sit smaller than Latin caps at the same size.
UITheme.arabicScale = 1.15

-- SPACE --------------------------------------------------------------------
UITheme.space = { xxs = 2, xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32, xxxl = 48 }

UITheme.radius = { sm = 6, md = 10, lg = 14, pill = 999 }

UITheme.stroke = {
	hairline = 1, -- cards, inputs: asphalt600
	selected = 2, -- the selected option: sodium
	focus = 2, -- keyboard / gamepad focus: lens
}

-- Roblox has no box shadow. A shadow is a Frame one radius larger, offset
-- down by shadow.offsetY, asphalt950 at shadow.transparency, behind the
-- panel (UIKit builds it).
UITheme.shadow = { offsetY = 4, spread = 2, transparency = 0.55 }

-- Tap targets and phone scaling.
UITheme.minTarget = 36 -- desktop
UITheme.minTouchTarget = 48 -- thumb
UITheme.touchScale = 1.25

-- The side panel (UI_SYSTEM.md "Targets and layout"; the garage panel,
-- 2026-09-28): 360 px wide on desktop; on touch 42% of the screen width, at
-- most 420 px, so the car always shows. A card grid inside it drops to one
-- column when the panel is narrower than oneColumnBelow.
UITheme.sidePanel = { width = 360, touchFraction = 0.42, touchMax = 420, oneColumnBelow = 340 }

-- Motion.
UITheme.motion = {
	quick = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), -- press, hover, select
	panel = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), -- slide in and out
	camera = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), -- camera moves
}

-- STATES -------------------------------------------------------------------
export type State = { bg: Color3, text: Color3, stroke: Color3?, strokeThickness: number? }

UITheme.button = {
	primary = { bg = UITheme.color.sodium, text = UITheme.color.asphalt900 },
	primaryPressed = { bg = UITheme.color.sodiumDeep, text = UITheme.color.asphalt900 },
	secondary = { bg = UITheme.color.asphalt800, text = UITheme.color.paint, stroke = UITheme.color.asphalt600, strokeThickness = 1 },
	secondaryPressed = { bg = UITheme.color.asphalt700, text = UITheme.color.paint, stroke = UITheme.color.asphalt600, strokeThickness = 1 },
	selected = { bg = UITheme.color.sodiumDim, text = UITheme.color.paint, stroke = UITheme.color.sodium, strokeThickness = 2 },
	danger = { bg = UITheme.color.beacon, text = UITheme.color.asphalt900 },
	disabled = { bg = UITheme.color.asphalt700, text = UITheme.color.asphalt500 },
} :: { [string]: State }

-- HELPERS ------------------------------------------------------------------
-- A size at this screen: scaled up on touch.
function UITheme.px(size: number, touch: boolean): number
	return if touch then math.floor(size * UITheme.touchScale + 0.5) else size
end

-- The smallest a tappable thing may be on this screen.
function UITheme.target(touch: boolean): number
	return if touch then UITheme.minTouchTarget else UITheme.minTarget
end

function UITheme.font(role: Role): Font
	local t = UITheme.type[role]
	return Font.new(t.family, t.weight)
end

function UITheme.textSize(role: Role, touch: boolean): number
	return UITheme.px(UITheme.type[role].size, touch)
end

-- WCAG relative luminance and contrast ratio, used by the spec to hold
-- every text-on-surface pair to 4.5:1 (3:1 for large display text).
local function channel(c: number): number
	return if c <= 0.03928 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
end

function UITheme.luminance(c: Color3): number
	return 0.2126 * channel(c.R) + 0.7152 * channel(c.G) + 0.0722 * channel(c.B)
end

function UITheme.contrast(a: Color3, b: Color3): number
	local la, lb = UITheme.luminance(a), UITheme.luminance(b)
	local hi, lo = math.max(la, lb), math.min(la, lb)
	return (hi + 0.05) / (lo + 0.05)
end

return UITheme
