"""Voice-consistency check for World Tongues clips (local, free).
Usage: consistency.py DIR [--lang ja|es] [--json out.json]
Per clip: Resemblyzer speaker embedding (short clips are looped to 1.6 s), median f0 (pyin),
spectral centroid and MFCC mean. Flags outliers vs. the group median:
  cosine distance of embedding to the median embedding > med + 3*MAD (and > 0.15), or
  f0 more than 4 semitones from the median, or MFCC distance z > 3.5.
"""
import sys, os, json, glob, numpy as np, librosa
from resemblyzer import VoiceEncoder, preprocess_wav
args = sys.argv[1:]
d = args[0]
lang = args[args.index('--lang') + 1] if '--lang' in args else 'ja'
out = args[args.index('--json') + 1] if '--json' in args else None
enc = VoiceEncoder('cpu', verbose=False)
rows = []
for f in sorted(glob.glob(os.path.join(d, lang + '_*.ogg'))):
    y, sr = librosa.load(f, sr=16000, mono=True)
    yt, _ = librosa.effects.trim(y, top_db=35)
    if len(yt) < 800: yt = y
    unit = np.concatenate([yt, np.zeros(int(0.05 * sr))])
    loop = np.tile(unit, int(np.ceil(1.7 * sr / len(unit)))) if len(yt) < 1.6 * sr else yt
    emb = enc.embed_utterance(preprocess_wav(loop, source_sr=sr) if False else loop.astype(np.float32))
    lo, hi = (140, 480) if lang == 'ja' else (75, 260)
    f0, vf, _ = librosa.pyin(yt, fmin=lo, fmax=hi, sr=sr, frame_length=1024)
    f0v = f0[~np.isnan(f0)]
    mf = librosa.feature.mfcc(y=yt, sr=sr, n_mfcc=20).mean(1)
    cen = float(librosa.feature.spectral_centroid(y=yt, sr=sr).mean())
    name = os.path.basename(f)[:-4]
    rows.append(dict(clip=name, group='kana' if name.startswith(lang + '_k_') else 'phrase', emb=emb, f0=float(np.median(f0v)) if len(f0v) else float('nan'), mfcc=mf, centroid=cen, dur=len(y) / sr))
res = {}
for g in ('kana', 'phrase'):
    R = [r for r in rows if r['group'] == g]
    if not R: continue
    E = np.stack([r['emb'] for r in R]); med = np.median(E, 0); med /= np.linalg.norm(med)
    cd = 1 - E @ med
    m, mad = np.median(cd), np.median(np.abs(cd - np.median(cd))) * 1.4826 + 1e-6
    f0 = np.array([r['f0'] for r in R]); f0m = np.nanmedian(f0)
    st = 12 * np.log2(f0 / f0m)
    M = np.stack([r['mfcc'] for r in R]); md = np.linalg.norm(M - np.median(M, 0), axis=1)
    mz = (md - np.median(md)) / (np.median(np.abs(md - np.median(md))) * 1.4826 + 1e-6)
    flags = []
    for r, c, s, z in zip(R, cd, st, mz):
        why = []
        if c > m + 3 * mad and c > 0.15: why.append('embedding %.3f' % c)
        if not np.isnan(s) and abs(s) > 4: why.append('f0 %+.1f st' % s)
        if z > 3.5: why.append('mfcc z %.1f' % z)
        r.update(cos=float(c), st=float(s), mz=float(z))
        if why: flags.append((r['clip'], why))
    res[g] = dict(n=len(R), cos_median=float(m), cos_p90=float(np.percentile(cd, 90)), cos_max=float(cd.max()),
                  f0_median=float(f0m), f0_sd_st=float(np.nanstd(st)), flags=flags)
    print('%-6s n=%d  cos-dist median %.3f p90 %.3f max %.3f | f0 median %.0f Hz, sd %.2f st | flagged %d' % (g, len(R), m, res[g]['cos_p90'], cd.max(), f0m, np.nanstd(st), len(flags)))
    for c, why in flags: print('   FLAG', c, ', '.join(why))
# cross-group: kana median vs phrase median embedding
if 'kana' in res and 'phrase' in res:
    K = np.median(np.stack([r['emb'] for r in rows if r['group'] == 'kana']), 0); P = np.median(np.stack([r['emb'] for r in rows if r['group'] == 'phrase']), 0)
    x = float(K @ P / np.linalg.norm(K) / np.linalg.norm(P)); res['kana_vs_phrase_cos'] = x
    print('kana-median vs phrase-median embedding similarity %.3f' % x)
if out:
    json.dump(dict(summary=res, clips=[{k: v for k, v in r.items() if k not in ('emb', 'mfcc')} for r in rows]), open(out, 'w'), indent=1, ensure_ascii=False)
