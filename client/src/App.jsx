import { Routes, Route, NavLink, useNavigate } from 'react-router-dom'
import BrowsePage  from './pages/BrowsePage'
import DetailPage  from './pages/DetailPage'
import HowItWorksPage from './pages/HowItWorksPage'
import AboutPage from './pages/AboutPage'
import SavedPage from './pages/SavedPage'
import AdminPage from './pages/AdminPage'
import useFavorites from './hooks/useFavorites'

function Nav() {
  const navigate = useNavigate()
  const { favorites } = useFavorites()
  return (
    <nav className="main-nav">
      <div className="nav-logo">
        <span className="nav-logo-red">▌</span> AuctionLab
      </div>

      <ul className="nav-links">
        <li><NavLink to="/">Browse</NavLink></li>
        <NavLink to="/how-it-works">How It Works</NavLink>
      <NavLink to="/about">About</NavLink>
        <NavLink to="/saved" className="nav-saved">
          ♥ Saved
          {favorites.length > 0 && <span className="nav-saved-count">{favorites.length}</span>}
        </NavLink>
      </ul>

      <button className="nav-cta" onClick={() => navigate('/')}>
        View All Vehicles
      </button>
    </nav>
  )
}

export default function App() {
  return (
    <>
      <Nav />
      <Routes>
        <Route path="/"            element={<BrowsePage />} />
        <Route path="/vehicle/:id" element={<DetailPage />} />
        <Route path="/how-it-works" element={<HowItWorksPage />} />
        <Route path="/about" element={<AboutPage />} />
        <Route path="/saved" element={<SavedPage />} />
        <Route path="/admin" element={<AdminPage />} />

      </Routes>
    </>
  )
}
