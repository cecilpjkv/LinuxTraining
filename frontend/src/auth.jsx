import { createContext, useContext, useEffect, useState } from 'react'
import { api } from './api.js'

const Ctx = createContext(null)

export function AuthProvider({ children }) {
  const [user, setUser] = useState(undefined) // undefined = loading, null = logged out
  const [needPw, setNeedPw] = useState(false)  // technicians must enter the shared test password
  useEffect(() => { api('/api/auth/session').then(r => { setUser(r.user); setNeedPw(r.test_password) }).catch(() => setUser(null)) }, [])
  const login = async (username, password) => setUser(await api('/api/auth/login', { method: 'POST', body: { username, password } }))
  const enter = async (full_name, email, password) => setUser(await api('/api/auth/technician', { method: 'POST', body: { full_name, email, password } }))
  const logout = async () => { await api('/api/auth/logout', { method: 'POST' }); setUser(null) }
  return <Ctx.Provider value={{ user, login, enter, logout, needPw }}>{children}</Ctx.Provider>
}

export const useAuth = () => useContext(Ctx)
