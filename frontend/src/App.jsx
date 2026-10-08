import { Link, Navigate, NavLink, Route, Routes } from 'react-router-dom'
import { AuthProvider, useAuth } from './auth.jsx'
import Login from './pages/Login.jsx'
import Register from './pages/Register.jsx'
import TechHome from './pages/TechHome.jsx'
import AdminDashboard from './pages/AdminDashboard.jsx'
import AdminUsers from './pages/AdminUsers.jsx'

function Shell({ children }) {
  const { user, logout } = useAuth()
  return (
    <div className="app">
      <header className="top">
        <Link to="/" className="brand">Linux Training</Link>
        {user && (
          <nav>
            {user.role === 'admin' ? (
              <>
                <NavLink to="/admin">Dashboard</NavLink>
                <NavLink to="/admin/users">Users</NavLink>
              </>
            ) : (
              <NavLink to="/">Scenarios</NavLink>
            )}
            <span className="who">{user.username} ({user.role})</span>
            <button className="link" onClick={logout}>Log out</button>
          </nav>
        )}
      </header>
      <main>{children}</main>
    </div>
  )
}

function Guard({ role, children }) {
  const { user } = useAuth()
  if (user === undefined) return <p className="muted">Loading…</p>
  if (!user) return <Navigate to="/login" replace />
  if (role && user.role !== role) return <Navigate to="/" replace />
  return children
}

function Home() {
  const { user } = useAuth()
  if (user === undefined) return <p className="muted">Loading…</p>
  if (!user) return <Navigate to="/login" replace />
  return user.role === 'admin' ? <Navigate to="/admin" replace /> : <TechHome />
}

export default function App() {
  return (
    <AuthProvider>
      <Shell>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/register" element={<Register />} />
          <Route path="/" element={<Home />} />
          <Route path="/admin" element={<Guard role="admin"><AdminDashboard /></Guard>} />
          <Route path="/admin/users" element={<Guard role="admin"><AdminUsers /></Guard>} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </Shell>
    </AuthProvider>
  )
}
