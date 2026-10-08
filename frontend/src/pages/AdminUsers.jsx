import { useEffect, useState } from 'react'
import { api, fmtDate } from '../api.js'
import { useAuth } from '../auth.jsx'

export default function AdminUsers() {
  const { user: me } = useAuth()
  const [users, setUsers] = useState([])
  const [err, setErr] = useState('')
  const load = () => api('/api/admin/users').then(setUsers).catch(e => setErr(e.message))
  useEffect(() => { load() }, [])
  const patch = async (u, body) => {
    setErr('')
    try { await api(`/api/admin/users/${u.id}`, { method: 'PATCH', body }); load() } catch (e) { setErr(e.message) }
  }
  return (
    <section className="card">
      <h1>Users</h1>
      {err && <p className="error">{err}</p>}
      <table>
        <thead><tr><th>Username</th><th>Name</th><th>E-mail</th><th>Role</th><th>Active</th><th>Last login</th><th></th></tr></thead>
        <tbody>
          {users.map(u => (
            <tr key={u.id}>
              <td>{u.username}</td><td>{u.full_name}</td><td>{u.email ?? '—'}</td><td>{u.role}</td>
              <td>{u.active ? 'yes' : 'no'}</td><td>{fmtDate(u.last_login_at)}</td>
              <td className="actions">
                {u.id !== me.id && <>
                  <button className="small" onClick={() => patch(u, { role: u.role === 'admin' ? 'technician' : 'admin' })}>
                    {u.role === 'admin' ? 'Make technician' : 'Make admin'}</button>
                  <button className="small" onClick={() => patch(u, { active: !u.active })}>{u.active ? 'Disable' : 'Enable'}</button>
                </>}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  )
}
