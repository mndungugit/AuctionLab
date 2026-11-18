import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { fetchCarImage } from '../api/carImage.js'

/**
 * VehicleCard
 * Displays a summary card for one vehicle in the browse grid.
 * Props: vehicle object from pub.vw_Vehicle
 */
export default function VehicleCard({ vehicle }) {
  const navigate = useNavigate()
  const [imgSrc, setImgSrc]     = useState(null)
  const [imgLoaded, setImgLoaded] = useState(false)

  useEffect(() => {
    let cancelled = false
    fetchCarImage(vehicle.Make, vehicle.Model, vehicle.ModelYear, vehicle.Vin).then(url => {
      if (!cancelled) setImgSrc(url)
    })
    return () => { cancelled = true }
  }, [vehicle.Make, vehicle.Model, vehicle.ModelYear, vehicle.Vin])

  const title = [vehicle.Make, vehicle.Model]
    .filter(Boolean)
    .join(' ') || 'Unknown Vehicle'

  const handleClick = () => navigate(`/vehicle/${vehicle.VehicleId}`)

  const handleKeyDown = (e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault()
      handleClick()
    }
  }

  const saleDate = vehicle.SaleDate
    ? new Date(vehicle.SaleDate).toLocaleDateString('en-US', {
        month: 'short', day: 'numeric', year: 'numeric'
      })
    : null

  return (
    <article
      className="vehicle-card"
      onClick={handleClick}
      onKeyDown={handleKeyDown}
      tabIndex={0}
      role="button"
      aria-label={`View details for ${vehicle.ModelYear || ''} ${title}`}
    >
      {/* ---- Image strip ---- */}
      <div className="card-image-wrap">
        {imgSrc && !imgLoaded && <span className="card-image-placeholder">&#x1F697;</span>}
        {imgSrc ? (
          <img
            src={imgSrc}
            alt={`${vehicle.ModelYear || ''} ${title}`}
            onLoad={() => setImgLoaded(true)}
            onError={() => { setImgSrc(null); setImgLoaded(false) }}
            style={{ display: imgLoaded ? 'block' : 'none' }}
          />
        ) : (
          <span className="card-image-placeholder">&#x1F697;</span>
        )}
      </div>

      {/* ---- Text content ---- */}
      <div className="card-header">
        <span className="card-year">{vehicle.ModelYear || '&mdash;'}</span>
        <span className={`badge ${vehicle.IsVerified ? 'badge-verified' : 'badge-unverified'}`}>
          {vehicle.IsVerified ? 'Verified' : 'Unverified'}
        </span>
      </div>

      <h3 className="card-title">{title}</h3>

      <div className="card-meta">
        {vehicle.Color     && <span>{vehicle.Color}</span>}
        {vehicle.BodyClass && <span>{vehicle.BodyClass}</span>}
      </div>

      {saleDate && (
        <p className="card-sale-date">Sale: {saleDate}</p>
      )}
    </article>
  )
}
