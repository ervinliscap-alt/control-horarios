'use client';
import {useEffect,useState} from 'react';
import {createClient} from '../lib/supabase/client';
export default function ReliefPoolManager({guards,plans,role}:{guards:any[],plans:any[],role:string}){
 const can=['ADMIN','OPERACIONES'].includes(role);
 const [catalog,setCatalog]=useState<any>({pools:[],members:[],plans:[]});
 const [pool,setPool]=useState('');const [name,setName]=useState('');const [person,setPerson]=useState('');
 const [plan,setPlan]=useState('');const [pref,setPref]=useState('MIXTO');const [msg,setMsg]=useState('');const [busy,setBusy]=useState(false);
 async function load(){const {data,error}=await createClient().rpc('provica_pool_catalog');if(error)setMsg(error.message);else {setCatalog(data);setPool((p:string)=>p||data.pools?.[0]?.id||'');}}
 useEffect(()=>{load()},[]);
 async function act(action:string,extras:any={}){setBusy(true);setMsg('');const {data,error}=await createClient().rpc('provica_pool_admin',{p_action:action,p_pool:pool||null,p_name:name||null,p_personnel:person||null,p_plan:plan||null,p_preference:pref,...extras});setBusy(false);if(error)setMsg(error.message);else{setMsg('Operación registrada');setName('');await load();}}
 const members=catalog.members?.filter((m:any)=>m.pool_id===pool)||[];
 const linked=catalog.plans?.filter((m:any)=>m.pool_id===pool)||[];
 return <div className="panel"><h3>4. Pools compartidos de sacafrancos</h3><p>Un trabajador puede pertenecer a varios pools y cubrir varios puestos. El motor verifica sus turnos existentes en todos los puestos antes de asignarlo. La preferencia diurna/nocturna se registra para la siguiente fase del optimizador global; todavía no restringe asignaciones automáticamente.</p>
 {can&&<div className="form"><label>Nuevo pool<input placeholder="Ej. Guayaquil Norte" value={name} onChange={e=>setName(e.target.value)}/></label><button disabled={busy||name.trim().length<3} onClick={()=>act('CREATE')}>Crear pool</button></div>}
 <div className="form"><label>Pool<select value={pool} onChange={e=>setPool(e.target.value)}><option value="">Seleccione</option>{(catalog.pools||[]).map((p:any)=><option key={p.id} value={p.id}>{p.name}</option>)}</select></label></div>
 {pool&&<><h4>Personal de relevo</h4>{members.map((m:any)=>{const g=guards.find(g=>g.id===m.personnel_id);return <p key={m.personnel_id}>{g?.person_code||m.personnel_id} · {g?.full_name||'Personal'} — {m.shift_preference} {can&&<button className="small secondary" disabled={busy} onClick={()=>act('REMOVE_MEMBER',{p_personnel:m.personnel_id})}>Retirar del pool</button>}</p>})}
 {can&&<div className="form"><label>Agregar trabajador<select value={person} onChange={e=>setPerson(e.target.value)}><option value="">Seleccione</option>{guards.filter(g=>!members.some((m:any)=>m.personnel_id===g.id)).map(g=><option key={g.id} value={g.id}>{g.person_code} · {g.full_name}</option>)}</select></label><label>Preferencia<select value={pref} onChange={e=>setPref(e.target.value)}><option value="MIXTO">Mixto</option><option value="DIURNO">Diurno</option><option value="NOCTURNO">Nocturno</option></select></label><button disabled={busy||!person} onClick={()=>act('ADD_MEMBER')}>Agregar al pool</button></div>}
 <h4>Planes asociados</h4>{linked.map((l:any)=><p key={l.plan_id}>{plans.find(p=>p.id===l.plan_id)?.guard_posts?.name||l.plan_id} {can&&<button className="small secondary" disabled={busy} onClick={()=>act('UNLINK_PLAN',{p_plan:l.plan_id})}>Desvincular</button>}</p>)}
 {can&&<div className="form"><label>Asociar plan<select value={plan} onChange={e=>setPlan(e.target.value)}><option value="">Seleccione</option>{plans.filter(p=>!linked.some((l:any)=>l.plan_id===p.id)).map(p=><option key={p.id} value={p.id}>{p.guard_posts?.post_code} · {p.guard_posts?.name} · {p.start_date}</option>)}</select></label><button disabled={busy||!plan} onClick={()=>act('LINK_PLAN')}>Asociar</button></div>}
 </>}{msg&&<p role="status">{msg}</p>}
 <p><small>Desvincular un pool no elimina turnos ni asignaciones ya sincronizadas en bolsas por plan. La planificación global multi-puesto con reservas concurrentes y tiempos de traslado queda pendiente de una versión posterior.</small></p></div>;
}
