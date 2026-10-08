import { useEffect, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { api, fmtDate } from '../api.js'
import { ScoreCell, statusLabel } from './TechHome.jsx'

export default function AdminAttempts() {
  const [sp, setSp] = useSearchParams()
  const [data, setData] = useState({ total: 0, items: [] })
  const [users, setUsers] = useState([])
  const [scen, setScen] = useState([])
  const f = Object.fromEntries(sp.entries())
  useEffect(() => {
    api('/api/admin/technicians').then(setUsers).catch(() => {})
    api('/api/admin/scenarios').then(setScen).catch(() => {})
  }, [])
  useEffect(() => {
    const q = new URLSearchParams(Object.entries(f).filter(([, v]) => v)).toString()
    api(`/api/admin/attempts?limit=200&${q}`).then(setData).catch(() => {})
  }, [sp])
  const set = k => e => { const n = new URLSearchParams(sp); e.target.value ? n.set(k, e.target.value) : n.delete(k); setSp(n) }
  return (
    <section className="card">
      <h1>Training attempts ({data.total})</h1>
      <div className="filters">
        <select value={f.result || ''} onChange={set('result')}><option value="">All results</option><option value="passed">Passed</option>
          <option value="not_passed">Failed tests (below pass mark)</option><option value="failed">Lab/grading errors</option></select>
        <select value={f.status || ''} onChange={set('status')}><option value="">All statuses</option>
          {Object.entries(statusLabel).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select>
        <select value={f.user_id || ''} onChange={set('user_id')}><option value="">All technicians</option>
          {users.map(u => <option key={u.id} value={u.id}>{u.username}</option>)}</select>
        <select value={f.scenario_id || ''} onChange={set('scenario_id')}><option value="">All scenarios</option>
          {scen.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}</select>
      </div>
      <table>
        <thead><tr><th>#</th><th>Technician</th><th>Scenario</th><th>Status</th><th>Started</th><th>Commands</th><th>Score</th></tr></thead>
        <tbody>
          {data.items.map(a => (
            <tr key={a.id}><td><Link to={`/admin/attempts/${a.id}`}>{a.id}</Link></td><td>{a.username}</td><td>{a.scenario_name}</td>
              <td>{statusLabel[a.status]}</td><td>{fmtDate(a.started_at || a.created_at)}</td><td>{a.commands}</td><td><ScoreCell a={a} /></td></tr>
          ))}
          {!data.items.length && <tr><td colSpan={7} className="muted">No attempts.</td></tr>}
        </tbody>
      </table>
    </section>
  )
}
