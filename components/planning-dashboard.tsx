'use client';
import {useCallback,useEffect,useMemo,useState} from 'react';
import {createClient} from '../lib/supabase/client';
import PlanningWeeklyGrid from './planning-weekly-grid';
import PlanningGantt from './planning-gantt';

type Row={id:string;starts_at:string;ends_at:string;status:string;personnel_id:string|null;plan_slot_id:string|null};
type SlotInfo={post:string;postId:string;client:string;site:string;primary:string|null};
const TZ='America/Guayaquil';
const fmt=(s:string)=>new Intl.DateTimeFormat('es-EC',{timeZone:TZ,dateStyle:'short',timeStyle:'short'}).format(new Date(s));
const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:TZ,year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
export default function PlanningDashboard({plans,guards}:{plans:any[];guards:any[]}){
 const [rows,setRows]=useState<Row[]>([]),[busy,setBusy]=useState(false),[error,setError]=useState('');
 const [client,setClient]=useState(''),[site,setSite]=useState(''),[post,setPost]=useState(''),[worker,setWorker]=useState(''),[view,setView]=useState<'current'|'upcoming'|'all'>('current'),[week,setWeek]=useState(today);
 const entries=useMemo(()=>plans.map(p=>({id:p.id,postId:p.guard_post_id||p.id,post:`${p.guard_posts?.post_code||''} · ${p.guard_posts?.name||''}`,client:p.guard_posts?.sites?.clients?.name||'Sin cliente',site:p.guard_posts?.sites?.name||'Sin instalación'})),[plans]);
 const slots=useMemo(()=>new Map<string,SlotInfo>(plans.flatMap(p=>(p.post_plan_slots||[]).map((s:any)=>[s.id,{post:`${p.guard_posts?.post_code||''} · ${p.guard_posts?.name||''}`,postId:p.id,client:p.guard_posts?.sites?.clients?.name||'Sin cliente',site:p.guard_posts?.sites?.name||'Sin instalación',primary:s.primary_personnel_id||null}] as const))),[plans]);
 const people=useMemo(()=>new Map<string,any>(guards.map(g=>[g.id,g])),[guards]);
 const refresh=useCallback(async()=>{
  setBusy(true);setError('');const ids=[...slots.keys()];if(!ids.length){setRows([]);setBusy(false);return;}
  const w=new Date(`${week}T00:00:00-05:00`),lower=new Date(Math.min(Date.now()-36*3600000,w.getTime()-8*86400000)),upper=new Date(Math.max(Date.now()+35*86400000,w.getTime()+15*86400000));
  const {data,error}=await createClient().from('shifts').select('id,starts_at,ends_at,status,personnel_id,plan_slot_id').in('plan_slot_id',ids).gte('ends_at',lower.toISOString()).lte('starts_at',upper.toISOString()).order('starts_at',{ascending:true}).limit(1000);
  setBusy(false);if(error)setError(error.message);else setRows((data||[]) as Row[]);
 },[slots,week]);
 useEffect(()=>{void refresh()},[refresh]);
 const clients=[...new Set(entries.map(e=>e.client))].sort(),sites=[...new Set(entries.filter(e=>!client||e.client===client).map(e=>e.site))].sort();
 const posts=entries.filter(e=>(!client||e.client===client)&&(!site||e.site===site));
 const filtered=rows.filter(r=>{const s=slots.get(r.plan_slot_id||'');return r.status!=='CANCELADO'&&!!s&&(!client||s.client===client)&&(!site||s.site===site)&&(!post||s.postId===post)&&(!worker||r.personnel_id===worker)});
 const now=Date.now(),current=filtered.filter(r=>Date.parse(r.starts_at)<=now&&Date.parse(r.ends_at)>now),upcoming=filtered.filter(r=>Date.parse(r.starts_at)>now);
 const shown=filtered.filter(r=>view==='all'||(view==='current'?current.includes(r):upcoming.includes(r)));
 const role=(r:Row)=>slots.get(r.plan_slot_id||'')?.primary===r.personnel_id?'Titular':'Relevo / pool*';
 const onClient=(v:string)=>{setClient(v);setSite('');setPost('')};const onSite=(v:string)=>{setSite(v);setPost('')};
 return <div className="panel"><h3>Dashboard · Cobertura y planificación semanal</h3><p>Consulta por cliente, instalación, puesto y trabajador. Horarios de Ecuador (UTC−5).</p>
  <div className="form"><label>Cliente<select value={client} onChange={e=>onClient(e.target.value)}><option value="">Todos los clientes</option>{clients.map(x=><option key={x}>{x}</option>)}</select></label><label>Instalación<select value={site} onChange={e=>onSite(e.target.value)}><option value="">Todas las instalaciones</option>{sites.map(x=><option key={x}>{x}</option>)}</select></label><label>Puesto<select value={post} onChange={e=>setPost(e.target.value)}><option value="">Todos los puestos</option>{posts.map(p=><option key={p.id} value={p.id}>{p.post}</option>)}</select></label><label>Trabajador<select value={worker} onChange={e=>setWorker(e.target.value)}><option value="">Todos</option>{guards.map(g=><option key={g.id} value={g.id}>{g.person_code} · {g.full_name}</option>)}</select></label><label>Vista<select value={view} onChange={e=>setView(e.target.value as any)}><option value="current">En turno ahora</option><option value="upcoming">Próximos turnos</option><option value="all">Todos (ventana consultada)</option></select></label><button type="button" disabled={busy} onClick={()=>void refresh()}>{busy?'Actualizando…':'Actualizar'}</button></div>
  <div style={{display:'flex',flexWrap:'wrap',gap:12,margin:'18px 0'}}>{[['En servicio ahora',current.length],['Próximos turnos',upcoming.length],['Turnos consultados',filtered.length],['Titulares ahora',current.filter(r=>role(r)==='Titular').length],['Relevos ahora',current.filter(r=>role(r)!=='Titular').length]].map(([label,value])=><div key={String(label)} style={{background:'#fff2e7',borderRadius:10,padding:'14px 20px',minWidth:140}}><div style={{fontSize:25,fontWeight:800}}>{value}</div><div>{label}</div></div>)}</div>
  {error&&<p className="error" role="alert">{error}</p>}
  {!busy&&!error&&<><div style={{overflowX:'auto'}}><table><thead><tr><th>Cliente</th><th>Instalación</th><th>Puesto</th><th>Trabajador</th><th>Asignación</th><th>Inicio</th><th>Fin</th><th>Estado</th></tr></thead><tbody>{shown.map(r=>{const s=slots.get(r.plan_slot_id||''),p=people.get(r.personnel_id||'');return <tr key={r.id}><td>{s?.client}</td><td>{s?.site}</td><td>{s?.post}</td><td>{p?.person_code||'—'} · {p?.full_name||'Sin identificar'}</td><td>{role(r)}</td><td>{fmt(r.starts_at)}</td><td>{fmt(r.ends_at)}</td><td>{r.status}</td></tr>})}{!shown.length&&<tr><td colSpan={8}>No hay turnos para esta vista y filtros.</td></tr>}</tbody></table></div><PlanningGantt rows={filtered} slots={slots} people={people} week={week} setWeek={setWeek}/><PlanningWeeklyGrid rows={filtered} slots={slots} people={people} week={week} setWeek={setWeek}/></>}
  <p><small>*La clasificación se basa en el titular actual del cajón, no en una marca histórica de función. El dashboard no valida asistencia ni cumplimiento laboral. Consulta limitada a 1.000 turnos; si la operación supera ese volumen, debe implementarse paginación.</small></p>
 </div>
}
