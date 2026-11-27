"""Final alignment of an accepted fit to the printed street corridors (image comparison, no VLM).

Sanborn streets are empty corridors between block outlines, and a modern centreline should run down the
middle. Point-to-line ICP over a similarity transform: every modern drawn-street centreline sample that
lies in a printed corridor under the current fit (no ink under it, ink on both sides 9..36 m apart) is
paired with that corridor's centre; every label is paired with its own street (weight LABEL_W samples,
so the corridors cannot slide the fit onto the neighbouring parallel street). The similarity is linear in
(a, b, tx, ty), so each iteration is one weighted least squares; residuals beyond 12 m (first pass) /
6 m are dropped.

On the check points: Cresskill 1.7 -> 1.2 m median, Hightstown 3.2 -> 2.6 m, Paulsboro 1.6 -> 1.7 m;
on the oldinsurancemaps.net human GCPs (LoC scans) town medians 13 better / 7 worse by layer
(Carneys Point 19.9 -> 13.5 m, Clayton 5.3 -> 3.5 m).

usage: align.py INPUT.json -> JSON {"t": {"a", "b", "tx", "ty"} | null, "move_m", "drot_deg", "n"}
INPUT (Georef.Py): {"image", "width", "mask": [[x, y]...], "t": {...}, "labels": [{"key", "px"}],
                    "streets", "osm", "projection"}
"""
import sys, os, json, math
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python -I leaves the script dir out
from corridor import Osm, Sheet, fwd, inv, rot  # noqa: E402

LABEL_W = 30.0
MAX_MOVE_M = 15.0
MAX_ROT_DEG = 3.0
# The ICP's basin in rotation is narrow on some sheets: a fit a few degrees off stays there (Belmar 1905
# Sheet 83 at 5 deg, Bay Head 1905 Sheet 51 at 5 deg, May's Landing 1924 Sheet 9, Princeton 1911 Sheet 4;
# all overlay-checked). Alignment is also started WIDE_DEG either side; such a start is kept only if its
# contrast beats the plain one by WIDE_GAIN, reaches WIDE_MIN, and turns <= WIDE_ROT_DEG. On a sound fit
# (Belmar Sheet 82) every start from -8..8 deg returns to the same place. 7/158 fits changed in the scan.
WIDE_DEG = 4.0
WIDE_GAIN = 0.05
WIDE_MIN = 0.1
WIDE_ROT_DEG = 6.0


def centres(sheet, osm, T):
    """canvas px of the corridor centre for each in-corridor centreline sample, its world point and normal"""
    s = T[0]
    wc = fwd(T, sheet.centre[None])[0]
    idx = osm.tree.query_ball_point(wc, sheet.radius * s + 20)
    if not idx:
        return None
    H, Wd = sheet.inkd.shape
    w, nw = osm.samp[idx], osm.nrm[idx]
    p = inv(T, w) * sheet.f
    n = nw @ rot(T[1])
    n = np.c_[n[:, 0], -n[:, 1]]
    pi = np.round(p).astype(int)
    ok = (pi[:, 0] >= 0) & (pi[:, 0] < Wd) & (pi[:, 1] >= 0) & (pi[:, 1] < H)
    w, nw, p, n, pi = w[ok], nw[ok], p[ok], n[ok], pi[ok]
    ok = sheet.mask[pi[:, 1], pi[:, 0]]
    w, nw, p, n = w[ok], nw[ok], p[ok], n[ok]
    mpp = s / sheet.f
    offs = np.arange(1.0, 26.0, 0.5)
    first = []
    for sg in (1, -1):
        q = np.round(p[:, None, :] + sg * (offs / mpp)[None, :, None] * n[:, None, :]).astype(int)
        q[..., 0] = q[..., 0].clip(0, Wd - 1)
        q[..., 1] = q[..., 1].clip(0, H - 1)
        hit = sheet.inkd[q[..., 1], q[..., 0]]
        first.append(np.where(hit.any(1), offs[hit.argmax(1)], 99.0))
    width = first[0] + first[1]
    good = (first[0] < 90) & (first[1] < 90) & (width >= 9) & (width <= 36)
    off_m = (first[0] - first[1]) / 2
    cpx = (p + (off_m / mpp)[:, None] * n)[good] / sheet.f
    return cpx, w[good], nw[good]


def label_rows(osm, T, labels):
    rows = []
    for k in sorted({l["key"] for l in labels}):  # sorted: set order varies per process (hash seed)
        if k not in osm.by_key:
            continue
        ls = [l for l in labels if l["key"] == k]
        px = np.array([l["px"] for l in ls], float)
        d, F, dd = osm.nearest(k, fwd(T, px))
        rows += [(px[j], F[j], np.array([-dd[j][1], dd[j][0]])) for j in range(len(ls)) if d[j] < 25]
    return rows


def solve(cpx, w, nw, wts):
    """similarity minimising sum wts * (nw . (T(cpx) - w))^2, T(c) = [[a,-b],[b,a]] @ (u, -v) + t"""
    u, v = cpx[:, 0], -cpx[:, 1]
    nx, ny = nw[:, 0], nw[:, 1]
    A = np.c_[nx * u + ny * v, -nx * v + ny * u, nx, ny]
    sw = np.sqrt(wts)
    a, b, tx, ty = np.linalg.lstsq(A * sw[:, None], (nx * w[:, 0] + ny * w[:, 1]) * sw, rcond=None)[0]
    return (math.hypot(a, b), math.atan2(b, a), np.array([tx, ty]))


def align(sheet, osm, T0, labels, iters=8):
    T, n = T0, 0
    for it in range(iters):
        got = centres(sheet, osm, T)
        if got is None or len(got[0]) < 30:
            return None, 0
        cpx, w, nw = got
        r = ((fwd(T, cpx) - w) * nw).sum(1)
        wts = np.where(np.abs(r) <= (6.0 if it else 12.0), 1.0, 0.0)
        n = int(wts.sum())
        if n < 30:
            return None, 0
        lr = label_rows(osm, T, labels)
        if lr:
            cpx = np.vstack([cpx, [x[0] for x in lr]])
            w = np.vstack([w, [x[1] for x in lr]])
            nw = np.vstack([nw, [x[2] for x in lr]])
            wts = np.r_[wts, np.full(len(lr), LABEL_W)]
        T = solve(cpx, w, nw, wts)
    return T, n


def corridor_fraction(sheet, osm, T):
    good, bad = sheet.corridor(T, osm)
    return good / max(good + bad, 1.0)


# Fixed displacements for the contrast: 8 directions, 20..120 m, every other one also turned 10 deg.
PERTURB = [(20 + 100 * k / 7, k * math.pi / 4, (-1) ** k * math.radians(10) * (k % 2)) for k in range(8)]


def contrast(sheet, osm, T):
    """how much more modern centreline lies in printed corridors at T than at nearby wrong placements:
    a true fit is a peak (median over our accepted fits 0.24, p10 0.09), a wrong placement is not
    (worst of 4 wrong placements per part: median 0.03, p90 0.12)"""
    c = sheet.centre[None]
    w = fwd(T, c)[0]
    vals = []
    for d, ang, dth in PERTURB:
        T2 = (T[0], T[1] + dth, np.zeros(2))
        w2 = fwd(T2, c)[0]
        vals.append(corridor_fraction(sheet, osm, (T[0], T[1] + dth, w - w2 + d * np.array([math.cos(ang), math.sin(ang)]))))
    return corridor_fraction(sheet, osm, T) - float(np.median(vals))


def to_T(t):
    return (math.hypot(t["a"], t["b"]), math.atan2(t["b"], t["a"]), np.array([t["tx"], t["ty"]]))


def from_T(T):
    s, th, tr = T
    return {"a": s * math.cos(th), "b": s * math.sin(th), "tx": float(tr[0]), "ty": float(tr[1])}


def main():
    inp = json.load(open(sys.argv[1]))
    osm = Osm(inp["streets"], inp["osm"], inp["projection"])
    sheet = Sheet(inp["image"], inp["width"], inp["mask"])
    if "candidates" in inp:
        # verify mode (corridor rescue of a declined part): align each candidate, report its contrast
        out = []
        for t in inp["candidates"]:
            T, n = align(sheet, osm, to_T(t), inp["labels"])
            T = T if T is not None else to_T(t)
            out.append({"t": from_T(T), "contrast": contrast(sheet, osm, T), "n": n})
        print(json.dumps({"candidates": out}))
        return
    T0 = to_T(inp["t"])
    c = sheet.centre[None]
    w0 = fwd(T0, c)[0]

    def result(T, wide):
        move = float(np.linalg.norm(fwd(T, c)[0] - w0))
        drot = math.degrees(T[1] - T0[1])
        ok = move <= MAX_MOVE_M and abs(drot) <= (WIDE_ROT_DEG if wide else MAX_ROT_DEG)
        return move, drot, ok

    T, n = align(sheet, osm, T0, inp["labels"])
    out = {"t": None, "move_m": None, "drot_deg": None, "n": n, "wide": False}
    best = None
    if T is not None:
        move, drot, ok = result(T, False)
        out.update(move_m=move, drot_deg=drot)
        if ok:
            out["t"] = from_T(T)
            best = contrast(sheet, osm, T)
    base = best if best is not None else contrast(sheet, osm, T0)
    for d in (-WIDE_DEG, WIDE_DEG):
        th = T0[1] + math.radians(d)
        Ts = (T0[0], th, w0 - fwd((T0[0], th, np.zeros(2)), c)[0])
        Tw, nw = align(sheet, osm, Ts, inp["labels"])
        if Tw is None:
            continue
        move, drot, ok = result(Tw, True)
        k = contrast(sheet, osm, Tw)
        if ok and k >= WIDE_MIN and k >= base + WIDE_GAIN and (best is None or k > best):
            best = k
            out.update(t=from_T(Tw), move_m=move, drot_deg=drot, n=nw, wide=True, contrast=k, contrast0=base)
    print(json.dumps(out))


if __name__ == "__main__":
    main()
