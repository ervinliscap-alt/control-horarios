'use client';
import {useEffect,useState} from 'react';
import {createClient} from '../lib/supabase/client';
type Pool={id:string;name:string;active:boolean};
export default function SharedPoolCoordinator({role}:{role:string}){
 const [pools,setPools]=useState<Pool[]>([]),[pool,setPool]=useState('');
 const [data,setData]=useState<any>(null),[error,setError]=useState('');
 const [busy,setBusy]=useState(false),[confirm,setConfirm]=useState('');
 const canGenerate=['ADMIN','OPERACIONES'].includes(role);
 useEffect(()=>{createClient().rpc('provica_pool_catalog').then(({data,error})=>{
  if(error){setError(error.message);return;}
  const items=(data?.pools||[]).filter((p:Pool)=>p.active);
  setPools(items);setPool(items[0]?.id||'');
 })},[]);
 async function run(generate:boolean){
  if(generate&&!window.confirm('¿Confirmas generar todos los turnos futuros de los planes del pool? No se modificarán turnos históricos.'))return;
  setBusy(true);setError('');
  const {data:result,error:err}=await createClient().rpc('provica_shared_pool_schedule',{
   p_pool:pool,p_min_rest_hours:12,p_generate:generate,p_confirm:generate?confirm:null
  });
  setBusy(false);
  if(err){setError(err.message);setData(null);return;}
  setData(result);setConfirm('');
 }
 return <div className="panel"><h3>7. Generación coordinada multipuesto · V3.4.4</h3>
  <p>Vista previa y generación utilizan el mismo algoritmo cronológico. <b>No reemplaza turnos existentes.</b> Solo genera cuando todos los puestos tienen cobertura completa.</p>
  <div className="form"><label>Pool<select value={pool} onChange={e=>{setPool(e.target.value);setData(null);setConfirm('')}}>{pools.map(p=><option key={p.id} value={p.id}>{p.name}</option>)}</select></label>
  <button disabled={!pool||busy} onClick={()=>run(false)}>{busy?'Procesando…':'Vista previa coordinada'}</button></div>
  {error&&<p className="error">{error}</p>}
  {data&&<div style={{marginTop:12,padding:12,border:'1px solid #ddd',borderRadius:8}}>
   <h4>{data.simulation_only?(data.viable?'✓ Vista previa completa':'⚠ Cobertura incompleta'):'✓ Turnos generados y auditados'}</h4>
   <p><b>{data.coverage_percent}%</b> · {data.covered_shifts}/{data.required_shifts} turnos · descubiertos: {data.uncovered_shifts} · descanso: {data.min_rest_hours} h</p>
   {data.shifts_created!==undefined&&<p><b>Turnos creados: {data.shifts_created}</b> · Auditoría: {data.audit_saved?'registrada':'sin confirmar'}</p>}
   <h4>Por puesto</h4><table><thead><tr><th>Puesto</th><th>Cubiertos</th><th>Descubiertos</th></tr></thead><tbody>{(data.plans||[]).map((x:any)=><tr key={x.plan_id}><td>{x.post}</td><td>{x.covered}/{x.required}</td><td>{x.uncovered}</td></tr>)}</tbody></table>
   <h4>Por trabajador</h4><table><thead><tr><th>Código</th><th>Turnos</th><th>Horas</th></tr></thead><tbody>{(data.workers||[]).map((x:any)=><tr key={x.person_code}><td>{x.person_code}</td><td>{x.shifts}</td><td>{x.hours}</td></tr>)}</tbody></table>
   {(data.conflicts||[]).length>0&&<p className="error">Existen {data.conflicts.length} incidencias en la vista previa.</p>}
   <p><small>{data.note} No certifica cumplimiento laboral.</small></p>
   {data.simulation_only&&data.viable&&canGenerate&&<div style={{borderTop:'1px solid #ddd',paddingTop:12}}>
    <p><b>Generación controlada:</b> verifica primero que sean datos de prueba, que no haya asistencias y que los planes no tengan turnos futuros existentes.</p>
    <label>Escribe GENERAR POOL <input value={confirm} onChange={e=>setConfirm(e.target.value)} placeholder="GENERAR POOL" /></label>{' '}
    <button disabled={busy||confirm!=='GENERAR POOL'} onClick={()=>run(true)}>Generar todos los puestos</button>
   </div>}
  </div>}
 </div>;
}
