#!/usr/bin/env python3
"""Machine-translate Locales/enUS.lua into the release locales (dev tool, offline).

Usage:  python3 tools/translate_locales.py [lang ...]     (default: all)
Needs:  pip install argostranslate opencc-python-reimplemented transformers sentencepiece torch,
        the Argos en->de/es/it/ru models, and facebook/nllb-200-distilled-600M (used for fr, pt, ko,
        zh: Argos output there was not usable). Translations are cached in $AA_TRANSLATE_CACHE (default
        /workspace/tmp/translate-cache) so a rerun only translates new or changed strings.

Every output string is MACHINE QUALITY and needs native-speaker review. Placeholders
(%d %s ...), color codes, textures, slash commands and character/place names are protected;
any translation that loses or reorders a format placeholder is dropped, so that key falls back
to English at runtime instead of breaking string.format.
"""
import json, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.environ.get("AA_TRANSLATE_CACHE", "/workspace/tmp/translate-cache")
# WoW locale -> (argos code, file, extra locales sharing the table, display name)
LOCALES = {
    "deDE": ("de", "deDE", [], "German"),
    "frFR": ("nllb:fra_Latn", "frFR", [], "French"),
    "esES": ("es", "esES", ["esMX"], "Spanish (esES; esMX uses the same table)"),
    "ptBR": ("nllb:por_Latn", "ptBR", [], "Portuguese (Brazil)"),
    "itIT": ("it", "itIT", [], "Italian"),
    "ruRU": ("ru", "ruRU", [], "Russian"),
    "koKR": ("nllb:kor_Hang", "koKR", [], "Korean"),
    "zhCN": ("nllb:zho_Hans", "zhCN", [], "Simplified Chinese"),
    "zhTW": ("nllb:zho_Hans", "zhTW", [], "Traditional Chinese (Simplified output converted with OpenCC s2twp)"),
}

class NLLB:
    def __init__(self, lang):
        import torch
        from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
        torch.set_num_threads(int(os.environ.get("AA_THREADS", "8")))
        name = "facebook/nllb-200-distilled-600M"
        self.lang = lang
        self.tok = AutoTokenizer.from_pretrained(name, src_lang="eng_Latn")
        self.model = AutoModelForSeq2SeqLM.from_pretrained(name)
    def sentences(self, s):
        return [x for x in re.split(r"(?<=[.!?])\s+", s) if x.strip()]
    def batch(self, items):
        import torch
        out = []
        with torch.no_grad():
            for i in range(0, len(items), 24):
                chunk = items[i:i + 24]
                b = self.tok(chunk, return_tensors="pt", padding=True)
                g = self.model.generate(**b, forced_bos_token_id=self.tok.convert_tokens_to_ids(self.lang),
                                        max_new_tokens=160, num_beams=2)
                out += self.tok.batch_decode(g, skip_special_tokens=True)
                print(self.lang, i + len(chunk), "/", len(items), flush=True)
        return out
    def translate_many(self, strings):
        # sentence cache saved after every batch, so an interrupted run resumes where it stopped
        spath = os.path.join(CACHE, "nllb-%s-sentences.json" % self.lang)
        done = json.load(open(spath, encoding="utf-8")) if os.path.exists(spath) else {}
        sents = sorted({x for s in strings for x in self.sentences(s)} - set(done), key=len)
        for i in range(0, len(sents), 96):
            chunk = sents[i:i + 96]
            done.update(zip(chunk, self.batch(chunk)))
            json.dump(done, open(spath, "w", encoding="utf-8"), ensure_ascii=False)
            print(self.lang, "sentences", min(i + 96, len(sents)), "/", len(sents), flush=True)
        joiner = "" if self.lang.startswith("zho") else " "
        return {s: joiner.join(done[x] for x in self.sentences(s)) for s in strings}
# Kept in English on purpose: names, the addon title, and keys whose text must match game data.
KEEP_ENGLISH = {"ADDON_TITLE", "FZ_NAME", "FZ_PARROT", "HOST_ZIXI", "HOST_QUILL", "LORE_CAMEO_THRALL", "LORE_CAMEO_MAGNI"}
NAMES = ["Zixi Inkspark", "Tamsin Quillfeather", "Magni Bronzebeard", "Thunder Bluff", "Booty Bay", "Steamwheedle",
         "Fizzwick", "Sprocket", "Zixi", "Quill", "Thrall", "Magni", "Gadgetzan", "Azeroth", "Stormwind", "Ironforge",
         "Orgrimmar", "Ratchet", "Undercity", "Darnassus", "Silvermoon", "Exodar", "Tanaris", "Kalimdor",
         "Eastern Kingdoms", "Durotar", "Elwynn", "Barrens", "Nixa", "Boltby", "WoW", "SavedVariables", "WPM"]
SUBCMDS = "drill|review|trial|forge|scribe|lore|nature|gnomish|library|mechanics|journal|blueprints|passport|deck|quiz|murloc|minimap|flight|voice|duel|parent|help|status|exam|stamps|cards|tactics|research"
FMT = r"%[-+ #0]*\d*(?:\.\d+)?[dsfixX%]"
PROTECT = re.compile("(" + "|".join([
    r"\|T[^|]*\|t", r"\|c[0-9a-fA-F]{8}", r"\|r", r"\|n", r"\n",
    r"/aa(?: (?:" + SUBCMDS + r"))?(?: (?:\[[^\]]*\]|on\|off|\[name\]))?",
    FMT,
] + [re.escape(n) for n in NAMES]) + ")")

def lua_dump():
    code = r'''
local ns = { Env = {} }
assert(loadfile("Locales/enUS.lua"))("AzerothAcademy", ns)
local function esc(s) return (s:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\t", "\\t")) end
for k, v in pairs(ns.LocaleData.enUS) do io.write(k, "\t", esc(v), "\n") end'''
    out = subprocess.run(["lua", "-e", code], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    vals = {}
    for line in out.splitlines():
        k, v = line.split("\t", 1)
        vals[k] = v.replace("\\t", "\t").replace("\\n", "\n").replace("\\\\", "\\")
    order = re.findall(r"\b([A-Z][A-Z0-9_]*)\s*=\s*[\"\[]", open(os.path.join(ROOT, "Locales/enUS.lua"), encoding="utf-8").read())
    seen, keys = set(), []
    for k in order + sorted(vals):
        if k in vals and k not in seen: seen.add(k); keys.append(k)
    return keys, vals

def fmt_seq(s): return [m for m in re.findall(FMT, s)]

def protect(s):
    toks = []
    def rep(m):
        toks.append(m.group(0)); return " XPH%d " % (len(toks) - 1) if m.group(0) == "\n" else "XPH%d" % (len(toks) - 1)
    return PROTECT.sub(rep, s), toks

def restore(t, toks):
    found = [int(x) for x in re.findall(r"XPH(\d+)", t)]
    if sorted(found) != list(range(len(toks))): return None
    def back(m):
        tok = toks[int(m.group(1))]
        return tok
    for i, tok in enumerate(toks):
        if tok == "\n": t = re.sub(r"\s*XPH%d(?!\d)\s*" % i, "\x01", t)
    return re.sub(r"XPH(\d+)", back, t).replace("\x01", "\n")

def valid(en, tr):
    if tr is None or not tr.strip(): return False
    if fmt_seq(en) != fmt_seq(tr): return False
    for code in (r"\|c[0-9a-fA-F]{8}", r"\|r", r"\|T"):
        if len(re.findall(code, en)) != len(re.findall(code, tr)): return False
    if len(tr) > max(40, len(en) * 3): return False      # runaway output
    if re.search(r"(.{2,6})\1{4,}", tr): return False     # repetition loops
    return True

def overrides():
    cols = ["deDE", "frFR", "esES", "ptBR", "itIT", "ruRU", "koKR", "zhTW", "zhCN"]
    out = {c: {} for c in cols}
    for line in open(os.path.join(ROOT, "tools", "locale_overrides.tsv"), encoding="utf-8"):
        if line.startswith("#") or not line.strip(): continue
        parts = line.rstrip("\n").split("\t")
        assert len(parts) == 10, parts[0]
        for c, v in zip(cols, parts[1:]): out[c][parts[0]] = v
    return out

def main():
    ov = overrides()
    want = sys.argv[1:] or list(LOCALES)
    keys, vals = lua_dump()
    os.makedirs(CACHE, exist_ok=True)
    report = {}
    for loc in want:
        code, fname, extra, title = LOCALES[loc]
        cpath = os.path.join(CACHE, code.replace(":", "-") + ".json")
        cache = json.load(open(cpath, encoding="utf-8")) if os.path.exists(cpath) else {}
        conv = None
        if loc == "zhTW":
            import opencc; conv = opencc.OpenCC("s2twp")
        if code.startswith("nllb:"):
            todo = []
            for k in keys:
                en = vals[k]
                if k in KEEP_ENGLISH or not re.search(r"[A-Za-z]{2}", PROTECT.sub("", en)): continue
                prot, _ = protect(en)
                if prot not in cache: todo.append(prot)
            if todo:
                cache.update(NLLB(code[5:]).translate_many(sorted(set(todo))))
                json.dump(cache, open(cpath, "w", encoding="utf-8"), ensure_ascii=False)
            tr = None
        else:
            import argostranslate.translate as at
            tr = at.get_translation_from_codes("en", code)
        out, dropped, kept = {}, [], 0
        for i, k in enumerate(keys):
            en = vals[k]
            if k in KEEP_ENGLISH or not re.search(r"[A-Za-z]{2}", PROTECT.sub("", en)):
                kept += 1; continue
            prot, toks = protect(en)
            if prot in cache:
                raw = cache[prot]
            else:
                raw = tr.translate(prot)
                cache[prot] = raw
                if len(cache) % 25 == 0:
                    json.dump(cache, open(cpath, "w", encoding="utf-8"), ensure_ascii=False)
                    print(loc, i, "/", len(keys), flush=True)
            res = restore(raw, toks)
            if res is not None:
                res = re.sub(r" +([!?.,:;])", r"\1", res) if code not in ("fr",) else res
                if en.startswith("  ") : res = "  " + res.lstrip()
                if loc in ("zhCN", "zhTW"):
                    # full-width punctuation between CJK text (placeholders and numbers keep ASCII)
                    res = re.sub(r"(?<=[\u4e00-\u9fff%sd0-9）])\s*([.!?,:;])\s*(?=[\u4e00-\u9fff%（]|$)",
                                 lambda m: {".": "。", "!": "！", "?": "？", ",": "，", ":": "：", ";": "；"}[m.group(1)], res)
                if conv: res = conv.convert(res)
            if res is not None and loc in ("zhCN", "zhTW", "koKR", "ruRU"):
                stray = set(re.findall(r"[A-Za-z]{3,}", PROTECT.sub(" ", res))) - set(re.findall(r"[A-Za-z]{3,}", en))
                if stray: res = None
            if k in ov[loc]: res = ov[loc][k]
            if valid(en, res): out[k] = res
            else: dropped.append(k)
        json.dump(cache, open(cpath, "w", encoding="utf-8"), ensure_ascii=False)
        write(loc, fname, extra, title, keys, out)
        report[loc] = (len(out), len(dropped), kept)
        print(loc, "translated", len(out), "dropped(fallback to English)", len(dropped), "kept English", kept, flush=True)
    return report

def luastr(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'

def write(loc, fname, extra, title, keys, out):
    cond = " or ".join('ns.WantLocale("%s")' % l for l in [loc] + extra)
    lines = [
        "-- %s (%s). MACHINE TRANSLATION of enUS (Argos Translate, offline), generated by" % (title, loc),
        "-- tools/translate_locales.py. NEEDS NATIVE-SPEAKER REVIEW before a final release.",
        "-- Keys missing here fall back to English. Keep %d / %s placeholders in the same order.",
        "-- Fizzwick's voice clips stay English in every locale.",
        "local _, ns = ...",
        "if not (%s) then return end" % cond,
        "ns.LocaleData = ns.LocaleData or {}",
        "local T = {",
    ]
    for k in keys:
        if k in out: lines.append("  %s = %s," % (k, luastr(out[k])))
    lines.append("}")
    lines.append("ns.LocaleData.%s = T" % loc)
    for l in extra: lines.append("ns.LocaleData.%s = T" % l)
    open(os.path.join(ROOT, "Locales", fname + ".lua"), "w", encoding="utf-8").write("\n".join(lines) + "\n")

if __name__ == "__main__":
    main()
