import sys, numpy as np, librosa
def segments(path, top_db=None, min_gap=0.06, sr=44100):
    y, sr = librosa.load(path, sr=sr, mono=True)
    hop = 220
    rms = librosa.feature.rms(y=y, frame_length=882, hop_length=hop)[0]
    db = 20*np.log10(rms+1e-9); thr = db.max() - (top_db or 35)
    on = db > thr
    segs=[]; i=0; n=len(on)
    while i<n:
        if on[i]:
            j=i
            while j<n and on[j]: j+=1
            segs.append([i,j]); i=j
        else: i+=1
    # merge gaps shorter than min_gap
    m=[]
    for s in segs:
        if m and (s[0]-m[-1][1])*hop/sr < min_gap: m[-1][1]=s[1]
        else: m.append(s)
    m=[s for s in m if (s[1]-s[0])*hop/sr > 0.05]
    return y, sr, [(a*hop/sr, b*hop/sr) for a,b in m], db
if __name__=='__main__':
    y,sr,s,db=segments(sys.argv[1])
    for a,b in s: print(round(a,3), round(b,3), round(b-a,3))
