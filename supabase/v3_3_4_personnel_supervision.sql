-- PROVICA V3.3.4 - Personal, tipo de usuario y alcance de supervision
-- Ejecutar despues de V3.3.3

-- 1) Clasificacion del perfil sin romper la relacion actual con Authentication.
alter table public.profiles add column if not exists user_type text not null default 'OPERATIVO'
  check (user_type in ('OPERATIVO','CONTROL'));
alter table public.profiles add column if not exists app_access boolean not null default true;
alter table public.profiles add column if not exists email text;

-- Normalizar perfiles existentes.
update public.profiles set user_type=case when role='GUARDIA' then 'OPERATIVO' else 'CONTROL' end
where user_type is distinct from case when role='GUARDIA' then 'OPERATIVO' else 'CONTROL' end;

-- 2) Registro RRHH independiente de login.
create table if not exists public.personnel (
 id uuid primary key default gen_random_uuid(),
 person_code text unique not null,
 full_name text not null,
 identification text,
 phone text,
 email text,
 personnel_type text not null default 'OPERATIVO' check(personnel_type in ('OPERATIVO','CONTROL')),
 intended_role public.user_role not null default 'GUARDIA',
 app_access boolean not null default false,
 profile_id uuid unique references public.profiles(id) on delete set null,
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create unique index if not exists personnel_identification_unique on public.personnel(identification) where identification is not null and identification<>'';

-- Reutiliza la secuencia P000xxx ya creada en V3.3.3.
create or replace function public.assign_personnel_code() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if new.person_code is null or new.person_code='' then new.person_code:='P'||lpad(nextval('public.person_code_seq')::text,6,'0'); end if;
 return new;
end $$;
drop trigger if exists assign_personnel_code_trigger on public.personnel;
create trigger assign_personnel_code_trigger before insert on public.personnel for each row execute function public.assign_personnel_code();

-- Copiar perfiles existentes al registro RRHH conservando su P-code.
insert into public.personnel(person_code,full_name,identification,phone,email,personnel_type,intended_role,app_access,profile_id,active)
select person_code,full_name,identification,phone,email,
 case when role='GUARDIA' then 'OPERATIVO' else 'CONTROL' end,role,true,id,active
from public.profiles
on conflict(person_code) do nothing;

-- 3) Alcance muchos-a-muchos de supervisores.
create table if not exists public.supervisor_clients(
 supervisor_id uuid not null references public.profiles(id) on delete cascade,
 client_id uuid not null references public.clients(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(supervisor_id,client_id)
);
create table if not exists public.supervisor_sites(
 supervisor_id uuid not null references public.profiles(id) on delete cascade,
 site_id uuid not null references public.sites(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(supervisor_id,site_id)
);

alter table public.personnel enable row level security;
alter table public.supervisor_clients enable row level security;
alter table public.supervisor_sites enable row level security;

drop policy if exists personnel_staff_read on public.personnel;
create policy personnel_staff_read on public.personnel for select to authenticated using(public.current_user_role() in ('ADMIN','RRHH','OPERACIONES','SUPERVISOR'));
drop policy if exists supervisor_scope_staff_read on public.supervisor_clients;
create policy supervisor_scope_staff_read on public.supervisor_clients for select to authenticated using(public.current_user_role() in ('ADMIN','OPERACIONES','SUPERVISOR'));
drop policy if exists supervisor_site_scope_staff_read on public.supervisor_sites;
create policy supervisor_site_scope_staff_read on public.supervisor_sites for select to authenticated using(public.current_user_role() in ('ADMIN','OPERACIONES','SUPERVISOR'));

-- 4) Alta/edicion segura de personal SIN crear credenciales Auth.
create or replace function public.provica_create_personnel(p_full_name text,p_identification text,p_phone text,p_email text,p_type text,p_role public.user_role,p_app_access boolean)
returns uuid language plpgsql security definer set search_path=public as $$
declare me public.user_role:=public.current_user_role(); nid uuid;
begin
 if me not in ('ADMIN','RRHH') then raise exception 'No autorizado'; end if;
 if me='RRHH' and (p_type<>'OPERATIVO' or p_role<>'GUARDIA') then raise exception 'RRHH solo puede crear personal operativo GUARDIA'; end if;
 if p_type not in ('OPERATIVO','CONTROL') then raise exception 'Tipo invalido'; end if;
 if p_type='OPERATIVO' and p_role<>'GUARDIA' then raise exception 'El personal operativo debe tener rol GUARDIA'; end if;
 if p_type='CONTROL' and p_role='GUARDIA' then raise exception 'Un usuario de control no puede tener rol GUARDIA'; end if;
 insert into personnel(person_code,full_name,identification,phone,email,personnel_type,intended_role,app_access)
 values('',trim(p_full_name),nullif(trim(p_identification),''),nullif(trim(p_phone),''),nullif(lower(trim(p_email)),''),p_type,p_role,p_app_access)
 returning id into nid;
 return nid;
end $$;
grant execute on function public.provica_create_personnel(text,text,text,text,text,public.user_role,boolean) to authenticated;

-- 5) Asignacion de alcance: ADMIN u OPERACIONES.
create or replace function public.provica_set_supervisor_scope(p_supervisor uuid,p_clients uuid[],p_sites uuid[])
returns void language plpgsql security definer set search_path=public as $$
begin
 if public.current_user_role() not in ('ADMIN','OPERACIONES') then raise exception 'No autorizado'; end if;
 if not exists(select 1 from profiles where id=p_supervisor and role='SUPERVISOR') then raise exception 'El usuario no es SUPERVISOR'; end if;
 delete from supervisor_clients where supervisor_id=p_supervisor;
 delete from supervisor_sites where supervisor_id=p_supervisor;
 insert into supervisor_clients(supervisor_id,client_id) select p_supervisor,unnest(coalesce(p_clients,array[]::uuid[]));
 insert into supervisor_sites(supervisor_id,site_id) select p_supervisor,unnest(coalesce(p_sites,array[]::uuid[]));
end $$;
grant execute on function public.provica_set_supervisor_scope(uuid,uuid[],uuid[]) to authenticated;
