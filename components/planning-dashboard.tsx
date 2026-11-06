'use client';
import {useCallback,useEffect,useMemo,useState} from 'react';
import {createClient} from '../lib/supabase/client';

type Row={id:string;starts_at:string;ends_at:string;status:string;personnel_id:string|null;plan_slot_id:string|null};
const fmt=(s:string)=>new Intl.DateTimeFormat('es-EC',{timeZone:'America/Guayaquil',dateStyle:'short',timeStyle:'short'}).format(new Date(s));
export default function PlanningDashboard({plans,guards}:{plans:any[];guards:any[]}){
 const [rows,setRows]=useState<Row[]>([]),[busy,setBusy]=useState(false),[error,setError]=useState('');
 const [post,setPost]=useState(''),[worker,setWorker]=useState(''),[view,setView]=useState<'current'|'upcoming'|'all'>('current');
 const slots=useMemo(()=>new Map<string,{post:string;plan:string;primary:string|null}>(plans.flatMap(p=>(p.post_plan_slots||[]).map((s:any)=>[s.id,{post:`${p.guard_posts?.post_code||''} · ${p.guard_posts?.name||''}`,plan:p.id,primary:s.primary_personnel_id||null}] as const))),[plans]);
 const people=useMemo(()=>new Map<string,any>(guards.map(g=>[g.id,g])),[guards]);
 const refresh=useCallback(async()=>{
  setBusy(true);setError('');
  const ids=Array.from(slots.keys());if(!ids.length){setRows([]);setBusy(false);return;}
  const start=new Date(Date.now()-36*3600000).toISOString(),end=new Date(Date.now()+35*86400000).toISOString();
  // Consulta limitada a 35 días; no se utiliza como auditoría histórica completa.
  const {data,error}=await createClient().from('shifts').select('id,starts_at,ends_at,status,personnel_id,plan_slot_id').in('plan_slot_id',ids).gte('ends_at',start).lte('starts_at',end).order('starts_at',{ascending:true}).limit(1000);
  setBusy(false);if(error)setError(error.message);else setRows((data||[]) as Row[]);
 },[slots]);
 useEffect(()=>{void refresh()},[refresh]);
 const now=Date.now();
 const relevant=rows.filter(r=>r.status!=='CANCELADO'&&(!post||slots.get(r.plan_slot_id||'')?.plan===post)&&(!worker||r.personnel_id===worker));
 const shown=relevant.filter(r=>view==='all'||(view==='current'?Date.parse(r.starts_at)<=now&&Date.parse(r.ends_at)>now:Date.parse(r.starts_at)>now));
 const current=relevant.filter(r=>Date.parse(r.starts_at)<=now&&Date.parse(r.ends_at)>now);
 const upcoming=relevant.filter(r=>Date.parse(r.starts_at)>now);
 const role=(r:Row)=>slots.get(r.plan_slot_id||'')?.primary===r.personnel_id?'Titular':'Relevo / pool*';
 return <div className="panel"><h3>Dashboard · Personal en servicio</h3><p>Turnos registrados en Supabase. Horarios de Ecuador (UTC−5). El indicador «Relevo / pool» identifica asignaciones distintas del titular del cajón; no acredita por sí solo la pertenencia a un pool específico.</p>
  <div className="form"><label>Puesto<select value={post} onChange={e=>setPost(e.target.value)}><option value="">Todos los puestos</option>{plans.map(p=><option key={p.id} value={p.id}>{p.guard_posts?.post_code} · {p.guard_posts?.name}</option>)}</select></label><label>Trabajador<select value={worker} onChange={e=>setWorker(e.target.value)}><option value="">Todos</option>{guards.map(g=><option key={g.id} value={g.id}>{g.person_code} · {g.full_name}</option>)}</select></label><label>Vista<select value={view} onChange={e=>setView(e.target.value as any)}><option value="current">En turno ahora</option><option value="upcoming">Próximos turnos</option><option value="all">Todos (ventana consultada)</option></select></label><button type="button" disabled={busy} onClick={()=>void refresh()}>{busy?'Actualizando…':'Actualizar'}</button></div>
  <div style={{display:'flex',flexWrap:'wrap',gap:12,margin:'18px 0'}}>{[['En servicio ahora',current.length],['Próximos turnos',upcoming.length],['Turnos consultados',relevant.length]].map(([label,value])=><div key={String(label)} style={{background:'#fff2e7',borderRadius:10,padding:'14px 20px',minWidth:150}}><div style={{fontSize:25,fontWeight:800}}>{value}</div><div>{label}</div></div>)}</div>
  {error&&<p className="error" role="alert">{error}</p>}{!busy&&!error&&<div style={{overflowX:'auto'}}><table><thead><tr><th>Trabajador</th><th>Asignación</th><th>Puesto</th><th>Inicio</th><th>Fin</th><th>Estado</th></tr></thead><tbody>{shown.map(r=><tr key={r.id}><td>{people.get(r.personnel_id||'')?.person_code||'—'} · {people.get(r.personnel_id||'')?.full_name||'Sin identificar'}</td><td>{role(r)}</td><td>{slots.get(r.plan_slot_id||'')?.post||'—'}</td><td>{fmt(r.starts_at)}</td><td>{fmt(r.ends_at)}</td><td>{r.status}</td></tr>)}{shown.length===0&&<tr><td colSpan={6}>No hay turnos para esta vista y los filtros seleccionados.</td></tr>}</tbody></table></div>}
  <p><small>*La clasificación se basa en el titular actual del cajón. Si se modificó después de generar turnos, podría diferir de la función original. El dashboard es informativo, no registra asistencia ni valida presencia física. Se consultan hasta 1.000 turnos en una ventana aproximada de 35 días.</small></p>
 </div>;
}
