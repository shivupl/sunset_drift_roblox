# UI system

Every interface in the game takes its values from `src/shared/UITheme.luau`.
This file says what each token is for and the rules for using them. Nothing
in a UI file is a literal colour, font or size; if a screen needs a value
that is not here, add a token here first.

Asked by the owner on 2026-09-28: the menus looked generic because nothing
defined them. The look comes from the world we built: the UI is **the
highway at golden hour, seen from a dark cabin**. Dark warm asphalt
surfaces, lane-paint text, sand for secondary text, and one accent: the
sodium lamp. Colour means something; it is never decoration.

`UITheme.spec.luau` holds every allowed text-on-surface pair to WCAG AA
(4.5:1).

## Colour

| Token | Hex | From the world | Use |
|---|---|---|---|
| `asphalt950` | `#0D0C0B` | night asphalt | Scrim behind a modal (at `alpha.scrim` 0.45), shadows |
| `asphalt900` | `#15130F` | rendered asphalt (88, 88, 92) taken dark and warm | Panels (at `alpha.panel` 0.06) |
| `asphalt800` | `#1F1C18` | | Cards, inputs, secondary buttons |
| `asphalt700` | `#2B2722` | | A card pressed or hovered; disabled button ground |
| `asphalt600` | `#3D3832` | | 1 px strokes, dividers |
| `asphalt500` | `#5E5750` | | Disabled text, idle icons |
| `paint` | `#E8E2CD` | lane paint (232, 226, 205) | Primary text |
| `sand` | `#C6AC84` | sand (198, 172, 132) | Secondary text; the Arabic line of a pair |
| `sandDim` | `#9C8768` | dark sand | Hints, captions, placeholders |
| `sodium` | `#FFBA5C` | sodium lamp bulb (255, 186, 92) | **The accent.** Primary buttons, the selected thing, prices |
| `sodiumDeep` | `#E08A2E` | | Primary button pressed |
| `sodiumDim` | `#4A3418` | | Selected-option ground, price-chip ground |
| `lens` | `#FFECC8` | lit lamp lens (255, 236, 200) | Focus ring; the brightest highlight |
| `gantry` | `#105C34` | highway sign green (16, 92, 52) | "Owned" badge ground |
| `gantryBright` | `#5CCB8A` | | Owned ticks and text on dark grounds |
| `beacon` | `#F0533F` | aircraft warning beacon (255, 70, 60) | Danger, errors, "not enough cash" |
| `beaconDim` | `#4A1A14` | | Error message ground |
| `dusk` | `#B784C9` | skyline aura violet (140, 76, 150) | Rarity mark on premium items only |
| `duskDim` | `#352040` | | Rarity chip ground |

Rules:
- **One accent.** Sodium marks what you can press or what is chosen. If two
  things on a screen are sodium, one of them is wrong.
- **Sodium means pressable, chosen, or a price you are about to pay.** Your
  own balance is none of these: cash you hold is `paint` (the garage header,
  a sheet's "Your cash"); an item's price and the BUY button are sodium.
- **Green only means yours.** Owned, equipped, done. Never a button.
- **No Roblox blue, no neutral grey, no pure black or white.** Surfaces are
  warm asphalt; text is paint.
- Allowed text pairs (all 4.5:1 or better): paint, sand or sandDim on any
  asphalt 700 to 900; asphalt900 on sodium, sodiumDeep or beacon; paint or
  sodium on sodiumDim; paint on gantry; gantryBright on asphalt 800 to 900;
  paint on beaconDim; beacon on asphalt 800 to 900 (error text: 4.86 and
  5.31; not on asphalt700, 4.25); dusk on asphalt900 or duskDim. **Not**
  gantryBright on gantry (3.98).
- Transparency: `alpha.panel` 0.06 for panels, `alpha.scrim` 0.45 for the
  modal dim, `alpha.disabled` 0.5 for a faded control, and `alpha.hud` 0.35
  for the two surfaces that float over the road while you drive (the HUD
  card and the CARS button), which must let the road through.

## Type

Two families, from Roblox's own font set:
- **Display: Oswald.** Condensed caps, like the plates and the road signs.
  Titles, numbers, prices.
- **Body: Builder Sans.** Roblox's UI face, clear at 12 px on a phone.

| Role | Family | Weight | Desktop | Touch | Case | Use |
|---|---|---|---|---|---|---|
| `hero` | Oswald | Bold | 40 | 50 | CAPS | A single word on a big moment: GARAGE |
| `display` | Oswald | Bold | 28 | 35 | CAPS | Screen title |
| `title` | Oswald | SemiBold | 20 | 25 | CAPS | Section title, tab names |
| `heading` | Builder Sans | Bold | 16 | 20 | Sentence | Card name |
| `body` | Builder Sans | Medium | 14 | 18 | Sentence | Running text, descriptions |
| `label` | Builder Sans | Bold | 12 | 15 | CAPS | Buttons, chips, badges |
| `caption` | Builder Sans | Regular | 12 | 15 | Sentence | Hints, footnotes |
| `price` | Oswald | SemiBold | 16 | 20 | Digits | Cash amounts |

- Touch sizes are desktop × `touchScale` (1.25), via `UITheme.px`.
- Nothing is smaller than 12 px on desktop, 15 px on touch.
- Numbers are grouped with commas: 25,000. Amounts are written without a
  currency symbol: `25,000`. A price is sodium; your balance is paint (see
  Colour rules).

## Arabic with English

The world's road signs put Arabic and English side by side. The UI does
the same, in a fixed way:

- **Titles pair on one line:** English at the left in its role, Arabic at
  the right edge in the same role, in `sand`, at `arabicScale` (1.15×) the
  size. The Arabic is right-aligned (`TextXAlignment.Right`).
- **Where a line is too narrow for both** (a phone header), the Arabic goes
  under the English, left-aligned, `body` role × 1.15, in `sand`.
- **Only titles are bilingual** (screen titles, sheet titles, section
  titles). Tabs, chips, buttons, prices, item names and running text are
  English only; doubling every line makes a menu twice as long and half as
  readable. (Ruled 2026-09-28 in the garage panel review: the spawn menu's
  tabs and the garage's category chips were already English only.)
- Arabic is never set in CAPS logic, never letter-spaced, and never in
  Oswald's condensed metrics: Roblox renders Arabic glyphs through its own
  Arabic face, at the weight asked for.
- Arabic numerals are not used in the UI; plates show their own digits.

## Space, radius, stroke, shadow

| Token | Value (px, desktop) |
|---|---|
| `space.xxs` / `xs` / `sm` / `md` / `lg` / `xl` / `xxl` / `xxxl` | 2 / 4 / 8 / 12 / 16 / 24 / 32 / 48 |
| `radius.sm` | 6: chips, badges |
| `radius.md` | 10: buttons, cards, inputs |
| `radius.lg` | 14: panels |
| `radius.pill` | 999: toggles, the collapse handle |
| `stroke.hairline` | 1: cards and inputs, `asphalt600` |
| `stroke.selected` | 2: the selected option, `sodium` |
| `stroke.focus` | 2: gamepad and keyboard focus, `lens` |
| `shadow` | A Frame behind the panel, `spread` 2 px larger, `offsetY` 4 px down, `asphalt950` at 0.55 |

- Padding inside a panel: `lg` (16). Between cards: `sm` (8). Between
  sections: `xl` (24).
- Everything scales by `touchScale` on touch, including spacing.

## Targets and layout

- The smallest tappable thing is 36 px on desktop, **48 px on touch**
  (`UITheme.minTarget` / `minTouchTarget`, read through `UITheme.target(touch)`).
- On a phone, controls you use often sit in the bottom two thirds of the
  screen or down the side panel, where a thumb reaches.
- A side panel is 360 px wide on desktop, 42% of the screen width (at most
  420 px) on touch, and always leaves the car or the road visible
  (`UITheme.sidePanel`; a card grid in it drops to one column under 340 px).

## States

| State | Ground | Text | Stroke |
|---|---|---|---|
| `button.primary` | sodium | asphalt900 | none |
| `button.primaryPressed` | sodiumDeep | asphalt900 | none |
| `button.secondary` | asphalt800 | paint | 1 px asphalt600 |
| `button.secondaryPressed` | asphalt700 | paint | 1 px asphalt600 |
| `button.selected` | sodiumDim | paint | 2 px sodium |
| `button.danger` | beacon | asphalt900 | none |
| `button.disabled` | asphalt700 | asphalt500 | none |

State changes tween over `motion.quick` (0.12 s). Panels slide over
`motion.panel` (0.25 s). Camera moves take `motion.camera` (0.8 s).

## Shop items: owned, equipped, previewing, for sale

The difference between what you own and what you do not must be
unmistakable at a glance:

| Item state | How it looks |
|---|---|
| **Equipped** (on this car) | `button.selected`: sodium stroke, and an `ON CAR` label chip in sodium |
| **Owned** | Card as `secondary`, and a `gantry` badge with a tick and `OWNED` in paint |
| **For sale** | Card as `secondary`, with a price chip: `sodiumDim` ground, the price in `sodium` `price` type, a padlock glyph. No green anywhere. |
| **Previewing** (for sale, on the car now) | As for sale plus the sodium stroke, and a bar across the panel's foot: `PREVIEWING` and the price, with a primary `BUY` button |
| **Rare** | A small `dusk` diamond before the name; nothing else changes |

Buying always goes through a confirm sheet: the item, the price, your cash
after, and two buttons, `BUY` (primary) and `CANCEL` (secondary). Nothing
is ever charged from a single tap. The sheet is opaque (not `alpha.panel`):
over a panel of cards, 6% see-through let the cards show through its rows.

## Don'ts

- No literal `Color3`, font or size in UI code: read `UITheme`.
- No gradients on controls, no drop shadows on text, no emoji.
- No sodium on anything that cannot be pressed, chosen or paid (a price).
- No text on the world without a surface behind it.
