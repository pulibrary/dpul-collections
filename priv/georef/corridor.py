"""Shared geometry for the georeferencing Python helpers (slide.py, neighbour.py).

Transform convention: world (m, east/north) = s * R(th) @ [x, -y] + t  (x, y canvas px),
i.e. Georef.Geometry's {a, b} = s * {cos th, sin th}.
  * Osm: named street segments by key (from the caller) + every drawn street and railway of the
    extract, sampled every 3 m, for the corridor score.
  * Sheet: the part's ink / distance maps; corridor(T, osm) scores how well modern centrelines
    fall into printed street corridors under T.
  * snap: point-to-line least squares of labels onto their streets, with caller-supplied priors.
"""
import json, math
import numpy as np, cv2
from scipy.spatial import cKDTree


DRAWN = {"residential", "primary", "secondary", "tertiary", "unclassified", "living_street", "trunk",
         "primary_link", "secondary_link", "tertiary_link", "road"}


def rot(th):
    c, s = math.cos(th), math.sin(th)
    return np.array([[c, -s], [s, c]])


def fwd(T, px):  # canvas -> world
    s, th, t = T
    return s * np.c_[px[:, 0], -px[:, 1]] @ rot(th).T + t


def inv(T, w):  # world -> canvas
    s, th, t = T
    q = (w - t) @ rot(th) / s
    return np.c_[q[:, 0], -q[:, 1]]


def sample(a, b, step):
    n = int(np.linalg.norm(b - a) / step) + 1
    return a + np.linspace(0, 1, n, endpoint=False)[:, None] * (b - a)


class Osm:
    """Named streets (segments by key, from the caller) + every drawn street and railway (for corridors)."""

    def __init__(self, streets, path, proj):
        self.by_key = {k: np.array(v, float).reshape(-1, 4) for k, v in streets.items() if v}
        P = lambda ll: np.c_[(ll[:, 0] - proj["lon0"]) * proj["kx"], (ll[:, 1] - proj["lat0"]) * proj["ky"]]
        samp, nrm, rail = [], [], []
        for line in open(path):
            f = json.loads(line)
            p, g = f["properties"], f["geometry"]
            if g["type"] != "LineString":
                continue
            w = P(np.array(g["coordinates"], float))
            if p.get("railway") in ("rail", "abandoned", "disused", "razed"):
                rail += [sample(a, b, 3.0) for a, b in zip(w[:-1], w[1:])]
            if p.get("highway") in DRAWN:
                for a, b in zip(w[:-1], w[1:]):
                    L = np.linalg.norm(b - a)
                    if L < 1e-6:
                        continue
                    s = sample(a, b, 3.0)
                    samp.append(s)
                    nrm.append(np.repeat([[-(b - a)[1] / L, (b - a)[0] / L]], len(s), 0))
        self.samp, self.nrm = np.concatenate(samp), np.concatenate(nrm)
        self.tree = cKDTree(self.samp)
        self.rail = np.concatenate(rail) if rail else np.zeros((0, 2))
        self.rtree = cKDTree(self.rail) if rail else None

    def nearest(self, key, pts):
        """distance, foot point and unit direction of the nearest segment of street `key`, per point."""
        S = self.by_key[key]
        A, B = S[:, :2], S[:, 2:]
        d = B - A
        L2 = np.maximum((d ** 2).sum(1), 1e-9)
        u = np.clip(((pts[:, None, :] - A[None]) * d[None]).sum(2) / L2[None], 0, 1)
        F = A[None] + u[..., None] * d[None]
        D = np.linalg.norm(pts[:, None, :] - F, axis=2)
        i = D.argmin(1)
        r = np.arange(len(pts))
        return D[r, i], F[r, i], d[i] / np.sqrt(L2[i])[:, None]


class Sheet:
    def __init__(self, image, width, mask):
        self.img = cv2.imread(image)
        self.f = self.img.shape[1] / width
        self.mask_poly = np.array(mask, float)
        hsv = cv2.cvtColor(self.img, cv2.COLOR_BGR2HSV)
        g = hsv[..., 2].astype(np.int16)
        ink = (g < cv2.blur(g, (31, 31)) - 25) | (g < 110) | (hsv[..., 1] > 70)
        # dilated so probes can't skip thin lines
        self.inkd = cv2.dilate(ink.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)
        self.dt = cv2.distanceTransform((~ink).astype(np.uint8), cv2.DIST_L2, 5)  # image px
        m = np.zeros(ink.shape, np.uint8)
        cv2.fillPoly(m, [np.int32(self.mask_poly * self.f)], 1)
        self.mask = cv2.erode(m, np.ones((15, 15), np.uint8)).astype(bool)
        self.centre = self.mask_poly.mean(0)
        self.radius = np.linalg.norm(self.mask_poly - self.centre, axis=1).max()

    def corridor(self, T, osm):
        """(good, bad) metres of modern drawn-street centreline (and railway) inside the mask: good = in a
        printed street corridor (no ink under it, ink both sides, 9..36 m apart); bad = otherwise."""
        s = T[0]
        wc = fwd(T, self.centre[None])[0]
        idx = osm.tree.query_ball_point(wc, self.radius * s + 20)
        if not idx:
            return 0.0, 0.0
        H, Wd = self.inkd.shape
        p = inv(T, osm.samp[idx]) * self.f
        n = osm.nrm[idx] @ rot(T[1])  # normals into the canvas frame
        pi = np.round(p).astype(int)
        ok = (pi[:, 0] >= 0) & (pi[:, 0] < Wd) & (pi[:, 1] >= 0) & (pi[:, 1] < H)
        pi, p, n = pi[ok], p[ok], n[ok]
        ok = self.mask[pi[:, 1], pi[:, 0]]
        pi, p, n = pi[ok], p[ok], n[ok]
        if len(p) == 0:
            return 0.0, 0.0
        n = np.c_[n[:, 0], -n[:, 1]]  # canvas y is down
        mpp = s / self.f  # metres per image px
        free = self.dt[pi[:, 1], pi[:, 0]] * mpp >= 2.5
        offs = np.arange(1.0, 26.0, 0.5)
        first, known = [], np.ones(len(p), bool)
        for sg in (1, -1):
            q = np.round(p[:, None, :] + sg * (offs / mpp)[None, :, None] * n[:, None, :]).astype(int)
            q[..., 0] = q[..., 0].clip(0, Wd - 1)
            q[..., 1] = q[..., 1].clip(0, H - 1)
            hit = self.inkd[q[..., 1], q[..., 0]]
            first.append(np.where(hit.any(1), offs[hit.argmax(1)], 99.0))
            known &= self.mask[q[:, -1, 1], q[:, -1, 0]]  # probe left the part: no evidence
        w = first[0] + first[1]
        good = free & (first[0] < 90) & (first[1] < 90) & (w >= 9) & (w <= 36) & known
        bad = known & ~good
        rg = rb = 0
        if osm.rtree is not None:
            ri = osm.rtree.query_ball_point(wc, self.radius * s + 20)
            if ri:
                rp = np.round(inv(T, osm.rail[ri]) * self.f).astype(int)
                ok = (rp[:, 0] >= 0) & (rp[:, 0] < Wd) & (rp[:, 1] >= 0) & (rp[:, 1] < H)
                rp = rp[ok]
                rp = rp[self.mask[rp[:, 1], rp[:, 0]]]
                near = self.dt[rp[:, 1], rp[:, 0]] * mpp <= 3.0  # printed track within 3 m
                rg, rb = int(near.sum()), int((~near).sum())
        return 3.0 * (good.sum() + 2 * rg), 3.0 * (bad.sum() + 2 * rb)


def snap(T, px, keys, osm, priors, iters=6):
    """Point-to-line least squares over x = (log s, th, tx, ty): each point px[i] is pulled onto the
    nearest segment (within 25 m) of street keys[i]; priors(x, T) returns extra residual rows (the
    caller's pulls on scale, rotation, translation)."""
    x = np.array([math.log(T[0]), T[1], *T[2]])
    unpack = lambda x: (math.exp(x[0]), x[1], x[2:4])
    for _ in range(iters):
        w = fwd(unpack(x), px)
        foots = []
        for k in sorted(set(keys)):  # sorted: set order varies per process (hash seed)
            ii = [i for i, kk in enumerate(keys) if kk == k]
            d, F, dd = osm.nearest(k, w[ii])
            foots += [(i, F[j], np.array([-dd[j][1], dd[j][0]])) for j, i in enumerate(ii) if d[j] < 25]

        def resid(x):
            T_ = unpack(x)
            w = fwd(T_, px)
            return np.array([nn @ (w[i] - F) for i, F, nn in foots] + priors(x, T_))

        r0 = resid(x)
        J = np.zeros((len(r0), 4))
        for j, eps in enumerate([1e-5, 1e-5, 1e-3, 1e-3]):
            x1 = x.copy()
            x1[j] += eps
            J[:, j] = (resid(x1) - r0) / eps
        dx = np.linalg.lstsq(J, -r0, rcond=None)[0]
        x = x + dx
        if np.abs(dx[2:]).max() < 0.05:
            break
    return unpack(x)
