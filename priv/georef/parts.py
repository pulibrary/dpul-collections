"""Split a map sheet into parts separated by heavy rules.

Sanborn sheets separate areas that are not geographically continuous (insets,
detached properties, a second street drawn below) with heavy black lines, much
thicker than block outlines. Keep only thick + long ink, then take connected
regions of the remaining page as parts.

usage: parts.py IMAGE CANVAS_W CANVAS_H [x,y x,y ...]   (neatline polygon in canvas px)
-> JSON {"parts": [[[x, y], ...], ...], "rules": n}   polygons in canvas px, largest first
"""
import sys, json
import numpy as np, cv2

path, W, H = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
img = cv2.imread(path, cv2.IMREAD_GRAYSCALE)
h, w = img.shape
s = w / W  # image px per canvas px
neat = [tuple(map(float, p.split(","))) for p in sys.argv[4:]] or [(0, 0), (W, 0), (W, H), (0, H)]
neat_px = np.array([[x * s, y * s] for x, y in neat], np.int32)

# Smallest part kept, as a share of the page: boxed insets go down to ~4 % (Roebling 1928
# Sheet 3 school, Cranford Sheet 1 Springfield Av); legend boxes are not ruled heavily enough to split.
MIN_PART = 0.03

ink = (img < 140).astype(np.uint8)
# heavy rules are ~3-4x block-outline thickness; open with a disk wider than
# outlines and most lettering so only heavy strokes survive
k = max(3, int(round(21 * s)))
heavy = cv2.morphologyEx(ink, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k)))
# Long straight runs of heavy ink, joined across small gaps (a compass rose or
# a label drawn over the rule).
L = max(w, h)
segs = cv2.HoughLinesP(heavy * 255, 1, np.pi / 360, threshold=int(0.05 * L),
                       minLineLength=int(0.12 * L), maxLineGap=int(0.06 * L))
rules = np.zeros_like(heavy)
nrules = 0 if segs is None else len(segs)
seglist = [] if segs is None else [tuple(map(float, s_)) for s_ in segs.reshape(-1, 4)]
for x1, y1, x2, y2 in seglist:
    cv2.line(rules, (int(x1), int(y1)), (int(x2), int(y2)), 1, k)

# A compass rose or label printed over a rule leaves a gap wider than Hough
# bridges (Mullica Hill 1933 Sheet 1), and the free page leaks through it.
# Join endpoints of two rule segments when the gap is short and runs in line
# with both segments.
def _dir(x1, y1, x2, y2):
    d = np.hypot(x2 - x1, y2 - y1)
    return ((x2 - x1) / d, (y2 - y1) / d) if d else (0.0, 0.0)

def _aligned(u, v, tol=0.97):
    return abs(u[0] * v[0] + u[1] * v[1]) >= tol

for i, a in enumerate(seglist):
    da = _dir(*a)
    for b in seglist[i + 1:]:
        db = _dir(*b)
        if not _aligned(da, db, 0.95):
            continue
        for p in ((a[0], a[1]), (a[2], a[3])):
            for q in ((b[0], b[1]), (b[2], b[3])):
                gap = np.hypot(q[0] - p[0], q[1] - p[1])
                # longer gaps only between two long rules lying on one line (offset < k)
                la, lb = np.hypot(a[2] - a[0], a[3] - a[1]), np.hypot(b[2] - b[0], b[3] - b[1])
                off = abs((q[0] - p[0]) * da[1] - (q[1] - p[1]) * da[0])
                max_gap = 0.25 * L if min(la, lb) >= 0.12 * L and off < 2 * k else 0.10 * L
                if 0.01 * L < gap < max_gap and _aligned(_dir(p[0], p[1], q[0], q[1]), da):
                    cv2.line(rules, (int(p[0]), int(p[1])), (int(q[0]), int(q[1])), 1, k)

page = np.zeros_like(heavy)
cv2.fillPoly(page, [neat_px], 1)
# Rules often stop just short of the border; split inside a slightly shrunk
# page, then grow each part back out to the full page.
m = int(0.025 * max(w, h))
inner = cv2.erode(page, cv2.getStructuringElement(cv2.MORPH_RECT, (2 * m + 1, 2 * m + 1)), borderType=cv2.BORDER_CONSTANT, borderValue=0)
rules = cv2.dilate(rules, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k)))
# A rule that steps (jogs) from one line to a parallel one leaves the short
# connecting stroke undetected by Hough; add heavy ink touching a found rule.
nh, hl = cv2.connectedComponents(heavy)
touch = np.unique(hl[(rules > 0) & (heavy > 0)])
rules |= cv2.dilate(np.isin(hl, touch[touch > 0]).astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k)))
free = (inner & (1 - rules)).astype(np.uint8)
import os
if os.environ.get("GEOREF_DEBUG"):
    dbg = cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)
    dbg[rules > 0] = (0, 0, 255)
    dbg[(inner == 0) & (page > 0)] = (dbg[(inner == 0) & (page > 0)] * 0.5).astype(np.uint8)
    cv2.imwrite(os.environ["GEOREF_DEBUG"], cv2.resize(dbg, None, fx=0.5, fy=0.5))
n, lab, stats, _ = cv2.connectedComponentsWithStats(free, 4)
parts = []
big = [i for i in range(1, n) if stats[i, cv2.CC_STAT_AREA] >= MIN_PART * page.sum()]
nearest = np.zeros_like(lab)
if len(big) > 1:
    _, near_px = cv2.distanceTransformWithLabels((~np.isin(lab, big)).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
    ids = np.zeros(near_px.max() + 1, lab.dtype)
    ys, xs = np.nonzero(np.isin(lab, big)); ids[near_px[ys, xs]] = lab[ys, xs]
    nearest = ids[near_px]
else:
    nearest[:] = big[0] if big else 0
for i in sorted(range(1, n), key=lambda i: -stats[i, cv2.CC_STAT_AREA]):
    if stats[i, cv2.CC_STAT_AREA] < MIN_PART * page.sum():
        continue
    region = (lab == i).astype(np.uint8)
    region = cv2.dilate(region, cv2.getStructuringElement(cv2.MORPH_RECT, (2 * m + 1, 2 * m + 1))) & page
    # grow out to the page border but not into another part: each pixel goes to the nearest part core
    region &= (nearest == i).astype(np.uint8)
    region = cv2.morphologyEx(region, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k * 2, k * 2)))
    cs, _ = cv2.findContours(region, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    c = max(cs, key=cv2.contourArea)
    poly = cv2.approxPolyDP(c, 0.004 * max(w, h), True)[:, 0, :]
    parts.append([[float(x / s), float(y / s)] for x, y in poly])
print(json.dumps({"parts": parts, "rules": nrules}))
