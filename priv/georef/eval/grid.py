# usage: grid.py SERVICE CANVAS_W CANVAS_H OUT [x y w h] [size]
# Renders a IIIF region with a grid labelled in full-res canvas pixels.
import sys, io, urllib.request, math
from PIL import Image, ImageDraw, ImageFont
svc, W, H, out = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
if len(sys.argv) >= 9:
    x, y, w, h = map(int, sys.argv[5:9])
else:
    x, y, w, h = 0, 0, W, H
size = int(sys.argv[9]) if len(sys.argv) >= 10 else 1400
w = min(w, W - x); h = min(h, H - y)
url = f"{svc}/{x},{y},{w},{h}/!{size},{size}/0/default.jpg"
img = Image.open(io.BytesIO(urllib.request.urlopen(url).read())).convert("RGB")
s = img.width / w
d = ImageDraw.Draw(img)
# grid step: aim ~10 lines
raw = max(w, h) / 10
step = 10 ** math.floor(math.log10(raw)); step = min([step, 2*step, 5*step, 10*step], key=lambda v: abs(v-raw))
font = ImageFont.load_default(size=14)
gx = math.ceil(x / step) * step
while gx < x + w:
    px = (gx - x) * s; d.line([(px, 0), (px, img.height)], fill=(255, 0, 0), width=1); d.text((px + 2, 2), str(int(gx)), fill=(255, 0, 0), font=font)
    gx += step
gy = math.ceil(y / step) * step
while gy < y + h:
    py = (gy - y) * s; d.line([(0, py), (img.width, py)], fill=(0, 0, 255), width=1); d.text((2, py + 2), str(int(gy)), fill=(0, 0, 255), font=font)
    gy += step
img.save(out, quality=88)
print(out, img.size, "step", step)
