"""Neatline (the printed border around the map drawing) by image processing (replaces asking the VLM).

usage: neatline_cv.py IMAGE [CANVAS_W CANVAS_H]  -> JSON {"corners": [[x, y] x4] (TL, TR, BR, BL), "sides": [...]}
corners in canvas px when CANVAS_W/H are given (else image px).

On each side, look in the outer band of the sheet for a long, thin, nearly axis-parallel dark line
(the neatline is a ruled line; the scanner background is a solid dark area, not a line) and take the
outermost one; a side with none (Princeton scans are cropped at the drawing) uses the image edge.
The corners are the intersections of the four side lines.
"""
import sys, json, math
import numpy as np, cv2

BAND = 0.085         # search this share of the sheet in from each edge (real margins: <= 8 %)
MIN_LEN = 0.45       # a neatline runs at least this share of the side
MAX_TILT = math.radians(3)
MARGIN_INK = 0.02
CONTENT_START = 0.01  # smoothed ink share where the drawing starts (blank paper is ~0)    # share of ink/colour pixels allowed in the margin beyond a border

def side_lines(thin, horizontal):
    h, w = thin.shape
    L = w if horizontal else h
    segs = cv2.HoughLinesP(thin * 255, 1, np.pi / 720, threshold=int(0.15 * L),
                           minLineLength=int(0.10 * L), maxLineGap=int(0.02 * L))
    out = []
    for x1, y1, x2, y2 in ([] if segs is None else segs.reshape(-1, 4)):
        ang = math.atan2(y2 - y1, x2 - x1)
        tilt = abs(math.sin(ang)) if horizontal else abs(math.cos(ang))
        if tilt <= math.sin(MAX_TILT): out.append((x1, y1, x2, y2))
    return out

def merge(lines, horizontal, L):
    """collinear segments -> (offset, angle, covered length): offset = mean y (h) or x (v)"""
    groups = []
    for x1, y1, x2, y2 in lines:
        off = (y1 + y2) / 2 if horizontal else (x1 + x2) / 2
        span = (min(x1, x2), max(x1, x2)) if horizontal else (min(y1, y2), max(y1, y2))
        for g in groups:
            if abs(g["off"] - off) <= 4:
                g["spans"].append(span); g["segs"].append((x1, y1, x2, y2)); break
        else:
            groups.append({"off": off, "spans": [span], "segs": [(x1, y1, x2, y2)]})
    for g in groups:
        cov = 0; end = -1
        for a, b in sorted(g["spans"]):
            if b > end: cov += b - max(a, end); end = b
        g["cov"] = cov / L
    return [g for g in groups if g["cov"] >= MIN_LEN]

def fit_line(segs):
    pts = np.array([[x, y] for x1, y1, x2, y2 in segs for x, y in ((x1, y1), (x2, y2))], np.float32)
    vx, vy, x0, y0 = cv2.fitLine(pts, cv2.DIST_L2, 0, 0.01, 0.01).ravel()
    return (float(x0), float(y0), float(vx), float(vy))

def intersect(l1, l2):
    x1, y1, dx1, dy1 = l1; x2, y2, dx2, dy2 = l2
    d = dx1 * dy2 - dy1 * dx2
    t = ((x2 - x1) * dy2 - (y2 - y1) * dx2) / d
    return [x1 + t * dx1, y1 + t * dy1]

def detect(gray, bgr=None):
    h, w = gray.shape
    bg = cv2.medianBlur(gray, 41)
    dark = ((bg.astype(np.int16) - gray > 35) | (gray < 90)).astype(np.uint8)
    # drop thick dark areas (scanner background, solid fills): keep strokes <= ~6 px
    thick = cv2.dilate(cv2.morphologyEx(dark, cv2.MORPH_OPEN, np.ones((9, 9), np.uint8)), np.ones((5, 5), np.uint8))
    thin = dark & (1 - thick)
    # content: thin ink, plus coloured fills (building colours) when colour is available
    content = thin.astype(np.float32)
    if bgr is not None:
        sat = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)[..., 1]
        content = np.maximum(content, (sat > 90).astype(np.float32) * (1 - thick))
    edges = {"top": (0.0, 0.0, 1.0, 0.0), "bottom": (0.0, h - 1.0, 1.0, 0.0),
             "left": (0.0, 0.0, 0.0, 1.0), "right": (w - 1.0, 0.0, 0.0, 1.0)}
    found = {}
    for side in ("top", "bottom", "left", "right"):
        horizontal = side in ("top", "bottom")
        L = w if horizontal else h; D = h if horizontal else w
        band = np.zeros_like(thin)
        b = int(BAND * D)
        if side == "top": band[:b, :] = thin[:b, :]
        if side == "bottom": band[h - b:, :] = thin[h - b:, :]
        if side == "left": band[:, :b] = thin[:, :b]
        if side == "right": band[:, w - b:] = thin[:, w - b:]
        groups = merge(side_lines(band, horizontal), horizontal, L)
        # a border has margin beyond it: little ink or colour between it and the edge (an
        # interior street, rail or part rule has map on both sides)
        def margin_ok(g):
            o = int(round(g["off"]))
            if side == "top": strip = content[: max(o - 6, 0), :]
            elif side == "bottom": strip = content[o + 7:, :]
            elif side == "left": strip = content[:, : max(o - 6, 0)]
            else: strip = content[:, o + 7:]
            return strip.size == 0 or strip.mean() < MARGIN_INK
        groups = [g for g in groups if margin_ok(g)]
        if not groups:
            # no ruled border: trim blank paper up to where the drawing starts (LoC scans keep
            # a margin; Princeton scans are cropped at the drawing, so nothing is trimmed)
            prof = content.mean(axis=1 if horizontal else 0)
            win = max(3, int(0.01 * D))
            prof = np.convolve(prof, np.ones(win) / win, mode="same")
            idx = range(int(BAND * D)) if side in ("top", "left") else range(D - 1, D - 1 - int(BAND * D), -1)
            start = next((i for i in idx if prof[i] > CONTENT_START), None)
            if start is None: continue
            pad = int(0.005 * D)
            off = max(start - pad, 0) if side in ("top", "left") else min(start + pad, D - 1)
            found[side] = ((0.0, float(off), 1.0, 0.0) if horizontal else (float(off), 0.0, 0.0, 1.0), 0.0)
            continue
        outer = min(groups, key=lambda g: g["off"]) if side in ("top", "left") else max(groups, key=lambda g: g["off"])
        width = (outer["off"] if side in ("top", "left") else D - outer["off"]) / D
        found[side] = (fit_line(outer["segs"]), round(width, 3))
    lines = {s: (found[s][0] if s in found else edges[s]) for s in edges}
    corners = [intersect(lines["top"], lines["left"]), intersect(lines["top"], lines["right"]),
               intersect(lines["bottom"], lines["right"]), intersect(lines["bottom"], lines["left"])]
    corners = [[min(max(x, 0), w - 1), min(max(y, 0), h - 1)] for x, y in corners]
    return corners, {s: round(found[s][1], 2) for s in found}

if __name__ == "__main__":
    bgr = cv2.imread(sys.argv[1]); img = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    corners, sides = detect(img, bgr)
    if len(sys.argv) > 3:
        k = int(sys.argv[2]) / img.shape[1]; corners = [[x * k, y * k] for x, y in corners]
    print(json.dumps({"corners": corners, "sides": sides}))
