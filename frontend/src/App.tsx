import { useEffect, useState } from 'react'
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import { supabase } from './services/supabase'
import { useAuthStore } from './store/useAuthStore'
import { Clients } from './pages/Clients'
import { Finance } from './pages/Finance'

export default function App() {
  const { setUser, setProfile } = useAuthStore()
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const init = async () => {
      const { data: { session } } = await supabase.auth.getSession()
      if (session) {
        setUser(session.user)
        const { data: profile } = await supabase.from('profiles').select('*').eq('id', session.user.id).single()
        setProfile(profile)
      }
      setLoading(false)
    }
    init()
  }, [])

  if (loading) return <div>Cargando...</div>

  return (
    <Router>
      <Routes>
        <Route path="/clients" element={<Clients />} />
        <Route path="/finance" element={<Finance />} />
        <Route path="/" element={<Navigate to="/clients" />} />
      </Routes>
    </Router>
  )
}
