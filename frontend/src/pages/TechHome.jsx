import { useEffect, useMemo, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { api, fmtDate } from '../api.js'

export const statusLabel = {
  queued: 'Queued', provisioning: 'Preparing lab', ready: 'In progress', verifying: 'Grading', completed: 'Completed',
  failed: 'Failed', timed_out: 'Time limit reached', abandoned: 'Abandoned', terminated: 'Terminated',
}

export function ScoreCell({ a }) {
  if (a.score == null) return <span className="muted">—</span>
  return <span className={a.passed ? 'ok' : 'bad'}>{a.score}/{a.max_score} ({a.percent}%) {a.passed ? 'pass' : 'fail'}</span>
}

export default function TechHome() {
  const [scenarios, setScenarios] = useState([])
  const [attempts, setAttempts] = useState([])
  const [filter, setFilter] = useState({ category: '', difficulty: '', q: '' })
  const [err, setErr] = useState('')
  const nav = useNavigate()
  useEffect(() => {
    api('/api/scenarios').then(setScenarios).catch(e => setErr(e.message))
    api('/api/attempts').then(setAttempts).catch(() => {})
  }, [])
  const active = attempts.find(a => ['queued', 'provisioning', 'ready', 'verifying'].includes(a.status))
  const cats = useMemo(() => [...new Set(scenarios.map(s => s.category))], [scenarios])
  const shown = scenarios.filter(s => (!filter.category || s.category === filter.category) &&
    (!filter.difficulty || s.difficulty === filter.difficulty) &&
    (!filter.q || (s.name + ' ' + s.description).toLowerCase().includes(filter.q.toLowerCase())))
  const start = async s => {
    setErr('')
    try { const a = await api('/api/attempts', { method: 'POST', body: { scenario_id: s.id } }); nav(`/attempts/${a.id}`) }
    catch (e) { setErr(e.message) }
  }
  return (
    <>
      {active && (
        <section className="card highlight">
          You have an unfinished test: <b>{active.scenario_name}</b> ({statusLabel[active.status]}).{' '}
          <Link to={`/attempts/${active.id}`}>Open it</Link>
        </section>
      )}
      <section className="card">
        <h1>Scenarios</h1>
        <div className="filters">
          <select value={filter.category} onChange={e => setFilter({ ...filter, category: e.target.value })}>
            <option value="">All categories</option>{cats.map(c => <option key={c}>{c}</option>)}
          </select>
          <select value={filter.difficulty} onChange={e => setFilter({ ...filter, difficulty: e.target.value })}>
            <option value="">All difficulties</option><option>easy</option><option>intermediate</option><option>advanced</option><option value="extra-hard">extra hard</option>
          </select>
          <input placeholder="Search" value={filter.q} onChange={e => setFilter({ ...filter, q: e.target.value })} />
        </div>
        {err && <p className="error">{err}</p>}
        <div className="grid">
          {shown.map(s => (
            <article key={s.id} className="scenario">
              <div className="tags"><span className="tag">{s.category}</span><span className={`tag d-${s.difficulty}`}>{s.difficulty.replace('-', ' ')}</span>
                <span className="tag">{s.time_limit} min</span></div>
              <h3>{s.name}</h3>
              <p className="desc">{s.description}</p>
              <button disabled={!!active} onClick={() => start(s)}>Start test</button>
            </article>
          ))}
          {!shown.length && <p className="muted">No scenarios match.</p>}
        </div>
      </section>
      <section className="card">
        <h2>My attempts</h2>
        <table>
          <thead><tr><th>#</th><th>Scenario</th><th>Status</th><th>Started</th><th>Score</th></tr></thead>
          <tbody>
            {attempts.map(a => (
              <tr key={a.id}><td><Link to={`/attempts/${a.id}`}>{a.id}</Link></td><td>{a.scenario_name}</td>
                <td>{statusLabel[a.status]}</td><td>{fmtDate(a.started_at || a.created_at)}</td><td><ScoreCell a={a} /></td></tr>
            ))}
            {!attempts.length && <tr><td colSpan={5} className="muted">No attempts yet.</td></tr>}
          </tbody>
        </table>
      </section>
    </>
  )
}
