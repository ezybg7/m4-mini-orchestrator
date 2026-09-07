import { appendFileSync } from 'node:fs';
import { B_ROWS } from './roster.mjs';
import { B_PANELS } from './panels.mjs';
import { BROAD_FAMILIES, BROAD_APPLIED_FAMILIES, BROAD_PROBES } from './bfam.mjs';

const TEST = '/Users/orchestrator/agents/worktrees/broad/tests/catalog-seed-extension.test.ts';
const ts = (s) => `'${s.replace(/\\/g, '\\\\').replace(/'/g, "\\'")}'`;
const pair = ([a, b]) => `  [${ts(a)}, ${ts(b)}],`;

const FAM_ORDER = ['bakery', 'international', 'breakfast', 'grains', 'snacks', 'condiments', 'canned', 'baking', 'dairy', 'meat', 'deli', 'produce'];
// group the family probes by the section comments already in bfam order
const famLines = BROAD_FAMILIES.map(pair);
const panels = B_ROWS.filter((r) => r[0] in B_PANELS).length;

const block = `
/**
 * §Families, item by item — "every §Families item present by name or alias",
 * across all twelve families.
 *
 * Same idiom as the two halves above: every entry runs through the real
 * matcher, because "present" is only worth asserting if a shopper can reach it.
 * The entries whose target is NOT one of the ${B_ROWS.length} new rows are the amendment's
 * "alias only if the row exists" cases — \`muffins\`, \`bread crumbs\`, \`popcorn\`,
 * \`panko\`, \`wasabi\`, \`chard\`, \`coconut cream\`, \`macaroni\`, \`spaghetti\` and
 * \`penne\` all land on rows that were already there.
 */
const BROAD_FAMILY_PROBES: [string, string][] = [
${famLines.join('\n')}
];

/** The five §Families phrases whose home is a GENERATED row, so the alias can
 *  only live in the data apply — the \`Cumin\` situation for a third time.
 *  \`scallions\` is the one that matters most: §Shelf lives gives scallions no
 *  value of its own, so a \`Scallions\` row would have had to invent one. */
const BROAD_APPLIED_PROBES: [string, string][] = [
${BROAD_APPLIED_FAMILIES.map(pair).join('\n')}
];

/** §Aliases and probes — the phrases the amendment names, one per family at
 *  least. \`jerky\` still answers with the FoodKeeper \`Jerky\` bucket while
 *  \`beef jerky\` now answers with the snack row: both are right, and the
 *  review snippet lists the pair for a later merge. */
const BROAD_TYPEAHEAD: [string, string][] = [
${BROAD_PROBES.map(pair).join('\n')}
];

describe('§Families (twelve families) — every named item resolves', () => {
  it.each(BROAD_FAMILY_PROBES)('%s -> %s', (probe, want) => {
    expect(matchCatalog(probe, catalog).match?.name).toBe(want);
  });

  it('covers all twelve families (guards the list itself)', () => {
    expect(BROAD_FAMILY_PROBES.length).toBeGreaterThanOrEqual(250);
  });
});

describe('twelve-family type-ahead probes', () => {
  it.each(BROAD_TYPEAHEAD)('%s -> %s', (probe, want) => {
    expect(matchCatalog(probe, catalog).match?.name).toBe(want);
  });

  it.each(BROAD_APPLIED_PROBES)('%s -> %s (after the data apply)', (probe, want) => {
    expect(matchCatalog(probe, appliedCatalog).match?.name).toBe(want);
    // …and NOT before it, for the same reason the thin half asserts it: if one
    // of these starts passing against the seed alone, the alias has moved and
    // the apply file is carrying dead weight.
    expect(matchCatalog(probe, catalog).match?.name).not.toBe(want);
  });

  it('routes the accented and alias-only probes through an alias, not a name', () => {
    for (const probe of ['jalapeño', 'ranch', 'basmati', 'spring mix', 'potstickers']) {
      const want = BROAD_TYPEAHEAD.find(([p]) => p === probe)![1];
      const row = seedRows.find((r) => r.name === want)!;
      expect(normalizeTokens(row.name)).not.toEqual(normalizeTokens(probe));
      expect(row.aliases.map(norm)).toContain(norm(probe));
    }
  });
});

describe('db/apply/catalog-extension-2026-09.sql — the twelve thin families', () => {
  const applyBroad = parseRows(section(APPLY, '-- (g) new rows', '-- (h) alias growth'));
  const byName = new Map(seedRows.map((r) => [norm(r.name), r]));

  it('inserts exactly the ${B_ROWS.length} new broad-extension rows', () => {
    expect(applyBroad.length).toBe(BROAD_ROWS.length);
    expect(applyBroad.map((r) => r.name).sort()).toEqual(BROAD_ROWS.map(([n]) => n).sort());
  });

  it('inserts every one of them exactly as the seed has it', () => {
    for (const row of applyBroad) {
      const seed = byName.get(norm(row.name));
      expect(seed).toBeDefined();
      expect(row.aliases).toEqual(seed!.aliases);
      expect(row.category).toBe(seed!.category);
      expect(row.shelfLife).toEqual(seed!.shelfLife);
      expect(row.category).toBe(broadByName.get(row.name)!.category);
    }
  });

  it('adds the three hand rows aliases the seed carries too', () => {
    const updates = new Map(APPLY_ALIAS_UPDATES.map(([n, a]) => [norm(n), a]));
    for (const name of Object.keys(BROAD_ALIASES_BEFORE)) {
      const added = updates.get(norm(name));
      expect(added).toBeDefined();
      for (const alias of added!) expect(byName.get(norm(name))!.aliases).toContain(alias);
    }
  });

  it('writes ${panels} broad panels and leaves ${B_ROWS.length - panels} rows null by design', () => {
    const body = section(APPLY, '-- (i) USDA panels', '-- (j) count check');
    const targets = [...body.matchAll(/ where lower\\(name\\) = lower\\('((?:[^']|'')*)'\\)/g)].map(
      (m) => m[1].replace(/''/g, "'"),
    );
    expect(targets).toHaveLength(${panels});
    expect(new Set(targets).size).toBe(${panels});
    for (const name of targets) expect(broadByName.has(name)).toBe(true);
    expect(BROAD_ROWS.length - targets.length).toBe(${B_ROWS.length - panels});
  });

  it('names the FDC description behind every broad panel', () => {
    const body = section(APPLY, '-- (i) USDA panels', '-- (j) count check');
    const comments = [...body.matchAll(/^-- (.+?) -> (.+?) \\[fdc_id (\\d+)\\]/gm)];
    expect(comments).toHaveLength(${panels});
    for (const [, name, description, fdcId] of comments) {
      expect(broadByName.has(name)).toBe(true);
      expect(description.length).toBeGreaterThan(3);
      expect(Number(fdcId)).toBeGreaterThan(0);
    }
  });

  it('guards every broad panel with spec 45\\'s three conditions', () => {
    const body = section(APPLY, '-- (i) USDA panels', '-- (j) count check');
    const statements = body.split('update catalog_items set').slice(1);
    expect(statements).toHaveLength(${panels});
    for (const stmt of statements) {
      expect(stmt).toContain("nutrition_source = 'usda'");
      expect(stmt).toContain('and nutrition is null');
      expect(stmt).toContain('and cardinality(barcodes) = 0');
      expect(stmt).toContain("and source = 'seed'");
    }
  });

  it('writes no nutrition key the Nutrition type does not declare', () => {
    // src/lib/types.ts is the contract; a stray key would render as a blank
    // row on the label rather than failing loudly.
    const KEYS = new Set([
      'kcal', 'fat_g', 'saturated_fat_g', 'carbs_g', 'sugars_g', 'fiber_g',
      'protein_g', 'salt_g', 'caffeine_mg',
    ]);
    const body = section(APPLY, '-- (i) USDA panels', '-- (j) count check');
    const panels = [...body.matchAll(/nutrition = '(\\{.*?\\})'::jsonb/g)].map((m) => JSON.parse(m[1]) as Record<string, number>);
    expect(panels).toHaveLength(${panels});
    for (const panel of panels) {
      for (const [key, value] of Object.entries(panel)) {
        expect(KEYS.has(key)).toBe(true);
        expect(typeof value).toBe('number');
        expect(value).toBeGreaterThanOrEqual(0);
      }
      expect(panel.kcal).toBeDefined();
    }
  });

  it('is one transaction whose every insert can be re-run', () => {
    expect(APPLY.trimStart().split('\\n').find((l) => l.trim().length > 0 && !l.startsWith('--'))).toBe('begin;');
    expect(APPLY.trimEnd().endsWith('commit;')).toBe(true);
    expect((APPLY.match(/^on conflict do nothing;$/gm) ?? []).length).toBe(3);
  });
});
`;

appendFileSync(TEST, block);
console.log('appended part 2', { panels, nulls: B_ROWS.length - panels });
