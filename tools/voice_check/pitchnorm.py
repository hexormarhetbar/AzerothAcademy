"""Formant-preserving register correction (Praat PSOLA via parselmouth).
usage: pitchnorm.py in.ogg out.wav semitones [pitch_floor pitch_ceiling]   (negative = lower)"""
import sys, numpy as np, librosa, soundfile as sf, parselmouth
from parselmouth.praat import call
src, dst, st = sys.argv[1], sys.argv[2], float(sys.argv[3])
lo = float(sys.argv[4]) if len(sys.argv) > 4 else 120
hi = float(sys.argv[5]) if len(sys.argv) > 5 else 600
y, sr = librosa.load(src, sr=44100)
s = parselmouth.Sound(y.astype(np.float64), sr)
m = call(s, "To Manipulation", 0.005, lo, hi)
pt = call(m, "Extract pitch tier")
call(pt, "Shift frequencies", s.xmin, s.xmax, st, "semitones")
call([pt, m], "Replace pitch tier")
out = call(m, "Get resynthesis (overlap-add)")
z = out.values[0].astype(np.float32)
sf.write(dst, z, sr)
