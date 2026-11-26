"""Neighbour placement for a declined part, from the fitted parts of the same atlas.

Scale and rotation come from priors (the caller's: printed or neighbouring scale class; the atlas
rotation + k * 90 deg), so each label is a line constraint on the translation. Every position of an
anchor label along its modern street (4 m steps) is kept when labels of >= 2 different streets land
on their streets (15 m, direction within 15 deg; a second pass ignores direction). Hypotheses are
snapped, ranked by labels on their streets + corridor score (modern centrelines through printed
street corridors), those covering a fitted footprint by more than half are dropped, and the top 8
are verified against the whole sheet's OCR:
  * names: a street-name token not among the labels MATCHES if it is printed within 20 m of the
    street it names, CONTRADICTS if that street passes nowhere within 60 m;
  * references: an adjacent-sheet number printed in or next to the part must land within 40 m of
    that sheet's fitted footprint; more than 150 m away contradicts.
Accepted (tier A): no contradiction, overlap <= 0.5, >= 2 name reads with >= 1 informative (when all
labels are parallel only reads on crossing streets pin the slide), >= 2 street directions overall,
and no rival >= 20 m away with as much support. The final fit holds scale and rotation and fits the
translation to the labels plus the reads; it must put max(3, 25 %) of them on their streets in >= 2
directions.

usage: neighbour.py INPUT.json  -> JSON {"best": {...} | null, "pass": "dir" | "nodir", "hyps": [...]}
INPUT: {"image": jpg of the canvas (1600 px wide), "width": canvas px, "mask": [[x, y]...],
        "labels": [{"px": [x, y], "key": k, "angle": rad | null}],
        "fitted": [{"sheet": n | null, "mask": [[x, y]...], "t": {"a", "b", "tx", "ty"}}],
        "scales": [m/px...], "rotation": rad, "region": [x0, y0, x1, y1] (projected m),
        "tokens": [{"text", "px": [x, y], "keys": [k...]}] (street-name tokens in the part),
        "refs": [{"n", "px": [x, y]}] (references to fitted sheets), "neutral": [k...],
        "streets": {key: [[x1, y1, x2, y2]...]}, "osm": geojsonseq path,
        "projection": {"lon0", "lat0", "kx", "ky"}, "top": 8}
best: {"t": {"a", "b", "tx", "ty"}, "reads": [{"key", "text", "px"}], "hits", "n"}
"""
import sys, os, json, math
import numpy as np
from scipy.spatial import cKDTree
from shapely.geometry import Polygon, Point

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python -I leaves the script dir out
import corridor  # noqa: E402
from corridor import Osm, Sheet, rot, fwd  # noqa: E402

LABEL_M = 15.0      # a hypothesis label lands on its street
HIT_M = 8.0         # ... and after snapping
MATCH_M, CONTRA_M = 20.0, 60.0
REF_OK_M, REF_BAD_M = 40.0, 150.0
MAX_OVERLAP = 0.5
MIN_READS = 2
RIVAL_M = 20.0


class Streets:
    """Named streets sampled every 2 m (with direction), one KD-tree per key."""

    def __init__(self, osm):
        self.o, self.t = osm, {}

    def get(self, key):
        if key not in self.t:
            P, D = [], []
            for a, b in zip(self.o.by_key[key][:, :2], self.o.by_key[key][:, 2:]):
                L = np.linalg.norm(b - a)
                if L < 1e-6:
                    continue
                n = int(L / 2.0) + 1
                P.append(a + np.linspace(0, 1, n, endpoint=False)[:, None] * (b - a))
                D.append(np.repeat([(b - a) / L], n, 0))
            P, D = np.concatenate(P), np.concatenate(D)
            self.t[key] = (P, D, cKDTree(P))
        return self.t[key]

    def query(self, key, W):
        P, D, tree = self.get(key)
        d, i = tree.query(W)
        return d, D[i]


def T_of(t):
    return (math.hypot(t["a"], t["b"]), math.atan2(t["b"], t["a"]), np.array([t["tx"], t["ty"]], float))


def adiff(a, b):  # degrees, undirected
    d = abs(a - b) % 180
    return min(d, 180 - d)


def dir_ok(world_angle, street_dirs, tol):
    a = np.arctan2(street_dirs[..., 1], street_dirs[..., 0])
    return np.abs((a - world_angle + math.pi / 2) % math.pi - math.pi / 2) < tol


def dir_bins(angs):
    """distinct directions, 30 deg apart"""
    out = []
    for a in angs:
        if all(adiff(a, b) >= 30 for b in out):
            out.append(a)
    return out


def street_dir(T, px, key, o):
    _, _, dd = o.nearest(key, fwd(T, np.asarray(px, float)[None]))
    return math.degrees(math.atan2(dd[0][1], dd[0][0])) % 180


def label_dists(T, labels, o):
    return np.array([o.nearest(l["key"], fwd(T, l["px"][None]))[0][0] for l in labels])


def snap(T0, labels, hit, o, s_w=200.0, th_w=300.0, t_w=0.02):
    """labels `hit` onto their streets; scale and rotation pulled to their start, translation weakly
    (it only fixes the slide's null space)."""
    s0, th0, t0 = T0
    px = np.array([labels[j]["px"] for j in hit], float).reshape(-1, 2)
    priors = lambda x, _T: [s_w * (x[0] - math.log(s0)), th_w * (x[1] - th0),
                            t_w * (x[2] - t0[0]), t_w * (x[3] - t0[1])]
    return corridor.snap(T0, px, [labels[j]["key"] for j in hit], o, priors)


# ---------------------------------------------------------------- hypotheses
def candidates(centre, labels, st, s, th, region, tol_m=LABEL_M, tol_dir=math.radians(15)):
    """translations where an anchor label (<= 2 per street, nearest the part centre) sits on its street
    and labels of >= 2 distinct streets land on theirs: [{"t", "hits"}]"""
    R = s * rot(th)
    Q = np.array([[l["px"][0], -l["px"][1]] for l in labels]) @ R.T     # label offsets before t
    keys = [l["key"] for l in labels]
    by_key = {}
    for a, l in enumerate(labels):
        by_key.setdefault(l["key"], []).append(a)
    anchors = [a for idx in by_key.values()
               for a in sorted(idx, key=lambda i: np.linalg.norm(labels[i]["px"] - centre))[:2]]
    out = []
    for a in anchors:
        P, D, _ = st.get(keys[a])
        sel = (P[:, 0] > region[0]) & (P[:, 0] < region[2]) & (P[:, 1] > region[1]) & (P[:, 1] < region[3])
        if labels[a]["ang"] is not None:
            sel &= dir_ok(th - labels[a]["ang"], D, tol_dir)
        P = P[sel][::2]                                                   # 4 m steps
        if len(P) == 0:
            continue
        T = P - Q[a]
        hit = np.zeros((len(T), len(labels)), bool)
        hit[:, a] = True
        for j, l in enumerate(labels):
            if j == a:
                continue
            d, dd = st.query(l["key"], T + Q[j])
            ok = d < tol_m
            if l["ang"] is not None:
                ok &= dir_ok(th - l["ang"], dd, tol_dir)
            hit[:, j] = ok
        nk = np.array([len({keys[j] for j in np.flatnonzero(h)}) for h in hit])
        out += [dict(t=T[i], hits=frozenset(np.flatnonzero(hit[i]).tolist())) for i in np.flatnonzero(nk >= 2)]
    return out


def overlap(fp, fitted):
    """largest share of the smaller footprint covered by a fitted one"""
    if not fp.is_valid or fp.area == 0:
        return 1.0
    return max([fp.intersection(F["fp"]).area / min(fp.area, F["fp"].area) for F in fitted
                if fp.intersects(F["fp"])], default=0.0)


def hypotheses(inp, mask, labels, fitted, st, sheet, tol_dir, top):
    centre = mask.mean(0)
    res = []
    for s in inp["scales"]:
        for k in range(4):
            th = inp["rotation"] + k * math.pi / 2
            seen, C = set(), []
            for c in candidates(centre, labels, st, s, th, inp["region"], tol_dir=tol_dir):
                sig = (c["hits"], tuple(np.round(c["t"] / 8).astype(int)))   # one per hit set and 8 m cell
                if sig not in seen:
                    seen.add(sig)
                    C.append(c)
            for c in C:
                T = snap((s, th, c["t"]), labels, sorted(c["hits"]), st.o)
                if not (0.96 * s < T[0] < 1.04 * s):
                    continue
                d = label_dists(T, labels, st.o)
                hit = [j for j in range(len(labels)) if d[j] < HIT_M]
                if len({labels[j]["key"] for j in hit}) < 2:
                    continue
                g, b = sheet.corridor(T, st.o)
                ov = overlap(Polygon(fwd(T, mask)), fitted)
                res.append(dict(T=T, k=k, s=s, hits=hit, overlap=ov, good=g, bad=b,
                                c=fwd(T, centre[None])[0],
                                score=(g - b) + 400.0 * len(hit) - (2000.0 if ov > MAX_OVERLAP else 0)))
    res.sort(key=lambda r: -r["score"])
    out = []
    for r in res:
        if all(np.linalg.norm(r["c"] - o["c"]) >= 40 or abs(r["T"][1] - o["T"][1]) > 0.5 for o in out):
            out.append(r)
        if len(out) == top:
            break
    return out


# ---------------------------------------------------------------- verification
def verify(T, tokens, o, neutral):
    """street-name tokens under T: {key: [token]} matches and [(key, text)] contradictions"""
    matches, contras = {}, []
    for tok in tokens:
        keys = [k for k in tok["keys"] if k in o.by_key]
        if not keys or any(k in neutral for k in tok["keys"]):
            continue
        w = fwd(T, tok["px"][None])
        d, k = min((o.nearest(k, w)[0][0], k) for k in keys)
        if d < MATCH_M:
            matches.setdefault(k, []).append(tok)
        elif d > CONTRA_M:
            contras.append((k, tok["text"]))
    return matches, contras


def ref_check(T, refs, fitted):
    """distances (m) from each printed sheet reference (under T) to that sheet's fitted footprint:
    (agreeing, contradicting)"""
    good, bad = [], []
    for r in refs:
        w = Point(*fwd(T, r["px"][None])[0])
        fps = [F["fp"] for F in fitted if F["sheet"] == r["n"]]
        if not fps:
            continue
        d = min(fp.distance(w) for fp in fps)
        if d <= REF_OK_M:
            good.append((r["n"], round(d)))
        elif d > REF_BAD_M:
            bad.append((r["n"], round(d)))
    return good, bad


def assess(h, labels, tokens, refs, fitted, o, neutral):
    h["matches"], h["contras"] = verify(h["T"], tokens, o, neutral)
    h["rg"], h["rb"] = ref_check(h["T"], refs, fitted)
    hd = [street_dir(h["T"], labels[j]["px"], labels[j]["key"], o) for j in h["hits"]]
    rd = {k: street_dir(h["T"], toks[0]["px"], k, o) for k, toks in h["matches"].items()}
    cross = [k for k, a in rd.items() if all(adiff(a, b) >= 30 for b in hd)]
    # labels in one direction leave a slide: only reads on crossing streets pin it
    h["ninf"] = len(cross) if len(dir_bins(hd)) < 2 else len(rd)
    clean = not h["contras"] and not h["rb"] and h["overlap"] <= MAX_OVERLAP
    h["acc"] = (clean and h["ninf"] >= 1 and len(h["matches"]) >= MIN_READS
                and len(dir_bins(hd + list(rd.values()))) >= 2)
    h["sup"] = (h["ninf"] + len(h["rg"]), len(h["matches"]))


def final_fit(T, labels, matches, o):
    """hold scale and rotation; fit the translation to the labels plus the reads"""
    L = list(labels) + [dict(key=k, px=t["px"], ang=None) for k, toks in matches.items() for t in toks]
    d = label_dists(T, L, o)
    T2 = snap(T, L, [j for j in range(len(L)) if d[j] < LABEL_M], o)
    for _ in range(2):
        d = label_dists(T2, L, o)
        T2 = snap(T2, L, [j for j in range(len(L)) if d[j] < HIT_M], o)
    d = label_dists(T2, L, o)
    hit = [j for j in range(len(L)) if d[j] < HIT_M]
    ndir = len(dir_bins([street_dir(T2, L[j]["px"], L[j]["key"], o) for j in hit]))
    ok = len(hit) >= max(3, math.ceil(0.25 * len(L))) and ndir >= 2
    return T2, dict(ok=ok, hits=len(hit), n=len(L))


def place(inp, mask, labels, tokens, refs, fitted, st, sheet, tol_dir):
    neutral = set(inp["neutral"]) | {l["key"] for l in labels}
    hyps = hypotheses(inp, mask, labels, fitted, st, sheet, tol_dir, inp.get("top", 8))
    for h in hyps:
        assess(h, labels, tokens, refs, fitted, st.o, neutral)
    ok = [h for h in hyps if h["acc"]]
    best = max(ok, key=lambda h: (h["sup"], h["score"])) if ok else None
    # ambiguity: a rival >= 20 m away with as much support
    if best and any(h is not best and np.linalg.norm(h["c"] - best["c"]) >= RIVAL_M and h["sup"] >= best["sup"]
                    for h in ok):
        best = None
    return hyps, best


def summary(h):
    return dict(k=h["k"], ft=round(h["s"] * 395 / 0.3048), centre=[round(float(v)) for v in h["c"]],
                hits=len(h["hits"]), overlap=round(h["overlap"], 2), corridor=[round(h["good"]), round(h["bad"])],
                reads=sorted(h["matches"]), informative=h["ninf"], contras=h["contras"][:4],
                refs_ok=h["rg"], refs_bad=h["rb"], accepted=h["acc"])


def tparams(T):
    s, th, t = T
    return dict(a=s * math.cos(th), b=s * math.sin(th), tx=float(t[0]), ty=float(t[1]))


def main():
    inp = json.load(open(sys.argv[1]))
    o = Osm(inp["streets"], inp["osm"], inp["projection"])
    st = Streets(o)
    sheet = Sheet(inp["image"], inp["width"], inp["mask"])
    mask = np.array(inp["mask"], float)
    labels = [dict(key=l["key"], px=np.array(l["px"], float), ang=l["angle"])
              for l in inp["labels"] if l["key"] in o.by_key]
    tokens = [dict(text=t["text"], px=np.array(t["px"], float), keys=t["keys"]) for t in inp["tokens"]]
    refs = [dict(n=r["n"], px=np.array(r["px"], float)) for r in inp["refs"]]
    fitted = [dict(sheet=f["sheet"], fp=Polygon(fwd(T_of(f["t"]), np.array(f["mask"], float))))
              for f in inp["fitted"]]
    out = dict(best=None, hyps=[], **{"pass": None})
    if len({l["key"] for l in labels}) >= 2:
        # a second pass ignores label directions (stub names printed across their street)
        for name, tol in (("dir", math.radians(15)), ("nodir", math.pi)):
            hyps, best = place(inp, mask, labels, tokens, refs, fitted, st, sheet, tol)
            if out["pass"] is None or (not out["hyps"] and hyps) or best:
                out.update(hyps=[summary(h) for h in hyps], **{"pass": name})
            if best:
                T, g = final_fit(best["T"], labels, best["matches"], o)
                if g["ok"]:
                    reads = [dict(key=k, text=t["text"], px=t["px"].tolist())
                             for k, toks in best["matches"].items() for t in toks]
                    out["best"] = dict(t=tparams(T), reads=reads, hits=g["hits"], n=g["n"])
                out["gates"] = g
                break
    print(json.dumps(out))


main()
