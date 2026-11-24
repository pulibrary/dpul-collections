# usage: seams.py ANNOTATION.json [ANNOTATION.json ...]
# Label-free accuracy check between georeferenced sheets of one atlas.
# Where two sheets' masks overlap on the ground, render both scans onto one
# ground grid through the affines Allmaps would fit, then template-match small
# patches. A patch with 2-D structure and one clear peak measures how far apart
# the two fits put the same printed marks (the seam gap).
# Prints, per overlapping pair, the median/90th-percentile disagreement (m).
import sys, json, io, math, re, itertools, urllib.request, urllib.parse
import numpy as np, cv2
from shapely.geometry import Polygon

ITEMS = [a for f in sys.argv[1:] for a in json.load(open(f))["items"]]
GSD = 0.25
GATE = 12.0  # m: largest seam gap measured (bigger ones show as no match)
import os; DEBUG = os.environ.get("SEAMS_DEBUG")  # metres per pixel to compare at

def parse(a):
    src = a["target"]["source"]
    svg = a["target"]["selector"]["value"]
    pts = [tuple(map(float, p.split(","))) for p in re.search(r'points="([^"]+)"', svg).group(1).split()]
    feats = a["body"]["features"]
    px = np.array([g["properties"]["resourceCoords"] for g in feats], float)
    ll = np.array([g["geometry"]["coordinates"] for g in feats], float)
    return dict(id=src["id"], w=src["width"], h=src["height"], label=src["partOf"][0]["id"].rsplit("/", 1)[-1][:8],
                mask=pts, px=px, ll=ll, canvas=src["partOf"][0]["id"])

S = [parse(a) for a in ITEMS]
lat0 = np.mean([s["ll"][:, 1].mean() for s in S]); lon0 = np.mean([s["ll"][:, 0].mean() for s in S])
K = 6378137 * math.pi / 180
def world(ll): return np.c_[(ll[:, 0] - lon0) * K * math.cos(math.radians(lat0)), (ll[:, 1] - lat0) * K]
for s in S:
    A = np.c_[s["px"], np.ones(len(s["px"]))]
    s["fwd"], *_ = np.linalg.lstsq(A, world(s["ll"]), rcond=None)            # px -> world
    W = np.c_[world(s["ll"]), np.ones(len(s["ll"]))]
    s["inv"], *_ = np.linalg.lstsq(W, s["px"], rcond=None)                   # world -> px
    s["gsd"] = math.sqrt(abs(np.linalg.det(s["fwd"][:2])))
    s["poly"] = Polygon(np.c_[s["mask"], np.ones(len(s["mask"]))] @ s["fwd"])

def crop(s, poly):
    pts = np.c_[np.array(poly.exterior.coords), np.ones(len(poly.exterior.coords))] @ s["inv"]
    x0, y0 = np.maximum(pts.min(0), 0); x1, y1 = np.minimum(pts.max(0), [s["w"], s["h"]])
    x0, y0, x1, y1 = map(int, (x0, y0, x1, y1))
    f = s["gsd"] / GSD  # output px per canvas px
    size = max(1, int((x1 - x0) * f))
    url = f'{s["id"]}/{x0},{y0},{x1 - x0},{y1 - y0}/{size},/0/default.jpg'
    img = cv2.imdecode(np.frombuffer(urllib.request.urlopen(url).read(), np.uint8), cv2.IMREAD_GRAYSCALE)
    sx = (x1 - x0) / img.shape[1]; sy = (y1 - y0) / img.shape[0]
    return img, lambda p: np.c_[x0 + p[:, 0] * sx, y0 + p[:, 1] * sy]

def render(s, x0w, y1w, cols, rows):
    """Sheet s on the ground grid (GSD m/px, top-left at x0w,y1w) + its mask."""
    # grid (c, r) -> world (x0w + c*GSD, y1w - r*GSD) -> canvas px
    G = np.array([[GSD, 0], [0, -GSD], [x0w, y1w]])
    C = np.c_[G, [0, 0, 1]] @ s["inv"]          # 3x2: [c r 1] -> canvas (u, v)
    corners = np.array([[0, 0, 1], [cols, 0, 1], [0, rows, 1], [cols, rows, 1]]) @ C
    x0, y0 = np.maximum(corners.min(0), 0); x1, y1 = np.minimum(corners.max(0), [s["w"], s["h"]])
    x0, y0, x1, y1 = map(int, (x0, y0, x1, y1))
    if x1 - x0 < 10 or y1 - y0 < 10:
        return None, None
    size = max(1, int((x1 - x0) * s["gsd"] / GSD))
    url = f'{s["id"]}/{x0},{y0},{x1 - x0},{y1 - y0}/{size},/0/default.jpg'
    img = cv2.imdecode(np.frombuffer(urllib.request.urlopen(url).read(), np.uint8), cv2.IMREAD_GRAYSCALE)
    sx = img.shape[1] / (x1 - x0); sy = img.shape[0] / (y1 - y0)
    # [c r 1] -> crop image px
    M = (C - np.array([[0, 0], [0, 0], [x0, y0]])) * [sx, sy]
    warped = cv2.warpAffine(img, M.T.astype(np.float32), (cols, rows), flags=cv2.INTER_LINEAR | cv2.WARP_INVERSE_MAP, borderValue=255)
    mask = np.zeros((rows, cols), np.uint8)
    poly = np.array(s["poly"].exterior.coords)
    cv2.fillPoly(mask, [np.int32(np.c_[(poly[:, 0] - x0w) / GSD, (y1w - poly[:, 1]) / GSD])], 1)
    return warped, mask

T, R = 64, int(GATE / GSD)    # template size (16 m), search radius (px)
out = []
for a, b in itertools.combinations(S, 2):
    if a["canvas"] == b["canvas"]:
        continue
    ov = a["poly"].intersection(b["poly"])
    if ov.is_empty or ov.area < 200:  # m^2
        continue
    x0w, y0w, x1w, y1w = ov.bounds
    cols, rows = int((x1w - x0w) / GSD), int((y1w - y0w) / GSD)
    ia, mka = render(a, x0w, y1w, cols, rows); ib, mkb = render(b, x0w, y1w, cols, rows)
    if ia is None or ib is None:
        continue
    both = (mka & mkb).astype(bool)
    if DEBUG:
        vis = np.dstack([ia, ib, np.minimum(ia, ib)]); vis[~both] //= 2
        cv2.imwrite(f'{DEBUG}/{a["label"]}_{b["label"]}.jpg', vis)
    gaps, where = [], []
    for r in range(R, rows - T - R, T // 4):
        for c in range(R, cols - T - R, T // 4):
            if both[r:r + T, c:c + T].mean() < 0.6:
                continue
            tpl = np.where(both[r:r + T, c:c + T], ia[r:r + T, c:c + T], 255).astype(np.uint8)
            ink = (tpl < 140).astype(np.float32)
            if ink.mean() < 0.01:
                continue
            gx = cv2.Sobel(ink, cv2.CV_32F, 1, 0); gy = cv2.Sobel(ink, cv2.CV_32F, 0, 1)
            J = np.array([[(gx * gx).sum(), (gx * gy).sum()], [(gx * gy).sum(), (gy * gy).sum()]])
            ev = np.linalg.eigvalsh(J)
            if ev[0] < 0.2 * ev[1]:   # 1-D structure (a lone street line): slides
                continue
            win = ib[r - R:r + T + R, c - R:c + T + R]
            res = cv2.matchTemplate(win, tpl, cv2.TM_CCOEFF_NORMED)
            _, peak, _, (px, py) = cv2.minMaxLoc(res)
            res2 = res.copy(); cv2.circle(res2, (px, py), 6, -1, -1)
            edge = min(px, py, res.shape[1] - 1 - px, res.shape[0] - 1 - py) < 3
            if peak < 0.5 or edge or res2.max() > peak - 0.1:
                continue
            gaps.append(math.hypot(px - R, py - R) * GSD)
            where.append((x0w + (c + T / 2) * GSD, y1w - (r + T / 2) * GSD))
    tag = f'{a["label"]} | {b["label"]}: overlap {ov.area:.0f} m2'
    if len(gaps) < 3:
        print(f"{tag}, {len(gaps)} usable patches (too few)"); continue
    out.append(np.median(gaps))
    print(f"{tag}, {len(gaps)} patches, seam gap median {np.median(gaps):.1f} m, p90 {np.percentile(gaps, 90):.1f} m")
    if DEBUG:
        print("   ", [round(g, 1) for g in gaps])
if out:
    print(f"SEAMS: n={len(out)} median={np.median(out):.1f} m max={max(out):.1f} m")
else:
    print("SEAMS: none")
