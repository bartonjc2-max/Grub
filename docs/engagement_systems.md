# Grub engagement systems: current truth

**As of build 48 (2026-11-23).** This is the one document to read first. The older specs (`mind_step0_spec.md`, `mischief_step1_spec.md`, `states_2to4_spec.md`, `states_remaining_spec.md`, `engagement_states_v1.md`) and the grub-mechanics board (#703–#748) explain the reasoning, but about 20 board corrections came later. Where this doc and those disagree, this doc and the code win. Every number below is a named constant in code (file in brackets), so change it there and update it here.

---

## 1. Layers

```
Touch / HUD / ball            GrubGestures, HudView, BeachBall          (Presentation, Unity)
   │  Verb (ReportInput)                    ▲ beats, faces, walks
   ▼                                        │
GrubPresenter  ── Brain loop ── PickState ── RunState(arc) / idles     (Presentation, Unity)
   │  Begin/MarkPeak/EndEpisode              ▲ desires, gates
   ▼                                         │
Mind (memory, relationship)  + *Rules (pure functions)                 (Grub.Sim, engine-free)
   │  reads stats                             ▲ ticks
   ▼                                          │
Sim (stats: fullness, happiness, energy, hygiene; sleep; mood)         (Grub.Sim, engine-free)
```

- **Sim** (`Scripts/Sim`): needs decay, commands (FEED, PLAY, SLEEP, CLEAN, pet), sleep, mood. It is deterministic and catches up offline. Its numbers are in `Tuning.cs`.
- **Mind** (`Scripts/Sim/Mind`): what he remembers, and how he feels about you and the room. It is saved as module `"mind"`, currently `mindVersion` 2. Its numbers are in `MindTuning` (`MindTypes.cs`) and the `*Rules` classes (`EngagementRules.cs`, `MischiefRules.cs`, `NotifyRules.cs`).
- **Presenter** (`Scripts/Presentation/GrubPresenter*.cs`): the Brain coroutine. It turns desires into arcs (a walk, a look, an ask, a reaction), opens a **response window** at each arc's peak, and reports how you reacted back to the Mind.

---

## 2. The loop: episodes, windows, outcomes

An **arc** (one engagement state run) is an **episode**:

1. `BeginEpisode(state, obj)` at the start.
2. `MarkPeak(h, action, windowSec[, matchVerb])` at the moment you should react. This opens a **ResponseWindow**, 8 s by default.
3. Your first input in the window classifies it (`ResponseWindow.Classify`); the full table is in §5.
4. `EndEpisode` resolves it: with the window's outcome, or `Ignored` if you never answered.

On resolve (`Mind.Resolve`), unless the episode is `away` (or dev `NoLearn` is on), the Mind:

1. **Learns what to expect.** `expect[state, outcome]` is an EMA with rate 0.2; the row always sums to 1; and since #733 every entry is floored at 0.02, so nothing becomes unthinkable (max is 0.90).
2. **Updates liking** for the object: rate 0.1. `owned` is hysteretic: on above 0.6, off below 0.4.
3. **Bond:** +0.02 × positive valence, capped at 0.06 per rolling hour and by the daily cap (§4).
4. **Trust:** shoo costs (§4), and NeedSeeking Rewarded adds +0.01.
5. **Grudge** if valence ≤ −0.5. The key is the object, otherwise the verb (`verb:shoo`, `verb:toss`, `verb:shake`). An overtickle never holds one.
6. **Trait drift:** ±0.002 toward the valence's sign. A trait never moves more than 0.10 from its anchor, which resets every 30 days, and stays within [0.1, 0.9].
7. Appends to the **episode ring** of 40.

**Valence tables** (`Mind.ValenceDefault` / `ValenceSocial`; the order is Ignored, Noticed, Joined, Rewarded, Redirected, Shooed):

| | Ign | Not | Join | Rew | Redir | Shoo |
|---|---|---|---|---|---|---|
| default | −0.1 | 0.3 | 0.7 | 0.8 | 0.1 | −0.5 |
| social (Affection, SocialPlay, Anticipation, Reunion) | −0.3 | 0.3 | 0.8 | 0.9 | −0.1 | −0.6 |

---

## 3. Traits (hidden, shown only through behaviour)

`boldness`, `sociability`, `playfulness`, `tidiness` are each seeded 0.3–0.7, deterministically from the creation time. Episodes nudge one trait per family (`Mind.TraitFor`):

| Trait | Moved by |
|---|---|
| bold | Mischief, Possessive |
| social | SocialPlay, Affection, Anticipation, Reunion, Sulk |
| play | SoloPlay, Pride, Restless |
| tidy | Nesting |

Over a simulated week the traits move at most ±0.02 (§9), so personality is very stable.

---

## 4. Relationship math (`MindTuning`)

| | Value |
|---|---|
| **trust** start | 0.5 |
| **bond** start / rest | 0.3; drifts toward 0.3 at 0.01/day |
| Trust floor (J1: always recoverable) | **0.1**, for every loss |
| Daily trust gain cap | **0.08**; **0.15** while trust < 0.5 (forgiveness is quicker than first trust) |
| Daily bond gain cap | **0.08** below 0.7, **0.04** above (closeness keeps growing for about 2 weeks) |
| Hourly bond gain cap (episodes) | 0.06 |
| Need met while LOW | +0.02 trust, or **+0.005** if it sat at CRIT more than 1 h ("late care"); a late fix also turns that NeedSeeking's Rewarded into **Noticed** |
| NeedSeeking Rewarded | +0.01 trust |
| CRIT spell | −0.03 trust/h after a 1 h grace |
| Away more than 24 h | −0.05 trust |
| Passive loss cap (CRIT and absence together) | **0.06/day** |
| Rhythm return (back at your usual hour after 2 h+, 5+ sessions) | +0.01 trust; +0.01 bond **only while trust ≥ 0.4** |
| **Shoo cost** | free against **Mischief** (a fair "no"); −0.03 trust and −0.01 bond in Affection, SocialPlay, Anticipation, Reunion, Pride and NeedSeeking |
| **Rough handling** | every shoo, fling and shake counts; past the 2nd within 10 min, each costs −0.02 trust and −0.01 bond |
| Grudge lifetime | 48 h at trust 0, falling to 6 h at trust 1; at most 5 grudges |

**Needs learning (#724):** for each stat, an EMA of how long it stays LOW before you fix it. If that's 20 min or more, he **asks early** (10 points before LOW); at 5 min or less he stops asking early.

---

## 5. Inputs → outcomes (`ResponseWindow.Classify`)

| Verb | From | Outcome |
|---|---|---|
| TapGrub | a tap on him | Noticed; **Shooed** if target "overtickle" (the 8th quick tap) |
| Pet (finger wiggle), Hold (long-press) | gestures | Rewarded (Noticed if the window wants a specific need) |
| Shoo | fast downward flick on him | Shooed |
| Call | double-tap the floor | Noticed |
| Carry | hold, then drag | Noticed. A gentle set-down while Content is also Hold (care) plus `Affection → Rewarded` |
| Toss | flinging him | **"fun"** (he cheered) is Noticed; **"rough"** (he turned away) is Shooed plus a `verb:toss` grudge |
| Shake | phone shaken (4 jerks over 1.6 g within 1 s) | Shooed plus a `verb:shake` grudge |
| Feed, Play, Sleep, Clean | HUD | Rewarded if it's the need he asked for, otherwise Redirected (Play joins a ball arc) |
| TapObject, DragObject, TossBall | room and ball | Joined if it's the arc's object, otherwise Redirected |

---

## 6. States (the Brain, `GrubPresenter.States.cs` `PickState`)

**Order of precedence:**

1. **Needs.** Hungry, tired or dirty → NeedSeeking, spaced 90 s (45 s at CRIT).
2. **Sad** → Sulk, spaced 300 s.
3. **Asks early** for learned slow fixes.
4. **Only when Content:** the arcs. At most one non-need arc per **90 s**, a **20–40 s rest** after each, and **never the same state three times running**.
5. The Director picks the highest desire among the states whose gates are open.
6. Otherwise he idles: wander, couch, ball, mischief idles, and so on.

| State | Starts when | Beats | Outcome → result |
|---|---|---|---|
| **NeedSeeking** | a need is LOW, or he learned to ask early, or the evening nest (after 20:00, energy < 50, desire 0.4 + 0.2·tidy) | walks to the HUD button (tired: to the couch), points while the button wiggles, looks up at you, jumps (2, or 3 at CRIT); Grumpy at urgency 2, Sad at 3 | Rewarded: you pressed it. Late: Noticed. Shoo: hurt |
| **Sulk** | mood Sad, or hurt by a branch | turns away, peeks back; hurt fades at 0.02·(trust+0.3)/s; a 2nd unrepaired sulk in 24 h starts **in retreat** (+0.2 hurt, peeks ½ as often) | His owned ball makes up (+bond, more if he was peeking); any other ball gets a cold shoulder |
| **Mischief** | desire 0.3·reaction chance + 0.3·(bold−0.5) − fatigue ≥ 0.5, energy ≥ 40, 180 s spacing, 20 s after you | pot shake, then pot lean, then picture tilt (tiers); escalates up to 3 tries; avoids an object after 3 shoos in 24 h | Escalate, Caught, Guilt, Slink, FixTogether, Delight… (`MischiefRules`) |
| **Affection** | 1.4·social·bond + 0.3 care + presence 0.15 + clingy 0.25 − 0.08·recent ≥ 0.35; energy ≥ 20; 120 s; you active in the last 90 s or clingy | comes over and leans in | Rewarded: snuggle. Noticed: wink. Joined: play. Shooed: sulk 0.8. Ignored: wanders off (clingy: sulk 0.4) |
| **SocialPlay** | 0.5·play + 0.3·bond + 0.15 present − 0.08·recent ≥ 0.40; energy ≥ 40; ball free | brings the ball toward you | Joined: play. Rewarded/Noticed: cuddle. Ignored: plays alone. Shooed: slinks off |
| **Fixation** | fascination 0.9·max(1−familiarity, 0.25) + theme 0.4 + 0.2·(play−0.5) ≥ 0.5; energy ≥ 30; 240 s | studies the item and finds tricks on it (the rug: roll, zoom); daily theme from the seed | familiarity gain capped per day |
| **Pride** | 0.5·play + win 0.3 + 0.2·reaction chance ≥ 0.55, you active in the last 60 s | "watch this" | |
| **Restless** | 0.6·boredom ≥ 0.5 (about 4 min of nothing), energy ≥ 50 | paces | relief: Joined/Redirected 0.35, Rewarded 0.15, Noticed 0.05 |
| **Reunion** | back after 30 min+ | welcome sized by hours, bond and rhythm; cold if away over 24 h and trust < 0.4 | |
| **Anticipation** | it's your usual hour | waits by the front (`FoundWaiting`) | |
| **Glass** (touch #1) | his own idea: quiet 40 s+, ≤1 per 5 min, Content, bond ≥ 0.45, 15% per idle | presses his face to the screen | an Affection episode: boop is Noticed, nothing is Ignored |

**Offline mess:** away 45 min or more, chance 0.5·(0.5+bold)·min(1, hours/3), at most one per absence: a crooked picture or a leaning plant. It is logged as an `away` episode, from which he learns nothing.

**Night (J4):**
- He doesn't auto-wake between **21:00 and 07:00** local.
- He puts himself to bed if it's night, he's awake, energy < 70 and there's been no command for 30 min.
- Asleep on the floor at night, he trudges to the couch first (`TuckIn`).

---

## 7. Touch (`GrubPresenter.Touch.cs`, `GrubGestures.cs`)

| Touch | Behaviour |
|---|---|
| **Eyes** | follow any finger on the screen |
| **Tap**: head (top 38%), belly, feet (bottom 24%) | squish and look up; giggle; hop. He stops and faces you. 4+ taps within 0.9 s = tickle; the 5th = laughing fit; the 8th = Grumpy, annoyed for 6 s |
| **Hold** (550 ms) | squish; on the **head**, let go → **face to the glass** (tap there = boop) |
| **Hold + drag** | carry (legs dangle). Gentle release: set down, or seated on the couch if your finger is over a cushion. Release faster than 2.4 m/s: tumble (about his middle, landing upright), then FallDown, dizzy; cross if not Content, trust < 0.35 or temper Calm |
| **Tilt** | measured against a 3 s rolling baseline: he leans; a change over 0.45 g held 0.6 s makes him slide, and the baseline catches up so he settles |
| **Shake** | dizzy (Wobble); grumpy if not Content |
| **Grudge flinches** | `verb:toss`: Oof and a lean-away when lifted. `verb:shake`: braces (squat, Skeptical) instead of sliding |
| **Call** | double-tap the floor: he comes to the spot |

He is 1.85 m in world units (1.37 local, scale 1.35); `bodyHeight` is used for the tap zones and the tumble.

---

## 8. Notifications (`NotifyRules`)

- There are two, at the same cadence as always: the first stat LOW (its need line), and the auto-wake.
- The wake notification's body can depend on what's on his mind, in this order:
  1. a mess in the room;
  2. it's your usual hour;
  3. trust < 0.35;
  4. otherwise the plain hello.
- **These lines are switched off (`MindLinesEnabled = false`) until Jesse approves the copy.**
- Quiet hours are 22:00–08:00.

---

## 9. Persona table (`MindPersonaSimTests`, a simulated week in 1-min slices)

| Persona | Behaviour | Day 7 trust / bond |
|---|---|---|
| Attentive | 4 sessions/day; fixes at LOW, fills to 70; bedtime | **1.00 / 0.74** (0.82 / 0.58 at day 4) |
| Busy | 1–2 random sessions; fixes ≤ 40 | **≈ 0.40–0.43 / 0.41–0.45** (a bit wary, not hurt) |
| Rough | 3/day; fixes only at CRIT, once; no bedtime; 40% shoo, split evenly into shoo, fling and shake | **≈ 0.13–0.16 / 0.33** |
| Lapsed | 3 days on, 3 away, 1 on | 0.74 → 0.56 away (−0.18) → 0.58 |
| Rough, then Attentive | | day 2: 0.385; **day 3: 0.505** |

**Asserted:**
- traits stay within ±0.10 of their anchors;
- E stays in [0.02, 0.98];
- grudges ≤ 5, none lasting over 48 h;
- the episode ring stays at 40;
- no CRIT between 23:00 and 06:00 after an evening tuck-in;
- Rough < Attentive − 0.3;
- Busy is between Rough and Attentive, and in [0.30, 0.45];
- recovery ≥ 0.35 after 2 days and ≥ 0.45 after 3;
- Lapsed's time away costs ≥ 0.15.

---

## 10. Debug tools

- **Dev panel** (gear, then the debug sheet): Mind numbers, Mischief, States (Run <state>), Smoke (Run all arcs, Soak 10 min ± taps), **Performance (Measure 2 min: p50/p95 frame ms, GC per frame)**, and Gestures overlay.
- **Editor, via unityMCP:**
  - `GrubPresenter.SmokeRun()`: 39 cases, at 2× when the editor is in the background.
  - `SoakRun`, `CaptureBeats(folder)`, `CaptureAsks(folder)`, `CaptureTouch(folder)`: the touch demo with snapshots.
  - `DevFlingProbe()`: lowest vertex in flight and after landing.
  - `GrubPerfProbe.Run(sec)`.
- **Tests (EditMode, 85):**
  - `MindTests` A1–A14
  - `MischiefRulesTests` M1–M9
  - `EngagementRulesTests`
  - `MindPersonaSimTests` P0–P6
  - `TouchMindTests` K1–K5
  - `NotifyRulesTests` N1–N3
  - `SaveContinuityTests`: build-35 and build-40 saves load with their memory (fixtures from `tools/old_save.py`)
  - `SimTests`
- **Logging:** `GLog.Log` and `[Mind]` lines exist only in the editor and development builds; player builds compile them out.

---

## 11. Open items (waiting on Jesse)

- His on-device feel of the touches (hold time, shake strength, glass size).
- His OK on the notification copy.
- His read of `beats_readability.png` and `need_asks.png`.
- Frame rate: iOS runs at **30 fps** because `targetFrameRate` is unset. Going to 60 is smoother but uses more battery; this needs a decision.
- Hand-feeding (deferred).
