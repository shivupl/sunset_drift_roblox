# Dubai plates: design

Asked by the owner on 2026-09-27 ("do dubai now, separate branch"), after
Saudi plates shipped (`2026-09-26-number-plates-design.md`). Dubai is the
second style on the same system. The registry, the economy, the remotes and
the car plate spots are reused unchanged; only the style's rules, prices and
look are new.

## Reference check (2026-09-27)

| Question | Finding | Source |
|---|---|---|
| Format | A code, then a number of 1 to 5 digits: `A 12345` | Wikipedia, "Vehicle registration plates of the United Arab Emirates" |
| Codes | A single letter A–Z; also the double codes AA, BB, CC, DD, EE | same |
| Sizes | 550 × 110 mm and 335 × 155 mm, the same two sizes as Saudi | same; Wikimedia Commons drawings by Nima Farid (CC0) |
| Long plate | "Dubai" name block at the left with the code under it; the number large on the right | `Dubai License Plate - 550x110mm.png` |
| Short plate | "Dubai" at the top left, the code at the top right, the number large across the bottom | `Dubai License Plate - 335x155mm.png` |
| Colours | Black on white | Wikipedia |
| Digits | Western digits only; no Arabic-Indic digits on the plate | reference images |

The current plate carries the Dubai city wordmark. We draw it as plain text
("DUBAI" with "دبي" under it), not the wordmark itself.

## Decisions

- **Key:** `DU:A-12345` (style `DU`, the code, a hyphen, the number without
  leading zeros). A Dubai plate never collides with a Saudi one: the style is
  part of the key.
- **Input:** the code in English letters and the number, in either order,
  spaces and hyphens anywhere; Arabic-Indic and Persian digits are accepted
  and become 0–9 (same normalising as Saudi). Arabic letters are refused with
  a reason, since Dubai codes are English letters. Codes outside the list are
  refused. All zeros is refused.
- **Prices** (`PlateConfig.prices.DU`, first guesses for the owner, higher
  than Saudi as Dubai numbers are the prestige market): 1 digit 1,000,000;
  2 digits 400,000; 3 digits 150,000; 4 digits 40,000; 5 digits 15,000. All
  digits identical (2 or more) costs double, as for Saudi.
- **Default plate:** stays a random Saudi plate.
- **Remotes:** `PlateQuery(text, style)` and `PlateAction(what, text,
  style)`. A missing style means Saudi, so existing callers keep working;
  an unknown style is refused.
- **Menu:** a KSA / DUBAI switch next to the search box picks the style.
  Owned plates of both styles are listed together.
- **Cars:** unchanged. Each car's `short` or `long` spot takes the Dubai
  plate of that size.

## Files

`PlateText` (styles, Dubai parsing), `PlateConfig` (prices by style),
`PlateStyles` (Dubai layouts), `PlateService` (style argument),
`PlatesPanel` (the switch), their specs, `TUNING.md`, and
`tools/carbody/README.md` (a line on styles).
