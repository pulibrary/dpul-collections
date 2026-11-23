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
for x1, y1, x2, y2 in ([] if segs is None else segs.reshape(-1, 4)):
    cv2.line(rules, (int(x1), int(y1)), (int(x2), int(y2)), 1, k)

page = np.zeros_like(heavy)
cv2.fillPoly(page, [neat_px], 1)
# Rules often stop just short of the border; split inside a slightly shrunk
# page, then grow each part back out to the full page.
m = int(0.025 * max(w, h))
inner = cv2.erode(page, cv2.getStructuringElement(cv2.MORPH_RECT, (2 * m + 1, 2 * m + 1)), borderType=cv2.BORDER_CONSTANT, borderValue=0)
rules = cv2.dilate(rules, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k)))
free = (inner & (1 - rules)).astype(np.uint8)
import os
if os.environ.get("GEOREF_DEBUG"):
    dbg = cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)
    dbg[rules > 0] = (0, 0, 255)
    dbg[(inner == 0) & (page > 0)] = (dbg[(inner == 0) & (page > 0)] * 0.5).astype(np.uint8)
    cv2.imwrite(os.environ["GEOREF_DEBUG"], cv2.resize(dbg, None, fx=0.5, fy=0.5))
n, lab, stats, _ = cv2.connectedComponentsWithStats(free, 4)
parts = []
for i in sorted(range(1, n), key=lambda i: -stats[i, cv2.CC_STAT_AREA]):
    if stats[i, cv2.CC_STAT_AREA] < 0.08 * page.sum():
        continue
    region = (lab == i).astype(np.uint8)
    region = cv2.dilate(region, cv2.getStructuringElement(cv2.MORPH_RECT, (2 * m + 1, 2 * m + 1))) & page
    region = cv2.morphologyEx(region, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k * 2, k * 2)))
    cs, _ = cv2.findContours(region, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    c = max(cs, key=cv2.contourArea)
    poly = cv2.approxPolyDP(c, 0.004 * max(w, h), True)[:, 0, :]
    parts.append([[float(x / s), float(y / s)] for x, y in poly])
print(json.dumps({"parts": parts, "rules": nrules}))
