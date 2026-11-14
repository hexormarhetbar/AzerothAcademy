# Portraits: Fizzwick, Sprocket, Zixi and Quill

Since v0.5.1 the addon ships Hex's approved original posed art for Fizzwick and Sprocket, and
since v1.0.0-rc for the hosts Zixi and Quill.
All of it is original, made for this project. No Blizzard art is extracted or included;
skill icons and the fallback goblin model are loaded from the game at runtime.

## Files

Each pose comes in two sizes:

- `<name>.tga` is the full figure at 512x512. The reward screen, trial results and the
  rank-up card use it.
- `<name>_head.tga` is a 256x256 head-and-chest crop. The guide strip and Sprocket's spot
  use it.

| Pose file | When Fizzwick shows it |
|-----------|------------------------|
| `fizzwick_greet` | Opening the hub. Also the fallback for every other pose |
| `fizzwick_talking` | Round start and instructions, trial/exam/review start, correct answers |
| `fizzwick_thinking` | Waiting while you work on a problem (Scribe's Scrolls and default idle) |
| `fizzwick_researching` | Idle in Lore Chronicles and the Lore Quiz (the Librarian) |
| `fizzwick_tinkering` | Idle in the Rune Forger (and future engineering skills) |
| `fizzwick_teaching` | Hints (with Sprocket squawking the hint line) and worked examples after a miss |
| `fizzwick_excited` | Combo and Overcharge streaks; a perfect round on the reward screen |
| `fizzwick_celebrating` | Rank up and passing a Mastery Exam |
| `fizzwick_proud` | Mastering a skill; the placement trial result |
| `fizzwick_encouraging` | Wrong answers, exam retries, fading skills; a so-so round |
| `fizzwick_surprised` | A new personal best (typing WPM) |
| `sprocket_curious` | Sprocket's resting state. Bright when a hint is available, dim in trials |
| `sprocket_squawk` | Sprocket delivering a hint |
| `fizzwick_strip` | Optional talk animation (2, 4 or 8 frames of 256x256). Not shipped |

### Host portraits: Zixi and Quill (v1.0.0-rc)

Since v1.0.0-rc the addon also ships Hex's approved original art for the two subject hosts:
**Chronicler Zixi Inkspark** (Lore Chronicles and the Lore Quiz) and **Archivist Quill**
(Scribe's Scrolls). Each pose comes in the same two sizes as Fizzwick's: `<name>.tga` at 512x512
(full figure) and `<name>_head.tga` at 256x256 (head crop, made by hand with the art).

| Pose file | When the host shows it |
|-----------|------------------------|
| `zixi_storytelling` / `quill_writing` | Signature pose: the small slot at the top right of their skill list (34x34, hover for the name) |
| `zixi_greet` / `quill_greet` | Placement trial intro (72x72, replaces the subject icon). Also the fallback for every other pose |
| `zixi_talking` / `quill_talking` | Mastery Exam intro |
| `zixi_proud` / `quill_proud` | Trial results: placement finished, or exam passed (full figure, right side; Fizzwick stands on the left) |
| `zixi_encouraging` / `quill_encouraging` | Trial results: exam not passed yet |
| `zixi_thinking` / `quill_thinking` | Trial results: a trial left before the end |

The moment-to-pose map is `Art.HOST_MOMENT` in `Core/Art.lua`. If a file is missing the host shows
`greet`, then a placeholder loaded from the game (the subject icon in a small gold frame); the large
result slot just stays hidden.

**The Murloc Tidehunter has no art slot, by Hex's decision.** It always uses the in-game murloc
model (display 1995, falling back to the murloc icon). Don't add custom murloc art.

To replace host art, put `zixi_<pose>.png` / `quill_<pose>.png` (and optionally
`<name>_head.png` crops, which are used as-is) in `Media/Art/src/` and run `tools/convert_art.sh`.

Format: 32-bit uncompressed TGA with alpha, bottom-left origin, power-of-two sizes.

**Fallbacks.** If a pose is missing, Fizzwick shows `greet`. A small slot tries the head
crop first, then the full figure. With no art at all he uses the in-game goblin model,
then an icon. The large full-figure slots just stay hidden when there's no art. If the
client can't load a file (for example after an update but before a restart), the addon
marks it missing and moves on to the next candidate.

**Reduced motion.** The poses are static images. Reduced motion skips the fade-in on the
large portraits and the optional talk strip.

`Manifest.lua` lists the files that exist, because addons can't check the disk.

## Replacing or adding art

1. Install ImageMagick (`sudo apt install imagemagick`, `brew install imagemagick`, or the
   imagemagick.org installer on Windows, then use Git Bash or WSL). For face-centered head
   crops you also need Python 3 with Pillow and numpy (`pip install pillow numpy`).
2. Put the full-figure PNGs in `Media/Art/src/`, named `fizzwick_<pose>.png`,
   `sprocket_squawk.png` and `sprocket_curious.png`. Transparent backgrounds work best.
3. From the addon folder, run `sh tools/convert_art.sh`. It writes the 512 TGAs, the 256
   head crops (via `tools/make_heads.py`) and `Manifest.lua`. Without Python, the script
   uses a `<name>_head.png` you supply, or else a simple top-center crop.
4. Restart the game. New files are only picked up after a full restart, not `/reload`.

The PNGs in `src/` aren't needed in game. Since v1.0 the script only converts the PNGs you
supply and keeps every TGA already in `Media/Art`, so you can add just the host portraits
without the Fizzwick sources. To remove a file, delete its TGA and run the script again.
