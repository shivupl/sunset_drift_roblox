# Garage UI overhaul: a shade instead of a box, a category rail, palettes and lists

Date: 2026-10-06. Branch `garage-ui-overhaul`, from `main` after the
garage-polish merge.

## Why

The owner, 2026-10-06 (a /goal): "polish the UI of the garage, a complete
overhaul to make the UI look better and more organized + appealing. try
different styles and use /frontend-design or any other skills and research
you need to do."

What the panel looked like before (Play, 2026-10-06, PAINT open):

- The header (GARAGE, the Arabic under it, the cash under that), two rows
  of category chips, a row of sub-tab chips and three rows of finish pills
  stacked up before the first item: the grid started 60% of the way down
  the panel and showed four to six items.
- Categories, sub-tabs, finishes and REV were all the same chip, so
  nothing said which control was the main navigation.
- Item cards were boxes with a small swatch, the name and a spare second
  line: most of each card was empty box.
- The foot bar said `PREVIEWING 30,000` without the item's name.

What stays from the garage's rules (UI_SYSTEM.md, the garage specs): every
change previews live on the car; nothing is charged without the confirm
sheet; owned against unowned is unmistakable; the panel collapses; it
works at phone size; the camera goes to each part (garage-polish); the
sounds and the press, pop, cash count and slide motion.

## Styles tried

Three directions were built as static mockups in the Client datamodel over
the real garage view, with the real fonts, items and car, and compared in
screenshots:

| | A. Workshop | B. Paint chips | C. Heads-up |
|---|---|---|---|
| Chrome | the boxed panel | the boxed panel | no box: a shade that fades into the garage |
| Categories | a rail of words on a darker strip | a 4 + 3 segmented block on top | a column of large words, a sodium bar at the chosen one |
| Items | a 3-column swatch grid, name and price under each swatch | full-bleed swatch cards, name and price in a band | list rows: swatch, name, price at the right |
| Learned | organised, 12 paints in view; a box inside a box | colours look great; tips and tyres are empty dark cards; the categories still take two rows | the most like a car game, the car and garage stay in the picture; a list is right for parts and wasteful for 17 colours |

Chosen: **C's chrome with A's palette grid**. The panel is a shade, not a
box; the categories are a column of words; a set of colours is a swatch
grid, a set of parts is a list. Spending the boldness in one place: the
shade and the large category words are the look; everything inside is
quiet.

## 1. Chrome: the shade

- No panel box. Under the panel the screen darkens with `asphalt950`, from
  `UITheme.shade.near` (0.06 see-through) at the screen's left edge to
  `shade.far` (0.16) at the panel's edge, and then fades to clear over
  `sidePanel.fadeTail` (200 px; 96 on touch) past it, so the panel melts
  into the garage instead of ending at a border.
- The tail lets drags through to the turntable: it carries the
  `PassThrough` attribute, which `GarageView.overUi` skips. The solid part
  still counts as UI, as the panel did.
- The panel is wider: 420 px on desktop (was 360), 46% of the screen on
  touch, at most 460 (was 42%, at most 420): the rail costs width, and a
  phone's width is less scarce than its height.
- Collapsing slides everything out as before; the tail fades out with it,
  so no dark band stays on the screen's edge.

## 2. Layout

```
GARAGE  كراج                    2,000,000  [×]
                                                    
▌PAINT        COLOUR  FINISH  TINT                    
 MY CARS      ┌────┐ ┌────┐ ┌────┐                     
 WHEELS       │    │ │    │ │    │                     
 PLATES       └────┘ └────┘ └────┘                     
 LIGHTS       Factory Pearl  Sand                      
 SUN STRIPS   ON CAR  15,000 15,000                    
 EXHAUST      ...                                      
              ─────────────────────────                
              Pearl White              [ BUY ]         
              15,000                                   
```

(The rail keeps the categories in their order; PAINT is drawn first above
only to show the marker.)

- **Header**, one row: `GARAGE` (display) and `كراج` after it (title role
  × `arabicScale`, sand), the cash (title role, paint) at the right, and a
  square close button (×, secondary, a target square) at the far right.
  The close button is LEAVE: Esc and gamepad B still leave too. Where
  the row is too narrow for all four (a phone with a big balance), the
  Arabic goes under the English. The Arabic
  follows the English instead of sitting at the right edge, because the
  cash and the close button hold the right edge (UI_SYSTEM.md gets that
  case). The confirm sheet's dim runs under the top bar too, like the
  shade.
- **Rail**, down the left under the header: the seven categories as words
  in the new `nav` role (Oswald SemiBold 18, caps). The chosen one is paint
  and bold with a sodium bar at its left; the others are sand. The bar
  slides to a newly chosen row (`motion.panel`). Rows are a target tall
  plus `space.xs` on desktop; on touch they share the rail's height, at
  most 48 and at least `railMinTouchRow` 40 (the rail scrolls below that).
  The rail only widens during a visit, so the items don't shift when a
  wider word turns bold.
- **Content column**, right of the rail, top-aligned with it:
  - the **sub row**: the sub-tabs as words (`label` role; the chosen one
    paint with a 2 px sodium underline that slides to a new choice, the
    others sandDim), and the category's action at its right end (REV on
    EXHAUST, SHOP PLATES on PLATES) as a secondary button;
  - a **note** line under it where needed (the tyres' drivetrain and how
    the tyre drives; "This car's paint can't be changed yet");
  - the **items**, scrolling;
  - the **foot**, when there is an action: a hairline over it, the item's
    name (heading) with its price (price role, sodium) under it, and the
    primary button at the right (`BUY`, or `DRIVE THIS` on MY CARS with
    the car's name). The foot now names what you are buying.
  - the toast above the foot, as before.
- PAINT gets a third sub-tab, **FINISH** (`GarageConfig.views`, full
  shot): the finish pills and their rows above the colours go.
- Single-view categories (MY CARS, PLATES, SUN STRIPS) have no sub-tabs;
  SUN STRIPS loses its title row (the rail already says it).

## 3. Items: palettes and lists

A set of colours is a **palette** (a grid of swatches); everything else is
a **list** (one row per item). Palettes: paint colour, tint, rims, head
lights, tail lights. Lists: finish, tyres, tips, flames, sun strips,
plates, my cars.

- **Palette tile**: the swatch (the full cell width, `target × 1.4` tall,
  `radius.md`), the name under it (body, one line; a name that does not
  fit shrinks to caption size rather than being cut: Sodium Orange is
  104 px at touch size against a phone tile's 99), and the status line.
  Columns: as many as fit at `paletteMinTile` (76 px; 88 on touch), so 3 on
  desktop and 2 on a phone.
- **List row**: the swatch at the left (`radius.sm`, 1.6 times as wide as
  tall so four exhaust tips fit; 2.2 for plates and sun strips, whose art
  is a banner), the name (body) over the status line. One column.
- **Status line**: `ON CAR` (label, sodium) for what is saved on this car;
  `✓ OWNED` (label, gantryBright) for owned; the price (price role, sodium)
  for sale. No badge grounds: on the shade a coloured word reads at once,
  and the swatch is left clear. Owned against unowned stays unmistakable:
  green tick against a sodium price.
- **Showing on the car** (saved or previewing) is the selected state: a
  palette swatch gets the 2 px sodium ring; a list row gets the
  `button.selected` ground and stroke. One item per set shows, so there is
  one ring per grid. While a preview shows, the saved item keeps its
  `ON CAR` word without the ring.
- Pressed: a list row takes the `button.secondaryPressed` ground; any item shrinks to
  `feel.pressScale` as before. Disabled (the car can't show the slot): the
  swatch at `alpha.disabled`, the words asphalt500.
- Rare: the dusk diamond before the name, as before.
- Swatches are drawn as before (`drawItemTile`); finishes get the car's
  paint with a highlight whose strength follows the finish's reflectance,
  so the five rows differ at a glance.

## 4. Tokens

- `UITheme.type.nav`: Oswald SemiBold 18 (touch 23), caps: the garage's
  category rail.
- `UITheme.shade = { near = 0.06, far = 0.16 }`: the garage shade's
  see-through at the screen edge and at the panel's edge.
- `UITheme.sidePanel`: width 420 (was 360), touchFraction 0.46 (was
  0.42), touchMax 460 (was 420), `fadeTail` 200, `touchFadeTail` 96,
  `paletteMinTile` 76, `touchPaletteMinTile` 88, `railMinTouchRow` 40;
  `oneColumnBelow` goes (lists are one column, palettes count their
  columns).
- `UITheme.stroke.marker` 3: the rail's chosen-row bar.
- No new colours.

## 5. Testing (light: a UI change)

- `GarageConfig.spec` already checks every view names a shot and has a
  label; it covers the new FINISH view.
- `UITheme.spec`: the `nav` role exists, is caps, at least 12 px.
- Type check (`scripts/analyze.sh`) on the touched files.
- Play, desktop: PAINT (colour, finish, tint), WHEELS (tyres), EXHAUST
  with a tip previewing (foot with BUY), PLATES, MY CARS; the confirm
  sheet; collapse. Play with `ForceTouch`. Screenshots of each.

## Files

| File | Change |
|---|---|
| `src/shared/UITheme.luau` | `nav` role, `shade`, `sidePanel` values |
| `src/shared/GarageConfig.luau` | the FINISH view |
| `src/client/Garage/GaragePanel.luau` | the shade, header, rail, sub row, palettes and lists, the foot naming the item |
| `src/client/Garage/GarageView.luau` | `overUi` skips `PassThrough` |
| `src/shared/Tests/UITheme.spec.luau` | the `nav` role |
| `UI_SYSTEM.md`, `TUNING.md`, `BRANCH_STATUS.md` | the garage's shade, rail, palettes and lists, status words, the Arabic-after-English case; the new tokens; the branch |
