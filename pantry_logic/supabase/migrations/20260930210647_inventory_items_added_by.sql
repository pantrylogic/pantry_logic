-- Track who added each stock (inventory) item, mirroring grocery_items.added_by.
--
-- RLS: inventory_items already has the household-scoped policy
-- "inventory_household_all" (FOR ALL, USING/WITH CHECK on the JWT
-- app_metadata.household_id). Row-level policies cover every column, so the
-- new column needs no extra policy. The display name is read through the
-- existing profiles_select policy (same household only).

alter table public.inventory_items
  add column if not exists added_by uuid
    references public.profiles (id) on delete set null;

comment on column public.inventory_items.added_by is
  'Profile that added the item to stock (carried over from the grocery row on check-off). Null for rows created before this column existed.';

-- Index the foreign key (lookups on profile deletion / joins).
create index if not exists inventory_items_added_by_idx
  on public.inventory_items (added_by);
