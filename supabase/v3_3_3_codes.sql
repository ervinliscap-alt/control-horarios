-- PROVICA V3.3.3 - Codigos operativos inmutables
create sequence if not exists public.guard_post_code_seq;
create sequence if not exists public.person_code_seq;
alter table public.guard_posts add column if not exists post_code text;
alter table public.profiles add column if not exists person_code text;

with n as (select id,row_number() over(order by created_at nulls last,id) rn from public.guard_posts where post_code is null)
update public.guard_posts g set post_code=lpad(n.rn::text,6,'0') from n where g.id=n.id;
with n as (select id,row_number() over(order by created_at,id) rn from public.profiles where person_code is null)
update public.profiles p set person_code='P'||lpad(n.rn::text,6,'0') from n where p.id=n.id;

select setval('public.guard_post_code_seq',greatest(coalesce((select max(post_code::bigint) from public.guard_posts where post_code~'^[0-9]+$'),0),1),true);
select setval('public.person_code_seq',greatest(coalesce((select max(substring(person_code from 2)::bigint) from public.profiles where person_code~'^P[0-9]+$'),0),1),true);

create or replace function public.assign_guard_post_code() returns trigger language plpgsql security definer set search_path=public as $$begin if new.post_code is null then new.post_code:=lpad(nextval('public.guard_post_code_seq')::text,6,'0');end if;return new;end$$;
create or replace function public.assign_person_code() returns trigger language plpgsql security definer set search_path=public as $$begin if new.person_code is null then new.person_code:='P'||lpad(nextval('public.person_code_seq')::text,6,'0');end if;return new;end$$;
drop trigger if exists assign_guard_post_code_trigger on public.guard_posts;
create trigger assign_guard_post_code_trigger before insert on public.guard_posts for each row execute function public.assign_guard_post_code();
drop trigger if exists assign_person_code_trigger on public.profiles;
create trigger assign_person_code_trigger before insert on public.profiles for each row execute function public.assign_person_code();

alter table public.guard_posts alter column post_code set not null;
alter table public.profiles alter column person_code set not null;
create unique index if not exists guard_posts_post_code_unique on public.guard_posts(post_code);
create unique index if not exists profiles_person_code_unique on public.profiles(person_code);

create or replace function public.protect_operational_code() returns trigger language plpgsql as $$begin
if tg_table_name='guard_posts' and new.post_code is distinct from old.post_code then raise exception 'El numero de puesto es inmutable';
elsif tg_table_name='profiles' and new.person_code is distinct from old.person_code then raise exception 'El codigo de personal es inmutable';end if;return new;end$$;
drop trigger if exists protect_guard_post_code on public.guard_posts;
create trigger protect_guard_post_code before update on public.guard_posts for each row execute function public.protect_operational_code();
drop trigger if exists protect_person_code on public.profiles;
create trigger protect_person_code before update on public.profiles for each row execute function public.protect_operational_code();
