-- PROVICA V3.1. Ejecutar UNA VEZ despues de V3.
drop policy if exists "admin_ops_insert_shifts" on public.shifts;
create policy "admin_ops_insert_shifts" on public.shifts for insert to authenticated with check(public.current_user_role() in ('ADMIN','OPERACIONES'));
drop policy if exists "admin_ops_update_shifts" on public.shifts;
create policy "admin_ops_update_shifts" on public.shifts for update to authenticated using(public.current_user_role() in ('ADMIN','OPERACIONES')) with check(public.current_user_role() in ('ADMIN','OPERACIONES'));
create extension if not exists btree_gist;
alter table public.shifts drop constraint if exists shifts_guard_no_overlap;
alter table public.shifts add constraint shifts_guard_no_overlap exclude using gist (guard_id with =,tstzrange(starts_at,ends_at,'[)') with &&) where (guard_id is not null);
alter table public.profiles add column if not exists identification text;
alter table public.profiles add column if not exists phone text;
create unique index if not exists profiles_identification_unique on public.profiles(identification) where identification is not null and identification<>'';
drop policy if exists "admin_hr_update_profiles" on public.profiles;
create policy "admin_hr_update_profiles" on public.profiles for update to authenticated using(public.current_user_role() in ('ADMIN','RRHH')) with check(public.current_user_role() in ('ADMIN','RRHH'));
