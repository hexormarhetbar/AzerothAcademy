# Fizzwick and Sprocket portraits

Since v0.5.1 the addon ships Hex's approved original posed art for Fizzwick and Sprocket.
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

### Host portraits (slots since v1.0, art pending Hex)

Three more characters have portrait slots. The files use the same two sizes as Fizzwick's poses.
**No host art ships yet.** Until it does, each slot shows a placeholder loaded from the game at
runtime: the host's subject icon in a small gold frame. The Tidehunter keeps its in-game murloc
model.

| File | Size | Who | Where it shows |
|------|------|-----|----------------|
| `zixi_portrait.tga` | 512x512 | Chronicler Zixi Inkspark (Lore Chronicles, Lore Quiz) | Full-figure slot (reserved) |
| `zixi_portrait_head.tga` | 256x256 | Zixi | Top right of the Lore Chronicles and Lore Quiz skill lists (shown at 34x34) |
| `quill_portrait.tga` | 512x512 | Archivist Quill (Scribe's Scrolls) | Full-figure slot (reserved) |
| `quill_portrait_head.tga` | 256x256 | Quill | Top right of the Scribe's Scrolls skill list (34x34) |
| `tidehunter_portrait.tga` | 512x512 | The Murloc Tidehunter | Full-figure slot (reserved) |
| `tidehunter_portrait_head.tga` | 256x256 | The Tidehunter | The boss slot in Murloc Boarding Party (76x76) |

Source PNGs go in `Media/Art/src/` as `zixi_portrait.png`, `quill_portrait.png` and
`tidehunter_portrait.png`. `tools/convert_art.sh` turns them into both sizes and adds them to the
manifest, exactly like the poses. Fallback: head crop, then full figure, then the placeholder.

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
supply and keeps every TGA already in `Media/Art`, so you can add just the three host portraits
without the Fizzwick sources. To remove a file, delete its TGA and run the script again.
