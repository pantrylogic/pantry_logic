-- Directions for a meal: an ordered list of steps.
--
-- RLS matches the other household tables: every row carries household_id
-- and the policy compares it with the JWT app_metadata.household_id (no
-- table lookups inside the policy).
--
-- A step's household must be its meal's household. RLS alone can't ensure
-- that (FK checks bypass RLS, so a client could attach a step to another
-- household's meal id), so the meal FK is composite over
-- (meal_id, household_id). That needs a unique key on meals(id, household_id),
-- which is trivially true because meals.id is already the primary key.

alter table public.meals
  add constraint meals_id_household_id_key unique (id, household_id);

create table public.meal_steps (
  id           uuid primary key default gen_random_uuid(),
  meal_id      uuid not null,
  household_id uuid not null references public.households (id) on delete cascade,
  position     integer not null default 0,
  text         text not null check (length(btrim(text)) between 1 and 2000),
  created_at   timestamptz not null default now(),
  constraint meal_steps_meal_fkey
    foreign key (meal_id, household_id)
    references public.meals (id, household_id)
    on delete cascade
);

comment on table public.meal_steps is
  'Ordered directions for a meal. Display order: position, then created_at.';

-- Also serves the composite FK's cascade lookups (meal_id is the leading column).
create index meal_steps_meal_position_idx
  on public.meal_steps (meal_id, position);

alter table public.meal_steps enable row level security;

create policy meal_steps_household_all on public.meal_steps
  for all to authenticated
  using      (household_id = ((auth.jwt() -> 'app_metadata' ->> 'household_id'))::uuid)
  with check (household_id = ((auth.jwt() -> 'app_metadata' ->> 'household_id'))::uuid);

revoke all on public.meal_steps from anon;
grant select, insert, update, delete on public.meal_steps to authenticated;

-- Realtime: the meal detail screen re-fetches steps on any change.
alter publication supabase_realtime add table public.meal_steps;
