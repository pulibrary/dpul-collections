# usage: overlay.py REPORT.json ANNOTATION.json OSM.geojsonseq OUTDIR
# Draws modern OSM lines (red=street, blue=water, black dashed=rail) onto each
# georeferenced sheet through the inverse of the affine Allmaps would fit,
# plus GCPs (green) and the mask (magenta).
import sys, json, io, math, urllib.request, os
import numpy as np
from PIL import Image, ImageDraw
rep, ann, osm, out = json.load(open(sys.argv[1])), json.load(open(sys.argv[2])), sys.argv[3], sys.argv[4]
os.makedirs(out, exist_ok=True)
lines = []
for l in open(osm):
    f = json.loads(l); p = f["properties"]
    kind = "street" if "highway" in p else "rail" if "railway" in p else "water"
    lines.append((kind, f["geometry"]["coordinates"], p.get("name")))
by_id = {c["id"]: c for c in rep["canvases"]}  # any part's entry has the service
for ai, a in enumerate(ann["items"]):
    cid = a["target"]["source"]["partOf"][0]["id"]; c = by_id[cid]
    feats = a["body"]["features"]
    lon0 = np.mean([g["geometry"]["coordinates"][0] for g in feats]); lat0 = np.mean([g["geometry"]["coordinates"][1] for g in feats])
    k = 6378137 * math.pi / 180; kx = k * math.cos(math.radians(lat0))
    P = lambda ll: ((ll[0] - lon0) * kx, (ll[1] - lat0) * k)
    # affine world -> pixel (inverse direction fit directly)
    W = np.array([[*P(g["geometry"]["coordinates"]), 1.0] for g in feats]); U = np.array([g["properties"]["resourceCoords"] for g in feats], float)
    M, *_ = np.linalg.lstsq(W, U, rcond=None)
    size = 1600
    img = Image.open(io.BytesIO(urllib.request.urlopen(f"{c['service']}/full/!{size},{size}/0/default.jpg").read())).convert("RGB")
    s = img.width / c["width"]
    d = ImageDraw.Draw(img)
    col = {"street": (230, 0, 0), "water": (0, 90, 255), "rail": (0, 0, 0)}
    for kind, coords, name in lines:
        px = [tuple((np.array([*P(ll), 1.0]) @ M) * s) for ll in coords]
        if all(not (-200 < x < img.width + 200 and -200 < y < img.height + 200) for x, y in px): continue
        d.line(px, fill=col[kind], width=2)
    for g in feats:
        x, y = g["properties"]["resourceCoords"]; x *= s; y *= s
        d.ellipse([x - 7, y - 7, x + 7, y + 7], outline=(0, 170, 0), width=3)
    pts = [tuple(map(float, p.split(","))) for p in a["target"]["selector"]["value"].split('points="')[1].split('"')[0].split()]
    d.line([(x * s, y * s) for x, y in pts + pts[:1]], fill=(220, 0, 220), width=3)
    name = f"{out}/{ai:02d}_{(c['label'] or cid[-8:]).replace(' ', '_').replace('(', '').replace(')', '')}.jpg"
    img.save(name, quality=85); print(name)
