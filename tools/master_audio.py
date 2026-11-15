#!/usr/bin/env python3
"""Master generated audio for Azeroth Academy: mono 44.1 kHz, trim silence,
normalize to about -16 LUFS with peaks held at -1 dBFS (sample peak -1.5 for true-peak headroom),
encode Ogg Vorbis q4.  usage: master_audio.py in.(mp3|wav|ogg) out.ogg [target_lufs] [--tempo T] [--lead S] [--tail S]
v1.2.3: --tempo slows speech without changing pitch (rubberband, formants kept; 0.85 = 15% slower),
--lead / --tail add that many seconds of silence before / after the trimmed clip (World Tongues: 0.2 / 0.15)."""
import subprocess, sys, re, numpy as np, tempfile, os

def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", "44100", "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()

def lufs(x):
    with tempfile.NamedTemporaryFile(suffix=".f32") as t:
        # loop very short clips so the 400 ms gating blocks have audio to measure
        y = x
        while len(y) < 44100 * 3: y = np.concatenate([y, x])
        t.write(y.astype(np.float32).tobytes()); t.flush()
        out = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-f", "f32le", "-ar", "44100", "-ac", "1", "-i", t.name,
                              "-af", "ebur128", "-f", "null", "-"], capture_output=True, text=True).stderr
    m = re.findall(r"I:\s+(-?[\d.]+) LUFS", out)
    return float(m[-1]) if m else -70.0

def trim(x, thr_db=-45.0, pad=0.012):
    a = np.abs(x)
    thr = 10 ** (thr_db / 20) * max(a.max(), 1e-9)
    idx = np.where(a > thr)[0]
    if len(idx) == 0: return x
    p = int(pad * 44100)
    s, e = max(0, idx[0] - p), min(len(x), idx[-1] + p)
    y = x[s:e].copy()
    f = min(int(0.005 * 44100), len(y) // 4)     # 5 ms fades: no clicks at the cut
    if f > 0:
        y[:f] *= np.linspace(0, 1, f); y[-f:] *= np.linspace(1, 0, f)
    return y

def limit(y):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-f", "f32le", "-ar", "44100", "-ac", "1", "-i", "-",
                          "-af", "alimiter=limit=0.84:attack=1:release=40:level=disabled:asc=1", "-f", "f32le", "-"],
                         input=y.tobytes(), capture_output=True, check=True).stdout
    z = np.frombuffer(raw, dtype=np.float32).copy()
    m = np.abs(z).max()
    if m > 0.84: z *= 0.84 / m
    return z

def stretch(x, tempo):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-f", "f32le", "-ar", "44100", "-ac", "1", "-i", "-",
                          "-af", f"rubberband=tempo={tempo}:pitch=1:transients=smooth:formant=preserved:pitchq=quality",
                          "-f", "f32le", "-"], input=x.astype(np.float32).tobytes(), capture_output=True, check=True).stdout
    return trim(np.frombuffer(raw, dtype=np.float32).copy())

def main():
    args, opts = [], {"--tempo": 1.0, "--lead": 0.0, "--tail": 0.0}
    it = iter(sys.argv[1:])
    for a in it:
        if a in opts: opts[a] = float(next(it))
        else: args.append(a)
    src, dst = args[0], args[1]
    target = float(args[2]) if len(args) > 2 else -16.0
    x = trim(decode(src))
    if abs(opts["--tempo"] - 1.0) > 1e-6: x = stretch(x, opts["--tempo"])
    l = lufs(x)
    gain_db = target - l
    peak = 20 * np.log10(max(np.abs(x).max(), 1e-9))
    gain_db = min(gain_db, -1.5 - peak + 4.0)   # allow up to ~4 dB of gentle limiting on spiky clips
    y = (x * 10 ** (gain_db / 20)).astype(np.float32)
    if np.abs(y).max() > 10 ** (-1.5 / 20):
        y = limit(y)
    lead, tail = int(opts["--lead"] * 44100), int(opts["--tail"] * 44100)
    if lead or tail:
        y = np.concatenate([np.zeros(lead, np.float32), y.astype(np.float32), np.zeros(tail, np.float32)])
    with tempfile.NamedTemporaryFile(suffix=".f32", delete=False) as t:
        t.write(y.tobytes()); tmp = t.name
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", "44100", "-ac", "1", "-i", tmp,
                    "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
    os.unlink(tmp)
    print(f"{os.path.basename(dst):16s} {len(y)/44100:5.2f}s  in {l:6.1f} LUFS  gain {gain_db:+5.1f} dB  "
          f"out {lufs(y):6.1f} LUFS  peak {20*np.log10(max(np.abs(y).max(),1e-9)):5.1f} dBFS")

main()
