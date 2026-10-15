-- Confirmed meal consumption: one idempotent, household-scoped transaction.
-- Rollback: drop function public.consume_meal_ingredients(uuid, uuid, jsonb),
-- table public.meal_consumption_operations, and its RLS policies.

create table public.meal_consumption_operations (
  id uuid primary key,
  household_id uuid not null references public.households(id) on delete cascade,
  meal_id uuid not null references public.meals(id) on delete cascade,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  result jsonb not null
);

alter table public.meal_consumption_operations enable row level security;

create policy "Household members manage meal consumption operations"
on public.meal_consumption_operations for all to authenticated
using (household_id = ((auth.jwt() -> 'app_metadata' ->> 'household_id')::uuid))
with check (household_id = ((auth.jwt() -> 'app_metadata' ->> 'household_id')::uuid));

create or replace function public.consume_meal_ingredients(
  p_meal_id uuid,
  p_operation_id uuid,
  p_expected jsonb
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_household_id uuid;
  v_existing jsonb;
  v_need record;
  v_inventory record;
  v_expected jsonb;
  v_current numeric;
  v_new numeric;
  v_applied jsonb := '[]'::jsonb;
  v_skipped jsonb := '[]'::jsonb;
begin
  if p_meal_id is null or p_operation_id is null or jsonb_typeof(p_expected) <> 'array' then
    raise exception 'meal, operation, and expected inventory are required' using errcode = '22023';
  end if;

  select household_id into v_household_id from meals where id = p_meal_id;
  if not found then raise exception 'meal not found' using errcode = 'P0002'; end if;

  select result into v_existing from meal_consumption_operations
   where id = p_operation_id and household_id = v_household_id;
  if found then return v_existing || jsonb_build_object('idempotent', true); end if;

  -- Lock count-tracked rows in item order and reject any preview that changed.
  for v_need in
    select item_id, required_quantity, items.name as item_name
      from meal_need_list join items on items.id = meal_need_list.item_id
     where meal_id = p_meal_id and required_quantity is not null
     order by item_id
  loop
    select value into v_expected from jsonb_array_elements(p_expected)
     where value ->> 'item_id' = v_need.item_id::text limit 1;
    if v_expected is null then raise exception 'missing expected item' using errcode = '22023'; end if;

    select id, quantity, updated_at into v_inventory from inventory_items
     where household_id = v_household_id and item_id = v_need.item_id for update;
    if coalesce(v_expected ->> 'inventory_id', '') is distinct from coalesce(v_inventory.id::text, '')
       or coalesce(v_expected ->> 'quantity', '') is distinct from coalesce(v_inventory.quantity, '')
       or coalesce((v_expected ->> 'updated_at')::timestamptz, '-infinity'::timestamptz) is distinct from coalesce(v_inventory.updated_at, '-infinity'::timestamptz) then
      return jsonb_build_object('status', 'conflict');
    end if;

    if not found then
      v_skipped := v_skipped || jsonb_build_array(jsonb_build_object('item_id', v_need.item_id, 'reason', 'absent'));
    else
      v_current := stock_quantity_numeric(v_inventory.quantity);
      if v_current is null then
        v_skipped := v_skipped || jsonb_build_array(jsonb_build_object('item_id', v_need.item_id, 'reason', 'check_quantity'));
      elsif v_current < v_need.required_quantity then
        v_skipped := v_skipped || jsonb_build_array(jsonb_build_object('item_id', v_need.item_id, 'reason', 'shortage'));
      else
        v_applied := v_applied || jsonb_build_array(jsonb_build_object('item_id', v_need.item_id, 'quantity', v_need.required_quantity));
      end if;
    end if;
  end loop;

  -- Every preview has now been checked while its stock row is locked. Apply
  -- the eligible deductions only after that full validation succeeds.
  for v_need in
    select item_id, required_quantity from meal_need_list
     where meal_id = p_meal_id and required_quantity is not null
     order by item_id
  loop
    if exists (
      select 1 from jsonb_array_elements(v_applied) as applied
       where applied ->> 'item_id' = v_need.item_id::text
    ) then
      select id, quantity into v_inventory from inventory_items
       where household_id = v_household_id and item_id = v_need.item_id;
      v_new := stock_quantity_numeric(v_inventory.quantity) - v_need.required_quantity;
      if v_new = 0 then
        delete from inventory_items where id = v_inventory.id;
      else
        update inventory_items set quantity = trim_scale(round(v_new, 3))::text
         where id = v_inventory.id;
      end if;
    end if;
  end loop;

  v_existing := jsonb_build_object('status', 'success', 'applied', v_applied, 'skipped', v_skipped, 'idempotent', false);
  insert into meal_consumption_operations (id, household_id, meal_id, created_by, result)
  values (p_operation_id, v_household_id, p_meal_id, auth.uid(), v_existing);
  return v_existing;
end;
$$;

revoke all on function public.consume_meal_ingredients(uuid, uuid, jsonb) from public, anon;
grant execute on function public.consume_meal_ingredients(uuid, uuid, jsonb) to authenticated;
