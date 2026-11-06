import {redirect} from 'next/navigation';
import {createClient} from '../../lib/supabase/server';
import AppShell from '../../components/app-shell';
import PostPlanner from '../../components/post-planner';
import CoverageCalendar from '../../components/coverage-calendar';
import ReliefPoolManager from '../../components/relief-pool-manager';
import FutureShiftCleanup from '../../components/future-shift-cleanup';
import SharedPoolCoordinator from '../../components/shared-pool-coordinator';
import SharedPoolSimulator from '../../components/shared-pool-simulator';
import PlanningTabs from '../../components/planning-tabs';
import PlanningDashboard from '../../components/planning-dashboard';
export default async function Page(){
 const s=await createClient(),{data:{user}}=await s.auth.getUser();if(!user)redirect('/login');
 const {data:p}=await s.from('profiles').select('full_name,role').eq('id',user.id).single();
 const {data:posts}=await s.from('guard_posts').select('id,post_code,name,coverage_hours,sites(id,name,clients(id,name))').eq('active',true).order('post_code');
 const {data:guards}=await s.from('personnel').select('id,person_code,full_name').eq('active',true).eq('personnel_type','OPERATIVO').eq('intended_role','GUARDIA').order('person_code');
 const {data:plans}=await s.from('post_plans').select('id,start_date,end_date,guard_posts(post_code,name,coverage_hours,sites(name,clients(name))),post_plan_slots(id,slot_order,start_time,duration_hours,work_days,rest_days,cycle_offset,primary_personnel_id),post_plan_relief_pool(personnel_id)').eq('active',true).order('created_at',{ascending:false});
 const P=plans||[],G=guards||[],R=p?.role||'';
 return <AppShell title="Planificación de cobertura" user={p?.full_name||user.email||''} role={R}>
  <PlanningTabs tabs={[
   {id:'titulares',label:'Titulares y puestos',description:'Crea cajones y configura los trabajadores titulares, desfases y relevos de cada puesto.',content:<PostPlanner posts={posts||[]} guards={G} plans={P} role={R}/>},
   {id:'horarios',label:'Horarios',description:'Consulta el calendario mensual de cada puesto y las alertas de descanso.',content:<CoverageCalendar plans={P}/>},
   {id:'pools',label:'Pools de sacafrancos',description:'Administra los pools compartidos, sus integrantes y los puestos asociados.',content:<ReliefPoolManager guards={G} plans={P} role={R}/>},
   {id:'simulacion',label:'Simulación global',description:'Evalúa la cobertura conjunta antes de crear turnos.',content:<SharedPoolSimulator/>},
   {id:'generacion',label:'Generación coordinada',description:'Vista previa y generación controlada de varios puestos que comparten personal.',content:<SharedPoolCoordinator role={R}/>},
   ...(R==='ADMIN'?[{id:'limpieza',label:'Limpieza (ADMIN)',description:'Herramienta de mantenimiento para retirar turnos futuros de prueba de forma controlada.',content:<FutureShiftCleanup plans={P} role={R}/>}]:[]),
   {id:'dashboard',label:'Dashboard',description:'Identifica trabajadores en turno y próximos relevos, diferenciando titulares de sustituciones.',content:<PlanningDashboard plans={P} guards={G}/>}
  ]}/>
 </AppShell>;
}
