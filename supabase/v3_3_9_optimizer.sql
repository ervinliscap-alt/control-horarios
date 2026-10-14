-- V3.3.9 Optimizador de desfases + semaforos de planificacion
create or replace function public.provica_optimize_post_plan(
 p_plan uuid,
 p_min_rest_hours integer default 12,
 p_load_warning_hours integer default 240
) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
 sl1 uuid; sl2 uuid; slots_count integer;
 o1 integer; o2 integer; old1 integer; old2 integer;
 sim jsonb; best jsonb:=null; best_cov numeric:=-1; best_max numeric:=999999; cov numeric; mx numeric;
begin
 if current_user_role() not in('ADMIN','RRHH','OPERACIONES','SUPERVISOR') then raise exception 'No autorizado'; end if;
 select count(*) into slots_count from post_plan_slots where plan_id=p_plan;
 if slots_count<>2 then
   return jsonb_build_object('supported',false,'message','Optimizacion automatica V3.3.9 disponible para planes de 2 cajones');
 end if;
 select id,cycle_offset into sl1,old1 from post_plan_slots where plan_id=p_plan order by slot_order limit 1;
 select id,cycle_offset into sl2,old2 from post_plan_slots where plan_id=p_plan order by slot_order offset 1 limit 1;
 for o1 in 0..6 loop
  for o2 in 0..6 loop
   update post_plan_slots set cycle_offset=o1 where id=sl1;
   update post_plan_slots set cycle_offset=o2 where id=sl2;
   sim:=provica_simulate_post_plan(p_plan,p_min_rest_hours);
   cov:=coalesce((sim->>'coverage_percent')::numeric,0);
   mx:=coalesce((sim->>'max_person_hours')::numeric,999999);
   if cov>best_cov or (cov=best_cov and mx<best_max) then
    best_cov:=cov;best_max:=mx;
    best:=sim||jsonb_build_object('offset_1',o1,'offset_2',o2);
   end if;
  end loop;
 end loop;
 update post_plan_slots set cycle_offset=old1 where id=sl1;
 update post_plan_slots set cycle_offset=old2 where id=sl2;
 return best||jsonb_build_object(
  'supported',true,
  'coverage_ok',coalesce((best->>'coverage_percent')::numeric,0)=100,
  'rest_ok',coalesce((best->>'fatigue_conflicts')::integer,0)=0 and coalesce((best->>'uncovered_shifts')::integer,0)=0,
  'load_ok',coalesce((best->>'max_person_hours')::numeric,0)<=p_load_warning_hours,
  'load_warning_hours',p_load_warning_hours,
  'load_is_advisory',true
 );
exception when others then
 if sl1 is not null then update post_plan_slots set cycle_offset=old1 where id=sl1; end if;
 if sl2 is not null then update post_plan_slots set cycle_offset=old2 where id=sl2; end if;
 raise;
end$$;

create or replace function public.provica_apply_optimized_offsets(p_plan uuid,p_offset_1 integer,p_offset_2 integer)
returns void language plpgsql security definer set search_path=public as $$
declare a uuid;b uuid;
begin
 if current_user_role() not in('ADMIN','OPERACIONES') then raise exception 'No autorizado';end if;
 if p_offset_1 not between 0 and 6 or p_offset_2 not between 0 and 6 then raise exception 'Desfase invalido';end if;
 select id into a from post_plan_slots where plan_id=p_plan order by slot_order limit 1;
 select id into b from post_plan_slots where plan_id=p_plan order by slot_order offset 1 limit 1;
 if a is null or b is null then raise exception 'El plan requiere dos cajones';end if;
 update post_plan_slots set cycle_offset=p_offset_1 where id=a;
 update post_plan_slots set cycle_offset=p_offset_2 where id=b;
end$$;

revoke all on function public.provica_optimize_post_plan(uuid,integer,integer) from public;
revoke all on function public.provica_apply_optimized_offsets(uuid,integer,integer) from public;
grant execute on function public.provica_optimize_post_plan(uuid,integer,integer) to authenticated;
grant execute on function public.provica_apply_optimized_offsets(uuid,integer,integer) to authenticated;
select pg_notify('pgrst','reload schema');
