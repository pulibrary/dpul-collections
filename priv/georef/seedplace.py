"""Seed placement of a declined part (image comparison, no VLM): one junction seed and the labels of its
two streets.

A declined part often has a junction seed (an OCR'd pair of crossing street names found in OSM) but too
few other labels for a fit. The seed fixes one point; the scale is printed or the atlas's; the rotation is
swept 0..358 by 2 deg. Each rotation is scored by the corridor fraction (modern centrelines in printed
street corridors), the 6 best distinct rotations are aligned (align.py: corridors + the two streets'
labels) and scored by corridor contrast. Accepted only when the best candidate
  - has contrast >= MIN_CONTRAST and leads every other candidate by >= MIN_MARGIN,
  - puts >= 2 labels on their streets (8 m) with the text running along the street (20 deg), none across,
  - and no other candidate with agreeing labels reaches AMBIGUOUS (a straight crossing is symmetric:
    turned 180 deg, both labels still lie on their streets).
Leave-one-out on 127 fitted parts (held-out sample, 15-atlas batch, Princeton 1911/1918), each placed from
one seed and only its two streets' labels: 65 placed, 0 wrong, all within 15 m of the full fit.

usage: seedplace.py INPUT.json -> JSON {"t": {...} | null, "contrast", "rival", "why"}
INPUT (Georef.Py): {"image", "width", "mask", "seeds": [{"px", "xy", "keys"}], "scales": [m/px],
                    "labels": [{"key", "px", "angle"}], "streets", "osm", "projection"}
"""
import sys, os, json, math
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from corridor import Osm, Sheet, fwd, rot  # noqa: E402
import align as al  # noqa: E402

MIN_CONTRAST = 0.15
MIN_MARGIN = 0.05
AMBIGUOUS = 0.1
TOP = 6


def agree(T, labs, osm):
    """labels on their street (8 m) whose text runs along it (20 deg) / across it"""
    ok = bad = 0
    for l in labs:
        if l.get("angle") is None or l["key"] not in osm.by_key:
            continue
        d, F, dd = osm.nearest(l["key"], fwd(T, np.array([l["px"]], float)))
        if d[0] > 8:
            continue
        a = l["angle"]
        v = rot(T[1]) @ np.array([math.cos(a), -math.sin(a)])
        if abs(v[0] * dd[0][1] - v[1] * dd[0][0]) < math.sin(math.radians(20)):
            ok += 1
        else:
            bad += 1
    return ok, bad


def candidates(sheet, osm, seed, s, labels):
    px, xy = np.array(seed["px"], float), np.array(seed["xy"], float)
    labs = [l for l in labels if l["key"] in seed["keys"]]
    ranked = []
    for deg in range(0, 360, 2):
        th = math.radians(deg)
        T = (s, th, xy - fwd((s, th, np.zeros(2)), px[None])[0])
        ranked.append((al.corridor_fraction(sheet, osm, T), deg, T))
    ranked.sort(key=lambda x: -x[0])
    out = []
    for _, deg, T in ranked:
        if any(abs((deg - o["deg"] + 180) % 360 - 180) < 8 for o in out):
            continue
        T2, _ = al.align(sheet, osm, T, labs)
        T2 = T2 if T2 is not None else T
        out.append({"T": T2, "deg": deg, "contrast": al.contrast(sheet, osm, T2),
                    "agree": agree(T2, labs, osm), "c": fwd(T2, sheet.centre[None])[0]})
        if len(out) >= TOP:
            break
    return out


def main():
    inp = json.load(open(sys.argv[1]))
    osm = Osm(inp["streets"], inp["osm"], inp["projection"])
    sheet = Sheet(inp["image"], inp["width"], inp["mask"])
    cands = []
    for seed in inp["seeds"]:
        for s in inp["scales"]:
            cands += candidates(sheet, osm, seed, s, inp["labels"])
    # the same placement reached from two seeds is one candidate
    merged = []
    for c in sorted(cands, key=lambda c: -c["contrast"]):
        if not any(np.linalg.norm(c["c"] - m["c"]) < 40 for m in merged):
            merged.append(c)
    res = {"t": None, "contrast": None, "rival": None, "why": "no candidates"}
    if merged:
        b = merged[0]
        rival = merged[1]["contrast"] if len(merged) > 1 else -1.0
        res.update(contrast=b["contrast"], rival=rival)
        agrees = lambda c: c["agree"][0] >= 2 and c["agree"][1] == 0
        if b["contrast"] < MIN_CONTRAST:
            res["why"] = "low contrast"
        elif b["contrast"] - rival < MIN_MARGIN:
            res["why"] = "no margin"
        elif not agrees(b):
            res["why"] = f"labels {b['agree'][0]} along / {b['agree'][1]} across"
        elif any(agrees(c) and c["contrast"] >= AMBIGUOUS for c in merged[1:]):
            res["why"] = "symmetric"
        else:
            res.update(t=al.from_T(b["T"]), why="ok")
    print(json.dumps(res))


if __name__ == "__main__":
    main()
