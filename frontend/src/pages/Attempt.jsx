import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { useParams } from 'react-router-dom'
import { api, fmtDate } from '../api.js'
import Terminal from './Terminal.jsx'
import { statusLabel } from './TechHome.jsx'

function Countdown({ deadline }) {
  const [now, setNow] = useState(Date.now())
  useEffect(() => { const t = setInterval(() => setNow(Date.now()), 1000); return () => clearInterval(t) }, [])
  const left = Math.max(0, Math.floor((new Date(deadline) - now) / 1000))
  const m = Math.floor(left / 60), s = left % 60
  return <span className={left < 300 ? 'bad' : ''}>{m}:{String(s).padStart(2, '0')} left</span>
}

export function Result({ r }) {
  return (
    <>
      <p className="big"><span className={r.passed ? 'ok' : 'bad'}>{r.score} / {r.max_score} ({r.percent}%) — {r.passed ? 'PASSED' : 'NOT PASSED'}</span></p>
      <table>
        <thead><tr><th>Item</th><th>Type</th><th>Points</th></tr></thead>
        <tbody>
          {(r.breakdown || []).map(b => (
            <tr key={b.item}><td>{b.label}</td><td className="muted">{b.kind}</td>
              <td className={b.points < 0 ? 'bad' : b.points >= b.max ? 'ok' : ''}>{b.points}{b.kind !== 'deduction' && ` / ${b.max}`}</td></tr>
          ))}
        </tbody>
      </table>
    </>
  )
}

export default function Attempt() {
  const { id } = useParams()
  const [a, setA] = useState(null)
  const [err, setErr] = useState('')
  const [busy, setBusy] = useState(false)
  useEffect(() => {
    let t, alive = true
    const load = async () => {
      try {
        const r = await api(`/api/attempts/${id}/result`)
        if (!alive) return
        setA(r)
        if (['queued', 'provisioning', 'verifying', 'ready'].includes(r.status)) t = setTimeout(load, r.status === 'ready' ? 10000 : 2000)
      } catch (e) { setErr(e.message) }
    }
    load()
    return () => { alive = false; clearTimeout(t) }
  }, [id])
  if (err) return <p className="error">{err}</p>
  if (!a) return <p className="muted">Loading…</p>
  const act = async (path, confirmText) => {
    if (confirmText && !window.confirm(confirmText)) return
    setBusy(true); setErr('')
    try { setA({ ...a, ...(await api(`/api/attempts/${id}/${path}`, { method: 'POST' })) }) } catch (e) { setErr(e.message) } finally { setBusy(false) }
  }
  return (
    <>
      <section className="card">
        <div className="row-between">
          <h1>{a.scenario_name}</h1>
          <span className="status">{statusLabel[a.status]}{a.status === 'ready' && a.deadline_at && <> · <Countdown deadline={a.deadline_at} /></>}</span>
        </div>
        <p className="desc pre">{a.description}</p>
        {a.status === 'queued' && <p>Waiting for a free lab slot{a.queue_position ? ` — position ${a.queue_position} in the queue` : ''}. This page updates by itself.</p>}
        {a.status === 'provisioning' && <p>Preparing your lab server… (usually under a minute)</p>}
        {a.status === 'verifying' && <p>Checking the server state and calculating your score…</p>}
        {['failed', 'abandoned', 'terminated'].includes(a.status) && <p className="bad">{a.end_reason}{a.error && `: ${a.error}`}</p>}
        {a.status === 'ready' && (
          <div className="actions-row">
            <button disabled={busy} onClick={() => act('complete', 'Finish the test now? The server will be checked and the lab removed.')}>Complete Test</button>
            <button className="secondary" disabled={busy} onClick={() => act('abandon', 'Abandon this test? It will not be graded.')}>Abandon</button>
          </div>
        )}
        {['queued', 'provisioning'].includes(a.status) && <button className="secondary" disabled={busy} onClick={() => act('abandon', 'Cancel this test?')}>Cancel</button>}
        {err && <p className="error">{err}</p>}
      </section>
      {a.status === 'ready' && <Terminal attemptId={a.id} enabled />}
      {a.score != null && (
        <section className="card">
          <h2>Result</h2>
          <Result r={a} />
          <p className="muted">Started {fmtDate(a.started_at)} · ended {fmtDate(a.ended_at)} · <Link to="/">Back to scenarios</Link></p>
        </section>
      )}
    </>
  )
}
