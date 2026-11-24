# usage: labelfree.py OUTDIR   (expects <name>.report.json / <name>.json / <name>.seams per atlas)
# Label-free quality signals across many atlases, no hand-labelled truth needed:
#  * status: how many sheet parts were georeferenced vs declined
#  * label fraction: share of printed street names that land on their modern street
#  * implied scan DPI: printed "N ft to an inch" / fitted m-per-px. Every sheet
#    of an atlas is scanned alike, so a fit whose DPI disagrees with its
#    siblings has the wrong scale (or the scale text was misread)
#  * seam gap: from seams.py, where neighbouring sheets overlap
import sys, json, glob, os, re, statistics as st
d = sys.argv[1]
rows = []
for rep in sorted(glob.glob(f"{d}/*.report.json")):
    name = os.path.basename(rep)[:-len(".report.json")]
    r = json.load(open(rep))
    parts = r["canvases"]
    dpis = {}
    for p in parts:
        if p["status"] == "ok" and p.get("printed_scale_ft") and p.get("scale_m_per_px"):
            dpis[p["label"]] = p["printed_scale_ft"] * 0.3048 / p["scale_m_per_px"]
    med = st.median(dpis.values()) if dpis else None
    seams = open(f"{d}/{name}.seams").read() if os.path.exists(f"{d}/{name}.seams") else ""
    print(f"== {name}: {r['label']}")
    for p in parts:
        lab = len(p["labels"]); hits = p.get("label_hits")
        dpi = dpis.get(p["label"])
        flag = " <-- DPI off" if dpi and med and abs(dpi / med - 1) > 0.05 else ""
        print(f"  {p['label']:<28} {p['status']:<6} labels {hits}/{lab}  scale {p.get('printed_scale_ft')} ft/in"
              + (f"  dpi {dpi:.0f}" if dpi else "") + flag)
        rows.append(dict(atlas=name, ok=p["status"] == "ok", frac=(hits or 0) / lab if lab else 0, dpi_off=bool(flag)))
    for line in seams.strip().splitlines():
        print("  seam", line)
ok = [r for r in rows if r["ok"]]
print(f"\nTOTAL parts {len(rows)}: georeferenced {len(ok)}, declined {len(rows) - len(ok)}; "
      f"DPI outliers {sum(r['dpi_off'] for r in ok)}; median label fraction (ok) "
      f"{st.median([r['frac'] for r in ok]) if ok else 0:.2f}")
