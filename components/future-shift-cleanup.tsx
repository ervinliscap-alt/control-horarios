'use client';
import {useState} from 'react';
import {createClient} from '../lib/supabase/client';
export default function FutureShiftCleanup({plans,role}:{plans:any[],role:string}){
 const [plan,setPlan]=useState(plans[0]?.id||'');const [confirm,setConfirm]=useState('');const [msg,setMsg]=useState('');const [busy,setBusy]=useState(false);
 if(role!=='ADMIN')return null;
 async function cleanup(){if(confirm!=='BORRAR FUTUROS')return;setBusy(true);const {data,error}=await createClient().rpc('provica_cleanup_future_test_shifts',{p_plan:plan,p_confirm:confirm,p_note:'Reinicio controlado de turnos de prueba V3.4.2'});setBusy(false);setMsg(error?error.message:`Eliminados ${data?.deleted||0} turnos futuros. Registro de auditoría guardado.`);setConfirm('');}
 return <div className="panel"><h3>5. Limpieza controlada de turnos futuros (ADMIN)</h3><p>Solo elimina turnos <b>PROGRAMADO</b> que todavía no comenzaron y pertenecen al plan elegido. Los turnos iniciados o históricos permanecen intactos. Si existen referencias operativas protegidas por claves foráneas, la transacción se detiene.</p><div className="form"><label>Plan<select value={plan} onChange={e=>setPlan(e.target.value)}>{plans.map(p=><option key={p.id} value={p.id}>{p.guard_posts?.post_code} · {p.guard_posts?.name} · {p.start_date} → {p.end_date}</option>)}</select></label><label>Escribe BORRAR FUTUROS<input value={confirm} onChange={e=>setConfirm(e.target.value)} placeholder="BORRAR FUTUROS"/></label><button className="danger" disabled={busy||!plan||confirm!=='BORRAR FUTUROS'} onClick={cleanup}>Eliminar futuros del plan</button></div>{msg&&<p role="status">{msg}</p>}</div>;
}
