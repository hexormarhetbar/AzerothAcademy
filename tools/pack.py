#!/usr/bin/env python3
"""Build the installable addon zip:  python3 tools/pack.py ../AzerothAcademy-vX.Y.Z.zip

Packs this folder as AzerothAcademy/... and leaves out dev-only files (tests, source
art, git files, lint config). Audio (.ogg) and in-game textures (.blp/.tga) ship.
Write the zip OUTSIDE the repo (zips are git-ignored anyway).
"""
import os, sys, zipfile, stat

src = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = os.path.abspath(sys.argv[1])
SKIP_DIRS = {'tests', 'src', '__pycache__', '.git', '.github'}
SKIP_FILES = {'.luacheckrc', '.gitignore', '.gitattributes', '.DS_Store'}
SKIP_EXT = ('.png', '.pyc', '.bak', '.zip', '.mp3', '.wav')
n = 0
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for root, dirs, files in os.walk(src):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
        for f in sorted(files):
            if f in SKIP_FILES or f.endswith(SKIP_EXT):
                continue
            p = os.path.join(root, f)
            if os.path.abspath(p) == out:
                continue
            arc = os.path.join('AzerothAcademy', os.path.relpath(p, src))
            zi = zipfile.ZipInfo.from_file(p, arc)
            zi.compress_type = zipfile.ZIP_DEFLATED
            mode = 0o755 if f.endswith(('.sh', '.py')) else 0o644
            zi.external_attr = (stat.S_IFREG | mode) << 16
            with open(p, 'rb') as fh:
                z.writestr(zi, fh.read(), compresslevel=9)
            n += 1
print(out, n, 'files', os.path.getsize(out), 'bytes')
