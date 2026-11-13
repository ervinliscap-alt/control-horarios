'use client';
import {useMemo,useState} from 'react';

type Shift={id:string;starts_at:string;ends_at:string;status:string;personnel_id:string|null;plan_slot_id:string|null};
type SlotInfo={post:string;postId:string;client:string;site:string;primary:string|null};
type Person={id:string;person_code:string;full_name:string};
const TZ='America/Guayaquil';
const localDate=(d:Date)=>new Intl.DateTimeFormat('en-CA',{timeZone:TZ,year:'numeric',month:'2-digit',day:'2-digit'}).format(d);
const fromLocal=(date:string)=>new Date(`${date}T00:00:00-05:00`);
const addDays=(date:string,n:number)=>localDate(new Date(fromLocal(date).getTime()+n*86400000));
const monday=(date:string)=>addDays(date,-((fromLocal(date).getUTCDay()+6)%7));
const dateLabel=(date:string)=>new Intl.DateTimeFormat('es-EC',{timeZone:TZ,weekday:'short',day:'2-digit',month:'2-digit'}).format(fromLocal(date));
const hhmm=(v:string)=>new Intl.DateTimeFormat('es-EC',{timeZone:TZ,hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).format(new Date(v));
const stamp=(v:string)=>new Intl.DateTimeFormat('es-EC',{timeZone:TZ,dateStyle:'medium',timeStyle:'short'}).format(new Date(v));
const hours=(a:number,b:number)=>Math.round((b-a)/360000)/10;

export default function PlanningGantt({rows,slots,people,week,setWeek}:{rows:Shift[];slots:Map<string,SlotInfo>;people:Map<string,Person>;week:string;setWeek:(v:string)=>void}){
 const [scale,setScale]=useState<'week'|'day'>('week');
 const [selectedDay,setSelectedDay]=useState('');
 const [zoom,setZoom]=useState(125);
 const [selected,setSelected]=useState<Shift|null>(null);
 const start=monday(week);const days=Array.from({length:7},(_,i)=>addDays(start,i));
 const day=selectedDay&&days.includes(selectedDay)?selectedDay:start;
 const begin=fromLocal(scale==='week'?start:day).getTime();
 const end=fromLocal(addDays(scale==='week'?start:day,scale==='week'?7:1)).getTime();
 const groups=useMemo(()=>{
  const map=new Map<string,{key:string;label:string;slot:SlotInfo;items:Shift[]}>();
  for(const r of rows){if(r.status==='CANCELADO'||!r.plan_slot_id)continue;const slot=slots.get(r.plan_slot_id);if(!slot)continue;
   if(!map.has(r.plan_slot_id))map.set(r.plan_slot_id,{key:r.plan_slot_id,label:`${slot.post} · ${slot.site}`,slot,items:[]});
   map.get(r.plan_slot_id)!.items.push(r);
  }
  return [...map.values()].sort((a,b)=>a.label.localeCompare(b.label)||a.key.localeCompare(b.key));
 },[rows,slots]);
 const activeGroups=groups.filter(g=>g.items.some(r=>Date.parse(r.starts_at)<end&&Date.parse(r.ends_at)>begin));
 const person=(r:Shift)=>people.get(r.personnel_id||'');
 const isPrimary=(r:Shift)=>slots.get(r.plan_slot_id||'')?.primary===r.personnel_id;
 const background=(r:Shift)=>isPrimary(r)?'#dbeafe':'#ffedd5';
 const accent=(r:Shift)=>isPrimary(r)?'#2563eb':'#ea580c';
 const pick=(r:Shift)=><button type="button" onClick={()=>setSelected(r)} title={`${person(r)?.person_code||'—'} · ${person(r)?.full_name||'Sin identificar'} · ${stamp(r.starts_at)} a ${stamp(r.ends_at)}`} style={{cursor:'pointer',width:'100%',textAlign:'left',border:`1px solid ${accent(r)}`,borderLeft:`5px solid ${accent(r)}`,background:background(r),color:'#0f172a',borderRadius:7,padding:'7px 8px',minHeight:55,display:'flex',flexDirection:'column',gap:2}}><strong style={{fontSize:12,whiteSpace:'normal',overflowWrap:'anywhere'}}>{person(r)?.person_code||'—'} · {person(r)?.full_name||'Sin identificar'}</strong><span style={{fontSize:11}}>{hhmm(r.starts_at)}–{hhmm(r.ends_at)} · {isPrimary(r)?'Titular':'Relevo'}</span></button>;
 return <section style={{marginTop:28}}><h3>Gantt de cobertura · {scale==='week'?'semana':'24 horas'}</h3><p>Una fila por cajón. Selecciona cualquier turno para ver el nombre completo y sus detalles. Azul: titular actual; naranja: sustitución.</p>
 <div className="form"><label>Semana que contiene<input type="date" value={week} onChange={e=>{setWeek(e.target.value);setSelectedDay('');setSelected(null)}}/></label><label>Escala<select value={scale} onChange={e=>setScale(e.target.value as 'week'|'day')}><option value="week">Semana · 7 días</option><option value="day">Día · 24 horas</option></select></label>{scale==='day'&&<label>Día<select value={day} onChange={e=>setSelectedDay(e.target.value)}>{days.map(d=><option key={d} value={d}>{dateLabel(d)}</option>)}</select></label>}<label>Zoom<select value={zoom} onChange={e=>setZoom(Number(e.target.value))}><option value={100}>100 %</option><option value={125}>125 %</option><option value={150}>150 %</option></select></label><button type="button" onClick={()=>{setWeek(addDays(start,-7));setSelectedDay('');setSelected(null)}}>← Anterior</button><button type="button" onClick={()=>{setWeek(addDays(start,7));setSelectedDay('');setSelected(null)}}>Siguiente →</button></div>
 <div style={{overflowX:'auto',border:'1px solid #cbd5e1',borderRadius:12,marginTop:14}}>
 {scale==='week'?<div style={{minWidth:245+7*Math.round(205*zoom/100)}}>
 <div style={{display:'grid',gridTemplateColumns:`245px repeat(7,minmax(0,1fr))`,background:'#f1f5f9',position:'sticky',top:0,zIndex:3}}><strong style={{padding:12}}>Puesto / cajón</strong>{days.map(d=><strong key={d} style={{padding:'12px 8px',borderLeft:'1px solid #cbd5e1',fontSize:12}}>{dateLabel(d)}</strong>)}</div>
 {activeGroups.map((g,idx)=><div key={g.key} style={{display:'grid',gridTemplateColumns:'245px repeat(7,minmax(0,1fr))',borderTop:'1px solid #cbd5e1',minHeight:96}}><div style={{padding:12,background:'#f8fafc'}}><strong style={{display:'block',fontSize:13}}>{g.label}</strong><span style={{fontSize:11,color:'#475569'}}>Cajón {idx+1} · Titular: {people.get(g.slot.primary||'')?.full_name||'No asignado'}</span></div>{days.map(d=>{const a=fromLocal(d).getTime(),b=fromLocal(addDays(d,1)).getTime();const items=g.items.filter(r=>Date.parse(r.starts_at)<b&&Date.parse(r.ends_at)>a).sort((x,y)=>Date.parse(x.starts_at)-Date.parse(y.starts_at));return <div key={d} style={{padding:6,borderLeft:'1px solid #e2e8f0',display:'flex',flexDirection:'column',gap:6,background:items.length?'#fff':'#f8fafc'}}>{items.map(r=><div key={r.id}>{pick(r)}<div style={{height:5,marginTop:3,background:'#e2e8f0',borderRadius:4,position:'relative'}}><div style={{position:'absolute',height:'100%',borderRadius:4,background:accent(r),left:`${(Math.max(a,Date.parse(r.starts_at))-a)/(b-a)*100}%`,width:`${(Math.min(b,Date.parse(r.ends_at))-Math.max(a,Date.parse(r.starts_at)))/(b-a)*100}%`}}/></div></div>)}</div>})}</div>)}
 </div>:<div style={{minWidth:245+Math.round(1050*zoom/100)}}><div style={{display:'grid',gridTemplateColumns:'245px 1fr',background:'#f1f5f9'}}><strong style={{padding:12}}>Puesto / cajón</strong><div style={{display:'grid',gridTemplateColumns:'repeat(24,minmax(0,1fr))'}}>{Array.from({length:24},(_,i)=><span key={i} style={{borderLeft:'1px solid #cbd5e1',padding:'12px 2px',fontSize:11,fontWeight:700}}>{String(i).padStart(2,'0')}:00</span>)}</div></div>{activeGroups.map((g,idx)=>{const a=fromLocal(day).getTime(),b=fromLocal(addDays(day,1)).getTime();const items=g.items.filter(r=>Date.parse(r.starts_at)<b&&Date.parse(r.ends_at)>a).sort((x,y)=>Date.parse(x.starts_at)-Date.parse(y.starts_at));return <div key={g.key} style={{display:'grid',gridTemplateColumns:'245px 1fr',borderTop:'1px solid #cbd5e1',minHeight:Math.max(96,items.length*66+16)}}><div style={{padding:12,background:'#f8fafc'}}><strong style={{display:'block',fontSize:13}}>{g.label}</strong><span style={{fontSize:11,color:'#475569'}}>Cajón {idx+1} · Titular: {people.get(g.slot.primary||'')?.full_name||'No asignado'}</span></div><div style={{position:'relative',background:'repeating-linear-gradient(to right,#fff 0,#fff calc(4.1666667% - 1px),#e2e8f0 calc(4.1666667% - 1px),#e2e8f0 4.1666667%)'}}>{items.map((r,i)=>{const left=(Math.max(a,Date.parse(r.starts_at))-a)/(b-a)*100;const width=(Math.min(b,Date.parse(r.ends_at))-Math.max(a,Date.parse(r.starts_at)))/(b-a)*100;return <div key={r.id} style={{position:'absolute',left:`${left}%`,width:`${width}%`,top:8+i*66,minWidth:0}}>{pick(r)}</div>})}</div></div>})}</div>}
 {!activeGroups.length&&<div style={{padding:18}}>No hay turnos en la ventana consultada para los filtros seleccionados.</div>}
 </div>
 {selected&&<div role="dialog" aria-label="Detalle del turno" style={{marginTop:14,padding:16,border:'1px solid #cbd5e1',borderRadius:12,background:'#f8fafc'}}><div style={{display:'flex',justifyContent:'space-between',alignItems:'center',gap:12}}><h4 style={{margin:0}}>Detalle del turno</h4><button type="button" onClick={()=>setSelected(null)}>Cerrar</button></div><p><strong>Trabajador:</strong> {person(selected)?.person_code||'—'} · {person(selected)?.full_name||'Sin identificar'}<br/><strong>Cliente:</strong> {slots.get(selected.plan_slot_id||'')?.client||'—'}<br/><strong>Instalación:</strong> {slots.get(selected.plan_slot_id||'')?.site||'—'}<br/><strong>Puesto:</strong> {slots.get(selected.plan_slot_id||'')?.post||'—'}<br/><strong>Asignación:</strong> {isPrimary(selected)?'Titular':'Relevo / sustitución'}<br/><strong>Inicio:</strong> {stamp(selected.starts_at)}<br/><strong>Fin:</strong> {stamp(selected.ends_at)}<br/><strong>Duración:</strong> {hours(Date.parse(selected.starts_at),Date.parse(selected.ends_at))} horas<br/><strong>Estado:</strong> {selected.status}</p></div>}
 <p><small>Los turnos nocturnos aparecen en ambos días cuando cruzan medianoche. «Cajón» es una agrupación visual por identificador de cajón; la numeración mostrada no necesariamente coincide con el orden configurado. Esta vista refleja programación, no asistencia confirmada ni cumplimiento laboral. Los espacios vacíos no se clasifican automáticamente como descubiertos.</small></p></section>;
}
