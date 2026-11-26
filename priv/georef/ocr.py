"""Text detection + recognition for map sheets (PP-OCRv5 via RapidOCR/onnxruntime).

usage: ocr.py IMAGE [IMAGE ...]   -> JSON lines: {"image", "items": [{"text","score","quad"}]}
quad = 4 [x, y] points in the image's pixel space (clockwise from top-left of the text).

Two passes: the page as is, and rotated 90 degrees. Sanborn prints the names of
north-south streets vertically, and the recogniser reads those far better on a
rotated page (Vineland sheet 20: no vertical names upright, "S.3RD"/"S.4TH"
rotated). Rotated-pass reads of vertical text are kept when the upright pass
missed them or read them with a lower score.
"""
import sys, json
from PIL import Image
from rapidocr import RapidOCR

from rapidocr import ModelType, OCRVersion

# Detection: PP-OCRv5 mobile. Recognition: PP-OCRv6 small, which read 25 of 33
# street names the v5 recogniser missed vs 22 (benchmark of VLM-only labels,
# held-out sample), at ~1 s per 2400 px tile.
engine = RapidOCR(params={"Global.text_score": 0.5, "Det.limit_side_len": 4000, "Det.limit_type": "max",
                          "Rec.ocr_version": OCRVersion.PPOCRV6, "Rec.model_type": ModelType.SMALL})


def run(img):
    res = engine(img)
    if res.boxes is None:
        return []
    return [(text, float(score), [[float(x), float(y)] for x, y in quad])
            for quad, text, score in zip(res.boxes, res.txts, res.scores)]


def bbox(q):
    xs, ys = [p[0] for p in q], [p[1] for p in q]
    return min(xs), min(ys), max(xs), max(ys)


def overlaps(a, b):
    ax0, ay0, ax1, ay1 = bbox(a); bx0, by0, bx1, by1 = bbox(b)
    ix = max(0, min(ax1, bx1) - max(ax0, bx0)); iy = max(0, min(ay1, by1) - max(ay0, by0))
    small = min((ax1 - ax0) * (ay1 - ay0), (bx1 - bx0) * (by1 - by0)) or 1
    return ix * iy / small > 0.3


for path in sys.argv[1:]:
    page = Image.open(path).convert("RGB")
    w, h = page.size
    items = [{"text": t, "score": s, "quad": q} for t, s, q in run(path)]
    # clockwise 90: original (x, y) -> rotated (h-1-y, x); back: (u, v) -> (v, h-1-u)
    rot = page.rotate(-90, expand=True)
    for t, s, q in run(rot):
        back = [[v, h - 1 - u] for u, v in q]
        x0, y0, x1, y1 = bbox(back)
        if (y1 - y0) < 1.5 * (x1 - x0):
            continue  # not vertical text in the page frame
        clash = [it for it in items if overlaps(back, it["quad"])]
        # the upright pass often reads vertical text as junk; keep the better read
        if any(it["score"] >= s for it in clash):
            continue
        items = [it for it in items if it not in clash] + [{"text": t, "score": s, "quad": back}]
    print(json.dumps({"image": path, "width": w, "height": h, "items": items}), flush=True)
