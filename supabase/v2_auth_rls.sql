-- PROVICA V2: perfiles automáticos + políticas RLS.
-- Ejecutar UNA VEZ después de schema.sql.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.email, 'Usuario'), 'GUARDIA')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Permite que cada usuario consulte su propio perfil.
drop policy if exists "profile_self_read" on public.profiles;
create policy "profile_self_read" on public.profiles
for select to authenticated
using (id = auth.uid());

-- Función auxiliar para roles administrativos.
create or replace function public.current_user_role()
returns public.user_role
language sql stable security definer set search_path = public
as $$ select role from public.profiles where id = auth.uid() $$;

-- ADMIN/RRHH/OPERACIONES/SUPERVISOR pueden consultar catálogos operativos.
drop policy if exists "staff_read_clients" on public.clients;
create policy "staff_read_clients" on public.clients for select to authenticated
using (public.current_user_role() in ('ADMIN','RRHH','OPERACIONES','SUPERVISOR'));

drop policy if exists "staff_read_sites" on public.sites;
create policy "staff_read_sites" on public.sites for select to authenticated
using (public.current_user_role() in ('ADMIN','RRHH','OPERACIONES','SUPERVISOR'));

drop policy if exists "staff_read_posts" on public.guard_posts;
create policy "staff_read_posts" on public.guard_posts for select to authenticated
using (public.current_user_role() in ('ADMIN','RRHH','OPERACIONES','SUPERVISOR'));

-- Un guardia ve sus turnos; personal operativo/administrativo ve todos.
drop policy if exists "shift_read" on public.shifts;
create policy "shift_read" on public.shifts for select to authenticated
using (
  guard_id = auth.uid()
  or public.current_user_role() in ('ADMIN','RRHH','OPERACIONES','SUPERVISOR')
);

-- Cada guardia puede leer y registrar sus propias marcaciones.
drop policy if exists "attendance_read" on public.attendance;
create policy "attendance_read" on public.attendance for select to authenticated
using (
  guard_id = auth.uid()
  or public.current_user_role() in ('ADMIN','RRHH','OPERACIONES','SUPERVISOR')
);

drop policy if exists "attendance_insert_self" on public.attendance;
create policy "attendance_insert_self" on public.attendance for insert to authenticated
with check (guard_id = auth.uid());

-- Incidentes propios o visibles para personal operativo.
drop policy if exists "incidents_read" on public.incidents;
create policy "incidents_read" on public.incidents for select to authenticated
using (
  guard_id = auth.uid()
  or public.current_user_role() in ('ADMIN','RRHH','OPERACIONES','SUPERVISOR')
);

drop policy if exists "incidents_insert_self" on public.incidents;
create policy "incidents_insert_self" on public.incidents for insert to authenticated
with check (guard_id = auth.uid());

-- IMPORTANTE: la asignación inicial de ADMIN se realiza manualmente en SQL Editor
-- después de crear el primer usuario en Authentication > Users:
-- update public.profiles set role='ADMIN' where id='<UUID DEL USUARIO>';
