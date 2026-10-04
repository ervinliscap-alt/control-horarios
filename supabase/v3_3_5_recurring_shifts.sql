-- V3.3.5 CORREGIDA: programación operativa basada en personnel, no en Auth.
create table if not exists public.shift_templates(id uuid primary key default gen_random_uuid(),name text not null unique,duration_hours integer not null check(duration_hours in(8,12)),default_start_time time not null,active boolean not null default true,created_at timestamptz not null default now());
insert into public.shift_templates(name,duration_hours,default_start_time) values('Diurno 12h',12,'07:00'),('Nocturno 12h',12,'19:00'),('Mañana 8h',8,'07:00'),('Tarde 8h',8,'15:00'),('Noche 8h',8,'23:00') on conflict(name) do nothing;
create table if not exists public.shift_schedules(id uuid primary key default gen_random_uuid(),guard_post_id uuid not null references public.guard_posts(id),personnel_id uuid not null references public.personnel(id),template_id uuid references public.shift_templates(id),start_date date not null,start_time time not null,duration_hours integer not null check(duration_hours in(8,12)),pattern text not null check(pattern in('DAILY','5X2','WEEKDAYS')),end_date date not null,active boolean not null default true,created_by uuid references public.profiles(id),created_at timestamptz not null default now(),check(end_date>=start_date));
alter table public.shifts add column if not exists personnel_id uuid references public.personnel(id);
alter table public.shifts add column if not exists schedule_id uuid references public.shift_schedules(id) on delete set null;
update public.shifts s set personnel_id=pe.id from public.personnel pe where s.personnel_id is null and s.guard_id=pe.profile_id;
create index if not exists shifts_personnel_time_idx on public.shifts(personnel_id,starts_at,ends_at);
alter table public.shift_templates enable row level security;alter table public.shift_schedules enable row level security;
drop policy if exists shift_templates_staff_read on public.shift_templates;create policy shift_templates_staff_read on public.shift_templates for select to authenticated using(public.current_user_role() in('ADMIN','RRHH','OPERACIONES','SUPERVISOR'));
drop policy if exists shift_schedules_staff_read on public.shift_schedules;create policy shift_schedules_staff_read on public.shift_schedules for select to authenticated using(public.current_user_role() in('ADMIN','RRHH','OPERACIONES','SUPERVISOR'));
create or replace function public.prevent_inactive_guard_shift() returns trigger language plpgsql set search_path=public as $$ begin
 if new.personnel_id is not null and exists(select 1 from personnel where id=new.personnel_id and (not active or personnel_type<>'OPERATIVO' or intended_role<>'GUARDIA')) then raise exception 'No se puede asignar el turno: personal inactivo o no es GUARDIA operativo';end if;
 if new.guard_id is not null and exists(select 1 from profiles p left join personnel pe on pe.profile_id=p.id where p.id=new.guard_id and(not p.active or(pe.id is not null and not pe.active)))then raise exception 'No se puede asignar un turno a personal inactivo';end if;return new;end $$;
drop trigger if exists prevent_inactive_guard_shift_trigger on public.shifts;create trigger prevent_inactive_guard_shift_trigger before insert or update of guard_id,personnel_id on public.shifts for each row execute function public.prevent_inactive_guard_shift();
create or replace function public.provica_create_recurring_schedule(p_post uuid,p_personnel uuid,p_template uuid,p_start_date date,p_start_time time,p_pattern text,p_months integer default 1) returns jsonb language plpgsql security definer set search_path=public as $$
declare me user_role:=current_user_role();dur int;finish date;sid uuid;d date;a timestamptz;b timestamptz;n int:=0;day_index int:=0;linked_profile uuid;
begin
if me not in('ADMIN','OPERACIONES')then raise exception 'Solo ADMIN u OPERACIONES pueden programar turnos';end if;
if p_months<1 or p_months>12 then raise exception 'La vigencia debe ser de 1 a 12 meses';end if;if p_pattern not in('DAILY','5X2','WEEKDAYS')then raise exception 'Patron invalido';end if;
select duration_hours into dur from shift_templates where id=p_template and active=true;if dur is null then raise exception 'Turno preestablecido inexistente o inactivo';end if;
if not exists(select 1 from guard_posts where id=p_post and active=true)then raise exception 'Puesto inexistente o inactivo';end if;
select profile_id into linked_profile from personnel where id=p_personnel and active=true and personnel_type='OPERATIVO' and intended_role='GUARDIA';if not found then raise exception 'Guardia inexistente, inactivo o no operativo';end if;
finish:=(p_start_date+make_interval(months=>p_months))::date-1;
insert into shift_schedules(guard_post_id,personnel_id,template_id,start_date,start_time,duration_hours,pattern,end_date,created_by)values(p_post,p_personnel,p_template,p_start_date,p_start_time,dur,p_pattern,finish,auth.uid())returning id into sid;
d:=p_start_date;while d<=finish loop
if p_pattern='DAILY' or(p_pattern='WEEKDAYS' and extract(isodow from d)<=5)or(p_pattern='5X2' and(day_index%7)<5)then
a:=(d::text||' '||p_start_time::text)::timestamp at time zone 'America/Guayaquil';b:=a+make_interval(hours=>dur);
if exists(select 1 from shifts where personnel_id=p_personnel and status<>'CANCELADO' and starts_at<b and ends_at>a)then raise exception 'Conflicto de turno para % en %',(select person_code from personnel where id=p_personnel),d;end if;
insert into shifts(guard_post_id,guard_id,personnel_id,starts_at,ends_at,status,schedule_id)values(p_post,linked_profile,p_personnel,a,b,'PROGRAMADO',sid);n:=n+1;end if;d:=d+1;day_index:=day_index+1;end loop;
return jsonb_build_object('schedule_id',sid,'shifts_created',n,'end_date',finish);end $$;
revoke all on function public.provica_create_recurring_schedule(uuid,uuid,uuid,date,time,text,integer) from public;grant execute on function public.provica_create_recurring_schedule(uuid,uuid,uuid,date,time,text,integer) to authenticated;
