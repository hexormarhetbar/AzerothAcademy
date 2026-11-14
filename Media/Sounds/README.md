# Sounds and voice for Azeroth Academy

Since v0.8.0 Azeroth Academy ships **original** audio, generated for this addon with
ElevenLabs (sound effects and a designed voice). None of it is extracted from, copied
from or modelled on the game. Every sound effect also keeps a built-in game SoundKit
fallback, played by ID at runtime, so the addon still sounds right if a file is missing.

The addon tries `Interface\AddOns\AzerothAcademy\Media\Sounds\<event>.ogg` first. If the
file is missing or will not play, it falls back to the built-in SoundKit and does not try
that file again until the next `/reload`. You can replace any file with your own.

- **Format:** Ogg Vorbis (`.ogg`), mono, 44.1 kHz, quality 4. Silence trimmed, loudness
  matched to about -16 LUFS with peaks at or below -1.5 dBFS, so no sound startles a young player.
  (Very short clicks measure quieter on a loudness meter; they are peak-limited instead.)
- **New files:** the game only finds files that existed when it started. After adding
  or replacing files, restart the game client; `/reload` is not enough.
- **Parent Panel controls:**
  - Sound ON/OFF (mute: silences effects **and** voice).
  - Channel: Effects, Master, Dialog or Ambience. This picks which of the player's
    volume sliders applies, to effects and voice alike.
  - "Important only", which plays just answers, rewards and rank-ups.
  - Custom sound files ON/OFF (OFF = built-in SoundKits only).
  - Fizzwick's voice ON/OFF (also `/aa voice on|off`).
  - The addon never changes the player's volume settings.
- **Licensing:** generated on the project owner's ElevenLabs account for this free addon.
  If you regenerate or add sounds, check that your own plan allows that use.

| File | Plays when | Length | Built-in fallback (SoundKit) |
|---|---|---|---|
| `click.ogg` | Any button press | 0.1-0.2 s | IG_MAINMENU_OPTION_CHECKBOX_ON (856) |
| `open.ogg` | The Academy window opens | 0.4-0.6 s | IG_SPELLBOOK_OPEN (829) |
| `close.ogg` | The Academy window closes | 0.3-0.5 s | IG_SPELLBOOK_CLOSE (830) |
| `correct.ogg` | Right answer | 0.5-0.8 s | IG_QUEST_LIST_COMPLETE (878) |
| `wrong.ogg` | Wrong answer (must be gentle) | 0.3-0.5 s | IG_MAINMENU_OPTION_CHECKBOX_OFF (857) |
| `combo.ogg` | A streak of 3 or more right answers | 0.5-0.8 s | LOOT_WINDOW_COIN_SOUND (120) |
| `overcharge.ogg` | A streak of 5 (double shards) | 1.0-1.5 s | UI_EPICLOOT_TOAST (31578), then 888 |
| `forge.ogg` | A Rune Forger round starts | 0.6-1.0 s | PUT_DOWN_GEMS (1204), then IG_ABILITY_OPEN (834) |
| `scroll.ogg` | A Scribe's Scrolls round starts | 0.6-1.0 s | IG_ABILITY_PAGE_TURN (836) |
| `reward.ogg` | A tier is mastered, or a trial is finished | 1.5-2.5 s | LEVELUPSOUND (888), then 878 |
| `rankup.ogg` | Academy rank goes up | 2.0-3.0 s | LEVELUPSOUND (888), then 31578 |
| `exampass.ogg` | A Mastery Exam is passed | 2.5-3.5 s | UI_WORLDQUEST_COMPLETE (73277), then 888 |
| `chirp.ogg` | Professor Fizzwick greets you | 0.3-0.6 s | TELL_MESSAGE (3081) |
| `hint.ogg` | Sprocket the parrot gives a hint | 0.4-0.7 s | MAP_PING (3175) |
| `cameo.ogg` | A faction leader card appears | 1.0-1.5 s | READY_CHECK (8960) |
| `splash.ogg` | Murloc Boarding Party: a murloc goes overboard | 0.5-0.9 s | kit 1097 (large water splash), then 1096 |
| `cannon.ogg` | Murloc Boarding Party: the broadside fires | 0.8-1.4 s | kit 1400 (cannon blast), then 3641 |
| `gurgle.ogg` | Murloc Boarding Party: murlocs climb aboard, the Tidehunter appears | 0.4-0.8 s | kit 416 (murloc "mrglglgl"), then 1109 |
| `flight.ogg` | The In-Flight Lesson pop-up appears on a flight path | 0.5-0.9 s | TELL_MESSAGE (3081) |
| `page.ogg` | The Field Journal opens or turns to another band (v0.9) | 0.4-0.8 s | IG_ABILITY_PAGE_TURN (836) |
| `specimen.ogg` | A new specimen is collected for the Field Journal (v0.9) | 0.7-1.2 s | IG_QUEST_LIST_COMPLETE (878) |
| `countdown.ogg` | Each beat of the Duel of Wits 3-2-1 countdown (v0.10) | 0.5-0.8 s | RAID_WARNING (8959) |
| `duelwin.ogg` | You win a Duel of Wits race (v0.10) | 1.2-2.0 s | UI_EPICLOOT_TOAST (31578), LEVELUPSOUND (888) |
| `gears.ogg` | A Gnomish Engineering round starts, or a new blueprint is collected (v0.11) | 0.6-1.2 s | PUT_DOWN_GEMS (1204), then IG_ABILITY_OPEN (834) |
| `stamp.ogg` | A new stamp is added to the Library Passport (v0.12) | 0.5-0.9 s | IG_ABILITY_PAGE_TURN (836), then IG_QUEST_LIST_COMPLETE (878) |

## Sound-effect briefs

The shipped files were made with the ElevenLabs *Sound Effects* generator
(`eleven_text_to_sound_v2`), one generation per file, with prompts adapted from these
briefs plus a "small cartoony goblin-workshop gadget" flavour. Every prompt asked for an
original sound and none imitated any game's audio.

- **click.ogg:** "Soft wooden-and-brass toggle click, tiny mechanical tick, warm and friendly, very short, no reverb tail."
- **open.ogg:** "Small brass latch unclips and a leather-bound book creaks open, light whoosh of paper, cozy workshop feel."
- **close.ogg:** "Leather book gently closes with a soft thump and a tiny brass latch click."
- **correct.ogg:** "Bright cheerful two-note chime on a glockenspiel with a sparkle shimmer, rising pitch, happy and rewarding, child-friendly."
- **wrong.ogg:** "Very gentle low wooden 'bonk' with a soft descending two-note marimba, kind and playful, not a buzzer, not sad."
- **combo.ogg:** "Three gold coins clinking into a small brass bowl, quick rising sparkle, playful and lucky."
- **overcharge.ogg:** "Whimsical steam-powered gadget revs up, rising whistle, crackle of harmless sparks, ending in a triumphant ding and coin shower, cartoon style."
- **forge.ogg:** "Small hammer taps a glowing rune on an anvil twice with a magical hum and a soft sparkle, light and friendly, not heavy metal."
- **scroll.ogg:** "Parchment scroll unrolls with a soft paper flutter and a quill scratch flourish, gentle magical twinkle."
- **reward.ogg:** "Short joyful fanfare on bells and plucked strings with a sparkle swell, celebratory and warm, suitable for kids."
- **rankup.ogg:** "Triumphant but cute orchestral flourish, brass and bells rising, with confetti-like sparkles and a cheerful cymbal swell, magical school graduation feel."
- **exampass.ogg:** "Grand celebratory fanfare with trumpets, bells and a choir 'ahh', ending in a bright shimmering chord, proud and happy, family-friendly."
- **chirp.ogg:** "Tiny clockwork parrot chirp, two quick metallic whistles with a gear whirr, cute and curious."
- **hint.ogg:** "Mechanical parrot squawk made of small whistles and clicks, playful, ends with a soft bell ping, cartoon style."
- **cameo.ogg:** "Distant noble horn call, short and warm, followed by a soft magical shimmer, heroic but gentle, no specific faction theme."
- **splash.ogg:** "Cartoon splash of a small creature landing in the sea, bubbly plop and spray, funny and light, not violent."
- **cannon.ogg:** "Friendly cartoon ship cannon volley, three soft booms in quick succession with a puff of smoke and a cheerful whistle, no explosion debris."
- **gurgle.ogg:** "Original silly fish-creature gurgle, wet bubbly warble rising in pitch, comic and cute, not a copy of any game creature."
- **flight.ogg:** "Friendly little airship bell and propeller whirr, a bright two-note 'ding-ding' inviting you to a lesson, cartoon goblin gadget."
- **gears.ogg:** "Small clockwork gears whirring and clicking into place, ending with a tiny cheerful bell ding, cartoon gadget workshop, short and friendly."
- **stamp.ogg (v0.12):** "A rubber stamp thunks onto a paper passport page with a soft ink press, followed by a tiny bright sparkle chime, cozy library, short and friendly"
- **page.ogg:** "A single soft paper page turning in an old leather field notebook, short and crisp, gentle, no music."
- **specimen.ogg:** "Cheerful nature discovery chime: a bright magical sparkle with a tiny leafy rustle and a happy two-note marimba ding, cartoon, short."
- **countdown.ogg (v0.10):** "Single soft wooden clock tick with a gentle bright chime, friendly game countdown beep, clean, no voice." (0.8 s requested)
- **duelwin.ogg (v0.10):** "Short cheerful fantasy victory fanfare, sparkling bells and small brass flourish, kid-friendly game win jingle, no voice." (2.5 s requested)

## Professor Fizzwick's voice (v0.8.0)

Some of Fizzwick's lines are spoken aloud by an **original designed voice**.

- **Voice:** "Professor Fizzwick Coppercoil", made with ElevenLabs Voice Design and saved in
  the project owner's voice library. **voice_id: `6cM4EfZ7l0vIR7bts4fm`**. Lines were
  rendered with the `eleven_v3` model.
- **Ethics rule:** this voice was designed from a text description only. It is not a clone of,
  and does not imitate, any real actor, any Blizzard character voice or any in-game goblin.
  No game audio or performer recording was used as a reference. Keep it that way if you add lines.
- **When it plays:** a clip plays only together with its exact text line in Fizzwick's bubble,
  so the words on screen always match the voice. The first time an event with a recording
  happens in a session, the recorded line is picked. After that the normal shuffle decides,
  and only some lines have audio. One clip at a time, never overlapping: at least 6 s
  between clips, and the same clip at most once every 45 s. Rank-up and Mastered may cut
  off a clip that is still playing. "Goodbye" plays only after a visit of 20 s or more,
  and never when the window hides for combat.
- **Off switch:** Parent Panel "Fizzwick's voice", `/aa voice off`, or Sound OFF (mutes all).
  The voice uses the same channel/volume slider as the sound effects.

| File (`VO/`) | Text (bubble line) | Plays on |
|---|---|---|
| `VO/greet.ogg` | "Welcome back to the Knowledge Exchange! Your brain is my favorite investment." (`FZ_GREET_1`) | Hub greeting |
| `VO/roundstart.ogg` | "Let's crank up the learning engine!" (`FZ_ROUNDSTART_2`) | A round starts |
| `VO/correct.ogg` | "Now THAT'S a return on investment!" (`FZ_CORRECT_1`) | Right answer |
| `VO/wrong.ogg` | "Not quite, but that's how learning works. Try again!" (`FZ_WRONG_1`) | Wrong answer |
| `VO/hint.ogg` | "Squawk! Hint, hint!" | Any parrot hint |
| `VO/combo.ogg` | "A combo! Your brain is on a winning streak!" (`FZ_COMBO_1`) | Streak |
| `VO/rankup.ogg` | "A new rank! Your knowledge is worth more than ever!" (`FZ_RANKUP_1`) | Rank up |
| `VO/mastered.ogg` | "Mastered! That skill is yours forever, partner!" (`FZ_MASTERED_1`) | Tier mastered |
| `VO/flight.ogg` | "Sky time is brain time! Five quick questions before we land?" (`FZ_FLIGHTSTART_4`) | In-Flight Lesson pop-up |
| `VO/landing.ogg` | "We landed! Finish whenever you like. Nothing is lost." (`FZ_FLIGHTLAND_1`) | Landing mid-lesson |
| `VO/murloc.ogg` | "All aboard! Murlocs love free rides, so let's show them the water." (`FZ_BOARDSTART_1`) | Murloc Boarding Party starts |
| `VO/bye.ogg` | "Class dismissed! Great work today, partner. See you soon!" (`FZ_BYE_1`) | Closing the Academy |
| `VO/nat_start.ogg` | "Grab your field journal! Science time in the wild!" (`FZ_NATSTART_1`) | A Naturalist round starts (v0.9) |
| `VO/nat_correct.ogg` | "Sharp eyes! That's real science, partner!" (`FZ_NATCORRECT_1`) | Naturalist right answer (v0.9) |
| `VO/nat_specimen.ogg` | "A new specimen for your journal! Ooh, look at that!" (`FZ_NATSPECIMEN_1`) | New Field Journal specimen (v0.9) |
| `VO/nat_journal.ogg` | "Welcome to your field journal. You earned every page!" (`FZ_NATJOURNAL_1`) | Opening the Field Journal (v0.9) |
| `VO/nat_flight.ogg` | "Look down! Every zone below is a habitat. Let's study!" (`FZ_NATFLIGHT_1`) | In-flight Naturalist round (v0.9) |
| `VO/duel_invite.ogg` | "A challenger appears! Ready for a duel of wits?" (`FZ_DUELINVITE_1`) | A Duel of Wits challenge arrives (v0.10) |
| `VO/duel_start.ogg` | "Brains ready? Let the duel of wits begin!" (`FZ_DUELSTART_1`) | A duel race starts (v0.10) |
| `VO/duel_win.ogg` | "Victory! Your brain won that duel fair and square!" (`FZ_DUELWIN_1`) | You won a duel (v0.10) |
| `VO/duel_done.ogg` | "Great race! Every duel makes your brain stronger." (`FZ_DUELDONE_1`) | A duel ends and you did not win (v0.10) |
| `VO/ge_start.ogg` | "Goggles down, wrenches up! Boltby is ready for orders." (`FZ_GESTART_1`) | A Gnomish Engineering round starts (v0.11) |
| `VO/ge_blueprint.ogg` | "A new blueprint! Into the Binder it goes!" (`FZ_GEBLUEPRINT_1`) | New Blueprint Binder page (v0.11) |
| `VO/lib_start.ogg` | "Shh, library voices! Let's go find some answers." (`FZ_LIBSTART_1`) | A Librarian Quests round starts (v0.12) |
| `VO/lib_stamp.ogg` | "A new stamp for your Library Passport! Well researched!" (`FZ_LIBSTAMP_1`) | New Library Passport stamp (v0.12) |

## Voice design brief (original)

The brief below is what the voice was designed from.


Use it if you ever record or design more **original** narration for Fizzwick.

**Do not imitate, clone or reference any Blizzard voice actor, any in-game goblin
voice, or any other real performer.** Do not upload game audio as a reference. The
voice must be a new character.

- **Character:** Professor Fizzwick Coppercoil runs a "knowledge exchange" school in a desert
  trading town. He is a fast-talking inventor and teacher who treats learning like
  a smart investment. He is mischievous but always kind, he never mocks a mistake,
  and he is genuinely delighted when a child gets something right.
- **Voice design prompt:** "An original, energetic cartoon narrator for a children's learning game: a small,
  quick-witted inventor-teacher. Mid-to-high pitched male voice, slightly nasal
  and raspy, like an excited street merchant who is secretly a big softie.
  Fast but crystal-clear diction, playful rising intonation, light comic
  timing, warm smile in every line. Neutral, non-regional accent. Clean studio
  recording, no background noise."
- **Delivery rules:**
  - About 170-185 words per minute. Slow down to about 140 for hints, so a 5-year-old can follow.
  - Celebrations go big and bouncy ("Now THAT'S a return on investment!").
  - Encouragement after a wrong answer is soft and reassuring, never sarcastic.
  - Keep each line under 6 seconds.
- **Test lines:**
  - "Welcome back to the Knowledge Exchange! Your brain is my favorite investment."
  - "Not quite, but that's how learning works. Try again!"
  - "OVERCHARGE! The gauges are off the charts!"
- **Parrot (Sprocket):** in v0.8 the hint clip is Fizzwick himself playing parrot ("Squawk! Hint, hint!"). Later: a separate original voice, or processed sound effects: short whistles, clicks
  and one-word squawks ("Hint! Squawk!"). Not a recognizable parrot from any media.
- **Faction leaders:** no voice, ever. Their cameo cards stay text only, so no real or game
  performer is imitated.
