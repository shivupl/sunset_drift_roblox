# Kamri '07

A mid-2000s Japanese saloon from the Creator Store (asset 876308553, an
A-Chassis car). Catalog id `kamri07`.

## How it is built

The body is the store model's own meshes, untouched, referenced by mesh id
(BodyBuilder loads them with `CreateMeshPartAsync`, like the Cruiser), so
nothing is uploaded and it works in play and live. 73 of its parts:
**91,618 triangles of the original 158,140.**

Cut in Studio, whole parts only, each cut checked by screenshot from the
outside and through the glass:

| Cut | Parts | Triangles |
|---|---|---|
| Scripts, GUIs, sounds, lights, remotes, seats (not geometry) | 34 scripts and the rest | 0 |
| Invisible parts (light toggles, hubs, sound emitters) | 18 | - |
| Front badge | 2 | - |
| No ray from outside reaches (engine bay, brackets, stacked duplicates) | 23 | about 14,600 |
| Chrome boot strip carrying the maker's oval and lettering | P169 | 4,642 |
| Rear cabin shells and rear door linings | P110, P130, P177 | 9,766 |
| Full-length trim tub, cabin shells | P50, P111, P157 | 19,766 |
| Centre console | P85 | 7,812 |
| Seat set | P158 | 9,972 |
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

Decimating the whole car to 28,452 triangles with
`tools/carbody/store_body.py`: the owner found it looked far worse than the
original. Keep the store meshes and cut whole parts instead.
