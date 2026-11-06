-- V3.4.3: simulación multipuesto sin escrituras persistentes.
-- No modifica los turnos, los desfases ni los pools.
BEGIN;
CREATE OR REPLACE FUNCTION public.provica_simulate_shared_pool(
 p_pool uuid, p_min_rest_hours integer DEFAULT 12
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
 r record; person uuid; total_n int:=0; covered_n int:=0; missing_n int:=0;
 problems jsonb:='[]'::jsonb; by_worker jsonb; by_plan jsonb;
 rest_gap interval; current_pool text; total_hours numeric;
BEGIN
 IF public.current_user_role() NOT IN ('ADMIN','OPERACIONES','RRHH','SUPERVISOR') THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF p_min_rest_hours IS NULL OR p_min_rest_hours NOT BETWEEN 1 AND 48 THEN RAISE EXCEPTION 'Descanso fuera de rango'; END IF;
 SELECT name INTO current_pool FROM public.relief_pools WHERE id=p_pool AND active;
 IF current_pool IS NULL THEN RAISE EXCEPTION 'Pool inexistente o inactivo'; END IF;
 rest_gap:=make_interval(hours=>p_min_rest_hours);
 CREATE TEMP TABLE IF NOT EXISTS pg_temp.v343_schedule (
  plan_id uuid, slot_id uuid, worker uuid, starts_at timestamptz, ends_at timestamptz, is_relief boolean
 ) ON COMMIT DROP;
 TRUNCATE pg_temp.v343_schedule;
 CREATE TEMP TABLE IF NOT EXISTS pg_temp.v343_demands (
  plan_id uuid, slot_id uuid, starts_at timestamptz, ends_at timestamptz, primary_id uuid, primary_on boolean, assigned uuid
 ) ON COMMIT DROP;
 TRUNCATE pg_temp.v343_demands;
 -- Construye todas las necesidades de los planes asociados al pool, en orden temporal global.
 INSERT INTO pg_temp.v343_demands(plan_id,slot_id,starts_at,ends_at,primary_id,primary_on)
 SELECT pl.id,sl.id,
   ((d.day_date::text||' '||sl.start_time::text)::timestamp AT TIME ZONE 'America/Guayaquil') AS a,
   ((d.day_date::text||' '||sl.start_time::text)::timestamp AT TIME ZONE 'America/Guayaquil')+make_interval(hours=>sl.duration_hours),
   sl.primary_personnel_id,
   ((d.day_date-pl.start_date+sl.cycle_offset)%(sl.work_days+sl.rest_days))<sl.work_days
 FROM public.relief_pool_plans l
 JOIN public.post_plans pl ON pl.id=l.plan_id AND pl.active
 JOIN public.post_plan_slots sl ON sl.plan_id=pl.id
 CROSS JOIN LATERAL (SELECT gs::date AS day_date FROM generate_series(pl.start_date::timestamp,pl.end_date::timestamp,interval '1 day') gs) d
 WHERE l.pool_id=p_pool AND sl.work_days>0 AND sl.rest_days>0
   AND ((d.day_date::text||' '||sl.start_time::text)::timestamp AT TIME ZONE 'America/Guayaquil')>now();
 SELECT count(*) INTO total_n FROM pg_temp.v343_demands;
 FOR r IN SELECT * FROM pg_temp.v343_demands ORDER BY starts_at,slot_id LOOP
   person:=NULL;
   IF r.primary_on THEN
     SELECT p.id INTO person FROM public.personnel p
     WHERE p.id=r.primary_id AND p.active
       AND NOT EXISTS (SELECT 1 FROM pg_temp.v343_schedule t WHERE t.worker=p.id AND t.starts_at<r.ends_at+rest_gap AND t.ends_at>r.starts_at-rest_gap)
       AND NOT EXISTS (SELECT 1 FROM public.shifts s WHERE s.personnel_id=p.id AND s.status<>'CANCELADO'
         AND NOT (s.status='PROGRAMADO' AND s.starts_at>now() AND s.plan_slot_id IN (SELECT slot_id FROM pg_temp.v343_demands))
         AND s.starts_at<r.ends_at+rest_gap AND s.ends_at>r.starts_at-rest_gap);
   ELSE
     -- Solo integrantes del pool seleccionado; preferencia es informativa en esta versión.
     SELECT m.personnel_id INTO person
     FROM public.relief_pool_members m JOIN public.personnel p ON p.id=m.personnel_id AND p.active
     WHERE m.pool_id=p_pool
       AND NOT EXISTS (SELECT 1 FROM pg_temp.v343_schedule t WHERE t.worker=m.personnel_id AND t.starts_at<r.ends_at+rest_gap AND t.ends_at>r.starts_at-rest_gap)
       AND NOT EXISTS (SELECT 1 FROM public.shifts s WHERE s.personnel_id=m.personnel_id AND s.status<>'CANCELADO'
         AND NOT (s.status='PROGRAMADO' AND s.starts_at>now() AND s.plan_slot_id IN (SELECT slot_id FROM pg_temp.v343_demands))
         AND s.starts_at<r.ends_at+rest_gap AND s.ends_at>r.starts_at-rest_gap)
     ORDER BY (SELECT coalesce(sum(extract(epoch FROM (t.ends_at-t.starts_at))/3600),0) FROM pg_temp.v343_schedule t WHERE t.worker=m.personnel_id),m.priority,m.personnel_id
     LIMIT 1;
   END IF;
   IF person IS NULL THEN
     missing_n:=missing_n+1;
     IF jsonb_array_length(problems)<50 THEN problems:=problems||jsonb_build_array(jsonb_build_object('plan_id',r.plan_id,'slot_id',r.slot_id,'starts_at',r.starts_at,'reason',CASE WHEN r.primary_on THEN 'Titular no disponible o descanso insuficiente' ELSE 'Pool sin relevo compatible' END)); END IF;
   ELSE
     INSERT INTO pg_temp.v343_schedule VALUES(r.plan_id,r.slot_id,person,r.starts_at,r.ends_at,NOT r.primary_on);
     UPDATE pg_temp.v343_demands SET assigned=person WHERE slot_id=r.slot_id AND starts_at=r.starts_at;
     covered_n:=covered_n+1;
   END IF;
 END LOOP;
 SELECT coalesce(jsonb_agg(jsonb_build_object('person_code',person_code,'hours',hours,'shifts',n) ORDER BY person_code),'[]'::jsonb) INTO by_worker
 FROM (SELECT p.person_code,round(sum(extract(epoch FROM (t.ends_at-t.starts_at))/3600)::numeric,1) hours,count(*) n FROM pg_temp.v343_schedule t JOIN public.personnel p ON p.id=t.worker GROUP BY p.person_code) x;
 SELECT coalesce(jsonb_agg(jsonb_build_object('plan_id',id,'post',post,'required',required,'covered',covered,'uncovered',required-covered) ORDER BY post),'[]'::jsonb) INTO by_plan
 FROM (SELECT d.plan_id id,g.post_code||' · '||g.name post,count(*) required,count(d.assigned) covered FROM pg_temp.v343_demands d JOIN public.post_plans pl ON pl.id=d.plan_id JOIN public.guard_posts g ON g.id=pl.guard_post_id GROUP BY d.plan_id,g.post_code,g.name) q;
 SELECT coalesce(sum(extract(epoch FROM (ends_at-starts_at))/3600),0) INTO total_hours FROM pg_temp.v343_schedule;
 RETURN jsonb_build_object('engine_version','3.4.3-preview','pool',current_pool,'required_shifts',total_n,'covered_shifts',covered_n,'uncovered_shifts',missing_n,'coverage_percent',CASE WHEN total_n=0 THEN 0 ELSE round(covered_n*100.0/total_n,1) END,'viable',total_n>0 AND missing_n=0,'min_rest_hours',p_min_rest_hours,'hours_assigned',total_hours,'workers',by_worker,'plans',by_plan,'conflicts',problems,'simulation_only',true,'note','No genera turnos. Preferencias de horario, traslados y topes contractuales aún no son restricciones duras.');
END $$;
REVOKE ALL ON FUNCTION public.provica_simulate_shared_pool(uuid,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.provica_simulate_shared_pool(uuid,integer) TO authenticated;
SELECT pg_notify('pgrst','reload schema');
COMMIT;
