# Azeroth Academy: Architecture (v0.12)

## Goals that shape the code
1. **WoW Forever first, Retail second.** Forever (1.60.1, interface 16001) is a Mainline-family
   game type ("forever", formerly "camelot"), so one modern code path covers both. Old-client
   APIs are still guarded so a Classic Era load can't error.
2. **The learning logic must be testable without the game.** All of it is plain Lua 5.1
   with no UI calls.
3. **Modules can be added without touching existing ones.** Since v0.2 a subject is just data
   handed to `ns.Modules.Register`, and the round engine, trial, review, report, and hub tiles pick it up.

## Layers

```
 +-------------------------------------------------------------+
 |  Main.lua  (events, slash commands, combat hide/resume, taxi)|
 +-------------------------------------------------------------+
 |  UI/  Hub (frame + router) | Guide | Lessons | Trial | Parent |
 |       Widgets (buttons, bars, flash, sparks, reveal, pulse)   |
 +-----------------------------+-------------------------------+
 |  Adapters/Compat.lua        |  only place that branches on   |
 |  flavor detection, frames,  |  client version or uses        |
 |  backdrop, color, timers,   |  optional APIs                 |
 |  sound, combat/taxi checks  |                                |
 +-----------------------------+-------------------------------+
 |  Core/  (pure Lua 5.1, no WoW API; clock via ns.Env)         |
 |   Namespace/Util | Progress | Modules | Review | Mastery |    |
 |   Session | Trial | Report | Guide | SoundEvents |           |
 |   Art | subjects: MathGen, ScribeGen, LoreGen (+ Lore Quiz)   |
 |   + Locales/ (enUS → locale → key fallback)                  |
 +-------------------------------------------------------------+
 |  SavedVariables: AzerothAcademyDB (account),                 |
 |                  AzerothAcademyCharDB (per character)        |
 +-------------------------------------------------------------+
```

- **Core** never calls `CreateFrame`, `GetTime`, `UnitName`, or similar. The adapter injects `time` and `date`
  through `ns.Env`. The UI passes `GetTime()` into `Session:Submit(answer, now)`.
  A lint step enforces this. The test harness loads Core exactly as the TOC does
  (`chunk("AzerothAcademy", ns)`) and runs it with nothing from WoW present.
- **Adapter**: `ns.Compat` detects the flavor with `WOW_PROJECT_CAMELOT` first, then by interface
  range (`16000 < interface < 20000` means Forever, `>= 100000` means Mainline, and so on). Each flavor
  gets a small settings table. It also wraps every version-sensitive API:
  - `BackdropTemplateMixin and "BackdropTemplate"`, falling back to a flat texture background
  - `SetColorTexture`, falling back to `SetTexture(r,g,b,a)`
  - `C_Timer.After`, falling back to an OnUpdate scheduler
  - Sound (v0.4): `PlaySoundFile` for an optional custom file, then `PlaySound` through `pcall`,
    trying SOUNDKIT names and then numeric kit IDs, on the parent-chosen channel
  - `UnitFactionGroup` through `pcall`, and `PlayerModel` creation and display/creature IDs through `pcall`, with async load verification
  - `InCombatLockdown`/`UnitAffectingCombat`, `UnitOnTaxi`, and `UnitName` through `pcall`

  Runtime detection is used instead of per-flavor TOC files or inline `[AllowLoadGameType]` directives,
  because not every client recognizes the "forever" game type yet.
- **UI**: one movable, ESC-closable frame (`AzerothAcademyHub`) with a simple view router
  (`Hub.RegisterView(name, builder)` and `Hub.ShowView(name, ...)`). Views are built lazily and expose
  `OnShowView` and `OnHubHidden`. Combat hides the frame and keeps the round alive in memory, and a toast
  offers Resume.

## Module registry (v0.2)

```lua
ns.Modules.Register({
  id = "runeforger", nameKey = "MOD_RUNEFORGER", descKey = "MOD_RUNEFORGER_DESC", icon = "...",
  titleKey, loreKey, placementKey, placementLoreKey, examKey, examLoreKey,   -- optional UI text keys
  bands = { initiate = { nodes = { "count", "add10", ... } }, adept = {...}, magister = {...} },
  nodes = { count = { key = "N_COUNT", descKey = "N_COUNT_DESC", gen = function(level, tier, node) ... end }, ... },
  choiceOnlyBands = { initiate = true },   -- buttons only, no typing (young kids)
  youngChoices = 3, choices = 4,           -- defaults
  inputMode = function(node, tier, purpose) end, -- optional override: return "choice"|"input"|nil
  check = function(problem, given) end,          -- optional custom answer checker
})
```

- **Node (skill) ids are globally unique** across modules. That keeps every v0.1 API keyed by
  `(nodeId, tier)`. `Modules.FindNode(nodeId)` returns the owning module, and `Register` rejects duplicates.
- Default input mode: a choice-only band always uses buttons. The trial ("trial" purpose) uses typed
  answers. Spark gets 4 choices, and Rune and Glyph are typed.
- `Session`, `Trial`, `Review`, `Mastery.Recommend(band, moduleId)`, `Report`, the Hub tiles, and the
  Lessons/Trial UI only talk to the registry. `tests/harness.lua` registers a dummy module and plays a
  round, a trial, and a report on it without engine changes.

## Answer modes and checking (v0.3)

`Modules.Generate` decides `p.mode` in this order:
1. `p.forceMode == "typing"` gives **typing** (copy a line). This applies even in a choice-only band.
2. `p.choices` already provided gives **choice**.
3. Otherwise `InputMode` (choice-only band → 3 buttons; trial → typed; Spark → 4 buttons; else typed).
   `p.choiceOnly` forces buttons (definitions, synonyms, word pairs).
4. Buttons with a number answer use `Util.MakeChoices`. With a string answer they use
   `Modules.TextChoices(answer, p.distractors, n)`, which drops case-insensitive duplicates.
   `p.chooseText` replaces the prompt when the problem is shown as buttons.
5. A typed string answer gives **text**. A typed number gives **input** (numeric, as before).

`Modules.Check(p, given, ctx)` calls `module.check(p, given, ctx)` when the module has one.
`ctx = {elapsed, tier}`: Session and Trial compute `elapsed = now - shownAt` from the `now` the UI
passes in (`GetTime()`), so Core never reads a clock for timing. The checker returns
`correct, info`. Session puts `info` on the result (`r.typing`) and keeps `rec.bestWpm` for accurate attempts.

Scribe checker (`ns.Scribe.Check`):
- **text / choice:** `NormalizeWord` lowercases, trims and collapses spaces, and strips surrounding
  quotes and a trailing `.!?`. The letters must then match exactly. `p.accept` can list alternates.
- **typing:** accuracy = 1 − Levenshtein(target, typed) / #target, after whitespace cleanup. It is
  case-insensitive on Spark/Rune and case-sensitive on Glyph. The pass mark is `TYPING_PASS` = 85/90/95%.
  WPM = (#target / 5) / (elapsed / 60), with elapsed ≥ 1 s and a cap of 200. WPM never decides
  pass/fail.

## Scribe's Scrolls (v0.3)

- `Core/ScribeData.lua` holds pure data: CVC words, letter words, sight words (with misspellings and a
  lore sentence), meanings (with near-synonym `grp` so close meanings never appear as distractors for
  each other), silent-e / digraph / plural tables, context sentences, synonym/antonym pairs with a
  meaning-cluster map, Adept/Magister spelling words with curated misspellings, prefixes/suffixes/roots,
  affix-building words, confused-word sentences with the rule (`why`), and typing lines by level.
- `Core/ScribeGen.lua` holds 15 generators (5 per band) and registers module `scribe`. Spelling
  prompt types by level: 1 scrambled letters, 2 one smudged letter, 3 several smudged letters,
  4 meaning + length + first letter, 5 meaning + length. At Spark they are shown as "choose the
  correct spelling" buttons (curated misspellings first, then generated swaps, doubles, or drops,
  never equal to the word).
- The harness validates every data entry: unique ids, lowercase-letter words, non-empty definitions
  that don't contain the word, misspellings different from the word and from each other, one `___`
  per sentence, context sentences that use their word, plural rules that match the spelling, synonym
  clusters, unique affix meanings, confused-word answers present once among the choices, and ASCII
  typing lines. It also generates every node × level × tier × purpose many times and checks the
  checker against the answer, its misspellings, and distractors.

## Trials: placement and exam (v0.2)

`Trial.New(moduleId, band, "placement"|"exam")` returns an object with the same interface as a
Session (`Next`, `Submit`, `Header`, `Charge`, `Finish`, `problem`, `index`, `total`, `streak`), so the
same problem screen runs it. The `noHints`, `isTrial`, and `resultView = "trialResult"` flags
change the UI. Format: 2 problems per skill. #1 is at level 2, and #2 is at level 4 if #1 was right,
otherwise level 1. Skill level is 1 (missed #1), 2 (#1 right, #2 missed), or 3 (both right). One try, no hints.

- **Placement** sets `placement[band] = {status = "done", result, history, override}`.
  `Trial.StartTier(nodeId)` = parent override > trial level > 1. `Mastery.IsTierUnlocked` treats
  tiers at or below the start tier as unlocked, and `CurrentTier` starts there. Placement never
  writes mastery, so reviews and minutes only come from real practice. `history` keeps the first
  result (the baseline) plus recent ones (max 10). A re-run clears the parent override.
- **Exam** unlocks when `EXAM_SKILLS_NEEDED` (4) of 5 skills have Rune or Glyph mastered (or the
  parent testing toggle is on). Pass = 8/10. Rewards: +50 per attempt; +100 and `AwardMastery()`
  minutes on the first pass. It stores `attempts`, `best`, `passed`, and `passedAt`.
- `Trial.Comparison(moduleId, band)` returns baseline placement, latest and best exam, and passed, which
  Report turns into "Placement vs exam" plus per-skill Growth arrows.
- Unfinished trials are never saved.

## Spaced review (v0.2)

- Mastering a tier sets `rec.review = {stage = 1, due = masteredAt + 1 day}`. `Review.INTERVALS = {1, 3, 7}` days.
- `Review.Due(now)` walks existing records only (it never creates any) and returns due items, oldest
  first. It returns nothing when `settings.reviews == false`.
- `Session.NewReview(items)`: up to 2 items × 3 problems at the tier's base + 1 level, with no adaptivity.
  The normal retry and hint flow applies. On finish, `Review.Apply` uses first-try results.
  Pass (≥ ceil(2/3 × n)) moves to the next stage. After stage 3, `done = true` and the item never
  comes back. Fail sets `fading = true` and stage 1 due in 1 day. **Mastery, shards, and minutes are
  never removed.**
- Fading tiers come first in `Mastery.Recommend` (Quick Drill). A practice round on that tier with
  5 or more of 6 first-try right clears fading.
- Clock: `ns.Env.time` (the game's `time()`), so tests inject a fake clock.

## Guide, cameos, and presentation (v0.4)

**Professor Fizzwick Coppercoil** is a neutral Steamwheedle Cartel goblin who runs the Academy as a "knowledge exchange" from Gadgetzan.
- **Core/Guide.lua** (pure) owns his lines.
  - Lines are locale keys `FZ_<EVENT>_<n>`, counted from enUS, so adding a line just means adding the next number.
  - 16 events: GREET, ROUNDSTART, CORRECT, COMBO, OVERCHARGE, WRONG, HINT (the parrot, with `%s` = the hint), MASTERED, RANKUP, EXAMSTART, EXAMPASS, EXAMTRY, TRIALSTART, TRIALDONE, REVIEW, FADING.
  - Each event draws from a shuffle bag, so every line is used once before any repeats. The new bag never starts with the line just said.
- **UI/Guide.lua** draws the strip under the hub content.
  - The Parent Panel sets `hideGuide` to take the full height.
  - Lessons and Trial call `GuideUI.Say(event)` at the matching moments, and **Hint** calls `GuideUI.Parrot(hint)`.

**Cameos.** `Guide.Cameo(kind, faction, now, settings)` decides whether a leader appears.
- Kinds: RANKUP, EXAMPASS, MILESTONE (every 5th mastered tier across all subjects, from `Progress.TotalMastered()`).
- At most one every 300 seconds, and the Parent Panel can turn them off.
- `faction` comes from `UnitFactionGroup` via `Compat.Faction()`. Horde gets Thrall, Alliance gets King Magni Bronzebeard (v0.5; Bolvar in v0.4). Neutral or nil gets nothing, and Fizzwick celebrates alone.
- Lines are `CAMEO_<HORDE|ALLIANCE>_<KIND>_<n>`. Cameos are text only and never voiced.
- The rank-up celebration card shows first; the cameo appears when the card closes, so the two never overlap.

**Models, all loaded at runtime from the client.** `Guide.CAST` lists the display IDs and creature IDs for each character.
- `Compat.SetModel` tries each candidate in turn: `SetDisplayInfo`, then `SetCreature`, each through `pcall`.
- 1.5 seconds later it checks `GetModelFileID` on modern clients, where 0 means the ID loaded nothing. A failed ID is skipped for the rest of the session, and the next candidate is tried.
- When every candidate fails, or the client has no `PlayerModel`, the portrait shows an in-client icon.
- The model is re-applied in OnShow because some clients drop models that were set while hidden.

| Character | Primary display (NPC) | Fallbacks | Icon fallback | Confidence |
|---|---|---|---|---|
| Fizzwick (stand-in model) | 7340 (Nixx Sprocketspring, Gadgetzan engineering trainer, NPC 8126) | 7217 (Krinkle Goodsteel, 5411), 7136 (Sovik, 3413), then the creature IDs | Trade_Engineering | IDs high, Forever rendering medium |
| Horde leader | 4527 (Thrall, NPC 4949) | creature 4949 | INV_BannerPVP_01 | IDs high, Forever rendering medium |
| Alliance leader | 3597 (King Magni Bronzebeard, NPC 2784) | creature 2784 | INV_BannerPVP_02 | IDs high, Forever rendering medium |
| Sprocket the parrot | (icon only) | | INV_Misc_Gear_01 | high |

The IDs were cross-checked on Wowhead's Classic and Retail NPC pages, and both list the same display IDs. Nobody has run them on Forever yet. v0.5 switched the Alliance leader from Bolvar (5566 / NPC 1748) to Magni Bronzebeard, the classic-era King of Ironforge, at Hex's request.

**Visuals.**
- Hub: the dialog-box border and background, the header plate, framed icons (the `UI-Quickslot2` slot), and the dialog divider under section headers. Everything uses in-client textures, with a colored-backdrop fallback when `BackdropTemplate` is missing.
- `Widgets` adds:
  - `Reveal`: an AnimationGroup with alpha plus scale, and an OnUpdate fallback.
  - `Pulse`: a looping alpha bounce, or a steady glow as the fallback.
  - `CountUp`.
  - `Header` and `FramedIcon`.
- **Reduced motion** (`settings.reducedMotion`) turns off Flash, Sparks, Float movement, Reveal, Pulse, and CountUp. Each one shows its final state immediately.

**Sound (Core/SoundEvents.lua, pure).**
- `S.Plan(event, settings, missing)` returns an ordered list to try: an optional custom file first, then the event's kits. It returns nil when the addon is muted or the level is "important" and the event isn't flagged important.
- `Compat.Sound` plays the plan on the chosen channel (`SFX`, `Master`, `Dialog`, or `Ambience`).
- A custom file that fails to play is added to `Compat.missingSounds` for the rest of the session.
- Kits are listed oldest first so they exist on every client. Each event has at least one numeric ID, which the harness enforces.
- Since v0.8 the custom files ship: 19 original generated effects (`Media/Sounds/<event>.ogg`, incl. the new `flight` event for the In-Flight toast). Nothing is extracted from the game; the kits stay as the fallback. `Media/Sounds/README.md` documents the files, prompts, mastering targets and the voice.

**Faction neutrality is tested.**
- The host strings must not contain any faction city or faction name: forge and scribe lore, trial and exam lore, Fizzwick's lines, praise, and review strings.
- The review strings must not say "rune".
- Lesson content may mention any city, and a few sentences were rebalanced toward neutral places.

## Lore Chronicles and the Lore Quiz (v0.5)

**Lore Chronicles** (`Core/LoreData.lua` + `Core/LoreGen.lua`, module id `lore`) is registered exactly like Scribe's Scrolls. Trial, review, exam, mastery, report, and Parent Panel work unchanged.
- **Data.** `LoreData` holds original, kid-safe passages. Each entry has `lv` 1–3, and the generator level maps to it (1–2 → 1, 3 → 2, 4–5 → 3, else the nearest `lv` that exists).
  - `SENTENCES` and `STORIES` (literal who/what/where answers) and `SEQUENCES` for Initiate.
  - `PASSAGES_A` (main idea, feelings, cause, vocabulary) and `BUILD` (word tiles) for Adept.
  - `PASSAGES_M` (inference, purpose, summary), `COMPARE` (a Horde and an Alliance account of one place), `GRAMMAR` (one correct sentence plus 3 with errors, and `why`), and `WRITE` (prompt, model answer, keyword rubric, `need`) for Magister.
  - `QUIZ` for the adult track.
- **Shuffle bags** (`Lore.Draw`) are kept per pool and data level, so a passage repeats only after the whole pool has been seen.
- **Answer modes.**
  - Reading questions preset `p.choices`, so they are always buttons. `Modules.Generate` marks them `choiceOnly`. Initiate gets 3 buttons, everyone else 4.
  - `lc_build` and `lc_written` return `answer`, `distractors`, and `chooseText` instead, so the normal input-mode rules apply: buttons on Spark, a typed `text` answer on Rune, Glyph, and trials.
  - `p.wide` asks the UI for a 420-pixel edit box.
- **`Lore.Check`.**
  - Choice answers use equality.
  - `build` normalizes the answer (lowercase, punctuation to spaces, spaces collapsed) and compares it to the sentence.
  - `rubric` counts keyword groups. A multi-word keyword is a phrase match, a keyword of 4+ letters is a prefix match, and a shorter one must be a whole word. The answer passes when `matched >= need` and it has at least 3 words. The check returns `{rubric = true, matched, need}`, and the problem screen shows "Key ideas found: N of M" instead of typing stats.
- **Fairness.** `lc_compare` shows the two accounts in random order. Host strings (Zixi's lore, trial and exam lines, quiz intro) are in the harness neutrality list.
- **Limits.** Problem text is at most 480 characters (the longest generated today is about 360) and choices at most 80, both enforced by tests. The card uses a 12-point font above 320 characters, and long button labels wrap onto two lines.

**Unbanded modules.** New registry flags, used first by the **Lore Quiz for Everyone** (`lorequiz`):
- `unbanded = true`: there is a single `bands.everyone`, and `Modules.Nodes` returns it whatever band is asked. `Modules.BandIds(module)` gives the bands a module really has. Review walks `BandIds`, so no tier is visited twice. The report prints one "Everyone (all ages)" section.
- `noTrials = true`: `Trial.NeedsPlacement` and `ExamStatus` return false, and `Trial.New` returns nil. The skill list hides the exam button, and the trial view redirects to the skill list.
- `hidden = true`: no hub tile (`Modules.Visible()`).
- `linkModule` + `linkKey`: a button at the bottom right of the skill list opens the linked module. Lore Chronicles links to the quiz, and **Story lessons** links back.
- Saved data is unchanged: quiz progress lives under `char.modules.lorequiz.nodes`, like any other module.

## Posed art (v0.5.1; slots since v0.5)

- `Core/Art.lua` is pure logic.
  - It maps each guide event to a pose with `EVENT_POSE`. Three extra pseudo-events have no line of their own: `IDLE`, `EXPLAIN`, `BEST`.
  - `SUBJECT_POSE` sets the idle pose per module (lore and lorequiz → researching, runeforger → tinkering, else thinking).
  - `Candidates(pose, small)` gives the order `<pose>_head` (small only), `<pose>`, `greet_head`, `greet`.
  - `Sprocket(state, ...)` tries the wanted state first, then the other one.
  - It returns texture paths only for files listed in `ns.ArtManifest`.
- `Media/Art/Manifest.lua` lists the 26 shipped files. It's rewritten by `tools/convert_art.sh`.
- `UI/Guide.lua`:
  - `ShowPose(holder, pose, small, allowModel)` walks the candidates. A file whose `SetTexture` returns false goes into `missingArt` and the next candidate is tried. After that comes the model, then the icon. Heroes are hidden instead.
  - `ApplyFace(event[, pose])` and `Pose(pose)` drive the strip using the head crops.
  - `ProblemShown(moduleId, hintAvailable)` is called by every problem render. It sets Sprocket to curious, bright or dim, and schedules the idle pose after `IDLE_DELAY` (2.5 s). A token cancels it if a new line comes first.
  - `Parrot(hint)` switches Sprocket to squawk and Fizzwick to teaching.
  - `Hero(parent, size)` and `ShowHero(holder, pose)` handle the full figures on the reward, trial-result and rank-up screens. Each is a portrait with no model, hidden without art. Reduced motion skips the fade-in.
- Lessons calls `Pose("teaching")` on the worked example and `Pose("surprised")` on `r.newBestWpm`.
- Format: power-of-two 32-bit uncompressed TGA with alpha, bottom-left origin (descriptor 0x08). Full figures are 512, head crops 256.
  - Head crops come from `tools/make_heads.py`: the widest olive skin blob in the top 45% of the figure is the face. The crop is a 250 px square starting 16% above it, lifted up to 25 px to keep the hair, padded with transparency, then resized to 256.
  - The art is Hex's original work, so it doesn't conflict with the rule against extracted Blizzard assets.
- Per-skill icons: `Core/SkillIcons.lua` maps node IDs to `Interface\Icons\...` paths. `Modules.Register` fills `node.icon` from it (else the module icon), and the forge rows use `node.icon`.

## Murloc Boarding Party (v0.6)

- **`Core/Boarding.lua` is pure.** `B.New(band, route)` returns a game object driven by `Tick(dt)` and `Input(fullText)`.
  - **Deck:** positions run 0 (rail) to 100 (wheel). Each murloc's speed is `100 / ((base + perChar * #need) * route.pace)`, slower for the boss (`bossSlow`).
  - **Spawning:** at most `maxOnDeck` at a time. The next arrives after `max(gap, #need / cps * pace)`, where `cps` is the band's design typing speed. An empty deck shortens the wait to `EMPTY_DECK_WAIT`, so fast typists aren't kept waiting.
  - **Waves:** waves come in turn, then the Tidehunter.
  - **`Input` diffs the edit-box text against `typed`:**
    - Appending checks each new character against the target's `need`. With no target, the first character locks onto the murloc closest to the wheel that starts with it.
    - A wrong character returns the old text, so the box reverts. It counts a typo and breaks the streak, but progress stays.
    - Shorter text is a backspace. An empty box drops the target.
    - Finishing an order knocks the murloc out: +1 meter, or +2 if clean.
  - **Typing forms:** `Prepare` builds the typing form. Younger bands are lowercased, keep only letters, digits and single spaces, and keep `map` so the UI can color the original text. Magister uses the exact text.
  - **Failing:** Initiate murlocs stop at `WAIT_AT` (no fail state). In other bands a murloc that reaches 100 costs a wheel point (the Tidehunter is pushed back to 40), and 0 points ends the voyage.
  - **Broadside:** a full meter (`METER_MAX = 6`) clears the regular murlocs, and the boss goes back to 0, stunned 3 s.
  - **Other rules:** `Tick` clamps dt to 0.5 s, and `paused` stops everything.
  - **Events** (`spawn`, `wave`, `waveClear`, `boss`, `target`, `splash`, `stumble`, `broadsideReady`, `broadside`, `bossHit`, `wheel`, `atWheel`, `win`, `lose`) are queued for the UI.
  - **Draws:** a shuffle bag per pool. It avoids an order whose first letter matches one already on deck.
- **`B.Record`** scores and saves the game under `char.modules.scribe.boarding`, created lazily, so there's no schema change.
  - It stores counts, best WPM per band, cleared routes per band, and a 10-entry log.
  - It pays shards through `Progress.AddShards` and adds the time to `stats`.
  - Routes unlock when the previous route was cleared in any band, or always with the parent `unlockAllTiers` setting.
  - `B.ReportLines()` feeds the Scribe's Scrolls section of the report.
- **The registry:** a module may declare `game = { view, key, tileKey, tipKey }`. The hub tile gets a shortcut button and the skill list's link button opens the view. Scribe's Scrolls declares `boarding`.
- **`UI/Boarding.lua`** is one view with three panels: setup, play and result.
  - **Murlocs** are pooled icon slots with tints. Labels above them are clamped to the deck, and the typed part is colored green.
  - **The Tidehunter** is a `GuideUI.Portrait` showing a cast entry (display 1995 / creature 127 → murloc icon).
  - **The input box** reverts typos inside `OnTextChanged`, guarded against its own `SetText`.
  - **OnUpdate** ticks only while playing. `OnHubHidden` and Escape pause.
  - **Fizzwick at the wheel** is a head-crop hero that mirrors the pose of each line.
  - **Splashes** use `W.Animate` to fling the icon over the rail, and a slot stays busy until the animation ends. Reduced motion hides it immediately.
- **Tuning:** the numbers come from a simulated typist with 8% typos.
  - Adept routes need about 7 / 10 / 12 WPM; Magister about 17 / 20 / 24 WPM.
  - A voyage takes about 1.5 to 5 minutes, depending on speed and route.

## In-Flight Lessons (v0.7)

- **Split:** `Core/Flight.lua` holds every rule as pure functions; `UI/Flight.lua` feeds it and acts.
  - `F.Update(tracker, onTaxi, now)` turns a stream of yes/no samples into `takeoff` / `landed` edges, so
    polling and events can both call it as often as they like.
  - `F.Decide(tracker, now, ctx)` returns `toast`, `auto`, `wait` or `skip`. Skips (off, muted, instance,
    Academy open, no band, cap reached) end the flight's chance; waits (combat, under `TAKEOFF_DELAY` = 2.5 s)
    try again on the next check. `F.MarkOffered` makes it once per flight.
- **Detection:** `UnitOnTaxi("player")` through `Compat.OnTaxi`, polled every 0.5 s (`C.settings.flightPoll`).
  `PLAYER_CONTROL_LOST/GAINED`, `TAXIMAP_CLOSED` and `PLAYER_ENTERING_WORLD` are registered through
  `C.RegisterEvents` (pcall per event, since unknown event names raise on modern clients) and only trigger an
  early check plus one 0.5 s later. Polling is the source of truth because the event behavior on WoW Forever
  is unverified.
- **Round:** `Session.New(nodeId, tier, now, size)` takes an optional size (5 for flights, clamped to 1..6).
  Sessions and summaries carry `flight = true`; the reward view shows "Another round" only while
  `F.CanOfferAnother` (still on the taxi). Reviews keep their normal 3/6-problem size, because the pass rule
  needs every item's 3 problems.
- **Landing:** hides the toast and updates the reward view. It never opens or closes the hub, so combat hiding
  and the resume prompt are untouched.
- **Cap rule:** `F.CapReached(earned, cap)` is `cap > 0 and earned >= cap`. A cap of 0 means "no bonus
  minutes", not "no learning", so it doesn't block.
- **Test mode:** `/aa flight test` sets a pretend taxi for 120 s (`FU.simUntil`), resets the edge, ignores the
  session mute, and prints the reason when a skip happens. `/aa flight land` ends it.

## Fizzwick's voice (v0.8)

- **Split:** `Core/Voice.lua` (pure) decides; `UI/Guide.lua` asks and plays through `Compat.PlayVoice`.
- **Clips:** `V.LINES` maps one text key per event (`FZ_<EVENT>_<n>`) to `{ file, dur, big }`; `V.EVENT_CLIPS`
  holds event-wide clips that fit every line (Sprocket's `HINT`). Files live in `Media/Sounds/VO/`. `dur` is
  measured from the shipped file and drives the busy window. The voice is an original ElevenLabs Voice Design
  voice (`V.VOICE_ID`), never a clone or imitation of a real or game voice.
- **Text and audio always agree:** a keyed clip plays only when that exact key was picked for the bubble.
  `GU.PickLine` asks `V.PreferKey` first: the voiced key is forced while the event hasn't been heard this
  session *and* the clip could play now (so a forced line is never silent). Otherwise the normal shuffle
  bag picks. `Guide.LineKey` takes a forced line out of the bag so it doesn't repeat right away.
- **Throttle (`V.Decide`):** off/mute -> nothing; nothing while `busyUntil` (start + dur + 0.25 s); `V.GAP` = 6 s
  between clips; `V.REPEAT_GAP` = 45 s for the same file. `big` clips (rank up, mastered) skip busy/gap and
  `Compat.PlayVoice(path, true)` stops the previous handle with `StopSound(handle, 250)`.
- **Failures:** a clip `PlaySoundFile` refuses is put in `GU.voice.missing` for the session, like effects.
- **Goodbye:** `Hub` OnHide calls `GU.Goodbye()` (bye clip, no bubble) when the window was open for at least
  `H.BYE_AFTER` = 20 s and it wasn't a combat hide.
- **Settings:** `settings.voice = { enabled = true }` (defaults filler, no schema bump). `V.Enabled` is false
  when either the voice or the whole sound is off. Channel/volume come from `settings.sound.channel`.
- **Adding a line:** generate with the saved voice, master with `tools/master_audio.py`, drop it in `VO/`,
  add the key to `V.LINES` with its duration and a row to the Sounds README. The harness checks the key exists,
  the file is a real Ogg, the README lists it and the duration is sane.

## Azeroth Naturalist and the Field Journal (v0.9)

- **Module #4** (`Core/NaturalistGen.lua`, data in `Core/NaturalistData.lua`), registered like the others:
  15 generators, `choiceOnlyBands = { initiate = true }`, `textAnswers`, its own `check` (`NA.Check`).
  Most skills draw curated entries `{ lv = 1..3, q, a, d = { distractors, best first }, why, t = { typed alts }? }`
  through shuffle bags (`NA.Draw`, a full pool before any repeat). Habitats, living/not living, food chains,
  matter states, the water-cycle order and life cycles are partly generated from small data tables.
- **Typed answers** only when an entry has `t` (accepted spellings) and the band is not Initiate. Problems
  set `typed`, `distractors` and `alts` and leave `choices` empty, so `Modules.InputMode` decides: buttons on
  Spark practice, a text box on Rune/Glyph and trials. `NA.Normalize` lowercases, strips punctuation and a
  leading article before comparing. Explanations and predictions always use buttons.
- **Distractor safety:** food-chain "who eats X" distractors only come from below X in its chain (or other
  chains' plants), because higher animals might really eat X. The harness checks this.
- **Guide events per module:** `module.guideEvents = { ROUNDSTART = { "NATSTART", every = 1 }, CORRECT = { "NATCORRECT", every = 3 }, ... }`.
  `Lessons.EventFor` swaps the generic event for the module's own on the 1st, (1+every)th... time, so the subject
  has its own voice without losing combo/overcharge lines.
- **Flight:** `module.flightNodes[band]` (preferred skills, passed to `Mastery.Recommend(band, module, prefer)`,
  ignored once all are fully mastered) and `module.flightEvent` (Fizzwick's line instead of FLIGHTSTART).
- **Field Journal (`ns.Journal`):** `SPECIMENS[nodeId][tier]` = `{ id, name, zone, icon (in-game), note }`.
  `Session:Submit` calls `Journal.Collect(nodeId, tier)` when a tier is newly mastered and puts the specimen on
  the result (`r.specimen`) and the round summary (`specimens`). `Journal.Status` is `missing | collected | faded`;
  faded means this character's tier is fading or its review is due, so the journal doubles as a review prompt.
  Pages are never removed. `Journal.Sync()` (run in `Progress.Bind` and when the journal opens) collects every tier
  the current character has mastered, which covers upgrades and new account files.
- **UI (`UI/Journal.lua`, view `journal`):** band tabs, 5 x 3 grid, page panel; actions reuse `Lessons.StartRound`
  (missing page or fading) and `Lessons.StartReview` (due).

## Duel of Wits (v0.10)

Multiplayer learning races. Three layers, so the hard parts are testable headless:

- **`Core/DuelProto.lua` (pure): the wire format.**
  - Message = `AA<protocol>~<TYPE>~field~...`. Prefix `AzAcadDuel` (<= 16 chars), protocol `1`.
    Fields are escaped (`%` `~` `|` newline -> `%XX`), so no field can inject a separator or a chat escape code.
  - **Chunking:** anything over 250 bytes becomes `AC~<id>~<i>~<n>~<slice>` pieces of 200 bytes; the assembler is
    keyed by sender + id, accepts pieces in any order and drops partials after 20 s.
  - **Throttle queue:** ChatThrottleLib-style token bucket (burst 8, refill 1/s, well under the client's per-prefix
    limit). Progress/state messages carry a coalescing key, so a queued update is replaced instead of piling up.
- **`Core/Duel.lua` (pure): the engine.** `Duel.NewEngine{ me, realm, now, send, band, display, settings, context,
  isFriend, isBlocked, groupChannel, inGuild, queueChannel, queueJoin, queueLeave, notify }`; methods `Host`, `Accept`,
  `Decline`, `Start`, `Answer`, `Leave`, `Emote`, `QueueJoin/Leave`, `OnCombat`, `Receive(msg, channel, sender)`,
  `Update()`. It never calls WoW: transport, clock and context are injected.
- **`UI/Duel.lua`:** binds the engine to Compat (`C.SendAddonMessage`, `C.GroupChannel`, `C.IsFriend`, hidden channel),
  ticks it every 0.1 s from its own frame, and draws setup/waiting room, the invite pop-up, race and results.
  `Main.lua` routes `CHAT_MSG_ADDON` for our prefix and `/aa duel [name|queue|leave]`; combat calls `OnCombat`.

### Protocol (star topology)

The challenger hosts. Racers whisper the host; the host broadcasts on PARTY/RAID/GUILD (one message for everyone)
or whispers each racer (one-player and random duels).

| Type | From -> to | Fields | Reliability |
|---|---|---|---|
| `INV` | host -> scope | id, subject, length, scope, display, band, aliasA, aliasB, addonVersion | once (popup) |
| `ACC` | racer -> host | id, band, display, aliasA, aliasB, addonVersion | ACK + retry |
| `DEC` | racer -> host | id, reason (`declined/timeout/busy/combat/instance/parent/friendsOnly`) | once |
| `VER` | either | id, protocol | once; format frozen forever |
| `LOB` | host -> racers | id, subject, length, scope, n, n x (name, display, band, aA, aB, status) | re-sent every 10 s |
| `FUL` / `CAN` | host -> racer(s) | id (+ reason) | once |
| `STA` | host -> racers | id, seed, countdown, typeBand, subject, length, scope, n, n x (name, display, band, aA, aB) | ACK + retry |
| `PRG` | racer -> host | id, seq, answered, correct, elapsedMs, wpm, acc | seq-numbered, coalesced, keepalive 4 s |
| `FIN` | racer -> host | same as PRG | ACK + retry |
| `ST8` | host -> racers | id, seq, n, n x (answered, correct, time x10, status) by racer index | seq-numbered, 1 s (more for whispers) |
| `RES` | host -> racers | id, n, n x (answered, correct, elapsedMs, wpm, acc, status, valid) | ACK + retry |
| `LEV` | either | id, reason (`left/combat/...`) | once; silence timeout backs it up |
| `EMO` | racer -> racers | id, emote index (1-4) | once, rate-limited both ends |
| `ACK` | either | id, type acknowledged | - |
| `Q` | queued -> hidden channel | subject, length, band, nonce | every 8 s while searching |

- **Retries:** reliable messages repeat every 2 s up to 5 times until the matching `ACK`. Group-scope `STA`/`RES` go out
  once on the group channel, then repeat by whisper only to racers that haven't acknowledged.
- **Ordering:** `PRG` and `ST8` carry sequence numbers; anything not newer than the last accepted one is dropped.
  Duplicate `ACC`/`STA`/`FIN`/`RES` are re-acknowledged but applied once.
- **Handshake:** the version is in every header. A client that gets an `INV` with another protocol answers `VER`
  and tells its kid; the host shows the mismatch and a one-player duel closes. Non-`VER` messages with another
  protocol are ignored, so mismatched clients can never half-run a race.
- **Timeouts:** invite 25 s (auto-decline), empty lobby 120 s (20 s for a random match), racer silence 15 s during
  a race (marked `left`), maximum race `length x 45 + 20` s (still racing = `dnf`). If the host goes silent, each
  racer finishes its own questions and ranks the race locally ("partial"); a late `RES` still replaces it.
- **Combat:** the engine declines pending invites, leaves the queue and leaves an active race with reason `combat`.
  The other racers continue. In instances every invite is declined (Midnight-era clients also limit addon messages there).

### Questions

- `Duel.BuildSet(subject, band, seed, length)` seeds a Park-Miller generator with a hash of
  `seed:subject:band:length` and runs the normal generators through `Util.WithRNG`. All generators draw through
  `Util.Random` (Namespace's `random`), so the same inputs build the same set on every client and Lua build.
  The Lore/Naturalist shuffle bags (solo history) are swapped out while the set is built and restored afterwards.
- Spark (tier 1) practice problems, levels 1-3, nodes cycled through a seeded shuffle; anything that isn't buttons is
  re-rolled (duels are button races). Typing races use the youngest racer's band and its Scribe typing skill, so
  everyone types the same lines; a line is correct at the Spark typing pass mark (85%).
- Each racer uses its **own** band (from the host's `STA` list, not trusted for anything else).

### Scoring, anti-cheat, rewards

- Score = correct answers (more is better), then time = elapsed + 3 s per wrong answer (less is better). Exact ties
  (within 0.05 s) share the rank. `left` racers and invalid reports rank last.
- The host validates every report: integers, `correct <= answered <= length`, never going backwards, at least 0.4 s per
  answer on average, and elapsed no more than 8 s ahead of the host's own race clock. A failing racer is "not counted".
  This stops accidents and casual tampering, not a rewritten addon; rewards only ever change the cheater's own game.
- Rewards (each client, once per duel): 2 shards per correct, +5 finished, +10 win against a real opponent, max 40.
  2 bonus minutes for a finished race against an opponent who answered at least half the questions, max 10 per day
  from duels (`AzerothAcademyDB.duel.minutes/day`) and always within the shared daily cap (`Progress.AwardDuelMinutes`).
  Answers add to tier-1 `attempts/correct/time` (practice stats in the report) and never to `recent`, so duels can't
  master a tier.

### Safety design (kid-first)

- **Off switches, PIN-protected:** Parent Panel -> Duel of Wits settings: duels on/off (default on, covers group,
  guild and one-player duels), friends only (default off), allow random challengers (**default off**), duel name,
  clear blocked list. With duels off or friends-only, invites are declined automatically.
- **No free text anywhere.** No message type carries player-typed text. Emotes are indexes into four preset lines,
  rate-limited (one per 3 s, six per duel) on both sides. The only typed text in a duel is the kid's own typing-race
  line, which is checked locally and never sent.
- **Minimum data:** messages carry subject, length, age band, two alias indexes, scores and state. The queue beacon is
  subject, length, band and a random nonce. No level, class, zone, guild or real name is ever sent.
- **Random challengers never see names.** In `QUEUE` scope the display fields are sent empty and every screen shows
  the alias (preset adjective + creature chosen by the parent, randomised once on first load). WoW itself always gives
  addons the sender's character name; the addon uses it only to address whispers and to block.
- **Hidden queue channel:** `AzerothAcademyQ` is joined only while searching, removed from every chat window, and left
  as soon as a match starts, the search stops or times out (5 min), combat starts, or the parent setting turns off.
- **Matching** is limited to the same subject and length and an age band at most one step away.
- **Block** on every result row: blocked players' invites get a neutral "busy", their emotes and queue beacons are
  ignored. Nothing is reported anywhere; the list lives in the account SavedVariables and can be cleared by a parent.

## Gnomish Engineering and collection books (v0.11)

- **Module `gnomish`** (Core/GnomishData.lua + Core/GnomishGen.lua) follows the Naturalist pattern: curated entries
  (`{lv, q, a, d, why, t}`, shuffle bags via `Naturalist.Draw`) mixed with procedural generators. Node ids `ge_*`.
- **Grid engine (pure):** `GE.Step/Run/Flatten/Reaches/Shortest/Mutations/Mark`. A grid is `{w, h, bot={x,y,dir},
  goal, walls, marks}` with y = 1 at the top. Commands: `U/D/L/R` (absolute), `F/TL/TR` (relative), loops
  `{rep=n, body={...}}`. A blocked move leaves Boltby in place and flags `crashed`; generators only keep puzzles whose
  answer never crashes.
- **Uniqueness rules:** stop-puzzles letter the true end square plus decoys produced by one-mistake mutations (dropped,
  swapped or extra step, swapped turns); program/loop choices are kept only if they do NOT reach the gear (replayed with
  `GE.Reaches`; `p.programs` keeps them for tests); debugging puzzles are rejected unless exactly one step can be changed
  to reach the gear. The harness replays all of this for every generated grid puzzle.
- **Answers:** letters A-D (kept in order), program text, numbers (Modules builds number choices on Spark; typed on
  Rune/Glyph), True/False with yes/no alternatives. `GE.Check` = numeric compare, else `Naturalist.Check`.
- **Display:** `p.grid` → `W.Grid` (max 6 x 6, icons for Boltby/gear/rocks, letters as text), question text beside it;
  `p.code` → left-aligned smaller text. Duel races draw the same grid.
- **Collection books (`Core/Journal.lua`):** `Journal.RegisterBook{ moduleId, items, prefix, openEvent, newEvent, sound }`.
  Items are keyed node → tier and stamped with `nodeId/tier/moduleId`; entries live in `AzerothAcademyDB.journal.entries`
  keyed `"nodeId:tier"` (node ids are unique, so books share the table and no schema change was needed).
  `Count/All/FadedCount` take a module id (default `naturalist`, which keeps the v0.9 API), `Sync` covers every book,
  `Str(moduleId, suffix)` reads `L[prefix_SUFFIX]` with the `JOURNAL_*` strings as fallback. The "journal" view takes
  `{ moduleId }` or `{ nodeId, tier }` and otherwise opens the current subject's book.

## Librarian Quests (v0.12)

- **Module `librarian`** (Core/LibrarianData.lua + Core/LibrarianGen.lua), node ids `lib_*`, the same curated +
  generated mix as Naturalist/Gnomish. Seven curated lists (true/silly, young key words, fact/opinion, notes, sources,
  citing, research process); the rest is generated from small data tables (24 topics, 12 animals, 5 keyword templates,
  10 invented books, 5 two-source comparisons, 5 data tables).
- **Builders (pure, unit-tested):** `LB.Topics(n, distinctFirst)`, `LB.Contents(n, first, maxGap)` (rising start
  pages, returns the first page after the book), `LB.Index(n)` (ABC order, unique page numbers),
  `LB.Citation(book, parts)` ("Last, First. Title. Year.", any part can be dropped).
- **Answers:** shelf/topic/citation buttons, numbers (Modules builds number choices on Spark; typed on Rune/Glyph),
  typed words via `Naturalist.Check`. `LB.Check` = numeric compare, else `Naturalist.Check`. Tables, indexes, contents
  pages and citations set `p.code` for the left-aligned layout.
- **Neutral framing with real libraries:** stamps name Stormwind/Ironforge and Orgrimmar/Thunder Bluff equally often
  (7 / 7) plus neutral places; the subject suite's `balancedSides` option counts sided words in host strings, book items
  and curated data and requires the two sides within 2 of each other, instead of banning them.
- **Library Passport:** `Journal.RegisterBook{ moduleId = "librarian", prefix = "PASSPORT", newEvent = "LIBSTAMP",
  openEvent = "LIBPASSPORT", sound = "stamp" }`. Slash `/aa passport` maps through `BOOK_SLASH`.

## Data model (schema 7)

```lua
AzerothAcademyDB = {            -- account-wide: parent settings + daily minutes + Field Journal
  version  = 7,
  settings = { minutesPerMastery = 10, dailyCap = 60, unlockAllTiers = false, reviews = true,
               sound = { enabled = true, channel = "SFX", level = "all"|"important", custom = true },   -- v0.4
               reducedMotion = false, cameos = true,                                                -- v0.4
               minimap = { hide = false, angle = 225 },                                             -- v0.6.1
               flight = { mode = "off"|"toast"|"auto" },                                            -- v0.7
               voice = { enabled = true },                                                          -- v0.8
               duel = { enabled = true, friendsOnly = false, random = false,                        -- v0.10
                        alias = { adj, creature }, aliasPicked = true } },
  minutes  = { day = "YYYY-MM-DD", earned = 0 },   -- shared so alts can't double the cap
  pin      = { salt = "123456", hash = "..." },    -- soft lock only
  ui       = { point, relPoint, x, y },
  journal  = { entries = { ["nodeId:tier"] = { at = ts } } },                                       -- v0.9
  duel     = { blocked = { ["name-realm"] = true }, day = "YYYY-MM-DD", minutes = 0 },              -- v0.10
}
AzerothAcademyCharDB = {        -- per character: the kid's learning progress
  version = 7,
  profile = { band = "initiate"|"adept"|"magister", created = ts },
  shards  = 0,
  stats   = { rounds, problems, firstCorrect, time },
  duel    = { played, wins, finished },                                                             -- v0.10
  modules = { [moduleId] = {
    nodes = { [nodeId] = { tiers = { [1..3] = {
                attempts, correct, time, recent = {1,0,1,...} (last 10), mastered, masteredAt,
                fading, review = { stage, due, last, done }, bestWpm (typing skills) } } } },
    placement = { [band] = { status = "done"|"skipped", date, result, history = {...}, override = { [nodeId] = tier }, migrated } },
    exams     = { [band] = { attempts = {...}, best, passed, passedAt } },
  } },
}
```

**Migration v6 → v7** (v0.10): `settings.duel`, `duel` and `char.duel` are filled in by `ApplyDefaults`; both
versions go to 7. The first `Bind` that sees no `aliasPicked` picks a random duel name once.
Duel tier-1 practice records add a `duel` counter next to `attempts`.

**Migration v5 → v6** (v0.9): `journal` is filled in by `ApplyDefaults`, both versions go to 6, and
`Progress.Bind` then runs `Journal.Sync()`, so Naturalist tiers already mastered get their pages (with
their original `masteredAt` date). `ResetProfile` wipes only the character, so the family journal stays.

**Migration v4 → v5** (v0.7): `settings.flight` is filled in by `ApplyDefaults`. If the account was
below 5 and the old `taxiNudge` was `false`, `flight.mode` becomes `"off"`. It runs once (the account
version is then 5), so a later choice sticks. The old `taxiNudge` value is left in place and no longer read.

**Migration v3 → v4** (v0.4) is a version bump. `ApplyDefaults` merges the new settings without
overwriting anything a parent already set, including a partial `sound` table.

**Migration v2 → v3** (v0.3) is a version bump only. Scribe state is created lazily under
`char.modules.scribe`, and `P.upgradedFrom` records the old version for the session.

**Migration v1 → v2** (`Progress.Bind`, idempotent): `char.nodes` moves to
`char.modules.runeforger.nodes`, and every mastered tier gets a review scheduled from `masteredAt`.
Every band the kid already played gets `placement = {status = "skipped", migrated = true}`, so nobody
is pushed into a trial on upgrade. New defaults fill in (`fading`, `settings.reviews`), and the PIN, minutes,
UI position, shards, and stats are untouched. The report notes "carried over from v0.1".

## Learning rules (all constants at the top of the files)
- **Problem**: `{text, answer, display?, verify, hint, explain, choices?|input, icons?}`.
  `verify` is a Lua expression using `ANS`. The harness evaluates it to prove the answer is right.
- **Answer mode**: Initiate always uses multiple choice with 3 options (2 for "which is more" pairs).
  Adept and Magister use 4 choices on Spark tier and typed answers on Rune and Glyph. Distractors come
  from likely mistakes first, such as neighboring times-table facts or the left-to-right answer in
  order-of-operations problems.
- **Difficulty levels** run 1–5. Each tier has a range: Spark 1–3, Rune 2–4, Glyph 3–5.
  3 first-try corrects in a row raise the level. 2 misses in a row (any try) lower it.
- **Mastery** is counted on first tries only, over a rolling window of 10, and needs at least 9 right (85%).
  Once a tier is mastered it stays mastered.
- **Shards**: Spark 10, Rune 15, Glyph 20 per first-try correct. A combo (streak of 3 or more) adds 5, and
  overcharge (streak of 5 or more) doubles the total. A correct retry gives 3. Finishing the 6-problem round
  gives 10, and mastering a tier gives 50. Shards are never taken away.
- **Minutes**: each mastery grants `minutesPerMastery`, clamped to `dailyCap - earnedToday`.

## Adding the next module (e.g. Scribe's Scrolls)
1. `Core/<Module>Gen.lua`: generators that return the problem shape above (a custom `check` can handle
   word answers), then a `ns.Modules.Register{...}` call. Add the file to the TOC after `Core\Report.lua`.
2. That's enough for it to appear as a hub tile and get skill lists, rounds, placement, review, exam,
   Parent Panel rows, and the report. Remove its placeholder from `Hub.COMING_SOON`.
3. Add locale keys to `enUS.lua`, and generator cases to `tests/harness.lua`.
4. String answers, typing, button-only problems, and custom checkers are already supported (see
   "Answer modes and checking"). Scribe's Scrolls is the reference for a non-math module.

## Known design debts
- Fizzwick uses a stand-in goblin NPC model (Nixx Sprocketspring) as a fallback only. Since v0.5.1 Hex's posed art ships in `Media/Art` and replaces it in the strip. The cameo card still uses models.
- The written-answer rubric matches keywords, not meaning (see the README's known limits). A future version could add per-prompt "must not contain" words or synonyms.
- Lore content is a fixed hand-written set. A content pass (more passages per level) is the cheapest way to add variety.
- Cameo, Fizzwick, and all lore lines are enUS only, like everything else. Translations are deliberately deferred to the end of the project, and the locale scaffold is in place.
- Scribe word data is English-only. Translating it means separate word lists per locale, not string tables.
- `/aa drill` still drills the subject opened most recently. Each hub tile now has its own Drill button.
- Problem text templates use `%d` in a fixed order (Lua 5.1 has no positional format arguments), so
  translations must keep that order or move to a token-replacement formatter.
- Thousands separators are hardcoded as commas.
- Reviews use the local clock; a big clock change can make several reviews due at once (capped at 2 per round).
- Duel of Wits trusts the host for the final ranking and only sanity-checks racers; a modified host could misreport.
  "Rematch?" is an emote, not a one-click rematch (the challenger starts a new duel).
- Duels haven't run between two real clients yet; channel/whisper behaviour on Forever is assumed to match Retail.
