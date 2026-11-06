'use client';
import {useMemo,useState} from 'react';

type Shift={id:string;starts_at:string;ends_at:string;status:string;personnel_id:string|null;plan_slot_id:string|null};
type SlotInfo={post:string;postId:string;client:string;site:string;primary:string|null};
type Person={id:string;person_code:string;full_name:string};
const TZ='America/Guayaquil';
const localDate=(d:Date)=>new Intl.DateTimeFormat('en-CA',{timeZone:TZ,year:'numeric',month:'2-digit',day:'2-digit'}).format(d);
const localHour=(d:Date)=>new Intl.DateTimeFormat('en-GB',{timeZone:TZ,hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).format(d);
const dayLabel=(d:Date)=>new Intl.DateTimeFormat('es-EC',{timeZone:TZ,weekday:'short',day:'2-digit',month:'2-digit'}).format(d);
const fromLocal=(date:string,hour=0)=>new Date(`${date}T${String(hour).padStart(2,'0')}:00:00-05:00`);
const addDays=(date:string,days:number)=>{const d=fromLocal(date);d.setUTCDate(d.getUTCDate()+days);return localDate(d)};
const monday=(date:string)=>{const d=fromLocal(date);const weekday=d.getUTCDay();return addDays(date,-((weekday+6)%7))};
export default function PlanningWeeklyGrid({rows,slots,people,week,setWeek}:{rows:Shift[];slots:Map<string,SlotInfo>;people:Map<string,Person>;week:string;setWeek:(v:string)=>void}){
 const [group,setGroup]=useState<'post'|'worker'>('post');
 const start=monday(week),days=Array.from({length:7},(_,i)=>addDays(start,i));
 const grouped=useMemo(()=>{
  const map=new Map<string,{label:string;shifts:Shift[]}>();
  for(const r of rows){if(r.status==='CANCELADO')continue;const slot=slots.get(r.plan_slot_id||'');if(!slot)continue;
   const id=group==='post'?slot.postId:(r.personnel_id||'unassigned');
   const person=people.get(r.personnel_id||'');const label=group==='post'?`${slot.post} · ${slot.site}`:`${person?.person_code||'—'} · ${person?.full_name||'Sin identificar'}`;
   if(!map.has(id))map.set(id,{label,shifts:[]});map.get(id)!.shifts.push(r);
  }
  return [...map.values()].sort((a,b)=>a.label.localeCompare(b.label));
 },[rows,slots,people,group]);
 return <section style={{marginTop:26}}><h3>Planificación semanal · 7 días</h3>
  <p>Vista tipo calendario por puesto o trabajador. Los turnos nocturnos se muestran en ambos días cuando cruzan la medianoche.</p>
  <div className="form"><label>Semana que contiene<input type="date" value={week} onChange={e=>setWeek(e.target.value)}/></label><label>Agrupar por<select value={group} onChange={e=>setGroup(e.target.value as 'post'|'worker')}><option value="post">Puesto</option><option value="worker">Trabajador</option></select></label><button type="button" onClick={()=>setWeek(addDays(start,-7))}>← Semana anterior</button><button type="button" onClick={()=>setWeek(addDays(start,7))}>Semana siguiente →</button></div>
  <div style={{overflowX:'auto',border:'1px solid #dfe4ea',borderRadius:12,marginTop:14}}><table style={{width:'100%',minWidth:920,borderCollapse:'collapse'}}><thead><tr><th style={{minWidth:185}}> {group==='post'?'Puesto / instalación':'Trabajador'}</th>{days.map(d=><th key={d} style={{minWidth:108}}>{dayLabel(fromLocal(d))}</th>)}</tr></thead><tbody>{grouped.map(g=><tr key={g.label}><th style={{textAlign:'left',verticalAlign:'top',fontWeight:650}}>{g.label}</th>{days.map(day=>{const ds=fromLocal(day),de=fromLocal(addDays(day,1));const cell=g.shifts.filter(r=>Date.parse(r.starts_at)<de.getTime()&&Date.parse(r.ends_at)>ds.getTime());return <td key={day} style={{verticalAlign:'top',padding:6,background:cell.length?'#fffaf5':'#fff'}}>{cell.map(r=>{const slot=slots.get(r.plan_slot_id||'');const person=people.get(r.personnel_id||'');const titular=slot?.primary===r.personnel_id;const from=new Date(Math.max(Date.parse(r.starts_at),ds.getTime()));const to=new Date(Math.min(Date.parse(r.ends_at),de.getTime()));return <div key={r.id} title={`${new Date(r.starts_at).toLocaleString('es-EC',{timeZone:TZ})} → ${new Date(r.ends_at).toLocaleString('es-EC',{timeZone:TZ})}`} style={{padding:'7px 8px',borderRadius:7,background:titular?'#edf4ff':'#fff0df',borderLeft:`3px solid ${titular?'#2d69bb':'#e96d10'}`,marginBottom:5,fontSize:12}}><strong>{localHour(from)}–{localHour(to)}</strong><br/>{group==='post'?`${person?.person_code||'—'} ${person?.full_name||''}`:slot?.post}<br/><small>{titular?'Titular':'Relevo*'}</small></div>})}</td>})}</tr>)}{!grouped.length&&<tr><td colSpan={8}>No se encontraron turnos para la semana y los filtros seleccionados.</td></tr>}</tbody></table></div>
  <p><small>Azul: titular actual del cajón. Naranja: asignación distinta del titular (no necesariamente integrante de un pool). La vista refleja programación, no asistencia confirmada.</small></p>
 </section>
}
