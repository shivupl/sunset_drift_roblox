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
- **The garage's shade** (`UITheme.shade`, garage-ui-overhaul 2026-10-06):
  the garage panel has no box. asphalt950 darkens the screen under it, 0.06
  see-through at the screen's edge to `shade.far` 0.16 at the panel's edge,
  then fades to clear over `sidePanel.fadeTail` (200 px, 96 on touch), so
  the panel melts into the garage. Its tail lets drags through to the
  turntable (the `PassThrough` attribute, which `GarageView.overUi` skips).
  It and the confirm sheet's dim run under Roblox's top bar, so neither
  shows an edge there.

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
| `nav` | Oswald | SemiBold | 18 | 23 | CAPS | The garage's category rail (the chosen word Bold) |

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
- **Where the right edge holds something else** (the garage header: the
  cash and the close button), the Arabic follows the English after
  `space.md`, in `sand`, the `title` role × 1.15. Where even that row is
  too narrow (a phone with a big balance: measured on touch, GARAGE 79 px,
  the Arabic 37, a 12-digit balance 120, the close button 48, against a
  345 px phone panel's 305), the Arabic goes under the English at the
  same size (a smaller one would fit the row again and flip back).
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
| `stroke.marker` | 3: the bar beside the garage rail's chosen word, `sodium` |
| `shadow` | A Frame behind the panel, `spread` 2 px larger, `offsetY` 4 px down, `asphalt950` at 0.55 |

- Padding inside a panel: `lg` (16). Between cards: `sm` (8). Between
  sections: `xl` (24).
- Everything scales by `touchScale` on touch, including spacing.

## Targets and layout

- The smallest tappable thing is 36 px on desktop, **48 px on touch**
  (`UITheme.minTarget` / `minTouchTarget`, read through `UITheme.target(touch)`).
- On a phone, controls you use often sit in the bottom two thirds of the
  screen or down the side panel, where a thumb reaches.
- A side panel is 420 px wide on desktop, 46% of the screen width (at most
  460 px) on touch, and always leaves the car or the road visible
  (`UITheme.sidePanel`; widened from 360 px and 42% in the garage-ui-overhaul,
  2026-10-06, because the garage's category rail costs width and a phone's
  width is less scarce than its height).
- The garage's category rail: rows a target plus `space.xs` tall on
  desktop; on touch the seven rows share the rail's height so all show on a
  350 px phone, at most a target and never under `railMinTouchRow` (40 px;
  Apple's floor is 44, and a 40 px row is as wide as the rail). Below that
  the rail scrolls.
- A palette (a grid of colour swatches) has as many columns as fit tiles
  `paletteMinTile` wide (76 px; 88 on touch): three on desktop, two on a
  phone. A palette name that does not fit shrinks, down to caption size.

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
unmistakable at a glance.

**In the garage** (garage-ui-overhaul, 2026-10-06), an item's state is a
word under its name, with no badge ground: on the shade a coloured word
reads at once, and the swatch stays clear.

| Item state | How it looks |
|---|---|
| **On car** (saved on this car) | `ON CAR`, `label` role, in sodium |
| **Owned** | `✓ OWNED`, `label` role, in gantryBright |
| **For sale** | The price, `price` role, in sodium. No green anywhere. |
| **Showing on the car now** (saved or previewing) | Chosen: a palette swatch gets the 2 px sodium ring; a list row gets the `button.selected` ground and stroke. One item per set shows, so one per set is chosen; while a preview shows, the saved item keeps its `ON CAR` word without the ring. |
| **Previewing** (for sale, on the car now) | Chosen, with its price, and the foot names it: the item's name, its price, and a primary `BUY` |
| **Disabled** (the car can't show the slot) | The swatch at `alpha.disabled`, the name asphalt500, no word |
| **Rare** | A small `dusk` diamond before the name; nothing else changes |
| **Pressed** | A list row takes the `button.secondaryPressed` ground; any item shrinks to `GarageConfig.feel.pressScale` |

A set of colours is a **palette**, a grid of swatches with the name and the
word under each (paint colour, tint, rims, head and tail lights);
everything else is a **list**, a row per item with its swatch at the left
(finish, tyres, tips, flames, sun strips, plates, my cars; a car's word is
its drivetrain, or `✓ DRIVING`).

**In the menu's PLATES** (ui-flow, 2026-10-12), your plates are blocks
like the garage's: the one on your car edged green with `ON CAR`, the
others `✓ OWNED`, the session's default `THIS SESSION`.

A category is named for what a player knows it as: the windscreen banner
is `SUN STRIPS`, though the code, the slot key and the stored ids still say
`decal` (garage round 3 §4; ids are on profiles and never change). The
garage's seven categories are a rail of words down the panel's left
(`nav` role), the chosen one paint and bold with the sodium marker beside
it, which slides to a new choice.

A category with more than one set of items has **sub-tabs**: words in the
`label` role at the top of its content, the chosen one paint with a 2 px
sodium underline that slides to a new choice, the others sandDim (PAINT:
COLOUR, FINISH, TINT; WHEELS: RIMS, TYRES; LIGHTS: HEADLIGHTS, TAIL LIGHTS;
EXHAUST: TIPS, FLAMES). One set shows at a time (garage-polish,
2026-10-05, `GarageConfig.views`; FINISH became a sub-tab in the overhaul),
and each sub-tab moves the garage camera to its part. A category's action
that is not an item (EXHAUST's `REV`, which plays the flames on the
turntable car; PLATES' `SHOP PLATES`) is a `secondary` button at the end
of that row, never an item, and it costs nothing.

Buying always goes through a confirm sheet: the item, the price, your cash
after, and two buttons, `BUY` (primary) and `CANCEL` (secondary). Nothing
is ever charged from a single tap. The sheet is opaque (not `alpha.panel`):
over a panel of cards, 6% see-through let the cards show through its rows.
Plates too: the menu's PLATES BUY opens the same sheet (`Parts.sheet`: the
plate drawn, its name, price, your cash, cash after or `Short N` in beacon),
and only the sheet's BUY charges. Buttons under a sheet still hear clicks
through its scrim, so each one checks for an open sheet first.

## One frame for every screen (ui-flow)

The owner, 2026-10-12: "string together the entire UI from here for mobile.
make a couple different complete layouts but just stop it from being so
choppy and disconnected". Before, the car list was the car picker's own
panels, PLATES and SETTINGS the old spawn menu's panel on these tokens (where
the picker's plate and gear buttons dropped a player), the garage a third
arrangement, the load cover a fourth, and the coins a different pill in the
garage and missing in the menu.

Now the menu (`src/client/Menu`: CARS, PLATES, SETTINGS) and the garage
(`Garage/GaragePanel`) are two controllers drawing through the same layouts
(`Garage/Looks`), in the look the owner picked for the car picker
(`CarPicker/Kit`: graphite panels with a dot texture, heavy italic
Montserrat, slanted tabs, cut-corner boxes, green for go and yours, sodium
for money). Every screen has the same anchors, so nothing moves going from
one to the next:

| Anchor | Where | Menu | Garage |
|---|---|---|---|
| The words | Down the left on a shade (or the dock's tabs) | CARS, PLATES, SETTINGS | Its seven categories |
| EXIT, LAYOUT | Bottom left (or the dock's ends) | Closes the menu | Leaves the garage |
| The coins | Where the driving HUD has them, drawn as the HUD draws them (`HudLab.coins`) | | |
| The title | Top, after the words: the place, small, then the subject, big | HAJWALA هجولة; the car or plate | GARAGE كراج; the car |
| The subject | The middle | The car's photo with its weight and length; the plate, big | The 3D car |
| The column | Under the coins: sub-tabs, a form, blocks, the item picked | Drive filters and cars; plate styles, search, your plates; the settings' rows | Sub-tabs and items |
| The action | Bottom right, the bottom row's height | SPAWN THIS CAR / RESPAWN; BUY with the price; DONE | BUY; DRIVE THIS; ON YOUR CAR |

**The layouts** are complete: one choice (`Looks/Layouts`, the LocalPlayer
attribute `UiLayout`) for every screen, cycled by any LAYOUT button or
picked in Settings' SCREEN LAYOUT row. SHOWCASE (the words on a shade, a
graphite column), GLASS (the column see-through), FRAME (the column on a
shade, the blocks in a tray) and DOCK (the words as tabs in a dock along the
bottom with LAYOUT, the action and EXIT; the column a panel on the left, the
subject on the right). SHADE is parked; SHADES, EDGE, SHELF, CARD and WIDE
were tried in the garage and removed.

**A phone has GLASS** (the owner, 2026-10-12: "lets go with 'glass' for
Mobile view garage"); a PC keeps all four. On a phone its column reaches a
little past the coins' right edge (24 drawing pixels, only into room the
screen has: never nearer its edge than a notch's depth, so with no margin
past the coins it stays put), and its list has no fades ("remove the
scroll shaddow"). In their place an obvious up/down control
(`Parts.scroller`; "add an obvious scroll/updown for the options (make a
couple versions)"), the three phone layouts the LAYOUT button cycles:
- GLASS ARROWS: round white chevron buttons centred on the list's top and
  foot, over the row cut off there, each only while there is more that
  way; a row a tap; the down one nods once when a set opens.
- GLASS RAIL: a track down the list's right edge with a green thumb as
  tall as the share showing, dragged to scroll, chevrons at its ends a row
  a tap (the blocks give it 18 px).
- GLASS MORE: a pager row under the list in its own room, a small up and a
  wide "11 MORE" (the items wholly below), faded at either end; a page a
  tap.
The settings' rows scroll the same way. The garage view hides the shell's
roof beams on this screen (`GarageConfig.viewHides`): they crossed right
behind the coins and read as their shadow.

The pieces they share (`Looks/Parts`): the column lines up under the
coins, its right edge and just below their foot (`Parts.coinAnchor`: the
HUD's gui keeps out of the notch only, a panel's out of Roblox's margins
too, so on a phone the coins sat right of the panel); items are square
blocks (two across in the column, three in DOCK's panel; the owner,
2026-10-12: "make them blocks/squares"), the chosen one edged green; a list
fades into its panel (or shade) at an edge with more past it; the line
naming the item picked sits over the action (not on MY CARS or CARS, where
the car's name is the title's subject); titles' Arabic is at
`arabicScale`; the confirm sheet's dim covers the whole screen
(`UIKit.edgeToEdge`, BEHAVIOURS.md).

**The world behind** a menu page blurs (a `BlurEffect`, 16) and dims to 0.5;
SETTINGS leaves it clear (dim 0.8, no blur) because what it changes (the
time of day) is the world.

**Motion** is one language (`Parts.intro`, `outro`, `settle`): positions
only, since a fade needs a CanvasGroup, which redraws its children soft.
- Opening, every piece comes in from out of sight past the edge it lives
  on (the words and their shade from the left, the column and the action
  from the right, the title from above, the subject or the dock from below),
  a few hundredths of a second apart, over 0.42 s (Quint out), while the
  world blurs and dims over 0.35 s.
- Closing, they go back out the same way over 0.2 s (Quad in); what was
  under the menu (the top bar, the HUD, the garage) comes back once they
  are gone, the top bar sliding down from above the screen.
- A page, a sub-tab or a filter swaps its content in place, and that
  content eases up 14 px over 0.22 s; the rail's green marker slides to the
  word chosen; the dock's chosen tab widens as the one it left narrows.
- The garage's SHOP PLATES opens the menu's PLATES in the same frame: the
  garage hides under it with no slide, and EXIT hands it straight back.

The menu covers the HUD while driving (`HudLab.setCovered`): the pedals
showed through its middle. A toast is the same graphite pill everywhere
(`Parts.toast` in the menu and the garage, the HUD's own for STYLE and VIEW),
and the menu and the garage play the same sounds (`GarageSounds`: a tab, a
tap, a fit, a purchase, an error).

The action slot is never empty: where there is nothing to do it says why,
in grey (ON YOUR CAR, TAKEN, CHECKING…), and SETTINGS has a green DONE, so
no layout shows a hole at the bottom right or in the dock.

The load cover wears the same look (graphite, HAJWALA هجولة, the green
bar), and the menu slides in under it as it fades.

The phone's **top bar** (`src/client/TopBar.luau`, 2026-10-11) is one row
right of Roblox's own buttons, GARAGE (the menu's CARS) and SETTINGS always,
RESET, VIEW and STYLE between them while driving. Its buttons are the
picker's: graphite squares with a hairline edge, the icon (art/topbar) over
a heavy italic word, GARAGE edged in the picker's green. A desktop keeps the
CARS button and the keys.

Each layout is drawn for an 844x346 phone and a 1280x664 PC and scaled to
the screen it is on. In Studio the LocalPlayer attribute `ScreenSim` (a
Vector2) lays the menu and the garage out for that screen size at the
viewport's top left, to check a phone's proportions (`Parts.screen`).

## Don'ts

- No literal `Color3`, font or size in UI code: read `UITheme`.
- No gradients on controls, no drop shadows on text, no emoji.
- No sodium on anything that cannot be pressed, chosen or paid (a price).
- No text on the world without a surface behind it.
