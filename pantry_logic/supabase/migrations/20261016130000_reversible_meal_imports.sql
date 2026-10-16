alter table public.meal_need_list
  add column original_ingredient_text text,
  add column source_markdown text,
  add column ingredient_position integer,
  add constraint meal_need_list_original_ingredient_text_length
    check (original_ingredient_text is null or length(btrim(original_ingredient_text)) between 1 and 2000),
  add constraint meal_need_list_source_markdown_length
    check (source_markdown is null or length(source_markdown) between 3 and 2002),
  add constraint meal_need_list_source_markdown_matches_original
    check (
      source_markdown is null
      or (
        source_markdown ~ E'^\\*\\s+'
        and regexp_replace(source_markdown, E'^\\*\\s+', '') = original_ingredient_text
      )
    ),
  add constraint meal_need_list_ingredient_position_nonnegative
    check (ingredient_position is null or ingredient_position >= 0);

create unique index meal_need_list_meal_ingredient_position_key
  on public.meal_need_list (meal_id, ingredient_position)
  where ingredient_position is not null;

create table public.meal_import_batches (
  id uuid primary key,
  household_id uuid not null references public.households(id) on delete cascade,
  source_id text not null check (length(btrim(source_id)) between 1 and 200),
  source_checksum text not null check (source_checksum ~ '^[0-9a-f]{64}$'),
  payload_checksum text not null check (payload_checksum ~ '^[0-9a-f]{64}$'),
  status text not null default 'active' check (status in ('active', 'rolled_back')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  rolled_back_at timestamptz,
  import_result jsonb,
  rollback_result jsonb,
  constraint meal_import_batches_id_household_key unique (id, household_id)
);

create unique index meal_import_batches_active_source_key
  on public.meal_import_batches (household_id, source_id, source_checksum)
  where status = 'active';

create table public.meal_import_batch_meals (
  batch_id uuid not null,
  household_id uuid not null,
  source_key text not null check (length(btrim(source_key)) between 1 and 200),
  meal_id uuid,
  imported_meal_id uuid not null,
  meal_name text not null,
  imported_checksum text not null check (imported_checksum ~ '^[0-9a-f]{64}$'),
  status text not null default 'imported' check (status in ('imported', 'removed', 'protected')),
  rollback_reasons jsonb,
  created_at timestamptz not null default now(),
  evaluated_at timestamptz,
  primary key (batch_id, source_key),
  constraint meal_import_batch_meals_batch_fkey
    foreign key (batch_id, household_id)
    references public.meal_import_batches(id, household_id)
    on delete cascade,
  constraint meal_import_batch_meals_meal_fkey
    foreign key (meal_id, household_id)
    references public.meals(id, household_id)
    on delete set null (meal_id),
  constraint meal_import_batch_meals_live_id_check
    check (meal_id is null or meal_id = imported_meal_id)
);

create unique index meal_import_batch_meals_live_meal_key
  on public.meal_import_batch_meals (meal_id)
  where meal_id is not null;

create index meal_import_batch_meals_household_batch_idx
  on public.meal_import_batch_meals (household_id, batch_id);

alter table public.meal_import_batches enable row level security;
alter table public.meal_import_batch_meals enable row level security;

create policy meal_import_batches_household_select
  on public.meal_import_batches
  for select to authenticated
  using (household_id = nullif(auth.jwt() -> 'app_metadata' ->> 'household_id', '')::uuid);

create policy meal_import_batch_meals_household_select
  on public.meal_import_batch_meals
  for select to authenticated
  using (household_id = nullif(auth.jwt() -> 'app_metadata' ->> 'household_id', '')::uuid);

revoke all on public.meal_import_batches from public, anon, authenticated;
revoke all on public.meal_import_batch_meals from public, anon, authenticated;
grant select on public.meal_import_batches to authenticated;
grant select on public.meal_import_batch_meals to authenticated;

create or replace function public.import_meal_batch(
  p_batch_id uuid,
  p_source_id text,
  p_source_checksum text,
  p_meals jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id uuid := auth.uid();
  v_household_id uuid := nullif(auth.jwt() -> 'app_metadata' ->> 'household_id', '')::uuid;
  v_source_id text := btrim(coalesce(p_source_id, ''));
  v_source_checksum text := lower(btrim(coalesce(p_source_checksum, '')));
  v_payload_checksum text;
  v_existing public.meal_import_batches;
  v_duplicate public.meal_import_batches;
  v_meal jsonb;
  v_ingredient jsonb;
  v_ingredients jsonb;
  v_step jsonb;
  v_source_key text;
  v_meal_name text;
  v_notes text;
  v_category_id uuid;
  v_category_text text;
  v_meal_id uuid;
  v_item_id uuid;
  v_item_id_text text;
  v_item_name text;
  v_original_ingredient_text text;
  v_source_markdown text;
  v_required_text text;
  v_required_quantity integer;
  v_position integer;
  v_snapshot jsonb;
  v_meal_checksum text;
  v_created_items integer := 0;
  v_result_meals jsonb := '[]'::jsonb;
  v_result jsonb;
begin
  if v_user_id is null or v_household_id is null then
    raise exception 'not authenticated or household missing' using errcode = '42501';
  end if;
  if p_batch_id is null then
    raise exception 'batch id is required' using errcode = '22023';
  end if;
  if length(v_source_id) not between 1 and 200 then
    raise exception 'source id is invalid' using errcode = '22023';
  end if;
  if v_source_checksum !~ '^[0-9a-f]{64}$' then
    raise exception 'source checksum must be a SHA-256 hex digest' using errcode = '22023';
  end if;
  if p_meals is null
     or jsonb_typeof(p_meals) <> 'array'
     or jsonb_array_length(p_meals) not between 1 and 100 then
    raise exception 'meals must be a non-empty array of at most 100 entries' using errcode = '22023';
  end if;

  v_payload_checksum := encode(extensions.digest(convert_to(p_meals::text, 'UTF8'), 'sha256'), 'hex');
  perform pg_advisory_xact_lock(hashtextextended(p_batch_id::text, 0));

  select * into v_existing
    from public.meal_import_batches
   where id = p_batch_id and household_id = v_household_id
   for update;
  if found then
    if v_existing.source_id <> v_source_id
       or v_existing.source_checksum <> v_source_checksum
       or v_existing.payload_checksum <> v_payload_checksum then
      raise exception 'batch id already used for different import data' using errcode = '22023';
    end if;
    if v_existing.status = 'rolled_back' then
      return coalesce(v_existing.rollback_result, '{}'::jsonb)
        || jsonb_build_object('idempotent', true, 'status', 'rolled_back');
    end if;
    return coalesce(v_existing.import_result, '{}'::jsonb)
      || jsonb_build_object('idempotent', true);
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_household_id::text || ':' || v_source_id || ':' || v_source_checksum, 0));
  select * into v_duplicate
    from public.meal_import_batches
   where household_id = v_household_id
     and source_id = v_source_id
     and source_checksum = v_source_checksum
     and status = 'active'
   for update;
  if found then
    return jsonb_build_object(
      'status', 'duplicate',
      'batch_id', v_duplicate.id,
      'duplicate_of', v_duplicate.id,
      'idempotent', false,
      'meals', coalesce(v_duplicate.import_result -> 'meals', '[]'::jsonb)
    );
  end if;

  insert into public.meal_import_batches (
    id, household_id, source_id, source_checksum, payload_checksum, created_by
  ) values (
    p_batch_id,
    v_household_id,
    v_source_id,
    v_source_checksum,
    v_payload_checksum,
    case when exists (select 1 from public.profiles where id = v_user_id) then v_user_id end
  );

  for v_meal in select value from jsonb_array_elements(p_meals)
  loop
    if jsonb_typeof(v_meal) <> 'object' then
      raise exception 'each meal must be an object' using errcode = '22023';
    end if;

    v_source_key := btrim(coalesce(v_meal ->> 'sourceKey', v_meal ->> 'source_key', ''));
    v_meal_name := btrim(coalesce(v_meal ->> 'name', ''));
    v_notes := nullif(btrim(coalesce(v_meal ->> 'notes', '')), '');
    if length(v_source_key) not between 1 and 200 then
      raise exception 'meal source key is required' using errcode = '22023';
    end if;
    if length(v_meal_name) not between 1 and 200 then
      raise exception 'meal name is required' using errcode = '22023';
    end if;

    v_category_id := null;
    v_category_text := nullif(coalesce(v_meal ->> 'categoryId', v_meal ->> 'category_id'), '');
    if v_category_text is not null then
      begin
        v_category_id := v_category_text::uuid;
      exception when invalid_text_representation then
        raise exception 'meal category id is invalid' using errcode = '22023';
      end;
      perform 1 from public.meal_categories
       where id = v_category_id and household_id = v_household_id;
      if not found then
        raise exception 'meal category not found' using errcode = 'P0002';
      end if;
    elsif nullif(btrim(coalesce(v_meal ->> 'category', '')), '') is not null then
      select id into v_category_id
        from public.meal_categories
       where household_id = v_household_id
         and lower(name) = lower(btrim(v_meal ->> 'category'));
      if not found then
        raise exception 'meal category not found' using errcode = 'P0002';
      end if;
    end if;

    if jsonb_typeof(v_meal -> 'ingredientMappings') = 'array' then
      v_ingredients := v_meal -> 'ingredientMappings';
    else
      v_ingredients := v_meal -> 'ingredients';
    end if;
    if v_ingredients is null
       or jsonb_typeof(v_ingredients) <> 'array'
       or jsonb_array_length(v_ingredients) = 0 then
      raise exception 'meal ingredients must be a non-empty array' using errcode = '22023';
    end if;
    if v_meal -> 'steps' is null
       or jsonb_typeof(v_meal -> 'steps') <> 'array'
       or jsonb_array_length(v_meal -> 'steps') = 0 then
      raise exception 'meal steps must be a non-empty array' using errcode = '22023';
    end if;

    insert into public.meals (household_id, name, category_id, notes)
    values (v_household_id, v_meal_name, v_category_id, v_notes)
    returning id into v_meal_id;

    v_position := 0;
    for v_ingredient in select value from jsonb_array_elements(v_ingredients)
    loop
      if jsonb_typeof(v_ingredient) <> 'object' then
        raise exception 'each ingredient must be an object' using errcode = '22023';
      end if;
      v_item_id := null;
      v_item_id_text := nullif(coalesce(
        v_ingredient #>> '{mapping,itemId}',
        v_ingredient ->> 'itemId',
        v_ingredient ->> 'item_id'
      ), '');
      v_item_name := btrim(coalesce(
        v_ingredient #>> '{mapping,itemName}',
        v_ingredient ->> 'itemName',
        v_ingredient ->> 'item_name',
        v_ingredient ->> 'name',
        ''
      ));
      v_original_ingredient_text := v_ingredient ->> 'originalText';
      v_source_markdown := v_ingredient ->> 'sourceMarkdown';
      if length(btrim(coalesce(v_original_ingredient_text, ''))) not between 1 and 2000 then
        raise exception 'ingredient original text is required' using errcode = '22023';
      end if;
      if length(coalesce(v_source_markdown, '')) not between 3 and 2002
         or v_source_markdown !~ E'^\\*\\s+'
         or regexp_replace(v_source_markdown, E'^\\*\\s+', '') <> v_original_ingredient_text then
        raise exception 'ingredient source Markdown does not match original text' using errcode = '22023';
      end if;
      if v_ingredient ? 'raw'
         and (v_ingredient ->> 'raw') is distinct from v_original_ingredient_text then
        raise exception 'ingredient raw text does not match original text' using errcode = '22023';
      end if;

      if v_item_id_text is not null then
        begin
          v_item_id := v_item_id_text::uuid;
        exception when invalid_text_representation then
          raise exception 'ingredient item id is invalid' using errcode = '22023';
        end;
        perform 1 from public.items where id = v_item_id and household_id = v_household_id;
        if not found then
          raise exception 'ingredient item not found' using errcode = 'P0002';
        end if;
      else
        if length(v_item_name) not between 1 and 200 then
          raise exception 'ingredient item name is required' using errcode = '22023';
        end if;
        select id into v_item_id
          from public.items
         where household_id = v_household_id and lower(name) = lower(v_item_name);
        if not found then
          insert into public.items (household_id, name)
          values (v_household_id, v_item_name)
          on conflict do nothing
          returning id into v_item_id;
          if v_item_id is not null then
            v_created_items := v_created_items + 1;
          else
            select id into v_item_id
              from public.items
             where household_id = v_household_id and lower(name) = lower(v_item_name);
          end if;
        end if;
      end if;

      v_required_text := coalesce(
        v_ingredient ->> 'requiredQuantity',
        v_ingredient ->> 'required_quantity'
      );
      v_required_quantity := null;
      if v_required_text is not null then
        if v_required_text !~ '^[1-9][0-9]*$' or length(v_required_text) > 10 then
          raise exception 'required quantity must be a positive integer' using errcode = '22023';
        end if;
        begin
          v_required_quantity := v_required_text::integer;
        exception when numeric_value_out_of_range then
          raise exception 'required quantity is too large' using errcode = '22023';
        end;
      end if;

      begin
        insert into public.meal_need_list (
          meal_id,
          item_id,
          required_quantity,
          original_ingredient_text,
          source_markdown,
          ingredient_position
        ) values (
          v_meal_id,
          v_item_id,
          v_required_quantity,
          v_original_ingredient_text,
          v_source_markdown,
          v_position
        );
      exception when unique_violation then
        raise exception 'meal contains a duplicate ingredient' using errcode = '22023';
      end;
      v_position := v_position + 1;
    end loop;

    v_position := 0;
    for v_step in select value from jsonb_array_elements(v_meal -> 'steps')
    loop
      if jsonb_typeof(v_step) <> 'string'
         or length(btrim(v_step #>> '{}')) not between 1 and 2000 then
        raise exception 'each meal step must be a non-empty string of at most 2000 characters' using errcode = '22023';
      end if;
      insert into public.meal_steps (meal_id, household_id, position, text)
      values (v_meal_id, v_household_id, v_position, btrim(v_step #>> '{}'));
      v_position := v_position + 1;
    end loop;

    select jsonb_build_object(
      'name', m.name,
      'category_id', m.category_id,
      'notes', m.notes,
      'ingredients', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'item_id', n.item_id,
            'required_quantity', n.required_quantity,
            'original_ingredient_text', n.original_ingredient_text,
            'source_markdown', n.source_markdown,
            'ingredient_position', n.ingredient_position
          )
          order by n.ingredient_position nulls last, n.item_id
        )
        from public.meal_need_list n where n.meal_id = m.id
      ), '[]'::jsonb),
      'steps', coalesce((
        select jsonb_agg(
          jsonb_build_object('position', s.position, 'text', s.text)
          order by s.position, s.id
        )
        from public.meal_steps s where s.meal_id = m.id
      ), '[]'::jsonb)
    ) into v_snapshot
    from public.meals m where m.id = v_meal_id;
    v_meal_checksum := encode(extensions.digest(convert_to(v_snapshot::text, 'UTF8'), 'sha256'), 'hex');

    begin
      insert into public.meal_import_batch_meals (
        batch_id, household_id, source_key, meal_id, imported_meal_id, meal_name, imported_checksum
      ) values (
        p_batch_id, v_household_id, v_source_key, v_meal_id, v_meal_id, v_meal_name, v_meal_checksum
      );
    exception when unique_violation then
      raise exception 'meal source keys must be unique within a batch' using errcode = '22023';
    end;

    v_result_meals := v_result_meals || jsonb_build_array(jsonb_build_object(
      'source_key', v_source_key,
      'meal_id', v_meal_id,
      'name', v_meal_name
    ));
  end loop;

  v_result := jsonb_build_object(
    'status', 'imported',
    'batch_id', p_batch_id,
    'source_id', v_source_id,
    'source_checksum', v_source_checksum,
    'items_created', v_created_items,
    'meals', v_result_meals,
    'idempotent', false
  );
  update public.meal_import_batches set import_result = v_result where id = p_batch_id;
  return v_result;
end;
$$;

create or replace function public.rollback_meal_import(p_batch_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id uuid := auth.uid();
  v_household_id uuid := nullif(auth.jwt() -> 'app_metadata' ->> 'household_id', '')::uuid;
  v_batch public.meal_import_batches;
  v_mapping public.meal_import_batch_meals;
  v_meal public.meals;
  v_snapshot jsonb;
  v_current_checksum text;
  v_reasons jsonb;
  v_removed jsonb := '[]'::jsonb;
  v_protected jsonb := '[]'::jsonb;
  v_result jsonb;
begin
  if v_user_id is null or v_household_id is null then
    raise exception 'not authenticated or household missing' using errcode = '42501';
  end if;
  if p_batch_id is null then
    raise exception 'batch id is required' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_batch_id::text, 0));
  select * into v_batch
    from public.meal_import_batches
   where id = p_batch_id and household_id = v_household_id
   for update;
  if not found then
    raise exception 'import batch not found' using errcode = 'P0002';
  end if;
  if v_batch.status = 'rolled_back' then
    return coalesce(v_batch.rollback_result, '{}'::jsonb)
      || jsonb_build_object('idempotent', true);
  end if;

  for v_mapping in
    select * from public.meal_import_batch_meals
     where batch_id = p_batch_id and household_id = v_household_id
     order by source_key
     for update
  loop
    v_reasons := '[]'::jsonb;
    if v_mapping.meal_id is null then
      v_reasons := jsonb_build_array('missing');
    else
      select * into v_meal
        from public.meals
       where id = v_mapping.meal_id and household_id = v_household_id
       for update;
      if not found then
        v_reasons := jsonb_build_array('missing');
      else
        perform 1 from public.meal_need_list where meal_id = v_meal.id for update;
        perform 1 from public.meal_steps where meal_id = v_meal.id for update;

        select jsonb_build_object(
          'name', m.name,
          'category_id', m.category_id,
          'notes', m.notes,
          'ingredients', coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'item_id', n.item_id,
                'required_quantity', n.required_quantity,
                'original_ingredient_text', n.original_ingredient_text,
                'source_markdown', n.source_markdown,
                'ingredient_position', n.ingredient_position
              )
              order by n.ingredient_position nulls last, n.item_id
            )
            from public.meal_need_list n where n.meal_id = m.id
          ), '[]'::jsonb),
          'steps', coalesce((
            select jsonb_agg(
              jsonb_build_object('position', s.position, 'text', s.text)
              order by s.position, s.id
            )
            from public.meal_steps s where s.meal_id = m.id
          ), '[]'::jsonb)
        ) into v_snapshot
        from public.meals m where m.id = v_meal.id;
        v_current_checksum := encode(extensions.digest(convert_to(v_snapshot::text, 'UTF8'), 'sha256'), 'hex');

        if exists (select 1 from public.calendar_entries where meal_id = v_meal.id) then
          v_reasons := v_reasons || jsonb_build_array('scheduled');
        end if;
        if v_current_checksum <> v_mapping.imported_checksum then
          v_reasons := v_reasons || jsonb_build_array('edited');
        end if;
      end if;
    end if;

    if jsonb_array_length(v_reasons) = 0 then
      delete from public.meals where id = v_meal.id and household_id = v_household_id;
      update public.meal_import_batch_meals
         set status = 'removed', rollback_reasons = '[]'::jsonb, evaluated_at = now()
       where batch_id = p_batch_id and source_key = v_mapping.source_key;
      v_removed := v_removed || jsonb_build_array(jsonb_build_object(
        'source_key', v_mapping.source_key,
        'meal_id', v_mapping.imported_meal_id,
        'name', v_mapping.meal_name
      ));
    else
      update public.meal_import_batch_meals
         set status = 'protected', rollback_reasons = v_reasons, evaluated_at = now()
       where batch_id = p_batch_id and source_key = v_mapping.source_key;
      v_protected := v_protected || jsonb_build_array(jsonb_build_object(
        'source_key', v_mapping.source_key,
        'meal_id', v_mapping.imported_meal_id,
        'name', v_mapping.meal_name,
        'reasons', v_reasons
      ));
    end if;
  end loop;

  v_result := jsonb_build_object(
    'status', 'rolled_back',
    'batch_id', p_batch_id,
    'removed', v_removed,
    'protected', v_protected,
    'removed_count', jsonb_array_length(v_removed),
    'protected_count', jsonb_array_length(v_protected),
    'idempotent', false
  );
  update public.meal_import_batches
     set status = 'rolled_back', rolled_back_at = now(), rollback_result = v_result
   where id = p_batch_id;
  return v_result;
end;
$$;

revoke all on function public.import_meal_batch(uuid, text, text, jsonb) from public, anon;
revoke all on function public.rollback_meal_import(uuid) from public, anon;
grant execute on function public.import_meal_batch(uuid, text, text, jsonb) to authenticated;
grant execute on function public.rollback_meal_import(uuid) to authenticated;
