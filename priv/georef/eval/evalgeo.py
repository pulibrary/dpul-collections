# usage: evalgeo.py TRUTH.json [ANNOTATION.json]
# Fits what Allmaps would (affine / polynomial order 1) from the annotation's GCPs,
# then measures error at the hand-labelled check points (metres).
# Without an annotation: fits a similarity to the truth points themselves (label/OSM noise floor).
import sys, json, math
import numpy as np
truth = json.load(open(sys.argv[1]))
ann = json.load(open(sys.argv[2])) if len(sys.argv) > 2 else None
def proj(lon0, lat0):
    k = 6378137 * math.pi / 180
    return lambda ll: ((ll[0] - lon0) * k * math.cos(math.radians(lat0)), (ll[1] - lat0) * k)
def fit_affine(px, xy):
    A = np.hstack([np.array(px, float), np.ones((len(px), 1))])
    sol, *_ = np.linalg.lstsq(A, np.array(xy, float), rcond=None)
    return lambda p: np.array([p[0], p[1], 1.0]) @ sol
def fit_sim(px, xy):
    A = []; b = []
    for (u, v), (x, y) in zip(px, xy):
        A.append([u, v, 1, 0]); b.append(x); A.append([-v, u, 0, 1]); b.append(y)  # image y is down
    s, *_ = np.linalg.lstsq(np.array(A, float), np.array(b, float), rcond=None)
    return lambda p: np.array([s[0]*p[0] + s[1]*p[1] + s[2], -s[0]*p[1] + s[1]*p[0] + s[3]])
anns = {}
if ann:
    for a in ann["items"]:
        anns.setdefault(a["target"]["source"]["partOf"][0]["id"], []).append(a)
def mask_of(a):
    v = a["target"]["selector"]["value"].split('points="')[1].split('"')[0]
    return [tuple(map(float, p.split(","))) for p in v.split()]
def inside(pt, poly):
    x, y = pt; c = False
    for (x1, y1), (x2, y2) in zip(poly, poly[1:] + poly[:1]):
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1: c = not c
    return c
allerr = []
for cid, pts in truth["canvases"].items():
    lon0 = np.mean([p["lonlat"][0] for p in pts]); lat0 = np.mean([p["lonlat"][1] for p in pts]); P = proj(lon0, lat0)
    name = cid.split("/")[-1][:8]
    if ann is None:
        f = fit_sim([p["px"] for p in pts], [P(p["lonlat"]) for p in pts])
        mode = "truth-self-fit"
    else:
        fits = []
        for a in anns.get(cid, []):
            feats = a["body"]["features"]
            if len(feats) >= 3:
                fits.append((mask_of(a), fit_affine([g["properties"]["resourceCoords"] for g in feats], [P(g["geometry"]["coordinates"]) for g in feats]), len(feats)))
        if not fits:
            print(f"{name}: NOT GEOREFERENCED"); allerr += [float("inf")] * len(pts); continue
        def f(px):
            for poly, fn, _ in fits:
                if inside(px, poly): return fn(px)
            return None
        mode = f"{len(fits)} part(s), gcps {[n for _, _, n in fits]}"
    errs = [float("inf") if f(p["px"]) is None else float(np.linalg.norm(f(p["px"]) - np.array(P(p["lonlat"])))) for p in pts]
    allerr += errs
    print(f"{name} ({mode}): median {np.median(errs):.1f} m, max {max(errs):.1f} m  " + " ".join(f"{p['label']}={e:.1f}" for p, e in zip(pts, errs)))
fin = [e for e in allerr if math.isfinite(e)]
print(f"ALL: n={len(allerr)} uncovered={sum(1 for e in allerr if not math.isfinite(e))} georef'd={len(fin)} median={np.median(fin) if fin else float('nan'):.1f} m max={max(fin) if fin else float('nan'):.1f} m")
