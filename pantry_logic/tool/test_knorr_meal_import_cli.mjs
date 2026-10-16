import assert from 'node:assert/strict';
import test from 'node:test';
import {
  createSupabaseClient,
  parseCliArgs,
  parseCollection,
  runCli,
  validateCollection,
} from './knorr_meal_import.mjs';

const householdId = '11111111-1111-4111-8111-111111111111';
const otherHouseholdId = '22222222-2222-4222-8222-222222222222';
const batchId = '33333333-3333-4333-8333-333333333333';
const existingItems = [
  { id: '44444444-4444-4444-8444-444444444441', name: 'Chicken breasts' },
  { id: '44444444-4444-4444-8444-444444444442', name: 'Milk' },
  { id: '44444444-4444-4444-8444-444444444443', name: 'Fresh Button mushrooms' },
  { id: '44444444-4444-4444-8444-444444444444', name: 'Frozen Button mushrooms' },
];

function fixtureMarkdown() {
  const sections = [];
  for (let recipe = 1; recipe <= 21; recipe += 1) {
    const ingredientCount = recipe <= 12 ? 9 : 8;
    const stepCount = recipe <= 12 ? 5 : 4;
    const ingredients = [];
    for (let index = 0; index < ingredientCount; index += 1) {
      if (recipe === 1 && index === 0) ingredients.push('* 4 Chicken breasts');
      else if (recipe === 1 && index === 1) ingredients.push('* Fresh Milk');
      else if (recipe === 1 && index === 2) ingredients.push('* Button mushrooms');
      else ingredients.push(`* Ingredient ${recipe}-${index + 1}`);
    }
    const steps = Array.from({ length: stepCount }, (_, index) => `${index + 1}. Recipe ${recipe} step ${index + 1}.`);
    sections.push(`## ${recipe}. Fixture Recipe ${recipe}\n\n### Ingredients\n${ingredients.join('\n')}\n\n### Instructions\n${steps.join('\n')}`);
  }
  return sections.join('\n\n');
}

function tokenFor(selectedHouseholdId) {
  const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(JSON.stringify({
    sub: '55555555-5555-4555-8555-555555555555',
    app_metadata: { household_id: selectedHouseholdId },
  })).toString('base64url');
  return `${header}.${payload}.test-signature`;
}

function fakeClient(overrides = {}) {
  const calls = { verify: [], import: [], rollback: [] };
  const client = {
    async verifyHousehold(id) {
      calls.verify.push(id);
      return { id, name: 'Fixture Household' };
    },
    async listItems() {
      return existingItems;
    },
    async findActiveImport() {
      return null;
    },
    async importBatch(...args) {
      calls.import.push(args);
      return {
        status: 'imported',
        batch_id: args[0],
        meals: args[2].map((meal) => ({ source_key: meal.sourceKey, name: meal.name })),
        items_created: 177,
        idempotent: false,
      };
    },
    async rollbackBatch(id) {
      calls.rollback.push(id);
      return {
        status: 'rolled_back',
        batch_id: id,
        removed_count: 1,
        protected_count: 1,
        removed: [{ meal_id: 'meal-1', name: 'Untouched meal' }],
        protected: [{ meal_id: 'meal-2', name: 'Edited meal', reasons: ['edited', 'scheduled'] }],
        idempotent: false,
      };
    },
    ...overrides,
  };
  return { client, calls };
}

function dependencies(client, files = {}) {
  const writes = new Map();
  const logs = [];
  return {
    dependencies: {
      env: {
        SUPABASE_URL: 'https://example.supabase.co',
        SUPABASE_ANON_KEY: 'test-anon-key',
        SUPABASE_ACCESS_TOKEN: tokenFor(householdId),
      },
      client,
      async readFile(path) {
        if (path === 'fixture.md') return fixtureMarkdown();
        if (Object.hasOwn(files, path)) return files[path];
        throw new Error(`Unexpected read: ${path}`);
      },
      async writeFile(path, contents) {
        writes.set(path, contents);
      },
      now: () => new Date('2026-10-15T12:00:00.000Z'),
      log: (message) => logs.push(message),
    },
    writes,
    logs,
  };
}

async function approvedMapping(client) {
  const dryRun = dependencies(client);
  await runCli([
    '--dry-run',
    '--source', 'fixture.md',
    '--household', householdId,
    '--mapping-out', 'review.json',
  ], dryRun.dependencies);
  const review = JSON.parse(dryRun.writes.get('review.json'));
  for (const mapping of review.mappings) {
    mapping.approved = true;
    if (mapping.status === 'ambiguous') mapping.itemId = mapping.candidates[0].itemId;
  }
  return JSON.stringify(review);
}

test('validates the complete collection totals and required counts', () => {
  const validation = validateCollection(parseCollection(fixtureMarkdown()));
  assert.deepEqual(validation, {
    recipes: 21,
    ingredientMappings: 180,
    preservedIngredientTexts: 180,
    steps: 96,
    requiredCounts: 1,
    recipesRequiringReview: 0,
  });
});

test('rejects structurally incomplete collection totals', () => {
  const recipes = parseCollection(fixtureMarkdown());
  recipes[0].ingredients.pop();
  assert.throws(() => validateCollection(recipes), /Expected 180 ingredient mappings, found 179/);
});

test('requires one operation and an explicit household UUID', () => {
  assert.throws(() => parseCliArgs(['--dry-run', '--source', 'fixture.md']), /--household/);
  assert.throws(() => parseCliArgs(['--dry-run', '--apply', '--source', 'fixture.md', '--household', householdId]), /exactly one operation/);
});

test('dry-run verifies authorization and writes a complete review mapping', async () => {
  const { client, calls } = fakeClient();
  const context = dependencies(client);
  const report = await runCli([
    '--dry-run',
    '--source', 'fixture.md',
    '--household', householdId,
    '--mapping-out', 'review.json',
  ], context.dependencies);
  const review = JSON.parse(context.writes.get('review.json'));
  assert.deepEqual(calls.verify, [householdId]);
  assert.equal(report.validation.recipes, 21);
  assert.equal(report.validation.ingredientMappings, 180);
  assert.equal(report.validation.preservedIngredientTexts, 180);
  assert.equal(report.validation.steps, 96);
  assert.equal(report.resolution.exact, 1);
  assert.equal(report.resolution.normalized, 1);
  assert.equal(report.resolution.ambiguous, 1);
  assert.equal(report.resolution.newItems, 177);
  assert.equal(review.mappings.length, 178);
  assert.equal(review.mappings.every((mapping) => mapping.approved === false), true);
  assert.equal(review.recipeReviews.length, 0);
  assert.match(context.logs[0], /DRY RUN — no database changes made/);
});

test('apply rejects unapproved mapping entries before calling the RPC', async () => {
  const { client, calls } = fakeClient();
  const dryRun = dependencies(client);
  await runCli(['--dry-run', '--source', 'fixture.md', '--household', householdId, '--mapping-out', 'review.json'], dryRun.dependencies);
  const context = dependencies(client, { 'review.json': dryRun.writes.get('review.json') });
  await assert.rejects(
    runCli(['--apply', '--source', 'fixture.md', '--household', householdId, '--batch-id', batchId, '--mapping', 'review.json'], context.dependencies),
    /178 item mappings remain unapproved/,
  );
  assert.equal(calls.import.length, 0);
});

test('apply sends the validated parser payload and stable batch id to the RPC', async () => {
  const { client, calls } = fakeClient();
  const review = await approvedMapping(client);
  const context = dependencies(client, { 'approved.json': review });
  const report = await runCli([
    '--apply',
    '--source', 'fixture.md',
    '--household', householdId,
    '--batch-id', batchId,
    '--mapping', 'approved.json',
  ], context.dependencies);
  assert.equal(report.result.status, 'imported');
  assert.equal(calls.import.length, 1);
  assert.equal(calls.import[0][0], batchId);
  assert.equal(calls.import[0][2].length, 21);
  assert.equal(calls.import[0][2].flatMap((meal) => meal.ingredientMappings).length, 180);
  assert.equal(calls.import[0][2].flatMap((meal) => meal.steps).length, 96);
  assert.equal(calls.import[0][2][0].ingredientMappings[0].requiredQuantity, 4);
  assert.equal(calls.import[0][2][0].ingredientMappings[0].sourceMarkdown, '* 4 Chicken breasts');
  assert.equal(calls.import[0][2][0].ingredientMappings[0].originalText, '4 Chicken breasts');
  assert.equal(calls.import[0][2][0].ingredientMappings[0].raw, '4 Chicken breasts');
  assert.match(context.logs[0], /IMPORT IMPORTED/);
});

test('apply rejects recipes whose quantity text has no safe inventory identity', async () => {
  const { client, calls } = fakeClient();
  const unsafeSource = fixtureMarkdown().replace('* 4 Chicken breasts', '* 2 cups');
  const context = dependencies(client, { 'unsafe.md': unsafeSource });
  await assert.rejects(
    runCli([
      '--apply',
      '--source', 'unsafe.md',
      '--household', householdId,
      '--batch-id', batchId,
      '--mapping', 'unused.json',
    ], context.dependencies),
    /1 recipes require ingredient review before import/,
  );
  assert.equal(calls.import.length, 0);
});

test('duplicate RPC result is reported as a safe no-op', async () => {
  const { client } = fakeClient({
    async importBatch() {
      return {
        status: 'duplicate',
        batch_id: '66666666-6666-4666-8666-666666666666',
        duplicate_of: '66666666-6666-4666-8666-666666666666',
        meals: [],
        idempotent: false,
      };
    },
  });
  const review = await approvedMapping(client);
  const context = dependencies(client, { 'approved.json': review });
  const report = await runCli(['--apply', '--source', 'fixture.md', '--household', householdId, '--batch-id', batchId, '--mapping', 'approved.json'], context.dependencies);
  assert.equal(report.result.status, 'duplicate');
  assert.match(context.logs[0], /IMPORT SKIPPED — duplicate active batch/);
});

test('RPC failures are surfaced without retrying another household', async () => {
  const { client, calls } = fakeClient({
    async rollbackBatch(id) {
      calls.rollback.push(id);
      throw new Error('Supabase request failed P0002: import batch not found');
    },
  });
  const context = dependencies(client);
  await assert.rejects(
    runCli(['--rollback', batchId, '--household', householdId], context.dependencies),
    /P0002: import batch not found/,
  );
  assert.deepEqual(calls.verify, [householdId]);
  assert.deepEqual(calls.rollback, [batchId]);
});

test('rollback prints removed and protected meal details', async () => {
  const { client, calls } = fakeClient();
  const context = dependencies(client);
  const report = await runCli(['--rollback', batchId, '--household', householdId], context.dependencies);
  assert.equal(report.result.removed_count, 1);
  assert.equal(report.result.protected_count, 1);
  assert.deepEqual(calls.rollback, [batchId]);
  assert.match(context.logs[0], /removed: Untouched meal/);
  assert.match(context.logs[0], /protected: Edited meal .* edited, scheduled/);
});

test('token household mismatch is rejected before any Supabase request', async () => {
  const { client, calls } = fakeClient();
  const context = dependencies(client);
  context.dependencies.env.SUPABASE_ACCESS_TOKEN = tokenFor(otherHouseholdId);
  await assert.rejects(
    runCli(['--rollback', batchId, '--household', householdId], context.dependencies),
    /does not match the access token authorization/,
  );
  assert.equal(calls.verify.length, 0);
});

test('Supabase client sends the Phase 3A import RPC contract exactly', async () => {
  const requests = [];
  const client = createSupabaseClient({
    url: 'https://example.supabase.co',
    anonKey: 'anon-key',
    accessToken: tokenFor(householdId),
    async fetchImpl(url, options) {
      requests.push({ url, options });
      return {
        ok: true,
        status: 200,
        async text() {
          return JSON.stringify({ status: 'imported', batch_id: batchId });
        },
      };
    },
  });
  await client.importBatch(batchId, 'a'.repeat(64), [{ sourceKey: 'recipe-1' }]);
  assert.equal(requests[0].url.pathname, '/rest/v1/rpc/import_meal_batch');
  assert.equal(requests[0].options.method, 'POST');
  assert.deepEqual(JSON.parse(requests[0].options.body), {
    p_batch_id: batchId,
    p_source_id: 'knorr-sidekicks-meal-plan',
    p_source_checksum: 'a'.repeat(64),
    p_meals: [{ sourceKey: 'recipe-1' }],
  });
  assert.equal(requests[0].options.headers.authorization.startsWith('Bearer '), true);
});

test('Supabase client surfaces rollback RPC error codes and messages', async () => {
  const client = createSupabaseClient({
    url: 'https://example.supabase.co',
    anonKey: 'anon-key',
    accessToken: tokenFor(householdId),
    async fetchImpl(url) {
      assert.equal(url.pathname, '/rest/v1/rpc/rollback_meal_import');
      return {
        ok: false,
        status: 404,
        async text() {
          return JSON.stringify({ code: 'P0002', message: 'import batch not found' });
        },
      };
    },
  });
  await assert.rejects(client.rollbackBatch(batchId), /Supabase request failed P0002: import batch not found/);
});
