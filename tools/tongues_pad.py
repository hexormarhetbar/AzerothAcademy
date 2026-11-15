#!/usr/bin/env python3
"""v1.2.3: re-master the World Tongues clips with breathing room, from the v1.2.2 masters (no regeneration).
Every clip gets LEAD s of silence before and TAIL s after the speech; single kana (ja_k_*) are also slowed to
KANA_TEMPO (pitch and formants kept). Run on the v1.2.2 clips, not on already padded ones (the slow-down would
stack):   python3 tools/tongues_pad.py V122_DIR Media/Sounds/Tongues
Then update the seconds column of tools/tongues_clips.tsv (done here) and run tools/gen_tongues_clips.py."""
import os, subprocess, sys
LEAD, TAIL, KANA_TEMPO = 0.2, 0.15, 0.85
src, dst = sys.argv[1], sys.argv[2]
here = os.path.dirname(os.path.abspath(__file__))
tsv = os.path.join(here, "tongues_clips.tsv")
rows = [l.rstrip("\n").split("\t") for l in open(tsv, encoding="utf8")]
out = []
for r in rows:
    if r[0].startswith("#") or len(r) < 4:
        out.append(r); continue
    clip = r[0]
    cmd = [sys.executable, os.path.join(here, "master_audio.py"), os.path.join(src, clip + ".ogg"),
           os.path.join(dst, clip + ".ogg"), "--lead", str(LEAD), "--tail", str(TAIL)]
    if clip.startswith("ja_k_"): cmd += ["--tempo", str(KANA_TEMPO)]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)
    dur = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
                                os.path.join(dst, clip + ".ogg")], capture_output=True, text=True, check=True).stdout)
    r[3] = str(round(dur, 2)); out.append(r)
with open(tsv, "w", encoding="utf8") as f:
    for r in out: f.write("\t".join(r) + "\n")
print("re-mastered", sum(1 for r in out if not r[0].startswith("#") and len(r) >= 4), "clips")
