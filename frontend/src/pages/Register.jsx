import { useState } from 'react'
import { Link, Navigate } from 'react-router-dom'
import { useAuth } from '../auth.jsx'

export default function Register() {
  const { user, register } = useAuth()
  const [f, setF] = useState({ username: '', email: '', full_name: '', password: '' })
  const [err, setErr] = useState('')
  if (user) return <Navigate to="/" replace />
  const set = k => e => setF({ ...f, [k]: e.target.value })
  const submit = async e => {
    e.preventDefault(); setErr('')
    try { await register({ ...f, email: f.email || null }) } catch (x) { setErr(x.message) }
  }
  return (
    <form className="card narrow" onSubmit={submit}>
      <h1>Create a technician account</h1>
      <label>Username<input autoFocus value={f.username} onChange={set('username')} required pattern="[A-Za-z0-9_.\-]{3,64}" /></label>
      <label>Full name<input value={f.full_name} onChange={set('full_name')} /></label>
      <label>E-mail (optional)<input type="email" value={f.email} onChange={set('email')} /></label>
      <label>Password (at least 10 characters)<input type="password" value={f.password} onChange={set('password')} required minLength={10} /></label>
      {err && <p className="error">{err}</p>}
      <button>Create account</button>
      <p className="muted">Already registered? <Link to="/login">Log in</Link></p>
    </form>
  )
}
