# HAJWALA — Game Design Overview

**Working title:** Hajwala | هجولة
**Platform:** Roblox (mobile-first, PC, console)
**Genre:** Vehicle sim / competitive drift / social hub
**Developer:** Solo (Shiv), with one Gulf-based community partner
**Target audience:** Gulf teens and young adults, 13–24, primarily Saudi Arabia, then UAE, Kuwait, Qatar, Bahrain, Oman
**Goal:** 500–800 concurrent players sustained, ~$5K/month net, within 4–6 months of launch

---

## 1. The one-line pitch

Drift on real Riyadh highways, tune your car until it's yours, and get judged by the crowd every ten minutes. The best hajwala game on Roblox, built for the people who actually do it.

## 2. What hajwala is

Hajwala (هجولة, also *tafheet*) is Saudi street drifting culture. Drivers slide sedans sideways at speed down highways while crowds line the road and film. It's a huge youth scene on TikTok and YouTube across the Gulf, with its own slang, its own cars (Camry, Caprice, Crown Victoria, Lexus LS, Hilux, Yukon), and its own stars. It is competitive, visual, and social by nature.

## 3. Why this game, why now

Roblox search data (Sept 2026):

- Three live hajwala games pull a combined **30–40K new players per day** but keep only ~800 online at any time. They have no objective, no progression, and stores with one or two items.
- Ten more hajwala games sit at zero players. The theme alone doesn't work; the loop has to.
- The biggest Gulf Roblox game, **Kingdom World** (Riyadh city roleplay), holds ~2.5K concurrent by giving players things to own and show off. It has weak driving.
- Roblox's own data says the 18–34 audience is its fastest-growing and highest-spending segment, and Gulf countries have high purchasing power.

Nobody has combined good drift physics, a reason to come back, and a status layer. That's the gap.

## 4. Core loop

```
Drive → Score → Rank up → Earn cases → Customize → Get seen → Drive again
```

1. **Drive.** Spawn already in a car on the highway. No menus. Drift, two-wheel, chain combos. Score is on screen from the first second.
2. **Score.** Live drift score: angle × speed × duration × proximity to the crowd line. Your best and the server best are always visible.
3. **Rank up.** Seasonal ranks: Bronze → Silver → Gold → Diamond → Malik (King). Rank shows above your car.
4. **Earn cases.** Ranked sessions and weekly leaderboard placement pay out cosmetic cases. Plus one free daily case with a streak bonus.
5. **Customize.** Plates, wraps, rims, underglow, exhaust flames, horns, titles. Cosmetic only, never performance.
6. **Get seen.** 30-player servers, voice chat, a kashtah camp hub where cars park and people hang out. Everything you own is visible to everyone.

## 5. Key features

### Driving and tuning
- Drift and two-wheel physics tuned to feel like the real clips. This is the core technical advantage over every existing game.
- Real tuning: suspension, gearing, tire pressure, weight, aero. A car you spent an hour dialing in is a car you come back for.
- Real Riyadh roads: Al Quwat, Al Furusiya, the Diriyah ring, King Khalid Road. Players recognize them.
- Runs at 60 fps on mid-range Android with 30 cars on screen. Most of the audience is on phones.

### Tafheet sessions (ranked, crowd-judged)
- Every 10 minutes the server announces a session at a marked stretch of road.
- 2–4 drivers get 60 seconds each. Everyone else is teleported roadside as crowd with a phone-camera view.
- **Score = 50% crowd vote, 50% system score.** Votes are weighted by rank. No voting for your own crew. Ties go to system score.
- Winner gets rank points, cash, a case, and a title over their car until the next session.
- Under 8 players: runs on system score only so the feature never depends on a crowd that isn't there.
- **Auto replay** of the winning run from the best angle with score overlay. Built to be screen-recorded and posted.

### Plates (the status product)
Gulf plate culture is real: single-digit and repeating-number plates sell for six and seven figures in the UAE and Saudi. Nobody has built this on Roblox.
- Plate styles by country (Saudi, Dubai, Abu Dhabi, Kuwait, Qatar, Bahrain, Oman).
- Custom text plates, run through Roblox's text filter.
- **Numbered plates with global uniqueness.** One "7" exists in the whole game. Single digits auctioned after launch; doubles, triples, and patterns sold at tiered prices.
- In-game auction house for plates. Players trade; the game takes 10%.
- Rank-locked plates (Malik gets a gold frame you can't buy). Earned status next to bought status.
- Plate shows on car, profile, and leaderboard.

### Cases
- Free daily case, streak bonus, day 7 guaranteed rare.
- Earned cases from ranked and weekly placement.
- Cosmetics only. Rarity tiers with visible odds. Legendary items visible from across the server.
- Rare pulls announce server-wide. Duplicates scrap into crafting.
- Seasonal cases (Ramadan, National Day) with retired exclusives.

### Kashtah camp (social hub)
- Desert camp: tents, fire, trucks, tea, mic chat. The garage and the hangout in one place.
- Where cars get parked, plates get compared, and crews form.
- Added after launch once retention exists; not in the first build.

### Crews
- Crew tags on cars and plates. Crew leaderboard. Crew-only voice.

## 6. Progression

- **Cash** from drifting, stunts, sessions. Buys cars and upgrades.
- **Rank points** from sessions. Seasonal reset every ~8 weeks. Rank badge over the car, on profile, on leaderboard.
- **Collection**: plates, wraps, rims, titles. A garage screen that's basically a trophy room.
- **Weekly leaderboard** per server region and global. Top 10 get a case and a title.

## 7. Monetization

Cosmetics and status first. Cash packs because they work in car games. Never sell driving performance; it would kill ranked.

**Launch store**
| Item | Robux |
|---|---|
| Cash packs | 19 – 1,099 |
| x2 Cash pass | 129 |
| Plate style (per country) | 49–99 |
| Custom text plate | 149 |
| Wrap pack | 199 |
| Car packs (Luxury / Classic / Truck) | 149–299 |
| Premium (chat tag, discount, exclusive plate style) | 449 |
| Case re-open (max 2/day) | 49 |

**After 500 CCU**
- Numbered plate auctions (single digits, patterns). Whale product.
- Direct purchase of legendary cosmetics alongside cases.
- Seasonal cosmetics, retired after the event. Retired items become status by themselves.

**Reference points:** Kingdom World earns an estimated $8–30K/month on 2.4K CCU with a mediocre store. Highway Drifting earns ~$2–5K on 211 CCU with a bad game and good pricing. This design needs ~500–800 CCU for $5K/month.

## 8. First 60 seconds

1. 0–10s: spawn in a car on the highway. Prompt: "Hold Shift, drift."
2. 10–40s: first drift scores. "Your best: 340. Server best: 8,200."
3. 40–60s: "Tafheet session in 2:00 at Km 4. Enter?"
4. End of session: saw the crowd, saw a winner with a title, got placed Bronze, offered one cheap plate. "Next session in 8:00."

Every step answers: what do I do, how am I doing, who am I against, what do I get, why come back.

## 9. Build plan (six-week vertical slice)

| Week | Deliverable |
|---|---|
| 1–2 | Vehicle chassis, drift + two-wheel physics, one car. Tune until it feels right. |
| 3 | One highway loop, drift scoring HUD. First Gulf testers in. |
| 4 | Garage: plate system, 3 wraps, cars 2 and 3. Cosmetic slot system. |
| 5 | Tafheet sessions, ranks, daily cases. Arabic localization. |
| 6 | Mobile controls, performance, thumbnail, launch. |

**Cut from v1:** city, jobs, police, economy, kashtah camp, crews. All come after retention is proven.

**Tech:** Rojo-synced repo, AI-assisted coding for systems, physics tuned by hand.

## 10. Localization and community

- English-first build, Arabic title, thumbnail, UI, and store. Gulf dialect, not machine-translated formal Arabic.
- **One Gulf partner** (Saudi/Kuwaiti, late teens to twenties, lives in the scene) on rev-share or monthly fee. Owns localization, community, creator relations, car list, cultural detail. Recruited with the week-4 demo. Also the first ten testers.
- Discord from week 3.

## 11. Launch

- Thumbnail: sideways car on a Riyadh highway at night, Arabic title.
- One Arabic Roblox creator posting on launch day, seeded from the Hajwala X / Kingdom World creator circle.
- Like-for-code milestones at 1K, 5K, 10K.
- Updates every 3–4 days for the first two months. Roblox's algorithm and the community both reward it.
- Expect two quiet weeks. Discovery on Roblox is slow and can fail; the plan mitigates, not guarantees.

## 12. Milestones and decision points

- **500 CCU sustained**: #1 hajwala game. Open plate auctions.
- **2K CCU**: Kingdom World scale, ~$10–30K/month. Add the city layer.
- **Under 150 CCU after 6 weeks of daily updates**: the loop is wrong. Keep the engine, pivot the skin.

## 13. Expansion

The engine (physics, tuning, ranked, plates, cases) is skin-independent. Map, car list, language, and cosmetics are data.

- **Skin 2: Brazil.** Rebaixados (lowered cars, air ride, sound systems) and grau (motorcycle wheelies). One live incumbent at 1.5K in pre-alpha; grau scene at ~3.5K across five games. Bigger market, lower spend.
- **Skin 3: Indonesia.** Largest regional driving audience on Roblox (4K+ across several games), lowest spend.
- **Gulf depth:** kashtah camp, Riyadh city layer, Dubai supercar tier, Ramadan/National Day seasons.

One game at $5K/month is the floor. A regional car-game studio is the ceiling.

## 14. Risks

| Risk | Mitigation |
|---|---|
| Discovery never fires | Creator seeding, update cadence, thumbnail; pivot skin if dead after 6 weeks |
| Physics don't feel right | Weeks 1–2 are only this; Gulf testers by week 3 |
| Cultural miss | Partner owns car list, slang, Arabic; nothing cultural ships without their sign-off |
| Vote manipulation in sessions | Rank-weighted votes, crew lockout, 50% system score |
| Random-item policy | Cases are free/earned; check Roblox's current paid-random rules before selling anything random |
| Solo dev burnout on 3-day updates | Data-driven cosmetics so updates are content, not code |
