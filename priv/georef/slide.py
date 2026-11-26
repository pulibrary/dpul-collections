"""Slide search for parts whose readable street names are all on PARALLEL streets.

Labels on one family of parallel streets fix rotation and the offset across
them, but the fit can slide along them. For each family this tries every
placement of one family label along its modern street (every 4 m) at Sanborn's
standard scales, snaps the family labels onto their streets, and ranks the
placements by how well the modern street centrelines fall into printed street
corridors (blank paper with ink both sides). For each of the top placements it
predicts up to 3 named cross streets and mid-block points on them where their
name should be printed; the caller reads those points (OCR / VLM) to confirm or
contradict the placement.

usage: slide.py INPUT.json  -> JSON {"families": [{"keys": [...], "hyps": [...]}]}
INPUT: {"image": jpg of the whole canvas, "width": canvas px, "mask": [[x, y]...],
        "families": [[{"px": [x, y], "key": k, "angle": rad}...]...],
        "scales": [m/px...], "streets": {key: [[x1, y1, x2, y2]...]} (projected m),
        "osm": geojsonseq path, "projection": {"lon0", "lat0", "kx", "ky"},
        "top": 8, "edge": px a read point must keep from the part edge}
hyp: {"t": {"a", "b", "tx", "ty"}, "score", "cross": [{"key", "pts": [[x, y]...]}]}
Transform convention: world (m, east/north) = s * R(th) @ [x, -y] + t  (x, y canvas px),
i.e. Georef.Geometry's {a, b} = s * {cos th, sin th}.
"""
import sys, os, json, math
import numpy as np, cv2
from scipy.spatial import cKDTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python -I leaves the script dir out
import corridor  # noqa: E402
from corridor import Osm, Sheet, rot, fwd, inv, sample  # noqa: E402


def snap(T, fam, osm, anchor, aw=3.0):
    """Snap the family labels onto their streets with the anchor's along-street position held (the
    slide) and scale and rotation pulled to their start. Returns T and each label's distance."""
    s0, th0 = T[0], T[1]
    px = np.array([l["px"] for l in fam], float)
    a_px, a_world, a_dir = anchor
    # rotation prior: labels in one column leave rotation unconstrained otherwise; 1 deg ~ 5 m
    priors = lambda x, T_: [aw * (a_dir @ (fwd(T_, a_px[None])[0] - a_world)),
                            200.0 * (x[0] - math.log(s0)), 300.0 * (x[1] - th0)]
    T_ = corridor.snap(T, px, [l["key"] for l in fam], osm, priors)
    d = np.array([osm.nearest(l["key"], fwd(T_, np.array([l["px"]], float)))[0][0] for l in fam])
    return T_, d


def search(sheet, fam, osm, scales, step=4.0, pre_tol=30.0):
    """Every placement of up to 3 anchor labels (nearest the part centre, one per street) along their street,
    both ways round, at each scale; snapped, filtered (>= 2 family streets and half the family labels within
    8 m), scored by corridor evidence."""
    anchors = []
    for k in sorted({l["key"] for l in fam}):
        ls = [l for l in fam if l["key"] == k]
        anchors.append(min(ls, key=lambda l: np.linalg.norm(np.array(l["px"]) - sheet.centre)))
    anchors = sorted(anchors, key=lambda l: np.linalg.norm(np.array(l["px"]) - sheet.centre))[:3]
    res = []
    for A in anchors:
        rest = [l for l in fam if l["key"] != A["key"]]
        rest_px = np.array([l["px"] for l in rest], float)
        S = osm.by_key[A["key"]]
        P, D = [], []
        for a, b in zip(S[:, :2], S[:, 2:]):
            L = np.linalg.norm(b - a)
            if L < 1e-6:
                continue
            n = max(1, int(L / step))
            P.append(a + np.linspace(0, 1, n, endpoint=False)[:, None] * (b - a))
            D.append(np.repeat([(b - a) / L], n, 0))
        P, D = np.concatenate(P), np.concatenate(D)
        apx = np.array(A["px"], float)
        for s in scales:
            for flip in (0, math.pi):
                th = np.arctan2(D[:, 1], D[:, 0]) + A["angle"] + flip  # label dir in the y-up frame is -angle
                for i in range(len(P)):
                    T = (s, th[i], P[i] - s * rot(th[i]) @ np.array([apx[0], -apx[1]]))
                    w = fwd(T, rest_px)
                    if not any(osm.nearest(l["key"], w[j:j + 1])[0][0] < pre_tol for j, l in enumerate(rest)):
                        continue
                    T2, d = snap(T, fam, osm, (apx, P[i], D[i]))
                    if not (0.96 * s < T2[0] < 1.04 * s):
                        continue
                    if len({l["key"] for l, dd in zip(fam, d) if dd < 8}) < 2 or (d < 8).mean() < 0.5:
                        continue
                    g, b = sheet.corridor(T2, osm)
                    res.append(dict(T=T2, score=g - b, c=fwd(T2, sheet.centre[None])[0]))
    res.sort(key=lambda r: -r["score"])
    return res


def top_k(res, k, sep=40.0):
    """best k placements whose part centres are >= sep m apart"""
    out = []
    for r in res:
        if all(np.linalg.norm(r["c"] - o["c"]) >= sep for o in out):
            out.append(r)
        if len(out) == k:
            break
    return out


def predicted_cross(T, sheet, fam, osm, edge, nmax=3):
    """Named streets crossing the family (> 45 deg) inside the part, longest first, each with up to 3
    read points placed mid-block (farthest from any street parallel to the family), 1000 px apart."""
    famdir = rot(T[1]) @ np.array([math.cos(-fam[0]["angle"]), math.sin(-fam[0]["angle"])])
    wc = fwd(T, sheet.centre[None])[0]
    idx = osm.tree.query_ball_point(wc, sheet.radius * T[0] + 50)
    par = [i for i in idx if abs(osm.nrm[i] @ famdir) < 0.5]  # normal ~ perpendicular to the family
    ptree = cKDTree(osm.samp[par]) if par else None
    poly = np.float32(sheet.mask_poly)
    fam_keys = {l["key"] for l in fam}
    cands = []
    for key, S in osm.by_key.items():
        if key in fam_keys:
            continue
        pts = []
        for a, b in zip(S[:, :2], S[:, 2:]):
            L = np.linalg.norm(b - a)
            if L < 1 or abs((b - a) @ famdir) / L > 0.7 or np.linalg.norm(a - wc) > sheet.radius * T[0] + 2000:
                continue
            pts.append(sample(a, b, 3.0))
        if not pts:
            continue
        P = np.concatenate(pts)
        px = inv(T, P)
        dedge = np.array([cv2.pointPolygonTest(poly, (float(x), float(y)), True) for x, y in px])
        good = dedge > edge
        if good.sum() < 10:
            continue
        Pc = px[good]
        dd = ptree.query(P[good])[0] if ptree else np.full(good.sum(), 50.0)
        chosen = []
        while len(chosen) < 3 and (dd > 0).any():
            i = int(dd.argmax())
            chosen.append(Pc[i].tolist())
            dd[np.linalg.norm(Pc - Pc[i], axis=1) < 1000] = -1
        cands.append((int(good.sum()), key, chosen))
    cands.sort(key=lambda c: -c[0])
    return [dict(key=k, pts=p) for _, k, p in cands[:nmax]]


def main():
    inp = json.load(open(sys.argv[1]))
    osm = Osm(inp["streets"], inp["osm"], inp["projection"])
    sheet = Sheet(inp["image"], inp["width"], inp["mask"])
    out = []
    for fam in inp["families"]:
        fam = [l for l in fam if l["key"] in osm.by_key]
        if len({l["key"] for l in fam}) < 2:
            continue
        hyps = []
        for r in top_k(search(sheet, fam, osm, inp["scales"]), inp.get("top", 8)):
            s, th, t = r["T"]
            hyps.append(dict(
                t=dict(a=s * math.cos(th), b=s * math.sin(th), tx=float(t[0]), ty=float(t[1])),
                score=float(r["score"]),
                cross=predicted_cross(r["T"], sheet, fam, osm, inp["edge"])))
        out.append(dict(keys=sorted({l["key"] for l in fam}), hyps=hyps))
    print(json.dumps({"families": out}))


main()
