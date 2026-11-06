'use client';
import {useMemo,useState} from 'react';

type Shift={id:string;starts_at:string;ends_at:string;status:string;personnel_id:string|null;plan_slot_id:string|null};
type SlotInfo={post:string;postId:string;client:string;site:string;primary:string|null};
type Person={id:string;person_code:string;full_name:string};
const TZ='America/Guayaquil';
const localDate=(d:Date)=>new Intl.DateTimeFormat('en-CA',{timeZone:TZ,year:'numeric',month:'2-digit',day:'2-digit'}).format(d);
const fromLocal=(date:string)=>new Date(`${date}T00:00:00-05:00`);
const addDays=(date:string,n:number)=>{const d=fromLocal(date);d.setUTCDate(d.getUTCDate()+n);return localDate(d)};
const monday=(date:string)=>addDays(date,-((fromLocal(date).getUTCDay()+6)%7));
const dateLabel=(date:string)=>new Intl.DateTimeFormat('es-EC',{timeZone:TZ,weekday:'short',day:'2-digit',month:'2-digit'}).format(fromLocal(date));
const hhmm=(v:string)=>new Intl.DateTimeFormat('es-EC',{timeZone:TZ,hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).format(new Date(v));
export default function PlanningGantt({rows,slots,people,week,setWeek}:{rows:Shift[];slots:Map<string,SlotInfo>;people:Map<string,Person>;week:string;setWeek:(v:string)=>void}){
 const [scale,setScale]=useState<'week'|'day'>('week');
 const [selectedDay,setSelectedDay]=useState('');
 const start=monday(week);const date=selectedDay&&selectedDay>=start&&selectedDay<addDays(start,7)?selectedDay:start;
 const startMs=fromLocal(scale==='week'?start:date).getTime();const endMs=fromLocal(addDays(scale==='week'?start:date,scale==='week'?7:1)).getTime();
 const groups=useMemo(()=>{const m=new Map<string,{label:string;items:Shift[]}>();for(const r of rows){if(r.status==='CANCELADO')continue;const slot=slots.get(r.plan_slot_id||'');if(!slot)continue;const k=slot.postId;if(!m.has(k))m.set(k,{label:`${slot.post} · ${slot.site}`,items:[]});m.get(k)!.items.push(r)}return [...m.values()].sort((a,b)=>a.label.localeCompare(b.label))},[rows,slots]);
 const ticks=scale==='week'?Array.from({length:8},(_,i)=>addDays(start,i)):Array.from({length:25},(_,i)=>String(i).padStart(2,'0')+':00');
 const range=endMs-startMs;
 return <section style={{marginTop:28}}><h3>Gantt de cobertura · {scale==='week'?'semana':'24 horas'}</h3><p>Turnos programados por puesto. Azul: titular actual; naranja: sustitución. Los intervalos vacíos no se clasifican automáticamente como descubiertos.</p>
 <div className="form"><label>Semana que contiene<input type="date" value={week} onChange={e=>{setWeek(e.target.value);setSelectedDay('')}}/></label><label>Escala<select value={scale} onChange={e=>setScale(e.target.value as 'week'|'day')}><option value="week">Semana</option><option value="day">Día · 24 horas</option></select></label>{scale==='day'&&<label>Día<select value={date} onChange={e=>setSelectedDay(e.target.value)}>{Array.from({length:7},(_,i)=>addDays(start,i)).map(d=><option key={d} value={d}>{dateLabel(d)}</option>)}</select></label>}<button type="button" onClick={()=>{setWeek(addDays(start,-7));setSelectedDay('')}}>← Anterior</button><button type="button" onClick={()=>{setWeek(addDays(start,7));setSelectedDay('')}}>Siguiente →</button></div>
 <div style={{overflowX:'auto',border:'1px solid #e2e8f0',borderRadius:12,marginTop:14}}><div style={{minWidth:scale==='week'?1080:980}}>
 <div style={{display:'grid',gridTemplateColumns:'235px 1fr',background:'#f8fafc',borderBottom:'1px solid #dbe3eb'}}><strong style={{padding:12}}>Puesto / instalación</strong><div style={{display:'flex',position:'relative',height:42}}>{ticks.slice(0,-1).map((t,i)=><div key={i} style={{width:`${100/(ticks.length-1)}%`,borderLeft:'1px solid #dbe3eb',padding:'11px 3px',fontSize:11,fontWeight:700}}>{scale==='week'?dateLabel(t):t}</div>)}</div></div>
 {groups.map(g=><div key={g.label} style={{display:'grid',gridTemplateColumns:'235px 1fr',borderBottom:'1px solid #e8edf2',minHeight:72}}><div style={{padding:12,fontSize:12,fontWeight:650}}>{g.label}</div><div style={{position:'relative',minHeight:72,background:'repeating-linear-gradient(to right,#fff 0,#fff calc(14.2857% - 1px),#e8edf2 calc(14.2857% - 1px),#e8edf2 14.2857%)'}}>{g.items.filter(r=>Date.parse(r.starts_at)<endMs&&Date.parse(r.ends_at)>startMs).map((r,i)=>{const a=Math.max(startMs,Date.parse(r.starts_at)),b=Math.min(endMs,Date.parse(r.ends_at));const slot=slots.get(r.plan_slot_id||'');const p=people.get(r.personnel_id||'');const titular=slot?.primary===r.personnel_id;const left=(a-startMs)/range*100,width=Math.max((b-a)/range*100,.25);const tooltip=`${p?.person_code||'—'} · ${p?.full_name||'Sin identificar'}\n${slot?.post}\n${hhmm(r.starts_at)} → ${hhmm(r.ends_at)}\n${titular?'Titular':'Relevo / sustitución'}`;return <div key={r.id} title={tooltip} style={{position:'absolute',left:`${left}%`,width:`${width}%`,top:6+(i%3)*21,height:19,borderRadius:4,background:titular?'#2563eb':'#ea580c',color:'#fff',fontSize:10,padding:'2px 4px',whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis',zIndex:2}}>{width>5?`${p?.person_code||'—'} ${hhmm(r.starts_at)}`:''}</div>})}</div></div>)}
 {!groups.length&&<div style={{padding:18}}>No hay turnos en la ventana consultada para los filtros seleccionados.</div>}
 </div></div><p><small>Los segmentos se recortan al inicio y final de la ventana, sin alterar los turnos originales. Esta visualización no valida asistencia, traslados ni cumplimiento laboral; la cobertura contratada requiere un análisis adicional.</small></p></section>
}
