#!/usr/bin/env python3
"""Build the bundled subset fonts in Media/Fonts (dev tool, v1.1).

Usage:  python3 tools/build_fonts.py [--src DIR]
Needs:  pip install fonttools; the Google Fonts variable TTFs NotoSansJP[wght].ttf,
        NotoSansKR[wght].ttf, NotoSansSC[wght].ttf, NotoSansTC[wght].ttf in DIR (default
        /workspace/fonts, saved as NotoSansJP.ttf etc.) from https://github.com/google/fonts/tree/main/ofl

Each output is a static Medium (wght 500) instance of one Noto Sans regional font, cut down to
only the characters the addon can show: basic Latin + Latin-1 + Latin Extended-A, punctuation,
every kana, plus every character found in the World Tongues data and in the locale files that
font serves. Re-run after changing any locale or course text; tests/harness.lua fails if a
shown character is missing. License: SIL Open Font License 1.1 (Media/Fonts/OFL.txt). The
family is renamed (OFL: modified versions are distributed under a different name).
"""
import argparse, glob, io, os, shutil, sys
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools import subset

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Media", "Fonts")
LATIN_LOCALES = ["enUS", "deDE", "frFR", "esES", "ptBR", "itIT", "ruRU"]
FONTS = {  # output -> (source, locales whose strings it must cover)
    "AzAcadSans-JP.ttf": ("NotoSansJP.ttf", LATIN_LOCALES),
    "AzAcadSans-KR.ttf": ("NotoSansKR.ttf", ["enUS", "koKR"]),
    "AzAcadSans-SC.ttf": ("NotoSansSC.ttf", ["enUS", "zhCN"]),
    "AzAcadSans-TC.ttf": ("NotoSansTC.ttf", ["enUS", "zhTW"]),
}
COURSE_FILES = ["Core/TonguesData.lua", "Core/TonguesGen.lua", "Locales/Init.lua"]

def chars_of(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return {ord(c) for c in f.read() if ord(c) >= 0x20}

def base():
    s = set(range(0x20, 0x7F)) | set(range(0xA0, 0x180))
    s |= set(range(0x2010, 0x2028)) | {0x2030, 0x2039, 0x203A, 0x2190, 0x2192, 0x2026, 0x00B7, 0x30FB}
    s |= set(range(0x3000, 0x3040)) | set(range(0x3040, 0x3100)) | set(range(0xFF01, 0xFF5F))
    return s

def build(src_dir):
    os.makedirs(OUT, exist_ok=True)
    course = set()
    for p in COURSE_FILES: course |= chars_of(p)
    report, coverage = [], []
    for out, (src, locales) in FONTS.items():
        want = base() | course
        for loc in locales: want |= chars_of("Locales/%s.lua" % loc)
        if out.endswith("JP.ttf"): want |= set(range(0x400, 0x460))
        font = TTFont(os.path.join(src_dir, src))
        if "fvar" in font: font = instancer.instantiateVariableFont(font, {"wght": 500})
        cmap = font.getBestCmap()
        used = set(course)
        for loc in locales: used |= chars_of("Locales/%s.lua" % loc)
        missing = sorted(c for c in used if c not in cmap and c > 0x7E)
        opts = subset.Options()
        opts.layout_features = ["kern", "liga", "ccmp", "locl", "vert"]
        opts.hinting = False
        opts.name_IDs = ["*"]
        opts.notdef_outline = True
        sub = subset.Subsetter(opts)
        sub.populate(unicodes=[c for c in want if c in cmap])
        sub.subset(font)
        fam = "AzAcad Sans " + out.split("-")[1][:2]
        for rec in font["name"].names:
            if rec.nameID in (1, 4, 16): rec.string = fam if rec.nameID != 4 else fam + " Medium"
            elif rec.nameID == 6: rec.string = fam.replace(" ", "") + "-Medium"
            elif rec.nameID == 3: rec.string = fam + " Medium; subset for Azeroth Academy"
        font.save(os.path.join(OUT, out))
        covered = "".join(chr(c) for c in sorted(want) if c in cmap)
        coverage.append(out + "\t" + covered)
        size = os.path.getsize(os.path.join(OUT, out))
        report.append("%s: %d characters, %.0f KB, %d not in the source font%s" % (
            out, len([c for c in want if c in cmap]), size / 1024, len(missing),
            (" (" + "".join(chr(c) for c in missing[:20]) + ")") if missing else ""))
    # tests/harness.lua checks every shown character against this list
    with open(os.path.join(OUT, "coverage.txt"), "w", encoding="utf-8") as f: f.write("\n".join(coverage) + "\n")
    shutil.copy(os.path.join(src_dir, "OFL.txt"), os.path.join(OUT, "OFL.txt"))
    print("\n".join(report))

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="/workspace/fonts")
    build(ap.parse_args().src)
