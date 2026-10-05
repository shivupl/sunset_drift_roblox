# Exhaust pops, backfires & flames — research for Hajwala VFX/audio variants

Research only. No code/files in the game repo were touched.

---

## 1. Physics and types of exhaust pops/flames

### 1.1 Overrun "pops and bangs" / crackle tune / burble

**Mechanism:** On lift-off (overrun) the ECU normally cuts fuel. A pop-and-bang / crackle / burble tune instead: (a) delays or disables the deceleration fuel cut so injectors keep squirting, (b) heavily **retards ignition timing** during overrun, (c) richens the mixture slightly. The still-burning/unburnt mixture is still combusting as the exhaust valve opens, so it finishes burning in the hot exhaust manifold/downpipe (temperatures commonly quoted **>1,200°F / ~650°C**) instead of the cylinder. [EngineerFix](https://engineerfix.com/what-makes-a-car-exhaust-pop-and-crackle/), [ScienceABC](https://www.scienceabc.com/innovation/how-do-cars-shoot-flames-from-their-exhaust), [FastCar](https://www.fastcar.co.uk/tuning-tech-guides/pop-and-bang-maps/)

**What it sounds/looks like:**
- Light/stock-ish "burble" tunes: **soft, frequent, continuous** popping — more of a rolling crackle than discrete bangs.
- Aggressive crackle maps: **sharper, louder, more irregular** bangs mixed in with the small pops — described as "pop pop pop... BANG... pop pop" rather than a steady beat. [QuantumTuning](https://blog.quantumtuning.co.uk/pops-bang-remap-aka-crackle-or-burble-tuning/), [SleepyTuned](https://www.sleepytuned.com/knowledge-base/what-is-a-burble-tune)
- "Popcorn" mode (on a hard rev-limiter hit) is described explicitly as sounding **like a machine gun** — fast, continuous, evenly-spaced pops rather than the irregular overrun crackle.
- **Decay behaviour:** happens "during and immediately after" lift-off; as road speed/RPM bleeds off and manifold temperature/pressure drops, the pops get sparser and quieter until they stop. No source gives an exact pop-per-second count, but qualitatively it's a dense burst right at lift-off (many pops in the first beat) thinning out to occasional single pops over roughly **0.5–2 s**, consistent with the brief's own estimate — treat 0.5–2 s as the design target for a single lift-off burble, confirmed only qualitatively ("decay as the driver continues decelerating") by sources, not with a hard number. [EngineerFix](https://engineerfix.com/what-makes-a-car-exhaust-pop-and-crackle/)
- Ignition retard numbers given for the related anti-lag case: spark set **35–45° after TDC** (vs. normal ~10–30° BTDC), which is the same lever a milder crackle tune pulls less aggressively. [ScienceABC](https://www.scienceabc.com/innovation/how-do-cars-shoot-flames-from-their-exhaust)

### 1.2 Anti-lag (ALS) bangs — rally/turbo

**Mechanism:** Same unburnt-fuel-in-hot-exhaust principle, pushed much further and done continuously rather than just on lift-off, specifically to keep the turbine spinning against a closed throttle. Ignition retarded **40° or more**; mixture heavily enriched; throttle kept slightly cracked or an auxiliary air injector feeds the cylinders so there's still airflow to combust with. [Rallycars.com](https://rallycars.com/technical-stuff/bang-bang-or-anti-lag-system/), [Antilag system – Wikipedia](https://en.wikipedia.org/wiki/Antilag_system)

**What it sounds/looks like:**
- Much **louder, deeper "explosion" bangs** than a road-car crackle tune — commentators call it "the bang-bang system." Ford/Subaru WRC-style ALS is noted as noticeably "more noisy and aggressive" than Toyota/Mitsubishi tunes of the same era.
- **Large, visible flame/fireball** out of the tailpipe on each bang — "important flames," sometimes a yard-scale jet on full-send rally cars (anecdotal "~2 feet" mentioned for a road car burble, bigger for full ALS).
- **Turbo temperature spikes from ~800°C to over 1,100°C** when ALS is active — this is why it's race-only (street use would cook the turbo/exhaust in **50–100 km**). Manifold pressure with throttle closed can spike to **0 to 0.3 bar** on mild road setups and **up to 1.5 bar** on full race ALS (vs. ~ −1 bar/vacuum at a normal closed-throttle idle) — i.e. the "bang" is a real pressure pulse, not just noise. [Rallycars.com](https://rallycars.com/technical-stuff/bang-bang-or-anti-lag-system/)
- Sonically it's a continuous, slightly irregular **"machine-gun rattle"** while off-throttle (e.g. between gearshifts), not a single pop — closer in character to repeated gunfire than a single backfire. [LS1Tech](https://ls1tech.com/forums/forced-induction/379066-anti-lag-explanation.html)

### 1.3 2-step / launch control — rhythmic bangs on the limiter

**Mechanism:** While stationary (or near-stationary) against the brake, the 2-step holds the engine at a lower "launch" RPM by cutting ignition (preferred, for flames) or fuel on some cylinders/cycles, intentionally dumping unburnt fuel into the headers each time it cuts. [Low-Offset](https://low-offset.com/workshop/2-step-launch-control/)

**What it sounds/looks like:**
- Aftermarket boxes often expose a **"gain"/rate knob** that changes how often the ignition cuts, directly tuning the bang frequency — i.e. the designer picked frequency as *the* knob, which is exactly the kind of parameter a game variant should expose.
- Because the cut is rhythmic (tied to a fixed RPM ceiling and skip-fire pattern rather than the engine's natural decay), the result reads as a **steady, repeating machine-gun burst** of bangs+flames rather than the irregular crackle of overrun pops — the clearest audible/visual distinction between "2-step" and "burble."
- Typical hold time before launch: **2–4 seconds** is "more than enough" per tuners — i.e. a sustained flame-and-bang loop of a few seconds, not a one-off.
- No source gives an exact bangs/second figure. A physically-grounded estimate: at a typical launch RPM of ~3,500–4,500 on a 4-cylinder, full-cycle ignition events occur ~115–150×/s, but 2-step only skip-fires a fraction of those cycles, so the *audible* individual bang rate that reads as "machine gun" to the ear is plausibly in the **~8–20 bangs/second** range (this is a reasoned estimate, not sourced — treat as a tuning starting point, not a cited fact).

### 1.4 Single big backfire "fireball" (rich-mixture bang)

- A true backfire (one big bang, not a tuned pattern) comes from a large, discrete slug of unburnt rich mixture igniting all at once rather than a steady trickle — described as "a loud, destructive explosion," distinct from the "controlled acoustic events" of a pop-and-bang tune. [EngineerFix](https://engineerfix.com/what-makes-a-car-exhaust-pop-and-crackle/)
- Visually: a **mushrooming orange fireball** at the tailpipe, usually trailing **black/grey sooty smoke** afterward — rich mixtures that backfire are consistently associated with black exhaust smoke and a wet, fouled, black spark plug. [Family Handyman](https://www.familyhandyman.com/article/what-makes-a-car-backfire/)
- One anecdotal report: flames **"almost 2 feet" (~60 cm) long**, lasting **2–3 seconds** during engine coasting — useful as an order-of-magnitude anchor for a "big single backfire" visual. [GTPlanet forum, via search synthesis]

### 1.5 Straight-pipe / race-car downshift flame jets

- Achieved by removing the catalytic converter (which would otherwise burn up the unburnt fuel before the tip) plus a throttle-snap or overrun tune, so unburnt fuel reaches the open tip and ignites in open air against ambient oxygen. [CarThrottle](https://www.carthrottle.com/news/heres-how-make-your-car-exhaust-spit-flames)
- Rotary engines are repeatedly singled out as the best natural flame-throwers because they inherently run richer. [CarThrottle]
- **"Shock diamonds"**: this is a supersonic-exhaust phenomenon (rocket/jet afterburner), and no automotive source turned up describes them in car tailpipe flames — car exhaust flow is subsonic even under boost, so shock diamonds are **not** a real feature of car exhaust flames. Skip this for realism; it would only make sense as a deliberately stylised "jet-engine" exaggeration, not a drift-car reference point.
- No hard numbers found for flame length in metres on straight-pipe cars; treat anecdotal "up to ~0.5–1 m" jets on full-throttle-snap big-turbo cars as a plausible visual ceiling, softer than the rocket-flame imagery the name suggests.

### 1.6 Colour physics — why blue vs orange/yellow

- **Blue/violet core:** chemiluminescence from excited **CH and C2 radicals** (and OH) as they relax — this only happens where there's enough oxygen for complete, fast combustion (a leaner, well-mixed flame front). [Illinois Physics Van](https://van.physics.illinois.edu/ask/listing/12501), general combustion-physics search synthesis
- **Orange/yellow outer flame:** **incandescent soot particles** glowing like a blackbody (same mechanism as an incandescent filament), peaking in the yellow/orange band at flame temperatures — this is the signature of a **rich** mixture that doesn't have enough oxygen to fully oxidize the fuel, so it makes soot. [Luminous flame – Wikipedia]
- Practical read for the game: **leaner overrun pops → more blue/white at the core, shorter and "cleaner" looking**; **richer ALS/backfire/2-step flames → bigger, more orange/yellow, sootier, with visible black smoke after** the flame dies. This is the single cleanest rule for differentiating variants by colour.
- No hard numbers for flame-lick duration in ms were found in automotive sources (that scale of detail exists only in combustion-engineering papers on flame-front propagation, not flame *appearance* duration); treat a single visible "lick" as roughly **80–250 ms** (a plausible range inferred from how a camera/eye perceives a single pop-ignited flash, not a cited figure) with the brightest flash front-loaded in the first ~30–50 ms.

### 1.7 Secondary effects worth modelling

- **Ground/bumper light flash**: implied by every "it lights up the night" description of pop-and-bang/ALS videos; practically this is a very short, bright point-light flash timed to the pop's attack, not a sustained glow.
- **Heat shimmer**: not explicitly sourced for exhaust pops specifically, but is a standard real-world byproduct of any sudden hot-gas release; worth a cheap, subtle distortion only on the biggest variant (ALS fireball / big backfire), skipped on quick overrun pops where it wouldn't be visible anyway given the short duration.
- **Sparks / carbon flakes**: real on diesels and heavily sooted systems — "a really hot diesel exhaust will sometimes throw out sparks, but that's mainly accumulated soot that ignites" — i.e. sparks are a **soot/carbon-buildup** effect, appropriate for the richest, dirtiest variant (backfire/ALS), not a clean lean pop.
- **Smoke puff afterward**: directly tied to richness — the sootier/richer the bang, the more black/grey smoke should linger after the flame itself is gone (backfire, ALS, 2-step); a lean overrun pop should leave little to no smoke.
- **Glowing tip**: exhaust tips do visibly heat-glow under sustained hard use (not per-pop, but as a state) — could be a cosmetic/persistent glow under heavy flame-variant use rather than per-event.

Sources for section 1: [ScienceABC](https://www.scienceabc.com/innovation/how-do-cars-shoot-flames-from-their-exhaust), [EngineerFix – pop and crackle](https://engineerfix.com/what-makes-a-car-exhaust-pop-and-crackle/), [EngineerFix – burble tune](https://engineerfix.com/what-is-a-burble-tune-and-how-does-it-work-2/), [Rallycars.com bang-bang](https://rallycars.com/technical-stuff/bang-bang-or-anti-lag-system/), [Antilag system – Wikipedia](https://en.wikipedia.org/wiki/Antilag_system), [Back-fire – Wikipedia](https://en.wikipedia.org/wiki/Back-fire), [Low-Offset 2-step guide](https://low-offset.com/workshop/2-step-launch-control/), [CarThrottle flame guide](https://www.carthrottle.com/news/heres-how-make-your-car-exhaust-spit-flames), [FastCar pop and bang maps](https://www.fastcar.co.uk/tuning-tech-guides/pop-and-bang-maps/), [QuantumTuning](https://blog.quantumtuning.co.uk/pops-bang-remap-aka-crackle-or-burble-tuning/), [Luminous flame – Wikipedia](https://en.wikipedia.org/wiki/Luminous_flame), [Illinois Physics Van – colors of flames](https://van.physics.illinois.edu/ask/listing/12501).

---

## 2. The sound of a sputter/crackle, and how to build it

### Acoustic character (from descriptive sources — no automotive source gives hard ms numbers, so treat the following as a synthesis of consistent qualitative description + standard game-audio transient-design practice):

- Each pop is a **short, sharp transient** — a "crack"/"snap" attack with a fast decay, not a sustained tone. Game-audio practice for comparable transient one-shots (gunfire, firecrackers) uses **single-shot samples in the ~80–300 ms range** (tail included); the "crack" itself (attack + first decay) is typically **well under 50 ms**.
- **Loudness is mixed, not uniform**: small pops and occasional big bangs are interleaved — "lighter tunes produce softer pops... more aggressive tunes deliver sharper, louder bangs," and a crackle map mixes both in the same burst. This is explicitly the "popcorn"/"machine gun" quality described by multiple tuning sources.
- **Spacing is irregular** for overrun crackle (not metronomic) — described only qualitatively ("pop pop pop... bang... pop"), but 2-step/ALS bangs are comparatively more **rhythmic/steady** because they're gated by a fixed RPM/skip-fire pattern rather than a decaying thermal/pressure event. This irregular-vs-rhythmic split is the key acoustic differentiator between the "burble" and "2-step/ALS" variants.
- **Big ("whump") vs small ("crack") distinction**: a big bang (backfire/ALS) carries more low-frequency energy and a felt "whump"/thump (bigger pressure pulse, per the 0–1.5 bar manifold pressure swings noted in §1.2), while small overrun pops are higher-pitched, sharper "cracks" with little low end — model this as two different sample layers (low-passed boomy "bang" layer vs. bright transient "crack" layer), not just volume-scaled copies of one sample.
- **Echo/reverb off buildings**: not sourced specifically for exhaust pops, but is standard urban-acoustic behaviour for any sharp impulsive sound; appropriate as a short slap-delay/early-reflection layer when the car is near walls (matches Hajwala's Riyadh-style city setting) — a cheap way to make bangs feel like they're happening in a real street rather than open desert.

### How games build crackle/burble — synthesis of general game-audio practice (no racing-game-specific GDC talk gave exact numbers, but the mechanism is consistent across sources):

- **Layered one-shots, randomized**: sound teams receive many (e.g. 10+) recorded pop/crackle variations and play them back **randomly per trigger**, each with independent **pitch and volume jitter**, so no two pops sound identical. [Game audio practice synthesis]
- **Granular approach**: treat each pop as a short grain; granular synthesis grains are typically **10–100 ms**, with short grains (1–20 ms) giving a buzzy/glitchy texture and longer grains (50–100 ms) a smoother one — a crackle burst is best built from short-to-medium grains layered at randomized offsets. [Output.com granular synthesis guide]
- **Wwise/FMOD implementation pattern**: a **Random Container** (Wwise) or **Multi Instrument** (FMOD) holds the pop-sample pool; set playback to a **"continuous" trigger-rate mode** so the container keeps firing new random grains at a controllable **randomized interval**, rather than one deterministic loop — this is the standard middleware recipe for "popcorn"/crackle beds. [Forum/dev synthesis on Wwise random containers]
- Forza's own sound model is modular (separate engine layer, exhaust layer, bolt-on layer) with inputs including **throttle position, engine load, boost pressure, gear, clutch, RPM** feeding the mix in real time — the lesson for Hajwala is to drive the *pop density/rate*, not just a binary on/off, from throttle-lift delta and current RPM, so the burble naturally thins out as speed bleeds off rather than cutting abruptly. [GDC Vault — Forza Motorsport 3/5 audio talks, Gamedeveloper.com Forza 6 mix article]

### Recipe to build a "crackle/burble" burst (synthesis, not a single cited source — combines the above):

1. **Pop pool**: 8–15 short one-shot samples per variant (small crack layer + big whump layer), each ~80–250 ms with the transient front-loaded in the first ~20–30 ms.
2. **Trigger pattern**: on throttle lift, fire an initial dense cluster (several pops within the first ~150–300 ms), then space subsequent pops at **randomized intervals that grow longer over time** (e.g. start ~60–120 ms apart, stretching toward ~300–600 ms apart) to simulate thermal/pressure decay — this directly implements the "decays as RPM falls" behaviour described qualitatively by every tuning source.
3. **Per-pop randomisation**: pitch ±5–15%, volume ±3–6 dB, and an occasional (~1 in 5–8) "big one" pulled from the whump layer at full volume to break the pattern — matching the sourced "mixed loudness, some big bangs among small crackles" description.
4. **Overall envelope**: total burst length ~0.5–2 s for a simple lift-off burble (per the brief's own target, consistent with "happens during and immediately after lift-off" sourcing); 2–4 s sustained loop for 2-step/launch (sourced hold time); continuous for as long as off-throttle for ALS.
5. **2-step/ALS should sound more regular** (near-fixed interval, little jitter) vs. overrun burble which should sound **more irregular** (wide interval variance) — this single parameter (jitter amount) is the cheapest way to make the variants read as mechanically different, not just louder/quieter.
6. **Space/echo**: add a short slap-delay bus when near buildings (city) vs. drier in open desert, for free atmosphere differentiation.

---

## 3. How games render exhaust flames well

### Common techniques across NFS/Forza/GTA/drift games (devforum + mod-community synthesis; no single authoritative "official breakdown" article was found for NFS/Forza flame VFX specifically, so this section leans on consistent patterns across GTA5 modding docs, Roblox devforum practice, and general particle-VFX convention):

- **Bright core + additive outer glow**: a small, near-white/blue hot core particle layered under a larger, softer additive orange/yellow glow billboard — this maps directly onto the real colour physics in §1.6 (blue chemiluminescent core, orange sooty glow outer).
- **Flipbook/sprite-sheet animated flame textures** rather than a single static blob — gives the flame internal motion (licking, flickering) instead of reading as a static sprite. Roblox natively supports this via `ParticleEmitter.FlipbookLayout` (Grid2x2/4x4/8x8/Custom) and `FlipbookMode`, with `FlipbookFramerate` (up to 30 fps, randomizable min/max) controlling playback speed. [Roblox creator docs — particle emitters](https://create.roblox.com/docs/effects/particle-emitters)
- **Velocity-aligned / stretched billboards**: orienting the flame particle along the exhaust-gas direction (`VelocityParallel` orientation in Roblox) makes a flame read as a directional jet rather than a puffball — this is the single biggest "looks cool vs. looks like a spark" lever. A flame that doesn't stretch along its direction of travel reads as a generic spark/explosion, not a jet.
- **Emissive light flash tied to the pop**: a very short-lived `PointLight` brightness spike timed to each bang (not a sustained light) sells the "this just exploded" moment and lights the ground/bumper/nearby geometry for a frame or two — matches the "it lights up the area" quality real pop-and-bang footage has.
- **Burst emission, not continuous drizzle**: using `Emit(n)` to fire a discrete burst of particles per pop (rather than leaving the emitter continuously running) reads as "more intentional and less like a flickering lightbulb" — directly applicable to making each pop look like a discrete event rather than a mushy continuous flame. [Roblox particle-script community guide synthesis]
- **Smoke/soot trail after the flame**: a slower, longer-lived grey/black smoke puff emitted just after the bright flame particle dies sells the richer/sootier variants (backfire, ALS) per the real soot-smoke correlation in §1.4; the lean variant should emit little to no smoke.
- **Heat-shimmer/distortion**: a cheap refraction or UV-distortion plane right at the tip is a "cool" upgrade reserved for the biggest variant — not required for a quick lean pop where it wouldn't be visible at that duration anyway.
- **Sparks**: a handful of small, fast, gravity-affected bright particles (not flame-shaped) read as "carbon flakes" kicked out of a sooty system — appropriate for the richest/dirtiest variant only (§1.7), since real sparks are a soot-buildup effect, not a universal flame feature.

### Roblox-specific implementation notes (devforum-sourced):

- `FlipbookLayout` + `FlipbookMode` + `FlipbookFramerate` (max 30 fps, can randomize min/max) drive the sprite-sheet animation. [Roblox creator docs](https://create.roblox.com/docs/effects/particle-emitters)
- `LightEmission` (0–1) switches a particle into additive blending — essential for a flame to glow rather than look like a flat decal; `LightInfluence` controls how much scene lighting tints the particle vs. it staying pure emissive.
- `Squash` (non-uniform scale over lifetime) is explicitly recommended for "rising flame" shapes.
- `ColorSequence`/`Transparency` over lifetime should fade in/out at both ends to avoid a "popping" artifact when the particle spawns/dies.
- Mobile performance guidance: cap emission around **~100 particles/second**, and prefer shrinking size/transparency over spawning more particles, since particle overdraw is the dominant mobile cost — directly relevant given Hajwala's existing mobile-perf concerns (see MEMORY.md skyline-streaming-split note).
- For position/attachment: parent exhaust-flame emitters to `Attachment`s (not raw Parts) for precise placement and easy per-variant swapping; use `Debris:AddItem` to auto-clean one-shot burst emitters.
- Beams (`Beam` instance between two `Attachment`s, `FaceCamera` on, low `TextureSpeed`) are the standard Roblox tool for a stretched jet-flame streak if a flipbook-billboard alone looks too flat/round — worth layering a thin Beam under the flipbook particle for the "jet" variants (ALS/straight-pipe).
- GTA5 modding community independently arrived at the same "large/medium/small variant" structure for backfire particle effects (reverse-engineered vanilla "scr_carsteal5_car_muzzle_flash" style particles), reinforcing that discrete size/intensity tiers (not one scalable effect) is the standard approach for multiple flame "looks." [GTA5-Mods Volumetric VFX notes]

Sources for section 3: [Roblox creator docs — particle emitters](https://create.roblox.com/docs/effects/particle-emitters), [Roblox devforum — recreate effect with ParticleEmitter](https://devforum.roblox.com/t/how-to-recreate-this-effect-with-a-particleemitter/1288681), [Roblox devforum — campfire particle tutorial](https://devforum.roblox.com/t/using-particles-to-make-a-campfire/1750488), [robloxparticlescript.pages.dev guide](https://robloxparticlescript.pages.dev/posts/roblox-particle-script/), [GTA5-Mods — Exhaust Backfire FX](https://www.gta5-mods.com/misc/exhaust-flame-burst-for-addon-cars-1-0), [GTAForums — trigger backfire](https://gtaforums.com/topic/876855-c-how-to-trigger-backfire-on-exhaust/).

---

## 4. Proposed VARIANTS

Each variant pairs a distinct **look** with a distinct **sound pattern** so they read as different mechanisms, not just "more/less of the same effect." Jitter amount and colour/richness are the two cheapest levers that make them feel mechanically different.

### A. "Crackle / Burble" (road-tune overrun pop)
- **Trigger:** throttle lift at moderate-high RPM.
- **Look:** small, mostly **blue-white core flicks** at the tip, occasional faint orange edge; no smoke; no sparks; subtle/no light flash (just barely catches the eye). Flame "lick" very short, ~80–150 ms, low profile — reads as a glimpse, not a shot of fire.
- **Sound:** irregular interval (wide jitter, 60–300 ms+ between pops, growing further apart), mostly small "crack" layer with rare small bangs mixed in, total burst **0.5–2 s** decaying to nothing as RPM falls. Dry/high-pitched character — "popcorn" rather than "gunfire."
- **Basis:** §1.1, §1.6, §2 recipe.

### B. "Anti-Lag Fireball" (ALS bang)
- **Trigger:** sustained off-throttle at high RPM / holding a gear with the throttle shut (e.g. mid-drift lift, pre-corner).
- **Look:** large, **orange/yellow mushrooming fireball**, visibly bigger and sootier than the burble, trailing a **puff of grey-black smoke** after each bang; a real **point-light flash** on the ground/bumper per bang; occasional spark/carbon-flake kick. Flame can reach the biggest size of all variants (closest to the sourced "~2 ft" backfire anchor, scaled up for ALS's bigger pressure pulse).
- **Sound:** louder, lower, "whump"-heavy bangs — continuous machine-gun rattle while sustained, **fairly steady rhythm with only moderate jitter** (not as metronomic as 2-step, not as ragged as burble). Add a short room/slap-echo layer when near city buildings.
- **Basis:** §1.2 (800→1,100°C turbo spike, up to 1.5 bar, "important flames," "noisy and aggressive").

### C. "2-Step Machine Gun" (launch control)
- **Trigger:** stationary, on the brake, holding the limiter before a launch.
- **Look:** rhythmic, **evenly-spaced** flame pulses — medium-orange, shorter than ALS's fireball but more frequent and more *regular* looking (same size/shape repeating), like a strobing jet rather than one big fireball. Light flash per pulse, synced tightly to the beat.
- **Sound:** the most **rhythmic/regular** of all variants — near-fixed interval, minimal jitter, genuinely reads as "machine gun fire" (reasoned estimate ~8–20 bangs/sec, tune to taste/feel target). Sustained for the **2–4 s** hold before launch, then cuts cleanly on launch rather than decaying.
- **Basis:** §1.3 (gain/rate knob as the designed parameter, 2–4 s hold time, "machine gun" description).

### D. "Blue Lean Jet" (straight-pipe / high-rpm clean overrun, stylised)
- **Trigger:** sustained high-rpm overrun/downshift on a straight-piped, no-cat setup — the "cleanest" look, for a stylised/premium car flavor rather than a dirty bang.
- **Look:** a longer, **narrower, mostly blue-to-white jet** stretched along the exhaust direction (velocity-aligned billboard + thin Beam underlay), minimal orange, no soot/smoke, no sparks — the leanest, most "complete combustion" look of the set, longest sustained jet shape (continuous rather than discrete pops) rather than the biggest single flame.
- **Sound:** fewer, sharper individual cracks rather than a dense burst — higher-pitched, "cleaner," less bass than the ALS whump; can be nearly continuous as a thin crackling hiss-crackle rather than discrete separated bangs.
- **Basis:** §1.5 (straight-pipe/no-cat flame jets), §1.6 (lean → blue, complete combustion). Note: deliberately skips "shock diamonds" since that's not a real car-exhaust phenomenon (§1.5) — keep the jet smooth/continuous rather than beaded, to stay closer to reality while still reading as distinct and "premium."

---

## Key source list

- [EngineerFix — What Makes a Car Exhaust Pop and Crackle?](https://engineerfix.com/what-makes-a-car-exhaust-pop-and-crackle/)
- [EngineerFix — What Is a Burble Tune and How Does It Work?](https://engineerfix.com/what-is-a-burble-tune-and-how-does-it-work-2/)
- [ScienceABC — How Do Cars Shoot Flames From Their Exhaust?](https://www.scienceabc.com/innovation/how-do-cars-shoot-flames-from-their-exhaust)
- [Rallycars.com — Bang-Bang, or Anti-Lag System](https://rallycars.com/technical-stuff/bang-bang-or-anti-lag-system/)
- [Wikipedia — Antilag system](https://en.wikipedia.org/wiki/Antilag_system)
- [Wikipedia — Back-fire](https://en.wikipedia.org/wiki/Back-fire)
- [Low-Offset — 2-Step Launch Control & Rev Limiters Explained](https://low-offset.com/workshop/2-step-launch-control/)
- [CarThrottle — Here's How To Make Your Car Exhaust Spit Flames](https://www.carthrottle.com/news/heres-how-make-your-car-exhaust-spit-flames)
- [FastCar — Pop and Bang Maps Guide](https://www.fastcar.co.uk/tuning-tech-guides/pop-and-bang-maps/)
- [QuantumTuning — Pops & Bang Remap AKA Crackle OR Burble Tuning](https://blog.quantumtuning.co.uk/pops-bang-remap-aka-crackle-or-burble-tuning/)
- [SleepyTuned — What Is a Burble Tune?](https://www.sleepytuned.com/knowledge-base/what-is-a-burble-tune)
- [Wikipedia — Luminous flame](https://en.wikipedia.org/wiki/Luminous_flame)
- [Illinois Physics Van — Colors of Flames](https://van.physics.illinois.edu/ask/listing/12501)
- [Family Handyman — What Makes a Car Backfire?](https://www.familyhandyman.com/article/what-makes-a-car-backfire/)
- [Roblox Creator Docs — Particle Emitters](https://create.roblox.com/docs/effects/particle-emitters)
- [Roblox Devforum — How to recreate this effect with a ParticleEmitter?](https://devforum.roblox.com/t/how-to-recreate-this-effect-with-a-particleemitter/1288681)
- [robloxparticlescript.pages.dev — Roblox particle script guide](https://robloxparticlescript.pages.dev/posts/roblox-particle-script/)
- [GTA5-Mods — Exhaust Backfire FX](https://www.gta5-mods.com/misc/exhaust-flame-burst-for-addon-cars-1-0)
- [GDC Vault — Making a Car Sound Like a Car (Forza Motorsport 3 audio)](https://www.gdcvault.com/play/1012692/Making-a-Car-Sound-Like)
- [GameDeveloper.com — Simulating the Race Day Experience: Mixing Forza Motorsport 6](https://www.gamedeveloper.com/audio/get-into-the-mix-of-i-forza-motorsport-6-i-s-audio-at-gdc-2016)
- [Output.com — Granular Synthesis: How It Works and When to Use It](https://output.com/blog/granular-synthesis)

**Caveat:** numbers marked "reasoned estimate" or "not sourced" above (pop-interval ms, bangs/sec for 2-step, single flame-lick duration) are not given by any source found — automotive forums/articles describe these qualitatively ("irregular," "machine gun," "decays") rather than numerically. Treat those as starting points for in-Studio tuning by ear/eye against the owner's feel targets, not as facts to defend.
