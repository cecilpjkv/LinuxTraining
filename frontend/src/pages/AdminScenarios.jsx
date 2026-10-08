import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { api } from '../api.js'

export default function AdminScenarios() {
  const [rows, setRows] = useState([])
  const [msg, setMsg] = useState('')
  const [err, setErr] = useState('')
  const [q, setQ] = useState('')
  const load = () => api('/api/admin/scenarios').then(setRows).catch(e => setErr(e.message))
  useEffect(() => { load() }, [])
  const run = async (fn, ok) => { setErr(''); setMsg(''); try { await fn(); if (ok) setMsg(ok); load() } catch (e) { setErr(e.message) } }
  const upload = e => {
    const f = e.target.files[0]; if (!f) return
    const form = new FormData(); form.append('file', f)
    run(() => api('/api/admin/scenarios/upload', { method: 'POST', form }), `Imported ${f.name}`)
    e.target.value = ''
  }
  const seed = () => run(async () => {
    const r = await api('/api/admin/scenarios/seed', { method: 'POST' })
    setMsg(`${r.added.length} imported` + (Object.keys(r.errors).length ? `; errors: ${Object.entries(r.errors).map(([k, v]) => `${k}: ${v}`).join('; ')}` : ''))
  })
  const shown = rows.filter(s => !q || `${s.name} ${s.slug} ${s.category}`.toLowerCase().includes(q.toLowerCase()))
  return (
    <section className="card">
      <div className="row-between">
        <h1>Scenarios ({rows.length})</h1>
        <div className="actions-row">
          <Link to="/admin/scenarios/new"><button>New scenario</button></Link>
          <label className="button-like">Upload package (.zip/.tar.gz)<input type="file" accept=".zip,.tar.gz,.tgz" onChange={upload} hidden /></label>
          <button className="secondary" onClick={seed} title="Import packages from the scenarios directory that were never imported">Import packages</button>
        </div>
      </div>
      {msg && <p className="ok">{msg}</p>}{err && <p className="error">{err}</p>}
      <input placeholder="Search" value={q} onChange={e => setQ(e.target.value)} style={{ maxWidth: 300 }} />
      <table>
        <thead><tr><th>Name</th><th>Category</th><th>Difficulty</th><th>Image</th><th>Weight</th><th>Time</th><th>Ver.</th><th>Enabled</th><th></th></tr></thead>
        <tbody>
          {shown.map(s => (
            <tr key={s.id} className={s.enabled ? '' : 'dim'}>
              <td><Link to={`/admin/scenarios/${s.id}`}>{s.name}</Link><div className="muted small">{s.slug}</div></td>
              <td>{s.category}</td><td>{s.difficulty}</td><td className="small">{s.docker_image}</td><td>{s.resource_weight}</td>
              <td>{s.time_limit} min</td><td>{s.version}</td><td>{s.enabled ? 'yes' : 'no'}</td>
              <td className="actions">
                <button className="small" onClick={() => run(() => api(`/api/admin/scenarios/${s.id}`, { method: 'PATCH', body: { enabled: !s.enabled } }))}>{s.enabled ? 'Disable' : 'Enable'}</button>
                <button className="small danger" onClick={() => window.confirm(`Delete "${s.name}"? Past attempts keep their results.`) &&
                  run(() => api(`/api/admin/scenarios/${s.id}`, { method: 'DELETE' }), 'Deleted')}>Delete</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  )
}
