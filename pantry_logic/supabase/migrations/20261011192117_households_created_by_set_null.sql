-- Deleting the creator's auth account must not delete the household.
-- Previously households.created_by -> auth.users was ON DELETE CASCADE, which
-- wiped the household and (via household_id cascades) all items, inventory,
-- grocery, meal, storage location, meal category and calendar rows.
--
-- created_by is informational only. Ownership is profiles.role, exposed to
-- RLS as the JWT app_metadata.household_role claim (households_update_owner).
-- The only policy using created_by is households_insert_owner
-- (WITH CHECK created_by = auth.uid()), which still requires it on insert.
-- No functions or triggers reference created_by.

alter table public.households
  alter column created_by drop not null;

alter table public.households
  drop constraint households_created_by_fkey,
  add constraint households_created_by_fkey
    foreign key (created_by) references auth.users (id) on delete set null;

comment on column public.households.created_by is
  'auth.users.id of the user who created this household. Informational only; NULL once that account is deleted. Ownership is profiles.role.';
