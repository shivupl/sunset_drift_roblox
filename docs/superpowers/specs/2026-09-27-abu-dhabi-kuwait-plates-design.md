# Abu Dhabi and Kuwait plates: design

Asked by the owner on 2026-09-27 ("add abu dhabi and kuwait on this same
branch, do research and get it right: design, number sequence, shape"),
after Dubai (`2026-09-27-dubai-plates-design.md`). Both are new styles on
the same system: parsing, prices and look are new; the registry, economy,
remotes and car plate spots are reused. Unlike Saudi and Dubai, both use a
numeric code and a number, so typed input keeps the space between them.

## Reference check (2026-09-27)

Sources: Wikipedia, "Vehicle registration plates of the United Arab
Emirates" and "Vehicle registration plates of Kuwait"; Wikimedia Commons
drawings by Nima Farid (`Abu Dhabi License plate - 520x110mm.png`,
`- 335x155mm.png`, `Kuwait License Plate - Private.png`, `- EU Size.png`)
and photos (`Abu Dhabi Plate Number.jpeg`, `Abu Dhabi License plate
6-19000.jpg`).

| Question | Abu Dhabi | Kuwait |
|---|---|---|
| Format | Code, then a number of 1 to 5 digits: `20 10234` | Code, then a number of 1 to 5 digits: `10-23456` |
| Codes (private cars) | 1, 4 to 22, and 50 (50 marks the UAE's 50th National Day) | 1 to 89 |
| Sizes | 520 × 110 mm and 335 × 155 mm | 520 × 110 mm and 335 × 155 mm |
| Colours | Black on white; the code white in a red box (long) or a red band across the top (short) | Black on white |
| Long plate | Red code box at the left; "الامارات" / "أبوظبي" / "U.A.E A.D" stacked beside it; the number large on the right | "دولة الكويت" over "KUWAIT" at the left; then `10-23456` large, code and number joined by a hyphen |
| Short plate | A red band across the top: "أبوظبي" over "A.D" at the left, the code in the middle, "الامارات" over "U.A.E" at the right; the number large below | A vertical "KUWAIT" strip down the left edge; the code at the top left and "دولة الكويت" at the top right; the number large below |
| Digits | Western only | Western only |

Abu Dhabi has a second current design carrying the city's brand logo. We
draw the red-box design: it is the familiar one, and the other depends on a
logo (no real brands).

## Decisions

- **Keys:** `AD:20-10234` and `KW:10-23456` (style, the code, a hyphen, the
  number, no leading zeros in either).
- **Input:** the code and the number as two groups of digits, separated by a
  space or a hyphen, Western, Arabic-Indic or Persian digits. One group
  alone is refused with a reason that shows the format ("20 10234"),
  since a code and a number run together cannot be told apart. Letters are
  refused. A code outside the list, a number over 5 digits and a number of
  all zeros are refused.
- **Parsing:** the shared scan now also keeps the runs of digits and letters
  as typed, split by spaces and hyphens. Saudi and Dubai keep using the
  joined letters and digits, so their keys do not change.
- **Sizes per style:** Saudi and Dubai long plates are 55 cm, Abu Dhabi and
  Kuwait 52 cm; all short plates are 33.5 × 15.5 cm. A car's plate part and
  canvas take the size of the style shown on it, at the same spot.
- **Prices** (`PlateConfig.prices.AD` and `.KW`, first guesses for the
  owner): Abu Dhabi 900,000 / 350,000 / 125,000 / 35,000 / 12,000 and
  Kuwait 600,000 / 250,000 / 90,000 / 30,000 / 10,000 for 1 to 5 digits.
  All digits identical (2 or more) costs double, as for the others.
- **Menu:** the style switch gains AD and KW (KSA, DUBAI, AD, KW).

## Files

`PlateText`, `PlateConfig`, `PlateStyles`, `CarPlates` (size per style),
`PlatesPanel`, their specs, `TUNING.md`, `tools/carbody/README.md`.
