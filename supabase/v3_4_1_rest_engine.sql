-- Seguridad bajo control V3.4.1 — motor cronológico único.
-- Ejecutar como un solo bloque en Supabase SQL Editor. No modifica turnos existentes.
-- Regla operativa: descanso >=12h (parametrizable 1..48); no es dictamen legal.

create or replace function public.provica_plan_engine(
 p_plan uuid, p_min_rest_hours integer,
 p_offset_1 integer default null, p_offset_2 integer default null
) returns jsonb language plpgsql security definer set search_path=public as $$
declare
 pl public.post_plans%rowtype;
 rec record;
 candidate uuid;
 chosen uuid;
 total integer:=0;
 covered integer:=0;
 uncovered integer:=0;
 conflicts integer:=0;
 relief_count integer:=0;
 max_hours numeric:=0;
 by_person jsonb:='{}'::jsonb;
 problems jsonb:='[]'::jsonb;
 is_primary boolean;
 rest_interval interval;
begin
 if public.current_user_role() not in ('ADMIN','RRHH','OPERACIONES','SUPERVISOR') then
  raise exception 'No autorizado';
 end if;
 if p_min_rest_hours is null or p_min_rest_hours not between 1 and 48 then
  raise exception 'Descanso mínimo inválido (1..48 horas)';
 end if;
 if (p_offset_1 is not null and p_offset_1 not between 0 and 6)
    or (p_offset_2 is not null and p_offset_2 not between 0 and 6) then
  raise exception 'Desfase inválido';
 end if;
 select * into pl from public.post_plans where id=p_plan and active;
 if not found then raise exception 'Plan inexistente o inactivo'; end if;
 rest_interval:=make_interval(hours=>p_min_rest_hours);
 create temporary table if not exists pg_temp.provica_v341_assignments (
  plan_slot_id uuid, personnel_id uuid, starts_at timestamptz,
  ends_at timestamptz, is_relief boolean
 ) on commit drop;
 truncate pg_temp.provica_v341_assignments;

 -- Orden global por inicio, no por cajón: elimina la falla de V3.3.9.
 for rec in
  select sl.id as slot_id,sl.slot_order,sl.primary_personnel_id,
   ((day.day_date-pl.start_date + coalesce(
      case sl.slot_order when 1 then p_offset_1 when 2 then p_offset_2 end,
      sl.cycle_offset)) % (sl.work_days+sl.rest_days)) < sl.work_days as primary_on,
   (day.day_date::text||' '||sl.start_time::text)::timestamp
       at time zone 'America/Guayaquil' as a,
   ((day.day_date::text||' '||sl.start_time::text)::timestamp
       at time zone 'America/Guayaquil')+make_interval(hours=>sl.duration_hours) as b
  from public.post_plan_slots sl
  cross join lateral (
    select gs::date as day_date
    from generate_series(pl.start_date::timestamp,pl.end_date::timestamp,interval '1 day') gs
  ) day
  where sl.plan_id=p_plan
  order by a,sl.slot_order
 loop
  if rec.a<=now() then continue; end if;
  total:=total+1;
  candidate:=null;
  chosen:=null;
  is_primary:=rec.primary_on;
  if is_primary then
   candidate:=rec.primary_personnel_id;
   if candidate is not null and exists(
      select 1 from public.personnel p where p.id=candidate and p.active
   ) then
    if not exists(
       select 1 from pg_temp.provica_v341_assignments t
       where t.personnel_id=candidate
         and t.starts_at < rec.b+rest_interval
         and t.ends_at > rec.a-rest_interval
    ) and not exists(
       select 1 from public.shifts x
       where x.personnel_id=candidate and x.status<>'CANCELADO'
         and not (x.starts_at>now() and x.status='PROGRAMADO'
           and x.plan_slot_id in (select id from public.post_plan_slots where plan_id=p_plan))
         and x.starts_at < rec.b+rest_interval
         and x.ends_at > rec.a-rest_interval
    ) then chosen:=candidate; end if;
   end if;
  else
   select rp.personnel_id into chosen
   from public.post_plan_relief_pool rp
   join public.personnel p on p.id=rp.personnel_id and p.active
   where rp.plan_id=p_plan
    and not exists(
      select 1 from pg_temp.provica_v341_assignments t
      where t.personnel_id=rp.personnel_id
        and t.starts_at < rec.b+rest_interval
        and t.ends_at > rec.a-rest_interval
    )
    and not exists(
      select 1 from public.shifts x
      where x.personnel_id=rp.personnel_id and x.status<>'CANCELADO'
        and not (x.starts_at>now() and x.status='PROGRAMADO'
          and x.plan_slot_id in (select id from public.post_plan_slots where plan_id=p_plan))
        and x.starts_at < rec.b+rest_interval
        and x.ends_at > rec.a-rest_interval
    )
   order by (select count(*) from pg_temp.provica_v341_assignments t
             where t.personnel_id=rp.personnel_id),rp.priority,rp.created_at
   limit 1;
  end if;
  if chosen is null then
   uncovered:=uncovered+1;
   if is_primary then conflicts:=conflicts+1; end if;
   if jsonb_array_length(problems)<20 then
    problems:=problems||jsonb_build_array(jsonb_build_object(
      'slot',rec.slot_order,'starts_at',rec.a,
      'reason',case when is_primary then 'Titular ausente o descanso insuficiente'
                    else 'No hay relevo con descanso suficiente' end));
   end if;
  else
   insert into pg_temp.provica_v341_assignments values
    (rec.slot_id,chosen,rec.a,rec.b,not is_primary);
   covered:=covered+1;
   if not is_primary then relief_count:=relief_count+1; end if;
  end if;
 end loop;
 select coalesce(max(h),0) into max_hours from (
   select sum(extract(epoch from (ends_at-starts_at))/3600) h
   from pg_temp.provica_v341_assignments group by personnel_id
 ) q;
 select coalesce(jsonb_object_agg(person_code,h),'{}'::jsonb) into by_person
 from (
   select p.person_code,
    round(sum(extract(epoch from (t.ends_at-t.starts_at))/3600)::numeric,1) h
   from pg_temp.provica_v341_assignments t
   join public.personnel p on p.id=t.personnel_id
   group by p.person_code
 ) q;
 return jsonb_build_object(
  'viable',uncovered=0 and total>0,'coverage_percent',
    case when total=0 then 0 else round(100.0*covered/total,1) end,
  'required_shifts',total,'covered_shifts',covered,
  'uncovered_shifts',uncovered,'relief_shifts',relief_count,
  'fatigue_conflicts',conflicts,'min_rest_hours',p_min_rest_hours,
  'max_person_hours',max_hours,'hours_by_person',by_person,
  'conflicts',problems,'engine_version','3.4.1',
  'message',case when total=0 then 'No hay turnos futuros que generar'
                 when uncovered>0 then 'Dotación o desfases insuficientes con descanso obligatorio'
                 else 'Cobertura viable con descanso mínimo verificado' end);
end $$;

create or replace function public.provica_simulate_post_plan(
 p_plan uuid,p_min_rest_hours integer default 12
) returns jsonb language plpgsql security definer set search_path=public as $$
begin
 return public.provica_plan_engine(p_plan,p_min_rest_hours,null,null);
end $$;

create or replace function public.provica_optimize_post_plan(
 p_plan uuid,p_min_rest_hours integer default 12,p_load_warning_hours integer default 240
) returns jsonb language plpgsql security definer set search_path=public as $$
declare n integer; o1 integer;o2 integer;v jsonb;best jsonb:=null;
 cov numeric;mx numeric;best_cov numeric:=-1;best_max numeric:=999999;
begin
 if public.current_user_role() not in ('ADMIN','RRHH','OPERACIONES','SUPERVISOR') then
  raise exception 'No autorizado'; end if;
 select count(*) into n from public.post_plan_slots where plan_id=p_plan;
 if n<>2 then return jsonb_build_object('supported',false,
  'message','Optimización disponible para planes de dos cajones');end if;
 -- Evalúa 49 combinaciones sin alterar post_plan_slots ni activar auditorías.
 for o1 in 0..6 loop
  for o2 in 0..6 loop
   v:=public.provica_plan_engine(p_plan,p_min_rest_hours,o1,o2);
   cov:=coalesce((v->>'coverage_percent')::numeric,0);
   mx:=coalesce((v->>'max_person_hours')::numeric,999999);
   if cov>best_cov or (cov=best_cov and mx<best_max) then
    best_cov:=cov;best_max:=mx;
    best:=v||jsonb_build_object('offset_1',o1,'offset_2',o2);
   end if;
  end loop;
 end loop;
 return best||jsonb_build_object(
  'supported',true,'coverage_ok',coalesce((best->>'coverage_percent')::numeric,0)=100,
  'rest_ok',coalesce((best->>'uncovered_shifts')::integer,0)=0
     and coalesce((best->>'fatigue_conflicts')::integer,0)=0,
  'load_ok',coalesce((best->>'max_person_hours')::numeric,0)<=p_load_warning_hours,
  'load_warning_hours',p_load_warning_hours,'load_is_advisory',true);
end $$;

create or replace function public.provica_generate_post_plan(
 p_plan uuid,p_min_rest_hours integer default 12
) returns jsonb language plpgsql security definer set search_path=public as $$
declare v jsonb;n integer;pl public.post_plans%rowtype;
begin
 if public.current_user_role() not in ('ADMIN','OPERACIONES') then
  raise exception 'No autorizado';end if;
 -- Serializa generación del mismo plan. Cualquier error revierte toda la transacción.
 perform pg_advisory_xact_lock(hashtext(p_plan::text));
 select * into pl from public.post_plans where id=p_plan and active for update;
 if not found then raise exception 'Plan inexistente';end if;
 v:=public.provica_plan_engine(p_plan,p_min_rest_hours,null,null);
 if not coalesce((v->>'viable')::boolean,false) then
  raise exception 'Plan NO viable: % turnos sin cubrir. Revise descansos y dotación.',
   coalesce(v->>'uncovered_shifts','0');
 end if;
 delete from public.shifts s
 where s.status='PROGRAMADO' and s.starts_at>now()
  and s.plan_slot_id in (select id from public.post_plan_slots where plan_id=p_plan);
 insert into public.shifts(guard_post_id,guard_id,personnel_id,
                          starts_at,ends_at,status,plan_slot_id)
 select pl.guard_post_id,p.profile_id,t.personnel_id,t.starts_at,t.ends_at,
        'PROGRAMADO',t.plan_slot_id
 from pg_temp.provica_v341_assignments t
 join public.personnel p on p.id=t.personnel_id
 order by t.starts_at,t.plan_slot_id;
 get diagnostics n=row_count;
 return v||jsonb_build_object('shifts_created',n);
end $$;

revoke all on function public.provica_plan_engine(uuid,integer,integer,integer) from public,anon;
revoke all on function public.provica_simulate_post_plan(uuid,integer) from public,anon;
revoke all on function public.provica_optimize_post_plan(uuid,integer,integer) from public,anon;
revoke all on function public.provica_generate_post_plan(uuid,integer) from public,anon;
-- Motor interno: solo invocable indirectamente mediante funciones autorizadas.
revoke all on function public.provica_plan_engine(uuid,integer,integer,integer) from authenticated;
grant execute on function public.provica_simulate_post_plan(uuid,integer) to authenticated;
grant execute on function public.provica_optimize_post_plan(uuid,integer,integer) to authenticated;
grant execute on function public.provica_generate_post_plan(uuid,integer) to authenticated;
select pg_notify('pgrst','reload schema');
