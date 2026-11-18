import { Routes, Route, Navigate } from 'react-router-dom'
import BrowsePage from './pages/BrowsePage.jsx'
import DetailPage from './pages/DetailPage.jsx'

function Header() {
  return (
    <header className="site-header">
      <div className="header-inner">
        <a href="/" className="site-logo">
          <span className="logo-icon"></span>
          <span className="logo-text">AuctionLab</span>
        </a>
        <p className="site-tagline">K.O. Towing Auction Vehicles</p>
      </div>
    </header>
  )
}

function Footer() {
  return (
    <footer className="site-footer">
      <p>AuctionLab  Vehicle data sourced from K.O. Towing auction listings</p>
    </footer>
  )
}

export default function App() {
  return (
    <div className="app-shell">
      <Header />
      <main className="main-content">
        <Routes>
          <Route path="/" element={<BrowsePage />} />
          <Route path="/vehicle/:id" element={<DetailPage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </main>
      <Footer />
    </div>
  )
}
