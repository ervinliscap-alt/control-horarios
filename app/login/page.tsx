'use client'
import { FormEvent, useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '../../lib/supabase/client'

export default function LoginPage() {
  const [email,setEmail]=useState('')
  const [password,setPassword]=useState('')
  const [error,setError]=useState('')
  const [loading,setLoading]=useState(false)
  const router=useRouter()

  async function login(e:FormEvent){
    e.preventDefault(); setError(''); setLoading(true)
    const supabase=createClient()
    const {error}=await supabase.auth.signInWithPassword({email,password})
    setLoading(false)
    if(error){setError('Correo o contraseña incorrectos.');return}
    router.replace('/dashboard'); router.refresh()
  }

  return <main className="login-shell">
    <form className="login-card" onSubmit={login}>
      <div className="brand-mark">P</div>
      <h1>PROVICA</h1><p>Control de Guardias</p>
      <label>Correo electrónico</label>
      <input type="email" required value={email} onChange={e=>setEmail(e.target.value)} />
      <label>Contraseña</label>
      <input type="password" required value={password} onChange={e=>setPassword(e.target.value)} />
      {error && <div className="error">{error}</div>}
      <button disabled={loading}>{loading?'Ingresando…':'Ingresar'}</button>
      <small>Acceso exclusivo para personal autorizado.</small>
    </form>
  </main>
}
