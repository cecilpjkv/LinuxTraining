import { useEffect, useState } from 'react'
import { api } from '../api.js'

export default function AdminSettings() {
  const [s, setS] = useState(null)
  const [vals, setVals] = useState({})
  const [msg, setMsg] = useState('')
  const [err, setErr] = useState('')
  useEffect(() => { api('/api/admin/settings').then(r => { setS(r); setVals(r.values) }).catch(e => setErr(e.message)) }, [])
  if (!s) return <p className="muted">{err || 'Loading…'}</p>
  const save = async e => {
    e.preventDefault(); setErr(''); setMsg('')
    try { const r = await api('/api/admin/settings', { method: 'PUT', body: vals }); setVals(r.values); setMsg('Saved') } catch (x) { setErr(x.message) }
  }
  return (
    <form className="card" onSubmit={save}>
      <h1>Resource settings</h1>
      <p className="muted">A test starts only when the number of active tests is below the maximum and the resource weight still fits;
        otherwise it waits in the queue. Changes apply to labs created from now on.</p>
      <div className="form-grid">
        {s.fields.map(f => (
          <label key={f.key}>{f.label}<input type="number" step={f.type === 'float' ? '0.1' : '1'} min={f.min} max={f.max}
            value={vals[f.key]} onChange={e => setVals({ ...vals, [f.key]: e.target.value })} /></label>
        ))}
      </div>
      {err && <p className="error">{err}</p>}{msg && <p className="ok">{msg}</p>}
      <button>Save</button>
    </form>
  )
}
