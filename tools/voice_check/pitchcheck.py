"""Robust per-clip pitch: pyin (from consistency json) and yin must agree; returns semitone offset from target."""
import json, sys, math, librosa, numpy as np
def yin_f0(path):
    y, sr = librosa.load(path, sr=16000)
    f = librosa.yin(y, fmin=100, fmax=600, sr=sr, frame_length=1024)
    rms = librosa.feature.rms(y=y, frame_length=1024, hop_length=256)[0]
    n = min(len(f), len(rms)); f = f[:n][rms[:n] > rms.max() * 0.3]
    return float(np.median(f))
def pyin_f0(path):
    y, sr = librosa.load(path, sr=16000)
    f, v, p = librosa.pyin(y, fmin=140, fmax=480, sr=sr, frame_length=1024)
    f = f[~np.isnan(f)]
    return float(np.median(f)) if len(f) else float('nan')
TARGET = 255.0
def st(f): return 12 * math.log2(f / TARGET)
if __name__ == '__main__':
    out = {}
    for p in sys.argv[2:]:
        a, b = pyin_f0(p), yin_f0(p)
        agree = not math.isnan(a) and abs(12 * math.log2(a / b)) < 2
        f = (a * b) ** .5 if agree else b
        out[p] = dict(pyin=a, yin=b, agree=agree, f0=f, st=st(f))
    json.dump(out, open(sys.argv[1], 'w'), indent=1)
