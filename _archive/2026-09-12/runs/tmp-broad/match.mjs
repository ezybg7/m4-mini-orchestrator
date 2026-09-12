const MATCH_THRESHOLD = 0.6;
const CANDIDATE_THRESHOLD = 0.4;
const COVERAGE_THRESHOLD = 0.6;
const UNIT_TOKEN = /^(\d+([./]\d+)?|oz|lb|lbs|g|kg|ml|l|ct|pk|pkg|pack|count|ea|x)$/;
function normalizeTokens(text) {
  return text.toLowerCase().replace(/[^a-z0-9]+/g, " ").split(/\s+/).filter((token) => token && !UNIT_TOKEN.test(token));
}
function tokenMatches(token, set) {
  if (set.has(token)) return true;
  if (set.has(`${token}s`) || set.has(`${token}es`)) return true;
  if (token.endsWith("es") && set.has(token.slice(0, -2))) return true;
  if (token.endsWith("s") && set.has(token.slice(0, -1))) return true;
  return false;
}
function score(query, target) {
  if (query.length === 0 || target.length === 0) return { dice: 0, coverage: 0 };
  const targetSet = new Set(target);
  const querySet = new Set(query);
  let queryHits = 0;
  for (const token of querySet) if (tokenMatches(token, targetSet)) queryHits += 1;
  let targetHits = 0;
  for (const token of targetSet) if (tokenMatches(token, querySet)) targetHits += 1;
  return {
    dice: (queryHits + targetHits) / (querySet.size + targetSet.size),
    coverage: queryHits / querySet.size
  };
}
function similarity(a, b) {
  return score(normalizeTokens(a), normalizeTokens(b)).dice;
}
function similarityScored(a, b) {
  return score(normalizeTokens(a), normalizeTokens(b));
}
const FUZZY_MAX_DISTANCE = 1;
const FUZZY_MIN_TOKEN_LENGTH = 5;
const FUZZY_MAX_OWNERS = 3;
const FUZZY_STOPWORDS = /* @__PURE__ */ new Set([
  "raw",
  "dry",
  "dried",
  "cooked",
  "uncooked",
  "fresh",
  "frozen",
  "canned",
  "bottled",
  "jar",
  "jars",
  "can",
  "cans",
  "box",
  "bag",
  "packaged",
  "commercial",
  "commercially",
  "homemade",
  "sliced",
  "slice",
  "whole",
  "half",
  "halves",
  "ground",
  "chopped",
  "minced",
  "shredded",
  "smoked",
  "cured",
  "hot",
  "cold",
  "solid",
  "liquid",
  "powder",
  "powdered",
  "instant",
  "plain",
  "baked",
  "roasted",
  "boneless",
  "pre",
  "mix",
  "style",
  "deli",
  "luncheon",
  "all",
  "air",
  "eat",
  "ready",
  "hard",
  "soft",
  "large",
  "small",
  "baby"
]);
function stemToken(token) {
  if (token.endsWith("es") && token.length > 4) return token.slice(0, -2);
  if (token.endsWith("s") && !token.endsWith("ss") && token.length > 3) {
    return token.slice(0, -1);
  }
  return token;
}
function boundedDistance(a, b, max) {
  if (a === b) return 0;
  const over = max + 1;
  if (Math.abs(a.length - b.length) > max) return over;
  const m = a.length;
  const n = b.length;
  let prev2 = new Array(n + 1).fill(over);
  let prev = new Array(n + 1);
  for (let j = 0; j <= n; j += 1) prev[j] = j;
  for (let i = 1; i <= m; i += 1) {
    const curr = new Array(n + 1).fill(over);
    curr[0] = i;
    const from = Math.max(1, i - max);
    const to = Math.min(n, i + max);
    let rowMin = over;
    for (let j = from; j <= to; j += 1) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      let value = Math.min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost);
      if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) {
        value = Math.min(value, prev2[j - 2] + 1);
      }
      curr[j] = value;
      if (value < rowMin) rowMin = value;
    }
    if (rowMin > max) return over;
    prev2 = prev;
    prev = curr;
  }
  return prev[n] <= max ? prev[n] : over;
}
const fuzzyIndexCache = /* @__PURE__ */ new WeakMap();
function buildFuzzyIndex(catalog) {
  const cached = fuzzyIndexCache.get(catalog);
  if (cached) return cached;
  const owners = /* @__PURE__ */ new Map();
  const targets = [];
  const consider = (surface, entry, viaName) => {
    const tokens = normalizeTokens(surface);
    if (tokens.length !== 1) return;
    const token = tokens[0];
    if (FUZZY_STOPWORDS.has(token)) return;
    const stemmed = stemToken(token);
    if (stemmed.length < FUZZY_MIN_TOKEN_LENGTH) return;
    if (FUZZY_STOPWORDS.has(stemmed)) return;
    let set = owners.get(stemmed);
    if (!set) {
      set = /* @__PURE__ */ new Set();
      owners.set(stemmed, set);
    }
    set.add(entry.id);
    targets.push({ stem: stemmed, id: entry.id, name: entry.name, viaName });
  };
  for (const entry of catalog) {
    consider(entry.name, entry, true);
    for (const alias of entry.aliases) consider(alias, entry, false);
  }
  const index = targets.filter(
    (target) => (owners.get(target.stem)?.size ?? 0) < FUZZY_MAX_OWNERS
  );
  fuzzyIndexCache.set(catalog, index);
  return index;
}
function fuzzyMatchCatalog(query, catalog) {
  const stems = query.map(stemToken).filter((token) => token.length >= FUZZY_MIN_TOKEN_LENGTH && !FUZZY_STOPWORDS.has(token));
  if (stems.length === 0) return null;
  const index = buildFuzzyIndex(catalog);
  let bestDistance = FUZZY_MAX_DISTANCE + 1;
  let hits = [];
  for (const token of stems) {
    for (const target of index) {
      const distance = boundedDistance(token, target.stem, FUZZY_MAX_DISTANCE);
      if (distance > FUZZY_MAX_DISTANCE || distance > bestDistance) continue;
      if (distance < bestDistance) {
        bestDistance = distance;
        hits = [target];
      } else if (!hits.some((hit) => hit.id === target.id && hit.viaName === target.viaName)) {
        hits.push(target);
      }
    }
  }
  if (hits.length === 0) return null;
  const rows = new Set(hits.map((hit) => hit.id));
  if (rows.size > 1) {
    const named = hits.filter((hit) => hit.viaName);
    if (named.length !== 1) return null;
    hits = named;
  }
  return { id: hits[0].id, name: hits[0].name, score: MATCH_THRESHOLD };
}
const normalizedCache = /* @__PURE__ */ new WeakMap();
function normalizedCatalog(catalog) {
  const cached = normalizedCache.get(catalog);
  if (cached) return cached;
  const normalized = catalog.map(({ id, name, aliases }) => ({
    id,
    name,
    nameTokens: normalizeTokens(name),
    aliasTokens: aliases.map((alias) => normalizeTokens(alias))
  }));
  normalizedCache.set(catalog, normalized);
  return normalized;
}
function matchCatalog(name, catalog) {
  const query = normalizeTokens(name);
  const scored = [];
  for (const entry of normalizedCatalog(catalog)) {
    let best = score(query, entry.nameTokens);
    let viaName = true;
    for (const aliasTokens of entry.aliasTokens) {
      const aliasScore = score(query, aliasTokens);
      if (aliasScore.dice > best.dice) {
        best = aliasScore;
        viaName = false;
      }
    }
    if (best.dice >= CANDIDATE_THRESHOLD) {
      scored.push({
        id: entry.id,
        name: entry.name,
        score: best.dice,
        coverage: best.coverage,
        viaName
      });
    }
  }
  scored.sort(
    (a, b) => b.score - a.score || Number(b.viaName) - Number(a.viaName) || a.name.localeCompare(b.name)
  );
  const candidates = scored.slice(0, 3).map(({ id, name: n, score: s }) => ({ id, name: n, score: s }));
  const top = scored[0];
  const confident = top && top.score >= MATCH_THRESHOLD && top.coverage >= COVERAGE_THRESHOLD;
  if (confident) return { match: candidates[0], candidates };
  if (scored.length === 0) {
    const rescued = fuzzyMatchCatalog(query, catalog);
    if (rescued) return { match: rescued, candidates: [rescued] };
  }
  return { match: null, candidates };
}
export {
  CANDIDATE_THRESHOLD,
  COVERAGE_THRESHOLD,
  FUZZY_MAX_DISTANCE,
  FUZZY_MIN_TOKEN_LENGTH,
  MATCH_THRESHOLD,
  matchCatalog,
  normalizeTokens,
  similarity,
  similarityScored
};
