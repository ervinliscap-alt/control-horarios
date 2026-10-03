-- PROVICA V3.3 - Roles, maestros y auditoria. Ejecutar UNA VEZ despues de V3.2.

-- RRHH solo personal. ADMIN puede cambiar cualquier dato/rol.
drop policy if exists "admin_hr_update_profiles" on public.profiles;
create policy "admin_update_profiles" on public.profiles for update to authenticated
using(public.current_user_role()='ADMIN') with check(public.current_user_role()='ADMIN');
create policy "hr_update_profiles" on public.profiles for update to authenticated
using(public.current_user_role()='RRHH' and role='GUARDIA')
with check(public.current_user_role()='RRHH' and role='GUARDIA');

-- Solo ADMIN/OPERACIONES modifican maestros. Eliminacion fisica no se habilita.
-- Se usa active=false para conservar historia.

-- Auditoria automatica de INSERT/UPDATE/DELETE.
create or replace function public.provica_audit_trigger() returns trigger
language plpgsql security definer set search_path=public as $$
declare v_reason text;
begin
  v_reason:=nullif(current_setting('request.headers',true)::jsonb->>'x-provica-reason','');
  if tg_op='INSERT' then
    insert into audit_log(actor_id,entity,entity_id,action,new_value,reason)
    values(auth.uid(),tg_table_name,new.id::text,'CREAR',to_jsonb(new),v_reason); return new;
  elsif tg_op='UPDATE' then
    insert into audit_log(actor_id,entity,entity_id,action,old_value,new_value,reason)
    values(auth.uid(),tg_table_name,new.id::text,
      case when to_jsonb(old)->>'active'='true' and to_jsonb(new)->>'active'='false' then 'DESACTIVAR'
           when to_jsonb(old)->>'active'='false' and to_jsonb(new)->>'active'='true' then 'ACTIVAR'
           else 'EDITAR' end,to_jsonb(old),to_jsonb(new),v_reason); return new;
  else
    insert into audit_log(actor_id,entity,entity_id,action,old_value,reason)
    values(auth.uid(),tg_table_name,old.id::text,'ELIMINAR',to_jsonb(old),v_reason); return old;
  end if;
end $$;

do $$ declare t text; begin
 foreach t in array array['clients','sites','guard_posts','shifts','profiles'] loop
  execute format('drop trigger if exists provica_audit_%I on public.%I',t,t);
  execute format('create trigger provica_audit_%I after insert or update or delete on public.%I for each row execute function public.provica_audit_trigger()',t,t);
 end loop;
end $$;

-- Eliminar turnos deja de ser operacion normal: se conserva V3.2 solo para correccion previa a asistencia.
-- Auditoria: solo ADMIN.
drop policy if exists "admin_read_audit" on public.audit_log;
create policy "admin_read_audit" on public.audit_log for select to authenticated using(public.current_user_role()='ADMIN');

-- Evita que clientes/instalaciones/puestos se borren por API.
revoke delete on public.clients,public.sites,public.guard_posts from authenticated;
