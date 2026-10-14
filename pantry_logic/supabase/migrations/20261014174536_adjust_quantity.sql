-- Atomic +/- for stock quantities (Stock row stepper, batch stock entry).
--
-- inventory_items.quantity is free text ("2", "1.5", "500 ml", "½"). Only
-- empty or plain-decimal quantities can be adjusted; anything else raises
-- 22023 and the client never offers a stepper for it (see
-- isSteppableQuantity in lib/core/quantity.dart — keep the regex in sync).
--
-- p_item_id is an inventory_items.id (the stock row), not an items.id.
--
-- Concurrency: the row is locked FOR UPDATE, so simultaneous taps from
-- several household members serialize and every delta is applied.
--
-- RLS: SECURITY INVOKER, so the select/update go through the existing
-- "inventory_household_all" policy (JWT household_id). A row in another
-- household is invisible and reports "not found".
--
-- Returns numeric, not int: quantities such as "1.5" exist and must survive
-- a +1. The result is clamped at 0. (Removing a used-up item is
-- consume_item's job.)

-- Stored quantity text → number: '' / null → 0, plain decimal → value,
-- anything else → null (not adjustable).
create or replace function public.stock_quantity_numeric(p_quantity text)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case
    when btrim(coalesce(p_quantity, '')) = '' then 0::numeric
    when btrim(p_quantity) ~ '^\d*\.?\d+$' then btrim(p_quantity)::numeric
  end
$$;

create or replace function public.adjust_quantity(p_item_id uuid, p_delta int)
returns numeric
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_raw text;
  v_cur numeric;
  v_new numeric;
begin
  if p_delta is null then
    raise exception 'delta is required' using errcode = '22004';
  end if;

  select quantity into v_raw
    from inventory_items
   where id = p_item_id
     for update;
  if not found then
    raise exception 'inventory item not found' using errcode = 'P0002';
  end if;

  v_cur := stock_quantity_numeric(v_raw);
  if v_cur is null then
    raise exception 'quantity is not numeric' using errcode = '22023';
  end if;

  v_new := trim_scale(round(greatest(v_cur + p_delta, 0), 3));

  update inventory_items
     set quantity = v_new::text
   where id = p_item_id;

  return v_new;
end;
$$;

revoke all on function public.stock_quantity_numeric(text) from public, anon;
revoke all on function public.adjust_quantity(uuid, int) from public, anon;
grant execute on function public.stock_quantity_numeric(text) to authenticated;
grant execute on function public.adjust_quantity(uuid, int) to authenticated;
