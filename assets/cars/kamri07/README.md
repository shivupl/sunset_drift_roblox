# Kamri '07

A mid-2000s Japanese saloon from the Creator Store (asset 876308553, an
A-Chassis car). Catalog id `kamri07`.

## How it is built

The body is the store model's own meshes, untouched, referenced by mesh id
(BodyBuilder loads them with `CreateMeshPartAsync`, like the Cruiser), so
nothing is uploaded and it works in play and live. 89 of its parts:
**143,632 triangles of the original 158,140**, interior included.

Only what cannot be seen is removed (the owner's rule: below the car, the
engine bay, the boot; never the interior):

| Cut | Parts | Triangles |
|---|---|---|
| Scripts, GUIs, sounds, lights, remotes, seats (not geometry) | 34 scripts and the rest | 0 |
| Invisible parts (light toggles, hubs, sound emitters) | 18 | - |
| No ray from outside reaches (brackets, stacked duplicates) | P106, P109, P152, P186, P187, P188, P33, P67, P83, P84 | 1,344 |
| Engine bay | P173, P191, P39, P171 | 4,900 |
| Boot interior | P175 | 1,042 |
| Under the car (floor pan, tray) | P31, P49 | 2,556 |
| Front badge | 2 parts | - (its backing oval is back, turned out, flattened and painted, as `Trim_Badge`: the empty badge spot showed as a black hole, 2026-09-27) |
| Chrome boot strip carrying the maker's oval and lettering | P169 | 4,642 |
| The maker's emblem on the steering wheel pad (seen from the first-person view, 2026-11-08) | P184 | 740 |
| Sunroof glass and a bracket (plain blocks, no mesh id) | P126, P195 | 24 |

Visibility came from 2.4 million rays at the car from 300 directions,
glass letting them through (`tools/carbody/store_body.py` has the ray code).
`parts.csv` is every part's colour, material, transparency and position as
exported.

The catalog entry was generated from the Studio model: each part's mesh id,
size, centre and rotation relative to the car (origin on the ground under the
wheelbase centre, 0.2505 m a stud so the wheel centres sit on the real 2.775 m
wheelbase).

## Tried and dropped

- Decimating the whole car to 28,452 triangles with
  `tools/carbody/store_body.py`: far worse than the original.
- Cutting to 91,618 by also removing interior parts behind the glass (seats,
  trim tub, console, cabin shells): the owner wants the interior kept.
