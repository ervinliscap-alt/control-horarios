-- PROVICA V3.3.1 - ejecutar UNA VEZ despues de V3.3
drop policy if exists "hr_update_profiles" on public.profiles;

create or replace function public.provica_update_master(p_table text,p_id uuid,p_patch jsonb,p_reason text) returns void language plpgsql security definer set search_path=public as $$
declare r public.user_role:=public.current_user_role(); aid bigint;
begin
 if r not in ('ADMIN','OPERACIONES') then raise exception 'No autorizado'; end if;
 if coalesce(trim(p_reason),'')='' then raise exception 'El motivo es obligatorio'; end if;
 if p_table='clients' then update clients set name=coalesce(p_patch->>'name',name) where id=p_id;
 elsif p_table='sites' then update sites set name=coalesce(p_patch->>'name',name),client_id=coalesce((p_patch->>'client_id')::uuid,client_id),address=case when p_patch?'address' then nullif(p_patch->>'address','') else address end,geofence_radius_m=coalesce((p_patch->>'geofence_radius_m')::int,geofence_radius_m) where id=p_id;
 elsif p_table='guard_posts' then update guard_posts set name=coalesce(p_patch->>'name',name),site_id=coalesce((p_patch->>'site_id')::uuid,site_id),coverage_hours=coalesce((p_patch->>'coverage_hours')::int,coverage_hours) where id=p_id;
 else raise exception 'Tabla no permitida'; end if;
 select id into aid from audit_log where actor_id=auth.uid() and entity=p_table and entity_id=p_id::text order by id desc limit 1; update audit_log set reason=p_reason where id=aid;
end $$;

create or replace function public.provica_toggle_master(p_table text,p_id uuid,p_active boolean,p_reason text) returns void language plpgsql security definer set search_path=public as $$
declare r public.user_role:=public.current_user_role(); aid bigint;
begin
 if r not in ('ADMIN','OPERACIONES') then raise exception 'No autorizado'; end if;
 if coalesce(trim(p_reason),'')='' then raise exception 'El motivo es obligatorio'; end if;
 if p_table='clients' then update clients set active=p_active where id=p_id;
 elsif p_table='sites' then update sites set active=p_active where id=p_id;
 elsif p_table='guard_posts' then update guard_posts set active=p_active where id=p_id;
 else raise exception 'Tabla no permitida'; end if;
 select id into aid from audit_log where actor_id=auth.uid() and entity=p_table and entity_id=p_id::text order by id desc limit 1; update audit_log set reason=p_reason where id=aid;
end $$;

create or replace function public.provica_update_profile(p_profile_id uuid,p_patch jsonb,p_reason text) returns void language plpgsql security definer set search_path=public as $$
declare me public.user_role:=public.current_user_role(); target public.user_role; requested public.user_role; aid bigint;
begin
 if coalesce(trim(p_reason),'')='' then raise exception 'El motivo es obligatorio'; end if;
 select role into target from profiles where id=p_profile_id;
 if target is null then raise exception 'Perfil inexistente'; end if;
 if me='RRHH' then if target<>'GUARDIA' or p_patch?'role' then raise exception 'RRHH solo puede modificar perfiles GUARDIA y no puede cambiar roles'; end if;
 elsif me<>'ADMIN' then raise exception 'No autorizado'; end if;
 requested:=case when p_patch?'role' then (p_patch->>'role')::public.user_role else target end;
 update profiles set full_name=coalesce(p_patch->>'full_name',full_name),identification=case when p_patch?'identification' then nullif(p_patch->>'identification','') else identification end,phone=case when p_patch?'phone' then nullif(p_patch->>'phone','') else phone end,active=case when p_patch?'active' then (p_patch->>'active')::boolean else active end,role=requested where id=p_profile_id;
 select id into aid from audit_log where actor_id=auth.uid() and entity='profiles' and entity_id=p_profile_id::text order by id desc limit 1; update audit_log set reason=p_reason where id=aid;
end $$;

revoke all on function public.provica_update_master(text,uuid,jsonb,text) from public;
revoke all on function public.provica_toggle_master(text,uuid,boolean,text) from public;
revoke all on function public.provica_update_profile(uuid,jsonb,text) from public;
grant execute on function public.provica_update_master(text,uuid,jsonb,text) to authenticated;
grant execute on function public.provica_toggle_master(text,uuid,boolean,text) to authenticated;
grant execute on function public.provica_update_profile(uuid,jsonb,text) to authenticated;
