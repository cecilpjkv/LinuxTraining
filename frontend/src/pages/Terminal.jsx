import { useEffect, useRef, useState } from 'react'
import { Terminal as XTerm } from '@xterm/xterm'
import { FitAddon } from '@xterm/addon-fit'
import '@xterm/xterm/css/xterm.css'

// Browser terminal: xterm.js <-> WebSocket <-> PTY in the lab. Reconnects by itself; the server keeps the shell and
// replays the recent screen.
export default function Terminal({ attemptId, enabled }) {
  const box = useRef(null)
  const [state, setState] = useState('connecting')
  useEffect(() => {
    if (!enabled) return
    const term = new XTerm({ cursorBlink: true, fontSize: 14, scrollback: 5000,
      fontFamily: 'ui-monospace, SFMono-Regular, Menlo, Consolas, monospace', theme: { background: '#0d1117' } })
    const fit = new FitAddon()
    term.loadAddon(fit)
    term.open(box.current)
    fit.fit()
    let ws, stopped = false, retry = 0, timer
    const send = m => ws && ws.readyState === 1 && ws.send(JSON.stringify(m))
    const connect = () => {
      const proto = location.protocol === 'https:' ? 'wss' : 'ws'
      ws = new WebSocket(`${proto}://${location.host}/ws/attempts/${attemptId}/terminal?cols=${term.cols}&rows=${term.rows}`)
      ws.onopen = () => { retry = 0; setState('connected'); term.reset(); term.focus() }
      ws.onmessage = e => term.write(e.data)
      ws.onclose = e => {
        if (stopped) return
        if (e.code === 4403) { setState('closed'); return }
        setState('reconnecting')
        timer = setTimeout(connect, Math.min(1000 * 2 ** retry++, 10000))
      }
    }
    connect()
    // no copying out of the lab (answers must not be pasted into an AI chat): selections are cleared at once, the
    // copy shortcuts are swallowed; Ctrl+C still reaches the shell as an interrupt
    const onSel = term.onSelectionChange(() => { if (term.hasSelection()) term.clearSelection() })
    // xterm.js selects with the mouse itself (and mirrors the selection into the page): the mouse never reaches it,
    // a click only focuses the terminal for typing
    const el = box.current
    const block = e => { e.preventDefault(); e.stopPropagation(); if (e.type === 'mousedown') term.focus() }
    for (const t of ['mousedown', 'dblclick', 'selectstart']) el.addEventListener(t, block, true)
    term.attachCustomKeyEventHandler(e => {
      const k = e.key.toLowerCase()
      if ((e.ctrlKey || e.metaKey) && e.shiftKey && k === 'c') return false   // Ctrl+Shift+C (terminal copy)
      if (e.metaKey && k === 'c') return false                                 // Cmd+C (macOS copy)
      if ((e.ctrlKey || e.metaKey) && k === 'insert') return false             // Ctrl+Insert (copy)
      return true
    })
    const onData = term.onData(d => send({ type: 'input', data: d }))
    const onResize = term.onResize(({ cols, rows }) => send({ type: 'resize', cols, rows }))
    const ro = new ResizeObserver(() => { try { fit.fit() } catch { /* hidden */ } })
    ro.observe(box.current)
    return () => { for (const t of ['mousedown', 'dblclick', 'selectstart']) el.removeEventListener(t, block, true)
      stopped = true; clearTimeout(timer); onSel.dispose(); onData.dispose(); onResize.dispose(); ro.disconnect(); ws && ws.close(); term.dispose() }
  }, [attemptId, enabled])
  return (
    <div className="terminal-wrap no-copy" onCopy={e => e.preventDefault()} onCut={e => e.preventDefault()}
      onContextMenu={e => e.preventDefault()} onDragStart={e => e.preventDefault()}>
      <div className={`term-state s-${state}`}>{{ connecting: 'Connecting…', connected: 'Connected', reconnecting: 'Connection lost — reconnecting…', closed: 'Terminal closed' }[state]}</div>
      <div ref={box} className="terminal" />
    </div>
  )
}
