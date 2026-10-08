// Small fetch wrapper: the session is an HttpOnly cookie, so requests only need credentials: 'same-origin'.
export class ApiError extends Error {
  constructor(status, message) { super(message); this.status = status }
}

export async function api(path, { method = 'GET', body, form } = {}) {
  const opts = { method, credentials: 'same-origin', headers: {} }
  if (form) opts.body = form
  else if (body !== undefined) { opts.body = JSON.stringify(body); opts.headers['Content-Type'] = 'application/json' }
  const r = await fetch(path, opts)
  if (r.status === 204) return null
  const data = await r.json().catch(() => null)
  if (!r.ok) {
    let msg = data?.detail ?? r.statusText
    if (Array.isArray(msg)) msg = msg.map(d => `${d.loc?.slice(-1)[0]}: ${d.msg}`).join('; ')
    throw new ApiError(r.status, msg)
  }
  return data
}

export const fmtDate = s => (s ? new Date(s).toLocaleString() : '—')
