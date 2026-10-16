import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';
import { buildDryRun, normalizeIngredientName, parseCollection, validateCollection } from './knorr_meal_import.mjs';

const source = 'C:/Users/OWNER/Downloads/knorr_sidekicks_meal_plan.md';

test('parses all 21 recipes with ordered directions', async () => {
  const recipes = parseCollection(await readFile(source, 'utf8'));
  assert.equal(recipes.length, 21);
  assert.equal(recipes[0].steps.length, 7);
  assert.equal(recipes[20].steps[0], 'Season pork chops with garlic powder, salt, and pepper.');
});

test('preserves count requirements and presence-only measurements', async () => {
  const recipes = parseCollection(await readFile(source, 'utf8'));
  for (const recipe of recipes) {
    const sidekicks = recipe.ingredients.find((item) => item.normalized.startsWith('knorr sidekicks'));
    assert.equal(sidekicks.requiredQuantity, 2, `${recipe.sourceKey} Sidekicks packages`);
  }
  assert.equal(recipes[0].ingredients.find((item) => item.normalized === 'chicken breasts').requiredQuantity, 4);
  assert.equal(recipes[14].ingredients.find((item) => item.normalized === 'eggs').requiredQuantity, 4);
  assert.equal(recipes[0].ingredients.find((item) => item.name === 'Milk').requiredQuantity, null);
  const lemon = recipes[0].ingredients.find((item) => item.name === 'Lemon');
  assert.equal(lemon.sourceMarkdown, '* 1 Lemon (juiced)');
  assert.equal(lemon.originalText, '1 Lemon (juiced)');
  assert.equal(lemon.raw, lemon.originalText);
  assert.deepEqual(validateCollection(recipes), {
    recipes: 21,
    ingredientMappings: 180,
    preservedIngredientTexts: 180,
    steps: 96,
    requiredCounts: 36,
    recipesRequiringReview: 0,
  });
  assert.equal(
    recipes.flatMap((recipe) => recipe.ingredients).every((item) => item.sourceMarkdown === `* ${item.originalText}`),
    true,
  );
});

test('separates inventory names without changing source quantities or preparation', async () => {
  const recipes = parseCollection(await readFile(source, 'utf8'));
  const ingredients = recipes.flatMap((recipe) => recipe.ingredients);
  const examples = new Map(ingredients.map((item) => [item.originalText, item]));
  assert.equal(examples.get('25-30 Frozen fully cooked Italian meatballs').name, 'Frozen fully cooked Italian meatballs');
  assert.equal(examples.get('2 cans (15 oz each) Black beans (drained and rinsed)').name, 'Black beans');
  assert.equal(examples.get('5-6 Thin-cut boneless pork loin chops').name, 'boneless pork loin chops');
  assert.equal(examples.get('0.66 cup BBQ sauce').requiredQuantity, null);
  assert.equal(examples.get('0.66 cup BBQ sauce').originalText, '0.66 cup BBQ sauce');
});

test('normalizes only obvious item spelling differences', () => {
  assert.equal(normalizeIngredientName('Fresh  Milk'), 'milk');
  assert.equal(normalizeIngredientName('Button or Cremini mushrooms (sliced)'), 'button or cremini mushrooms');
});

test('dry run reports existing and new item mappings', () => {
  const preview = buildDryRun([{ sourceKey: 'x', name: 'X', reviewReasons: [], ingredients: [{ sourceMarkdown: '* 1 cup Milk', originalText: '1 cup Milk', raw: '1 cup Milk', name: 'Milk', normalized: 'milk', requiredQuantity: null, reviewReasons: [] }], steps: ['Cook.'] }], [{ id: 'milk-id', name: 'milk' }]);
  assert.equal(preview.meals[0].ingredientMappings[0].mapping.status, 'existing');
  assert.equal(preview.newItems.length, 0);
});
