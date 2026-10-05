# Drift overhaul research: drift physics, throttle bursts, hajwala 360s, how games do it

Round 2, 2026-10-05. This builds on `2026-10-05-drift-feel-research.md` (round 1: technique names, Focus RS 70 % rear, Forza, CarX and Assetto Corsa tuning knobs, the tafheet overview) and does not repeat it. Round 2 adds measured numbers.
A claim marked **(inferred)** is my own reasoning or arithmetic; everything else is stated by the linked source. Links use reference keys; the URLs are listed at the end.
Sign convention: β is the body sideslip (the drift angle), δ is the front wheel angle, and a negative δ next to a positive β means countersteer.

---

## A. Steady-state drift physics

### A1. Measured and computed drift equilibria
| Source | Vehicle / surface | Radius | Speed | Sideslip β | Yaw rate | Steer δ | Drive |
|---|---|---|---|---|---|---|---|
| Velenis, expert rally driver [V10] | 1980 Escort, 110 bhp RWD + LSD, dirt on tarmac | ≈13 m | 8.1 m/s (29 km/h) | 31.4° | 36°/s | 12.5° countersteer | throttle "close to the maximum" |
| Hindiyeh P1 controller [H13] | by-wire RWD testbed | – | 8 m/s | 20.4° | 0.6 rad/s (34°/s) | −12° | FxR 2293 N; drifted >30 s, β error "rarely exceeding 3–5°" |
| Velenis model, Table 2 [V09] | 1450 kg single-track model | 7 m | 7 m/s | 10.4° / 51° | – | +3.2° (into the turn) / −40.7° (countersteer) | rear slip ratio 0.29 / 0.75 |
| Edelmann field test [Ed08] | 2066 kg SUV, AWD switched off, watered asphalt (µ≈0.59) | 50 m | 57–61.4 km/h | – | – | countersteer | ESC off |
| Edelmann driver model [Ed11] | 4-wheel RWD model | 100 m | – | ≈25–27.5° (plot axis) | 10–17.5°/s (plot axis) | −10 to −25° | 0–3 kNm pulses |
| Goh, MARTY [Goh16] | RWD DeLorean, electric rear motors | varying | – | up to 45° | – | – | path tracked at 45° |
| Goh et al., TRI [Goh24] | test car, Thunderhill | slalom | – | peak >55° | peak >1.5 rad/s (86°/s) | – | rear tyres "fully sliding throughout" |
| Path-following drift [Lat26] | Mercedes-AMG GT 63 S | figure-8 | 12.6–14.4 m/s | target 0.6 rad (34°) | ≤0.95 rad/s | lock 34° | – |
| Eberhart AWD study [Eb25] | AWD model, µ=1 | 60 m | – | 35° | – | see A5 | rear share 27–100 % |

Rear wheelspin in a drift, from [V09] Table 2: rear tyre surface speed ÷ road speed (computed from ω_R·r/V) is **1.37×** at β=10°, **1.74×** at 29°, **2.07×** at 51° (R=15 m) and **2.5×** at 51° (R=7 m). That drives engine rpm flare, tyre smoke and audio.

### A2. What controls the drift angle and what controls the path
- **Rear drive force sets the angle.** Once the rear tyre is saturated it sits on its friction circle, FyR = √((µFzR)² − FxR²), so ∂FyR/∂FxR = −FxR/|FyR|. More drive force means less rear lateral force, so the car yaws and β grows. [H13] Edelmann puts it in words: "Pushing vigorously the accelerator pedal of a RWD vehicle during cornering reduces the lateral forces of the rear axle … causing a large sideslip angle" [Ed25].
- **Throttle authority grows with angle.** FxR/|FyR| "increases monotonically with |βeq|", so at a 20° drift the rear-force input is an order of magnitude stronger than in limit grip cornering. There are "actually two effective inputs for lateral control". [H13] Measured drivers use both inputs, and in a powerslide (unlike regular cornering) both are effective. [Ed11] [TUW]
- **The jobs split.** Stanford's controllers treat yaw rate as the input that steers β, coordinated through steering and rear drive [H13]. MARTY uses the rotation rate of the velocity vector for the path and yaw acceleration for β [Goh16]. On the AMG, steering mainly controls yaw and β, and rear torque sets the thrust angle of the saturated rear tyres [Lat26]. In driver terms: the throttle holds the angle, and the wheel aims the car.
- **Countersteer tracks the angle.** At a given radius, more β needs more countersteer [Sun25]. The required rear torque rises "in a quite proportional manner" with countersteer angle [Ed25]. At high β, more speed needs less countersteer [V09] [Ed08].
- **Higher angle can mean higher speed.** On tight radii the fastest equilibria are at the larger sideslip angles [V10], and the same holds for front-drive handbrake drifts [V11].

### A3. Stability: why players need help
- **Every drift equilibrium is open-loop unstable** (a saddle point) [H13] [Ed09] [Ed25].
  - P1 at 8 m/s, 3-state model: poles at +2.774, +0.137 and −9.742 1/s, so an uncorrected error grows by e every **≈0.36 s** [H13].
  - Velenis' cases: an unstable pair at 0.75 ± 1.14i (β=10°) and 0.58 ± 0.72i (β=51°), which is an e-folding time of 1.3–1.7 s and a 0.11–0.18 Hz wobble [V09].
  - (inferred) The 2-state pole ½(−c1+√(c1²+4c0)) tends to √(aC̃αF/Iz) as speed rises, so the ≈0.35 s divergence does not get easier at highway speed.
- **The stable band is tiny.** The SUV's powerslide is stable only within 0.1 km/h of its maximum speed, so "a permanent steering (and throttle) correction" is needed [Ed08].
- **Human control rates.** Expert drivers' steering moves from 0.3–0.6 Hz in normal driving to **≈1 Hz in a powerslide**. Reaction time is modelled as 0.1 s, and the driver previews 7.5 m ahead instead of the normal 30 m. [Ed11] Rear-torque "power thrusts of the driver when drifting" are an effective stabiliser [Ed25].
- **Latency budget.** More than **95 ms** of actuation latency makes drift oscillations "catastrophic" unless the controller predicts ahead. The AMG's measured delays are 140 ms for steering and 280 ms for engine torque, and the fix predicts about 170 ms ahead. [Lat26]
- **Fixed inputs end in a donut.** With steering and throttle frozen, the car first spins in or out. It then settles into a stable small-radius circle (very large countersteer plus large torque: a donut) or a "flower-like" limit cycle. On snow this took δ≈−9° with 1000 Nm of rear torque, or δ≈−38° with 1350 Nm. [Ed25]
- The trade-off: rear-tyre saturation costs open-loop stability but adds direct throttle control over the car's sideways motion [H13].

### A4. How speed is kept
- In a steady powerslide the driver holds near-full throttle and speed stays constant: 8.1 m/s for 15 s [V10]. A powerslide needs more drive torque than grip cornering (it is less efficient) but reaches slightly higher lateral g [Ed25].
- **RWD strategy:** cut the drive torque to reduce β, and speed falls with it. Speed then settles on its own ("velocity zero-dynamics"). [Eb25]
- (inferred) Speed bleed with no drive: a saturated, rolling rear axle drags at about share_r·µ·g·sin β along the path. For 40 % rear weight and µ=0.9 that is 1.8 m/s² (6 km/h per second) at 30°, 3.1 m/s² (11 km/h/s) at 60°, and up to µg (32 km/h/s) fully sideways. A locked rear (lever held) drags at about share_r·µ·g, so 3.5 m/s², 13 km/h/s.

### A5. Front drive and all-wheel drive
- **A front-drive car cannot hold a power drift.** Steady states with front drive (T_F>0) need rear braking (T_R<0), "for instance by application of the handbrake". [V09] Examples:
  - R=7 m, 6.1 m/s, β=29°, δ=−13.7°.
  - R=15 m, 8.65 m/s, β=33°, δ=−21.5°.
- **Front-drive handbrake cornering.** Expert data in a rally car on gravel [V11]:
  - The handbrake goes on for about **1.5 s** (1.5–3 s, then 9.5–11 s), with no front brake, to kill understeer.
  - It reaches a 1 m instantaneous radius against a 4.5 m full-lock radius, and sideslip peaks around 30–35° (read from the plot).
  - After release the driver "did not counter-steer": he applied throttle and unwound the wheel to straighten.
- **Front-drive handbrake equilibria** [V11]:
  - Higher speed comes with higher β.
  - At R=1 m the wheel points into the corner; at R=5 m, β beyond 12° needs countersteer.
  - At R=1 m, β>47° (the fastest states) is **stable**: a held-lever front-drive donut can sit on its own.
- **For a front-drive car on a tight hairpin the handbrake is time- and space-optimal**, independent of the vehicle data [Tav14].
- **All-wheel drive** [Eb25], at β=35°, R=60 m:
  - Powerslides exist from 100 % rear down to only **27 % rear**.
  - Large countersteer is needed while the rear share γ > 0.43. Below that much less is needed, and below 0.39 the wheel points into the corner.
  - Speed peaks at γ≈0.43. Up to three equilibria exist per β.
  - **The strategy flips at about 25:75 front:rear.** More rear-biased than that, the car follows the RWD strategy: more torque, more angle. Less rear-biased, it follows the AWD strategy: more torque gives **less** β and yaw, and **more speed**, because the front drive "overcompensates" the rear's lost grip. This "coincides with anecdotal knowledge from expert drivers".
  - Their assist ramps target β to 35° at 10°/s by moving all torque rearward. A driver on dry asphalt then tracks R≈20 m "solely by steering".

## B. Throttle bursts

- **Gas widens, lift tightens (RWD).** "If you lift off the throttle you'll reduce drift angle, and if you put your foot down, you'll increase it" [D61]. The physics is A2.
  - **Transition:** over-rotate slightly, then lift; the rear regains grip and swings the car the other way [D61].
  - (inferred) The response time is set by the ≈0.35 s instability (A3) plus engine lag (≈0.28 s on a turbo V8 [Lat26]). A stab therefore shows up as angle change within 0.3–0.6 s, and feathering at the ≈1 Hz drivers use [Ed11] is the natural rhythm.
- **Throttle-to-angle mapping tested on people** [Sun25], a 4WD drift assist with 34 drivers:
  - Target β = 25° + 10°·throttle (0–1); speed is held by a separate controller.
  - Full gas for 2 s arms drift mode.
  - Three β build-up rates were tested; the extracted table lists τ = 0.5, 1 and 1.5 s against "low", "medium" and "high" rate. That pairing is ambiguous: with β̇ = (βd−β)/τ, a larger τ is slower.
  - Failure rate (spin or leaving the track): **2.9 %** at the slowest build rate, 16 % at the middle one, **25 %** at the fastest. Ratings were 3.98 / 3.44 / 2.69.
  - A slower β build-up "allows the drivers better preparation to counter-steer".
- **Clutch kick:**
  - Procedure: clutch in, raise rpm "by about 3,000", release quickly, stay on the throttle. It works at initiation and "mid-drift if the car starts to regain grip". [TDA]
  - Weaker source: windows of 4,500–5,500 rpm in 2nd at 20–35 mph and 5,000–6,000 rpm in 3rd at 40–55 mph [ESB].
  - Definition: "the clutch is 'popped-up' to give a sudden jolt through the driveline to upset rear traction" [F1D].
  - Shift-lock is the opposite: let revs drop on a downshift and release, which slows the rears [F1D].
  - (inferred) Engine and flywheel at about 0.1–0.2 kg·m² ([FW] gives 0.114), dumped from +3000 rpm (314 rad/s) in about 0.2 s, add 160–310 Nm at the crank, about 1× a sedan's engine torque. So the kick is roughly a **2× drive-torque pulse for 0.15–0.3 s**. That collapses rear lateral grip (A2), worth an estimated +8–15° in about 0.4 s.
- **Power-over initiation:** full throttle at corner entry for heavy oversteer [F1D]. A beginner guide suggests about 30 mph (48 km/h), 2nd gear, about 3000 rpm [MyT] (weak source). It needs power, and it is impossible in front drive (E).
- **Weight-transfer entries** [F1D]:
  - Feint: rock the car outward, use the rebound to throw it in.
  - Kansei: lift very fast at a high-speed entry.
  - Braking drift: trail-brake into the corner, then balance.
- **Trail braking, from a rally school** [V07]: 60 mph at 90 % brake with the wheel straight, then 45, 35, 30 mph as braking eases (70 → 30 → 10 %) while steering builds 10° → 60° → 90°. At the apex: countersteer plus throttle "to stop rotation".
- **Pendulum (Scandinavian) turn** [V07]:
  - Sequence: lift; steer away and progressively brake; release and steer in; accelerate and countersteer.
  - It is "not applied for high center of gravity vehicles or on paved roads".
- **Handbrake initiation, measured** [Goh24]:
  - Rear wheel speed drops to 0 and yaw rate peaks at about **1.2 rad/s (69°/s)**.
  - Countersteer is applied fast. The whole thing takes **under about 1.2 s (≈5 car lengths)**, then hands over to the throttle at β≈40° and 0.5 rad/s.
- **Locked rears plus a steering step versus steering alone** [Ac17]: yaw acceleration 384 against 197 °/s², 90° of heading in 3.0 against 3.7 s, and β rate 35.5 against 16.6 °/s.
- (inferred) Load transfer on a lift or brake is ΔFz = m·a·h/L. For a Camry-like car (h/L≈0.2, 40 % rear weight), the rear load falls about 0.5 %/(0.01 g): **7–15 % for a lift** (0.15–0.3 g of engine braking) and **≈40 % for hard braking** (0.8 g). That is the lever behind lift-off throws and braking drifts.

## C. Hajwala / tafheet specifics

### C1. Vocabulary
| Term | Meaning | Source |
|---|---|---|
| تفحيط tafheet = تقحيص / تشحيط / تفحيص / تمتيع ; هجولة hajwala | regional synonyms for the whole practice | [AB] |
| نطلة / تنطيل natla, tanteel | the skid; repeated slides with opposite lock at 160–260 km/h | [Men] [WikiT] |
| عقدة ʿugda "knot" (likely Wikipedia's "Ta'geed" (inferred)) | the 360, also "looping" | [Men] [AGSI] [WikiT] |
| عكسية ʿaksiya "opposite" | the hardest figure; 180°-and-back to a full 360 | [Men] [WikiT] |
| سفتي sefti "flashing light" | opposite plus knot, i.e. a 360 one way and then the other with a short slide between | [Men] [WikiT] |
| ردة الوجه raddat al-wajh | "face turn" (180°) | [F09] |
| حركة الموت harakat al-mawt | throw it one way at 180 km/h, then the other, and let it ride sideways until it stops; also a head-on game of chicken | [Saaid] [Men] |
| تطويف tatweef | passing traffic sideways, up to 160 km/h | [WikiT] |
| استفهام istifham | "question mark": a U-turn at top speed | [AGSI] [Marefa] |
| مروحة / شرارة muruha, sharara | slaloms; sparks from scraping the kerb | [Men] |
| تربيع / تخميس / سلسلة / تكوير | named figures, not described | [Saaid] [Marefa] |
| الجلنط al-jalant ; الطارة al-tara ; كسرة kasra | slang: handbrake; steering wheel; a hard steering "break" | [F09] |

### C2. How the moves are driven (practitioner instructions)
- **Skid (natla)** [Men]: above 75 mph (120 km/h), shake the wheel; turn strongly left, slightly right twice, strongly right, slightly left twice, and so on.
- **Knot (ʿugda, the 360)** [Men]:
  - At 65–75 mph (105–120 km/h) in the left lane, turn right "and handbrake neatly until the car turns its back to the road". Then release the handbrake and turn "all the way to the left".
  - "If you want to perform two knots, repeat … for the first knot, and don't use the handbrake for the second one."
- **Opposite (ʿaksiya)** [Men]: at 75–85 mph (120–137 km/h), do two skids, and on the third turn the wheel to the opposite side "and let the car go".
- **Forum lessons** (2009, reposted 2011) [F09] [F11]:
  - **Face turn:** at 60 km/h or more, put the gearbox in **neutral**, steer slightly right, then break the wheel hard left together with the handbrake pull.
  - **Single knot:** at 80–90 km/h ("prefer 90"), break right slightly and return it (in 3rd), then break left "with a light handbrake pull". When the car has turned its face, steer the opposite way and release the handbrake.
  - **Single ʿaksiya:** at 90–100 km/h, hold the wheel at its left side and never touch the brakes. Break right, then immediately a barely-there left with the handbrake, and **keep it pulled**. Ease the wheel back right "until the speed reaches 60". Then break hard right and release.
  - **Tanteel:** at 120 km/h or more, hands at the top of the wheel. Use the "kasra" (preferred over the handbrake): a **light** break one way, then a **strong** break the other. "The first calms the car … the second gives you power and a strong natla."
- **Harakat al-mawt** [Saaid]: at 180 km/h, throw the car, throw it the other way, and let it ride on its side until it stops. Menoret watched a car "sliding with a shriek while presenting its flank" (≈90°) [Men].
- **"American style"** [Men]: in automatic US sedans at 125 mph, the gear goes into neutral, which "immediately provoked perfectly shaped doughnuts that the driver would control by using the steering wheel". No handbrake is needed. "When American cars f\*\*\* up, they f\*\*\* up big time." (inferred) This is likely a neutral-drop: N→D at high rpm, an automatic's clutch kick.

### C3. The hajwala 360, synthesised
- **Entry:** 80–137 km/h by the sources above; harakat al-mawt at 180 km/h.
- **Sequence:** a feint (a light steer away), then a hard steer in with a light handbrake. Hold until the car faces backwards, then release and apply full opposite lock. The car comes round to face forward, and a second knot needs no lever.
- (inferred) Physics of the exit: a car travelling backwards is directionally unstable (its centre of gravity trails), so once the lever is released it wants to swap ends again. That free second half-turn is why "let the car go" works.
- **Speed cost:** a spinning car with locked wheels at 70 mph still decelerates at 0.70–0.745 g for yaw rates of 0–500 °/s [JSH]. The ʿaksiya bleeds 90–100 → 60 km/h with the lever held [F09].
  - (inferred) A lever-assisted 360 averages about 0.3–0.5 g, so it loses **≈20–35 km/h over 1.8–2.6 s** from 100–130 km/h.
- (inferred) Rotation time: a mean yaw of 140–200 °/s gives a 1.8–2.6 s 360, with the peak while the car is backwards. The handbrake *initiation* alone peaks around 70 °/s [Goh24].

### C4. Cars
- **Japanese and Korean front-drive sedans** (Camry, Accord, Sonata, Altima): popular for being "lightweight, powerful engine, and wide availability". Japanese makers held 50–75 % of 1980s sales; Cressida and Datsun 200L were early icons. [Men] Tafheet cars are "front-wheel drive … not designed for drifting" [Strive].
- **Big US automatics** (Caprice type) were "around one third" of 1980s sales and did the American style [Men].
- **Land Cruiser 200:** Torsen centre diff, 41:59 in a straight line, up to 30:70 in hard cornering, front at most 53 % [LC].
- **SUVs need the AWD off to powerslide**, to get enough rear traction force [Ed08].
- **Speeds:** 160–260 km/h [WikiT] [ArT]; 140–150 mph Camry/Sonata runs in convoys [Men].
- **Now sanctioned:** first SAMF hajwala event, 26–27 June 2026, 6 drivers, 4,000 spectators [SPA].

## D. How drift games make it work

| Game | Inputs | Initiation | Sustain / angle | Throttle | 360 / recovery | Reception | Source |
|---|---|---|---|---|---|---|---|
| FR Legends (mobile) | gas, brake and handbrake buttons; tilt, slider or arrow steering | tap handbrake and turn; sharp turn at speed; **double-tap gas** while turning | angle and speed both score; "Kiss the Wall" proximity scoring | the engine is abstract: rpm limit changed nothing in a memory-editor test | – | "steering buttons are virtually impossible … for grip"; tilt and gas on the left thumb, brakes on the right "very intuitive" once learned | [FRL] [FRLrev] [FRLsr] |
| CarX (PC keyboard) | binary keys plus steering assist | handbrake, clutch | **with no steer key the auto-countersteer holds ≈65–70°, 75–80° when steering in**; Ackermann 0 % gives more countersteer, lower front tyre pressure more angle | – | for 360s, **100 % front brake bias, then brake while drifting adds angle** | (round 1: assist off feels "twitchy") | [CXk] |
| Torque Drift 2 | pad or wheel | – | – | – | – | "like walking on ice … no feel of grip"; an R35 "lose[s] all its power mid-corner in 3rd … at 80km/h", so players must keep downshifting; one 308 h player: "great balance between arcade and simulator" | [TD2] |
| Drift Hunters (web) | WASD, Space for handbrake, Shift/Ctrl for gears | – | – | – | – | – | [DH] |
| Forza | pad | – | Normal steering damps input and limits lock (270° against 900° of wheel); Simulation gives quicker countersteer | – | – | – | [FzS] |
| NFS 2015 / Heat | pad | a handbrake tap; Heat offers "brake to drift" or "gas to drift" | "hidden steering aids" make it "nearly impossible to spin"; power barely changes wheelspin | gas drift "takes less of your speed away" and is "the only way to make long drifts"; brake drift loses more and is "more responsive" | – | "will not be teaching people about car control" | [NFS15] [NFSH] |
| Initial D Arcade | wheel, pedals, shifter | feint 50–100 m before the corner | the "eraser" (an up-then-down shift mid-feint) lets "some turns full gas" | – | – | TST exits are 1–2 km/h faster | [IDA] |
| Ridge Racer | d-pad | **steer while off the gas**, no brakes | "snap-to-rail", like a slot car | – | "physics-defying … spinning 360s" | the series' signature feel | [RR] |
| Inertial Drift | twin stick | right stick = **drift angle** directly | per car: slides "immediately … only when you lift off the throttle, only when you hit the brake" | – | – | "accessible by giving the player even *more* control" | [ID] |
| art of rally | keyboard friendly | – | separate countersteer assist; **countersteer runs faster than steer-in** (steer-in damped) | keyboard throttle must be tapped | – | a mod recommends 100 % countersteer for keys | [AoR] |
| AC gamepad assist mod | pad or keyboard | – | self-steer "Response", "Max angle" (90° for drift), "Damping"; keyboard steering rate 30–60 % | – | – | – | [AGA] |
| BeamNG | any | – | the "oversteer reduction assistant" tunes the wheel into "the countersteer window" | – | – | – | [BNG] |
| Assetto Corsa setups | wheel | – | brake bias of **66 %+ front adds angle** under left-foot braking; 64 % or less loses it | – | – | – | [ACWH] |
| Midnight Racing: Tokyo (Roblox) | keyboard | handbrake plus gas | **"aggro" sets how the car countersteers "without your steering input"**: start at 37 %, ratio 14:1, max lock | – | – | drift ≤180 km/h, ≤4 gears | [MRT] |

Patterns across games:
1. Every binary-input success adds a **hands-off countersteer that holds an angle**. That stabilises the saddle from A3, which no keyboard player can do at about 1 Hz. The real-world equivalent is caster: about 7° of caster lets you "let go of the wheel and let it feed through your fingers and the car will counter faster than if you were steering it yourself" [MotoIQ].
2. **Speed in the slide is a design choice.** Gas drifts keep speed, brake drifts lose it [NFSH]. Hiding spins entirely draws "too easy" criticism [NFS15]. rpm bogging mid-drift draws complaints [TD2].
3. **Binary triggers get rich meaning through timing:** a gas double-tap [FRL], lift-and-steer [RR], brake-while-drifting [CXk], a shift blip [IDA].
4. **Per-car initiation and exit rules give character** without a new physics model [ID].
5. **Steering rates are asymmetric:** fast countersteer, slow steer-in [AoR].

## E. Drivetrain character

- **Front drive:**
  - A continuous power slide is impossible: "the power going to the front tyres then pulls you out of the slide" [evoI]. "In an FWD car, the throttle's main job is to pull you *out* of the slide" [DRC].
  - Lift-off is "throttle, lift, turn, slide" [Drive]. Lift-off oversteer is strongest in mid-engine cars because of their low yaw inertia [LOO].
  - The handbrake "is a trigger, not a switch you just leave on". Holding it too long "will bleed off too much speed". [DRC]
  - Left-foot braking with the gas on: "the front wheels keep turning … the rear wheels try to lock up", and the car pivots on its fronts. It is handbrake-like but modulated. [RRN]
  - The research nuance: a *held* handbrake plus front drive does make steady states (A5). The fastest are the high-β ones, and tight high-β ones are stable. [V09] [V11]
- **All-wheel drive:**
  - The Focus RS sends up to 70 % rear, 100 % of that to one rear wheel. Because ≥30 % stays at the front it "four-wheel-drifts rather than executes full-on power-slides". Its ESC watches yaw rate and the driver's correction and clamps down on "a lack of skill". [WhC]
  - **GR Yaris:** 2020 car Normal 60:40, Sport 30:70, Track 50:50 [MRg]. Current car Normal 60:40, Gravel 53:47, Track variable 60:40 → 30:70 [GRF].
  - **AMG E63 drift mode:** "up to 100 per cent … to the rear" [CTE63].
  - The control strategy flips at about 25:75; more gas gives more speed and less angle on the AWD side [Eb25]. Hairpin-optimal sideslip reaches about 40° [Ac17].
- **Heavy 4x4:**
  - Land Cruiser 41:59 → 30:70 [LC]. A 2066 kg SUV (Iz 3120 kg·m²) only powerslid with the AWD off, and only in a narrow speed band [Ed08].
  - The pendulum turn is not used on high-centre-of-gravity vehicles [V07]. Tatweef is a sustained sideways pass up to 160 km/h [WikiT].

---

## Implications for modes

Assumptions: binary keys or touch buttons (gas, brake, lever, left, right), steering lock 38° (CLAUDE.md), and hajwala on straights at 100–260 km/h. Numbers are starting points for Play measurement, not answers. Knob names in `code` already exist in `CarConfig.drift`, `DriftStyles` or the lever code, where they match.

### Rules for every mode
- **The assist owns stability; the player owns angle and path.** This is the Eberhart split [Eb25] and the Sun split [Sun25]: gas and lift move a *target* β, the wheel bends the path, and the hands-off countersteer (`driftAssistHandsOff`) catches the ≈0.35 s instability [H13].
- **Cap the angle build-up rate.** Use τ≈0.75–1.0 s, or 10–20 °/s, for throttle-driven growth. The slowest build rate had a 2.9 % failure rate against 25 % for the fastest [Sun25], and Eberhart's assist ramps at 10 °/s [Eb25].
  - Lifting can shrink β faster, at 30–60 °/s (inferred): lift-to-catch is the safety valve.
  - `holdEaseDegPerSec` 25–35 fits.
- **The steering-lock ceiling on a straight** (inferred): to hold a slide on a straight road the front wheels must point roughly along the path, so countersteer ≈ β. With 38° of lock plus about 8° of front slip, a **held** straight-line angle above ≈45° cannot be sustained by the wheel. Higher angles need the assist or must stay transient (swings, 360s).
- **Countersteer faster than steer-in** (≈1.5–2× rate) [AoR].
- **Latency:** keep input-to-torque under 100 ms on the client [Lat26].
- **Speed bleed model** (inferred, A4): no gas ≈ share_r·µ·g·sin β; lever held ≈ share_r·µ·g. Gas adds thrust ∝ cos β (RWD) or front-axle pull (FWD/AWD).
- **Wheelspin cue:** rear tyre speed ≈ 1.4× road speed at 10° and ≈2× at 30–50° [V09]. Drive rpm, smoke and audio from it, and don't let rpm bog mid-drift [TD2].
- **The hajwala 360, shared spec** (all inferred from C3):
  - Entry 80–140 km/h. Lever plus a hard steer, after an optional light feint.
  - Peak yaw ≈180–220 °/s while backwards; total 1.8–2.6 s (Kamri lever 360 measured 2.52 s).
  - Loses 20–35 km/h. Exit when heading is within ±20° of velocity: lever released, auto-catch on.
  - Chains: a second 360 with no lever (Ta'geed); a reversed second 360 after a 0.5–1 s slide (Sefty) [WikiT] [Men].

### RWD (Caprice, Charger)
1. **Power Hold** (stable drifting; default):
   - Init: power-over at ≥45 km/h with ≥0.5 lock and gas [MyT] [F1D]; lever tap; or feint.
   - Sustain: held gas grows target β at 15 °/s toward the band top; lift shrinks it at 40 °/s.
   - Band 20–40°, cf. 20–34° measured [H13] [V10] [Lat26].
   - Speed: gas holds speed (the Escort held 8.1 m/s for 15 s [V10]); aim for ≤5 km/h lost over 4 s (inferred). Lift bleeds per the model.
   - Bursts: a stab ≥0.2 s after a lift kicks +6–10° over 0.3–0.5 s (inferred; `kickDeg` 8).
   - Transition: over-rotate, lift, gas back on the new side [D61].
   - 360: shared spec, with gas keeping it spinning.
   - The catch: lift, and the hands-off countersteer straightens it in ≈0.6 s.
2. **Kick** (throttle bursts):
   - Init: gas double-tap within 0.3 s while steering [FRL], or a kick key.
   - Effect: drive torque ×2 for 0.2 s (inferred from [TDA] plus the flywheel estimate), +10–15° in ≈0.4 s, rpm +3000 [TDA]. Cooldown 0.6 s.
   - Use it when the slide is regaining grip [TDA]. Speed: ±0 (RWD).
   - Feathering at ≈1 Hz [Ed11] holds a band of 25–45°.
   - Catch: as Power Hold. Hajwala skin: "American style" N→D drop at ≥150 km/h as the kick [Men] (inferred interpretation).
3. **Long Angle** (stable, high):
   - Band 40–55° (MARTY 45° [Goh16], TRI >55° peaks [Goh24]). Strong hands-off hold of about 30–40°; CarX's 65–70° is a ceiling, not a target [CXk].
   - Above 45° on straights only with the assist (lock ceiling).
   - Speed loss ≈1–2 km/h per second on gas (inferred; the game's own "High Angle" measured 7–8 km/h over 4 s, `DriftStyles.luau`).
   - Transition: lift, swing, regather in 0.8–1.2 s.
4. **Natl swing** (hajwala RWD): kasra pairs. A light steer one way (≈30 % lock, 0.2 s), then a strong steer the other (≥80 % lock) [F11]. This throws 25–40° per swing at ≥120 km/h. Gas holds it, and the swing period is 1.5–3 s (inferred).

### FWD (Kamri / Camry, Accord, Sonata)
1. **Lever Throw** (tafheet default):
   - Init: lever at ≥60 km/h, full from 80–90 [F09].
   - Sustain: **only while the lever is held** (FWD needs rear braking to hold a slide [V09] [V11]). Gas while held adds front pull: it tightens the radius and keeps speed, and does *not* straighten. Held band 25–50°. Bleed ≈13 km/h/s (inferred; ʿaksiya 95 → 60 km/h [F09]).
   - On release: gas pulls it straight at −15 to −25 °/s with no countersteer needed [V11]. Off gas the slide fades at 2–5 °/s (`holdDecayDegPerSec`).
   - 360 (the knot): the shared spec with this exact order [Men] [F09]: feint, light lever, hold to backwards, release with full opposite lock, let it come round.
   - The catch is free: gas plus centred wheel (fronts pull).
2. **Lift-Off / Kansei:**
   - Init: lift at ≥60 km/h with ≥0.5 lock. Rear grip ×0.85–0.9 for 0.4 s (inferred from 7–15 % load transfer; the existing measured `liftThrowRearGrip` 0.6 is stronger).
   - Throw 20–35°, lasting 1–2 s; slides are short by nature [evoI] [Drive].
   - Gas = straighten (`kickDeg` −6 to −8).
   - Transition: each side is a new lift-throw (Tanteel). No 360 without the lever.
3. **Pivot** (left-foot brake: gas + brake):
   - Both held: the fronts stay driven, the rears drag, and the car pivots on its nose [RRN]. β grows at 15–25 °/s while held (inferred), brake share 0.3–0.5 rear-biased (inferred).
   - Front-biased brake alone mid-slide also adds angle [ACWH] [CXk]. Speed cost about 0.3 g.
   - Release brake: the gas pulls straight. A modulated "handbrake" for touch players.
4. **Natl / Tanteel** (steering-only throws, ≥120 km/h):
   - Light kasra then strong kasra (preferred over the lever [F09]). The weight-transfer flick cuts rear grip for 0.4–0.5 s (`flick*`), giving 20–30° swings.
   - Harakat al-mawt finisher: a 90° coast that bleeds at about µg (inferred) "until it stops" [Saaid].

### AWD (Patrol / Land Cruiser types, hot hatches)
1. **Rally** (front share 0.45–0.5, the AWD strategy):
   - Init: flick or pendulum (lift, steer away, brake, steer in) [V07], or the lever.
   - Sustain: **gas *reduces* the target β and adds speed** [Eb25]. Band 15–30°; little countersteer, and at γ<0.4 the wheel may point into the turn [Eb25].
   - Speed: gains 0–3 km/h/s on gas (inferred).
   - Bursts: a stab is −3 to −5° and drives forward. A lift is +5°, for rotation.
   - 360: needs the lever held longer, ≈2.4–2.8 s (the fronts keep pulling, inferred).
   - The catch: gas.
2. **Drift Mode** (front share ≤0.25, the RWD strategy):
   - Gas adds angle like RWD, but the remaining front pull caps the band at 25–40° and catches sooner (Focus RS "four-wheel-drifts" [WhC]; flip point 25:75 [Eb25]).
   - Bursts +6–8°. Sold as the factory drift-mode toggle (Focus RS 70 % rear, GR Yaris 30:70, E63 100 % rear) [WhC] [MRg] [CTE63].
3. **4x4 Tatweef** (41:59, heavy, high centre of gravity):
   - Init: lever or flick at ≥100 km/h; no pendulum turn [V07].
   - Sustain: long, shallow sideways passes, band 10–25° (inferred from high CG and narrow stability [Ed08]).
   - Yaw build ≤10 °/s and catch slower (Iz ≈1.5× a sedan's, inferred). Gas keeps speed for passes up to 160 km/h [WikiT].
   - 360 heavy: 2.6–3.2 s, loses 30–40 km/h (inferred).
   - The catch: gas, as in the AWD strategy.
4. **Assist Drift** (optional, any AWD, touch-first):
   - The Eberhart/Sun assist: gas held ≥0.5 s arms it, and torque shifts rearward to ramp β at 10 °/s to 25°. Gas modulates 25–35° (β = 25 + 10·gas) [Sun25] [Eb25].
   - The player only steers the path. Lowest skill floor; label it as assisted.

---

## Sources
[V10]: https://dcsl.gatech.edu/papers/avec10.pdf
[V09]: https://dcsl.gatech.edu/papers/ijvas09R.pdf
[H13]: https://ddl.stanford.edu/sites/g/files/sbiybj25996/files/media/file/2013_thesis_hindiyeh_dynamics_and_control_of_drifting_in_automobiles_0.pdf
[Ed08]: https://repositum.tuwien.at/bitstream/20.500.12708/65776/1/Edelmann-2008-Investigations%20on%20the%20powerslide%20of%20automobiles-am.pdf
[Ed09]: https://link.springer.com/article/10.1134/S1560354709060069
[Ed11]: https://repositum.tuwien.at/bitstream/20.500.12708/66338/1/Edelmann-2011-Analysis%20of%20steady-state%20vehicle%20handling%20and%20driver%20behav...-smur.pdf
[Ed25]: https://repositum.tuwien.at/bitstream/20.500.12708/213683/1/Edelmann-2025-Vehicle%20System%20Dynamics-vor.pdf
[Eb25]: https://repositum.tuwien.at/bitstream/20.500.12708/222315/1/Eberhart%20Manuel%20-%202025%20-%20Influence%20of%20the%20drive%20torque%20distribution%20on%20vehicle...pdf
[TUW]: https://www.tuwien.at/en/mwbw/mec/e325-01-research-unit-of-technical-dynamics-and-vehicle-system-dynamics/research-projects/powerslide-controlling-vehicle-motion-at-the-limits
[Goh16]: https://ddl.stanford.edu/publications/conference-proceeding/simultaneous-stabilization-and-tracking-basic-automobile
[Goh24]: https://www.tandfonline.com/doi/pdf/10.1080/00423114.2023.2297799
[Lat26]: https://arxiv.org/html/2606.27914
[Sun25]: https://www.tandfonline.com/doi/pdf/10.1080/00423114.2025.2487186
[V11]: https://scispace.com/pdf/fwd-vehicle-drifting-control-the-handbrake-cornering-2jgxakh5b3.pdf
[Tav14]: https://www.researchgate.net/publication/262067518_The_Optimality_of_the_Handbrake_Cornering_Technique
[V07]: https://dcsl.gatech.edu/papers/ecc07a.pdf
[Ac17]: https://pure.coventry.ac.uk/ws/files/11109111/vehicle_agile_maneuveringv4.pdf
[JSH]: https://www.jsheld.com/uploads/Post-Impact-Dynamics-for-Vehicles-with-a-High-Yaw-Velocity.pdf
[TDA]: https://texasdriftacademy.com/how-a-clutch-kick-works-in-drifting/
[ESB]: https://engineerskill.blog/how-to-clutch-kick-technique-explained
[F1D]: https://www.formula1-dictionary.net/drifting.html
[FW]: https://www.researchgate.net/figure/Calculated-values-of-flywheel-moment-of-inertia_tbl2_318224600
[D61]: https://driver61.com/uni/how-to-drift/
[MyT]: https://mytour.vn/en/blog/bai-viet/mastering-the-art-of-car-drifting.html
[MotoIQ]: https://motoiq.com/basic-drift-chassis-setup-part-3/2/
[RRN]: https://rallyracingnews.com/lfb.html
[Drive]: https://www.thedrive.com/news/27898/can-you-drift-a-front-wheel-drive-car
[evoI]: https://www.evoindia.com/cars/how-to-drift-or-slide-a-fwd-car
[DRC]: https://digitalrc.ca/blogs/news/drift-with-fwd
[LOO]: https://en.wikipedia.org/wiki/Lift-off_oversteer
[WhC]: https://www.whichcar.com.au/features/ford-focus-rs-drift-mode-geek-speak
[MRg]: https://www.motoringresearch.com/car-reviews/toyota-gr-yaris-2020-review/
[GRF]: https://toyotagazooracing.com/gr/gr-four/
[CTE63]: https://www.carthrottle.com/news/awd-only-mercedes-amg-e63-will-have-drift-mode
[LC]: https://forum.ih8mud.com/threads/land-cruiser-200-information.1173186/
[Men]: https://ebin.pub/joyriding-in-riyadh-oil-urbanism-and-road-revolt-newnbsped-1107035481-9781107035485.html
[WikiT]: https://en.wikipedia.org/wiki/Tafheet
[ArT]: https://ar.wikipedia.org/wiki/%D8%AA%D9%81%D8%AD%D9%8A%D8%B7
[F09]: https://mf-hs-mf.yoo7.com/t533-topic
[F11]: https://aloohsh.yoo7.com/t12-topic
[Saaid]: https://saaid.org/gesah/sami/25.htm
[AGSI]: https://agsi.org/analysis/kings-of-the-road-the-politicization-of-saudi-drifting/
[Marefa]: https://www.marefa.org/%D8%AA%D9%81%D8%AD%D9%8A%D8%B7
[AB]: https://arabic.arabianbusiness.com/lifestyle/lifestyle-cars-yachts/news-332799
[Strive]: https://striveme.com/article/%D9%85%D8%AD%D8%B1%D9%83%D8%A7%D8%AA/%D9%85%D8%A7-%D9%84%D8%A7-%D8%AA%D8%B9%D8%B1%D9%81%D9%87-%D8%B9%D9%86-%D8%B3%D9%8A%D8%A7%D8%B1%D8%A7%D8%AA-%D8%A7%D9%84%D8%AA%D9%81%D8%AD%D9%8A%D8%B7
[SPA]: https://www.spa.gov.sa/en/N2623706
[FRL]: https://fr-legends.fandom.com/wiki/FAQ
[FRLrev]: https://motorsportformentalhealth.com/2018/10/25/game-review-fr-legends/
[FRLsr]: https://www.speedrun.com/FR_Legends/guides/3luyx
[CXk]: https://steamcommunity.com/app/635260/discussions/0/3113644379487928419/
[TD2]: https://steamcommunity.com/app/3116640/reviews/?browsefilter=toprated
[DH]: https://ilyakaminetsky.itch.io/drift-hunters
[FzS]: https://www.gtplanet.net/forum/threads/normal-vs-sim-steering.278031/
[NFS15]: https://www.gtplanet.net/need-for-speed-review-function-follows-form/
[NFSH]: https://steamcommunity.com/app/1222680/discussions/0/3083256496979040224/
[IDA]: https://initiald-arcade.com/advanced.php
[RR]: https://giantbomb.com/wiki/Franchises/Ridge_Racer
[ID]: https://gamingbolt.com/inertial-drift-interview-twin-stick-drifts
[AoR]: https://steamcommunity.com/app/550320/discussions/0/5755024051047475646/
[AGA]: https://github.com/adam10603/AC-Advanced-Gamepad-Assist/blob/release/ConfigGuide.md
[BNG]: https://www.beamng.com/threads/discussion-how-do-you-use-the-steering-assistants-in-beamng-drive.89993/
[ACWH]: https://supplymods.com/news/how-to-setup-cars-for-drifting-in-assetto-corsa-by-will-hurst-122
[MRT]: https://gameplay.tips/guides/midnight-racing-tokyo-keyboard-drift-tuning-guide.html
