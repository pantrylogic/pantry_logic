-- "Used up": apply a quantity delta and delete the stock row if the result
-- is <= 0, all under one row lock in one transaction.
--
-- p_item_id is an inventory_items.id. p_delta is signed, as in
-- adjust_quantity (the client passes the negative total of its pending
-- taps).
--
-- Returns the deleted row (one row) so Undo can re-insert it as it was.
-- Returns no rows when the result is still > 0 — e.g. another household
-- member added stock in the meantime — in which case the quantity is
-- updated like adjust_quantity and the row is kept.
--
-- Errors: P0002 when the row is already gone (someone else removed it),
-- 22023 when the quantity isn't adjustable (see stock_quantity_numeric).
--
-- RLS: SECURITY INVOKER; the existing "inventory_household_all" policy
-- applies to the select, update and delete … returning.

create or replace function public.consume_item(p_item_id uuid, p_delta int)
returns setof public.inventory_items
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_quantity text;
  v_cur      numeric;
  v_new      numeric;
begin
  if p_delta is null then
    raise exception 'delta is required' using errcode = '22004';
  end if;

  select quantity into v_quantity
    from inventory_items
   where id = p_item_id
     for update;
  if not found then
    raise exception 'inventory item not found' using errcode = 'P0002';
  end if;

  v_cur := stock_quantity_numeric(v_quantity);
  if v_cur is null then
    raise exception 'quantity is not numeric' using errcode = '22023';
  end if;

  v_new := v_cur + p_delta;
  if v_new <= 0 then
    return query
      delete from inventory_items where id = p_item_id returning *;
  else
    update inventory_items
       set quantity = trim_scale(round(v_new, 3))::text
     where id = p_item_id;
  end if;
end;
$$;

revoke all on function public.consume_item(uuid, int) from public, anon;
grant execute on function public.consume_item(uuid, int) to authenticated;
