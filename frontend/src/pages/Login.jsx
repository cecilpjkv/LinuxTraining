import { useState } from 'react'
import { Link, Navigate } from 'react-router-dom'
import { useAuth } from '../auth.jsx'

// Technicians start with their name and e-mail address (plus the shared test password when one is set);
// administrators use /admin/login.
export default function Login() {
  const { user, enter, needPw } = useAuth()
  const [f, setF] = useState({ full_name: '', email: '', password: '' })
  const [err, setErr] = useState('')
  const [busy, setBusy] = useState(false)
  if (user) return <Navigate to="/" replace />
  const submit = async e => {
    e.preventDefault(); setErr(''); setBusy(true)
    try { await enter(f.full_name, f.email, f.password) } catch (x) { setErr(x.message) } finally { setBusy(false) }
  }
  return (
    <form className="card narrow" onSubmit={submit}>
      <h1>Linux troubleshooting training</h1>
      <p className="muted">Enter your name and e-mail address to start. Use the same address next time to see your earlier results.</p>
      <label>Full name<input autoFocus value={f.full_name} onChange={e => setF({ ...f, full_name: e.target.value })} required minLength={2} /></label>
      <label>E-mail address<input type="email" value={f.email} onChange={e => setF({ ...f, email: e.target.value })} required /></label>
      {needPw && <label>Test password<input type="password" autoComplete="off" value={f.password} onChange={e => setF({ ...f, password: e.target.value })} required /></label>}
      {err && <p className="error">{err}</p>}
      <button disabled={busy}>Continue</button>
      <p className="muted small"><Link to="/admin/login">Administrator login</Link></p>
    </form>
  )
}
