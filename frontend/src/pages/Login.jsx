import { useState } from 'react'
import { Link, Navigate } from 'react-router-dom'
import { useAuth } from '../auth.jsx'

export default function Login() {
  const { user, login } = useAuth()
  const [f, setF] = useState({ username: '', password: '' })
  const [err, setErr] = useState('')
  const [busy, setBusy] = useState(false)
  if (user) return <Navigate to="/" replace />
  const submit = async e => {
    e.preventDefault(); setErr(''); setBusy(true)
    try { await login(f.username, f.password) } catch (x) { setErr(x.message) } finally { setBusy(false) }
  }
  return (
    <form className="card narrow" onSubmit={submit}>
      <h1>Log in</h1>
      <label>Username or e-mail<input autoFocus value={f.username} onChange={e => setF({ ...f, username: e.target.value })} required /></label>
      <label>Password<input type="password" value={f.password} onChange={e => setF({ ...f, password: e.target.value })} required /></label>
      {err && <p className="error">{err}</p>}
      <button disabled={busy}>Log in</button>
      <p className="muted">New technician? <Link to="/register">Create an account</Link></p>
    </form>
  )
}
