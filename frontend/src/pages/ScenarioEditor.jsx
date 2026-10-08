import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { api } from '../api.js'

const blank = {
  slug: '', name: '', description: '', category: 'Linux', difficulty: 'easy', docker_image: 'linux-training-base',
  time_limit: 30, resource_weight: 1, enabled: true,
  setup_script: '#!/bin/bash\n# create the broken state (runs as root inside the lab, never on the host)\nset -e\n',
  verify_script: '# check the final state: check NAME CMD..., pass/fail NAME [detail], partial NAME 0.5, deduct NAME\ncheck service_running systemctl is-active --quiet crond\n',
  score_yaml: 'pass_score: 70\nitems:\n  service_running: {points: 100, label: "Service is running"}\n',
  options: { capabilities: [], tmpfs: {}, collect: [] },
}
const IMAGES = ['linux-training-base', 'linux-training-web', 'linux-training-lamp']

export default function ScenarioEditor() {
  const { id } = useParams()
  const nav = useNavigate()
  const isNew = !id
  const [f, setF] = useState(null)
  const [meta, setMeta] = useState({ categories: [], difficulties: [], capabilities: [] })
  const [opts, setOpts] = useState('')
  const [err, setErr] = useState('')
  const [msg, setMsg] = useState('')
  useEffect(() => {
    api('/api/scenarios/meta').then(setMeta)
    if (isNew) { setF(blank); setOpts(JSON.stringify(blank.options, null, 2)) }
    else api(`/api/admin/scenarios/${id}`).then(s => { setF(s); setOpts(JSON.stringify(s.options, null, 2)) }).catch(e => setErr(e.message))
  }, [id])
  if (!f) return <p className="muted">{err || 'Loading…'}</p>
  const set = (k, num) => e => setF({ ...f, [k]: e.target.type === 'checkbox' ? e.target.checked : num ? Number(e.target.value) : e.target.value })
  const save = async e => {
    e.preventDefault(); setErr(''); setMsg('')
    let options
    try { options = JSON.parse(opts || '{}') } catch { setErr('Lab options: not valid JSON'); return }
    const body = { ...f, options }
    try {
      const s = isNew ? await api('/api/admin/scenarios', { method: 'POST', body }) : await api(`/api/admin/scenarios/${id}`, { method: 'PATCH', body })
      setF(s); setMsg(`Saved (version ${s.version})`)
      if (isNew) nav(`/admin/scenarios/${s.id}`, { replace: true })
    } catch (x) { setErr(x.message) }
  }
  return (
    <form className="card" onSubmit={save}>
      <h1>{isNew ? 'New scenario' : `Edit: ${f.name}`} {!isNew && <span className="muted small">version {f.version}</span>}</h1>
      <div className="form-grid">
        <label>Identifier (directory name){isNew ? <input value={f.slug} onChange={set('slug')} required pattern="[a-z0-9][a-z0-9\-]{1,62}" /> : <input value={f.slug} disabled />}</label>
        <label>Scenario name<input value={f.name} onChange={set('name')} required /></label>
        <label>Category<select value={f.category} onChange={set('category')}>{meta.categories.map(c => <option key={c}>{c}</option>)}</select></label>
        <label>Difficulty<select value={f.difficulty} onChange={set('difficulty')}>{meta.difficulties.map(c => <option key={c}>{c}</option>)}</select></label>
        <label>Docker image<select value={f.docker_image} onChange={set('docker_image')}>{IMAGES.map(c => <option key={c}>{c}</option>)}</select></label>
        <label>Time limit (minutes)<input type="number" min={1} max={600} value={f.time_limit} onChange={set('time_limit', true)} /></label>
        <label>Resource weight<input type="number" min={1} value={f.resource_weight} onChange={set('resource_weight', true)} /></label>
        <label className="check"><input type="checkbox" checked={f.enabled} onChange={set('enabled')} /> Enabled</label>
      </div>
      <label>Description shown to the technician (the symptom, not the cause)<textarea rows={4} value={f.description} onChange={set('description')} /></label>
      <label>Setup script (setup.sh — creates the broken state inside the lab)<textarea rows={14} value={f.setup_script} onChange={set('setup_script')} spellCheck={false} /></label>
      <label>Verification script (verify.sh — checks the final state)<textarea rows={12} value={f.verify_script} onChange={set('verify_script')} spellCheck={false} /></label>
      <label>Scoring (score.yaml)<textarea rows={10} value={f.score_yaml} onChange={set('score_yaml')} spellCheck={false} /></label>
      <label>Lab options (JSON: capabilities {meta.capabilities.join('/')}, tmpfs {'{path: MB}'}, collect [commands])<textarea rows={5} value={opts} onChange={e => setOpts(e.target.value)} spellCheck={false} /></label>
      {err && <p className="error">{err}</p>}{msg && <p className="ok">{msg}</p>}
      <div className="actions-row"><button>Save</button><button type="button" className="secondary" onClick={() => nav('/admin/scenarios')}>Back</button></div>
    </form>
  )
}
