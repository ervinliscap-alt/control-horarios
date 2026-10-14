-- V3.3.8 Simulacion de cobertura + descanso minimo + desfase 5x2
alter table public.post_plan_slots add column if not exists cycle_offset integer not null default 0;
alter table public.post_plan_slots drop constraint if exists post_plan_slots_cycle_offset_chk;
alter table public.post_plan_slots add constraint post_plan_slots_cycle_offset_chk check(cycle_offset between 0 and 6);

create or replace function public.provica_set_plan_cycle_offset(p_slot uuid,p_offset integer)
returns void language plpgsql security definer set search_path=public as $$
begin
 if current_user_role() not in('ADMIN','OPERACIONES') then raise exception 'No autorizado'; end if;
 if p_offset<0 or p_offset>6 then raise exception 'Desfase invalido'; end if;
 update post_plan_slots set cycle_offset=p_offset where id=p_slot;
 if not found then raise exception 'Cajon inexistente'; end if;
end$$;

create or replace function public.provica_simulate_post_plan(p_plan uuid,p_min_rest_hours integer default 12)
returns jsonb language plpgsql security definer set search_path=public as $$
declare pl post_plans%rowtype;sl post_plan_slots%rowtype;d date;a timestamptz;b timestamptz;who uuid;idx int;
total int:=0;reliefs int:=0;uncovered int:=0;fatigue int:=0;mx numeric:=0;hours jsonb:='{}'::jsonb;last_end jsonb:='{}'::jsonb;code text;prev timestamptz;
begin
 if current_user_role() not in('ADMIN','RRHH','OPERACIONES','SUPERVISOR') then raise exception 'No autorizado';end if;
 if p_min_rest_hours<0 or p_min_rest_hours>48 then raise exception 'Descanso minimo invalido';end if;
 select * into pl from post_plans where id=p_plan and active;if not found then raise exception 'Plan inexistente';end if;
 if exists(select 1 from post_plan_slots where plan_id=p_plan and primary_personnel_id is null) then return jsonb_build_object('viable',false,'coverage_percent',0,'message','Faltan titulares');end if;
 if not exists(select 1 from post_plan_relief_pool where plan_id=p_plan) then return jsonb_build_object('viable',false,'coverage_percent',0,'message','Falta bolsa de relevos');end if;

 create temp table if not exists tmp_plan_sim(personnel_id uuid,starts_at timestamptz,ends_at timestamptz,is_relief boolean) on commit drop;
 truncate tmp_plan_sim;

 for sl in select * from post_plan_slots where plan_id=p_plan order by slot_order loop
  d:=pl.start_date;idx:=0;
  while d<=pl.end_date loop
   a:=(d::text||' '||sl.start_time::text)::timestamp at time zone 'America/Guayaquil'; b:=a+make_interval(hours=>sl.duration_hours);
   if a>now() then
    total:=total+1;
    if ((idx+sl.cycle_offset)%(sl.work_days+sl.rest_days))<sl.work_days then who:=sl.primary_personnel_id;
    else
     reliefs:=reliefs+1;who:=null;
     select rp.personnel_id into who from post_plan_relief_pool rp
      where rp.plan_id=p_plan
       and not exists(select 1 from tmp_plan_sim x where x.personnel_id=rp.personnel_id and x.starts_at<b and x.ends_at>a)
       and not exists(select 1 from tmp_plan_sim x where x.personnel_id=rp.personnel_id and x.ends_at<=a and x.ends_at>a-make_interval(hours=>p_min_rest_hours))
       and not exists(select 1 from shifts x where x.personnel_id=rp.personnel_id and x.status<>'CANCELADO' and x.plan_slot_id is distinct from sl.id and x.starts_at<b and x.ends_at>a)
      order by (select count(*) from tmp_plan_sim z where z.personnel_id=rp.personnel_id),rp.priority,rp.created_at limit 1;
     if who is null then uncovered:=uncovered+1; d:=d+1;idx:=idx+1;continue;end if;
    end if;
    if exists(select 1 from tmp_plan_sim x where x.personnel_id=who and (x.starts_at<b and x.ends_at>a or (x.ends_at<=a and x.ends_at>a-make_interval(hours=>p_min_rest_hours)))) then fatigue:=fatigue+1;uncovered:=uncovered+1;
    else insert into tmp_plan_sim values(who,a,b,who<>sl.primary_personnel_id);end if;
   end if;
   d:=d+1;idx:=idx+1;
  end loop;
 end loop;

 select coalesce(max(h),0) into mx from(select sum(extract(epoch from(ends_at-starts_at))/3600) h from tmp_plan_sim group by personnel_id)x;
 select coalesce(jsonb_object_agg(person_code,h),'{}'::jsonb) into hours from(select p.person_code,round(sum(extract(epoch from(t.ends_at-t.starts_at))/3600)::numeric,1) h from tmp_plan_sim t join personnel p on p.id=t.personnel_id group by p.person_code)x;
 return jsonb_build_object('viable',uncovered=0,'coverage_percent',case when total=0 then 0 else round(100.0*(total-uncovered)/total,1) end,'required_shifts',total,'covered_shifts',total-uncovered,'uncovered_shifts',uncovered,'relief_shifts',reliefs,'fatigue_conflicts',fatigue,'min_rest_hours',p_min_rest_hours,'max_person_hours',mx,'hours_by_person',hours);
end$$;

create or replace function public.provica_generate_post_plan(p_plan uuid,p_min_rest_hours integer default 12)
returns jsonb language plpgsql security definer set search_path=public as $$
declare sim jsonb;pl post_plans%rowtype;sl post_plan_slots%rowtype;d date;a timestamptz;b timestamptz;who uuid;prof uuid;idx int;n int:=0;r int:=0;
begin
 if current_user_role() not in('ADMIN','OPERACIONES') then raise exception 'No autorizado';end if;
 sim:=provica_simulate_post_plan(p_plan,p_min_rest_hours);
 if coalesce((sim->>'viable')::boolean,false)=false then raise exception 'Plan no viable. Cobertura %%, faltan % turno(s). Simule y ajuste dotacion/desfases.',sim->>'coverage_percent',sim->>'uncovered_shifts';end if;
 select * into pl from post_plans where id=p_plan and active for update;
 delete from shifts where plan_slot_id in(select id from post_plan_slots where plan_id=p_plan) and status='PROGRAMADO' and starts_at>now();
 for sl in select * from post_plan_slots where plan_id=p_plan order by slot_order loop
  d:=pl.start_date;idx:=0;
  while d<=pl.end_date loop
   a:=(d::text||' '||sl.start_time::text)::timestamp at time zone 'America/Guayaquil';b:=a+make_interval(hours=>sl.duration_hours);
   if a>now() then
    if ((idx+sl.cycle_offset)%(sl.work_days+sl.rest_days))<sl.work_days then who:=sl.primary_personnel_id;
    else
     r:=r+1;who:=null;
     select rp.personnel_id into who from post_plan_relief_pool rp where rp.plan_id=p_plan
      and not exists(select 1 from shifts x where x.personnel_id=rp.personnel_id and x.status<>'CANCELADO' and x.starts_at<b and x.ends_at>a)
      and not exists(select 1 from shifts x where x.personnel_id=rp.personnel_id and x.status<>'CANCELADO' and x.ends_at<=a and x.ends_at>a-make_interval(hours=>p_min_rest_hours))
      order by(select count(*) from shifts z where z.personnel_id=rp.personnel_id and z.plan_slot_id in(select id from post_plan_slots where plan_id=p_plan)),rp.priority,rp.created_at limit 1;
     if who is null then raise exception 'La planificacion cambio: relevo no disponible para cajon % el %',sl.slot_order,d;end if;
    end if;
    if exists(select 1 from shifts x where x.personnel_id=who and x.status<>'CANCELADO' and (x.starts_at<b and x.ends_at>a or(x.ends_at<=a and x.ends_at>a-make_interval(hours=>p_min_rest_hours)))) then raise exception 'Descanso insuficiente para % el %',(select person_code from personnel where id=who),d;end if;
    select profile_id into prof from personnel where id=who;
    insert into shifts(guard_post_id,guard_id,personnel_id,starts_at,ends_at,status,plan_slot_id)values(pl.guard_post_id,prof,who,a,b,'PROGRAMADO',sl.id);n:=n+1;
   end if;d:=d+1;idx:=idx+1;
  end loop;
 end loop;
 return sim||jsonb_build_object('shifts_created',n,'relief_shifts_generated',r);
end$$;

revoke all on function public.provica_set_plan_cycle_offset(uuid,integer) from public;
revoke all on function public.provica_simulate_post_plan(uuid,integer) from public;
revoke all on function public.provica_generate_post_plan(uuid,integer) from public;
grant execute on function public.provica_set_plan_cycle_offset(uuid,integer) to authenticated;
grant execute on function public.provica_simulate_post_plan(uuid,integer) to authenticated;
grant execute on function public.provica_generate_post_plan(uuid,integer) to authenticated;
select pg_notify('pgrst','reload schema');
