"""Text detection + recognition for map sheets (PP-OCRv5 via RapidOCR/onnxruntime).

usage: ocr.py IMAGE [IMAGE ...]   -> JSON lines: {"image", "items": [{"text","score","quad"}]}
quad = 4 [x, y] points in the image's pixel space (clockwise from top-left of the text).
"""
import sys, json
from rapidocr import RapidOCR

engine = RapidOCR(params={"Global.text_score": 0.5, "Det.limit_side_len": 4000, "Det.limit_type": "max"})
for path in sys.argv[1:]:
    from PIL import Image
    w, h = Image.open(path).size
    res = engine(path)
    items = []
    if res.boxes is not None:
        for quad, text, score in zip(res.boxes, res.txts, res.scores):
            items.append({"text": text, "score": float(score), "quad": [[float(x), float(y)] for x, y in quad]})
    print(json.dumps({"image": path, "width": w, "height": h, "items": items}), flush=True)
