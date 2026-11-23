import { Routes, Route, NavLink, useNavigate } from 'react-router-dom'
import BrowsePage  from './pages/BrowsePage'
import DetailPage  from './pages/DetailPage'

function Nav() {
  const navigate = useNavigate()
  return (
    <nav className="main-nav">
      <div className="nav-logo">
        <span className="nav-logo-red">▌</span> AuctionLab
      </div>

      <ul className="nav-links">
        <li><NavLink to="/">Browse</NavLink></li>
        <li><a href="#how-it-works">How It Works</a></li>
        <li><a href="https://kotowing.com" target="_blank" rel="noreferrer">KO Towing</a></li>
        <li><a href="#about">About</a></li>
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
      </Routes>
    </>
  )
}
