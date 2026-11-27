// OCR tokens -> street-name labels: matching words to the town's modern street names (normalize
// is shared with the server, lib/dpul_collections/georef/osm.ex), letter-spaced names, tiles,
// library stamps and the title's town name. Tokens: {text, score, quad, center: [x, y], angle, height}
// in canvas pixels.

const SUFFIXES = new Set(("street st avenue ave av road rd lane ln drive dr boulevard blvd place pl court ct way " +
  "alley aly terrace ter pike turnpike highway hwy parkway pkwy circle cir square sq row").split(" "));
const DIRECTIONS = new Set("north south east west n s e w".split(" "));
const ORDINALS = { first: "1st", second: "2nd", third: "3rd", fourth: "4th", fifth: "5th", sixth: "6th",
  seventh: "7th", eighth: "8th", ninth: "9th", tenth: "10th", eleventh: "11th", twelfth: "12th" };

const MIN_STREET_NAME_PX = 100;
const MIN_TILE_NAME_PX = 78;

/** Osm.normalize: "N. Delaware St." -> "delaware", "Second Avenue" -> "2nd" */
export function normalize(name) {
  let words = name.toLowerCase()
    .replace(/['’]s\b/gu, "s")
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .replace(/\brail\s+road\b/g, "railroad")
    .replace(/\br\s*r\b/g, "railroad")
    .split(/\s+/).filter(Boolean)
    .map((w) => ORDINALS[w] || w)
    .map((w) => (["rr", "ry", "railway"].includes(w) ? "railroad" : ["cr", "crk"].includes(w) ? "creek" : w));
  const dropWhile = (ws, set) => { let i = 0; while (i < ws.length && set.has(ws[i])) i++; return ws.slice(i); };
  const stripSuffix = (ws) => dropWhile(ws.slice().reverse(), SUFFIXES).reverse();
  // a leading "the" is filler: "The Terrace" is Terrace, and a bare "THE" names nothing
  words = dropWhile(words, new Set(["the"]));
  let t = dropWhile(stripSuffix(dropWhile(words, DIRECTIONS)).reverse(), DIRECTIONS).reverse();
  if (!t.length) t = stripSuffix(words); // "West Street" is a street named West
  return (t.length ? t : words).join(" ");
}

/** Jaro similarity (Elixir String.jaro_distance) */
function jaro(a, b) {
  if (a === b) return 1;
  const la = a.length, lb = b.length;
  if (!la || !lb) return 0;
  const win = Math.max(0, Math.floor(Math.max(la, lb) / 2) - 1);
  const ma = new Array(la).fill(false), mb = new Array(lb).fill(false);
  let m = 0;
  for (let i = 0; i < la; i++)
    for (let j = Math.max(0, i - win); j < Math.min(lb, i + win + 1); j++)
      if (!mb[j] && a[i] === b[j]) { ma[i] = mb[j] = true; m++; break; }
  if (!m) return 0;
  let t = 0, k = 0;
  for (let i = 0; i < la; i++) if (ma[i]) { while (!mb[k]) k++; if (a[i] !== b[k]) t++; k++; }
  return (m / la + m / lb + (m - t / 2) / m) / 3;
}

/** Osm.match_name: the gazetteer key best matching a name read off the map, or null */
export function matchName(keys, keySet, name) {
  const key = normalize(name);
  if (!key) return null;
  if (keySet.has(key)) return key;
  if (key.split(" ").every((w) => SUFFIXES.has(w))) return null;
  let best = null, bd = 0;
  for (const k of keys) {
    if (Math.abs(k.length - key.length) > 2) continue;
    const d = jaro(k, key);
    if (d >= 0.93 && d > bd) { bd = d; best = k; }
  }
  return best;
}

const ORDINAL = /^\s*\d{1,3}\s*(ST|ND|RD|TH)\.?\s*$/i;
const isOrdinal = (t) => ORDINAL.test(t);
const ordinalFix = (t) => t.replace(/^\s*(\d{1,3})\s*H\.?\s*$/i, "$1TH");
const indexEntry = (t) => /,|\.\./.test(t);
const BUILDING_WORDS = new Set(("church school mill hall hotel depot station market chapel academy factory college " +
  "cemetery bank mills red green blue yellow brown gray grey stone iron brick frame adobe metal slate garage stage " +
  "storage shed bridge scale sale wood pipe piper carriage division lumber coal yard ridge").split(" "));

function matchLabel(osm, text) {
  if (isOrdinal(text) || /^[A-Z] (ST|AV|AVE|RD|PL)\.?$/.test(text)) {
    const k = normalize(text);
    return osm.keySet.has(k) ? k : null;
  }
  return matchName(osm.keys, osm.keySet, text);
}

/** token from an OCR item (quad in image px) scaled by k and offset into canvas px (Ocr.to_tokens) */
export function toToken({ text, score, quad }, k = 1, dx = 0, dy = 0) {
  const q = quad.map(([x, y]) => [x * k + dx, y * k + dy]);
  const center = [q.reduce((a, p) => a + p[0], 0) / q.length, q.reduce((a, p) => a + p[1], 0) / q.length];
  const d = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);
  const height = q.length === 4 ? Math.min(d(q[0], q[3]), d(q[0], q[1])) : 0;
  const [a, b, c] = q, ax = b[0] - a[0], ay = b[1] - a[1], bx = c[0] - b[0], by = c[1] - b[1];
  const angle = ax * ax + ay * ay >= bx * bx + by * by ? Math.atan2(ay, ax) : Math.atan2(by, bx);
  return { text, score, quad: q, center, angle, height };
}

const SPACED_LETTER = /^\s*([A-Z])\.?\s*$/, SPACED_TYPE = /^\s*(ST|AV|AVE|RD|PL)\.?\s*$/i;
/** letter-spaced lettered streets: a lone letter + a type word on its line ("B      ST.") */
function spacedNames(tokens) {
  const types = tokens.filter((t) => SPACED_TYPE.test(t.text) && t.angle != null), out = [];
  for (const l of tokens) {
    const m = SPACED_LETTER.exec(l.text);
    if (!m || !(l.height > 0)) continue;
    for (const t of types) {
      const r = t.height / l.height;
      if (!(r >= 0.6 && r <= 1.6)) continue;
      const dx = t.center[0] - l.center[0], dy = t.center[1] - l.center[1];
      const along = dx * Math.cos(t.angle) + dy * Math.sin(t.angle), across = Math.abs(-dx * Math.sin(t.angle) + dy * Math.cos(t.angle));
      if (along > 0 && along <= 12 * l.height && across <= 0.5 * Math.max(l.height, t.height))
        out.push({ text: `${m[1]} ${t.text.trim().toUpperCase()}`, score: Math.min(l.score, t.score),
                   center: [l.center[0] + dx / 2, l.center[1] + dy / 2], angle: t.angle, height: Math.max(l.height, t.height) });
    }
  }
  return out;
}

/** OCR tokens that name a modern street / railway / waterway / building */
function ocrLabels(tokens, osm) {
  const out = [];
  for (const t of tokens.concat(spacedNames(tokens))) {
    if (t.score < 0.75) continue;
    const text = ordinalFix(t.text);
    if (!(isOrdinal(text) || text.replace(/[^\p{L}]/gu, "").length >= 3) || indexEntry(text)) continue;
    const key = matchLabel(osm, text);
    if (!key) continue;
    if (BUILDING_WORDS.has(key) && (t.height ?? MIN_STREET_NAME_PX) < MIN_STREET_NAME_PX) continue;
    out.push({ name: text, key, px: t.center, angle: t.angle, height: t.height, source: "ocr" });
  }
  return out;
}

const near = (a, b, r) => Math.hypot(a[0] - b[0], a[1] - b[1]) < r;

/** the whole sheet's labels plus tile-only ones (tall enough, not already read within 400 px),
 *  without stamp text and title lettering of the town's own name */
export function sheetLabels(wholeTokens, tileTokens, osm, excludeKeys) {
  const have = ocrLabels(wholeTokens, osm);
  const tiled = ocrLabels(tileTokens.filter((t) => t.height >= MIN_TILE_NAME_PX), osm)
    .filter((l) => !have.some((h) => h.key === l.key && near(h.px, l.px, 400)))
    .map((l) => ({ ...l, tiled: true }));
  const stamps = wholeTokens.filter((t) => /princeton|universit|librar|congress/i.test(t.text)).map((t) => t.center);
  const titles = wholeTokens.filter((t) => /\b1[89]\d\d\b|n\.\s*j|jersey|sanborn|population|water\s*fac|prevailing|scale/i.test(t.text)).map((t) => t.center);
  return have.concat(tiled)
    .filter((l) => !stamps.some((s) => near(s, l.px, 500)))
    .filter((l) => !(excludeKeys.includes(l.key) && (titles.some((s) => near(s, l.px, 700)) || (l.height || MIN_STREET_NAME_PX) < MIN_STREET_NAME_PX)));
}

/** tiles: 2400 px squares every 1800 px (the last flush with the edge), read at 1536 px */
export const TILE = 2400, STRIDE = 1800;
export function tileStarts(n) {
  const s = [];
  for (let x = 0; x <= Math.max(n - TILE, 0); x += STRIDE) s.push(x);
  if (s[s.length - 1] + TILE < n) s.push(n - TILE);
  return s;
}

/** tokens cut by an inner tile edge are dropped (the overlap holds a whole copy) */
export function cutByTileEdge(t, [x0, y0, w, h], W, H) {
  const xs = t.quad.map((p) => p[0]), ys = t.quad.map((p) => p[1]);
  return (x0 > 0 && Math.min(...xs) < x0 + 5) || (y0 > 0 && Math.min(...ys) < y0 + 5) ||
    (x0 + w < W && Math.max(...xs) > x0 + w - 5) || (y0 + h < H && Math.max(...ys) > y0 + h - 5);
}

export function dedupeTiles(tokens) {
  const out = [];
  for (const t of tokens) if (!out.some((o) => o.text === t.text && near(o.center, t.center, 40))) out.push(t);
  return out;
}

export const suffixOnly = (key) => key.split(" ").every((w) => SUFFIXES.has(w));

/** the gazetteer the matcher needs, from the atlas OSM payload */
export function gazetteer(groups) {
  const keys = Object.keys(groups);
  return { keys, keySet: new Set(keys) };
}
