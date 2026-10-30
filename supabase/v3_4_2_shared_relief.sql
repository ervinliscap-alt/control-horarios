-- V3.4.2: pools compartidos + limpieza controlada de turnos futuros.
-- Ejecutar en SQL Editor. No elimina turnos al instalar.
begin;
create table if not exists public.relief_pools (
 id uuid primary key default gen_random_uuid(),
 name text not null unique,
 zone text,
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create table if not exists public.relief_pool_members (
 pool_id uuid not null references public.relief_pools(id) on delete cascade,
 personnel_id uuid not null references public.personnel(id),
 shift_preference text not null default 'MIXTO' check (shift_preference in ('DIURNO','NOCTURNO','MIXTO')),
 priority integer not null default 100 check(priority between 1 and 1000),
 primary key(pool_id,personnel_id)
);
create table if not exists public.relief_pool_plans (
 pool_id uuid not null references public.relief_pools(id) on delete cascade,
 plan_id uuid not null references public.post_plans(id) on delete cascade,
 primary key(pool_id,plan_id)
);
create table if not exists public.plan_cleanup_audit (
 id bigint generated always as identity primary key,
 plan_id uuid not null references public.post_plans(id),
 actor uuid not null default auth.uid(),
 performed_at timestamptz not null default now(),
 deleted_count integer not null,
 deleted_shift_ids uuid[] not null,
 note text not null
);
-- Tablas internas: solo lectura/escritura mediante RPC autorizado.
alter table public.relief_pools enable row level security;
alter table public.relief_pool_members enable row level security;
alter table public.relief_pool_plans enable row level security;
alter table public.plan_cleanup_audit enable row level security;
revoke all on public.relief_pools,public.relief_pool_members,public.relief_pool_plans,public.plan_cleanup_audit from anon,authenticated;

create or replace function public.provica_pool_admin(
 p_action text,p_pool uuid default null,p_name text default null,
 p_personnel uuid default null,p_plan uuid default null,
 p_preference text default 'MIXTO'
) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_pool uuid; n integer;
begin
 if public.current_user_role() not in ('ADMIN','OPERACIONES') then raise exception 'No autorizado';end if;
 if p_action='CREATE' then
  if length(trim(coalesce(p_name,'')))<3 then raise exception 'Nombre de pool demasiado corto';end if;
  insert into public.relief_pools(name) values(trim(p_name)) returning id into v_pool;
 elsif p_action='ADD_MEMBER' then
  if p_preference not in ('DIURNO','NOCTURNO','MIXTO') then raise exception 'Preferencia inválida';end if;
  if not exists(select 1 from public.personnel where id=p_personnel and active and intended_role='GUARDIA') then
   raise exception 'Personal no elegible';end if;
  insert into public.relief_pool_members(pool_id,personnel_id,shift_preference)
  values(p_pool,p_personnel,p_preference)
  on conflict(pool_id,personnel_id) do update set shift_preference=excluded.shift_preference;
  v_pool:=p_pool;
 elsif p_action='REMOVE_MEMBER' then
  delete from public.relief_pool_members where pool_id=p_pool and personnel_id=p_personnel;
  v_pool:=p_pool;
 elsif p_action='LINK_PLAN' then
  insert into public.relief_pool_plans(pool_id,plan_id) values(p_pool,p_plan) on conflict do nothing;
  v_pool:=p_pool;
 elsif p_action='UNLINK_PLAN' then
  delete from public.relief_pool_plans where pool_id=p_pool and plan_id=p_plan;
  v_pool:=p_pool;
 else raise exception 'Acción inválida';end if;
 -- Mantener la bolsa por plan compatible con el motor V3.4.1.
 -- No se eliminan relevos asignados manualmente al plan.
 insert into public.post_plan_relief_pool(plan_id,personnel_id,priority)
 select l.plan_id,m.personnel_id,m.priority
 from public.relief_pool_plans l
 join public.relief_pool_members m on m.pool_id=l.pool_id
 where (p_pool is null or l.pool_id=p_pool)
 on conflict(plan_id,personnel_id) do nothing;
 get diagnostics n=row_count;
 return jsonb_build_object('ok',true,'pool_id',v_pool,'new_plan_memberships',n);
end $$;

create or replace function public.provica_pool_catalog()
returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if public.current_user_role() not in ('ADMIN','OPERACIONES','RRHH','SUPERVISOR') then
  raise exception 'No autorizado';end if;
 return jsonb_build_object(
  'pools',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'name',r.name,'active',r.active) order by r.name) from public.relief_pools r),'[]'::jsonb),
  'members',coalesce((select jsonb_agg(jsonb_build_object('pool_id',m.pool_id,'personnel_id',m.personnel_id,'shift_preference',m.shift_preference)) from public.relief_pool_members m),'[]'::jsonb),
  'plans',coalesce((select jsonb_agg(jsonb_build_object('pool_id',l.pool_id,'plan_id',l.plan_id)) from public.relief_pool_plans l),'[]'::jsonb));
end $$;

create or replace function public.provica_cleanup_future_test_shifts(
 p_plan uuid,p_confirm text,p_note text default 'Reinicio de planificación de pruebas'
) returns jsonb language plpgsql security definer set search_path=public as $$
declare ids uuid[]; n integer; v_count integer; v_all integer;
begin
 if public.current_user_role()<>'ADMIN' then raise exception 'Solo ADMIN puede limpiar turnos';end if;
 if p_confirm <> 'BORRAR FUTUROS' then raise exception 'Confirmación incorrecta';end if;
 perform pg_advisory_xact_lock(hashtext(p_plan::text));
 perform 1 from public.post_plans where id=p_plan for update;
 if not found then raise exception 'Plan inexistente';end if;
 select array_agg(s.id),count(*) into ids,n
 from public.shifts s where s.status='PROGRAMADO' and s.starts_at>now()
 and s.plan_slot_id in(select id from public.post_plan_slots where plan_id=p_plan);
 if n=0 then return jsonb_build_object('deleted',0,'message','No hay turnos futuros programados');end if;
 -- No eliminar registros que tengan relaciones operativas (FK, asistencia, incidentes, etc.).
 -- RESTRICT de claves foráneas detendrá la transacción si hay dependencias.
 delete from public.shifts s where s.id=any(ids);
 get diagnostics v_count=row_count;
 insert into public.plan_cleanup_audit(plan_id,deleted_count,deleted_shift_ids,note)
 values(p_plan,v_count,ids,coalesce(nullif(trim(p_note),''),'Reinicio de planificación de pruebas'));
 return jsonb_build_object('deleted',v_count,'plan_id',p_plan,'audit_saved',true);
end $$;
revoke all on function public.provica_pool_admin(text,uuid,text,uuid,uuid,text) from public,anon;
revoke all on function public.provica_pool_catalog() from public,anon;
revoke all on function public.provica_cleanup_future_test_shifts(uuid,text,text) from public,anon;
grant execute on function public.provica_pool_admin(text,uuid,text,uuid,uuid,text) to authenticated;
grant execute on function public.provica_pool_catalog() to authenticated;
grant execute on function public.provica_cleanup_future_test_shifts(uuid,text,text) to authenticated;
select pg_notify('pgrst','reload schema');
commit;
