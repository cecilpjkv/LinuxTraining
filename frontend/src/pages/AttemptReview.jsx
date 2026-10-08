import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import { api, fmtDate } from '../api.js'
import { statusLabel } from './TechHome.jsx'

const dur = s => (s == null ? '—' : `${Math.floor(s / 60)} min ${s % 60} s`)
const time = s => new Date(s).toLocaleTimeString()

export default function AttemptReview() {
  const { id } = useParams()
  const [a, setA] = useState(null)
  const [err, setErr] = useState('')
  const [open, setOpen] = useState({})
  useEffect(() => { api(`/api/admin/attempts/${id}`).then(setA).catch(e => setErr(e.message)) }, [id])
  if (!a) return <p className="muted">{err || 'Loading…'}</p>
  return (
    <>
      <section className="card">
        <h1>Attempt #{a.id}</h1>
        <dl className="facts">
          <dt>Technician</dt><dd>{a.technician.username}{a.technician.full_name && ` (${a.technician.full_name})`}</dd>
          <dt>Scenario</dt><dd>{a.scenario.name}{a.scenario.version && <span className="muted"> · version {a.scenario.version}</span>}</dd>
          <dt>Status</dt><dd>{statusLabel[a.status]}{a.end_reason && <span className="muted"> — {a.end_reason}</span>}</dd>
          <dt>Start time</dt><dd>{fmtDate(a.started_at)}</dd>
          <dt>End time</dt><dd>{fmtDate(a.ended_at)}</dd>
          <dt>Duration</dt><dd>{dur(a.duration_seconds)}</dd>
          <dt>Score</dt><dd>{a.score != null ? `${a.score}/${a.max_score} (${a.percent}%)` : '—'}</dd>
          <dt>Pass/fail</dt><dd>{a.passed == null ? '—' : a.passed ? <span className="ok">PASS</span> : <span className="bad">FAIL</span>}</dd>
        </dl>
        {a.error && <pre className="block bad">{a.error}</pre>}
      </section>
      <section className="card">
        <h2>Command history ({a.commands.length})</h2>
        <table className="cmds">
          <thead><tr><th>Time</th><th>Command</th><th>Exit</th><th>Directory</th></tr></thead>
          <tbody>
            {a.commands.map((c, i) => (
              <>
                <tr key={i} className="clickable" onClick={() => setOpen({ ...open, [i]: !open[i] })}>
                  <td className="mono">{time(c.at)}</td><td className="mono">{c.command}</td>
                  <td className={c.exit_code ? 'bad' : 'ok'}>{c.exit_code}</td><td className="mono small">{c.cwd}</td>
                </tr>
                {open[i] && <tr key={`o${i}`}><td /><td colSpan={3}><pre className="block">{c.output || '(no output)'}</pre></td></tr>}
              </>
            ))}
            {!a.commands.length && <tr><td colSpan={4} className="muted">No commands recorded.</td></tr>}
          </tbody>
        </table>
        <p className="muted small">Click a command to see its output.</p>
      </section>
      <section className="card">
        <h2>Verification</h2>
        <table><tbody>
          {a.verification.map(v => (
            <tr key={v.check}><td>{v.label}</td><td className={v.passed ? 'ok' : 'bad'}><b>{v.passed ? 'PASS' : 'FAIL'}</b></td><td className="small muted">{v.detail}</td></tr>
          ))}
          {!a.verification.length && <tr><td className="muted">Not verified.</td></tr>}
        </tbody></table>
      </section>
      <section className="card">
        <h2>Score breakdown</h2>
        <table><tbody>
          {a.breakdown.map(b => (
            <tr key={b.item}><td>{b.label}</td><td className="muted">{b.kind}</td>
              <td className={b.points < 0 ? 'bad' : ''}>{b.points}{b.kind !== 'deduction' && ` / ${b.max}`}</td><td className="small muted">{b.reason}</td></tr>
          ))}
          {a.score != null && <tr><td><b>Total</b></td><td /><td><b>{a.score} / {a.max_score}</b></td><td /></tr>}
        </tbody></table>
      </section>
      <section className="card">
        <h2>Final state</h2>
        <pre className="block">{a.final_state || 'Not collected.'}</pre>
        {a.verify_output && <details><summary>verify.sh output</summary><pre className="block">{a.verify_output}</pre></details>}
      </section>
    </>
  )
}
