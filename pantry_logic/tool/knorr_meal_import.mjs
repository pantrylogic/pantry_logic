#!/usr/bin/env node
/**
 * Reversible recipe import utility for the Phase 3 Knorr collection.
 *
 * `node tool/knorr_meal_import.mjs --dry-run --source plan.md --household <uuid> --mapping-out mappings.json`
 * `node tool/knorr_meal_import.mjs --apply --source plan.md --household <uuid> --batch-id <uuid> --mapping mappings.json`
 * `node tool/knorr_meal_import.mjs --rollback <batch-id> --household <uuid>`
 */
import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

const SOURCE_ID = 'knorr-sidekicks-meal-plan';
const EXPECTED_RECIPES = 21;
const EXPECTED_INGREDIENT_MAPPINGS = 180;
const EXPECTED_STEPS = 96;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function normalizeIngredientName(value) {
  return value
    .toLowerCase()
    .replace(/[\u2019']/g, '')
    .replace(/&/g, 'and')
    .replace(/\([^)]*\)/g, '')
    .replace(/\b(fresh|frozen|large|medium|small|fully cooked|pre-cooked|cooked|raw|peeled|deveined|shredded|sliced|trimmed|extra firm|thick-sliced|thin-cut|center-cut|store-bought|jarred)\b/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function ingredient(line) {
  const sourceMarkdown = line.replace(/\r$/, '');
  const sourceMatch = sourceMarkdown.match(/^\*\s+(.*)$/);
  if (!sourceMatch) throw new Error(`Invalid ingredient Markdown: ${sourceMarkdown}`);

  const originalText = sourceMatch[1];
  const parsingText = originalText.trim();
  const count = parsingText.match(/^(\d+)(?:\s*[\u2013-]\s*(\d+))?\s+(.+)$/i);
  const countedName = count?.[3].replace(/^(?:large|medium|thin-cut|center-cut)\s+/i, '') ?? '';
  const trackedName = countedName.replace(/^(?:packages?|pouches?)\s+/i, '');
  const countable = /^(?:knorr sidekicks|chicken breasts?|chicken thighs?|salmon fillets?|pork chops?|eggs?|smoked sausage loops?|blocks? extra firm tofu|red bell peppers?|ears? fresh corn|cans? .*black beans|packets? taco seasoning)/i;
  const quantity = count && count[2] == null && countable.test(trackedName)
    ? Number(count[1])
    : null;
  const derivedName = parsingText
    .replace(/^\d+(?:\.\d+)?(?:\s*[\u2013-]\s*\d+(?:\.\d+)?)?\s+/i, '')
    .replace(/^(?:(?:cups?|tablespoons?|tbsp|teaspoons?|tsp|pounds?|lbs?|ounces?|oz|packages?|pouches?|cans?|packets?|bunches?|blocks?|ears?|large|medium|small|thin-cut|center-cut)\s+)+/i, '')
    .replace(/\s*\([^)]*\)/g, '')
    .trim();
  const reviewReasons = [];
  const name = derivedName || parsingText;
  const measurementOnly = /^(?:cups?|tablespoons?|tbsp|teaspoons?|tsp|pounds?|lbs?|ounces?|oz|packages?|pouches?|cans?|packets?|bunches?|blocks?|ears?)$/i;
  if (!derivedName || !normalizeIngredientName(name) || measurementOnly.test(name)) {
    reviewReasons.push('inventory_identity_unresolved');
  }
  return {
    sourceMarkdown,
    originalText,
    raw: originalText,
    name,
    normalized: normalizeIngredientName(name),
    requiredQuantity: quantity,
    reviewReasons,
  };
}

export function parseCollection(markdown) {
  const recipes = markdown.split(/^##\s+\d+\.\s+/m).slice(1).map((section, index) => {
    const [name, ...body] = section.split('\n');
    const text = body.join('\n');
    const ingredientsText = text.match(/### Ingredients\s*([\s\S]*?)### Instructions/i)?.[1] ?? '';
    const instructionsText = text.match(/### Instructions\s*([\s\S]*?)$/i)?.[1] ?? '';
    const ingredients = ingredientsText.split('\n').filter((line) => /^\*\s+/.test(line)).map(ingredient);
    const steps = [...instructionsText.matchAll(/^\d+\.\s+(.+)$/gm)].map((match) => match[1].trim());
    if (!name?.trim() || ingredients.length === 0 || steps.length === 0) {
      throw new Error(`Recipe ${index + 1} is incomplete.`);
    }
    return {
      sourceKey: `knorr-sidekicks-${String(index + 1).padStart(2, '0')}`,
      name: name.trim(),
      ingredients,
      steps,
      reviewReasons: ingredients.flatMap((entry) => entry.reviewReasons),
    };
  });
  if (recipes.length !== 21) throw new Error(`Expected 21 recipes, found ${recipes.length}.`);
  return recipes;
}

export function sourceChecksum(markdown) {
  return createHash('sha256').update(markdown).digest('hex');
}

export function validateCollection(recipes) {
  if (!Array.isArray(recipes) || recipes.length !== EXPECTED_RECIPES) {
    throw new Error(`Expected ${EXPECTED_RECIPES} recipes, found ${recipes?.length ?? 0}.`);
  }
  const sourceKeys = new Set();
  let ingredientMappings = 0;
  let preservedIngredientTexts = 0;
  let steps = 0;
  let requiredCounts = 0;
  let recipesRequiringReview = 0;
  for (const recipe of recipes) {
    if (!recipe.sourceKey || sourceKeys.has(recipe.sourceKey)) {
      throw new Error(`Duplicate or missing recipe source key: ${recipe.sourceKey ?? '(missing)'}.`);
    }
    sourceKeys.add(recipe.sourceKey);
    if (!recipe.name?.trim() || !Array.isArray(recipe.ingredients) || !Array.isArray(recipe.steps)) {
      throw new Error(`Recipe ${recipe.sourceKey} is incomplete.`);
    }
    if (!Array.isArray(recipe.reviewReasons)) {
      throw new Error(`Recipe ${recipe.sourceKey} has invalid review metadata.`);
    }
    if (recipe.reviewReasons.length > 0) recipesRequiringReview += 1;
    for (const entry of recipe.ingredients) {
      if (!entry.name?.trim() || entry.normalized !== normalizeIngredientName(entry.name)) {
        throw new Error(`Recipe ${recipe.sourceKey} has an invalid ingredient mapping.`);
      }
      const sourceMatch = entry.sourceMarkdown?.match(/^\*\s+(.*)$/);
      if (!sourceMatch
          || sourceMatch[1] !== entry.originalText
          || entry.raw !== entry.originalText
          || !entry.originalText?.trim()) {
        throw new Error(`Recipe ${recipe.sourceKey} did not preserve an ingredient's original Markdown text.`);
      }
      if (!Array.isArray(entry.reviewReasons)) {
        throw new Error(`Recipe ${recipe.sourceKey} has invalid ingredient review metadata.`);
      }
      if (entry.requiredQuantity != null) {
        if (!Number.isSafeInteger(entry.requiredQuantity) || entry.requiredQuantity <= 0) {
          throw new Error(`Recipe ${recipe.sourceKey} has an invalid required ingredient count.`);
        }
        requiredCounts += 1;
      }
      ingredientMappings += 1;
      preservedIngredientTexts += 1;
    }
    for (const step of recipe.steps) {
      if (typeof step !== 'string' || !step.trim()) {
        throw new Error(`Recipe ${recipe.sourceKey} has an invalid instruction.`);
      }
      steps += 1;
    }
  }
  if (ingredientMappings !== EXPECTED_INGREDIENT_MAPPINGS) {
    throw new Error(`Expected ${EXPECTED_INGREDIENT_MAPPINGS} ingredient mappings, found ${ingredientMappings}.`);
  }
  if (steps !== EXPECTED_STEPS) {
    throw new Error(`Expected ${EXPECTED_STEPS} ordered steps, found ${steps}.`);
  }
  return {
    recipes: recipes.length,
    ingredientMappings,
    preservedIngredientTexts,
    steps,
    requiredCounts,
    recipesRequiringReview,
  };
}

function exactIngredientName(value) {
  return value.trim().replace(/\s+/g, ' ').toLowerCase();
}

function indexItems(existingItems) {
  const byId = new Map();
  const exact = new Map();
  const normalized = new Map();
  for (const item of existingItems) {
    if (!item?.id || !item?.name) continue;
    byId.set(item.id, item);
    exact.set(exactIngredientName(item.name), item);
    const key = normalizeIngredientName(item.name);
    const matches = normalized.get(key) ?? [];
    matches.push(item);
    normalized.set(key, matches);
  }
  return { byId, exact, normalized };
}

function automaticMapping(entry, itemIndex) {
  const exact = itemIndex.exact.get(exactIngredientName(entry.name));
  if (exact) {
    return { status: 'existing', match: 'exact', itemId: exact.id, itemName: exact.name };
  }
  const candidates = itemIndex.normalized.get(entry.normalized) ?? [];
  if (candidates.length === 1) {
    return { status: 'existing', match: 'normalized', itemId: candidates[0].id, itemName: candidates[0].name };
  }
  if (candidates.length > 1) {
    return {
      status: 'ambiguous',
      candidates: candidates.map((item) => ({ itemId: item.id, itemName: item.name })),
    };
  }
  return { status: 'new', itemName: entry.name };
}

function applyDecision(entry, decision, itemIndex) {
  if (decision?.approved !== true) return null;
  if (decision.action === 'use_existing') {
    const item = itemIndex.byId.get(decision.itemId);
    if (!item) throw new Error(`Mapping ${entry.normalized} selects an item outside the selected household.`);
    return { status: 'existing', match: 'reviewed', itemId: item.id, itemName: item.name };
  }
  if (decision.action === 'create') {
    const itemName = decision.itemName?.trim();
    if (!itemName) throw new Error(`Mapping ${entry.normalized} requires a non-empty itemName.`);
    return { status: 'new', match: 'reviewed', itemName };
  }
  throw new Error(`Mapping ${entry.normalized} has an unsupported action.`);
}

export function buildDryRun(recipes, existingItems = [], decisions = new Map()) {
  const itemIndex = indexItems(existingItems);
  const unresolvedByKey = new Map();
  const usedDecisions = new Set();
  const newItems = new Map();
  const existingItemIds = new Set();
  let exactMatches = 0;
  let normalizedMatches = 0;
  let reviewedMatches = 0;

  const meals = recipes.map((recipe) => ({
    ...recipe,
    category: 'Meal',
    ingredientMappings: recipe.ingredients.map((entry) => {
      const automatic = automaticMapping(entry, itemIndex);
      const decision = decisions.get(entry.normalized);
      if (automatic.status !== 'existing' && decision) usedDecisions.add(entry.normalized);
      const reviewed = automatic.status === 'existing' ? null : applyDecision(entry, decision, itemIndex);
      const mapping = reviewed ?? automatic;
      if (reviewed) {
        reviewedMatches += 1;
      }
      if (mapping.status === 'existing') {
        existingItemIds.add(mapping.itemId);
        if (mapping.match === 'exact') exactMatches += 1;
        if (mapping.match === 'normalized') normalizedMatches += 1;
      } else if (mapping.status === 'new') {
        newItems.set(entry.normalized, mapping.itemName);
      }
      if (!reviewed && automatic.status !== 'existing') {
        const group = unresolvedByKey.get(entry.normalized) ?? {
          ingredientKey: entry.normalized,
          sourceNames: new Set(),
          sourceTexts: new Set(),
          occurrenceCount: 0,
          status: automatic.status,
          itemName: automatic.itemName,
          candidates: automatic.candidates ?? [],
        };
        group.sourceNames.add(entry.name);
        group.sourceTexts.add(entry.originalText);
        group.occurrenceCount += 1;
        unresolvedByKey.set(entry.normalized, group);
      }
      return { ...entry, mapping };
    }),
  }));

  const unresolved = [...unresolvedByKey.values()]
    .map((entry) => ({
      ...entry,
      sourceNames: [...entry.sourceNames].sort(),
      sourceTexts: [...entry.sourceTexts].sort(),
    }))
    .sort((left, right) => left.ingredientKey.localeCompare(right.ingredientKey));
  const ambiguous = unresolved.filter((entry) => entry.status === 'ambiguous');
  const unusedDecisions = [...decisions.keys()].filter((key) => !usedDecisions.has(key));
  return {
    sourceId: SOURCE_ID,
    meals,
    newItems: [...newItems.values()].sort(),
    ambiguous,
    unresolved,
    unusedDecisions,
    matchSummary: {
      exact: exactMatches,
      normalized: normalizedMatches,
      reviewed: reviewedMatches,
      existingUniqueItems: existingItemIds.size,
    },
  };
}

function createMappingReview({ householdId, checksum, resolution, duplicate, generatedAt }) {
  return {
    version: 1,
    sourceId: SOURCE_ID,
    sourceChecksum: checksum,
    householdId,
    generatedAt,
    duplicate: duplicate ? { batchId: duplicate.id, status: duplicate.status } : null,
    recipeReviews: resolution.meals
      .filter((meal) => meal.reviewReasons.length > 0)
      .map((meal) => ({ sourceKey: meal.sourceKey, name: meal.name, reasons: meal.reviewReasons })),
    mappings: resolution.unresolved.map((entry) => ({
      ingredientKey: entry.ingredientKey,
      sourceNames: entry.sourceNames,
      sourceTexts: entry.sourceTexts,
      occurrenceCount: entry.occurrenceCount,
      status: entry.status,
      action: entry.status === 'new' ? 'create' : 'use_existing',
      itemId: null,
      itemName: entry.status === 'new' ? entry.itemName : null,
      candidates: entry.candidates,
      approved: false,
    })),
  };
}

function mappingDecisions(review, householdId, checksum) {
  if (!review || review.version !== 1 || review.sourceId !== SOURCE_ID) {
    throw new Error('Mapping file has an unsupported format or source.');
  }
  if (review.householdId !== householdId) {
    throw new Error('Mapping file belongs to a different household.');
  }
  if (review.sourceChecksum !== checksum) {
    throw new Error('Mapping file does not match the source checksum.');
  }
  if (!Array.isArray(review.mappings)) throw new Error('Mapping file mappings must be an array.');
  const decisions = new Map();
  for (const entry of review.mappings) {
    if (!entry?.ingredientKey || decisions.has(entry.ingredientKey)) {
      throw new Error('Mapping file contains a missing or duplicate ingredientKey.');
    }
    decisions.set(entry.ingredientKey, entry);
  }
  return decisions;
}

function parseJwtPayload(token) {
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('SUPABASE_ACCESS_TOKEN is not a JWT.');
  try {
    return JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  } catch {
    throw new Error('SUPABASE_ACCESS_TOKEN has an invalid JWT payload.');
  }
}

function assertSelectedHousehold(token, householdId) {
  const payload = parseJwtPayload(token);
  const authorizedHousehold = payload?.app_metadata?.household_id;
  if (!authorizedHousehold) throw new Error('The access token has no authorized household claim.');
  if (authorizedHousehold !== householdId) {
    throw new Error('The selected household does not match the access token authorization.');
  }
}

function requestError(status, body) {
  const code = body?.code ? ` ${body.code}` : '';
  const message = body?.message ?? body?.error_description ?? body?.error ?? `HTTP ${status}`;
  return new Error(`Supabase request failed${code}: ${message}`);
}

export function createSupabaseClient({ url, anonKey, accessToken, fetchImpl = fetch }) {
  let baseUrl;
  try {
    baseUrl = new URL(url);
  } catch {
    throw new Error('SUPABASE_URL is invalid.');
  }
  const headers = {
    apikey: anonKey,
    authorization: `Bearer ${accessToken}`,
    'content-type': 'application/json',
  };

  async function request(path, options = {}) {
    const response = await fetchImpl(new URL(path, baseUrl), {
      ...options,
      headers: { ...headers, ...options.headers },
    });
    const text = await response.text();
    let body = null;
    if (text) {
      try {
        body = JSON.parse(text);
      } catch {
        body = text;
      }
    }
    if (!response.ok) throw requestError(response.status, body);
    return body;
  }

  return {
    async verifyHousehold(householdId) {
      const query = new URLSearchParams({ select: 'id,name', id: `eq.${householdId}`, limit: '1' });
      const rows = await request(`rest/v1/households?${query}`);
      if (!Array.isArray(rows) || rows.length !== 1) {
        throw new Error('Selected household is not authorized or does not exist.');
      }
      return rows[0];
    },
    async listItems(householdId) {
      const rows = [];
      const pageSize = 1000;
      for (let offset = 0; ; offset += pageSize) {
        const query = new URLSearchParams({
          select: 'id,name',
          household_id: `eq.${householdId}`,
          order: 'name.asc,id.asc',
        });
        const page = await request(`rest/v1/items?${query}`, {
          headers: { range: `${offset}-${offset + pageSize - 1}` },
        });
        if (!Array.isArray(page)) throw new Error('Supabase items response was not an array.');
        rows.push(...page);
        if (page.length < pageSize) return rows;
      }
    },
    async findActiveImport(householdId, sourceId, checksum) {
      const query = new URLSearchParams({
        select: 'id,status,created_at',
        household_id: `eq.${householdId}`,
        source_id: `eq.${sourceId}`,
        source_checksum: `eq.${checksum}`,
        status: 'eq.active',
        limit: '1',
      });
      const rows = await request(`rest/v1/meal_import_batches?${query}`);
      return Array.isArray(rows) ? rows[0] ?? null : null;
    },
    importBatch(batchId, checksum, meals) {
      return request('rest/v1/rpc/import_meal_batch', {
        method: 'POST',
        body: JSON.stringify({
          p_batch_id: batchId,
          p_source_id: SOURCE_ID,
          p_source_checksum: checksum,
          p_meals: meals,
        }),
      });
    },
    rollbackBatch(batchId) {
      return request('rest/v1/rpc/rollback_meal_import', {
        method: 'POST',
        body: JSON.stringify({ p_batch_id: batchId }),
      });
    },
  };
}

function valueOption(argv, index, option) {
  const value = argv[index + 1];
  if (!value || value.startsWith('--')) throw new Error(`${option} requires a value.`);
  return value;
}

export function parseCliArgs(argv) {
  const options = {};
  for (let index = 0; index < argv.length; index += 1) {
    const option = argv[index];
    if (option === '--dry-run') options.mode = options.mode ? 'conflict' : 'dry-run';
    else if (option === '--apply') options.mode = options.mode ? 'conflict' : 'apply';
    else if (option === '--rollback') {
      options.mode = options.mode ? 'conflict' : 'rollback';
      options.rollbackBatchId = valueOption(argv, index, option);
      index += 1;
    } else if (['--source', '--household', '--mapping-out', '--mapping', '--batch-id'].includes(option)) {
      const key = {
        '--source': 'source',
        '--household': 'householdId',
        '--mapping-out': 'mappingOut',
        '--mapping': 'mapping',
        '--batch-id': 'batchId',
      }[option];
      options[key] = valueOption(argv, index, option);
      index += 1;
    } else {
      throw new Error(`Unknown option: ${option}`);
    }
  }
  if (!options.mode || options.mode === 'conflict') {
    throw new Error('Select exactly one operation: --dry-run, --apply, or --rollback <batch-id>.');
  }
  if (!UUID_PATTERN.test(options.householdId ?? '')) throw new Error('--household requires an explicit UUID.');
  if (options.mode !== 'rollback' && !options.source) throw new Error(`${options.mode} requires --source.`);
  if (options.mode === 'apply' && !UUID_PATTERN.test(options.batchId ?? '')) {
    throw new Error('--apply requires an explicit --batch-id UUID.');
  }
  if (options.mode === 'rollback' && !UUID_PATTERN.test(options.rollbackBatchId ?? '')) {
    throw new Error('--rollback requires a batch UUID.');
  }
  if (!options.mappingOut) options.mappingOut = 'knorr-meal-import-mappings.json';
  return options;
}

function formatDryRun(report) {
  const duplicate = report.duplicate
    ? `Duplicate: active batch ${report.duplicate.id}`
    : 'Duplicate: none';
  return [
    'DRY RUN — no database changes made',
    `Household: ${report.household.name} (${report.household.id})`,
    `Source checksum: ${report.sourceChecksum}`,
    duplicate,
    `Recipes: ${report.validation.recipes}`,
    `Ingredient mappings: ${report.validation.ingredientMappings} (${report.resolution.exact} exact, ${report.resolution.normalized} normalized)`,
    `Original ingredient texts preserved: ${report.validation.preservedIngredientTexts}`,
    `Ordered steps: ${report.validation.steps}`,
    `Recipes requiring quantity review: ${report.validation.recipesRequiringReview}`,
    `Existing items used: ${report.resolution.existingUniqueItems}`,
    `New items requiring approval: ${report.resolution.newItems}`,
    `Ambiguous items requiring selection: ${report.resolution.ambiguous}`,
    `Planned rows: 1 batch, ${report.validation.recipes} batch mappings, ${report.validation.recipes} meals, ${report.validation.ingredientMappings} meal ingredients, ${report.validation.steps} meal steps`,
    `Mapping review: ${report.mappingFile}`,
  ].join('\n');
}

function formatImport(report) {
  const result = report.result;
  if (result.status === 'duplicate') {
    return `IMPORT SKIPPED — duplicate active batch ${result.duplicate_of ?? result.batch_id}`;
  }
  return [
    `IMPORT ${String(result.status).toUpperCase()}`,
    `Household: ${report.household.name} (${report.household.id})`,
    `Batch: ${result.batch_id}`,
    `Meals: ${result.meals?.length ?? 0}`,
    `Items created: ${result.items_created ?? 0}`,
    `Idempotent retry: ${Boolean(result.idempotent)}`,
  ].join('\n');
}

function formatRollback(report) {
  const result = report.result;
  const lines = [
    `ROLLBACK ${String(result.status).toUpperCase()}`,
    `Household: ${report.household.name} (${report.household.id})`,
    `Batch: ${result.batch_id}`,
    `Removed: ${result.removed_count ?? result.removed?.length ?? 0}`,
  ];
  for (const meal of result.removed ?? []) lines.push(`  removed: ${meal.name} (${meal.meal_id})`);
  lines.push(`Protected: ${result.protected_count ?? result.protected?.length ?? 0}`);
  for (const meal of result.protected ?? []) {
    lines.push(`  protected: ${meal.name} (${meal.meal_id}) — ${(meal.reasons ?? []).join(', ')}`);
  }
  lines.push(`Idempotent retry: ${Boolean(result.idempotent)}`);
  return lines.join('\n');
}

export async function runCli(argv, dependencies = {}) {
  const options = parseCliArgs(argv);
  const env = dependencies.env ?? process.env;
  const read = dependencies.readFile ?? readFile;
  const write = dependencies.writeFile ?? writeFile;
  const log = dependencies.log ?? console.log;
  const accessToken = env.SUPABASE_ACCESS_TOKEN;
  const url = env.SUPABASE_URL;
  const anonKey = env.SUPABASE_ANON_KEY;
  if (!url || !anonKey || !accessToken) {
    throw new Error('SUPABASE_URL, SUPABASE_ANON_KEY, and SUPABASE_ACCESS_TOKEN are required.');
  }
  assertSelectedHousehold(accessToken, options.householdId);
  const client = dependencies.client ?? createSupabaseClient({
    url,
    anonKey,
    accessToken,
    fetchImpl: dependencies.fetch,
  });
  const household = await client.verifyHousehold(options.householdId);

  if (options.mode === 'rollback') {
    const result = await client.rollbackBatch(options.rollbackBatchId);
    const report = { operation: 'rollback', household, result };
    log(formatRollback(report));
    return report;
  }

  const markdown = await read(options.source, 'utf8');
  const checksum = sourceChecksum(markdown);
  const recipes = parseCollection(markdown);
  const validation = validateCollection(recipes);
  if (options.mode === 'apply' && validation.recipesRequiringReview > 0) {
    throw new Error(`${validation.recipesRequiringReview} recipes require ingredient review before import.`);
  }
  const existingItems = await client.listItems(options.householdId);
  const duplicate = await client.findActiveImport(options.householdId, SOURCE_ID, checksum);

  if (options.mode === 'dry-run') {
    const resolution = buildDryRun(recipes, existingItems);
    const review = createMappingReview({
      householdId: options.householdId,
      checksum,
      resolution,
      duplicate,
      generatedAt: (dependencies.now ?? (() => new Date()))().toISOString(),
    });
    await write(options.mappingOut, `${JSON.stringify(review, null, 2)}\n`, 'utf8');
    const report = {
      operation: 'dry-run',
      household,
      sourceChecksum: checksum,
      duplicate,
      validation,
      mappingFile: options.mappingOut,
      resolution: {
        ...resolution.matchSummary,
        newItems: resolution.unresolved.filter((entry) => entry.status === 'new').length,
        ambiguous: resolution.ambiguous.length,
      },
      changes: {
        batches: 1,
        batchMappings: validation.recipes,
        meals: validation.recipes,
        mealIngredients: validation.ingredientMappings,
        mealSteps: validation.steps,
        inventory: 0,
        groceries: 0,
        calendarEntries: 0,
      },
    };
    log(formatDryRun(report));
    return report;
  }

  let decisions = new Map();
  if (options.mapping) {
    const review = JSON.parse(await read(options.mapping, 'utf8'));
    decisions = mappingDecisions(review, options.householdId, checksum);
  }
  const resolution = buildDryRun(recipes, existingItems, decisions);
  if (resolution.unusedDecisions.length > 0) {
    throw new Error(`Mapping file contains stale entries: ${resolution.unusedDecisions.join(', ')}.`);
  }
  if (resolution.unresolved.length > 0) {
    throw new Error(`${resolution.unresolved.length} item mappings remain unapproved; run --dry-run and review the mapping file.`);
  }
  const result = await client.importBatch(options.batchId, checksum, resolution.meals);
  const report = { operation: 'apply', household, sourceChecksum: checksum, validation, duplicate, result };
  log(formatImport(report));
  return report;
}

async function main() {
  return runCli(process.argv.slice(2));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => { console.error(error.message); process.exitCode = 1; });
}
