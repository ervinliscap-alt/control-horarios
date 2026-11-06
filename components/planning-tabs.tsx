'use client';
import {useState, type ReactNode} from 'react';

type Tab={id:string;label:string;description:string;content:ReactNode};
export default function PlanningTabs({tabs}:{tabs:Tab[]}){
 const [active,setActive]=useState('titulares');
 const selected=tabs.find(t=>t.id===active)||tabs[0];
 return <div>
  <div role="tablist" aria-label="Secciones de planificación" style={{display:'flex',flexWrap:'wrap',gap:8,marginBottom:18,padding:10,background:'#f5f6f8',borderRadius:12}}>
   {tabs.map(t=><button key={t.id} type="button" role="tab" aria-selected={selected.id===t.id} aria-controls={'planning-panel-'+t.id} id={'planning-tab-'+t.id} onClick={()=>setActive(t.id)} style={{padding:'11px 15px',borderRadius:9,border:selected.id===t.id?'2px solid #e96d10':'1px solid #d8dde3',background:selected.id===t.id?'#fff0e4':'#fff',color:'#20262d',fontWeight:selected.id===t.id?700:500,cursor:'pointer'}}>{t.label}</button>)}
  </div>
  <div role="tabpanel" id={'planning-panel-'+selected.id} aria-labelledby={'planning-tab-'+selected.id}>
   <p style={{margin:'0 0 12px',color:'#52606d'}}>{selected.description}</p>
   {selected.content}
  </div>
 </div>;
}
