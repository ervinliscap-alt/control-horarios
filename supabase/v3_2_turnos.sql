-- PROVICA V3.2 - ejecutar UNA VEZ despues de V3.1
-- Bloquea jornadas distintas de 8 o 12 horas en la propia base de datos.
alter table public.shifts drop constraint if exists shifts_allowed_duration;
alter table public.shifts add constraint shifts_allowed_duration
check (ends_at - starts_at in (interval '8 hours', interval '12 hours')) not valid;

-- Valida registros nuevos/modificados, pero conserva temporalmente turnos antiguos incorrectos
-- para que puedan editarse o eliminarse desde V3.2.

-- Permite eliminar turnos solo a ADMIN/OPERACIONES y solo si no tienen asistencia.
drop policy if exists "admin_ops_delete_shifts" on public.shifts;
create policy "admin_ops_delete_shifts" on public.shifts
for delete to authenticated
using (
 public.current_user_role() in ('ADMIN','OPERACIONES')
 and not exists (select 1 from public.attendance a where a.shift_id=shifts.id)
);
