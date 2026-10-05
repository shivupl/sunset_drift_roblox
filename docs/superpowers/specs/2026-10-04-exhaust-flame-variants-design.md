# Exhaust flame variants: sputter, fireballs, blue jets

Asked by the owner on 2026-10-04, on a new branch: "I want you to create
different exhaust flame variants but really cool ones. what i have now is not
bad but is kind of just like a spark, i need way cooler ones and the audio has
to be like the sputter. do some research on this exaust bursts/pops and
implement a couple varitations to try."

The owner set a /goal for the session, so the approval gates in this process
are rulings of mine, recorded here; the owner can redirect at any point.

## 1. Where it stands, measured

- **Why it reads as a spark.** The flame layers are 0.04-0.24 m particles that
  live 0.05-0.22 s (CosmeticsConfig.flames). The chase camera sits 7.5 m
  behind and 2.6 m up at 70 degrees of field, so a 0.18 m flame is about
  20 px tall on a 1080p screen; a 0.5-1 m flame would be 60-120 px. The
  textures are Roblox's built-in single frames, so nothing in a flame moves
  but its particles. The "before" capture (2026-10-04, chase cam) shows two
  thin orange streaks under the bumper.
- **Why it doesn't sputter.** A lift-off fires 1-3 pops (times the
  exhaust's crackleChance) at random times in 0.5 s, each the same 0.44 s
  sample ("Car Backfire Exhaust"), which is itself a "pa-pop" with a long
  tail. A real crackle tune fires a dense, irregular string of short sharp
  cracks that thins out as the revs fall.

## 2. Research

Sources and numbers are in the research notes summarised here (web research,
2026-10-04) and in the measurements below.

- **What a pop is.** Unburnt fuel reaching the hot exhaust and lighting
  there. A "pops and bangs" (crackle) map retards the ignition and keeps
  injecting on the overrun, so a lift from high rpm sets off a string of
  small detonations in the pipe that slows and stops as the revs fall. Anti-lag
  (rally ALS) does it on purpose to spin the turbo: fewer, far bigger bangs
  and fireballs. Launch control's "2-step" cuts sparks on a rhythm on the
  limiter: machine-gun bangs at an even rate. A race car's lean overrun
  burns clean: short blue-cored jets with sharp, high cracks.
- **Colour.** The core of a clean burn is blue (excited CH and C2 radicals;
  lean, complete combustion); the body is orange-yellow from glowing soot
  (rich). Rich fireballs are orange and leave dark smoke; lean jets are blue
  with little smoke.
- **What makes it look cool in games.** An animated (flipbook) fire texture
  rather than a still blob; size you can see from the chase camera; a bright
  flash that lights the bumper and the road; sparks; a smoke puff after;
  and the flame fired on the same frame as its sound, every time.

### Measured in this place (Studio, 2026-10-04)

Every candidate was loaded here (ContentProvider, all Success) and its
loudness envelope recorded through an AudioPlayer into an AudioAnalyzer at
0.1-0.4 playback speed (the analyser samples once a frame; slowed down, a
frame is 2-6 ms of the clip). Pops were found as sharp rises over the floor
and cut where the level falls under 12% of the pop's peak.

| Asset | Length | What it is |
|---|---|---|
| 129025289910636 "pop backfire sound" | 1.30 s | A real pops-and-bangs run: 28 sharp pops, 12-45 ms each, 25-130 ms apart, quiet between. Sliced into grains. |
| 17651974920 "exhaust crackles" | 0.59 s | Dense, loud crackle: 18 pops, 14-38 ms each, almost back to back, near clipping. Sliced. |
| 17651322643 "exhaust crackle 3" | 0.55 s | Six clean pops, 30-40 ms, ~95 ms apart, quiet (peak 0.32). Sliced. |
| 17865169434 "Backfire Pop" | 0.16 s | One small sharp crack. |
| 86084579153761 "zx6r backfire pop" | 0.23 s | One medium-big pop with a short body. |
| 1001293842 "Anti-Lag" | 0.30 s | One huge saturated bang. |
| 112720519011313 (today's pop) | 0.44 s | "Pa-pop" (two peaks 34 ms apart) and a tail. |
| 5752881893 "anti_lag" | 1.03 s | A 1 s rattle of peaks every 25-45 ms. |
| 1618282056, 3019991081, 17696637615, 85415029522611 and others | | A crackle bed with engine underneath, clipped noise, a 4 s engine loop, a near-silent clip: not used. |

Textures (Creator Store flipbooks, each drawn in Studio as one animated
cell, so each is the 1024 px sheet a flipbook needs):

| Image | Grid | Use |
|---|---|---|
| 9968039364 | 4x4 | Realistic orange flame licks on black: drawn additive (LightEmission 1), the black adds nothing. |
| 17703378809 | 4x4 | Realistic white fire, recolourable: tinted blue for the jets. |
| 9636673935 | 8x8 | A one-shot fireball that turns to smoke. |
| 12156297119 | 4x4 | A starburst flash that shrinks (1024 x 1024, checked). |
| 13346862770 | 4x4 | Soft smoke puff (1024 x 1024, checked). |

`FlipbookIncompatible` reads "must be 1024 by 1024" for every one of them in
Edit, even the two checked at 1024; the textures animate regardless. Kept
as a BEHAVIOURS note.

## 3. Approaches

1. **Make today's flame bigger and swap the pop sound.** Cheap, but it is
   still one look, and 1-3 copies of one sample can't sputter.
2. **Play whole recorded crackles and fire flames at their measured pops.**
   The most authentic sound, but every burst is the same clip, it can't be
   cut short when the throttle goes back on, and it can't follow the revs or
   the exhaust.
3. **Styles: a sputter sequencer, a bank of real pop grains, and a flame look
   per style (chosen).** A pure, seeded sequencer turns a style's rhythm into a
   list of pops (time, size). Each pop plays a single real pop cut from the
   recordings above (Sound.PlaybackRegion) and fires a flame of that size on
   the same frame. Styles differ in rhythm, sound and look. Every client
   rebuilds the same sputter from the same seed, so the relay is one message a
   burst instead of one a pop.

## 4. The styles

Each is a rhythm, a sound bank (small, mid and big pops) and a look (layers
per pop size). Sizes and counts below are at the factory exhaust; the
exhaust item still scales the flame (flameSize) and how many pops
(crackleChance, gently, see section 5).

1. **Crackle** (the "pops and bangs" tune; the sputter the owner asked for).
   7-14 pops over about 0.6-1.4 s; gaps start at 30-70 ms and widen to
   90-170 ms as it dies away, each jittered by half; a pop now and then gets a
   quick double 15-35 ms after; mostly small cracks, some mid, the odd big
   one, the first mid or big; loudness falls to about half by the end. Look:
   ragged animated flame licks (9968039364) 0.3-0.9 m by size over a
   velocity-stretched blue root at the mouth, a glow flash on the bigger
   pops, a few sparks on the big ones, a thin dark wisp after.
2. **Anti-Lag** (rally ALS). 2-4 big bangs 120-280 ms apart. Look: a
   mushrooming fireball (9636673935) 0.9-1.4 m, a white-hot starburst
   (12156297119), a shower of sparks, a dark soot puff (13346862770), the
   strongest light flash. Sound: the huge bang (1001293842) and the big pops,
   pitched down for weight.
3. **Blue Flame** (lean race overrun). 3-6 sharp cracks evenly 70-110 ms
   apart. Look: long blue-violet jets (17703378809 tinted) 0.7-1.2 m with a
   white-hot core and violet tips, a blue flash, almost no smoke. Sound: the
   small and mid pops pitched up, crisp.
4. **2-Step** (launch control's machine gun). 6-10 bangs on an even beat,
   80-100 ms apart (8% jitter), all one size. Look: orange fireball licks
   with sparks every bang. Sound: the loud dense crackle grains.
5. **Classic**: today's flame and pop, unchanged, kept to compare against.

## 5. How it fits together

- **`src/shared/ExhaustSputter.luau` (new, pure).** `generate(pattern,
  seed, scale) -> { { t, class, level } }`: times in seconds from the first
  pop (0), class `"small" | "mid" | "big"`, level 0..1 (loudness and flame
  size within the class). Two pattern kinds: `burble` (the four new styles:
  gaps easing from a start range to an end range, jitter, doubles, class
  weights easing from start to end, a fade) and `uniform` (Classic: pops at
  random times in a window). Deterministic for a seed.
- **`src/shared/ExhaustStyles.luau` (new config).** The styles: name,
  pattern, sound grains per class (asset, region start and end, gain), pitch
  and volume ranges, the light flash, and the flame layers. Classic's layers
  stay in `CosmeticsConfig.flames.layers`, untouched.
- **`src/client/ExhaustPops.luau` (new).** Runs a burst on any car: makes
  the events, plays each grain from a small pool of Sounds on the car
  (PlaybackRegion), fires `ExhaustFlames.flame(model, style, event)` on the
  same frame, and moves the one pooled flash light. Cancels a burst when the
  driver is back on the throttle. Owns the relay and the style choice.
- **`src/client/ExhaustFlames.luau`.** Builds emitters per style, layer and
  size class at each outlet (sizes never change on a live emitter: Size,
  Color and Transparency apply to particles already out, so per-pop sizes
  would make earlier flames jump). Classic is built exactly as today.
- **`src/client/EngineAudio.luau`.** Keeps deciding when (a fast lift-off;
  single pops on upshift and limiter still exist and stay 0, off, per the
  owner's 2026-09-22 ruling) and hands the burst to ExhaustPops through a
  hook with its intensity (lifting from higher revs gives more pops).
- **Pop count.** pops = pattern count x (1 + (crackleChance - 1) x
  chanceGain) x the rev factor, capped at the style's maxPops: the titanium's
  2.5 would otherwise make a 14-pop crackle 35.
- **Relay.** The driver sends one message a burst: (kind, style, seed,
  scale), kind 1 a burst, 2 a single pop, 3 cut. The server checks the
  sender drives the car, the numbers' types and ranges, and a rate (bursts a
  second), then sends (car, kind, style, seed, scale) to everyone else. A cut
  stops what is left of that car's burst. The one-message-a-pop relay and its
  counting go.
- **Light.** One PointLight per client, moved to the newest pop of any car
  in range, its brightness by pop size, fading in about 0.1 s, no shadows.
  Like the twelve street lights, the cap is structural: one pooled light,
  never more.
- **Trying them.** `ExhaustStyles.default` picks the style everyone gets.
  In Studio only, P cycles the style on the client (a small label shows its
  name) and the LocalPlayer attribute `FlameStyle` shows and sets it, so the
  owner can switch while driving; relayed bursts carry their style, so other
  clients see the one the driver chose. The garage REV fires the chosen
  style. Wiring styles to the exhaust items, or selling them, waits for the
  owner's pick.

## 6. Budgets

- At most 40 particles per pop per outlet (the big class of the heaviest
  style); a quad's 14-pop crackle is then under 2,000 particles over 1.4 s,
  most of them small and short.
- Flames live at most 0.6 s; smoke at most 1.5 s.
- Frame time measured in Play with a quad exhaust firing each style
  repeatedly in the chase view, before and after.

## 7. Testing

- **`ExhaustSputter.spec`:** the same seed gives the same burst; counts
  within the pattern's range times the scale, capped; times start at 0,
  ascend, never closer than the pattern's minimum gap, and end inside its
  longest span; a crackle thins out (the last third's mean gap is longer than
  the first third's); 2-Step's gaps are even (spread under 15% of the mean);
  Anti-Lag's pops are big; Classic stays inside its window.
- **`ExhaustStyles` checks (in `CosmeticsConfig.spec`):** every style has a
  pattern, all three classes of sound, grain regions inside their clip's
  length and in order, layers well formed (sequences start at 0 and end at
  1, whole counts), and the particle budget; the default style exists.
- **Play, with the harness:** each style at speed in the chase view and from
  the side, on the kamri07 and a quad exhaust, frozen at set ages for
  screenshots; frame time; a relayed burst checked on the server side for its
  arguments.
