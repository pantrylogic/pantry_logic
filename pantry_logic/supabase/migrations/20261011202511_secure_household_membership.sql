-- Household membership can only change through SECURITY DEFINER RPCs.
--
-- Before: any signed-in user could read every household (incl. invite codes),
-- insert households directly, and set their own profiles.household_id / role,
-- i.e. join any household as owner without a code.
--
-- After:
--   * join_household(p_code) / create_household(p_name) are the only paths
--     that set profiles.household_id / role.
--   * households: SELECT own household only (JWT household_id); owners may
--     UPDATE name only; no direct INSERT/DELETE.
--   * profiles: users may UPDATE only display_name and auth_type (column
--     grants, an allow-list). Do NOT re-grant table-level UPDATE on profiles:
--     that would let users change household_id / role again.
--   * anon (signed-out) has no access to either table.

-- ─── join_household ──────────────────────────────────────────────────────────
create or replace function public.join_household(p_code text)
returns public.households
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid       uuid := auth.uid();
  v_current   uuid;
  v_household public.households;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  -- Lock the caller's profile so concurrent create/join calls serialize.
  select household_id into v_current from profiles where id = v_uid for update;
  if not found then
    raise exception 'profile not found' using errcode = 'P0001';
  end if;
  if v_current is not null then
    raise exception 'already in a household' using errcode = 'P0001';
  end if;

  select * into v_household
    from households
   where upper(invite_code) = upper(btrim(coalesce(p_code, '')));
  if not found then
    raise exception 'invalid code' using errcode = 'P0001';
  end if;

  update profiles set household_id = v_household.id, role = 'member' where id = v_uid;
  return v_household;
end;
$$;

-- ─── create_household ────────────────────────────────────────────────────────
create or replace function public.create_household(p_name text)
returns public.households
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid       uuid := auth.uid();
  v_name      text := btrim(coalesce(p_name, ''));
  v_current   uuid;
  v_household public.households;
  v_alphabet  constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_bytes     bytea;
  v_code      text;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if v_name = '' or length(v_name) > 100 then
    raise exception 'invalid name' using errcode = '22023';
  end if;

  select household_id into v_current from profiles where id = v_uid for update;
  if not found then
    raise exception 'profile not found' using errcode = 'P0001';
  end if;
  if v_current is not null then
    raise exception 'already in a household' using errcode = 'P0001';
  end if;

  -- 6-char code from a CSPRNG; 256 % 32 = 0 so there is no modulo bias.
  loop
    v_bytes := extensions.gen_random_bytes(6);
    v_code  := '';
    for i in 0..5 loop
      v_code := v_code || substr(v_alphabet, (get_byte(v_bytes, i) % 32) + 1, 1);
    end loop;
    begin
      insert into households (name, invite_code, created_by)
      values (v_name, v_code, v_uid)
      returning * into v_household;
      exit;
    exception when unique_violation then
      -- invite_code collision: try again
    end;
  end loop;

  update profiles set household_id = v_household.id, role = 'owner' where id = v_uid;
  return v_household;
end;
$$;

revoke all on function public.join_household(text)   from public, anon;
revoke all on function public.create_household(text) from public, anon;
grant execute on function public.join_household(text)   to authenticated;
grant execute on function public.create_household(text) to authenticated;

-- ─── households ──────────────────────────────────────────────────────────────
drop policy households_select_authenticated on public.households;
create policy households_select_own on public.households
  for select to authenticated
  using (id = ((auth.jwt() -> 'app_metadata' ->> 'household_id'))::uuid);

drop policy households_insert_owner on public.households;

drop policy households_update_owner on public.households;
create policy households_update_owner on public.households
  for update to authenticated
  using      (id = ((auth.jwt() -> 'app_metadata' ->> 'household_id'))::uuid
              and (auth.jwt() -> 'app_metadata' ->> 'household_role') = 'owner')
  with check (id = ((auth.jwt() -> 'app_metadata' ->> 'household_id'))::uuid
              and (auth.jwt() -> 'app_metadata' ->> 'household_role') = 'owner');

revoke all on public.households from anon, authenticated;
grant select on public.households to authenticated;
grant update (name) on public.households to authenticated;

-- ─── profiles ────────────────────────────────────────────────────────────────
revoke all on public.profiles from anon;
revoke insert, update, delete, truncate, references, trigger on public.profiles from authenticated;
grant update (display_name, auth_type) on public.profiles to authenticated;
