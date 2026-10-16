begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(50);

insert into public.households (id, name, invite_code)
values
  ('10000000-0000-0000-0000-000000000001', 'Import Test One', 'IMPT01'),
  ('10000000-0000-0000-0000-000000000002', 'Import Test Two', 'IMPT02');

insert into public.items (id, household_id, name)
values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Shared ingredient'),
  ('30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'Replacement ingredient');

create temp table import_test_payloads (
  name text primary key,
  payload jsonb not null
);

insert into import_test_payloads (name, payload) values
('atomic', $json$
[
  {
    "sourceKey": "atomic-first",
    "name": "Atomic first",
    "ingredients": [{"name": "Atomic ingredient", "requiredQuantity": 1, "originalText": "1 Atomic ingredient", "raw": "1 Atomic ingredient", "sourceMarkdown": "* 1 Atomic ingredient"}],
    "steps": ["First step."]
  },
  {
    "sourceKey": "atomic-invalid",
    "name": "",
    "ingredients": [{"name": "Never created", "requiredQuantity": 1, "originalText": "1 Never created", "raw": "1 Never created", "sourceMarkdown": "* 1 Never created"}],
    "steps": ["Never inserted."]
  }
]
$json$::jsonb),
('lossy', $json$
[
  {
    "sourceKey": "lossy-source",
    "name": "Lossy source",
    "ingredients": [{"name": "Milk", "requiredQuantity": null, "originalText": "Milk", "raw": "Milk", "sourceMarkdown": "* 1 cup Milk"}],
    "steps": ["Use the measured milk."]
  }
]
$json$::jsonb),
('valid', $json$
[
  {
    "sourceKey": "assoc",
    "name": "Association edit",
    "category": "Meal",
    "ingredientMappings": [{"mapping": {"itemId": "30000000-0000-0000-0000-000000000001", "itemName": "Shared ingredient"}, "requiredQuantity": 1, "originalText": "1 Shared ingredient (prepared)", "raw": "1 Shared ingredient (prepared)", "sourceMarkdown": "* 1 Shared ingredient (prepared)"}],
    "steps": ["Association step one.", "Association step two."]
  },
  {
    "sourceKey": "count",
    "name": "Count edit",
    "category": "Meal",
    "ingredientMappings": [{"mapping": {"itemId": "30000000-0000-0000-0000-000000000001", "itemName": "Shared ingredient"}, "requiredQuantity": 2, "originalText": "2 Shared ingredients", "raw": "2 Shared ingredients", "sourceMarkdown": "* 2 Shared ingredients"}],
    "steps": ["Count step."]
  },
  {
    "sourceKey": "details",
    "name": "Details edit",
    "category": "Meal",
    "ingredientMappings": [{"mapping": {"itemId": "30000000-0000-0000-0000-000000000001", "itemName": "Shared ingredient"}, "requiredQuantity": null, "originalText": "0.66 cup Shared ingredient (prepared)", "raw": "0.66 cup Shared ingredient (prepared)", "sourceMarkdown": "* 0.66 cup Shared ingredient (prepared)"}],
    "steps": ["Details step."]
  },
  {
    "sourceKey": "instructions",
    "name": "Instruction edit",
    "category": "Meal",
    "ingredientMappings": [{"mapping": {"itemId": "30000000-0000-0000-0000-000000000001", "itemName": "Shared ingredient"}, "requiredQuantity": 1, "originalText": "1 Shared ingredient", "raw": "1 Shared ingredient", "sourceMarkdown": "* 1 Shared ingredient"}],
    "steps": ["Original instruction."]
  },
  {
    "sourceKey": "scheduled",
    "name": "Scheduled meal",
    "category": "Meal",
    "ingredientMappings": [{"mapping": {"itemId": "30000000-0000-0000-0000-000000000001", "itemName": "Shared ingredient"}, "requiredQuantity": 1, "originalText": "1 Shared ingredient", "raw": "1 Shared ingredient", "sourceMarkdown": "* 1 Shared ingredient"}],
    "steps": ["Scheduled step."]
  },
  {
    "sourceKey": "untouched",
    "name": "Untouched meal",
    "category": "Meal",
    "ingredientMappings": [{"mapping": {"itemId": "30000000-0000-0000-0000-000000000001", "itemName": "Shared ingredient"}, "requiredQuantity": 4, "originalText": "4 Shared ingredients", "raw": "4 Shared ingredients", "sourceMarkdown": "* 4 Shared ingredients"}],
    "steps": ["Untouched step."]
  },
  {
    "sourceKey": "source-text",
    "name": "Source text edit",
    "category": "Meal",
    "ingredientMappings": [{"mapping": {"itemId": "30000000-0000-0000-0000-000000000001", "itemName": "Shared ingredient"}, "requiredQuantity": null, "originalText": "2 tbsp Shared ingredient (finely prepared)", "raw": "2 tbsp Shared ingredient (finely prepared)", "sourceMarkdown": "* 2 tbsp Shared ingredient (finely prepared)"}],
    "steps": ["Source text step."]
  }
]
$json$::jsonb);

create temp table import_test_results (
  name text primary key,
  result jsonb not null
);

grant select on import_test_payloads to authenticated;
grant select, insert on import_test_results to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', '40000000-0000-0000-0000-000000000001',
    'role', 'authenticated',
    'app_metadata', jsonb_build_object('household_id', '10000000-0000-0000-0000-000000000001')
  )::text,
  true
);

select throws_ok(
  $$select public.import_meal_batch(
    '50000000-0000-0000-0000-000000000001',
    'atomic-source',
    repeat('b', 64),
    (select payload from import_test_payloads where name = 'atomic')
  )$$,
  '22023',
  'meal name is required',
  'a late validation failure aborts the entire import'
);
select is((select count(*) from public.meal_import_batches where id = '50000000-0000-0000-0000-000000000001'), 0::bigint, 'atomic failure leaves no batch');
select is((select count(*) from public.meals where name = 'Atomic first'), 0::bigint, 'atomic failure leaves no meal');
select is((select count(*) from public.items where household_id = '10000000-0000-0000-0000-000000000001' and lower(name) = 'atomic ingredient'), 0::bigint, 'atomic failure leaves no item');

select throws_ok(
  $$select public.import_meal_batch(
    '50000000-0000-0000-0000-000000000004',
    'lossy-source',
    repeat('c', 64),
    (select payload from import_test_payloads where name = 'lossy')
  )$$,
  '22023',
  'ingredient source Markdown does not match original text',
  'an import cannot discard an original quantity during normalization'
);
select is((select count(*) from public.meal_import_batches where id = '50000000-0000-0000-0000-000000000004'), 0::bigint, 'quantity preservation failure leaves no batch');

select lives_ok(
  $$insert into import_test_results (name, result)
    select 'import', public.import_meal_batch(
      '50000000-0000-0000-0000-000000000002',
      'knorr-sidekicks-meal-plan',
      repeat('a', 64),
      (select payload from import_test_payloads where name = 'valid')
    )$$,
  'valid batch imports transactionally'
);
select is((select status from public.meal_import_batches where id = '50000000-0000-0000-0000-000000000002'), 'active', 'batch is active after import');
select is((select count(*) from public.meal_import_batch_meals where batch_id = '50000000-0000-0000-0000-000000000002'), 7::bigint, 'all meals are mapped to the batch');
select is((
  select n.required_quantity
    from public.meal_import_batch_meals bm
    join public.meal_need_list n on n.meal_id = bm.meal_id
   where bm.batch_id = '50000000-0000-0000-0000-000000000002' and bm.source_key = 'untouched'
), 4, 'required ingredient count is imported');
select is((
  select n.original_ingredient_text
    from public.meal_import_batch_meals bm
    join public.meal_need_list n on n.meal_id = bm.meal_id
   where bm.batch_id = '50000000-0000-0000-0000-000000000002' and bm.source_key = 'details'
), '0.66 cup Shared ingredient (prepared)', 'original quantity, measurement, and preparation text is imported exactly');
select is((
  select n.source_markdown
    from public.meal_import_batch_meals bm
    join public.meal_need_list n on n.meal_id = bm.meal_id
   where bm.batch_id = '50000000-0000-0000-0000-000000000002' and bm.source_key = 'details'
), '* 0.66 cup Shared ingredient (prepared)', 'complete ingredient Markdown is imported exactly');
select is((
  select string_agg(s.text, '|' order by s.position)
    from public.meal_import_batch_meals bm
    join public.meal_steps s on s.meal_id = bm.meal_id
   where bm.batch_id = '50000000-0000-0000-0000-000000000002' and bm.source_key = 'assoc'
), 'Association step one.|Association step two.', 'step order is imported');

select lives_ok(
  $$insert into import_test_results (name, result)
    select 'idempotent_import', public.import_meal_batch(
      '50000000-0000-0000-0000-000000000002',
      'knorr-sidekicks-meal-plan',
      repeat('a', 64),
      (select payload from import_test_payloads where name = 'valid')
    )$$,
  'repeating the operation id succeeds'
);
select is((select result ->> 'idempotent' from import_test_results where name = 'idempotent_import'), 'true', 'repeated operation reports idempotency');
select is((select count(*) from public.meals where household_id = '10000000-0000-0000-0000-000000000001'), 7::bigint, 'idempotent retry creates no meals');

select lives_ok(
  $$insert into import_test_results (name, result)
    select 'duplicate', public.import_meal_batch(
      '50000000-0000-0000-0000-000000000003',
      'knorr-sidekicks-meal-plan',
      repeat('a', 64),
      (select payload from import_test_payloads where name = 'valid')
    )$$,
  'duplicate source checksum is detected without error'
);
select is((select result ->> 'status' from import_test_results where name = 'duplicate'), 'duplicate', 'duplicate source reports duplicate status');
select is((select result ->> 'duplicate_of' from import_test_results where name = 'duplicate'), '50000000-0000-0000-0000-000000000002', 'duplicate identifies the original batch');
select is((select count(*) from public.meal_import_batches where source_id = 'knorr-sidekicks-meal-plan'), 1::bigint, 'duplicate source creates no second batch');

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', '40000000-0000-0000-0000-000000000002',
    'role', 'authenticated',
    'app_metadata', jsonb_build_object('household_id', '10000000-0000-0000-0000-000000000002')
  )::text,
  true
);
select is((select count(*) from public.meal_import_batches), 0::bigint, 'batch RLS hides another household');
select is((select count(*) from public.meal_import_batch_meals), 0::bigint, 'mapping RLS hides another household');
select throws_ok(
  $$select public.rollback_meal_import('50000000-0000-0000-0000-000000000002')$$,
  'P0002',
  'import batch not found',
  'another household cannot roll back the batch'
);
select is((select count(*) from public.meals), 0::bigint, 'meal RLS hides another household');

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', '40000000-0000-0000-0000-000000000001',
    'role', 'authenticated',
    'app_metadata', jsonb_build_object('household_id', '10000000-0000-0000-0000-000000000001')
  )::text,
  true
);

reset role;

update public.meals
   set name = 'Details edited'
 where id = (select meal_id from public.meal_import_batch_meals where batch_id = '50000000-0000-0000-0000-000000000002' and source_key = 'details');

delete from public.meal_need_list
 where meal_id = (select meal_id from public.meal_import_batch_meals where batch_id = '50000000-0000-0000-0000-000000000002' and source_key = 'assoc');
insert into public.meal_need_list (meal_id, item_id, required_quantity)
select meal_id, '30000000-0000-0000-0000-000000000002', 1
  from public.meal_import_batch_meals
 where batch_id = '50000000-0000-0000-0000-000000000002' and source_key = 'assoc';

update public.meal_need_list
   set required_quantity = 9
 where meal_id = (select meal_id from public.meal_import_batch_meals where batch_id = '50000000-0000-0000-0000-000000000002' and source_key = 'count');

update public.meal_steps
   set text = 'Edited instruction.'
 where meal_id = (select meal_id from public.meal_import_batch_meals where batch_id = '50000000-0000-0000-0000-000000000002' and source_key = 'instructions');

update public.meal_need_list
   set original_ingredient_text = '2 tbsp Shared ingredient (coarsely prepared)',
       source_markdown = '* 2 tbsp Shared ingredient (coarsely prepared)'
 where meal_id = (select meal_id from public.meal_import_batch_meals where batch_id = '50000000-0000-0000-0000-000000000002' and source_key = 'source-text');

insert into public.calendar_entries (household_id, meal_id, date)
select household_id, meal_id, date '2099-01-01'
  from public.meal_import_batch_meals
 where batch_id = '50000000-0000-0000-0000-000000000002' and source_key = 'scheduled';

insert into public.meals (id, household_id, name)
values ('60000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Unrelated meal');
insert into public.inventory_items (household_id, item_id, quantity)
values ('10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '3');
insert into public.grocery_items (household_id, item_id, quantity)
values ('10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '2');

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', '40000000-0000-0000-0000-000000000001',
    'role', 'authenticated',
    'app_metadata', jsonb_build_object('household_id', '10000000-0000-0000-0000-000000000001')
  )::text,
  true
);

select lives_ok(
  $$insert into import_test_results (name, result)
    select 'rollback', public.rollback_meal_import('50000000-0000-0000-0000-000000000002')$$,
  'rollback succeeds'
);

reset role;

select is((select (result ->> 'removed_count')::integer from import_test_results where name = 'rollback'), 1, 'rollback removes one untouched meal');
select is((select (result ->> 'protected_count')::integer from import_test_results where name = 'rollback'), 6, 'rollback protects all edited and scheduled meals');
select is((select result -> 'removed' -> 0 ->> 'source_key' from import_test_results where name = 'rollback'), 'untouched', 'rollback reports the removed meal exactly');
select is((
  select string_agg(entry ->> 'source_key', ',' order by entry ->> 'source_key')
    from import_test_results, jsonb_array_elements(result -> 'protected') entry
   where name = 'rollback'
), 'assoc,count,details,instructions,scheduled,source-text', 'rollback reports the protected meals exactly');
select is((select entry -> 'reasons' from import_test_results, jsonb_array_elements(result -> 'protected') entry where name = 'rollback' and entry ->> 'source_key' = 'details')::text, '["edited"]', 'meal detail edits are detected');
select is((select entry -> 'reasons' from import_test_results, jsonb_array_elements(result -> 'protected') entry where name = 'rollback' and entry ->> 'source_key' = 'assoc')::text, '["edited"]', 'ingredient association edits are detected');
select is((select entry -> 'reasons' from import_test_results, jsonb_array_elements(result -> 'protected') entry where name = 'rollback' and entry ->> 'source_key' = 'count')::text, '["edited"]', 'required count edits are detected');
select is((select entry -> 'reasons' from import_test_results, jsonb_array_elements(result -> 'protected') entry where name = 'rollback' and entry ->> 'source_key' = 'instructions')::text, '["edited"]', 'instruction edits are detected');
select is((select entry -> 'reasons' from import_test_results, jsonb_array_elements(result -> 'protected') entry where name = 'rollback' and entry ->> 'source_key' = 'source-text')::text, '["edited"]', 'original ingredient text edits are detected');
select is((select entry -> 'reasons' from import_test_results, jsonb_array_elements(result -> 'protected') entry where name = 'rollback' and entry ->> 'source_key' = 'scheduled')::text, '["scheduled"]', 'scheduled meals are protected');
select is((select count(*) from public.meals where name = 'Untouched meal'), 0::bigint, 'untouched imported meal is deleted');
select is((select count(*) from public.meal_import_batch_meals where status = 'protected' and meal_id is not null), 6::bigint, 'protected imported meals remain');
select is((select count(*) from public.meals where id = '60000000-0000-0000-0000-000000000001'), 1::bigint, 'unrelated meal remains');
select is((select count(*) from public.items where household_id = '10000000-0000-0000-0000-000000000001'), 2::bigint, 'shared items remain');
select is((select count(*) from public.inventory_items where item_id = '30000000-0000-0000-0000-000000000001'), 1::bigint, 'inventory remains');
select is((select count(*) from public.grocery_items where item_id = '30000000-0000-0000-0000-000000000001'), 1::bigint, 'grocery rows remain');
select is((select count(*) from public.calendar_entries where meal_id is not null and date = date '2099-01-01'), 1::bigint, 'scheduled meal relation remains');
select is((
  select count(*) from public.meal_need_list
   where meal_id = (select meal_id from public.meal_import_batch_meals where source_key = 'assoc')
     and item_id = '30000000-0000-0000-0000-000000000002'
), 1::bigint, 'edited ingredient association remains');
select is((select status from public.meal_import_batches where id = '50000000-0000-0000-0000-000000000002'), 'rolled_back', 'batch records rolled-back status');
select is((select count(*) from public.meal_import_batch_meals where status = 'removed' and meal_id is null), 1::bigint, 'removed mapping retains its imported meal id');
select is((select count(*) from public.meal_import_batch_meals where status = 'protected'), 6::bigint, 'protected mappings record their disposition');

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', '40000000-0000-0000-0000-000000000001',
    'role', 'authenticated',
    'app_metadata', jsonb_build_object('household_id', '10000000-0000-0000-0000-000000000001')
  )::text,
  true
);

select lives_ok(
  $$insert into import_test_results (name, result)
    select 'rollback_retry', public.rollback_meal_import('50000000-0000-0000-0000-000000000002')$$,
  'rollback retry succeeds'
);
select is((select result ->> 'idempotent' from import_test_results where name = 'rollback_retry'), 'true', 'rollback retry reports idempotency');
select is((
  select result -> 'removed' from import_test_results where name = 'rollback_retry'
), (select result -> 'removed' from import_test_results where name = 'rollback'), 'rollback retry reports the same removed meals');
select is((
  select result -> 'protected' from import_test_results where name = 'rollback_retry'
), (select result -> 'protected' from import_test_results where name = 'rollback'), 'rollback retry reports the same protected meals');

select * from finish();
rollback;
