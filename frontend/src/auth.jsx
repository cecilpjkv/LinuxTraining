import { createContext, useContext, useEffect, useState } from 'react'
import { api } from './api.js'

const Ctx = createContext(null)

export function AuthProvider({ children }) {
  const [user, setUser] = useState(undefined) // undefined = loading, null = logged out
  useEffect(() => { api('/api/auth/me').then(setUser).catch(() => setUser(null)) }, [])
  const login = async (username, password) => setUser(await api('/api/auth/login', { method: 'POST', body: { username, password } }))
  const register = async b => setUser(await api('/api/auth/register', { method: 'POST', body: b }))
  const logout = async () => { await api('/api/auth/logout', { method: 'POST' }); setUser(null) }
  return <Ctx.Provider value={{ user, login, register, logout }}>{children}</Ctx.Provider>
}

export const useAuth = () => useContext(Ctx)
