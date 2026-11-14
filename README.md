# Azeroth Academy v0.13.0 (test build)

A free learning addon for kids ages 5 to 13. Lessons are framed as Academy quests in Azeroth.
This build has the **Main Hub** and two subjects: **Rune Forger** (math) and, new in v0.3,
**Scribe's Scrolls** (spelling, vocabulary, and typing). Each has 15 skills across 3 age bands.
It also has progression (shards, ranks, bonus minutes), a PIN-gated **Parent Panel**, and,
for every subject, a placement test, spaced review, and a mastery exam.
New in v0.4: **Professor Fizzwick Coppercoil**, a neutral Steamwheedle goblin teacher who runs the
Academy from Gadgetzan. His mechanical parrot Sprocket delivers the hints. You also get short
text-only cheers from your faction's leader at big moments, a framed and animated look, and a
sound system you can customize.
New in v0.5: **Lore Chronicles**, subject #3 (reading comprehension and writing, with original
short stories from all over Azeroth), an optional unbanded **Lore Quiz for Everyone** for older
kids and grown-ups, **King Magni Bronzebeard** as the Alliance cameo, and slots for your own
Fizzwick portraits (`Media/Art`).
New in v0.5.1: **Hex's posed art for Fizzwick and Sprocket ships with the addon**. That's 11 Fizzwick poses
and 2 Sprocket states, full figure at 512 plus head-and-chest crops at 256, and each moment picks
its own pose. Every skill now also has its own in-game icon.
New in v0.6: **Murloc Boarding Party**, a typing mini-game inside Scribe's Scrolls (Hex's idea). You crew a
Steamwheedle ship out of Booty Bay, and murlocs climb aboard carrying crew orders. Type an order and
your crew knocks that murloc overboard.
New in v0.7: **In-Flight Lessons**, a quick optional round while you ride a flight path.
New in v0.8: **real sounds and Fizzwick's voice**. 19 original sound effects ship with the addon, and
Professor Fizzwick speaks 12 of his lines in an original designed voice (switch it off in the
Parent Panel or with `/aa voice off`).
New in v0.9: **Azeroth Naturalist**, subject #4 (science). Field Warden Bramble Quickroot runs the
greenhouse at the Knowledge Exchange in Gadgetzan. Kids sort creatures by zone, follow food chains and the
water cycle through Thousand Needles, mix states of matter in a goblin alchemy lab, and design fair tests.
Every mastered tier adds a specimen page to the new **Field Journal**, a bestiary shared by the whole account.
New in v0.10: **Duel of Wits**, learning races with other players. Challenge your group, your guild or one
player (or, only if a parent allows it, a random challenger). Everyone answers the same kind of questions at their
own age band; most correct wins and time breaks ties. Nothing typed is ever sent: only scores and four preset emotes.
New in v0.11: **Gnomish Engineering**, subject #5 (programming). Tinker Nixa Sprocketwhirl runs the workshop at the
Knowledge Exchange, and kids program **Boltby**, a clockwork critter, on a command grid: steps in order, patterns,
directions, loops, IF/ELSE, debugging, then variables, functions, boolean logic, algorithms and pseudocode. Every
mastered tier adds a gadget page to the new **Blueprint Binder**, and the subject joins Duel of Wits.
New in v0.12: **Librarian Quests**, subject #6 (research skills). Head Librarian Tamsin Quillfeather keeps the
library of the Knowledge Exchange and trades books with libraries of every faction. Kids find the right shelf, sort
in ABC order, use contents pages and indexes, pick key words, tell fact from opinion, take notes, judge sources, cite
books, compare two accounts and read data tables. Each mastered tier earns a stamp in the **Library Passport**.
New in v0.13: **Mechanics Academy**, subject #7 (group tactics with reading and math). Coach Brakka Steelwhistle runs
the Training Ring: tank/healer/DPS roles, "avoid the fire" grid puzzles, health bars, threat, positioning, interrupts,
cooldowns, classes and racial traits, plus DPS math, mana budgets, priority lists and boss mechanics. The class and
race lists follow your game client (9 classes on WoW Forever and Classic Era, 13 on Retail). Each mastered tier adds a
card to the **Tactics Deck**. Every hub tile is now a real subject.
Progress stays on your computer. The only thing the addon ever sends is Duel of Wits race data, inside the game, to
the players you race (see "Duel of Wits").

## Which game clients it targets

| Client | Interface | Status |
|---|---|---|
| **WoW Forever** (1.60.1, Blizzard's "forever"/"camelot" game type) | **16001** | **Primary target.** |
| Retail / Midnight 12.1.5 (and the 12.1.7 PTR) | 120105, 120107 | Secondary. |
| Classic Era 1.15.9 | 11509 | Best effort only, never prioritized. |

There's a single `AzerothAcademy.toc` with `## Interface: 16001, 120105, 120107, 11509`, and
the addon detects which client it's on at runtime (see DESIGN.md). Warcraft Wiki recommends a
comma-separated list over per-client TOC files. It also keeps one file list, so the clients
can't drift apart.

**How sure is this?** About the version number: pretty sure. warcraft.wiki.gg (TOC format page
and Patch 1.60.1 API page, checked 2026-11-13) lists WoW Forever as 1.60.1, build 70790,
interface 16001. Install guides from Nov 2026 say the same. WoW Forever runs on the **modern
Mainline UI code**, including Midnight's addon restrictions. It does not use the old Classic
code. This addon only draws its own windows and reads no combat data, so those restrictions
don't affect it.

**Not tested in a real game client yet.** This build hasn't run inside WoW. It passed
syntax checks, lint, a headless test of the core logic, and UI smoke tests against a mock of
the WoW API (see "Developer checks"). Your first in-game test is the real one. If WoW Forever
moves to a new patch and the addon shows as "out of date", type
`/dump select(4, GetBuildInfo())` in game and put that number into the `## Interface:` line.
Or tick **Load out of date AddOns** on the AddOns screen.

## Install

1. Unzip `AzerothAcademy-v0.5.zip`. (Upgrading from an earlier version? Delete the old `AzerothAcademy` folder first, then copy the new one in. Progress carries over automatically.) You should get a folder named `AzerothAcademy` with
   `AzerothAcademy.toc` directly inside it.
2. Move that folder into the AddOns folder:
   - WoW Forever: `World of Warcraft\_forever_\Interface\AddOns\`
     (Battle.net app → World of Warcraft → pick **WoW Forever** in the version menu → gear icon → *Show in Explorer*.
     Create `Interface\AddOns` if they don't exist.)
   - Retail: `World of Warcraft\_retail_\Interface\AddOns\`
3. The final path should be `...\Interface\AddOns\AzerothAcademy\AzerothAcademy.toc`
   (not `AddOns\AzerothAcademy\AzerothAcademy\...`).
4. Start the game. On the character screen, click **AddOns** and make sure **Azeroth Academy** is ticked.
5. Log in. Chat should show `Azeroth Academy: Loaded v0.8.0. Type /aa to open the Academy.`

## Slash commands

| Command | What it does |
|---|---|
| `/aa` or `/academy` | Open or close the Academy hub |
| `/aa drill` | Jump straight into a recommended round in the subject you opened last |
| `/aa forge` | Open the Rune Forger skill list |
| `/aa scribe` | Open the Scribe's Scrolls skill list |
| `/aa lore` | Open the Lore Chronicles story list (v0.5) |
| `/aa quiz` | Open the Lore Quiz for Everyone (v0.5; no age band, no trial) |
| `/aa nature` | Open the Azeroth Naturalist skill list (v0.9; `/aa science` works too) |
| `/aa journal` | Open the Field Journal (v0.9; specimens you collected by mastering Naturalist skills) |
| `/aa gnomish` | Open the Gnomish Engineering skill list (v0.11; `/aa engineering` and `/aa code` work too) |
| `/aa blueprints` | Open the Blueprint Binder (v0.11; gadget blueprints you collected by mastering Gnomish Engineering skills; `/aa binder` works too) |
| `/aa library` | Open the Librarian Quests skill list (v0.12; `/aa librarian` and `/aa research` work too) |
| `/aa mechanics` | Open the Mechanics Academy skill list (v0.13; `/aa tactics` and `/aa training` work too) |
| `/aa deck` | Open the Tactics Deck (v0.13; tactics cards you earned by mastering Mechanics Academy skills; `/aa cards` works too) |
| `/aa passport` | Open the Library Passport (v0.12; library stamps you earned by mastering Librarian Quests skills; `/aa stamps` works too) |
| `/aa review` | Start a Review Time round (if any reviews are due) |
| `/aa trial` | Open the placement trial for the current subject and band |
| `/aa exam` | Open the mastery exam screen for the current subject (it says how many skills are still needed) |
| `/aa parent` | Open the Parent Panel |
| `/aa status` | Print rank, shards, today's minutes, and the detected client and interface |
| `/aa minimap` | Hide or show the minimap button (v0.6.1) |
| `/aa flight [off\|toast\|auto]` | In-Flight Lessons: off, ask first with a pop-up (default), or open a quick round automatically (v0.7) |
| `/aa flight test` / `/aa flight land` | Pretend to take off / land, to test In-Flight Lessons without flying (v0.7) |
| `/aa voice [on\|off]` | Fizzwick's recorded voice on or off (no argument flips it). Uses the same volume as the sound effects (v0.8) |
| `/aa duel` | Open Duel of Wits: pick a subject, 5 or 10 questions, and who to challenge (v0.10) |
| `/aa duel <name>` | Open Duel of Wits ready to challenge that player (`Name` or `Name-Realm`) (v0.10) |
| `/aa duel queue` | Open Duel of Wits on **Random challenger** (only works if a parent turned it on) (v0.10) |
| `/aa duel leave` | Leave the current race, waiting room or random search (v0.10) |
| `/aa nudge` | Old command: turns In-Flight Lessons off, or back on (ask first) |
| `/aa help` | List the commands |

ESC closes the window. You can drag it by any empty spot, and it remembers where you left it.

## Minimap button (v0.6.1)

A round button with Fizzwick's face sits on the edge of the minimap.
- **Left-click** opens or closes the Academy. **Right-click** opens the Parent Panel (the PIN still applies).
- **Drag** it to slide it around the minimap rim. The spot is saved for the whole account.
- **Hover** shows a tooltip with rank, shards, minutes today and reviews due.
- Hide or show it with `/aa minimap` or the **Minimap button** toggle in the Parent Panel.
- Square minimaps (from minimap addons) are handled: the button follows the square edge.
- If another addon has already loaded LibDBIcon, Azeroth Academy registers with it instead, so you get
  one button that minimap-button collectors (like those in ElvUI or Minimap Button Bag) can manage.
  Azeroth Academy doesn't ship any libraries.
- **Shift-click** or **middle-click** opens Duel of Wits (v0.10).
- Like the hub, it does nothing in combat.

## Duel of Wits (v0.10)

Race other players who also have Azeroth Academy. Open it from the hub's **Duel of Wits** button, `/aa duel`,
or shift/middle-click on the minimap button.
- **Setup:** pick a subject (Rune Forger, Scribe's Scrolls, Typing race, Lore Chronicles, Azeroth Naturalist,
  the Lore Quiz or, since v0.11, Gnomish Engineering, grid puzzles included, since v0.12 Librarian Quests and since v0.13 Mechanics Academy), **5** or **10** questions, and who to challenge: **My group** (party or raid), **My guild**,
  **One player** (type their name), or **Random challenger**. Then **Send challenge**.
- **Invites:** everyone challenged gets a small pop-up (**Accept** / **No thanks**), even with the Academy closed.
  It says no by itself after 25 seconds, and right away in combat, in a dungeon/raid/battleground, when duels are off
  in the Parent Panel, or (with **Friends only**) when the challenger isn't on your friends list.
- **Waiting room:** the challenger sees who joined (2 to 5 racers) and presses **Start race!**.
- **The race:** a 3-2-1 countdown, then everyone answers their own questions. Questions come from one shared
  seed plus **each racer's own age band**, so a 6-year-old and a 12-year-old can race fairly. A bar per racer
  shows how far everyone got. Each question gets one try; a wrong answer adds 3 seconds.
- **Typing race:** everyone types the **same lines** (at the youngest racer's level). The result shows WPM and accuracy;
  a line counts as correct at 85% accuracy or better.
- **Results:** most correct answers wins, time breaks ties. Fizzwick cheers, and you get shards (2 per correct answer,
  +5 for finishing, +10 for winning, at most 40). Finishing against a real opponent also gives **2 bonus minutes,
  at most 10 a day from duels**, and always inside the parent's daily cap. Duel answers count as practice (accuracy
  and time in the report) but **never** count toward mastery, so duels can't skip the 9-of-10 rule.
- After the race: four preset emotes (**Good game!**, **Well played!**, **Rematch?**, **That was fun!**), a
  **Block** button per racer, and **New duel**.
- **Combat** during a race makes you leave it (the others keep racing). If someone disconnects, the race finishes
  without them; if the challenger disconnects, your game scores the race itself.
- **Both players need v0.10.0.** A different version says so in chat and the duel doesn't start.

**Safety (Parent Panel → Duel of Wits settings):**
- **Group, guild & friend duels: On** (default). Off = every invite is declined.
- **Friends only: Off** (default). On = only players on your character's friends list can challenge you, and
  random challengers are off too.
- **Allow random challengers: Off** (default). Only when a parent turns this on can the kid search for a random
  opponent. Random races match the same subject and length and an age band at most one step away. Random
  opponents only ever see your **duel name** (like "Clever Gryphon", picked from preset words in the Parent Panel),
  never your character name, and you only see theirs.
- **No free text, ever.** There is no chat box. Only scores, the four preset emotes and the duel name are sent.
- **Clear blocked list.** Blocked players can't challenge you or send emotes; they just see "busy".

## In-Flight Lessons (v0.7)

Flight paths are perfect lesson time, so Fizzwick speaks up a couple of seconds after takeoff.
- **Ask first (default):** a small pop-up near the top of the screen: **Start**, **Not now**, or **Not this
  session** (no more asking until the next login or `/reload`). It doesn't block the game, and if you ignore
  it, it fades away after about 25 seconds.
- **Auto-open:** skips the pop-up and opens straight into the quick round.
- **Off:** nothing happens.
- **The quick round:** Review Time if reviews are due, otherwise 5 problems of the recommended skill in the
  subject you opened last. A brand-new subject starts with its placement trial, as usual.
- **Still flying when you finish?** The reward screen has **Another round (still flying!)**.
- **Landing:** nothing closes. A finished round shows its reward; a round in progress stays open, so you can
  finish on the ground with nothing lost. Fizzwick says you've landed.
- **Never pops up:** in combat (it waits, and asks if the flight is still going when combat ends), in
  dungeons/battlegrounds, when the Academy window is already open, before a path (age band) is picked, or
  once today's bonus-minute cap is reached. At most once per flight. Combat still hides the Academy.
- Choose the mode in the Parent Panel (**In-flight lessons: Off / Ask first / Auto-open**) or with `/aa flight`.
- **Testing without flying:** close the Academy, type `/aa flight test`, and wait 3 seconds. `/aa flight land`
  pretends to land (or it lands by itself after 2 minutes). If nothing shows, chat says why.

## How it plays

- **First run:** pick an age band. **Initiate** is ages 5–7, **Adept** is 8–10, **Magister** is 11–13.
- **Hub:** shows your rank and progress bar, knowledge shards, bonus minutes earned today
  against the daily cap, and the module tiles. Rune Forger, Scribe's Scrolls, Lore Chronicles,
  Azeroth Naturalist, Gnomish Engineering, Librarian Quests and Mechanics Academy are all active (since v0.13
  no tile says "Coming soon").
- **Rune Forger:** 5 skills per band, and each skill has 3 tiers: **Spark → Rune → Glyph**.
  - Initiate: Counting, Adding within 10, Adding within 20, Subtracting within 20, More or Less
  - Adept: Times Tables, Division, Place Value, Fractions of a Whole, Word Problems
  - Magister: Percentages, Negative Numbers, Order of Operations, Equations, Area
- **Rounds** are 6 problems. Initiate always answers with big buttons (2–3 choices). Older bands
  get 4 choices on Spark tier and type the answer on Rune and Glyph (Enter submits).
- **Correct:** the card flashes, sparks fly, a sound plays, the charge meter fills, and shards float up.
  3 in a row is a **Combo** (+5 per answer). 5 in a row is **Overcharge**, which doubles shards.
- **Wrong:** you get a gentle hint and one more try. Nothing is ever taken away. A second miss shows
  the answer with a worked explanation.
- **Difficulty adjusts during a round:** 3 first-try corrects in a row step it up, and 2 misses in a
  row step it down. It stays inside the tier's range: Spark 1–3, Rune 2–4, Glyph 3–5.
- **Mastery:** a tier is mastered once you get 9 of your last 10 first tries right (85%).
  Mastering a tier gives +50 shards and bonus minutes, and unlocks the next tier.
- **Ranks** (by total shards): Initiate 0, Apprentice 250, Journeyman 750, Adept 1500,
  Magister 3000, Archmage 6000.
- **Bonus minutes:** each mastered tier earns +10 minutes by default, up to 60 a day. Parents can
  change both numbers. The count is shared across the whole account, so switching characters
  doesn't add more, and it resets each day.
- **Flight paths:** Fizzwick offers an In-Flight Lesson a couple of seconds after takeoff (see In-Flight Lessons).
- **The Forgemaster's Trial (placement, new in v0.2):** the first time you open Rune Forger on
  a band, the Forgemaster offers a short trial: 10 problems, 2 per skill, no hints and one try
  each. The first problem for each skill is medium (level 2). Get it right and the second is
  hard (level 4); miss it and the second is easy (level 1). Each skill then starts at
  **Spark** (missed the first), **Rune** (first right, second missed), or **Glyph** (both right).
  Starting higher only unlocks tiers. It never marks anything mastered. The trial pays +20
  shards. "Skip for now" starts every skill at Spark. Leaving partway changes nothing.
- **Review Time (spaced review, new in v0.2; called Review Runes before v0.4):** every mastered tier comes back for a quick
  check **1 day, 3 days, and 7 days** after mastery. When one is due, the hub shows a
  **Review Time (N due)** button and chat reminds you at login. A review round covers up to
  2 runes with 3 problems each. Get 2 of 3 right and the rune stays glowing until the next
  check. Pass the 7-day check and it's "locked in for good". Miss a review and the rune is marked
  **fading**. Nothing is taken away (mastery, shards, and minutes stay). It just comes back
  in 1 day, and Quick Drill suggests practising it. A practice round with 5 of 6 first-try
  right clears fading.
- **Rune Mastery Exam (post-test, new in v0.2):** unlocks once 4 of a band's 5 skills have
  Rune or Glyph mastered. It uses the same format as the placement trial, so the Parent Panel
  report can compare before and after. You need 8 of 10 to pass. Every attempt gives +50
  shards. The first pass adds +100 shards and bonus minutes.
- **Scribe's Scrolls (new in v0.3):** Archivist Quill of the Steamwheedle Archive in
  Gadgetzan needs help mending scrolls. 5 skills per band, the same Spark → Rune → Glyph tiers, and the same
  rewards, trial, reviews, and exam as Rune Forger. The Scribe has its own trial
  ("The Scribe's Trial") and exam ("Scroll Mastery Exam").
  - Initiate (5–7): Letters in Words (first, last, and middle letter), Short Words (CVC words like
    cat and sun), Sight Words (spot the right spelling, alone or in a lore sentence), Word Meanings,
    and Typing Words. All answers are big buttons except Typing Words.
  - Adept (8–10): Spelling Patterns (silent e, sh/ch/th/wh/ck, plurals including -ies, -ves, and
    irregulars like mice), Words in Context (meanings from lore sentences), Same and Opposite
    (synonyms and antonyms), Scroll Spelling, and Typing Phrases.
  - Magister (11–13): Prefixes, Suffixes, Roots; Tricky Word Pairs (their/there/they're, its/it's,
    affect/effect, and more); Lore Vocabulary; Master Spelling (necessary, rhythm, conscience...);
    and Typing Sentences.
  - **Spelling without sound:** unscramble jumbled letters, fill in smudged letters, choose the
    correct spelling, or spell a word from its meaning (with a letter count, plus the first letter on easier levels).
  - **Typed answers:** on Rune and Glyph you type the word. Capitals, extra spaces, quotes, and a final
    `.`, `!`, or `?` are ignored, but **every letter must be right**. That's the spelling test.
    Meaning, synonym, and word-pair questions always use buttons, because typing a definition
    would be unfair.
  - **Typing practice:** copy the line exactly. You pass with at least 85% accuracy on Spark, 90% on
    Rune, and 95% on Glyph. Accuracy counts every wrong, missing, or extra character. Capital letters
    only count on Glyph. The result shows **accuracy and words per minute** (WPM, 5 characters = 1 word,
    timed from when the line appears). Each typing skill keeps a best-WPM record, and the report
    shows it. Speed never fails you: accuracy is what counts.
- **Lore Chronicles (new in v0.5):** Chronicler Zixi Inkspark keeps the Story Vault of the
  Knowledge Exchange in Gadgetzan. Every passage is original writing for this addon. Lore is
  paraphrased and stories come from both factions and neutral lands. Same tiers, rewards, trial
  ("The Chronicler's Trial"), reviews, and exam ("Chronicle Mastery Exam") as the other subjects.
  - Initiate (5–7): Read a Sentence, What Happened First? (sequencing), Who?, What?, Where?
    Short sentences and tiny stories, always 3 big buttons, and the answer is written in the text.
  - Adept (8–10): Main Idea, Feelings & Reasons (feelings and motives), Cause & Effect, Words in
    Context (vocabulary from the passage), and Sentence Builder (put shuffled word tiles in order).
  - Magister (11–13): Reading Between the Lines (inference), Two Sides of the Story (a Horde account
    and an Alliance account of the same place, shown in random order), Purpose & Summary (author's
    purpose or best summary), Sentence Doctor (pick the correctly written sentence), and
    Chronicler's Answer (a short written answer).
  - **Reading questions always use buttons**, because typing "the main idea" would be unfair.
    Sentence Builder and Chronicler's Answer use buttons on Spark and a wide text box on Rune,
    Glyph, and trials.
  - **Sentence Builder:** type the sentence. Capitals, extra spaces, and punctuation are forgiven;
    the word order must be right.
  - **Chronicler's Answer (keyword rubric):** write a short sentence of at least 3 words. The answer
    passes when it contains enough key ideas, for example "fight / rule" plus "bruisers / not allowed"
    for "How does Gadgetzan stay peaceful?". Longer keywords also match their endings
    ("enem" matches enemy and enemies). The feedback says "Key ideas found: 1 of 2" and shows a model
    answer. After a miss the text stays in the box so it can be fixed.
- **Lore Quiz for Everyone (new in v0.5, optional):** a relaxed lore quiz for the whole family,
  opened with the **Lore Quiz (for everyone)** button on the Lore Chronicles story list or with
  `/aa quiz`. It has 5 topics (Horde Legends, Alliance Legends, Neutral Friends, Places of
  Azeroth, Great Legends) with 12 questions each, classic-era lore, and always 4 buttons. It has no
  age band, no trial, and no exam, and no hub tile, but mastery, shards, reviews, and the report
  work as usual (the report shows one "Everyone (all ages)" section). **Story lessons** goes back.
- **Azeroth Naturalist (new in v0.9):** Field Warden Bramble Quickroot (original, neutral) tends the
  greenhouse of the Knowledge Exchange in Gadgetzan. Same tiers, rewards, trial ("The Field Warden's Survey"),
  reviews and exam ("Naturalist Mastery Exam") as the other subjects. All science text is original and was
  checked for accuracy; Azeroth places and creatures are the flavour, real science is the content.
  - Initiate (5–7): Zone Sorting (which creatures and plants live in which zone, plant or animal),
    What Animals Need (food, water, air, shelter), Living or Not?, Day and Night, Seasons.
    Always 3 big buttons.
  - Adept (8–10): Food Chains (8 zone food chains: producer, who eats whom, top predator, where the energy
    comes from), The Water Cycle (Thousand Needles and the Shimmering Flats), States of Matter (a Gadgetzan
    alchemy lab), Adaptations, Life Cycles.
  - Magister (11–13): Fair Tests (hypothesis, variables, controls), Predict and Explain (patterns in data,
    evidence vs opinion), Ecosystems, Forces and Motion, Energy.
  - **Typed answers** only where a short word is fair (e.g. *evaporation*, *herbivore*, *gas*,
    *chrysalis*), on Rune, Glyph and trials for Adept and Magister. Capitals, extra spaces, punctuation
    and a leading "a/the" are forgiven and common alternatives count (*pupa* for chrysalis).
    Explanations and predictions always use buttons.
  - Wrong-answer explanations say *why* (e.g. "Plants capture the sun's energy, and it passes along the chain").
- **Field Journal (new in v0.9):** mastering a Naturalist tier collects that tier's specimen page:
  45 pages (5 skills x 3 tiers x 3 bands), each with an in-game icon, a name, where in Azeroth it lives and a
  short field note. A banner, a sound and Fizzwick announce each new page, and the reward screen has an
  **Open Field Journal** button. Open the journal from the Naturalist skill list (**Field Journal** link),
  the hub tile's **Journal** button, or `/aa journal`. Band tabs, a 5 x 3 grid (skills x Spark/Rune/Glyph),
  and a page view. Undiscovered pages show a "?" and a **Go collect it!** button. When a skill's review is
  due or it is fading, its page's ink fades and offers **Review now**; passing brings the ink back. Pages are
  never taken away. The journal is account-wide, so siblings on different characters fill one book.
- **Gnomish Engineering (new in v0.11):** Tinker Nixa Sprocketwhirl (original, neutral) runs the workshop of the
  Knowledge Exchange in Gadgetzan. Kids give orders to **Boltby**, a clockwork critter, on a command grid drawn with
  in-game icons (Boltby, the gear, rocks, lettered spots). Same tiers, rewards, trial ("The Tinker's Test Bench"),
  reviews and exam ("Engineering Mastery Exam") as the other subjects. All questions are original; grid puzzles are
  generated and every answer is worked out by the addon's own grid engine, so no puzzle has two right answers.
  - Initiate (5–7): Steps in Order (first, next, last), Patterns (what comes next, what's missing, counting
    patterns), Grid Directions (Up/Down/Left/Right: where does Boltby stop?), Program Boltby (which program reaches
    the gear, with rocks in the way at higher levels), Turn and Go (Forward / Turn left / Turn right). Always 3 big buttons.
  - Adept (8–10): Loops (repeat counts, nested loops, which loop matches a program, counting loops), Loop Paths (loops on
    the grid), IF and ELSE (true runs THEN, false runs ELSE, also ELSE IF and AND), Debugging (which step is the bug /
    what should it be, with exactly one fixable step), Events and Parts (WHEN-this-happens and decomposition).
  - Magister (11–13): Variables (trace assignments, swaps with temp), Functions (parameters, return, nested calls, an IF
    inside), Boolean Logic (and / or / not with brackets), Algorithms (sum, count, maximum, linear search, one bubble-sort
    pass, binary search ideas), Reading Pseudocode (WHILE, FOR-each filters, what a program is for).
  - **Typed answers** on Rune, Glyph and trials for Adept and Magister: numbers (loop totals, variable values, function
    results, step numbers), *True*/*False* (*yes*/*no* count too) and a few short words. Code is shown left-aligned.
- **Blueprint Binder (new in v0.11):** the Field Journal's sibling. Mastering a Gnomish Engineering tier drafts that
  tier's gadget blueprint (45 pages: name, what it's built for, a note about the skill, an in-game icon). Same band
  tabs, grid, smudged-lines-then-**Review now**, **Go collect it!**, reward-screen **Open Blueprint Binder** button,
  skill-list link, hub tile **Binder** button and `/aa blueprints`. Account-wide like the journal.
- **Librarian Quests (new in v0.12):** Head Librarian Tamsin Quillfeather (original, neutral) runs the library of
  the Knowledge Exchange in Gadgetzan and swaps books with Stormwind's Royal Library, Orgrimmar's Valley of Wisdom and
  Dalaran's Violet Citadel alike. Same tiers, rewards, trial ("The Librarian's Reading Room"), reviews and exam
  ("Research Mastery Exam") as the other subjects. All questions are original; shelves, contents pages, indexes,
  citations, two-source comparisons and data tables are generated, so the numbers change every time.
  - Initiate (5–7): Finding the Shelf (topic shelves, then letter ranges A-H / I-Q / R-Z), ABC Order (first or last
    word, then words with the same first letter), Contents Page (which page / which part), Key Words (the word to look
    for), True or Silly (real facts vs make-believe, fiction vs nonfiction). Always 3 big buttons.
  - Adept (8–10): Using an Index (first page, which topic, how many pages), Chapters (which chapter a page is in, how
    long a chapter is), Search Words (turn a question into search words, spot the worst ones), Fact or Opinion,
    Taking Notes (best short note, headings, writing the source next to each fact).
  - Magister (11–13): Reliable Sources (who, when, why; bias; primary vs secondary), Citing Sources (Author. Title. Year.,
    what's missing, plagiarism, paraphrasing, common knowledge), Comparing Sources (what two accounts agree on, where
    they differ, which is more reliable, how far apart the numbers are), Reading Tables (look up, most/fewest,
    difference, total), Research Quest (skimming vs scanning, research steps, glossary, index).
  - **Typed answers** on Rune, Glyph and trials for Adept and Magister: page numbers, chapter lengths, table values,
    *Fact*/*Opinion*, *primary*/*secondary*, the missing citation part and a few research words. Tables, indexes and
    citations are shown left-aligned like a page of a book.
- **Library Passport (new in v0.12):** mastering a Librarian Quests tier stamps that tier's library stamp (45 stamps from
  Stormwind, Ironforge, Orgrimmar and Thunder Bluff in equal numbers plus Dalaran, Gadgetzan and other neutral places).
  Same band tabs, fading-ink-then-**Review now**, **Go collect it!**, reward-screen **Open Library Passport** button,
  skill-list link, hub tile **Passport** button and `/aa passport`. Account-wide like the journal.
- **Mechanics Academy (new in v0.13):** Coach Brakka Steelwhistle (original goblin, neutral) runs the Training Ring
  behind the Knowledge Exchange in Gadgetzan. Group-play ideas taught with reading and math drills. Same tiers,
  rewards, trial ("The Coach's Tryout"), reviews and exam ("Tactics Mastery Exam") as the other subjects. All questions
  are original; game facts (roles, classes, racial traits) are described in our own words.
  - Initiate (5–7): Tank, Healer, DPS (who does what), Avoid the Fire (a small arena grid drawn with the in-game fire
    icon: which lettered spot is safe, which stays safe when the fire spreads, which way the hero steps out),
    Count the Monsters (adding, taking away, packs), Health Bars (who needs a heal first, what is missing),
    Teamwork (kindness, ready checks, staying together, telling a grown-up about rude chat). Always 3 big buttons.
  - Adept (8–10): Threat (who the monster attacks, how far behind the tank, when you'd catch up), Positioning (behind or
    beside, spread out, stack up, line of sight), Interrupts (cast timing, counting casts, can one or two players
    interrupt every cast), Cooldowns (ready again, uses per fight, minutes:seconds), Classes and Roles.
  - Magister (11–13): DPS Math (totals, group DPS, fight length, enrage timers), Mana Budget (casts, regen, which heal
    gives more for the mana), Priority Lists (use the first ability whose rule is true), Boss Mechanics (phases,
    enrage, adds, soaking, tank swaps, phase health), Racial Traits.
  - **Client-aware lists:** WoW Forever and Classic Era teach the original 9 classes and 8 races; Retail adds Death
    Knight, Monk, Demon Hunter, Evoker and four more races (Compat decides; the harness checks both lists).
- **Tactics Deck (new in v0.13):** mastering a Mechanics Academy tier earns that tier's tactics card (45 cards, each
  naming a neutral place to practise it). Same band tabs, fading-then-**Review now**, **Go collect it!**, reward-screen
  **Open Tactics Deck** button, skill-list link, hub tile **Deck** button and `/aa deck`. Account-wide.
- **In-flight science:** if Azeroth Naturalist was the last subject you opened, flight rounds pick a
  "look down" skill first (Zone Sorting, Day and Night, Seasons; Water Cycle, Food Chains, Adaptations;
  Ecosystems, Energy, Forces) and Fizzwick says something like "Look down! Every zone below is a habitat."
- **Combat:** the window hides as soon as combat starts. When combat ends, a small
  "Resume / Later" prompt appears. Resume brings back the exact same problem.

## Professor Fizzwick, Sprocket, and faction cameos (v0.4)

- **Professor Fizzwick Coppercoil** stands in a strip along the bottom of the hub, shown as an in-game goblin model.
  - He greets you, kicks off rounds, and cheers right answers, combos, and overcharges ("Now THAT'S a return on investment!").
  - After a wrong answer he encourages; he never mocks.
  - He also reacts to mastery, rank-ups, trials, exams, and reviews.
  - Lines are drawn at random without repeats: every line is used once before any comes back.
- **Hints come from Sprocket**, his mechanical parrot. Press **Hint** and the hint appears in the strip as well as under the problem.
- **Leader cameos.** On a rank-up, a passed Mastery Exam, or every 5th mastered tier, a small card can appear with a line of text from your faction's leader:
  - Horde: Thrall.
  - Alliance: King Magni Bronzebeard of Ironforge (v0.5; Highlord Bolvar Fordragon in v0.4).
  - Cameos are text only, never voice, and at most one every 5 minutes.
  - Neutral characters (for example, a Pandaren who hasn't chosen yet) get Fizzwick only.
  - Parents can turn cameos off.
- **Faction-neutral hosts.** Every Academy host is faction-neutral: the Forgemaster's rune forge, the Steamwheedle Archive, and the Story Vault are all in Gadgetzan.
- **Everything is drawn from the game client at runtime:** character models (by creature display ID), icons, window frames, and built-in fallback sounds. The addon ships no extracted Blizzard art or audio; the v0.8 sounds and voice are original generated audio.
- **Fallbacks.** If a model can't load, the character shows as an in-game icon instead. If an animation isn't supported, the screen just appears without it.

## Fizzwick and Sprocket posed art (v0.5.1)

- **Art ships with the addon.** These are Hex's original posed renders of Fizzwick and Sprocket, 26 TGA files in `Media/Art`.
  - Each pose comes as a 512x512 full figure and a 256x256 head-and-chest crop centered on the face.
  - It's all original art made for this project. No Blizzard art is extracted or shipped.
- **Each moment gets its own pose:**

  | Moment | Fizzwick |
  |---|---|
  | Opening the hub | greet |
  | Round, trial, exam or review start; correct answers | talking |
  | Waiting on a problem | thinking (Scribe's Scrolls), researching (Lore Chronicles, Lore Quiz), tinkering (Rune Forger) |
  | Hint, with Sprocket squawking the hint line | teaching |
  | Worked example after a final miss | teaching |
  | Combo, Overcharge | excited |
  | Rank up, Mastery Exam passed | celebrating |
  | Skill mastered | proud |
  | Wrong answer, exam retry, fading skill | encouraging |
  | New personal best (typing WPM) | surprised |

- **Sprocket** sits on the right of the strip.
  - He looks *curious*: bright when a hint is available, dim when it isn't (trials).
  - He switches to *squawk* while he delivers a hint.
- **Where the art shows:**
  - The guide strip uses the head crops.
  - The full figures appear on the reward screen, the trial result, and the rank-up card:
    - Reward screen: proud for a mastery, excited for a perfect round, talking for a review, encouraging otherwise.
    - Trial result: proud after placement, celebrating or encouraging after an exam.
    - Rank-up card: celebrating.
- **Fallbacks:**
  - Head crop → full figure → the `greet` pose → the in-game goblin model → an icon.
  - A file the client refuses is skipped automatically.
  - The large portraits stay hidden if there's no art, so the screens look like v0.5.
- **Reduced motion.** The poses are static. Reduced motion skips the fade-in on large portraits (and an optional talk strip, which isn't shipped).
- **Replacing art.** `tools/convert_art.sh` (ImageMagick) and `tools/make_heads.py` (Python, Pillow and numpy) rebuild the TGAs, the head crops, and `Media/Art/Manifest.lua` from PNGs. See `Media/Art/README.md`.
- **Per-skill icons.** All 50 skills (Rune Forger, Scribe's Scrolls, Lore Chronicles, Lore Quiz) now show their own in-game icon on the skill list.
  - Each icon is loaded from the client by path (`Core/SkillIcons.lua`).
  - The subject icon is still used for subject tiles and the reward glyph.

## Murloc Boarding Party (v0.6)

**Where to find it:** the **Murlocs** button on the Scribe's Scrolls hub tile, the **Murloc Boarding Party** button on the Scribe's Scrolls skill list, or `/aa murloc`.

- **How it plays:**
  - You crew Captain Fizzwick's Steamwheedle ship. Murlocs climb over the rail in waves, each with a crew order above its head ("Fire the cannon!", "Raise the sail!").
  - Type an order and your crew knocks that murloc overboard. Splash!
  - The first letter you type picks the murloc closest to the wheel with that letter. The letters turn green as you type, on the murloc and in the big line under the deck.
  - **Typos** make a crew member slip on a fish. The wrong letter is refused, but you keep everything typed so far.
  - Murlocs **creep toward the captain's wheel** over time.
  - **Broadside meter:** each knockout adds 1, or 2 for a clean one with no typos. When it's full, press **Enter** (or the button) to fire a broadside. It clears every murloc on deck and knocks the Tidehunter back.
  - After the last wave, the **Murloc Tidehunter** climbs aboard carrying a whole sentence. Type it to win the voyage.
  - Fizzwick calls out from the ship's wheel: his head crop is on deck, and his lines run in the strip.
- **By age band:**

  | Band | What you type | Rules |
  |---|---|---|
  | Initiate (5-7) | Single letters, then short words | Slow, and no fail state: murlocs just wait at the wheel |
  | Adept (8-10) | Short crew orders (capitals and punctuation are skipped for you) | 3 wheel points; three murlocs at the wheel end the voyage |
  | Magister (11-13) | Full sentences, typed exactly (capitals and punctuation count) | Timed with WPM and a par time (+5 shards under par) |

- **Routes:** **Booty Bay Harbor** (2 waves) → **Booty Bay to Ratchet** (3 waves, faster) → **Ratchet to the Maelstrom** (4 waves, fastest).
  - Clearing a route unlocks the next one. The Parent Panel's "unlock all" setting opens all three.
  - If you're fast, murlocs arrive sooner: when the deck is empty, the next one climbs up within a second.
- **Rewards:**
  - Shards: 2 per murloc (3 in Magister), +10 for a win, +15 the first time you clear a route in your band, +5 under par.
  - A **voyage log** keeps your last 10 voyages and your best WPM per band.
  - The parent report shows voyages, wins, murlocs splashed, accuracy, best WPM, and routes.
  - Voyages don't change mastery or bonus minutes.
- **Presentation:**
  - Murlocs are in-game icons, and the Tidehunter is the in-game murloc model (display 1995, with an icon fallback).
  - Sounds are built in (splash, cannon, murloc gurgle), and you can drop in your own `splash.ogg`, `cannon.ogg` and `gurgle.ogg` (see `Media/Sounds/README.md`).
  - Reduced motion turns off the murloc bobbing, the overboard flight, flashes and sparks. Murlocs still walk, because that's the game.
- **Pausing:** Escape, closing the window, or combat pauses the voyage. Reopen it and press **Resume**.

## Sounds (v0.4, real audio since v0.8)

- **Original sound effects (v0.8).** 19 short, cartoony "goblin workshop" sounds ship in
  `Media/Sounds/`: button click, window open/close, right answer, a gentle wrong answer, combo,
  overcharge, forge, scroll, reward, rank-up, exam pass, Fizzwick's chirp, parrot hint, cameo,
  the three Murloc Boarding Party sounds, and a new chime for the In-Flight Lesson pop-up.
  v0.9 adds two more (21 total): a journal **page** turn and a **specimen** discovery chime.
  They were generated for this addon (ElevenLabs), not taken from the game, and are matched in loudness.
- **Built-in fallback.** Every sound event still has a built-in game sound. If a file is missing,
  or **Custom sound files** is OFF, the built-in sound plays.
- **Your own sounds.** Replace any `.ogg` in `AzerothAcademy\Media\Sounds\` (names in
  `Media/Sounds/README.md`), then restart the game client (`/reload` doesn't pick up new files).
- **Parent Panel sound controls:**
  - **Sound ON/OFF** mutes the addon.
  - **Sound channel** chooses which of the game's volume sliders the addon follows: Effects, Master, Dialog, or Ambience.
  - **Sounds: All / Important only** plays only answers, rewards, and rank-ups.
  - **Custom sound files ON/OFF.**
  - The addon never changes the game's own volume settings.

## Fizzwick's voice (v0.8)

Professor Fizzwick now **speaks** some of his lines in an original voice designed for this addon.
It's a fast-talking, warm, slightly raspy goblin professor. The voice was designed from a written
description only: it is not a clone or imitation of any actor or game character.

- **12 recorded lines:** greeting, round start, right answer, wrong answer (encouraging), Sprocket's
  hint ("Squawk! Hint, hint!"), combo, rank up, mastered, the In-Flight Lesson offer, landing,
  Murloc Boarding Party start, and goodbye.
- **5 more in v0.9 (Azeroth Naturalist):** "Grab your field journal! Science time in the wild!",
  "Sharp eyes! That's real science, partner!", "A new specimen for your journal! Ooh, look at that!",
  "Welcome to your field journal. You earned every page!" and "Look down! Every zone below is a habitat.
  Let's study!". Same voice, same rules.
- **Words always match.** A recording plays only with its own text line in the bubble. The first
  time each of these moments happens in a session, Fizzwick picks the recorded line. After
  that his usual lines rotate, and only some of them are spoken.
- **Never chatty.** One clip at a time, never overlapping, at least 6 seconds between clips and
  45 seconds before the same clip again. Rank up and Mastered may cut in. Goodbye plays only when you
  close the Academy after at least 20 seconds, and never when combat hides it.
- **Volume and off switch:** it uses the same channel and volume slider as the sound effects
  (Parent Panel **Sound channel**). **Sound OFF** mutes it too. Turn just the voice off with
  the Parent Panel **Fizzwick's voice** button or `/aa voice off`. It's on by default.

## Parent Panel

The first visit asks you to create a 4–6 digit PIN. After that, the PIN unlocks:
- **Subject: <name>** button (new in v0.3): switches the progress table, Start buttons, and Re-run Trial
  between Rune Forger and Scribe's Scrolls.
- First-try accuracy, attempts, recent results out of 10, and time spent, for each skill and tier.
  A gold star means mastered.
- Minutes per mastered tier (0–60) and the daily cap (0–240)
- Changing the age band
- **Unlock all tiers (testing)**, so you can try Rune and Glyph without mastering first (this also unlocks the exam)
- **Start** button on each skill row (new): click it to cycle where that skill begins
  (Spark → Rune → Glyph). This overrides the placement trial until the next trial.
- **Re-run Trial** (new): the Forgemaster's Trial comes back the next time Rune Forger opens.
  Earlier results are kept in the report.
- **Spaced reviews: ON/OFF**: turns Review Time off or on. Nothing is lost while it's off.
- New in v0.4:
  - **Sound**, **Sound channel**, **Sounds: All/Important only**, and **Custom sound files** (see Sounds).
  - **Reduced motion**: no flashes, flying sparks, pulsing glow, or counting-up numbers.
  - **Leader cameos**: on or off.
- **Minimap button: ON/OFF** (v0.6.1).
- **In-flight lessons: Off / Ask first / Auto-open** (v0.7). Click to cycle.
- **Fizzwick's voice: ON/OFF** (v0.8).
- **Duel of Wits settings** (v0.10): duels on/off, friends only, allow random challengers (off by default),
  the duel name random opponents see, and clearing the blocked list.
  - The panel uses the full window height, so Fizzwick's strip is hidden while it's open.
- A `!` next to a tier means it's **fading** (missed its last review).
- **Export Report:** a text report. Click *Select All*, then press Ctrl+C. The **Report:** button at the
  bottom (new in v0.3) switches between the picked subject and **All subjects**. Typing skills show
  their best WPM. Since v0.2 it also lists
  reviews due, fading skills, each skill's starting tier, and for each band **placement vs exam**:
  first trial score, latest and best exam, and how each skill's level changed.
- Change PIN, Reset Profile (click twice; clears this character's progress and keeps the PIN and settings), and Lock.
- Closing the window locks the panel again.

**About the PIN:** it only slows kids down. It isn't real security. It's stored lightly scrambled
in the SavedVariables file on your computer. If you forget it, quit the game and delete
`WTF\Account\<ACCOUNT>\SavedVariables\AzerothAcademy.lua`. That clears the PIN and minute
settings but leaves kids' progress alone, because progress is saved per character in
`WTF\Account\<ACCOUNT>\<Realm>\<Character>\SavedVariables\AzerothAcademy.lua`.

## In-game test checklist

1. [ ] Addon appears in the AddOns list and isn't marked "out of date" (on Forever, interface 16001).
2. [ ] Login message appears. `/aa status` reports `client: WoW Forever (interface 16001)`.
3. [ ] `/aa` opens the hub with the band picker the first time. Pick a band and the hub appears.
4. [ ] Drag the window, `/reload`, and it reopens in the same place. ESC closes it.
5. [ ] Clicking a "Coming soon" tile prints a message. Rune Forger opens the 5-skill list.
6. [ ] Spark round: problems appear, buttons work, correct answers flash and play a sound, the charge bar fills,
       "+N shards" floats up, and the round moves to the next problem on its own.
7. [ ] Answer 3 right in a row and look for **Combo**; 5 right in a row shows **OVERCHARGE**.
8. [ ] A wrong answer shows a hint and disables that button. A second miss shows the answer, the explanation, and a **Next** button.
9. [ ] Initiate → Counting shows icons you can count (coins, stars, orbs, books).
10. [ ] Reward screen shows first-try score, best combo, shards, minutes, mastery progress, and the rank bar.
11. [ ] Two perfect Spark rounds on one skill master it: you get "+10 bonus minutes" and the Rune button unlocks.
12. [ ] On a Rune tier (Adept/Magister), type an answer and press Enter. Typing letters doesn't use up a try.
13. [ ] Start combat (attack a training dummy or a critter) in the middle of a problem. The window hides. When combat ends, Resume returns to the same problem.
14. [ ] Take a flight path. Fizzwick's In-Flight Lesson pop-up appears (see items 86-95).
15. [ ] Parent Panel: set a PIN, Lock, try a wrong PIN, unlock, change minutes and cap, switch band,
        turn on Unlock all tiers, Export (Select All and Ctrl+C work), Reset Profile with two clicks.
16. [ ] Log out and back in. Shards, mastery, and settings are still there.
17. [ ] Check that × and ÷ display correctly (Adept times tables and division). If they show as boxes, tell me and I'll switch to x and /.

New in v0.2:

18. [ ] (Upgrade test) With v0.1 progress, install v0.2: progress, shards, PIN, and settings are all still there, and Rune Forger opens straight to the skill list (no forced trial for bands already played).
19. [ ] Fresh character: opening Rune Forger shows **The Forgemaster's Trial**. "Skip for now" goes to the skill list.
20. [ ] `/aa trial` and take the trial: no Hint button, one try per problem, the second problem for a skill is easier after a miss. The result screen lists a starting tier per skill, and those tier buttons are unlocked in the skill list.
21. [ ] Parent Panel: the **Start** button cycles Spark/Rune/Glyph and the skill list follows. **Re-run Trial** brings the trial back next time.
22. [ ] Master a tier, then (the next day, or after changing the PC clock) log in: the chat reminder and **Review Time (1 due)** on the hub (called Review Runes before v0.4). Pass it and the result says "still strong".
23. [ ] Miss a review on purpose: "fading" shows on the result and in the skill list, the **Practice** button starts a round on it, and a strong round clears it.
24. [ ] **Spaced reviews: OFF** in the Parent Panel hides the Review Time button.
25. [ ] With 4 skills at Rune mastery (or Unlock all tiers on), the **Mastery Exam** button in the forge lights up. Take it: pass or try again, shards, and on the first pass bonus minutes. Export Report shows "Placement vs exam" and Growth.

New in v0.3:

26. [ ] (Upgrade test) With v0.2 progress, install v0.3: Rune Forger progress, trial results, reviews, PIN, and settings are unchanged.
27. [ ] The hub shows **Scribe's Scrolls** as an active tile (gold border). Clicking it offers **The Scribe's Trial**.
28. [ ] Initiate: letters, short words, sight words, and meanings use 3 big buttons. **Typing Words** shows a text box, and typing the word and pressing Enter works.
29. [ ] Adept/Magister on Rune tier: spelling questions show a text box. Type the word in CAPITALS with extra spaces and it's still right. One wrong letter is wrong and shows a hint.
30. [ ] Words in Context / Lore Vocabulary: long definitions show as 4 wide buttons in 2 columns, and the text fits (no overflow).
31. [ ] Long lore passages fit inside the problem card (the font shrinks for long text).
32. [ ] Typing Phrases/Sentences: after Enter, the screen shows "Accuracy N% - Speed N WPM". A faster accurate try shows "New best speed".
33. [ ] Apostrophes and punctuation type and display correctly (For the Horde!, They're, It's, Who's).
34. [ ] Parent Panel: **Subject:** switches the table between subjects. Export → **Report:** cycles between the subject and All subjects.
35. [ ] Reviews: a mastered Scribe skill comes back under **Review Time** after a day, together with any Rune Forger reviews.

v0.4 (Fizzwick, cameos, visuals, sound):

36. [ ] (Upgrade test) With v0.3 progress, install v0.4: progress, best WPM, PIN, and settings are unchanged, and the new Parent Panel toggles show Sound ON, Effects, All, Custom ON, Reduced motion OFF, and Leader cameos ON.
37. [ ] The hub has a framed dialog border and a header plate with the title.
    - Fizzwick's strip at the bottom shows a **goblin model** with goggles. Tell me which goblin appears, or whether you see a gear icon instead.
38. [ ] Opening the hub gets a greeting from Fizzwick, once per opening. Going in and out of views doesn't repeat it.
39. [ ] In a round: the start line, a cheer on right answers, encouragement on wrong ones, and Combo/Overcharge lines. Lines don't repeat back-to-back.
40. [ ] **Hint** makes "Sprocket the parrot" speak in the strip (the gear icon lights up) with a little whistle sound.
41. [ ] 3 right in a row: a warm glow pulses around the charge bar. Overcharge makes it brighter gold.
42. [ ] Each subject tile has a small **Drill** button that jumps straight into that subject's next lesson.
43. [ ] Reward screen:
    - The icon fades and grows in. It's the rune for Rune Forger, the scroll for Scribe's Scrolls, and a pocket watch for reviews.
    - The shards line counts up.
44. [ ] Rank up (or use `/run` to add shards): a **RANK UP!** card with sparks. When it closes, the leader card appears:
    - Horde character: **Thrall's model** and a line of text.
    - Alliance character: **Magni Bronzebeard's model** (v0.5).
    - Neutral Pandaren: no leader card.
    - Tell me if the models show or fall back to banner icons.
45. [ ] Pass a Mastery Exam: the exam fanfare, Fizzwick's line, and the leader card (unless one appeared in the last 5 minutes).
46. [ ] Parent Panel: **Reduced motion ON**. The reward icon and shard number appear instantly, with no sparks, flashes, or pulsing glow.
47. [ ] Parent Panel sound toggles:
    - **Sound OFF** silences the addon.
    - **Sound channel: Dialog**: lower the in-game Dialog slider and the addon gets quieter.
    - **Important only** stops button clicks.
48. [ ] Custom sounds: copy any short `.ogg` to `Media\Sounds\correct.ogg` and restart the game. Right answers now play it, and every other event still plays its built-in sound.

v0.5 (Lore Chronicles, Lore Quiz, Magni, art slots):

49. [ ] (Upgrade test) Install v0.5 over v0.4: all progress and settings are unchanged (no new saved data; schema stays 4).
50. [ ] The hub shows **Lore Chronicles** as an active tile. Clicking it offers **The Chronicler's Trial**.
51. [ ] Initiate: Read a Sentence, What Happened First?, Who?, What?, and Where? show a short text and 3 big buttons.
52. [ ] Adept/Magister passages fit inside the problem card. The longest are about 360 characters and use a smaller font. Tell me if any text overflows.
53. [ ] Sentence answers on buttons wrap onto two lines and stay readable (Main Idea, Purpose & Summary, Two Sides of the Story).
54. [ ] Sentence Builder on Rune: the wide text box accepts the sentence typed in lowercase without the period.
55. [ ] Chronicler's Answer on Rune/Glyph: a weak answer shows "Key ideas found: N of M" and the model answer, and your text stays in the box.
56. [ ] Two Sides of the Story shows both accounts. Sometimes the Horde account is first, sometimes the Alliance account.
57. [ ] **Lore Quiz (for everyone)** button (bottom right of the story list) opens the quiz: title "Lore Quiz - Everyone (all ages)", no exam button, and **Story lessons** goes back. `/aa quiz` and `/aa lore` work too.
58. [ ] Alliance character: the leader card shows **King Magni Bronzebeard** (dwarf model, or a blue banner icon if the model fails).
59. [ ] (Optional art) Run `tools/convert_art.sh` with a few test PNGs and restart the game. Fizzwick's portrait changes with the moment, and `/aa status` shows "Custom portraits: N".

v0.5.1 (posed art, skill icons):

60. [ ] Install v0.5.1 and **fully restart the game** (new art files aren't seen after `/reload`). The hub strip shows Fizzwick's waving head crop, and `/aa status` shows "Custom portraits: 26".
61. [ ] Start a Rune Forger round: Fizzwick talks, then after about 2 seconds he tinkers. In Lore Chronicles he researches; in Scribe's Scrolls he thinks.
62. [ ] Press **Hint**: Sprocket squawks the hint, and Fizzwick points at the board (teaching). When a hint is available Sprocket looks curious and bright; in a trial he's dim.
63. [ ] Wrong answer: encouraging. Miss twice: the worked example shows with Fizzwick teaching. Combo or Overcharge: excited.
64. [ ] Reward screen: a large Fizzwick on the left (proud, excited, or encouraging). A rank up shows him celebrating beside the card. A new typing best shows him surprised.
65. [ ] Art looks right side up, with clean transparent edges (no black boxes). Tell me if any pose looks flipped, blurry, or cut off.
66. [ ] Skill lists show a different icon per skill. Tell me about any blank or green squares, especially on Classic Era.

v0.6 (Murloc Boarding Party):

67. [ ] Scribe's Scrolls tile → **Murlocs** opens the game setup: three routes, with Ratchet and the Maelstrom locked, and an empty voyage log. `/aa murloc` works too.
68. [ ] **Set sail!** Murlocs climb aboard with an order above their heads. Type one: its letters turn green, and when it's finished there's a splash sound and it flies overboard. A wrong key gives a soft tick and the letter is refused.
69. [ ] Typing stays in the box while you play: W/A/S/D must not move your character. Tell me if the box ever loses focus.
70. [ ] Fill the broadside meter with clean knockouts, then press **Enter**: cannon sound, and the deck clears.
71. [ ] The **Murloc Tidehunter** appears after the last wave as a murloc model, carrying a sentence. Type it to win. Check the result screen, shards, and the "New route unlocked" line.
72. [ ] Adept: let three murlocs reach the wheel. The voyage ends kindly ("The murlocs took the wheel!"), and shards are paid for what you splashed.
73. [ ] Initiate: murlocs wait at the wheel and the voyage can't be lost. Magister: capitals and periods count, and the time shows a par.
74. [ ] Escape pauses, **Resume** continues. Entering combat mid-voyage pauses it, and reopening shows **Resume**.
75. [ ] Tell me if any band feels too fast or too slow. The speeds were tuned in simulation, not with real kids yet.

**Minimap button (v0.6.1)**

76. [ ] After logging in, a round button with Fizzwick's face sits on the minimap edge (lower left the first time), with a gold ring.
77. [ ] Hovering glows and shows the tooltip: Azeroth Academy, the three help lines, then rank and shards, minutes today and reviews due.
78. [ ] Left-click opens the Academy, and left-click again closes it.
79. [ ] Right-click opens the Parent Panel and asks for the PIN, even if it was unlocked before.
80. [ ] Drag the button around the rim. It stays on the edge, and after `/reload` it's where you left it.
81. [ ] `/aa minimap` hides it and prints "Minimap button: OFF". Again shows it. The Parent Panel toggle does the same.
82. [ ] Hide it, `/reload`, and it stays hidden. Log onto another character on the account: same spot, same hidden/shown state.
83. [ ] In combat, clicking the button doesn't open anything (and no errors).
84. [ ] If you use a square-minimap addon (or ElvUI), the button sits on the square edge, or appears in your button bag if LibDBIcon is loaded.
85. [ ] Check it on Retail and Classic Era too if you can. Tell me if the icon shows as a green square or the ring looks off-center.

**In-Flight Lessons (v0.7)**

86. [ ] Without flying: close the Academy, type `/aa flight test`. About 3 seconds later the pop-up appears with Fizzwick's face, a flight joke, and **Start / Not now / Not this session**. You can still move and click the world.
87. [ ] **Start** opens a 5-problem round (or Review Time if reviews are due). Finish it: the reward screen shows **Another round (still flying!)**. Type `/aa flight land`: the button goes away and Fizzwick says you landed.
88. [ ] Take a real flight path (pick one that's at least 30 seconds). The pop-up appears 2-3 seconds after takeoff, only once per flight. **Tell me if it never appears, or appears late:** WoW Forever's flight detection is unverified.
89. [ ] On a real flight, start the round and don't finish before landing. After landing the round is still open, on the same problem, and you can finish it normally.
90. [ ] Ignore the pop-up: it fades away after about 25 seconds. **Not now** closes it, and no second pop-up comes on that flight.
91. [ ] **Not this session**: no pop-ups on later flights until `/reload`.
92. [ ] `/aa flight auto`, then fly (or `/aa flight test`): the Academy opens straight into the round. `/aa flight off`: nothing. `/aa flight` prints the mode.
93. [ ] With the Academy window already open, take off (or `/aa flight test`): no pop-up (test mode prints why).
94. [ ] Parent Panel: the **In-flight lessons** button cycles Off → Ask first → Auto-open, and the choice survives `/reload` and other characters on the account.
95. [ ] If you get into combat while flying (rare) or while the pop-up is up, the pop-up disappears, and the Academy still hides in combat as before.

**Sounds and Fizzwick's voice (v0.8)**. Restart the game client after installing, because new sound files aren't found by `/reload`.

96. [ ] Open the Academy: you hear a short "open" sound, and Fizzwick says "Welcome back to the Knowledge Exchange!..." aloud, with the same words in his bubble.
97. [ ] Play a round: first right answer says "Now THAT'S a return on investment!", first wrong answer says "Not quite, but that's how learning works. Try again!" (the wrong *sound* should be soft, not a buzzer). Voices never talk over each other.
98. [ ] Answer fast for a while: Fizzwick doesn't speak on every answer (one clip every 6+ seconds, same clip at most every 45 s), and the bubble text always matches what you hear.
99. [ ] Ask for a hint: you hear "Squawk! Hint, hint!". Reach a combo, a mastered tier and a rank up if you can (Rank up and Mastered may cut a clip short).
100. [ ] `/aa flight test` (Academy closed): the pop-up has its own chime, and Fizzwick asks "Sky time is brain time!...". `/aa flight land` during a round: "We landed!..."
101. [ ] Start a Murloc Boarding Party: "All aboard! Murlocs love free rides...". Close the Academy after 20+ seconds: "Class dismissed!..."
102. [ ] `/aa voice off` (or the Parent Panel **Fizzwick's voice** button): no more voice, sound effects still play. `/aa voice on` brings it back. **Sound OFF** silences both.
103. [ ] Change **Sound channel** to Dialog and move the game's Dialog slider: both effects and voice follow it.
104. [ ] Tell me if any sound is too loud, too quiet, too long, or annoying after a few rounds, and if the voice feels too fast for a 5-year-old.

**Azeroth Naturalist and the Field Journal (v0.9)**. Restart the game client once (new sound and voice files).

105. [ ] The hub shows an **Azeroth Naturalist** tile (no longer "Coming soon"). Clicking it offers **The Field Warden's Survey**; take it or skip it.
106. [ ] Fizzwick says "Grab your field journal! Science time in the wild!" (voice and bubble) when a Naturalist round starts. You hear a page-turn sound.
107. [ ] Initiate: every question has 3 big buttons. Try Zone Sorting, What Animals Need, Living or Not?, Day and Night and Seasons.
108. [ ] Adept: on Spark you get 4 buttons. On Rune/Glyph some questions ask you to type (e.g. "Evaporation", "Herbivore", "Gas"). Try typing in lower case or with "a"/"the" in front: it's accepted.
109. [ ] Read a few questions and explanations in each band. Tell me about anything that's wrong, confusing, or too hard/easy for the age.
110. [ ] Master a Naturalist tier: the banner says "New specimen for your Field Journal: ...", a sparkle chime plays, and Fizzwick says "A new specimen for your journal!". The reward screen names it and shows **Open Field Journal**.
111. [ ] **Open Field Journal** goes straight to the new page (icon, name, "Found in: ...", field note, collected date).
112. [ ] In the journal, switch band tabs, click "?" pages (shows how to collect it and **Go collect it!**), and check the counter "Specimens: N / 45". Fizzwick says "Welcome to your field journal..." the first time.
113. [ ] `/aa journal` opens the journal; `/aa nature` opens the Naturalist skill list; the hub tile's **Journal** button and the skill list's **Field Journal** link work; **Back** returns to the skill list.
114. [ ] A day after mastering a Naturalist tier, its page shows "The ink is fading!" and a **Review now** button. Passing the review restores it.
115. [ ] Log in on another character on the same account: the journal still has every page.
116. [ ] Open Azeroth Naturalist, then take a flight path and start the In-Flight Lesson: it's a "look down" skill and Fizzwick says "Look down! Every zone below is a habitat..."
117. [ ] Parent Panel export / report ends with "Field Journal: N / 45 specimens collected." and has an Azeroth Naturalist section.
118. [ ] Specimen icons all show a real picture (no green "?" boxes) on Forever, Retail and Classic. Tell me which ones are missing.

**Duel of Wits (v0.10)**. Restart the game client once (new sound and voice files). You need **two players with
Azeroth Academy v0.10.0** (two accounts, or a friend), both with an age band picked. Call them A and B.

119. [ ] A: the hub has a gold **Duel of Wits** button; `/aa duel` and shift-click / middle-click on the minimap button open the same screen. The minimap tooltip has a "Shift-click or middle-click" line.
120. [ ] A and B in a party. A picks Rune Forger, 5 questions, **My group**, **Send challenge**. B gets the pop-up (even with the Academy closed) naming A, the subject and 5 questions, and Fizzwick says "A challenger appears!..." if B's Academy is open.
121. [ ] B clicks **Accept**: B's waiting room says "Waiting for the challenger..."; A's lists B as "ready". A clicks **Start race!**.
122. [ ] Both see 3-2-1 (a tick sound each), then "Go!" and the first question. Give A and B different age bands: each gets questions for their own band.
123. [ ] The race bars move for both players as each answers (within a second or two). A wrong answer says "+3 seconds" and shows the right answer.
124. [ ] The first to finish sees "Waiting for the other racers...". When both are done, both see the same ranking, a "Winner:" line, a reward line and Fizzwick's win (fanfare) or "Great race!" line.
125. [ ] Shards went up by the reward, and the minutes line rose by 2 (if the daily cap allows). Play 6 duels: duel minutes stop at 10 for the day.
126. [ ] Emote buttons: B sees "A: Good game!" in chat and on the results screen. Clicking emotes fast only sends one every 3 seconds.
127. [ ] **Block** on the results screen: A blocks B. B challenges A again: B sees "can't duel right now (busy)", A sees nothing. Clear it in Parent Panel → Duel of Wits settings → **Clear blocked list**.
128. [ ] **One player:** `/aa duel B-name` opens with the name filled in. Send it; B gets the pop-up. Let it sit 25 seconds: it closes and A is told B didn't answer.
129. [ ] Typing race with A and B in different bands: both type the same lines; results show WPM and accuracy.
130. [ ] Guild: **My guild** invites everyone in the guild with the addon. Up to 5 racers can join; later ones are told it's full.
131. [ ] B enters combat during a race (hit a training dummy): B leaves with "You left the race because combat started"; A keeps racing and B shows as "left". B can't be invited while in combat or inside a dungeon (A is told why).
132. [ ] Disconnect test: B `/reload`s mid-race. About 15 seconds later A's race marks B as left and finishes normally.
133. [ ] Parent Panel → **Duel of Wits settings**: turn **Group, guild & friend duels** off on B; A's challenge is declined with "duels are off". Turn **Friends only** on: only A on B's friends list can challenge.
134. [ ] Random queue (needs both A and B to allow it in the Parent Panel; default Off): both pick the same subject and length, **Random challenger**, **Find a random challenger**. Within ~20 seconds the race starts by itself. Both only see the other's duel name (like "Clever Gryphon"), never the character name. No new channel appears in any chat tab.
135. [ ] Random queue with **Allow random challengers: Off** shows "A parent can turn on random challengers...". **Stop searching** works; after 5 minutes alone it stops by itself.
136. [ ] `/aa duel leave` leaves a race, waiting room or search. Tell me if anything feels too fast, too slow, or confusing for your kids.

**Gnomish Engineering and the Blueprint Binder (v0.11)**. Restart the game client once (new sound and voice files).

137. [ ] The hub shows a **Gnomish Engineering** tile (no longer "Coming soon"); **Librarian Quests** and **Mechanics Academy** are still "Coming soon". The tile offers **The Tinker's Test Bench**.
138. [ ] A round starts with a gear-whirr sound and Fizzwick saying "Goggles down, wrenches up! Boltby is ready for orders." (voice and bubble).
139. [ ] Initiate **Grid Directions** and **Program Boltby**: the card shows a small grid on the left with Boltby (strider icon with an arrow), a gear or lettered spots A/B/C, and rocks at higher levels. Trace a few with your finger: the answer is always right and only one choice works.
140. [ ] **Turn and Go**: the arrow on Boltby shows which way it faces. Check that "turn right" is Boltby's own right.
141. [ ] Adept **Debugging**: the program is numbered; only one step can be changed to reach the gear. On Rune/Glyph you type the step number or the right direction.
142. [ ] Magister **Variables / Functions / Algorithms / Pseudocode**: code is left-aligned and readable; type numbers on Rune/Glyph. **Boolean Logic** accepts True/False (or yes/no).
143. [ ] Read questions in each band. Tell me about anything confusing or too hard/easy for the age, and whether the grid is big enough to read.
144. [ ] Master a Gnomish Engineering tier: "New blueprint for your Binder: ...", Fizzwick says "A new blueprint! Into the Binder it goes!", and the reward screen shows **Open Blueprint Binder**, which opens on the new page ("Built for: ...").
145. [ ] `/aa blueprints`, the hub tile's **Binder** button and the skill list's **Blueprint Binder** link open the Binder; `/aa journal` still opens the Field Journal. **Back** returns to Gnomish Engineering.
146. [ ] A day later, a Gnomish page says "The lines are smudging!" with **Review now**; passing restores it.
147. [ ] Duel of Wits setup shows 7 subjects in two rows of 4 (Gnomish Engineering included) and nothing overlaps the question-count and "Who" rows. Race on Gnomish Engineering: grid questions show the grid in the race card.
148. [ ] Parent Panel export ends with both "Field Journal: N / 45" and "Blueprint Binder: N / 45" lines.

**Librarian Quests and the Library Passport (v0.12)**. Restart the game client once (new sound and voice files).

149. [ ] The hub shows a **Librarian Quests** tile; only **Mechanics Academy** is still "Coming soon". The tile offers **The Librarian's Reading Room**.
150. [ ] A round starts with a page sound and Fizzwick saying "Shh, library voices! Let's go find some answers." (voice and bubble).
151. [ ] Initiate **Finding the Shelf**, **ABC Order** and **Contents Page**: the shelf list and contents list are left-aligned and easy to read; the answer really is on the right shelf / page.
152. [ ] Adept **Using an Index** and **Chapters**: the index is in ABC order; chapter lengths count both the first and last page. On Rune/Glyph you type page numbers.
153. [ ] Magister **Citing Sources** (Last, First. Title. Year.), **Comparing Sources** (two accounts A and B) and **Reading Tables**: readable, and the numbers add up. Type *author*, *title* or *year* for a missing citation part.
154. [ ] Read questions in each band. Tell me about anything confusing, too hard/easy for the age, or anything that feels one-sided between Alliance and Horde.
155. [ ] Master a Librarian Quests tier: "New stamp for your Library Passport: ...", a stamp sound, Fizzwick says "A new stamp for your Library Passport! Well researched!", and the reward screen shows **Open Library Passport**, which opens on the new stamp ("Library: ...").
156. [ ] `/aa passport`, the hub tile's **Passport** button and the skill list's **Library Passport** link open the passport; **Back** returns to Librarian Quests. `/aa research` opens the subject.
157. [ ] A day later, a Librarian stamp says "The ink is fading!" with **Review now**; passing restores it.
158. [ ] Duel of Wits setup shows 8 subjects in two rows of 4 (Librarian Quests included); a Librarian race shows tables and citations in the race card.
159. [ ] Parent Panel export also lists "Library Passport: N / 45 stamps collected."

**Mechanics Academy and the Tactics Deck (v0.13)**. Restart the game client once (new sound and voice files).

160. [ ] The hub shows 7 real subject tiles and no "Coming soon" tile. **Mechanics Academy** offers **The Coach's Tryout**.
161. [ ] A round starts with a horn-and-thump sound and Fizzwick saying "Tanks up front, healers ready. Training begins!" (voice and bubble).
162. [ ] Initiate **Avoid the Fire**: the grid shows fire icons on red squares and letters A/B/C; exactly one letter is safe. At higher levels the fire "spreads" (pick the spot not touching fire) and the hero icon must step out (Up/Down/Left/Right).
163. [ ] Initiate **Health Bars** and **Count the Monsters**: names and numbers are readable; the answer is the lowest health / right count.
164. [ ] Adept **Threat**, **Interrupts** and **Cooldowns**: type numbers on Rune/Glyph; the minutes:seconds question shows 4 buttons.
165. [ ] Adept **Classes and Roles** on WoW Forever: only Warrior, Paladin, Hunter, Rogue, Priest, Shaman, Mage, Warlock and Druid appear ("This game has 9 classes"). On Retail you also see Death Knight, Monk, Demon Hunter and Evoker (13).
166. [ ] Magister **DPS Math**, **Mana Budget** and **Priority Lists**: the numbers work out; the priority list is left-aligned and the answer is the first rule that is true.
167. [ ] Magister **Racial Traits** on WoW Forever shows only the 8 original races. Tell me if any trait description looks wrong for your client.
168. [ ] Master a Mechanics tier: "New card for your Tactics Deck: ...", Fizzwick says "Drill complete! A new tactics card for your deck!", and **Open Tactics Deck** opens on the new card ("Practice it in: ...").
169. [ ] `/aa deck`, the hub tile's **Deck** button and the skill list's **Tactics Deck** link open the deck; `/aa mechanics` opens the subject.
170. [ ] Duel of Wits setup shows 9 subjects in three rows (4 + 4 + 1) and nothing overlaps the question-count and "Who" rows. A Mechanics race shows the fire grid in the race card.
171. [ ] Parent Panel export also lists "Tactics Deck: N / 45 cards collected."

## Known limits (v0.13)

- **Class and race lists are picked by client type.** WoW Forever and Classic Era get the original 9 classes and 8 races,
  Retail gets 13 and 12. If WoW Forever ever adds the newer classes, `C.HasModernClasses` in `Adapters/Compat.lua` is
  the one line to change. Class and trait names are English until the v1.0 translations.
- **Racial traits are the long-standing ones** (one per race). Exact game numbers (damage, cooldowns) are never quoted,
  because they change between patches; all battle math uses made-up abilities and numbers.
- **Duel players on different clients** may get different class/race questions in a Mechanics race (each racer's game
  builds its own set, as always), which keeps it fair for their own game.
- **27 lines are spoken now** (2 new Mechanics lines); one new sound effect (`drill`).

## Known limits (v0.12)

- **Research is practised on short texts in the card**, not real books or web searches; the libraries and books in the
  questions are invented for the Academy (no real titles or authors).
- **Librarian duels need v0.12 on every racer** (older clients don't answer the invite, as with Gnomish duels).
- **No in-flight Librarian skills**: flight rounds on Librarian Quests use normal skill picks.
- **25 lines are spoken now** (2 new Librarian lines); one new sound effect (`stamp`).

## Known limits (v0.11)

- **Grid puzzles are drawn with icons, not animated.** Boltby doesn't walk the path yet; kids trace it themselves.
  The answer explanation spells out the path.
- **Code is pseudocode in English** (keywords like IF, WHILE, function, return), like most beginner coding courses.
- **Gnomish Engineering duels need v0.11 on every racer.** A v0.10 player can't build those questions, so their
  game just doesn't answer the invite (the challenger is told they didn't answer).
- **No in-flight Gnomish skills**: flight rounds on Gnomish Engineering use normal skill picks.
- **23 lines are spoken now** (2 new Gnomish lines); one new sound effect (`gears`).

## Known limits (v0.10)

- **Duel of Wits hasn't been tried between two real clients yet.** It was tested headless with simulated players on a
  lossy, out-of-order network and with UI smoke tests. Two accounts are the real test (checklist 119-136).
- **Both players need the same Duel of Wits protocol** (v0.10.0). Older versions don't answer at all; newer ones say so.
- **The random queue needs a modern client** (Forever, Retail, Classic Era). It uses a hidden custom channel, which very
  old clients can't send addon messages on; there it explains that it's unavailable. Random matching only finds players who
  are searching at the same time on the same realm group.
- **Friends only** checks your character's friends list, not Battle.net friends.
- **Anti-cheat is light.** The challenger's game rejects impossible reports (more answers than questions, answering faster
  than 0.4 s a question, time running ahead of the race). A determined cheater with a modified addon could still win a race;
  it only changes shards in their own game.
- **Duels only send what a race needs**: subject, length, age band, duel name numbers, scores and emote numbers. WoW itself
  always shows the sender's character name to addons, so the addon hides it in random races; it can't make it secret.
- **21 lines are spoken now** (4 new duel lines). The other duel lines are text only.

## Known limits (v0.9)

- **Naturalist content is a first pass.** About 260 curated items plus generated food-chain, matter,
  habitat and life-cycle questions. It has been accuracy-checked but not yet played by kids; tell me about
  anything wrong or unclear.
- **Specimen icons are in-game icons** chosen to work on every client. A few may look generic, or be missing on
  very old clients (then you'd see the "?" icon).
- **Only 17 lines are spoken** (12 from v0.8 plus 5 Naturalist lines). Everything else Fizzwick says stays text-only, and the faction
  leaders never speak. English only (like the rest of the addon for now).
- **New or replaced sound files need a full game restart**, not `/reload`.
- **The voice and effects haven't been heard in game yet.** They were checked for loudness and
  length offline. Tell me if a clip doesn't play, because the addon then silently falls back to text only
  (and to the built-in sound for effects).
- **Playtime unlocks are soft.** The addon tracks bonus minutes and shows them, but it can't
  enforce screen time. Pair it with Battle.net Parental Controls or the operating system's.
- **Saving happens at logout or `/reload`.** If the game crashes, progress since the last reload can be lost.
- **Mastery is per character.** A kid with two characters builds progress separately on each. The daily
  minute cap and parent settings are shared across the account.
- **Reviews use your computer's clock** (`time()`). Changing the clock moves reviews too. It's
  harmless, just a way to "time travel" when testing.
- **The trial is short on purpose** (10 problems), so a lucky or unlucky guess can place a skill one
  tier off. Practice and the Parent Panel **Start** override fix that. Adaptivity inside rounds keeps
  correcting difficulty too.
- **Three subjects are playable** (plus the optional Lore Quiz). The other four tiles still say "Coming soon".
- **The keyword rubric is simple.** It looks for key words, not meaning. A clever wrong answer that uses
  the right words can pass, and a correct answer worded very differently can miss. The model answer is
  always shown, and the rubric only applies on Rune, Glyph, and trials.
- **Lore content is hand-written and limited:** 18 sentences, 16 stories, 14 sequences, 14 Adept passages,
  22 word-tile sentences, 12 Magister passages, 8 two-sided accounts, 20 grammar items, 12 written
  prompts, and 60 quiz questions. Shuffle bags stop repeats within a pass, but a kid who plays a lot will
  see passages again.
- **New or replaced art needs a full game restart** to be picked up. The manifest is the source of truth,
  because some clients report a missing texture as loaded. Run `tools/convert_art.sh` again after
  adding or removing files.
- **The art adds about 14 MB** of uncompressed TGA (26 files) to the addon folder. Textures load on demand,
  but the 512 full figures use about 1 MB of texture memory each while they're shown.
- **Murloc Boarding Party speeds are tuned in simulation.**
  - In simulation the routes need roughly these speeds: Adept harbor about 7 WPM, Ratchet 10, the Maelstrom 12; Magister harbor about 17 WPM, Ratchet 20, the Maelstrom 24 (all with occasional typos).
  - Real kids also need time to read, so the game may feel faster than that. The numbers are easy to change in `Core/Boarding.lua` (`B.BANDS`).
- **The game needs keyboard focus.** The typing box holds focus while you play. If a click elsewhere takes focus away, click the box again.
- **Per-skill icons are untested in game.** Every icon name exists in the game's icon set, but an
  older client (Classic Era) might be missing a few. A missing one shows as a green or blank square.
- **Spelling is English only.** The word lists are hand-curated. Spelling answers avoid words that US
  and UK English spell differently. Definitions use US spelling (for example "armor"). Other
  languages would need their own word lists, not just translated UI strings.
- **No audio in spelling.** Spelling is tested by unscrambling, filling in letters, choosing a spelling,
  and spelling from a meaning, never by dictation.
- **Typing speed depends on reading speed too.** The WPM timer starts when the line appears, so
  younger readers show lower WPM. It's for personal bests, not for passing.
- **Character models are untested in a real client.**
  - The creature display IDs come from the game's own NPC data and match in both the Classic and Retail databases. Whether Forever renders them is still to be confirmed.
  - A model that doesn't load falls back to the next ID and then to an icon. On older clients that can't report load failures, a blank portrait is possible.
- **Custom sound files need a game restart** to be noticed.
  - If a client reports a missing file as "playing", that event goes silent. **Custom sound files: OFF** fixes it.
- **There is no per-addon volume.** The channel option picks which game slider applies. The game's volume settings are never changed.
- **The faction leaders are text only**, by design. Fizzwick speaks only his 12 recorded lines (v0.8), in an original voice.
- **English only so far.** The translation setup is in place for deDE, frFR, esES, esMX, ptBR, ruRU, koKR,
  and zhTW, but those tables are empty and fall back to English. Word-problem templates and
  number formats (1,000 vs 1.000) will need care when translated.
- **Icons, sounds, and fonts haven't been checked in a real client yet.** Missing textures would show as
  blank or green squares, and a missing sound just stays silent. Neither causes errors.
- **The PIN isn't security** (see above).
- **In-Flight Lessons haven't been tried on a real flight yet.** Flights are found by checking
  `UnitOnTaxi("player")` twice a second, plus control-lost/gained events as a hint. That works on Retail and
  Classic, but WoW Forever's behavior is unverified (see checklist item 88). Flight length can't be read
  reliably, so the round is always 5 problems, with "another round" while still flying.
- **"Not this session" lasts until logout or `/reload`.** It isn't saved.
- **The minimap button hasn't been seen in a real client yet.** The ring, icon size and offsets copy the standard minimap-button layout, but they may need a pixel nudge.

## Files

```
AzerothAcademy/
  AzerothAcademy.toc        one TOC, multi-interface
  Core/                     shared logic, pure Lua 5.1, no UI or game calls
    Namespace.lua           namespace + utilities (RNG helpers, hash, number parsing)
    Progress.lua            shards, ranks, minutes, PIN, profile, SavedVariables + v0.1->v0.2 migration
    Modules.lua             subject registry (id, bands, skills, generators, input modes)
    Review.lua              spaced review schedule (1/3/7 days), fading
    Mastery.lua             tier windows, 85%-of-10 mastery, unlocks, quick-drill recommendation
    Session.lua             practice and review rounds: streaks, combo/overcharge, adaptivity, rewards
    Trial.lua               placement trial + mastery exam (same format), start tiers, overrides
    Report.lua              plain-text parent export (all modules, placement vs exam)
    Guide.lua               Fizzwick's lines (no-repeat shuffle bags), cast + model IDs, cameo rules
    SoundEvents.lua         sound event registry: SoundKit fallbacks, custom-file plan, mute/level/channel
    MathGen.lua             Rune Forger: 15 procedural generators, registered as a module
    ScribeData.lua          Scribe's Scrolls word lists, sentences, typing lines (curated, validated by tests)
    ScribeGen.lua           Scribe's Scrolls: 15 generators, text/typing checker, WPM, registered as module #2
    LoreData.lua            Lore Chronicles passages, questions, rubrics + Lore Quiz questions (original writing)
    LoreGen.lua             Lore Chronicles (module #3, 15 generators, keyword rubric) + Lore Quiz (unbanded)
    NaturalistData.lua      Azeroth Naturalist questions, habitats, food chains, substances, life cycles, 45 specimens (original)
    NaturalistGen.lua       Azeroth Naturalist (module #4, 15 generators, typed-answer checker); registers the Field Journal book
    Journal.lua             collection books (v0.11): Field Journal + Blueprint Binder share one account-wide store
    GnomishData.lua         Gnomish Engineering curated questions + 45 blueprint pages (original writing)
    GnomishGen.lua          Gnomish Engineering (module #5): grid engine (moves, turns, loops, BFS), 15 generators, checker
    LibrarianData.lua       Librarian Quests curated questions, topics, invented books, comparisons, tables, 45 stamps (original)
    LibrarianGen.lua        Librarian Quests (module #6): shelves, contents, index, citation, comparison and table generators
    MechanicsData.lua       Mechanics Academy curated questions, classes, racial traits, 45 tactics cards (original writing)
    MechanicsGen.lua        Mechanics Academy (module #7): fire grids, battle math, priority lists, client-aware class lists
    Art.lua                 posed art rules: pose per event/subject, head crops, Sprocket states, fallbacks
    SkillIcons.lua          per-skill in-game icon paths
    BoardingData.lua        Murloc Boarding Party crew orders + Tidehunter sentences (original writing)
    Boarding.lua            Murloc Boarding Party rules: waves, creeping, typing/typos, broadside, routes, rewards, log
    MinimapMath.lua         minimap button rim position for round/square/corner minimaps, drag angle
    Flight.lua              In-Flight Lessons rules: takeoff/landing edges, once per flight, combat/instance/cap/mode
    Voice.lua               Fizzwick's recorded voice rules: which line, one at a time, gaps, repeat throttle, on/off
    DuelProto.lua           Duel of Wits wire format: versioned, escaped messages, chunking, throttle queue
    Duel.lua                Duel of Wits engine: invites, lobby, seeded question sets, race, scoring, anti-cheat, random queue
  Locales/                  enUS strings, empty stubs for 8 locales, fallback setup
  Adapters/Compat.lua       client detection and every version-sensitive API call
  UI/                       Widgets (+ reveal/pulse/count-up animations), Hub (+ profile/home), Guide (Fizzwick strip,
                            parrot, cameo card, rank-up celebration), Lessons (skill list/problem/reward for any
                            module), Trial (trial intro/result), ParentPanel, Minimap (minimap button), Flight (flight watcher + toast),
                            Boarding (Murloc Boarding Party: setup, ship deck, result), Journal (Field Journal and
                            Blueprint Binder), Widgets.Grid (Gnomish command grid),
                            Duel (Duel of Wits: setup + waiting room, invite pop-up, race, results)
  Media/Sounds/             24 original sound effects (.ogg) + README.md (events, fallbacks, prompts, voice notes)
  Media/Sounds/VO/          23 original Fizzwick voice clips (.ogg)
  Media/Art/                Hex's posed art: 13 x 512 full figures + 13 x 256 head crops (TGA), Manifest.lua, README.md
  tools/convert_art.sh      PNG -> 512 TGA + 256 head crops (ImageMagick) + manifest writer
  tools/make_heads.py       face-centered 256 head-and-chest crops (Python, Pillow + numpy)
  tools/master_audio.py     master a generated clip: mono 44.1 kHz, trim, ~-16 LUFS, Ogg Vorbis q4 (ffmpeg + numpy)
  tools/pack.py             build the release zip (leaves out tests/, .luacheckrc, git files, raw audio)
  Main.lua                  events, slash commands, combat hide/resume
  README.md, DESIGN.md
```

## Developer checks

v0.10 adds harness section 23: the wire format (escaping, chunking, throttle), the seeded RNG, deterministic duel
sets for every subject x band x length on two fresh clients, validation and ranking, and a simulated chat bus with
2-7 clients covering clean races, 25% message loss with reordering, version mismatch, disconnects (racer and host),
combat, auto-declines, blocking, the 5-racer cap, typing races, the random queue and the schema 6 -> 7 migration.
The UI smoke tests host a party race, accept an invite, hit combat, a version mismatch, the parent settings and
the random queue on all four client runs (the legacy run uses the old global `SendAddonMessage`).

v0.9 adds harness section 22 (Azeroth Naturalist data + generators + Field Journal + schema 6) and a UI smoke
pass through the Naturalist tile, survey, every skill, a specimen, the journal and an in-flight round.
The harness prints the Naturalist question-bank size per band.

The source folder also contains `tests/` and `.luacheckrc`. They're left out of the zip because
the game doesn't need them. `tests/run_all.sh` runs:
`luac -p` on every file, `luacheck` (0 warnings), a core-purity lint (Core/ may only use
`time`, `date`, `GetLocale`), the headless harness (`lua tests/harness.lua 600`), and UI smoke
tests that load every TOC file against a mock WoW API as Forever (16001), Retail (120105),
Classic Era (11509), and a "legacy" run with no `C_Timer` or `BackdropTemplate`.
Since v0.2 the harness reads its file list from the TOC. It also covers registering a dummy
module, placement, overrides, spaced review on a fake clock, the exam, and migration from v0.1 data.
The UI smoke test plays a full trial, a review, a failed review then Practice, the exam, and the
new Parent Panel buttons.
v0.3 adds validation of every Scribe word entry and generated problem, unit tests for the text
checker and typing scoring (accuracy, WPM, pass marks by tier), Scribe's trial, reviews, exam, and
report through the engine, and migration from v0.2 data. The UI smoke test plays the Scribe's Trial,
a round of every Scribe skill in every band, text and typing answers through the edit box, the
2-column definition buttons, `/aa scribe`, and the Parent Panel subject picker and export scope.

v0.4 harness additions:
- Every Fizzwick event has clean lines that fit the strip, and no encouragement line contains mocking words.
- Shuffle bags never repeat a line within a bag or back-to-back.
- Cameo rules: per faction, neutral, unknown faction, toggled off, rate limit, and the every-5th milestone.
- The host strings are faction-neutral, and the review strings are subject-neutral.
- The sound registry's plan logic (mute, important-only, missing file, channel), and the sound README covers every event.
- Migration from v0.3.

v0.4 smoke-test mocks: `PlayerModel` (Retail pretends one display ID fails, to exercise the async fallback; legacy has no model widget at all), `UnitFactionGroup` (Horde / Alliance / none / Neutral), `PlaySoundFile` (only `correct.ogg` "exists"), and AnimationGroups (stripped in legacy). The smoke test then checks:
- Fizzwick's model or icon fallback, and the greeting.
- The strip hiding in the Parent Panel.
- The per-tile Drill button.
- Parrot hints and the answer lines.
- The combo glow.
- Custom-file-then-kit sound fallback.
- The per-subject reward icon, the animated versus reduced-motion reveal, and the shard counter.
- The rank-up card followed by a Thrall, Bolvar, or no cameo.
- Every new Parent Panel toggle, mute, and channel pass-through.

v0.5 harness additions (section 18):
- Every Lore Chronicles entry is validated:
  - Literal Initiate answers and sequence steps appear in their text, and every vocabulary word appears in its passage.
  - Each answer appears exactly once among the choices, and distractors are distinct.
  - Text and choice lengths stay inside the card limits (480 and 80 characters).
  - Word tiles rebuild their sentence, and the wrong orders use the same tiles.
  - Every written-answer model passes its own rubric, while the wrong answers and junk ("I do not know") fail it.
- Every lore node is generated at every level, tier, and purpose. The quiz is checked at 4 choices with the answer once.
- Rubric unit tests, the build checker, and shuffle bags with no repeats inside a pass.
- Lore through the engine: trial, mastery, exam, reviews, and the report.
- The unbanded quiz: same topics for every band, no trials, no hub tile, reviews once per tier, and a single "Everyone (all ages)" report section.
- Art rules: moods, fallbacks, refused files, strip frames, and the README and script cover every file.
- Magni as the Alliance cameo.

The v0.5 smoke tests cover:
- The Chronicler's Trial, and a round of every lore skill in every band.
- Typed sentence building and written answers in the wide box, with the rubric feedback and the text kept after a miss.
- The quiz link and back link, `/aa quiz`, `/aa lore`, and `/aa trial` redirecting on the quiz.
- The Parent Panel subject picker across all 4 modules.
- Manifest art replacing the model, mood fallbacks, the talk strip, a refused texture falling back to the next mood and then the model, and Sprocket art.
- The Magni cameo.

The v0.6 tests cover:
- Typing form: lowercase and auto-skipped punctuation for younger bands, exact text for Magister, and green-coverage mapping.
- Order data: no duplicates, lengths that fit the deck, band rules (letters, words, orders, sentences), and neutral wording.
- A simulated typist winning every band × route (all waves, then the Tidehunter), and measured WPM.
- Initiate never failing even at very slow typing; Adept losing after three murlocs reach the wheel.
- Typing rules: targeting the murloc closest to the wheel, refused typos with progress kept, backspace, capitals, and Magister exactness.
- Broadside: the meter math, clearing the deck, and stunning and pushing back the Tidehunter.
- Pause, frame-hitch clamping, and no two murlocs on deck with the same first letter.
- Saving: rewards, first-clear and par bonuses, route unlocks, the parent "unlock all" setting, the log size, and report lines. Schema stays 4.
- Smoke tests: the hub tile and skill-list shortcuts, `/aa murloc`, live green typing, stumbles, splash (animated and reduced motion), the broadside button and Enter, Escape/Resume, pause on hub close, a full voyage won through the UI with the Tidehunter model (icon in legacy), the result pose, route unlock and selection, Magister case rules, the Initiate no-fail label, slot pooling, and the report.

The v0.5.1 tests cover:
- Every event's pose, head crops for the strip, and the full figures for heroes.
- Fallbacks: head → full → greet → model/icon, plus files refused by the client.
- Idle poses per subject, Sprocket curious/squawk with hint-available brightness, and teaching on hints and worked examples.
- A real Lore round (researching → encouraging → teaching), surprised on a new typing best, and the reward, trial-result and rank-up heroes.
- The shipped manifest matching the 26 files, and each TGA header (512 or 256, 32-bit, uncompressed, bottom-left origin).
- Every skill having its own distinct icon, also checked on the forge rows.

`tools/convert_art.sh` was rerun for v0.5.1 on the approved PNGs. It produced 512 TGAs that match the
originals and face-centered head crops, and wrote a 26-entry manifest.
For v0.5, `tools/convert_art.sh` was run with ImageMagick 7.1.2 on test PNGs. It produced 512x512 RGBA TGAs, a 1024x256 (4-frame) and a 2048x256 (8-frame) strip, and a correct manifest. Removed files dropped out of the manifest, and a bad `STRIP_FRAMES` was rejected.

## Changelog

**v0.13.0**
- **Mechanics Academy (group tactics), subject #7:** 15 skills across Initiate / Adept / Magister with the usual
  mastery, trial ("The Coach's Tryout"), reviews, exam ("Tactics Mastery Exam"), shards and report. Host: Coach Brakka
  Steelwhistle (original). 38 curated questions plus generators for fire grids, monster counts, health bars, threat,
  interrupts, cooldowns, classes, DPS, mana, priority lists, phase health and racial traits.
- **Avoid the Fire:** `W.Grid` learned fire squares (in-game fire icon on a red square, letters on top) and per-puzzle
  icon overrides (the hero). Every fire puzzle is re-checked by the harness: exactly one safe spot / one way out.
- **Client-aware lists:** `Compat.HasModernClasses()` sets `ns.Env.modernClasses`; the module filters classes and races.
- **Tactics Deck:** 45 tactics cards on the shared collection system.
- **Hub:** all 7 subject tiles are real; the last "Coming soon" tile is gone.
- **Duel of Wits:** Mechanics Academy is a duel subject (9 subjects).
- **Fizzwick:** 5 new events with 15 lines, 2 voice clips and the `drill` sound effect (from the v0.11 audio batch).
- **Slash:** `/aa mechanics` (`tactics`, `training`), `/aa deck` (`cards`).
- **Tests:** harness section 26 (both class lists, no newer classes/races on Forever/Era, fire-grid and priority-list
  replay, healer counts) and a UI smoke pass (fire icon, hero icon, class list per client, deck).

**v0.12.0**
- **Librarian Quests (research skills), subject #6:** 15 skills across Initiate / Adept / Magister with the usual
  Spark → Rune → Glyph mastery, placement trial ("The Librarian's Reading Room"), spaced review, mastery exam, shards,
  bonus minutes and the parent report. Host: Head Librarian Tamsin Quillfeather (original, neutral). 69 curated
  questions plus generators for shelves, ABC order, contents pages, indexes, search words, citations, two-source
  comparisons and data tables.
- **Library Passport:** 45 library stamps on the shared collection system; Alliance and Horde libraries appear equally
  often (checked by the harness), plus neutral ones.
- **Duel of Wits:** Librarian Quests is a duel subject (8 subjects, two rows of 4).
- **Fizzwick:** 5 new events (round start, right, wrong, new stamp, passport) with 15 lines, 2 voice clips and the
  `stamp` sound effect (generated in the v0.11 audio batch, no new credits).
- **Slash:** `/aa library` (`librarian`, `research`), `/aa passport` (`stamps`).
- **Tests:** harness section 25 (citation format, contents/index builders, balanced faction mentions, ABC/table/contents
  answers re-checked for every generated problem) and a UI smoke pass for the subject and its passport.

**v0.11.0**
- **Gnomish Engineering (programming), subject #5:** 15 skills across Initiate / Adept / Magister with the usual
  Spark → Rune → Glyph mastery, placement trial ("The Tinker's Test Bench"), spaced review, mastery exam, shards,
  bonus minutes and the parent report. Host: Tinker Nixa Sprocketwhirl; star: Boltby the clockwork critter (both original).
- **Command-grid puzzles:** a pure-Lua grid engine (absolute moves, Forward/Turn left/Turn right, nested loops, walls,
  BFS shortest paths). Where-does-it-stop puzzles letter the real end square plus one-mistake-away decoys; program
  choices are replayed so only the answer reaches the gear; debugging puzzles have exactly one fixable step.
  `W.Grid` draws the grid (in-game icons) on the problem card and in Duel of Wits races.
- **Blueprint Binder:** 45 gadget blueprints. The Field Journal code became a shared collection system
  (`Core/Journal.lua`, books keyed by module, one account-wide store, per-book strings/events/sounds); the journal view,
  reward screen, banner and report now work for any book. No schema change.
- **Duel of Wits:** Gnomish Engineering is a duel subject; the setup screen lays subjects out 4 per row when there are more than 6.
- **Fizzwick:** 5 new events (round start, right, wrong, new blueprint, binder) with 15 lines, 2 new voice clips and the
  `gears` sound effect. (ElevenLabs: 306 credits for this push's whole audio batch, which also covers v0.12/v0.13 lines.)
- **Slash:** `/aa gnomish` (`engineering`, `code`), `/aa blueprints` (`binder`).
- **Tests:** a reusable subject suite in the harness (registration, book, curated data, generator sweep, engine,
  report, deterministic duel sets) plus section 24 (grid engine + replay of every grid puzzle), and a reusable UI smoke
  pass for subjects with a book.

**v0.10.0**
- **Duel of Wits, multiplayer learning races:** challenge your party/raid, guild or one player; 2-5 racers; any subject
  (Rune Forger, Scribe's Scrolls, Typing race, Lore Chronicles, Azeroth Naturalist, Lore Quiz) with 5 or 10 questions.
  Accept/decline pop-up with automatic "no" in combat, in instances, when a parent turned duels off, for non-friends
  in friends-only mode, and after 25 seconds. 3-2-1 countdown, live race bars, one try per question, +3 s per wrong
  answer, most correct wins with time as the tiebreak. Typing races: same lines for everyone, WPM + accuracy.
- **Deterministic questions:** a shared seed plus each racer's own age band builds the set on every client
  (`Util.NewRNG`/`Util.WithRNG`; every generator now draws through `Util.Random`; Lore/Naturalist no-repeat bags are
  set aside while a duel set is built).
- **Protocol:** addon messages (prefix `AzAcadDuel`, protocol 1) through Compat (`C_ChatInfo` or the legacy globals) on
  PARTY/RAID/GUILD/WHISPER (+ a hidden CHANNEL for the queue). Versioned header with a VER handshake, escaped fields,
  chunking past 250 bytes, a token-bucket throttle with coalesced progress updates, ACK + retry for the important
  messages, sequence numbers against stale/out-of-order updates, keepalives and silence timeouts. Host-side sanity
  checks mark impossible reports as "not counted".
- **Rewards without farming:** 2 shards per correct answer, +5 finish, +10 win (max 40); 2 bonus minutes for a finished
  race against a real opponent, max 10 a day from duels and always inside the daily cap. Answers count as practice
  stats only, never toward the mastery window.
- **Random challengers (phase 2), OFF by default:** parent-gated in a new PIN-protected **Duel of Wits settings**
  overlay (duels on/off, friends only, random challengers, duel name, clear blocked list). Matching by subject, length
  and age band (at most one band apart) on a hidden channel that is joined only while searching. Random opponents see
  only a preset-word duel name; no free text exists anywhere; Block on every result.
- **Entry points:** hub button, `/aa duel [name|queue|leave]`, shift/middle-click on the minimap button (+ tooltip line).
- **Fizzwick:** 5 new events (invite, start, win, done, waiting) with 14 lines, 4 new voice clips (same original voice,
  ElevenLabs) and 2 new sound effects (`countdown`, `duelwin`); 219 ElevenLabs credits in total.
- **Saved data (schema 7):** `settings.duel`, `AzerothAcademyDB.duel` (block list, duel minutes per day) and per-character
  duel stats. Migration from v0.9 fills the defaults and picks a random duel name once.
- **Tests:** harness section 23 (multi-client simulated bus) and duel UI smoke passes on all four client runs.

**v0.9.0**
- **Azeroth Naturalist (science), subject #4:** 15 skills across Initiate / Adept / Magister with the usual
  Spark → Rune → Glyph mastery (9 of the last 10), placement trial ("The Field Warden's Survey"), spaced review,
  mastery exam, shards, bonus minutes and the parent report. Host: Field Warden Bramble Quickroot (original, neutral).
  All questions, explanations and field notes are original writing; no game text or art is copied.
- **Field Journal:** 45 specimen pages collected by mastering Naturalist tiers. Band tabs, a 5 x 3 grid, page view,
  faded ink + **Review now** when a skill is due or fading, **Go collect it!** on missing pages. New-specimen banner,
  sound and Fizzwick line; **Open Field Journal** on the reward screen; `/aa journal`, a skill-list link and a hub tile button.
- **Saved data (schema 6):** `AzerothAcademyDB.journal` (account-wide). Migration from v0.8 creates the journal and fills it
  with any Naturalist tiers already mastered; a profile reset keeps the family journal.
- **Fizzwick:** 6 new events (Naturalist round start, right, wrong, new specimen, journal, flight) with 21 lines, and
  5 new voice clips in his original voice (ElevenLabs, same voice id, about 300 credits). Two new sound effects:
  `page` (journal / round start) and `specimen` (new page).
- **In-Flight Lessons:** a subject can choose "look down" skills for flight rounds and its own flight line;
  Naturalist uses both. `Mastery.Recommend` takes an optional preferred-skill list.
- **Typed science answers:** short words only (Adept/Magister, Rune/Glyph/trial), forgiving case, punctuation, a leading article
  and listed alternatives.
- **Tests:** data validation for every Naturalist item (levels, distractors, lengths, neutrality), every skill x level x tier x
  purpose generated, food-chain distractors never secretly correct, typed-answer checks, the full engine (trial, mastery →
  specimens, exam, review → faded ink, flight preference, reset, 5 → 6 migration, report), and UI smoke for the tile, survey,
  every skill, specimen banner, journal view and actions, slash commands and the in-flight round on all four client runs.

**v0.8.0**
- **Real sounds:** 19 original, kid-friendly sound effects generated for the addon (ElevenLabs), mono 44.1 kHz Ogg,
  trimmed and loudness-matched (about -16 LUFS). Built-in game sounds remain as the fallback.
  New `flight` sound event for the In-Flight Lesson pop-up.
- **Fizzwick's voice:** an original designed voice ("Professor Fizzwick Coppercoil", not a clone or imitation
  of anyone) speaks 12 lines, always matching the bubble text. One clip at a time, throttled, rank-up/mastery
  may interrupt, goodbye on close after a real visit (not in combat).
- **Controls:** Parent Panel **Fizzwick's voice: ON/OFF**, `/aa voice on|off`. The voice shares the
  sound channel, volume and mute with the effects. Saved per account (no schema change).
- **Tests:** voice rules (key match, prefer-once, busy/gap/repeat, interrupts, off/mute, missing files),
  every referenced sound file exists and is Ogg, the packager keeps `.ogg`, and UI smoke for voice, the slash
  command, the Parent Panel toggle and goodbye.
- **Repo hygiene:** `.gitignore` (zips, raw renders, junk). `tools/pack.py` and `tools/master_audio.py` are now in the repo.

**v0.7.0**
- **In-Flight Lessons** (Hex's idea): Fizzwick offers a quick round a couple of seconds after a flight path takes off.
  - Modes: Off, Ask first (default: a small non-blocking pop-up with Start / Not now / Not this session), and Auto-open.
  - The quick round is Review Time if reviews are due, otherwise 5 problems of the recommended skill. **Another round** is offered while still flying.
  - Landing never closes anything: a finished round shows its reward, and an unfinished one stays open with no penalty.
  - Never in combat, instances, while the Academy is open, before a band is picked, or past the daily cap. At most once per flight.
  - Parent Panel button, `/aa flight [off|toast|auto]`, and `/aa flight test` / `land` to try it without flying.
  - New Fizzwick lines: flight jokes, round done in the air, and landing.
- Replaces the v0.1 chat-only flight nudge. **Schema 5:** a parent who had turned the nudge off gets In-Flight Lessons off. `/aa nudge` still works.
- Tests: harness checks for the trigger rules (edges, once per flight, delay, combat waits, instance/open/band/cap/off skips, session mute, test mode), the migration, and the 5-problem round; UI smoke flies through every case on all four client runs.

**v0.6.1**
- **Minimap button** (Hex's request; replaces the old "no minimap button" decision).
  - Round, standard look: tracking-border ring, Fizzwick head-crop icon (in-game engineering icon as a fallback), highlight glow.
  - Left-click toggles the hub, right-click opens the Parent Panel behind the PIN, and drag moves it around the rim. The angle is saved per account.
  - The tooltip shows help plus rank, shards, minutes today and reviews due.
  - Hide or show it with `/aa minimap` or the Parent Panel toggle.
  - Handles square and corner minimaps via `GetMinimapShape`. If LibDBIcon is already loaded by another addon, it registers there instead (no libraries shipped).
- New setting `minimap = { hide, angle }` is filled into existing saved data automatically, so the schema stays 4.
- Tests: harness checks for the rim math (round, square, corner shapes, drag angle) and the setting; UI smoke checks for creation (once only), look, tooltip, clicks, PIN, combat, drag and save, square minimap, and both hide/show paths on all four client runs.

**v0.6.0**
- **Murloc Boarding Party** (Hex's idea): a typing mini-game in Scribe's Scrolls, with a hub tile shortcut and `/aa murloc`.
  - Murlocs climb aboard carrying crew orders, and typing an order knocks them overboard.
  - Typos are refused but cost no progress.
  - The broadside meter clears the deck, and the Murloc Tidehunter boss carries a full sentence.
  - Bands: letters and words with no fail state (5-7), crew orders (8-10), timed sentences with WPM and par (11-13).
  - Three routes unlock in order: Booty Bay Harbor → Ratchet → the Maelstrom.
  - Shards, a voyage log with best WPM, and lines in the parent report.
  - In-game murloc icons and model, Fizzwick at the ship's wheel, and new sound events `splash`, `cannon` and `gurgle` (built-in kits plus custom-sound slots).
  - Reduced motion is respected.
- New Fizzwick lines for the voyage (8 events). Voyage data is saved under `modules.scribe.boarding` on first play, so the schema stays 4.

**v0.5.1**
- **Hex's posed art is wired in at full quality.**
  - 11 Fizzwick poses and 2 Sprocket states, each as a 512 full figure and a 256 face-centered head crop (26 TGAs).
  - The old mood slots are replaced by poses mapped to every guide event, and idle poses depend on the subject.
  - Sprocket is curious (bright when a hint is available) and squawks while he delivers a hint.
  - Teaching on hints and worked examples; surprised on a new typing best.
  - Large full-figure Fizzwick on the reward screen, the trial result, and the rank-up card.
  - Fallbacks: head → full → greet → model → icon. Reduced motion is respected.
- **Per-skill icons**: 50 distinct in-game icons, one per skill, on the skill lists.
- `tools/convert_art.sh` handles poses, Sprocket states, and head crops, and now writes bottom-left TGAs (`-flip -orient BottomLeft`). `tools/make_heads.py` is new.
- There is no new saved data (schema 4).

**v0.5.0**
- **Lore Chronicles**, subject #3 (reading & writing), with 15 skills across 3 bands:
  - Comprehension, sequencing, main idea, feelings, cause & effect, vocabulary in context, and sentence building.
  - Inference, Horde vs Alliance accounts, purpose & summary, grammar correction, and short written answers checked by a keyword rubric.
  - All passages are original, and lore is paraphrased.
  - It is hosted by Chronicler Zixi Inkspark in Gadgetzan. Trial, reviews, exam, and report work unchanged.
- **Lore Quiz for Everyone**: an optional adult/family track with 60 questions in 5 topics.
  - It is the first **unbanded** module (`unbanded`, `noTrials`, `hidden`, `linkModule` in the registry).
  - It is reached from the Lore Chronicles list or `/aa quiz`.
- **Alliance cameo is now King Magni Bronzebeard** (display 3597, NPC 2784), keeping the banner icon fallback. The lines were rewritten with a dwarven flavor.
- **Custom portrait slots** (`Media/Art`):
  - Five Fizzwick moods, Sprocket, and an optional talk strip.
  - Missing or refused files fall back to the model, then the icon.
  - `tools/convert_art.sh` converts PNG to TGA and writes the manifest.
- Problem screen:
  - Wide text box for sentences.
  - Rubric feedback ("Key ideas found") instead of typing stats.
  - Sentence answers wrap onto two lines.
  - Smaller font for very long passages.
- `/aa lore`, `/aa quiz`, and an art count in `/aa status`. The Parent Panel subject picker and the report include the new modules.
- Translations stay deferred to the end of the project (enUS only, scaffold intact). There is no new saved data (schema 4).

**v0.4.0**
- **Professor Fizzwick Coppercoil**: a neutral Steamwheedle goblin teacher from Gadgetzan.
  - He appears in a guide strip with an in-game goblin model and an icon fallback.
  - About 70 original enUS lines across 16 events, randomized without repeats.
  - His mechanical parrot **Sprocket** delivers hints.
- **Faction leader cameos** (text only): Thrall for the Horde, Bolvar Fordragon for the Alliance.
  - Shown on rank-ups, exam passes, and every 5th mastery, rate-limited.
  - Neutral characters get Fizzwick only. Parents can turn cameos off.
- **Neutral re-homing.**
  - The rune forge and the Steamwheedle Archive are in Gadgetzan. Kirin Tor, Dalaran, and Khadgar references are gone.
  - A few lesson sentences now use neutral places.
- **Visual polish:**
  - Dialog frame and header plate.
  - Framed icons and a section divider.
  - A **Drill** button on every subject tile.
  - Animated reward screen: the subject icon reveal uses an AnimationGroup, with an OnUpdate fallback, and shards count up.
  - Combo meter glow and a rank-up celebration card.
  - **Reduced motion** option.
- **Sound registry.**
  - 15 events mapped to built-in SoundKits, with name and numeric fallbacks.
  - Optional custom `.ogg` overrides, tried safely and remembered when missing.
  - Mute, channel, and Important-only options.
  - `Media/Sounds/README.md` lists file names and lengths, ElevenLabs prompts, and an original narrator voice brief.
- **Subject-neutral reviews:** "Review Time" replaces "Review Runes", and review results say "still strong".
- The reward icon now matches the subject.
- SavedVariables schema 4, which adds the new settings. Migration from v0.3, v0.2, and v0.1 is automatic.

**v0.3.0**
- **Scribe's Scrolls**, subject #2: spelling, vocabulary, and typing for all three bands (15 skills),
  with Warcraft-lore sentences. It plugs into the registry, so the placement trial, reviews, exam,
  rewards, and report all work for it unchanged.
- The problem screen gained **text answers** (case/space-tolerant, exact letters) and a **typing mode**
  (accuracy + WPM, best WPM saved). Long button answers use a 2-column layout, and long passages
  shrink their font.
- Engine: modules can supply their own answer checker. `Check` receives the elapsed time and tier from
  the session (the UI clock stays in the UI layer). Problems can be button-only or typing-only.
- Parent Panel **subject picker**, and an Export **scope** button (one subject or All subjects).
- Subject-specific trial/exam wording (the Archivist instead of the Forgemaster).
- SavedVariables schema 3 (migration from v0.2 and v0.1 is automatic, and nothing existing moves).
- `/aa scribe`; `/aa forge` now also switches back to Rune Forger.

**v0.2.0**
- Module registry (`Core/Modules.lua`). Rune Forger is the first registered module, and the hub
  tiles, lesson screens, trial, review, and report are all module-agnostic.
- The Forgemaster's Trial: an adaptive placement test that sets starting tiers. It runs on first
  entry and can be re-run from the Parent Panel. Parents can override each skill's start tier.
- Review Runes: spaced review at 1, 3, and 7 days, with "fading" (no penalties), a hub button,
  a login reminder, Practice suggestions, and a parent ON/OFF switch.
- Rune Mastery Exam (post-test). The report compares placement and exam per band and per skill.
- Localized the hub's "Quick Drill" and "Choose your lesson", and added all new strings to enUS.
- SavedVariables schema 2, with automatic migration from v0.1 (progress, shards, PIN, and settings kept).
- New slash commands: `/aa review`, `/aa trial`, `/aa exam`.

**v0.1.0**: first test build (hub, Rune Forger, progression, Parent Panel).

## License

Azeroth Academy is released under the [MIT License](LICENSE). You are free to use, modify, and share it, as long as you keep the copyright notice and credit: "Azeroth Academy by HexorMarhetbar". Original art, sounds, and Professor Fizzwick's voice are part of the project and covered by the same license. World of Warcraft is a trademark of Blizzard Entertainment; this addon is fan-made and not affiliated with Blizzard.
