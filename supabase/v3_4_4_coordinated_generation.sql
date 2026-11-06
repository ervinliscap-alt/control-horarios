-- V3.4.4. Generación coordinada de turnos futuros, sin reemplazar registros existentes.
-- No ejecutar la generación hasta comprobar la vista previa y la ausencia de datos reales.
BEGIN;
CREATE TABLE IF NOT EXISTS public.shared_pool_generation_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 pool_id uuid NOT NULL REFERENCES public.relief_pools(id),
 actor uuid DEFAULT auth.uid(),
 generated_at timestamptz NOT NULL DEFAULT now(),
 created_count integer NOT NULL,
 created_shift_ids uuid[] NOT NULL,
 min_rest_hours integer NOT NULL,
 note text NOT NULL
);
ALTER TABLE public.shared_pool_generation_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.shared_pool_generation_audit FROM anon,authenticated;

-- Único algoritmo para vista previa y escritura: la generación usa la misma asignación.
CREATE OR REPLACE FUNCTION public.provica_shared_pool_schedule(
 p_pool uuid, p_min_rest_hours integer DEFAULT 12, p_generate boolean DEFAULT false,
 p_confirm text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
 r record; v_person uuid; v_profile uuid; v_total integer:=0; v_covered integer:=0;
 v_missing integer:=0; v_created integer:=0; v_ids uuid[]:=ARRAY[]::uuid[];
 v_problems jsonb:='[]'::jsonb; v_workers jsonb; v_plans jsonb;
 v_gap interval; v_name text; v_output jsonb;
BEGIN
 IF public.current_user_role() NOT IN ('ADMIN','OPERACIONES','RRHH','SUPERVISOR') THEN
  RAISE EXCEPTION 'No autorizado'; END IF;
 IF p_generate AND public.current_user_role() NOT IN ('ADMIN','OPERACIONES') THEN
  RAISE EXCEPTION 'Solo ADMIN u OPERACIONES pueden generar'; END IF;
 IF p_generate AND p_confirm IS DISTINCT FROM 'GENERAR POOL' THEN
  RAISE EXCEPTION 'Confirmación requerida: GENERAR POOL'; END IF;
 IF p_min_rest_hours IS NULL OR p_min_rest_hours NOT BETWEEN 12 AND 48 THEN
  RAISE EXCEPTION 'El descanso debe ser de 12 a 48 horas'; END IF;
 SELECT name INTO v_name FROM public.relief_pools WHERE id=p_pool AND active;
 IF v_name IS NULL THEN RAISE EXCEPTION 'Pool no encontrado o inactivo'; END IF;
 v_gap:=make_interval(hours=>p_min_rest_hours);
 -- Evita dos generaciones simultáneas desde este procedimiento, incluso en pools distintos.
 IF p_generate THEN PERFORM pg_advisory_xact_lock(987344,1); END IF;
 CREATE TEMP TABLE IF NOT EXISTS pg_temp.v344_demands (
  plan_id uuid, post_id uuid, slot_id uuid, starts_at timestamptz,
  ends_at timestamptz, primary_id uuid, primary_on boolean, assigned uuid
 ) ON COMMIT DROP;
 TRUNCATE pg_temp.v344_demands;
 INSERT INTO pg_temp.v344_demands(plan_id,post_id,slot_id,starts_at,ends_at,primary_id,primary_on)
 SELECT pl.id,pl.guard_post_id,sl.id,
  ((d.day_date::text||' '||sl.start_time::text)::timestamp AT TIME ZONE 'America/Guayaquil'),
  ((d.day_date::text||' '||sl.start_time::text)::timestamp AT TIME ZONE 'America/Guayaquil')+make_interval(hours=>sl.duration_hours),
  sl.primary_personnel_id,
  ((d.day_date-pl.start_date+sl.cycle_offset)%(sl.work_days+sl.rest_days))<sl.work_days
 FROM public.relief_pool_plans l
 JOIN public.post_plans pl ON pl.id=l.plan_id AND pl.active
 JOIN public.post_plan_slots sl ON sl.plan_id=pl.id
 CROSS JOIN LATERAL (
  SELECT gs::date AS day_date
  FROM generate_series(pl.start_date::timestamp,pl.end_date::timestamp,interval '1 day') gs
 ) d
 WHERE l.pool_id=p_pool AND sl.work_days>0 AND sl.rest_days>0
 AND ((d.day_date::text||' '||sl.start_time::text)::timestamp AT TIME ZONE 'America/Guayaquil')>now();
 SELECT count(*) INTO v_total FROM pg_temp.v344_demands;
 IF v_total=0 THEN RAISE EXCEPTION 'No hay jornadas futuras para este pool'; END IF;
 -- Conservación estricta: no se borra ni sustituye ningún turno futuro existente.
 IF p_generate AND EXISTS (
  SELECT 1 FROM public.shifts s
  JOIN public.post_plan_slots sl ON sl.id=s.plan_slot_id
  JOIN public.relief_pool_plans l ON l.plan_id=sl.plan_id AND l.pool_id=p_pool
  WHERE s.status<>'CANCELADO' AND s.starts_at>now()
 ) THEN RAISE EXCEPTION 'Ya existen turnos para algunas fechas del pool; no se sobrescribe nada'; END IF;
 CREATE TEMP TABLE IF NOT EXISTS pg_temp.v344_alloc (
  plan_id uuid, post_id uuid, slot_id uuid, worker uuid,
  starts_at timestamptz, ends_at timestamptz, is_relief boolean
 ) ON COMMIT DROP;
 TRUNCATE pg_temp.v344_alloc;
 FOR r IN SELECT * FROM pg_temp.v344_demands ORDER BY starts_at,slot_id LOOP
  v_person:=NULL;
  IF r.primary_on THEN
   SELECT p.id INTO v_person FROM public.personnel p
   WHERE p.id=r.primary_id AND p.active
    AND NOT EXISTS (
     SELECT 1 FROM pg_temp.v344_alloc t WHERE t.worker=p.id
      AND t.starts_at<r.ends_at+v_gap AND t.ends_at>r.starts_at-v_gap)
    AND NOT EXISTS (
     SELECT 1 FROM public.shifts s WHERE s.personnel_id=p.id AND s.status<>'CANCELADO'
      AND s.starts_at<r.ends_at+v_gap AND s.ends_at>r.starts_at-v_gap
      AND NOT (s.status='PROGRAMADO' AND s.starts_at>now()
       AND EXISTS (SELECT 1 FROM pg_temp.v344_demands d WHERE d.slot_id=s.plan_slot_id AND d.starts_at=s.starts_at)));
  ELSE
   SELECT m.personnel_id INTO v_person
   FROM public.relief_pool_members m
   JOIN public.personnel p ON p.id=m.personnel_id AND p.active
   WHERE m.pool_id=p_pool
    AND NOT EXISTS (
     SELECT 1 FROM pg_temp.v344_alloc t WHERE t.worker=m.personnel_id
      AND t.starts_at<r.ends_at+v_gap AND t.ends_at>r.starts_at-v_gap)
    AND NOT EXISTS (
     SELECT 1 FROM public.shifts s WHERE s.personnel_id=m.personnel_id AND s.status<>'CANCELADO'
      AND s.starts_at<r.ends_at+v_gap AND s.ends_at>r.starts_at-v_gap
      AND NOT (s.status='PROGRAMADO' AND s.starts_at>now()
       AND EXISTS (SELECT 1 FROM pg_temp.v344_demands d WHERE d.slot_id=s.plan_slot_id AND d.starts_at=s.starts_at)))
   ORDER BY (SELECT coalesce(sum(extract(epoch FROM(t.ends_at-t.starts_at))/3600),0)
    FROM pg_temp.v344_alloc t WHERE t.worker=m.personnel_id),m.priority,m.personnel_id
   LIMIT 1;
  END IF;
  IF v_person IS NULL THEN
   v_missing:=v_missing+1;
   IF jsonb_array_length(v_problems)<50 THEN
    v_problems:=v_problems||jsonb_build_array(jsonb_build_object(
     'plan_id',r.plan_id,'slot_id',r.slot_id,'starts_at',r.starts_at,
     'reason',CASE WHEN r.primary_on THEN 'Titular no disponible' ELSE 'Pool sin relevo compatible' END));
   END IF;
  ELSE
   INSERT INTO pg_temp.v344_alloc VALUES
    (r.plan_id,r.post_id,r.slot_id,v_person,r.starts_at,r.ends_at,NOT r.primary_on);
   UPDATE pg_temp.v344_demands SET assigned=v_person
    WHERE slot_id=r.slot_id AND starts_at=r.starts_at;
   v_covered:=v_covered+1;
  END IF;
 END LOOP;
 SELECT coalesce(jsonb_agg(jsonb_build_object('person_code',person_code,'hours',hours,'shifts',n)
  ORDER BY person_code),'[]'::jsonb) INTO v_workers
 FROM (SELECT p.person_code,round(sum(extract(epoch FROM(t.ends_at-t.starts_at))/3600)::numeric,1) hours,
  count(*) n FROM pg_temp.v344_alloc t JOIN public.personnel p ON p.id=t.worker
  GROUP BY p.person_code) x;
 SELECT coalesce(jsonb_agg(jsonb_build_object('plan_id',id,'post',post,'required',required,
  'covered',covered,'uncovered',required-covered) ORDER BY post),'[]'::jsonb) INTO v_plans
 FROM (SELECT d.plan_id id,g.post_code||' · '||g.name post,count(*) required,
  count(d.assigned) covered FROM pg_temp.v344_demands d
  JOIN public.post_plans pl ON pl.id=d.plan_id
  JOIN public.guard_posts g ON g.id=pl.guard_post_id
  GROUP BY d.plan_id,g.post_code,g.name) q;
 v_output:=jsonb_build_object('engine_version','3.4.4','pool',v_name,
  'required_shifts',v_total,'covered_shifts',v_covered,'uncovered_shifts',v_missing,
  'coverage_percent',round(100.0*v_covered/v_total,1),'viable',v_missing=0,
  'min_rest_hours',p_min_rest_hours,'workers',v_workers,'plans',v_plans,
  'conflicts',v_problems,'simulation_only',NOT p_generate,
  'note','Asignación cronológica heurística; aún no optimiza desfases, traslado ni topes contractuales.');
 IF NOT p_generate THEN RETURN v_output; END IF;
 IF v_missing>0 THEN RAISE EXCEPTION 'Generación cancelada: % jornadas sin cubrir',v_missing; END IF;
 -- No insertar si se han creado turnos en el intervalo desde la vista previa.
 IF EXISTS (
  SELECT 1 FROM public.shifts s
  JOIN public.post_plan_slots sl ON sl.id=s.plan_slot_id
  JOIN public.relief_pool_plans l ON l.plan_id=sl.plan_id AND l.pool_id=p_pool
  WHERE s.status<>'CANCELADO' AND s.starts_at>now()
 ) THEN RAISE EXCEPTION 'Generación cancelada: ya existen turnos futuros en el plan'; END IF;
 -- Inserción atómica, con auditoría y sin borrar ningún registro.
 FOR r IN SELECT * FROM pg_temp.v344_alloc ORDER BY starts_at,slot_id LOOP
  SELECT profile_id INTO v_profile FROM public.personnel WHERE id=r.worker;
  INSERT INTO public.shifts(guard_post_id,guard_id,personnel_id,starts_at,ends_at,status,plan_slot_id)
  VALUES(r.post_id,v_profile,r.worker,r.starts_at,r.ends_at,'PROGRAMADO',r.slot_id)
  RETURNING id INTO v_person;
  v_ids:=array_append(v_ids,v_person);
  v_created:=v_created+1;
 END LOOP;
 INSERT INTO public.shared_pool_generation_audit(pool_id,created_count,created_shift_ids,min_rest_hours,note)
 VALUES(p_pool,v_created,v_ids,p_min_rest_hours,'Generación coordinada V3.4.4');
 RETURN v_output||jsonb_build_object('simulation_only',false,'shifts_created',v_created,'audit_saved',true);
END $$;
REVOKE ALL ON FUNCTION public.provica_shared_pool_schedule(uuid,integer,boolean,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.provica_shared_pool_schedule(uuid,integer,boolean,text) TO authenticated;
SELECT pg_notify('pgrst','reload schema');
COMMIT;
