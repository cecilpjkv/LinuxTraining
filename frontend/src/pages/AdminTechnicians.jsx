import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { api, fmtDate } from '../api.js'

export default function AdminTechnicians() {
  const [rows, setRows] = useState([])
  useEffect(() => { api('/api/admin/technicians').then(setRows).catch(() => {}) }, [])
  return (
    <section className="card">
      <h1>Technicians</h1>
      <table>
        <thead><tr><th>Username</th><th>Name</th><th>Attempts</th><th>Graded</th><th>Passed</th><th>Average score</th><th>Last login</th></tr></thead>
        <tbody>
          {rows.map(u => (
            <tr key={u.id} className={u.active ? '' : 'dim'}>
              <td><Link to={`/admin/attempts?user_id=${u.id}`}>{u.username}</Link></td><td>{u.full_name}</td><td>{u.attempts}</td>
              <td>{u.graded}</td><td>{u.passed}</td><td>{u.average_score != null ? `${u.average_score}%` : '—'}</td><td>{fmtDate(u.last_login_at)}</td>
            </tr>
          ))}
          {!rows.length && <tr><td colSpan={7} className="muted">No technicians yet.</td></tr>}
        </tbody>
      </table>
    </section>
  )
}
