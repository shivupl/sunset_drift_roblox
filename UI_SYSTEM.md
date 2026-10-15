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
- A phone plays in landscape only: `StarterGui.ScreenOrientation` is
  `LandscapeSensor` (default.project.json), and the client sets its
  PlayerGui's the same at boot (the owner, 2026-10-14: "when i startup the
  game it should automatically lock the screen to landscape"). Every
  layout is drawn for a landscape phone; portrait would stack them off
  the screen.

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
| The coins | Where the driving HUD has them, drawn as the HUD draws them (`HudLab.coins`): the price tag below | | |
| The title | Top, after the words: the place, small, then the subject, big | HAJWALA هجولة; the car or plate | GARAGE كراج; the car |
| The subject | The middle | The car's photo with its weight and length; the plate, big | The 3D car |
| The column | Under the coins: sub-tabs, a form, blocks, the item picked | Drive filters and cars; plate styles, search, your plates; the settings' rows | Sub-tabs and items |
| The action | Bottom right, the bottom row's height | SPAWN THIS CAR / RESPAWN; BUY with the price; DONE | BUY; DRIVE THIS; ON YOUR CAR |

**The layouts** are complete: one choice (`Looks/Layouts`, the LocalPlayer
attribute `UiLayout`) for every screen, picked in Settings' SCREEN LAYOUT
row (DOCK on a PC also cycles it with its LAYOUT button; the button beside
EXIT went, the owner's phone, 2026-10-12: "remove the layout button"). SHOWCASE (the words on a shade, a
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
scroll shaddow"). In their place a rail (`Parts.scroller`; "add an
obvious scroll/updown for the options (make a couple versions)": ARROWS,
RAIL and MORE were tried, and from their phone the owner picked RAIL, then
"remove the two arrows on either side, have a simple scroll bar"): a track
down the list's right edge with a green thumb the track's width, as tall
as the share showing, dragged to scroll (the blocks give it 18 px). On a
phone the list's own finger scrolling is done by hand too
(`Parts.touchScroll`; the owner: "sometimes when i try it just doesnt
scroll"): Roblox's gesture takes a drag only once it moves mostly up or
down and drops one that starts across, so the list follows the finger
from its first pixel, up-and-down only, and flings on release
(`FLING_DECAY` 4 per second, `FLING_STOP` 24 px/s); the engine's gesture
is off there. A touch that starts on a button outside the list (the
thumb, EXIT) is that button's, unless the button is marked `PassThrough`
(drawn but not in the way): the menu's tap-outside button lies under
every point, and until it was marked (2026-10-14, the owner's phone: "i
cant tap scroll, only the scroll bar seems to work") it took every drag
on the car menu's list.
The settings' rows scroll the same way. With no fades a row cut by the
list's foot read as broken, so the list shows whole rows (`fitRows`): as
many as fit at the block size; a set that fits does not scroll, and the
list's spare height is left empty under the rows (MORE's pager follows
them up). The blocks used to shrink by up to a quarter to fit one more
row, so MY CARS drew 73 px boxes beside PAINT's 85 on a phone (the owner,
2026-10-14: "boxes need to be proportionate"); every tab's boxes are the
block size now.

The bottom row is one line: EXIT is the action's slanted shape in graphite
(`Parts.C.graphite`), the action's height on the action's foot, under the
words; the words share the height down to it (38 to 44 drawing px a row on
a phone, 46 to 50 on a PC), the first level with the title. The garage view hides the shell's
roof beams on this screen (`GarageConfig.viewHides`): they crossed right
behind the coins and read as their shadow.

**On a PC** (desktop-ui, 2026-10-14, the owner of the garage: "the
spacing is off all around. the left side menu options need to be
adjusted better also the right side menu needs to be compacted a bit so
that the exit and buy buttons can be raised slightly"): the margin from
the screen's edges is 22 drawing px (a phone's 8; EXIT and the action
had sat 8 from the bottom, the words 7 from the left); EXIT's cross and
word start where the rail's words do (`Parts.exit`'s indent, the rail's
own `size * 1.1`), so the left side has one edge; the rows 50 at most
(were 54); the column 332 wide with 10 of padding (were 352, 12), 8
between its pieces and its blocks (were 10), the sub-tabs 32 (36), the
swatch 56 (60), the item line 26 (28), 12 between the column's foot and
the action. Measured in Studio's 1257x683 viewport (the layout scaled
0.941): EXIT and the action 56 tall at y 547 of 625, 22 from the gui's
foot (were y 560, 9 from it); the words and the cross both at x 36 (were
23 and about 35); the column 312x503 (was 331x520) holding four rows of
88 px blocks (were 92) and a sliver of the fifth, which fades.

**A PC's SHOWCASE comes in three sizes** (`Showcase.Sizing`: REGULAR,
BIGGER, WIDE; `Layouts.pc` lists them as SHOWCASE, BIGGER and WIDE
beside DOCK, picked in Settings' SCREEN LAYOUT row or cycled with K in
the garage (`Layouts.nextSize`, the three sizes round, DOCK skipped; the
HUD's K, the desk layout, stands aside while the garage is up: the
`GarageOpen` attribute); the owner,
2026-10-14: "make a couple variants of the customization UI, i feel like
the text buttons on the left side need to be a bit bigger and also the
boxes in the right side menu also could be bigger"). GLASS and FRAME are
off a PC's list. In drawing px:

| | SHOWCASE | BIGGER | WIDE |
|---|---|---|---|
| Rail words, chosen word | 16, 21 | 18, 24 | 18, 24 |
| Rows, at most | 50 | 56 | 56 |
| Rail width | 190 | 200 | 200 |
| Column, blocks across | 332, 3 of 94 | 372, 3 of 108 | 352, 2 of 156 |
| Swatch, name, word | 56, 13, 11 | 66, 14, 12 | 88, 15, 12 |
| Sub-tabs | 32 | 34 | 34 |

Measured at 1257x683 (scaled 0.941): BIGGER's rows 52 with 18 px words,
its column 350 wide with 101 px blocks, three rows whole and the fourth
cut; WIDE's column 331 with 146 px blocks, two rows whole and the third
cut (MY CARS' cards the same 146). The car sits a little further left
under the wider columns (`GarageConfig.layoutOffset`: bigger -0.08, wide
-0.07, showcase -0.06).

**The price on BIGGER's and WIDE's blocks** comes three ways
(`Parts.BoxMetrics.price`, the LocalPlayer attribute `BoxStyle`, J in the
garage cycles it with a `BOXES:` toast; the owner, 2026-10-14: "make a
couple redesigned versions of the display boxes where the price is more
visible"). PLAIN is the word under the name as it was. BAND puts the
name over a dark band along the box's foot (`Kit.C.chip` 0.3
see-through, inset 6 from the cut edge, the word's size plus 12 tall)
with the coin and the price in Oswald a size up on the plain word's,
ON CAR and OWNED in green with no coin, a note grey; the swatch gives
up the room (BIGGER's 39 px for 66, WIDE's 82 for 88). TAG leaves the
name alone at the foot and puts the price on a sodium pill in the box's
top right corner with the dark buy ink, ON CAR and OWNED on a green pill
with its dark ink, a note on grey; the swatch keeps its size. SHOWCASE's
blocks stay plain (`Showcase.Sizing.restyle`).

**CARS and PLATES are the car picker's SHOWROOM** (`Menu/Looks/Showroom`;
the owner, 2026-10-12: "the old layouts were internally a bit better the
rhs boxes, the overall styling"; of PICKER, SHOWROOM and FRAME tried,
"lets go with showroom for the cars menu"; of a RAIL or a SEGMENT to the
pages and CUSTOMIZE on the STAGE or as a BUTTON tried from the canvas's
row E, "go with showroom segment stage"). Two panels: the subject on the
left (its name, chip and star in a row; under them the page's stage in a
framed graphite box the panel's width, F1 from the canvas's row F, chosen
over a big card and over spot, floor, glass, carbon and band looks of the
box, "lets just go with the original f1 background": the car with IN USE
top left and CUSTOMIZE, a dark pill with a green ring, bottom right,
which takes you to the garage with that car on the turntable (the owner,
2026-10-14: "clicking customize should take me to the actual garage";
`Actions.customize` → `GarageView.visit`: on foot a walk-in from where
you stand, LEAVE standing you at the door; driving your own car a drive-in
from afar, the server's "bringIn" parking it on the drive-out spot and
LEAVE seating you back in it; in another's car a notice and nothing moves;
far from the garage its parts are streamed in first, around the folder's
`DoorPosition`); or
the plate; the weight and length under the box; the action, SPAWN or
BUY), the page on
the right: a CARS | PLATES switch in the header with the count and close
beside it, the sub-tabs, a search beside them where the page has one, the
page's form (the plates' field) and its items, the picker's wide cards for
cars (`Parts.cards`: `Kit.tile`, the name, its own star, the photo on a
lit stage, the drive chip, the picked one edged green) or the blocks for
plates, with the rail and the finger's scrolling. A page says what the
cards need (`Entry.image`, `Entry.chip`, `EntryState.starred`,
`Actions.starEntry`, `Ctx.search` with `has`).

**SETTINGS is the BOARD** (`Menu/Looks/Board`, the canvas's "B. Settings";
the owner, 2026-10-12: "implement this version that we had planned but
remove the buttons at the bottom"): one panel in the showroom's frame, a
header (SETTINGS إعدادات, "Time of day saves to your account", the
close) and three columns the page draws (`Menu/Settings`). TIME OF DAY
down the left as art tiles (the sunset's band, the night's stars and a
lamp), the chosen one edged green with a tick; HUD STYLE across the
middle as cards, each a mock readout in the finish's own colours (the
slide score and its multiplier, a speed dial with the needle low on the
left); CAMERA on the right as slanted choices (CHASE, CLOSE, FAR:
`CameraViews.set`); HUD LAYOUT under it as rows, a word on each
(`Versions.blurb`); CLEAR UI under them, one row that switches; SCREEN
LAYOUT (the garage's layout) last, only where there is more than one (a
PC). The canvas's bottom bar (CARS, PLATES,
SETTINGS, the note, the close) went: the words are the showroom's switch
and the phone's top bar (which reaches SETTINGS once the menu is closed),
and the note and the close moved into the header. No action: what is
picked is in force at once. Moving between the showroom and the board
builds the screen again, coming in from its edges. The screen's layout
(`Looks/Layouts`) is the garage's alone now.

**CLEAR UI** (`src/client/ClearUi.luau`, the LocalPlayer attribute
`ClearUi`, the session's; the owner, 2026-10-13: "add a 'clear UI' option
that literally removes every element from the UI except a small settings
gear button"): on, the driving HUD with its coins, callouts and edge glow,
the phone's controls, the top bar and a desktop's CARS button all go. What
stays is one small round gear in the top bar's place (`TopBar`, on a phone
or a desktop), which opens SETTINGS, where the switch turns it off. A
screen you open yourself (the menu, the garage) still shows while it is
up. Each gui's owner reads the switch as it shows (`ClearUi.on`) and
repaints on `ClearUi.changed`; the speed lines stay, being the camera's
effect, not UI. On a phone this hides the pedals too, so you cannot drive
with it on: that is the literal ask, and the one-line knob is the controls'
`Enabled` in `HudLab.setCovered`.

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
in grey (ON YOUR CAR, TAKEN, CHECKING…), so no layout shows a hole at the
bottom right or in the dock (the settings board has no action slot; its
page still answers DONE for a layout with one).

The load cover wears the same look (graphite, HAJWALA هجولة, the green
bar), and the menu slides in under it as it fades.

**The cash is one price tag everywhere** (`HudLab/CashTag.luau`; the owner,
2026-10-14, of the canvas's J7 "Price tag: a sodium plate with the cut
corner, dark ink": "uniformly implement this one throughout the ui"): a
sodium plate (#FFD592 over #FFBA5C, a white 9-slice `hud_tag` tinted by a
gradient; three corners rounded, the bottom-right cut, the kit's shape),
the amount in the HUD's italic digits in dark ink (#2B1903), the coin
1.25 the plate's height over its left end. The driving HUD draws it in
every version and finish (ScoreLive, ScoreBoard: BOARD's long CASH plate
went, BEST sits under the tag as in FLOW), and the menu and the garage
show the same drawing at the same spot (`Coins`). Sized in fractions of
the screen's height as before (`LayoutD.CASH_H` tall at `CASH_Y`), the
plate as wide as the amount: the mock's 34/32 of its height left of the
digits, 12/32 right, one atlas cell (80/150 of the digits' height, half
the plate's) a character.

The phone's **top bar** (`src/client/TopBar.luau`, 2026-10-11) is one row
right of Roblox's own buttons: STORE (the plates page, until a store
exists), GARAGE (the car menu, tinted green) and SETTINGS always, EXIT
while driving (2026-10-14: "on mobile - need an exit car button"; the
same pulse as E, a group apart from the places), CAMERA and STYLE while
driving once they are back (RESET left the row 2026-10-13: "store,
garage, settings then camera, style buttons"; R stays on a keyboard). A
desktop has the same row since desktop-ui (2026-10-14; before it kept a
CARS button and the keys): see "The desktop HUD" below. The row is the kit's slanted tabs as
glass (the owner, of the TABS row on their phone: "i am a big fan of this
one but i think it needs some work"; the canvas's row L): each tab the
slanted shape nearly clear over a fainter copy of itself (a white tint,
green for GARAGE), sized to Roblox's pill, which is not centred in the
top bar inset but 12 px down it and 44 tall where the inset is 58
(Studio and the owner's phone agree), so the row takes those fractions
of the inset's height ("line the buttons up well with this
horizontally"). The tab is laid out from the mock's measurements, taken
in the browser ("make sure the text and icon sizes are also
proportionate", then "the spacing and proportions isnt as good as the
prototypes ... make sure they are close to 1-to-1"): an 18 px icon and an
11 px word on a 44 tab, 16 of padding and 8 between them, the tools 42
wide with the icon alone, 5 between tabs and 20 before the tools. The
icon shows its sheet cell cropped to the drawing (`ICON_CROP`: the
drawings sit in a margin of their cell), so an 18 px icon draws 18 px;
the word is a size up (12) because Roblox draws Montserrat narrower than
the browser, with no letter spacing. The places carry their words, the
tools their icons alone (of the four takes tried, with SETTINGS as a word
or the gear and the icon over the word: "just implement this version but
fix the spacing"). The row fits the room it has (the owner's phone: the
row ran into the coin; "make sure you are making all these changes so
that they adjust dynamically ... not hard programming for the mobile
emulation on pc"): it measures what it would need (the words through a
hidden label's `TextBounds`) against the room from where it rests to the
cash (the left edge of any "Cash" frame or hanging "Coin" showing, the
HUD's or a menu's; Roblox's inset's end with none) less 8, and if that is
more than the room scales the row down to fit, never past 0.7, keeping
every word; it refits as the tools come and go, the menu opens, the cash
appears and the inset changes. On the owner's phone (about 404 px of
room with the tools up, the row needing 428) that is 0.95. In Studio the
LocalPlayer attribute `TopRowRoom` (a number) stands in for the cash to
try a narrow phone. With CLEAR UI on the row is one small round gear.

SETTINGS is the gear alone (the owner, 2026-10-13, of four takes tried,
the row full size or compact and SETTINGS as a word or the gear: "go with
this one"), a slimmer slanted tab with a 24 px gear and 13 of padding.
CAMERA and STYLE are off the row for now ("forget the style and camera
buttons for now"; `TOOLS`, the code kept). The icons are 22 on 44 (the
mock's 18 was "big enough" only just: "make sure the icons are big
enough"); the tab itself is 40 tall round them (`TAB_SHARE`, 2026-10-14:
"buttons should be slightly vertically narrower (text and icon remain
the same)"), its middle on the pill's, and its art is drawn at 277x128,
twice the old 138x64 ("edges look wierd and blury": a 44 px tab is 88 to
132 device pixels on a phone, more than the old art had), and the
icon-and-word pair is leaned 2 px left ("the text is
centered well, right now it kind of looks off center and that there is a
little less room on the right of it"): an icon's drawing sits inside its
box and the italic word's ink leans past its box's right, so a
geometrically centred pair read right of centre (the owner's phone: 10 px
clear left of STORE, 8 right; a 3 px lean overshot to 10 and 12 in a
Studio capture).

The row stays up while the menu is open, which hangs under it
(`Ctx.top`: the drawing pixels to leave clear under the row, mostly 0
since the row ends above the menu's gui; nil with no row), and the button
of the page showing is lit; tapping it again closes the menu. The owner,
2026-10-13: "when clicking settings or garage the options should stay
there and the tabs/menu should just show below". The row draws over the
menu's dim (DisplayOrder 22), so the lit button stays crisp, and shades
its other buttons itself while the menu is open ("it should darken the
other buttons on top"), all of them under a confirm sheet
(`TopBar.setBusy`); Roblox's own pill is not ours to shade. Three ways
out of the menu: the × at the top right of every page, as before (the
cars header after the count, the settings header after the note; "there
should always be a like x button ... top right, as it was before"), the
row's lit button, and a tap anywhere outside the panels (the menu's
`Outside` button under everything it draws; "i should also be able to
leave the menu by clicking outside"). The frames over that button do not
keep a tap from it, Active or not (2026-10-14: a tap on a car card
activated it and closed the menu), so it hit-tests the tap itself, where
it came down and where it let go, and ignores one over a panel either
time (`Kit.panel` marks its frame with the attribute `Panel`; a drag down
a list that let go past the panel used to close the menu). The button is
`PassThrough` so the lists' finger scrolling does not take it for a
button over them.

Each layout is drawn for an 844x346 phone and a 1280x664 PC and scaled to
the screen it is on. In Studio the LocalPlayer attribute `ScreenSim` (a
Vector2) lays the menu and the garage out for that screen size at the
viewport's top left, to check a phone's proportions (`Parts.screen`).

## The desktop HUD (desktop-ui)

The owner, 2026-10-14, of the PC screen: "put a small guide on which
keys are for what", "the odometer and stuff should go on the right",
"the buttons and everything needs to be redone and spaced for pc", "make
a couple different full UI options ... and also implement them in game
for me to switch between". Three were drawn and built (DASH, STRIP,
CLUSTER: the canvas "Hajwala desktop HUD", boards A–C; the code at
`a669f1a`). The owner picked DASH "but still needs some polishing and
work, make a couple variants ... the controls on the bottom should be
faint and lighter opacity and more simple ... the keys inside [the
buttons] are off center and too dark". So every layout is DASH now, and
the layouts differ in the key guide (the canvas's A1–A3 boards, and "The
keys" board up close). `src/client/HudLab/Desk.luau` is the list
(`HudDesk` attribute; K cycles it, the PC LAYOUT rows under HUD STYLE's
cards in Settings pick one, the toast says `PC: DASH THIN`). Nothing of
it touches a phone: a phone's readouts are the dial in the bottom
middle, its controls layout D.

| | DASH | DASH THIN | DASH FADE |
|---|---|---|---|
| Key guide, bottom left | outlined keycaps, nothing behind them | the letters alone, no keycaps | the outlined keycaps on black fading up 130 px from the screen's bottom edge (0.58 at the edge), under the dial too |
| Measured at 1257x683 | 638x22 at 24 in, 28 up | 531x24 | as DASH; the fade 1257x130 |

The same in all three: the dial as it was (0.28 of the height, was 0.3
in the bottom middle) in the bottom right corner, the gear above its
cap and the speed under it (measured: 191 px at x 1048); the top row's
tabs 44 tall with their keys.

- **The keycap** (`KeyGuide.cap`): 22 tall, 4 round, the letter 11
  ExtraBold centred in a cap sized to it, never narrower than it is
  tall; a *tone* colours its face, its 1 px edge and its ink, each with
  its own transparency (`KeyGuide.TONES`). The guide's `ghost` tone is
  white: the face 0.94 see-through, the edge 0.66, the letter 0.28; the
  word after the keys white 12 SemiBold, 0.5 see-through. THIN's `bare`
  caps have no face or edge, the letter 12 (a 24 cap), the word 0.55.
  Held: `lit`, sodium with the lamp's lens for an edge and dark ink
  (bare: the letter itself goes sodium). 4 between keys (THIN 3), 6
  before the word (8), 24 between pairs (28): W A S D DRIVE, SPACE HAND,
  Q E NATL, R RESET, H HORN, G LIGHTS. The keys on the row's tabs (M, F,
  V, U) are not repeated.
- **The first cut's mistake:** the letter was drawn in a label of its
  own width set at the cap's left, so it sat left of centre by half the
  slack (F by 3 px at 22 wide) and 1 px high over a 2 px lip; the cap was
  near-black on the dark glass. Now the label fills the cap and centres
  the text; the lip went. Measured: every tab's letter box 0,0 off its
  cap's centre (was -1.5 to -3.0, -1.0).
- **The top row on a desktop** (`TopBar`): the phone's row, STORE,
  GARAGE, SETTINGS (the gear), then EXIT, CAMERA and STYLE while driving
  (CAMERA and STYLE are off the phone's row for now), each tab with a key
  wearing it as the same keycap after its word (half the tab's height)
  in the `tab` tone: a white face 0.84 see-through, the edge 0.66, the
  letter white; GARAGE's key green with its word (`tabGreen`), and on
  the lit tab the dark green ink the word takes (`tabOn`); a shaded tab
  washes its key out 0.45 more. The tabs 44 tall (`DESK_TAB_H`), their
  middle on Roblox's pill's. The CARS (M) button went (`SpawnMenu`). The
  debug panel sits under the inset so it does not lie over the row.
  Measured at 1257x683: STORE 98, GARAGE 138, EXIT 116, CAMERA 140, STYLE
  125 wide, all 44 tall, the same as before the fix.

## Don'ts

- No literal `Color3`, font or size in UI code: read `UITheme`.
- No gradients on controls, no drop shadows on text, no emoji.
- No sodium on anything that cannot be pressed, chosen or paid (a price).
- No text on the world without a surface behind it.
