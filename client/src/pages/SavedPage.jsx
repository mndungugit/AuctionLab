import { useNavigate } from 'react-router-dom'
import useFavorites from '../hooks/useFavorites'
import VehicleCard from '../components/VehicleCard'

export default function SavedPage() {
  const navigate = useNavigate()
  const { favorites, clearFavorites } = useFavorites()

  const handleClear = () => {
    if (window.confirm('Remove all saved vehicles?')) clearFavorites()
  }

  return (
    <section className="browse-section saved-page">
      <div className="section-header">
        <h2 className="section-title">
          Saved <span className="accent">Vehicles</span>
        </h2>
        <div className="saved-actions">
          <span className="results-count">
            {favorites.length} {favorites.length === 1 ? 'vehicle' : 'vehicles'}
          </span>
          {favorites.length > 0 && (
            <button className="btn-clear" onClick={handleClear}>Clear all</button>
          )}
        </div>
      </div>

      {favorites.length === 0 ? (
        <div className="state-empty">
          <span className="saved-empty-icon">♡</span>
          <span>No saved vehicles yet. Tap the heart on any vehicle to save it here.</span>
          <button className="btn-view saved-empty-cta" onClick={() => navigate('/')}>
            Browse Vehicles →
          </button>
        </div>
      ) : (
        <div className="vehicle-grid">
          {favorites.map(v => (
            <VehicleCard
              key={v.id}
              vehicle={v}
              onClick={() => navigate(`/vehicle/${v.id}`)}
            />
          ))}
        </div>
      )}

      <p className="saved-note">Saved vehicles are stored in this browser only.</p>
    </section>
  )
}
