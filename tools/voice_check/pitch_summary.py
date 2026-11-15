"""Register spread per group using Praat autocorrelation pitch (robust on short clips).
usage: pitch_summary.py BEFORE_DIR AFTER_DIR [out.json]   (dirs hold ja_k_*.ogg, ja_w_/ja_d_*.ogg, es_*.ogg)"""
import glob, json, math, sys, numpy as np, librosa, parselmouth
def f0(p, lo, hi):
    y, sr = librosa.load(p, sr=44100); s = parselmouth.Sound(y.astype(np.float64), sr)
    f = s.to_pitch_ac(pitch_floor=lo, pitch_ceiling=hi, very_accurate=True).selected_array['frequency']; f = f[f > 0]
    return float(np.median(f))
def summ(files, lo, hi):
    v0 = {p.split('/')[-1][:-4]: f0(p, lo, hi) for p in files}
    v = {k: x for k, x in v0.items() if x == x}
    med = float(np.median(list(v.values()))); st = {k: 12 * math.log2(x / med) for k, x in v.items()}
    a = np.array(list(st.values()))
    return dict(n=len(a), unvoiced=sorted(set(v0) - set(v)), median_hz=round(med, 1), sd_st=round(float(a.std()), 2), max_abs_st=round(float(abs(a).max()), 1),
                over4=int((abs(a) > 4).sum()), over6=int((abs(a) > 6).sum()), worst=sorted(st, key=lambda k: -abs(st[k]))[:5])
out = {}
for tag, d in [('before', sys.argv[1]), ('after', sys.argv[2])]:
    kana = sorted(glob.glob(d + '/ja_k_*.ogg')); phr = sorted(glob.glob(d + '/ja_[wd]_*.ogg')); es = sorted(glob.glob(d + '/es_*.ogg'))
    out[tag] = dict(ja_kana=summ(kana, 120, 600), ja_phrase=summ(phr, 120, 600), es=summ(es, 60, 400))
    for g, s in out[tag].items(): print(tag, g, s)
json.dump(out, open(sys.argv[3] if len(sys.argv) > 3 else 'pitch_summary.json', 'w'), indent=1)
