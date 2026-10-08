import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { api, fmtDate } from '../api.js'
import { statusLabel } from './TechHome.jsx'

const Stat = ({ label, value, sub }) => <div className="stat"><div className="v">{value ?? '—'}</div><div className="l">{label}</div>{sub && <div className="s">{sub}</div>}</div>

export default function AdminDashboard() {
  const [d, setD] = useState(null)
  const [labs, setLabs] = useState(null)
  const [err, setErr] = useState('')
  const load = () => {
    api('/api/admin/dashboard').then(setD).catch(e => setErr(e.message))
    api('/api/admin/labs').then(setLabs).catch(() => {})
  }
  useEffect(() => { load(); const t = setInterval(load, 5000); return () => clearInterval(t) }, [])
  const terminate = async a => {
    if (!window.confirm(`Terminate attempt #${a.id} of ${a.username}? It will not be graded.`)) return
    try { await api(`/api/admin/attempts/${a.id}/terminate`, { method: 'POST' }); load() } catch (e) { setErr(e.message) }
  }
  if (!d) return <p className="muted">{err || 'Loading…'}</p>
  return (
    <>
      <section className="card">
        <h1>Dashboard</h1>
        {err && <p className="error">{err}</p>}
        <div className="stats">
          <Stat label="Active labs" value={`${d.active}/${d.max_active}`} />
          <Stat label="Resource weight" value={`${d.weight}/${d.max_weight}`} />
          <Stat label="Queued" value={d.queued} />
          <Stat label="Completed tests" value={d.completed} sub={`${d.passed} passed`} />
          <Stat label={<Link to="/admin/attempts?result=not_passed">Failed tests</Link>} value={d.not_passed} sub={`${d.errors} lab errors`} />
          <Stat label="Average score" value={d.average_score != null ? `${d.average_score}%` : '—'} />
          <Stat label="Technicians" value={d.technicians} />
          <Stat label="Scenarios" value={d.scenarios} sub={`${d.scenarios_enabled} enabled`} />
        </div>
      </section>
      <section className="card">
        <h2>Active and queued tests</h2>
        <table>
          <thead><tr><th>#</th><th>Technician</th><th>Scenario</th><th>Status</th><th>Weight</th><th>Started</th><th>Deadline</th><th></th></tr></thead>
          <tbody>
            {labs?.labs.map(a => (
              <tr key={a.id}><td><Link to={`/admin/attempts/${a.id}`}>{a.id}</Link></td><td>{a.username}</td><td>{a.scenario_name}</td>
                <td>{statusLabel[a.status]}{a.status === 'queued' && a.queue_position ? ` (#${a.queue_position})` : ''}</td><td>{a.resource_weight}</td>
                <td>{fmtDate(a.started_at)}</td><td>{fmtDate(a.deadline_at)}</td>
                <td><button className="small danger" onClick={() => terminate(a)}>Terminate</button></td></tr>
            ))}
            {!labs?.labs.length && <tr><td colSpan={8} className="muted">Nothing running.</td></tr>}
          </tbody>
        </table>
      </section>
    </>
  )
}
