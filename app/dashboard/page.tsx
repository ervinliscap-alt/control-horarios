import { redirect } from 'next/navigation'
import { createClient } from '../../lib/supabase/server'
import LogoutButton from '../../components/logout-button'

const puestos=[['Agripac','Garita principal','Juan Pérez','Cubierto','ok'],['FV','Acceso norte','Carlos Ruiz','Relevo pendiente','warn'],['Cliente XYZ','Bodega','Sin guardia','Sin cobertura','bad']]

export default async function Dashboard(){
  const supabase=await createClient()
  const {data:{user}}=await supabase.auth.getUser()
  if(!user) redirect('/login')
  const {data:profile}=await supabase.from('profiles').select('full_name,role').eq('id',user.id).maybeSingle()
  return <main className="app-shell">
    <aside><h1>PROVICA</h1><p>Control de Guardias</p><nav>Dashboard<br/>Personal<br/>Clientes<br/>Instalaciones<br/>Puestos<br/>Turnos<br/>Planificación<br/>Asistencia<br/>Alertas<br/>Reportes</nav></aside>
    <section>
      <header><div><small>CENTRO DE OPERACIONES</small><h2>Resumen de cobertura</h2><p className="userline">{profile?.full_name||user.email} · {profile?.role||'USUARIO'}</p></div><LogoutButton/></header>
      <div className="cards"><article><b>87</b><span>Puestos activos</span></article><article><b>84</b><span>Cubiertos</span></article><article><b>2</b><span>Relevo pendiente</span></article><article><b>1</b><span>Sin cobertura</span></article></div>
      <div className="panel"><h3>Estado de puestos</h3><table><thead><tr><th>Cliente</th><th>Puesto</th><th>Guardia</th><th>Estado</th></tr></thead><tbody>{puestos.map((p,i)=><tr key={i}><td>{p[0]}</td><td>{p[1]}</td><td>{p[2]}</td><td><span className={'status '+p[4]}>{p[3]}</span></td></tr>)}</tbody></table></div>
      <div className="panel"><h3>V2 · Autenticación activa</h3><p>La sesión se valida con Supabase. El siguiente incremento conectará los indicadores a datos operativos reales.</p></div>
    </section>
  </main>
}
