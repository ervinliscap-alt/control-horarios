-- PROVICA V3.3.4.1 - Control administrativo de Personal
-- Requiere V3.3.4 Bloques 1 y 2.

-- Auditoría específica del registro RRHH.
create table if not exists public.personnel_audit(
 id bigint generated always as identity primary key,
 actor_id uuid references public.profiles(id),
 personnel_id uuid not null references public.personnel(id),
 action text not null check(action in ('UPDATE','ACTIVATE','DEACTIVATE')),
 old_value jsonb,
 new_value jsonb,
 reason text not null,
 created_at timestamptz not null default now()
);
alter table public.personnel_audit enable row level security;
drop policy if exists personnel_audit_admin_read on public.personnel_audit;
create policy personnel_audit_admin_read on public.personnel_audit for select to authenticated using(public.current_user_role()='ADMIN');

-- Nadie modifica personnel directamente desde REST; las modificaciones pasan por RPC ADMIN.
revoke update, delete on public.personnel from authenticated;

create or replace function public.provica_admin_update_personnel(p_personnel_id uuid,p_patch jsonb,p_reason text)
returns void language plpgsql security definer set search_path=public as $$
declare oldrow personnel%rowtype; newrow personnel%rowtype; typ text; rol user_role;
begin
 if current_user_role()<>'ADMIN' then raise exception 'Solo ADMIN puede editar personal'; end if;
 if coalesce(trim(p_reason),'')='' then raise exception 'El motivo es obligatorio'; end if;
 select * into oldrow from personnel where id=p_personnel_id for update;
 if not found then raise exception 'Personal inexistente'; end if;
 typ:=coalesce(p_patch->>'personnel_type',oldrow.personnel_type);
 rol:=coalesce((p_patch->>'intended_role')::user_role,oldrow.intended_role);
 if typ not in ('OPERATIVO','CONTROL') then raise exception 'Tipo invalido'; end if;
 if typ='OPERATIVO' and rol<>'GUARDIA' then raise exception 'OPERATIVO debe tener rol GUARDIA'; end if;
 if typ='CONTROL' and rol='GUARDIA' then raise exception 'CONTROL no puede tener rol GUARDIA'; end if;
 update personnel set
  full_name=coalesce(nullif(trim(p_patch->>'full_name'),''),full_name),
  identification=case when p_patch?'identification' then nullif(trim(p_patch->>'identification'),'') else identification end,
  phone=case when p_patch?'phone' then nullif(trim(p_patch->>'phone'),'') else phone end,
  email=case when p_patch?'email' then nullif(lower(trim(p_patch->>'email')),'') else email end,
  personnel_type=typ,intended_role=rol,
  app_access=case when p_patch?'app_access' then (p_patch->>'app_access')::boolean else app_access end
 where id=p_personnel_id returning * into newrow;
 insert into personnel_audit(actor_id,personnel_id,action,old_value,new_value,reason)
 values(auth.uid(),p_personnel_id,'UPDATE',to_jsonb(oldrow),to_jsonb(newrow),trim(p_reason));
end $$;

create or replace function public.provica_admin_set_personnel_active(p_personnel_id uuid,p_active boolean,p_reason text)
returns void language plpgsql security definer set search_path=public as $$
declare oldrow personnel%rowtype; newrow personnel%rowtype;
begin
 if current_user_role()<>'ADMIN' then raise exception 'Solo ADMIN puede cambiar el estado del personal'; end if;
 if coalesce(trim(p_reason),'')='' then raise exception 'El motivo es obligatorio'; end if;
 select * into oldrow from personnel where id=p_personnel_id for update;
 if not found then raise exception 'Personal inexistente'; end if;
 update personnel set active=p_active where id=p_personnel_id returning * into newrow;
 -- Si ya tiene cuenta vinculada, impedir acceso operativo al inactivar y reactivar al activar.
 if newrow.profile_id is not null then update profiles set active=p_active where id=newrow.profile_id; end if;
 insert into personnel_audit(actor_id,personnel_id,action,old_value,new_value,reason)
 values(auth.uid(),p_personnel_id,case when p_active then 'ACTIVATE' else 'DEACTIVATE' end,to_jsonb(oldrow),to_jsonb(newrow),trim(p_reason));
end $$;

revoke all on function public.provica_admin_update_personnel(uuid,jsonb,text) from public;
revoke all on function public.provica_admin_set_personnel_active(uuid,boolean,text) from public;
grant execute on function public.provica_admin_update_personnel(uuid,jsonb,text) to authenticated;
grant execute on function public.provica_admin_set_personnel_active(uuid,boolean,text) to authenticated;

-- Bloqueo adicional: un guardia vinculado e inactivo no puede recibir NUEVOS turnos.
create or replace function public.prevent_inactive_guard_shift()
returns trigger language plpgsql set search_path=public as $$
begin
 if new.guard_id is not null and exists(
   select 1 from profiles p
   left join personnel pe on pe.profile_id=p.id
   where p.id=new.guard_id and (not p.active or (pe.id is not null and not pe.active))
 ) then raise exception 'No se puede asignar un turno a personal inactivo'; end if;
 return new;
end $$;
drop trigger if exists prevent_inactive_guard_shift_trigger on public.shifts;
create trigger prevent_inactive_guard_shift_trigger before insert or update of guard_id on public.shifts for each row execute function public.prevent_inactive_guard_shift();

select routine_name from information_schema.routines
where routine_schema='public' and routine_name in ('provica_admin_update_personnel','provica_admin_set_personnel_active')
order by routine_name;
